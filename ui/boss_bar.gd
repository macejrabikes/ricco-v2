extends CanvasLayer
## Pás zdravia bossa hore v strede obrazovky (meno + červený prúžok v štýle plagátu WANTED z HUD).
## Po zásahu prúžok hneď klesne a svetlý „odštiepok“ za ním dobehne o chvíľu neskôr.
## Značky (notches) delia pás na fázy boja – Big Lou má tri (characters/lou/big_lou.gd).
## Použitie: var bar := BossBar.new(); add_child(bar); bar.track("BIG LOU", lou) – boss musí mať signály
## health_changed(health, max_health) a died. Godot docs: classes/class_canvaslayer, classes/class_control (_draw)

const FONT := preload("res://ui/fonts/tiny5.ttf")
const WIDTH := 168.0
const BAR_H := 4.0
const TOP := 10.0

const FRAME := Color8(120, 92, 56)
const BACK := Color8(40, 26, 20)
const FILL := Color8(176, 32, 30)
const FILL_HI := Color8(220, 70, 60)
const CHIP := Color8(250, 240, 214)
const NAME := Color8(245, 235, 209)

var _root: Control
var _label: Label
var _value: float = 1.0      ## 0–1 skutočné zdravie
var _chip: float = 1.0       ## 0–1 odštiepok (dobieha)
var _chip_wait: float = 0.0
var _flash: float = 0.0
var notches: Array[float] = []   ## 0–1 hranice fáz (napr. [1/3, 2/3])


func _ready() -> void:
	layer = 11
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.modulate.a = 0.0
	_root.draw.connect(_draw_bar)
	add_child(_root)
	_label = Label.new()
	_label.add_theme_font_override(&"font", FONT)
	_label.add_theme_font_size_override(&"font_size", 8)
	_label.add_theme_color_override(&"font_color", NAME)
	_label.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	_label.add_theme_constant_override(&"outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_label)


## Ukáže pás a sleduje zdravie bossa
func track(boss_name: String, boss: Node) -> void:
	_label.text = boss_name
	_value = 1.0
	_chip = 1.0
	boss.health_changed.connect(_on_health)
	boss.died.connect(hide_bar)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.5)


func hide_bar() -> void:
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(_root, "modulate:a", 0.0, 0.8)


func _on_health(health: float, max_health: float) -> void:
	_value = clampf(health / maxf(max_health, 0.001), 0.0, 1.0)
	_chip_wait = 0.45
	_flash = 1.0


func _process(delta: float) -> void:
	_chip_wait -= delta
	if _chip_wait <= 0.0 and _chip > _value:
		_chip = maxf(_chip - delta * 0.6, _value)
	_flash = maxf(_flash - delta * 6.0, 0.0)
	var vp: Vector2 = _root.get_viewport_rect().size
	_label.position = Vector2(0, TOP - 1.0)
	_label.size = Vector2(vp.x, 10)
	_root.queue_redraw()


func _draw_bar() -> void:
	var vp: Vector2 = _root.get_viewport_rect().size
	var r := Rect2(floorf((vp.x - WIDTH) / 2.0), TOP + 11.0, WIDTH, BAR_H)
	_root.draw_rect(r.grow(2.0), Color8(14, 10, 12))
	_root.draw_rect(r.grow(1.0), FRAME)
	_root.draw_rect(r, BACK)
	_root.draw_rect(Rect2(r.position, Vector2(ceilf(r.size.x * _chip), r.size.y)), CHIP)
	var fill: Color = FILL.lerp(Color.WHITE, _flash * 0.6)
	_root.draw_rect(Rect2(r.position, Vector2(ceilf(r.size.x * _value), r.size.y)), fill)
	_root.draw_rect(Rect2(r.position, Vector2(ceilf(r.size.x * _value), 1.0)), FILL_HI.lerp(Color.WHITE, _flash * 0.6))
	for n in notches:
		var x: float = r.position.x + roundf(r.size.x * n)
		_root.draw_rect(Rect2(x, r.position.y - 2.0, 1.0, r.size.y + 4.0), Color8(14, 10, 12))
		_root.draw_rect(Rect2(x - 1.0, r.position.y - 3.0, 3.0, 1.0), FRAME)
