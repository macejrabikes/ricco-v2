extends AnimatableBody2D
## Plávajúci sud v zatopenej pivnici vily (kapitola IV – cellar.tscn): pomaly sa hojdá hore-dole na hladine.
## Je to jednosmerná plošinka (CollisionShape2D s one_way_collision, skupina „platform“) – Ricco po ňom môže
## preskákať ponad vodu (ale nad hladinou ho brodiaci sa strážcovia s baterkou vidia).
## Skupina „floaters“: keď voda klesá (pump.gd), čerpadlo posúva hladinu cez set_base – na dne sud dosadne a nehojdá sa.
## Godot docs: classes/class_animatablebody2d (sync_to_physics)

@export var amplitude: float = 2.5     ## px hore-dole
@export var period: float = 2.6        ## s – jedno pohojdanie
@export var phase: float = 0.0         ## 0–1 – posun, aby sa sudy nehojdali naraz

var _base_y: float
var _t: float = 0.0
var _afloat: bool = true


func _ready() -> void:
	add_to_group(&"platform")
	add_to_group(&"floaters")
	sync_to_physics = true
	_base_y = position.y
	_t = phase * period


## Nová hladina (y bez hojdania); afloat = false → sud leží na dne
func set_base(y: float, afloat: bool = true) -> void:
	_base_y = y
	_afloat = afloat


func _physics_process(delta: float) -> void:
	_t += delta
	var k: float = 1.0 if _afloat else 0.0
	position.y = _base_y + sin(_t * TAU / period) * amplitude * k
	rotation = sin(_t * TAU / period + 1.1) * 0.05 * k
