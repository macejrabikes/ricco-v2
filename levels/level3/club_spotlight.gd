extends StaticBody2D
## Sledovací reflektor na balkóne sály (kapitola III – klub The Blue Canary). Kužeľ svieti od lampy dolu do sály a
## škvrna svetla pomaly prechádza po podlahe sem a tam (ako lúč majáka v prístave – world/fx/lighthouse_beam.gd).
## V škvrne je LightZone: kto v nej stojí, toho mafiáni vidia (aj hostia – Guest).
## Osvetľovač (operator – gangster pri reflektore): kým o Riccovi nevie, reflektor prechádza sálou; keď Ricca zbadá,
## namieri škvrnu rovno na neho a sleduje ho (kým ho nezloží, Ricco sa v tme neschová). Keď je osvetľovač zložený,
## reflektor ostane svietiť na pódium (stage). Klobúk alebo guľka do reflektora ho zhasne nadobro.
## Deti: Lamp (Sprite2D), Shape. Kužeľ, škvrnu a LightZone si vytvorí sám.
## Godot docs: classes/class_polygon2d, classes/class_area2d, classes/class_canvasitemmaterial

@export var from_x: float = 1150.0           ## škvrna prechádza od…
@export var to_x: float = 2250.0             ## …po (globálne x)
@export var floor_y: float = 0.0             ## podlaha sály (globálne y)
@export var period: float = 11.0             ## s – tam a späť
@export var stage: Vector2 = Vector2(2420, -40)   ## kam svieti, keď osvetľovač padne
@export var operator_path: NodePath
@export var follow_speed: float = 260.0      ## px/s – takto rýchlo škvrna dobehne Ricca
@export var spot_w: float = 72.0
@export var zone_up: float = 90.0            ## px – výška svetla nad škvrnou
@export var lens: Vector2 = Vector2(14, -24) ## sklo reflektora voči uzlu (odtiaľ ide kužeľ)

const GLOW := preload("res://levels/level1/art/glow.png")

var _off: bool = false
var _t: float = 0.0
var _spot: Vector2 = Vector2.ZERO   ## stred škvrny na podlahe (globálne)
var _beam: Polygon2D
var _glow: Sprite2D
var _flare: Sprite2D
var _zone: Area2D
var _shape: RectangleShape2D
var _operator: Node2D
var _player: Node2D


func _ready() -> void:
	collision_layer = 4   # zasiahne ho Riccova guľka aj klobúk
	collision_mask = 0
	_operator = get_node_or_null(operator_path) as Node2D
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam = Polygon2D.new()
	_beam.material = add
	_beam.z_index = 4
	add_child(_beam)
	_glow = _make_glow(Color(1.0, 0.92, 0.7, 0.5))
	_glow.top_level = true
	_flare = _make_glow(Color(1.0, 0.95, 0.8, 0.8))
	_flare.position = lens
	_flare.scale = Vector2(0.5, 0.5)
	_zone = Area2D.new()
	_zone.set_script(preload("res://world/stealth/light_zone.gd"))
	_zone.top_level = true
	var cs := CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_shape.size = Vector2(spot_w, zone_up + 12.0)
	cs.shape = _shape
	_zone.add_child(cs)
	add_child(_zone)
	_spot = Vector2(from_x, floor_y)
	_update_visual()


func _make_glow(col: Color) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = GLOW
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.modulate = col
	g.z_index = 4
	add_child(g)
	return g


func _physics_process(delta: float) -> void:
	if _off:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	var target: Vector2 = _spot
	var speed: float = 420.0
	match _mode():
		0:   # prechádza sálou
			_t += delta
			var k: float = (1.0 - cos(TAU * _t / period)) / 2.0
			target = Vector2(lerpf(from_x, to_x, k), floor_y)
		1:   # sleduje Ricca
			if _player:
				target = _player.global_position
			speed = follow_speed
		2:   # osvetľovač padol – svieti na pódium
			target = stage
			speed = 160.0
		_:   # osvetľovač je omráčený – reflektor stojí
			speed = 0.0
	_spot = _spot.move_toward(target, speed * delta)
	_update_visual()


## 0 = prechádza, 1 = sleduje Ricca, 2 = na pódium, 3 = stojí
func _mode() -> int:
	if _operator == null or not is_instance_valid(_operator) or int(_operator.get(&"state")) == 10:   # Gangster.State.DEAD
		return 2
	var st: int = int(_operator.get(&"state"))
	if st >= 2 and st <= 8:   # AIM … RECOVER – vie o Riccovi
		return 1
	if st == 9:               # STUN
		return 3
	return 0


func _update_visual() -> void:
	var tip: Vector2 = _spot - global_position
	var hw: float = spot_w * 0.5
	_beam.polygon = PackedVector2Array([lens + Vector2(0, -3), lens + Vector2(0, 3), tip + Vector2(hw, 2), tip + Vector2(-hw, 2)])
	_beam.vertex_colors = PackedColorArray([Color(1.0, 0.95, 0.75, 0.32), Color(1.0, 0.95, 0.75, 0.32),
			Color(1.0, 0.9, 0.6, 0.12), Color(1.0, 0.9, 0.6, 0.12)])
	_glow.global_position = _spot + Vector2(0, -6)
	_glow.scale = Vector2(spot_w / 60.0, 0.5)
	_zone.global_position = _spot + Vector2(0, -zone_up / 2.0 + 6.0)


func take_hit(_damage: float, _dir: Vector2) -> void:
	switch_off()


func hat_hit(_damage: float, _dir: Vector2) -> void:
	switch_off()


func switch_off() -> void:
	if _off:
		return
	_off = true
	Sfx.play(&"glass_break", global_position + lens)
	Burst.spawn(get_parent(), global_position + lens, Vector2.UP, Color(1.0, 0.9, 0.6), 10, 80.0)
	_beam.visible = false
	_glow.visible = false
	_flare.visible = false
	(_zone as LightZone).switch_off()
	var lamp := get_node_or_null(^"Lamp") as CanvasItem
	if lamp:
		lamp.modulate = Color(0.6, 0.6, 0.65)


func is_off() -> bool:
	return _off
