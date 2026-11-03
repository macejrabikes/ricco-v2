extends Level3
## Kapitola III – časť 9: rozostavaný mrakodrap Iron Mikea za svitania („topping out“) a boss Iron Mike.
## Scéna tower.tscn (píše ju _art_src/make_tower_scene.py). Ricco ide zo staveniska na ulici po rebríkoch hore
## oceľovou kostrou (nosníky v míniu, fošne, betón na spodných poschodiach), poschodia sa striedajú – rebrík raz
## na západnom, raz na východnom konci:
##   ulica / prízemie (0)   plot staveniska, búdka, miešačka, nitovači a bitkár
##   1. poschodie (−130)    nitovači si hádžu rozžeravené nity (rivet_forge.gd) – kto vojde do oblúka, popáli sa
##   2. poschodie (−260)    zväzok nosníkov na reťazi nad obedujúcimi mafiánmi (drop_weight.gd)
##   3. poschodie (−390)    checkpoint 31, Thompson za stohom nosníkov
##   4. poschodie (−520)    žeriav zametá poschodie nosníkom vo výške pása (tower_crane.gd – SWEEP) – šmyk popod neho
##   5. poschodie (−650)    vietor (nárazy odfúknu Ricca k okraju), posledná partia
##   vrchol (−780)          paluba z fošní, diera v palube nad 5. poschodím (kto do nej spadne / vietor ho tam odfúkne,
##                          vylezie späť rebríkom), vyhňa, stohy nosníkov (kryt), vežový žeriav (východ),
##                          stožiar pre vzducholoď „IRON“ (západ) s plošinou −930 a rebríkom
## Boss (characters/iron_mike/iron_mike.gd, pás zdravia ui/boss_bar.gd – tri fázy):
##   1. Mike na poslednom nosníku na háku žeriavu → popruh praskne, Mike zletí na palubu, nosník spadne vedľa
##   2. paluba – pumpovačka, nabíjanie po náboji, pažba, kopanec do vyhne; žeriavnik púšťa sudy s nitami (tieň)
##   3. plošina stožiara; smrť – chytí sa povrazového rebríka gondoly, závoj v okne… a rebrík niekto odreže.
##      Vzducholoď „M.“ odletí, Winchester 1897 ostane na plošine → naháňačka taxíkom (časť 10 – chase.gd).
## Checkpointy (Level3.checkpoint): 30 = stavenisko, 31 = 3. poschodie, 32 = vrchol (boj; mike_phase = dosiahnutá fáza).
## Godot docs: classes/class_tween, classes/class_characterbody2d (move_and_collide), classes/class_canvaslayer

const TOWER_MAP := Rect2i(-20, -1160, 1660, 1240)
const DECK := -780.0
const WIND_FROM := -600.0          ## nad touto výškou fúka (otvorené poschodia hore)
const GUST := 60.0                 ## px/s – ako silno náraz tlačí Ricca (na stožiari viac)
const DAWN := Color(1.0, 0.9, 0.86)   ## mafiáni v ranom svetle
const BOSS_BAR := preload("res://ui/boss_bar.gd")
const STREAK := preload("res://levels/level3/art/tower/wind_streak.png")

const ARRIVE_TOWER: Array[String] = [
	"Dawn. Iron Mike's tower - seventy-two floors of steel and not a single wall yet.",
	"He's up top, topping out. With a zeppelin tied to the roof.",
]
const END_THOUGHT: Array[String] = [
	"She cut the rope. Didn't even look down.",
	"The veil in that window. The lady from Sal's photograph. 'M.'",
]
const TAUNTS: Array[String] = [
	"COME ON UP, BIRD! I DON'T BITE!",
	"I BUILT THIS TOWER WITH MY HANDS. I'LL BURY YOU IN IT!",
	"CAREFUL ON THEM RUNGS. LONG WAY DOWN!",
]
const HIT_LINES: Array[String] = [
	"STAND STILL, YOU OVERDRESSED PIGEON!",
	"TWELVE GAUGE, BIRD. SAY AHH!",
	"THIS TOWER'S MINE! THIS CITY'S MINE!",
]

var _mike: IronMike
var _crane: Node
var _bar   ## ui/boss_bar.gd
var _fight: bool = false
var _ending: bool = false
var _said: Array[StringName] = []
var _gust_t: float = 8.0
var _gust_len: float = 0.0
var _gust_age: float = 0.0
var _gust_dir: float = -1.0
var _wind: AudioStreamPlayer
var _line_cd: float = 0.0


func _ready() -> void:
	var black := _setup(TOWER_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 30)
	player.dark_area = false   # svitá – vidno všetkých (aj Ricca)
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var rig := g.get(&"rig") as Node2D
		if rig:
			rig.modulate = DAWN
	_mike = get_node_or_null(^"IronMike") as IronMike
	_crane = get_node_or_null(^"Crane")
	if _mike:
		_mike.stage.connect(_on_mike_stage)
		_mike.health_changed.connect(_on_mike_hurt)
	_connect(^"StartBark", func(): _once(&"tower_start", "UP THE STEEL, KID. A LADDER EVERY FLOOR.\nMIKE'S AT THE VERY TOP."))
	_connect(^"RivetBark", func(): _once(&"tower_rivets", "THEY'RE PITCHIN' HOT RIVETS.\nDON'T WALK INTO THE THROW."))
	_connect(^"BundleBark", func(): _once(&"tower_bundle", "STEEL ON A CHAIN OVER THEIR LUNCH.\nSHOOT THE CHAIN, KID."))
	_connect(^"SweepBark", func(): _once(&"tower_sweep", "THAT CRANE'S SWINGIN' A BEAM THROUGH HERE.\nSLIDE UNDER IT (%s)." % KeyBindings.short(&"slide")))
	_connect(^"WindBark", func(): _once(&"tower_wind", "WIND'S PICKIN' UP. MIND THE EDGE -\nA GUST'LL BLOW A BIRD RIGHT OFF."))
	_connect(^"GapBark", func():
		if _fight:
			say("BACK UP THE LADDER, KID!"))
	for cp in [31, 32]:
		var n: int = cp
		_connect(NodePath("Checkpoint%d" % n), func(): checkpoint = maxi(checkpoint, n))
	_connect(^"BossTrigger", _start_fight)
	var bundle := get_node_or_null(^"Bundle")
	if bundle and bundle.has_signal(&"landed"):
		bundle.landed.connect(func(kills: int):
			if kills > 0:
				say("LUNCH BREAK'S OVER, BOYS."))
	_wind = Sfx.loop(&"wind_loop", self, Vector2.INF, -30.0) as AudioStreamPlayer
	Sfx.loop(&"airship_drone", self, Vector2(560, -1000), -12.0)
	Sfx.music(&"desolation")
	if _crane:
		if mike_phase >= 2:
			_crane.call(&"start_drops")
		else:
			_crane.call(&"start_sweep")
	_fade_in(black)
	if checkpoint >= 32:
		_start_fight.call_deferred()
	elif checkpoint == 30 and not tower_arrived:
		tower_arrived = true
		_arrive_tower()


func _arrive_tower() -> void:
	player.set_cutscene(true)
	await _wait(0.8)
	player.set_cutscene(false)
	await ThoughtBox.think(self, ARRIVE_TOWER).finished


func _process(delta: float) -> void:
	if player == null:
		return
	_tick_say(delta)
	_line_cd -= delta


func _say_once(key: StringName, t: String) -> void:
	if key in _said:
		return
	_said.append(key)
	say(t)


# ---------------------------------------------------------------- vietor

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var high: bool = player.global_position.y < WIND_FROM
	if _wind:
		_wind.volume_db = move_toward(_wind.volume_db, -10.0 if high else -30.0, 12.0 * delta)
	if _ending:
		return
	_gust_t -= delta
	if _gust_t <= 0.0 and high and _gust_len <= 0.0:
		_gust_t = randf_range(5.0, 9.0)
		_gust_len = randf_range(1.4, 2.0)
		_gust_age = 0.0
		_gust_dir = -1.0 if randf() < 0.75 else 1.0   # väčšinou od rieky (z východu)
		Sfx.play(&"wind_gust", Vector2.INF, -4.0, 0.08, &"Ambience")
		_streaks()
	if _gust_len <= 0.0:
		return
	_gust_age += delta
	if _gust_age >= _gust_len:
		_gust_len = 0.0
		return
	var st: int = int(player.get(&"state"))
	if not high or player.get(&"in_cutscene") or (st != 0 and st != 4):
		return
	var k: float = sin(PI * _gust_age / _gust_len)
	var strength: float = GUST * (1.35 if player.global_position.y < DECK - 60.0 else 1.0)
	(player as CharacterBody2D).move_and_collide(Vector2(_gust_dir * strength * k * delta, 0.0))


## Biele šmuhy vetra okolo Ricca
func _streaks() -> void:
	for i in 12:
		var s := Sprite2D.new()
		s.texture = STREAK
		s.z_index = 20
		s.modulate.a = 0.0
		add_child(s)
		var start := player.global_position + Vector2(-_gust_dir * randf_range(200.0, 380.0) + randf_range(-160.0, 160.0), randf_range(-170.0, 60.0))
		s.global_position = start
		var tw := s.create_tween()
		tw.tween_interval(randf_range(0.0, 0.8))
		tw.tween_property(s, "modulate:a", randf_range(0.4, 0.8), 0.15)
		tw.parallel().tween_property(s, "global_position", start + Vector2(_gust_dir * 520.0, randf_range(-10.0, 10.0)), 1.1)
		tw.tween_property(s, "modulate:a", 0.0, 0.2)
		tw.tween_callback(s.queue_free)


# ---------------------------------------------------------------- Iron Mike

## Ricco vyliezol na vrchol – žeriav vytiahne posledný nosník a na ňom stojí Mike (po smrti: dosiahnutá fáza)
func _start_fight() -> void:
	if _fight or _mike == null or _crane == null:
		return
	_fight = true
	checkpoint = maxi(checkpoint, 32)
	Sfx.music(&"intensity", 0.8)
	_bar = BOSS_BAR.new()
	add_child(_bar)
	_bar.notches.assign([1.0 / 3.0, 2.0 / 3.0])
	_bar.track("IRON MIKE", _mike)
	match mike_phase:
		2:
			_crane.set(&"drops_enabled", true)
			var at := get_node_or_null(^"DeckSpot") as Node2D
			_mike.start(2, at.global_position if at else Vector2(900, DECK))
		3:
			_crane.set(&"drops_enabled", true)   # sudy padajú, len keď je Ricco dolu na palube
			var at := get_node_or_null(^"MastSpot") as Node2D
			_mike.start(3, at.global_position if at else Vector2(640, -930))
		_:
			mike_phase = 1
			_mike.ride = _crane.get(&"ride_point")
			_crane.call(&"start_ride", _mike, not mike_revealed)
			_mike.start(1)
			if not mike_revealed:
				mike_revealed = true
				_speak(_mike, "TOPPING OUT, BIRD! YOU'RE JUST IN TIME FOR THE CEREMONY!", 92.0)
				await _wait(2.6)
				say("HE'S RIDIN' THE LAST BEAM.\nRATTLE THAT HOOK - A HAT'LL DO IT.")
	_bar._on_health(_mike.health, float(_mike.max_health))   # po smrti v 2./3. fáze nezačína plný
	_bar._chip = _bar._value


func _on_mike_hurt(_h: float, _m: float) -> void:
	if _line_cd <= 0.0 and randf() < 0.25 and is_instance_valid(_mike) and _mike.active:
		_line_cd = 6.0
		_speak(_mike, HIT_LINES[randi() % HIT_LINES.size()], 92.0)


## Udalosti boja od Mikea (iron_mike.gd → signál stage)
func _on_mike_stage(n: StringName) -> void:
	match n:
		&"lurch":
			_say_once(&"lurch", "THAT'S IT! RATTLE HIS CAGE!")
		&"beam_tilt":
			mike_phase = 2
			_say_queue.clear()
			var dir: float = signf(player.global_position.x - _mike.global_position.x)
			dir = dir if dir != 0.0 else 1.0
			if _mike.global_position.x > 1330.0:
				dir = -1.0   # nie do diery v palube
			_crane.call(&"snap", dir)
			await _wait(0.3)
			_mike.fall_off(dir)
			say("THE SLING SNAPPED! HERE HE COMES!")
		&"landed":
			_crane.set(&"drops_enabled", true)
			await _wait(1.2)
			_speak(_mike, "YOU KNOW WHAT THAT BEAM COST ME?!", 92.0)
			_say_once(&"drops", "WATCH THE CRANE - SHADOW ON THE DECK\nMEANS SOMETHIN'S COMIN' DOWN.")
		&"reload":
			_say_once(&"reload", "HE'S RELOADIN' ONE SHELL AT A TIME.\nGET IN THERE, KID!")
		&"bash":
			_say_once(&"bash", "NOT TOO CLOSE - HE SWINGS\nTHAT STOCK LIKE A SLEDGEHAMMER.")
		&"forge":
			_say_once(&"forge", "HOT RIVETS! DON'T SIT BEHIND\nTHAT COVER ALL DAY!")
		&"to_mast":
			mike_phase = 3
			_say_queue.clear()
			_speak(_mike, "YOU WANT ME? COME AND GET ME!", 92.0)
			say("HE'S RUNNIN' FOR THE AIRSHIP MAST!")
		&"on_mast":
			_say_once(&"mast", "UP THE LADDER, KID. HE WON'T SHOOT\nTILL YOU'RE ON TOP - HE WANTS IT PERSONAL.")
		&"taunt":
			_speak(_mike, TAUNTS[randi() % TAUNTS.size()], 92.0)
		&"dying":
			_mike_dies()


# ---------------------------------------------------------------- koniec: povrazový rebrík, závoj, pád

func _mike_dies() -> void:
	if _ending:
		return
	_ending = true
	_crane.call(&"stop")
	_say_queue.clear()
	Sfx.music(&"", 2.5)
	var m := _mike
	var rope := get_node_or_null(^"Airship/RopeLadder") as Sprite2D
	var ship := get_node_or_null(^"Airship") as Node2D
	var gondola := get_node_or_null(^"Airship/Gondola") as Sprite2D
	await _wait(0.6)
	# potáca sa k povrazovému rebríku a chytí sa ho
	var rx: float = rope.global_position.x + 6.0 if rope else m.global_position.x - 30.0
	m.call(&"_set_facing", -1.0)
	var tw := create_tween()
	tw.tween_property(m, "global_position:x", rx, maxf(absf(m.global_position.x - rx) / 50.0, 0.3))
	_speak(m, "M.! MAGGIE! PULL ME UP!", 92.0)
	await tw.finished
	m.hands_up = true
	player.set_cutscene(true)
	await _wait(0.5)
	# vzducholoď sa odpúta od stožiara a stúpa – Mike visí na rebríku
	Sfx.play(&"chain_rattle", Vector2(640, -960), -4.0)
	var up := Vector2(-30.0, -46.0)
	tw = create_tween().set_parallel(true)
	if ship:
		tw.tween_property(ship, "position", ship.position + up, 2.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(m, "global_position", m.global_position + up, 2.4).set_trans(Tween.TRANS_SINE)
	await _wait(1.0)
	if gondola:
		gondola.frame = 1   # v okne silueta v závoji
	_speak(m, "M.?! IT'S ME! IT'S MIKE!", 92.0)
	await _wait(2.0)
	if gondola:
		gondola.frame = 2   # ruka v rukavici s nožom
	await _wait(0.7)
	Sfx.play(&"punch_swing", m.global_position + Vector2(0, -80), 0.0)
	if rope:   # rebrík pretnutý tesne pod gondolou
		rope.region_rect.size.y = 10.0
	var fall := create_tween().set_parallel(true)
	fall.tween_property(m, "global_position:y", m.global_position.y + 760.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(m, "rotation", -2.5, 1.6)
	Sfx.play(&"enemy_death", m.global_position, 0.0)
	await _wait(0.9)
	if gondola:
		gondola.frame = 1
	await _wait(1.2)
	m.queue_free()
	if gondola:
		gondola.frame = 0
	Sfx.play(&"airship_drone", Vector2(400, -1000), -6.0)
	if ship:
		var away := create_tween()
		away.tween_property(ship, "position", ship.position + Vector2(-980.0, -150.0), 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _wait(1.5)
	player.set_cutscene(false)
	await ThoughtBox.think(self, END_THOUGHT).finished
	bark("MARGARET. MY MARGARET.\nI BURIED HER IN THAT VEIL.")
	await _wait(3.6)
	bark("GRAB THAT SHOTGUN, KID.\nWE GOT A LADY TO CATCH.")
	await _wait(5.0)
	_leave_door(CHASE, 33, false)   # dole na ulicu, taxík za vzducholoďou (časť 10 – chase.gd)
