extends StaticBody2D
## Karoséria taxíka v naháňačke (levels/level3/chase.gd). Pevná (vrstva 1 – Ricco po nej chodí, guľky do nej narazia).
## Každý zásah guľkou odletí iskrou a lakom a pošle signál hit – chase.gd z neho (a z drgnutí áut) počíta,
## ako je taxík doničený (dym, vybité okná, oheň). Godot docs: classes/class_staticbody2d

signal hit(damage: float, pos: Vector2)


func take_hit_at(damage: float, dir: Vector2, pos: Vector2) -> void:
	Burst.spawn(get_tree().current_scene, pos, -dir + Vector2(0, -0.5), Color(1.0, 0.82, 0.3), 5, 90.0)   # iskry a žltý lak
	Sfx.play([&"impact_wall", &"ricochet_1", &"ricochet_2"][randi() % 3], pos, -8.0, 0.12)
	hit.emit(damage, pos)


func take_hit(damage: float, dir: Vector2 = Vector2.ZERO, _blood: bool = true) -> void:
	take_hit_at(damage, dir, global_position + Vector2(90, -40))
