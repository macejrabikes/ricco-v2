class_name CameraZone
extends Area2D
## Časť levelu s vlastnými hranicami kamery (Phantom Camera). Keď do nej Ricco vojde, hranice sa
## plynule presunú (napr. dole do pivnice), takže netreba prepínať mapu.

@export var limits: Rect2i = Rect2i(0, 0, 640, 360)
@export var blend_time: float = 0.6

static var _tween: Tween


func _ready() -> void:
	add_to_group(&"camera_zone")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(func(b: Node):
		if b.is_in_group(&"player"):
			apply(b, false))


func apply(player: Node, instant: bool) -> void:
	var pcam := player.get_node_or_null(^"PhantomCamera2D")
	if pcam == null:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	if instant:
		pcam.limit_left = limits.position.x
		pcam.limit_top = limits.position.y
		pcam.limit_right = limits.end.x
		pcam.limit_bottom = limits.end.y
		return
	_tween = pcam.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(pcam, "limit_left", limits.position.x, blend_time)
	_tween.tween_property(pcam, "limit_top", limits.position.y, blend_time)
	_tween.tween_property(pcam, "limit_right", limits.end.x, blend_time)
	_tween.tween_property(pcam, "limit_bottom", limits.end.y, blend_time)


## Zóna, v ktorej leží bod (na nastavenie hraníc hneď pri štarte z checkpointu)
static func find_at(tree: SceneTree, pos: Vector2) -> CameraZone:
	for z in tree.get_nodes_in_group(&"camera_zone"):
		var cz := z as CameraZone
		var shape := cz.get_node_or_null(^"Shape") as CollisionShape2D
		if shape and shape.shape is RectangleShape2D:
			var size: Vector2 = (shape.shape as RectangleShape2D).size
			if Rect2(cz.global_position - size / 2.0, size).has_point(pos):
				return cz
	return null
