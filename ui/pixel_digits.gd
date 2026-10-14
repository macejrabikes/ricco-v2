class_name PixelDigits
## Pixelové číslice 4×6 z ui/hud_ammo.png – spoločné pre celý HUD (náboje, HP…).
## Volá sa z _draw() ľubovoľného CanvasItem: PixelDigits.draw_number(self, 42, pos, farba)

const ATLAS: Texture2D = preload("res://ui/hud_ammo.png")
const GLYPHS := "0123456789/x"
const GLYPH := Vector2(4, 6)
const OUTLINE_OFFSETS: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1)]


static func text_width(text: String, scale: int = 1) -> float:
	return text.length() * (GLYPH.x + 1.0) * scale - scale


static func number_width(n: int, scale: int = 1) -> float:
	return text_width(str(n), scale)


## text môže obsahovať číslice, '/' a 'x'
static func draw_text(ci: CanvasItem, text: String, pos: Vector2, color: Color, scale: int = 1, outline: bool = true) -> void:
	for i in text.length():
		draw_glyph(ci, text[i], pos + Vector2(i * (GLYPH.x + 1.0) * scale, 0), color, scale, outline)


static func draw_number(ci: CanvasItem, n: int, pos: Vector2, color: Color, scale: int = 1, outline: bool = true) -> void:
	draw_text(ci, str(n), pos, color, scale, outline)


static func draw_glyph(ci: CanvasItem, ch: String, pos: Vector2, color: Color, scale: int = 1, outline: bool = true) -> void:
	var idx: int = GLYPHS.find(ch)
	if idx < 0:
		return
	var src := Rect2(Vector2(idx * 5.0, 0), GLYPH)
	var dst := Rect2(pos, GLYPH * scale)
	if outline:
		for o in OUTLINE_OFFSETS:
			ci.draw_texture_rect_region(ATLAS, Rect2(dst.position + o, dst.size), src, Color(0, 0, 0, 0.9))
	ci.draw_texture_rect_region(ATLAS, dst, src, color)
