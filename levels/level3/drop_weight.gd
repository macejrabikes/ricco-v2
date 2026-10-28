extends StaticBody2D
## Závažie na lane / reťazi (kapitola III – klub The Blue Canary): luster nad stolom mafiánov v sále, vrecia s pieskom
## v zákulisí. Riccova guľka alebo klobúk do lana / reťaze ho uvoľní: spadne a kto stojí pod ním, toho zloží (mafián),
## Ricca zraní. Hosť pod ním by tiež padol – duch to Riccovi nedaruje (Guest.take_hit).
## Poloha uzla = úchyt pod stropom. Deti: Rope (Line2D od úchytu dolu), Weight (Node2D – obrázok „Sprite“, pri lustri
## aj Glow a Light = LightZone), Shape (CollisionShape2D cez lano aj závažie – sem trafí guľka).
## Po dopade luster zhasne a rozbije sa (broken_texture), vrece ostane ležať ako kryt (cover_size).
## Vrstva 4 ako nepriatelia: zasiahne ho Riccova guľka aj klobúk, mafiánske guľky nie.
## Godot docs: classes/class_staticbody2d, classes/class_line2d

signal dropped
signal landed(kills: int)

@export var floor_y: float = 0.0              ## globálne y podlahy, kam dopadne (spodok závažia)
@export var weight_h: float = 22.0            ## px – výška závažia (od úchytu lana po spodok)
@export var kill_half: float = 20.0           ## px – koho zloží (vodorovne od stredu)
@export var player_damage: int = 2
@export var heavy: bool = false               ## luster: rinčanie skla a kovu, počuť ho do ďaleka
@export var noise_radius: float = 260.0
@export var cover_size: Vector2 = Vector2.ZERO   ## po dopade kryt (vrstva 6) – 0 = žiadny
@export var broken_texture: Texture2D         ## obrázok po dopade (Weight/Sprite)

const GRAVITY := 900.0
const COVER_LAYER := 32

var _falling: bool = false
var _done: bool = false
var _vy: float = 0.0
var _weight: Node2D
var _rope: Line2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	_weight = get_node_or_null(^"Weight") as Node2D
	_rope = get_node_or_null(^"Rope") as Line2D


func take_hit(_damage: float, _dir: Vector2) -> void:
	drop()


func hat_hit(_damage: int, _dir: Vector2) -> void:
	drop()


func drop() -> void:
	if _falling or _done or _weight == null:
		return
	_falling = true
	(get_node(^"Shape") as CollisionShape2D).set_deferred(&"disabled", true)
	Sfx.play(&"chain_rattle" if heavy else &"punch_swing", global_position + Vector2(0, 20), -2.0)
	if _rope:   # lano sa pretrhne – hore ostane kúsok
		_rope.points = PackedVector2Array([Vector2.ZERO, Vector2(0, 6)])
	dropped.emit()


func _physics_process(delta: float) -> void:
	if not _falling:
		return
	_vy += GRAVITY * delta
	_weight.position.y += _vy * delta
	if _weight.global_position.y + weight_h >= floor_y:
		_weight.global_position.y = floor_y - weight_h
		_land()


func _land() -> void:
	_falling = false
	_done = true
	var x: float = _weight.global_position.x
	var tree := get_tree()
	var scene := tree.current_scene
	var kills: int = 0
	for g in tree.get_nodes_in_group(&"enemies"):
		var e := g as Gangster
		if e == null or e.state == Gangster.State.DEAD:
			continue
		var dx: float = e.global_position.x - x
		if absf(dx) < kill_half and absf(e.global_position.y - floor_y) < 30.0:
			e.take_hit(99.0, Vector2(1.0 if dx >= 0.0 else -1.0, 0.4))
			kills += 1
	for g in tree.get_nodes_in_group(&"guests"):
		var n := g as Guest
		if n and not n.dead and absf(n.global_position.x - x) < kill_half and absf(n.global_position.y - floor_y) < 30.0:
			n.take_hit(1.0, Vector2(signf(n.global_position.x - x) + 0.01, 0.4))
	var p := tree.get_first_node_in_group(&"player") as Node2D
	if p and int(p.get(&"state")) != 3 and absf(p.global_position.x - x) < kill_half + 6.0 and absf(p.global_position.y - floor_y) < 30.0:
		p.call(&"take_damage", player_damage, Vector2(x, floor_y - 20.0))
	if p and p.global_position.distance_to(_weight.global_position) < 260.0:
		p.set(&"shake_timer", 0.2 if heavy else 0.1)
	var at := Vector2(x, floor_y - 4.0)
	if heavy:
		Sfx.play(&"metal_crash", at, 2.0, 0.05)
		Sfx.play(&"glass_break", at, 0.0, 0.1)
		Burst.spawn(scene, at, Vector2.UP, Color(0.85, 0.95, 1.0), 18, 140.0, Vector2(0, 500), 0.7)
	else:
		Sfx.play(&"body_thud", at, -2.0, 0.1)
	Burst.spawn(scene, at, Vector2.UP, Color(0.7, 0.66, 0.6, 0.6), 10, 60.0, Vector2(0, 60), 0.5)
	Gangster.noise(at, noise_radius)
	var spr := _weight.get_node_or_null(^"Sprite") as Sprite2D
	if spr and broken_texture:
		spr.texture = broken_texture
	var glow := _weight.get_node_or_null(^"Glow") as CanvasItem
	if glow:
		glow.visible = false
	var light := _weight.get_node_or_null(^"Light") as LightZone
	if light:
		light.switch_off()
	if cover_size != Vector2.ZERO:
		var b := StaticBody2D.new()
		b.collision_layer = COVER_LAYER
		b.collision_mask = 0
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = cover_size
		cs.shape = r
		b.add_child(cs)
		add_child(b)
		b.global_position = Vector2(x, floor_y - cover_size.y / 2.0)
	landed.emit(kills)
