class_name ThoughtBox
extends CanvasLayer
## Riccova samomluva (myšlienky) – menšia sestra DialogBox: malý tmavý panel vľavo hore s výrezom portrétu,
## tenký sivomodrý rám (nie mosadzný ako rozhovor), menšie písmo. Vypisuje sa ako na stroji a sám pokračuje,
## takže sa netreba preklikávať a hra beží ďalej (Ricco sa môže hýbať). Tab (DialogBox.SKIP_KEY) myšlienku hneď zavrie.
##
## Použitie:
##     ThoughtBox.think(self, ["Line one.", "Line two."])            # nečaká
##     await ThoughtBox.think(self, lines).finished                   # počká na koniec

signal finished

const FRAME := Color8(120, 128, 150)
const TEXT := Color8(214, 210, 200)
const NAME := Color8(150, 158, 182)
const CHARS_PER_SEC := 45.0
const READ_BASE := 1.3          ## s – po dopísaní riadku ostane aspoň toľko…
const READ_PER_CHAR := 0.045    ## …plus toľko za každý znak
const WIDTH := 300.0
const POS := Vector2(12, 12)
const FONT := preload("res://ui/fonts/tiny5.ttf")
const PORTRAIT := preload("res://characters/don/portrait_ricco.png")

static var _current: ThoughtBox   ## naraz len jedna – nová myšlienka nahradí starú

var _lines: Array[String] = []
var _panel: Panel
var _text: Label
var _shown: float = 0.0
var _hold: float = 0.0
var _closing: bool = false


## Ukáže myšlienky jednu po druhej a sama zmizne
static func think(parent: Node, lines: Array[String]) -> ThoughtBox:
	if is_instance_valid(_current):
		_current.queue_free()
	var box := ThoughtBox.new()
	box._lines = lines.duplicate()
	parent.add_child(box)
	_current = box
	return box


func _ready() -> void:
	layer = 34
	_panel = Panel.new()
	_panel.position = POS
	_panel.size = Vector2(WIDTH, 40)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.82)
	sb.border_color = FRAME
	sb.set_border_width_all(1)
	sb.anti_aliasing = false
	_panel.add_theme_stylebox_override(&"panel", sb)
	add_child(_panel)
	# výrez tváre z portrétu (48×48 → 32×32, bez zmenšovania pixelov)
	var face := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = PORTRAIT
	at.region = Rect2(8, 10, 32, 32)
	face.texture = at
	face.position = Vector2(4, 4)
	face.size = Vector2(32, 32)
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.modulate = Color(0.85, 0.87, 0.95)   # trochu do modra – „v hlave“
	_panel.add_child(face)
	var who := _label(NAME)
	who.text = "RICCO  (THINKING)"
	who.position = Vector2(42, 3)
	_panel.add_child(who)
	_text = _label(TEXT)
	_text.position = Vector2(42, 14)
	_text.size = Vector2(WIDTH - 48, 24)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_text)
	_panel.modulate.a = 0.0
	_panel.position.x = POS.x - 8.0
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "position:x", POS.x, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_next()


func _label(col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", 8)
	l.add_theme_color_override(&"font_color", col)
	return l


func _next() -> void:
	if _lines.is_empty():
		_close()
		return
	var line: String = _lines.pop_front()
	_text.text = line
	_text.visible_characters = 0
	_shown = 0.0
	_hold = READ_BASE + line.length() * READ_PER_CHAR


func _process(delta: float) -> void:
	if get_tree().paused or _hold <= 0.0:
		return
	var real: float = delta / Engine.time_scale if Engine.time_scale > 0.0 else delta   # spomalenie ho nespomalí
	if _text.visible_characters >= 0:
		_shown += CHARS_PER_SEC * real
		_text.visible_characters = int(_shown)
		if _text.visible_characters >= _text.get_total_character_count():
			_text.visible_characters = -1
		return
	_hold -= real
	if _hold <= 0.0:
		_next()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == DialogBox.SKIP_KEY and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_lines.clear()
		_hold = 0.0
		_close()


func _close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		finished.emit()
		queue_free())
