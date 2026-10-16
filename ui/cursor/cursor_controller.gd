class_name CursorController
extends Node
## Vlastný kurzor myši (Godot docs: classes/class_input – set_custom_mouse_cursor).
## - menu a pauza: rukavica, pri kliknutí sa prst stlačí a okolo špičky odskočia čiarky,
## - v hre: zameriavač podľa Settings (CROSS / RING / SIGHTS / GHOST, veľkosť SMALL–LARGE),
##   pri každom výstrele na chvíľu „odskočí“ (snímok *_kick),
## - zameriavač je aj bez zbrane (prológ levelu 1) – myšou sa mieri hod klobúkom.
## Obrázky sa zväčšia na rovnaký celý násobok ako hra (640×360 → okno), takže pixely ostanú ostré.
## Je to hardvérový kurzor – nemešká za myšou ako sprite.

@export var in_game: bool = true   ## false = úvodné menu (vždy rukavica)

const DIR := "res://ui/cursor/"
const GLOVE_HOTSPOT := Vector2(5, 1)    ## špička prsta v glove*.png
const RETICLE_CENTER := Vector2(10, 10) ## stred v reticle_*.png (21×21)
const TINY_CENTER := Vector2(5, 5)      ## stred v reticle_*_tiny.png (11×11)
const KICK_TIME := 0.07                 ## s – ako dlho je zameriavač po výstrele „roztiahnutý“
const CLICK_FX_TIME := 0.1              ## s – čiarky okolo prsta po kliknutí
const MAX_CURSOR := 256                 ## px – väčší kurzor systém nedovolí

var _kick: float = 0.0
var _click_fx: float = 0.0
var _pressed: bool = false
var _current: String = ""
var _cache: Dictionary = {}   ## "meno@násobok" → Image
var _player: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # beží aj v pauze (tam je rukavica)
	GameSettings.ensure_loaded()


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_pressed = mb.pressed
		if mb.pressed:
			_click_fx = CLICK_FX_TIME


func _process(delta: float) -> void:
	_kick -= delta
	_click_fx -= delta
	if in_game and not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player")
		if _player and _player.has_signal(&"shot_fired"):
			_player.shot_fired.connect(func(): _kick = KICK_TIME)

	var px: float = _pixel_scale()
	if _menu_mode():
		var glove: String = "glove_click" if _click_fx > 0.0 else ("glove_press" if _pressed else "glove")
		_use(glove, int(px), GLOVE_HOTSPOT)
	else:
		var tex_name: String = "reticle_" + GameSettings.CROSSHAIRS[GameSettings.crosshair].to_lower()
		if _kick > 0.0:
			tex_name += "_kick"
		var center := RETICLE_CENTER
		if GameSettings.crosshair_size == 0:   # VERY SMALL – polovičné obrázky
			tex_name += "_tiny"
			center = TINY_CENTER
		var k: int = maxi(1, roundi(px * GameSettings.CROSSHAIR_SCALES[GameSettings.crosshair_size]))
		_use(tex_name, k, center)


## Menu, pauza alebo mŕtvy Ricco → rukavica
func _menu_mode() -> bool:
	if not in_game or get_tree().paused:
		return true
	return _player != null and _player.get(&"state") == 3   # Ricco.State.DEAD


## Násobok, ktorým je hra zväčšená do okna (pri PIXEL PERFECT celé číslo, inak zaokrúhlené)
func _pixel_scale() -> float:
	return maxf(1.0, roundf(get_tree().root.get_final_transform().get_scale().x))


func _use(tex_name: String, k: int, hotspot: Vector2) -> void:
	var key := "%s@%d" % [tex_name, k]
	if key == _current:
		return
	var img := _image(tex_name, k)
	if img == null:
		return
	_current = key
	k = int(img.get_width() / float(_image(tex_name, 1).get_width()))   # mohol sa zmenšiť kvôli MAX_CURSOR
	Input.set_custom_mouse_cursor(img, Input.CURSOR_ARROW, hotspot * k + Vector2(k, k) * 0.5)


func _image(tex_name: String, k: int) -> Image:
	var key := "%s@%d" % [tex_name, k]
	if _cache.has(key):
		return _cache[key]
	var tex := load(DIR + tex_name + ".png") as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	while k > 1 and img.get_width() * k > MAX_CURSOR:
		k -= 1
	if k > 1:
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	_cache[key] = img
	return img
