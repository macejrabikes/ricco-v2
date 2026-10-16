class_name Guest
extends Sprite2D
## Hosť na oslave v pizzerii (nie mafián). Pohráva sa s pohárom / je / tancuje (snímky vedľa seba v obrázku).
## Keď uvidí Ricca na svetle, zvrieskne a privolá mafiánov (Gangster.alarm) – Ricco sa musí držať v tme.

@export var loop: bool = false           ## true = snímky stále dookola (tanec, harmonika); false = občas sa napije
@export var fps: float = 5.0
@export var witness: bool = true         ## zbadá Ricca a spustí poplach
@export var see_range: float = 150.0     ## px vodorovne
@export var alarm_range: float = 520.0   ## px – ktorí mafiáni počujú krik

const SCREAMS: Array[String] = ["AIUTO!! A PENGUIN!", "MAMMA MIA! A BIRD!", "HEY! WHO LET THAT IN?!", "EEEEK!!", "SECURITY! A PENGUIN!"]

static var _last_scream_ms: int = -100000   ## krik naraz len jeden (ostatní sa len zľaknú)

var _t: float = 0.0
var _seq: Array = []      ## [snímka, trvanie]
var _i: int = 0
var _cool: float = 0.0
var _check: float = 0.0
var player: Node2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_t = randf_range(0.0, 3.0)


func _process(delta: float) -> void:
	_animate(delta)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D   # Ricco môže byť v strome až po hosťoch
	if not witness or player == null:
		return
	_cool -= delta
	_check -= delta
	if _cool > 0.0 or _check > 0.0:
		return
	_check = 0.15
	if player.get(&"in_cutscene") or player.get(&"state") == 3:
		return
	var d: Vector2 = player.global_position - global_position
	if absf(d.x) < see_range and absf(d.y) < 70.0 and player.has_method(&"is_lit") and player.is_lit():
		_scream()


func _animate(delta: float) -> void:
	if hframes <= 1:
		return
	_t -= delta
	if _t > 0.0:
		return
	if loop:
		frame = (frame + 1) % hframes
		_t = 1.0 / fps
		return
	# pohár ku ústam: 0 (dlho) → 1 → 2 (chvíľu) → 3 → 0
	frame = (frame + 1) % hframes
	match frame:
		0: _t = randf_range(1.5, 4.5)
		2: _t = randf_range(0.6, 1.2)
		_: _t = 0.14


func _scream() -> void:
	_cool = 8.0
	var lvl := get_tree().current_scene
	var now := Time.get_ticks_msec()
	if lvl.has_method(&"speech") and now - _last_scream_ms > 2500:
		_last_scream_ms = now
		lvl.speech(self, SCREAMS[randi() % SCREAMS.size()], Color8(255, 220, 200), 2.4, offset.y - 4.0)
	for g in get_tree().get_nodes_in_group(&"enemies"):
		if g.has_method(&"alarm") and (g as Node2D).global_position.distance_to(global_position) < alarm_range:
			g.alarm()
	# leknutie – poskočí
	var tw := create_tween()
	tw.tween_property(self, "offset:y", offset.y - 4.0, 0.08)
	tw.tween_property(self, "offset:y", offset.y, 0.12)
