class_name MenuPages
extends RefCounted
## Spoločné stránky menu (štýl „minimal“, vpravo, po anglicky) pre pause menu aj úvodné menu:
## nadpis, položky, nastavenia, zoznam ovládania. Stavia ich do VBoxContainera (column).

const CREAM := MenuItem.CREAM
const BRASS := MenuItem.BRASS
const HINT := Color8(120, 112, 96)

var column: VBoxContainer
var on_apply: Callable      ## zavolá sa po každej zmene nastavení (uloženie, celá obrazovka…)
var item_size: int = 8      ## veľkosť písma položiek (úvodné menu 16)
var title_size: int = 16
var preview: SettingsPreview   ## náhľad vedľa nastavení (zameriavač, plagát, retro filter)
var esc_back: Callable         ## kam sa vráti ESC z práve otvorenej stránky (nastaví ju každá stránka)


func _init(column_: VBoxContainer, on_apply_: Callable) -> void:
	column = column_
	on_apply = on_apply_


func clear() -> void:
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null
	for c in column.get_children():
		column.remove_child(c)
		c.queue_free()


func focus(it: MenuItem) -> void:
	if it:
		it.grab_focus.call_deferred()


func title(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_font_size_override(&"font_size", title_size)
	l.add_theme_color_override(&"font_color", CREAM)
	column.add_child(l)
	var line := ColorRect.new()   # zlatá čiara pod nadpisom
	line.color = BRASS
	line.custom_minimum_size = Vector2(64.0 * title_size / 16.0, 1 if title_size <= 16 else 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(line)
	spacer(6)


func item(t: String, action: Callable) -> MenuItem:
	var it := MenuItem.new(t)
	it.font_size = item_size
	it.pressed.connect(action)
	column.add_child(it)
	return it



## Položka s malým podnadpisom pod textom (výber kapitoly: CHAPTER I / THE DON'S GHOST)
func item_sub(t: String, sub: String, action: Callable) -> MenuItem:
	var it := MenuItem.new(t)
	it.font_size = item_size
	it.subtitle = sub
	it.pressed.connect(action)
	column.add_child(it)
	return it


func setting(t: String, v: String, on_change: Callable) -> MenuItem:
	var it := MenuItem.new(t, v)
	it.font_size = item_size
	if t == "RETRO FILTER":
		it.focus_entered.connect(func(): _preview(t, 1 if GameSettings.retro_filter else 0))
		it.changed.connect(func(_d: int): _preview(t, 1 if GameSettings.retro_filter else 0), CONNECT_DEFERRED)
	else:
		it.focus_entered.connect(func(): _preview("", 0))
	it.changed.connect(func(d: int):
		on_change.call(d, it)
		GameSettings.apply_display(column.get_tree().root)
		GameSettings.save()
		if on_apply.is_valid():
			on_apply.call())
	column.add_child(it)
	return it


## Nastavenie s rolovacím menu (viac možností). on_pick(index) nastaví hodnotu.
func choice(t: String, opts: PackedStringArray, current: int, on_pick: Callable) -> MenuItem:
	var it := MenuItem.new(t, opts[current])
	it.choices = opts
	it.font_size = item_size
	if t in PREVIEWS:
		it.on_hover = func(i: int): _preview(t, i)
		it.focus_entered.connect(func(): _preview(t, maxi(0, opts.find(it.value))))
	else:
		it.focus_entered.connect(func(): _preview("", 0))
	it.changed.connect(func(d: int):
		var i: int = posmod(opts.find(it.value) + d, opts.size())
		on_pick.call(i)
		it.set_value(opts[i])
		if t in PREVIEWS:
			_preview(t, i)
		GameSettings.apply_display(column.get_tree().root)
		GameSettings.save()
		if on_apply.is_valid():
			on_apply.call())
	column.add_child(it)
	return it


func spacer(h: float = 4.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	column.add_child(c)


func hint(t: String) -> void:
	spacer(10)
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override(&"font_color", HINT)
	column.add_child(l)


const PREVIEWS := ["CROSSHAIR", "CROSSHAIR SIZE", "WANTED POSTER"]


## Náhľad vedľa stĺpca menu (vľavo od neho, zvislo v strede)
func _preview(key: String, index: int) -> void:
	if not is_instance_valid(preview):
		return
	preview.show_for(key, index)
	var r: Rect2 = column.get_global_rect()
	preview.global_position = Vector2(r.position.x - preview.size.x - 70.0, r.get_center().y - preview.size.y / 2.0).round()


## Stránka nastavení = zoznam kategórií (obraz, HUD a mierenie, zvuk, ovládanie).
## back = kam sa vráti BACK / ESC, audio = otvorí stránku zvuku.
func settings_page(back: Callable, audio: Callable = Callable()) -> MenuItem:
	clear()
	esc_back = back
	title("SETTINGS")
	var reopen := func(): settings_page(back, audio)
	var first := item("DISPLAY", func(): display_page(reopen))
	item("HUD & AIM", func(): hud_page(reopen))
	if audio.is_valid():
		item("AUDIO", audio)
	item("CONTROLS", func(): controls_page(reopen))
	spacer()
	item("BACK", back)
	hint("ENTER  SELECT     ESC  BACK")
	focus(first)
	return first


## Kategória OBRAZ: celá obrazovka, škálovanie, retro filter
func display_page(back: Callable) -> MenuItem:
	clear()
	esc_back = back
	preview = SettingsPreview.new()
	column.get_parent().add_child(preview)
	title("DISPLAY")
	var full := setting("FULLSCREEN", _full_name(), func(_d: int, it: MenuItem):
		GameSettings.fullscreen = not GameSettings.fullscreen
		it.set_value(_full_name()))
	choice("SCALING", PackedStringArray(["PIXEL PERFECT", "FILL SCREEN"]), 0 if GameSettings.pixel_perfect else 1, func(i: int):
		GameSettings.pixel_perfect = i == 0)
	setting("RETRO FILTER", _on_off(GameSettings.retro_filter), func(_d: int, it: MenuItem):
		GameSettings.retro_filter = not GameSettings.retro_filter
		it.set_value(_on_off(GameSettings.retro_filter)))
	spacer()
	item("BACK", back)
	hint("LEFT / RIGHT  CHANGE     ENTER  LIST     ESC  BACK")
	focus(full)
	return full


## Kategória HUD A MIERENIE: štýl HUD, plagát, zameriavač, zoznam ovládania
func hud_page(back: Callable) -> MenuItem:
	clear()
	esc_back = back
	preview = SettingsPreview.new()
	column.get_parent().add_child(preview)
	title("HUD & AIM")
	var first := choice("HUD STYLE", PackedStringArray(["NOIR", "MINIMAL"]), GameSettings.hud_style, func(i: int):
		GameSettings.hud_style = i as GameSettings.HudStyle)
	var posters := PackedStringArray()
	for v in GameSettings.PORTRAIT_SCALES:
		posters.append("%sx" % str(v).trim_suffix(".0"))
	choice("WANTED POSTER", posters, maxi(0, GameSettings.PORTRAIT_SCALES.find(GameSettings.portrait_scale)), func(i: int):
		GameSettings.portrait_scale = GameSettings.PORTRAIT_SCALES[i])
	choice("CROSSHAIR", PackedStringArray(GameSettings.CROSSHAIRS), GameSettings.crosshair, func(i: int):
		GameSettings.crosshair = i)
	choice("CROSSHAIR SIZE", PackedStringArray(GameSettings.CROSSHAIR_SIZES), GameSettings.crosshair_size, func(i: int):
		GameSettings.crosshair_size = i)
	setting("CONTROLS HINT", _on_off(GameSettings.show_controls), func(_d: int, it: MenuItem):
		GameSettings.show_controls = not GameSettings.show_controls
		it.set_value(_on_off(GameSettings.show_controls)))
	spacer()
	item("BACK", back)
	hint("LEFT / RIGHT  CHANGE     ENTER  LIST     ESC  BACK")
	focus(first)
	return first


const VOLUMES := [["MASTER", "Master"], ["MUSIC", "Music"], ["EFFECTS", "SFX"], ["AMBIENCE", "Ambience"], ["MENU", "UI"]]
## Skúšobný zvuk pri zmene hlasitosti danej zbernice
const VOLUME_TEST := {"Master": &"ui_select", "Music": &"ui_select", "SFX": &"pistol_a", "Ambience": &"drip", "UI": &"ui_move"}


## Stránka zvuku: hlasitosť zberníc 0–10 ako posuvníky (audio/sfx.gd, GameSettings.volumes).
## Šípky (aj podržané) alebo myš – klik / ťahanie po dráhe. Pri zmene zaznie skúšobný zvuk danej zbernice.
func audio_page(back: Callable) -> MenuItem:
	clear()
	esc_back = back
	title("AUDIO")
	var first: MenuItem = null
	for row in VOLUMES:
		var key: String = row[1]
		var it := MenuItem.new(row[0])
		it.steps = 10
		it.level = GameSettings.volume(key)
		it.font_size = item_size
		it.changed.connect(func(d: int):
			GameSettings.volumes[key] = clampi(GameSettings.volume(key) + d, 0, 10)
			it.set_level(GameSettings.volumes[key])
			Sfx.apply_volumes()
			GameSettings.save()
			if key != "UI" and key != "Music":   # hudba hrá stále, netreba skúšobný zvuk; UI pípne samo (menu_item.gd)
				Sfx.play(VOLUME_TEST[key], Vector2.INF, -4.0, 0.0, &"UI" if key == "Master" else StringName(key)))
		column.add_child(it)
		if first == null:
			first = it
	spacer()
	item("BACK", back)
	hint("LEFT / RIGHT  VOLUME     ESC  BACK")
	focus(first)
	return first


## Kategória OVLÁDANIE: zakrádanie HOLD (drž C) / TOGGLE (C zapne / vypne) a stránka KEYBOARD s klávesmi
func controls_page(back: Callable) -> MenuItem:
	clear()
	esc_back = back
	title("CONTROLS")
	var reopen := func(): controls_page(back)
	var first := choice("SNEAK", PackedStringArray(["HOLD", "TOGGLE"]), 1 if GameSettings.sneak_toggle else 0, func(i: int):
		GameSettings.sneak_toggle = i == 1
		_refresh_key_hints())
	item("KEYBOARD", func(): keyboard_page(reopen))
	spacer()
	item("BACK", back)
	hint("ENTER  SELECT     ESC  BACK")
	focus(first)
	return first


## Stránka KEYBOARD: všetky akcie s klávesmi (settings/key_bindings.gd). Enter / klik → „PRESS A KEY“ →
## stlačený kláves (aj tlačidlo myši) sa stane hlavným klávesom akcie; ESC zruší. Zoznam sa roluje (ScrollContainer).
func keyboard_page(back: Callable) -> MenuItem:
	clear()
	esc_back = back
	title("KEYBOARD")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	scroll.custom_minimum_size.y = 11 * (item_size + 2)
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var rows: Array[MenuItem] = []
	var first: MenuItem
	for row in KeyBindings.ACTIONS:
		var action: StringName = row[0]
		var it := MenuItem.new(row[1], KeyBindings.text(action))
		it.font_size = item_size
		list.add_child(it)
		it.custom_minimum_size.y = item_size + 2
		it.changed.connect(func(_d: int): _capture_key(it, action, rows))
		rows.append(it)
		if first == null:
			first = it
	spacer()
	item("RESET TO DEFAULTS", func():
		KeyBindings.reset_all()
		GameSettings.save()
		_update_key_rows(rows)
		_refresh_key_hints())
	item("BACK", back)
	hint("ENTER  CHANGE KEY     ESC  BACK")
	focus(first)
	return first


## Čaká na kláves pre akciu (KeyCapture beží aj počas pauzy a zachytí udalosť skôr, než ju dostane menu)
func _capture_key(it: MenuItem, action: StringName, rows: Array[MenuItem]) -> void:
	it.set_value("PRESS A KEY ...")
	var cap := KeyCapture.new()
	cap.done.connect(func(code: int):
		if code != KeyCapture.CANCEL:
			KeyBindings.rebind(action, code)
			GameSettings.save()
			_refresh_key_hints()
		_update_key_rows(rows)
		if is_instance_valid(it):
			it.grab_focus())
	column.add_child.call_deferred(cap)


func _update_key_rows(rows: Array[MenuItem]) -> void:
	for i in rows.size():
		if is_instance_valid(rows[i]):
			rows[i].set_value(KeyBindings.text(KeyBindings.ACTIONS[i][0]))


## Nápisy kriedou, nápovedy a zoznam ovládania vľavo dole sa prepíšu podľa nových kláves
func _refresh_key_hints() -> void:
	var tree := column.get_tree()
	tree.call_group(&"chalk_text", &"queue_redraw")   # nápisy kriedou „HOLD C – SNEAK“ (world/fx/chalk_text.gd)
	tree.call_group(&"controls_help", &"refresh")


static func _on_off(b: bool) -> String:
	return "ON" if b else "OFF"


## V okne editora (Embed game) sa celá obrazovka zapnúť nedá – povie to rovno
static func _full_name() -> String:
	if GameSettings.embedded_in_editor():
		return "NOT IN EDITOR"
	return _on_off(GameSettings.fullscreen)


static func _scaling_name() -> String:
	return "PIXEL PERFECT" if GameSettings.pixel_perfect else "FILL SCREEN"


static func _hud_name() -> String:
	return "NOIR" if GameSettings.hud_style == GameSettings.HudStyle.NOIR else "MINIMAL"


static func _poster_name() -> String:
	return "%sx" % str(GameSettings.portrait_scale).trim_suffix(".0")
