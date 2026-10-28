extends StaticBody2D
## Poklop v podlahe (kapitola III – klub The Blue Canary): uhoľná šachta v chodníku pred klubom, padacie dvere v izbe
## personálu nad šatňou speváčky. Ricco pri nich stlačí F a otvorí ich – prepadne dolu (šachtou do tunela, do šatne).
## Deti: Sprite (2 snímky – zatvorené / otvorené), Shape, Spot (InteractSpot – nápoveda „F – OPEN“).
## Godot docs: classes/class_staticbody2d

signal opened

@export var noise_radius: float = 0.0   ## > 0 = vŕzganie počujú mafiáni v okolí

var is_open: bool = false


func _ready() -> void:
	var spot := get_node_or_null(^"Spot") as InteractSpot
	if spot:
		spot.used.connect(open)


func open() -> void:
	if is_open:
		return
	is_open = true
	(get_node(^"Shape") as CollisionShape2D).set_deferred(&"disabled", true)
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s:
		s.frame = 1
	Sfx.play(&"slot_open", global_position, -4.0, 0.1)
	if noise_radius > 0.0:
		Gangster.noise(global_position, noise_radius)
	opened.emit()
