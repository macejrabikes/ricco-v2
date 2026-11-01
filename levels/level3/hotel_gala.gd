extends ClubLevel
## Kapitola III – časť 8: gala „M.“ v Starlight Room hotela Majestic a strecha s nápisom MAJESTIC.
## Scéna hotel_gala.tscn (píše ju _art_src/make_hotel_gala_scene.py). Ricco ide zo západu na východ a hore na strechu.
##   Špajza čašníkov – služobné dvere z predsiene (časť 7), čašníci s tácami, kapitán čašníkov. Rebrík hore na balkón.
##   Starlight Room – kapela a Lark Lavelle pod balkónom, tanečný parket, tri lustre (drop_weight.gd), dlhý stôl rodín:
##      sedem bossov (boss.gd – nebojujú, pri poplachu sa skrčia), ich bodyguardi, deviata prázdna stolička
##      s modrým závojom a menovkou „M.“ (READ). Iron Mike pri stole predná prípitok (len raz – toast_done) a odíde.
##   Schodisko – tri rebríky cez medziposchodia hore na strechu.
##   Strecha – obrí nápis MAJESTIC: písmená visia pod lávkou (drop_weight.gd – klobúk / guľka a padnú na mafiánov),
##      na lávke odstreľovač so Springfieldom (2 kúsky pizze). Poistková skriňa nápisu (hat_lamp.gd) – keď zhasne,
##      pod nápisom je tma. Na západnom konci strechy výhľad na nedostavanú vežu Iron Mikea so vzducholoďou → časť 9 (tower.gd).
## Poplach (ClubLevel) len v sále a špajzi. hotel_loud (poplach v časti 7) = v špajzi čakajú dvaja navyše.
## Checkpointy (Level3.checkpoint): 26 = špajza, 27 = sála (balkón), 28 = schodisko, 29 = strecha.
## Godot docs: classes/class_tween, classes/class_sprite2d

const GALA_MAP := Rect2i(-20, -660, 1920, 740)
const ROOF_Y := -330.0
const STAIR_X := 1720.0                    ## x východnej steny sály – za ňou schodisko
const GANG := "res://characters/gangster/gangster_coppola.tscn"
const TOMMY_G := "res://characters/gangster/gangster_tommy.tscn"
const PISTOL := preload("res://weapons/pistol/pistol.tres")
const PLACE_CARD := preload("res://levels/level3/art/gala/place_card_big.png")
const TUX_PROPS := {"kind": "tux", "weapon": PISTOL, "pellets": 1, "spread_deg": 3.0, "bullet_lifetime": 1.4,
		"preferred_range": 0.0, "walk_speed": 30.0}

const ARRIVE_GALA: Array[String] = [
	"The Starlight Room. Champagne, a big band and every crook with a tuxedo.",
	"Eight families at one table. And one chair nobody sits in.",
]
const CARD_THOUGHT: Array[String] = [
	"'M.' Nine chairs in this city. One of them was always hers.",
	"Hers. The veil, the blue linen, the lady who's particular...",
]
const TOAST: Array[String] = [
	"LADIES AND GENTLEMEN... THE FAMILIES OF NEW YORK!",
	"TO M.! WHO COULDN'T BE WITH US TONIGHT.",
	"THE OLD DON IS IN THE GROUND. HIS CITY NEEDS NEW OWNERS.",
	"MY TOWER TOPS OUT AT DAWN. SEE YOU ALL AT THE TOP!",
]
const END_THOUGHT: Array[String] = [
	"Iron Mike's tower. Steel all the way to the clouds, and a zeppelin tied to the top.",
	"He carried the Don's coffin. Now he's carving up the Don's city.",
	"Next stop: the top floor.",
]

var _mike: Sprite2D
var _toast_running: bool = false
var _sign_dark: bool = false
var _ending: bool = false


func _ready() -> void:
	var black := _setup(GALA_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 26)
	exits = PackedFloat32Array([0.0, STAIR_X - 20.0])
	_mike = get_node_or_null(^"IronMike") as Sprite2D
	if toast_done and _mike:
		_mike.queue_free()
		_mike = null
	var card := get_node_or_null(^"PlaceCardSpot") as InteractSpot
	if card:
		card.used.connect(_read_card)
	_connect(^"ToastTrigger", _start_toast)
	_connect(^"ToastTriggerUp", _start_toast)
	_connect(^"BalconyBark", func(): _once(&"gala_balcony", "THREE CHANDELIERS, KID.\nA HAT TO THE CHAIN - AND DOWN THEY COME."))
	_connect(^"TableBark", func(): _once(&"gala_table", "THE BOSSES DON'T FIGHT. THEIR BOYS DO.\nCHECK THAT EMPTY CHAIR."))
	_connect(^"StairBark", func(): _once(&"gala_stairs", "SERVICE STAIRS TO THE ROOF.\nWHERE THERE'S A VIEW, THERE'S A SNIPER."))
	_connect(^"RoofBark", func(): _once(&"gala_roof", "RIFLE UP ON THE SIGN. KILL THE SIGN'S FUSE BOX\nAND HE'S SHOOTIN' AT SHADOWS."))
	_connect(^"LetterBark", func(): _once(&"gala_letters", "THOSE LETTERS HANG BY A BOLT EACH.\nA HAT DOES WONDERS."))
	for cp in [27, 28, 29]:
		var n: int = cp
		_connect(NodePath("Checkpoint%d" % n), func(): checkpoint = maxi(checkpoint, n))
	_connect(^"Checkpoint27Up", func(): checkpoint = maxi(checkpoint, 27))
	_connect(^"EndView", _on_end_view)
	_club_ready()
	_crowd = Sfx.loop(&"crowd", self, Vector2.INF, -16.0) as AudioStreamPlayer
	if hotel_loud:
		_pantry_guards()
	_fade_in(black)
	if checkpoint == 26 and not gala_arrived:
		gala_arrived = true
		_arrive_gala()


func _arrive_gala() -> void:
	player.set_cutscene(true)
	await _wait(0.8)
	player.set_cutscene(false)
	await ThoughtBox.think(self, ARRIVE_GALA).finished
	if hotel_loud:
		_once(&"gala_loud", "THEY HEARD US DOWNSTAIRS, KID.\nTHE PANTRY'S CROWDED.")


## Poplach len v sále a v špajzi (schodisko a strecha nie)
func _in_club(pos: Vector2) -> bool:
	return pos.x < STAIR_X and pos.y > ROOF_Y + 10.0


func _club_tick(delta: float) -> void:
	super._club_tick(delta)
	_tick_sign()


## hotel_loud: dvaja bodyguardi navyše pri dverách do sály
func _pantry_guards() -> void:
	for x in [230.0, 270.0]:
		var g := (load(GANG) as PackedScene).instantiate() as Gangster
		for k in TUX_PROPS:
			g.set(k, TUX_PROPS[k])
		g.respawn_time = 0.0
		g.stationary = true
		g.start_facing = -1.0
		g.needs_light = true
		g.position = Vector2(x, 0.0)
		add_child(g)
		if g.rig:
			g.rig.modulate = NIGHT


# ---------------------------------------------------------------- deviata stolička

func _read_card() -> void:
	await ReadCard.open(self, PLACE_CARD).closed
	await ThoughtBox.think(self, CARD_THOUGHT).finished
	bark("THAT VEIL, KID. I BURIED A WOMAN\nIN THAT VEIL. OR I THOUGHT I DID.")


# ---------------------------------------------------------------- prípitok Iron Mikea

func _start_toast() -> void:
	if toast_done or _toast_running or _mike == null:
		return
	_toast_running = true
	toast_done = true
	Sfx.play(&"glass_break", _mike.global_position + Vector2(0, -50), -18.0, 0.3)   # cink lyžičkou o pohár
	_mike.frame = 1
	for line in TOAST:
		if alarm_on or not is_instance_valid(_mike):
			break
		_speak(_mike, line, 92.0)
		await _wait(3.4)
	if is_instance_valid(_mike):
		_mike.frame = 0
		if alarm_on:
			_speak(_mike, "SHOW'S OVER, BOYS! KEEP HIM BUSY.", 92.0)
		_mike_leaves()
	await _wait(1.0)
	say("IRON MIKE. HE CARRIED MY COFFIN, KID.\nAND HE WAS SMILIN' UNDER THAT MUSTACHE.")


## Iron Mike odíde k východným dverám (schodisko na strechu – k vzducholodi)
func _mike_leaves() -> void:
	var m := _mike
	_mike = null
	m.flip_h = false
	var tw := m.create_tween()
	var dist: float = STAIR_X - 10.0 - m.global_position.x
	tw.tween_property(m, "global_position:x", STAIR_X - 10.0, maxf(dist, 1.0) / 40.0)
	tw.parallel().tween_method(func(t: float): m.frame = int(t * 8.0) % 2 * 3, 0.0, dist / 40.0, dist / 40.0)
	tw.tween_property(m, "modulate:a", 0.0, 0.4)
	tw.tween_callback(m.queue_free)
	Sfx.play(&"door_open", Vector2(STAIR_X, -40.0), -8.0)


# ---------------------------------------------------------------- strecha

## Poistková skriňa nápisu zhasla – písmená stmavnú (svetlo pod nápisom zhaslo samo – LightZone v skrini)
func _tick_sign() -> void:
	if _sign_dark:
		return
	var fuse := get_node_or_null(^"SignFuse")
	if fuse == null or not fuse.get(&"_off"):
		return
	_sign_dark = true
	Sfx.play(&"metal_crash", (fuse as Node2D).global_position, -14.0, 0.1)
	for i in range(1, 9):
		var l := get_node_or_null(NodePath("Letter%d/Weight/Sprite" % i)) as CanvasItem
		if l:
			l.modulate = Color(0.45, 0.4, 0.45)
	var sn := get_node_or_null(^"Sniper") as Gangster
	if sn and sn.state != Gangster.State.DEAD:
		_speak(sn, "HEY! WHO KILLED THE SIGN?!")
		sn.hear(sn.global_position + Vector2(-200.0, 120.0))


## Západný koniec strechy: výhľad na vežu Iron Mikea (vzducholoď sa pri stožiari pohojdáva) – ďalej na vežu (časť 9)
func _on_end_view() -> void:
	if _ending:
		return
	_ending = true
	player.set_cutscene(true)
	var ship := get_node_or_null(^"IronTower/Airship") as Node2D
	if ship:
		var tw := ship.create_tween()
		tw.set_loops(4)
		tw.tween_property(ship, "position", ship.position + Vector2(0.0, -4.0), 1.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ship, "position", ship.position, 1.6).set_trans(Tween.TRANS_SINE)
	await _wait(1.2)
	await ThoughtBox.think(self, END_THOUGHT).finished
	bark("SUBTLE AS A BRASS BAND, KID." if hotel_loud or club_loud or alarm_on else "NOT A PEEP ALL NIGHT. I'M PROUD OF YA.")
	await _wait(2.6)
	_leave_door(TOWER, 30, false)   # dolu z hotela a taxíkom k veži – za svitania
