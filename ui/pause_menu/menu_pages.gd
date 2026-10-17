class_name MenuPages
extends RefCounted
## Spoločné stránky menu (štýl „minimal“, vpravo, po anglicky) pre pause menu aj úvodné menu:
## nadpis, položky, nastavenia, zoznam ovládania. Stavia ich do VBoxContainera (column).

const CREAM := MenuItem.CREAM
const BRASS := MenuItem.BRASS
const HINT := Color8(120, 112, 96)

const CONTROLS := [
	["MOVE", "A / D"], ["JUMP, WALL JUMP, CLIMB", "SPACE / W"], ["SHOOT", "LEFT MOUSE"],
	["THROW HAT", "RIGHT MOUSE / E"], ["RELOAD", "R"], ["SWITCH WEAPON", "1-4 / WHEEL / Q"], ["SLOW-MO", "SHIFT"],
	["BELLY SLIDE", "S / CTRL"], ["SNEAK (HOLD)", "C / ALT"], ["TAKEDOWN FROM BEHIND", "F"], ["PAUSE", "ESC / P"], ["FULLSCREEN", "F11"],
]

var column: VBoxContainer
var on_apply: Callable      ## zavolá sa po každej zmene nastavení (uloženie, celá obrazovka…)
var item_size: int = 8      ## veľkosť písma položiek (úvodné menu 16)
var title_size: int = 16
var preview: SettingsPreview   ## náhľad vedľa nastavení (zameriavač, plagát, retro filter)


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


## Stránka nastavení. back = kam sa vráti BACK / ESC, audio = otvorí stránku zvuku.
func settings_page(back: Callable, audio: Callable = Callable()) -> MenuItem:
	clear()
	preview = SettingsPreview.new()
	column.get_parent().add_child(preview)
	title("SETTINGS")
	var first: MenuItem = null
	if audio.is_valid():
		first = item("AUDIO", audio)
		first.focus_entered.connect(func(): _preview("", 0))
	var full := setting("FULLSCREEN", _full_name(), func(_d: int, it: MenuItem):
		GameSettings.fullscreen = not GameSettings.fullscreen
		it.set_value(_full_name()))
	choice("SCALING", PackedStringArray(["PIXEL PERFECT", "FILL SCREEN"]), 0 if GameSettings.pixel_perfect else 1, func(i: int):
		GameSettings.pixel_perfect = i == 0)
	setting("RETRO FILTER", _on_off(GameSettings.retro_filter), func(_d: int, it: MenuItem):
		GameSettings.retro_filter = not GameSettings.retro_filter
		it.set_value(_on_off(GameSettings.retro_filter)))
	choice("HUD STYLE", PackedStringArray(["NOIR", "MINIMAL"]), GameSettings.hud_style, func(i: int):
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
	if first == null:
		first = full
	focus(first)
	return first


const VOLUMES := [["MASTER", "Master"], ["MUSIC", "Music"], ["SOUND EFFECTS", "SFX"], ["AMBIENCE", "Ambience"], ["MENU SOUNDS", "UI"]]
## Skúšobný zvuk pri zmene hlasitosti danej zbernice
const VOLUME_TEST := {"Master": &"ui_select", "Music": &"ui_select", "SFX": &"pistol_a", "Ambience": &"drip", "UI": &"ui_move"}


## Stránka zvuku: hlasitosť zberníc 0–10 (audio/sfx.gd, GameSettings.volumes)
func audio_page(back: Callable) -> MenuItem:
	clear()
	title("AUDIO")
	var first: MenuItem = null
	for row in VOLUMES:
		var key: String = row[1]
		var it := MenuItem.new(row[0], _vol_text(GameSettings.volume(key)))
		it.font_size = item_size
		it.changed.connect(func(d: int):
			var v: int = GameSettings.volume(key) + d
			if v > 10:
				v = 0   # Enter / klik prechádza dookola
			GameSettings.volumes[key] = clampi(v, 0, 10)
			it.set_value(_vol_text(GameSettings.volumes[key]))
			Sfx.apply_volumes()
			GameSettings.save()
			if key != "UI":
				Sfx.play(VOLUME_TEST[key], Vector2.INF, -4.0, 0.0, &"UI" if key in ["Master", "Music"] else StringName(key)))
		column.add_child(it)
		if first == null:
			first = it
	spacer()
	item("BACK", back)
	hint("LEFT / RIGHT  VOLUME     ESC  BACK")
	focus(first)
	return first


static func _vol_text(v: int) -> String:
	return "%s%s  %3d%%" % ["|".repeat(v), ".".repeat(10 - v), v * 10]


func controls_page(back: Callable) -> MenuItem:
	clear()
	title("CONTROLS")
	for row in CONTROLS:
		var it := MenuItem.new(row[0], row[1])
		it.selectable = false
		it.font_size = item_size
		column.add_child(it)
	spacer()
	var first := item("BACK", back)
	hint("ESC  BACK")
	focus(first)
	return first


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
