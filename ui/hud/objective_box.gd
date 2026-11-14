class_name ObjectiveBox
extends Control
## Vpravo hore: aktuálny cieľ (ui/hud/objectives.gd) a pečiatka CHECKPOINT, keď sa uloží checkpoint.
## Nový cieľ prídu s nápisom NEW OBJECTIVE a krátko zasvieti; po smrti (reštart scény) sa nič neopakuje,
## lebo posledný ukázaný cieľ a checkpoint si pamätá statická premenná.
## Vypína sa v Settings → HUD → Objective (GameSettings.show_objective).

const FONT := preload("res://ui/fonts/tiny5.ttf")
const CREAM := Color8(245, 235, 209)
const BRASS := Color8(199, 153, 71)
const DARK := Color8(14, 10, 12)
const MARGIN := Vector2(8, 8)
const MAX_W := 180.0      ## px – dlhší cieľ sa zalomí, aby nezasahoval do pruhu bossa v strede hore
const CHECK_EVERY := 0.4    ## s – ako často sa pozrie na checkpoint a ciele

static var _last_text: String = ""   ## posledný ukázaný cieľ (aby sa po smrti nezobrazil ako nový)
static var _last_cp: String = ""     ## "Level2:7" – posledný ohlásený checkpoint

var _box: VBoxContainer
var _tag: Label
var _text: Label
var _stamp: Label
var _check_t: float = 0.0
var _flash: float = 0.0
var _shown_text: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 1)
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_tag = _label("NEW OBJECTIVE", BRASS)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tag.modulate.a = 0.0
	_box.add_child(_tag)
	_text = _label("", CREAM)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_box.add_child(_text)
	_stamp = _label("CHECKPOINT", BRASS)
	_stamp.add_theme_font_size_override(&"font_size", 16)
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stamp.modulate.a = 0.0
	add_child(_stamp)
	_check_t = CHECK_EVERY   # prvá kontrola hneď


func _process(delta: float) -> void:
	_check_t += delta
	if _check_t >= CHECK_EVERY:
		_check_t = 0.0
		_refresh()
	if _flash > 0.0:   # nový cieľ chvíľu svieti
		_flash = maxf(0.0, _flash - delta)
		_text.modulate = Color(1, 1, 1).lerp(Color(1.5, 1.35, 1.0), clampf(_flash, 0.0, 1.0) * (0.5 + 0.5 * sin(_flash * 18.0)))
	_place()


func _refresh() -> void:
	var scene := get_tree().current_scene
	var info: Dictionary = Objectives.current(scene)
	var player := get_tree().get_first_node_in_group(&"player")
	var hide: bool = info.is_empty() or not GameSettings.show_objective \
			or (player != null and bool(player.get(&"in_cutscene")))
	_box.visible = not hide
	if info.is_empty():
		return
	var text: String = String(info["text"]).to_upper()
	if text != _shown_text:
		_shown_text = text
		_text.text = text
		_text.reset_size()
		if text != _last_text and _last_text != "":
			_announce()
		_last_text = text
	# checkpoint: ohlási sa len zvýšenie v tej istej kapitole (nie začiatok hry, nie reštart po smrti)
	var key: String = "%s:%d" % [_chapter(scene), int(info["cp"])]
	if key != _last_cp:
		var parts: PackedStringArray = _last_cp.split(":")
		if parts.size() == 2 and parts[0] == _chapter(scene) and int(info["cp"]) > int(parts[1]):
			_checkpoint_stamp()
		_last_cp = key


func _announce() -> void:
	_flash = 1.6
	var tw := create_tween()
	_tag.modulate.a = 0.0
	tw.tween_property(_tag, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.2)
	tw.tween_property(_tag, "modulate:a", 0.0, 0.5)
	Sfx.ui(&"ui_select")


func _checkpoint_stamp() -> void:
	var tw := create_tween()
	_stamp.modulate.a = 0.0
	_stamp.scale = Vector2(1.6, 1.6)
	tw.set_parallel(true)
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.12)
	tw.tween_property(_stamp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.4)
	tw.chain().tween_property(_stamp, "modulate:a", 0.0, 0.6)


func _place() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.custom_minimum_size.x = 0.0
	if _text.get_minimum_size().x > MAX_W:
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.custom_minimum_size.x = MAX_W
	var w: float = maxf(_text.get_combined_minimum_size().x, _tag.get_combined_minimum_size().x)
	_box.size = Vector2(w, 0)
	_box.reset_size()
	_box.position = Vector2(vp.x - MARGIN.x - w, MARGIN.y).floor()
	var sw: float = _stamp.get_combined_minimum_size().x
	_stamp.size = Vector2(sw, 16)
	_stamp.pivot_offset = _stamp.size / 2.0
	_stamp.position = Vector2(vp.x - MARGIN.x - sw, _box.position.y + _box.size.y + 4).floor()


static func _chapter(scene: Node) -> String:
	if scene is Level1: return "1"
	if scene is Level2: return "2"
	if scene is Level3: return "3"
	if scene is Level4: return "4"
	return "?"


func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", 8)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", DARK)
	l.add_theme_constant_override(&"outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
