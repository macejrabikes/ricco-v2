class_name PatrolWagon
extends AnimatableBody2D
## Obrnený policajný voz Chiefa Murphyho na Queensboro Bridge (levels/level3/chase.gd, boss characters/murphy/murphy.gd).
## Obrázok levels/level3/art/chase/wagon.png (264 × 128, snímky: 0 zatvorený, 1 zadné dvere otvorené, 2 vybúraný).
## Počiatok uzla = stred spodku voza na ceste (y = 0). facing +1 = predok doprava (zadné dvere vľavo), -1 = zrkadlovo.
## Telo (strecha, kabína, kapota) je pevné – Ricco naň vyskočí a AnimatableBody2D (sync_to_physics) ho vezie so sebou.
## drive_to(x, rýchlosť) – rozbehne sa a zabrzdí presne na x (signál arrived); kolesá sa točia, motor znie vyššie.
## ram = true: pri jazde dopredu zrazí Ricca na ceste (ram_damage kúskov pizze, odhodí ho) a rozmetá barikády
## z vriec (skupina „sandbags“ – metóda shatter), sud s benzínom na ceste odpáli. Okno kabíny (WindowHit – chase_hitbox.gd) – zásah šoféra (window_hit).
## Telo a kolesá stavia skript sám (zrkadlenie pri otočení). Godot docs: classes/class_animatablebody2d

signal arrived                                  ## dorazil na cieľ drive_to
signal window_hit(damage: float, dir: Vector2)  ## guľka cez okno kabíny (Murphy za volantom)

const TEX := preload("res://levels/level3/art/chase/wagon.png")
const WHEEL_TEX := preload("res://levels/level3/art/chase/wheel_truck.png")
const GLOW := preload("res://levels/level1/art/glow.png")
const HITBOX := preload("res://levels/level3/chase_hitbox.gd")
const W := 264.0
const H := 128.0
## pevné časti v obrázku (x, y, šírka, výška): skriňa so strechou, kabína, kapota s baranidlom
const SOLID: Array[Rect2] = [Rect2(6, 14, 180, 98), Rect2(188, 36, 42, 76), Rect2(230, 66, 30, 46)]
const WHEELS: Array[Vector2] = [Vector2(46, 114), Vector2(76, 114), Vector2(238, 114)]
const WINDOW := Rect2(196, 42, 26, 20)
const LAMP := Vector2(258, 82)                  ## reflektor vpredu (obrázok)
const ROOF_Y := -114.0                          ## strecha (kde stojí Murphy v 1. fáze)
const ACCEL := 420.0                            ## px/s² rozbeh
const DECEL := 620.0                            ## px/s² brzdenie

@export var facing: float = 1.0
@export var ram_damage: int = 2

var speed: float = 0.0          ## px/s (so znamienkom)
var ram: bool = false
var _target: float = NAN
var _max_v: float = 0.0
var _braking: bool = false
var _shapes: Array[CollisionShape2D] = []
var _wheels: Array[Sprite2D] = []
var _dist: float = 0.0
var _engine: Node
var _lamp: Sprite2D
var _window: StaticBody2D
var _window_shape: CollisionShape2D
var _revving: bool = false
var sprite: Sprite2D


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = TEX
	sprite.hframes = 3
	sprite.centered = false
	sprite.position = Vector2(-W / 2.0, -H)
	add_child(sprite)
	for r in SOLID:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		cs.shape = rs
		add_child(cs)
		_shapes.append(cs)
	for i in WHEELS.size():
		var w := Sprite2D.new()
		w.texture = WHEEL_TEX
		w.hframes = 4
		w.z_index = 1
		add_child(w)
		_wheels.append(w)
	_lamp = Sprite2D.new()
	_lamp.texture = GLOW
	_lamp.modulate = Color(1.0, 0.95, 0.7, 0.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lamp.material = add
	_lamp.scale = Vector2(2.2, 1.4)
	_lamp.z_index = 3
	add_child(_lamp)
	_window = StaticBody2D.new()
	_window.set_script(HITBOX)
	_window.name = "WindowHit"
	add_child(_window)
	_window_shape = CollisionShape2D.new()
	var ws := RectangleShape2D.new()
	ws.size = WINDOW.size
	_window_shape.shape = ws
	_window.add_child(_window_shape)
	_window.connect(&"hit", func(d: float, dir: Vector2): window_hit.emit(d, dir))
	set_window(false)
	set_facing(facing)
	_engine = Sfx.loop(&"car_engine", self, Vector2.ZERO, -12.0, &"SFX")


## Bod v obrázku → lokálna poloha (podľa smeru voza)
func img(p: Vector2) -> Vector2:
	return Vector2((p.x - W / 2.0) * facing, p.y - H)


func set_facing(f: float) -> void:
	facing = 1.0 if f >= 0.0 else -1.0
	sprite.flip_h = facing < 0.0
	for i in SOLID.size():
		_shapes[i].position = img(SOLID[i].get_center())
	for i in WHEELS.size():
		_wheels[i].position = img(WHEELS[i])
	_window_shape.position = img(WINDOW.get_center())
	_lamp.position = img(LAMP) + Vector2(facing * 26.0, 0)


## Predný a zadný okraj (globálne x)
func front_x() -> float:
	return global_position.x + facing * W / 2.0


func rear_x() -> float:
	return global_position.x - facing * W / 2.0


## Rozbehne sa a zastaví presne na x (globálne – stred voza)
func drive_to(x: float, max_speed: float) -> void:
	_target = x
	_max_v = max_speed
	_braking = false


func stop_now() -> void:
	_target = NAN
	speed = 0.0


func open_doors() -> void:
	if sprite.frame != 2:
		sprite.frame = 1
	Sfx.play(&"door_open", global_position + img(Vector2(20, 60)), -4.0)


func close_doors() -> void:
	if sprite.frame != 2:
		sprite.frame = 0
	Sfx.play(&"door_close", global_position + img(Vector2(20, 60)), -6.0)


func wreck() -> void:
	sprite.frame = 2
	stop_now()
	lights(false)
	set_window(false)
	if _engine:
		_engine.queue_free()
		_engine = null
	Sfx.play(&"metal_crash", global_position + img(Vector2(230, 70)), 0.0)
	Sfx.play(&"glass_break", global_position + img(WINDOW.get_center()), -4.0)
	Burst.spawn(get_tree().current_scene, global_position + img(Vector2(240, 60)), Vector2(facing, -0.6), Color(1.0, 0.8, 0.4), 14, 140.0)


## Reflektor (výstraha pred nájazdom)
func lights(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_lamp, "modulate:a", 0.85 if on else 0.0, 0.2)


## Okno kabíny sa dá trafiť (len keď Murphy šoféruje)
func set_window(on: bool) -> void:
	_window.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Motor zavrčí naprázdno (výstraha pred nájazdom)
func rev() -> void:
	if _engine == null:
		return
	_revving = true
	var tw := create_tween()
	tw.tween_property(_engine, "pitch_scale", 1.7, 0.35)
	tw.tween_property(_engine, "pitch_scale", 0.9, 0.4)
	tw.tween_property(_engine, "pitch_scale", 1.8, 0.35)
	tw.tween_property(_engine, "pitch_scale", 1.0, 0.4)
	tw.tween_callback(func(): _revving = false)


func _physics_process(delta: float) -> void:
	if not is_nan(_target):
		var d: float = _target - global_position.x
		var stop: float = speed * speed / (2.0 * DECEL)
		if absf(d) <= stop + 2.0 and signf(speed) == signf(d):
			if not _braking and absf(speed) > 220.0:
				Sfx.play(&"tire_skid", global_position + img(Vector2(200, 110)), -2.0)
			_braking = true
			speed = move_toward(speed, 0.0, DECEL * delta)
		else:
			speed = move_toward(speed, signf(d) * _max_v, ACCEL * delta)
		var step: float = speed * delta
		if absf(d) < 1.5 or (absf(step) >= absf(d) and _braking):
			global_position.x = _target
			speed = 0.0
			_target = NAN
			_braking = false
			arrived.emit()
		else:
			global_position.x += step
	_dist += absf(speed) * delta
	var f: int = int(_dist / 7.0) % 4
	for w in _wheels:
		w.frame = f
	if _engine and not _revving:
		_engine.set(&"pitch_scale", lerpf(0.75, 1.5, clampf(absf(speed) / 400.0, 0.0, 1.0)))
	if ram and speed * facing > 60.0:
		_ram_check()


## Zrazí Ricca na ceste a rozmetá barikády pred sebou
func _ram_check() -> void:
	var fx: float = front_x()
	var bx: float = global_position.x
	var lo: float = minf(fx, bx) - 4.0
	var hi: float = maxf(fx, bx) + 4.0
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	if p and int(p.get(&"state")) != 3 and p.global_position.y > -50.0 and p.global_position.x > lo and p.global_position.x < hi:
		if float(p.get(&"invulnerable_timer")) <= 0.0:
			p.take_damage(ram_damage, Vector2(fx - facing * 30.0, p.global_position.y - 20.0))
			p.set(&"velocity", Vector2(facing * 380.0, -240.0))
			p.set(&"shake_timer", 0.35)
			Sfx.play(&"body_thud", p.global_position, 2.0)
			Sfx.play(&"metal_crash", p.global_position, -8.0, 0.1)
	for b in get_tree().get_nodes_in_group(&"ship_barrel"):   # sud s benzínom na ceste – voz ho odpáli
		var bn := b as Node2D
		if bn and bn.global_position.x > lo and bn.global_position.x < hi and bn.global_position.y > -10.0 and bn.has_method(&"ignite"):
			bn.ignite(0.05)
	for s in get_tree().get_nodes_in_group(&"sandbags"):
		var n := s as Node2D
		if n and n.global_position.x > lo - 10.0 and n.global_position.x < hi + 10.0 and n.has_method(&"shatter"):
			n.shatter(Vector2(facing, -1.0))
