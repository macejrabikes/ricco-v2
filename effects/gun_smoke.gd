class_name GunSmoke
extends Sprite2D
## Dym z hlavne po výstrele: pár obláčikov (effects/art/smoke_puff.png – 3 veľkosti) vyletí v smere streľby,
## spomalí, pomaly stúpa, rastie a rozplynie sa. Ostane chvíľu visieť vo vzduchu za Riccom.
## Použitie: GunSmoke.spawn(get_tree().current_scene, muzzle_pos, aim_dir, 1.0)
## Godot docs: classes/class_sprite2d (hframes), classes/class_tween

const SHEET := preload("res://effects/art/smoke_puff.png")

var velocity: Vector2
var life: float = 1.4
var _age: float = 0.0
var _alpha: float = 0.5
var _grow: float = 0.8


## strength 1 = pištoľ, viac = viac a hustejšieho dymu (lupara)
static func spawn(parent: Node, pos: Vector2, dir: Vector2, strength: float = 1.0) -> void:
	var n: int = clampi(int(round(3.0 + 3.0 * strength)), 3, 9)
	for i in n:
		var s := GunSmoke.new()
		s.texture = SHEET
		s.hframes = 3
		s.frame = mini(2, i * 3 / n + (1 if strength > 1.2 else 0))
		s.z_index = 6
		var t: float = float(i) / maxf(1.0, n - 1.0)   # 0 = pri ústí, 1 = najďalej
		s.velocity = dir * lerpf(10.0, 85.0, t) * randf_range(0.8, 1.2) + Vector2(randf_range(-6, 6), randf_range(-14, -4))
		s.life = randf_range(1.6, 2.6) * (0.85 + 0.15 * strength)
		s._alpha = randf_range(0.45, 0.62) * clampf(0.8 + 0.2 * strength, 0.8, 1.2)
		s._grow = randf_range(0.9, 1.5)
		s.scale = Vector2.ONE * randf_range(0.6, 0.85)
		s.rotation = randf_range(-0.3, 0.3)
		s.flip_h = randf() < 0.5
		s.modulate = Color(1, 1, 1, 0.0)
		parent.add_child(s)
		s.global_position = pos + dir * randf_range(0.0, 4.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	var k: float = _age / life
	position += velocity * delta
	velocity = velocity.lerp(Vector2(4.0, -10.0), minf(1.0, 3.0 * delta))   # zbrzdí sa, potom pomaly stúpa a driftuje
	scale = Vector2.ONE * (0.7 + _grow * k)
	# rýchlo sa objaví, potom pomaly bledne
	modulate.a = _alpha * minf(1.0, _age / 0.06) * (1.0 - k * k * k)   # dlho drží, ku koncu sa rozplynie
