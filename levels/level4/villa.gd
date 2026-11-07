extends Level4
## Kapitola IV – časť 5: vila Vito (scéna villa.tscn – píše ju _art_src/make_villa_scene.py, obrázky
## _art_src/make_ch4_villa_art.py, rozloženie _art_src/villa_layout.py). Prierez domom 5600 × 1100, poschodia po 220 px:
##   G 1000 prízemie – vestibul (príchod z pivnice), jedáleň (dva lustre, slúžka), salón (krb, komorník),
##        biliard, kuchyňa (kuchárka, mäsiar, výťah na jedlo);
##   U1 780 – izby pre hostí, galéria portrétov (lustre, hliadky s baterkami), hudobný salón, izby služobníctva;
##   U2 560 – Margaretina pracovňa (list od „C.“ – READ), budoár (ochranka vo vestách), zimná záhrada (mesiac cez sklo),
##        podkrovie (rebrík cez poklop na strechu);
##   R 340 – strecha so stožiarom a vzducholoďou IRON, kupola so zrkadlovou sieňou (boss Margaret – mirror_hall.gd).
## Átrium 2000–3600 cez tri poschodia: schodiská cik-cak (levels/level4/stairs.gd – v pozadí, naskočí sa skokom),
## mostík na U2 nesie obrí luster (drop_weight.gd – reťaz prestreliť → zmetie prízemie), hore schody A3 rovno do siene.
## Tichá cesta: výťah na jedlo z kuchyne do podkrovia → rebrík → strecha → sklenené dvere do siene.
## Svedkovia (slúžky, komorník, kuchárka – world/npc/guest.gd, waiter.gd) vidia Ricca na svetle a privolajú mafiánov.
## Checkpointy (Level4.checkpoint): 8 = príchod, 9 = prvé poschodie, 10 = druhé poschodie.
## Godot docs: classes/class_area2d, classes/class_tween

const VILLA_MAP := Rect2i(0, 0, 5600, 1100)
const LETTER := preload("res://levels/level4/art/letter_big.png")

const ARRIVE_VILLA: Array[String] = [
	"Grandpa's money, wall to wall. And not one picture of him in the hall.",
	"She's up there somewhere. Under the glass.",
]
const LETTER_THOUGHT: Array[String] = [
	"\"C.\" Same initials as in that ledger.",
	"So the widow takes orders too. From Chicago.",
]
const HALL_THOUGHT: Array[String] = [
	"Mirrors. A hundred of her, and only one of 'em bleeds.",
]

var _dumb_busy: bool = false


func _ready() -> void:
	var black := _setup(VILLA_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 8)
	_connect(^"DiningBark", func(): _once(&"vil_dining", "TWENTY CHAIRS AND SHE EATS ALONE.\nTHE MAIDS WILL SCREAM - STAY IN THE DARK."))
	_connect(^"AtriumBark", func(): _once(&"vil_stairs", "MY GRAND HALL. JUMP (%s) ONTO THE STAIRS -\nTHEY GO ALL THE WAY UP TO HER." % KeyBindings.short(&"jump")))
	_connect(^"ChandelierBark", func(): _once(&"vil_chandelier", "I HUNG THAT CHANDELIER FOR OUR WEDDING.\nSHOOT THE CHAIN, KID."))
	_connect(^"KitchenBark", func(): _once(&"vil_kitchen", "THE DUMBWAITER GOES UP TO THE ATTIC.\nQUIETER THAN THE STAIRS."))
	_connect(^"GalleryBark", func(): _once(&"vil_gallery", "THAT'S ME IN 1902.\nHANDSOME DEVIL, WASN'T I?"))
	_connect(^"BoudoirBark", func(): _once(&"vil_boudoir", "HER PERFUME. SAME ONE SHE WORE\nAT MY FUNERAL."))
	_connect(^"WinterBark", func(): _once(&"vil_winter", "GLASS ALL AROUND.\nTHE MOON GIVES YOU AWAY IN HERE."))
	_connect(^"RoofBark", func(): _once(&"vil_roof", "THE IRON. SHE'S GOT A ZEPPELIN\nPARKED ON MY ROOF."))
	for p in [^"Checkpoint9a", ^"Checkpoint9b"]:
		_connect(p, func(): checkpoint = maxi(checkpoint, 9))
	for p in [^"Checkpoint10a", ^"Checkpoint10b", ^"Checkpoint10c"]:
		_connect(p, func(): checkpoint = maxi(checkpoint, 10))
	_connect(^"HallEnter", _mirror_hall)
	var door := get_node_or_null(^"MirrorDoorSpot") as InteractSpot
	if door:
		door.used.connect(_mirror_hall)
	var letter := get_node_or_null(^"LetterSpot") as InteractSpot
	if letter:
		letter.used.connect(_read_letter)
	var up := get_node_or_null(^"DumbwaiterSpotG") as InteractSpot
	if up:
		up.used.connect(_ride_dumbwaiter.bind(true))
	var down := get_node_or_null(^"DumbwaiterSpotU2") as InteractSpot
	if down:
		down.used.connect(_ride_dumbwaiter.bind(false))
	var grand := get_node_or_null(^"GrandChandelier")
	if grand:
		grand.connect(&"landed", _on_grand_chandelier)
	Sfx.music(&"night_cafe")
	_fade_in(black)
	if not villa_arrived:
		villa_arrived = true
		_arrive_villa()


func _arrive_villa() -> void:
	await _wait(0.8)
	await ThoughtBox.think(self, ARRIVE_VILLA).finished


## Výťah na jedlo: dvierka sa otvoria, Ricco sa vtesná dnu, stmievačka, vyjde o dve poschodia vyššie / nižšie
func _ride_dumbwaiter(going_up: bool) -> void:
	if _dumb_busy or _leaving:
		return
	_dumb_busy = true
	var from_door := get_node_or_null(^"DumbwaiterG" if going_up else ^"DumbwaiterU2") as Sprite2D
	var to_door := get_node_or_null(^"DumbwaiterU2" if going_up else ^"DumbwaiterG") as Sprite2D
	var to := get_node_or_null(^"DumbwaiterOutU2" if going_up else ^"DumbwaiterOutG") as Node2D
	if to == null:
		_dumb_busy = false
		return
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	if from_door:
		from_door.frame = 1
	Sfx.play(&"door_open", player.global_position, -10.0, 0.1)
	var black := _fade_rect()
	var tw := create_tween()
	tw.tween_property(player, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(black, "color:a", 1.0, 0.4)
	await tw.finished
	if from_door:
		from_door.frame = 0
	Sfx.play(&"chain_rattle", to.global_position, -14.0)
	player.global_position = to.global_position
	player.velocity = Vector2.ZERO
	pcam.teleport_position()
	await _wait(0.6)
	if to_door:
		to_door.frame = 1
	var tw2 := create_tween()
	tw2.tween_property(black, "color:a", 0.0, 0.4)
	tw2.parallel().tween_property(player, "modulate:a", 1.0, 0.4)
	await tw2.finished
	black.get_parent().queue_free()
	if to_door:
		to_door.frame = 0
	player.set_cutscene(false)
	_dumb_busy = false
	if going_up:
		_once(&"vil_attic", "THE ATTIC. THERE'S A HATCH TO THE ROOF -\nAND A GLASS DOOR STRAIGHT INTO HER HALL.")


## List na písacom stole v Margaretinej pracovni (od „C.“ z Chicaga)
func _read_letter() -> void:
	Sfx.play(&"pickup_ammo", player.global_position, -10.0)
	await ReadCard.open(self, LETTER).closed
	await ThoughtBox.think(self, LETTER_THOUGHT).finished


func _on_grand_chandelier(kills: int) -> void:
	if kills > 0:
		say("THAT WAS A WEDDING PRESENT.\nWORTH IT.")
	else:
		say("SEVEN HUNDRED CRYSTALS... AND YOU MISSED.")


## Zrkadlová sieň (schody A3 alebo sklenené dvere zo strechy) – boss Margaret (časť 6 – mirror_hall.gd)
func _mirror_hall() -> void:
	if _leaving:
		return
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	await ThoughtBox.think(self, HALL_THOUGHT).finished
	_leave_door(MIRROR_HALL, 11, false)
