extends Level4
## Kapitola IV – časť 2: jaskyňa pašerákov pod útesom sídla Vito (scéna cave.tscn – píše ju _art_src/make_cave_scene.py).
## Ricco prichádza tunelom z búdy BAIT & TACKLE (tajné dvere za sieťami) a ide doprava k moru:
##   A  prebaľovňa – rum z lode ide na pás (world/coldstore/conveyor.gd) a do debien „MEDICINE“, pašeráci pri páse
##      pod lampami (zhasnúť klobúkom → v tme ho nevidia), luparista. Tichá cesta: z lávky skokom na voľný hák
##      koľajnice pod stropom (world/coldstore/hook_rail.gd – debny rumu namiesto mäsa) a ponad všetkých až na strednú rímsu.
##      Prítok cez nábrežie – prehnitá doska (roof_plank.gd), alebo do vody a rebríkom von. Dokár s hákom a baterkou.
##   B  stredná rímsa a povrazový most (hliadka), bedne a sudy rumu pri kancelárii (ship_barrel.gd – jedna guľka a bum),
##      Thompson pred kanceláriou, kniha s platbami (SEARCH → ledger_big.png: „M.V.“ aj záhadný „C.M.“),
##      doberman na reťazi (world/npc/dog.gd), reflektor na hornej rímse (club_spotlight.gd) prechádza po nábreží,
##      žeriav so sieťou rumu nad dvoma strážcami na móle (drop_weight.gd – prestreľ lano), loď SEA WIDOW.
##   Z mólа rebríkom na lávku pri žeriave a ďalej na hornú rímsu – chodba k lodenici (časť 3 – boathouse.gd).
## Checkpointy (Level4.checkpoint): 1 = tunel z búdy, 2 = stredná rímsa (za koľajnicou s hákmi).
## Godot docs: classes/class_animatablebody2d, classes/class_tween, classes/class_area2d

const CAVE_MAP := Rect2i(0, 160, 2700, 660)
const LEDGER := preload("res://levels/level4/art/ledger_big.png")

const ARRIVE_CAVE: Array[String] = [
	"A smugglers' cave right under her lawn. Half of Long Island's rum comes through this hole.",
	"Lou's boats, the old man's routes. Somebody kept the business running without him.",
]
const LEDGER_THOUGHT: Array[String] = [
	"'M.V.' - Margaret Vito. Twelve grand a run.",
	"And 'C.M.' gets eighteen. Off the top, before the widow. Who the hell is C.M.?",
]

var _bottles: Array[Node2D] = []
var _belt_len: float = 420.0


func _ready() -> void:
	var black := _setup(CAVE_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 1)
	_connect(^"CaveBark", func(): _once(&"cave_start", "SECRET DOOR, SECRET TUNNEL, SECRET RUM.\nNOT MUCH OF A SECRET, KID."))
	_connect(^"HookBark", func(): _once(&"cave_hooks", "HOOKS UNDER THE ROOF. JUMP FOR AN EMPTY ONE\nAND RIDE OVER 'EM LIKE A SIDE OF BEEF."))
	_connect(^"InletBark", func(): _once(&"cave_inlet", "ANOTHER ROTTEN PLANK.\nYOU KNOW THE DRILL - TIPTOE."))
	_connect(^"BarrelBark", func(): _once(&"cave_barrels", "RUM BARRELS NEXT TO THAT GUARD.\nONE BULLET - BIG PARTY."))
	_connect(^"DogBark", func(): _once(&"cave_dog", "A DOBERMAN. HE SMELLS YOU IN THE DARK.\nHAT TO THE HEAD - HE TAKES A NAP."))
	_connect(^"NetBark", func(): _once(&"cave_net", "A NET FULL OF RUM OVER TWO HEADS.\nSHOOT THE ROPE."))
	_connect(^"Checkpoint2", func(): checkpoint = maxi(checkpoint, 2))
	_connect(^"ExitBoathouse", func(): _leave_door(BOATHOUSE, 3, false))
	var spot := get_node_or_null(^"OfficeSpot") as InteractSpot
	if spot:
		spot.used.connect(_read_ledger)
	var net := get_node_or_null(^"CraneNet")
	if net:
		net.landed.connect(_on_net_landed)
	var cv := get_node_or_null(^"Conveyor") as Node2D
	if cv:
		_belt_len = float(cv.get(&"length"))
		for c in cv.get_children():
			if c is AnimatableBody2D:
				_bottles.append(c as Node2D)
	Sfx.loop(&"docks", self, Vector2(2500, 640), -10.0)
	Sfx.music(&"desolation")
	_fade_in(black)
	if not cave_arrived:
		cave_arrived = true
		_arrive_cave()


func _arrive_cave() -> void:
	await _wait(0.8)
	await ThoughtBox.think(self, ARRIVE_CAVE).finished


func _process(delta: float) -> void:
	super._process(delta)
	# fľaše na páse: za koncami pásu ich nevidno (vracajú sa na začiatok)
	for b in _bottles:
		b.visible = b.position.x > 2.0 and b.position.x < _belt_len - 2.0


func _on_net_landed(kills: int) -> void:
	if kills > 0:
		say("RUM ON THE HOUSE, BOYS.")


## Kniha v kancelárii: platby za jazdu SEA WIDOW – „M.V.“ a „C.M.“
func _read_ledger() -> void:
	ledger_read = true
	Sfx.play(&"pickup_ammo", player.global_position, -10.0)
	await ReadCard.open(self, LEDGER).closed
	await ThoughtBox.think(self, LEDGER_THOUGHT).finished
