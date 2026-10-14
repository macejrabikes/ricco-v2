extends Sprite2D
## Riccov klobúk ako frisbee: letí naplocho a točí sa okolo zvislej osi (4 snímky, hat_frisbee.png),
## spomalí, otočí sa a vráti sa k Riccovi.
## Od stien, zeme a stropu sa odrazí (Vector2.bounce), aj pri návrate – cez steny neprejde.
## Ak sa pri návrate zasekne (alebo letí priveľmi dlho), „puf“ a je späť u Ricca.
## Každý terč zasiahne raz za hod.

signal caught

@export var throw_speed: float = 450.0
@export var turn_back_decel: float = 480.0   ## ako rýchlo spomalí a otočí sa (dolet ≈ throw_speed² / (2·decel) ≈ 210 px)
@export var return_speed: float = 420.0
@export var bounce_keep: float = 0.8         ## koľko rýchlosti ostane po odraze
@export var damage: int = 1
@export var catch_distance: float = 14.0
@export var max_time: float = 3.0
@export var stuck_time: float = 0.8          ## s – ak sa pri návrate nepribližuje, vráti sa „kúzlom“
@export_flags_2d_physics var hit_mask: int = 1 | 4

var owner_body: Node2D = null    ## Ricco
var velocity: Vector2 = Vector2.ZERO
var returning: bool = false
var already_hit: Array = []
var spin_t: float = 0.0
var _best_dist: float = INF
var _stuck: float = 0.0


func launch(from: Vector2, dir: Vector2, who: Node2D) -> void:
	global_position = from
	velocity = dir.normalized() * throw_speed
	owner_body = who


func _physics_process(delta: float) -> void:
	max_time -= delta
	# frisbee: rýchle točenie (snímky), mierny náklon podľa smeru letu
	spin_t += delta
	frame = int(spin_t * 28.0) % hframes
	rotation = lerpf(rotation, clampf(velocity.y / 900.0, -0.35, 0.35), minf(1.0, 10.0 * delta))
	flip_h = velocity.x < 0.0

	var target_pos: Vector2 = owner_body.global_position + Vector2(0, -24)
	if not returning:
		velocity = velocity.move_toward(Vector2.ZERO, turn_back_decel * delta)
		if velocity.length() < 40.0 or max_time < 1.5:
			returning = true
	else:
		var to_owner: Vector2 = target_pos - global_position
		var dist: float = to_owner.length()
		if dist < catch_distance or max_time <= 0.0:
			_finish(dist >= catch_distance)
			return
		# zaseknutý za stenou → po chvíli sa vráti sám
		if dist < _best_dist - 2.0:
			_best_dist = dist
			_stuck = 0.0
		else:
			_stuck += delta
			if _stuck > stuck_time:
				_finish(true)
				return
		velocity = velocity.move_toward(to_owner.normalized() * return_speed, 1600.0 * delta)

	_move(velocity * delta)


## Pohyb s odrazmi: lúč po dráhe, pri stene odraz a zvyšok dráhy pokračuje novým smerom.
func _move(motion: Vector2) -> void:
	var space := get_world_2d().direct_space_state
	for i in 3:   # najviac 3 odrazy za snímku
		var from: Vector2 = global_position
		var q := PhysicsRayQueryParameters2D.create(from, from + motion, hit_mask)
		q.exclude = already_hit.map(func(o): return o.get_rid())
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			global_position = from + motion
			return
		var c: Object = hit.collider
		if c.has_method("take_hit"):
			c.take_hit(damage, velocity.normalized())
			already_hit.append(c)
			continue   # terčom preletí
		# stena / zem / strop → odraz
		var n: Vector2 = hit.normal
		Burst.spawn(get_parent(), hit.position, n, Color(0.3, 0.3, 0.3), 4, 50.0)
		var used: float = (hit.position - from).length()
		global_position = hit.position + n * 1.5
		velocity = velocity.bounce(n) * bounce_keep
		motion = motion.bounce(n).normalized() * maxf(motion.length() - used, 0.0)
		if not returning:
			returning = velocity.length() < 120.0   # slabý odraz → rovno späť


func _finish(magic: bool) -> void:
	if magic:   # vrátil sa „kúzlom“ – obláčik tam, kde zmizol
		Burst.spawn(get_parent(), global_position, Vector2.UP, Color(0.75, 0.72, 0.68, 0.8), 6, 40.0, Vector2(0, -20), 0.4)
	caught.emit()
	queue_free()
