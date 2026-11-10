class_name Guest
extends Sprite2D
## Hosť na oslave v pizzerii (nie mafián). Pohráva sa s pohárom / je / tancuje (snímky vedľa seba v obrázku).
## Keď uvidí Ricca na svetle, zľakne sa („!“ nad hlavou) a privolá mafiánov (Gangster.alarm) – Ricco sa musí držať v tme.
## Riccova guľka ho môže trafiť (telo na vrstve 7 = INNOCENT_LAYER, Riccove guľky ju majú v hit_mask): padne, ostatní
## zvreskú a duch Dona Ricca zvozí (Level2.bark). Mafiánske guľky hosťami preletia.
## flee = true (smútiaci na cintoríne): keď sa v okolí strieľa (Guest.panic – volá ho Riccov aj mafiánsky výstrel),
## s „!“ zvreskne a uteká preč od streľby, kým nezmizne z obrazovky.

@export var loop: bool = false           ## true = snímky stále dookola (tanec, harmonika); false = občas sa napije
@export var fps: float = 5.0
@export var witness: bool = true         ## zbadá Ricca a spustí poplach
@export var see_range: float = 150.0     ## px vodorovne
@export var alarm_range: float = 520.0   ## px – ktorí mafiáni počujú krik
@export var flee: bool = false           ## pri streľbe v okolí uteká preč (inak len zvreskne)
@export var flee_speed: float = 96.0     ## px/s

static var _last_alert_ms: int = -100000   ## zvuk „!“ naraz len raz
static var _scold_n: int = 0               ## koľkokrát už duch Ricca zvozil (hlášky sa striedajú)
static var _last_scold_ms: int = -100000

const INNOCENT_LAYER := 64   ## vrstva 7: nevinní (hostia, smútiaci) – zasiahne ich len Riccova guľka
const BLOOD := preload("res://characters/don/blood_pool.png")
const GUEST_BODY := preload("res://world/npc/guest_body.gd")
const SCOLDS := [
	"OI! WE DON'T DO THAT\nTO INNOCENT PEOPLE, KID!",
	"RICCO! THEY'RE CIVILIANS!\nI RAISED YA BETTER THAN THAT.",
	"WHAT'S WRONG WITH YOU?!\nWE GOT RULES IN THIS FAMILY.",
]

var _t: float = 0.0
var _seq: Array = []      ## [snímka, trvanie]
var _i: int = 0
var _cool: float = 0.0
var _check: float = 0.0
var player: Node2D
var _mark: Label
var dead: bool = false
var _body: StaticBody2D
var fleeing: bool = false
var _flee_dir: float = 1.0
var _run_t: float = 0.0
var _base_offset: Vector2


func _ready() -> void:
	add_to_group(&"guests")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_t = randf_range(0.0, 3.0)
	_make_body.call_deferred()


## Telo pre guľky: obdĺžnik na mieste postavy (užší ako obrázok – stoličky, harmonika okolo nie)
func _make_body() -> void:
	var r: Rect2 = get_rect()
	_body = GUEST_BODY.new()
	_body.collision_layer = INNOCENT_LAYER
	_body.collision_mask = 0
	add_child(_body)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(8.0, r.size.x * 0.45), r.size.y * 0.9)
	cs.shape = shape
	cs.position = Vector2(r.get_center().x, r.end.y - shape.size.y / 2.0)
	_body.add_child(cs)
	_body.set_meta(&"guest", self)


func _process(delta: float) -> void:
	if dead:
		return
	if fleeing:
		_run(delta)
		return
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
	var now := Time.get_ticks_msec()
	if now - _last_alert_ms > 600:
		_last_alert_ms = now
		Sfx.play(&"alert", global_position + Vector2(0, -40), -4.0, 0.02)
	_show_mark()
	for g in get_tree().get_nodes_in_group(&"enemies"):
		if g.has_method(&"alarm") and (g as Node2D).global_position.distance_to(global_position) < alarm_range:
			g.alarm()
	# leknutie – poskočí
	var tw := create_tween()
	tw.tween_property(self, "offset:y", offset.y - 4.0, 0.08)
	tw.tween_property(self, "offset:y", offset.y, 0.12)


## „!“ nad hlavou (ako u mafiánov)
func _show_mark() -> void:
	if _mark == null:
		_mark = Label.new()
		_mark.text = "!"
		_mark.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
		_mark.add_theme_font_size_override(&"font_size", 16)
		_mark.add_theme_color_override(&"font_color", Color8(255, 214, 90))
		_mark.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
		_mark.add_theme_constant_override(&"outline_size", 4)
		_mark.z_index = 30
		add_child(_mark)
	var top: float = get_rect().position.y
	_mark.visible = true
	_mark.modulate.a = 1.0
	_mark.position = Vector2(-3, top - 12.0)
	var tw := create_tween()
	tw.tween_property(_mark, "position:y", top - 18.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(_mark, "modulate:a", 0.0, 0.25)


# ---------------------------------------------------------------- útek pred streľbou

## Streľba na pos: smútiaci (flee) v okruhu radius utečú preč. Volá Gangster.gunshot (Ricco) a Gangster._fire.
static func panic(pos: Vector2, radius: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group(&"guests"):
		var g := n as Guest
		if g and g.flee and not g.dead and not g.fleeing and g.global_position.distance_to(pos) < radius:
			g._start_flee(pos)


## Každý zareaguje inak rýchlo (nie všetci naraz), zvreskne, poskočí a uteká opačne od streľby
func _start_flee(from: Vector2) -> void:
	fleeing = true
	_base_offset = offset
	var dx: float = global_position.x - from.x
	_flee_dir = signf(dx) if absf(dx) > 6.0 else (-1.0 if randf() < 0.5 else 1.0)
	set_process(false)
	await get_tree().create_timer(randf_range(0.05, 0.45), false).timeout
	if dead or not is_inside_tree():
		return
	_show_mark()
	var now := Time.get_ticks_msec()
	if now - _last_alert_ms > 250:
		_last_alert_ms = now
		Sfx.play(&"alert", global_position + Vector2(0, -40), -5.0, 0.15)
	frame = 0
	flip_h = _flee_dir < 0.0
	_run_t = randf() * TAU
	set_process(true)


## Beh: poskakovanie a predklon (sprite nemá snímky behu), mimo obrazovky zmizne
func _run(delta: float) -> void:
	_run_t += delta * 15.0
	global_position.x += _flee_dir * flee_speed * delta
	offset = _base_offset + Vector2(0, -absf(sin(_run_t)) * 2.0)
	scale = Vector2(1.04, 0.86)          # zohnutý – hlava dole pred guľkami
	rotation = _flee_dir * 0.16
	if player and is_instance_valid(player) and absf(global_position.x - player.global_position.x) > 420.0:
		queue_free()


# ---------------------------------------------------------------- zásah (omylom)

## Riccova guľka: padne naznak v smere strely, krv, ostatní zvreskú (privolajú mafiánov), duch Ricca zvozí
func take_hit(_damage: float, dir: Vector2) -> void:
	if dead:
		return
	dead = true
	fleeing = false
	offset = _base_offset if _base_offset != Vector2.ZERO else offset
	scale = Vector2.ONE   # z behu zohnutý – padá v normálnej veľkosti
	witness = false
	if _body:
		_body.queue_free()
		_body = null
	if _mark:
		_mark.visible = false
	var fall: float = signf(dir.x) if dir.x != 0.0 else 1.0
	var scene := get_tree().current_scene
	var chest: Vector2 = global_position + Vector2(0, get_rect().position.y * 0.6)
	Burst.spawn(scene, chest, (dir + Vector2(0, -0.4)).normalized(), Color(0.55, 0.05, 0.06), 12, 110.0, Vector2(0, 420), 0.5)
	Sfx.play(&"impact_body", chest, -2.0, 0.1)
	Sfx.play(&"alert", chest, -6.0, 0.02)
	# pád naznak okolo nôh
	var tw := create_tween()
	tw.tween_property(self, "rotation", fall * PI / 2.0 * 0.96, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", fall * PI / 2.0 * 0.9, 0.08)
	tw.tween_property(self, "rotation", fall * PI / 2.0 * 0.94, 0.08)
	tw.tween_callback(func():
		Sfx.play(&"land", global_position, -6.0, 0.1)
		var pool := Sprite2D.new()
		pool.texture = BLOOD
		pool.z_index = z_index - 1
		pool.scale = Vector2(0.2, 0.2)
		scene.add_child(pool)
		pool.global_position = global_position + Vector2(fall * get_rect().size.y * 0.5, -1)
		pool.create_tween().tween_property(pool, "scale", Vector2(0.8, 0.8), 2.5).set_ease(Tween.EASE_OUT))
	tw.parallel().tween_property(self, "modulate", Color(0.8, 0.78, 0.8), 0.6)
	# ostatní hostia v okolí to videli – krik a poplach
	for g in get_tree().get_nodes_in_group(&"guests"):
		if g != self and not g.dead and (g as Node2D).global_position.distance_to(global_position) < alarm_range:
			g._scream()
	Gangster.noise(global_position, alarm_range)
	Guest.panic(global_position, alarm_range)
	_scold()


## Duch Dona sa ozve (len ak level má hlášky ducha – Level2.bark; naraz najviac raz za 6 s)
func _scold() -> void:
	var scene := get_tree().current_scene
	var now := Time.get_ticks_msec()
	if not scene.has_method(&"bark") or now - _last_scold_ms < 6000:
		return
	_last_scold_ms = now
	scene.bark(SCOLDS[_scold_n % SCOLDS.size()])
	_scold_n += 1
