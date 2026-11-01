extends Sprite2D
## Rozžeravená nita (kapitola III – veža Iron Mikea). Letí oblúkom (gravitácia), Ricca popáli (1 kúsok pizze),
## pri dopade zasyčí a rozprskne sa iskrami. Hádže ich vyhňa (world/tower/rivet_forge.gd) – nitovači si ich podávajú,
## Iron Mike do vyhne kopne. Godot docs: classes/class_physicsdirectspacestate2d

const TEX := preload("res://levels/level3/art/tower/rivet_hot.png")
const GLOW := preload("res://levels/level1/art/glow.png")
const GRAVITY := 520.0

var velocity: Vector2 = Vector2.ZERO
var damage: int = 1
var life: float = 2.5
var catch_x: float = NAN   ## chytač (nitovač s vedrom) – na tomto x nita zmizne v jeho vedre
var _done: bool = false


func _ready() -> void:
	texture = TEX
	z_index = 6
	var g := Sprite2D.new()
	g.texture = GLOW
	g.scale = Vector2(0.18, 0.18)
	g.modulate = Color(1.0, 0.55, 0.2, 0.6)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	add_child(g)


func _physics_process(delta: float) -> void:
	if _done:
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	velocity.y += GRAVITY * delta
	var from: Vector2 = global_position
	var to: Vector2 = from + velocity * delta
	rotation += 14.0 * delta
	if not is_nan(catch_x) and velocity.y > 0.0 and signf(to.x - catch_x) != signf(from.x - catch_x):
		Sfx.play(&"knock", to, -14.0, 0.2)   # cvak do vedra
		queue_free()
		return
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	if p and int(p.get(&"state")) != 3:
		var h: float = 24.0 if int(p.get(&"state")) == 4 else 40.0
		if Rect2(p.global_position + Vector2(-8, -h), Vector2(16, h)).has_point(to):
			p.call(&"take_damage", damage, from)
			_fizzle(to)
			return
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_fizzle(hit.position)
		return
	global_position = to


func _fizzle(at: Vector2) -> void:
	_done = true
	global_position = at
	Sfx.play(&"steam_hiss", at, -20.0, 0.2)
	Burst.spawn(get_tree().current_scene, at, Vector2.UP, Color(1.0, 0.7, 0.3), 5, 60.0, Vector2(0, 200), 0.35)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(0.35, 0.3, 0.3, 1.0), 0.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)
