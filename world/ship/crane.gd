extends Node2D
## Nákladný žeriav S.S. Margaret – 2. fáza boja s Big Lou (characters/lou/big_lou.gd): Lou ho ovláda pákou z búdky pri stĺpe.
## Rameno sa otáča okolo stĺpa (pohľad zboku → kladka ide doľava/doprava a rameno sa pritom skracuje, ako by mierilo k nám),
## lano so sieťou plnou debien sa na ňom hojdá (kyvadlo poháňané zrýchlením kladky).
##   drop_cargo() – zo siete vypadne debna (world/ship/falling_cargo.gd), tieň na palube ju vopred prezradí
##   lethal = true – nízko spustená sieť zmetie Ricca (2 kúsky pizze) aj debny; popod ňu sa dá prešmyknúť po bruchu
##   collapse() – blesk ho zlomí: rameno sa zrúti na palubu, sieť spadne a roztrhne sa (3. fáza)
## Uzly Boom, Rope, Net, Shadow vytvára tools/build_margaret.gd. Godot docs: classes/class_line2d, classes/class_tween

signal net_landed(pos: Vector2)
signal boom_landed(pos: Vector2)

const CARGO := preload("res://world/ship/falling_cargo.gd")
const NET_SIZE := Vector2(56, 48)
const G := 900.0   ## „gravitácia“ kyvadla – ťažká sieť s nákladom sa hojdá pomaly a málo

@export var pivot: Vector2 = Vector2(576, -174)   ## čap ramena nad kabínou
@export var length: float = 216.0                 ## px od čapu po kladku
@export var luff: float = 0.35                    ## rad – sklon ramena nad vodorovnou
@export var x_speed: float = 110.0                ## px/s – ako rýchlo kladka ide za cieľom
@export var x_accel: float = 260.0                ## px/s² – rozbeh a brzdenie (ťažké rameno, sieť sa za ním hojdá)
@export var rope: float = 98.0                    ## px – lano od kladky po očko siete
@export var rope_speed: float = 110.0

var tip_x: float
var target_x: float
var rope_target: float
var lethal: bool = false
var sweep_dir: float = 1.0
var swing: float = 0.0
var _swing_v: float = 0.0
var _prev_vx: float = 0.0
var _broken: bool = false
var _net_fall: bool = false
var _net_v: Vector2 = Vector2.ZERO
var _shadow_t: float = -1.0
var _motor: Node
var _motor_vol: float = -60.0

@onready var boom: Sprite2D = $Boom
@onready var rope_line: Line2D = $Rope
@onready var net: Sprite2D = $Net
@onready var shadow: Sprite2D = $Shadow


func _ready() -> void:
	add_to_group(&"crane")
	tip_x = pivot.x - length * cos(luff)
	target_x = tip_x
	rope_target = rope
	net.centered = false
	net.offset = Vector2(-NET_SIZE.x / 2.0, 0)
	net.z_index = 3          # pred Riccom – keď ho zmetie, je to vidieť
	rope_line.z_index = 2
	shadow.visible = false
	_place()


## Kam až kladka dočiahne (px, globálne x)
func reach() -> Vector2:
	var lc: float = length * cos(luff)
	return Vector2(pivot.x - lc, pivot.x + lc)


func tip() -> Vector2:
	return Vector2(tip_x, pivot.y - length * sin(luff))


## Očko siete (koniec lana)
func hook() -> Vector2:
	return tip() + Vector2(sin(swing), cos(swing)) * rope


func net_bottom() -> Vector2:
	return hook() + Vector2(sin(swing), cos(swing)) * NET_SIZE.y


func net_rect() -> Rect2:
	var c: Vector2 = hook() + Vector2(sin(swing), cos(swing)) * (NET_SIZE.y / 2.0 + 4.0)
	return Rect2(c - Vector2(25, 20), Vector2(50, 40))


## Je kladka (takmer) na mieste?
func settled() -> bool:
	return absf(target_x - tip_x) < 3.0 and absf(rope_target - rope) < 2.0


func _physics_process(delta: float) -> void:
	if _broken:
		_fall_net(delta)
		return
	var dx: float = target_x - tip_x
	var want: float = clampf(dx * 4.0, -x_speed, x_speed)
	var vx: float = move_toward(_prev_vx, want, x_accel * delta)
	if absf(dx) < 0.5 and absf(vx) < 4.0:
		vx = 0.0
		tip_x = target_x
	tip_x += vx * delta
	var accel: float = (vx - _prev_vx) / delta
	_prev_vx = vx
	# kyvadlo: θ'' = −(g/l)·sin θ − (a/l)·cos θ, tlmené
	var l: float = rope + NET_SIZE.y / 2.0
	_swing_v += (-(G / l) * sin(swing) - (accel / l) * cos(swing)) * delta
	_swing_v *= 1.0 - 1.4 * delta
	swing = clampf(swing + _swing_v * delta, -0.7, 0.7)
	rope += clampf(rope_target - rope, -rope_speed * delta, rope_speed * delta)
	_place()
	# motor žeriavu hučí, keď sa rameno hýbe
	var vol: float = -10.0 if absf(vx) > 5.0 or absf(rope_target - rope) > 1.0 else -60.0
	_motor_vol = move_toward(_motor_vol, vol, 120.0 * delta)
	if _motor == null and _motor_vol > -50.0:
		_motor = Sfx.loop(&"crane_motor", self, pivot + Vector2(0, 150), -60.0, &"SFX")
	if _motor:
		_motor.set(&"volume_db", _motor_vol)
	if _shadow_t >= 0.0:
		_shadow_t += delta
		_place_shadow()
	if lethal:
		_sweep()


func _place() -> void:
	var v: Vector2 = tip() - pivot
	boom.position = pivot
	boom.rotation = v.angle() - PI
	boom.scale = Vector2(v.length() / length, 1.0 if v.x <= 0.0 else -1.0)
	var h: Vector2 = hook()
	rope_line.points = PackedVector2Array([tip(), h])
	net.position = h
	net.rotation = -swing


# ---------------------------------------------------------------- útoky

## Tieň pod sieťou – bliká, kým nepadne debna
func show_shadow(on: bool) -> void:
	shadow.visible = on
	_shadow_t = 0.0 if on else -1.0
	if on:
		_place_shadow()


func _place_shadow() -> void:
	var b: Vector2 = net_bottom()
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(b, b + Vector2(0, 400), 1))
	var y: float = hit.position.y if not hit.is_empty() else 0.0
	shadow.position = Vector2(b.x - shadow.texture.get_width() / 2.0, y - shadow.texture.get_height() + 2.0)
	shadow.modulate.a = 0.55 + 0.35 * sin(_shadow_t * 18.0)
	shadow.scale = Vector2.ONE * (0.7 + minf(_shadow_t, 0.75) * 0.5)   # tieň rastie – debna sa blíži
	shadow.position.x = b.x - shadow.texture.get_width() * shadow.scale.x / 2.0


## Sieťou trhne a vypadne z nej debna
func drop_cargo() -> void:
	var c: Node2D = CARGO.new()
	get_tree().current_scene.add_child(c)
	c.global_position = net_bottom() + Vector2(0, 2)
	c.set(&"velocity", Vector2(_prev_vx * 0.5, 30.0))
	_swing_v += randf_range(-0.8, 0.8)
	Sfx.play(&"chain_rattle", net_bottom(), -4.0, 0.1)
	net.position.y -= 3.0


## Sieť zmetie, čo jej príde do cesty (len keď je spustená nízko – lethal)
func _sweep() -> void:
	var r: Rect2 = net_rect()
	var tree := get_tree()
	var p := tree.get_first_node_in_group(&"player") as Node2D
	if p and p.get(&"state") != 3 and p.get(&"invulnerable_timer") <= 0.0:
		var h: float = 24.0 if p.get(&"state") == 4 else 38.0   # po bruchu sa prešmykne popod
		if r.intersects(Rect2(p.global_position + Vector2(-8, -h), Vector2(16, h))):
			p.take_damage(2, r.get_center())
			p.velocity = Vector2(sweep_dir * 280.0, -220.0)
			Sfx.play(&"body_thud", p.global_position, 0.0, 0.1)
			Burst.spawn(tree.current_scene, p.global_position + Vector2(0, -20), Vector2(sweep_dir, -0.5), Color(1, 0.9, 0.5), 8, 120.0)
	for c in tree.get_nodes_in_group(&"ship_cover"):
		var cn := c as Node2D
		if cn and cn.has_method(&"shatter") and r.intersects(Rect2(cn.global_position - Vector2(15, 10), Vector2(30, 20))):
			cn.shatter(Vector2(sweep_dir, -1.0))
			_swing_v -= sweep_dir * 0.3


# ---------------------------------------------------------------- blesk ho zlomí

## Kam dopadne kladka zrúteného ramena (na palubu y = 0; tam stojí sud Barrel1, tools/build_margaret.gd)
func landing() -> Vector2:
	return pivot + _landing_dir()


func _landing_dir() -> Vector2:
	return Vector2(-sqrt(maxf(length * length - pivot.y * pivot.y, 0.0)), -pivot.y)


## Rameno sa zrúti na palubu (kladka dopadne na landing()), sieť sa utrhne a padne
func collapse() -> void:
	if _broken:
		return
	_broken = true
	lethal = false
	show_shadow(false)
	if _motor:
		_motor.queue_free()
		_motor = null
	_net_fall = true
	_net_v = Vector2(_prev_vx * 0.4, 0.0)
	rope_line.visible = false
	Sfx.play(&"metal_crash", pivot, 0.0, 0.0)
	boom.scale = Vector2(boom.scale.x, 1.0)
	var end_rot: float = _landing_dir().angle() - PI   # kladka na palube
	boom.rotation = wrapf(boom.rotation, end_rot - PI, end_rot + PI)
	var tw := create_tween()
	tw.tween_property(boom, "scale:x", 1.0, 0.25)
	tw.parallel().tween_property(boom, "rotation", end_rot, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var at: Vector2 = pivot + Vector2(-length, 0).rotated(end_rot)
		Sfx.play(&"metal_crash", at, 4.0, 0.05)
		Burst.spawn(get_tree().current_scene, at, Vector2(0, -1), Color(1, 0.85, 0.5), 18, 200.0, Vector2(0, 500), 0.5)
		boom_landed.emit(at))
	# odskočí od paluby
	tw.tween_property(boom, "rotation", end_rot + 0.05, 0.08)
	tw.tween_property(boom, "rotation", end_rot, 0.12)


## Už zrútený (checkpoint v 3. fáze) – bez zvukov a signálov
func wrecked() -> void:
	_broken = true
	lethal = false
	rope_line.visible = false
	boom.scale = Vector2.ONE
	boom.rotation = _landing_dir().angle() - PI
	net.rotation = 0.0
	net.scale = Vector2(1.15, 0.55)
	net.modulate = Color(0.55, 0.5, 0.48)
	net.position = Vector2(reach().x, -(NET_SIZE.y - 6.0) + NET_SIZE.y * 0.45)   # ako po páde v collapse()


func _fall_net(delta: float) -> void:
	if not _net_fall:
		return
	_net_v.y += 900.0 * delta
	var b: Vector2 = net.position + Vector2(0, NET_SIZE.y)
	var to: Vector2 = b + _net_v * delta
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(b, to + Vector2(0, 2), 1))
	net.rotation = move_toward(net.rotation, 0.0, 2.0 * delta)
	if hit.is_empty():
		net.position += _net_v * delta
		return
	_net_fall = false
	net.position = hit.position - Vector2(0, NET_SIZE.y - 6.0)
	Sfx.play(&"crate_break", hit.position, 2.0, 0.0)
	Burst.spawn(get_tree().current_scene, hit.position, Vector2(0, -1), Color(0.55, 0.5, 0.42, 0.6), 14, 70.0, Vector2(0, 80), 0.7)
	# sieť sa roztrhla – zvyšky ostanú ležať na palube
	var tw := create_tween()
	tw.tween_property(net, "scale", Vector2(1.15, 0.55), 0.12)
	tw.parallel().tween_property(net, "position:y", net.position.y + NET_SIZE.y * 0.45, 0.12)
	tw.tween_property(net, "modulate", Color(0.55, 0.5, 0.48), 0.6)
	net_landed.emit(hit.position)
