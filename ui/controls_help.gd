extends PanelContainer
## Dočasný zoznam ovládania vľavo dole (kým nebude menu). F1 ho skryje/ukáže.
## Klávesy sú „tlačidlá“ (Label so StyleBoxFlat), písmo Tiny5 z ui/theme/hud_theme.tres.

const ROWS := [
	[["A", "D"], "pohyb  (aj šípky)"],
	[["MEDZERNÍK"], "skok, odraz, vyliezť  (aj W)"],
	[["ĽAVÉ TL."], "streľba"],
	[["PRAVÉ TL.", "E"], "hod klobúka"],
	[["R"], "prebiť"],
	[["SHIFT"], "spomalenie – duch Dona"],
	[["F2"], "štýl HUD"],
	[["K", "H"], "TEST: zásah / vyliečiť"],
	[["F1"], "skryť ovládanie"],
]

const BG := Color(0.04, 0.04, 0.06, 0.72)
const BRASS := Color8(199, 153, 71)
const CREAM := Color8(245, 235, 209)
const KEY_BG := Color8(46, 42, 36)
const KEY_EDGE := Color8(20, 18, 16)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := StyleBoxFlat.new()
	panel.bg_color = BG
	panel.border_color = BRASS
	panel.set_border_width_all(1)
	panel.set_content_margin_all(4)
	add_theme_stylebox_override(&"panel", panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	add_child(box)
	var title := Label.new()
	title.text = "OVLÁDANIE"
	title.add_theme_color_override(&"font_color", BRASS)
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 5)
	grid.add_theme_constant_override(&"v_separation", 1)
	box.add_child(grid)
	for row in ROWS:
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override(&"separation", 2)
		for k: String in row[0]:
			keys.add_child(_keycap(k))
		grid.add_child(keys)
		var desc := Label.new()
		desc.text = row[1]
		desc.add_theme_color_override(&"font_color", CREAM)
		desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(desc)
	_place.call_deferred()
	get_viewport().size_changed.connect(_place)


## Retro klávesa: tmavé tlačidlo so spodnou hranou (vyzerá „vystúpene“)
func _keycap(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override(&"font_color", CREAM)
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


func _place() -> void:
	size = get_combined_minimum_size()
	position = Vector2(8, get_viewport_rect().size.y - size.y - 8).floor()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F1:
		visible = not visible
		get_viewport().set_input_as_handled()
