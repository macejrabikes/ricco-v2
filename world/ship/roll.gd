extends Node2D
## Hojdanie lode na vlnách – posúva a mierne nakláňa vzdialené more (a mraky), takže sa zdá, že sa kolíše paluba.
## Fyzika paluby sa nemení (hrateľnosť ostane rovná), hojdá sa len pozadie.
## Godot docs: classes/class_node2d

@export var amplitude: float = 8.0     ## px hore-dole
@export var tilt_deg: float = 1.6      ## stupne náklonu
@export var period: float = 6.5        ## s na jedno zhupnutie
@export var phase: float = 0.0
@export var lean_deg: float = 0.0      ## trvalý náklon (potápajúca sa loď pri úteku – margaret.gd ho postupne zvyšuje)

var _base: Vector2
var _t: float = 0.0


func _ready() -> void:
	_base = position


func _process(delta: float) -> void:
	_t += delta
	var k: float = TAU * _t / period + phase
	position = _base + Vector2(0.0, amplitude * sin(k))
	rotation = deg_to_rad(lean_deg + tilt_deg * sin(k + 0.9))
