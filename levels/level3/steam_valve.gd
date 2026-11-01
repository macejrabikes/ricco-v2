extends StaticBody2D
## Ventil na parnom potrubí (hotel Majestic – kuchyňa pri kotloch na vývar, práčovňa pri parnom lise). Občas si
## len pofúkne obláčik. Riccova guľka alebo klobúk ho utrhne: z potrubia vyrazí prúd horúcej pary (direction, length)
## – mafián v ňom sa obarí a padne na chrbát (Gangster.trip, kým leží, dá sa zneškodniť F), Ricca opáli.
## Para potom ešte chvíľu visí v miestnosti ako oblak (kryt, vrstva 6) – zastaví pohľad aj guľky, Ricco ním prejde.
## Syčanie počujú mafiáni v okolí (Gangster.noise). Deti: Sprite (2 snímky: celý / utrhnutý ventil), Shape.
## Godot docs: classes/class_staticbody2d, classes/class_rectangleshape2d

signal burst

@export var direction: Vector2 = Vector2.RIGHT   ## kam strieľa prúd pary
@export var length: float = 96.0                 ## px – dĺžka prúdu
@export var jet_time: float = 5.0                ## s – ako dlho prúd syčí
@export var cloud_time: float = 8.0              ## s – ako dlho potom visí oblak
@export var cloud_size: Vector2 = Vector2(110, 70)
@export var noise_radius: float = 220.0

const COVER_LAYER := 32
const STEAM := Color(0.92, 0.94, 0.96, 0.55)

var _broken: bool = false
var _jet: float = 0.0
var _puff_t: float = 0.0
var _cloud: StaticBody2D
var _hiss: Node
var _player: Node2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	_puff_t = randf_range(2.0, 5.0)
	direction = direction.normalized()


func take_hit(_damage: float, _dir: Vector2) -> void:
	open()


func hat_hit(_damage: int, _dir: Vector2) -> void:
	open()


func open() -> void:
	if _broken:
		return
	_broken = true
	_jet = jet_time
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s and s.hframes > 1:
		s.frame = 1
	Sfx.play(&"impact_wall", global_position, -4.0, 0.1)
	_hiss = Sfx.loop(&"steam_hiss", self, Vector2.ZERO, -4.0, &"SFX")
	Gangster.noise(global_position, noise_radius)
	_make_cloud()
	burst.emit()


func _make_cloud() -> void:
	_cloud = StaticBody2D.new()
	_cloud.collision_layer = COVER_LAYER
	_cloud.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = cloud_size
	cs.shape = r
	_cloud.add_child(cs)
	get_parent().add_child.call_deferred(_cloud)
	_cloud.position = position + direction * length * 0.5 + Vector2(0, -cloud_size.y * 0.25)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	var scene := get_tree().current_scene
	if not _broken:
		_puff_t -= delta
		if _puff_t <= 0.0:   # kvapka pary z netesného ventilu
			_puff_t = randf_range(3.0, 6.0)
			Burst.spawn(scene, global_position + Vector2(0, -4), Vector2(0, -1), Color(0.9, 0.92, 0.95, 0.35), 3, 14.0, Vector2(0, -20), 1.2)
		return
	if _jet > 0.0:
		_jet -= delta
		# prúd: obláčiky pozdĺž celej dĺžky, ďaleko sa rozplývajú
		for i in 3:
			var t: float = randf()
			var p: Vector2 = global_position + direction * length * t + Vector2(0, randf_range(-5.0, 5.0))
			Burst.spawn(scene, p, direction + Vector2(0, -0.3), STEAM, 1, 60.0 + 80.0 * (1.0 - t), Vector2(0, -30), 0.5)
		_scald()
		if _jet <= 0.0:
			if _hiss:
				_hiss.queue_free()
				_hiss = null
			var tw := create_tween()
			tw.tween_interval(cloud_time)
			tw.tween_callback(_clear_cloud)
	elif is_instance_valid(_cloud) and randf() < delta * 10.0:   # oblak ešte visí
		var c: Vector2 = _cloud.global_position + Vector2(randf_range(-cloud_size.x, cloud_size.x) * 0.45, randf_range(-cloud_size.y, cloud_size.y) * 0.4)
		Burst.spawn(scene, c, Vector2(0, -1), Color(0.9, 0.92, 0.95, 0.3), 1, 8.0, Vector2(0, -6), 1.6)


func _clear_cloud() -> void:
	if is_instance_valid(_cloud):
		_cloud.queue_free()


## Kto je v prúde pary: mafián padne (obarí sa), Ricco sa popáli
func _scald() -> void:
	var a: Vector2 = global_position
	var b: Vector2 = global_position + direction * length
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(4, 30)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(4, 30)
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var g := n as Gangster
		if g == null or g.state == Gangster.State.DEAD:
			continue
		var p: Vector2 = g.global_position + Vector2(0, -30)
		if p.x > lo.x and p.x < hi.x and p.y > lo.y and p.y < hi.y:
			if g.trip(signf(direction.x) if direction.x != 0.0 else 1.0):
				Sfx.play(&"hurt", g.global_position + Vector2(0, -50), -8.0, 0.15)
	if _player and _player.get(&"state") != 3:
		var pp: Vector2 = _player.global_position + Vector2(0, -16)
		if pp.x > lo.x and pp.x < hi.x and pp.y > lo.y and pp.y < hi.y:
			_player.call(&"take_damage", 1, global_position)
