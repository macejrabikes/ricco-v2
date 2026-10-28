extends Level3
## Kapitola III – časť 3: dlhé strechy na Lower East Side až k stanici nadzemky Delancey St (návrh dlhsie_strechy_navrh.png).
## Ricco vyjde dverami schodiska o dom ďalej (za lahôdkami z ulice – street.gd) a ide zľava doprava
## (scénu píše _art_src/make_roofs_scene.py priamo, bez spúšťania Godotu):
##   E billboard LUCKY STAR – tri reflektory na streche svietia na tabuľu (svetlo = vidno ťa), pod tabuľou hliadkuje
##     strážny s Thompsonom. Reflektor zhasne klobúk alebo guľka (world/fx/hat_lamp.gd); alebo hore po rebríku a cez
##     vrch tabule (tma, holuby – potichu).
##   F úzka doska cez dvor (roof_plank.gd – kto beží, ten spadne; zakrádaním prejde) → holubník a starý chovateľ
##     (world/npc/guest.gd – svedok: keď Ricca uvidí na svetle lampy, skríkne a privolá mafiána). Lampa sa dá zhasnúť
##     klobúkom, alebo sa ide po streche holubníka (tam ho nevidí).
##   G krajčírska dielňa – na streche plot s ostnatým drôtom, ďalej sa ide len dnu: šmyk po svetlíku (skylight.gd) a pád
##     dnu (rinčanie počujú). Vnútri v tme šijacie stroje a balíky látky (kryt), vzadu pod lampou dvaja mafiáni vyberajú
##     výpalné od krajčíra a skorumpovaný policajt s baterkou sa tvári, že nič nevidí (rozhovor počuť už zo strechy
##     cez svetlík – _start_chatter).
##     Predná stena dielne zmizne, keď je Ricco dnu (ako vozeň 3 na nadzemke). Von oknom na požiarne schodisko.
##   H rebrík hore na dom s vysokou vodnou nádržou → z nádrže najdlhšia šnúra kapitoly (world/fx/clothesline.gd)
##     ponad ulicu až na prístrešok stanice.
##   I stanica Delancey St: na nástupišti policajti, prichádza vlak (zastaví pri nástupišti – _call_train), Ricco
##     zoskočí z prístrešku na strechu vozňa → nadzemka (train.tscn).
## Kto spadne do dvora, vylezie späť po rebríku na stene domu.
## Checkpointy (Level3.checkpoint): 5 = strecha za dverami schodiska, 6 = za doskou, 7 = strecha dielne, 8 = požiarne schodisko.
## Godot docs: classes/class_tween, classes/class_area2d, classes/class_audiostreamplayer2d

const ROOFS_MAP := Rect2i(0, -900, 3840, 964)     ## hranice kamery (px) – ulica/dvory sú na y = 0
const ROOM := Rect2(1562.0, -434.0, 668.0, 124.0)  ## dielňa – tu predná stena (GWall) zmizne
const TRAIN_RUN := 1400.0      ## px – odkiaľ vlak prichádza (zľava, schovaný za domami)
const ARRIVE_TIME := 6.0       ## s – rovnomerne brzdí až do zastavenia pri nástupišti
const TRAIN_SOUND := Vector2(3360.0, -400.0)   ## kde je vlak (stred, po zastavení) – odtiaľ znejú brzdy a zvonec

const ARRIVE_ROOFS: Array[String] = [
	"Up the stairs, through the attic, out the next roof. These tenements go on for blocks.",
	"Delancey Street station's a few roofs east. The El runs all the way uptown.",
]
## Rozhovor v dielni: [kto (uzol), čo povie, pauza po ňom]
const SHAKEDOWN := [
	["Collector", "TEN BUCKS A WEEK, MR. LIEBERMAN.\nSAME AS ALWAYS.", 3.0],
	["Tailor", "BUSINESS IS SLOW, FELLAS...\nNOBODY BUYS SUITS NO MORE.", 3.2],
	["Muscle", "THEN SEW FASTER.", 2.2],
	["Collector", "AND M. RAISED THE RATE.\nFIFTEEN, STARTING TONIGHT.", 3.2],
	["Tailor", "OFFICER! YOU HEAR THIS?", 2.4],
	["CrookedCop", "I DON'T HEAR NOTHIN'.\nI'M ON MY LUNCH BREAK.", 3.0],
]
const CREW: Array[NodePath] = [^"Collector", ^"Muscle", ^"CrookedCop"]

var _gwall: CanvasItem
var _train: Node2D
var _board: Area2D
var _train_called: bool = false
var _train_stopped: bool = false
var _train_x: float = 0.0
var _rumble: AudioStreamPlayer2D
var _lamps: Array[Node] = []
var _chatter: bool = false


func _ready() -> void:
	if checkpoint >= 9:   # zomrel na nadzemke alebo v klube → rovno tam
		get_tree().change_scene_to_file.call_deferred(part_for(checkpoint))
		return
	var black := _setup(ROOFS_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 5)
	_gwall = get_node_or_null(^"GWall") as CanvasItem
	_train = get_node_or_null(^"Train") as Node2D
	_board = get_node_or_null(^"Train/Board") as Area2D
	if _train:
		_train.visible = false
		_train.position.x = -TRAIN_RUN
		_train_x = _train.position.x
	if _board:
		_board.body_entered.connect(_on_board)
	_lamps = get_tree().get_nodes_in_group(&"billboard_lamps")
	_connect(^"BillboardBark", func(): _once(&"billboard", "SPOTLIGHTS AND A TOMMY GUN.\nHAT 'EM OUT (%s) OR GO OVER THE TOP." % KeyBindings.short(&"throw_hat")))
	_connect(^"PlankBark", func(): _once(&"plank", "THAT PLANK'S OLDER THAN ME.\nSNEAK ACROSS (%s), DON'T RUN." % KeyBindings.short(&"sneak")))
	_connect(^"Checkpoint6", func(): checkpoint = maxi(checkpoint, 6))
	_connect(^"CoopBark", func(): _once(&"coop", "OLD-TIMER WITH THE PIGEONS.\nHE SEES YA, HE HOLLERS."))
	_connect(^"Checkpoint7", func():
		checkpoint = maxi(checkpoint, 7)
		_once(&"skylight", "FENCE AHEAD. THE WAY ON IS DOWN –\nSLIDE (%s) OVER THAT SKYLIGHT." % KeyBindings.short(&"slide")))
	_connect(^"ShopVoices", _start_chatter)
	_connect(^"Checkpoint8", _on_fire_escape)
	_connect(^"TowerBark", func(): _once(&"tower", "UP THE WATER TOWER, KID.\nTHAT LINE GOES ALL THE WAY TO THE STATION."))
	_connect(^"TrainCall", _call_train)
	_connect(^"TrainCall2", _call_train)
	var plank := get_node_or_null(^"Plank")
	if plank:
		plank.connect(&"broke", func(): _once(&"plank_broke", "TOLD YA. OLDER THAN ME."))
	var sky := get_node_or_null(^"Skylight")
	if sky:
		sky.connect(&"shattered", func(): _once(&"crash_in", "SUBTLE, KID. REAL SUBTLE."))
	for n in get_children():
		if n.has_signal(&"scattered"):
			n.connect(&"scattered", func(): _once(&"pigeons_again", "PIGEONS. EVERY ROOF IN THIS TOWN."))
	Sfx.loop(&"rain", self, Vector2.INF, -8.0)
	Sfx.music(&"rainy_noir")
	_fade_in(black)
	if checkpoint == 5 and not roofs_arrived:
		roofs_arrived = true
		_arrive_roofs()


func _arrive_roofs() -> void:
	Sfx.play(&"door_close", player.global_position, -8.0)
	player.set_cutscene(true)
	await _wait(0.9)
	player.set_cutscene(false)
	await ThoughtBox.think(self, ARRIVE_ROOFS).finished


func _process(delta: float) -> void:
	if player == null:
		return
	_tick_say(delta)
	_update_wall(delta)
	_update_train(delta)
	if not (&"lights_out" in barks) and not _lamps.is_empty() and _lamps.all(func(l: Node): return l.get(&"_off")):
		_once(&"lights_out", "LIGHTS OUT. NOW YOU'RE\nJUST A SHADOW, KID.")


# ---------------------------------------------------------------- G: krajčírska dielňa

## Predná stena dielne zmizne, keď je Ricco dnu (prierez)
func _update_wall(delta: float) -> void:
	if _gwall == null:
		return
	var inside: bool = ROOM.has_point(player.global_position + Vector2(0, -2))
	_gwall.modulate.a = move_toward(_gwall.modulate.a, 0.0 if inside else 1.0, delta * 4.0)


## Rozhovor pri vyberaní výpalného – kým o Riccovi nikto z nich nevie
func _start_chatter() -> void:
	if _chatter:
		return
	_chatter = true
	for line in SHAKEDOWN:
		var who := get_node_or_null(NodePath(line[0])) as Node2D
		if who == null or not _crew_calm() or who.get(&"dead") == true:
			return
		_speak(who, line[1])
		await _wait(line[2])


## Nikto z partie (výbercovia a policajt) Ricca nezbadal ani nepočul a všetci žijú
func _crew_calm() -> bool:
	for path in CREW:
		var g := get_node_or_null(path) as Node2D
		if g == null or int(g.get(&"state")) > 1:   # Gangster.State: PATROL 0, IDLE 1 – inak už o niečom vie (alebo je mŕtvy)
			return false
	return true


## Na požiarnom schodisku: checkpoint; ak Ricco partiu zložil, krajčír mu poďakuje
func _on_fire_escape() -> void:
	checkpoint = maxi(checkpoint, 8)
	var tailor := get_node_or_null(^"Tailor") as Node2D
	var all_down: bool = true
	for path in CREW:
		var g := get_node_or_null(path) as Node2D
		if g and int(g.get(&"state")) != 10:   # Gangster.State.DEAD
			all_down = false
	if all_down and tailor and tailor.get(&"dead") == false and not (&"tailor_thanks" in barks):
		barks.append(&"tailor_thanks")
		_speak(tailor, "GOD BLESS YOU, MISTER...\nPENGUIN?")
	_once(&"tower_hint", "THE EL'S PAST THAT WATER TOWER.\nCLIMB UP, KID.")


# ---------------------------------------------------------------- I: vlak do stanice Delancey St

## Vlak príde zľava (spoza domov) a rovnomerne zabrzdí pri nástupišti (Tween EASE_OUT QUAD = rovnomerné spomalenie)
func _call_train() -> void:
	if _train_called or _train == null:
		return
	_train_called = true
	_train.visible = true
	for path in [^"Train/Roof1/Shape", ^"Train/Roof2/Shape"]:
		var s := get_node_or_null(path) as CollisionShape2D
		if s:
			s.set_deferred(&"disabled", false)
	_rumble = Sfx.loop(&"train_rumble", _train, TRAIN_SOUND, -2.0, &"SFX") as AudioStreamPlayer2D
	var tw := create_tween()
	tw.tween_property(_train, "position:x", 0.0, ARRIVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_callback(func(): Sfx.play(&"brakes", TRAIN_SOUND, -2.0, 0.0)).set_delay(ARRIVE_TIME - 3.6)
	tw.tween_callback(_on_train_stopped)
	say("HEAR THAT? THE UPTOWN LOCAL.\nDON'T MISS IT, KID.")


## Hukot vlaku podľa rýchlosti (pri nástupišti len tiché pradenie motora)
func _update_train(delta: float) -> void:
	if _rumble == null or _train == null or delta <= 0.0:
		return
	var v: float = absf(_train.position.x - _train_x) / delta
	_train_x = _train.position.x
	var k: float = clampf(v / (2.0 * TRAIN_RUN / ARRIVE_TIME), 0.0, 1.0)
	_rumble.pitch_scale = lerpf(0.5, 1.0, k)
	_rumble.volume_db = lerpf(-16.0, -2.0, k)


func _on_train_stopped() -> void:
	_train_stopped = true
	Sfx.play(&"train_bell", TRAIN_SOUND, -6.0, 0.0)
	if _board:
		_board.set_deferred(&"monitoring", true)
	say("ALL ABOARD, KID.\nROOF SEATS ONLY.")


## Ricco doskočil na strechu vozňa → nadzemka (train.tscn, checkpoint 9)
func _on_board(b: Node) -> void:
	if b != player or _leaving or not _train_stopped or player.state == 3:
		return
	_leaving = true
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	var black := _fade_rect()
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(black, "color:a", 1.0, 0.8)
	await tw.finished
	_go_next(TRAIN, 9)
