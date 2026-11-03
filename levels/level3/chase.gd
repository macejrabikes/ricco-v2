extends Level3
## Kapitola III – časť 10: naháňačka za vzducholoďou „IRON“ a boss Police Chief Murphy (koniec kapitoly III).
## Scéna chase.tscn (píše ju _art_src/make_chase_scene.py). Dve časti v jednej mape:
##
## 1. Taxík (checkpoint 33) – Ricco stojí na streche žltého taxíka, ktorý sa ženie po Second Avenue pod nadzemkou za
##    vzducholoďou. Taxík v scéne stojí, ubieha svet okolo neho (Parallax2D.autoscroll, skupina „street_scroll“), kamera
##    stojí (hranice = obrazovka). Zozadu dobiehajú autá so strelcami (chase_car.gd – policajti, ľudia Margaret), vo
##    vedľajšom pruhu predbiehajú policajti na motorkách a strieľajú dozadu (chase_moto.gd). Kryt: strecha taxíka je
##    na rane z oboch strán – pred autami vzadu sa schová na kapote (kabína ho kryje), pred motorkami vpredu na kufri.
##    Šofér auta (trafiť cez čelné sklo) = auto sa vybúra aj so strelcami. Pod stanicami nadzemky sú nízke nosníky
##    (ako nad vlakom – train.gd): kto stojí na streche taxíka, toho zhodia → zísť na kapotu / kufor alebo šmyk.
##    Spadnúť na cestu = zásah a Ricco sa vráti na strechu. Vlny: policajné auto → nosníky a dve motorky →
##    auto ľudí Margaret → policajné auto s motorkou → Queensboro Bridge: zápcha, taxikár nezabrzdí a nabúra.
## 2. Most (checkpointy 34–36) – zápcha na Queensboro Bridge za svitania: Ricco skáče po strechách áut, nákladiakov
##    a električky (rebrík na čele), policajti a mafiáni na ceste aj na strechách, sudy s benzínom na korbe (výbuch
##    zraní aj gangstrov okolo). Na konci policajné zábrany a boss Police Chief Murphy (characters/murphy/murphy.gd)
##    s obrneným vozom (patrol_wagon.gd) – tri fázy, lávka nad pruhmi (rebríky) je úkryt pred nájazdmi voza.
##    Po jeho smrti preletí vzducholoď na východ (Long Island), Ricco skočí z mosta do East River →
##    END OF CHAPTER III → kapitola IV (levels/level4/pier.tscn).
## Checkpointy (Level3.checkpoint): 33 = taxík (chase_wave = dosiahnutá vlna), 34 = most po nehode,
## 35 = strecha nákladiaka v strede mosta, 36 = pred zábranami (boj; murphy_phase = dosiahnutá fáza).
## Godot docs: classes/class_parallax2d, classes/class_tween, classes/class_animatablebody2d, classes/class_canvaslayer

const CAM_TAXI := Rect2i(0, -320, 640, 360)       ## kamera počas jazdy taxíkom (stojí – hranice = obrazovka)
const BRIDGE_MAP := Rect2i(0, -320, 3700, 360)    ## celý most (cesta y = 0)
const ARENA_MAP := Rect2i(2700, -320, 1000, 360)  ## počas boja s Murphym
const TAXI_SPEED := 420.0        ## px/s – tak rýchlo ubieha cesta a letia nosníky
const TAXI_ROOF := -88.0         ## strecha taxíka
const TAXI_SPAN := Vector2(222, 406)   ## taxík (x od–do)
const GIRDER_BOTTOM := -118.0    ## spodok nosníka (30 px nad strechou – ako BEAM_CLEAR v train.gd)
const GIRDER_HALF := 20.0
const GIRDER_DAMAGE := 2
const BRIDGE_IN := 1500.0        ## px – odkiaľ sa most prisunie (potom nehoda)
const BOMB_RADIUS := 70.0        ## px – výbuch sudu na korbe zraní gangstrov v tomto okruhu
const DAWN := Color(1.0, 0.92, 0.86)   ## mafiáni a policajti v rannom svetle
const BOSS_BAR := preload("res://ui/boss_bar.gd")
const GIRDER_TEX := preload("res://levels/level3/art/chase/el_girder.png")
const COP := preload("res://characters/gangster/gangster_coppola.tscn")
const CHAPTER_4 := "res://levels/level4/pier.tscn"

const ARRIVE_CHASE: Array[String] = [
	"Grabbed the first cab on Second Avenue. Told him to follow the zeppelin.",
	"He didn't ask why a penguin was riding on his roof. That's New York for ya.",
]
const END_THOUGHT: Array[String] = [
	"The zeppelin's heading east. Out over the water, toward Long Island.",
	"Margaret Vito. My Margaret's name, on another woman's letters. Time I met her.",
]
const MURPHY_HIT: Array[String] = [
	"THIRTY YEARS ON THE FORCE, AND A BIRD?!",
	"YOU'RE UNDER ARREST! DEAD OR ALIVE!",
	"THE LADY PAYS GOOD, PENGUIN. REAL GOOD!",
]
const SUMMON_LINES: Array[String] = [
	"ALL UNITS! GET THAT BIRD!",
	"MORE MEN! OUT OF THE WAGON!",
	"WHAT AM I PAYIN' YOU FOR?! GO!",
]

var _speed: float = 0.0              ## 1 = taxík ide naplno, 0 = stojí
var _scrollers: Array = []           ## [Parallax2D, pôvodný autoscroll]
var _taxi: Node2D
var _taxi_sprite: Sprite2D
var _cabbie: Sprite2D
var _engine: AudioStreamPlayer2D
var _traffic: Node
var _wheel_d: float = 0.0
var _girders: Array[Node2D] = []
var _girders_on: bool = false
var _girder_t: float = 2.0
var _girder_n: int = 0
var _warn: Label
var _blink: float = 0.0
var _static: Array[Node] = []        ## deti scény pri štarte (zvyšok – náboje, zásobníky – ubieha s cestou)
var _bridge: Node2D
var _bridge_in: bool = false
var _screamed: bool = false
var _skidded: bool = false
var _crashed: bool = false
var _honk_t: float = 4.0
var _murphy: ChiefMurphy
var _wagon: PatrolWagon
var _bar   ## ui/boss_bar.gd
var _fight: bool = false
var _ending: bool = false
var _cops: Array[Node] = []
var _line_cd: float = 0.0
var _said: Array[StringName] = []


func _ready() -> void:
	checkpoint = maxi(checkpoint, 33)
	var black := _setup(CAM_TAXI)
	if black == null:
		return
	player.dark_area = false   # ráno – vidno všetkých
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var rig := g.get(&"rig") as Node2D
		if rig:
			rig.modulate = DAWN
	_taxi = get_node_or_null(^"Taxi") as Node2D
	_taxi_sprite = get_node_or_null(^"Taxi/Sprite") as Sprite2D
	_cabbie = get_node_or_null(^"Taxi/Cabbie") as Sprite2D
	_bridge = get_node_or_null(^"Bridge") as Node2D
	_murphy = get_node_or_null(^"Bridge/Murphy") as ChiefMurphy
	_wagon = get_node_or_null(^"Bridge/Wagon") as PatrolWagon
	for n in get_tree().get_nodes_in_group(&"street_scroll"):
		_scrollers.append([n, n.get(&"autoscroll")])
	for path in [^"PoliceCar1", ^"PoliceCar2", ^"MobCar1"]:
		var car := get_node_or_null(path)
		if car:
			car.connect(&"bumped", _on_bump)
	if _murphy:
		_murphy.stage.connect(_on_murphy_stage)
		_murphy.health_changed.connect(_on_murphy_hurt)
		_murphy.cops_alive = _cops_alive
	for b in get_tree().get_nodes_in_group(&"ship_barrel"):
		var drum := b as Node2D
		drum.connect(&"exploded", func(): _blast_gangsters(drum.global_position))
	_connect(^"Checkpoint35", func():
		checkpoint = maxi(checkpoint, 35)
		_once(&"chase_mid", "HALFWAY ACROSS. KEEP TO THE ROOFTOPS, KID -\nTHE ROAD'S CRAWLIN' WITH BLUE."))
	_connect(^"TrolleyBark", func(): _once(&"chase_trolley", "LADDER ON THE BACK OF THAT TROLLEY.\nUP AND OVER."))
	_connect(^"DrumBark", func(): _once(&"chase_drums", "GASOLINE DRUMS ON THAT FLATBED.\nONE SHOT, AND THE BOYS AROUND 'EM GO UP TOO."))
	_connect(^"BossTrigger", _start_fight)
	_static.assign(get_children())
	_make_warn()
	_traffic = Sfx.loop(&"traffic", self, Vector2.INF, -16.0)
	_fade_in(black)
	if checkpoint >= 34:
		_bridge_state()
		if checkpoint >= 36:
			_start_fight.call_deferred()
		return
	# taxík
	_engine = Sfx.loop(&"car_engine", _taxi, Vector2(150, -40), -6.0, &"SFX") as AudioStreamPlayer2D
	Sfx.music(&"intensity")
	if _bridge:
		_bridge.visible = false
		_bridge.process_mode = Node.PROCESS_MODE_DISABLED
	var far := get_node_or_null(^"BridgeFar") as CanvasItem
	if far:
		far.visible = false
	_run_waves()


func _process(delta: float) -> void:
	if player == null:
		return
	_tick_say(delta)
	_line_cd -= delta
	if not _crashed:
		_update_taxi(delta)
		_update_girders(delta)
		_update_road(delta)
		_update_bridge_in(delta)
	else:
		_honk_t -= delta
		if _honk_t <= 0.0 and not _ending:
			_honk_t = randf_range(2.5, 5.5)
			var at: Vector2 = player.global_position + Vector2(randf_range(-300.0, 300.0), -40.0)
			Sfx.play([&"klaxon", &"klaxon_2", &"klaxon_3"][randi() % 3], at, -12.0, 0.05)


# ---------------------------------------------------------------- 1. taxík

func _update_taxi(delta: float) -> void:
	for s in _scrollers:
		(s[0] as Node).set(&"autoscroll", (s[1] as Vector2) * _speed)
	_wheel_d += TAXI_SPEED * _speed * delta
	var f: int = int(_wheel_d / 7.0) % 4
	for w in get_tree().get_nodes_in_group(&"spin_wheels"):
		(w as Sprite2D).frame = f
	if _engine:
		_engine.pitch_scale = lerpf(0.7, 1.35, _speed) + sin(Time.get_ticks_msec() * 0.003) * 0.03
	if _taxi_sprite:   # taxík sa trasie na kockách
		_taxi_sprite.position.y = -100.0 + (1.0 if fmod(_wheel_d, 46.0) < 3.0 and _speed > 0.3 else 0.0)


## Hlavný scenár jazdy – vlny prenasledovateľov (po smrti pokračuje od dosiahnutej vlny – chase_wave)
func _run_waves() -> void:
	var resume: bool = chase_wave > 0 or chase_arrived
	if not chase_arrived:
		chase_arrived = true
		player.set_cutscene(true)
		await _wait(0.6)
		if _cabbie:
			_speak(_cabbie, "FOLLOW THAT BLIMP?! MISTER, YOU GOT IT!", 40.0)
		await _wait(1.4)
		_accelerate(3.0)
		await _wait(1.2)
		player.set_cutscene(false)
		await ThoughtBox.think(self, ARRIVE_CHASE).finished
	else:
		_accelerate(1.2)
		await _wait(1.0)
	if not resume:
		await _wait(1.5)
	if chase_wave <= 0:
		chase_wave = 0
		Sfx.play(&"siren", Vector2(-100, -60), -8.0, 0.0)
		say("SIRENS! THE WHOLE PRECINCT'S\nOUT FOR US, KID.")
		await _wait(1.5)
		_once(&"chase_cover", "GET DOWN ON THE HOOD - THE CAB'LL\nSTOP THE LEAD. THEN GO FOR THE DRIVER!")
		await _send([^"PoliceCar1"])
		chase_wave = 1
	if chase_wave <= 1:
		_girders_on = true
		await _wait(2.5)
		say("MOTORCYCLE COPS IN THE NEXT LANE!")
		await _send([^"Moto1"], 1.8, [^"Moto2"])
		chase_wave = 2
	_girders_on = true
	if chase_wave <= 2:
		await _wait(1.5)
		say("THAT'S NO POLICE CAR. MARGARET'S BOYS -\nTHEY WANT YOU WORSE THAN THE COPS DO.")
		await _send([^"MobCar1"])
		chase_wave = 3
	if chase_wave <= 3:
		await _wait(1.5)
		say("HERE COMES THE CAVALRY. BOTH LANES!")
		await _send([^"PoliceCar2"], 2.5, [^"Moto3"])
		chase_wave = 4
	for p in [^"PoliceCar1", ^"Moto1", ^"Moto2", ^"MobCar1", ^"PoliceCar2", ^"Moto3"]:
		var n := get_node_or_null(p)
		if n:
			n.queue_free()   # preskočené vlny (po smrti)
	await _wait(2.0)
	_approach_bridge()


## Pustí prenasledovateľov (first hneď, then po delay) a počká, kým všetci odídu alebo sa vybúrajú
func _send(first: Array, delay: float = 0.0, then: Array = []) -> void:
	var all: Array[Node] = []
	for p in first:
		var n := get_node_or_null(p as NodePath)
		if n:
			n.call(&"start")
			all.append(n)
	if not then.is_empty():
		await _wait(delay)
		for p in then:
			var n := get_node_or_null(p as NodePath)
			if n:
				n.call(&"start")
				all.append(n)
	while true:
		var busy: bool = false
		for n in all:
			if is_instance_valid(n) and not bool(n.get(&"done")):
				busy = true
				break
		if not busy:
			return
		await get_tree().process_frame


func _accelerate(t: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_speed", 1.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Auto prenasledovateľov drglo do taxíka – zatrasie ním a Riccom
func _on_bump() -> void:
	Sfx.play(&"metal_crash", Vector2(220, -40), -14.0, 0.15)
	player.shake_timer = 0.2
	player.shake_strength = 3.0
	if _taxi_sprite:
		var tw := create_tween()
		tw.tween_property(_taxi_sprite, "rotation", -0.03, 0.06)
		tw.tween_property(_taxi_sprite, "rotation", 0.0, 0.2)
	var p: Vector2 = player.global_position
	if p.x > TAXI_SPAN.x and p.x < TAXI_SPAN.y and p.y < -40.0 and player.state == 0 and player.is_on_floor():
		player.velocity += Vector2(90.0, -150.0)
	_said_once(&"bump", "HE'S RAMMIN' US! HOLD ON!")


## Spadol na cestu – zásah a späť na strechu taxíka; náboje a zásobníky na ceste ubiehajú s ňou
func _update_road(delta: float) -> void:
	var p: Vector2 = player.global_position
	if player.state != 3 and p.y > -4.0 and player.is_on_floor() and not player.in_cutscene:
		player.take_damage(1, Vector2.INF)
		if player.state != 3:
			player.global_position = Vector2(300, TAXI_ROOF)
			player.velocity = Vector2.ZERO
			Sfx.play(&"body_thud", Vector2.INF, -2.0)
			_once(&"chase_road", "STAY ON THE CAB, KID!\nTHAT ROAD'S DOIN' FORTY.")
	var v: float = TAXI_SPEED * _speed * delta
	for c in get_children():
		var n := c as Node2D
		if n == null or n in _static or n == player or n in _girders:
			continue
		if n.global_position.y > -12.0:
			n.position.x -= v
			if n.global_position.x < -120.0:
				n.queue_free()


# ---------------------------------------------------------------- nosníky pod stanicami nadzemky

func _update_girders(delta: float) -> void:
	var p: Vector2 = player.global_position
	if _girders_on and not _bridge_in and _speed > 0.5 and player.state != 3:
		_girder_t -= delta
		if _girder_t <= 0.0:
			_spawn_girder()
	var ahead: Node2D = null
	for g in _girders.duplicate():
		g.position.x -= TAXI_SPEED * _speed * delta
		_girder_hits(g, p)
		if g.position.x < -80.0:
			_girders.erase(g)
			g.queue_free()
		elif g.position.x > 644.0 and (ahead == null or g.position.x < ahead.position.x):
			ahead = g
	_blink += delta
	_warn.visible = ahead != null and fmod(_blink, 0.36) < 0.22
	if ahead:
		_warn.position = Vector2(624.0, GIRDER_BOTTOM - CAM_TAXI.position.y - 22.0).round()


func _spawn_girder() -> void:
	_girder_n += 1
	_girder_t = randf_range(3.4, 5.2)
	var g := Node2D.new()
	g.position = Vector2(640.0 + 320.0, GIRDER_BOTTOM)   # poloha = stred spodku nosníka
	g.z_index = 6
	var s := Sprite2D.new()
	s.texture = GIRDER_TEX
	s.centered = false
	s.position = Vector2(-20, -300)
	g.add_child(s)
	g.set_meta(&"whoosh", false)
	add_child(g)
	_girders.append(g)
	Sfx.play(&"train_bell", Vector2.INF, -14.0, 0.03)
	if _girder_n == 1:
		_once(&"chase_girder", "LOW GIRDER UNDER THE EL! OFF THE ROOF -\nHOOD, TRUNK, OR SLIDE (%s)!" % KeyBindings.short(&"slide"))


func _girder_hits(g: Node2D, p: Vector2) -> void:
	var dx: float = absf(p.x - g.position.x)
	if not g.get_meta(&"whoosh") and dx < 60.0:
		g.set_meta(&"whoosh", true)
		Sfx.play(&"beam_whoosh", g.position, -4.0)
	if player.state != 3 and dx < GIRDER_HALF + 8.0 and p.y - _player_height() < GIRDER_BOTTOM and p.y > GIRDER_BOTTOM - 260.0:
		if player.invulnerable_timer <= 0.0:
			player.take_damage(GIRDER_DAMAGE, Vector2(g.position.x + 30.0, p.y - 20.0))
			Sfx.play(&"beam_clang", g.position, 0.0)
			_once(&"chase_girder_hit", "TOLD YA. LOW STEEL.")


func _player_height() -> float:
	if player.state == 4:   # SLIDE
		return 24.0
	return 22.0 if player.ducked else 38.0


func _make_warn() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_warn = Label.new()
	_warn.text = "!"
	_warn.add_theme_font_override(&"font", FONT)
	_warn.add_theme_font_size_override(&"font_size", 16)
	_warn.add_theme_color_override(&"font_color", Color8(255, 80, 60))
	_warn.add_theme_color_override(&"font_outline_color", Color8(20, 6, 6))
	_warn.add_theme_constant_override(&"outline_size", 6)
	_warn.visible = false
	layer.add_child(_warn)


# ---------------------------------------------------------------- Queensboro Bridge a nehoda

func _approach_bridge() -> void:
	_girders_on = false
	if _bridge == null:
		return
	say("QUEENSBORO BRIDGE DEAD AHEAD...\nAND IT'S JAMMED SOLID!")
	_bridge.position.x = BRIDGE_IN
	_bridge.visible = true
	_bridge_in = true


## Most sa prisúva rýchlosťou cesty; taxikár zbadá zápchu, nezabrzdí a narazí do nákladiaka
func _update_bridge_in(delta: float) -> void:
	if not _bridge_in:
		return
	_bridge.position.x -= TAXI_SPEED * _speed * delta
	if not _screamed and _bridge.position.x < 950.0:
		_screamed = true
		if _cabbie:
			_cabbie.frame = 1
			_speak(_cabbie, "THE BRAKES! I GOT NO BRAKES!", 40.0)
	if not _skidded and _bridge.position.x < 520.0:
		_skidded = true
		Sfx.play(&"brakes", Vector2.INF, -2.0, 0.0)
		Sfx.play(&"tire_skid", Vector2.INF, 0.0, 0.0)
		_said_once(&"brace", "BRACE YOURSELF, KID!")
	if _bridge.position.x <= 0.0:
		_crash()


func _crash() -> void:
	_bridge_in = false
	_bridge.position.x = 0.0
	Sfx.play(&"metal_crash", Vector2.INF, 2.0, 0.0)
	Sfx.play(&"glass_break", Vector2.INF, 0.0, 0.05)
	Sfx.play(&"klaxon_3", Vector2.INF, -4.0, 0.0)
	var flash := _fade_rect()
	flash.color = Color(1.0, 0.96, 0.88, 0.95)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.6)
	tw.tween_callback(flash.get_parent().queue_free)
	player.shake_timer = 0.5
	player.shake_strength = 7.0
	if _taxi:
		Burst.spawn(self, _taxi.global_position + Vector2(176, -40), Vector2(1, -0.6), Color(1.0, 0.85, 0.45), 18, 160.0)
		Burst.spawn(self, _taxi.global_position + Vector2(176, -50), Vector2(0, -1), Color(0.6, 0.58, 0.6, 0.6), 14, 40.0, Vector2(0, -40), 1.8)
	# Ricca to vystrelí dopredu na nákladiak (ak bol na taxíku)
	var p: Vector2 = player.global_position
	if player.state != 3 and p.x > TAXI_SPAN.x - 30.0 and p.x < TAXI_SPAN.y and not player.in_cutscene:
		player.velocity = Vector2(240.0, -280.0)
	_bridge_state()
	checkpoint = maxi(checkpoint, 34)
	chase_wave = 5
	await _wait(1.0)
	if _cabbie:
		_speak(_cabbie, "THAT'S A DOLLAR TEN, PAL!", 40.0)
	await _wait(2.4)
	if _cabbie:
		_cabbie.frame = 2   # utiekol
	say("YOU OK, KID? GOOD. THE BLIMP'S\nOVER THE BRIDGE. ACROSS THE ROOFS - GO!")


## Svet po nehode (aj po smrti na moste): ulica zmizne, most stojí, kamera ide za Riccom
func _bridge_state() -> void:
	_crashed = true
	_speed = 0.0
	for s in _scrollers:
		(s[0] as CanvasItem).visible = false
	for g in _girders:
		g.queue_free()
	_girders.clear()
	if _warn:
		_warn.visible = false
	if _engine:
		_engine.queue_free()
		_engine = null
	if _traffic:
		_traffic.set(&"volume_db", -22.0)
	if _taxi_sprite:
		_taxi_sprite.frame = 1
		_taxi_sprite.position.y = -100.0
	if _cabbie and checkpoint >= 34:
		_cabbie.frame = 2
	if _bridge:
		_bridge.position.x = 0.0
		_bridge.visible = true
		_bridge.process_mode = Node.PROCESS_MODE_INHERIT
	var far_static := get_node_or_null(^"Bridge/FarStatic") as CanvasItem
	if far_static:
		far_static.visible = false
	var far := get_node_or_null(^"BridgeFar") as CanvasItem
	if far:
		far.visible = true
	var wall := get_node_or_null(^"TaxiWallR/Shape") as CollisionShape2D
	if wall:
		wall.set_deferred(&"disabled", true)
	_set_limits(BRIDGE_MAP)
	Sfx.music(&"desolation", 2.0)
	for p in [^"PoliceCar1", ^"Moto1", ^"Moto2", ^"MobCar1", ^"PoliceCar2", ^"Moto3"]:
		var n := get_node_or_null(p)
		if n and not bool(n.get(&"active")):
			n.queue_free()


## Výbuch sudu s benzínom zraní gangstrov okolo (explosion.gd zraní len Ricca a bossa)
func _blast_gangsters(at: Vector2) -> void:
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var e := g as Node2D
		if e == null or e.is_in_group(&"boss") or int(e.get(&"state")) == 10:
			continue
		if (e.global_position + Vector2(0, -30)).distance_to(at) < BOMB_RADIUS + 30.0:
			e.call(&"take_hit", 5.0, Vector2(signf(e.global_position.x - at.x), -0.6))
	_said_once(&"boom", "HA! THAT'S HOW YOU CLEAR TRAFFIC.")


# ---------------------------------------------------------------- Police Chief Murphy

func _start_fight() -> void:
	if _fight or _murphy == null or _wagon == null or not _crashed:
		return
	_fight = true
	checkpoint = maxi(checkpoint, 36)
	_set_limits(ARENA_MAP)
	_bar = BOSS_BAR.new()
	add_child(_bar)
	_bar.notches.assign([1.0 / 3.0, 2.0 / 3.0])
	if murphy_phase <= 0:
		murphy_phase = 1
		if not murphy_revealed:
			murphy_revealed = true
			Sfx.music(&"", 1.0)
			_speak(_murphy, "THIS IS CHIEF MURPHY! YOU'RE UNDER ARREST, BIRD!", 92.0)
			await _wait(2.6)
			say("THE CHIEF HIMSELF. ON MARGARET'S\nPAYROLL, I'D BET MY HAT ON IT.")
			await _wait(1.6)
	Sfx.music(&"intensity", 0.8)
	_bar.track("CHIEF MURPHY", _murphy)
	_murphy.start(murphy_phase)
	_bar._on_health(_murphy.health, float(_murphy.max_health))   # po smrti v 2./3. fáze nezačína plný
	_bar._chip = _bar._value
	if murphy_phase == 1:
		_said_once(&"murphy_duck", "HE DUCKS BEHIND THAT RAIL - WAIT\nTILL HE POPS UP, THEN LET HIM HAVE IT.")


func _cops_alive() -> int:
	var n: int = 0
	for c in _cops:
		if is_instance_valid(c) and int(c.get(&"state")) != 10:
			n += 1
	return n


func _on_murphy_hurt(_h: float, _m: float) -> void:
	if _line_cd <= 0.0 and randf() < 0.25 and is_instance_valid(_murphy) and _murphy.active and _murphy.visible:
		_line_cd = 6.0
		_speak(_murphy, MURPHY_HIT[randi() % MURPHY_HIT.size()], 92.0)


## Udalosti boja od Murphyho (murphy.gd → signál stage)
func _on_murphy_stage(n: StringName) -> void:
	match n:
		&"summon":
			_speak(_murphy, SUMMON_LINES[randi() % SUMMON_LINES.size()], 92.0)
			_summon_cop()
		&"jump_down":
			murphy_phase = 2
			_say_queue.clear()
			_speak(_murphy, "ALL RIGHT! YOU WANT IT THE HARD WAY!", 92.0)
		&"landed":
			_said_once(&"murphy_drum", "WATCH THAT DRUM MAG. WHEN HE\nSWAPS IT, THAT'S YOUR OPENING.")
		&"reload":
			_said_once(&"murphy_reload", "HE'S CHANGIN' DRUMS! NOW, KID!")
		&"kick":
			_said_once(&"murphy_kick", "OLD FLATFOOT KICKS LIKE A MULE.\nDON'T CROWD HIM.")
		&"to_wagon":
			murphy_phase = 3
			_say_queue.clear()
			_speak(_murphy, "THAT DOES IT! I'LL RUN YOU DOWN MYSELF!", 92.0)
			say("HE'S GOIN' FOR THE WAGON!")
		&"telegraph":
			_said_once(&"murphy_ram", "HEADLIGHTS! OFF THE ROAD - UP ON THE\nCATWALK, OR BACK BEHIND THE BARRICADES!")
		&"dazed":
			_said_once(&"murphy_dazed", "HE'S SEEIN' STARS! LET HIM HAVE IT!")
			_said_once(&"murphy_window", "AND WHEN HE'S DRIVIN' - SHOOT\nTHROUGH THE WINDSHIELD.")
		&"dying":
			_murphy_dies()


## Posila zo zadných dverí voza (len policajt s revolverom – Murphy volá megafónom)
func _summon_cop() -> void:
	if _wagon == null or _ending:
		return
	_wagon.open_doors()
	await _wait(0.45)
	if _ending or _wagon == null:
		return
	var c := COP.instantiate()
	c.set(&"kind", "cop")
	c.set(&"weapon", REVOLVER)
	c.set(&"pellets", 1)
	c.set(&"spread_deg", 3.0)
	c.set(&"bullet_lifetime", 1.4)
	c.set(&"preferred_range", 0.0)
	c.set(&"walk_speed", 44.0)
	c.set(&"sight_range", 340.0)
	c.set(&"start_facing", -1.0)
	c.set(&"respawn_time", 0.0)
	c.set(&"max_health", 2)
	c.position = Vector2(_wagon.rear_x() - _wagon.facing * 16.0, 0.0)
	_bridge.add_child(c)
	var rig := c.get(&"rig") as Node2D
	if rig:
		rig.modulate = DAWN
	_cops.append(c)
	await _wait(0.7)
	if _wagon and is_instance_valid(_wagon):
		_wagon.close_doors()


# ---------------------------------------------------------------- koniec kapitoly III

func _murphy_dies() -> void:
	if _ending:
		return
	_ending = true
	_say_queue.clear()
	Sfx.music(&"", 2.5)
	for g in get_tree().get_nodes_in_group(&"enemies"):   # ostatní policajti to vzdajú
		if g != _murphy and int(g.get(&"state")) != 10:
			g.set(&"passive", true)
			g.set(&"state", 1)   # Gangster.State.IDLE
			var l := g.get(&"laser") as CanvasItem
			if l:
				l.visible = false
	var m := _murphy
	await _wait(1.4)
	_speak(m, "SHE... OWNS THIS WHOLE TOWN, BIRD...", 30.0)
	await _wait(3.0)
	# vzducholoď preletí nad mostom na východ
	var ship := get_node_or_null(^"Sky/Airship") as Sprite2D
	Sfx.play(&"airship_drone", Vector2.INF, -6.0, 0.0, &"Ambience")
	if ship:   # z miesta, kde visela celú cestu, odletí doprava (na východ) a trochu sa priblíži
		var tw := create_tween().set_parallel(true)
		tw.tween_property(ship, "position", Vector2(820, 24), 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(ship, "scale", Vector2(1.5, 1.5), 12.0)
	await _wait(1.2)
	await ThoughtBox.think(self, END_THOUGHT).finished
	bark("THAT BLIMP'S HEADED FOR LONG ISLAND.\nSHE'S GOIN' HOME, KID.")
	await _wait(3.6)
	bark("COPS'LL SEAL THIS BRIDGE ANY MINUTE.\nONLY ONE WAY OFF - STRAIGHT DOWN.")
	await _wait(3.6)
	bark("YOU'RE A PENGUIN, KID.\nYOU'LL BE FINE.")
	await _wait(2.8)
	_dive()


## Ricco skočí z mosta do East River (šípkou dolu pred mostovkou), šplech, titulky
func _dive() -> void:
	if _leaving:
		return
	_leaving = true
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"jump"))
	Sfx.play(&"jump", Vector2.INF, -4.0)
	player.z_index = 20
	var start: Vector2 = player.global_position
	var tw := create_tween()
	tw.tween_property(player, "global_position", start + Vector2(16, -40), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): player.sprite.play(player._hat_anim(&"fall")))
	tw.tween_property(player, "global_position", start + Vector2(30, 420), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(player, "rotation", 1.4, 0.9)
	await tw.finished
	Sfx.play(&"splash", Vector2.INF, 2.0, 0.0)
	await _wait(0.4)
	var black := _fade_rect()
	var title := _title_label("END OF CHAPTER III", 24, Color8(245, 235, 209), -14)
	var sub := _title_label("THE BIG APPLE", 8, Color8(150, 230, 245), 14)
	for l in [title, sub]:
		black.add_child(l)
	var t2 := create_tween()
	t2.tween_property(black, "color:a", 1.0, 1.2)
	t2.tween_property(title, "modulate:a", 1.0, 0.8)
	t2.tween_property(sub, "modulate:a", 1.0, 0.6)
	t2.tween_interval(3.0)
	t2.tween_property(title, "modulate:a", 0.0, 0.6)
	t2.parallel().tween_property(sub, "modulate:a", 0.0, 0.6)
	await t2.finished
	Level3.reset()
	Level4.reset()
	LoadingScreen.go(get_tree(), CHAPTER_4, 0.6)


## Hláška len raz za tento pokus (po smrti znova – na rozdiel od _once)
func _said_once(key: StringName, t: String) -> void:
	if key in _said:
		return
	_said.append(key)
	say(t)
