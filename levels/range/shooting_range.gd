extends Node2D
## Strelnica (namiesto starej debug room) – krytá strelnica klubu Fontana Gun Club (tehlová hala, lampy, drôty s terčmi).
## Vľavo zbrojnica: pri zbrani F = vezmi ju (bočná sa vymení, hlavné Ricco nosí obe). Náboje sú obmedzené ako v leveloch –
## keď dôjdu, F pri zbrani, ktorú Ricco už má, ju doplní (REFILL).
## Pri skrinke s pákou F = ďalší režim. Tabuľa ukazuje skóre, zásahy, čas a režim.
## Režimy (MODES): plechovky a fľaše → pohyblivé terče (vozík, háky žeriavu) → vyskakovacie terče na 30 s (najlepšie skóre)
##   → figuríny (gangstri stoja, nestrieľajú) → gangstri (naozaj strieľajú; keď Ricco padne, scéna sa načíta znova v tom istom režime).
## Terče: props/range/range_target.gd, plechovky/fľaše props/target/target.tscn. Scénu (prostredie + značky miest) generuje
## tools/build_range.gd – terče a gangstrov sem pridáva tento skript podľa značiek (Spots/…).
## Godot docs: classes/class_label, classes/class_tween, classes/class_node (groups, call_group)

const MODES: Array[String] = ["CANS & BOTTLES", "MOVING TARGETS", "POP-UP 30 SEC", "DUMMIES", "GANGSTERS"]
const RANGE_MAP := Rect2i(-32, -300, 1376, 370)   ## hranice kamery (px) – hore je strop haly
const ROUND_TIME := 30.0
const FONT := preload("res://ui/fonts/tiny5.ttf")
const TARGET := preload("res://props/target/target.tscn")
const BOTTLES := preload("res://levels/range/art/bottles.png")
const LOADOUT: Array[WeaponData] = [preload("res://weapons/pistol/pistol.tres"), preload("res://weapons/tommy/tommy.tres"),
		preload("res://weapons/lupara/lupara.tres")]
const BOTTLE_COLORS: Array[Color] = [Color(0.3, 0.62, 0.32), Color(0.6, 0.36, 0.2), Color(0.72, 0.86, 0.9)]

static var mode: int = 0      ## prežije načítanie scény po smrti
static var best: int = 0      ## najlepšie skóre vo vyskakovacích terčoch

var player: Node2D
var score: int = 0
var hits: int = 0
var _live: Node2D              ## terče a gangstri aktuálneho režimu
var _gangsters: Array = []     ## [gangster, miesto, figurína?]
var _respawn: Array = []       ## [čas, miesto, figurína?]
var _popups: Array[RangeTarget] = []
var _round_t: float = -1.0     ## vyskakovacie: zostávajúci čas (−1 = nebeží)
var _countdown: float = 0.0
var _pop_t: float = 0.0
var _clock: float = 0.0
var _lbl_score: Label
var _lbl_hits: Label
var _lbl_time: Label
var _lbl_mode: Label
var _banner: Label
var _banner_tw: Tween
var _switch: Sprite2D
var _light: Sprite2D           ## svetlo strelnice: zelená = strieľaj, červená = odpočítavanie / koniec kola
var _rack_spot: InteractSpot
var _rack_guns: Array = []     ## [x, WeaponData, Sprite2D]


func _ready() -> void:
	add_to_group(&"shooting_range")
	process_physics_priority = -100   # figurínam vráti „passive“ skôr, ako sa pohnú
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var pcam := player.get_node(^"PhantomCamera2D")
	pcam.limit_left = RANGE_MAP.position.x
	pcam.limit_top = RANGE_MAP.position.y
	pcam.limit_right = RANGE_MAP.end.x
	pcam.limit_bottom = RANGE_MAP.end.y
	var help := get_node_or_null(^"HUD/ControlsHelp") as Control
	if help:
		help.visible = false
	player.set_loadout(LOADOUT.duplicate())
	player.focus.unlocked = true
	player.dark_area = false
	var spawn := get_node_or_null(^"Spawn") as Node2D
	if spawn:
		player.global_position = spawn.global_position
	pcam.teleport_position.call_deferred()
	_live = Node2D.new()
	_live.name = "Live"
	add_child(_live)
	_build_board()
	_hook_rack()
	_switch = get_node_or_null(^"ModeSwitch") as Sprite2D
	_light = get_node_or_null(^"RangeLight") as Sprite2D
	var sw := get_node_or_null(^"ModeSwitch/Spot") as InteractSpot
	if sw:
		sw.used.connect(_next_mode)
	Sfx.loop(&"rain_inside", self, Vector2.INF, -10.0)   # dážď bubnuje na strechu haly
	Sfx.music(&"night_cafe")
	_apply_mode(false)


# ---------------------------------------------------------------- zbrojnica

func _hook_rack() -> void:
	var rack := get_node_or_null(^"Rack")
	if rack == null:
		return
	for g in rack.get_children():
		if g is Sprite2D and g.has_meta(&"weapon"):
			_rack_guns.append([g.global_position.x, load(g.get_meta(&"weapon")), g])
	_rack_spot = rack.get_node_or_null(^"Spot") as InteractSpot
	if _rack_spot:
		_rack_spot.used.connect(func(): _take_weapon(_nearest_gun()))


## Má Ricco túto zbraň a chýbajú mu do nej náboje?
func _needs_refill(w: WeaponData) -> bool:
	var i: int = player.loadout.find(w)
	if i < 0:
		return false
	var a: Array = [player.ammo_in_mag, player.ammo_reserve] if i == player.weapon_index else player.weapon_ammo[i]
	return a[0] < w.mag_size or a[1] < w.reserve_start


## Zbraň na doske najbližšie k Riccovi (vodorovne)
func _nearest_gun() -> WeaponData:
	var best_w: WeaponData = null
	var best_d := INF
	for e in _rack_guns:
		var d: float = absf(e[0] - player.global_position.x)
		if d < best_d:
			best_d = d
			best_w = e[1]
	return best_w


func _take_weapon(w: WeaponData) -> void:
	if w == null:
		return
	if player.loadout.has(w):
		var refilled: bool = player.refill_weapon(w)
		player.give_weapon(w)          # už ju má – doplní náboje a vezme ju do ruky
		if refilled:
			_say("REFILL " + w.name.to_upper())
			return
	elif player.pickup_mode(w) == 1:   # Ricco.Pickup.TAKE (voľné miesto)
		player.pick_up_weapon(w, w.mag_size + w.reserve_start)
	else:
		player.swap_weapon(w, w.mag_size + w.reserve_start)   # stará bočná ostane na stene (tá je tam stále)
	_say(w.name.to_upper())


# ---------------------------------------------------------------- režimy

func _next_mode() -> void:
	mode = (mode + 1) % MODES.size()
	Sfx.play(&"slot_open", Vector2.INF, -4.0, 0.05)
	_apply_mode(true)


func _apply_mode(announce: bool) -> void:
	if _switch:
		_switch.frame = mode % 2
	for c in _live.get_children():
		c.queue_free()
	_gangsters.clear()
	_respawn.clear()
	_popups.clear()
	_round_t = -1.0
	score = 0
	hits = 0
	_clock = 0.0
	match mode:
		0:
			_spawn_cans()
		1:
			for m in _spots(&"RailSpots"):
				_paper(m, RangeTarget.Motion.RAIL)
			for m in _spots(&"SwingSpots"):
				_paper(m, RangeTarget.Motion.SWING)
			for m in _spots(&"PaperSpots"):
				_paper(m, RangeTarget.Motion.STATIC)
		2:
			for m in _spots(&"PopupSpots"):
				var t := RangeTarget.new()
				t.kind = RangeTarget.Kind.POPUP
				t.position = m.position
				_live.add_child(t)
				_popups.append(t)
			_countdown = 3.0
			_say("GET READY")
		3, 4:
			for m in _spots(&"GangsterSpots"):
				_spawn_gangster(m, mode == 3)
	if announce:
		_say(MODES[mode])
	_update_board()


func _spots(group: StringName) -> Array:
	var n := get_node_or_null(NodePath("Spots/" + String(group)))
	return n.get_children() if n else []


func _spawn_cans() -> void:
	var i := 0
	for m in _spots(&"CanSpots"):
		var t: Node2D = TARGET.instantiate()
		t.position = m.position
		if i % 2 == 1:   # každá druhá je fľaša
			var k: int = (i / 2) % 3
			var s := t.get_node(^"Sprite2D") as Sprite2D
			s.texture = BOTTLES
			s.hframes = 3
			s.frame = k
			s.position = Vector2(0, -7)
			t.set(&"debris_color", BOTTLE_COLORS[k])
			t.set(&"break_sound", &"glass_break")
			t.set(&"points", 15)
		t.set(&"respawn_time", 1.5)
		_live.add_child(t)
		i += 1


func _paper(m: Node2D, motion: RangeTarget.Motion) -> void:
	var t := RangeTarget.new()
	t.motion = motion
	t.position = m.position
	for k in [&"span", &"speed", &"rope", &"swing_deg", &"swing_period"]:
		if m.has_meta(k):
			t.set(k, m.get_meta(k))
	_live.add_child(t)


## Gangster na mieste m. dummy = figurína: stojí, nestrieľa, Ricca si nevšíma (ani po zásahu)
func _spawn_gangster(m: Node2D, dummy: bool) -> void:
	var scene: String = m.get_meta(&"scene", "gangster_coppola")
	var g: Node2D = load("res://characters/gangster/%s.tscn" % scene).instantiate()
	g.set(&"start_facing", -1.0)
	g.set(&"respawn_time", 0.0)
	g.set(&"stationary", true)
	if dummy:
		g.set(&"passive", true)
	else:
		g.set(&"sight_range", 420.0)
		g.set(&"look_back", Vector2.ZERO)
	g.position = m.position
	_live.add_child(g)
	_gangsters.append([g, m, dummy])


# ---------------------------------------------------------------- beh

## Gangster.State: AIM 2, SHOOT 3, COOLDOWN 4, CHASE 5, WINDUP 6, PUNCH 7 → figurína sa vráti do IDLE 1 (zásah ju len zatrasie)
const DUMMY_BUSY: Array[int] = [2, 3, 4, 5, 6, 7]

func _physics_process(_delta: float) -> void:
	for e in _gangsters:
		if e[2] and is_instance_valid(e[0]):
			e[0].set(&"passive", true)
			if e[0].get(&"state") in DUMMY_BUSY:
				e[0].set(&"state", 1)
				e[0].set(&"shots_left", 0)


func _process(delta: float) -> void:
	if player == null:
		return
	if _rack_spot and not _rack_guns.is_empty():
		var near := _nearest_gun()
		_rack_spot.verb = ("REFILL " if _needs_refill(near) else "TAKE ") + near.name.to_upper()
		var lit: bool = _rack_spot.get(&"_inside")   # pri doske sa najbližšia zbraň rozsvieti
		for e in _rack_guns:
			e[2].modulate = Color(1.6, 1.5, 1.2) if lit and e[1] == near else Color.WHITE
	_clock += delta
	_tick_gangsters(delta)
	if mode == 2:
		_tick_popups(delta)
	_update_board()
	if _light:
		_light.frame = 1 if mode == 2 and _round_t <= 0.0 else 0


func _tick_gangsters(delta: float) -> void:
	for i in range(_gangsters.size() - 1, -1, -1):
		var e: Array = _gangsters[i]
		var g = e[0]
		if not is_instance_valid(g) or g.get(&"state") == 10:   # Gangster.State.DEAD
			_respawn.append([3.5, e[1], e[2]])
			_gangsters.remove_at(i)
			if is_instance_valid(g):
				add_score(100, g.global_position + Vector2(0, -70))
	for i in range(_respawn.size() - 1, -1, -1):
		_respawn[i][0] -= delta
		if _respawn[i][0] <= 0.0:
			_spawn_gangster(_respawn[i][1], _respawn[i][2])
			_respawn.remove_at(i)


func _tick_popups(delta: float) -> void:
	if _countdown > 0.0:
		var before: int = ceili(_countdown)
		_countdown -= delta
		if ceili(_countdown) != before and _countdown > 0.0:
			_say(str(ceili(_countdown)))
			Sfx.ui(&"ui_move")
		if _countdown <= 0.0:
			_round_t = ROUND_TIME
			score = 0
			hits = 0
			_say("GO!")
			Sfx.ui(&"ui_select")
		return
	if _round_t < 0.0:
		return
	_round_t -= delta
	_pop_t -= delta
	if _pop_t <= 0.0:
		_pop_t = randf_range(0.45, 0.9)
		var down := _popups.filter(func(t: RangeTarget) -> bool: return not t.up)
		if not down.is_empty():
			down[randi() % down.size()].pop(randf_range(1.1, 1.8))
	if _round_t <= 0.0:
		_round_t = -1.0
		for t in _popups:
			if t.up:
				t.pop(0.01)
		var rec := score > best
		best = maxi(best, score)
		_say("NEW RECORD! %d" % score if rec else "TIME! SCORE %d" % score)
		Sfx.play(&"church_bell", Vector2.INF, -10.0, 0.0)
		_countdown = 6.0   # po chvíli ďalšie kolo (odpočítavanie od 3 – prvé 3 s je pauza)


## Volajú terče (call_group „shooting_range“)
func add_score(pts: int, at: Vector2) -> void:
	if mode == 2 and _round_t < 0.0:
		return   # mimo kola sa nepočíta
	score += pts
	hits += 1
	var l := _label(8, Color8(255, 214, 90) if pts < 50 else Color8(255, 120, 90))
	l.text = "+%d" % pts
	l.z_index = 50
	add_child(l)
	l.reset_size()
	l.position = (at - Vector2(l.size.x / 2.0, 0)).round()
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 18.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- tabuľa a nápisy

func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	l.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	l.add_theme_constant_override(&"outline_size", 4)
	return l


func _build_board() -> void:
	var board := get_node_or_null(^"Scoreboard") as Node2D
	if board:
		var chalk := Color8(232, 232, 220)
		var y := 8
		for n in ["_lbl_mode", "_lbl_score", "_lbl_hits", "_lbl_time"]:
			var l := _label(8, Color8(240, 200, 90) if n == "_lbl_mode" else chalk)
			l.remove_theme_constant_override(&"outline_size")
			l.position = Vector2(10, y)
			board.add_child(l)
			set(n, l)
			y += 12
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_banner = _label(16, Color8(255, 214, 90))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(0, 70)
	_banner.size = Vector2(640, 24)
	_banner.modulate.a = 0.0
	layer.add_child(_banner)


func _update_board() -> void:
	if _lbl_mode == null:
		return
	_lbl_mode.text = "%d/%d  %s" % [mode + 1, MODES.size(), MODES[mode]]
	_lbl_score.text = "SCORE  %d" % score + ("     BEST %d" % best if mode == 2 else "")
	_lbl_hits.text = "HITS   %d" % hits
	var t: float = _round_t if mode == 2 and _round_t >= 0.0 else (ROUND_TIME if mode == 2 else _clock)
	_lbl_time.text = "TIME   %d:%02d" % [int(t) / 60, int(t) % 60]


func _say(t: String) -> void:
	if _banner == null:
		return
	_banner.text = t
	if _banner_tw:
		_banner_tw.kill()
	_banner.modulate.a = 1.0
	_banner_tw = create_tween()
	_banner_tw.tween_interval(1.0)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.4)
