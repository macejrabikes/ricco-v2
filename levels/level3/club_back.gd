extends ClubLevel
## Kapitola III – časť 6: zákulisie klubu The Blue Canary, pivnica, herňa a kancelária Velvet Sala.
## Scéna club_back.tscn (píše ju _art_src/make_club_back_scene.py).
##   B1 zákulisie – vrecia s pieskom na lanách (drop_weight.gd – klobúk do lana a mafián pod ním je zložený), lávka.
##   B2 šatne – R2 šatňa speváčky Lark Lavelle (bubon do Thompsonu, telegram), klopacie dvere do R3, kde pijú traja
##      mafiáni (knock_door.gd – po jednom ich vylákaš von), nad šatňami izby personálu s poklopom do R2.
##   Pivnica – sudy whisky (whisky_barrel.gd – prestrelený sud = šmykľavá mláka, mafiáni sa pošmyknú), pašeráci,
##      rúry so svorkami pod stropom (ručkovanie ponad hlavy).
##   Šachta – z pivnice cez poschodie (herňa) až na strechu.
##   C1 herňa – štyria Salovi poručíci pri pokrovom stole (lampa nad stolom; stôl sa dá prevrátiť na kryt).
##   C2 kancelária – Sal (Thompson, vesta) a bodyguard. Keď je poplach (alebo bol v sále – club_loud), Sal sa zamkne,
##      prevráti stôl a čaká za ním: dvere treba vystreliť, alebo ísť strechou cez svetlík.
## Keď Sal padne, trezor: pozvánka od „M.“ na gala v hoteli Majestic a fotka ženy v závoji. Potom oknom von.
## Checkpointy (Level3.checkpoint): 17 = zákulisie, 18 = šatne / izby personálu, 19 = pivnica, 20 = šachta pri herni,
## 21 = strecha.
## Godot docs: classes/class_tween, classes/class_collisionshape2d

const BACK_MAP := Rect2i(-1460, -400, 3020, 620)
const UP := -160.0
const OFFICE := Vector2(-1340.0, -860.0)   ## kancelária od–do x
const DRUM_AMMO := 50                      ## nábojov v bubne zo šatne speváčky
const GANG := "res://characters/gangster/gangster_coppola.tscn"
const TOMMY_G := "res://characters/gangster/gangster_tommy.tscn"
const WEAPON_PICKUP := preload("res://weapons/weapon_pickup.gd")
const TELEGRAM := preload("res://levels/level3/art/club_back/telegram_big.png")
const INVITE := preload("res://levels/level3/art/club_back/invite_big.png")
const PHOTO := preload("res://levels/level3/art/club_back/photo_big.png")
const SAFE_OPEN := preload("res://levels/level3/art/club_back/safe_open.png")

const ARRIVE_BACK: Array[String] = [
	"Backstage. Ropes, sandbags and cheap perfume.",
	"Sal's office is upstairs, past his card room. The long way round is the quiet way.",
]
const TELEGRAM_THOUGHT: Array[String] = [
	"A telegram for the singer. Lark Lavelle sings at the Majestic gala, Saturday.",
	"'The lady is particular.' What lady?",
]
const SAFE_THOUGHT: Array[String] = [
	"The Majestic. Saturday, midnight. Every family in town at one table - carving up the Don's city.",
	"'M.' throws the party. And the old man knows that veil.",
	"Looks like I'm going to a gala.",
]

var _sal: Gangster
var _sal_hp: float = 0.0
var _sal_down: bool = false
var _fight: bool = false
var _locked: bool = false
var _poker_dark: bool = false
var _safe_open: bool = false
var _window_open: bool = false


func _ready() -> void:
	var black := _setup(BACK_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 17)
	_sal = get_node_or_null(^"Sal") as Gangster
	if _sal:
		_sal_hp = _sal.health
	_spawn_drum()
	_connect_spot(^"TelegramSpot", _read_telegram)
	var safe := get_node_or_null(^"SafeSpot") as InteractSpot
	if safe:
		safe.used.connect(_open_safe)
		safe.monitoring = false   # až keď Sal padne
		safe.set_process(false)
	var door := get_node_or_null(^"OfficeDoor")
	if door:
		door.broken.connect(func(): say("THAT'S ONE WAY TO KNOCK."))
	_connect(^"CatwalkBark", func(): _once(&"sandbags", "SANDBAGS UP ON THE GRID, KID.\nA HAT TO THE ROPE (%s) AND - THUNK." % KeyBindings.short(&"throw_hat")))
	_connect(^"KnockBark", func(): _once(&"knock", "CARD GAME BEHIND THAT DOOR.\nKNOCK (%s) AND SEE WHO COMES OUT." % KeyBindings.short(&"takedown")))
	_connect(^"TrapdoorBark", func(): _once(&"trapdoor", "TRAPDOOR. DROPS RIGHT INTO\nTHE SINGER'S DRESSING ROOM."))
	_connect(^"CellarBark", func(): _once(&"whisky", "BOOTLEG WHISKY. SHOOT A BARREL OPEN -\nTHAT FLOOR GETS SLICK AS A SEAL."))
	_connect(^"PipeBark", func(): _once(&"pipes", "PIPES UNDER THE CEILING.\nUP ON THE CRATES AND GRAB A CLAMP."))
	_connect(^"ShaftBark", func(): _once(&"shaft", "THIS SHAFT GOES ALL THE WAY UP.\nCARD ROOM ON TWO, ROOF ON TOP."))
	_connect(^"PokerBark", func(): _once(&"poker", "SAL'S LIEUTENANTS. KILL THAT LAMP\nAND THEY'RE PLAYIN' BLIND MAN'S BLUFF."))
	_connect(^"RoofBark", func(): _once(&"skylight_sal", "SKYLIGHT OVER SAL'S OFFICE.\nSLIDE ONTO IT (%s) AND DROP IN." % KeyBindings.short(&"slide")))
	_connect(^"LockedBark", func():
		if _locked and not _sal_down:
			_once(&"locked", "LOCKED TIGHT. SHOOT THE LOCK OFF -\nOR DROP IN THROUGH THE ROOF."))
	_connect(^"OfficeEnter", func():
		if _locked and is_instance_valid(_sal) and not _sal_down:
			_sal.alarm())
	for cp in [18, 19, 20, 21]:
		var n: int = cp
		_connect(NodePath("Checkpoint%d" % n), func(): checkpoint = maxi(checkpoint, n))
	_connect(^"Checkpoint18Up", func(): checkpoint = maxi(checkpoint, 18))
	_connect(^"ExitWindow", _on_exit_window)
	_club_ready()
	_crowd = Sfx.loop(&"crowd", self, Vector2.INF, -24.0) as AudioStreamPlayer   # sála je za stenou
	if club_loud:   # v sále bol poplach – Sal o Riccovi vie a zamkol sa
		_lock_office(true)
	_fade_in(black)
	if checkpoint == 17 and not club_back_arrived:
		club_back_arrived = true
		_arrive_back()


func _arrive_back() -> void:
	player.set_cutscene(true)
	await _wait(0.8)
	player.set_cutscene(false)
	await ThoughtBox.think(self, ARRIVE_BACK).finished
	if club_loud:
		_once(&"sal_knows", "WORD TRAVELS FAST, KID.\nSAL'S LOCKED HIMSELF IN.")


func _connect_spot(path: NodePath, f: Callable) -> void:
	var s := get_node_or_null(path) as InteractSpot
	if s:
		s.used.connect(f)


func _club_tick(delta: float) -> void:
	super._club_tick(delta)
	_tick_poker()
	_tick_sal()


# ---------------------------------------------------------------- šatňa speváčky

## Bubon do Thompsonu na zemi pri toaletke (zbraň na zemi – ak ju Ricco má, vyberie z nej náboje)
func _spawn_drum() -> void:
	var at := get_node_or_null(^"DrumSpot") as Node2D
	if at == null:
		return
	var d := WEAPON_PICKUP.new()
	d.weapon = TOMMY
	d.ammo = DRUM_AMMO
	add_child(d)
	d.global_position = at.global_position


func _read_telegram() -> void:
	await ReadCard.open(self, TELEGRAM).closed
	await ThoughtBox.think(self, TELEGRAM_THOUGHT).finished


# ---------------------------------------------------------------- herňa

## Lampa nad pokrovým stolom zhasla – poručíci sa zľaknú a idú sa pozrieť
func _tick_poker() -> void:
	if _poker_dark:
		return
	var lamp := get_node_or_null(^"PokerLamp")
	if lamp == null or not lamp.get(&"_off"):
		return
	_poker_dark = true
	var said: bool = false
	for i in range(1, 5):
		var g := get_node_or_null(NodePath("Lieutenant%d" % i)) as Gangster
		if g and g.state != Gangster.State.DEAD:
			g.hear(lamp.global_position)
			if not said:
				said = true
				_speak(g, "WHO KILLED THE LIGHTS?!")


# ---------------------------------------------------------------- Sal

func _tick_sal() -> void:
	if _sal_down:
		return
	if not is_instance_valid(_sal) or _sal.state == Gangster.State.DEAD:
		_on_sal_down()
		return
	_sal_hp = _sal.health
	var st: int = int(_sal.state)
	if not _fight and st >= AWARE_FROM and st <= AWARE_TO:
		_fight = true
		_speak(_sal, "SO YOU'RE THE BIRD EVERYBODY'S SQUAWKIN' ABOUT!")


func _on_sal_down() -> void:
	_sal_down = true
	var quiet: bool = _sal_hp >= _sal.max_health if is_instance_valid(_sal) else false
	say("LIGHTS OUT, SAL. NOT EVEN A PEEP." if quiet else "SAL'S DONE SINGIN', KID.")
	say("CHECK THE SAFE. A RAT LIKE SAL\nKEEPS HIS SECRETS IN STEEL.")
	var safe := get_node_or_null(^"SafeSpot") as InteractSpot
	if safe:
		safe.monitoring = true
		safe.set_process(true)


## Trezor: pozvánka a list od „M.“, potom fotka ženy v závoji – duch Dona ten závoj pozná
func _open_safe() -> void:
	if _safe_open:
		return
	_safe_open = true
	var s := get_node_or_null(^"Safe") as Sprite2D
	if s:
		s.texture = SAFE_OPEN
	Sfx.play(&"slot_open", player.global_position, -2.0)
	await ReadCard.open(self, INVITE).closed
	await ReadCard.open(self, PHOTO).closed
	bark("THAT VEIL...\nI KNOW THAT VEIL.")
	await _wait(3.0)
	await ThoughtBox.think(self, SAFE_THOUGHT).finished
	_window_open = true
	var wb := get_node_or_null(^"WindowBlock/Shape") as CollisionShape2D
	if wb:
		wb.set_deferred(&"disabled", true)
	Sfx.play(&"door_open", Vector2(-1350.0, UP - 40.0), -6.0)
	say("OUT THE WINDOW, KID.\nWE GOT A PARTY TO CRASH.")


## Kancelária sa zamkne: Sal za prevráteným stolom, bodyguard otočený k dverám (quiet = už pri načítaní scény)
func _lock_office(quiet: bool) -> void:
	if _locked or _sal_down or not is_instance_valid(_sal):
		return
	var p: Vector2 = player.global_position
	if p.x > OFFICE.x and p.x < OFFICE.y and p.y < -100.0:
		return   # Ricco už je vnútri
	_locked = true
	var door := get_node_or_null(^"OfficeDoor")
	if door:
		door.set_locked(true, quiet)
	var desk := get_node_or_null(^"Desk")
	if desk:
		desk.flip(quiet)
	if quiet:
		_sal.global_position.x = -1080.0
		_sal.call(&"_set_facing", 1.0)
		_sal.home_facing = 1.0
	else:
		_sal.goto_x = -1080.0
		_speak(_sal, "LOCK THAT DOOR! NOBODY GETS IN!")
	var bg := get_node_or_null(^"Bodyguard") as Gangster
	if bg and bg.state != Gangster.State.DEAD:
		bg.home_facing = 1.0
		bg.call(&"_set_facing", 1.0)
		bg.look_back = Vector2.ZERO


# ---------------------------------------------------------------- poplach

func _on_alarm() -> void:
	_once(&"back_alarm", "THEY KNOW YOU'RE HERE, KID.\nSAL'S GONNA HOLE UP IN THAT OFFICE.")
	_lock_office(false)
	_reinforce()


func _reinforce() -> void:
	await _wait(3.0)
	if player == null or player.get(&"state") == 3:
		return
	var kinds := [[TOMMY_G, {}], [GANG, {"kind": "tux", "weapon": preload("res://weapons/pistol/pistol.tres"), "pellets": 1,
			"spread_deg": 3.0, "bullet_lifetime": 1.4, "preferred_range": 0.0, "walk_speed": 30.0}]]
	var pts := reinforce_points(2)
	for i in pts.size():
		spawn_reinforcement(kinds[i][0], pts[i], kinds[i][1])


# ---------------------------------------------------------------- koniec

func _on_exit_window() -> void:
	if not _window_open:
		return
	player.set_cutscene(true)
	bark("SUBTLE AS A BRASS BAND, KID." if club_loud or alarm_on else "QUIET AS A CHURCH MOUSE, KID.")
	await _wait(2.6)
	_to_be_continued()
