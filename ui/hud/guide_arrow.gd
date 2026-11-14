class_name GuideArrow
extends Control
## „Kam ďalej“: keď sa hráč dlho motá (STUCK_TIME s sa nepriblížil k cieľu aspoň o PROGRESS px), ukáže sa
## mosadzná šípka – na okraji obrazovky smerom k cieľu, alebo (keď je cieľ na obrazovke) poskakujúca nad ním.
## Cieľ berie z ui/hud/objectives.gd. Vypína sa v Settings → HUD → Guide arrow (GameSettings.guide_arrow).

const BRASS := Color8(199, 153, 71)
const DARK := Color8(14, 10, 12)
const STUCK_TIME := 20.0   ## s bez pokroku, kým sa šípka ukáže
const PROGRESS := 48.0     ## px – o toľko sa treba priblížiť, aby sa to rátalo ako pokrok
const EDGE := 18.0         ## px od okraja obrazovky

var _target: Node2D
var _targets_key: String = ""
var _best: float = INF
var _since: float = 0.0
var _check_t: float = 1.0
var _a: float = 0.0
var _t: float = 0.0
var _screen_pos: Vector2
var _on_screen: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	_check_t += delta
	if _check_t >= 0.5:
		_check_t = 0.0
		_pick_target()
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var want: float = 0.0
	if _target and is_instance_valid(_target) and _target.is_inside_tree() and player and GameSettings.guide_arrow \
			and not bool(player.get(&"in_cutscene")) and int(player.get(&"state")) != 3:
		var d: float = player.global_position.distance_to(_target.global_position)
		if d < _best - PROGRESS or _best == INF:
			_best = d
			_since = 0.0
		else:
			_since += delta
		if _since >= STUCK_TIME and d > 40.0:
			want = 1.0
		_screen_pos = _target.get_global_transform_with_canvas().origin
		var vp: Vector2 = get_viewport_rect().size
		_on_screen = Rect2(Vector2.ZERO, vp).grow(-EDGE).has_point(_screen_pos + Vector2(0, -24))
	_a = move_toward(_a, want, delta * 2.0)
	queue_redraw()


func _pick_target() -> void:
	var scene := get_tree().current_scene
	var info: Dictionary = Objectives.current(scene)
	var key: String = "" if info.is_empty() else "%s|%s" % [info["text"], info["targets"]]
	var t: Node2D = null if info.is_empty() else Objectives.find_target(scene, info["targets"], info["cp"])
	if key != _targets_key or t != _target:
		_targets_key = key
		_target = t
		_best = INF   # nový cieľ – čas sa ráta odznova
		_since = 0.0


func _draw() -> void:
	if _a <= 0.01:
		return
	var vp: Vector2 = get_viewport_rect().size
	var pulse: float = 0.75 + 0.25 * sin(_t * 5.0)
	var col := Color(BRASS, _a * pulse)
	var out := Color(DARK, _a * 0.9)
	if _on_screen:   # šípka dolu nad cieľom, poskakuje
		var p: Vector2 = (_screen_pos + Vector2(0, -40 + sin(_t * 6.0) * 3.0)).round()
		_tri(p, Vector2.DOWN, 7.0, col, out)
		return
	var c: Vector2 = vp / 2.0
	var dir: Vector2 = (_screen_pos - c).normalized()
	if dir == Vector2.ZERO:
		return
	# priesečník lúča zo stredu s obdĺžnikom zmenšeným o EDGE
	var half: Vector2 = c - Vector2(EDGE, EDGE)
	var k: float = minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var p: Vector2 = (c + dir * k - dir * sin(_t * 6.0) * 2.0).round()
	_tri(p, dir, 8.0, col, out)


## Trojuholník špičkou v smere dir (s tmavým obrysom, aby bol vidno všade)
func _tri(tip: Vector2, dir: Vector2, s: float, col: Color, out: Color) -> void:
	var side: Vector2 = dir.orthogonal()
	var pts := PackedVector2Array([tip, tip - dir * s * 1.4 + side * s, tip - dir * s * 1.4 - side * s])
	var big := PackedVector2Array([tip + dir * 2.0, tip - dir * (s * 1.4 + 1.5) + side * (s + 2.0), tip - dir * (s * 1.4 + 1.5) - side * (s + 2.0)])
	draw_colored_polygon(big, out)
	draw_colored_polygon(pts, col)
