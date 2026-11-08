extends Level4
## Kapitola IV – časť 6: zrkadlová sieň pod sklenou kupolou vily a boss Margaret Vito (scéna mirror_hall.tscn – píše ju
## _art_src/make_mirror_hall_scene.py, obrázky _art_src/make_ch4_hall_art.py). Ricco prišiel schodmi z átria (villa.gd).
##   sieň 0–1700: osem zrkadiel na zadnej stene, medzi nimi zamatové závesy (curtain_fire.gd), svietniky, obrí luster
##                (drop_weight.gd), nad tým kupola zo skla – búrka, blesky; sklené dvere vpravo na strechu
##   strecha 1700–2700: dážď, stožiar so vzducholoďou IRON (plošina, rebrík), zábradlie nad útesom
## Boss (characters/margaret/margaret.gd, pás zdravia ui/boss_bar.gd – tri fázy):
##   1. zrkadlá – ona a jej odrazy; blesk (tu: _lightning) odrazy zhasne, praskne zrkadlo, kam ju Ricco trafí
##   2. vystúpi zo zrkadla, kopne do svietnika – závesy horia a oheň sa šíri na susedné (každých SPREAD s)
##   3. sklenými dverami na strechu, hore na plošinu stožiara; blesk do stožiara ju omráči (a Ricca na rebríku popáli)
##   smrť – C96 jej vypadne, kľačí („I just signed the checks“), blesk, padá zo stožiara do tmy nad morom, vzducholoď
##   odletí; niekto podpálil vilu → poklop pri stožiari = útek (časť 7 – villa_fire.gd, na útese čaká Mancini).
## Checkpoint 11 = začiatok boja (margaret_phase = dosiahnutá fáza – po smrti sa pokračuje v nej).
## Godot docs: classes/class_tween, classes/class_canvaslayer, classes/class_line2d

const HALL_MAP := Rect2i(0, 0, 2700, 700)
const FLOOR := 560.0
const ROOF_X := 1700.0                 ## od tejto x je strecha (dážď)
const MAST_X := 2350.0
const MAST_TOP := 340.0                ## podlaha plošiny stožiara
const SPREAD := 7.0                    ## s – oheň preskočí na susedný záves
const BOSS_BAR := preload("res://ui/boss_bar.gd")
const C96 := preload("res://weapons/c96/c96.tres")

const ARRIVE_HALL: Array[String] = [
	"Mirrors floor to ceiling. Somebody likes looking at herself.",
]
const END_THOUGHT: Array[String] = [
	"'Signed the checks.' For who? 'C.M.' in the ledger, 'C.' in the letter.",
	"The widow was just the face. Somebody's still running this show.",
]
const MIRROR_LINES: Array[String] = [
	"WHICH ONE OF ME DO YOU LOVE, DARLING?",
	"VITO NEVER COULD TELL ME FROM MY REFLECTION.",
	"LOOK CLOSER. THEY ALL HAVE MY SMILE.",
]
const DECOY_LINES: Array[String] = [
	"WRONG GIRL, SUGAR.",
	"SEVEN YEARS' BAD LUCK, BOY.",
	"MISSED ME. AGAIN.",
]
const HIT_LINES: Array[String] = [
	"YOU'VE GOT HIS EYES. I'LL CLOSE THEM TOO.",
	"I WORE BLACK FOR HIM. I'LL WEAR IT FOR YOU.",
	"THIS HOUSE IS MINE! EVERY BRICK!",
]
const TAUNTS: Array[String] = [
	"CLIMB, LITTLE BIRD. THE IRON WAITS FOR NO ONE.",
	"CAREFUL - LIGHTNING LOVES A TALL MAN.",
	"MY SHIP'S LEAVING. YOU'RE NOT ON THE LIST.",
]

var _m: Margaret
var _bar   ## ui/boss_bar.gd
var _fight: bool = false
var _ending: bool = false
var _said: Array[StringName] = []
var _line_cd: float = 0.0
var _curtains: Array[Node] = []
var _spread_t: float = 0.0
var _storm_t: float = 5.0
var _strikes: int = 0
var _flash: ColorRect
var _rain: CPUParticles2D
var _door_open: bool = false
var _fire_anim: float = 0.0


func _ready() -> void:
	var black := _setup(HALL_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 11)
	player.dark_area = false   # sieň svieti sviečkami, strecha bleskami
	_m = get_node_or_null(^"Margaret") as Margaret
	if _m:
		_m.stage.connect(_on_stage)
		_m.health_changed.connect(_on_hurt)
		_m.mirror_broken.connect(_on_mirror_broken)
		var rig := _m.get(&"rig") as Node2D
		if rig:
			rig.modulate = Color.WHITE
	for i in 16:
		var c := get_node_or_null(NodePath("Curtain%d" % i))
		if c:
			_curtains.append(c)
	_rain = get_node_or_null(^"Rain") as CPUParticles2D
	if _rain:
		_rain.emitting = false
	var layer := CanvasLayer.new()   # záblesk cez celú obrazovku
	layer.layer = 9
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(0.85, 0.9, 1.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	_connect(^"FireBark", func():
		if _fight:
			_say_once(&"fire", "DON'T TOUCH THE DRAPES, KID.\nVELVET BURNS LIKE PAPER."))
	_connect(^"RoofBark", func():
		if _fight:
			_say_once(&"roof", "SHE'S HEADIN' FOR THE ZEPPELIN!\nUP THE MAST - QUICK!"))
	var hatch := get_node_or_null(^"HatchSpot") as InteractSpot
	if hatch:
		hatch.monitoring = false   # zapne sa po smrti Margaret
		hatch.used.connect(_down_the_hatch)
	Sfx.loop(&"wind_loop", self, Vector2.INF, -24.0)
	Sfx.loop(&"airship_drone", self, Vector2(MAST_X + 150.0, 200.0), -14.0)
	Sfx.music(&"intensity")
	_fade_in(black)
	if margaret_phase >= 2:
		_start_fight.call_deferred()
	else:
		_arrive_hall()


func _arrive_hall() -> void:
	player.set_cutscene(true)
	await _wait(0.8)
	if not margaret_met:
		await ThoughtBox.think(self, ARRIVE_HALL).finished
	player.set_cutscene(false)
	_start_fight()


func _process(delta: float) -> void:
	if player == null:
		return
	_tick_say(delta)
	_process_house_fire(delta)
	_line_cd -= delta
	if _rain:
		_rain.emitting = player.global_position.x > ROOF_X - 40.0
	if not _fight or _ending:
		return
	# búrka: blesky (v 1. fáze ich spúšťa Margaret – aby ju bolo vidno práve pri mierení)
	_storm_t -= delta
	if _storm_t <= 0.0 and _m and _m.phase >= 2:
		_storm_t = randf_range(6.0, 10.0)
		_strikes += 1
		_lightning(_m.phase == 3 and _strikes % 2 == 0)
	# oheň sa šíri na susedné závesy
	if _any_burning():
		_spread_t -= delta
		if _spread_t <= 0.0:
			_spread_t = SPREAD
			_spread_fire()


func _say_once(key: StringName, t: String) -> void:
	if key in _said:
		return
	_said.append(key)
	say(t)


# ---------------------------------------------------------------- boj

func _start_fight() -> void:
	if _fight or _m == null:
		return
	_fight = true
	_bar = BOSS_BAR.new()
	add_child(_bar)
	_bar.notches.assign([1.0 / 3.0, 2.0 / 3.0])
	_bar.track("MARGARET VITO", _m)
	match margaret_phase:
		2:
			var at := get_node_or_null(^"HallSpot") as Node2D
			_m.start(2, at.global_position if at else Vector2(1200, FLOOR))
			for i in [3, 4]:   # sieň už horí
				if i < _curtains.size():
					_curtains[i].call(&"ignite")
			_knock_candle(Vector2(1200, FLOOR))
		3:
			_open_door(false)
			var at := get_node_or_null(^"MastSpot") as Node2D
			_m.start(3, at.global_position if at else Vector2(MAST_X + 40.0, MAST_TOP))
			for c in _curtains:
				c.call(&"ignite")
		_:
			margaret_phase = 1
			_m.start(1)
			if not margaret_met:
				margaret_met = true
				await _wait(1.0)
				var spots := get_node_or_null(^"MirrorSpots")
				var who: Node2D = spots.get_child(spots.get_child_count() - 1) as Node2D if spots else player
				_speak(who, "WELCOME HOME, BOY. VITO LOVED THIS ROOM.", 96.0)
				await _wait(2.4)
				say("THAT'S HER. IN THE GLASS - ALL OF 'EM.\nWAIT FOR THE LIGHTNING, KID.")
	_bar._on_health(_m.health, float(_m.max_health))   # po smrti v 2./3. fáze nezačína plný
	_bar._chip = _bar._value


func _on_hurt(_h: float, _mx: float) -> void:
	if _line_cd <= 0.0 and randf() < 0.3 and is_instance_valid(_m) and _m.active and _m.phase >= 2:
		_line_cd = 6.0
		_speak(_m, HIT_LINES[randi() % HIT_LINES.size()], 96.0)


func _on_stage(n: StringName) -> void:
	match n:
		&"mirrors":
			if _line_cd <= 0.0 and randf() < 0.5:
				_line_cd = 5.0
				_speak(_m, MIRROR_LINES[randi() % MIRROR_LINES.size()], 96.0)
		&"lightning":
			_lightning(false)
		&"decoy":
			if _line_cd <= 0.0:
				_line_cd = 4.0
				_speak(_m, DECOY_LINES[randi() % DECOY_LINES.size()], 96.0)
			_say_once(&"decoy", "JUST GLASS. WATCH WHICH ONE\nSTAYS WHEN THE SKY LIGHTS UP.")
		&"mirror_hit":
			_say_once(&"mirror_hit", "THAT'S HER! KEEP BREAKIN' GLASS!")
		&"emerge":
			margaret_phase = 2
			_say_queue.clear()
			_speak(_m, "ENOUGH! I'LL DO IT MYSELF!", 96.0)
		&"candle":
			_knock_candle(_m.global_position)
			_spread_t = SPREAD
			_say_once(&"candle", "SHE KICKED THE CANDLES INTO THE DRAPES!\nTHE WHOLE HALL'S GONNA GO UP!")
		&"reload":
			_say_once(&"reload", "SHE'S LOADIN' A STRIPPER CLIP.\nNOW, KID!")
		&"whip":
			_say_once(&"whip", "CAREFUL - SHE PISTOL-WHIPS\nLIKE A LONGSHOREMAN.")
		&"to_roof":
			margaret_phase = 3
			_say_queue.clear()
			_open_door(true)
			_speak(_m, "THE IRON IS WAITING FOR ME. NOT FOR YOU.", 96.0)
			say("SHE'S RUNNIN' FOR THE ROOF!")
		&"on_mast":
			_say_once(&"mast", "UP THE LADDER. SHE WON'T SHOOT\nTILL YOU'RE ON TOP - SHE WANTS TO WATCH.")
		&"taunt":
			_speak(_m, TAUNTS[randi() % TAUNTS.size()], 96.0)
		&"dying":
			_margaret_dies()


## Prasklo zrkadlo, kde ju Ricco trafil
func _on_mirror_broken(i: int) -> void:
	var crack := get_node_or_null(NodePath("Crack%d" % i)) as CanvasItem
	if crack:
		crack.visible = true


## Kopnutý svietnik – zapáli najbližší záves
func _knock_candle(at: Vector2) -> void:
	var best: Node2D = null
	for i in 8:
		var c := get_node_or_null(NodePath("Candle%d" % i)) as Sprite2D
		if c and c.frame == 0 and (best == null or absf(c.global_position.x - at.x) < absf(best.global_position.x - at.x)):
			best = c
	if best:
		(best as Sprite2D).frame = 1
		var g := best.get_node_or_null(^"Glow") as CanvasItem
		if g:
			g.visible = false
		Sfx.play(&"metal_crash", best.global_position, -8.0, 0.1)
		Burst.spawn(self, best.global_position + Vector2(0, -20), Vector2.UP, Color(1.0, 0.7, 0.3), 10, 60.0, Vector2(0, 200), 0.6)
	var cur: Node2D = null
	for c in _curtains:
		var n := c as Node2D
		if c.get(&"state") == 0 and (cur == null or absf(n.global_position.x - at.x) < absf(cur.global_position.x - at.x)):
			cur = n
	if cur:
		cur.call(&"ignite")


func _any_burning() -> bool:
	for c in _curtains:
		if c.call(&"is_burning"):
			return true
	return false


func _spread_fire() -> void:
	var next: Array[int] = []
	for i in _curtains.size():
		if _curtains[i].call(&"is_burning"):
			for j in [i - 1, i + 1]:
				if j >= 0 and j < _curtains.size() and _curtains[j].get(&"state") == 0 and not next.has(j):
					next.append(j)
	if not next.is_empty():
		_curtains[next[randi() % next.size()]].call(&"ignite")


## Sklené dvere na strechu – Margaret ich prestrelí
func _open_door(fx: bool) -> void:
	if _door_open:
		return
	_door_open = true
	var door := get_node_or_null(^"GlassDoor")
	if door == null:
		return
	var spr := door.get_node_or_null(^"Sprite") as Sprite2D
	if spr:
		spr.frame = 1
	for c in door.get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).set_deferred(&"disabled", true)
	if fx:
		Sfx.shot(C96, (door as Node2D).global_position, -2.0)
		Sfx.play(&"glass_break", (door as Node2D).global_position + Vector2(0, -60), 2.0)
		Burst.spawn(self, (door as Node2D).global_position + Vector2(0, -60), Vector2.RIGHT, Color(0.8, 0.92, 1.0), 20, 140.0, Vector2(0, 420), 0.7)
		Sfx.play(&"wind_gust", Vector2.INF, -6.0, 0.08, &"Ambience")


# ---------------------------------------------------------------- búrka

## Blesk: záblesk, hrom a čiara z oblohy. at_mast = udrie do stožiara (popáli Ricca na rebríku/plošine, omráči Margaret)
func _lightning(at_mast: bool) -> void:
	if at_mast:
		Sfx.play(&"steam_hiss", Vector2(MAST_X, MAST_TOP - 20.0), -6.0)   # praskanie na hrote – varovanie
		Burst.spawn(self, Vector2(MAST_X, MAST_TOP - 60.0), Vector2.UP, Color(0.7, 0.8, 1.0), 10, 40.0, Vector2.ZERO, 1.0)
		await _wait(1.1)
		if _ending:
			return
	var x: float = MAST_X if at_mast else player.global_position.x + randf_range(-260.0, 260.0)
	var bottom_y: float = MAST_TOP - 60.0 if at_mast else 60.0
	_bolt(x, bottom_y)
	_flash.color.a = 0.75
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35)
	tw.tween_property(_flash, "color:a", 0.35, 0.05)
	tw.tween_property(_flash, "color:a", 0.0, 0.25)
	Sfx.play(&"lightning_strike" if at_mast else &"thunder", Vector2.INF, -2.0 if at_mast else -6.0, 0.1, &"Ambience")
	if _m and is_instance_valid(_m):
		_m.reveal()
	if at_mast:
		player.set(&"shake_timer", 0.3)
		if _m and is_instance_valid(_m):
			_m.lightning_stun()
		var p := player.global_position
		if absf(p.x - MAST_X) < 80.0 and p.y < FLOOR - 20.0:
			player.call(&"take_damage", 1, Vector2(MAST_X, p.y - 30.0))
			_say_once(&"zap", "OFF THE STEEL WHEN IT CRACKLES, KID!")


## Klikatá čiara blesku z vrchu obrazovky (krátko svieti a zmizne)
func _bolt(x: float, bottom_y: float) -> void:
	var l := Line2D.new()
	l.width = 2.0
	l.default_color = Color(0.92, 0.94, 1.0)
	l.z_index = -1
	var pts := PackedVector2Array()
	var y: float = 0.0
	var cx: float = x + randf_range(-60.0, 60.0)
	pts.append(Vector2(cx, y))
	while y < bottom_y:
		y = minf(y + randf_range(14.0, 26.0), bottom_y)
		cx = lerpf(cx + randf_range(-16.0, 16.0), x, 0.25 if y < bottom_y else 1.0)
		pts.append(Vector2(cx, y))
	l.points = pts
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.08)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- koniec

func _margaret_dies() -> void:
	if _ending:
		return
	_ending = true
	_say_queue.clear()
	Sfx.music(&"", 2.5)
	var m := _m
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	await _wait(0.6)
	# potáca sa k pravému okraju plošiny a klesne na kolená (sukňa – stačí rig posunúť nižšie)
	m.set_physics_process(false)
	m.call(&"_set_facing", -1.0)
	var tw := create_tween()
	tw.tween_property(m, "global_position:x", MAST_X + 40.0, 1.0).set_trans(Tween.TRANS_SINE)
	var rig := m.get(&"rig") as Node2D
	if rig:
		tw.tween_property(rig, "position:y", rig.position.y + 8.0, 0.4)
	await tw.finished
	_speak(m, "YOU THINK A WIDOW BOUGHT A WHOLE CITY?", 96.0)
	await _wait(2.8)
	_speak(m, "I JUST SIGNED THE CHECKS, BOY.", 96.0)
	await _wait(2.8)
	_speak(m, "VITO... YOU OLD FOOL... YOU SENT A BOY...", 96.0)
	await _wait(2.6)
	# blesk do stožiara – a pád cez zábradlie do tmy nad morom
	_strikes = 0
	_bolt(MAST_X, MAST_TOP - 60.0)
	_flash.color.a = 0.9
	create_tween().tween_property(_flash, "color:a", 0.0, 0.6)
	Sfx.play(&"lightning_strike", Vector2.INF, 0.0, 0.0, &"Ambience")
	player.set(&"shake_timer", 0.4)
	m.hands_up = true
	var fall := create_tween().set_parallel(true)
	fall.tween_property(m, "global_position", m.global_position + Vector2(170.0, 520.0), 1.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(m, "rotation", 2.6, 1.7)
	Sfx.play(&"enemy_death", m.global_position, 0.0)
	# vzducholoď sa odtrhne od stožiara a odpláva do búrky
	var ship := get_node_or_null(^"Airship") as Node2D
	var rope := get_node_or_null(^"MooringRope") as CanvasItem
	if rope:
		rope.visible = false
	if ship:
		Sfx.play(&"chain_rattle", ship.global_position, -6.0)
		var drift := create_tween()
		drift.tween_property(ship, "position", ship.position + Vector2(900.0, -160.0), 16.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _wait(1.8)
	m.queue_free()
	await _wait(1.0)
	bark("MARGARET... SHE WAS NEVER MINE.\nNOT EVEN ON OUR WEDDING DAY.")
	await _wait(3.6)
	await ThoughtBox.think(self, END_THOUGHT).finished
	# niekto podpálil prízemie (Manciniho ľudia – ukáže sa na útese) – plamene a dym spoza okraja strechy
	_house_on_fire()
	await _wait(1.2)
	bark("SOMEBODY'S TORCHING THE HOUSE!\nGRAB HER PISTOL - DOWN THE HATCH!")
	var hatch := get_node_or_null(^"Hatch") as Sprite2D
	if hatch:
		hatch.frame = 1
	var spot := get_node_or_null(^"HatchSpot") as InteractSpot
	if spot:
		spot.monitoring = true
	player.set_cutscene(false)


## Vila horí – plamene a žiara spoza okraja strechy, dym, výbuch dole
func _house_on_fire() -> void:
	var fire := get_node_or_null(^"HouseFire") as Node2D
	if fire:
		fire.visible = true
		fire.modulate.a = 0.0
		create_tween().tween_property(fire, "modulate:a", 1.0, 1.5)
	Sfx.play(&"explosion", Vector2(ROOF_X + 500.0, FLOOR + 80.0), -4.0)
	player.set(&"shake_timer", 0.5)
	Sfx.loop(&"fuse", self, Vector2(ROOF_X + 500.0, FLOOR + 40.0), -14.0)
	for i in 6:
		Burst.spawn(self, Vector2(ROOF_X + 120.0 + i * 150.0, FLOOR + 6.0), Vector2.UP, Color(0.2, 0.18, 0.2, 0.7), 8, 40.0, Vector2(0, -30), 1.6)


func _process_house_fire(delta: float) -> void:
	var fire := get_node_or_null(^"HouseFire") as Node2D
	if fire == null or not fire.visible:
		return
	_fire_anim += delta * 10.0
	var i := 0
	for c in fire.get_children():
		if c is Sprite2D and (c as Sprite2D).hframes == 3:
			(c as Sprite2D).frame = (int(_fire_anim) + i) % 3
			i += 1
	if randf() < delta * 4.0:
		Burst.spawn(self, Vector2(randf_range(ROOF_X, ROOF_X + 1000.0), FLOOR + 4.0), Vector2.UP, Color(1.0, 0.6, 0.2), 2, 50.0, Vector2(0, -40), 0.9)


## Poklop pri stožiari – dolu do podkrovia horiacej vily (časť 7)
func _down_the_hatch() -> void:
	Sfx.play(&"ladder_rung", player.global_position, -4.0)
	_leave_door(VILLA_FIRE, 12, false)
