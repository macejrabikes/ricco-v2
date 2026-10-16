class_name SettingsPreview
extends Control
## Náhľad nastavenia vedľa menu – ukáže sa, keď je vybraná (alebo myšou ukázaná) položka:
##   CROSSHAIR / CROSSHAIR SIZE – ako vyzerá zameriavač (v pomere k Riccovi),
##   WANTED POSTER – plagát so zdravím v danej veľkosti,
##   RETRO FILTER – dva malé obrázky vedľa seba: bez filtra a s filtrom.

const BRASS := Color8(199, 153, 71)
const CREAM := Color8(245, 235, 209)
const DIM := Color8(150, 140, 120)
const PORTRAIT: Texture2D = preload("res://ui/hud_wanted_portrait.png")
const RETRO_OFF: Texture2D = preload("res://ui/pause_menu/preview_retro_off.png")
const RETRO_ON: Texture2D = preload("res://ui/pause_menu/preview_retro_on.png")
const RICCO: Texture2D = preload("res://characters/ricco/sprites/idle_hurt.png")
const BOX := Vector2(142, 92)

var key: String = ""
var index: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # ostré pixely aj pri 1.5×
	size = BOX
	visible = false


## Ukáž náhľad pre nastavenie key s možnosťou index (prázdny key = skryť)
func show_for(key_: String, index_: int) -> void:
	key = key_
	index = index_
	visible = key != ""
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, BOX), Color(0.05, 0.04, 0.05, 0.92))
	draw_rect(Rect2(Vector2.ZERO, BOX), BRASS, false, 1.0)
	var font: Font = get_theme_default_font()
	match key:
		"CROSSHAIR", "CROSSHAIR SIZE":
			var style: int = index if key == "CROSSHAIR" else GameSettings.crosshair
			var sz: int = index if key == "CROSSHAIR SIZE" else GameSettings.crosshair_size
			var tname: String = "reticle_" + GameSettings.CROSSHAIRS[style].to_lower() + ("_tiny" if sz == 0 else "")
			var tex: Texture2D = _tex(tname)
			# pozadie ako tehlová stena + Ricco pre porovnanie veľkosti
			draw_rect(Rect2(6, 6, BOX.x - 12, BOX.y - 22), Color8(70, 34, 32))
			for y in range(6, int(BOX.y) - 16, 6):
				draw_line(Vector2(6, y), Vector2(BOX.x - 6, y), Color8(54, 26, 26))
			draw_texture_rect_region(RICCO, Rect2(8, BOX.y - 16 - 48, 48, 48), Rect2(8, 8, 48, 48))
			var k: float = GameSettings.CROSSHAIR_SCALES[sz]
			var ts: Vector2 = tex.get_size() * k
			draw_texture_rect(tex, Rect2((Vector2(78, 40) - ts / 2.0).round(), ts), false)
			_caption(font, GameSettings.CROSSHAIRS[style] + "  " + GameSettings.CROSSHAIR_SIZES[sz])
		"WANTED POSTER":
			var s: float = GameSettings.PORTRAIT_SCALES[index]
			var ps := Vector2(33, 30) * s
			var o := Vector2(BOX.x - 8 - ps.x, BOX.y - 16 - ps.y)
			draw_rect(Rect2(o + Vector2(2, 2), ps), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(o, ps), Color8(214, 190, 140))
			draw_rect(Rect2(o, ps), Color8(120, 92, 56), false, 1.0)
			draw_texture_rect(PORTRAIT, Rect2(o + Vector2(2, 2) * s, Vector2(29, 23) * s), false)
			draw_rect(Rect2(o + Vector2(2, 27) * s, Vector2(29, 1) * s), Color8(176, 32, 30))
			_caption(font, "%sx" % str(s).trim_suffix(".0"))
		"RETRO FILTER":
			# dva obrázky vedľa seba: bez filtra / s filtrom (vybraný má zlatý rám)
			for i in 2:
				var at := Vector2(6 + i * 66, 22)
				draw_texture(RETRO_OFF if i == 0 else RETRO_ON, at)
				draw_rect(Rect2(at - Vector2.ONE, Vector2(66, 34)), BRASS if index == i else DIM, false, 1.0)
				draw_string(font, at + Vector2(0, 46), "OFF" if i == 0 else "ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, CREAM if index == i else DIM)


var _texs: Dictionary = {}

## Obrázok zameriavača ako ImageTexture (kópia dát) – rovnaký súbor používa aj kurzor
func _tex(tname: String) -> Texture2D:
	if not _texs.has(tname):
		var src: Texture2D = load("res://ui/cursor/%s.png" % tname)
		_texs[tname] = ImageTexture.create_from_image(src.get_image())
	return _texs[tname]


func _caption(font: Font, t: String) -> void:
	var w: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(font, Vector2(roundf((BOX.x - w) / 2.0), BOX.y - 5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, CREAM)
