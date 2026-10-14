extends Control
## Počítadlo nábojov vpravo dole. Kreslí sa cez _draw (Godot docs: tutorials/2d/custom_drawing_in_2d).
## Dva štýly (GameSettings.hud_style):
##   NOIR    – krémový lístok ako z kina v 30. rokoch: silueta zbrane, náboje ako čierne čiarky, rezerva
##   MINIMAL – veľké číslo v zásobníku, malá rezerva, tenký pásik nábojov (štýl My Friend Pedro)
## F2 prepína štýl (dočasne, kým nebude menu s nastaveniami) a uloží ho.
## Spoločné efekty: vystrelený náboj odskočí, pri prebíjaní sa plní prúžok,
## po prebití sa náboje doplnia jeden po druhom, prázdny zásobník bliká načerveno.

const ATLAS: Texture2D = preload("res://ui/hud_ammo.png")
const GLYPH := PixelDigits.GLYPH
const MAX_ICONS := 12          ## väčší zásobník (napr. Tommy gun) sa ukáže číslom
const MARGIN := Vector2(8, 8)  ## odstup od rohu obrazovky

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

@export var weapon_icon: Texture2D = preload("res://weapons/pistol/pistol.png")

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


func _ready() -> void:
	GameSettings.ensure_loaded()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		mag_size = player.mag_size
		reload_time = player.reload_time
		player.ammo_changed.connect(_on_ammo_changed)
		mag = player.ammo_in_mag
		reserve = player.ammo_reserve
	_icon_silhouette = _make_silhouette(weapon_icon)
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F2:
		GameSettings.hud_style = GameSettings.HudStyle.MINIMAL if GameSettings.hud_style == GameSettings.HudStyle.NOIR else GameSettings.HudStyle.NOIR
		GameSettings.save()
		_update_layout()
		get_viewport().set_input_as_handled()


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
	if reloading:
		_reload_t += delta
	queue_redraw()


# ---------------------------------------------------------------- rozloženie

func _noir_size() -> Vector2:
	return Vector2(4 + weapon_icon.get_width() + 4 + _bars_width(3.0) + 5 + _number_width(999) + 4, 20)


func _minimal_size() -> Vector2:
	return Vector2(_number_width(99, 3) + 2 + 4 + 1 + _number_width(999), 18 + 7)


func _update_layout() -> void:
	var s: Vector2 = _noir_size() + Vector2(2, 2) if GameSettings.hud_style == GameSettings.HudStyle.NOIR else _minimal_size()
	size = s
	position = (get_viewport_rect().size - size - MARGIN).floor()
	if GameSettings.hud_style == GameSettings.HudStyle.NOIR:
		_speckles.clear()
		var ns: Vector2 = _noir_size()
		for y in range(1, int(ns.y) - 1):
			for x in range(1, int(ns.x) - 1):
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
	var s: Vector2 = _noir_size()
	var w: float = s.x
	var h: float = s.y
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
	var icon_y: float = floorf((h - weapon_icon.get_height()) / 2.0)
	draw_texture(_icon_silhouette, Vector2(x, icon_y), Color(INK, 0.35 if reloading else 1.0))
	x += weapon_icon.get_width() + 4.0

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
	x += bw + 5.0
	_draw_number(reserve, Vector2(x, by), STAMP if reserve == 0 else INK, 1, false)


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
		var bw: float = mag_size * 4 - 1 if mag_size <= MAX_ICONS else big_w
		var k: float = clampf(_reload_t / reload_time, 0.0, 1.0)
		draw_rect(Rect2(x0, y + 3, bw, 1), BRASS_D)
		draw_rect(Rect2(x0, y + 3, floorf(bw * k), 1), BRASS)


# ---------------------------------------------------------------- písmo (ui/pixel_digits.gd)

func _number_width(n: int, scale: int = 1) -> float:
	return PixelDigits.number_width(n, scale)


func _draw_number(n: int, pos: Vector2, color: Color, scale: int, outline: bool) -> void:
	PixelDigits.draw_number(self, n, pos, color, scale, outline)


func _draw_glyph(ch: String, pos: Vector2, color: Color, scale: int, outline: bool) -> void:
	PixelDigits.draw_glyph(self, ch, pos, color, scale, outline)


## Biela silueta obrázka (farbí sa cez modulate) – pre čiernu zbraň na lístku
static func _make_silhouette(tex: Texture2D) -> Texture2D:
	var img: Image = tex.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var a: float = img.get_pixel(x, y).a
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if a > 0.5 else 0.0))
	return ImageTexture.create_from_image(img)
