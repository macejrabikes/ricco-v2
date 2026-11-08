extends Node2D
## Dym pod stropom horiacej izby (kapitola IV – útek z vily): tmavý pás od stropu skoro po zem, dole ostáva pár pixelov
## čistého vzduchu. Kto v ňom stojí vzpriamene, dusí sa (každých damage_time s jeden zásah); prikrčený (sneak) alebo
## na bruchu (šmyk) dýcha. Poloha uzla = ľavý horný roh izby, size = šírka × výška (po podlahu).
## Godot docs: classes/class_gradienttexture2d

signal choking   ## Ricco sa prvý raz rozkašle (level povie hlášku)

@export var size: Vector2 = Vector2(1000, 206)
@export var clear: float = 40.0           ## px nad podlahou bez dymu
@export var damage_time: float = 1.8      ## s vzpriamene v dyme → 1 zásah
@export var density: float = 0.72         ## nepriehľadnosť pod stropom

var _c: float = 0.0
var _player: Node2D
var _warned: bool = false
var _puff: float = 0.0


func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.09, 0.07, 0.07, density))
	g.set_color(1, Color(0.16, 0.13, 0.13, 0.0))
	g.add_point(0.75, Color(0.13, 0.1, 0.1, density * 0.65))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 8
	t.height = 64
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.scale = Vector2(size.x / 8.0, (size.y - clear + 12.0) / 64.0)
	s.z_index = 15
	add_child(s)


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		if _player == null:
			return
	var p: Vector2 = _player.global_position - global_position
	var inside: bool = p.x >= 0.0 and p.x <= size.x and p.y > 0.0 and p.y <= size.y + 4.0
	var st: int = int(_player.get(&"state"))
	var low: bool = bool(_player.get(&"sneaking")) or st == 4   # prikrčený / šmyk na bruchu
	if not inside or low or st == 3 or bool(_player.get(&"in_cutscene")):
		_c = maxf(0.0, _c - delta * 2.0)
		return
	_c += delta
	_puff -= delta
	if _puff <= 0.0:
		_puff = 0.5
		Burst.spawn(get_parent(), _player.global_position + Vector2(0, -36), Vector2.UP, Color(0.5, 0.48, 0.48, 0.6), 2, 20.0, Vector2(0, -20), 0.6)
	if _c >= damage_time * 0.5 and not _warned:
		_warned = true
		choking.emit()
	if _c >= damage_time:
		_c = 0.0
		if _player.has_method(&"take_damage"):
			_player.call(&"take_damage", 1, _player.global_position + Vector2(0, -60))
