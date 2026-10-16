extends StaticBody2D
## Visiaca lampa, ktorú zhasne hodený klobúk (alebo guľka): zmizne kužeľ, žiara aj svetlo (LightZone).
## Deti: Cone, Glow (Sprite2D), Light (LightZone). Vrstva 4 = ako nepriatelia, aby ju klobúk trafil.

var _off: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0


func hat_hit(_damage: int, dir: Vector2) -> void:
	switch_off(dir)


func take_hit(_damage: int, dir: Vector2) -> void:
	switch_off(dir)


func switch_off(dir: Vector2 = Vector2.UP) -> void:
	if _off:
		return
	_off = true
	for n in [&"Cone", &"Glow"]:
		var c := get_node_or_null(NodePath(String(n))) as CanvasItem
		if c:
			c.visible = false
	var light := get_node_or_null(^"Light") as LightZone
	if light:
		light.switch_off()
	Burst.spawn(get_parent(), global_position + Vector2(0, 6), -dir, Color(1.0, 0.85, 0.5), 8, 70.0)
	# lampa sa zahojdá
	var tw := create_tween()
	tw.tween_property(self, "rotation", 0.35 * signf(dir.x if dir.x != 0.0 else 1.0), 0.15)
	tw.tween_property(self, "rotation", -0.2 * signf(dir.x if dir.x != 0.0 else 1.0), 0.3)
	tw.tween_property(self, "rotation", 0.0, 0.4)
