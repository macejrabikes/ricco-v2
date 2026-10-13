extends Sprite2D
## Riccov klobúk ako bumerang: letí k myši, spomalí, otočí sa a vráti sa k Riccovi.
## Zasiahne každý terč raz za hod; pri náraze do steny sa hneď vracia.

signal caught

@export var throw_speed: float = 450.0
@export var turn_back_decel: float = 480.0   ## ako rýchlo spomalí a otočí sa (dolet ≈ throw_speed² / (2·decel) ≈ 210 px)
@export var return_speed: float = 420.0
@export var damage: int = 1
@export var catch_distance: float = 14.0
@export var max_time: float = 3.0
@export_flags_2d_physics var hit_mask: int = 1 | 4

var owner_body: Node2D = null    ## Ricco
var velocity: Vector2 = Vector2.ZERO
var returning: bool = false
var already_hit: Array = []
var spin_t: float = 0.0


func launch(from: Vector2, dir: Vector2, who: Node2D) -> void:
	global_position = from
	velocity = dir.normalized() * throw_speed
	owner_body = who


func _physics_process(delta: float) -> void:
	max_time -= delta
	# točenie: 2 framy + rotácia
	spin_t += delta
	frame = int(spin_t * 16.0) % 2
	rotation += delta * 18.0

	var target_pos: Vector2 = owner_body.global_position + Vector2(0, -24)
	if not returning:
		velocity = velocity.move_toward(Vector2.ZERO, turn_back_decel * delta)
		if velocity.length() < 40.0 or max_time < 1.5:
			returning = true
	else:
		var to_owner: Vector2 = target_pos - global_position
		if to_owner.length() < catch_distance or max_time <= 0.0:
			caught.emit()
			queue_free()
			return
		velocity = velocity.move_toward(to_owner.normalized() * return_speed, 1600.0 * delta)

	var from: Vector2 = global_position
	var to: Vector2 = from + velocity * delta
	# pri návrate ignoruje steny (aby sa vždy vrátil), terče zasahuje stále
	var mask: int = (hit_mask & ~1) if returning else hit_mask
	var q := PhysicsRayQueryParameters2D.create(from, to, mask)
	q.exclude = already_hit.map(func(o): return o.get_rid())
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var c: Object = hit.collider
		if c.has_method("take_hit"):
			c.take_hit(damage, velocity.normalized())
			already_hit.append(c)
		elif not returning:
			Burst.spawn(get_parent(), hit.position, hit.normal, Color(0.3, 0.3, 0.3), 5, 60.0)
			global_position = hit.position
			returning = true
			return
	global_position = to
