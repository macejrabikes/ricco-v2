extends Control
## Ukazovateľ spomalenia (duch Dona) – tenký prúžok nad počítadlom nábojov.
## Štýl sa riadi GameSettings.hud_style (noir lístok / minimal), farba je „duchovská“ modrá.
## Keď sa spomalenie nedá zapnúť (málo), prúžok je tmavší; počas spomalenia jemne pulzuje.

const GHOST := Color8(120, 220, 245)
const GHOST_D := Color8(52, 104, 128)
const PAPER := Color8(232, 222, 196)
const PAPER_DD := Color8(196, 184, 156)
const INK := Color8(22, 20, 18)
const DIM := Color8(60, 60, 66)

@export var ammo_panel_path: NodePath = ^"../AmmoPanel"

var value: float = 1.0
var active: bool = false
var min_to_start: float = 0.15
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var player := get_tree().get_first_node_in_group(&"player")
	if player and player.get(&"focus"):
		player.focus.changed.connect(_on_focus_changed)
		min_to_start = player.focus.min_to_start


func _on_focus_changed(v: float, a: bool) -> void:
	value = v
	active = a


func _process(delta: float) -> void:
	_time += delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	var panel := get_node_or_null(ammo_panel_path) as Control
	if panel:
		var noir: bool = GameSettings.hud_style == GameSettings.HudStyle.NOIR
		var w: float = (panel.size.x - 2.0) if noir else 40.0
		size = Vector2(w, 7.0 if noir else 3.0)
		position = Vector2(panel.position.x + panel.size.x - (2.0 if noir else 0.0) - size.x, panel.position.y - size.y - 3.0)
	queue_redraw()


func _draw() -> void:
	var low: bool = value < min_to_start and not active
	var fill_col: Color = GHOST_D if low else GHOST
	if active:
		fill_col = fill_col.lerp(Color.WHITE, 0.25 + 0.25 * sin(_time * 12.0))
	if GameSettings.hud_style == GameSettings.HudStyle.NOIR:
		draw_rect(Rect2(Vector2(2, 2), size), Color(0, 0, 0, 0.45))   # tieň
		draw_rect(Rect2(Vector2.ZERO, size), PAPER)
		draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), INK)
		draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), PAPER_DD)
		draw_rect(Rect2(3, 3, floorf((size.x - 6) * value), size.y - 6), fill_col)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), DIM)
		draw_rect(Rect2(0, 0, floorf(size.x * value), size.y), fill_col)
