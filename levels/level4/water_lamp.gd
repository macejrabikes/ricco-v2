extends StaticBody2D
## Lampa na kábli nad zatopenou pivnicou vily (kapitola IV – cellar.tscn). Riccova guľka alebo klobúk pretrhne kábel:
## lampa spadne do vody, zaiskrí a prúd zloží každého, kto stojí vo vode (brodiaci sa strážcovia). Ricca, ak práve
## pláva, zraní (player_damage). Potom je tma – svetlo (LightZone) zhasne.
## Deti: Cord (Line2D od stropu po lampu), Lamp (Node2D – obrázok Sprite, Glow, Light = LightZone),
## Shape (CollisionShape2D cez kábel aj lampu – sem trafí guľka). Vodu nájde v skupine „water“ (WaterZone).
## Vrstva 4 ako nepriatelia: zasiahne ju Riccova guľka aj klobúk, mafiánske guľky nie.
## Godot docs: classes/class_staticbody2d, classes/class_line2d

signal shorted(kills: int)

@export var water_y: float = 0.0          ## globálne y hladiny
@export var reach: float = 900.0          ## px vodorovne od lampy – kam až prúd vo vode dosiahne
@export var player_damage: int = 2

const GRAVITY := 900.0

var _falling: bool = false
var _done: bool = false
var _vy: float = 0.0
var _lamp: Node2D
var _cord: Line2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	_lamp = get_node_or_null(^"Lamp") as Node2D
	_cord = get_node_or_null(^"Cord") as Line2D


func take_hit(_damage: float, _dir: Vector2) -> void:
	drop()


func hat_hit(_damage: float, _dir: Vector2) -> void:
	drop()


func drop() -> void:
	if _falling or _done or _lamp == null:
		return
	_falling = true
	(get_node(^"Shape") as CollisionShape2D).set_deferred(&"disabled", true)
	Sfx.play(&"punch_swing", _lamp.global_position, -4.0)
	Burst.spawn(get_parent(), _lamp.global_position + Vector2(0, -4), Vector2.UP, Color(1.0, 0.9, 0.5), 6, 60.0)
	if _cord:   # kábel sa pretrhne – hore ostane kúsok
		_cord.points = PackedVector2Array([Vector2.ZERO, Vector2(0, 8)])


func _physics_process(delta: float) -> void:
	if not _falling:
		return
	_vy += GRAVITY * delta
	_lamp.position.y += _vy * delta
	if _lamp.global_position.y >= water_y:
		_lamp.global_position.y = water_y
		_short()


## Lampa je vo vode: iskry, prúd zloží všetkých vo vode, potom tma
func _short() -> void:
	_falling = false
	_done = true
	var at: Vector2 = _lamp.global_position
	var scene := get_tree().current_scene
	Sfx.play(&"splash", at, 0.0, 0.05)
	Sfx.play(&"glass_break", at, -2.0, 0.1)
	for i in 4:   # iskry pobehnú po hladine na obe strany
		Burst.spawn(scene, at + Vector2(randf_range(-reach, reach) * 0.4, -2), Vector2.UP, Color(0.7, 0.9, 1.0), 10, 120.0, Vector2(0, 300), 0.45)
	Burst.spawn(scene, at, Vector2.UP, Color(1.0, 1.0, 0.8), 18, 160.0, Vector2(0, 400), 0.5)
	var kills: int = 0
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var e := g as Gangster
		if e == null or e.state == Gangster.State.DEAD:
			continue
		if _in_water(e.global_position + Vector2(0, -6)) and absf(e.global_position.x - at.x) < reach:
			e.take_hit(99.0, Vector2(signf(e.global_position.x - at.x) + 0.01, -0.6))
			kills += 1
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	if p and int(p.get(&"state")) == 5 and absf(p.global_position.x - at.x) < reach:   # 5 = SWIM
		p.call(&"take_damage", player_damage, at)
	Gangster.noise(at, 360.0)
	for n in [&"Glow", &"Sprite"]:
		var c := _lamp.get_node_or_null(NodePath(String(n))) as CanvasItem
		if c:
			c.visible = false
	var light := _lamp.get_node_or_null(^"Light") as LightZone
	if light:
		light.switch_off()
	shorted.emit(kills)


## Je bod (globálne) vo vode? (WaterZone v skupine „water“)
func _in_water(pos: Vector2) -> bool:
	for w in get_tree().get_nodes_in_group(&"water"):
		var wz := w as WaterZone
		if wz and wz.find(pos) >= 0:
			return true
	return false
