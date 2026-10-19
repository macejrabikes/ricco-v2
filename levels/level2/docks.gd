extends Level2
## Kapitola II – Wharf Rats, časť 2: prístav v noci, móla v hmle (návrh A2). Sem vedie tunel z krypty na cintoríne.
## Časti (tools/build_docks.gd): nábrežie s pašeráckym kanálom → mólo 1 (dokár s hákom a lampášom, popod mólo sa pláva) →
##   rybárska loďka (rybár s luparou – zozadu ho zložíš a lupara je tvoja) → mólo 2 (pes na reťazi, strelci, lúč majáka) →
##   vlnolam s majákom (v diaľke loď S.S. Margaret, za oknom mostíka Big Lou – duch ho spozná) →
##   Pier 13 (dokár s hákom, strelec) → dvere skladu Fontana Shipping = ďalej mraziareň (coldstore.gd).
## Celý prístav je tma (player.dark_area): vidno ťa len v lúči majáka, pri lampáši loďky, dokárov a nad dverami skladu.
## Pod hladinou ťa nevidí nikto a pes ťa necíti.
## Checkpointy (Level2.checkpoint): 4 = príchod z tunela, 5 = mólo 2, 6 = vlnolam. Scénu generuje tools/build_docks.gd.
## Godot docs: classes/class_tween, classes/class_parallax2d

const DOCKS_MAP := Rect2i(0, -264, 2512, 360)       ## hranice kamery (px) – dno je na y = 80, vidno kúsok pod vodou
const LUPARA := preload("res://weapons/lupara/lupara.tres")

const ARRIVE: Array[String] = [
	"The old rum tunnel. Comes out right under the waterfront.",
	"Pier 13's down the line somewhere. Big Lou's turf.",
]

var _cigar: Sprite2D
var _cigar_t: float = 3.0
var _horn_t: float = 9.0
var _say_queue: Array[String] = []
var _say_busy: float = 0.0


func _ready() -> void:
	var black := _fade_rect()
	black.color.a = 1.0
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	pcam = player.get_node(^"PhantomCamera2D")
	_set_limits(DOCKS_MAP)
	var help := get_node_or_null(^"HUD/ControlsHelp") as Control
	if help:
		help.visible = false
	checkpoint = maxi(checkpoint, 4)
	# výbava z cintorína (derringer alebo revolver) + lupara, ak ju už vzal rybárovi
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
	for g in get_tree().get_nodes_in_group(&"enemies") + get_tree().get_nodes_in_group(&"dogs"):
		var rig := g.get(&"rig") as Node2D
		if rig:
			rig.modulate = NIGHT
		elif g.get(&"sprite"):
			(g.sprite as CanvasItem).modulate = NIGHT
	# rybár už lupara nemá (Ricco mu ju vzal pred smrťou) – na loďke nikto nie je
	if has_lupara:
		var f := get_node_or_null(^"Fisherman")
		if f:
			f.queue_free()
	_cigar = get_node_or_null(^"FarShip/Ship/Cigar") as Sprite2D
	_connect(^"SwimBark", func(): _once(&"swim", "SWIM, KID. YOU'RE A BIRD,\nBUT THE USEFUL KIND."))
	_connect(^"LightBark", func(): _once(&"light", "WATCH THAT LIGHTHOUSE.\nWHEN IT COMES, YOU DUCK UNDER."))
	_connect(^"DogBark", func(): _once(&"dog", "MUTT'S GOT A NOSE ON HIM.\nUNDER THE WATER HE CAN'T SMELL YA."))
	_connect(^"LouView", _on_lou_view)
	_connect(^"ExitDoor", _on_exit)
	for t in [[^"Checkpoint5", 5], [^"Checkpoint6", 6]]:
		_connect(t[0], func(): checkpoint = maxi(checkpoint, t[1]))
	Sfx.loop(&"docks", self, Vector2.INF, -3.0)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(black, "color:a", 0.0, 0.8)
	tw.tween_callback(black.get_parent().queue_free)
	if checkpoint == 4 and not docks_arrived:
		docks_arrived = true
		_arrive()


## Ricco vylezie z kanála (tunel z krypty) a rozhliadne sa
func _arrive() -> void:
	player.set_cutscene(true)
	var target: Vector2 = player.global_position
	player.global_position = target + Vector2(-26, 0)
	player.modulate.a = 0.0
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
	# hmlová siréna z mora občas zatrúbi
	_horn_t -= delta
	if _horn_t <= 0.0:
		_horn_t = randf_range(26.0, 40.0)
		Sfx.play(&"foghorn", Vector2.INF, -12.0, 0.0, &"Ambience")
	# Big Lou na mostíku si občas potiahne z cigary
	_cigar_t -= delta
	if _cigar and _cigar_t <= 0.0:
		_cigar_t = randf_range(3.0, 6.0)
		var tw := _cigar.create_tween()
		tw.tween_property(_cigar, "modulate:a", 0.9, 0.5)
		tw.tween_property(_cigar, "modulate:a", 0.25, 1.4)
	# lupara: Ricco ju zobral rybárovi (zo zeme – voľné miesto, berie sa sama)
	if not has_lupara and LUPARA in player.loadout:
		has_lupara = true
		say("A LUPARA! NOW THAT'S\nA SICILIAN HELLO.")
	# hlášky ducha po jednej (aby sa neprekrývali)
	_say_busy -= delta
	if _say_busy <= 0.0 and not _say_queue.is_empty():
		_say_busy = 3.4
		bark(_say_queue.pop_front())
	# duch vedľa Ricca (pri pohľade na loď)
	if _ghost:
		_ghost_t += delta
		_ghost.global_position = player.global_position + Vector2(26.0 * player.facing, -42.0 + sin(_ghost_t * 2.2) * 2.0)
		_ghost.flip_h = player.facing < 0.0
		_ghost_glow.global_position = _ghost.global_position


## Hláška ducha do radu – zaznie, keď dobehne predošlá
func say(t: String) -> void:
	_say_queue.append(t)


## Hláška len raz za hru (prežije smrť – statické docks_barks)
func _once(key: StringName, t: String) -> void:
	if key in docks_barks:
		return
	docks_barks.append(key)
	say(t)


## Vlnolam: v diaľke kotví S.S. Margaret – duch spozná Big Lou za oknom mostíka
var _lou_playing: bool = false

func _on_lou_view() -> void:
	if lou_seen or _lou_playing:
		return
	_lou_playing = true
	checkpoint = maxi(checkpoint, 6)
	_ghost_show(true)
	await _wait(0.6)
	bark("SEE THE FAT ONE ON THE BRIDGE?\nTHAT'S LOU. MY 'FRIEND'.")
	await _wait(3.6)
	bark("TWENTY YEARS HE ATE\nAT MY TABLE.")
	await _wait(3.6)
	var lines: Array[String] = ["Big Lou Fontana. Smokin' cigars on a boat full of Canadian hooch.", "Whatever he's hidin', it goes through that warehouse on Pier 13."]
	await ThoughtBox.think(self, lines).finished
	_ghost_show(false)
	lou_seen = true
	_lou_playing = false


## Dvere skladu Fontana Shipping – Ricco vojde dnu, ďalej mraziareň (coldstore.tscn)
func _on_exit() -> void:
	if _leaving:
		return
	_leaving = true
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	var black := _fade_rect()
	var tw := create_tween()
	tw.tween_property(player, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(black, "color:a", 1.0, 1.0)
	await tw.finished
	checkpoint = 7
	LoadingScreen.go(get_tree(), COLDSTORE, 0.6)
