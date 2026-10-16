extends CanvasItem
## Plameň / žiara – jemne bliká (náhodná priehľadnosť a veľkosť), napr. oheň v peci.

@export var amount: float = 0.18

var _base_alpha: float
var _t: float = 0.0


func _ready() -> void:
	_base_alpha = modulate.a


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = randf_range(0.05, 0.12)
		modulate.a = _base_alpha * (1.0 - randf() * amount)
