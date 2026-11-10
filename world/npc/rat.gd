extends Sprite2D
## Potkan v tuneloch – pobehuje sem a tam, občas zastane.
## Dá sa zabiť: skokom na neho (Ricco sa od neho odrazí) alebo guľkou / hodeným klobúkom.
## Telo pre guľky (StaticBody2D na vrstve 3 „enemies“ ako pes – world/npc/dog.gd) si vyrobí sám;
## hráč s ním nekoliduje (Ricco má collision_mask = 1), takže cez potkana sa dá prejsť ako doteraz.

@export var span: float = 28.0
@export var speed: float = 34.0

const STOMP_BOUNCE := -230.0   ## px/s – odraz Ricca po skoku na potkana
const BLOOD := Color(0.55, 0.05, 0.06)

var _home: Vector2
var _dir: float = 1.0
var _t: float = 0.0
var _pause: float = 0.0
var _dead: bool = false
var _body: RatBody
var _player: CharacterBody2D


## Telo, ktoré trafí guľka/klobúk (hľadajú take_hit na kolízii) – zásah pošle potkanovi
class RatBody extends StaticBody2D:
	var rat: Node

	func take_hit(_damage: float, dir: Vector2) -> void:
		if rat and is_instance_valid(rat):
			rat.die(dir)


func _ready() -> void:
	_home = position
	_dir = 1.0 if randf() < 0.5 else -1.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_make_body.call_deferred()


func _make_body() -> void:
	_body = RatBody.new()
	_body.rat = self
	_body.collision_layer = 4
	_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 10)
	cs.shape = shape
	cs.position = offset   # obrázok je vycentrovaný, offset (0, −4) → telo stojí na podlahe
	_body.add_child(cs)
	add_child(_body)


func _process(delta: float) -> void:
	if _dead:
		return
	_check_stomp()
	if _dead or _pause > 0.0:
		_pause -= delta
		return
	position.x += _dir * speed * delta
	flip_h = _dir < 0.0
	_t += delta
	frame = int(_t * 10.0) % 2
	if absf(position.x - _home.x) > span:
		_dir = -_dir
		position.x = _home.x + signf(position.x - _home.x) * span
	if randf() < delta * 0.6:
		_pause = randf_range(0.4, 1.5)
		if randf() < 0.35:
			Sfx.play(&"rat_squeak", global_position, -10.0, 0.15)


## Ricco padá zhora a chodidlami trafí potkana → rozpučí ho a odrazí sa
func _check_stomp() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
		return
	if _player.velocity.y <= 0.0 or _player.is_on_floor():
		return
	var feet: Vector2 = _player.global_position - global_position   # pôvod Ricca = chodidlá
	if absf(feet.x) > 17.0 or feet.y < -16.0 or feet.y > 4.0:   # 7 px polovica potkana + 10 px Riccova kapsula
		return
	die(Vector2(0, 1))
	if _player.has_method("bounce"):
		_player.bounce(STOMP_BOUNCE)


## Smrť: krv, piskot, ostane ležať a po chvíli zmizne
func die(dir: Vector2) -> void:
	if _dead:
		return
	_dead = true
	if _body:
		_body.queue_free()
		_body = null
	var scene := get_tree().current_scene
	Burst.spawn(scene, global_position + Vector2(0, -4), (dir + Vector2(0, -0.6)).normalized(), BLOOD, 8, 90.0, Vector2(0, 420), 0.4)
	Sfx.play(&"rat_squeak", global_position, -2.0, 0.25)
	Sfx.play(&"impact_body", global_position, -8.0, 0.1)
	frame = 0
	if dir.y > 0.5:   # rozpučený zhora – splošti sa (spodok ostane na podlahe)
		scale = Vector2(1.3, 0.35)
	else:             # guľka – prevráti sa na chrbát (scale.y = −1 otočí aj offset, preto +4)
		scale = Vector2(1.0, -1.0)
		offset = Vector2(0, 4)
	modulate = Color(0.75, 0.6, 0.6)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
