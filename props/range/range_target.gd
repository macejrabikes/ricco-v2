class_name RangeTarget
extends StaticBody2D
## Terč na strelnici (levels/range/shooting_range.gd):
##   PAPER – papierová postava gangstra s kruhmi, stojí, ide po koľajnici na vozíku (RAIL) alebo visí na štipke pod kladkou na drôte (SWING),
##   POPUP – okrúhly terč na pánte, vyskočí zo zeme (pop) a po zásahu alebo po čase sa sklopí.
## Body podľa toho, kam guľka trafila: stred 50, vnútorný kruh 25, inak 10. Diery od guliek ostanú na papieri.
## Pohyb rieši skript sám (pozícia tela sa mení každý snímok – lúče guliek ju hneď vidia).
## Godot docs: classes/class_staticbody2d, classes/class_tween

enum Kind { PAPER, POPUP }
enum Motion { STATIC, RAIL, SWING }

const ART := "res://levels/range/art/"
const HOLE := preload("res://levels/range/art/hole.png")
const MAX_HOLES := 14

@export var kind: Kind = Kind.PAPER
@export var motion: Motion = Motion.STATIC
@export var span: float = 200.0       ## RAIL: px doprava od začiatku a späť
@export var speed: float = 60.0       ## RAIL: px/s
@export var rope: float = 100.0       ## SWING: dĺžka lana od háku (px)
@export var swing_deg: float = 28.0   ## SWING: najväčší uhol
@export var swing_period: float = 3.0 ## SWING: s na jeden kmit tam a späť

var up: bool = true                   ## POPUP: je vyklopený (dá sa trafiť)
var _origin: Vector2
var _t: float = 0.0
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _holes: Node2D
var _rope_line: Line2D
var _hook: Sprite2D
var _cart: Sprite2D
var _down_timer: float = 0.0
var _tw: Tween


func _ready() -> void:
	collision_layer = 4    # guľky (Bullet.hit_mask) zasiahnu ako nepriateľa
	collision_mask = 0
	_origin = position
	_t = randf() * 10.0
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	_holes = Node2D.new()
	_sprite.add_child(_holes)
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	_shape.shape = r
	add_child(_shape)
	if kind == Kind.PAPER:
		_sprite.texture = load(ART + "paper_target.png")
		_sprite.position = Vector2(-12, -46)      # spodok postavy je v počiatku
		r.size = Vector2(18, 44)
		_shape.position = Vector2(0, -23)
	else:
		_sprite.texture = load(ART + "popup_target.png")
		_sprite.offset = Vector2(-10, -36)         # pánt (spodok paličky) je v počiatku – otáča sa okolo neho
		_sprite.centered = false
		_sprite.position = Vector2.ZERO
		r.size = Vector2(18, 18)
		_shape.position = Vector2(0, -26)
		var base := Sprite2D.new()
		base.texture = load(ART + "popup_base.png")
		base.position = Vector2(0, -3)
		base.z_index = 1
		add_child(base)
		_set_up(false, false)
	if motion == Motion.RAIL:
		_cart = Sprite2D.new()
		_cart.texture = load(ART + "cart.png")
		_cart.position = Vector2(0, 7 - 14)        # vozík pod postavou, kolesá na koľajnici
		_cart.z_index = 1
		add_child(_cart)
		_sprite.position.y -= 12
		_shape.position.y -= 12
	elif motion == Motion.SWING:
		_rope_line = Line2D.new()
		_rope_line.width = 1.0
		_rope_line.default_color = Color8(150, 140, 120)
		_rope_line.top_level = true                # šnúra sa kreslí od kladky (svetové súradnice)
		_rope_line.z_index = -1
		add_child(_rope_line)
		_hook = Sprite2D.new()
		_hook.texture = load(ART + "hook.png")
		_hook.position = Vector2(0, -46 - 8)
		add_child(_hook)


func _physics_process(delta: float) -> void:
	_t += delta
	match motion:
		Motion.RAIL:
			position.x = _origin.x + pingpong(_t * speed, span)
		Motion.SWING:
			var a: float = deg_to_rad(swing_deg) * sin(_t * TAU / swing_period)
			# _origin = kladka na drôte pod stropom; terč visí na šnúre pod ňou
			position = _origin + Vector2(sin(a), cos(a)) * rope + Vector2(0, 46 + 14)
			rotation = -a * 0.6
			_rope_line.points = PackedVector2Array([_origin, to_global(Vector2(0, -46 - 14))])
	if kind == Kind.POPUP and up and _down_timer > 0.0:
		_down_timer -= delta
		if _down_timer <= 0.0:
			_set_up(false)


## POPUP: vyklopí sa na dur sekúnd
func pop(dur: float) -> void:
	_down_timer = dur
	_set_up(true)


func _set_up(on: bool, animate: bool = true) -> void:
	up = on
	_shape.set_deferred(&"disabled", not on)
	if _tw:
		_tw.kill()
	var to: float = 0.0 if on else -PI / 2.0
	if not animate:
		_sprite.rotation = to
		return
	_tw = create_tween()
	_tw.tween_property(_sprite, "rotation", to, 0.12 if on else 0.18).set_trans(Tween.TRANS_BACK if on else Tween.TRANS_QUAD)
	if on:
		Sfx.play(&"knock_wood", global_position, -10.0, 0.15)


func take_hit_at(damage: float, dir: Vector2, pos: Vector2) -> void:
	if kind == Kind.POPUP and not up:
		return
	# stred kruhov v obrázku: papier (12, 26), okrúhly terč (10, 10)
	var center: Vector2 = Vector2(12, 26) if kind == Kind.PAPER else Vector2(10, 10)
	var local: Vector2 = _sprite.to_local(pos) - (_sprite.offset if kind == Kind.POPUP else Vector2.ZERO)
	var d: float = local.distance_to(center)
	var pts: int = 50 if d < 3.0 else (25 if d < 6.5 else 10)
	_add_hole(local + (_sprite.offset if kind == Kind.POPUP else Vector2.ZERO))
	get_tree().call_group(&"shooting_range", &"add_score", pts, global_position + Vector2(0, -60))
	Sfx.play(&"knock_wood", global_position, -4.0 if pts < 50 else 0.0, 0.1)
	_sprite.modulate = Color(1.8, 1.8, 1.8)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	Burst.spawn(get_tree().current_scene, pos, dir + Vector2(0, -0.4), Color(0.9, 0.86, 0.74), 4, 70.0, Vector2(0, 300), 0.3)
	if kind == Kind.POPUP:
		_set_up(false)
	else:
		# papier sa po zásahu zakýve
		var tw := create_tween()
		tw.tween_property(_sprite, "skew", 0.25 * signf(dir.x), 0.05)
		tw.tween_property(_sprite, "skew", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func take_hit(damage: float, dir: Vector2) -> void:   # klobúk a iné bez presného miesta
	take_hit_at(damage, dir, global_position + Vector2(0, -26))


func _add_hole(local: Vector2) -> void:
	var h := Sprite2D.new()
	h.texture = HOLE
	h.position = local.round()
	_holes.add_child(h)
	if _holes.get_child_count() > MAX_HOLES:
		_holes.get_child(0).queue_free()


## Strelnica pri zmene režimu zmaže diery
func clear_holes() -> void:
	for h in _holes.get_children():
		h.queue_free()
