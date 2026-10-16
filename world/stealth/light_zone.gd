class_name LightZone
extends Area2D
## Svetlo (lampa, pec…), v ktorom Ricca vidno. Mimo neho je v interiéri tma a gangstri s needs_light ho nevidia.
## Tvar = CollisionShape2D v scéne (kužeľ lampy sa zjednoduší na obdĺžnik).

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2    # hráč
	monitorable = false
	body_entered.connect(func(b: Node): if b.get(&"light_zones") != null: b.light_zones += 1)
	body_exited.connect(func(b: Node): if b.get(&"light_zones") != null: b.light_zones = maxi(0, b.light_zones - 1))


## Zhasne (napr. lampa trafená klobúkom) – kto bol vo svetle, už nie je
func switch_off() -> void:
	for b in get_overlapping_bodies():
		if b.get(&"light_zones") != null:
			b.light_zones = maxi(0, b.light_zones - 1)
	set_deferred(&"monitoring", false)
