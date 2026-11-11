class_name InteractGlow
extends Sprite2D
## Mäkká teplá žiara za vecou, ktorú Ricco môže použiť (dvere, kniha, páka…). Z obrázka veci (aktuálna snímka)
## sa raz vyrobí rozmazaná silueta (cache), kreslí sa za ňou (show_behind_parent) a sčítava sa so svetlom (ADD).
## Ďaleko svieti slabo a pomaly dýcha, keď je Ricco pri nej (nápoveda svieti), zosilnie. Keď sa už nedá použiť, zhasne.
## Keď vec nemá vlastný obrázok (je namaľovaná v pozadí), svieti len mäkký ovál v mieste (blob).
##
## Použitie:
##     InteractGlow.attach(sprite, func() -> int: return InteractGlow.NEAR if near else InteractGlow.FAR)
##     InteractGlow.blob(parent, Rect2(-16, -24, 32, 24), state)   # bez obrázka
## state: OFF = zhasnuté, FAR = dá sa použiť (slabá žiara), NEAR = Ricco stojí pri nej
## Godot docs: classes/class_image, classes/class_canvasitemmaterial (blend_mode ADD)

enum { OFF, FAR, NEAR }

const COLOR := Color(1.0, 0.72, 0.32)   ## teplá zlatá (ako lampy)
const FAR_A := 0.20      ## sila žiary ďaleko (dýcha medzi FAR_A a FAR_A + FAR_PULSE)
const FAR_PULSE := 0.08
const NEAR_A := 0.45     ## sila žiary pri vecí
const FADE := 4.0        ## ako rýchlo sa mení sila (za s)
const PAD := 6           ## px – o koľko presahuje žiara okraj obrázka
const MAX_PIXELS := 220 * 220   ## väčšie obrázky (pozadia) sa nerozmazávajú – dostanú blob

static var _cache: Dictionary = {}   ## kľúč snímky → ImageTexture so žiarou
static var _blob_tex: Texture2D

var state: Callable      ## () -> int (OFF / FAR / NEAR)
var _target: CanvasItem
var _key: String = ""
var _a: float = 0.0
var _t: float = 0.0


## Žiara za obrázkom target (Sprite2D alebo AnimatedSprite2D). Keď sa obrázok nedá použiť, vráti null.
static func attach(target: CanvasItem, state_fn: Callable) -> InteractGlow:
	if not (target is Sprite2D or target is AnimatedSprite2D):
		return null
	var g := InteractGlow.new()
	g._target = target
	g.state = state_fn
	if not g._refresh():
		g.free()
		return null
	target.add_child(g)
	return g


## Žiara bez obrázka: mäkký ovál cez rect (lokálne súradnice parent)
static func blob(parent: Node2D, rect: Rect2, state_fn: Callable) -> InteractGlow:
	var g := InteractGlow.new()
	g.state = state_fn
	if _blob_tex == null:
		var gt := GradientTexture2D.new()
		gt.width = 64
		gt.height = 64
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 0.8))
		gr.set_color(1, Color(1, 1, 1, 0.0))
		gr.add_point(0.55, Color(1, 1, 1, 0.3))
		gt.gradient = gr
		_blob_tex = gt
	g.texture = _blob_tex
	var sz: Vector2 = rect.size + Vector2(PAD, PAD) * 2.0
	g.scale = sz / 64.0
	g.position = rect.get_center()
	parent.add_child(g)
	return g


func _ready() -> void:
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if _target == null else CanvasItem.TEXTURE_FILTER_NEAREST
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	self_modulate = Color(COLOR, 0.0)


func _process(delta: float) -> void:
	_t += delta
	if not state.is_valid():
		queue_free()   # majiteľ (InteractSpot, dvere…) zmizol
		return
	var s: int = state.call()
	var want: float = 0.0
	match s:
		FAR: want = FAR_A + FAR_PULSE * (0.5 + 0.5 * sin(_t * 2.2))
		NEAR: want = NEAR_A + 0.05 * sin(_t * 5.0)
	_a = move_toward(_a, want, FADE * delta * maxf(0.3, absf(want - _a) * 3.0))
	self_modulate = Color(COLOR, _a)
	visible = _a > 0.005
	if visible and _target:
		_refresh()   # zmenila sa snímka (otvorené dvere…) → iná silueta (z cache)


## Prevezme aktuálnu snímku cieľa (a jej žiaru z cache). false = obrázok sa nedá použiť.
func _refresh() -> bool:
	var tex: Texture2D
	var region := Rect2()
	var cen := true
	var off := Vector2.ZERO
	var fh := false
	var fv := false
	if _target is Sprite2D:
		var s := _target as Sprite2D
		tex = s.texture
		if tex == null:
			return false
		region = Rect2(Vector2.ZERO, tex.get_size())
		if s.region_enabled:
			region = s.region_rect
		elif s.hframes * s.vframes > 1:
			var fs: Vector2 = tex.get_size() / Vector2(s.hframes, s.vframes)
			region = Rect2(Vector2(s.frame_coords) * fs, fs)
		cen = s.centered
		off = s.offset
		fh = s.flip_h
		fv = s.flip_v
	else:
		var a := _target as AnimatedSprite2D
		if a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
			return false
		tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		if tex == null:
			return false
		region = Rect2(Vector2.ZERO, tex.get_size())
		cen = a.centered
		off = a.offset
		fh = a.flip_h
		fv = a.flip_v
	if region.size.x * region.size.y > MAX_PIXELS or region.size.x < 1 or region.size.y < 1:
		return false
	var key: String = "%d|%s" % [tex.get_rid().get_id(), region]
	if key != _key:
		var gt: Texture2D = _cache.get(key)
		if gt == null:
			gt = _make_glow(tex, region)
			if gt == null:
				return false
			_cache[key] = gt
		_key = key
		texture = gt
	centered = cen
	offset = off - (Vector2.ZERO if cen else Vector2(PAD, PAD))
	flip_h = fh
	flip_v = fv
	return true


## Silueta obrázka → rozšírená o 1 px a rozmazaná (2× box blur) → biela textúra s priehľadnosťou
static func _make_glow(tex: Texture2D, region: Rect2) -> Texture2D:
	var img: Image = tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	if not (tex is AtlasTexture):
		img = img.get_region(Rect2i(region))
	var w: int = img.get_width()
	var h: int = img.get_height()
	var W: int = w + PAD * 2
	var H: int = h + PAD * 2
	var a := PackedFloat32Array()
	a.resize(W * H)
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.1:
				a[(y + PAD) * W + x + PAD] = 1.0
	# o 1 px hrubšia silueta (aby žiara vyšla aj okolo tenkých vecí – páka, kniha)
	var d := PackedFloat32Array()
	d.resize(W * H)
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var i: int = y * W + x
			if a[i] > 0.0 or a[i - 1] > 0.0 or a[i + 1] > 0.0 or a[i - W] > 0.0 or a[i + W] > 0.0:
				d[i] = 1.0
	for _pass in 2:
		d = _box(d, W, H, 1, 2)
		d = _box(d, W, H, W, 2)
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			out.set_pixel(x, y, Color(1, 1, 1, clampf(d[y * W + x] * 1.4, 0.0, 1.0)))
	return ImageTexture.create_from_image(out)


## Jeden smer box blur (step 1 = vodorovne, step W = zvislo), polomer r
static func _box(src: PackedFloat32Array, W: int, H: int, step: int, r: int) -> PackedFloat32Array:
	var dst := PackedFloat32Array()
	dst.resize(W * H)
	var n: float = 2.0 * r + 1.0
	var horizontal: bool = step == 1
	var lines: int = H if horizontal else W
	var length: int = W if horizontal else H
	for l in lines:
		var base: int = l * W if horizontal else l
		var sum: float = 0.0
		for k in range(-r, r + 1):
			var kk: int = clampi(k, 0, length - 1)
			sum += src[base + kk * step]
		for p in length:
			dst[base + p * step] = sum / n
			var out_i: int = clampi(p - r, 0, length - 1)
			var in_i: int = clampi(p + r + 1, 0, length - 1)
			sum += src[base + in_i * step] - src[base + out_i * step]
	return dst
