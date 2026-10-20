extends Control
## Zásoba jedla v HUD – 3 políčka naľavo od nábojov (vpravo dole), v nich obrázky nesených jedál (Food.carried)
## a pod prvým kláves na zjedenie (akcia „eat“, predvolene V). Nové jedlo v políčku poskočí, zjedené blikne.
## Godot docs: classes/class_control (_draw), classes/class_canvasitem (draw_texture, draw_rect)

const SLOT := 18.0
const GAP := 2.0
const MARGIN := Vector2(8, 8)
const AMMO_GAP := 6.0
const FONT := preload("res://ui/fonts/tiny5.ttf")
const BG := Color(0.07, 0.06, 0.08, 0.82)
const EDGE := Color8(199, 153, 71)
const EDGE_DIM := Color8(110, 90, 60)
const CREAM := Color8(245, 235, 209)

@export var ammo_panel_path: NodePath = ^"../AmmoPanel"

var _shown: Array[StringName] = []
var _pop: Array[float] = [1.0, 1.0, 1.0]
var _flash: Array[float] = [1.0, 1.0, 1.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(SLOT * Food.MAX_CARRIED + GAP * (Food.MAX_CARRIED - 1), SLOT + 9)
	var player := get_tree().get_first_node_in_group(&"player")
	if player and player.has_signal(&"food_changed"):
		player.food_changed.connect(_sync)
	_shown = Food.carried.duplicate()


## Porovná zobrazené so zásobou: pribudnuté poskočí, zjedené (vždy prvé) blikne
func _sync() -> void:
	var now: Array[StringName] = Food.carried.duplicate()
	if now.size() > _shown.size():
		_pop[mini(now.size(), Food.MAX_CARRIED) - 1] = 0.0
	elif now.size() < _shown.size():
		_flash[0] = 0.0
	_shown = now


func _process(delta: float) -> void:
	for i in Food.MAX_CARRIED:
		_pop[i] = minf(_pop[i] + delta / 0.3, 1.0)
		_flash[i] = minf(_flash[i] + delta / 0.3, 1.0)
	if _shown.size() != Food.carried.size():
		_sync()   # zmena mimo signálu (nový level, reset)
	var vp: Vector2 = get_viewport_rect().size
	var right: float = vp.x - MARGIN.x
	var ammo := get_node_or_null(ammo_panel_path) as Control
	if ammo and ammo.visible:
		right = ammo.position.x - AMMO_GAP
	position = Vector2(right - size.x, vp.y - MARGIN.y - size.y).floor()
	queue_redraw()


func _draw() -> void:
	for i in Food.MAX_CARRIED:
		var r := Rect2(Vector2(i * (SLOT + GAP), 0), Vector2(SLOT, SLOT))
		draw_rect(r, BG)
		var full: bool = i < mini(_shown.size(), Food.MAX_CARRIED)
		var edge: Color = EDGE if full else EDGE_DIM
		if _flash[i] < 1.0 and i == 0:
			edge = edge.lerp(Color.WHITE, 1.0 - _flash[i])
			draw_rect(r.grow(-1), Color(1, 1, 1, 0.4 * (1.0 - _flash[i])))
		draw_rect(r, edge, false, 1.0)
		if not full:
			continue
		var tex := Food.texture(_shown[i])
		var k: float = _pop[i]
		var s: float = 1.0 + 0.4 * sin(k * PI) * (1.0 - k)   # poskočí a zmenší sa späť
		var tsize: Vector2 = Vector2(16, 16) * s
		draw_texture_rect(tex, Rect2((r.get_center() - tsize / 2.0).round(), tsize.round()), false)
	# kláves pod prvým políčkom
	var key: String = KeyBindings.short(&"eat")
	draw_string_outline(FONT, Vector2(1, SLOT + 8), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 4, Color8(14, 10, 12))
	draw_string(FONT, Vector2(1, SLOT + 8), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, CREAM)
