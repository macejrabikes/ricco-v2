extends Node2D
## Pivnica: Ricco nájde umierajúceho Dona Vita. Dialóg (DialogBox), Don zomrie, z tela vystúpi jeho duch
## (v kabáte, ktorý ležal vedľa), zdvihne zo zeme svoju pištoľ a „požičia“ Riccovi ruky:
## Ricco dostane pištoľ a spomalenie. Hneď nato zídu po schodoch gangstri – prvá prestrelka.
## Keď padnú všetci, otvoria sa dvere von (koniec kapitoly 1).
##
## Uzly (vytvára tools/build_level1.gd): Pool, Body, Hat, Coat, Gun, Ghost, GhostGlow, Bulb + v leveli
## DonTrigger (Area2D), CellarDoor (Sprite2D), CellarExit (Area2D), FightHints (Node2D), EnemySpawn (Marker2D – hore na schodoch).
## Checkpoint 5 = po cutscéne (Level1.checkpoint).

const PORTRAIT_DON := preload("res://characters/don/portrait_don.png")
const PORTRAIT_GHOST := preload("res://characters/don/portrait_ghost.png")
const PORTRAIT_RICCO := preload("res://characters/don/portrait_ricco.png")
const DON_DEAD := preload("res://characters/don/don_dead.png")
const SWEAT := preload("res://characters/don/sweat.png")
const DOOR_OPEN := preload("res://levels/level1/art/cellar_door_open.png")
const PISTOL := preload("res://weapons/pistol/pistol.tres")
const WAVE := ["gangster_tommy", "gangster_coppola", "gangster_bruiser"]

const DON := "DON VITO"
const GHOST := "THE DON'S GHOST"
const RICCO := "RICCO"

@onready var body: Sprite2D = $Body
@onready var pool: Sprite2D = $Pool
@onready var gun: Sprite2D = $Gun
@onready var ghost: Sprite2D = $Ghost
@onready var ghost_glow: Sprite2D = $GhostGlow
@onready var coat: Sprite2D = $Coat

var level: Node
var player: Node2D
var _played: bool = false
var _nervous: bool = false
var _bob: float = 0.0
var _ghost_float: bool = false
var _enemies: Array[Node] = []
var _fight: bool = false
var _door_open: bool = false


func _ready() -> void:
	level = get_parent()
	ghost.visible = false
	ghost_glow.visible = false
	var trig := level.get_node_or_null(^"DonTrigger") as Area2D
	if trig:
		trig.body_entered.connect(_on_trigger)
	var exit := level.get_node_or_null(^"CellarExit") as Area2D
	if exit:
		exit.body_entered.connect(func(b: Node):
			if _door_open and b == player:
				level.chapter_end())
	_set_hints(false)
	if Level1.checkpoint >= 5:
		_skip_to_fight.call_deferred()


## Checkpoint po cutscéne (Ricco zomrel v prestrelke): Don je mŕtvy, Ricco má pištoľ, gangstri prídu znova
func _skip_to_fight() -> void:
	_played = true
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	body.texture = DON_DEAD
	coat.visible = false
	gun.visible = false
	player.global_position = Vector2(global_position.x - 40, global_position.y)
	var list: Array[WeaponData] = [PISTOL]
	player.set_loadout(list)
	player.focus.unlocked = true
	player.dark_area = false   # v prestrelke sa už neskrýva – nestmavne
	_set_hints(true)
	get_tree().create_timer(1.2, false).timeout.connect(_start_fight)


func _on_trigger(b: Node) -> void:
	if _played or not b.is_in_group(&"player"):
		return
	_played = true
	player = b as Node2D
	_play()


func _process(delta: float) -> void:
	_bob += delta
	if _ghost_float:
		ghost.position.y = -42.0 + sin(_bob * 2.2) * 2.0
		ghost_glow.position = ghost.position
	if _nervous and player:
		player.visual.position.x = randf_range(-0.8, 0.8)   # trasie sa
	if _fight and not _door_open:
		for e in _enemies:
			if is_instance_valid(e) and e.state != 10:   # 10 = Gangster.State.DEAD
				return
		_open_door()


# ---------------------------------------------------------------- cutscéna

func _play() -> void:
	# počká, kým Ricco stojí na zemi, potom mu zoberie ovládanie
	while not player.is_on_floor():
		await get_tree().physics_frame
	player.set_cutscene(true)
	await _walk_to(global_position.x - 54.0)
	var box := DialogBox.new()
	level.add_child(box)
	await _wait(0.4)
	await box.say(DON, PORTRAIT_DON, "Ricciardo... figlio mio. You found me.")
	_nervous = true
	_emote("!!")
	_sweat_loop()
	await box.say(RICCO, PORTRAIT_RICCO, "B-boss! Who did this to you?!")
	await box.say(DON, PORTRAIT_DON, "Ehh, don't fuss, kid. Them rats took me for a ride. I'm all washed up.")
	await box.say(DON, PORTRAIT_DON, "Listen to me. You gotta settle the score. Every last one of 'em pays. For me... for the Family. Capisce?")
	await box.say(RICCO, PORTRAIT_RICCO, "D-don't talk like that, boss! Just hang on, I'll fetch the doc!")
	await box.say(DON, PORTRAIT_DON, "Ricciardo...")
	box.close()
	# Don zomrie – žiarovka zablikne, ticho
	body.texture = DON_DEAD
	_flicker_bulb()
	await _wait(1.6)
	# z tela vystúpi duch
	await _ghost_rise()
	_nervous = false
	player.sprite.play(player._hat_anim(&"hurt"))   # zľakne sa (klobúk podskočí)
	_emote("?!")
	var back := create_tween()
	back.tween_property(player, "global_position:x", player.global_position.x - 14.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(0.6)
	player.sprite.play(player._hat_anim(&"idle"))
	_nervous = true
	box = DialogBox.new()
	level.add_child(box)
	await box.say(RICCO, PORTRAIT_RICCO, "B-B-BOSS?! WHAT IN THE SAM HILL...?!")
	await box.say(GHOST, PORTRAIT_GHOST, "Ha! Looks like Saint Peter ain't openin' the gates for me just yet.", true)
	await box.say(GHOST, PORTRAIT_GHOST, "Guess you're stuck with me, kid. Till every last debt is paid in full.", true)
	await box.say(GHOST, PORTRAIT_GHOST, "And no offense, little one, but with them flippers you couldn't hold a pea-shooter.", true)
	box.visible = false
	_nervous = false
	player.visual.position.x = 0.0
	await _ghost_takes_gun()
	box.visible = true
	await box.say(GHOST, PORTRAIT_GHOST, "So I'll lend you a hand. Two of 'em. Now let's go teach these bums some manners.", true)
	box.close()
	await _ghost_merge()
	# odteraz má Ricco pištoľ (drží ju ruka ducha) a spomalenie
	var list: Array[WeaponData] = [PISTOL]
	player.set_loadout(list)
	player.focus.unlocked = true
	player.dark_area = false   # v prestrelke sa už neskrýva – nestmavne
	Level1.checkpoint = 5
	_set_hints(true)
	await _wait(0.25)   # aby klik, ktorým sa zavrel dialóg, hneď nevystrelil
	player.set_cutscene(false)
	await _wait(1.6)
	_start_fight()


func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


func _walk_to(x: float) -> void:
	var dx: float = x - player.global_position.x
	if absf(dx) < 2.0:
		return
	player.facing = signf(dx)
	player.visual.scale.x = player.facing
	player.sprite.play(player._hat_anim(&"run"))
	var tw := create_tween()
	tw.tween_property(player, "global_position:x", x, absf(dx) / 110.0)
	await tw.finished
	player.facing = 1.0
	player.visual.scale.x = 1.0
	player.sprite.play(player._hat_anim(&"idle"))


## „!!“ / „?!“ nad Riccovou hlavou
func _emote(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
	l.add_theme_font_size_override(&"font_size", 16)
	l.add_theme_color_override(&"font_color", Color8(255, 214, 90))
	l.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	l.add_theme_constant_override(&"outline_size", 4)
	l.position = player.global_position + Vector2(-6, -68)
	l.z_index = 30
	level.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 8.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## Kvapky potu, kým je nervózny
func _sweat_loop() -> void:
	while _nervous and is_instance_valid(player):
		var s := Sprite2D.new()
		s.texture = SWEAT
		s.position = player.global_position + Vector2(randf_range(-2.0, 8.0), -44)
		s.z_index = 25
		level.add_child(s)
		var tw := create_tween()
		tw.tween_property(s, "position:y", s.position.y + 10.0, 0.5)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 0.5).set_delay(0.2)
		tw.tween_callback(s.queue_free)
		await _wait(randf_range(0.35, 0.7))


func _flicker_bulb() -> void:
	var g := get_node_or_null(^"BulbGlow") as CanvasItem
	if g == null:
		return
	var tw := create_tween()
	for i in 4:
		tw.tween_property(g, "modulate:a", 0.1, 0.05)
		tw.tween_property(g, "modulate:a", 1.0, 0.08)


## Duch sa zdvihne z tela: najprv leží (otočený), postaví sa, kabát zo zeme sa „rozplynie“ (má ho na sebe)
func _ghost_rise() -> void:
	ghost.visible = true
	ghost_glow.visible = true
	ghost.modulate.a = 0.0
	ghost_glow.modulate.a = 0.0
	ghost.rotation = -PI / 2.0
	ghost.position = Vector2(0, -10)
	var tw := create_tween()
	tw.tween_property(ghost, "modulate:a", 0.9, 0.8)
	tw.parallel().tween_property(ghost_glow, "modulate:a", 0.8, 0.8)
	tw.parallel().tween_property(coat, "modulate:a", 0.0, 1.2)
	tw.tween_property(ghost, "rotation", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(ghost, "position", Vector2(0, -42), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_ghost_float = true


## Duch dopláva k pištoli, zdvihne ju a priletí s ňou za Ricca
func _ghost_takes_gun() -> void:
	_ghost_float = false
	var tw := create_tween()
	tw.tween_property(ghost, "position", Vector2(gun.position.x + 6.0, -40.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	var tw2 := create_tween()
	tw2.tween_property(gun, "position", ghost.position + Vector2(10, 4), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(gun, "rotation", 0.0, 0.5)
	await tw2.finished
	var behind: Vector2 = to_local(player.global_position) + Vector2(-16, -46)
	var tw3 := create_tween()
	tw3.tween_property(ghost, "position", behind, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw3.parallel().tween_property(gun, "position", behind + Vector2(26, 14), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw3.parallel().tween_property(ghost_glow, "position", behind, 0.9)
	await tw3.finished


## Duch sa stiahne do Ricca (záblesk) – zostane z neho len ruka, ktorá drží zbraň
func _ghost_merge() -> void:
	var target: Vector2 = to_local(player.global_position) + Vector2(0, -20)
	var tw := create_tween()
	tw.tween_property(ghost, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ghost, "scale", Vector2(0.2, 0.2), 0.45)
	tw.parallel().tween_property(ghost, "modulate:a", 0.0, 0.45)
	tw.parallel().tween_property(gun, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(ghost_glow, "position", target, 0.45)
	tw.tween_property(ghost_glow, "scale", ghost_glow.scale * 3.0, 0.15)
	tw.tween_property(ghost_glow, "modulate:a", 0.0, 0.4)
	await tw.finished
	ghost.visible = false
	gun.visible = false


func _set_hints(on: bool) -> void:
	var h := level.get_node_or_null(^"FightHints") as CanvasItem
	if h == null:
		return
	h.visible = on
	if on:
		h.modulate.a = 0.0
		create_tween().tween_property(h, "modulate:a", 1.0, 0.8)


# ---------------------------------------------------------------- prestrelka

func _start_fight() -> void:
	_bark("WATCH OUT, KID! THEY'RE COMIN' DOWN THE STAIRS!\nSHOOT 'EM!")
	await _wait(0.9)
	var spawn := level.get_node(^"EnemySpawn") as Node2D
	for i in WAVE.size():
		var g: Node2D = load("res://characters/gangster/%s.tscn" % WAVE[i]).instantiate()
		g.set("respawn_time", 0.0)
		g.set("start_facing", 1.0)
		g.set("sight_range", 420.0)
		g.global_position = spawn.global_position + Vector2(-i * 4.0, 0)
		level.add_child(g)
		g.set(&"goto_x", spawn.global_position.x + 150.0 - i * 26.0)   # zbehnú dole po schodoch (aj cez schody)
		_enemies.append(g)
		await _wait(1.3)
	_fight = true


## Krátka hláška ducha nad Riccom (nezastaví hru, sama zmizne)
func _bark(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
	l.add_theme_font_size_override(&"font_size", 8)
	l.add_theme_color_override(&"font_color", Color8(200, 244, 250))
	l.add_theme_color_override(&"font_outline_color", Color8(10, 24, 34))
	l.add_theme_constant_override(&"outline_size", 4)
	l.z_index = 40
	level.add_child(l)
	l.reset_size()
	var follow := func(): if is_instance_valid(l) and is_instance_valid(player): l.global_position = player.global_position + Vector2(-l.size.x / 2.0, -78)
	follow.call()
	var tw := create_tween()
	tw.tween_method(func(_v: float): follow.call(), 0.0, 1.0, 3.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(2.7)
	tw.tween_callback(l.queue_free)


func _open_door() -> void:
	_door_open = true
	var door := level.get_node_or_null(^"CellarDoor") as Sprite2D
	if door:
		door.texture = DOOR_OPEN
	var g := level.get_node_or_null(^"CellarDoorGlow") as CanvasItem
	if g:
		g.visible = true
