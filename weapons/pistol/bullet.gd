extends Sprite2D
## Náboj. Letí rovno; kolíziu zisťuje lúčom z minulej polohy do novej
## (Godot docs: tutorials/physics/ray-casting), takže rýchly náboj neprestrelí tenkú stenu.

@export var speed: float = 650.0
@export var damage: float = 1.0
@export var lifetime: float = 1.2
## Dostrel: do effective_range plný damage, potom za falloff_range rýchlo klesne na MIN_DAMAGE (guľka letí ďalej).
## effective_range = 0 → damage sa nemení (gangstrove guľky – Ricco vždy príde o 1 kúsok pizze).
@export var effective_range: float = 0.0
@export var falloff_range: float = 1.0

const MIN_DAMAGE := 0.1   ## podiel damage na konci poklesu

var _traveled: float = 0.0
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
	_traveled += speed * delta
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
		target.take_hit(damage * _falloff(), direction)
	else:
		Burst.spawn(get_parent(), hit.position, hit.normal, Color(1.0, 0.85, 0.4), 6, 80.0)  # iskry od steny
		Sfx.play([&"impact_wall", &"impact_wall", &"ricochet_1", &"ricochet_2"][randi() % 4], hit.position, -6.0, 0.12)
	queue_free()


## Násobok damage podľa preletenej vzdialenosti – najprv 1, za effective_range strmo dole (kvadraticky)
func _falloff() -> float:
	if effective_range <= 0.0 or _traveled <= effective_range:
		return 1.0
	var t: float = clampf((_traveled - effective_range) / maxf(falloff_range, 1.0), 0.0, 1.0)
	return lerpf(1.0, MIN_DAMAGE, 1.0 - (1.0 - t) * (1.0 - t))
