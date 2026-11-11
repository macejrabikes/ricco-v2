class_name InteractHint
extends PanelContainer
## Nápoveda nad vecou, ktorú Ricco môže použiť: tmavá tabuľka s mosadzným rámom, v nej kláves (ako v ovládaní
## vľavo dole) a slovo – napr. [F] OPEN. Jemne pulzuje, aby sa nestratila na tmavom ani pestrom pozadí.
## Používa InteractSpot, klopacie dvere, zbraň na zemi aj zneškodnenie nad gangstrom (ricco.gd).
##
## Použitie:
##     var hint := InteractHint.new()
##     add_child(hint)
##     hint.set_hint([KeyBindings.short(&"takedown")], "OPEN")    # verb môže byť prázdny – len kláves
##     hint.position = Vector2(-hint.size.x / 2.0, -40)

const FONT := preload("res://ui/fonts/tiny5.ttf")
const CREAM := Color8(245, 235, 209)
const BRASS := Color8(199, 153, 71)
const KEY_BG := Color8(46, 42, 36)
const KEY_EDGE := Color8(20, 18, 16)

var _row: HBoxContainer
var _keys: Array = []
var _verb: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.05, 0.88)
	sb.border_color = BRASS
	sb.set_border_width_all(1)
	sb.content_margin_left = 2
	sb.content_margin_right = 3
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.anti_aliasing = false
	add_theme_stylebox_override(&"panel", sb)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 3)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)


## keys = texty klávesov (napr. ["F"] alebo ["F", "LMB"]), verb = čo sa stane (OPEN, READ…)
func set_hint(keys: Array, verb: String = "") -> void:
	if keys == _keys and verb == _verb:
		return   # volá sa každý snímok – prestavia sa len pri zmene (napr. prestavený kláves)
	_keys = keys.duplicate()
	_verb = verb
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	for i in keys.size():
		if i > 0:
			_row.add_child(_label("/", BRASS))
		_row.add_child(_keycap(str(keys[i])))
	if verb != "":
		_row.add_child(_label(verb, CREAM))
	reset_size()


func _process(_delta: float) -> void:
	if visible:   # jemné pulzovanie jasu
		modulate = Color(1, 1, 1).lerp(Color(1.25, 1.2, 1.1), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005))


func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", 8)
	l.add_theme_color_override(&"font_color", color)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Retro klávesa (rovnaká ako v ui/controls_help.gd)
func _keycap(text: String) -> Label:
	var l := _label(text, CREAM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = KEY_BG
	sb.border_color = KEY_EDGE
	sb.border_width_bottom = 2
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	l.add_theme_stylebox_override(&"normal", sb)
	return l
