extends Level2
## Kapitola II – Wharf Rats, finále: paluba S.S. Margaret v búrke (návrh A + žeriav). Sem vedie pás z mraziarne do podpalubia.
## Časti (tools/build_margaret.gd): kajuta na korme (Ricco vyjde z podpalubia) → záchranný čln (plošina) → debny a sudy
##   (kryt) → nákladný žeriav so sieťou → krídlo mostíka (Big Lou) → nadstavba s mostíkom → prova.
## Bossfight s Big Lou (characters/lou/big_lou.gd): keď ho Ricco prvý raz uvidí na krídle mostíka, Lou nabije Thompson
##   a hore sa ukáže pás jeho zdravia (ui/boss_bar.gd, značky = tri fázy):
##   1. krídlo mostíka → zoskočí a beží do búdky (kúsok pizze) → 2. žeriav (world/ship/crane.gd): náklad a švih sieťou →
##   blesk do žeriavu, rameno sa zrúti na sud, výbuch búdky odhodí Lou, loď začne horieť → 3. pripálený Lou na palube.
##   Lou o réžii dáva vedieť signálom stage (_on_lou_stage) – tu sú hlášky ducha, blesk, požiar a pickupy.
##   Po Louovej smrti zatiaľ TO BE CONTINUED (únik z horiacej lode a list v kajute prídu v ďalšom kroku).
## Checkpointy: Level2.checkpoint 11 = paluba lode, Level2.lou_phase = fáza boja (po smrti začne v búdke / na horiacej palube).
## Scénu generuje tools/build_margaret.gd. Godot docs: classes/class_tween, classes/class_parallax2d, classes/class_cpuparticles2d

const SHIP_MAP := Rect2i(0, -304, 1568, 360)     ## hranice kamery (px) – paluba na y = 0, dole kúsok trupu a vlny
const LUPARA := preload("res://weapons/lupara/lupara.tres")
const BOSS_BAR := preload("res://ui/boss_bar.gd")
const FIRE := preload("res://world/ship/deck_fire.gd")
const PIZZA := preload("res://props/food/food_pickup.tscn")   ## jedlo (striedajú sa druhy) – Ricco ho vezme do zásoby
const AMMO := preload("res://props/ammo/ammo_pickup.tscn")

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
	player.set_loadout(list)
	player.focus.unlocked = true
	player.dark_area = false   # paluba je osvetlená (okná mostíka, lampy) – v boji nie je kde sa schovať do tmy
	var spawn := get_node_or_null(NodePath("Spawn%d" % checkpoint)) as Node2D
	if spawn:
		player.global_position = spawn.global_position
	pcam.teleport_position.call_deferred()
	_splash = get_node_or_null(^"Splash") as Sprite2D
	Sfx.loop(&"storm", self, Vector2.INF, -2.0)
	Sfx.loop(&"rain", self, Vector2.INF, -8.0)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(black, "color:a", 0.0, 0.8)
	tw.tween_callback(black.get_parent().queue_free)
	_lou = get_node_or_null(^"BigLou") as BigLou
	_crane = get_node_or_null(^"CraneArm") as Node2D
	if _crane:
		_crane.boom_landed.connect(_on_boom_landed)
		_crane.net_landed.connect(_on_net_landed)
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
	# vlna sa občas prevalí cez zábradlie (zatiaľ len efekt – v boji zhodí Ricca, ak nie je za krytom)
	_splash_t -= delta
	if _splash and _splash_t <= 0.0:
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
	for spec in [[Vector2(1310, -168), 48.0, true, -5], [Vector2(186, -60), 30.0, false, -3], [Vector2(36, -96), 34.0, false, -5],
			[Vector2(1410, -96), 40.0, true, -5]]:
		var f := FIRE.new()
		f.width = spec[1]
		f.big = spec[2]
		f.harmful = false
		f.sound = false
		f.z_index = spec[3]
		add_child(f)
		f.position = spec[0]
	Sfx.loop(&"fire_loop", self, Vector2.INF, -14.0)
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


## Lou padol. Zatiaľ koniec – fázy 2 a 3, únik z horiacej lode a list v kajute prídu v ďalšom kroku.
func _on_lou_died() -> void:
	if _ended:
		return
	_ended = true
	await _wait(1.6)
	_say_queue.clear()
	bark("SO LONG, LOU. YOU SHOULD'A\nSTAYED IN THE FISH BUSINESS.")
	await _wait(3.4)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var l := Label.new()
	l.text = "TO BE CONTINUED..."
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", 16)
	l.add_theme_color_override(&"font_color", Color8(245, 235, 209))
	l.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	l.add_theme_constant_override(&"outline_size", 6)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0
	layer.add_child(l)
	create_tween().tween_property(l, "modulate:a", 1.0, 0.8)
