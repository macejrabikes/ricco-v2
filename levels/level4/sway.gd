extends Node2D
## Pomalé kývanie vo vetre (kapitola IV – lampáš na stĺpe móla). Uzol = úchyt (kĺb), deti visia pod ním a kývu sa
## s ním – aj LightZone, takže svetlo lampáša sa posúva sem a tam. Zhasnutý lampáš (hat_lamp.gd) sa kýve ďalej.
## Godot docs: classes/class_node2d

@export var amplitude: float = 0.22   ## rad – najväčší výkyv
@export var period: float = 3.4       ## s – tam a späť
@export var gust: float = 0.12        ## rad – občasný náraz vetra navyše

var _t: float = 0.0
var _gust_t: float = 4.0
var _extra: float = 0.0


func _ready() -> void:
	_t = randf() * period


func _process(delta: float) -> void:
	_t += delta
	_gust_t -= delta
	if _gust_t <= 0.0:
		_gust_t = randf_range(5.0, 9.0)
		_extra = gust
	_extra = move_toward(_extra, 0.0, delta * 0.05)
	rotation = sin(_t * TAU / period) * (amplitude + _extra)
