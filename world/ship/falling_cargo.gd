extends Sprite2D
## Debna, ktorú Big Lou pustí zo siete žeriavu (world/ship/crane.gd). Padá, kto stojí pod ňou, príde o 2 kúsky pizze
## (Louovi na hlavu za 3 HP). Po dopade ostane stáť ako dočasný kryt (world/ship/ship_crate.gd, slabšia – CRATE_HP),
## alebo sa rozletí (stay = false, dopad na vysokú kopu, alebo by niekoho zavrela do seba).
## Godot docs: classes/class_sprite2d, classes/class_physicsdirectspacestate2d

const CRATE := preload("res://world/ship/ship_crate.gd")
const TEXTURES: Array[String] = ["crate.png", "crate_maple.png", "crate_whisky.png"]
const DOCKS := "res://levels/level2/art/docks/"
const GRAVITY := 640.0
const SIZE := Vector2(30, 20)
const CRATE_HP := 5.0   ## debna zo žeriavu vydrží pár Louových guliek (pevné debny na palube 10)

var velocity: Vector2 = Vector2.ZERO
var stay: bool = true
var _tex_name: String
var _hit: bool = false


func _ready() -> void:
	_tex_name = TEXTURES[randi() % TEXTURES.size()]
	texture = load(DOCKS + _tex_name)
	z_index = 1
	rotation = randf_range(-0.1, 0.1)


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	rotation = move_toward(rotation, 0.0, delta)
	var to: Vector2 = global_position + velocity * delta
	var tree := get_tree()
	var box := Rect2(to - SIZE / 2.0, SIZE)
	# Ricco pod debnou
	var p := tree.get_first_node_in_group(&"player") as Node2D
	if not _hit and p and p.get(&"state") != 3:
		var h: float = 24.0 if p.get(&"state") == 4 else 40.0
		if box.intersects(Rect2(p.global_position + Vector2(-7, -h), Vector2(14, h))):
			_hit = true
			p.take_damage(2, global_position)
			p.velocity = Vector2(signf(p.global_position.x - global_position.x) * 180.0, -120.0)
	# Lou (keď ho Ricco naláka pod sieť)
	for b in tree.get_nodes_in_group(&"boss"):
		var bn := b as Node2D
		if bn and box.intersects(Rect2(bn.global_position + Vector2(-12, -86), Vector2(28, 28))) and bn.has_method(&"cargo_hit"):
			bn.cargo_hit(3.0)
			_land(true)
			return
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, to + Vector2(0, SIZE.y / 2.0), 1))
	if hit.is_empty():
		global_position = to
		return
	global_position = hit.position - Vector2(0, SIZE.y / 2.0)
	_land(hit.position.y < -30.0 or not stay)   # na vysokú kopu sa už nezmestí


func _land(shatter: bool) -> void:
	set_physics_process(false)
	var scene := get_tree().current_scene
	Sfx.play(&"land", global_position, 4.0, 0.1)
	Burst.spawn(scene, global_position + Vector2(0, SIZE.y / 2.0), Vector2(0, -1), Color(0.6, 0.6, 0.65, 0.6), 8, 50.0, Vector2(0, 40), 0.5)
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	if p and p.global_position.distance_to(global_position) < 220.0:
		p.set(&"shake_timer", 0.15)
		p.set(&"shake_strength", 2.5)
	# stojí tam niekto (Ricco, Lou)? Pevná debna by ho zavrela do seba a nemohol by sa pohnúť → radšej sa rozletí
	if _someone_at(global_position.round()):
		shatter = true
	# zmení sa na skutočnú debnu (kryt) – telo sa poskladá ešte pred vložením do stromu
	var b := StaticBody2D.new()
	b.set_script(CRATE)
	b.ammo_chance = 0.35
	b.hp = CRATE_HP
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = SIZE
	cs.shape = r
	b.add_child(cs)
	var s := Sprite2D.new()
	s.name = "Sprite"
	s.texture = texture
	s.centered = false
	s.position = -SIZE / 2.0
	s.z_index = -1
	b.add_child(s)
	b.add_to_group(&"ship_cover", true)
	b.add_to_group(&"crane_crate", true)   # Lou počíta, koľko ich už na palube stojí
	b.position = global_position.round()
	scene.add_child(b)
	if shatter:
		b.shatter(Vector2(0, -1))
	queue_free()


## Je v mieste debny postava (Ricco vrstva 2, Lou vrstva 4)? Godot docs: classes/class_physicsshapequeryparameters2d
func _someone_at(pos: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var r := RectangleShape2D.new()
	r.size = SIZE + Vector2(2, 2)
	q.shape = r
	q.transform = Transform2D(0.0, pos)
	q.collision_mask = 2 | 4
	for h in get_world_2d().direct_space_state.intersect_shape(q, 4):
		if h.collider is CharacterBody2D:
			return true
	return false
