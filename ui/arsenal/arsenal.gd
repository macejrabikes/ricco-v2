class_name Arsenal
extends Control
## Arsenal – drevená stena so zbraňami (úvodné menu aj pause menu → ARSENAL).
## Hore bočné zbrane, dole hlavné, v poradí, ako ich Ricco postupne odomyká.
## Odomknutá zbraň visí na mosadzných kolíkoch. Zamknutá je zakrytá vrecovinou so zámkom,
## takže nevidno jej tvar ani štatistiky (štítok ukáže ??? a pečiatku LOCKED).
## Vybraná zbraň je pod lampou (žiara sa k nej presunie) a trochu sa rozhojdá. Vpravo visí papierový štítok:
## damage, fire rate, range, accuracy ako pásiky (stat_bars), zásobník a prebíjanie ako čísla.
## Odomknutie rieši Progress (settings/progress.gd). Šípky alebo myš vyberajú, ESC / pravé tlačidlo / BACK zavrie → closed.

signal closed

const WALL := preload("res://ui/arsenal/wall.png")
const PEG := preload("res://ui/arsenal/peg.png")
const PADLOCK := preload("res://ui/arsenal/padlock.png")
const CLOTH_SMALL := preload("res://ui/arsenal/cloth_small.png")
const CLOTH_LARGE := preload("res://ui/arsenal/cloth_large.png")
const PLAQUE := preload("res://ui/arsenal/plaque.png")
const TAG := preload("res://ui/arsenal/tag.png")
const GLOW := preload("res://levels/level1/art/glow.png")
const THEME := preload("res://ui/theme/hud_theme.tres")

const CREAM := MenuItem.CREAM
const BRASS := MenuItem.BRASS
const HINT := MenuPages.HINT
const INK := Color8(52, 40, 32)
const INK_DIM := Color8(118, 98, 76)
const STAMP := Color8(158, 42, 34)
const TWINE := Color8(176, 150, 104)

const RACK_X := 216.0          ## stred steny so zbraňami (štítok je vpravo)
const SIDE_Y := 98.0           ## rad bočných zbraní
const PRIMARY_Y: Array[float] = [188.0, 258.0]   ## dva rady hlavných zbraní
const WEAPON_SCALE := 2.0
const TAG_POS := Vector2(428, 22)   ## klinec, na ktorom visí štítok (štítok je o 20 px nižšie)

## Všetky zbrane hry v poradí odomykania. res = "" → zbraň ešte v hre nie je (vždy zamknutá).
## Prvé 4 sú bočné (rad hore), ďalších 6 hlavné (2 rady po 3).
const ENTRIES: Array[Dictionary] = [
	{"res": "res://weapons/derringer/derringer.tres", "title": "DERRINGER", "model": "REMINGTON M95   .41 RF",
		"text": ["THE DON KEPT IT IN HIS SLEEVE.", "TWO SHOTS. MAKE THEM COUNT."]},
	{"res": "res://weapons/revolver/revolver.tres", "title": "REVOLVER", "model": "COLT POLICE POSITIVE   .38",
		"text": ["SIX ROUNDS AND IT NEVER JAMS.", "EVERY COP IN TOWN CARRIES ONE."]},
	{"res": "res://weapons/pistol/pistol.tres", "title": "COLT 1911", "model": "M1911   .45 ACP",
		"text": ["ARMY SURPLUS, SMUGGLED IN", "A CRATE OF OLIVE OIL."]},
	{"res": ""},   # Mauser C96
	{"res": "res://weapons/lupara/lupara.tres", "title": "LUPARA", "model": "SAWN-OFF DOUBLE   12 GA",
		"text": ["AN OLD SICILIAN TRADITION.", "UP CLOSE, NOTHING ARGUES BACK."]},
	{"res": "res://weapons/winchester/winchester.tres", "title": "WINCHESTER 1897", "model": "TRENCH GUN   12 GA",
		"text": ["IRON MIKE BROUGHT IT HOME", "FROM THE TRENCHES OF FRANCE.", "PUMP. BOOM. PUMP."]},
	{"res": "res://weapons/tommy/tommy.tres", "title": "THOMPSON", "model": "M1928   .45 ACP",
		"text": ["THE CHICAGO TYPEWRITER.", "LOUD, HUNGRY, AND IT", "NEVER STOPS TALKING."]},
	{"res": ""},   # Winchester 1894
	{"res": "res://weapons/springfield/springfield.tres", "title": "SPRINGFIELD 1903", "model": "M1903   .30-06",
		"text": ["FROM THE WIDOW'S TROPHY ROOM.", "FIVE ROUNDS, ONE BOLT.", "ONE MAN PER SHOT."]},
	{"res": ""},   # BAR M1918
]
const SIDEARMS := 4
## Mriežka pre šípky: riadky indexov do ENTRIES
const GRID: Array = [[0, 1, 2, 3], [4, 5, 6], [7, 8, 9]]

var _weapons: Array[WeaponData] = []
var selected: int = 0
var _font: Font
var _rack: Control      ## zbrane, kolíky, nadpisy (nad žiarou lampy)
var _tag: Control       ## papierový štítok (hojdá sa na klinci)
var _spot: Sprite2D     ## žiara lampy nad vybranou zbraňou
var _swing_t: float = 9.0   ## čas od výberu (hojdanie zbrane doznieva)
var _fill: float = 1.0      ## pásiky na štítku sa po výbere „dopečiatkujú“
var _back_hover: bool = false
var _closing: bool = false


func _ready() -> void:
	Progress.ensure_loaded()
	theme = THEME
	_font = THEME.default_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for e in ENTRIES:
		_weapons.append(load(e.res) as WeaponData if e.res != "" else null)

	_spot = Sprite2D.new()
	_spot.texture = GLOW
	_spot.scale = Vector2(2.5, 2.5)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_spot.material = add
	_spot.modulate = Color(1.0, 0.78, 0.45, 0.55)
	add_child(_spot)

	_rack = Control.new()
	_rack.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rack.draw.connect(_draw_rack)
	add_child(_rack)

	_tag = Control.new()
	_tag.position = TAG_POS
	_tag.size = Vector2(200, 292)
	_tag.pivot_offset = Vector2(100, 0)   # hojdá sa okolo klinca
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.draw.connect(_draw_tag)
	add_child(_tag)

	get_viewport().gui_release_focus()
	selected = 0
	for i in ENTRIES.size():   # začne na prvej odomknutej
		if _unlocked(i):
			selected = i
			break
	_spot.position = _cell(selected)
	_on_selected(false)
	# príchod: stena sa rozsvieti, štítok sa zhora spustí na klinec
	modulate.a = 0.0
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	_tag.position.y = TAG_POS.y - 40.0
	tw.tween_property(_tag, "position:y", TAG_POS.y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.ui(&"ui_select")
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(closed.emit)


# ---------------------------------------------------------------- štatistiky

## Pásiky 1–10: [damage, fire rate, range, accuracy]. Brokovnica počíta všetky broky,
## dostrel = plný damage + polovica doznievania, presnosť = základný rozptyl + štvrtina rozptylu pri dlhej streľbe.
static func stat_bars(w: WeaponData) -> Array[int]:
	var dmg: float = w.damage * w.pellets / 3.0 * 10.0
	var rate: float = (1.0 / w.fire_cooldown) / 13.0 * 10.0
	var rng: float = (w.effective_range + w.falloff_range * 0.5) / 500.0 * 10.0
	var acc: float = 10.0 - (w.spread_deg + w.spread_max_deg * 0.25) * 0.75
	var out: Array[int] = []
	for v in [dmg, rate, rng, acc]:
		out.append(clampi(roundi(v), 1, 10))
	return out


# ---------------------------------------------------------------- výber

func _unlocked(i: int) -> bool:
	return _weapons[i] != null and Progress.is_unlocked(_weapons[i].name)


## Stred miesta na stene pre zbraň i
func _cell(i: int) -> Vector2:
	if i < SIDEARMS:
		return Vector2(RACK_X + (i - 1.5) * 100.0, SIDE_Y)
	var k: int = i - SIDEARMS
	return Vector2(RACK_X + (k % 3 - 1) * 130.0, PRIMARY_Y[floori(k / 3.0)])


## Veľkosť toho, čo na mieste visí (zbraň 2×, alebo vrecovina)
func _cell_size(i: int) -> Vector2:
	if _unlocked(i):
		return _weapons[i].texture.get_size() * WEAPON_SCALE
	return (CLOTH_SMALL if i < SIDEARMS else CLOTH_LARGE).get_size()


func _select(i: int) -> void:
	if i == selected or i < 0:
		return
	selected = i
	Sfx.ui(&"ui_move")
	_on_selected(true)


func _on_selected(animate: bool) -> void:
	_swing_t = 0.0 if animate else 9.0
	if _unlocked(selected):
		Progress.mark_seen(_weapons[selected].name)
	if animate:
		_fill = 0.0
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_property(self, "_fill", 1.0, 0.3)
		_tag.rotation = deg_to_rad(randf_range(2.5, 4.0) * (1.0 if randf() < 0.5 else -1.0))
		var sw := create_tween().set_ignore_time_scale(true)
		sw.tween_property(_tag, "rotation", 0.0, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tag.queue_redraw()


## Pohyb po mriežke: doľava/doprava v riadku, hore/dole na najbližšiu zbraň v susednom riadku
func _move(dx: int, dy: int) -> void:
	var row: int = 0
	for r in GRID.size():
		if selected in GRID[r]:
			row = r
	var cols: Array = GRID[row]
	if dx != 0:
		_select(cols[posmod(cols.find(selected) + dx, cols.size())])
		return
	var nr: int = posmod(row + dy, GRID.size())
	var x: float = _cell(selected).x
	var best: int = GRID[nr][0]
	for j in GRID[nr]:
		if absf(_cell(j).x - x) < absf(_cell(best).x - x):
			best = j
	_select(best)


func _hit(i: int, p: Vector2) -> bool:
	var s: Vector2 = _cell_size(i) + Vector2(16, 14)
	return Rect2(_cell(i) - s / 2.0, s).has_point(p)


const BACK_RECT := Rect2(10, 338, 44, 14)

func _input(event: InputEvent) -> void:
	if _closing:
		return
	var handled: bool = true
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		close()
	elif event.is_action_pressed(&"ui_left", true):
		_move(-1, 0)
	elif event.is_action_pressed(&"ui_right", true):
		_move(1, 0)
	elif event.is_action_pressed(&"ui_up", true):
		_move(0, -1)
	elif event.is_action_pressed(&"ui_down", true):
		_move(0, 1)
	elif event is InputEventMouseMotion:
		var p: Vector2 = get_local_mouse_position()
		for i in ENTRIES.size():
			if _hit(i, p):
				_select(i)
		_back_hover = BACK_RECT.has_point(p)
		handled = false
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			close()
		elif event.button_index == MOUSE_BUTTON_LEFT and BACK_RECT.has_point(get_local_mouse_position()):
			close()
		else:
			handled = false
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_swing_t += delta
	# lampa sa plynulo presunie nad vybranú zbraň a jemne bliká
	_spot.position = _spot.position.lerp(_cell(selected), 1.0 - exp(-12.0 * delta))
	_spot.modulate.a = 0.55 + 0.03 * sin(Time.get_ticks_msec() * 0.011) + 0.02 * sin(Time.get_ticks_msec() * 0.037)
	_rack.queue_redraw()
	if _fill < 1.0:
		_tag.queue_redraw()


# ---------------------------------------------------------------- kreslenie

func _draw() -> void:
	draw_texture(WALL, Vector2.ZERO)


## Text s ľavým horným rohom v pos (draw_string chce základnú čiaru)
func _text(ci: CanvasItem, pos: Vector2, t: String, fs: int, col: Color, center: bool = false) -> void:
	if center:
		pos.x -= roundf(_font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2.0)
	ci.draw_string(_font, Vector2(pos.x, pos.y + _font.get_ascent(fs)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_rack() -> void:
	var r := _rack
	_text(r, Vector2(RACK_X, 4), "ARSENAL", 24, CREAM, true)
	r.draw_rect(Rect2(RACK_X - 32, 32, 64, 1), BRASS)
	for row in [[52.0, "SIDEARMS"], [142.0, "PRIMARIES"]]:
		r.draw_texture(PLAQUE, Vector2(RACK_X - 44, row[0] - 6))
		_text(r, Vector2(RACK_X, row[0] - 5), row[1], 8, INK, true)

	var t: float = Time.get_ticks_msec() / 1000.0
	for i in ENTRIES.size():
		var c: Vector2 = _cell(i)
		var sel: bool = i == selected
		var sz: Vector2 = _cell_size(i)
		if _unlocked(i):
			var w: WeaponData = _weapons[i]
			var tl: Vector2 = (c - sz / 2.0).round()
			# po výbere sa zbraň na kolíkoch rozhojdá a doznie
			var ang: float = deg_to_rad(4.0) * exp(-_swing_t * 4.0) * sin(_swing_t * 14.0) if sel else 0.0
			var lift: float = -1.0 if sel else 0.0
			r.draw_set_transform(c + Vector2(3, 4), ang, Vector2.ONE)   # tieň na stene
			r.draw_texture_rect(w.texture, Rect2(-sz / 2.0, sz), false, Color(0, 0, 0, 0.45))
			r.draw_set_transform(c + Vector2(0, lift), ang, Vector2.ONE)
			var shade: Color = Color.WHITE if sel else Color(0.62, 0.6, 0.58)
			r.draw_texture_rect(w.texture, Rect2(-sz / 2.0, sz), false, shade)
			r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for f in [-0.28, 0.28]:
				r.draw_texture(PEG, Vector2(roundf(c.x + f * sz.x) - 3.0, tl.y + sz.y - 4.0))
			if Progress.is_new(w.name) and fmod(t, 1.0) < 0.7:
				_text(r, tl + Vector2(sz.x - 6, -10), "NEW", 8, STAMP)
		else:
			var cloth: Texture2D = CLOTH_SMALL if i < SIDEARMS else CLOTH_LARGE
			var tl: Vector2 = (c - sz / 2.0).round()
			for f in [-0.3, 0.3]:
				r.draw_texture(PEG, Vector2(roundf(c.x + f * sz.x) - 3.0, tl.y - 2.0))
			r.draw_texture(cloth, tl, Color.WHITE if sel else Color(0.7, 0.68, 0.66))
			# zámok sa po výbere zatrasie
			var shake: float = roundf(2.0 * exp(-_swing_t * 6.0) * sin(_swing_t * 40.0)) if sel else 0.0
			r.draw_texture(PADLOCK, Vector2(c.x - 5.0 + shake, tl.y + sz.y - 12.0))
		if sel:   # mosadzné rohy okolo vybranej
			var h: Vector2 = (sz / 2.0 + Vector2(8, 7)).round()
			var a: float = 0.75 + 0.25 * sin(t * 5.0)
			var col := Color(BRASS, a)
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var p: Vector2 = c.round() + Vector2(sx * h.x, sy * h.y)
					r.draw_rect(Rect2(minf(p.x, p.x - sx * 6.0), p.y, 6, 1), col)
					r.draw_rect(Rect2(p.x, minf(p.y, p.y - sy * 6.0), 1, 6), col)

	_text(r, Vector2(BACK_RECT.position.x + 6, 343), "< BACK", 8, BRASS if _back_hover else CREAM)
	_text(r, Vector2(BACK_RECT.end.x + 14, 343), "ARROWS / MOUSE  SELECT     ESC  BACK", 8, HINT)


func _draw_tag() -> void:
	var g := _tag
	var w: WeaponData = _weapons[selected] if _unlocked(selected) else null
	# klinec a povrázok
	g.draw_line(Vector2(100, 0), Vector2(96, 31), TWINE)
	g.draw_line(Vector2(100, 0), Vector2(104, 31), TWINE)
	g.draw_texture(TAG, Vector2(0, 20))
	g.draw_rect(Rect2(99, -1, 3, 3), Color8(150, 140, 130))
	var l: float = 14.0
	var y: float = 20.0
	var e: Dictionary = ENTRIES[selected]
	if w:
		_text(g, Vector2(l, y + 30), e.title, 16, INK)
		_text(g, Vector2(l, y + 50), e.model, 8, INK_DIM)
		_text(g, Vector2(l, y + 60), "SIDEARM" if w.slot_name == "SIDEARM" else "PRIMARY", 8, STAMP)
		for k in e.text.size():
			_text(g, Vector2(l, y + 76 + k * 10), e.text[k], 8, INK)
	else:
		_text(g, Vector2(l, y + 30), "???", 16, INK)
		_text(g, Vector2(l, y + 50), "NOT YET FOUND", 8, INK_DIM)
		_text(g, Vector2(l, y + 76), "KEEP YOUR EYES OPEN", 8, INK)
		_text(g, Vector2(l, y + 86), "ON THE STREETS.", 8, INK)
	_dashes(g, y + 116)
	var bars: Array[int] = [0, 0, 0, 0]
	if w:
		bars = stat_bars(w)
	var labels := ["DAMAGE", "FIRE RATE", "RANGE", "ACCURACY"]
	for k in 4:
		var yy: float = y + 126 + k * 16
		_text(g, Vector2(l, yy), labels[k], 8, INK)
		var n: int = roundi(bars[k] * _fill)
		for b in 10:
			var box := Rect2(l + 80 + b * 9, yy + 1, 7, 7)
			if b < n:   # pečiatka – každý štvorček trochu inak nasiaknutý
				g.draw_rect(box, Color(STAMP, 0.82 + 0.18 * fmod(b * 0.37 + k * 0.61, 1.0)))
			else:
				g.draw_rect(box, Color(INK_DIM, 0.8), false, 1.0)
	_dashes(g, y + 194)
	var nums := [["MAGAZINE", str(w.mag_size) if w else "--"], ["RELOAD", ("%.1f S" % w.reload_time) if w else "--"]]
	for k in 2:
		var yy: float = y + 204 + k * 20
		_text(g, Vector2(l, yy + 4), nums[k][0], 8, INK)
		var vw: float = _font.get_string_size(nums[k][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_text(g, Vector2(186 - vw, yy), nums[k][1], 16, INK)
	_text(g, Vector2(l, y + 252), "FAMIGLIA ARMS   NO. %02d" % (selected + 1), 8, INK_DIM)
	if not w:   # červená pečiatka cez štatistiky
		g.draw_set_transform(Vector2(100, y + 150), deg_to_rad(-12.0), Vector2.ONE)
		var col := Color(STAMP, 0.85)
		g.draw_rect(Rect2(-54, -14, 108, 28), col, false, 1.0)
		g.draw_rect(Rect2(-52, -12, 104, 24), col, false, 1.0)
		_text(g, Vector2(0, -9), "LOCKED", 16, col, true)
		g.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _dashes(ci: CanvasItem, yy: float) -> void:
	var x: float = 14.0
	while x < 186.0:
		ci.draw_rect(Rect2(x, yy, 2, 1), INK_DIM)
		x += 4.0
