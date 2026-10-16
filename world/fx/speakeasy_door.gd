extends StaticBody2D
## Oceľové dvere do zadnej herne (K2). Otvoria sa len na správne zaklopanie: KLOP KLOP … KLOP KLOP KLOP.
## Keď Ricco príde do zadnej časti skladu, z kuchyne príde mafián, zaklope a vojde – tak sa Ricco rytmus naučí.
## Ricco potom pri dverách klope sám (F). Zle = „BEAT IT!“, trikrát zle = vyhadzovač vyjde von.
## Deti: Sprite (3 snímky: zatvorené / okienko / otvorené), Shape. Vyhadzovač vnútri: uzol doorman_path.
## Godot docs: classes/class_staticbody2d, class_tween, class_input (is_action_just_pressed).

signal opened

## Rytmus: krátka (< LONG s) a dlhá medzera medzi klopnutiami
const PATTERN: Array[bool] = [false, true, false, false]   ## false = krátka, true = dlhá medzera
const KNOCK_TIMES: Array[float] = [0.0, 0.28, 1.0, 1.28, 1.56]
const LONG: float = 0.55
const FONT := preload("res://ui/fonts/tiny5.ttf")

@export var doorman_path: NodePath
@export var messenger_scene: PackedScene
@export var messenger_from: Vector2
@export var hint_path: NodePath

var player: Node2D
var doorman: Node2D
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _hint: Label
var _busy: bool = false
var _open: bool = false
var _knocks: Array[float] = []
var _wrong: int = 0
var _demo_done: bool = false
var _demo_started: bool = false


func _ready() -> void:
	_sprite = $Sprite
	_shape = $Shape
	doorman = get_node_or_null(doorman_path) as Node2D
	_hint = Label.new()
	_hint.text = "F  -  KNOCK"
	_hint.add_theme_font_override(&"font", FONT)
	_hint.add_theme_font_size_override(&"font_size", 8)
	_hint.add_theme_color_override(&"font_color", Color8(245, 235, 209))
	_hint.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	_hint.add_theme_constant_override(&"outline_size", 4)
	_hint.position = Vector2(-22, -80)
	_hint.visible = false
	add_child(_hint)
	if Level1.checkpoint >= 2:   # už bol vnútri – scénka sa neopakuje, vyhadzovač pozerá do herne
		_demo_done = true
		_demo_started = true
		_reveal_hint()
		if doorman:
			doorman.set(&"home_facing", 1.0)
			doorman.call(&"_set_facing", 1.0)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
		return
	var near: bool = not _open and absf(player.global_position.x - (global_position.x - 20.0)) < 22.0 and absf(player.global_position.y - global_position.y) < 20.0
	_hint.visible = near and not _busy and _demo_started
	if not near or _busy or _open or not _demo_started:
		return
	if Input.is_action_just_pressed(&"takedown"):
		_knock_fx()
		_knocks.append(Time.get_ticks_msec() / 1000.0)
		_check_later.call_deferred(_knocks.size())


## Pol sekundy po poslednom klopnutí sa vyhodnotí celý rytmus
func _check_later(count: int) -> void:
	await get_tree().create_timer(1.1).timeout
	if _knocks.size() != count or _busy or _open:
		return   # medzitým klopal ďalej
	var ok: bool = _knocks.size() == KNOCK_TIMES.size()
	if ok:
		for i in PATTERN.size():
			var gap: float = _knocks[i + 1] - _knocks[i]
			if (gap >= LONG) != PATTERN[i] or gap > 2.0:
				ok = false
	_knocks.clear()
	_answer(ok)


func _answer(ok: bool) -> void:
	_busy = true
	_sprite.frame = 1
	await get_tree().create_timer(0.6).timeout
	if ok:
		_say("...GET IN. QUICK.", 1.6)
		await get_tree().create_timer(0.9).timeout
		_set_open(true)
		if doorman:
			_doorman_gag()
	else:
		_wrong += 1
		if _wrong >= 3:
			_say("THAT'S IT, WISE GUY!", 1.8)
			await get_tree().create_timer(0.8).timeout
			_set_open(true)
			if doorman:
				doorman.set(&"passive", false)
				doorman.set(&"goto_x", global_position.x - 40.0)   # vyjde von za Riccom
				doorman.call(&"alarm")
		else:
			_say(["WRONG KNOCK. BEAT IT!", "WHO'S THERE?! SCRAM!"][_wrong - 1], 1.8)
			await get_tree().create_timer(1.2).timeout
			_sprite.frame = 0
	_busy = false


## Vyhadzovač pozerá do výšky dospelého – tučniaka pod nosom nevidí
func _doorman_gag() -> void:
	doorman.set(&"passive", true)
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(doorman):
		get_tree().current_scene.speech(doorman, "HUH? ...NOBODY.\nDAMN KIDS.", Color8(245, 235, 209), 2.4, -70.0)
	await get_tree().create_timer(2.2).timeout
	_set_open(false)
	if is_instance_valid(doorman):
		doorman.set(&"home_facing", 1.0)
		doorman.call(&"_set_facing", 1.0)
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(doorman):
			doorman.set(&"passive", false)


func _set_open(on: bool) -> void:
	_open = on
	_sprite.frame = 2 if on else 0
	_shape.set_deferred(&"disabled", on)
	if on:
		opened.emit()


# ---------------------------------------------------------------- ukážka: mafián príde a zaklope

func start_demo() -> void:
	if _demo_started:
		return
	_demo_started = true
	if messenger_scene == null:
		_demo_done = true
		_reveal_hint()
		return
	var m: Node2D = messenger_scene.instantiate()
	m.set(&"needs_light", true)
	m.set(&"respawn_time", 0.0)
	m.set(&"start_facing", 1.0)
	m.set(&"walk_speed", 55.0)
	m.global_position = messenger_from
	get_parent().add_child(m)
	m.set(&"goto_x", global_position.x - 36.0)
	m.tree_exiting.connect(func(): if not _demo_done: _reveal_hint())
	# počká, kým dôjde k dverám (alebo kým ho Ricco nezloží / nezačne strieľať)
	while is_instance_valid(m) and m.get(&"goto_x") == m.get(&"goto_x"):   # NAN != NAN → došiel
		await get_tree().physics_frame
		if not is_instance_valid(m) or m.get(&"state") not in [0, 1]:
			_reveal_hint()
			return
	if not is_instance_valid(m):
		return
	_busy = true
	await get_tree().create_timer(0.4).timeout
	var t0: float = 0.0
	for t in KNOCK_TIMES:
		await get_tree().create_timer(t - t0).timeout
		t0 = t
		_knock_fx()
	await get_tree().create_timer(0.7).timeout
	_sprite.frame = 1
	_say("...", 1.0)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(m) or m.get(&"state") not in [0, 1]:
		_sprite.frame = 0
		_busy = false
		_reveal_hint()
		return
	_set_open(true)
	m.set(&"goto_x", global_position.x + 40.0)
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(m):
		m.queue_free()   # vošiel dnu (stratí sa za dverami)
	_set_open(false)
	_busy = false
	_demo_done = true
	_reveal_hint()


func _reveal_hint() -> void:
	var h := get_node_or_null(hint_path) as CanvasItem
	if h:
		h.visible = true


func _knock_fx() -> void:
	var l := Label.new()
	l.text = "KNOCK"
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", 8)
	l.add_theme_color_override(&"font_color", Color8(255, 236, 190))
	l.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	l.add_theme_constant_override(&"outline_size", 4)
	l.position = Vector2(-30 + randf_range(-4.0, 4.0), -44 + randf_range(-6.0, 2.0))
	l.z_index = 30
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 10.0, 0.5)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	var sh := create_tween()   # dvere sa trasú
	sh.tween_property(_sprite, "position:x", 1.0, 0.03)
	sh.tween_property(_sprite, "position:x", 0.0, 0.05)


func _say(t: String, dur: float) -> void:
	var lvl := get_tree().current_scene
	if lvl.has_method(&"speech"):
		lvl.speech(self, t, Color8(245, 235, 209), dur, -46.0)
