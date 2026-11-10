extends PanelContainer
## Zoznam ovládania vľavo dole. F1 ho skryje/ukáže (aj pause menu → Settings → Controls hint).
## Klávesy sú „tlačidlá“ (Label so StyleBoxFlat), písmo Tiny5 z ui/theme/hud_theme.tres.

## [akcie (ich hlavné klávesy) alebo pevné klávesy, popis] – klávesy akcií berie z KeyBindings (dajú sa prestaviť)
const ROWS := [
	[[&"move_left", &"move_right"], "pohyb  (aj šípky)"],
	[[&"jump"], "skok, odraz, vyliezť"],
	[[&"shoot"], "streľba"],
	[[&"throw_hat"], "hod klobúka"],
	[[&"reload"], "prebiť"],
	[[&"holster"], "schovať / vytiahnuť zbraň"],
	[[&"eat"], "zjesť jedlo zo zásoby (vylieči)"],
	[[&"weapon_1", &"weapon_2", &"weapon_3"], "bočná / hlavné zbrane  (aj koliesko)"],
	[[&"weapon_last"], "posledná zbraň"],
	[[&"fire_mode"], "režim streľby (AUTO/SEMI, 1 alebo 2 hlavne, akimbo)"],
	[[&"focus"], "spomalenie – duch Dona"],
	[[&"slide"], "šmyk po bruchu"],
	[[&"sneak"], "zakrádanie (drž), pri debne = kryt"],
	[[&"takedown"], "použiť, zneškodniť zozadu, vymeniť zbraň"],
	[[&"pause"], "pauza"],
	[["F2"], "štýl HUD"],
	[["K", "H"], "TEST: zásah / vyliečiť"],
	[["F1"], "skryť ovládanie  (aj v nastaveniach)"],
]

const BG := Color(0.04, 0.04, 0.06, 0.72)
const BRASS := Color8(199, 153, 71)
const CREAM := Color8(245, 235, 209)
const KEY_BG := Color8(46, 42, 36)
const KEY_EDGE := Color8(20, 18, 16)


func _ready() -> void:
	GameSettings.ensure_loaded()
	visible = GameSettings.show_controls
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

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override(&"h_separation", 5)
	_grid.add_theme_constant_override(&"v_separation", 1)
	box.add_child(_grid)
	add_to_group(&"controls_help")
	refresh()
	_place.call_deferred()
	get_viewport().size_changed.connect(_place)


var _grid: GridContainer

## Zoznam podľa aktuálnych kláves a nastavenia zakrádania (drž / prepínaj) – volá ho aj menu po zmene (ui/pause_menu/menu_pages.gd)
func refresh() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for row in ROWS:
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override(&"separation", 2)
		for k in row[0]:
			keys.add_child(_keycap(_cap_text(k)))
		_grid.add_child(keys)
		var desc := Label.new()
		desc.text = row[1]
		if row[1].begins_with("zakrádanie"):
			desc.text = ("zakrádanie (zapnúť / vypnúť)" if GameSettings.sneak_toggle else "zakrádanie (drž)") + ", pri debne = kryt"
		desc.add_theme_color_override(&"font_color", CREAM)
		desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_grid.add_child(desc)
	_place.call_deferred()


## Text na klávese: akcia → jej hlavný kláves (myš a medzerník po slovensky), inak pevný text
func _cap_text(k) -> String:
	if k is String:
		return k
	var c: Array = KeyBindings.codes(k)
	if c.is_empty():
		return "?"
	match int(c[0]):
		-MOUSE_BUTTON_LEFT: return "ĽAVÉ TL."
		-MOUSE_BUTTON_RIGHT: return "PRAVÉ TL."
		-MOUSE_BUTTON_MIDDLE: return "STRED. TL."
		KEY_SPACE: return "MEDZERNÍK"
	return KeyBindings.name_of(c[0])


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
		GameSettings.show_controls = visible
		GameSettings.save()
		get_viewport().set_input_as_handled()
