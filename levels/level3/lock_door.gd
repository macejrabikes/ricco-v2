extends StaticBody2D
## Dvere do Salovej kancelárie (kapitola III – zákulisie klubu The Blue Canary). Kým je v klube kľud, sú otvorené.
## Pri poplachu sa Sal zamkne (club_back.gd – set_locked): zamknuté dvere sú stena, zastavia pohyb, pohľad aj guľky.
## Ricco ich vystrelí – po hits_to_break zásahoch zámok povolí a dvere sa rozletia (hluk). Alebo ide strechou cez svetlík.
## Poloha uzla = spodok dverí na podlahe. Deti: Sprite (door_side.png – 2 snímky: zatvorené / otvorené), Shape.
## Godot docs: classes/class_staticbody2d

signal broken

@export var hits_to_break: int = 3

var locked: bool = false
var _hits: int = 0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_apply()


func set_locked(on: bool, quiet: bool = false) -> void:
	if locked == on:
		return
	locked = on
	_hits = 0
	_apply()
	if not quiet:
		Sfx.play(&"door_close" if on else &"door_open", global_position + Vector2(0, -40), -4.0)
		if on:
			Sfx.play(&"slot_open", global_position + Vector2(0, -44), -6.0, 0.1)   # cvaknutie zámky


func _apply() -> void:
	(get_node(^"Shape") as CollisionShape2D).set_deferred(&"disabled", not locked)
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s:
		s.frame = 0 if locked else 1


## Riccova guľka do zamknutých dverí – zámka po čase povolí
func take_hit(_damage: float, dir: Vector2) -> void:
	if not locked:
		return
	_hits += 1
	var at := global_position + Vector2(0, -44)
	Sfx.play(&"impact_wall", at, -2.0, 0.1)
	Burst.spawn(get_parent(), at, -dir, Color(0.5, 0.32, 0.2), 6, 70.0, Vector2(0, 300), 0.5)
	if _hits >= hits_to_break:
		locked = false
		_apply()
		Sfx.play(&"crate_break", at, 0.0, 0.1)
		Burst.spawn(get_parent(), at, dir, Color(0.5, 0.32, 0.2), 14, 140.0, Vector2(0, 400), 0.7)
		Gangster.noise(at, 320.0)
		broken.emit()
