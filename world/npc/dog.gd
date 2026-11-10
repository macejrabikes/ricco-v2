class_name Dog
extends CharacterBody2D
## Strážny pes na reťazi (prístav, kapitola II). Na svetlo nedbá – Ricca zacíti nosom aj v tme,
## len keď je pod hladinou (submerged), necíti ho. Prikrčeného (plíženie) zacíti až bližšie.
## Keď ho zacíti: „!“, šteká a privolá mafiánov v okolí (Gangster.alarm), kým je Ricco blízko.
## Klobúk ho omráči (chvíľu leží), výstrel ho len vyľaká – zakňučí a na chvíľu sa schová (psa nezabíjame).
## Reťaz vedie od kolíka (spawn) – pes chodí len v jej dosahu.
## Godot docs: classes/class_characterbody2d, classes/class_line2d

enum State { IDLE, WALK, BARK, STUN, SCARED }

@export var chain_length: float = 40.0     ## px – ako ďaleko od kolíka dočiahne
@export var smell_range: float = 96.0      ## px vodorovne
@export var smell_height: float = 60.0     ## px zvisle (cíti aj Ricca na hladine pod mólom)
@export var alarm_range: float = 460.0     ## px – ktorí mafiáni počujú štekot
@export var start_facing: float = 1.0

const TEX := preload("res://levels/level2/art/docks/dog.png")
const FONT := preload("res://ui/fonts/tiny5.ttf")

static var _last_alert_ms: int = -100000

var state: State = State.IDLE
var facing: float = 1.0
var post: Vector2
var player: Node2D
var _t: float = 0.0
var _anim_t: float = 0.0
var _bark_t: float = 0.0
var _check: float = 0.0
var _walk_dir: float = 1.0
var _mark: Label
var sprite: Sprite2D
var chain: Line2D


func _ready() -> void:
	collision_layer = 4    # ako nepriatelia – zasiahne ho klobúk aj guľka
	collision_mask = 1
	floor_snap_length = 8.0
	add_to_group(&"dogs")
	post = global_position
	facing = start_facing
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(22, 14)
	shape.shape = r
	shape.position = Vector2(0, -7)
	add_child(shape)
	chain = Line2D.new()
	chain.width = 1.0
	chain.default_color = Color8(70, 74, 78)
	chain.top_level = true
	chain.z_index = -1
	add_child(chain)
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.hframes = 5
	sprite.offset = Vector2(0, -12)
	add_child(sprite)
	_t = randf_range(1.0, 3.0)
	_face(facing)


func _face(f: float) -> void:
	facing = f
	sprite.flip_h = f < 0.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	_t -= delta
	_bark_t -= delta
	_anim_t += delta
	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			sprite.frame = 1 if fmod(_anim_t, 1.2) > 0.6 else 0
			if _t <= 0.0:
				state = State.WALK
				_t = randf_range(0.8, 1.8)
				_walk_dir = -1.0 if global_position.x > post.x + 8.0 else (1.0 if global_position.x < post.x - 8.0 else (1.0 if randf() < 0.5 else -1.0))
		State.WALK:
			_face(_walk_dir)
			velocity.x = _walk_dir * 22.0
			sprite.frame = int(_anim_t * 6.0) % 2
			if absf(global_position.x + _walk_dir * 4.0 - post.x) > chain_length or _t <= 0.0:
				state = State.IDLE
				_t = randf_range(1.5, 3.5)
		State.BARK:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if player:
				_face(signf(player.global_position.x - global_position.x) if absf(player.global_position.x - global_position.x) > 2.0 else facing)
			sprite.frame = 3 if fmod(_anim_t, 0.5) < 0.18 else 2
			if _bark_t <= 0.0:
				_bark()
			if _t <= 0.0 and not _smells():
				state = State.IDLE
				_t = randf_range(1.0, 2.0)
		State.STUN:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			sprite.frame = 4
			if _t <= 0.0:
				state = State.IDLE
				_t = 1.0
		State.SCARED:
			# odbehne ku kolíku a krčí sa
			var dx: float = post.x - global_position.x
			velocity.x = signf(dx) * 60.0 if absf(dx) > 4.0 else 0.0
			sprite.frame = 4
			if _t <= 0.0:
				state = State.IDLE
				_t = 1.0
	move_and_slide()
	# reťaz nedovolí odísť ďalej od kolíka (aj keď ho niečo odhodí)
	global_position.x = clampf(global_position.x, post.x - chain_length, post.x + chain_length)
	chain.points = PackedVector2Array([post + Vector2(0, -3), global_position + Vector2(facing * 9.0, -10.0)])
	# nos: kontrola každých 0,15 s
	_check -= delta
	if _check <= 0.0 and state in [State.IDLE, State.WALK]:
		_check = 0.15
		if _smells():
			_alert()


## Cíti Ricca? Svetlo nehrá rolu, voda áno (pod hladinou necíti nič).
func _smells() -> bool:
	if player == null or player.get(&"state") == 3 or player.get(&"in_cutscene"):
		return false
	if player.get(&"submerged"):
		return false
	var d: Vector2 = player.global_position - global_position
	var r: float = smell_range * (0.55 if player.get(&"sneaking") else 1.0)
	return absf(d.x) < r and absf(d.y) < smell_height


func _alert() -> void:
	state = State.BARK
	_t = 1.2
	_bark_t = 0.0
	_show_mark()


## Šteká: zvuk + mafiáni v okolí vedia, kde Ricco je (ako pri krikoch hostí)
func _bark() -> void:
	_bark_t = randf_range(0.45, 0.7)
	_t = maxf(_t, 0.8)
	Sfx.play(&"dog_bark", global_position + Vector2(0, -12), -2.0, 0.08)
	for g in get_tree().get_nodes_in_group(&"enemies"):
		if g.has_method(&"alarm") and (g as Node2D).global_position.distance_to(global_position) < alarm_range:
			g.alarm()


func _show_mark() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_alert_ms > 600:
		_last_alert_ms = now
		Sfx.play(&"alert", global_position + Vector2(0, -30), -4.0, 0.02)
	if _mark == null:
		_mark = Label.new()
		_mark.text = "!"
		_mark.add_theme_font_override(&"font", FONT)
		_mark.add_theme_font_size_override(&"font_size", 16)
		_mark.add_theme_color_override(&"font_color", Color8(255, 214, 90))
		_mark.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
		_mark.add_theme_constant_override(&"outline_size", 4)
		_mark.z_index = 30
		add_child(_mark)
	_mark.visible = true
	_mark.modulate.a = 1.0
	_mark.position = Vector2(-3, -40)
	var tw := create_tween()
	tw.tween_property(_mark, "position:y", -46.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(_mark, "modulate:a", 0.0, 0.25)


## Klobúk (weapons/hat/hat_projectile.gd): omráči ho – chvíľu leží a nič necíti
func hat_hit(_damage: float, _dir: Vector2) -> void:
	Sfx.play(&"hat_bonk", global_position + Vector2(0, -12))
	Sfx.play(&"dog_yelp", global_position + Vector2(0, -12), -4.0)
	state = State.STUN
	_t = 7.0
	if _mark:
		_mark.visible = false


## Guľka (weapons/pistol/bullet.gd): psa nezraní – zakňučí a krčí sa pri kolíku
func take_hit(_damage: float, _dir: Vector2) -> void:
	if state == State.STUN:
		return
	Sfx.play(&"dog_yelp", global_position + Vector2(0, -12), -2.0)
	state = State.SCARED
	_t = 4.0
