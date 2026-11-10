extends StaticBody2D
## Medená panvica na háku nad sporákmi (hotel Majestic – kuchyňa). Riccova guľka sa od nej odrazí – a nie hocikam:
## panvica ju pošle do najbližšieho mafiána, ktorého odtiaľ vidno (trikový výstrel ako v My Friend Pedro).
## Keď nikto nie je na dosah (reach), guľka sa odrazí zrkadlovo. Klobúk panvicu len rozhojdá a zazvoní.
## Cinknutie počujú mafiáni v okolí (Gangster.noise). Vrstva 4 ako nepriatelia: mafiánske guľky ňou preletia.
## Poloha uzla = hák (os kývania). Deti: Sprite (panvica visí dole), Shape.
## Godot docs: classes/class_physicsdirectspacestate2d (intersect_ray), classes/class_staticbody2d

@export var reach: float = 340.0       ## px – ako ďaleko panvica „vidí“ mafiána
@export var noise_radius: float = 160.0

const BULLET := preload("res://weapons/pistol/bullet.tscn")
const COVER_LAYER := 32
const STIFF := 26.0
const DAMP := 3.0

var _angle: float = 0.0
var _spin: float = 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0


func _physics_process(delta: float) -> void:
	_spin += (-STIFF * _angle - DAMP * _spin) * delta
	_angle += _spin * delta
	rotation = _angle


func hat_hit(_damage: float, dir: Vector2) -> void:
	_spin += signf(dir.x) * 3.0
	Sfx.play(&"beam_clang", global_position, -6.0, 0.15)


## Guľka: cink, iskry a guľka letí ďalej – do najbližšieho mafiána na dohľad
func take_hit(damage: float, dir: Vector2) -> void:
	_spin += signf(dir.x) * 4.0
	var at: Vector2 = _center()
	Sfx.play(&"beam_clang", at, -2.0, 0.15)
	Sfx.play([&"ricochet_1", &"ricochet_2"][randi() % 2], at, -2.0, 0.1)
	Burst.spawn(get_tree().current_scene, at, -dir, Color(1.0, 0.75, 0.35), 8, 90.0)
	Gangster.noise(at, noise_radius)
	var out: Vector2 = _aim_at_enemy(at)
	if out == Vector2.ZERO:
		out = Vector2(-dir.x, dir.y).normalized()   # nikto na dohľad – odrazí sa späť
	var b := BULLET.instantiate()
	b.direction = out
	b.shooter = self
	b.damage = maxf(damage, 1.0)
	b.speed = 760.0
	b.lifetime = 0.8
	b.hit_mask = 1 | 4 | COVER_LAYER   # odrazená guľka kuchárov a hostí nezasiahne (len svet, mafiánov, kryt)
	b.modulate = Color(1.0, 0.85, 0.45)
	b.global_position = at
	get_tree().current_scene.add_child.call_deferred(b)


func _center() -> Vector2:
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s and s.texture:
		return s.global_position + Vector2(s.texture.get_width() / 2.0, s.texture.get_height() * 0.65).rotated(rotation)
	return global_position + Vector2(0, 12)


## Smer k hrudi najbližšieho živého mafiána, ktorého odtiaľ vidno (nič medzi nimi). ZERO = nikto.
func _aim_at_enemy(from: Vector2) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_d: float = reach
	var space := get_world_2d().direct_space_state
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var g := n as Gangster
		if g == null or g.state == Gangster.State.DEAD:
			continue
		var chest: Vector2 = g.global_position + Vector2(0, -40)
		var d: float = from.distance_to(chest)
		if d >= best_d:
			continue
		var q := PhysicsRayQueryParameters2D.create(from, chest, 1 | COVER_LAYER)
		if space.intersect_ray(q).is_empty():
			best_d = d
			best = (chest - from).normalized()
	return best
