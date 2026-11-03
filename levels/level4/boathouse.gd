extends Level4
## Kapitola IV – časť 3: lodenica v jaskyni pod sídlom a nákladný výťah do vínnej pivnice
## (scéna boathouse.tscn – píše ju _art_src/make_boathouse_scene.py).
## Ricco prichádza chodbou z jaskyne dverami na podkroví (vpravo) a ide doľava k šachte s výťahom:
##   podkrovie C – kartári pod lampou (zhasnúť klobúkom), bedne; rebrík hore na trámy (tichá cesta ponad všetkých)
##               alebo dierou v podlahe dolu
##   sklz 2 – čln WIDOW na vode, luparista pri bedniach
##   sklz 1 – čln LADY M. na reťazovom zdviháku nad lávkou, kde pracujú dvaja mechanici (drop_weight.gd – prestreľ reťaz)
##   podkrovie B – nádrž s palivom (ship_barrel.gd): výbuch → potrubím aj dole pri pumpe (PumpSpot), strážca s výhľadom
##   suchý dok – VITO III na podperách, lešenie s mechanikmi, Thompson na podlahe
##   dielňa – sudy benzínu (výbušné), Thompson; podkrovie A – prične, spiaci pašerák (passive – zneškodniť zozadu)
##   šachta – kabína nákladného výťahu: F GO UP → kabína ide hore → pivnica vily (časť 4 – cellar.gd, checkpoint 5).
## Checkpointy (Level4.checkpoint): 3 = dvere na podkroví, 4 = suchý dok (podkrovie B / podlaha pri farbách).
## Godot docs: classes/class_animatablebody2d, classes/class_tween

const BOATHOUSE_MAP := Rect2i(0, 160, 2300, 640)
const LIFT_RISE := 360.0          ## px – o koľko kabína vyjde hore, kým sa obraz stmaví

const ARRIVE_BOATHOUSE: Array[String] = [
	"A boathouse inside the cliff. Lou's boats, Margaret's rum. My money.",
	"That freight lift goes straight up into the house. Into her wine cellar.",
]
const LIFT_THOUGHT: Array[String] = [
	"Up we go. Time to pay my respects to the widow.",
]

var _riding: bool = false


func _ready() -> void:
	var black := _setup(BOATHOUSE_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 3)
	_connect(^"BoathouseBark", func(): _once(&"bh_start", "CARDS UNDER A LAMP. YOU KNOW WHAT\nTO DO WITH A LAMP, KID."))
	_connect(^"BeamBark", func(): _once(&"bh_beams", "BEAMS UNDER THE ROOF. CLIMB UP -\nNOBODY EVER LOOKS UP."))
	_connect(^"BoatBark", func(): _once(&"bh_boat", "THAT BOAT'S HANGIN' ON ONE CHAIN\nOVER TWO GREASE MONKEYS."))
	_connect(^"FuelBark", func(): _once(&"bh_fuel", "FUEL TANK UP THERE, A PIPE DOWN TO THE PUMP.\nYOU DO THE MATH."))
	_connect(^"ShaftBark", func(): _once(&"bh_lift", "THE FREIGHT LIFT. GOES STRAIGHT UP\nINTO HER WINE CELLAR."))
	_connect(^"Checkpoint4", func(): checkpoint = maxi(checkpoint, 4))
	var tank := get_node_or_null(^"FuelTank")
	if tank:
		tank.connect(&"exploded", _on_tank_exploded)
	var boat := get_node_or_null(^"LadyM")
	if boat:
		boat.connect(&"landed", _on_boat_landed)
	var spot := get_node_or_null(^"Lift/LiftSpot") as InteractSpot
	if spot:
		spot.used.connect(_ride_up)
	Sfx.loop(&"docks", self, Vector2(2300, 700), -12.0)
	Sfx.music(&"desolation")
	_fade_in(black)
	if not boathouse_arrived:
		boathouse_arrived = true
		_arrive_boathouse()


func _arrive_boathouse() -> void:
	await _wait(0.8)
	await ThoughtBox.think(self, ARRIVE_BOATHOUSE).finished


func _on_boat_landed(kills: int) -> void:
	if kills > 0:
		say("LADY M. JUST DOCKED. HARD.")


## Nádrž s palivom vybuchla – oheň prebehne potrubím a o chvíľu vybuchne aj pumpa dole pri sklze
func _on_tank_exploded() -> void:
	var pump := get_node_or_null(^"PumpSpot") as Node2D
	if pump == null:
		return
	var pos: Vector2 = pump.global_position
	await _wait(0.45)
	Explosion.spawn(get_tree().current_scene, pos, 1.6, 2, 4.0, 56.0)
	_once(&"bh_boom", "AND THAT'S THE MATH.")


## Kabína výťahu: Ricco nastúpi, mreža sa zatvorí, kabína ide hore šachtou → pivnica vily (časť 4)
func _ride_up() -> void:
	if _riding or _leaving:
		return
	_riding = true
	var lift := get_node_or_null(^"Lift") as Node2D
	if lift == null:
		_go_next(CELLAR, 5)
		return
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	player.global_position.x = lift.global_position.x + 10.0
	var gate := lift.get_node_or_null(^"Gate") as Sprite2D
	if gate:
		gate.frame = 1
	Sfx.play(&"door_close", lift.global_position + Vector2(0, -60), -6.0)
	await ThoughtBox.think(self, LIFT_THOUGHT).finished
	var motor := Sfx.loop(&"crane_motor", lift, Vector2(0, -60), -10.0, &"SFX")
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(lift, "position:y", lift.position.y - LIFT_RISE, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(1.8)
	var black := _fade_rect()
	var fade := create_tween()
	fade.tween_property(black, "color:a", 1.0, 0.8)
	await fade.finished
	if motor:
		motor.queue_free()
	_leaving = true
	_go_next(CELLAR, 5)
