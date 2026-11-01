extends ClubLevel
## Kapitola III – časť 7: hotel Majestic, servisné krídlo. Scéna hotel.tscn (píše ju _art_src/make_hotel_scene.py).
## Ricco ide z východu na západ a nahor – do služobnej predsiene pred Starlight Room, kde je gala „M.“.
##   Ulička s rampou – dodávka zeleniny, rozvážač, policajt, čo berie od mafie (píšťalka, baterka). Rampou rovno
##      do príjmu tovaru (strážca pri dverách), alebo potichu požiarnym schodiskom oknom na východnú galériu kuchyne.
##   Kuchyňa – kuchári sú svedkovia (pri poplachu utekajú). Háky na panvice pod stropom (ručkovanie ponad hlavy),
##      medené panvice (ricochet_pan.gd – guľka sa odrazí do najbližšieho mafiána), kotol s parným ventilom
##      (steam_valve.gd), sud oleja (whisky_barrel.gd – šmykľavá mláka), stojan na hrnce nad mafiánom pri výdajnom okne
##      (drop_weight.gd). Západná galéria: kancelária šéfkuchára (objednávka na gala – menu_big.png), rebrík na poschodie.
##   Poschodie (izby personálu) – šatňa so spiacim poslíčkom, klopacie dvere do herne policajtov (knock_door.gd),
##      izba slúžok, sklad bielizne s poklopom šachty na bielizeň (dolu do práčovne).
##   Práčovňa – plachty na šnúrach (kryt), parný lis s ventilom, búdka predáka s kľúčom od výťahu. Zamknuté dvere
##      do kuchyne (lock_door.gd – vystreliť = hluk). Poklop v podlahe → plazivý tunel do šachty výťahu.
##   Nákladný výťah (service_elevator.gd) – kým žije liftboy, jazdí sám; potom ho ovláda Ricco (panel, privolávače).
##      Do predsiene (3. zastávka) treba kľúč. Alebo šachtou: rebrík okolo protiváhy hore do strojovne a dierou
##      v podlahe strojovne dolu do predsiene – za chrbát vrátnikom.
## Poplach (ClubLevel): kuchári a slúžky utekajú, mafiáni vedia o Riccovi, prídu posily; hotel_loud ide do galy.
## Checkpointy (Level3.checkpoint): 22 = ulička, 23 = príjem / východná galéria, 24 = poschodie, 25 = práčovňa.
## Godot docs: classes/class_tween, classes/class_area2d

const HOTEL_MAP := Rect2i(660, -700, 2300, 840)
const INSIDE_X := 2290.0                   ## x hrany hotela – východne je ulička (poplach v hoteli sa jej netýka)
const GANG := "res://characters/gangster/gangster_coppola.tscn"
const TOMMY_G := "res://characters/gangster/gangster_tommy.tscn"
const PISTOL := preload("res://weapons/pistol/pistol.tres")
const MENU := preload("res://levels/level3/art/hotel/menu_big.png")
const KEY := preload("res://levels/level3/art/hotel/key_big.png")
const KEY_BOARD_EMPTY := preload("res://levels/level3/art/hotel/key_board_empty.png")

const ARRIVE_HOTEL: Array[String] = [
	"The Majestic. Forty floors of marble out front, garbage cans and grease in the back.",
	"The gala's upstairs in the Starlight Room. The staff goes up in the freight car.",
]
const MENU_THOUGHT: Array[String] = [
	"Table one, nine covers. Eight families and one empty chair with a blue napkin.",
	"Seat nine: 'M.' No shellfish. The lady is particular.",
]
const KEY_THOUGHT: Array[String] = [
	"The freight car key. Roof and gala floor.",
]

var _lift: Node
var _liftman_down: bool = false
var _key_spot: InteractSpot


func _ready() -> void:
	var black := _setup(HOTEL_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 22)
	exits = PackedFloat32Array([830.0, 2290.0])
	_lift = get_node_or_null(^"Lift")
	if _lift:
		_lift.locked.connect(_on_lift_locked)
		if lift_key:
			_lift.set(&"has_key", true)
	_key_spot = get_node_or_null(^"KeySpot") as InteractSpot
	if _key_spot:
		_key_spot.used.connect(_take_key)
		if lift_key:
			_key_taken_visual()
	var order := get_node_or_null(^"OrderSpot") as InteractSpot
	if order:
		order.used.connect(_read_menu)
	var door := get_node_or_null(^"LaundryDoor")
	if door:
		door.set_locked(true, true)
		door.broken.connect(func():
			hotel_loud = true
			say("SUBTLE. THE WHOLE KITCHEN HEARD THAT."))
	var rack := get_node_or_null(^"PotRack")
	if rack:
		rack.landed.connect(func(kills: int):
			if kills > 0:
				say("SOUP'S ON."))
	_connect(^"DockBark", func(): _once(&"dock", "COP ON THE TAKE. HE WATCHES THE DOCK\nFOR THE FAMILIES. FIRE ESCAPE'S QUIETER."))
	_connect(^"HooksBark", func(): _once(&"hooks", "POT HOOKS UNDER THE CEILING, KID.\nHANG ON AND GO OVER THEIR HEADS."))
	_connect(^"PansBark", func(): _once(&"pans", "COPPER PANS. SHOOT ONE AND THE SLUG\nBOUNCES INTO THE NEAREST HOOD."))
	_connect(^"SteamBark", func(): _once(&"steam", "STEAM VALVE ON THAT KETTLE.\nPOP IT AND WATCH HIM HOP."))
	_connect(^"OilBark", func(): _once(&"oil", "FRYER OIL. SHOOT THE DRUM -\nNOBODY STAYS ON HIS FEET IN THAT."))
	_connect(^"RackBark", func(): _once(&"rack", "HEAVY POT RACK ON A CHAIN.\nRIGHT OVER THAT SHOTGUN."))
	_connect(^"KnockBark", func(): _once(&"cops", "COPS PLAYIN' CARDS ON THE FAMILY'S DIME.\nKNOCK (%s) - ONE AT A TIME." % KeyBindings.short(&"takedown")))
	_connect(^"ChuteBark", func(): _once(&"chute", "LINEN CHUTE. GOES STRAIGHT DOWN\nTO THE LAUNDRY. SOFT LANDING."))
	_connect(^"LaundryBark", func(): _once(&"laundry", "THE FOREMAN'S GOT THE LIFT KEY.\nSHEETS ON THE LINES - GOOD COVER."))
	_connect(^"PitBark", func(): _once(&"pit", "THAT HATCH GOES UNDER THE SHAFT.\nCRAWL THROUGH (%s)." % KeyBindings.short(&"slide")))
	_connect(^"ShaftBark", func(): _once(&"shaft", "COUNTERWEIGHT RIDES THIS SHAFT.\nDON'T BE UNDER IT WHEN IT MOVES - RIDE IT."))
	_connect(^"MachineBark", func(): _once(&"machine", "HOLE IN THE FLOOR. THE GALA DOOR'S\nRIGHT UNDER IT - AND TWO GORILLAS."))
	_connect(^"LiftBark", func(): _once(&"lift", "FREIGHT CAR. THE LIFTBOY'S\nON THE FAMILY PAYROLL TOO."))
	_connect(^"Checkpoint23", func(): checkpoint = maxi(checkpoint, 23))
	_connect(^"Checkpoint23Up", func(): checkpoint = maxi(checkpoint, 23))
	_connect(^"Checkpoint24", func(): checkpoint = maxi(checkpoint, 24))
	_connect(^"Checkpoint25", func(): checkpoint = maxi(checkpoint, 25))
	_connect(^"Checkpoint25Up", func(): checkpoint = maxi(checkpoint, 25))
	_connect(^"ExitGala", _on_exit_gala)
	_club_ready()
	Sfx.music(&"rainy_noir")
	var kitchen := get_node_or_null(^"KitchenSound") as Node2D
	if kitchen:
		Sfx.loop(&"kitchen", kitchen, Vector2.ZERO, -10.0)   # 2D – počuť ju len pri kuchyni
	_fade_in(black)
	if checkpoint == 22 and not hotel_arrived:
		hotel_arrived = true
		_arrive_hotel()


func _arrive_hotel() -> void:
	player.set_cutscene(true)
	await _wait(0.8)
	player.set_cutscene(false)
	await ThoughtBox.think(self, ARRIVE_HOTEL).finished
	if club_loud:
		_once(&"hotel_word", "WORD OF SAL GOT HERE BEFORE US.\nEYES OPEN, KID.")


## Poplach len vnútri hotela – ulička má svojho policajta (píšťalka)
func _in_club(pos: Vector2) -> bool:
	return pos.x < INSIDE_X


func _club_tick(delta: float) -> void:
	super._club_tick(delta)
	if not _liftman_down and not alive(^"Liftman"):
		_liftman_down = true
		say("THE LIFT'S ALL YOURS. PANEL INSIDE,\nCALL BUTTONS BY THE DOORS.")


# ---------------------------------------------------------------- kľúč, objednávka, výťah

func _read_menu() -> void:
	await ReadCard.open(self, MENU).closed
	await ThoughtBox.think(self, MENU_THOUGHT).finished


## Tabuľka s kľúčmi v búdke predáka práčovne: kľúč od nákladného výťahu (3. zastávka – gala)
func _take_key() -> void:
	if lift_key:
		return
	lift_key = true
	if _lift:
		_lift.set(&"has_key", true)
	_key_taken_visual()
	Sfx.play(&"pickup_ammo", player.global_position, -4.0)
	await ReadCard.open(self, KEY).closed
	await ThoughtBox.think(self, KEY_THOUGHT).finished


func _key_taken_visual() -> void:
	var b := get_node_or_null(^"KeyBoard") as Sprite2D
	if b:
		b.texture = KEY_BOARD_EMPTY
	if _key_spot:
		_key_spot.monitoring = false
		_key_spot.set_process(false)


func _on_lift_locked(_stop: int) -> void:
	if lift_key:
		return
	_once(&"lift_key", "TOP STOP NEEDS A KEY, KID.\nTHE LAUNDRY FOREMAN KEEPS 'EM ON A BOARD.")


# ---------------------------------------------------------------- poplach

func _on_alarm() -> void:
	hotel_loud = true
	_once(&"hotel_alarm", "THAT'S THE WHOLE KITCHEN SCREAMIN'.\nMORE OF 'EM COMIN', KID.")
	_reinforce()


func _reinforce() -> void:
	await _wait(3.0)
	if player == null or player.get(&"state") == 3:
		return
	var kinds := [[TOMMY_G, {}], [GANG, {"kind": "tux", "weapon": PISTOL, "pellets": 1, "spread_deg": 3.0,
			"bullet_lifetime": 1.4, "preferred_range": 0.0, "walk_speed": 30.0}]]
	var pts := reinforce_points(2)
	for i in pts.size():
		spawn_reinforcement(kinds[i][0], pts[i], kinds[i][1])


# ---------------------------------------------------------------- koniec

## Služobné dvere do Starlight Room – časť 8 (hotel_gala.tscn)
func _on_exit_gala() -> void:
	bark("QUIET AS A CHURCH MOUSE, KID." if not hotel_loud and not alarm_on else "WELL, THEY KNOW WE'RE COMIN'.")
	_leave_door(HOTEL_GALA, 26)
