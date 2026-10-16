extends Sprite2D
## Potkan v tuneloch – pobehuje sem a tam, občas zastane (len pre atmosféru).

@export var span: float = 28.0
@export var speed: float = 34.0

var _home: Vector2
var _dir: float = 1.0
var _t: float = 0.0
var _pause: float = 0.0


func _ready() -> void:
	_home = position
	_dir = 1.0 if randf() < 0.5 else -1.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	position.x += _dir * speed * delta
	flip_h = _dir < 0.0
	_t += delta
	frame = int(_t * 10.0) % 2
	if absf(position.x - _home.x) > span:
		_dir = -_dir
		position.x = _home.x + signf(position.x - _home.x) * span
	if randf() < delta * 0.6:
		_pause = randf_range(0.4, 1.5)
