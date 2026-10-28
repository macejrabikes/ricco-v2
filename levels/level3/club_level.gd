class_name ClubLevel
extends Level3
## Spoločný základ jazzového klubu The Blue Canary v Harleme (kapitola III – časti 5 a 6: club.gd, club_back.gd).
## Poplach: keď si Ricca v klube všimne mafián (stav AIM … RECOVER), keď v sále vystrelí alebo keď spadne luster,
## klub „stíchne“ – kapela prestane hrať a uteká, hostia pri stoloch sa skrčia pod stoly, stojaci hostia a čašníci
## utekajú k východu, hudba sa zmení na naháňačku a scéna pošle posily (spawn_reinforcement).
## Hostia: skupina „seated“ (sediaci – skrčia sa), „runners“ (stojaci, čašníci, kapela – utečú), „band“ (prestane hrať).
## Godot docs: classes/class_tween, classes/class_packedscene

const AWARE_FROM := 2      ## Gangster.State.AIM
const AWARE_TO := 8        ## Gangster.State.RECOVER
const CALM_MUSIC := &"night_cafe"
const ALARM_MUSIC := &"intensity"
const RUN_SPEED := 95.0    ## px/s – ako rýchlo hostia utekajú

var alarm_on: bool = false
var exits: PackedFloat32Array = PackedFloat32Array()   ## x východov, kam utekajú hostia (najbližší)
var _poll: float = 0.0
var _fleeing: Array = []             ## [Sprite2D, x východu]
var _crowd: AudioStreamPlayer


func _club_ready() -> void:
	player.shot_fired.connect(_on_shot)
	Sfx.music(CALM_MUSIC)


func _process(delta: float) -> void:
	if player == null:
		return
	_tick_say(delta)
	_club_tick(delta)


func _club_tick(delta: float) -> void:
	_tick_flee(delta)
	if alarm_on:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.2
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var g := n as Gangster
		if g and int(g.state) >= AWARE_FROM and int(g.state) <= AWARE_TO and _in_club(g.global_position):
			raise_alarm()
			return


## Je miesto v klube (poplach tu vyruší hostí)? Scéna spresní (napr. ulica a kotolňa nie)
func _in_club(_pos: Vector2) -> bool:
	return true


## Riccov výstrel v klube = poplach (klobúk je potichu)
func _on_shot() -> void:
	if not alarm_on and _in_club(player.global_position):
		raise_alarm()


func raise_alarm() -> void:
	if alarm_on:
		return
	alarm_on = true
	Sfx.music(ALARM_MUSIC, 0.6)
	if _crowd:
		create_tween().tween_property(_crowd, "volume_db", -40.0, 1.5)
	for n in get_tree().get_nodes_in_group(&"band"):
		var b := n as Guest
		if b and not b.dead:
			b.loop = false
			b.frame = 0
	for n in get_tree().get_nodes_in_group(&"seated"):
		_duck(n as Guest)
	for n in get_tree().get_nodes_in_group(&"runners"):
		_flee(n as Guest)
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var g := n as Gangster
		if g and _in_club(g.global_position):
			g.alarm()
	_on_alarm()


## Scéna: čo ešte sa stane pri poplachu (posily, dvere…)
func _on_alarm() -> void:
	pass


## Sediaci hosť sa skrčí za stôl (už nič nevidí, nekričí)
func _duck(g: Guest) -> void:
	if g == null or g.dead:
		return
	g.witness = false
	g.loop = false
	g.frame = 0
	g.set_process(false)
	var tw := g.create_tween()
	tw.tween_interval(randf_range(0.0, 0.4))
	tw.tween_property(g, "offset:y", g.offset.y + 18.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Stojaci hosť / čašník / muzikant uteká k najbližšiemu východu
func _flee(g: Guest) -> void:
	if g == null or g.dead or exits.is_empty():
		return
	g.witness = false
	if g.get(&"walking") != null:
		g.set(&"walking", false)
	var best: float = exits[0]
	for x in exits:
		if absf(x - g.global_position.x) < absf(best - g.global_position.x):
			best = x
	g.flip_h = best < g.global_position.x
	_fleeing.append([g, best, randf_range(0.1, 0.7)])


func _tick_flee(delta: float) -> void:
	for e in _fleeing.duplicate():
		var g := e[0] as Guest
		if not is_instance_valid(g) or g.dead:
			_fleeing.erase(e)
			continue
		if e[2] > 0.0:   # chvíľu sa spamätáva
			e[2] -= delta
			continue
		var dx: float = e[1] - g.global_position.x
		g.global_position.x += signf(dx) * minf(absf(dx), RUN_SPEED * delta)
		g.rotation = sin(Time.get_ticks_msec() * 0.03) * 0.06   # beží – kýve sa
		if absf(dx) < 2.0:
			_fleeing.erase(e)
			g.witness = false
			var tw := g.create_tween()
			tw.tween_property(g, "modulate:a", 0.0, 0.4)
			tw.tween_callback(g.queue_free)


## Posila pri poplachu: mafián zo scény path na mieste pos, hneď vie o Riccovi
func spawn_reinforcement(path: String, pos: Vector2, props: Dictionary = {}) -> Gangster:
	var g := (load(path) as PackedScene).instantiate() as Gangster
	for k in props:
		g.set(k, props[k])
	g.respawn_time = 0.0
	g.position = pos
	add_child(g)
	if g.rig:
		g.rig.modulate = NIGHT
	g.alarm()
	return g


## Najbližšie značky (skupina „reinforce“) k Riccovi, ale aspoň min_dist od neho (aby sa neobjavili pred nosom)
func reinforce_points(count: int, min_dist: float = 260.0) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for n in get_tree().get_nodes_in_group(&"reinforce"):
		var m := n as Node2D
		if m and m.global_position.distance_to(player.global_position) >= min_dist:
			pts.append(m.global_position)
	pts.sort_custom(func(a: Vector2, b: Vector2): return a.distance_to(player.global_position) < b.distance_to(player.global_position))
	return pts.slice(0, count)


## Žije mafián na ceste (je v strome a nie je mŕtvy)?
func alive(path: NodePath) -> bool:
	var g := get_node_or_null(path) as Gangster
	return g != null and g.state != Gangster.State.DEAD
