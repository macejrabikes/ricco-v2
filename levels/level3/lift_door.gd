extends StaticBody2D
## Šachtové dvere nákladného výťahu (hotel Majestic – service_elevator.gd). Zatvorené = stena (do šachty sa nedá
## spadnúť), otvorené = priechod do kabíny. Otvára a zatvára ich výťah, keď na poschodí zastane / odíde.
## Deti: Shape (CollisionShape2D v otvore), Sprite (2 snímky: 0 = zatvorené, 1 = otvorené).
## Godot docs: classes/class_staticbody2d

var is_open: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0


func set_open(on: bool) -> void:
	if on == is_open:
		return
	is_open = on
	(get_node(^"Shape") as CollisionShape2D).set_deferred(&"disabled", on)
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s:
		s.frame = 1 if on else 0
	if on:
		Sfx.play(&"door_open", global_position + Vector2(0, -40), -10.0, 0.08)
