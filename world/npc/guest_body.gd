extends StaticBody2D
## Telo hosťa pre guľky (vytvorí ho world/npc/guest.gd) – zásah pošle hosťovi (Guest je Sprite2D, guľka hľadá take_hit na kolízii)

func take_hit(damage: float, dir: Vector2) -> void:
	var g: Node = get_meta(&"guest", null)
	if g and is_instance_valid(g):
		g.take_hit(damage, dir)
