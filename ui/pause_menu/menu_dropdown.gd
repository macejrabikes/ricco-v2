class_name MenuDropdown
extends PanelContainer
## Rolovacie menu pre nastavenie s viacerými možnosťami (napr. CROSSHAIR). Otvorí sa pod položkou,
## šípkami hore/dole sa vyberá, Enter / klik potvrdí, ESC alebo klik mimo zavrie.

signal picked(index: int)

var item: MenuItem
var _rows: Array[MenuItem] = []


static func open(for_item: MenuItem, choices: PackedStringArray, current: int) -> MenuDropdown:
	var dd := MenuDropdown.new()
	dd.item = for_item
	dd.top_level = true
	dd.z_index = 50
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.055, 0.96)
	sb.border_color = MenuItem.BRASS
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	sb.anti_aliasing = false
	dd.add_theme_stylebox_override(&"panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	dd.add_child(box)
	for i in choices.size():
		var row := MenuItem.new(choices[i])
		row.font_size = maxi(8, for_item.font_size - 4)
		row.custom_minimum_size = Vector2(0, row.font_size + 4)
		row.pressed.connect(func(): dd._pick(i))
		if for_item.on_hover.is_valid():
			row.focus_entered.connect(func(): for_item.on_hover.call(i))
		box.add_child(row)
		dd._rows.append(row)
	for_item.add_child(dd)
	dd._place.call_deferred()
	dd._rows[clampi(current, 0, choices.size() - 1)].grab_focus.call_deferred()
	return dd


func _place() -> void:
	var r: Rect2 = item.get_global_rect()
	var w: float = 0.0
	for row in _rows:
		var f: Font = row.get_theme_default_font()
		w = maxf(w, f.get_string_size(row.label, HORIZONTAL_ALIGNMENT_LEFT, -1, row.font_size).x)
	var row_h: float = _rows[0].font_size + 4.0
	size = Vector2(w + 30.0, row_h * _rows.size() + 6.0)
	global_position = Vector2(r.end.x - size.x, r.end.y + 1.0)
	var vp: Vector2 = get_viewport_rect().size
	if global_position.y + size.y > vp.y - 4.0:   # nezmestí sa dole → otvorí sa nad položkou
		global_position.y = r.position.y - size.y - 1.0


func _pick(i: int) -> void:
	picked.emit(i)
	_close()


func _close() -> void:
	if is_instance_valid(item):
		item.grab_focus()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_close()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and not get_global_rect().has_point(mb.position):
		get_viewport().set_input_as_handled()
		_close()
