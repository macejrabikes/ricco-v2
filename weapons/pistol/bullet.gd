extends Sprite2D
## Náboj. Letí rovno; kolíziu zisťuje lúčom z minulej polohy do novej
## (Godot docs: tutorials/physics/ray-casting), takže rýchly náboj neprestrelí tenkú stenu.

@export var speed: float = 650.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export_flags_2d_physics var hit_mask: int = 1 | 4   ## world + enemies

var direction: Vector2 = Vector2.RIGHT
var shooter: CollisionObject2D = null


func _ready() -> void:
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var from: Vector2 = global_position
	var to: Vector2 = from + direction * speed * delta
	var q := PhysicsRayQueryParameters2D.create(from, to, hit_mask)
	if shooter:
		q.exclude = [shooter.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	global_position = hit.position
	var target: Object = hit.collider
	if target.has_method("take_hit"):
		target.take_hit(damage, direction)
	else:
		Burst.spawn(get_parent(), hit.position, hit.normal, Color(1.0, 0.85, 0.4), 6, 80.0)  # iskry od steny
	queue_free()
