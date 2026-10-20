extends Level2
## Kapitola II – Wharf Rats, časť 3: mraziareň Fontana Shipping (návrh A – háky na koľajnici + ľad). Sem vedú dvere skladu z Pier 13.
## Časti (tools/build_coldstore.gd): príjem tovaru (whisky sa prebaľuje do rybích debien) → mraziareň 1 (ľad, háky na mäso,
##   mafián vo veste) → chodba s potrubím (len šmykom, para) → mraziareň 2 (regály, druhá koľajnica, lávka, rozbitá debna „tresky“) →
##   kancelária Lou na lávke (účtovná kniha = stopa: S.S. Margaret odpláva o 2:00) → tunel k lodi (schody, pás) → vráta k lodi = koniec časti.
## Celá mraziareň je tma (player.dark_area): vidno ťa len pod lampami. Visiace mäso zakryje výhľad aj guľky (vrstva 32).
## Checkpointy (Level2.checkpoint): 7 = príchod zo skladu, 8 = mraziareň 1, 9 = mraziareň 2, 10 = lávka pred kanceláriou.
## Scénu generuje tools/build_coldstore.gd.
## Godot docs: classes/class_tween, classes/class_label, classes/class_cpuparticles2d

const COLD_MAP := Rect2i(0, -304, 4992, 360)        ## hranice kamery (px) – zvisle presne jedna obrazovka
const LUPARA := preload("res://weapons/lupara/lupara.tres")
const LEDGER := preload("res://levels/level2/art/cold/ledger.png")
const LEDGER_BIG := preload("res://levels/level2/art/cold/ledger_big.png")
const PUFF := preload("res://levels/level2/art/cold/puff.png")
const COLD := Color(0.78, 0.86, 0.95)               ## mafiáni v studenom svetle mraziarne
const WARM := Color(1.0, 0.92, 0.82)                ## strážca v kancelárii (teplá žiarovka)
const FREEZE_X := Vector2(44 * 16, 236 * 16)        ## px – v týchto miestnostiach je mráz (Riccovi ide para od zobáka)

const ARRIVE: Array[String] = [
	"Fontana Shipping. Smells like fish and money.",
	"Somewhere in here Lou keeps his books.",
]

var _ledger: InteractSpot
var _say_queue: Array[String] = []
var _say_busy: float = 0.0
var _breath_t: float = 1.5
var _vents: Array[Node2D] = []
var _vent_t: Array[float] = []


func _ready() -> void:
	var black := _fade_rect()
	black.color.a = 1.0
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	pcam = player.get_node(^"PhantomCamera2D")
	_set_limits(COLD_MAP)
	var help := get_node_or_null(^"HUD/ControlsHelp") as Control
	if help:
		help.visible = false
	checkpoint = maxi(checkpoint, 7)
	# výbava z prístavu (derringer alebo revolver) + lupara, ak ju vzal rybárovi
	var list: Array[WeaponData] = [REVOLVER if has_revolver else DERRINGER]
	if has_lupara:
		list.append(LUPARA)
	player.set_loadout(list)
	player.focus.unlocked = true
	player.dark_area = true
	player.light_zones = 0
	var spawn := get_node_or_null(NodePath("Spawn%d" % checkpoint)) as Node2D
	if spawn:
		player.global_position = spawn.global_position
	pcam.teleport_position.call_deferred()
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var rig := g.get(&"rig") as Node2D
		if rig:
			rig.modulate = WARM if g.name == &"OfficeGuard" else COLD
	if not ledger_read:
		_spawn_ledger()
	for n in get_children():
		if n.name.begins_with("Vent"):
			_vents.append(n)
			_vent_t.append(randf_range(0.5, 3.0))
	_connect(^"CrateBark", func(): _once(&"crates", "FISH ON THE LABEL,\nWHISKY IN THE BOX. CLASSIC LOU."))
	_connect(^"IceBark", func(): _once(&"ice", "COLD ENOUGH FOR YA, KID?\nYOU'RE A PENGUIN. ENJOY IT."))
	_connect(^"HookBark", func(): _once(&"hook", "GRAB A HOOK, KID.\nRIDE IT LIKE THE EL."))
	_connect(^"VestBark", func(): _once(&"vest", "THAT ONE'S GOT A VEST.\nAIM FOR THE HEAD, OR GET BEHIND HIM."))
	_connect(^"PipeBark", func(): _once(&"pipes", "TOO LOW TO WALK.\nSO DON'T WALK."))
	_connect(^"RyeBark", func(): _once(&"rye", "FROZEN COD, MY EYE.\nTHAT'S CANADIAN RYE."))
	_connect(^"ExitDoor", _on_exit)
	for t in [[^"Checkpoint8", 8], [^"Checkpoint9", 9], [^"Checkpoint10", 10]]:
		_connect(t[0], func(): checkpoint = maxi(checkpoint, t[1]))
	Sfx.loop(&"cold", self, Vector2.INF, -5.0)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(black, "color:a", 0.0, 0.8)
	tw.tween_callback(black.get_parent().queue_free)
	if checkpoint == 7 and not coldstore_arrived:
		coldstore_arrived = true
		_arrive()


## Ricco vojde zadnými dverami skladu a rozhliadne sa
func _arrive() -> void:
	player.set_cutscene(true)
	var target: Vector2 = player.global_position
	player.global_position = target + Vector2(-30, 0)
	player.modulate.a = 0.0
	Sfx.play(&"door_close", target, -6.0)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(player, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(player, "global_position", target, 0.9)
	await tw.finished
	player.set_cutscene(false)
	await _wait(0.4)
	ThoughtBox.think(self, ARRIVE)


func _process(delta: float) -> void:
	if player == null:
		return
	_exit_hint_t -= delta
	_say_busy -= delta
	if _say_busy <= 0.0 and not _say_queue.is_empty():
		_say_busy = 3.4
		bark(_say_queue.pop_front())
	# v mraziarňach Riccovi ide para od zobáka
	var px: float = player.global_position.x
	if px > FREEZE_X.x and px < FREEZE_X.y and player.get(&"state") != 3:
		_breath_t -= delta
		if _breath_t <= 0.0:
			_breath_t = randf_range(2.2, 3.4)
			_breath(player.global_position + Vector2(8.0 * player.facing, -30.0), player.facing)
	# para z potrubia občas zasyčí (len keď je Ricco blízko)
	for i in _vents.size():
		_vent_t[i] -= delta
		if _vent_t[i] <= 0.0:
			_vent_t[i] = randf_range(2.5, 4.5)
			if absf(_vents[i].global_position.x - px) < 240.0:
				Sfx.play(&"steam_hiss", _vents[i].global_position, -12.0, 0.15)
	if _ghost:
		_ghost_t += delta
		_ghost.global_position = player.global_position + Vector2(26.0 * player.facing, -42.0 + sin(_ghost_t * 2.2) * 2.0)
		_ghost.flip_h = player.facing < 0.0
		_ghost_glow.global_position = _ghost.global_position


## Obláčik pary od zobáka – stúpa a rozplynie sa
func _breath(pos: Vector2, dir: float) -> void:
	var s := Sprite2D.new()
	s.texture = PUFF
	s.modulate = Color(0.92, 0.97, 1.0, 0.55)
	s.scale = Vector2(0.4, 0.4)
	s.z_index = 6
	add_child(s)
	s.global_position = pos
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "global_position", pos + Vector2(10.0 * dir, -10.0), 1.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2(1.1, 1.1), 1.2)
	tw.tween_property(s, "modulate:a", 0.0, 1.2)
	tw.chain().tween_callback(s.queue_free)


## Hláška ducha do radu – zaznie, keď dobehne predošlá
func say(t: String) -> void:
	_say_queue.append(t)


## Hláška len raz za hru (prežije smrť – statické cold_barks)
func _once(key: StringName, t: String) -> void:
	if key in cold_barks:
		return
	cold_barks.append(key)
	say(t)


# ---------------------------------------------------------------- účtovná kniha (stopa)

## Kniha leží na stole Lou – lesklá; Ricco pri nej stlačí F (použiť) a prečíta si ju (world/fx/interact_spot.gd)
func _spawn_ledger() -> void:
	var spot := get_node_or_null(^"LedgerSpot") as Node2D
	if spot == null:
		return
	_ledger = InteractSpot.new()
	_ledger.verb = "READ"
	_ledger.hint_offset = Vector2(0, -26)
	add_child(_ledger)
	_ledger.global_position = spot.global_position
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(40, 44)
	cs.shape = r
	cs.position = Vector2(0, 12)
	_ledger.add_child(cs)
	var spr := Sprite2D.new()
	spr.texture = LEDGER
	spr.position = Vector2(0, -4)
	spr.z_index = 1
	_ledger.add_child(spr)
	var shine := _light_sprite(Vector2.ZERO, Color(1.0, 0.85, 0.5, 0.35), 0.25)
	shine.reparent(_ledger, false)
	shine.position = Vector2(0, -4)
	var tw := shine.create_tween().set_loops()
	tw.tween_property(shine, "modulate:a", 0.08, 0.7)
	tw.tween_property(shine, "modulate:a", 0.35, 0.7)
	_ledger.used.connect(_read_ledger)


## Stopa: Lou posiela dnes v noci 400 debien whisky na S.S. Margaret – po Donových trasách
func _read_ledger() -> void:
	if ledger_read:
		return
	ledger_read = true
	Sfx.play(&"pickup_ammo")
	_ledger.queue_free()
	await ReadCard.open(self, LEDGER_BIG).closed   # hra stojí, kým si ju Ricco nedočíta (ui/dialog/read_card.gd)
	var lines: Array[String] = ["Lou's books. 'S.S. Margaret. Sails two a.m.'"]
	await ThoughtBox.think(self, lines).finished
	_ghost_show(true)
	await _wait(0.6)
	bark("MY ROUTES. MY BOATS.\nHE DIDN'T EVEN CHANGE THE NAMES.")
	await _wait(3.6)
	_ghost_show(false)
	var next: Array[String] = ["Lou's shippin' tonight. Two a.m. on the Margaret.", "Then I got a boat to catch."]
	ThoughtBox.think(self, next)


# ---------------------------------------------------------------- koniec časti

## Vráta k lodi: bez knihy ešte nie – s ňou Ricco ide pásom do podpalubia S.S. Margaret (margaret.tscn, checkpoint 11)
func _on_exit() -> void:
	if _leaving:
		return
	if not ledger_read:
		if _exit_hint_t <= 0.0:
			_exit_hint_t = 8.0
			var lines: Array[String] = ["Not without somethin' on Lou. His office is up top."]
			ThoughtBox.think(self, lines)
		return
	_leaving = true
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	var black := _fade_rect()
	var tw := create_tween()
	tw.tween_property(player, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(black, "color:a", 1.0, 1.0)
	await tw.finished
	checkpoint = 11
	LoadingScreen.go(get_tree(), MARGARET, 0.6)
