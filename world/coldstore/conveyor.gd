extends StaticBody2D
## Pás na nakladanie (tunel k lodi). Telo stojí, ale constant_linear_velocity „vezie“ všetko, čo na ňom stojí
## (Ricco ide s pásom, keď zoskočí, rýchlosť si nechá). Obrázok pásu sa posúva, debny na páse idú s ním
## a na konci zmiznú v otvore do podpalubia (vrátia sa na začiatok – začiatok aj koniec sú za stenou).
## Debny sú AnimatableBody2D (dá sa na nich stáť, zastavia pohľad aj guľky).
## Godot docs: classes/class_staticbody2d (constant_linear_velocity), classes/class_animatablebody2d

@export var speed: float = 40.0      ## px/s – kladné = doprava
@export var length: float = 480.0    ## px – dĺžka pásu (uzol je na ľavom konci, vrch pásu na y = 0)
@export var hidden_margin: float = 40.0   ## px za koncami pásu (v stene), kde sa debny vracajú

var _belt: Sprite2D
var _crates: Array[Node2D] = []


func _ready() -> void:
	constant_linear_velocity = Vector2(speed, 0.0)
	_belt = get_node_or_null(^"Belt") as Sprite2D
	for c in get_children():
		if c is AnimatableBody2D:
			_crates.append(c)
	Sfx.loop(&"conveyor", self, Vector2(length / 2.0, -8.0), -12.0, &"SFX")


func _physics_process(delta: float) -> void:
	if _belt:
		_belt.region_rect.position.x = fposmod(_belt.region_rect.position.x - speed * delta, 16.0)
	for c in _crates:
		var x: float = c.position.x + speed * delta
		if speed > 0.0 and x > length + hidden_margin:
			x -= length + 2.0 * hidden_margin
		elif speed < 0.0 and x < -hidden_margin:
			x += length + 2.0 * hidden_margin
		c.position.x = x
