extends StaticBody2D
## Visiaca polovica ošípanej na háku (mraziareň). Vrstva 6 (32) = kryt: zastaví pohľad mafiánov aj guľky,
## ale postavy ňou prejdú (Ricco aj mafiáni majú masku len 1). Po zásahu sa rozhojdá.
## Uzol je dieťa „Swing“ (Node2D s pivotom v úchyte háku) – hojdá sa celé aj s reťazou.
## Godot docs: classes/class_staticbody2d, tutorials/physics/physics_introduction (collision layers)

const STIFF := 9.0     ## tuhosť kyvadla (1/s²)
const DAMP := 1.6      ## tlmenie

var wood: bool = false   ## debna namiesto mäsa (hook_rail.gd – carcass_texture): triesky a zvuk dreva

var _angle: float = 0.0
var _spin: float = 0.0
var _swing: Node2D


func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	_swing = get_parent() as Node2D
	_angle = randf_range(-0.03, 0.03)


func _physics_process(delta: float) -> void:
	if _swing == null:
		return
	_spin += (-STIFF * _angle - DAMP * _spin) * delta
	_angle += _spin * delta
	_swing.rotation = _angle


## Guľka (weapons/pistol/bullet.gd): mäso sa rozhojdá, odletia ľadové triesky
func take_hit(_damage: float, dir: Vector2) -> void:
	_spin += -signf(dir.x) * 1.4
	if wood:
		Sfx.play(&"knock_wood", global_position + Vector2(0, 16), -4.0, 0.15)
		Burst.spawn(get_tree().current_scene, global_position + Vector2(0, 16), -dir + Vector2(0, -0.3),
				Color(0.62, 0.45, 0.26), 6, 70.0)
		return
	Sfx.play(&"carcass_hit", global_position + Vector2(0, 30), -3.0, 0.1)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, 34), -dir + Vector2(0, -0.3),
			Color(0.9, 0.96, 1.0, 0.9), 6, 70.0)


## Hodený klobúk – len odrazí a rozhojdá
func hat_hit(_damage: float, dir: Vector2) -> void:
	_spin += -signf(dir.x) * 1.0
