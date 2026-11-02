extends Level2
## Kapitola II – Wharf Rats, finále: paluba S.S. Margaret v búrke. Sem vedie pás z mraziarne do podpalubia.
## Časti (tools/build_margaret.gd): kajuta na korme (Ricco vyjde z podpalubia) → záchranný čln (plošina) → pár debien a sudov
##   → vysoký nákladný žeriav so sieťou → nákladný poklop (poskoci) → dlhé krídlo mostíka (Big Lou) → nadstavba → prova.
## Bossfight s Big Lou (characters/lou/big_lou.gd) – kamera sa oddiali (FIGHT_ZOOM), aby bolo vidno palubu aj krídlo:
##   0. poskoci: Lou z krídla ukazuje na Ricca, z poklopu a z kajuty na korme vylezú jeho chlapi (dve vlny, _henchmen)
##   1. mostík: Lou sa nasere – pás zdravia (ui/boss_bar.gd); páka žeriavu (debny = dočasný kryt) + Thompson + dynamit,
##      ktorý Ricco hodí späť (F); tri dynamity zničia krídlo (_break_wing) – Lou spadne na palubu, loď začne horieť
##   2. paluba: žeriav bez obsluhy udrie blesk (_crane_down), rameno sa zrúti na palubu a zúži arénu (ArenaWall)
##   Lou o réžii dáva vedieť signálom stage (_on_lou_stage) – tu sú hlášky ducha, blesk, požiar a pickupy.
## Útek z lode (Level2.escape_stage): Lou padol → duch pošle Ricca do kajuty Lou pod mostíkom (dvere v nadstavbe, F) →
##   v kajute (pod mapou, vlastné hranice kamery) list od „M.“ z hotela Majestic v New Yorku (ReadCard) → kotol vybuchne →
##   späť na palubu: na čas k záchrannému člnu (oheň, padajúce horiace trámy, výbuchy, loď sa nakláňa) → páka (F) spustí čln
##   → záver kapitoly na mori (epilogue.tscn). Keď čas vyprší, loď vybuchne (smrť → znova od dverí kajuty).
## Checkpointy: Level2.checkpoint 11 = paluba lode, Level2.lou_phase = fáza boja (0 poskoci, 1 mostík, 3 paluba),
##   Level2.escape_stage 1–2 = po boji (Ricco začne pri dverách kajuty – Spawn12).
## Scénu generuje tools/build_margaret.gd. Godot docs: classes/class_tween, classes/class_parallax2d, classes/class_cpuparticles2d

const SHIP_MAP := Rect2i(0, -420, 2080, 560)     ## hranice kamery (px) – paluba na y = 0, dole vysoký trup a vlny
const FIGHT_ZOOM := 0.8                          ## kamera v boji (800×450 sveta) – vidno palubu aj krídlo mostíka
const FIGHT_OFFSET := -112.0                     ## px – stred kamery nad Riccom v boji (normálne −20, characters/ricco/ricco.tscn)
const LOU_BIAS := 230.0                          ## px – najviac o toľko sa kamera v boji posunie k Lou na krídle
const FIGHT_START_X := 420.0                     ## px – tu Lou zbadá Ricca a pošle naňho poskokov
const BRIDGE_X := 1504.0                         ## px – ľavá stena nadstavby (tools/build_margaret.gd: BRIDGE_X * 16)
const HOUSE_W := 432.0                           ## px – šírka nadstavby (tools/build_margaret.gd: HOUSE_W)
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
const DOOR_X := 1615.0                        ## dvere do kajuty v spodnej nadstavbe (Spawn12)
const ESCAPE_TIME := 46.0                     ## s na útek k člnu, potom loď vybuchne
const ESCAPE_FIRES := [[Vector2(1420, 0), 20.0], [Vector2(1060, 0), 18.0], [Vector2(545, -26), 16.0], [Vector2(420, 0), 16.0]]
const BLASTS := [1300.0, 960.0, 640.0, 300.0]  ## keď Ricco prebehne toto x, kúsok za ním niečo vybuchne
## Poskoci v dvoch vlnách: [scéna, odkiaľ ("hatch" = nákladný poklop, "stern" = dvere kajuty na korme), oneskorenie s]
const WAVES := [
	[["gangster_tommy", "hatch", 0.0], ["gangster_coppola", "stern", 1.2], ["gangster_tommy", "hatch", 2.0]],
	[["gangster_slugger", "hatch", 0.0], ["gangster_coppola", "hatch", 1.4], ["gangster_tommy", "stern", 2.4]],
]

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
var _crane_due: bool = false   ## Lou spadol – žeriav sa zrúti, keď sú obaja za miestom dopadu ramena
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
var _henchmen_left: Array[Node] = []
var _wave: int = -1
var _wing_dmg: int = 0


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
		_lou.threw.connect(_on_lou_threw)
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
	# boj sa začne, keď Ricco vyjde spoza kajuty na palubu (Lou ho zbadá z krídla)
	if _lou and not _fight and player.global_position.x > FIGHT_START_X:
		_start_fight()
	if _wave >= 0:
		_henchmen_tick()
	# kým je Lou hore na krídle, kamera sa posunie k nemu (Ricco ostane na obrazovke) – je vidno, odkiaľ strieľa
	var bias_x: float = 0.0
	if _fight and _lou and _lou.phase <= 1 and not _ended:
		bias_x = clampf((_lou.global_position.x - player.global_position.x) * 0.5, -LOU_BIAS, LOU_BIAS)
	player.camera_bias.x = lerpf(player.camera_bias.x, bias_x, 1.0 - exp(-2.5 * delta))
	# Lou stojí pri sude whisky – duch poradí
	if _fight and _lou and _lou.phase == 3 and _lou.active and not (&"barrel" in _said):
		for b in get_tree().get_nodes_in_group(&"ship_barrel"):
			if absf((b as Node2D).global_position.x - _lou.global_position.x) < 50.0 and _lou.on_screen():
				_say_once(&"barrel", "HE'S STANDIN' BY THE WHISKY.\nLIGHT HIM UP, KID!")
	# žeriav bez obsluhy sa zrúti, keď sú Ricco aj Lou za miestom dopadu ramena (aréna sa zúži, nikto neostane odrezaný)
	if _crane_due and _crane and _lou and _lou.active:
		var edge: float = _crane.landing().x + 50.0
		if player.global_position.x > edge and _lou.global_position.x > edge:
			_crane_due = false
			_crane_down()
	if _embers:
		_embers.global_position = player.global_position + Vector2(0, 200)
	# Thompson po Lou – pri úteku ho Ricco po smrti dostane späť
	if not has_tommy and TOMMY in player.loadout:
		has_tommy = true
	if _escape:
		_escape_tick(delta)
	# vlna sa občas prevalí cez zábradlie (len efekt)
	_splash_t -= delta
	if _splash and _splash_t <= 0.0 and not _in_cabin:
		_splash_t = randf_range(6.0, 11.0)
		_wave_over(clampf(player.global_position.x + randf_range(-200.0, 200.0), 40.0, BRIDGE_X - 40.0))
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


## Kamera v boji oddialená (z = 1 normálne, FIGHT_ZOOM v boji) a posunutá vyššie, aby bolo vidno krídlo mostíka aj rameno
## žeriavu – paluba je potom v dolnej štvrtine obrazovky, pod ňou ešte čiara vody. Godot docs: classes/class_camera2d (zoom)
func _zoom_to(z: float, t: float = 1.2) -> void:
	if pcam == null:
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pcam, "zoom", Vector2(z, z), t)
	tw.tween_property(player, "camera_bias:y", FIGHT_OFFSET if z < 1.0 else -20.0, t)


# ---------------------------------------------------------------- Big Lou

## Lou zbadá Ricca: hudba, kamera sa oddiali. Prvý raz (lou_phase 0) pošle poskokov, po smrti v boji ide rovno na vec.
func _start_fight() -> void:
	_fight = true
	Sfx.music(&"intensity", 0.8)
	_zoom_to(FIGHT_ZOOM)
	if lou_phase >= 1:
		_show_bar()
		_lou.start(false)
		return
	_lou.command()
	if not lou_revealed:
		lou_revealed = true
		(get_node(^"Storm") as Node).call(&"strike", 0.9)
		await _wait(1.0)
		say("THERE HE IS. MY OLD 'FRIEND'.\nAND HE BROUGHT COMPANY.")
	Sfx.play(&"whistle", _lou.global_position + Vector2(0, -60), -2.0)   # Lou hvizdne na chlapov
	await _wait(0.8)
	_next_wave()


## Pás zdravia Lou hore na obrazovke (značka na tretine = pád z mostíka)
func _show_bar() -> void:
	if _bar:
		return
	_bar = BOSS_BAR.new()
	add_child(_bar)
	_bar.notches.assign([1.0 / 3.0])
	_bar.track("BIG LOU FONTANA", _lou)
	_bar._on_health(_lou.health, _lou.max_health)   # pri checkpointe na palube nezačína plný
	_bar._chip = _bar._value


# ---------------------------------------------------------------- 0. fáza: poskoci

func _next_wave() -> void:
	_wave += 1
	if _wave >= WAVES.size():
		_wave = -1
		_henchmen_done()
		return
	_henchmen_left.clear()
	for spec in WAVES[_wave]:
		_henchman(spec[0], spec[1], spec[2])
	if _wave == 1:
		say("MORE OF 'EM COMIN' OUTTA\nTHE HOLD. STAY SHARP!")


## Poskok vylezie z nákladného poklopu (zdola) alebo vyjde z dverí kajuty na korme – a ide rovno po Riccovi
func _henchman(scene: String, from: String, delay: float) -> void:
	var g := load("res://characters/gangster/%s.tscn" % scene).instantiate() as Gangster
	g.respawn_time = 0.0
	_henchmen_left.append(g)
	if delay > 0.0:
		await _wait(delay)
	if not is_inside_tree() or _ended:
		g.free()
		return
	var at: Vector2
	if from == "hatch":
		var hs := get_node_or_null(^"HatchSpot") as Node2D
		at = hs.global_position if hs else Vector2(1270, 0)
	else:
		var st := get_node_or_null(^"Spawn11") as Node2D
		at = st.global_position if st else Vector2(73, 0)
	g.start_facing = -1.0 if player.global_position.x < at.x else 1.0
	g.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(g)
	var tw := create_tween()
	if from == "hatch":
		# vyšplhá sa z podpalubia: za trupom (pod palubou) hore na palubu
		g.z_index = -1
		g.global_position = at + Vector2(randf_range(-10.0, 10.0), 56.0)
		Sfx.play(&"door_open", at, -4.0, 0.1)
		Burst.spawn(self, at + Vector2(0, -4), Vector2(0, -1), Color(0.6, 0.6, 0.65, 0.5), 8, 40.0, Vector2(0, 30), 0.6)
		tw.tween_property(g, "global_position:y", at.y - 18.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(g, "global_position:y", at.y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		g.global_position = at
		g.modulate.a = 0.0
		Sfx.play(&"door_open", at, -6.0, 0.1)
		tw.tween_property(g, "modulate:a", 1.0, 0.4)
		tw.parallel().tween_property(g, "global_position:x", at.x + 24.0 * g.start_facing, 0.6)
	await tw.finished
	if not is_instance_valid(g):
		return
	g.z_index = 0
	g.process_mode = Node.PROCESS_MODE_INHERIT
	g.alarm()
	g.hear(player.global_position)


## Žije ešte niekto z vlny? Keď nie, príde ďalšia – po poslednej sa Lou nasere.
func _henchmen_tick() -> void:
	for g in _henchmen_left:
		if is_instance_valid(g) and (g as Gangster).state != Gangster.State.DEAD:
			return
	_henchmen_left.clear()
	var w := _wave
	_wave = -1   # počas pauzy nekontroluj
	await _wait(1.6)
	_wave = w
	_next_wave()


## Poskoci padli – Lou na krídle zúri (rev), ukáže sa pás jeho zdravia a začne mostík
func _henchmen_done() -> void:
	lou_phase = 1
	_lou.enrage()


## Udalosti boja od Lou (big_lou.gd → signál stage)
func _on_lou_stage(n: StringName) -> void:
	match n:
		&"enraged":
			_show_bar()
			(get_node(^"Storm") as Node).call(&"strike", 0.8)
			say("NOW HE'S STEAMED.\nKEEP MOVIN', KID!")
		&"crane_drop":
			_say_once(&"drop", "HE'S WORKIN' THE CRANE!\nWATCH YOUR HEAD!")
		&"wing_hit":
			_wing_hit()
		&"wing_break":
			_break_wing(true)
		&"burnt_up":
			say("HE'S DOWN HERE WITH US NOW.\nAND HE'S MAD AS HELL.")
			_crane_due = true
		&"charge":
			_say_once(&"charge", "HE'S CHARGIN'! SLIDE\nBETWEEN HIS LEGS, KID!")
		&"dazed":
			_say_once(&"dazed", "HE'S SEEIN' STARS. NOW!")
		&"dying":
			_say_queue.clear()


func _on_lou_threw() -> void:
	if _lou.phase == 1:
		_say_once(&"dynamite", "DYNAMITE! GRAB IT AND\nSEND IT BACK TO HIM!")
	else:
		_say_once(&"dynamite3", "MORE DYNAMITE! THROW IT\nBACK OR GET CLEAR!")


## Po smrti v boji: Lou začne vo fáze, ktorú už Ricco raz dosiahol (mostík bez poskokov / horiaca paluba)
func _resume_phase() -> void:
	if lou_phase == 2:
		lou_phase = 1   # staré uloženie (búdka pri žeriave už nie je)
	if lou_phase == 3:
		_lou.setup_phase(3, Vector2(BRIDGE_X - 260.0, 0))
		_break_wing(false)
		_crane_wrecked()
		# Ricco začne za zrúteným ramenom (v zúženej aréne s Lou), nie pri kajute na korme
		if _crane:
			player.global_position = Vector2(_crane.landing().x + 90.0, 0)


# ---------------------------------------------------------------- krídlo mostíka

## Dynamit hodený späť vybuchol pri Lou – krídlo sa otrasie, tmavne, padajú z neho nity a plech
func _wing_hit() -> void:
	_wing_dmg += 1
	var wing := get_node_or_null(^"Props/Wing") as Node2D
	if wing:
		wing.modulate = Color.WHITE.lerp(Color(0.45, 0.4, 0.38), _wing_dmg / 3.0)
		var tw := wing.create_tween()
		tw.tween_property(wing, "rotation", -0.03 * _wing_dmg, 0.08)
		tw.tween_property(wing, "rotation", -0.012 * _wing_dmg, 0.25).set_trans(Tween.TRANS_BACK)
		var at: Vector2 = wing.global_position + Vector2(40, 18)
		Burst.spawn(self, at, Vector2(0, 1), Color(0.5, 0.5, 0.52), 10, 80.0, Vector2(0, 400), 0.6)
	Sfx.play(&"metal_crash", Vector2(BRIDGE_X - 50.0, -180.0), -4.0, 0.1)
	if _wing_dmg == 1:
		say("IT'S WORKIN'! THAT WING\nWON'T TAKE MUCH MORE.")
	elif _wing_dmg == 2:
		say("ONE MORE AND HE'S\nCOMIN' DOWN!")


## Krídlo sa odlomí (fx = výbuch, pád, hlášky; inak už leží na palube – checkpoint). Lou letí s ním (big_lou.gd).
func _break_wing(fx: bool) -> void:
	lou_phase = 3
	var floor_body := get_node_or_null(^"WingFloor") as Node
	if floor_body:
		floor_body.queue_free()
	for n in [^"Props/CraneConsole", ^"Lever"]:
		var c := get_node_or_null(n) as CanvasItem
		if c:
			c.visible = false
	var wing := get_node_or_null(^"Props/Wing") as Node2D
	# kus krídla leží zlomený na palube pod nadstavbou (len obrázok – Ricco popri ňom prejde)
	var land := Vector2(BRIDGE_X - 118.0, -22.0)   # zábradlie a podlaha nad palubou, vzpera za trupom
	if wing:
		wing.modulate = Color(0.45, 0.4, 0.38)
		if fx:
			var tw := wing.create_tween()
			tw.tween_property(wing, "rotation", -0.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(wing, "global_position", land, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(wing, "rotation", 0.06, 0.3)
			tw.tween_callback(func():
				Sfx.play(&"metal_crash", land, 4.0, 0.05)
				Burst.spawn(self, land + Vector2(56, 10), Vector2(0, -1), Color(0.7, 0.7, 0.74, 0.6), 16, 120.0, Vector2(0, 200), 0.6))
		else:
			wing.global_position = land
			wing.rotation = 0.06
	if fx:
		Explosion.spawn(self, Vector2(BRIDGE_X - 30.0, -186.0), 1.4, 0, 0.0, 30.0)
		_say_queue.clear()
		bark("TIMBER!")
		_drop(PIZZA, Vector2(BRIDGE_X - 70.0, -60.0), Vector2(-80, -160))
	# mostík horí
	var f := FIRE.new()
	f.width = 40.0
	f.big = true
	f.harmful = false
	f.sound = false
	f.z_index = -5
	add_child(f)
	f.position = Vector2(BRIDGE_X + 10.0, -176.0)
	_start_burning(fx)


# ---------------------------------------------------------------- žeriav bez obsluhy

## Blesk udrie do kabíny žeriavu, rameno sa zrúti na palubu (na sud whisky) a odreže kus paluby – aréna sa zúži
func _crane_down() -> void:
	if _crane == null or _crane.is_broken():
		return
	var cab: Vector2 = _cab()
	say("THE CRANE! IT'S COMIN' DOWN!")
	await _wait(0.8)
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
	await _wait(0.45)
	_crane.collapse()


## Checkpoint na palube: žeriav už leží, aréna je zúžená
func _crane_wrecked() -> void:
	if _crane == null:
		return
	_crane.wrecked()
	var b1 := get_node_or_null(^"Barrel1")
	if b1:
		b1.queue_free()
	_crash_fires(_crane.landing(), false)
	_arena_wall(_crane.landing().x)


## Kabína žeriavu (sem udrie blesk) – kúsok pod čapom ramena (world/ship/crane.gd)
func _cab() -> Vector2:
	return (_crane.get(&"pivot") as Vector2) + Vector2(-6, 26) if _crane else Vector2(994, -300)


## Zubatý blesk z neba do bodu (dve čiary – žiara a biele jadro), zmizne s bliknutím
func _bolt(to: Vector2) -> void:
	var pts := PackedVector2Array()
	var from := Vector2(to.x + randf_range(-60.0, 60.0), SHIP_MAP.position.y - 20.0)
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


func _on_boom_landed(at: Vector2) -> void:
	Explosion.spawn(self, at, 1.6, 1, 0.0, 44.0)
	_crash_fires(at, true)
	_arena_wall(at.x)


## Zrútené rameno odreže zadnú časť paluby: neviditeľná stena (aj pre guľky) – po boji zmizne (útek k člnu)
func _arena_wall(x: float) -> void:
	if get_node_or_null(^"ArenaWall"):
		return
	var b := StaticBody2D.new()
	b.name = "ArenaWall"
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 600)
	cs.shape = r
	b.add_child(cs)
	add_child(b)
	b.global_position = Vector2(x + 14.0, -300.0)
	if _lou:
		_lou.walk_span.x = maxf(_lou.walk_span.x, x + 40.0)


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


## Loď horí: oheň na mostíku, kajute a nadstavbe, iskry stúpajú cez celú obrazovku, oranžový nádych, praskanie
func _start_burning(fx: bool) -> void:
	if _burning:
		return
	_burning = true
	# (záchranný čln nehorí – je to cesta von)
	for spec in [[Vector2(BRIDGE_X + 90.0, -248), 48.0, true, -5], [Vector2(36, -96), 34.0, false, -5], [Vector2(BRIDGE_X + 190.0, -176), 40.0, true, -5], [Vector2(BRIDGE_X + 290.0, -248), 44.0, true, -5], [Vector2(BRIDGE_X + 386.0, -176), 36.0, true, -5]]:
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
	_zoom_to(1.0, 2.0)
	var wall := get_node_or_null(^"ArenaWall")
	if wall:
		wall.queue_free()   # cesta k člnu je voľná (oheň pri ramene sa dá preskočiť)
	_say_queue.clear()
	bark("SO LONG, LOU. YOU SHOULD'A\nSTAYED IN THE FISH BUSINESS.")
	await _wait(3.6)
	escape_stage = 1
	_open_house()
	(get_node(^"Storm") as Node).call(&"strike", 0.8)
	Explosion.spawn(self, Vector2(BRIDGE_X + 120.0, -180), 0.9, 0, 0.0, 30.0)   # mostík praská
	await _wait(1.0)
	bark("LOU'S CABIN'S UNDER THE BRIDGE.\nLET'S SEE WHAT HE WAS HIDIN'.")


# ---------------------------------------------------------------- útek z lode

## Po smrti počas úteku: Lou už nie je, loď horí, dvere kajuty sú otvorené; po liste rovno odpočet k člnu
func _resume_escape() -> void:
	if _lou:
		_lou.queue_free()
		_lou = null
	_break_wing(false)
	_crane_wrecked()
	var wall := get_node_or_null(^"ArenaWall")
	if wall:
		wall.free()
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
		r.size = Vector2(HOUSE_W - 128.0, 176)   # od pravého okraja dverí (BRIDGE_X + 128) po koniec nadstavby
		house.shape = r
		house.global_position = Vector2(BRIDGE_X + 64.0 + HOUSE_W * 0.5, -88)
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
		Explosion.spawn(self, Vector2(BRIDGE_X + 80.0, -190), 1.4, 0, 0.0, 30.0)   # kotol trhá mostík
		var big := FIRE.new()
		big.width = 60.0
		big.big = true
		big.harmful = false
		big.sound = false
		big.z_index = -5
		add_child(big)
		big.position = Vector2(BRIDGE_X + 250.0, -176)
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
		_drop_debris(clampf(player.global_position.x + off, 140.0, BRIDGE_X + 100.0))
	_lurch_t -= delta
	if _lurch_t <= 0.0:
		_lurch_t = randf_range(5.0, 8.0)
		player.shake_timer = 0.6
		player.shake_strength = 3.0
		Sfx.play(&"metal_crash", Vector2.INF, -8.0, 0.2)


## Horiaci trám: na zemi sa objaví tieň, o chvíľu z výšky spadne – kto pod ním stojí, dostane zásah; dopadne a chvíľu horí
func _drop_debris(x: float) -> void:
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, -150), Vector2(x, 40), 1))
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
