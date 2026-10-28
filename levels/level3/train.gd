extends Level3
## Kapitola III – časť 4: nadzemka (Third Avenue El) zo stanice Delancey St do Harlemu.
## Vlak v scéne stojí, ubieha svet okolo neho: mesto, domy pri trati a konštrukcia nadzemky (Parallax2D.autoscroll,
## skupina „train_scroll“). Proti vlaku letia nosníky mostov (_spawn_beam): kto na streche stojí, toho zasiahnu –
## Ricco sa musí šmyknúť (S) alebo prikrčiť za vetrákom (kryt). Mafiáni, čo o Riccovi nevedia, sa pred nosníkom prikrčia;
## kto práve mieri alebo strieľa na Ricca, na nosník zabudne a ten ho zloží.
## Šesť vozňov zľava (scéna train.tscn, píše ju _art_src/make_train_scene.py):
##   1 strecha (nosníky) → 2 strecha: po vedľajšej koľaji dobehne expres so strelcami na streche (Express – chvíľu ide
##   vedľa, potom odíde; keď sú strelci mŕtvi, odíde skôr) → rebrík dole k dverám vozňa 3 →
##   3 vnútri (prierez – predná stena zmizne, keď je Ricco dnu): v tme mafián s luparou a sediaci cestujúci, v strede
##   svetlo a stojaci cestujúci – ponad nich po remienkoch (train_strap.gd), vzadu ochrankár s Coltom 1911.
##   Alebo hore po streche vozňa 3. → 4 strecha v zákrute: kamera sa nakloní, odstredivá sila tlačí Ricca dozadu
##   (prikrčiť sa za vetrák alebo šmyk ju nepustí) → 5 poštový vozeň v tme: Tommy s baterkou, cez otvorené bočné dvere
##   občas prebehne svetlo pouličnej lampy (MailSweep) → 6 čelný vozeň: mafián drží motorovodiča ako rukojemníka.
##   Keď ho Ricco zloží, motorovodič zabrzdí v stanici 125 St (keby Ricco trafil motorovodiča, zabrzdí „mŕtvy muž“).
##   Ricco vyjde čelom vozňa na nástupište stanice 125 St → jazzový klub The Blue Canary (časť 5 – club.gd).
## Checkpointy (Level3.checkpoint): 9 = strecha vozňa 1, 10 = pred vozňom 3, 11 = pred vozňom 4, 12 = pred vozňom 5,
## 13 = pred vozňom 6.
## Godot docs: classes/class_parallax2d, classes/class_tween, classes/class_canvasitemmaterial, classes/class_camera2d

const TRAIN_MAP := Rect2i(0, -330, 2764, 394)   ## hranice kamery (px) – podlaha vozňov je na y = 0, strechy na y = -150
const ROOF_Y := -150.0           ## strecha vozňa (kde Ricco chodí)
const TRAIN_SPEED := 300.0       ## px/s – tak rýchlo letia nosníky a ubieha konštrukcia nadzemky
const BEAM_CLEAR := 30.0         ## px – spodok nosníka nad strechou: šmyk (24 px) aj skrčenie za krytom (22 px) prejdú, postava (38 px) nie
const BEAM_HALF := 16.0          ## polovica šírky nosníka
const BEAM_DAMAGE := 2
const BEAM_END := 2500.0         ## px – za touto čiarou (koniec strechy čelného vozňa) už nosníky nechodia
const DUCK_NEAR := 90.0          ## px – takto ďaleko pred nosníkom sa mafián prikrčí
## prierezy: predná stena zmizne, keď je Ricco vnútri (uzol → vnútro od–do x)
const WALLS := {
	^"Car3Wall": Vector2(866.0, 1262.0),
	^"Car5Wall": Vector2(1730.0, 2126.0),
	^"Car6Wall": Vector2(2162.0, 2558.0),
}
const STATION_X := 1964.0        ## kde zastane ľavý okraj stanice (obrázok station.png, 800 px – siaha po koniec mapy)
const BRAKE_TIME := 6.0          ## s brzdenia do stanice (stanica príde spoza pravého okraja mapy)
const EXPRESS_LAYER := 256       ## vrstva strechy expresu – stoja na nej len strelci
const EXPRESS_HOLD := 250.0      ## px – kde expres ide vedľa nás (ľavý okraj)
const EXPRESS_TIME := Vector3(7.0, 14.0, 5.0)   ## s – dobehnutie, jazda vedľa, odchod
const CURVE_TIME := 9.0          ## s – ako dlho trvá zákruta
const CURVE_TILT := 0.07         ## rad – náklon kamery v zákrute
const CURVE_PUSH := 70.0         ## px/s – odstredivá sila na streche (Ricco ide 140, plíži sa 58 – plížením neprejde)
const SWEEP_FROM := 2058.0       ## svetlo lampy cez dvere poštového vozňa: odkiaľ…
const SWEEP_TO := 1768.0         ## …kam prebehne (proti smeru jazdy, rýchlosťou vlaku)
const BEAM_TEX := preload("res://levels/level3/art/train/beam.png")
const SIGNAL_TEX := preload("res://levels/level3/art/train/signal.png")

const ARRIVE_TRAIN: Array[String] = [
	"The Third Avenue El. Hopped it at Delancey Street.",
	"Next stop, Harlem. No ticket, no problem.",
]

var _speed: float = 1.0                ## 1 = plná rýchlosť, 0 = vlak stojí v stanici
var _scrollers: Array = []             ## [Parallax2D, pôvodný autoscroll]
var _beams: Array[Node2D] = []
var _beam_t: float = 2.5
var _beam_n: int = 0
var _blink: float = 0.0
var _warn: Label
var _walls: Array = []                 ## [CanvasItem, Vector2 x od–do]
var _station: Node2D
var _front: Array[CollisionShape2D] = []
var _braking: bool = false
var _brake_t: float = 0.0
var _stopped: bool = false
var _rumble: AudioStreamPlayer
var _express: Node2D
var _express_tw: Tween
var _express_on: bool = false
var _express_leaving: bool = false
var _express_cleared: bool = false
var _gunmen: Array[Node2D] = []
var _curve_t: float = -1.0             ## < 0 = rovina; inak s od začiatku zákruty
var _squeal_t: float = 0.0
var _sweep: Node2D
var _sweep_wait: float = 1.5
var _hijacker: Node2D
var _motorman: Node2D


func _ready() -> void:
	if checkpoint >= 14:   # zomrel v klube → rovno tam
		get_tree().change_scene_to_file.call_deferred(part_for(checkpoint))
		return
	var black := _setup(TRAIN_MAP)
	if black == null:
		return
	checkpoint = maxi(checkpoint, 9)
	for path in WALLS:
		var w := get_node_or_null(path as NodePath) as CanvasItem
		if w:
			_walls.append([w, WALLS[path]])
	_station = get_node_or_null(^"Station") as Node2D
	for path in [^"FrontStop/Shape", ^"Car6WallR/Shape"]:
		var sh := get_node_or_null(path as NodePath) as CollisionShape2D
		if sh:
			_front.append(sh)
	if _station:
		_station.visible = false
	for n in get_tree().get_nodes_in_group(&"train_scroll"):
		_scrollers.append([n, n.get(&"autoscroll")])
	_setup_express()
	_sweep = get_node_or_null(^"MailSweep") as Node2D
	_hijacker = get_node_or_null(^"Hijacker") as Node2D
	_motorman = get_node_or_null(^"Motorman") as Node2D
	_connect(^"ExpressStart", _start_express)
	_connect(^"Checkpoint10", func():
		checkpoint = maxi(checkpoint, 10)
		_once(&"civilians", "CIVILIANS IN THERE, KID.\nAIM LIKE YOU MEAN IT."))
	for cp in [11, 12, 13]:
		var n: int = cp
		_connect(NodePath("Checkpoint%d" % n), func(): checkpoint = maxi(checkpoint, n))
		_connect(NodePath("Checkpoint%dRoof" % n), func(): checkpoint = maxi(checkpoint, n))
	_connect(^"StrapBark", func(): _once(&"strap", "UP ON THE SEAT, GRAB A STRAP.\n%s + DIRECTION TO SWING ON." % KeyBindings.short(&"jump")))
	_connect(^"CurveStart", _start_curve)
	_connect(^"MailBark", func(): _once(&"mail_car", "MAIL CAR. DARK AS A COAL BIN.\nWATCH THAT DOOR - STREETLIGHTS."))
	_connect(^"CabBark", _on_cab)
	_connect(^"ExitStation", func(): _leave_door(CLUB, 14, false))
	player.weapon_changed.connect(_on_weapon)
	_make_warn()
	_rumble = Sfx.loop(&"train_rumble", self, Vector2.INF, -4.0) as AudioStreamPlayer
	Sfx.music(&"rainy_noir")
	_fade_in(black)
	if checkpoint == 9 and not train_arrived:
		train_arrived = true
		_arrive_train()


func _arrive_train() -> void:
	player.set_cutscene(true)
	await _wait(0.9)
	player.set_cutscene(false)
	await ThoughtBox.think(self, ARRIVE_TRAIN).finished
	_once(&"hold_hat", "HOLD ON TO YOUR HAT, KID.")


func _process(delta: float) -> void:
	if player == null:
		return
	_tick_say(delta)
	_update_speed(delta)
	_update_beams(delta)
	_update_walls(delta)
	_update_express()
	_update_sweep(delta)
	_update_hostage()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_update_curve(delta)


# ---------------------------------------------------------------- jazda a brzdenie v stanici

func _update_speed(delta: float) -> void:
	if _braking and not _stopped:
		_brake_t = minf(_brake_t + delta, BRAKE_TIME)
		_speed = 1.0 - _brake_t / BRAKE_TIME
		# stanica sa priblíži a zastane presne na STATION_X (rovnomerné brzdenie: dráha = v·t − v·t²/2T)
		var run: float = TRAIN_SPEED * BRAKE_TIME / 2.0
		var done: float = TRAIN_SPEED * (_brake_t - _brake_t * _brake_t / (2.0 * BRAKE_TIME))
		if _station:
			_station.position.x = STATION_X + run - done
		if _brake_t >= BRAKE_TIME:
			_on_stopped()
	for s in _scrollers:
		(s[0] as Node).set(&"autoscroll", (s[1] as Vector2) * _speed)
	if _rumble:
		_rumble.pitch_scale = lerpf(0.55, 1.0, _speed)
		_rumble.volume_db = lerpf(-30.0, -4.0, _speed)


func _start_braking() -> void:
	if _braking:
		return
	_braking = true
	if _station:
		_station.position.x = STATION_X + TRAIN_SPEED * BRAKE_TIME / 2.0
		_station.visible = true
	Sfx.play(&"brakes", Vector2.INF, -6.0, 0.0)
	say("125TH STREET. HARLEM.\nTHAT'S OUR STOP, KID.")


func _on_stopped() -> void:
	if _stopped:
		return
	_stopped = true
	_speed = 0.0
	for sh in _front:
		sh.set_deferred(&"disabled", true)   # čelom vozňa (dvere kabíny aj zo strechy) sa už dá vyjsť na nástupište
	Sfx.play(&"train_bell", Vector2.INF, -8.0, 0.0)
	say("HOP OFF BEFORE THE CONDUCTOR\nASKS FOR A NICKEL.")


# ---------------------------------------------------------------- vozeň 2: expres na vedľajšej koľaji

func _setup_express() -> void:
	_express = get_node_or_null(^"Express") as Node2D
	if _express == null:
		return
	if checkpoint >= 10:   # po smrti ďalej vo vlaku – expres už odišiel
		_express.queue_free()
		_express = null
		return
	_express.visible = false
	for g in _express.get_children():
		if g.is_in_group(&"enemies"):
			var e := g as CharacterBody2D
			e.collision_mask = EXPRESS_LAYER   # stoja na streche expresu, nie na našich vozňoch (Gangster._ready dá 1)
			e.process_mode = Node.PROCESS_MODE_DISABLED   # kým expres nepríde, nestrieľajú
			_gunmen.append(e)


## Expres dobehne zozadu (rovnomerne spomalí na našu rýchlosť – Tween EASE_OUT QUAD), chvíľu ide vedľa, odíde dopredu
func _start_express() -> void:
	if _express == null or _express_on:
		return
	_express_on = true
	_express.visible = true
	for e in _gunmen:
		e.process_mode = Node.PROCESS_MODE_INHERIT
	Sfx.loop(&"train_rumble", _express, Vector2(416.0, -100.0), -6.0)
	Sfx.play(&"train_horn", Vector2.INF, -6.0, 0.0)
	_once(&"express", "EXPRESS ON THE NEXT TRACK!\nAND IT BROUGHT COMPANY.")
	_express_tw = create_tween()
	_express_tw.tween_property(_express, "position:x", EXPRESS_HOLD, EXPRESS_TIME.x).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_express_tw.tween_interval(EXPRESS_TIME.y)
	_express_tw.tween_callback(_leave_express)


## Expres odíde dopredu (zrýchli) a zmizne aj so strelcami (aj mŕtvymi – ležia na jeho streche)
func _leave_express() -> void:
	if _express == null or _express_leaving:
		return
	_express_leaving = true
	if _express_tw and _express_tw.is_valid():
		_express_tw.kill()   # odíde aj skôr – z miesta, kde práve je
	Sfx.play(&"train_horn", Vector2.INF, -10.0, 0.0)
	var tw := create_tween()
	tw.tween_property(_express, "position:x", 3600.0, EXPRESS_TIME.z).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_express.queue_free()
		_express = null)


## Keď sú strelci mŕtvi, expres o chvíľu odíde
func _update_express() -> void:
	if _express == null or not _express_on or _express_leaving or _express_cleared:
		return
	for e in _gunmen:
		if is_instance_valid(e) and int(e.get(&"state")) != 10:   # Gangster.State.DEAD
			return
	_express_cleared = true
	_once(&"express_clear", "THAT'S THE EXPRESS SORTED.")
	await _wait(1.5)
	_leave_express()


# ---------------------------------------------------------------- vozeň 4: zákruta

func _start_curve() -> void:
	if _curve_t >= 0.0 or _braking:
		return
	_curve_t = 0.0
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam.ignore_rotation = false   # PhantomCamera2D otáča Camera2D podľa svojej rotácie
	var tw := create_tween()
	tw.tween_property(pcam, "rotation", CURVE_TILT, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(CURVE_TIME - 2.8)
	tw.tween_property(pcam, "rotation", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_curve_t = -1.0
		if cam:
			cam.ignore_rotation = true)
	_once(&"curve", "CURVE! KEEP LOW OR SLIDE,\nOR SHE'LL THROW YA OFF.")


## V zákrute odstredivá sila tlačí Ricca na streche dozadu – prikrčený za krytom alebo v šmyku drží
func _update_curve(delta: float) -> void:
	if _curve_t < 0.0:
		return
	_curve_t += delta
	_squeal_t -= delta
	if _squeal_t <= 0.0:
		_squeal_t = randf_range(1.6, 2.4)
		Sfx.play(&"wheel_squeal", Vector2.INF, -12.0, 0.08)
	var body := player as CharacterBody2D
	if body == null or player.in_cutscene or player.ducked or player.state in [3, 4, 7]:   # DEAD, SLIDE, LADDER
		return
	if body.global_position.y < ROOF_Y + 10.0 and body.is_on_floor():
		var k: float = clampf(minf(_curve_t, CURVE_TIME - _curve_t) / 1.4, 0.0, 1.0)   # sila rastie s náklonom
		body.move_and_collide(Vector2(-CURVE_PUSH * k * delta, 0.0))


# ---------------------------------------------------------------- vozeň 5: svetlo lámp cez otvorené dvere

## Svetlo pouličnej lampy prebehne vozňom proti smeru jazdy; medzi lampami je zóna zaparkovaná pod traťou
func _update_sweep(delta: float) -> void:
	if _sweep == null:
		return
	if _sweep.position.y < 100.0:   # práve prebieha
		_sweep.position.x -= TRAIN_SPEED * maxf(_speed, 0.3) * delta
		if _sweep.position.x <= SWEEP_TO:
			_sweep.position.y = 400.0
			_sweep_wait = randf_range(1.2, 2.2)
		return
	if _stopped:
		return
	_sweep_wait -= delta
	if _sweep_wait <= 0.0:
		_sweep.position = Vector2(SWEEP_FROM, 0.0)


# ---------------------------------------------------------------- vozeň 6: únosca v kabíne

func _on_cab() -> void:
	if &"cab" in barks or _hijacker == null or int(_hijacker.get(&"state")) == 10:
		return
	barks.append(&"cab")
	_speak(_hijacker, "ONE MORE STEP, PENGUIN,\nAND THE MOTORMAN GETS IT!")
	await _wait(2.6)
	say("AIM HIGH, KID. OVER THE\nMOTORMAN'S HEAD.")


## Keď únosca padne, motorovodič zabrzdí do stanice; keby padol motorovodič, zabrzdí „mŕtvy muž“ (pedál v kabíne)
func _update_hostage() -> void:
	if _braking:
		return
	if _motorman and bool(_motorman.get(&"dead")):
		_start_braking()
		_once(&"deadman", "YOU SHOT THE MOTORMAN?!\nLUCKY THE DEAD MAN'S PEDAL STOPS HER.")
		return
	if _hijacker and int(_hijacker.get(&"state")) == 10:
		_start_braking()
		if _motorman:
			_speak(_motorman, "THANK YOU, MISTER!\nHOLD ON - 125TH STREET!", 70.0)


# ---------------------------------------------------------------- nosníky mostov nad traťou

func _update_beams(delta: float) -> void:
	var p: Vector2 = player.global_position
	if not _braking and p.y < ROOF_Y + 10.0 and p.x < BEAM_END and not player.in_cutscene and player.state != 3:
		_beam_t -= delta
		if _beam_t <= 0.0:
			_spawn_beam()
	var view := _view_rect()
	var ahead: Node2D = null
	for b in _beams.duplicate():
		b.position.x -= TRAIN_SPEED * _speed * delta
		_beam_hits(b)
		if b.position.x < view.position.x - 80.0:
			_beams.erase(b)
			b.queue_free()
		elif b.position.x > view.end.x + 4.0 and (ahead == null or b.position.x < ahead.position.x):
			ahead = b
	_duck_gangsters(delta)
	# varovanie na pravom okraji obrazovky, kým je nosník ešte za ním
	_blink += delta
	_warn.visible = ahead != null and fmod(_blink, 0.36) < 0.22
	if ahead:
		var screen: Vector2 = get_viewport().get_canvas_transform() * ahead.position
		_warn.position = Vector2(get_viewport().get_visible_rect().size.x - 16.0, screen.y - 22.0).round()


func _spawn_beam() -> void:
	_beam_n += 1
	_beam_t = randf_range(3.0, 4.6) * (1.5 if _curve_t >= 0.0 else 1.0)   # v zákrute redšie
	var x: float = _view_rect().end.x + 260.0   # mimo obrazovky – ku Riccovi doletí asi za 2 s (keď beží oproti, skôr)
	_add_beam(x)
	if _beam_n > 3 and _curve_t < 0.0 and randf() < 0.35:   # neskôr občas dva tesne za sebou
		_add_beam(x + 120.0)
	Sfx.play(&"train_bell", Vector2.INF, -12.0, 0.03)
	if _beam_n == 1:
		_once(&"low_bridge", "LOW BRIDGE AHEAD! SLIDE UNDER IT (%s)\nOR DUCK BEHIND A VENT." % KeyBindings.short(&"slide"))


func _add_beam(x: float) -> void:
	var b := Node2D.new()
	b.position = Vector2(x, ROOF_Y - BEAM_CLEAR)   # poloha = stred spodku nosníka
	b.z_index = 6
	var s := Sprite2D.new()
	s.texture = BEAM_TEX
	s.centered = false
	s.position = Vector2(-16, -220)
	b.add_child(s)
	var lamp := Sprite2D.new()   # červené návestidlo na boku mosta
	lamp.texture = SIGNAL_TEX
	lamp.centered = false
	lamp.position = Vector2(-26, -40)
	b.add_child(lamp)
	var glow := Sprite2D.new()
	glow.texture = GLOW
	glow.modulate = Color(1.0, 0.25, 0.15, 0.55)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.position = Vector2(-22, -33)
	glow.scale = Vector2(0.7, 0.7)
	b.add_child(glow)
	b.set_meta(&"whoosh", false)
	add_child(b)
	_beams.append(b)


## Kto na streche siaha vyššie ako spodok nosníka, toho zasiahne
func _beam_hits(b: Node2D) -> void:
	var bottom: float = b.position.y
	var p: Vector2 = player.global_position
	var dx: float = absf(p.x - b.position.x)
	if not b.get_meta(&"whoosh") and dx < 60.0 and p.y < ROOF_Y + 10.0:
		b.set_meta(&"whoosh", true)
		Sfx.play(&"beam_whoosh", b.position, -4.0)
	if player.state != 3 and dx < BEAM_HALF + 8.0 and p.y - _player_height() < bottom and p.y > bottom - 260.0:
		if player.invulnerable_timer <= 0.0:
			player.take_damage(BEAM_DAMAGE, Vector2(b.position.x + 30.0, p.y - 20.0))   # odhodí ho dozadu (proti smeru jazdy)
			Sfx.play(&"beam_clang", b.position, 0.0)
			_once(&"beam_hit", "TOLD YA. LOW BRIDGE.")
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var e := g as Node2D
		if e == null or not _on_roof(e) or absf(e.global_position.x - b.position.x) > BEAM_HALF + 8.0:
			continue
		if _aware(e):
			e.take_hit(99.0, Vector2(-1.0, -0.3))
			Sfx.play(&"beam_clang", b.position, 0.0)
			_once(&"beam_kill", "HE SHOULDA DUCKED.")


## Výška Ricca nad nohami podľa stavu (šmyk – leží na bruchu, skrčený za krytom, inak stojí / skáče)
func _player_height() -> float:
	if player.state == 4:   # SLIDE
		return 24.0
	return 22.0 if player.ducked else 38.0


## Mafián na streche vozňa alebo expresu (nie mŕtvy)
func _on_roof(e: Node2D) -> bool:
	return int(e.get(&"state")) != 10 and e.global_position.y < ROOF_Y + 4.0 and e.global_position.y > ROOF_Y - 60.0


## Vie o Riccovi a práve po ňom ide (mieri, strieľa, beží, bije) – na nosník zabudne
func _aware(e: Node2D) -> bool:
	var st: int = int(e.get(&"state"))
	return st >= 2 and st <= 8   # AIM … RECOVER (Gangster.State)


## Mafiáni, čo o Riccovi nevedia, sa pred nosníkom prikrčia (kostra sa stlačí k nohám)
func _duck_gangsters(delta: float) -> void:
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var e := g as Node2D
		if e == null:
			continue
		var rig := e.get(&"rig") as Node2D
		if rig == null:
			continue
		var near: bool = false
		if _on_roof(e) and not _aware(e):
			for b in _beams:
				var d: float = b.position.x - e.global_position.x
				if d > -BEAM_HALF - 10.0 and d < DUCK_NEAR:
					near = true
					break
		rig.scale.y = move_toward(rig.scale.y, 0.6 if near else 1.0, delta * 5.0)


func _make_warn() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_warn = Label.new()
	_warn.text = "!"
	_warn.add_theme_font_override(&"font", FONT)
	_warn.add_theme_font_size_override(&"font_size", 16)
	_warn.add_theme_color_override(&"font_color", Color8(255, 80, 60))
	_warn.add_theme_color_override(&"font_outline_color", Color8(20, 6, 6))
	_warn.add_theme_constant_override(&"outline_size", 6)
	_warn.visible = false
	layer.add_child(_warn)


## Viditeľná časť sveta (kamera)
func _view_rect() -> Rect2:
	var ct := get_viewport().get_canvas_transform()
	var sc: Vector2 = ct.get_scale()
	return Rect2(-ct.origin / sc, get_viewport().get_visible_rect().size / sc)


# ---------------------------------------------------------------- prierezy a Colt

## Predná stena vozňa zmizne, keď je Ricco vnútri (prierez ako v návrhu B)
func _update_walls(delta: float) -> void:
	var p: Vector2 = player.global_position
	for w in _walls:
		var r: Vector2 = w[1]
		var inside: bool = p.x > r.x and p.x < r.y and p.y > ROOF_Y + 14.0
		var c := w[0] as CanvasItem
		c.modulate.a = move_toward(c.modulate.a, 0.0 if inside else 1.0, delta * 4.0)


func _on_weapon(w: WeaponData) -> void:
	if w != null and w.name == "Pistol":   # weapons/pistol/pistol.tres = Colt 1911 (ui/arsenal)
		_once(&"colt", "A COLT 1911. NOW THAT'S\nA GENTLEMAN'S PIECE.")
