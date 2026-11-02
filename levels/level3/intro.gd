extends Node2D
## Úvod kapitoly III – noc v newyorskom prístave. Ricco vesluje v záchrannom člne z Margaret popri Soche slobody,
## za ňou svieti Manhattan (Empire State, Chrysler), v diaľke pláva trajekt. Nápis CHAPTER III – THE BIG APPLE,
## Riccove myšlienky a hláška ducha → stmavne → nábrežná stena (street.tscn – nábrežie a ulica v jednej mape, street.gd).
## Scénu generuje tools/build_level3.gd (_build_intro), obrázky _art_src/make_ch3_art.py. Bez kamery – súradnice = obrazovka.
## Godot docs: classes/class_tween, classes/class_animatedsprite2d

const FONT := preload("res://ui/fonts/tiny5.ttf")
const GLOW := preload("res://levels/level1/art/glow.png")
const STREET := "res://levels/level3/street.tscn"   ## nábrežie a ulica (jedna mapa)
const LoadingScreen := preload("res://ui/loading/loading_screen.gd")
const BOAT_FROM := -130.0     ## čln vpláva zľava…
const BOAT_STOP := 250.0      ## …zastaví sa pred sochou (rozhovor)…
const BOAT_TO := 700.0        ## …a odpláva doprava k mestu

var _boat: Node2D
var _ferry: Sprite2D
var _ghost: Sprite2D
var _ghost_glow: Sprite2D
var _waves: Sprite2D
var _t: float = 0.0
var _boat_y: float
var _wave_t: float = 2.0
var _skip: bool = false


func _ready() -> void:
	Progress.reach_chapter(3)   # STORY → CONTINUE
	_boat = $Boat
	_ferry = $Ferry
	_ghost = $Boat/Ghost
	_waves = $Waves
	_boat_y = _boat.position.y
	_boat.position.x = BOAT_FROM
	($Boat/Ricco as AnimatedSprite2D).play(&"idle")
	_ghost_glow = Sprite2D.new()
	_ghost_glow.texture = GLOW
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ghost_glow.material = m
	_ghost_glow.modulate = Color(0.45, 0.9, 1.0, 0.0)
	_ghost_glow.scale = Vector2(1.3, 1.8)
	_ghost_glow.position = _ghost.position + _ghost.texture.get_size() / 2.0
	_boat.add_child(_ghost_glow)
	Sfx.loop(&"docks", self, Vector2.INF, -8.0)
	Sfx.music(&"rainy_noir", 2.0)
	_play()


func _process(delta: float) -> void:
	_t += delta
	# čln sa hojdá, vlnky plynú, trajekt sa pomaly posúva
	_boat.position.y = roundf(_boat_y + 2.0 * sin(_t * 1.6))
	_boat.rotation = 0.03 * sin(_t * 1.6 + 0.8)
	_waves.region_rect.position.x = fmod(_t * 10.0, 640.0)
	_ferry.position.x += 4.0 * delta
	_ghost.position.y = -84.0 + roundf(2.0 * sin(_t * 2.2))
	_wave_t -= delta
	if _wave_t <= 0.0:
		_wave_t = randf_range(3.0, 6.0)
		Sfx.play(&"wave_crash", Vector2.INF, -24.0, 0.15, &"Ambience")


## Esc / Enter preskočí úvod
func _unhandled_input(event: InputEvent) -> void:
	if not _skip and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_accept")):
		_skip = true
		get_viewport().set_input_as_handled()
		_leave()


func _play() -> void:
	var black := _fade_rect()
	black.color.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(black, "color:a", 0.0, 2.0)
	tw.parallel().tween_property(_boat, "position:x", BOAT_STOP, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _wait(1.5)
	await _title()
	await tw.finished
	if _skip:
		return
	var lines: Array[String] = ["New York. Biggest town in the world.", "Seven million people. And one of 'em signs his letters 'M.'"]
	await ThoughtBox.think(self, lines).finished
	if _skip:
		return
	var tg := create_tween().set_parallel(true)
	tg.tween_property(_ghost, "modulate:a", 0.85, 1.0)
	tg.tween_property(_ghost_glow, "modulate:a", 0.4, 1.0)
	await _wait(1.0)
	await _ghost_says("LADY LIBERTY. SHE'S SEEN WORSE\nTHAN A PENGUIN IN A ROWBOAT.")
	if _skip:
		return
	await _ghost_says("THERE, UNDER THE BRIDGE.\nROW, KID. ROW.")
	if _skip:
		return
	var go := create_tween()
	go.tween_property(_boat, "position:x", BOAT_TO, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _wait(4.0)
	_leave()


## Nápis kapitoly hore nad mestom (ako na plagáte), po chvíli zmizne
func _title() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var title := _label("CHAPTER III", 24, Color8(245, 235, 209), -132)
	var sub := _label("THE BIG APPLE", 8, Color8(250, 200, 70), -108)
	layer.add_child(title)
	layer.add_child(sub)
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.8)
	tw.tween_property(sub, "modulate:a", 1.0, 0.6)
	tw.tween_interval(3.0)
	tw.tween_property(title, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(sub, "modulate:a", 0.0, 0.8)
	await tw.finished


## Hláška ducha nad ním (ako bark v Level3) – počká, kým zmizne
func _ghost_says(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", 8)
	l.add_theme_color_override(&"font_color", Color8(200, 244, 250))
	l.add_theme_color_override(&"font_outline_color", Color8(10, 24, 34))
	l.add_theme_constant_override(&"outline_size", 4)
	l.z_index = 40
	add_child(l)
	l.reset_size()
	var over: Vector2 = _boat.position + _ghost.position + Vector2(28, -6)
	l.position = (over - Vector2(l.size.x / 2.0, l.size.y)).round()
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	await tw.finished


var _left: bool = false

func _leave() -> void:
	if _left:
		return
	_left = true
	var black := _fade_rect()
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 1.2)
	await tw.finished
	LoadingScreen.go(get_tree(), STREET, 0.4)


func _label(t: String, size: int, col: Color, dy: float) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	l.add_theme_color_override(&"font_outline_color", Color8(20, 14, 10))
	l.add_theme_constant_override(&"outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)   # cez celú obrazovku, text v strede (posunutý o dy)
	l.offset_top = dy
	l.offset_bottom = dy
	l.modulate.a = 0.0
	return l


func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


func _fade_rect() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	return r
