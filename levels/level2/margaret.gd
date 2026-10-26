extends Level2
## Kapitola II – Wharf Rats, finále: paluba S.S. Margaret v búrke (návrh A + žeriav). Sem vedie pás z mraziarne do podpalubia.
## Časti (tools/build_margaret.gd): kajuta na korme (Ricco vyjde z podpalubia) → záchranný čln (plošina) → debny a sudy
##   (kryt) → nákladný žeriav so sieťou → krídlo mostíka (Big Lou) → nadstavba s mostíkom → prova.
## Bossfight s Big Lou (characters/lou/big_lou.gd): keď ho Ricco prvý raz uvidí na krídle mostíka, Lou nabije Thompson
##   a hore sa ukáže pás jeho zdravia (ui/boss_bar.gd, značky = tri fázy):
##   1. krídlo mostíka → zoskočí a beží do búdky (kúsok pizze) → 2. žeriav (world/ship/crane.gd): náklad a švih sieťou →
##   blesk do žeriavu, rameno sa zrúti na sud, výbuch búdky odhodí Lou, loď začne horieť → 3. pripálený Lou na palube.
##   Lou o réžii dáva vedieť signálom stage (_on_lou_stage) – tu sú hlášky ducha, blesk, požiar a pickupy.
## Útek z lode (Level2.escape_stage): Lou padol → duch pošle Ricca do kajuty Lou pod mostíkom (dvere v nadstavbe, F) →
##   v kajute (pod mapou, vlastné hranice kamery) list od „M.“ z hotela Majestic v New Yorku (ReadCard) → kotol vybuchne →
##   späť na palubu: na čas k záchrannému člnu (oheň, padajúce horiace trámy, výbuchy, loď sa nakláňa) → páka (F) spustí čln
##   → záver kapitoly na mori (epilogue.tscn). Keď čas vyprší, loď vybuchne (smrť → znova od dverí kajuty).
## Checkpointy: Level2.checkpoint 11 = paluba lode, Level2.lou_phase = fáza boja (po smrti začne v búdke / na horiacej palube),
##   Level2.escape_stage 1–2 = po boji (Ricco začne pri dverách kajuty – Spawn12).
## Scénu generuje tools/build_margaret.gd. Godot docs: classes/class_tween, classes/class_parallax2d, classes/class_cpuparticles2d

const SHIP_MAP := Rect2i(0, -304, 1568, 360)     ## hranice kamery (px) – paluba na y = 0, dole kúsok trupu a vlny
const LUPARA := preload("res://weapons/lupara/lupara.tres")
const BOSS_BAR := preload("res://ui/boss_bar.gd")
const FIRE := preload("res://world/ship/deck_fire.gd")
const PIZZA := preload("res://props/food/food_pickup.tscn")   ## jedlo (striedajú sa druhy) – Ricco ho vezme do zásoby
const AMMO := preload("res://props/ammo/ammo_pickup.tscn")
const TOMMY := preload("res://weapons/tommy/tommy.tres")
const LETTER := preload("res://levels/level2/art/ship/letter.png")
const LETTER_BIG := preload("res://levels/level2/art/ship/letter_big.png")
const DEBRIS := preload("res://levels/level2/art/ship/debris.png")
const SHADOW := preload("res://levels/level2/art/ship/shadow.png")
const CABIN_MAP := Rect2i(0, 800, 640, 360)   ## kajuta Lou pod mapou – kamera presne na jednu obrazovku
const DOOR_X := 1343.0                        ## dvere do kajuty v spodnej nadstavbe (Spawn12)
const ESCAPE_TIME := 40.0                     ## s na útek k člnu, potom loď vybuchne
const ESCAPE_FIRES := [[Vector2(1150, 0), 20.0], [Vector2(790, 0), 18.0], [Vector2(505, -26), 16.0], [Vector2(345, 0), 16.0]]
const BLASTS := [1010.0, 660.0, 300.0]        ## keď Ricco prebehne toto x, kúsok za ním niečo vybuchne

const ARRIVE: Array[String] = [
	"Two A.M. on the dot. The Margaret's pullin' out and I'm aboard.",
	"Lou's up on that bridge. Time we had a talk.",
]

var _splash: Sprite2D
var _splash_t: float = 5.0
var _say_queue: Array[String] = []
var _say_busy: float = 0.0
var _lou: BigLou
var _bar: CanvasLayer
var _fight: bool = false
var _vest_hits: int = 0
var _said: Array[StringName] = []   ## hlášky ducha v boji, ktoré už zazneli (v rámci jedného pokusu)
var _ended: bool = false
var _crane: Node2D
var _burning: bool = false
var _embers: CPUParticles2D
var _loops: Array[Node] = []   ## búrka, dážď, oheň – v kajute stíšené
var _in_cabin: bool = false
var _escape: bool = false      ## beží odpočet k člnu
var _escape_t: float = 0.0
var _escape_ui: Label
var _escape_bar: ColorRect
var _debris_t: float = 3.0
var _lurch_t: float = 5.0
var _blasts_left: Array = []
var _boarding: bool = false
var _letter: InteractSpot


func _ready() -> void:
	var black := _fade_rect()
	black.color.a = 1.0
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	pcam = player.get_node(^"PhantomCamera2D")
	_set_limits(SHIP_MAP)
	var help := get_node_or_null(^"HUD/ControlsHelp") as Control
	if help:
		help.visible = false
	checkpoint = maxi(checkpoint, 11)
	var list: Array[WeaponData] = [REVOLVER if has_revolver else DERRINGER]
	if has_lupara:
		list.append(LUPARA)
	if has_tommy and escape_stage > 0:
		list.append(TOMMY)
	player.set_loadout(list)
	player.focus.unlocked = true
	player.dark_area = false   # paluba je osvetlená (okná mostíka, lampy) – v boji nie je kde sa schovať do tmy
	var spawn := get_node_or_null(NodePath("Spawn%d" % (12 if escape_stage > 0 else checkpoint))) as Node2D
	if spawn:
		player.global_position = spawn.global_position
	pcam.teleport_position.call_deferred()
	_splash = get_node_or_null(^"Splash") as Sprite2D
	_loops.append(Sfx.loop(&"storm", self, Vector2.INF, -2.0))
	_loops.append(Sfx.loop(&"rain", self, Vector2.INF, -8.0))
	Sfx.music(&"")   # pred bojom len búrka, hudba príde s Lou (_start_fight)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(black, "color:a", 0.0, 0.8)
	tw.tween_callback(black.get_parent().queue_free)
	_lou = get_node_or_null(^"BigLou") as BigLou
	_crane = get_node_or_null(^"CraneArm") as Node2D
	if _crane:
		_crane.boom_landed.connect(_on_boom_landed)
		_crane.net_landed.connect(_on_net_landed)
	_spawn_letter()
	if escape_stage > 0:
		_resume_escape()
		return
	if _lou:
		_lou.vest_hit.connect(_on_vest_hit)
		_lou.threw.connect(func(): _say_once(&"dynamite", "DYNAMITE! MOVE YOUR\nFEATHERS, KID!"))
		_lou.stage.connect(_on_lou_stage)
		_lou.died.connect(_on_lou_died)
		_resume_phase()
	for c in get_tree().get_nodes_in_group(&"ship_cover"):
		if c.has_signal(&"broken"):
			c.broken.connect(func(): _say_once(&"cover", "HE'S CHEWIN' UP THE COVER.\nDON'T SIT STILL!"))
	if not margaret_arrived:
		margaret_arrived = true
		_arrive()


## Ricco vyjde dverami kajuty z podpalubia do búrky
func _arrive() -> void:
	player.set_cutscene(true)
	var target: Vector2 = player.global_position
	player.modulate.a = 0.0
	Sfx.play(&"door_open", target, -6.0)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(player, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(player, "global_position", target + Vector2(22, 0), 0.8)
	await tw.finished
	player.set_cutscene(false)
	(get_node(^"Storm") as Node).call(&"strike", 1.0)
	await _wait(1.0)
	ThoughtBox.think(self, ARRIVE)


func _process(delta: float) -> void:
	if player == null:
		return
	# boj sa začne, keď Ricco Lou prvý raz uvidí na krídle mostíka
	if _lou and not _fight and _lou.on_screen() and player.global_position.x > 200.0:
		_start_fight()
	# Lou stojí pri sude whisky – duch poradí
	if _fight and _lou.phase == 3 and _lou.active and not (&"barrel" in _said):
		for b in get_tree().get_nodes_in_group(&"ship_barrel"):
			if absf((b as Node2D).global_position.x - _lou.global_position.x) < 50.0 and _lou.on_screen():
				_say_once(&"barrel", "HE'S STANDIN' BY THE WHISKY.\nLIGHT HIM UP, KID!")
	if _embers:
		_embers.global_position = player.global_position + Vector2(0, 200)
	# Thompson po Lou – pri úteku ho Ricco po smrti dostane späť
	if not has_tommy and TOMMY in player.loadout:
		has_tommy = true
	if _escape:
		_escape_tick(delta)
	# vlna sa občas prevalí cez zábradlie (zatiaľ len efekt – v boji zhodí Ricca, ak nie je za krytom)
	_splash_t -= delta
	if _splash and _splash_t <= 0.0 and not _in_cabin:
		_splash_t = randf_range(6.0, 11.0)
		_wave_over(clampf(player.global_position.x + randf_range(-200.0, 200.0), 40.0, 1200.0))
	_say_busy -= delta
	if _say_busy <= 0.0 and not _say_queue.is_empty():
		_say_busy = 3.4
		bark(_say_queue.pop_front())


## Striekance vody cez zábradlie na mieste x (4 snímky)
func _wave_over(x: float) -> void:
	_splash.global_position = Vector2(x, 0.0)
	_splash.visible = true
	_splash.frame = 0
	Sfx.play(&"wave_crash", Vector2(x, 0.0), -4.0, 0.1)
	var tw := create_tween()
	for f in [1, 2, 3]:
		tw.tween_interval(0.09)
		tw.tween_callback(func(): _splash.frame = f)
	tw.tween_interval(0.12)
	tw.tween_callback(func(): _splash.visible = false)


## Hláška ducha do radu – zaznie, keď dobehne predošlá
func say(t: String) -> void:
	_say_queue.append(t)


# ---------------------------------------------------------------- Big Lou

## Lou nabije Thompson (prvý raz aj s bleskom a hláškou ducha), hore sa ukáže pás jeho zdravia
func _start_fight() -> void:
	_fight = true
	Sfx.music(&"intensity", 0.8)
	_bar = BOSS_BAR.new()
	add_child(_bar)
	_bar.notches.assign([1.0 / 3.0, 2.0 / 3.0])
	_bar.track("BIG LOU FONTANA", _lou)
	_bar._on_health(_lou.health, _lou.max_health)   # pri checkpointe v 2./3. fáze nezačína plný
	_bar._chip = _bar._value
	if lou_revealed:
		_lou.start(false)
		return
	lou_revealed = true
	(get_node(^"Storm") as Node).call(&"strike", 0.9)
	_lou.start(true)
	await _wait(1.2)
	say("THERE HE IS. MY OLD 'FRIEND'.\nTIME TO SETTLE UP, LOU.")


## Udalosti boja od Lou (big_lou.gd → signál stage)
func _on_lou_stage(n: StringName) -> void:
	match n:
		&"to_crane":
			_say_queue.clear()
			say("HE'S RUNNIN' FOR THE CRANE!\nWATCH YOUR HEAD, KID.")
		&"landed":
			_drop(PIZZA, _lou.global_position + Vector2(10, -30), Vector2(-60, -160))
		&"in_booth":
			lou_phase = 2
			_booth_lamp(true)
		&"crane_drop":
			_say_once(&"drop", "CARGO! ROLL OUTTA THE WAY!")
		&"crane_sweep":
			_say_once(&"sweep", "THAT NET'LL FLATTEN YA.\nSLIDE UNDER IT!")
		&"lightning":
			lou_phase = 3
			_lightning()
		&"burnt_up":
			say("THE CRANE'S DONE FOR...\nAND SO IS THIS BOAT!")
		&"charge":
			_say_once(&"charge", "HE'S CHARGIN'! SLIDE\nBETWEEN HIS LEGS, KID!")
		&"dazed":
			_say_once(&"dazed", "HE'S SEEIN' STARS. NOW!")
		&"dying":
			_say_queue.clear()


## Po smrti v boji: Lou začne vo fáze, ktorú už Ricco raz dosiahol (búdka / horiaca paluba)
func _resume_phase() -> void:
	if lou_phase == 2:
		var spot := get_node_or_null(^"BoothSpot") as Node2D
		_lou.setup_phase(2, spot.global_position if spot else Vector2(_booth_x(), 0))
		_booth_lamp(true)
	elif lou_phase == 3:
		_lou.setup_phase(3, Vector2(_booth_x() - 70.0, 0))   # pred stĺpom žeriavu
		if _crane:
			_crane.wrecked()
		var b1 := get_node_or_null(^"Barrel1")
		if b1:
			b1.queue_free()
		_wreck_booth(false)
		_crash_fires(_crane.landing() if _crane else Vector2(717, 0), false)
		_start_burning(false)


## Prechod 2 → 3: blesk do kabíny, rameno sa zrúti, výbuch búdky odhodí Lou, loď začne horieť
func _lightning() -> void:
	await _wait(1.1)   # Lou v panike, žeriav sa sám otáča k zádi
	var cab: Vector2 = _cab()
	_bolt(cab)
	(get_node(^"Storm") as Node).call(&"strike", 1.0)
	Sfx.play(&"lightning_strike", cab, 4.0, 0.0)
	Explosion.spawn(self, cab + Vector2(0, 14), 1.0, 0, 0.0, 24.0)
	var cab_fire := FIRE.new()
	cab_fire.width = 34.0
	cab_fire.big = true
	cab_fire.harmful = false
	cab_fire.z_index = -2
	add_child(cab_fire)
	cab_fire.position = cab + Vector2(0, -22)   # na streche kabíny
	bark("LOOK OUT!")
	await _wait(0.45)
	if _crane:
		_crane.collapse()
	await _wait(0.4)
	# trosky z kabíny padnú do búdky – výbuch vyhodí Lou von
	Explosion.spawn(self, Vector2(_booth_x(), -34), 1.3, 0, 0.0, 30.0)
	_wreck_booth(true)
	_lou.blown(1.0)
	await _wait(0.6)
	_start_burning(true)


## Kabína žeriavu (sem udrie blesk) – kúsok pod čapom ramena (world/ship/crane.gd)
func _cab() -> Vector2:
	return (_crane.get(&"pivot") as Vector2) + Vector2(-6, 26) if _crane else Vector2(874, -184)


## Stred búdky s pákou (marker BoothSpot z tools/build_margaret.gd)
func _booth_x() -> float:
	var spot := get_node_or_null(^"BoothSpot") as Node2D
	return spot.global_position.x if spot else 956.0


## Zubatý blesk z neba do bodu (dve čiary – žiara a biele jadro), zmizne s bliknutím
func _bolt(to: Vector2) -> void:
	var pts := PackedVector2Array()
	var from := Vector2(to.x + randf_range(-60.0, 60.0), -330.0)
	var n: int = 11
	for i in n + 1:
		var k: float = float(i) / n
		var p: Vector2 = from.lerp(to, k)
		if i > 0 and i < n:
			p.x += randf_range(-14.0, 14.0)
		pts.append(p.round())
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for spec in [[4.0, Color(0.55, 0.7, 1.0, 0.8)], [1.0, Color(1, 1, 1, 1)]]:
		var l := Line2D.new()
		l.points = pts
		l.width = spec[0]
		l.default_color = spec[1]
		l.material = m
		l.z_index = 9
		add_child(l)
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 0.2, 0.05)
		tw.tween_property(l, "modulate:a", 1.0, 0.04)
		tw.tween_property(l, "modulate:a", 0.0, 0.3)
		tw.tween_callback(l.queue_free)
	Burst.spawn(self, to, Vector2(0, -1), Color(0.8, 0.9, 1.0), 16, 180.0, Vector2(0, 400), 0.4)


func _booth_lamp(on: bool) -> void:
	var lamp := get_node_or_null(^"BoothLamp") as CanvasItem
	if lamp:
		lamp.visible = on


## Búdka po výbuchu: plech je očadený a nakrivo, páka preč, vnútri horí
func _wreck_booth(fx: bool) -> void:
	_booth_lamp(false)
	var front := get_node_or_null(^"BoothFront") as Node2D
	if front:
		if fx:
			var tw := front.create_tween()
			tw.tween_property(front, "rotation", 0.12, 0.2).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_property(front, "modulate", Color(0.4, 0.36, 0.34), 0.2)
		else:
			front.rotation = 0.12
			front.modulate = Color(0.4, 0.36, 0.34)
	var back := get_node_or_null(^"BoothBack") as CanvasItem
	if back:
		back.modulate = Color(0.45, 0.4, 0.38)
	var lever := get_node_or_null(^"Lever") as CanvasItem
	if lever:
		lever.visible = false
	var f := FIRE.new()
	f.width = 40.0
	f.harmful = false
	f.sound = false
	f.z_index = -6
	add_child(f)
	f.position = Vector2(_booth_x(), 0)


func _on_boom_landed(at: Vector2) -> void:
	Explosion.spawn(self, at, 1.6, 1, 0.0, 44.0)
	_crash_fires(at, true)


## Oheň okolo zrúteného ramena – v strede horí stále (treba ho preskočiť), po bokoch po chvíli zhasne
func _crash_fires(at: Vector2, fresh: bool) -> void:
	var main := FIRE.new()
	main.width = 44.0
	main.big = true
	add_child(main)
	main.position = Vector2(at.x, 0)
	if not fresh:
		return
	for dx in [-58.0, 62.0]:
		var f := FIRE.new()
		f.width = 26.0
		f.lifetime = randf_range(16.0, 22.0)
		add_child(f)
		f.position = Vector2(at.x + dx, 0)


## Sieť sa roztrhla – vysypú sa z nej náboje a kúsok pizze
func _on_net_landed(pos: Vector2) -> void:
	_drop(AMMO, pos + Vector2(-8, -12), Vector2(-70, -180))
	_drop(AMMO, pos + Vector2(8, -12), Vector2(60, -200))
	_drop(PIZZA, pos + Vector2(0, -16), Vector2(randf_range(-30.0, 30.0), -240))


func _drop(scene: PackedScene, at: Vector2, vel: Vector2) -> void:
	var d := scene.instantiate()
	d.set(&"velocity", vel)
	add_child.call_deferred(d)
	d.position = at


## Loď horí: oheň na mostíku, kajute a člne, iskry stúpajú cez celú obrazovku, oranžový nádych, praskanie
func _start_burning(fx: bool) -> void:
	if _burning:
		return
	_burning = true
	# (záchranný čln nehorí – je to cesta von)
	for spec in [[Vector2(1310, -168), 48.0, true, -5], [Vector2(36, -96), 34.0, false, -5], [Vector2(1410, -96), 40.0, true, -5]]:
		var f := FIRE.new()
		f.width = spec[1]
		f.big = spec[2]
		f.harmful = false
		f.sound = false
		f.z_index = spec[3]
		add_child(f)
		f.position = spec[0]
	_loops.append(Sfx.loop(&"fire_loop", self, Vector2.INF, -14.0))
	_embers = CPUParticles2D.new()
	_embers.amount = 48
	_embers.lifetime = 4.0
	_embers.local_coords = false
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(360, 10)
	_embers.direction = Vector2(0.2, -1)
	_embers.spread = 25.0
	_embers.gravity = Vector2(-6, -20)
	_embers.initial_velocity_min = 30.0
	_embers.initial_velocity_max = 70.0
	_embers.color = Color(1.0, 0.6, 0.25, 0.9)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	_embers.color_ramp = ramp
	_embers.z_index = 7
	add_child(_embers)
	_embers.global_position = player.global_position + Vector2(0, 200)
	if not fx:
		_embers.preprocess = 4.0
	# oranžový nádych (pod HUD)
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var tint := ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	tint.material = m
	tint.color = Color(0.22, 0.07, 0.0, 0.0)
	layer.add_child(tint)
	if fx:
		create_tween().tween_property(tint, "color:a", 1.0, 2.5)
	else:
		tint.color.a = 1.0


## Vesta pod sakom – po pár odrazených guľkách duch poradí hlavu
func _on_vest_hit() -> void:
	_vest_hits += 1
	if _vest_hits == 4:
		_say_once(&"vest", "HE'S WEARIN' STEEL UNDER\nTHAT SUIT. GO FOR THE HEAD!")


func _say_once(key: StringName, t: String) -> void:
	if key in _said:
		return
	_said.append(key)
	say(t)


## Lou padol – duch ho odprevadí a pošle Ricca do kajuty Lou pod mostíkom (útek z lode, 1. časť)
func _on_lou_died() -> void:
	if _ended:
		return
	_ended = true
	await _wait(1.6)
	Sfx.music(&"", 3.0)
	_say_queue.clear()
	bark("SO LONG, LOU. YOU SHOULD'A\nSTAYED IN THE FISH BUSINESS.")
	await _wait(3.6)
	escape_stage = 1
	_open_house()
	(get_node(^"Storm") as Node).call(&"strike", 0.8)
	Explosion.spawn(self, Vector2(1400, -100), 0.9, 0, 0.0, 30.0)   # mostík praská
	await _wait(1.0)
	bark("LOU'S CABIN'S UNDER THE BRIDGE.\nLET'S SEE WHAT HE WAS HIDIN'.")


# ---------------------------------------------------------------- útek z lode

## Po smrti počas úteku: Lou už nie je, loď horí, dvere kajuty sú otvorené; po liste rovno odpočet k člnu
func _resume_escape() -> void:
	if _lou:
		_lou.queue_free()
		_lou = null
	if _crane:
		_crane.wrecked()
	var b1 := get_node_or_null(^"Barrel1")
	if b1:
		b1.queue_free()
	_wreck_booth(false)
	_crash_fires(_crane.landing() if _crane else Vector2(717, 0), false)
	_start_burning(false)
	_open_house()
	if escape_stage >= 2:
		_letter.queue_free()
		await _wait(0.6)
		_start_escape(false)


## Spodná nadstavba: pred ľavými dverami sa dá prejsť (pevná časť nadstavby začína až za nimi), dvere svietia, F = vojsť
func _open_house() -> void:
	var house := get_node_or_null(^"House/Shape") as CollisionShape2D
	if house:
		var r := RectangleShape2D.new()
		r.size = Vector2(160, 96)
		house.shape = r
		house.global_position = Vector2(1440, -48)
	var glow := _light_sprite(Vector2(DOOR_X, -40), Color(1.0, 0.7, 0.35, 0.45), 0.5)
	glow.set_script(load("res://world/fx/flicker.gd"))
	var door := InteractSpot.new()
	door.verb = "ENTER"
	door.hint_offset = Vector2(0, -92)
	add_child(door)
	door.global_position = Vector2(DOOR_X, 0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(30, 60)
	cs.shape = rs
	cs.position = Vector2(0, -30)
	door.add_child(cs)
	door.used.connect(_enter_cabin.bind(door))


## List na stole v kajute (lesklý) – F = čítať
func _spawn_letter() -> void:
	var spot := get_node_or_null(^"LetterSpot") as Node2D
	if spot == null:
		return
	_letter = InteractSpot.new()
	_letter.verb = "READ"
	_letter.hint_offset = Vector2(0, -26)
	add_child(_letter)
	_letter.global_position = spot.global_position
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(44, 44)
	cs.shape = r
	cs.position = Vector2(0, 12)
	_letter.add_child(cs)
	var spr := Sprite2D.new()
	spr.texture = LETTER
	spr.position = Vector2(0, -3)
	spr.z_index = 1
	_letter.add_child(spr)
	var shine := _light_sprite(Vector2.ZERO, Color(1.0, 0.85, 0.5, 0.35), 0.25)
	shine.reparent(_letter, false)
	shine.position = Vector2(0, -3)
	var tw := shine.create_tween().set_loops()
	tw.tween_property(shine, "modulate:a", 0.08, 0.7)
	tw.tween_property(shine, "modulate:a", 0.35, 0.7)
	_letter.used.connect(_read_letter)


## Prechod dvermi medzi palubou a kajutou (stmavne, Ricco sa presunie, hranice kamery, búrka stíšená/naplno)
func _go_through(to_cabin: bool) -> void:
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	var black := _fade_rect()
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.4)
	await tw.finished
	Sfx.play(&"door_open" if to_cabin else &"door_close", Vector2.INF, -6.0)
	_in_cabin = to_cabin
	var at := get_node_or_null(^"CabinSpawn" if to_cabin else ^"Spawn12") as Node2D
	player.global_position = at.global_position if at else Vector2(DOOR_X, 0)
	player.facing = 1.0 if to_cabin else -1.0
	_set_limits(CABIN_MAP if to_cabin else SHIP_MAP)
	pcam.teleport_position()
	for n in [^"Rain1", ^"Rain2"]:
		var r := get_node_or_null(n) as CanvasItem
		if r:
			r.visible = not to_cabin
	if _embers:
		_embers.emitting = not to_cabin
	for l in _loops:
		if is_instance_valid(l):
			l.set(&"volume_db", l.get(&"volume_db") + (-12.0 if to_cabin else 12.0))
	if to_cabin:
		_cabin_fx()
	await _wait(0.25)
	var tw2 := create_tween()
	tw2.tween_property(black, "color:a", 0.0, 0.5)
	tw2.tween_callback(black.get_parent().queue_free)
	await tw2.finished
	player.set_cutscene(false)


func _enter_cabin(door: InteractSpot) -> void:
	door.queue_free()
	await _go_through(true)
	var lines: Array[String] = ["Lou's cabin. Smells like fish and cheap cigars."]
	ThoughtBox.think(self, lines)


## Kajuta horí zhora: plamene na palube nad stropom, dym sa valí pod stropom, lampa sa kýve
func _cabin_fx() -> void:
	for spec in [[150.0, 30.0], [330.0, 40.0], [500.0, 26.0]]:
		var f := FIRE.new()
		f.width = spec[1]
		f.harmful = false
		f.sound = false
		f.z_index = -8
		add_child(f)
		f.position = Vector2(spec[0], CABIN_MAP.position.y + 152)
	var smoke := CPUParticles2D.new()
	smoke.amount = 26
	smoke.lifetime = 5.0
	smoke.preprocess = 5.0
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(220, 4)
	smoke.direction = Vector2(1, 0.15)
	smoke.spread = 30.0
	smoke.gravity = Vector2.ZERO
	smoke.initial_velocity_min = 6.0
	smoke.initial_velocity_max = 16.0
	smoke.scale_amount_min = 6.0
	smoke.scale_amount_max = 12.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.2, 0.18, 0.18, 0.0))
	ramp.add_point(0.3, Color(0.2, 0.18, 0.18, 0.35))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.2, 0.18, 0.18, 0.0))
	smoke.color_ramp = ramp
	smoke.z_index = 6
	add_child(smoke)
	smoke.position = Vector2(320, CABIN_MAP.position.y + 178)
	_swing_lamp(0.25)


func _swing_lamp(strength: float) -> void:
	var lamp := get_node_or_null(^"CabinLamp") as Node2D
	if lamp == null:
		return
	var tw := lamp.create_tween()
	for k in 4:
		var a: float = strength * (1.0 - k * 0.22) * (1.0 if k % 2 == 0 else -1.0)
		tw.tween_property(lamp, "rotation", a, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lamp, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_SINE)


## Cliffhanger: list od „M.“ – Lou robil pre niekoho väčšieho v New Yorku. Potom vybuchne kotol a treba utekať.
func _read_letter() -> void:
	if escape_stage >= 2:
		return
	Sfx.play(&"pickup_ammo")
	_letter.queue_free()
	await ReadCard.open(self, LETTER_BIG).closed   # hra stojí, kým si ho Ricco nedočíta (ui/dialog/read_card.gd)
	escape_stage = 2
	var lines: Array[String] = ["'M.' Hotel Majestic, New York.", "So Lou was just the errand boy."]
	await ThoughtBox.think(self, lines).finished
	_ghost_show(true)
	await _wait(0.6)
	bark("SOMEBODY BIG. BIGGER THAN LOU.\nAND HE KNOWS ABOUT YOU, KID.")
	await _wait(3.2)
	# kotol pod nami
	player.shake_timer = 1.2
	player.shake_strength = 5.0
	var boom := Sfx.play(&"explosion", Vector2.INF, 0.0, 0.0)
	if boom:
		boom.set(&"pitch_scale", 0.6)   # hlboko pod palubou
	Sfx.play(&"metal_crash", Vector2.INF, -2.0)
	_swing_lamp(0.6)
	Burst.spawn(self, Vector2(player.global_position.x, CABIN_MAP.position.y + 172), Vector2(0, 1), Color(0.3, 0.28, 0.28, 0.7), 18, 60.0, Vector2(0, 80), 1.2)
	await _wait(0.8)
	bark("THAT'S THE BOILER! SHE'S GONNA\nBLOW - TO THE LIFEBOAT, NOW!")
	await _wait(2.0)
	_ghost_show(false)
	await _go_through(false)
	_start_escape(true)


## Odpočet k člnu: hudba, ukazovateľ času, oheň na ceste, páka pri člne. Loď sa postupne nakláňa.
func _start_escape(first: bool) -> void:
	_escape = true
	_escape_t = ESCAPE_TIME
	_blasts_left = BLASTS.duplicate()
	Sfx.music(&"intensity", 0.5)
	if first:
		Explosion.spawn(self, Vector2(1300, -110), 1.4, 0, 0.0, 30.0)   # kotol trhá mostík
		var big := FIRE.new()
		big.width = 60.0
		big.big = true
		big.harmful = false
		big.sound = false
		big.z_index = -5
		add_child(big)
		big.position = Vector2(1480, -96)
	for spec in ESCAPE_FIRES:
		var f := FIRE.new()
		f.width = spec[1]
		add_child(f)
		f.position = spec[0]
	for r in get_tree().get_nodes_in_group(&"ship_roll"):
		r.create_tween().tween_property(r, "lean_deg", 3.0, ESCAPE_TIME)
	_build_escape_ui()
	var lever := InteractSpot.new()
	lever.verb = "LOWER"
	lever.hint_offset = Vector2(0, -40)
	add_child(lever)
	var spot := get_node_or_null(^"LeverSpot") as Node2D
	lever.global_position = spot.global_position if spot else Vector2(256, 0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(40, 40)
	cs.shape = rs
	cs.position = Vector2(0, -20)
	lever.add_child(cs)
	lever.used.connect(_lower_boat)
	if first:
		await _wait(1.2)
		bark("RUN, KID! THE BOAT'S BY THE STERN!")


## Ukazovateľ času hore v strede (ako pás bossa): nápis, sekundy a červený pás
func _build_escape_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color8(14, 10, 12, 200)
	back.position = Vector2(220, 10)
	back.size = Vector2(200, 22)
	layer.add_child(back)
	_escape_ui = Label.new()
	_escape_ui.add_theme_font_override(&"font", FONT)
	_escape_ui.add_theme_font_size_override(&"font_size", 8)
	_escape_ui.add_theme_color_override(&"font_color", Color8(245, 235, 209))
	_escape_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escape_ui.position = Vector2(220, 11)
	_escape_ui.size = Vector2(200, 10)
	layer.add_child(_escape_ui)
	_escape_bar = ColorRect.new()
	_escape_bar.color = Color8(220, 70, 50)
	_escape_bar.position = Vector2(226, 24)
	_escape_bar.size = Vector2(188, 4)
	layer.add_child(_escape_bar)


func _escape_tick(delta: float) -> void:
	if _boarding or player.get(&"state") == 3:   # 3 = mŕtvy
		return
	_escape_t -= delta
	var secs: int = ceili(maxf(_escape_t, 0.0))
	_escape_ui.text = "GET TO THE LIFEBOAT   0:%02d" % secs
	_escape_bar.size.x = 188.0 * clampf(_escape_t / ESCAPE_TIME, 0.0, 1.0)
	_escape_bar.color = Color8(255, 220, 120) if _escape_t < 10.0 and int(_escape_t * 4.0) % 2 == 0 else Color8(220, 70, 50)
	if _escape_t <= 0.0:
		_escape = false
		_ship_blows()
		return
	# výbuchy za chrbtom, keď Ricco prebehne určité miesta
	if not _blasts_left.is_empty() and player.global_position.x < _blasts_left[0]:
		var x: float = _blasts_left.pop_front()
		Explosion.spawn(self, Vector2(x + 90.0, -6), 1.1, 0, 0.0, 34.0)
	# horiace trámy padajú pred Ricca (najprv tieň), občas sa loď otrasie
	_debris_t -= delta
	if _debris_t <= 0.0:
		_debris_t = randf_range(1.4, 2.4)
		var ahead: float = -1.0 if player.velocity.x <= 0.0 else 1.0
		var off: float = ahead * randf_range(30.0, 130.0) if absf(player.velocity.x) > 20.0 else randf_range(-16.0, 16.0)   # kto stojí, na toho padá
		_drop_debris(clampf(player.global_position.x + off, 140.0, 1330.0))
	_lurch_t -= delta
	if _lurch_t <= 0.0:
		_lurch_t = randf_range(5.0, 8.0)
		player.shake_timer = 0.6
		player.shake_strength = 3.0
		Sfx.play(&"metal_crash", Vector2.INF, -8.0, 0.2)


## Horiaci trám: na zemi sa objaví tieň, o chvíľu z výšky spadne – kto pod ním stojí, dostane zásah; dopadne a chvíľu horí
func _drop_debris(x: float) -> void:
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, -120), Vector2(x, 40), 1))
	var floor_y: float = hit.position.y if not hit.is_empty() else 0.0
	var sh := Sprite2D.new()
	sh.texture = SHADOW
	sh.z_index = 1
	sh.scale = Vector2(0.3, 1.0)
	sh.modulate.a = 0.4
	add_child(sh)
	sh.global_position = Vector2(x, floor_y - 2)
	var grow := sh.create_tween()
	grow.tween_property(sh, "scale", Vector2(0.8, 1.0), 0.75)
	var d := Sprite2D.new()
	d.texture = DEBRIS
	d.z_index = 4
	d.rotation = randf_range(-0.4, 0.4)
	add_child(d)
	var top: float = pcam.get_viewport().get_camera_2d().get_screen_center_position().y - 200.0
	d.global_position = Vector2(x, top)
	var trail := FIRE.new()
	trail.width = 10.0
	trail.harmful = false
	trail.sound = false
	d.add_child(trail)
	var fall := d.create_tween()
	fall.tween_interval(0.75)
	fall.tween_property(d, "global_position:y", floor_y - 5.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(d, "rotation", d.rotation * 0.2, 0.42)
	await fall.finished
	sh.queue_free()
	var at := Vector2(x, floor_y)
	if absf(player.global_position.x - x) < 18.0 and absf(player.global_position.y - floor_y) < 30.0:
		player.take_damage(1, at + Vector2(0, -20))
	Sfx.play(&"crate_break", at, -2.0)
	Burst.spawn(self, at + Vector2(0, -4), Vector2(0, -1), Color(1.0, 0.7, 0.3), 10, 140.0, Vector2(0, 300), 0.5)
	d.queue_free()
	var f := FIRE.new()
	f.width = 16.0
	f.lifetime = 3.0
	add_child(f)
	f.position = at


## Čas vypršal: kotol roztrhá loď – výbuchy okolo Ricca, smrť (znova od dverí kajuty s plným časom)
func _ship_blows() -> void:
	_escape_ui.text = "THE MARGARET BLOWS!"
	for i in 3:
		Explosion.spawn(self, player.global_position + Vector2(randf_range(-60.0, 60.0), -4), 1.6, 0, 0.0, 40.0)
		await _wait(0.18)
	player.set(&"invulnerable_timer", 0.0)
	player.take_damage(99, player.global_position + Vector2(20, 0))


## Páka pri člne: Ricco ju potiahne, skočí do člna a ten sa spustí dolu za bok lode → záver kapitoly na mori
func _lower_boat() -> void:
	if _boarding:
		return
	_boarding = true
	_escape = false
	player.set_cutscene(true)
	var lever := get_node_or_null(^"DavitLever") as Sprite2D
	if lever:
		lever.frame = 1
	Sfx.play(&"chain_rattle", player.global_position, 0.0)
	var boat := get_node_or_null(^"Lifeboat/Boat") as Node2D
	var seat := Vector2(184, -48)
	var from: Vector2 = player.global_position
	player.facing = -1.0
	player.sprite.play(player._hat_anim(&"jump"))
	var jump := create_tween()
	jump.tween_method(func(t: float): player.global_position = from.lerp(seat, t) + Vector2(0, -40.0 * sin(t * PI)), 0.0, 1.0, 0.5)
	await jump.finished
	Sfx.play(&"land", seat, -2.0)
	player.sprite.play(player._hat_anim(&"idle"))
	player.z_index = -3   # spolu s člnom zmizne za trupom
	await _wait(0.3)
	bark("HOLD ONTO YOUR HAT, KID!")
	var drop := create_tween().set_parallel(true)
	drop.tween_property(player, "global_position:y", seat.y + 120.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if boat:
		drop.tween_property(boat, "position:y", boat.position.y + 120.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		for n in [^"Lifeboat/RopeL", ^"Lifeboat/RopeR"]:
			var rope := get_node_or_null(n) as Line2D
			if rope:
				drop.tween_method(func(y: float): rope.set_point_position(1, Vector2(rope.points[1].x, y)), 58.0, 178.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop.finished
	Sfx.play(&"splash", Vector2.INF, 0.0)
	await _wait(0.5)
	# posledný pohľad: Margaret za Riccom vybuchne
	Explosion.spawn(self, Vector2(pcam.get_viewport().get_camera_2d().get_screen_center_position().x + 120.0, -60), 2.2, 0, 0.0, 40.0)
	var white := _fade_rect()
	white.color = Color(1.0, 0.95, 0.85, 0.0)
	var tw := create_tween()
	tw.tween_property(white, "color:a", 1.0, 0.25)
	tw.tween_property(white, "color", Color(0, 0, 0, 1), 1.2)
	await tw.finished
	Sfx.music(&"", 1.0)
	LoadingScreen.go(get_tree(), EPILOGUE, 0.6)
