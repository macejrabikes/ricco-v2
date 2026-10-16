extends Node2D
## Nekonečne sa posúvajúca vrstva (napr. silueta mesta v menu). Dieťa „Sprite“ sa skopíruje vedľa seba
## a celá vrstva sa posúva doľava; po šírke obrázka sa vráti na začiatok, takže to nevidno.

@export var speed: float = 5.0   ## px/s

var _w: float = 640.0


func _ready() -> void:
	var s := get_node(^"Sprite") as Sprite2D
	_w = s.texture.get_width()
	for i in 2:
		var c := s.duplicate() as Sprite2D
		c.position.x += _w * (i + 1)
		add_child(c)


func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x <= -_w:
		position.x += _w
