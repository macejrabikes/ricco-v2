class_name WaterZone
extends Node2D
## Hlboká voda, v ktorej Ricco pláva (characters/ricco/ricco.gd – stav SWIM).
## Tvar vody sú obdĺžniky v súradniciach tohto uzla (stĺpce vody z mapy pivnice, tools/build_level1.gd).
## Horná hrana obdĺžnika je hladina, ak je nad ňou vzduch (open_top); pod nízkym stropom (sifón) hladina nie je.

@export var rects: Array[Rect2] = []
@export var open_top: Array[bool] = []


func _ready() -> void:
	add_to_group(&"water")


## Index obdĺžnika vody, v ktorom je bod (globálne súradnice), alebo -1
func find(p: Vector2) -> int:
	var lp: Vector2 = p - global_position
	for i in rects.size():
		if rects[i].has_point(lp):
			return i
	return -1


## Výška hladiny (globálne y) nad obdĺžnikom i, alebo INF, ak je nad ním strop
func surface_y(i: int) -> float:
	if i < 0 or not open_top[i]:
		return INF
	return rects[i].position.y + global_position.y
