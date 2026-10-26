extends Node2D
## Záver kapitoly II – svitanie na mori. Ricco v záchrannom člne, v diaľke dohára S.S. Margaret: vybuchne a potopí sa,
## ukáže sa duch Dona Vita, posledné hlášky o „M.“ z New Yorku → END OF CHAPTER II → kapitola III (levels/level3/intro.tscn).
## Scénu generuje tools/build_margaret.gd (_build_epilogue), obrázky c9/make_escape_art.py. Bez kamery – súradnice = obrazovka.
## Godot docs: classes/class_tween, classes/class_animatedsprite2d

const FONT := preload("res://ui/fonts/tiny5.ttf")
const GLOW := preload("res://levels/level1/art/glow.png")
const CHAPTER_3 := "res://levels/level3/intro.tscn"   ## úvod kapitoly III – čln pri Soche slobody
const LoadingScreen := preload("res://ui/loading/loading_screen.gd")

var _boat: Node2D
var _ship: Sprite2D
var _ghost: Sprite2D
var _ghost_glow: Sprite2D
var _waves: Sprite2D
var _t: float = 0.0
var _frame_t: float = 0.0
var _boat_y: float
var _wave_t: float = 3.0


func _ready() -> void:
	_boat = $Boat
	_ship = $Margaret
	_ghost = $Boat/Ghost
	_waves = $Waves
	_boat_y = _boat.position.y
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
	Sfx.music(&"")
	_play()


func _process(delta: float) -> void:
	_t += delta
	# čln sa hojdá, vlnky plynú, plamene na lodi blikajú
	_boat.position.y = roundf(_boat_y + 2.0 * sin(_t * 1.6))
	_boat.rotation = 0.03 * sin(_t * 1.6 + 0.8)
	_waves.region_rect.position.x = fmod(_t * 8.0, 640.0)
	_frame_t += delta
	if _frame_t > 0.12:
		_frame_t = 0.0
		_ship.frame = (_ship.frame + 1) % 3
	_ghost.position.y = -84.0 + roundf(2.0 * sin(_t * 2.2))
	_wave_t -= delta
	if _wave_t <= 0.0:
		_wave_t = randf_range(3.0, 6.0)
		Sfx.play(&"wave_crash", Vector2.INF, -20.0, 0.15, &"Ambience")


func _play() -> void:
	var black := _fade_rect()
	black.color.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(black, "color:a", 0.0, 2.0)
	await tw.finished
	await _wait(0.8)
	var lines: Array[String] = ["Dawn. The storm finally blew itself out.", "Four hundred cases of Lou's rye, goin' to the bottom."]
	await ThoughtBox.think(self, lines).finished
	await _wait(0.6)
	await _sink_margaret()
	await _wait(1.0)
	_show_ghost()
	await _wait(1.2)
	await _ghost_says("WELL, KID. THAT'S ONE RAT\nOFF MY LIST.")
	var more: Array[String] = ["Lou was just the errand boy.", "The real boss signs his letters 'M.' And he's in New York."]
	await ThoughtBox.think(self, more).finished
	await _wait(0.4)
	await _ghost_says("THEN WE'RE GOIN' TO NEW YORK.\nROW, KID. ROW.")
	await _wait(1.0)
	await _titles(black)


## Margaret v diaľke vybuchne (záblesk, ohnivá guľa, dym) a pomaly zmizne pod hladinou
func _sink_margaret() -> void:
	var at: Vector2 = _ship.position + Vector2(110, 26)
	Explosion.spawn(self, at, 0.7, 0, 0.0, 10.0)
	await _wait(0.25)
	Explosion.spawn(self, at + Vector2(-60, 6), 0.5, 0, 0.0, 10.0, false)
	Sfx.music(&"rainy_noir", 4.0)
	var smoke := CPUParticles2D.new()
	smoke.amount = 30
	smoke.lifetime = 6.0
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(40, 4)
	smoke.direction = Vector2(0.3, -1)
	smoke.spread = 12.0
	smoke.gravity = Vector2(4, -4)
	smoke.initial_velocity_min = 8.0
	smoke.initial_velocity_max = 16.0
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 6.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.25, 0.2, 0.24, 0.8))
	ramp.set_color(1, Color(0.4, 0.3, 0.36, 0.0))
	smoke.color_ramp = ramp
	smoke.z_index = -4
	add_child(smoke)
	smoke.position = _ship.position + Vector2(90, 30)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_ship, "position:y", _ship.position.y + 60.0, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_ship, "rotation", -0.18, 7.0)
	tw.tween_property(smoke, "position:y", smoke.position.y + 20.0, 7.0)
	await _wait(4.5)
	smoke.emitting = false


func _show_ghost() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_ghost, "modulate:a", 0.85, 1.0)
	tw.tween_property(_ghost_glow, "modulate:a", 0.4, 1.0)


## Hláška ducha nad ním (ako bark v Level2) – počká, kým zmizne
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


## Titulky ako na konci kapitoly I, potom rovno kapitola III (úvod v New Yorku)
func _titles(black: ColorRect) -> void:
	var title := _label("END OF CHAPTER II", 24, Color8(245, 235, 209), -14)
	var sub := _label("WHARF RATS", 8, Color8(150, 230, 245), 14)
	for l in [title, sub]:
		black.add_child(l)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 1.5)
	tw.tween_property(title, "modulate:a", 1.0, 0.8)
	tw.tween_property(sub, "modulate:a", 1.0, 0.6)
	tw.tween_interval(3.0)
	tw.tween_property(title, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(sub, "modulate:a", 0.0, 0.6)
	Sfx.music(&"", 2.0)
	await tw.finished
	Level2.reset()
	Level3.reset()
	LoadingScreen.go(get_tree(), CHAPTER_3, 0.6)


func _label(t: String, size: int, col: Color, dy: float) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)   # cez celú obrazovku, text v strede
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
