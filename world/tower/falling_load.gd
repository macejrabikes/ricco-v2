extends Sprite2D
## Náklad, ktorý vežový žeriav pustí z háku (world/tower/tower_crane.gd): sud s nitami alebo posledný nosník stavby.
## Padá na floor_y (tieň na zemi ukáže žeriav vopred). Kto stojí pod ním: Ricco príde o player_damage kúskov pizze,
## mafián padne, Iron Mike dostane boss_damage (IronMike.cargo_hit) a omráči ho. Po dopade chvíľu leží a zmizne
## (stay = ostane ležať navždy – nosník s vlajkou). Godot docs: classes/class_sprite2d

const GRAVITY := 820.0

var velocity: Vector2 = Vector2.ZERO
var floor_y: float = 0.0
var half_w: float = 14.0
var player_damage: int = 2
var boss_damage: float = 4.0
var stay: bool = false
var spin: float = 0.0
var _landed: bool = false


func _physics_process(delta: float) -> void:
	if _landed:
		return
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	rotation = move_toward(rotation, 0.0, (absf(spin) + 1.5) * delta)
	if global_position.y >= floor_y:
		global_position.y = floor_y
		_land()


func _land() -> void:
	_landed = true
	rotation = 0.0
	var x: float = global_position.x
	var tree := get_tree()
	var scene := tree.current_scene
	for b in tree.get_nodes_in_group(&"boss"):
		var m := b as Node2D
		if m and m.has_method(&"cargo_hit") and absf(m.global_position.x - x) < half_w + 8.0 and absf(m.global_position.y - floor_y) < 30.0:
			m.call(&"cargo_hit", boss_damage)
	for g in tree.get_nodes_in_group(&"enemies"):
		var e := g as Gangster
		if e == null or e.is_in_group(&"boss") or e.state == Gangster.State.DEAD:
			continue
		if absf(e.global_position.x - x) < half_w + 6.0 and absf(e.global_position.y - floor_y) < 30.0:
			e.take_hit(99.0, Vector2(signf(e.global_position.x - x) + 0.01, 0.4))
	var p := tree.get_first_node_in_group(&"player") as Node2D
	if p and int(p.get(&"state")) != 3:
		if absf(p.global_position.x - x) < half_w + 6.0 and absf(p.global_position.y - floor_y) < 30.0:
			p.call(&"take_damage", player_damage, Vector2(x, floor_y - 20.0))
		if p.global_position.distance_to(global_position) < 300.0:
			p.set(&"shake_timer", 0.18)
	Sfx.play(&"metal_crash", global_position, -2.0, 0.08)
	Burst.spawn(scene, global_position, Vector2.UP, Color(0.75, 0.7, 0.66, 0.6), 12, 80.0, Vector2(0, 60), 0.6)
	Gangster.noise(global_position, 320.0)
	if stay:
		return
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)
