extends Sprite2D
## Riccov klobúk ako frisbee: ten istý klobúk, čo má na hlave (hat_frisbee.png – 6 snímok,
## cez klobúk prebieha odlesk, takže vidno, že sa točí); letí naplocho, nakláňa sa podľa smeru letu,
## spomalí, otočí sa a vráti sa k Riccovi.
## Od stien, zeme a stropu sa odrazí (Vector2.bounce), aj pri návrate – cez steny neprejde.
## Ak sa pri návrate zasekne (alebo letí priveľmi dlho), „puf“ a je späť u Ricca.
## Každý terč zasiahne raz cestou tam a raz cestou späť. Gangstra omráči (hat_hit).
## Od krytu (vrstva 32 – visiace mäso, debny) sa odrazí ako od steny, len ho pritom rozhojdá (hat_hit).

signal caught

@export var throw_speed: float = 450.0
@export var turn_back_decel: float = 480.0   ## ako rýchlo spomalí a otočí sa (dolet ≈ throw_speed² / (2·decel) ≈ 210 px)
@export var return_speed: float = 420.0
@export var bounce_keep: float = 0.8         ## koľko rýchlosti ostane po odraze
@export var damage: float = 0.5   ## mafián má 3 – klobúk omráči, ale sám zabije až na 6 zásahov
@export var catch_distance: float = 14.0
@export var max_time: float = 3.0
@export var stuck_time: float = 0.8          ## s – ak sa pri návrate nepribližuje, vráti sa „kúzlom“
@export var spin_fps: float = 20.0           ## rýchlosť odlesku (točenia)
@export var half_size: Vector2 = Vector2(16, 7)  ## polovica veľkosti klobúka – okraj sa odrazí, nie stred
@export_flags_2d_physics var hit_mask: int = 1 | 4 | 32   ## svet + nepriatelia + kryt (mäso, debny)

const COVER_LAYER := 32

var owner_body: Node2D = null    ## Ricco
var velocity: Vector2 = Vector2.ZERO
var returning: bool = false
var _return_sfx: bool = false   ## zvuk návratu (švih, ktorý sa približuje) zaznie raz
var already_hit: Array[RID] = []   ## RID, nie uzly – zasiahnutý sud / debna môže medzitým zmiznúť (queue_free)
var spin_t: float = 0.0
var _best_dist: float = INF
var _stuck: float = 0.0


func launch(from: Vector2, dir: Vector2, who: Node2D) -> void:
	global_position = from
	velocity = dir.normalized() * throw_speed
	owner_body = who


func _physics_process(delta: float) -> void:
	max_time -= delta
	# frisbee: odlesk prebieha dookola (snímky), mierny náklon podľa smeru letu
	spin_t += delta
	frame = int(spin_t * spin_fps) % hframes
	rotation = lerpf(rotation, clampf(velocity.y / 900.0, -0.35, 0.35), minf(1.0, 10.0 * delta))
	flip_h = velocity.x < 0.0

	var target_pos: Vector2 = owner_body.global_position + Vector2(0, -24)
	if not returning:
		velocity = velocity.move_toward(Vector2.ZERO, turn_back_decel * delta)
		if velocity.length() < 40.0 or max_time < 1.5:
			_start_return()
	else:
		if not _return_sfx:
			_return_sfx = true
			Sfx.play(&"hat_return", Vector2.INF, -4.0)
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


## Pohyb s odrazmi: lúč po dráhe (predĺžený o polovicu klobúka, aby sa odrazil okraj),
## pri stene odraz a zvyšok dráhy pokračuje novým smerom.
func _move(motion: Vector2) -> void:
	var space := get_world_2d().direct_space_state
	for i in 3:   # najviac 3 odrazy za snímku
		var from: Vector2 = global_position
		var dir: Vector2 = motion.normalized()
		var reach: float = absf(dir.x) * half_size.x + absf(dir.y) * half_size.y
		var q := PhysicsRayQueryParameters2D.create(from, from + motion + dir * reach, hit_mask)
		q.exclude = already_hit
		var hit := Gangster.solid_ray(space, q)   # plošiny, cez ktoré sa dá vyskočiť, klobúk preletí
		if hit.is_empty():
			global_position = from + motion
			return
		var c: Object = hit.collider
		var cover: bool = c is CollisionObject2D and ((c as CollisionObject2D).collision_layer & COVER_LAYER) != 0
		if not cover:
			if c.has_method("hat_hit"):        # gangster: omráči ho a zhodí mu klobúk
				already_hit.append(hit.rid)
				c.hat_hit(damage, velocity.normalized())
				continue
			if c.has_method("take_hit"):
				already_hit.append(hit.rid)
				c.take_hit(damage, velocity.normalized())
				continue   # terčom preletí
		elif c.has_method("hat_hit"):   # mäso / debna: rozhojdá sa, klobúk sa od neho odrazí
			c.hat_hit(damage, velocity.normalized())
		# stena / zem / strop → odraz; klobúk ostane celý pred stenou
		var n: Vector2 = hit.normal
		Burst.spawn(get_parent(), hit.position, n, Color(0.3, 0.3, 0.3), 4, 50.0)
		var edge: float = absf(n.x) * half_size.x + absf(n.y) * half_size.y
		var used: float = maxf((hit.position - from).length() - reach, 0.0)
		global_position = hit.position + n * (edge + 0.5)
		velocity = velocity.bounce(n) * bounce_keep
		motion = motion.bounce(n).normalized() * maxf(motion.length() - used, 0.0)
		if not returning and velocity.length() < 120.0:   # slabý odraz → rovno späť
			_start_return()


## Otočí sa k Riccovi – cestou späť môže znova zasiahnuť aj tých, ktorých trafil cestou tam
func _start_return() -> void:
	returning = true
	already_hit.clear()


func _finish(magic: bool) -> void:
	if magic:   # vrátil sa „kúzlom“ – obláčik tam, kde zmizol
		Burst.spawn(get_parent(), global_position, Vector2.UP, Color(0.75, 0.72, 0.68, 0.8), 6, 40.0, Vector2(0, -20), 0.4)
	caught.emit()
	queue_free()
