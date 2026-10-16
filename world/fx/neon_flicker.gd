extends Sprite2D
## Neónový nápis – občas zabliká (vymení obrázok za zhasnutý), žiara (dieťa „Glow“) sa stlmí s ním.

@export var on_texture: Texture2D
@export var off_texture: Texture2D
var _t: float = 0.0
var _next: float = 2.0
var _flicks: int = 0


func _process(delta: float) -> void:
	_t += delta
	if _t < _next:
		return
	_t = 0.0
	if _flicks > 0:
		_flicks -= 1
		_switch(texture == on_texture)   # prepni
		_next = randf_range(0.04, 0.12)
	else:
		_switch(false)
		_flicks = randi_range(2, 5) * 2
		_next = randf_range(2.0, 5.0)


func _switch(off: bool) -> void:
	texture = off_texture if off else on_texture
	var g := get_node_or_null(^"Glow") as CanvasItem
	if g:
		g.visible = not off
