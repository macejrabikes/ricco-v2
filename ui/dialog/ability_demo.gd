class_name AbilityDemo
extends Control
## Malá slučka v okne novej schopnosti (ui/dialog/ability_popup.gd) – ako GIF, ale zložená z obrázkov hry,
## takže vždy sedí s tým, ako Ricco naozaj vyzerá. Beží aj počas pauzy (okno ju má PROCESS_MODE_ALWAYS).
##  - focus:  mafiánske guľky letia rýchlo → stlačí sa SHIFT, svet zmodrie a spomalí → Ricco ich zostrelí vo vzduchu
##  - akimbo: strieľa jedna pištoľ → stlačí sa B, duch vytiahne druhú → strieľajú striedavo
## Nová ukážka = nová vetva v _build / _tick.

const SIZE := Vector2(128, 56)
const FLOOR_Y := 50.0
const FRAMES := preload("res://characters/ricco/ricco_frames.tres")
const PISTOL := preload("res://weapons/pistol/pistol.png")
const BULLET := preload("res://weapons/pistol/bullet.png")
const FLASH := preload("res://weapons/pistol/muzzle_flash.png")
const GHOST_HAND := preload("res://characters/ricco/ghost_hand/ghost_hand.tscn")
const FONT := preload("res://ui/fonts/tiny5.ttf")
const CREAM := Color8(245, 235, 209)
const BRASS := Color8(199, 153, 71)
const SHADE := Color(0.72, 0.72, 0.8)        ## zadná pištoľ (ako AKIMBO_SHADE v ricco.gd)
const FEET := Vector2(34, FLOOR_Y)
const GUN := FEET + Vector2(33, -19)         ## stred pištole (Aim + Gun z ricco.tscn)
const MUZZLE := GUN + Vector2(12, -4)
const GUN2 := GUN + Vector2(3, -6)           ## zadná pištoľ (AKIMBO_OFF)

var kind: StringName
var _t: float = 0.0
var _loop: float = 4.0
var _ricco: AnimatedSprite2D
var _gun: Sprite2D
var _gun2: Sprite2D
var _flash: Sprite2D
var _flash2: Sprite2D
var _tint: ColorRect
var _key: Label
var _key_sb: StyleBoxFlat
var _floor: Array[ColorRect] = []
var _shots: Array = []      ## [Sprite2D, rýchlosť x (px/s), spomaľuje sa?]
var _next: float = 0.0
var _back: bool = false
var _slow: float = 0.0      ## 0 = normálny čas, 1 = spomalené (plynulý prechod)


static func create(id: StringName) -> AbilityDemo:
	var d := AbilityDemo.new()
	d.kind = id
	return d


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.065, 0.085)
	bg.size = SIZE
	add_child(bg)
	var fl := ColorRect.new()   # podlaha
	fl.color = Color(0.2, 0.17, 0.17)
	fl.position = Vector2(0, FLOOR_Y)
	fl.size = Vector2(SIZE.x, SIZE.y - FLOOR_Y)
	add_child(fl)
	for i in 6:   # škáry v podlahe – pri spomalení sa posúvajú pomalšie
		var s := ColorRect.new()
		s.color = Color(0.13, 0.11, 0.11)
		s.size = Vector2(1, SIZE.y - FLOOR_Y)
		s.position = Vector2(i * 24.0, FLOOR_Y)
		add_child(s)
		_floor.append(s)

	_gun2 = _sprite(PISTOL, GUN2)   # za Riccom
	_gun2.self_modulate = SHADE
	var h2 := GHOST_HAND.instantiate() as Node2D
	h2.position = Vector2(-17.5, -6.5)
	(h2.get_node(^"Hand") as CanvasItem).self_modulate = SHADE
	_gun2.add_child(h2)
	_gun2.visible = false
	_flash2 = _sprite(FLASH, GUN2 + Vector2(16, -4))
	_flash2.visible = false

	_ricco = AnimatedSprite2D.new()
	_ricco.sprite_frames = FRAMES
	_ricco.position = FEET + Vector2(0, -21)
	_ricco.play(&"idle")
	add_child(_ricco)
	_gun = _sprite(PISTOL, GUN)
	var h := GHOST_HAND.instantiate() as Node2D
	h.position = Vector2(-17.5, -6.5)
	_gun.add_child(h)
	_flash = _sprite(FLASH, MUZZLE + Vector2(4, 0))
	_flash.visible = false

	_tint = ColorRect.new()   # modrý nádych spomalenia (ako focus_overlay)
	_tint.color = Color(0.35, 0.7, 1.0, 0.0)
	_tint.size = SIZE
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)

	# kláves vľavo hore – „stlačí sa“, keď ho ukážka použije
	_key = Label.new()
	_key.add_theme_font_override(&"font", FONT)
	_key.add_theme_font_size_override(&"font_size", 8)
	_key.add_theme_color_override(&"font_color", CREAM)
	_key_sb = StyleBoxFlat.new()
	_key_sb.bg_color = Color8(46, 42, 36)
	_key_sb.border_color = Color8(20, 18, 16)
	_key_sb.border_width_bottom = 2
	_key_sb.border_width_left = 1
	_key_sb.border_width_right = 1
	_key_sb.border_width_top = 1
	_key_sb.content_margin_left = 2
	_key_sb.content_margin_right = 2
	_key_sb.content_margin_bottom = 1
	_key.add_theme_stylebox_override(&"normal", _key_sb)
	_key.position = Vector2(4, 4)
	_key.text = KeyBindings.short(&"focus" if kind == &"focus" else &"fire_mode")
	add_child(_key)
	_loop = 4.6 if kind == &"focus" else 4.2


func _sprite(tex: Texture2D, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = at
	add_child(s)
	return s


func _process(delta: float) -> void:
	var prev: float = _t
	_t = fmod(_t + delta, _loop)
	if _t < prev:   # nová slučka
		_reset()
	var speed: float = lerpf(1.0, 0.3, _slow)
	for f in _floor:   # podlaha sa posúva (Ricco akoby stojí na idúcom vagóne – vidno rýchlosť času)
		f.position.x = fposmod(f.position.x - 20.0 * speed * delta, SIZE.x + 16.0)
	if kind == &"focus":
		_tick_focus(delta, speed)
	else:
		_tick_akimbo()
	_move_shots(delta, speed)
	_tint.color.a = 0.22 * _slow
	_ricco.speed_scale = 1.0   # Ricco sa nespomaľuje


func _reset() -> void:
	for s in _shots:
		(s[0] as Node).queue_free()
	_shots.clear()
	_next = 0.0
	_back = false
	_slow = 0.0
	_gun2.visible = false


## Ukážka spomalenia: 0–1.3 s guľky letia rýchlo (nad hlavou), 1.3 SHIFT, 1.5–3.6 Ricco ich zostrelí, 3.7 SHIFT
func _tick_focus(delta: float, _speed: float) -> void:
	var on: bool = _t >= 1.3 and _t < 3.8
	_slow = move_toward(_slow, 1.0 if on else 0.0, delta / 0.18)
	_press(absf(_t - 1.3) < 0.15 or absf(_t - 3.8) < 0.15)
	if _t >= _next:
		if _t < 1.2:
			_spawn(Vector2(SIZE.x + 2, 14), -230.0, true)   # mafiánska guľka nad hlavou
			_next = _t + 0.45
		elif _t < 3.0:
			_spawn(Vector2(SIZE.x + 2, MUZZLE.y), -230.0, true)   # guľka v jeho výške – zostrelí ju
			_next = _t + 0.55
		else:
			_next = _loop
	# Ricco strieľa po guľkách, keď sú dosť blízko
	if on and _t > 1.6:
		for s in _shots:
			var b := s[0] as Sprite2D
			if s[2] and absf(b.position.y - MUZZLE.y) < 1.0 and b.position.x < 112.0 and not b.has_meta(&"aimed"):
				b.set_meta(&"aimed", true)
				_fire(false)


## Ukážka akimbo: 0–1.4 s jedna pištoľ, 1.4 B (vysunie sa druhá), potom striedavo
func _tick_akimbo() -> void:
	_press(absf(_t - 1.4) < 0.15)
	if _t >= 1.4 and not _gun2.visible:
		_gun2.visible = true
		_gun2.position = GUN2 - Vector2(10, 0)
		create_tween().tween_property(_gun2, "position", GUN2, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _t >= _next and _t < _loop - 0.3:
		if _t < 1.4:
			_fire(false)
			_next = _t + 0.4
		elif _t >= 1.7:
			_fire(_back)
			_back = not _back
			_next = _t + 0.22
		else:
			_next = 1.7


func _press(on: bool) -> void:
	_key_sb.bg_color = BRASS if on else Color8(46, 42, 36)
	_key.position.y = 5.0 if on else 4.0
	_key.add_theme_color_override(&"font_color", Color8(14, 10, 12) if on else CREAM)


func _fire(back: bool) -> void:
	var g: Sprite2D = _gun2 if back else _gun
	var fl: Sprite2D = _flash2 if back else _flash
	var base: Vector2 = GUN2 if back else GUN
	fl.visible = true
	get_tree().create_timer(0.05, true, false, true).timeout.connect(func(): if is_instance_valid(fl): fl.visible = false)
	g.position = base - Vector2(2, 0)   # spätný ráz
	create_tween().tween_property(g, "position", base, 0.08)
	_spawn((GUN2 + Vector2(16, -4)) if back else MUZZLE, 420.0, false)


func _spawn(at: Vector2, vx: float, enemy: bool) -> void:
	var b := _sprite(BULLET, at)
	b.flip_h = vx < 0.0
	if enemy:
		b.modulate = Color(1.0, 0.85, 0.6)
	move_child(b, _tint.get_index())   # pod modrým nádychom
	_shots.append([b, vx, enemy])


## Guľky letia; Riccova guľka zostrelí mafiánsku, keď sa stretnú (iskra)
func _move_shots(delta: float, speed: float) -> void:
	for s in _shots:
		var b := s[0] as Sprite2D
		b.position.x += s[1] * delta * (speed if s[2] else 1.0)
	for s in _shots:
		if s[2] or not is_instance_valid(s[0]):
			continue
		for e in _shots:
			if not e[2] or not is_instance_valid(e[0]) or (e[0] as Node).is_queued_for_deletion():
				continue
			if absf((e[0] as Sprite2D).position.y - (s[0] as Sprite2D).position.y) < 2.0 \
					and (s[0] as Sprite2D).position.x >= (e[0] as Sprite2D).position.x - 2.0:
				_spark((e[0] as Sprite2D).position)
				(e[0] as Node).queue_free()
				(s[0] as Node).queue_free()
	var keep: Array = []
	for s in _shots:
		var b := s[0] as Sprite2D
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue
		if b.position.x < -8.0 or b.position.x > SIZE.x + 8.0:
			b.queue_free()
			continue
		keep.append(s)
	_shots = keep


func _spark(at: Vector2) -> void:
	var r := ColorRect.new()
	r.color = Color(1.0, 0.9, 0.55)
	r.size = Vector2(5, 5)
	r.position = at - Vector2(2.5, 2.5)
	add_child(r)
	move_child(r, _tint.get_index())
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.25)
	tw.tween_callback(r.queue_free)
