class_name Level2
extends Node2D
## Kapitola II – Wharf Rats. Level 2: cintorín v noci, Donov pohreb.
## Ricco má od začiatku Donov derringer a spomalenie (dostal ich v pivnici v kapitole I).
## Časti (tools/build_level2.gd): brána → hrobník s lampášom (úkryt v otvorenom hrobe) → kôlňa s revolverom .38 →
##   mauzóleá → strecha veľkého mauzólea (duch komentuje vlastný pohreb, mafián odhodí zápalky) →
##   pohreb pred kostolom (smútiaci zbadajú Ricca na svetle) → konáre duba alebo zozadu na strážnika →
##   krypta so svetlom vo dverách = cesta ďalej (len so stopou – zápalkami z prístavu, Pier 13) → tunel do prístavu (docks.tscn).
## Celý cintorín je „tma“ (player.dark_area): vidno ťa len na svetle lámp, sviečok, lampášov a dverí krypty.
## Scénu generuje tools/build_level2.gd – úpravy mapy rob tam, inak sa pri ďalšom generovaní prepíšu.
## Godot docs: classes/class_tween, classes/class_canvaslayer, classes/class_area2d

const MAP := Rect2i(0, -304, 2240, 360)            ## hranice kamery (px) – zvisle presne jedna obrazovka
const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const DOCKS := "res://levels/level2/docks.tscn"
const COLDSTORE := "res://levels/level2/coldstore.tscn"
const MARGARET := "res://levels/level2/margaret.tscn"
const LoadingScreen := preload("res://ui/loading/loading_screen.gd")
const DERRINGER := preload("res://weapons/derringer/derringer.tres")
const REVOLVER := preload("res://weapons/revolver/revolver.tres")
const WEAPON_PICKUP := preload("res://weapons/weapon_pickup.gd")
const GHOST := preload("res://characters/don/ghost_don.png")
const GLOW := preload("res://levels/level1/art/glow.png")
const MATCHBOOK := preload("res://levels/level2/art/matchbook.png")
const MATCHBOOK_BIG := preload("res://levels/level2/art/matchbook_big.png")
const FONT := preload("res://ui/fonts/tiny5.ttf")
const NIGHT := Color(0.72, 0.8, 0.86)               ## mafiáni sú v mesačnom svetle tmavší (Ricco sa stmavuje sám)
const BELL_POS := Vector2(1648, -60)                 ## kostol za pohrebom

## 0 = brána, 1 = za kôlňou, 2 = strecha nad pohrebom, 3 = za pohrebom; 4–6 = prístav (docks.gd), 7–10 = mraziareň (coldstore.gd), 11 = paluba S.S. Margaret (margaret.gd). Statické premenné prežijú smrť
## (reload scény), úvodné menu a koniec kapitoly I ich vynulujú (reset()).
static var checkpoint: int = 0
static var intro_done: bool = false
static var gate_seen: bool = false
static var has_revolver: bool = false
static var funeral_seen: bool = false
static var clue_found: bool = false
static var docks_arrived: bool = false
static var has_lupara: bool = false
static var lou_seen: bool = false
static var docks_barks: Array[StringName] = []   ## hlášky ducha v prístave, ktoré už zazneli
static var coldstore_arrived: bool = false
static var ledger_read: bool = false             ## účtovná kniha Lou z kancelárie v mraziarni (stopa k lodi)
static var cold_barks: Array[StringName] = []    ## hlášky ducha v mraziarni, ktoré už zazneli
static var margaret_arrived: bool = false        ## Ricco už vyšiel na palubu lode (úvod sa neopakuje po smrti)
static var lou_revealed: bool = false            ## Big Lou sa už ukázal na mostíku (po smrti bez blesku a hlášky)
static var lou_phase: int = 1                    ## fáza boja s Big Lou, ktorú Ricco dosiahol – po smrti začne od nej

const INTRO: Array[String] = [
	"Three days since they whacked the boss. Tonight they put him in the ground.",
	"The whole Family showed up in their Sunday best...",
	"...and somewhere in that crowd is the rat who sold him out. I stay in the dark. I watch.",
]

var player: Node2D
var pcam: PhantomCamera2D
var _ghost: Sprite2D
var _ghost_glow: Sprite2D
var _ghost_t: float = 0.0
var _smoker: Node2D
var _matchbook: Area2D
var _leaving: bool = false
var _exit_hint_t: float = 0.0
var _bell_t: float = 6.0


## Nová hra / nová kapitola – všetko odznova
static func reset() -> void:
	checkpoint = 0
	intro_done = false
	gate_seen = false
	has_revolver = false
	funeral_seen = false
	clue_found = false
	docks_arrived = false
	has_lupara = false
	lou_seen = false
	docks_barks.clear()
	coldstore_arrived = false
	ledger_read = false
	cold_barks.clear()
	margaret_arrived = false
	lou_revealed = false
	lou_phase = 1


func _ready() -> void:
	var black := _fade_rect()
	black.color.a = 1.0
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	pcam = player.get_node(^"PhantomCamera2D")
	_set_limits(MAP)
	var help := get_node_or_null(^"HUD/ControlsHelp") as Control
	if help:
		help.visible = false
	# výbava: derringer z kapitoly I (alebo revolver, ak ho už našiel) + spomalenie od ducha
	var list: Array[WeaponData] = [REVOLVER if has_revolver else DERRINGER]
	player.set_loadout(list)
	player.focus.unlocked = true
	player.dark_area = true
	player.light_zones = 0
	var spawn := get_node_or_null(NodePath("Spawn%d" % checkpoint)) as Node2D
	if spawn:
		player.global_position = spawn.global_position
	pcam.teleport_position.call_deferred()
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var rig := g.get(&"rig") as Node2D
		if rig:
			rig.modulate = NIGHT
	_smoker = get_node_or_null(^"Smoker") as Node2D
	if not has_revolver:
		_spawn_revolver()
	if funeral_seen and not clue_found:
		_drop_matchbook(_smoker.global_position + Vector2(-48, -4) if is_instance_valid(_smoker) else Vector2(1480, -4))
	_connect(^"GateBark", _on_gate)
	_connect(^"FuneralView", _on_funeral_view)
	_connect(^"CryptExit", _on_crypt)
	for t in [[^"Checkpoint1", 1], [^"Checkpoint3", 3]]:
		_connect(t[0], func(): checkpoint = maxi(checkpoint, t[1]))
	Sfx.loop(&"cemetery", self, Vector2.INF, -4.0)
	if checkpoint == 0 and not intro_done:
		_intro(black)
	else:
		var tw := create_tween()
		tw.tween_interval(0.15)
		tw.tween_property(black, "color:a", 0.0, 0.5)
		tw.tween_callback(black.get_parent().queue_free)


func _connect(path: NodePath, f: Callable) -> void:
	var a := get_node_or_null(path) as Area2D
	if a:
		a.body_entered.connect(func(b: Node):
			if b == player:
				f.call())


func _process(delta: float) -> void:
	if player == null:
		return
	# zvon kostola občas odbije (pohreb)
	_bell_t -= delta
	if _bell_t <= 0.0:
		_bell_t = randf_range(16.0, 24.0)
		Sfx.play(&"church_bell", Vector2.INF, -13.0, 0.0, &"Ambience")
	_exit_hint_t -= delta
	# revolver: Ricco ho vymenil za derringer pri skrinke hrobníka (F)
	if not has_revolver and REVOLVER in player.loadout:
		has_revolver = true
		bark("A .38! SIX SHOTS INSTEAD OF TWO.\nNOW WE'RE TALKIN', KID.")
	# mafián so zápalkami padol skôr, než ich stihol odhodiť – vypadnú mu z vrecka
	if not clue_found and _matchbook == null and is_instance_valid(_smoker) and _smoker.get(&"state") == Gangster.State.DEAD:
		_drop_matchbook(_smoker.global_position + Vector2(0, -4))
	# duch vedľa Ricca (len počas pohrebu na streche)
	if _ghost:
		_ghost_t += delta
		_ghost.global_position = player.global_position + Vector2(26.0 * player.facing, -42.0 + sin(_ghost_t * 2.2) * 2.0)
		_ghost.flip_h = player.facing < 0.0
		_ghost_glow.global_position = _ghost.global_position


# ---------------------------------------------------------------- udalosti

## Úvod: titulok kapitoly na čiernom, potom Riccove myšlienky
func _intro(black: ColorRect) -> void:
	intro_done = true
	player.set_cutscene(true)
	var title := _title_label("CHAPTER II", 24, Color8(245, 235, 209), -14)
	var sub := _title_label("WHARF RATS", 8, Color8(150, 230, 245), 14)
	black.add_child(title)
	black.add_child(sub)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(title, "modulate:a", 1.0, 0.8)
	tw.tween_property(sub, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.2)
	tw.tween_property(title, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(sub, "modulate:a", 0.0, 0.5)
	tw.tween_property(black, "color:a", 0.0, 1.0)
	await tw.finished
	black.get_parent().queue_free()
	player.set_cutscene(false)
	await get_tree().create_timer(0.6, false).timeout
	ThoughtBox.think(self, INTRO)


func _on_gate() -> void:
	if gate_seen:
		return
	gate_seen = true
	bark("MY OWN FUNERAL. AND NOBODY\nTHOUGHT TO HIRE A BAND.")


## Strecha veľkého mauzólea: duch sa ukáže vedľa Ricca a komentuje pohreb. Hra nestojí.
## Mafián vzadu si zapáli a odhodí zápalky – to je stopa (Pier 13).
var _funeral_playing: bool = false

func _on_funeral_view() -> void:
	if funeral_seen or _funeral_playing:
		return
	_funeral_playing = true
	checkpoint = maxi(checkpoint, 2)
	_ghost_show(true)
	await _wait(0.6)
	bark("LOOK AT 'EM. HALF THESE MUGS\nNEVER LIKED ME ANYWAY.")
	await _wait(3.6)
	bark("LOUSY FLOWERS.\nI PAID FOR BETTER FLOWERS.")
	await _wait(3.6)
	var lines: Array[String] = ["Every big shot in the Family came to pay respects.", "And one of 'em pulled the trigger. I'd bet my hat on it."]
	await ThoughtBox.think(self, lines).finished
	if is_instance_valid(_smoker) and _smoker.get(&"state") != Gangster.State.DEAD:
		await _smoker_tosses_matches()
		bark("SMOKIN' AT MY FUNERAL?!\n...HEY. WHAT'D THAT BUM JUST DROP?")
		await _wait(3.6)
	_ghost_show(false)
	funeral_seen = true
	_funeral_playing = false
	if not clue_found:
		var next: Array[String] = ["Gotta get my flippers on that. Quiet-like.", "Stay out of the lamplight."]
		ThoughtBox.think(self, next)


## Mafián si zapáli cigaretu (záblesk zápalky, žeravý koniec) a zápalky odhodí za seba do tmy
func _smoker_tosses_matches() -> void:
	var f: float = _smoker.get(&"facing")
	var mouth: Vector2 = _smoker.global_position + Vector2(7.0 * f, -60.0)
	var flare := _light_sprite(mouth + Vector2(3.0 * f, 4.0), Color(1.0, 0.8, 0.45, 0.9), 0.5)
	var tw := create_tween()
	tw.tween_property(flare, "scale", Vector2(0.9, 0.9), 0.15)
	tw.tween_property(flare, "modulate:a", 0.0, 0.9)
	tw.tween_callback(flare.queue_free)
	await _wait(0.9)
	var ember := _light_sprite(Vector2(7.0 * f, -60.0), Color(1.0, 0.45, 0.2, 0.8), 0.12)   # žeravá cigareta (na mafiánovi)
	ember.reparent(_smoker, false)
	ember.set_script(load("res://world/fx/flicker.gd"))
	await _wait(0.5)
	# odhodí zápalky dozadu cez plece
	var s := Sprite2D.new()
	s.texture = MATCHBOOK
	s.z_index = 6
	s.global_position = _smoker.global_position + Vector2(4.0 * f, -46.0)
	add_child(s)
	var from: Vector2 = s.global_position
	var land: Vector2 = _smoker.global_position + Vector2(-48.0 * f, -4.0)
	var mid: Vector2 = (from + land) / 2.0 + Vector2(0, -26)
	var arc := create_tween()
	arc.tween_method(func(t: float):
		s.global_position = _bezier(from, mid, land, t)
		s.rotation = t * 7.0, 0.0, 1.0, 0.55)
	await arc.finished
	s.queue_free()
	_drop_matchbook(land)


func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


## Zápalky na zemi – jemne sa lesknú; keď cez ne Ricco prejde, zoberie ich
func _drop_matchbook(pos: Vector2) -> void:
	if _matchbook or clue_found:
		return
	_matchbook = Area2D.new()
	_matchbook.collision_layer = 0
	_matchbook.collision_mask = 2
	_matchbook.global_position = pos
	add_child(_matchbook)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(18, 20)
	cs.shape = r
	cs.position = Vector2(0, -6)
	_matchbook.add_child(cs)
	var spr := Sprite2D.new()
	spr.texture = MATCHBOOK
	spr.position = Vector2(0, 1)
	_matchbook.add_child(spr)
	var shine := _light_sprite(Vector2.ZERO, Color(1.0, 0.85, 0.5, 0.35), 0.25)
	shine.reparent(_matchbook, false)
	var tw := shine.create_tween().set_loops()
	tw.tween_property(shine, "modulate:a", 0.08, 0.7)
	tw.tween_property(shine, "modulate:a", 0.35, 0.7)
	_matchbook.body_entered.connect(func(b: Node):
		if b == player:
			_found_clue())


## Stopa: zápalky „Fontana Shipping Co. – Pier 13“ (zväčšenina na chvíľu na obrazovke, hra beží ďalej)
func _found_clue() -> void:
	if clue_found:
		return
	clue_found = true
	Sfx.play(&"pickup_ammo")
	_matchbook.queue_free()
	_show_matchbook_card()
	var lines: Array[String] = ["Matches. 'Fontana Shipping Co. - Pier 13.'"]
	await ThoughtBox.think(self, lines).finished
	bark("FONTANA... BIG LOU FONTANA.\nTHAT FAT RAT RUNS THE DOCKS.")
	await _wait(3.6)
	var next: Array[String] = ["The docks, huh. Then that's where I'm headed.", "Out through the old crypt. Nobody sees me leave."]
	ThoughtBox.think(self, next)


func _show_matchbook_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 33
	add_child(layer)
	var root := Control.new()
	root.position = Vector2(640 - 124 - 16, 40)
	root.modulate.a = 0.0
	layer.add_child(root)
	var img := TextureRect.new()
	img.texture = MATCHBOOK_BIG
	root.add_child(img)
	# [text, veľkosť, farba, poloha, zarovnanie] – PIER 13 vľavo dole, aby nezakryl kotvu (logo prístavu)
	for spec in [["FONTANA", 16, Color8(240, 214, 140), Vector2(4, 14), HORIZONTAL_ALIGNMENT_CENTER],
			["SHIPPING CO.", 8, Color8(240, 214, 140), Vector2(4, 34), HORIZONTAL_ALIGNMENT_CENTER],
			["PIER 13", 8, Color8(250, 240, 220), Vector2(12, 58), HORIZONTAL_ALIGNMENT_LEFT]]:
		var l := Label.new()
		l.text = spec[0]
		l.add_theme_font_override(&"font", FONT)
		l.add_theme_font_size_override(&"font_size", spec[1])
		l.add_theme_color_override(&"font_color", spec[2])
		l.horizontal_alignment = spec[4]
		l.position = spec[3]
		l.size = Vector2(116, spec[1] + 2)
		root.add_child(l)
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(root, "position:y", 32.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(4.0)
	tw.tween_property(root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)


## Krypta: bez stopy ešte nie – so zápalkami Ricco vojde dnu, starým pašeráckym tunelom do prístavu
func _on_crypt() -> void:
	if _leaving:
		return
	if not clue_found:
		if _exit_hint_t <= 0.0:
			_exit_hint_t = 8.0
			var lines: Array[String] = ["Not yet. That bum by the grave dropped somethin'."]
			ThoughtBox.think(self, lines)
		return
	_leaving = true
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	var black := _fade_rect()
	var tw := create_tween()
	tw.tween_property(player, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(black, "color:a", 1.0, 1.0)
	await tw.finished
	checkpoint = 4
	LoadingScreen.go(get_tree(), DOCKS, 0.6)


# ---------------------------------------------------------------- revolver

## Revolver .38 leží v otvorenej skrinke hrobníka (výmena za derringer cez F – weapons/weapon_pickup.gd)
func _spawn_revolver() -> void:
	var spot := get_node_or_null(^"RevolverSpot") as Node2D
	if spot == null:
		return
	var p: Area2D = WEAPON_PICKUP.new()
	p.weapon = REVOLVER
	p.ammo = REVOLVER.mag_size * 2
	add_child(p)
	p.global_position = spot.global_position


# ---------------------------------------------------------------- duch a hlášky

func _ghost_show(on: bool) -> void:
	if on:
		_ghost_glow = _light_sprite(Vector2.ZERO, Color(0.45, 0.9, 1.0, 0.6), 1.3)
		_ghost_glow.scale = Vector2(1.3, 1.8)
		_ghost = Sprite2D.new()
		_ghost.texture = GHOST
		_ghost.z_index = 7
		add_child(_ghost)
		_ghost.modulate.a = 0.0
		_ghost_glow.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_ghost, "modulate:a", 0.85, 0.8)
		tw.tween_property(_ghost_glow, "modulate:a", 0.6, 0.8)
		return
	if _ghost == null:
		return
	var g := _ghost
	var gg := _ghost_glow
	_ghost = null
	_ghost_glow = null
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(g, "global_position", player.global_position + Vector2(0, -20), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(g, "scale", Vector2(0.2, 0.2), 0.45)
	tw2.tween_property(g, "modulate:a", 0.0, 0.45)
	tw2.tween_property(gg, "modulate:a", 0.0, 0.5)
	tw2.chain().tween_callback(func():
		g.queue_free()
		gg.queue_free())


## Krátka hláška ducha nad Riccom (ako v pivnici – nezastaví hru, sama zmizne); keď je duch vedľa, vyššie nad ním
func bark(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", 8)
	l.add_theme_color_override(&"font_color", Color8(200, 244, 250))
	l.add_theme_color_override(&"font_outline_color", Color8(10, 24, 34))
	l.add_theme_constant_override(&"outline_size", 4)
	l.z_index = 40
	add_child(l)
	l.reset_size()
	var follow := func(): if is_instance_valid(l) and is_instance_valid(player): l.global_position = (player.global_position + Vector2(-l.size.x / 2.0, (-96.0 if _ghost else -78.0) - l.size.y + 18.0)).round()
	follow.call()
	var tw := create_tween()
	tw.tween_method(func(_v: float): follow.call(), 0.0, 1.0, 3.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(2.7)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- pomocné

func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


func _light_sprite(pos: Vector2, col: Color, s: float) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = GLOW
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.modulate = col
	g.scale = Vector2(s, s)
	g.z_index = 6
	add_child(g)
	g.global_position = pos
	return g


func _title_label(t: String, size: int, col: Color, dy: float) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)   # cez celú obrazovku, text v strede
	l.offset_top = dy
	l.offset_bottom = dy
	l.modulate.a = 0.0
	return l


func _set_limits(r: Rect2i) -> void:
	pcam.limit_left = r.position.x
	pcam.limit_top = r.position.y
	pcam.limit_right = r.end.x
	pcam.limit_bottom = r.end.y


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
