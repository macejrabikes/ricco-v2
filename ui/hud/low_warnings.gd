class_name LowWarnings
extends Control
## Varovania, keď ide do tuhého:
##  - málo zdravia (≤ LOW_HEALTH kúskov pizze): okraje obrazovky pulzujú na červeno ako tlkot srdca,
##    a keď má Ricco jedlo, ukáže sa tabuľka [V] EAT
##  - prázdny zásobník: [R] RELOAD; nič v zásobe: OUT OF AMMO a ktorými klávesmi zmeniť zbraň
## Tabuľky sú rovnaké ako nápovedy pri veciach (world/fx/interact_hint.gd), dole v strede obrazovky.

const LOW_HEALTH := 2
const FONT := preload("res://ui/fonts/tiny5.ttf")
const Y_FROM_BOTTOM := 52.0

var _vignette: TextureRect
var _row: HBoxContainer
var _eat: InteractHint
var _reload: InteractHint
var _empty: InteractHint
var _t: float = 0.0
var _beat: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette = TextureRect.new()
	var g := GradientTexture2D.new()
	g.width = 128
	g.height = 72
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.05, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(0.6, 0.0, 0.02, 0.0))
	gr.set_color(1, Color(0.6, 0.0, 0.02, 0.55))
	gr.add_point(0.72, Color(0.6, 0.0, 0.02, 0.0))
	g.gradient = gr
	_vignette.texture = g
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 6)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_eat = InteractHint.new()
	_reload = InteractHint.new()
	_empty = InteractHint.new()
	for h in [_eat, _reload, _empty]:
		h.visible = false
		_row.add_child(h)


func _process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group(&"player")
	var alive: bool = p != null and int(p.get(&"state")) != 3 and not bool(p.get(&"in_cutscene"))
	var hp: int = int(p.get(&"health")) if p else 99
	var low: bool = alive and hp > 0 and hp <= LOW_HEALTH
	# tlkot srdca: dva rýchle údery a pauza (rýchlejšie pri 1 kúsku)
	var period: float = 0.8 if hp <= 1 else 1.1
	_beat = fmod(_t, period) / period
	var pulse: float = maxf(_bump(_beat, 0.0), _bump(_beat, 0.22) * 0.7)
	var want: float = (0.3 + 0.7 * pulse) if low else 0.0
	_vignette.modulate.a = move_toward(_vignette.modulate.a, want, delta * 4.0)

	var show_eat: bool = alive and hp <= LOW_HEALTH + 1 and hp < int(p.get(&"max_health")) \
			and not Food.carried.is_empty() and not bool(p.get(&"eating"))
	_eat.visible = show_eat
	if show_eat:
		_eat.set_hint([KeyBindings.short(&"eat")], "EAT")
	var w = p.get(&"weapon") if p else null
	var armed: bool = alive and w != null and not bool(p.get(&"holstered"))
	var mag: int = int(p.get(&"ammo_in_mag")) if p else 1
	var reserve: int = int(p.get(&"ammo_reserve")) if p else 1
	var reloading: bool = bool(p.get(&"reloading")) if p else false
	_reload.visible = armed and mag == 0 and reserve > 0 and not reloading
	if _reload.visible:
		_reload.set_hint([KeyBindings.short(&"reload")], "RELOAD")
	_empty.visible = armed and mag == 0 and reserve == 0 and not reloading
	if _empty.visible:
		_empty.set_hint([KeyBindings.short(&"weapon_1"), KeyBindings.short(&"weapon_2"), KeyBindings.short(&"weapon_3")], "OUT OF AMMO")
	_row.reset_size()
	var vp: Vector2 = get_viewport_rect().size
	_vignette.position = Vector2.ZERO
	_vignette.size = vp
	_row.position = Vector2((vp.x - _row.size.x) / 2.0, vp.y - Y_FROM_BOTTOM).floor()


## Krátky úder okolo bodu at (0–1 v perióde)
func _bump(x: float, at: float) -> float:
	var d: float = x - at
	if d < 0.0 or d > 0.18:
		return 0.0
	return sin(d / 0.18 * PI)
