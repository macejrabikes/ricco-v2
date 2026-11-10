class_name DialogBox
extends CanvasLayer
## Dialógové okno (štýl D1): tmavý panel s mosadzným rámom (hore, aby nezakrýval postavy na zemi), portrét vľavo, meno v štítku nad panelom,
## text sa vypisuje ako na písacom stroji. Ďalej / dopísať: medzerník, Enter, E alebo ľavé tlačidlo myši.
## Preskočiť celý rozhovor: Tab (SKIP_KEY) – okno zmizne a ďalšie say() sa vrátia hneď, cutscéna beží ďalej bez textu.
## Duch Dona má rám, meno aj text v modrej (rovnaká farba ako jeho ruka).
##
## Použitie (v cutscéne):
##     var box := DialogBox.new()
##     add_child(box)
##     await box.say("DON VITO", portrait, "Ricciardo...")
##     box.close()

signal advanced

const CREAM := Color8(238, 226, 196)
const BRASS := Color8(201, 160, 88)
const GHOST := Color8(150, 230, 245)
const GHOST_TEXT := Color8(200, 244, 250)
const CHARS_PER_SEC := 38.0
const TOP := 18.0
const FONT := preload("res://ui/fonts/tiny5.ttf")
const SKIP_KEY := KEY_TAB

var skipping: bool = false   ## hráč rozhovor preskočil – zvyšné repliky sa už neukážu

var _panel: Panel
var _frame: StyleBoxFlat
var _portrait_frame: Panel
var _portrait: TextureRect
var _name_tag: Panel
var _name: Label
var _text: Label
var _arrow: Polygon2D
var _typing: bool = false
var _shown: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Panel.new()
	_panel.position = Vector2(40, TOP)
	_panel.size = Vector2(560, 84)
	_frame = _box(Color(0.06, 0.05, 0.055, 0.9), BRASS, 2)
	_panel.add_theme_stylebox_override(&"panel", _frame)
	add_child(_panel)
	_portrait_frame = Panel.new()
	_portrait_frame.position = Vector2(10, 14)
	_portrait_frame.size = Vector2(54, 54)
	_portrait_frame.add_theme_stylebox_override(&"panel", _box(Color8(52, 40, 36), BRASS, 1))
	_panel.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(3, 3)
	_portrait.size = Vector2(48, 48)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_frame.add_child(_portrait)
	_name_tag = Panel.new()
	_name_tag.position = Vector2(74, -9)
	_name_tag.size = Vector2(90, 14)
	_name_tag.add_theme_stylebox_override(&"panel", _box(Color(0.06, 0.05, 0.055, 1.0), BRASS, 1))
	_panel.add_child(_name_tag)
	_name = _label(8, BRASS)
	_name.position = Vector2(6, 1)
	_name_tag.add_child(_name)
	_text = _label(16, CREAM)
	_text.position = Vector2(76, 12)
	_text.size = Vector2(468, 64)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_text)
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(0, 5)])
	_arrow.color = BRASS
	_arrow.position = Vector2(544, 70)
	_panel.add_child(_arrow)
	var skip := _label(8, Color(CREAM, 0.45))
	skip.text = OS.get_keycode_string(SKIP_KEY).to_upper() + "  SKIP"
	skip.position = Vector2(560 - 8 - FONT.get_string_size(skip.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, -11)
	_panel.add_child(skip)
	_panel.modulate.a = 0.0


func _box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(w)
	b.anti_aliasing = false
	return b


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	return l


## Povie jednu repliku a počká, kým ju hráč odklikne
func say(speaker: String, portrait: Texture2D, text: String, ghost: bool = false) -> void:
	if skipping:
		return
	var col := GHOST if ghost else BRASS
	_frame.border_color = col
	(_portrait_frame.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color = col
	(_name_tag.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color = col
	_name.add_theme_color_override(&"font_color", col)
	_text.add_theme_color_override(&"font_color", GHOST_TEXT if ghost else CREAM)
	_arrow.color = col
	_name.text = speaker
	_name_tag.size.x = FONT.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 12
	_portrait.texture = portrait
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	if _panel.modulate.a < 1.0:
		var tw := create_tween().set_ignore_time_scale(true)
		_panel.position.y = TOP - 10.0
		tw.parallel().tween_property(_panel, "modulate:a", 1.0, 0.18)
		tw.parallel().tween_property(_panel, "position:y", TOP, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await advanced


func close() -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t += delta
	if _typing:
		_shown += CHARS_PER_SEC * delta
		_text.visible_characters = int(_shown)
		if _text.visible_characters >= _text.get_total_character_count():
			_text.visible_characters = -1
			_typing = false
	_arrow.visible = not _typing and fmod(_t, 0.6) < 0.4   # bliká, keď sa dá pokračovať


func _input(event: InputEvent) -> void:
	if get_tree().paused or skipping or _panel.modulate.a < 0.5:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == SKIP_KEY:
		get_viewport().set_input_as_handled()
		_skip()
		return
	var go: bool = event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"jump") \
			or event.is_action_pressed(&"throw_hat") or event.is_action_pressed(&"shoot")
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		go = true
	if not go:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_typing = false
		_text.visible_characters = -1
	else:
		advanced.emit()


## Preskočí zvyšok rozhovoru: okno zmizne, čakajúca replika aj všetky ďalšie sa hneď vrátia
func _skip() -> void:
	skipping = true
	_typing = false
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.12)
	advanced.emit()
