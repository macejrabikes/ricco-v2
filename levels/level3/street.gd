extends Level3
## Kapitola III – časť 2: daždivá ulica na Lower East Side → požiarne schodisko → strechy so šnúrami (návrh strechy_AC_vyssie.png).
## Ide sa zľava doprava (tools/build_level3.gd → street.tscn):
##   ulica: pizzeria Napoli (markíza = trampolína, world/fx/awning.gd) → požiarne schodisko 3 plošiny + rebríky hore na strechu →
##   strecha pizzerie (holuby – world/npc/pigeons.gd) → šnúra s prádlom cez uličku (world/fx/clothesline.gd) →
##   strecha Chop Suey (vodná nádrž, na nej Thompsonove náboje, mafián s luparou) → rebrík na boku holičstva →
##   strecha holičstva (mafián s revolverom pri dverách so žiarovkou) → druhá šnúra nad ulicou →
##   strecha lahôdok (mafián s luparou) → dvere schodiska → ďalšie strechy (časť 3 – roofs.gd).
## Dole v ulici hliadkujú policajti s baterkou (gangster kind „cop“) – keď Ricca zbadajú, zapískajú a privolajú ostatných.
## Kto spadne do ulice, vylezie späť po schodisku pizzerie alebo lahôdok.
## Celé je to v noci a v daždi (player.dark_area): vidno ťa vo výkladoch, pod lampami, pri žiarovkách a v kuželi baterky.
## Checkpointy (Level3.checkpoint): 2 = začiatok ulice, 3 = strecha pizzerie, 4 = strecha holičstva.
## Godot docs: classes/class_tween, classes/class_cpuparticles2d

const STREET_MAP := Rect2i(0, -780, 1980, 844)       ## hranice kamery (px) – ulica je na y = 0

const ARRIVE_STREET: Array[String] = [
	"Lower East Side. Laundry lines, pigeons and coppers on somebody's payroll.",
	"The Majestic's uptown. First I gotta get off this street.",
]

const WANTED: Array[String] = ["'Penguin. Reward: five hundred bucks.'", "Five hundred? I'm insulted."]


func _ready() -> void:
	if checkpoint >= 5:   # zomrel na ďalších strechách alebo na nadzemke → rovno tam
		get_tree().change_scene_to_file.call_deferred(part_for(checkpoint))
		return
	var black := _setup(STREET_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 2)
	_connect(^"StreetBark", func(): _once(&"coppers", "COPPERS ON THE TAKE. STILL COPPERS.\nGO OVER 'EM, NOT THROUGH 'EM."))
	_connect(^"AwningBark", func(): _once(&"awning", "THAT AWNING'S BOUNCIER\nTHAN MY OLD MATTRESS."))
	_connect(^"WantedThought", _wanted_thought)
	_connect(^"Checkpoint3", func():
		checkpoint = maxi(checkpoint, 3)
		_once(&"pigeons", "WATCH THE PIGEONS, KID.\nTHEY SQUAWK LIKE STOOL PIGEONS."))
	_connect(^"LineBark", func(): _once(&"line", "GRAB THE PULLEY (%s).\nLET GRAVITY DO THE WALKING." % KeyBindings.short(&"jump")))
	_connect(^"Checkpoint4", func(): checkpoint = maxi(checkpoint, 4))
	_connect(^"ExitRoof", _on_exit_roof)
	for n in get_children():
		if n.has_signal(&"scattered"):
			n.connect(&"scattered", func(): _once(&"pigeons_told", "TOLD YA. STOOL PIGEONS."))
	Sfx.loop(&"rain", self, Vector2.INF, -8.0)
	Sfx.music(&"rainy_noir")
	_fade_in(black)
	if checkpoint == 2 and not street_arrived:
		street_arrived = true
		_arrive_street()


func _arrive_street() -> void:
	player.set_cutscene(true)
	await _wait(0.9)
	player.set_cutscene(false)
	await ThoughtBox.think(self, ARRIVE_STREET).finished


## Plagát WANTED na stene pizzerie – M. dala Ricca hľadať (myšlienka len raz)
func _wanted_thought() -> void:
	if &"wanted" in barks:
		return
	barks.append(&"wanted")
	ThoughtBox.think(self, WANTED)


func _process(delta: float) -> void:
	if player == null:
		return
	_tick_say(delta)


## Dvere schodiska na streche lahôdok – cez povalu na ďalšie strechy (roofs.tscn)
func _on_exit_roof() -> void:
	_leave_door(ROOFS, 5)
