extends Node2D
## Stropná koľajnica s hákmi na mäso (mraziareň Fontana Shipping). Vozíky idú dookola stálou rýchlosťou:
## na niektorých visí mäso (kryt), iné sú voľné – Ricco sa ich vo vzduchu chytí a vezie sa ako lanovkou
## (characters/ricco/ricco.gd – grab_hook / _process_hook). Za koncom koľajnice vozík zmizne v stene
## a vráti sa na začiatok. Kúsok pred stenou koľajnica Ricca sama pustí.
## Uzol je na ľavom konci koľajnice, koľajnica vedie doprava (length). Smer jazdy = znamienko speed.
## Godot docs: classes/class_node2d, classes/class_line2d

@export var length: float = 640.0       ## px – viditeľná dĺžka koľajnice
@export var speed: float = 60.0         ## px/s – kladné = doprava
@export var spacing: float = 48.0       ## px medzi vozíkmi
@export var pattern: String = "CCHCH"   ## C = mäso, H = voľný hák, - = bez háku (opakuje sa)
@export var carcass_drop: float = 60.0  ## px – dĺžka reťaze od háku po vrch mäsa
@export var release_margin: float = 28.0   ## px pred stenou koľajnica Ricca pustí
@export var phase: float = 0.0          ## px – posun vozíkov na začiatku

const ART := "res://levels/level2/art/cold/"
const TrolleyScript := preload("res://world/coldstore/hook_trolley.gd")
const CarcassScript := preload("res://world/coldstore/carcass.gd")
const GRIP_Y := 18.0                    ## px pod koľajnicou je úchyt háku

var trolleys: Array[Node2D] = []
var _offset: float = 0.0
var _total: float = 0.0
var _player: Node2D


func _ready() -> void:
	_offset = phase
	var rail := Sprite2D.new()
	rail.texture = load(ART + "rail.png")
	rail.centered = false
	rail.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rail.region_enabled = true
	rail.region_rect = Rect2(0, 0, length, rail.texture.get_height())
	rail.position = Vector2(0, -3)
	rail.z_index = 2
	add_child(rail)
	var n: int = int(ceil(length / spacing)) + 2
	_total = n * spacing
	for i in n:
		var t: Node2D = TrolleyScript.new()
		t.z_index = 2
		add_child(t)
		var s := Sprite2D.new()
		s.texture = load(ART + "hook_trolley.png")
		s.centered = false
		s.offset = Vector2(-6, -GRIP_Y - 4)
		t.add_child(s)
		var kind: String = pattern[i % pattern.length()] if pattern != "" else "H"
		if kind == "-":
			s.visible = false
			t.set_meta(&"empty", true)
		elif kind == "C":
			var swing := Node2D.new()
			swing.z_index = 1
			t.add_child(swing)
			var chain := Line2D.new()
			chain.points = PackedVector2Array([Vector2(0, 2), Vector2(0, carcass_drop + 2)])
			chain.width = 1.0
			chain.default_color = Color8(96, 104, 110)
			swing.add_child(chain)
			var body := StaticBody2D.new()
			body.set_script(CarcassScript)
			body.position = Vector2(0, carcass_drop)
			swing.add_child(body)
			var spr := Sprite2D.new()
			spr.texture = load(ART + "carcass.png")
			spr.centered = false
			spr.offset = Vector2(-12, 0)
			body.add_child(spr)
			var cs := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(16, spr.texture.get_height() - 6)
			cs.shape = r
			cs.position = Vector2(0, spr.texture.get_height() / 2.0)
			body.add_child(cs)
			t.carcass = body
		trolleys.append(t)
	if speed != 0.0:
		Sfx.loop(&"rail_clank", self, Vector2(length / 2.0, 0), -14.0, &"SFX")
	_place(0.0)


func _physics_process(delta: float) -> void:
	_offset += speed * delta
	_place(delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		return
	var hooked: Node2D = _player.get(&"_hook")
	for t in trolleys:
		if hooked == t and not _riding_ok(t.position.x):
			_player.release_hook(Vector2(speed, 0.0))   # koniec koľajnice – pustí sa skôr, než vozík zmizne v stene
	if _player.has_method(&"can_grab_hook") and _player.can_grab_hook():
		var hand: Vector2 = _player.hook_hand()
		var reach: float = _player.get(&"hook_reach")
		for t in trolleys:
			if t.carcass or t.has_meta(&"empty") or not t.shown or not _riding_ok(t.position.x):
				continue
			if hand.distance_to(t.global_position) < reach:
				_player.grab_hook(t)
				break


func _riding_ok(x: float) -> bool:
	return x > release_margin and x < length - release_margin


func _place(_delta: float) -> void:
	var v := Vector2(speed, 0.0)
	for i in trolleys.size():
		var t: Node2D = trolleys[i]
		var x: float = fposmod(_offset + i * spacing, _total) - spacing
		t.position = Vector2(x, GRIP_Y)
		t.velocity = v
		var inside: bool = x >= -6.0 and x <= length + 6.0
		if inside != t.shown:
			t.shown = inside
			t.visible = inside
			if t.carcass:
				(t.carcass as CollisionObject2D).collision_layer = 32 if inside else 0
