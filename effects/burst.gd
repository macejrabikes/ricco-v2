class_name Burst
extends CPUParticles2D
## Jednorazový výbuch častíc (iskry, črepy). Po dohraní sa sám zmaže.

static func spawn(parent: Node, pos: Vector2, dir: Vector2, color: Color, amount_: int = 8, speed: float = 90.0) -> void:
	var p := Burst.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount_
	p.lifetime = 0.35
	p.direction = dir
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 400)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.global_position = pos
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.emitting = true
