extends Node2D
## Vežový žeriav na vrchole veže Iron Mikea (kapitola III – časť 9, levels/level3/tower.gd). Stĺp, rameno a kabínu
## kreslí scéna (sprity), tento skript hýbe mačkou po ramene, lanom, hákom a nákladom (všetko v globálnych súradniciach,
## uzol žeriavu je v počiatku). Náklad sa na lane hojdá (kyvadlo poháňané zrýchlením mačky).
## Režimy:
##   SWEEP – cestou hore: nosník na háku zametá 4. poschodie vo výške pása – kto stojí, toho zrazí (1 kúsok pizze),
##           popod neho sa dá prešmyknúť po bruchu; mafiánov na poschodí zmetie tiež
##   RIDE  – boj, 1. fáza: posledný nosník stavby (vlajka, stromček) a na ňom Iron Mike; mačka ho vozí nad Riccom.
##           Klobúk do háku = nosník sa zakolíše, Mike sa chytá (IronMike.lurch)
##   TILT  – popruh praskol (snap): nosník sa nakloní, Mike zletí, o chvíľu nosník spadne na palubu a ostane ležať
##   DROPS – 2. a 3. fáza: žeriavnik vozí sudy s nitami nad Riccom – tieň na palube → sud spadne (falling_load.gd);
##           potom hák spustí dierou v palube dolu po ďalší (refill_x)
## Godot docs: classes/class_line2d, classes/class_tween, classes/class_physicsdirectspacestate2d

enum Mode { IDLE, SWEEP, RIDE, TILT, DROPS }

const ART := "res://levels/level3/art/tower/"
const LOAD := preload("res://world/tower/falling_load.gd")
const SLING_H := 26.0     ## px – od háku po vrch nosníka
const HOOK_H := 18.0
const PEND_G := 900.0     ## „gravitácia“ kyvadla
const SWING_MAX := 0.35

@export var jib_y: float = -1062.0               ## y koľajnice mačky (spodok ramena)
@export var span: Vector2 = Vector2(700, 1460)   ## kade môže mačka ísť (globálne x)
@export var sweep_floor: float = -520.0          ## podlaha poschodia, ktoré zametá
@export var sweep_span: Vector2 = Vector2(790, 1340)
@export var ride_y: float = -880.0               ## vrch nosníka s Mikeom (1. fáza)
@export var ride_max: float = 1300.0             ## px – s Mikeom nejde ďalej na východ (pod ním je diera v palube)
@export var deck_y: float = -780.0               ## paluba vrcholu
@export var refill: Vector2 = Vector2(1240, -690)   ## kam hák spustí dolu po nový sud (diera v palube)
@export var max_speed: float = 80.0
@export var accel: float = 160.0

var mode: Mode = Mode.IDLE
var trolley_x: float = 1000.0
var target_x: float = 1000.0
var hook_y: float = -880.0          ## vrch nákladu
var hook_target_y: float = -880.0
var drops_enabled: bool = false
var mike: Node2D
var ride_point: Marker2D

var _vx: float = 0.0
var _speed: float = 80.0
var swing: float = 0.0
var _swing_v: float = 0.0
var _t: float = 0.0
var _step: int = 0
var _hit_cd: float = 0.0
var _side: float = 1.0
var _loaded: bool = false
var _swept: Array = []

var _trolley: Sprite2D
var _rope: Line2D
var _load: Node2D
var _beam: Sprite2D
var _flag: Sprite2D
var _tree: Sprite2D
var _slings: Line2D
var _hook: Sprite2D
var _kegs: Sprite2D
var _shadow: Sprite2D
var _motor: Node


## Hák ako terč (vrstva 4 – Riccova guľka a klobúk ho trafia)
class HookBody extends StaticBody2D:
	var crane: Node

	func take_hit(_damage: float, dir: Vector2) -> void:
		crane.call(&"_hook_shot", dir, false)

	func hat_hit(_damage: int, dir: Vector2) -> void:
		crane.call(&"_hook_shot", dir, true)


func _ready() -> void:
	add_to_group(&"crane")
	_trolley = _sprite(self, "trolley.png", Vector2(-9, 0), 1)
	_rope = Line2D.new()
	_rope.width = 1.0
	_rope.default_color = Color(0.16, 0.14, 0.16)
	_rope.z_index = -2
	add_child(_rope)
	_load = Node2D.new()
	_load.z_index = -1
	add_child(_load)
	_slings = Line2D.new()
	_slings.width = 1.0
	_slings.default_color = Color(0.2, 0.18, 0.2)
	_load.add_child(_slings)
	_beam = _sprite(_load, "topping_beam.png", Vector2(-64, -1), 0)
	_flag = _sprite(_load, "flag.png", Vector2(46, -33), 0)
	_flag.hframes = 2
	_tree = _sprite(_load, "tree.png", Vector2(-60, -21), 0)
	_kegs = _sprite(_load, "rivet_kegs.png", Vector2(-15, 0), 0)
	_hook = _sprite(_load, "hook.png", Vector2(-6, -SLING_H - HOOK_H), 0)
	ride_point = Marker2D.new()
	_load.add_child(ride_point)
	var hb := HookBody.new()
	hb.crane = self
	hb.collision_layer = 4
	hb.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 18)
	cs.shape = r
	hb.add_child(cs)
	hb.position = Vector2(0, -SLING_H - HOOK_H + 8.0)
	_load.add_child(hb)
	_shadow = Sprite2D.new()
	_shadow.texture = load(ART + "shadow.png")
	_shadow.top_level = true
	_shadow.visible = false
	_shadow.z_index = 3
	add_child(_shadow)
	_show(false, false)
	_motor = Sfx.loop(&"crane_motor", self, Vector2(trolley_x, jib_y), -40.0, &"SFX")
	_place()


func _sprite(parent: Node, file: String, at: Vector2, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(ART + file)
	s.centered = false
	s.position = at
	s.z_index = z
	parent.add_child(s)
	return s


## Čo visí na háku: beam = nosník (top = s vlajkou a stromčekom), inak sud s nitami (ak _loaded)
func _show(beam: bool, top: bool) -> void:
	_beam.visible = beam
	_flag.visible = beam and top
	_tree.visible = beam and top
	_kegs.visible = not beam and _loaded
	var w: float = 50.0 if beam else 12.0
	_slings.visible = beam or _loaded
	_slings.points = PackedVector2Array([Vector2(-w, 0), Vector2(0, -SLING_H), Vector2(w, 0)])


# ---------------------------------------------------------------- režimy (volá level)

func start_sweep() -> void:
	mode = Mode.SWEEP
	_show(true, false)
	hook_y = sweep_floor - 38.0   # spodok nosníka 28 px nad podlahou – šmyk (24 px) popod neho prejde
	hook_target_y = hook_y
	trolley_x = sweep_span.x
	target_x = sweep_span.y
	_speed = 72.0
	_t = 0.0


## Topping out: nosník s vlajkou vyjde zdola až do výšky ride_y, na ňom Mike (m.ride = ride_point)
func start_ride(m: Node2D, rise: bool = true) -> void:
	mode = Mode.RIDE
	mike = m
	_show(true, true)
	if not rise:
		hook_y = ride_y
	hook_target_y = ride_y
	_speed = 52.0
	_t = 1.5


## Popruh na strane dir praskne – nosník sa nakloní (Mike zletí – IronMike.fall_off volá level), potom spadne
func snap(dir: float) -> void:
	mode = Mode.TILT
	Sfx.play(&"beam_clang", _load.global_position, 0.0)
	Sfx.play(&"chain_rattle", _load.global_position, -2.0)
	_slings.points = PackedVector2Array([Vector2(-50.0 * dir, 0), Vector2(0, -SLING_H)])
	var tw := create_tween()
	tw.tween_property(_load, "rotation", 0.9 * dir, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_callback(func(): _drop_beam(dir))


func _drop_beam(dir: float) -> void:
	var b := LOAD.new()
	b.texture = _beam.texture
	b.centered = false
	b.offset = Vector2(-64, -10)
	b.floor_y = deck_y
	b.half_w = 58.0
	b.stay = true
	b.spin = 2.0
	b.player_damage = 2
	b.rotation = _load.rotation
	b.z_index = -1
	get_parent().add_child(b)
	b.global_position = _load.global_position + Vector2(0, 10)
	for s in [_flag, _tree]:   # vlajka a stromček zostanú na nosníku
		var c := Sprite2D.new()
		c.texture = s.texture
		c.hframes = s.hframes
		c.centered = false
		c.position = s.position + Vector2(0, 10)
		b.add_child(c)
	Sfx.play(&"beam_whoosh", _load.global_position, -2.0)
	_load.rotation = 0.0
	_loaded = false
	_show(false, false)
	mode = Mode.DROPS
	_step = 2
	_t = 1.0
	hook_target_y = deck_y - 130.0
	_speed = 90.0


func start_drops(loaded: bool = true) -> void:
	mode = Mode.DROPS
	_loaded = loaded
	_show(false, false)
	hook_y = deck_y - 130.0
	hook_target_y = hook_y
	_step = 0 if loaded else 2
	_t = 2.0
	_speed = 90.0


func stop() -> void:
	mode = Mode.IDLE
	drops_enabled = false
	_shadow.visible = false
	target_x = trolley_x


# ---------------------------------------------------------------- slučka

func _physics_process(delta: float) -> void:
	_t -= delta
	_hit_cd -= delta
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	match mode:
		Mode.SWEEP:
			_sweep_tick(p)
		Mode.RIDE:
			if _t <= 0.0 and p:
				_t = randf_range(2.0, 3.2)
				if absf(p.global_position.x - trolley_x) < 60.0 or randf() < 0.3:
					_side = -_side
				target_x = clampf(p.global_position.x + _side * randf_range(80.0, 120.0), span.x, ride_max)
		Mode.DROPS:
			_drops_tick(p)
	# mačka: rozbeh a brzdenie, náklad sa za ňou hojdá
	var want: float = clampf((target_x - trolley_x) * 2.5, -_speed, _speed)
	var prev: float = _vx
	_vx = move_toward(_vx, want, accel * delta)
	trolley_x = clampf(trolley_x + _vx * delta, span.x, span.y)
	var a: float = (_vx - prev) / maxf(delta, 0.001)
	var l: float = maxf(hook_y - jib_y, 40.0)
	_swing_v += (-(PEND_G / l) * sin(swing) - (a / l) * cos(swing) * 0.6) * delta
	_swing_v *= 1.0 - 1.4 * delta
	swing = clampf(swing + _swing_v * delta, -SWING_MAX, SWING_MAX)
	hook_y = move_toward(hook_y, hook_target_y, 130.0 * delta)
	_place()
	if _motor:
		(_motor as Node2D).global_position = Vector2(trolley_x, jib_y)
		_motor.set(&"volume_db", lerpf(-40.0, -12.0, clampf(absf(_vx) / 60.0 + absf(hook_y - hook_target_y) / 40.0, 0.0, 1.0)))
	if _flag.visible:
		_flag.frame = int(Time.get_ticks_msec() / 220) % 2


func _place() -> void:
	var l: float = minf(hook_y - jib_y, 160.0)
	_trolley.position = Vector2(trolley_x - 9.0, jib_y - 1.0)
	_load.global_position = Vector2(trolley_x + sin(swing) * l, hook_y).round()
	if mode != Mode.TILT:
		_load.rotation = swing * 0.25
	var hook_top: Vector2 = _load.global_position + Vector2(0, -SLING_H - HOOK_H).rotated(_load.rotation)
	_rope.points = PackedVector2Array([Vector2(trolley_x, jib_y + 7.0), hook_top])


## Ricco (stojaci) a mafiáni v obdĺžniku nákladu → zrazí ich
func _ram(p: Node2D, rect: Rect2, damage: int) -> void:
	if p and _hit_cd <= 0.0 and int(p.get(&"state")) != 3:
		var h: float = 24.0 if int(p.get(&"state")) == 4 else 40.0
		if rect.intersects(Rect2(p.global_position + Vector2(-7, -h), Vector2(14, h))):
			_hit_cd = 1.0
			p.call(&"take_damage", damage, rect.get_center())
			var away: float = signf(_vx) if absf(_vx) > 5.0 else signf(p.global_position.x - rect.get_center().x)
			p.set(&"velocity", Vector2(away * 240.0, -140.0))
			Sfx.play(&"beam_clang", p.global_position, -2.0)
	if p == null or p.global_position.distance_to(rect.get_center()) > 420.0:
		return   # mafiánov zmetie len pred Riccom (aby ich nevymietol skôr, ako príde)
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var e := g as Gangster
		if e == null or e.is_in_group(&"boss") or e.state == Gangster.State.DEAD or e in _swept:
			continue
		if rect.intersects(Rect2(e.global_position + Vector2(-8, -64), Vector2(16, 64))):
			_swept.append(e)
			Sfx.play(&"beam_clang", e.global_position, -2.0)
			e.take_hit(99.0, Vector2(signf(_vx) + 0.01, -0.3))


func _sweep_tick(p: Node2D) -> void:
	if absf(trolley_x - target_x) < 2.0 and absf(_vx) < 4.0:
		if _t <= -1.2:   # chvíľu postojí na konci a ide naspäť
			target_x = sweep_span.y if target_x <= sweep_span.x + 1.0 else sweep_span.x
			Sfx.play(&"beam_whoosh", _load.global_position, -6.0)
	else:
		_t = 0.0
	_ram(p, Rect2(_load.global_position + Vector2(-64, 0), Vector2(128, 10)), 1)


func _drops_tick(p: Node2D) -> void:
	var on_deck: bool = p != null and absf(p.global_position.y - deck_y) < 24.0 and p.global_position.x > span.x - 20.0
	match _step:
		0:   # ide za Riccom
			if not drops_enabled or not on_deck:
				_shadow.visible = false
				return
			target_x = clampf(p.global_position.x, span.x, span.y)
			if _t <= 0.0 and (absf(_load.global_position.x - p.global_position.x) < 12.0 or _t < -2.5):
				_step = 1
				_t = 0.9
				target_x = trolley_x
				_shadow.global_position = Vector2(_load.global_position.x, _floor_below(_load.global_position) - 2.0)
				_shadow.visible = true
				Sfx.play(&"chain_rattle", _load.global_position, -4.0)
		1:   # tieň na palube – o chvíľu pustí
			_shadow.global_position.x = _load.global_position.x
			if _t <= 0.0:
				_release_keg()
				_step = 2
				_t = 0.8
		2:   # po nový sud – dierou v palube dolu
			if _t > 0.0:
				return
			target_x = refill.x
			if absf(trolley_x - refill.x) < 3.0:
				hook_target_y = refill.y
				if absf(hook_y - refill.y) < 2.0:
					_step = 3
					_t = 0.8
		3:
			if _t <= 0.0 and not _loaded:
				_loaded = true
				_show(false, false)
				Sfx.play(&"chain_rattle", _load.global_position, -10.0)
				hook_target_y = deck_y - 130.0
			if _loaded and absf(hook_y - hook_target_y) < 2.0:
				_step = 0
				_t = 2.5


func _floor_below(from: Vector2) -> float:
	var q := PhysicsRayQueryParameters2D.create(from + Vector2(0, 30), from + Vector2(0, 600), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else deck_y


func _release_keg() -> void:
	var k := LOAD.new()
	k.texture = _kegs.texture
	k.centered = false
	k.offset = Vector2(-15, -22)
	k.floor_y = _shadow.global_position.y + 2.0
	k.half_w = 15.0
	k.z_index = -1
	get_parent().add_child(k)
	k.global_position = _load.global_position + Vector2(0, 22)
	var fall: float = sqrt(2.0 * maxf(k.floor_y - k.global_position.y, 1.0) / LOAD.GRAVITY)
	var tw := create_tween()
	tw.tween_interval(fall)
	tw.tween_callback(_hide_shadow)
	_loaded = false
	_show(false, false)
	Sfx.play(&"beam_whoosh", _load.global_position, -6.0)


func _hide_shadow() -> void:
	if _step != 1:
		_shadow.visible = false


## Guľka alebo klobúk do háku
func _hook_shot(dir: Vector2, hat: bool) -> void:
	var at: Vector2 = _hook.global_position + Vector2(6, 8)
	Burst.spawn(get_tree().current_scene, at, -dir + Vector2(0, -0.3), Color(1.0, 0.85, 0.45), 5, 90.0)
	Sfx.play(&"ricochet_2" if not hat else &"beam_clang", at, -4.0, 0.1)
	_swing_v += signf(dir.x) * (1.4 if hat else 0.3)
	if hat and mode == Mode.RIDE and mike and mike.has_method(&"lurch"):
		mike.call(&"lurch")
