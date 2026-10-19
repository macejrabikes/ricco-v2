extends Area2D
## Kúsok pizze – vypadne v boji s Big Lou (prechod medzi fázami, rozbitá sieť žeriavu). Padne na zem, pohupkáva sa;
## Ricco ho zje, keď nemá plné zdravie (+2 kúsky v HUD). Ako krabička nábojov (props/ammo/ammo_pickup.gd).
## Godot docs: classes/class_area2d – body_entered

@export var amount: int = 2

var velocity: Vector2 = Vector2(0, -120)
var _t: float = 0.0
var _landed: bool = false
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2     # Ricco
	body_entered.connect(_on_body)
	velocity.x += randf_range(-30.0, 30.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		velocity.y += 600.0 * delta
		var to: Vector2 = global_position + velocity * delta
		var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, to + Vector2(0, 6), 1))
		if hit.is_empty():
			global_position = to
		elif hit.normal.y < -0.6:
			global_position = hit.position - Vector2(0, 6)
			_landed = true
		else:
			velocity.x = -velocity.x * 0.4
	sprite.position.y = -2.0 + roundf(sin(_t * 4.0) * 1.0) if _landed else 0.0
	# zje ho aj keď na ňom už stojí a medzitým ho zranili
	if _landed and int(_t * 10.0) % 3 == 0:
		for b in get_overlapping_bodies():
			_on_body(b)


func _on_body(body: Node) -> void:
	if not body.has_method(&"heal") or body.get(&"health") >= body.get(&"max_health") or body.get(&"state") == 3:
		return
	body.heal(amount)
	Sfx.play(&"pickup_ammo", global_position, -4.0, 0.3)
	Burst.spawn(get_parent(), global_position, Vector2.UP, Color(0.95, 0.75, 0.3), 8, 50.0, Vector2(0, 100), 0.35)
	queue_free()
