extends StaticBody2D
## Dvere do šatne, kde pijú mafiáni (kapitola III – zákulisie klubu The Blue Canary). Ricco pri nich zaklope (F):
## o chvíľu sa otvoria a jeden z mafiánov (inside – postupne, kto ešte žije) vyjde von pozrieť sa, kto to bol.
## Chvíľu sa obzerá (Ricco ho môže zozadu zneškodniť), potom sa vráti dnu a dvere sa zavrú. Keď si Ricca všimne,
## ostanú otvorené. Zatvorené dvere sú stena – zastavia pohyb, pohľad aj guľky.
## Poloha uzla = spodok dverí na podlahe. Deti: Sprite (door_side.png – 2 snímky), Shape.
## Godot docs: classes/class_staticbody2d, classes/class_scenetree (physics_frame)

@export var inside: Array[NodePath] = []     ## mafiáni v šatni (po poradí, kto vyjde)
@export var out_x: float = -64.0             ## px od dverí – kam vyjde (záporné = doľava)
@export var look_time: float = 3.6           ## s – ako dlho sa vonku obzerá
@export var lines: PackedStringArray = ["WHO'S THERE?", "HELLO? ...FUNNY GUY.", "QUIT KNOCKIN', WISE GUY!"]

const FONT := preload("res://ui/fonts/tiny5.ttf")

var _player: Node2D
var _hint: Label
var _busy: bool = false
var _open: bool = false
var _n: int = 0


func _ready() -> void:
	_hint = Label.new()
	_hint.add_theme_font_override(&"font", FONT)
	_hint.add_theme_font_size_override(&"font_size", 8)
	_hint.add_theme_color_override(&"font_color", Color8(245, 235, 209))
	_hint.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	_hint.add_theme_constant_override(&"outline_size", 4)
	_hint.position = Vector2(-22, -112)
	_hint.z_index = 40
	_hint.visible = false
	add_child(_hint)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		return
	var d: Vector2 = _player.global_position - global_position
	var near: bool = absf(d.x) < 30.0 and absf(d.y) < 20.0 and int(_player.get(&"state")) == 0 and not _player.get(&"in_cutscene")
	_hint.visible = near and not _busy and not _open
	if _hint.visible:
		_hint.text = "%s  -  KNOCK" % KeyBindings.short(&"takedown")
		if Input.is_action_just_pressed(&"takedown"):
			_knock()


func _knock() -> void:
	_busy = true
	Sfx.play(&"knock", global_position + Vector2(0, -50), -2.0)
	await get_tree().create_timer(1.0, false).timeout
	var guy := _next_guy()
	if guy == null:   # nikto už v šatni nie je – dvere sa dajú otvoriť
		set_open(true)
		_busy = false
		return
	set_open(true)
	var scene := get_tree().current_scene
	if scene.has_method(&"_speak"):
		scene._speak(guy, lines[mini(_n, lines.size() - 1)])
	_n += 1
	var home_x: float = guy.global_position.x
	var home_face: float = float(guy.get(&"home_facing"))
	guy.set(&"goto_x", global_position.x + out_x)
	# vyjde von
	var t: float = 0.0
	while t < 6.0 and _calm(guy) and not is_nan(float(guy.get(&"goto_x"))):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	# obzerá sa
	t = 0.0
	var turn: float = 1.2
	while t < look_time and _calm(guy):
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		turn -= dt
		if turn <= 0.0:
			turn = 1.2
			guy.call(&"_set_facing", -float(guy.get(&"facing")))
	if _calm(guy):   # nikoho nevidel – vráti sa dnu
		guy.set(&"goto_x", home_x)
		t = 0.0
		while t < 6.0 and _calm(guy) and not is_nan(float(guy.get(&"goto_x"))):
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		if _calm(guy):
			guy.set(&"home_facing", home_face)
			guy.call(&"_set_facing", home_face)
			set_open(false)
	elif not is_instance_valid(guy) or int(guy.get(&"state")) == 10:   # zneškodnený vonku – dvere sa privrú
		await get_tree().create_timer(1.2, false).timeout
		set_open(false)
	_busy = false


## Ďalší živý mafián zo šatne
func _next_guy() -> Node2D:
	for p in inside:
		var g := get_node_or_null(p) as Node2D
		if g and int(g.get(&"state")) != 10 and g.global_position.distance_to(global_position) < 260.0:
			return g
	return null


## Žije a o Riccovi nevie (PATROL, IDLE)
func _calm(g: Node2D) -> bool:
	return is_instance_valid(g) and int(g.get(&"state")) <= 1


func set_open(on: bool) -> void:
	if _open == on:
		return
	_open = on
	(get_node(^"Shape") as CollisionShape2D).set_deferred(&"disabled", on)
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s:
		s.frame = 1 if on else 0
	Sfx.play(&"door_open" if on else &"door_close", global_position + Vector2(0, -40), -8.0)
