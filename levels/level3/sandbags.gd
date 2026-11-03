extends StaticBody2D
## Policajná barikáda z vriec s pieskom na Queensboro Bridge (levels/level3/chase.gd) – nízky kryt (vrstva 6, COVER_LAYER):
## Ricco sa za ňou prikrčí, guľky ju nepreletia. Murphyho voz (patrol_wagon.gd) ju pri nájazde rozmetá (shatter).
## Počiatok = stred spodku. Godot docs: classes/class_staticbody2d

const TEX := preload("res://levels/level3/art/chase/sandbags.png")

var _done: bool = false


func _ready() -> void:
	add_to_group(&"sandbags")
	collision_layer = 32
	collision_mask = 0
	var s := Sprite2D.new()
	s.texture = TEX
	s.centered = false
	s.position = Vector2(-20, -22)
	add_child(s)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(36, 20)
	cs.shape = r
	cs.position = Vector2(0, -10)
	add_child(cs)


func shatter(dir: Vector2) -> void:
	if _done:
		return
	_done = true
	var scene := get_tree().current_scene
	Sfx.play(&"crate_break", global_position + Vector2(0, -10), -2.0, 0.1)
	Burst.spawn(scene, global_position + Vector2(0, -12), dir, Color(0.69, 0.61, 0.44), 18, 180.0, Vector2(0, 500), 0.7)
	Burst.spawn(scene, global_position + Vector2(0, -8), Vector2.UP, Color(0.8, 0.74, 0.6, 0.5), 10, 40.0, Vector2(0, -20), 1.2)
	queue_free()
