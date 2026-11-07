extends Level4
## Kapitola IV – časť 4: pivnica vily Vito (scéna cellar.tscn – píše ju _art_src/make_cellar_scene.py).
## Štyri poschodia nad sebou (každé 220 px), medzi nimi schody (pevné 45° rampy, nad nimi železná mreža v podlahe),
## striedavo vpravo / vľavo / vpravo – každé poschodie treba prejsť celé:
##   F0 zatopená stará pivnica – kabína výťahu z lodenice, voda (WaterZone): pod hladinou ho nevidia; plávajúce sudy
##      (levels/level4/bob.gd), dvaja strážcovia sa brodia s baterkami, lampa na kábli nad vodou
##      (levels/level4/water_lamp.gd – prestreliť = spadne do vody a prúd zloží každého vo vode), čerpadlo
##      (levels/level4/pump.gd – hukot prehluší výstrely okolo; F SWITCH OFF alebo prestreliť → voda odtečie, ticho zalarmuje).
##   F1 vínna pivnica – regály a sudy (kryt), čašník, hliadka s baterkou, degustačný stôl. Obrí sud RISERVA DEL DON
##      (vľavo pri schodoch) = tajné dvere: F KNOCK → chodba pod schodmi → šachta s rebríkom v stene až do komôrky
##      za otočnou policou v knižnici (tichá cesta – obíde vinárstvo aj trofejovú izbu).
##   F2 vinárstvo VITO & FIGLI – kade na kvasenie: prestrelený kohútik (levels/level3/whisky_barrel.gd) rozleje víno,
##      kto cez mláku prejde, pošmykne sa; trám s košmi na kladke (world/coldstore/hook_rail.gd – kôš = kryt,
##      voľný hák = vezie sa ponad hlavy; chytiť sa dá z okraja kade alebo zo steny sudov), lis TORCHIO, Thompson.
##   F3 prízemie vily – knižnica (krb, otočná polica), vestibul s dverami GRAND HALL (koniec časti),
##      trofejová izba: dva lustre (drop_weight.gd), doberman na reťazi, hájnik (kind keeper) s Winchestrom,
##      vitrína so Springfieldom (F OPEN → puška vypadne na zem ako weapons/weapon_pickup.gd).
##      Dvere GRAND HALL → vila (villa.tscn, checkpoint 8).
## Checkpointy (Level4.checkpoint): 5 = výťah dole, 6 = vínna pivnica (hore na schodoch), 7 = vinárstvo.
## Godot docs: classes/class_collisionpolygon2d, classes/class_animatablebody2d, classes/class_tween

const CELLAR_MAP := Rect2i(0, 0, 2400, 1000)

const ARRIVE_CELLAR: Array[String] = [
	"The old cellar. Grandpa Vito's. Half of it's under the sea now.",
	"Four floors of stone between me and the widow. Up it is.",
]
const HALL_THOUGHT: Array[String] = [
	"The grand hall. Somewhere up there she's pouring herself a drink.",
]

const SPRINGFIELD := preload("res://weapons/springfield/springfield.tres")
const WEAPON_PICKUP := preload("res://weapons/weapon_pickup.gd")
const CASE_AMMO := 15   ## náboje v puške z vitríny (5 do zásobníka, zvyšok do zálohy)

var _secret_busy: bool = false


func _ready() -> void:
	var black := _setup(CELLAR_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 5)
	_connect(^"CellarBark", func(): _once(&"cel_start", "COLD WATER, KID. DIVE (%s) AND THE FLASHLIGHTS\nWON'T FIND YOU. OR... THAT LAMP ON A WIRE." % KeyBindings.short(&"slide")))
	_connect(^"CaskBark", func(): _once(&"cel_cask", "MY RISERVA. NOBODY TOUCHES THAT BARREL.\nKNOCK ON IT - THREE TIMES, LIKE I USED TO."))
	_connect(^"WineryBark", func(): _once(&"cel_winery", "SHOOT THE TAP ON THAT VAT\nAND THE FLOOR TURNS INTO A SKATING RINK."))
	_connect(^"HookBark", func(): _once(&"cel_hooks", "BASKETS ON A PULLEY. JUMP FROM THE VAT\nFOR AN EMPTY HOOK AND RIDE OVER 'EM."))
	_connect(^"TrophyBark", func(): _once(&"cel_trophy", "TWO CHANDELIERS, ONE GAMEKEEPER.\nYOU KNOW WHAT TO DO WITH A CHANDELIER."))
	_connect(^"ClosetBark", func(): _once(&"cel_closet", "BEHIND THE BOOKCASE. PUSH IT - QUIETLY."))
	_connect(^"Checkpoint6", func(): checkpoint = maxi(checkpoint, 6))
	_connect(^"Checkpoint7", func(): checkpoint = maxi(checkpoint, 7))
	var cask := get_node_or_null(^"CaskSpot") as InteractSpot
	if cask:
		cask.used.connect(_through_cask.bind(true))
	var back := get_node_or_null(^"ShaftSpot") as InteractSpot
	if back:
		back.used.connect(_through_cask.bind(false))
	for p in [^"ShelfSpot", ^"ShelfSpotLibrary"]:
		var sp := get_node_or_null(p) as InteractSpot
		if sp:
			sp.used.connect(_open_shelf)
	var hall := get_node_or_null(^"GrandHallSpot") as InteractSpot
	if hall:
		hall.used.connect(_grand_hall)
	var lamp := get_node_or_null(^"WaterLamp")
	if lamp:
		lamp.connect(&"shorted", _on_lamp_shorted)
	for c in [^"Chandelier1", ^"Chandelier2"]:
		var ch := get_node_or_null(c)
		if ch:
			ch.connect(&"landed", _on_chandelier)
	var pump := get_node_or_null(^"Pump")
	var pump_spot := get_node_or_null(^"PumpSpot") as InteractSpot
	if pump:
		pump.connect(&"stopped", _on_pump_stopped)
		if pump_spot:
			pump_spot.used.connect(func(): pump.call(&"switch_off", false))
	var case_spot := get_node_or_null(^"CaseSpot") as InteractSpot
	if case_spot:
		case_spot.used.connect(_open_case)
	Sfx.music(&"desolation")
	_fade_in(black)
	if not cellar_arrived:
		cellar_arrived = true
		_arrive_cellar()


func _arrive_cellar() -> void:
	await _wait(0.8)
	await ThoughtBox.think(self, ARRIVE_CELLAR).finished


## Obrí sud RISERVA DEL DON: dvere na čele sa otvoria a Ricco prejde chodbou pod schodmi do šachty s rebríkom
## (inward = true) alebo zo šachty späť do vínnej pivnice
func _through_cask(inward: bool) -> void:
	if _secret_busy or _leaving:
		return
	_secret_busy = true
	var door := get_node_or_null(^"CaskDoor") as Sprite2D
	var to := get_node_or_null(^"ShaftIn" if inward else ^"CaskOut") as Node2D
	if to == null:
		_secret_busy = false
		return
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	if inward:
		for i in 3:   # tri ťuknutia ako za starých čias
			Sfx.play(&"knock_wood", player.global_position + Vector2(0, -30), -6.0, 0.05)
			await _wait(0.22)
	if door:
		door.frame = 1
	Sfx.play(&"door_open", player.global_position, -8.0)
	var black := _fade_rect()
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.35)
	await tw.finished
	player.global_position = to.global_position
	player.velocity = Vector2.ZERO
	pcam.teleport_position()
	await _wait(0.25)
	if door and not inward:
		door.frame = 0
	var tw2 := create_tween()
	tw2.tween_property(black, "color:a", 0.0, 0.35)
	await tw2.finished
	black.get_parent().queue_free()
	player.set_cutscene(false)
	_secret_busy = false
	if inward:
		_once(&"cel_shaft", "MY OLD WAY UP. ALL THE WAY TO THE LIBRARY.\nCLIMB, KID.")


## Otočná polica v knižnici: stena za ňou zmizne, polica sa pootočí (2. snímka)
func _open_shelf() -> void:
	var wall := get_node_or_null(^"ShelfDoor/Shape") as CollisionShape2D
	if wall == null or wall.disabled:
		return
	wall.set_deferred(&"disabled", true)
	var spr := get_node_or_null(^"ShelfDoor/Sprite") as Sprite2D
	if spr:
		var tw := create_tween()
		tw.tween_property(spr, "scale:x", 0.2, 0.18)
		tw.tween_callback(func(): spr.frame = 1)
		tw.tween_property(spr, "scale:x", 1.0, 0.18)
	Sfx.play(&"knock_wood", player.global_position + Vector2(0, -40), -10.0, 0.1)
	for p in [^"ShelfSpot", ^"ShelfSpotLibrary"]:   # druhá strana už netreba
		var sp := get_node_or_null(p)
		if sp:
			sp.queue_free()


## Dvere do hlavnej haly – hore do vily (časť 5, checkpoint 8)
func _grand_hall() -> void:
	if _leaving:
		return
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	await ThoughtBox.think(self, HALL_THOUGHT).finished
	_leave_door(VILLA, 8)


func _on_lamp_shorted(kills: int) -> void:
	if kills > 0:
		say("SHOCKING, AIN'T IT?")


## Čerpadlo stíchlo (páčka alebo guľka): páčka už netreba, voda odteká
func _on_pump_stopped(broken: bool) -> void:
	var sp := get_node_or_null(^"PumpSpot")
	if sp:
		sp.queue_free()
	_once(&"cel_pump", "THAT'S IT, LET THE SEA OUT.\nBUT NOW THEY CAN HEAR EVERY SHOT." if not broken else "WELL, THAT'S ONE WAY TO TURN IT OFF.\nNOW THEY CAN HEAR EVERY SHOT.")


## Vitrína v trofejovej izbe: dvierka sa otvoria a Springfield vypadne na zem (zoberie sa ako každá zbraň zo zeme –
## plná výbava = F vymení)
func _open_case() -> void:
	var case := get_node_or_null(^"TrophyCase") as Sprite2D
	if case == null or case.frame == 1:
		return
	case.frame = 1
	Sfx.play(&"door_open", case.global_position + Vector2(42, 80), -10.0, 0.1)
	var p := WEAPON_PICKUP.new()
	p.weapon = SPRINGFIELD
	p.ammo = CASE_AMMO
	p.velocity = Vector2(signf(player.global_position.x - (case.global_position.x + 42.0)) * 40.0, -110.0)
	p.spin = 3.0
	add_child(p)
	p.global_position = case.global_position + Vector2(42, 110)
	_once(&"cel_springfield", "A SPRINGFIELD. ONE SHOT, ONE MAN.\nWORK THE BOLT AND DON'T RUSH IT.")


func _on_chandelier(kills: int) -> void:
	if kills > 0:
		_once(&"cel_chandelier", "CRYSTAL. IMPORTED. MY MONEY.\nWORTH EVERY PENNY.")
