extends StaticBody2D
## Prepálená podlaha v horiacej vile (kapitola IV – útek): kus podlahy nad dierou. Keď naň Ricco stúpi, zapraská,
## zatrasie sa a o chvíľu sa prepadne – Ricco spadne o poschodie nižšie (tak sa ide ďalej). Deti (píše ich
## _art_src/make_villa_fire_scene.py): Shape (kolízia), Sprite (2 snímky: celá / zlomená), Trigger (Area2D nad podlahou).
## Godot docs: classes/class_staticbody2d, classes/class_tween

signal collapsed

@export var delay: float = 0.6            ## s od došľapu po prepadnutie

var _armed: bool = false


func _ready() -> void:
	var t := get_node_or_null(^"Trigger") as Area2D
	if t:
		t.collision_layer = 0
		t.collision_mask = 2
		t.body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if b.is_in_group(&"player"):
		_arm()


func _arm() -> void:
	if _armed:
		return
	_armed = true
	Sfx.play(&"plank_creak", global_position, 0.0)
	var spr := get_node_or_null(^"Sprite") as Sprite2D
	if spr:
		var x0: float = spr.position.x
		var tw := create_tween()
		for i in 6:
			tw.tween_property(spr, "position:x", x0 + (2.0 if i % 2 == 0 else -2.0), delay / 6.0)
		tw.tween_property(spr, "position:x", x0, 0.02)
	await get_tree().create_timer(delay, false).timeout
	var shape := get_node_or_null(^"Shape") as CollisionShape2D
	if shape:
		shape.set_deferred(&"disabled", true)
	if spr:
		spr.frame = 1
		var fall := create_tween().set_parallel(true)
		fall.tween_property(spr, "position:y", spr.position.y + 160.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(spr, "modulate:a", 0.0, 0.6)
	Sfx.play(&"crate_break", global_position, 0.0)
	for i in 6:
		Burst.spawn(get_parent(), global_position + Vector2(randf_range(-50.0, 50.0), 4.0), Vector2(randf_range(-0.5, 0.5), 1.0),
				Color(0.45, 0.3, 0.2), 3, 120.0, Vector2(0, 500), 0.8)
	Burst.spawn(get_parent(), global_position, Vector2.UP, Color(1.0, 0.6, 0.2), 10, 80.0, Vector2(0, -40), 1.0)
	collapsed.emit()
