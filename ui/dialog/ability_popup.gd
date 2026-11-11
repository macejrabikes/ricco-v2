class_name AbilityPopup
extends CanvasLayer
## Okno „nová schopnosť“: keď Ricco prvý raz dostane schopnosť (spomalenie, akimbo…), hra sa zastaví a v strede
## vyskočí karta – štítok NEW ABILITY, ikonka, názov, krátky popis, malá ukážka v slučke a ako sa to ovláda (klávesy berie z KeyBindings,
## takže sedia aj po prestavení). Každá schopnosť sa ukáže len raz (Progress.tips v user://progress.cfg),
## po smrti / checkpointe sa už neopakuje. Zavrie sa klávesom použiť (F), ESC, Enterom alebo kliknutím.
##
## Použitie:
##     var tip := AbilityPopup.unlock(self, &"focus")   # null = už ju videl
##     if tip:
##         await tip.closed
## Nová schopnosť = nový záznam v ABILITIES.
## Godot docs: tutorials/scripting/pausing_games, classes/class_canvaslayer

signal closed

const FONT := preload("res://ui/fonts/tiny5.ttf")
const GHOST_ICON := preload("res://characters/don/portrait_ghost.png")
const CREAM := Color8(245, 235, 209)
const BRASS := Color8(199, 153, 71)
const GHOST := Color8(150, 230, 245)       ## Donove dary majú modrý rám (ako jeho ruka a dialóg)
const KEY_BG := Color8(46, 42, 36)
const KEY_EDGE := Color8(20, 18, 16)
const WIDTH := 300.0
const MIN_TIME := 0.6   ## s – tak skoro sa nedá zavrieť (klik z dialógu ju hneď neodklikne)

## id → title, text (popis), icon, color, demo (malá ukážka v slučke – ui/dialog/ability_demo.gd), rows = [[akcie], "čo robí"] (prázdne akcie = len poznámka)
const ABILITIES := {
	&"focus": {
		"tag": "NEW ABILITY",
		"title": "SLOW-MO",
		"text": "The Don's ghost slows the world around you. Bullets crawl - you don't.",
		"icon": GHOST_ICON,
		"color": GHOST,
		"demo": true,
		"rows": [
			[[&"focus"], "slow-mo on / off"],
			[[], "drains the blue meter - it refills on its own"],
		],
	},
	&"akimbo": {
		"tag": "NEW ABILITY",
		"title": "AKIMBO",
		"text": "The ghost takes a second pistol in his other hand. One for each pistol.",
		"icon": GHOST_ICON,
		"color": GHOST,
		"demo": true,
		"rows": [
			[[&"fire_mode"], "one pistol / two pistols"],
			[[&"shoot"], "fire both, one after the other"],
			[[&"weapon_1"], "works only with the sidearm"],
		],
	},
}

var _id: StringName
var _info: Dictionary
var _dim: ColorRect
var _root: Control
var _card: PanelContainer
var _tag: PanelContainer
var _title: Label
var _hint: Label
var _t: float = 0.0
var _closing: bool = false


## Ukáže okno pre schopnosť id, ak ho hráč ešte nevidel. Vráti okno (čakaj na closed) alebo null.
static func unlock(parent: Node, id: StringName) -> AbilityPopup:
	if not ABILITIES.has(id) or Progress.tip_seen(id):
		return null
	Progress.mark_tip(id)
	var p := AbilityPopup.new()
	p._id = id
	p._info = ABILITIES[id]
	parent.add_child(p)
	return p


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var col: Color = _info.get("color", BRASS)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.04, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# karta: tmavý panel s farebným rámom
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.94)
	sb.border_color = col
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 12
	sb.content_margin_bottom = 8
	sb.anti_aliasing = false
	_card.add_theme_stylebox_override(&"panel", sb)
	_card.custom_minimum_size.x = WIDTH
	_root.add_child(_card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	_card.add_child(box)

	# hore: ikonka v ráme + názov a popis
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 8)
	box.add_child(top)
	var icon_frame := PanelContainer.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.1, 0.1, 0.13)
	isb.border_color = col.darkened(0.35)
	isb.set_border_width_all(1)
	isb.set_content_margin_all(1)
	icon_frame.add_theme_stylebox_override(&"panel", isb)
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.texture = _info.get("icon")
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.custom_minimum_size = Vector2(48, 48)
	icon_frame.add_child(icon)

	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right)
	_title = _label(_info.get("title", ""), 16, CREAM)
	right.add_child(_title)
	var desc := _label(_info.get("text", ""), 8, CREAM.darkened(0.12))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = WIDTH - 16 - 50 - 8
	right.add_child(desc)

	# malá ukážka v slučke (ako GIF) – ui/dialog/ability_demo.gd
	if _info.get("demo", false):
		var center := CenterContainer.new()
		box.add_child(center)
		var demo_frame := PanelContainer.new()
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color(0, 0, 0)
		dsb.border_color = col.darkened(0.35)
		dsb.set_border_width_all(1)
		dsb.set_content_margin_all(1)
		demo_frame.add_theme_stylebox_override(&"panel", dsb)
		center.add_child(demo_frame)
		demo_frame.add_child(AbilityDemo.create(_id))

	# čiara a ovládanie
	var line := ColorRect.new()
	line.color = col.darkened(0.55)
	line.custom_minimum_size = Vector2(0, 1)
	box.add_child(line)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 3)
	box.add_child(grid)
	for row in _info.get("rows", []):
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override(&"separation", 2)
		keys.alignment = BoxContainer.ALIGNMENT_END
		for a in row[0]:
			keys.add_child(_keycap(KeyBindings.short(a)))
		if row[0].is_empty():
			keys.add_child(_label("-", 8, col))
		grid.add_child(keys)
		var t := _label(row[1], 8, CREAM)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(t)

	# štítok na hornom okraji (ako meno v dialógu)
	_tag = PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = col
	tsb.content_margin_left = 4
	tsb.content_margin_right = 4
	tsb.content_margin_top = 0
	tsb.content_margin_bottom = 1
	_tag.add_theme_stylebox_override(&"panel", tsb)
	_tag.add_child(_label(_info.get("tag", "NEW ABILITY"), 8, Color8(14, 10, 12), false))
	_root.add_child(_tag)

	_hint = _label("%s / ESC  -  GOT IT" % KeyBindings.short(&"takedown"), 8, CREAM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	_root.add_child(_hint)

	get_tree().paused = true
	Sfx.ui(&"ui_select")
	_root.modulate.a = 0.0
	_layout.call_deferred()


## Rozmiestni kartu do stredu (až keď kontajnery poznajú svoju veľkosť) a spustí príchod
func _layout() -> void:
	var vp: Vector2 = Vector2(640, 360)
	_card.size = _card.get_combined_minimum_size()
	_card.position = ((vp - _card.size) / 2.0 - Vector2(0, 10)).round()
	_tag.size = _tag.get_combined_minimum_size()
	_tag.position = Vector2(_card.position.x + 8, _card.position.y - floorf(_tag.size.y / 2.0))
	_hint.size = Vector2(vp.x, 10)
	_hint.position = Vector2(0, _card.position.y + _card.size.y + 8)
	_root.position.y = 12.0
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.65, 0.2)
	tw.tween_property(_root, "modulate:a", 1.0, 0.2)
	tw.tween_property(_root, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	# názov jemne žiari, nápoveda naskočí až keď sa dá zavrieť a potom pomaly bliká
	if _title:
		_title.modulate = Color(1, 1, 1).lerp(Color(1.35, 1.3, 1.15), 0.5 + 0.5 * sin(_t * 3.0))
	if _hint and _t >= MIN_TIME:
		_hint.modulate.a = 0.55 + 0.45 * sin((_t - MIN_TIME) * 4.0 + PI / 2.0)


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


func _label(text: String, size: int, color: Color, outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	if outline:
		l.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
		l.add_theme_constant_override(&"outline_size", 2 if size <= 8 else 4)
	return l


## Retro klávesa (rovnaká ako v ui/controls_help.gd)
func _keycap(text: String) -> Label:
	var l := _label(text, 8, CREAM, false)
	var sb := StyleBoxFlat.new()
	sb.bg_color = KEY_BG
	sb.border_color = KEY_EDGE
	sb.border_width_bottom = 2
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	l.add_theme_stylebox_override(&"normal", sb)
	return l
