extends StaticBody2D
## Sud pašovanej whisky v pivnici klubu The Blue Canary (kapitola III). Je to kryt (vrstva 6 – zastaví pohľad aj guľky,
## postavy ním prejdú). Prestrelený sud vyteká: na podlahe sa rozleje mláka whisky a úsek podlahy pod ňou
## (puddle_floor) sa pridá do skupiny „ice“ – Ricco sa po ňom kĺže ako po ľade (ricco.gd – _update_ice) a mafián,
## ktorý cez mláku prejde, sa pošmykne a spadne na chrbát (Gangster.trip) – potom sa dá zneškodniť (F).
## Deti: Sprite (barrel.png), Shape, Puddle (Sprite2D – mláka na podlahe, na začiatku scale.x = 0).
## Godot docs: classes/class_node (add_to_group)

@export var puddle_floor: NodePath            ## úsek podlahy pod mlákou (StaticBody2D)
@export var puddle_half: float = 44.0         ## px – polovica šírky mláky
@export var leak_texture: Texture2D

const TRIP_COOL := 3.0   ## s – ten istý mafián sa znova pošmykne až po tomto čase

var _leaking: bool = false
var _wet: float = 0.0               ## 0 → 1 – ako veľmi je whisky rozliata
var _stream_t: float = 0.0
var _drip_t: float = 0.0
var _puddle: Sprite2D
var _cool: Dictionary = {}          ## gangster (instance id) → s do ďalšieho pošmyknutia


func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	_puddle = get_node_or_null(^"Puddle") as Sprite2D
	if _puddle:
		_puddle.scale.x = 0.0


func take_hit(_damage: float, _dir: Vector2) -> void:
	leak()


func leak() -> void:
	if _leaking:
		return
	_leaking = true
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s and leak_texture:
		s.texture = leak_texture
	Sfx.play(&"splash", global_position, -14.0, 0.1)
	var f := get_node_or_null(puddle_floor)
	if f:
		f.add_to_group(&"ice")
	Gangster.noise(global_position, 140.0)


func _physics_process(delta: float) -> void:
	if not _leaking or _puddle == null:
		return
	_wet = minf(_wet + delta / 2.5, 1.0)
	_puddle.scale.x = _wet
	# prúd z diery v sude, kým sa mláka rozlieva
	_stream_t -= delta
	if _wet < 1.0 and _stream_t <= 0.0:
		_stream_t = 0.07
		Burst.spawn(get_parent(), global_position + Vector2(0, 3), Vector2(0.3, 1.0), Color(0.85, 0.55, 0.15, 0.85), 2, 40.0, Vector2(0, 300), 0.4)
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = randf_range(1.4, 2.6)
		Sfx.play(&"drip", global_position, -18.0, 0.1)
	var c: Vector2 = _puddle.global_position
	var half: float = puddle_half * _wet
	for k in _cool.keys():
		_cool[k] -= delta
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var e := g as Gangster
		if e == null or e.state == Gangster.State.DEAD:
			continue
		var id: int = e.get_instance_id()
		if _cool.get(id, 0.0) > 0.0:
			continue
		if absf(e.global_position.x - c.x) < half and absf(e.global_position.y - c.y) < 8.0 and absf(e.velocity.x) > 15.0:
			if e.trip(signf(e.velocity.x)):
				_cool[id] = TRIP_COOL
				Sfx.play(&"splash", e.global_position, -10.0, 0.1)
