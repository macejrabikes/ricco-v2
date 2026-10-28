extends Node2D
## Šnúra s prádlom medzi strechami (kapitola III). Na šnúre visí kladka: Ricco sa jej vo vzduchu chytí (skok pri nej)
## a zvezie sa dole po šnúre – ako na háku v mraziarni (characters/ricco/ricco.gd – grab_hook / _process_hook),
## počas jazdy môže strieľať. Na konci šnúry ho kladka pustí, skokom (alebo S) sa pustí skôr.
## Kladka sa potom sama pomaly vráti na začiatok, takže sa dá ísť znova.
## Uzol = horný koniec šnúry (pri stĺpe), end = dolný koniec (relatívne). Prádlo sa rozvesí samo.
## Godot docs: classes/class_line2d, classes/class_node2d

@export var end: Vector2 = Vector2(200, 100)   ## px – dolný koniec šnúry voči uzlu
@export var clothes: int = 5                   ## koľko kusov prádla visí na šnúre
@export var cloth_seed: int = 1
@export var max_speed: float = 230.0           ## px/s – najväčšia rýchlosť jazdy
@export var accel: float = 320.0               ## px/s² – rozbeh z kopca
@export var start_s: float = 12.0              ## px od horného konca – tu kladka čaká
@export var end_margin: float = 12.0           ## px pred dolným koncom kladka Ricca pustí

const ART := "res://levels/level3/art/street/"
const TrolleyScript := preload("res://world/coldstore/hook_trolley.gd")
const GRIP := 12.0                             ## px pod šnúrou je úchyt kladky
const RETURN_SPEED := 70.0                     ## px/s – návrat prázdnej kladky
const REACH_BONUS := 6.0                       ## px navyše k Riccovmu hook_reach (kladka je malá)

var pulley: Node2D
var _player: Node2D
var _dir: Vector2
var _len: float
var _s: float
var _speed: float = 0.0
var _riding: bool = false
var _return_t: float = 0.0


func _ready() -> void:
	_len = end.length()
	_dir = end / maxf(_len, 1.0)
	_s = start_s
	var rope := Line2D.new()
	rope.points = PackedVector2Array([Vector2.ZERO, end])
	rope.width = 1.0
	rope.default_color = Color8(170, 160, 140)
	rope.z_index = -1
	add_child(rope)
	# prádlo – rovnomerne pozdĺž šnúry, mimo miesta, kde čaká kladka
	var tex: Texture2D = load(ART + "clothes.png")
	var r := RandomNumberGenerator.new()
	r.seed = cloth_seed
	for i in clothes:
		var t: float = (i + 1.0) / (clothes + 1.0)
		var s := Sprite2D.new()
		s.texture = tex
		s.region_enabled = true
		s.region_rect = Rect2(r.randi_range(0, 5) * 14, 0, 14, 18)
		s.centered = false
		s.offset = Vector2(-7, 0)
		s.position = end * t
		s.rotation = r.randf_range(-0.06, 0.06)
		s.z_index = -1
		add_child(s)
	pulley = TrolleyScript.new()
	pulley.z_index = 2
	add_child(pulley)
	var ps := Sprite2D.new()
	ps.texture = load(ART + "pulley.png")
	ps.centered = false
	ps.offset = Vector2(-6, -GRIP)
	pulley.add_child(ps)
	_place()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		return
	var hooked: Node2D = _player.get(&"_hook")
	if _riding:
		if hooked != pulley:      # pustil sa sám (skok, S, zásah, smrť)
			_stop_ride()
		else:
			_speed = minf(_speed + accel * delta, max_speed)
			_s += _speed * delta
			if _s >= _len - end_margin:
				_s = _len - end_margin
				_place()
				_player.release_hook(_dir * _speed * 0.8)
				_stop_ride()
				return
	elif _s > start_s:
		_return_t -= delta
		if _return_t <= 0.0:
			_s = maxf(start_s, _s - RETURN_SPEED * delta)
	_place()
	if not _riding and _player.has_method(&"can_grab_hook") and _player.can_grab_hook():
		var reach: float = _player.get(&"hook_reach") + REACH_BONUS
		if _player.hook_hand().distance_to(pulley.global_position) < reach:
			_riding = true
			_speed = 40.0
			_player.grab_hook(pulley)


func _stop_ride() -> void:
	_riding = false
	_speed = 0.0
	_return_t = 1.5


func _place() -> void:
	pulley.position = _dir * _s + Vector2(0, GRIP)
	pulley.velocity = _dir * _speed if _riding else Vector2.ZERO
