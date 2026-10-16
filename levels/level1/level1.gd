class_name Level1
extends Node2D
## Level 1 – Pizzeria Don Vito.
## Časti: 1 ulica v daždi, 2 zadný dvor → okno, 3 interiér ako jeden súvislý priestor: jedáleň → kuchyňa →
##        sklad (zakrádanie v tme) → zadná herňa (balkón s hliadkou) → schody → pivnica s umierajúcim Donom.
##        Duch Dona dá Riccovi pištoľ a spomalenie (levels/level1/don_cutscene.gd), prvá prestrelka,
##        dvere von = koniec kapitoly.
## Ricco tu ešte nemá zbraň ani spomalenie (dá mu ich až duch Dona v pivnici).
## Scénu generuje tools/build_level1.gd – úpravy mapy rob tam, inak sa pri ďalšom generovaní prepíšu.
##
## Jediný prechod je okno na dvore: obraz stmavne, Ricco sa ocitne vnútri pri okne, dážď sa vypne a zapne sa
## tma (CanvasModulate „Darkness“). Vnútri už kamera len plynule mení hranice (CameraZone).
## Checkpointy (oblasti Checkpoint2/3) – po smrti začína Ricco na poslednom.

@export var camera_limits: Rect2i = Rect2i(-1312, -480, 3532, 528)   ## exteriér: ľavý, horný, šírka, výška (px)
@export var start_unarmed: bool = true

## 0 = ulica, 1 = vnútri (jedáleň), 2 = herňa, 3 = pivnica, 4 = po cutscéne (Ricco má zbraň).
## Statická premenná prežije reštart scény (smrť), úvodné menu ju vynuluje.
static var checkpoint: int = 0
## Úvodný monológ sa ukáže len raz (po smrti na ulici už nie)
static var intro_done: bool = false
## Príchod do pivnice (zostup po schodoch + hláška) len raz
static var cellar_arrived: bool = false

const PORTRAIT_RICCO := preload("res://characters/don/portrait_ricco.png")
const INTRO: Array[String] = [
	"Don Vito rang me at midnight. 'Come to the pizzeria, kid. Back way. Nobody sees you.'",
	"When the Don calls, you don't ask why. You just come.",
	"...Still. The old man sounded scared. Never heard him scared before.",
]

const SPAWNS: Array[StringName] = [&"", &"InteriorSpawn", &"CasinoSpawn"]
const CELLAR := "res://levels/level1/cellar.tscn"   ## pivnica – samostatná mapa (checkpoint 3+)

var _ended: bool = false
var _inside: bool = false
var player: Node2D
var pcam: PhantomCamera2D


func _ready() -> void:
	if checkpoint >= 3 and scene_file_path != CELLAR:   # zomrel v pivnici → rovno tam
		get_tree().change_scene_to_file.call_deferred(CELLAR)
		return
	# začiatok (aj po smrti) z čiernej – nič nepreblikne, kým sa kamera a Ricco nepresunú na miesto
	var black := _fade_rect()
	black.color.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(black, "color:a", 0.0, 0.5)
	tw.tween_callback(black.get_parent().queue_free)
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player:
		# hranice kamery nastavuje Phantom Camera (tá ich prenesie na Camera2D)
		pcam = player.get_node(^"PhantomCamera2D")
		_set_limits(camera_limits)
		pcam.teleport_position.call_deferred()
		if start_unarmed:
			var empty: Array[WeaponData] = []
			player.set_loadout(empty)
			player.focus.unlocked = false
	# v tutoriáli učia ovládanie nápisy kriedou – zoznam ovládania (F1) netreba
	var help := get_node_or_null(^"HUD/ControlsHelp") as Control
	if help:
		help.visible = false
	var end := get_node_or_null(^"LevelEnd") as Area2D
	if end:
		end.body_entered.connect(_on_end)
	var window := get_node_or_null(^"WindowEnter") as Area2D
	if window:
		window.body_entered.connect(func(b: Node):
			if b == player and not _inside:
				_go_inside(1, true))
	for t in [[^"Checkpoint2", 2], [^"Checkpoint3", 3]]:
		var area := get_node_or_null(t[0]) as Area2D
		if area:
			area.body_entered.connect(func(b: Node):
				if b == player:
					checkpoint = maxi(checkpoint, t[1]))
	var knock := get_node_or_null(^"KnockTrigger") as Area2D
	if knock:
		knock.body_entered.connect(func(b: Node):
			if b == player and has_node(^"SpeakeasyDoor"):
				$SpeakeasyDoor.start_demo.call_deferred())
	var down := get_node_or_null(^"CellarDescent") as Area2D
	if down:
		down.body_entered.connect(func(b: Node):
			if b == player:
				_descend())
	var talk := get_node_or_null(^"BouncerTalk") as Area2D
	if talk:
		talk.body_entered.connect(_on_bouncer_talk)
	if checkpoint >= 1 and player:
		_go_inside.call_deferred(mini(checkpoint, 2), false)
	elif player and not intro_done:
		_intro()


## Zostup do pivnice: Ricco sám zíde po schodoch do tmy, obraz stmavne a načíta sa pivnica
var _descending: bool = false

func _descend() -> void:
	if _descending:
		return
	_descending = true
	while not player.is_on_floor():
		await get_tree().physics_frame
	player.set_cutscene(true)
	player.facing = 1.0
	player.visual.scale.x = 1.0
	player.sprite.play(player._hat_anim(&"run"))
	var black := _fade_rect()
	var tw := create_tween()
	tw.tween_property(pcam, "limit_bottom", pcam.limit_bottom + 140, 0.8)   # kamera ide s ním dole do schodiska
	tw.parallel().tween_property(player, "global_position", player.global_position + Vector2(84, 84), 1.5)
	tw.parallel().tween_property(black, "color:a", 1.0, 1.1).set_delay(0.5)
	await tw.finished
	checkpoint = maxi(checkpoint, 3)
	get_tree().change_scene_to_file(CELLAR)


## Ricco na začiatku vysvetlí, prečo je tu (I1)
func _intro() -> void:
	intro_done = true
	player.set_cutscene(true)
	await get_tree().create_timer(0.8).timeout
	var box := DialogBox.new()
	add_child(box)
	for line in INTRO:
		await box.say("RICCO", PORTRAIT_RICCO, line)
	box.close()
	player.set_cutscene(false)


## Vyhadzovač pred pizzeriou – dnu sa nedá, Ricco musí zadom (raz)
var _bouncer_talked: bool = false

func _on_bouncer_talk(b: Node) -> void:
	if b != player or _bouncer_talked:
		return
	var bouncer := get_node_or_null(^"Bouncer") as Node2D
	if bouncer == null or not bouncer.get(&"passive"):
		return
	_bouncer_talked = true
	speech(bouncer, "PRIVATE PARTY TONIGHT.\nBEAT IT, BIRD.", Color8(245, 235, 209), 3.0, -66.0)
	await get_tree().create_timer(2.6).timeout
	speech(player, "...BACK WAY IT IS.", Color8(245, 235, 209), 2.6, -72.0)


## Krátka hláška nad postavou (nezastaví hru, sama zmizne)
func speech(who: Node2D, t: String, col: Color, dur: float, height: float) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
	l.add_theme_font_size_override(&"font_size", 8)
	l.add_theme_color_override(&"font_color", col)
	l.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	l.add_theme_constant_override(&"outline_size", 4)
	var bg := StyleBoxFlat.new()   # tmavý podklad – čitateľné aj na pozadí so svetlami
	bg.bg_color = Color(0.05, 0.04, 0.05, 0.8)
	bg.set_content_margin_all(3)
	l.add_theme_stylebox_override(&"normal", bg)
	l.z_index = 40
	add_child(l)
	l.reset_size()
	var follow := func(): if is_instance_valid(l) and is_instance_valid(who): l.global_position = (who.global_position + Vector2(-l.size.x / 2.0, height - l.size.y)).round()
	follow.call()
	var tw := create_tween()
	tw.tween_method(func(_v: float): follow.call(), 0.0, 1.0, dur)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(dur - 0.4)
	tw.tween_callback(l.queue_free)


func _set_limits(r: Rect2i) -> void:
	pcam.limit_left = r.position.x
	pcam.limit_top = r.position.y
	pcam.limit_right = r.end.x
	pcam.limit_bottom = r.end.y


## Dnu oknom (s fade = stmavnutie obrazu; bez = rovno pri štarte z checkpointu na mieste spawn)
func _go_inside(spawn_index: int, fade: bool) -> void:
	_inside = true
	checkpoint = maxi(checkpoint, spawn_index)
	var black: ColorRect
	if fade:
		black = _fade_rect()
		player.set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(black, "color:a", 1.0, 0.35)
		await tw.finished
	player.global_position = (get_node(NodePath(SPAWNS[spawn_index])) as Node2D).global_position
	player.velocity = Vector2.ZERO
	player.dark_area = true
	player.light_zones = 0
	var zone := CameraZone.find_at(get_tree(), player.global_position)
	if zone:
		zone.apply(player, true)
	pcam.teleport_position()
	var rain := get_node_or_null(^"Rain") as CPUParticles2D
	if rain:
		rain.emitting = false
		rain.visible = false
	var dark := get_node_or_null(^"Darkness") as CanvasModulate
	if dark:
		dark.visible = true
	if fade:
		player.set_physics_process(true)
		var tw2 := create_tween()
		tw2.tween_interval(0.15)
		tw2.tween_property(black, "color:a", 0.0, 0.45)
		tw2.tween_callback(black.get_parent().queue_free)


func _fade_rect() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	return r


## Koniec kapitoly 1 – Ricco vyjde dverami z pivnice: titulok a návrat do úvodného menu
func chapter_end() -> void:
	if _ended:
		return
	_ended = true
	player.set_cutscene(true)
	var black := _fade_rect()
	var title := Label.new()
	title.text = "END OF CHAPTER I"
	var sub := Label.new()
	sub.text = "THE DON'S GHOST"
	for l in [title, sub]:
		l.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
		l.add_theme_color_override(&"font_color", Color8(245, 235, 209))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)   # cez celú obrazovku, text v strede
		l.modulate.a = 0.0
		black.add_child(l)
	title.add_theme_font_size_override(&"font_size", 24)
	sub.add_theme_font_size_override(&"font_size", 8)
	sub.add_theme_color_override(&"font_color", Color8(150, 230, 245))
	title.offset_top = -14
	title.offset_bottom = -14
	sub.offset_top = 14
	sub.offset_bottom = 14
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.8)
	tw.tween_property(title, "modulate:a", 1.0, 0.8)
	tw.tween_property(sub, "modulate:a", 1.0, 0.6)
	tw.tween_interval(3.0)
	tw.tween_callback(func():
		checkpoint = 0
		get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn"))


func _on_end(body: Node) -> void:
	if _ended or not body.is_in_group(&"player"):
		return
	_ended = true
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var l := Label.new()
	l.text = "TO BE CONTINUED..."
	l.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
	l.add_theme_font_size_override(&"font_size", 16)
	l.add_theme_color_override(&"font_color", Color8(245, 235, 209))
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0
	layer.add_child(l)
	create_tween().tween_property(l, "modulate:a", 1.0, 0.8)
