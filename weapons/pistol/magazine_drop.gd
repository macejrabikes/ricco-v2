extends Sprite2D
## Vyhodený zásobník – padá, raz odskočí od zeme, chvíľu leží a zmizne.

var velocity: Vector2 = Vector2.ZERO
var bounces: int = 0
var life: float = 4.0
var spin: float = 0.0


func _physics_process(delta: float) -> void:
	life -= delta
	if life < 1.0:
		modulate.a = maxf(life, 0.0)
		if life <= 0.0:
			queue_free()
			return
	if bounces >= 2:
		return
	velocity.y += 900.0 * delta
	rotation += spin * delta
	var to: Vector2 = global_position + velocity * delta
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, to + Vector2(0, 3), 1))
	if hit.is_empty():
		global_position = to
		return
	global_position = hit.position - Vector2(0, 3)
	bounces += 1
	if bounces == 1:
		Sfx.play(&"mag_drop" if texture and texture.get_width() > 6 else &"casing_drop", global_position, -8.0, 0.15)
	velocity = Vector2(velocity.x * 0.4, -velocity.y * 0.3)
	spin *= 0.3
	if bounces >= 2:
		rotation = PI / 2.0 * signf(rotation if rotation != 0.0 else 1.0)  # leží na boku
