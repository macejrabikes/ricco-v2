extends Area2D
## Krabička nábojov – vypadne z gangstra. Padne na zem, pohupkáva sa; keď sa jej Ricco dotkne,
## každá jeho zbraň dostane jeden zásobník navyše (Godot docs: classes/class_area2d – body_entered).

var velocity: Vector2 = Vector2(0, -80)
var _t: float = 0.0
var _landed: bool = false
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2     # Ricco
	body_entered.connect(_on_body_entered)
	velocity.x = randf_range(-30.0, 30.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		velocity.y += 600.0 * delta
		var to: Vector2 = global_position + velocity * delta
		var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, to + Vector2(0, 5), 1))
		if hit.is_empty():
			global_position = to
		else:
			global_position = hit.position - Vector2(0, 5)
			_landed = true
	sprite.position.y = -2.0 + roundf(sin(_t * 4.0) * 1.0) if _landed else 0.0


func _on_body_entered(body: Node) -> void:
	if body.has_method("add_ammo") and body.add_ammo():   # bez zbrane (prológ) náboje nezoberie
		Burst.spawn(get_parent(), global_position, Vector2.UP, Color(0.84, 0.67, 0.28), 6, 50.0, Vector2(0, 100), 0.3)
		queue_free()
