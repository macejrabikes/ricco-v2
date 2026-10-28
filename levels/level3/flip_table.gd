extends Node2D
## Stôl, ktorý sa dá prevrátiť na bok (kapitola III – klub The Blue Canary): pokrový stôl v herni prevráti Ricco (F),
## písací stôl v kancelárii prevráti Sal, keď sa pri poplachu zamkne (club_back.gd). Doska postavená na bok je vysoký
## kryt (vrstva 6 – zastaví guľky aj pohľad). Karty, žetóny a papiere sa rozletia, hluk počuje celá miestnosť.
## Poloha uzla = stred stola na podlahe. Deti: Sprite (stôl), Cover (StaticBody2D, vrstva 6 – Shape vypnutý, kým stôl
## stojí), voliteľne Spot (InteractSpot – nápoveda „F – FLIP“).
## Godot docs: classes/class_collisionshape2d (set_deferred disabled)

signal flipped

@export var flipped_texture: Texture2D
@export var flipped_offset: Vector2 = Vector2(-47, -46)   ## poloha obrázka prevráteného stola voči uzlu
@export var noise_radius: float = 300.0

var is_flipped: bool = false


func _ready() -> void:
	var spot := get_node_or_null(^"Spot") as InteractSpot
	if spot:
		spot.used.connect(flip)


## quiet = bez zvuku a hluku (stôl už je prevrátený, keď sa scéna načíta – kancelária zamknutá od začiatku)
func flip(quiet: bool = false) -> void:
	if is_flipped:
		return
	is_flipped = true
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s and flipped_texture:
		s.texture = flipped_texture
		s.position = flipped_offset
	var cs := get_node_or_null(^"Cover/Shape") as CollisionShape2D
	if cs:
		cs.set_deferred(&"disabled", false)
	var spot := get_node_or_null(^"Spot")
	if spot:
		spot.queue_free()
	if quiet:
		return
	Sfx.play(&"crate_break", global_position + Vector2(0, -20), -4.0, 0.1)
	Burst.spawn(get_parent(), global_position + Vector2(0, -30), Vector2.UP, Color(0.95, 0.92, 0.85), 12, 120.0, Vector2(0, 400), 0.8)
	Gangster.noise(global_position, noise_radius)
	flipped.emit()
