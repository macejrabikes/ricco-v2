extends Control
## Počítadlo nábojov vpravo dole. Kreslí sa cez _draw (Godot docs: tutorials/2d/custom_drawing_in_2d).
## Dva štýly (GameSettings.hud_style):
##   NOIR    – krémový lístok ako z kina v 30. rokoch: silueta zbrane, náboje ako čierne čiarky, rezerva
##   MINIMAL – veľké číslo v zásobníku, malá rezerva, tenký pásik nábojov (štýl My Friend Pedro)
## F2 prepína štýl (dočasne, kým nebude menu s nastaveniami) a uloží ho.
## Spoločné efekty: vystrelený náboj odskočí, pri prebíjaní sa plní prúžok,
## po prebití sa náboje doplnia jeden po druhom, prázdny zásobník bliká načerveno.
## Pod lístkom sú 3 sloty výbavy (klávesy 1–3): NOIR = papierové ústrižky, vybraný je svetlý, dlhší a podčiarknutý;
## MINIMAL = malé tmavé políčka. Pri zbrani s dvoma režimami ukáže červená pečiatka AUTO/SEMI alebo 1x/2x (kláves B).

const ATLAS: Texture2D = preload("res://ui/hud_ammo.png")
const GLYPH := PixelDigits.GLYPH
const MAX_ICONS := 12          ## väčší zásobník (napr. Tommy gun) sa ukáže číslom
const TICKET := Vector2(100, 20)  ## noir lístok má pevnú veľkosť – zbraň sa zmenší do ICON_BOX, sloty pod ním sedia
const ICON_BOX := Vector2(40, 12)
const STUB_H := 12.0           ## ústrižok so slotom (vybraný je o STUB_DROP dlhší)
const STUB_DROP := 3.0
const SLOTS := 3
const FONT := preload("res://ui/fonts/tiny5.ttf")
const MARGIN := Vector2(8, 8)  ## odstup od rohu obrazovky
const GAP := 6.0               ## medzera od HP plagátu (ten je úplne vpravo)

# noir lístok
const PAPER := Color8(232, 222, 196)
const PAPER_D := Color8(214, 202, 172)
const PAPER_DD := Color8(196, 184, 156)
const INK := Color8(22, 20, 18)
const STAMP := Color8(176, 32, 30)
# minimal
const CREAM := Color8(245, 235, 209)
const BRASS := Color8(199, 153, 71)
const BRASS_D := Color8(92, 69, 31)
const DIM := Color8(60, 60, 66)
const RED := Color8(255, 82, 66)
const STUB_DIM := Color8(150, 138, 110)
const SLOT_BG := Color(0.07, 0.06, 0.08, 0.82)
const MINI_SLOT := Vector2(18, 9)

@export var weapon_icon: Texture2D = preload("res://weapons/pistol/pistol.png")
@export var health_poster_path: NodePath = ^"../HealthPoster"

var mag: int = 0
var reserve: int = 0
var mag_size: int = 8
var reloading: bool = false
var reload_time: float = 1.0
var _reload_t: float = 0.0
var _pop_slot: int = -1        ## ktorý náboj práve odskakuje
var _pop_t: float = 1.0        ## 0 → 1 počas odskoku
var _fill_from: int = 0        ## od koľkých nábojov sa dopĺňa po prebití
var _fill_t: float = 1.0       ## 0 → 1 počas dopĺňania
var _time: float = 0.0
var _icon_silhouette: Texture2D  ## jednofarebná silueta zbrane pre noir lístok
var _speckles: PackedVector2Array  ## „zrnitosť“ papiera (pevné body, aby neblikali)
var _style: int = -1               ## štýl, pre ktorý je spočítané rozloženie (mení sa aj v pause menu)
var _player: Node
var _mode_label: String = ""       ## AUTO / SEMI / 1x / 2x ("" = zbraň má jeden režim)
var _mode_t: float = 1.0           ## 0 → 1 po prepnutí režimu (pečiatka sa „udrie“)
var _sel: int = 0                  ## vybraný slot
var _sel_t: float = 1.0            ## 0 → 1 po zmene slotu (ústrižok sa vysunie)
static var _icons: Dictionary = {} ## [textúra, šírka, výška] → zmenšená silueta (počíta sa raz)


func _ready() -> void:
	GameSettings.ensure_loaded()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		_player = player
		mag_size = player.mag_size
		reload_time = player.reload_time
		if player.weapon:
			weapon_icon = player.weapon.texture
		player.ammo_changed.connect(_on_ammo_changed)
		player.weapon_changed.connect(_on_weapon_changed)
		if player.has_signal(&"fire_mode_changed"):
			player.fire_mode_changed.connect(func(_alt: bool):
				_mode_label = player.fire_mode_label()
				_mode_t = 0.0)
		mag = player.ammo_in_mag
		reserve = player.ammo_reserve
		_sync_weapon()
	_icon_silhouette = fit_silhouette(weapon_icon, ICON_BOX)
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F2:
		GameSettings.hud_style = GameSettings.HudStyle.MINIMAL if GameSettings.hud_style == GameSettings.HudStyle.NOIR else GameSettings.HudStyle.NOIR
		GameSettings.save()
		_update_layout()
		get_viewport().set_input_as_handled()


## Iná zbraň v ruke: nová silueta, veľkosť zásobníka, rozloženie
func _on_weapon_changed(w: WeaponData) -> void:
	visible = w != null      # bez zbrane sa panel skryje
	if w == null:
		return
	weapon_icon = w.texture
	mag_size = w.mag_size
	reload_time = w.reload_time
	reloading = false
	mag = -100          # nasledujúce ammo_changed nespustí odskok ani dopĺňanie
	_pop_t = 1.0
	_fill_t = 1.0
	_icon_silhouette = fit_silhouette(weapon_icon, ICON_BOX)
	_sync_weapon()
	_update_layout()


## Vybraný slot a režim streľby podľa Ricca
func _sync_weapon() -> void:
	if _player == null:
		return
	if _player.weapon_index != _sel:
		_sel = _player.weapon_index
		_sel_t = 0.0
	_mode_label = _player.fire_mode_label() if _player.has_method(&"fire_mode_label") else ""


func _on_ammo_changed(new_mag: int, new_reserve: int, new_reloading: bool) -> void:
	if new_mag == mag - 1:
		_pop_slot = new_mag
		_pop_t = 0.0
	if reloading and not new_reloading and new_mag > mag:
		_fill_from = mag
		_fill_t = 0.0
	if new_reloading and not reloading:
		_reload_t = 0.0
	mag = new_mag
	reserve = new_reserve
	reloading = new_reloading


func _process(delta: float) -> void:
	_time += delta
	_pop_t = minf(_pop_t + delta / 0.25, 1.0)
	_fill_t = minf(_fill_t + delta / 0.2, 1.0)
	_mode_t = minf(_mode_t + delta / 0.25, 1.0)
	_sel_t = minf(_sel_t + delta / 0.15, 1.0)
	if reloading:
		_reload_t += delta
	if _style != GameSettings.hud_style:
		_update_layout()
	_place()
	queue_redraw()


## Vpravo dole, naľavo od HP plagátu (ak je)
func _place() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var right: float = vp.x - MARGIN.x
	var poster := get_node_or_null(health_poster_path) as Control
	if poster and poster.visible and poster.has_method("layout_rect"):
		right = poster.layout_rect().position.x - GAP
	position = Vector2(right - size.x, vp.y - MARGIN.y - size.y).floor()


# ---------------------------------------------------------------- rozloženie

func _noir_size() -> Vector2:
	return TICKET + Vector2(0, STUB_H + STUB_DROP)


func _minimal_size() -> Vector2:
	return Vector2(maxf(_number_width(99, 3) + 2 + 4 + 1 + _number_width(999), MINI_SLOT.x * SLOTS + 2 * (SLOTS - 1)), 18 + 7 + 3 + MINI_SLOT.y)


func _update_layout() -> void:
	_style = GameSettings.hud_style
	var s: Vector2 = _noir_size() + Vector2(2, 2) if GameSettings.hud_style == GameSettings.HudStyle.NOIR else _minimal_size()
	size = s
	_place()
	if GameSettings.hud_style == GameSettings.HudStyle.NOIR:
		_speckles.clear()
		for y in range(1, int(TICKET.y) - 1):
			for x in range(1, int(TICKET.x) - 1):
				if (x * 73 + y * 151 + x * y * 7) % 23 == 0:
					_speckles.append(Vector2(x, y))
	queue_redraw()


## Koľko nábojov ukázať (po prebití sa dopĺňajú postupne)
func _shown_rounds() -> int:
	if _fill_t < 1.0:
		return _fill_from + int(ceilf((mag - _fill_from) * _fill_t))
	return mag


func _bars_width(step: float) -> float:
	if mag_size <= MAX_ICONS:
		return mag_size * step - 1.0
	return _number_width(mag_size)


func _empty_blink() -> bool:
	return mag == 0 and not reloading and fmod(_time, 0.6) < 0.3


func _draw() -> void:
	if GameSettings.hud_style == GameSettings.HudStyle.NOIR:
		_draw_noir()
	else:
		_draw_minimal()


# ---------------------------------------------------------------- NOIR

func _draw_noir() -> void:
	_draw_stubs()                                             # ústrižky sú pod lístkom (lístok prekryje ich vrch)
	var w: float = TICKET.x
	var h: float = TICKET.y
	draw_rect(Rect2(2, 2, w, h), Color(0, 0, 0, 0.45))       # tieň
	draw_rect(Rect2(0, 0, w, h), PAPER)
	for p in _speckles:
		draw_rect(Rect2(p, Vector2.ONE), PAPER_D)
	for x in range(0, int(w), 3):                             # perforácia hore a dole
		draw_rect(Rect2(x, 0, 1, 1), PAPER_DD)
		draw_rect(Rect2(x + 1, h - 1, 1, 1), PAPER_DD)
	draw_rect(Rect2(2, 2, w - 4, 1), INK)                      # dvojité linky
	draw_rect(Rect2(2, h - 3, w - 4, 1), INK)

	var x: float = 4.0
	var isz: Vector2 = _icon_silhouette.get_size()
	var icon_pos: Vector2 = (Vector2(x, 0) + (Vector2(ICON_BOX.x, h) - isz) / 2.0).floor()
	draw_texture(_icon_silhouette, icon_pos, Color(INK, 0.35 if reloading else 1.0))
	x += ICON_BOX.x + 4.0

	var by: float = 7.0
	if mag_size <= MAX_ICONS:
		var shown: int = _shown_rounds()
		for i in mag_size:
			var full: bool = i < shown
			var c: Color = (Color(INK, 0.35) if reloading else INK) if full else PAPER_DD
			draw_rect(Rect2(x + i * 3, by, 2, 6), c)
		if _pop_t < 1.0 and _pop_slot >= 0 and _pop_slot < mag_size:
			draw_rect(Rect2(x + _pop_slot * 3, by - roundf(_pop_t * 4.0), 2, 6), Color(INK, 1.0 - _pop_t))
	else:
		_draw_number(_shown_rounds(), Vector2(x, by), INK, 1, false)
	var bw: float = _bars_width(3.0)
	if reloading:                                               # pečiatkovo červený prúžok
		var k: float = clampf(_reload_t / reload_time, 0.0, 1.0)
		draw_rect(Rect2(x, by + 8, bw, 1), PAPER_DD)
		draw_rect(Rect2(x, by + 8, floorf(bw * k), 1), STAMP)
	if _empty_blink():                                          # prázdny zásobník = červená pečiatka
		var r := Rect2(x - 2, by - 2, bw + 4, 10)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), STAMP)
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), STAMP)
		draw_rect(Rect2(r.position, Vector2(1, r.size.y)), STAMP)
		draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), STAMP)
	if _mode_label != "":                                       # režim streľby – červená pečiatka za nábojmi
		var k: float = 1.0 - _mode_t
		var c := Color(STAMP, 1.0 - 0.5 * k)
		draw_string(FONT, Vector2(x + bw + 3, by + 5 - roundf(2.0 * k)), _mode_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)
	_draw_number(reserve, Vector2(w - 4 - _number_width(reserve), by), STAMP if reserve == 0 else INK, 1, false)


## Ústrižky lístka so slotmi 1–3 (zbrane z výbavy Ricca). Vybraný je svetlý, o STUB_DROP dlhší, s červenou linkou.
func _draw_stubs() -> void:
	var loadout: Array = _player.loadout if _player else []
	for i in SLOTS:
		var x0: float = floorf(TICKET.x * i / SLOTS)
		var sw: float = floorf(TICKET.x * (i + 1) / SLOTS) - x0
		var act: bool = i == _sel and i < loadout.size()
		var drop: float = roundf(STUB_DROP * (_sel_t if act else 0.0))
		var r := Rect2(x0, TICKET.y - 1, sw, STUB_H + 1 + drop)
		draw_rect(Rect2(r.position + Vector2(2, 1), r.size), Color(0, 0, 0, 0.4))
		draw_rect(r, PAPER if act else PAPER_DD)
		for yy in range(int(r.position.y), int(r.end.y), 2):       # perforácia medzi ústrižkami
			if i > 0:
				draw_rect(Rect2(x0, yy, 1, 1), STUB_DIM)
		var ink: Color = INK if act else STUB_DIM
		var cy: float = r.position.y + 1 + (STUB_H - 6) / 2.0 + drop * 0.5
		_draw_glyph(str(i + 1), Vector2(x0 + 2, floorf(cy)), STAMP if act else STUB_DIM, 1, false)
		if i < loadout.size():
			var ic: Texture2D = fit_silhouette(loadout[i].texture, Vector2(sw - 10, 7))
			var p := Vector2(x0 + 8 + floorf((sw - 10 - ic.get_width()) / 2.0), floorf(r.position.y + 1 + (STUB_H - ic.get_height()) / 2.0 + drop * 0.5))
			draw_texture(ic, p, ink)
			if _player.weapon_ammo.size() > i and _player.weapon_ammo[i][0] + _player.weapon_ammo[i][1] <= 0:
				draw_rect(Rect2(x0 + 8, r.end.y - 3, sw - 10, 1), STAMP)   # bez nábojov – červená čiarka
		if act:
			draw_rect(Rect2(x0 + 2, r.end.y - 2, sw - 4, 1), STAMP)


# ---------------------------------------------------------------- MINIMAL

func _draw_minimal() -> void:
	var big_w: float = _number_width(mag, 3)
	var res_w: float = _number_width(reserve)
	var x0: float = size.x - (big_w + 2 + 4 + 1 + res_w)       # zarovnané doprava
	var bump: float = -1.0 if _pop_t < 0.25 else 0.0            # číslo pri výstrele cukne
	var col: Color = RED if _empty_blink() else (Color(CREAM, 0.5) if reloading else CREAM)
	_draw_number(mag, Vector2(x0, bump), col, 3, true)
	var sx: float = x0 + big_w + 2
	_draw_glyph("/", Vector2(sx, 12), BRASS, 1, true)
	_draw_number(reserve, Vector2(sx + 5, 12), RED if reserve == 0 else BRASS, 1, true)
	# pásik nábojov
	var y: float = 21.0
	if mag_size <= MAX_ICONS:
		var shown: int = _shown_rounds()
		for i in mag_size:
			draw_rect(Rect2(x0 + i * 4, y, 3, 2), BRASS if i < shown else DIM)
	if reloading:
		var bw: float = float(mag_size * 4 - 1) if mag_size <= MAX_ICONS else big_w
		var k: float = clampf(_reload_t / reload_time, 0.0, 1.0)
		draw_rect(Rect2(x0, y + 3, bw, 1), BRASS_D)
		draw_rect(Rect2(x0, y + 3, floorf(bw * k), 1), BRASS)
	if _mode_label != "":
		draw_string_outline(FONT, Vector2(sx + 1, 10), _mode_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.9))   # nad rezervou
		draw_string(FONT, Vector2(sx + 1, 10), _mode_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RED if _mode_t < 1.0 else BRASS)
	# sloty výbavy – malé tmavé políčka, vybrané má mosadzný rám
	var loadout: Array = _player.loadout if _player else []
	var sy: float = size.y - MINI_SLOT.y
	for i in SLOTS:
		var r := Rect2(size.x - (SLOTS - i) * (MINI_SLOT.x + 2) + 2, sy, MINI_SLOT.x, MINI_SLOT.y)
		var act: bool = i == _sel and i < loadout.size()
		draw_rect(r, SLOT_BG)
		draw_rect(r, BRASS if act else BRASS_D, false, 1.0)
		if i < loadout.size():
			var ic: Texture2D = fit_silhouette(loadout[i].texture, MINI_SLOT - Vector2(4, 3))
			draw_texture(ic, (r.get_center() - ic.get_size() / 2.0).floor(), CREAM if act else DIM.lightened(0.3))


# ---------------------------------------------------------------- písmo (ui/pixel_digits.gd)

func _number_width(n: int, sc: int = 1) -> float:
	return PixelDigits.number_width(n, sc)


func _draw_number(n: int, pos: Vector2, col: Color, sc: int, outline: bool) -> void:
	PixelDigits.draw_number(self, n, pos, col, sc, outline)


func _draw_glyph(ch: String, pos: Vector2, col: Color, sc: int, outline: bool) -> void:
	PixelDigits.draw_glyph(self, ch, pos, col, sc, outline)


## Biela silueta zbrane zmenšená tak, aby sa zmestila do box (farbí sa cez modulate). Zmenšuje sa priemerom
## pixelov (každý cieľový pixel = podiel nepriehľadných pixelov pod ním), takže aj malá silueta drží tvar.
## Výsledok sa pamätá – volá sa aj každý snímok z _draw.
static func fit_silhouette(tex: Texture2D, box: Vector2) -> Texture2D:
	var key := [tex, int(box.x), int(box.y)]
	if _icons.has(key):
		return _icons[key]
	var img: Image = tex.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var used: Rect2i = img.get_used_rect()
	var k: float = minf(1.0, minf(box.x / used.size.x, box.y / used.size.y))
	var w: int = maxi(1, roundi(used.size.x * k))
	var h: int = maxi(1, roundi(used.size.y * k))
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var x0: int = used.position.x + int(floorf(x / k))
			var y0: int = used.position.y + int(floorf(y / k))
			var x1: int = maxi(x0 + 1, used.position.x + int(floorf((x + 1) / k)))
			var y1: int = maxi(y0 + 1, used.position.y + int(floorf((y + 1) / k)))
			var on: int = 0
			for yy in range(y0, mini(y1, used.end.y)):
				for xx in range(x0, mini(x1, used.end.x)):
					if img.get_pixel(xx, yy).a > 0.5:
						on += 1
			var total: int = maxi(1, (mini(x1, used.end.x) - x0) * (mini(y1, used.end.y) - y0))
			out.set_pixel(x, y, Color(1, 1, 1, 1.0 if float(on) / total > 0.4 else 0.0))
	var t := ImageTexture.create_from_image(out)
	_icons[key] = t
	return t
