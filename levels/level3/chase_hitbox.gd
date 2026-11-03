extends StaticBody2D
## Zásahová plocha v naháňačke (šofér v aute, policajt na motorke, okno Murphyho voza). Vrstva 4 ako nepriatelia:
## Riccove guľky a klobúk ju zasiahnu, postavy ňou prejdú. Zásah len pošle ďalej – signál hit (chase_car.gd, chase_moto.gd,
## patrol_wagon.gd). Godot docs: classes/class_staticbody2d

signal hit(damage: float, dir: Vector2)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0


func take_hit_at(damage: float, dir: Vector2, _pos: Vector2) -> void:
	hit.emit(damage, dir)


func take_hit(damage: float, dir: Vector2 = Vector2.ZERO, _blood: bool = true) -> void:
	hit.emit(damage, dir)


func hat_hit(damage: int, dir: Vector2) -> void:
	hit.emit(float(damage), dir)
