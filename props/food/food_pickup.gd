extends Area2D
## Jedlo alebo lekárnička na zemi (aj vypadnuté z Lou). Spadne na zem a pohupkáva sa.
##  - jedlo: Ricco ho vezme do zásoby (najviac Food.MAX_CARRIED, zje ho klávesom V). Keď má plno, a je zranený, zje ho hneď.
##    kind = "" → druh sa vyberie podľa poradia (Food.next_kind – vždy iné jedlo).
##  - kind = "medkit": lekárnička – hneď doplní celé zdravie (keď je Ricco celý zdravý, ostane ležať).
## Godot docs: classes/class_area2d – body_entered

@export var kind: StringName = &""

var velocity: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _landed: bool = false
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2     # Ricco
	body_entered.connect(_on_body)
	if kind == &"":
		kind = Food.next_kind()
	sprite.texture = Food.texture(kind)
	_t = randf() * 3.0


func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		velocity.y += 600.0 * delta
		var to: Vector2 = global_position + velocity * delta
		var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, to + Vector2(0, 7), 1))
		if hit.is_empty():
			global_position = to
		elif hit.normal.y < -0.6:
			global_position = hit.position - Vector2(0, 7)
			_landed = true
		else:
			velocity.x = -velocity.x * 0.4
	sprite.position.y = -2.0 + roundf(sin(_t * 4.0) * 1.0) if _landed else 0.0
	# zoberie ho aj keď na ňom už stojí (napr. ho medzitým zranili alebo zjedol iné jedlo)
	if _landed and Engine.get_physics_frames() % 6 == 0:
		for b in get_overlapping_bodies():
			_on_body(b)


func _on_body(body: Node) -> void:
	if is_queued_for_deletion() or not body.has_method(&"heal") or body.get(&"state") == 3:
		return
	var hurt: bool = body.get(&"health") < body.get(&"max_health")
	if kind == &"medkit":
		if not hurt:
			return
		body.heal(body.get(&"max_health"))
		Sfx.play(&"medkit", global_position, -2.0, 0.05)
		_vanish(Color(0.9, 0.2, 0.2))
	elif Food.can_carry():
		Food.carried.append(kind)
		if body.has_signal(&"food_changed"):
			body.food_changed.emit()
		Sfx.play(&"pickup_ammo", global_position, -4.0, 0.3)
		_vanish(Color(0.95, 0.75, 0.3))
	elif hurt:
		body.heal(Food.HEAL.get(kind, 2))   # plná zásoba – zje ho hneď
		Sfx.play(&"pickup_ammo", global_position, -4.0, 0.3)
		_vanish(Color(0.95, 0.75, 0.3))


func _vanish(col: Color) -> void:
	Burst.spawn(get_parent(), global_position, Vector2.UP, col, 8, 50.0, Vector2(0, 100), 0.35)
	queue_free()
