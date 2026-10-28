extends ClubLevel
## Kapitola III – časť 5: jazzový klub The Blue Canary v Harleme (Lenox Avenue a sála). Scéna club.tscn
## (píše ju _art_src/make_club_scene.py). Ricco vystúpi z nadzemky na stanici 125 St a musí sa dostať cez sálu
## do zákulisia (časť 6 – club_back.gd). Cesty dnu:
##   • predné dvere – dvaja vyhadzovači (passive – Ricca nepustia, ale ani nenapadnú, kým ich nezasiahne).
##     Vyľakaná mačka na smetiaku (alley_cat.gd – aj klobúkom zďaleka) ich odláka – kým sú preč od dverí, dvere sú voľné.
##     Alebo ich zloží (hlučne – zasiahnutý vyhadzovač naštve aj druhého).
##   • požiarne schodisko – po rebríku na konštrukciu nadzemky, skok na schodisko a oknom do kabíny na balkóne.
##   • uhoľný poklop pri smetiakoch – šachtou do tunela (plaziť sa), kotolňa s kuričom, rebríkom za bar.
## Sála: hostia pri stoloch vidia Ricca na svetle lampičiek (klobúk ich zhasne), reflektor z balkóna prechádza sálou
## (osvetľovač – keď Ricca zbadá, reflektor ho sleduje), luster nad stolom mafiánov (výstrel do lana ho zhodí).
## Pod stropom háky rekvizitného ťahu (train_strap.gd) až na lávku nad pódiom – tichá cesta ponad hlavy.
## Poplach (ClubLevel): kapela stíchne, hostia utekajú, prídu posily. Ricco odíde lávkou alebo cez pódium do zákulisia.
## Checkpointy (Level3.checkpoint): 14 = stanica 125 St, 15 = vnútri (kabína / vestibul / kotolňa), 16 = lávka nad sálou.
## Godot docs: classes/class_cpuparticles2d, classes/class_tween

const CLUB_MAP := Rect2i(0, -370, 2780, 540)   ## hranice kamery – ulica a podlaha sály y = 0, kotolňa 150
const HALL_X := 708.0                          ## vnútorná strana čelnej steny klubu
const DOOR_X := 700.0
const DOOR_FREE := 90.0                        ## px – vyhadzovač ďalej od dverí = dvere sú voľné
const CAT_TIME := 25.0                         ## s – ako dlho vyhadzovači hľadajú, čo vyľakalo mačku
const GANG := "res://characters/gangster/gangster_coppola.tscn"
const TOMMY_G := "res://characters/gangster/gangster_tommy.tscn"

const ARRIVE_CLUB: Array[String] = [
	"125th Street, Harlem. Jazz leaking out of every door on the block.",
	"The Blue Canary. Sal's joint. If anybody knows who 'M.' is, it's Sal.",
]

var _b1: Gangster
var _b2: Gangster
var _angry: bool = false          ## vyhadzovači idú po Riccovi
var _cat_t: float = -1.0          ## s – kým vyhadzovači hľadajú mačku
var _door_open: bool = false
var _rain: CPUParticles2D
var _rain_snd: AudioStreamPlayer
var _operator_down: bool = false


func _ready() -> void:
	if checkpoint >= 17:   # zomrel v zákulisí → rovno tam
		get_tree().change_scene_to_file.call_deferred(CLUB_BACK)
		return
	var black := _setup(CLUB_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 14)
	exits = PackedFloat32Array([DOOR_X, 2752.0])
	_b1 = get_node_or_null(^"Bouncer1") as Gangster
	_b2 = get_node_or_null(^"Bouncer2") as Gangster
	_rain = get_node_or_null(^"Rain") as CPUParticles2D
	var cat := get_node_or_null(^"Cat")
	if cat:
		cat.startled.connect(_on_cat)
	var chandelier := get_node_or_null(^"Chandelier")
	if chandelier:
		chandelier.landed.connect(_on_chandelier)
	_connect(^"ElBark", func(): _once(&"el", "CLIMB THE EL, KID (%s).\nTHAT FIRE ESCAPE GOES SOMEWHERE." % KeyBindings.short(&"jump")))
	_connect(^"DoorTalk", _on_door_talk)
	_connect(^"TunnelBark", func(): _once(&"coal_tunnel", "COAL TUNNEL. TIGHT SQUEEZE -\nCRAWL ON YOUR BELLY (%s)." % KeyBindings.short(&"slide")))
	for path in [^"Checkpoint15", ^"Checkpoint15Door", ^"Checkpoint15Boiler"]:
		_connect(path, func(): checkpoint = maxi(checkpoint, 15))
	_connect(^"BoothBark", func(): _once(&"spotlight", "SPOTLIGHT MAN ON THE BALCONY.\nPUT HIM TO SLEEP AND THE LIGHT STOPS HUNTIN'."))
	_connect(^"RigBark", func(): _once(&"rigging", "STAGE RIGGING UP TOP - HOOKS ALL THE WAY\nTO THE STAGE. JUMP (%s) AND GRAB ON." % KeyBindings.short(&"jump")))
	_connect(^"HallBark", func(): _once(&"tables", "CIVILIANS AT EVERY TABLE.\nTHE HAT (%s) PUTS THEM LAMPS OUT QUIET." % KeyBindings.short(&"throw_hat")))
	_connect(^"ChandelierBark", func(): _once(&"chandelier", "THAT CHANDELIER OVER SAL'S BOYS...\nHANGIN' BY ONE LOUSY ROPE."))
	for path in [^"Checkpoint16", ^"Checkpoint16Floor"]:
		_connect(path, func(): checkpoint = maxi(checkpoint, 16))
	_connect(^"ExitBackstage", _on_exit_backstage)
	_club_ready()
	_crowd = Sfx.loop(&"crowd", self, Vector2.INF, -10.0) as AudioStreamPlayer
	_rain_snd = Sfx.loop(&"rain", self, Vector2.INF, -8.0) as AudioStreamPlayer
	_fade_in(black)
	if checkpoint == 14 and not club_arrived:
		club_arrived = true
		_arrive_club()


func _arrive_club() -> void:
	player.set_cutscene(true)
	await _wait(1.0)
	player.set_cutscene(false)
	await ThoughtBox.think(self, ARRIVE_CLUB).finished
	_once(&"gorillas", "TWO GORILLAS ON THE DOOR, KID.\nFIND ANOTHER WAY IN - OR MAKE ONE.")


func _club_tick(delta: float) -> void:
	super._club_tick(delta)
	_tick_bouncers(delta)
	_tick_outside()
	if not _operator_down and not alive(^"Operator"):
		_operator_down = true
		if not alarm_on:
			_once(&"operator_down", "LIGHTS-MAN'S OUT. NOW THAT SPOTLIGHT\nONLY CARES ABOUT THE SINGER.")


## V klube = sála, balkón, pódium (nie ulica ani kotolňa)
func _in_club(pos: Vector2) -> bool:
	return pos.x > HALL_X and pos.y < 6.0


# ---------------------------------------------------------------- vyhadzovači a predné dvere

func _bouncers() -> Array[Gangster]:
	var out: Array[Gangster] = []
	for b in [_b1, _b2]:
		if is_instance_valid(b) and b.state != Gangster.State.DEAD:
			out.append(b)
	return out


func _tick_bouncers(delta: float) -> void:
	var bs := _bouncers()
	if not _angry:
		for b in bs:
			var st: int = int(b.state)
			if b.health < b.max_health or (st >= AWARE_FROM and st <= AWARE_TO) or st == Gangster.State.STUN or bs.size() < 2:
				_angry = true
				break
		if _angry:   # zasiahol jedného (alebo jeden padol) – naštve aj druhého
			for b in bs:
				b.passive = false
				b.stationary = false
				b.alarm()
			if not bs.is_empty():
				_speak(bs[0], "HEY! GET HIM!")
		elif _cat_t >= 0.0:
			_cat_t -= delta
			if _cat_t < 0.0:
				for b in bs:   # nič nenašli – späť k dverám, zase si Ricca nevšímajú
					if b.state in [Gangster.State.PATROL, Gangster.State.IDLE]:
						b.passive = true
	# dvere: voľné, keď vyhadzovači nie sú pri nich (mŕtvi, odlákaní) alebo je v klube poplach
	var free: bool = alarm_on
	if not free:
		free = true
		for b in bs:
			if absf(b.global_position.x - DOOR_X) < DOOR_FREE and absf(b.global_position.y) < 30.0:
				free = false
	if free != _door_open:
		var px: float = player.global_position.x
		if free or px < 640.0 or px > 720.0:   # nezavrie sa Riccovi pred nosom
			_set_door(free)


func _set_door(on: bool) -> void:
	_door_open = on
	var door := get_node_or_null(^"DoorMain")
	if door == null:
		return
	(door.get_node(^"Shape") as CollisionShape2D).set_deferred(&"disabled", on)
	(door.get_node(^"Sprite") as Sprite2D).frame = 1 if on else 0
	Sfx.play(&"door_open" if on else &"door_close", Vector2(DOOR_X, -40.0), -8.0)


func _on_door_talk() -> void:
	if _door_open or _angry:
		return
	var bs := _bouncers()
	if bs.is_empty():
		return
	_speak(bs[bs.size() - 1], ["MEMBERS ONLY, PAL.", "BEAT IT, BIRD.", "NO TIE, NO JAZZ."][randi() % 3])
	_once(&"front_door", "THEY AIN'T LETTIN' A PENGUIN IN.\nFIRE ESCAPE, COAL CHUTE... OR SPOOK THAT CAT.")


## Mačka zrinčala smetiakom – vyhadzovači sa idú pozrieť (chvíľu si všímajú okolie)
func _on_cat() -> void:
	if _angry:
		return
	var cat_pos := Vector2(330.0, 0.0)
	for b in _bouncers():
		b.passive = false
		b.hear(cat_pos)
	_cat_t = CAT_TIME
	var bs := _bouncers()
	if not bs.is_empty():
		_speak(bs[0], "WHAT WAS THAT?")
	_once(&"cat", "THAT CAT RANG THE DINNER BELL.\nTHE GORILLAS ARE LEAVIN' THE DOOR.")


# ---------------------------------------------------------------- dážď vonku

func _tick_outside() -> void:
	var p: Vector2 = player.global_position
	var outside: bool = p.x < HALL_X - 4.0 and p.y < 2.0
	if _rain:
		_rain.emitting = outside
	if _rain_snd:
		_rain_snd.volume_db = move_toward(_rain_snd.volume_db, -8.0 if outside else -26.0, 0.5)
	if _crowd and not alarm_on:
		_crowd.volume_db = move_toward(_crowd.volume_db, -10.0 if p.x > HALL_X else -22.0, 0.5)


# ---------------------------------------------------------------- luster a poplach

func _on_chandelier(kills: int) -> void:
	if kills > 0:
		say("NOW THAT'S WHAT I CALL\nA FALLING OUT.")
	else:
		say("MISSED 'EM. BUT WHAT A RACKET.")
	raise_alarm()


func _on_alarm() -> void:
	_once(&"club_alarm", "SO MUCH FOR QUIET, KID.\nNOW IT'S A PARTY.")
	_reinforce()


## Posily: z vestibulu, zo zákulisia, od baru – tam, kde Ricco nie je
func _reinforce() -> void:
	await _wait(4.0)
	if player == null or player.get(&"state") == 3:
		return
	var pts := reinforce_points(2)
	var kinds := [[TOMMY_G, {}], [GANG, {"weapon": REVOLVER, "pellets": 1, "spread_deg": 3.0, "bullet_lifetime": 1.4,
			"preferred_range": 0.0, "walk_speed": 30.0}]]
	for i in pts.size():
		spawn_reinforcement(kinds[i][0], pts[i], kinds[i][1])
	await _wait(10.0)
	if player == null or player.get(&"state") == 3 or not _in_club(player.global_position):
		return
	for p in reinforce_points(1):
		spawn_reinforcement(GANG, p, {"kind": "tux"})


# ---------------------------------------------------------------- odchod do zákulisia

func _on_exit_backstage() -> void:
	club_loud = alarm_on
	_leave_door(CLUB_BACK, 17, false)
