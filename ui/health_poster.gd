extends Control
## Zdravie Ricca ako plagát WANTED – úplne vpravo dole, náboje sú naľavo od neho.
##  - sépiová fotka Riccovej tváre (ui/hud_wanted_portrait.png) s každým zásahom viac popraská
##    (zubaté praskliny s odbočkami, tmavý stred a svetlá hrana),
##  - pri menej zdraví náplasť, pri málo zdraví monokel a slzy,
##  - pod fotkou súvislý červený prúžok zdravia (pri málo zdraví bliká),
##  - zásah: nové praskliny bliknú nabielo a plagát sa zatrasie; vyliečenie: posledná prasklina zmizne.
## Kreslí sa v pôvodnej veľkosti a zväčší sa cez scale (GameSettings.portrait_scale, predvolene 1.5×).

const PORTRAIT: Texture2D = preload("res://ui/hud_wanted_portrait.png")
const PHOTO := Vector2(2, 2)               ## fotka v plagáte (29×23 – tvár s kúskom klobúka)
const PHOTO_SIZE := Vector2(29, 23)
const POSTER_SIZE := Vector2(33, 30)
const BAR := Rect2(2, 27, 29, 1)
const MARGIN := Vector2(8, 8)
const SHADOW := 2.0
const CRACK_COUNT := 8

const POSTER_BG := Color8(214, 190, 140)
const POSTER_EDGE := Color8(120, 92, 56)
const PHOTO_BG := Color8(172, 146, 100)
const BAR_EMPTY := Color8(120, 92, 56)
const BAR_FULL := Color8(176, 32, 30)
const BAR_LOW := Color8(255, 82, 66)
const CRACK_DARK := Color8(58, 36, 20)
const CRACK_LIGHT := Color8(250, 240, 214)
const BANDAGE := Color8(236, 200, 170)
const BRUISE := Color8(90, 50, 110)
const TEAR := Color8(110, 190, 240)

var health: int = 8
var max_health: int = 8
var _cracks: Array[PackedVector2Array] = []   ## každá „úroveň“ = niekoľko čiar (hlavná + odbočky)
var _crack_level: Array[int] = []
var _shake_t: float = 1.0
var _flash_t: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	GameSettings.ensure_loaded()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = POSTER_SIZE + Vector2(SHADOW, SHADOW)
	_generate_cracks()
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		player.health_changed.connect(_on_health_changed)
		health = player.health
		max_health = player.max_health


## Zubaté praskliny: začnú na okraji fotky a kľukatia sa dovnútra, každá má 1–2 odbočky.
## Pevné semienko → vždy rovnaké praskliny.
func _generate_cracks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1930
	# začiatky na okraji fotky (pomerne k jej veľkosti)
	var starts: Array[Vector2] = [Vector2(0, 0.16), Vector2(1, 0.1), Vector2(0.3, 0), Vector2(1, 0.7),
			Vector2(0, 0.8), Vector2(0.7, 0), Vector2(0.5, 1), Vector2(0, 0.45)]
	var last := PHOTO_SIZE - Vector2.ONE
	for level in CRACK_COUNT:
		var p: Vector2 = (starts[level] * last).round()
		var center := PHOTO_SIZE / 2.0 + Vector2(rng.randf_range(-5, 5), rng.randf_range(-4, 4))
		var main := PackedVector2Array([p])
		var steps: int = rng.randi_range(4, 6)
		for s in steps:
			var dir: Vector2 = (center - p).normalized().rotated(rng.randf_range(-0.9, 0.9))
			p = (p + dir * rng.randf_range(2.0, 3.5)).clamp(Vector2.ZERO, last)
			main.append(p.round())
			if s >= 1 and rng.randf() < 0.45:   # odbočka
				var b := PackedVector2Array([p.round()])
				var bp: Vector2 = p
				for t in rng.randi_range(2, 3):
					bp = (bp + dir.rotated(rng.randf_range(-1.6, 1.6)) * rng.randf_range(1.5, 3.0)).clamp(Vector2.ZERO, last)
					b.append(bp.round())
				_cracks.append(b)
				_crack_level.append(level)
		_cracks.append(main)
		_crack_level.append(level)


func _on_health_changed(new_health: int, new_max: int) -> void:
	if new_health < health:
		_shake_t = 0.0
		_flash_t = 0.0
	health = new_health
	max_health = new_max


func _process(delta: float) -> void:
	var real: float = delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_time += real
	_shake_t = minf(_shake_t + real / 0.3, 1.0)
	_flash_t = minf(_flash_t + real / 0.35, 1.0)
	var r := layout_rect()
	scale = Vector2.ONE * GameSettings.portrait_scale
	position = r.position
	queue_redraw()


## Kde je plagát na obrazovke (aj s tieňom) – úplne vpravo dole; podľa toho sa posunú náboje.
func layout_rect() -> Rect2:
	var s: float = GameSettings.portrait_scale
	var full: Vector2 = (POSTER_SIZE + Vector2(SHADOW, SHADOW)) * s
	var vp: Vector2 = get_viewport_rect().size
	return Rect2((vp - MARGIN - full).floor(), full)


func _levels_shown() -> int:
	if max_health <= 0:
		return 0
	var lost: float = float(max_health - health) / float(max_health)
	return clampi(roundi(lost * CRACK_COUNT), 0, CRACK_COUNT)


func _draw() -> void:
	var o := Vector2.ZERO
	if _shake_t < 1.0:
		o.x = roundf(sin(_shake_t * 45.0) * 2.0 * (1.0 - _shake_t))
	# tieň, papier, okraj
	draw_rect(Rect2(o + Vector2(2, 2), POSTER_SIZE), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(o, POSTER_SIZE), POSTER_BG)
	_draw_frame(Rect2(o, POSTER_SIZE), POSTER_EDGE)
	draw_rect(Rect2(o + PHOTO, PHOTO_SIZE), PHOTO_BG)
	draw_texture(PORTRAIT, o + PHOTO)
	_draw_face_damage(o + PHOTO)

	# praskliny
	var shown: int = _levels_shown()
	for i in _cracks.size():
		var lvl: int = _crack_level[i]
		if lvl >= shown:
			continue
		var fresh: bool = lvl == shown - 1 and _flash_t < 1.0
		var light := PackedVector2Array()
		var dark := PackedVector2Array()
		for pt: Vector2 in _cracks[i]:
			dark.append(o + PHOTO + pt + Vector2(0.5, 0.5))
			light.append(o + PHOTO + pt + Vector2(1.5, 0.5))
		draw_polyline(light, CRACK_LIGHT if not fresh else Color.WHITE, 1.0)
		draw_polyline(dark, CRACK_DARK.lerp(Color.WHITE, (1.0 - _flash_t) * 0.8) if fresh else CRACK_DARK, 1.0)

	# prúžok zdravia
	var low: bool = health > 0 and health <= maxi(1, int(max_health / 4.0))
	var fill: Color = BAR_LOW if (low and fmod(_time, 0.5) < 0.25) else BAR_FULL
	var k: float = clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)
	draw_rect(Rect2(o + BAR.position, BAR.size), BAR_EMPTY)
	draw_rect(Rect2(o + BAR.position, Vector2(ceilf(BAR.size.x * k), BAR.size.y)), fill)


func _draw_frame(r: Rect2, c: Color) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), c)
	draw_rect(Rect2(r.position, Vector2(1, r.size.y)), c)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), c)


## Náplasť od 5/8, monokel a slzy od 2/8 (súradnice vo fotke 29×23)
func _draw_face_damage(p: Vector2) -> void:
	var ratio: float = float(health) / float(maxi(max_health, 1))
	if ratio <= 0.625:   # náplasť na pravom líci
		draw_rect(Rect2(p + Vector2(23, 15), Vector2(5, 2)), BANDAGE)
		draw_rect(Rect2(p + Vector2(24, 14), Vector2(2, 4)), BANDAGE)
	if ratio <= 0.25:    # monokel okolo ľavého oka, slzy
		_draw_frame(Rect2(p + Vector2(7, 8), Vector2(6, 7)), BRUISE)
		draw_rect(Rect2(p + Vector2(9, 15), Vector2(1, 2)), TEAR)
		draw_rect(Rect2(p + Vector2(22, 14), Vector2(1, 2)), TEAR)
