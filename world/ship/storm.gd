extends Node
## Búrka nad loďou: blesky (biely záblesk cez celú obrazovku + hrom s oneskorením podľa vzdialenosti).
## Signál `flashed` – level môže na chvíľu ukázať niečo, čo v tme nevidno (napr. siluetu Lou na mostíku).
## Godot docs: classes/class_canvaslayer, classes/class_tween

signal flashed

@export var interval: Vector2 = Vector2(7.0, 15.0)   ## s medzi bleskami (náhodne)
@export var first_delay: float = 2.5

var _rect: ColorRect
var _t: float = 0.0


func _ready() -> void:
	_t = first_delay
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_rect = ColorRect.new()
	_rect.color = Color(0.85, 0.9, 1.0, 0.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rect.material = m
	layer.add_child(_rect)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = randf_range(interval.x, interval.y)
		strike()


## Blesk: dva rýchle záblesky, potom hrom (bližší blesk = silnejší a skôr)
func strike(near: float = -1.0) -> void:
	if near < 0.0:
		near = randf()
	var a: float = lerpf(0.18, 0.45, near)
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", a, 0.04)
	tw.tween_property(_rect, "color:a", 0.0, 0.08)
	tw.tween_interval(0.07)
	tw.tween_property(_rect, "color:a", a * 0.8, 0.03)
	tw.tween_property(_rect, "color:a", 0.0, 0.35)
	flashed.emit()
	await get_tree().create_timer(lerpf(1.4, 0.15, near), false).timeout
	Sfx.play(&"thunder", Vector2.INF, lerpf(-12.0, -2.0, near), 0.1, &"Ambience")
