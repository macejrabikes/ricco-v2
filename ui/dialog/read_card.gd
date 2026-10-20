class_name ReadCard
extends CanvasLayer
## Čítanie dokumentu (účtovná kniha, list…): hra sa zastaví, obrazovka stmavne a obrázok je v strede.
## Zavrie sa klávesom použiť (F), ESC, Enterom alebo kliknutím – potom hra beží ďalej.
## Použitie:  await ReadCard.open(self, LEDGER_BIG).closed
## Godot docs: tutorials/scripting/pausing_games, classes/class_canvaslayer

signal closed

const FONT := preload("res://ui/fonts/tiny5.ttf")
const MIN_TIME := 0.35   ## s – tak skoro sa nedá zavrieť (aby to hráč omylom hneď neodklikol)

var _root: Control
var _dim: ColorRect
var _t: float = 0.0
var _closing: bool = false


static func open(parent: Node, tex: Texture2D) -> ReadCard:
	var c := ReadCard.new()
	c._build(tex)
	parent.add_child(c)
	return c


func _build(tex: Texture2D) -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.04, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var img := TextureRect.new()
	img.texture = tex
	img.position = (Vector2(640, 360) - tex.get_size()) / 2.0 - Vector2(0, 8)
	img.position = img.position.round()
	_root.add_child(img)
	var hint := Label.new()
	hint.text = "%s / ESC  -  CLOSE" % KeyBindings.short(&"takedown")
	hint.add_theme_font_override(&"font", FONT)
	hint.add_theme_font_size_override(&"font_size", 8)
	hint.add_theme_color_override(&"font_color", Color8(245, 235, 209))
	hint.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	hint.add_theme_constant_override(&"outline_size", 4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(640, 10)
	hint.position = Vector2(0, img.position.y + tex.get_height() + 8)
	_root.add_child(hint)


func _ready() -> void:
	get_tree().paused = true
	Sfx.ui(&"ui_select")
	_root.modulate.a = 0.0
	_root.position.y = 10.0
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.6, 0.2)
	tw.tween_property(_root, "modulate:a", 1.0, 0.2)
	tw.tween_property(_root, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta


func _input(event: InputEvent) -> void:
	if _closing:
		get_viewport().set_input_as_handled()
		return
	var press: bool = event.is_action_pressed(&"takedown") or event.is_action_pressed(&"pause") \
			or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"shoot")
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()   # nič iné (pauza, streľba) to nedostane
	if press and _t >= MIN_TIME:
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.ui(&"ui_back")
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.0, 0.15)
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(func():
		get_tree().paused = false
		closed.emit()
		queue_free())
