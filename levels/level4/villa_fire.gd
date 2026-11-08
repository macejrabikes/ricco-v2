extends Level4
## Kapitola IV – časť 7: útek z horiacej vily a Mancini na útese (scéna villa_fire.tscn – píše ju
## _art_src/make_villa_fire_scene.py, obrázky _art_src/make_ch4_fire_art.py). Ricco zliezol poklopom zo strechy siene.
## Svet = pravé krídlo vily (x_vily − 3560) + útes vpravo: poschodia R 340, U2 560, U1 780, G 1000.
##   R    strecha pri stožiari, na západ horí (fire_wall.gd) → poklop dolu do podkrovia
##   U2   podkrovie → zimná záhrada (padá sklo zo stropu – glass_rain.gd), dym (smoke_zone.gd), na západnom konci
##        prepálená diera v podlahe → dolu
##   U1   hudobný salón → izby služobníctva; Manciniho „upratovači“ v čiernom s kanistrami (sudy benzínu – ship_barrel.gd);
##        podlaha pri služobníctve sa prepadne (collapse_floor.gd) → kuchyňa
##   G    kuchyňa → vyrazené zadné dvere → útes za svitania: čierne auto, Mancini a dvaja ochrankári s Thompsonmi.
##        Rozhovor (Mancini sa prizná), húkačky hasičov – „Not here. Not today. See you in Chicago.“ Auto odíde.
##        Ricco a duch pri lavičke nad morom → END OF CHAPTER IV / THE WIDOW → TO BE CONTINUED.
## Checkpointy 12 strecha, 13 hudobný salón, 14 kuchyňa. Godot docs: classes/class_tween, classes/class_area2d

const FIRE_MAP := Rect2i(0, 0, 2940, 1100)
const BENCH_X := 2490.0

const ARRIVE_FIRE: Array[String] = [
	"The whole house is going up. Somebody wanted the widow's secrets to burn with her.",
	"Down through the attic. Kitchen's got a back door.",
]
const MANCINI_THOUGHT: Array[String] = [
	"Consigliere Mancini. 'C.M.' Eighteen grand off the top, before the widow.",
	"Two Tommy guns on me. Not yet, Ricco. Not yet.",
]
const ALONE_THOUGHT: Array[String] = [
	"He let me walk. That's either a mistake or a promise.",
]
const CHICAGO_THOUGHT: Array[String] = [
	"Then Chicago it is.",
]

var _ending: bool = false


func _ready() -> void:
	var black := _setup(FIRE_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 12)
	player.dark_area = false   # všetko svieti požiar
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var rig := g.get(&"rig") as Node2D
		if rig:
			rig.modulate = Color(1.0, 0.86, 0.76)   # žiara ohňa namiesto noci
	# Mancini a ochrankári na útese – čakajú, nestrieľajú, nedajú sa zabiť
	for n in [^"Mancini", ^"GuardL", ^"GuardR"]:
		var g := get_node_or_null(n) as Gangster
		if g:
			g.passive = true
			g.collision_layer = 0   # guľky ani klobúk ich netrafia (Riccove strely hľadajú vrstvu 4)
			var rig := g.get(&"rig") as Node2D
			if rig:
				rig.modulate = Color(0.95, 0.88, 0.86)
	for i in 3:
		var a := get_node_or_null(NodePath("Smoke%d" % i))
		if a and a.has_signal(&"choking"):
			a.choking.connect(func(): _once(&"fire_smoke", "SMOKE'S THICK UP TOP. STAY LOW (%s)\nOR IT'LL CHOKE YOU, KID." % KeyBindings.short(&"sneak")))
	var glass := get_node_or_null(^"GlassRain")
	if glass:
		glass.first_shard.connect(func(): _once(&"fire_glass", "THE GLASS ROOF'S COMING DOWN!\nDON'T STAND STILL!"))
	var floor_ := get_node_or_null(^"CollapseFloor")
	if floor_:
		floor_.collapsed.connect(func():
			checkpoint = maxi(checkpoint, 14)
			say("HOLD ON TO YOUR HAT!"))
	_connect(^"HoleBark", func(): _once(&"fire_hole", "FLOOR'S BURNED THROUGH.\nJUMP, KID!"))
	_connect(^"CleanersBark", func(): _once(&"fire_cleaners", "GUYS IN BLACK WITH GAS CANS.\nTHAT'S WHO LIT THE PLACE. ONE BULLET IN A CAN..."))
	_connect(^"KitchenBark", func(): _once(&"fire_kitchen", "THE BACK DOOR - PAST THE STOVES!"))
	_connect(^"Checkpoint13", func(): checkpoint = maxi(checkpoint, 13))
	_connect(^"Checkpoint14", func(): checkpoint = maxi(checkpoint, 14))
	_connect(^"MeetMancini", _meet_mancini)
	Sfx.loop(&"fuse", self, Vector2.INF, -20.0)
	Sfx.loop(&"wind_loop", self, Vector2(2400, 900), -18.0)
	Sfx.music(&"intensity")
	_fade_in(black)
	if not fire_arrived and checkpoint == 12:
		fire_arrived = true
		_arrive()


func _arrive() -> void:
	player.set_cutscene(true)
	await _wait(0.8)
	player.set_cutscene(false)
	await ThoughtBox.think(self, ARRIVE_FIRE).finished


func _process(delta: float) -> void:
	if player == null:
		return
	_tick_say(delta)

# ---------------------------------------------------------------- útes: Mancini

func _meet_mancini() -> void:
	if _ending:
		return
	_ending = true
	_say_queue.clear()
	Sfx.music(&"", 3.0)
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	var m := get_node_or_null(^"Mancini") as Node2D
	var gl := get_node_or_null(^"GuardL") as Node2D
	var gr := get_node_or_null(^"GuardR") as Node2D
	if m == null:
		_end_chapter()
		return
	await _wait(0.8)
	_speak(m, "GOOD MORNING, BOY. YOU HAVE HIS EYES.")
	await _wait(3.0)
	bark("SALVATORE...!")
	await _wait(2.4)
	_speak(m, "YOUR GRANDFATHER TRUSTED ME WITH HIS BOOKS,\nHIS WIFE AND HIS FUNERAL.")
	await _wait(3.4)
	_speak(m, "VITO WANTED TO SELL IT ALL. FORTY YEARS OF WORK -\nFOR A LEMON GROVE IN SICILY.")
	await _wait(3.4)
	_speak(m, "MARGARET WAS A GOOD FACE. FACES CAN BE REPLACED.")
	await _wait(3.0)
	await ThoughtBox.think(self, MANCINI_THOUGHT).finished
	Sfx.play(&"siren", Vector2.INF, -12.0, 0.0, &"Ambience")   # hasiči z mesta
	await _wait(1.2)
	_speak(m, "HEAR THAT? HALF THE GOLD COAST\nIS WATCHING VITO'S HOUSE BURN.")
	await _wait(3.4)
	_speak(m, "NOT HERE. NOT TODAY.\nSEE YOU IN CHICAGO, PENGUIN.")
	await _wait(3.0)
	# nastúpia do auta (otočia sa a zmiznú pri dverách) a auto odíde po ceste doprava
	var car := get_node_or_null(^"Car") as Node2D
	var door_x: float = car.global_position.x - 30.0 if car else m.global_position.x + 60.0
	for g in [m, gl, gr]:
		if g == null:
			continue
		g.call(&"_set_facing", 1.0 if door_x > g.global_position.x else -1.0)
		var tw := create_tween()
		tw.tween_property(g, "global_position:x", door_x, absf(door_x - g.global_position.x) / 60.0 + 0.2)
		tw.parallel().tween_property(g, "modulate:a", 0.0, 0.4).set_delay(maxf(0.0, absf(door_x - g.global_position.x) / 60.0 - 0.2))
	await _wait(1.6)
	Sfx.play(&"door_close", Vector2(door_x, 980.0), -4.0)
	await _wait(0.6)
	if car:
		Sfx.play(&"car_engine", car.global_position, -2.0)
		var body := car.get_node_or_null(^"Body") as Sprite2D
		var drive := create_tween()
		drive.tween_property(car, "global_position:x", car.global_position.x + 900.0, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if body:
			drive.parallel().tween_method(func(v: float): body.frame = int(v) % 2, 0.0, 40.0, 4.0)
	await _wait(3.0)
	for g in [m, gl, gr]:
		if g:
			g.queue_free()
	_by_the_sea()


## Ricco a duch pri lavičke nad morom, slnko vychádza
func _by_the_sea() -> void:
	player.sprite.play(player._hat_anim(&"run"))
	var dist: float = absf(BENCH_X - player.global_position.x)
	var tw := create_tween()
	tw.tween_property(player, "global_position:x", BENCH_X, dist / 90.0 + 0.1)
	await tw.finished
	player.sprite.play(player._hat_anim(&"idle"))
	var sun := get_node_or_null(^"SunGlow") as CanvasItem
	if sun:
		create_tween().tween_property(sun, "modulate:a", 1.0, 6.0)
	Sfx.play(&"wave_crash", Vector2(2700, 1060), -10.0)
	await _wait(1.0)
	await ThoughtBox.think(self, ALONE_THOUGHT).finished
	bark("A LEMON GROVE...\nI NEVER TOLD SALVATORE ABOUT THE GROVE, KID.")
	await _wait(4.0)
	bark("CHICAGO. THAT'S WHERE HIS MONEY SLEEPS.")
	await _wait(3.4)
	await ThoughtBox.think(self, CHICAGO_THOUGHT).finished
	bark("FIRST BREAKFAST.\nEVEN A PENGUIN CAN'T FIGHT ON AN EMPTY STOMACH.")
	await _wait(3.8)
	_end_chapter()


## END OF CHAPTER IV / THE WIDOW, potom TO BE CONTINUED a hlavné menu
func _end_chapter() -> void:
	if _leaving:
		return
	_leaving = true
	player.set_cutscene(true)
	var black := _fade_rect()
	var title := _title_label("END OF CHAPTER IV", 24, Color8(245, 235, 209), -14)
	var sub := _title_label("THE WIDOW", 8, Color8(150, 230, 245), 14)
	var cont := _title_label("TO BE CONTINUED...", 16, Color8(245, 235, 209), 0)
	for l in [title, sub, cont]:
		black.add_child(l)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 1.6)
	tw.tween_property(title, "modulate:a", 1.0, 0.8)
	tw.tween_property(sub, "modulate:a", 1.0, 0.6)
	tw.tween_interval(3.0)
	tw.tween_property(title, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(sub, "modulate:a", 0.0, 0.6)
	tw.tween_property(cont, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.5)
	tw.tween_property(cont, "modulate:a", 0.0, 0.8)
	await tw.finished
	reset()
	LoadingScreen.go(get_tree(), MAIN_MENU, 0.6)
