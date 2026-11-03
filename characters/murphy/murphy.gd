class_name ChiefMurphy
extends Gangster
## Police Chief Murphy – boss konca kapitoly III v zápche na Queensboro Bridge (levels/level3/chase.gd). Šéf polície
## na výplatnej listine Margaret: biela čiapka so zlatým pásom, dvojradový kabát so zlatými gombíkmi, sivé fúzy a Thompson
## s bubnom. Telo je z častí ako každý Gangster (kind „chief“), mozog je vlastný. Zdravie má tri fázy (značky v
## ui/boss_bar.gd), pri prechode je chvíľu nezraniteľný (guľky sa odrazia).
##
## 1. fáza – strecha obrneného voza (levels/level3/patrol_wagon.gd): krčí sa za zábradlím (guľky sa odrazia), vystrčí sa,
##    zamieri (červená čiara) a pustí dávku. Megafónom volá posily – stage(&"summon"): level otvorí zadné dvere voza
##    a vybehne z nich policajt. → zoskočí zo strechy na most.
## 2. fáza – pešo: mieri, dávka 8, po dvoch dávkach mení bubon (okno na útok – keď Ricco pribehne, kopne ho), zblízka kopne.
##    Klobúk ho omráči, šmyk ho podkopne. → zadnými dverami vlezie do voza.
## 3. fáza – nájazdy vozom: voz cúvne za pravý okraj mosta, zatrúbi, rozsvieti reflektor a vytúruje motor (výstraha),
##    potom sa rúti doľava. Na ceste zrazí Ricca (2 kúsky pizze) – hore na lávke alebo za barikádami vľavo je v bezpečí.
##    Po zabrzdení Murphy vystúpi omámený (chvíľa na streľbu); cez okno kabíny sa dá trafiť aj za jazdy (polovičný damage).
## Smrť: zrúti sa na cestu, stage(&"dying") a died – ďalej režíruje level (koniec kapitoly III).
## Godot docs: classes/class_characterbody2d, classes/class_tween

signal health_changed(health: float, max_health: float)
signal died
## Udalosti pre level (hlášky, réžia): summon, duck, jump_down, landed, reload, kick, to_wagon, telegraph, ram, dazed, dying
signal stage(name: StringName)

enum Boss { WAIT, DUCK, POP, AIM, BURST, JUMP_DOWN, WALK, RELOAD, KICK, TO_WAGON, DRIVE_OUT, TELEGRAPH, RAM, DAZED, SCRIPTED }

const PHASE_HP := 10.0                  ## zdravia na fázu (max_health = 30 → tri fázy)
const ROOF_X := -60.0                   ## px od stredu voza (proti smeru jazdy) – kde stojí na streche
const DUCK_SCALE := 0.55                ## kostra prikrčená za zábradlím

@export_group("Chief Murphy")
@export var wagon_path: NodePath
@export var foot_span: Vector2 = Vector2(3000, 3280)  ## px (globálne x) – kade chodí v 2. fáze
@export var ram_from: float = 3960.0                  ## px – stred voza mimo obrazovky (vpravo) pred nájazdom
@export var ram_peek: float = 3810.0                  ## px – voz vykukne spoza okraja (reflektor) počas výstrahy
@export var ram_stop: float = 2990.0                  ## px – kde zastane predok voza po nájazde
@export var ram_speed: float = 380.0
@export var kick_range: float = 34.0
@export var reload_time: float = 2.0
@export var dazed_time: float = 2.6
@export var summon_every: float = 12.0

var boss: Boss = Boss.WAIT
var phase: int = 1
var invulnerable: bool = false
var active: bool = false
var in_wagon: bool = false
var wagon: PatrolWagon
var cops_alive: Callable   ## level dodá počítadlo živých policajtov (posily) – func() -> int
var _ducked: bool = false
var _bursts: int = 0
var _walk_t: float = 0.0
var _summon_t: float = 6.0
var _hidden_t: float = 0.0
var _kick_cd: float = 0.0


func _ready() -> void:
	super._ready()
	health = max_health
	add_to_group(&"boss")
	collision_layer = 0   # kým boj nezačne, guľky ním preletia
	wagon = get_node_or_null(wagon_path) as PatrolWagon
	if wagon:
		wagon.window_hit.connect(_on_window_hit)
		wagon.arrived.connect(_on_wagon_arrived)


## Začiatok boja vo fáze p (po smrti Ricca pokračuje v dosiahnutej fáze)
func start(p: int) -> void:
	phase = p
	health = max_health - (p - 1) * PHASE_HP
	health_changed.emit(health, max_health)
	active = true
	visible = true
	collision_layer = 4
	match p:
		1:
			_duck(randf_range(0.8, 1.2))
		2:
			global_position = Vector2(lerpf(foot_span.x, foot_span.y, 0.6), 0.0)
			_next_action()
		3:
			_enter_wagon()
			_drive_out()


func _phase_floor() -> float:
	return maxf(max_health - phase * PHASE_HP, 0.0)


func _on_roof() -> bool:
	return phase == 1 and wagon != null and boss != Boss.JUMP_DOWN


# ---------------------------------------------------------------- hlavná slučka

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	_flash_t -= delta
	flash.visible = _flash_t > 0.0
	_kick_cd -= delta
	if _on_roof():   # stojí na streche voza (pred bojom aj v 1. fáze)
		global_position = wagon.global_position + Vector2(ROOF_X * wagon.facing, PatrolWagon.ROOF_Y)
		velocity = Vector2.ZERO
	if boss == Boss.SCRIPTED or in_wagon or not active:
		laser.visible = false
		if not in_wagon:
			_animate(delta)
		_duck_pose(delta)
		return
	if not _on_roof() and boss != Boss.JUMP_DOWN and not is_on_floor():
		velocity += get_gravity() * delta
	timer -= delta
	if player == null:
		_end_frame(delta)
		return
	var los: bool = _has_los()
	_hidden_t = 0.0 if los else _hidden_t + delta

	if state == State.STUN and boss != Boss.DAZED:   # klobúk / podkopnutie (Gangster.hat_hit, trip) – potom pokračuje v boji
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		laser.visible = false
		if timer <= 0.0 and _tripped:
			_stand_up()
			timer = GETUP_TIME + 0.1
		elif timer <= 0.0 and not _getting_up:
			state = State.AIM
			_next_action()
		_end_frame(delta)
		return

	match boss:
		Boss.DUCK:
			_summon_t -= delta
			if _summon_t <= 0.0 and (not cops_alive.is_valid() or int(cops_alive.call()) < 2):
				_summon_t = summon_every
				stage.emit(&"summon")
			if timer <= 0.0:
				_ducked = false
				boss = Boss.POP
				timer = 0.3
		Boss.POP:
			_face_player()
			if timer <= 0.0:
				_start_aim()
		Boss.AIM:
			_face_player()
			_slow_down(delta)
			_track_aim(delta)
			_update_laser(true)
			if timer <= 0.0:
				if los or phase == 1:
					boss = Boss.BURST
					state = State.SHOOT
					shots_left = burst_count + (2 if phase == 2 else 0)
					timer = 0.0
				else:
					_next_action()
		Boss.BURST:
			_slow_down(delta)
			_track_aim(delta)
			if timer <= 0.0:
				if shots_left > 0:
					shots_left -= 1
					_fire()
					timer = burst_interval
				else:
					_bursts += 1
					if phase == 1:
						_duck(randf_range(1.2, 2.0))
					else:
						_next_action()
		Boss.WALK:
			_walk_t -= delta
			var dx: float = player.global_position.x - global_position.x
			var want: float = signf(dx)
			var nx: float = global_position.x + want * 10.0
			var ok: bool = nx > foot_span.x and nx < foot_span.y and _ledge_ok(want)
			if want != 0.0:
				_set_facing(want)
			velocity.x = want * walk_speed if ok else 0.0
			_aim_low(delta)
			if _walk_t <= 0.0 or not ok or (los and absf(dx) < preferred_range):
				velocity.x = 0.0
				_start_aim()
		Boss.RELOAD:
			_slow_down(delta)
			_aim_low(delta)
			if _player_close(kick_range + 14.0) and _kick_cd <= 0.0:
				_start_kick()
			elif timer <= 0.0:
				_bursts = 0
				Sfx.play(&"mag_in", global_position + Vector2(0, -40), -4.0, 0.05)
				_next_action()
		Boss.KICK:
			_slow_down(delta)
			if timer <= 0.0:
				_kick_hit()
				boss = Boss.WALK
				_walk_t = 0.0
				timer = 0.5
				_next_action.call_deferred()
		Boss.TO_WAGON:
			var door: float = wagon.rear_x() - wagon.facing * 12.0 if wagon else global_position.x
			var lx: float = door - global_position.x
			if absf(lx) < 6.0:
				velocity.x = 0.0
				_board_wagon()
			else:
				_set_facing(signf(lx))
				velocity.x = signf(lx) * walk_speed * 2.4
			_aim_low(delta)
		Boss.DAZED:
			velocity.x = 0.0
			if timer <= 0.0:
				_enter_wagon()
				_drive_out()
	_end_frame(delta)


func _end_frame(delta: float) -> void:
	if boss != Boss.AIM:
		laser.visible = false
	if not _on_roof() and boss != Boss.JUMP_DOWN:
		move_and_slide()
	_animate(delta)
	_duck_pose(delta)


## Prikrčenie za zábradlím strechy (kostra sa stlačí k nohám)
func _duck_pose(delta: float) -> void:
	if rig and state != State.DEAD and boss != Boss.SCRIPTED:
		rig.scale.y = move_toward(rig.scale.y, DUCK_SCALE if _ducked else 1.0, delta * 5.0)


func _slow_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)


func _aim_low(delta: float) -> void:
	var low: float = 0.8 if facing > 0.0 else PI - 0.8
	aim_angle = lerp_angle(aim_angle, low, minf(1.0, 8.0 * delta))


func _has_los() -> bool:
	if player == null or int(player.get(&"state")) == 3:
		return false
	var eye := global_position + Vector2(EYE.x * facing, EYE.y)
	var q := PhysicsRayQueryParameters2D.create(eye, _player_target(), 1 | COVER_LAYER)
	if wagon:
		q.exclude = [wagon.get_rid()]   # zo strechy cez vlastný voz (zábradlie)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _player_close(r: float) -> bool:
	var dx: float = player.global_position.x - global_position.x
	return absf(dx) < r and absf(player.global_position.y - global_position.y) < 30.0


# ---------------------------------------------------------------- rozhodovanie (2. fáza)

func _next_action() -> void:
	if not active or phase != 2:
		return
	if _player_close(kick_range + 6.0) and _kick_cd <= 0.0:
		_start_kick()
		return
	if _bursts >= 2:
		boss = Boss.RELOAD
		state = State.COOLDOWN
		timer = reload_time
		Sfx.play(&"mag_out", global_position + Vector2(0, -40), -4.0, 0.05)
		stage.emit(&"reload")
		return
	if _hidden_t > 0.6 or absf(player.global_position.x - global_position.x) > preferred_range + 40.0:
		boss = Boss.WALK
		_walk_t = 1.8
		return
	_start_aim()


func _start_aim() -> void:
	boss = Boss.AIM
	state = State.AIM
	timer = aim_time if phase == 1 else aim_time * 0.8


func _duck(t: float) -> void:
	boss = Boss.DUCK
	state = State.IDLE
	_ducked = true
	timer = t
	laser.visible = false


func _start_kick() -> void:
	boss = Boss.KICK
	state = State.WINDUP
	timer = 0.3
	_face_player()
	Sfx.play(&"punch_swing", global_position, -4.0)


func _kick_hit() -> void:
	_kick_cd = 1.6
	leg_front.rotation = -1.0   # kopanec (animácia nohu vráti)
	stage.emit(&"kick")
	if not _player_close(kick_range + 8.0) or signf(player.global_position.x - global_position.x) != facing:
		return
	Sfx.play(&"punch_hit", player.global_position, 0.0)
	if player.has_method(&"take_damage"):
		player.take_damage(1, global_position + Vector2(0, -30))
	player.velocity = Vector2(facing * 280.0, -200.0)
	Burst.spawn(get_tree().current_scene, player.global_position + Vector2(0, -16), Vector2(facing, -0.3), Color(1, 0.9, 0.5), 6, 80.0)


# ---------------------------------------------------------------- prechody fáz

## 1 → 2: zoskočí zo strechy voza (oblúkom pred zadné dvere)
func _jump_down() -> void:
	invulnerable = true
	_ducked = false
	boss = Boss.JUMP_DOWN
	state = State.IDLE
	laser.visible = false
	stage.emit(&"jump_down")
	var from: Vector2 = global_position
	var to := Vector2(wagon.rear_x() - wagon.facing * 46.0, 0.0) if wagon else from + Vector2(-60, 114)
	_set_facing(signf(to.x - from.x) if to.x != from.x else facing)
	var arc := func(k: float) -> void:
		global_position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 46.0)
	var tw := create_tween()
	tw.tween_method(arc, 0.0, 1.0, 0.7)
	tw.tween_callback(_landed)


func _landed() -> void:
	Sfx.play(&"body_thud", global_position, 2.0, 0.05)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -2), Vector2.UP, Color(0.75, 0.7, 0.66, 0.6), 10, 60.0, Vector2(0, 60), 0.5)
	if player:
		player.set(&"shake_timer", 0.2)
	phase = 2
	invulnerable = false
	_bursts = 0
	velocity = Vector2.ZERO
	stage.emit(&"landed")
	boss = Boss.WALK
	timer = 0.0
	_walk_t = 0.0
	_next_action()


## 2 → 3: beží k zadným dverám voza
func _to_wagon() -> void:
	invulnerable = true
	boss = Boss.TO_WAGON
	state = State.IDLE
	laser.visible = false
	stage.emit(&"to_wagon")


func _board_wagon() -> void:
	if wagon:
		wagon.open_doors()
	boss = Boss.SCRIPTED
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func():
		phase = 3
		_enter_wagon()
		if wagon:
			wagon.close_doors()
		invulnerable = false)
	tw.tween_interval(0.6)
	tw.tween_callback(_drive_out)


## Murphy je vo voze (nevidno ho, guľky ním preletia – zasiahnuť sa dá len cez okno kabíny)
func _enter_wagon() -> void:
	in_wagon = true
	visible = false
	collision_layer = 0
	velocity = Vector2.ZERO
	laser.visible = false
	state = State.IDLE


## 3. fáza: voz odíde (cúvne) za pravý okraj mosta
func _drive_out() -> void:
	if wagon == null or not active:
		return
	boss = Boss.DRIVE_OUT
	wagon.ram = false
	wagon.set_window(false)
	wagon.drive_to(ram_from, 300.0)


func _on_wagon_arrived() -> void:
	if not active or wagon == null:
		return
	match boss:
		Boss.DRIVE_OUT:
			wagon.set_facing(-1.0)   # mimo obrazovky sa otočí predkom k Riccovi
			boss = Boss.TELEGRAPH
			stage.emit(&"telegraph")
			wagon.lights(true)
			wagon.rev()
			wagon.set_window(true)
			Sfx.play(&"klaxon", Vector2(ram_peek - 140.0, -60.0), 0.0, 0.03)
			wagon.drive_to(ram_peek, 90.0)
		Boss.TELEGRAPH:
			await get_tree().create_timer(0.9, false).timeout
			if not active or boss != Boss.TELEGRAPH:
				return
			boss = Boss.RAM
			stage.emit(&"ram")
			Sfx.play(&"klaxon_2", wagon.global_position, 0.0, 0.03)
			wagon.ram = true
			wagon.drive_to(ram_stop + PatrolWagon.W / 2.0, ram_speed)
		Boss.RAM:
			wagon.ram = false
			wagon.lights(false)
			wagon.set_window(false)
			if player:
				player.set(&"shake_timer", 0.2)
			_step_out()


## Po nájazde vystúpi z kabíny omámený – chvíľa na streľbu
func _step_out() -> void:
	in_wagon = false
	visible = true
	collision_layer = 4
	global_position = Vector2(wagon.front_x() + wagon.facing * 22.0, 0.0)   # vypotáca sa pred kapotu
	_set_facing(wagon.facing)   # k Riccovi (voz stojí predkom vľavo)
	boss = Boss.DAZED
	state = State.STUN
	timer = dazed_time
	stage.emit(&"dazed")


# ---------------------------------------------------------------- zásahy

func take_hit_at(damage: float, dir: Vector2, pos: Vector2) -> void:
	if invulnerable or not active or _ducked or in_wagon:
		Burst.spawn(get_tree().current_scene, pos, -dir + Vector2(0, -0.4), Color(1.0, 0.85, 0.45), 4, 90.0)
		Sfx.play(&"ricochet_1", pos, -6.0, 0.15)
		return
	take_hit(damage, dir)


func take_hit(damage: float, dir: Vector2, blood: bool = true) -> void:
	if state == State.DEAD or invulnerable or not active or boss == Boss.SCRIPTED or _ducked:
		return
	var floor_hp: float = _phase_floor()
	health = maxf(health - damage, floor_hp)
	health_changed.emit(health, max_health)
	if blood and not in_wagon:
		Sfx.play(&"impact_body", global_position + Vector2(0, -40), -2.0)
		Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -44), dir + Vector2(0, -0.3),
				Color(0.62, 0.05, 0.05), 6, 90.0, Vector2(0, 520), 0.5)
	rig.modulate = Color(3, 3, 3)
	create_tween().tween_property(rig, "modulate", Color.WHITE, 0.12)
	if health > floor_hp:
		return
	match phase:
		1:
			_jump_down()
		2:
			_to_wagon()
		3:
			_start_dying()


## Guľka cez okno kabíny počas nájazdu – polovičný damage
func _on_window_hit(damage: float, dir: Vector2) -> void:
	if not in_wagon or not active or invulnerable:
		return
	Sfx.play(&"glass_break", wagon.global_position + wagon.img(PatrolWagon.WINDOW.get_center()), -8.0, 0.1)
	take_hit(damage * 0.5, dir, false)


## Výbuch sudu s benzínom (effects/explosion.gd – skupina boss)
func blast_hit(damage: float, dir: Vector2) -> void:
	if in_wagon or not visible:
		return
	take_hit(damage, dir)


func hat_hit(damage: int, dir: Vector2) -> void:
	if invulnerable or not active or boss == Boss.SCRIPTED or _ducked or in_wagon:
		Sfx.play(&"hat_bonk", global_position + Vector2(0, -60))
		return
	if phase != 2:   # na streche a omámený po nájazde: len zásah (bez omráčenia – má svoj časovač)
		_knock_hat(dir)
		Sfx.play(&"hat_bonk", global_position + Vector2(0, -60))
		take_hit(damage, dir)
		return
	super.hat_hit(damage, dir)


func trip(dir: float) -> bool:
	if invulnerable or not active or phase != 2 or boss in [Boss.SCRIPTED, Boss.TO_WAGON, Boss.JUMP_DOWN]:
		return false
	laser.visible = false
	return super.trip(dir)


func can_takedown(_from_x: float) -> bool:
	return false


func takedown(_dir: Vector2) -> void:
	pass


func hear(_pos: Vector2) -> void:
	pass


func alarm() -> void:
	pass


## Posledná rana: zrúti sa (keď bol vo voze, voz sa vybúra a Murphy z neho vypadne) – ďalej režíruje level
func _start_dying() -> void:
	invulnerable = true
	active = false
	boss = Boss.SCRIPTED
	laser.visible = false
	velocity = Vector2.ZERO
	_ducked = false
	if in_wagon and wagon:
		wagon.wreck()
		in_wagon = false
		visible = true
		global_position = Vector2(wagon.front_x() + wagon.facing * 22.0, 0.0)
	if wagon:
		wagon.ram = false
	rig.scale.y = 1.0
	state = State.DEAD
	collision_layer = 0
	Sfx.play(&"enemy_death", global_position, -2.0)
	_knock_hat(Vector2(-facing, -1))
	# padne na chrbát ako Gangster._die, ale ostane ležať (level ho potrebuje na poslednú repliku)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(rig, "rotation", PI / 2.0 * -facing, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(rig, "position:y", -4.0, 0.5)
	tw.tween_property(arm_front, "rotation", -2.0, 0.4)
	tw.tween_property(arm_back, "rotation", -2.2, 0.4)
	tw.tween_property(leg_front, "rotation", -0.3, 0.4)
	tw.tween_property(head, "rotation", -0.4, 0.4)
	stage.emit(&"dying")
	died.emit()


func _animate(delta: float) -> void:
	if state == State.DEAD:
		return
	super._animate(delta)
	if _ducked and boss == Boss.DUCK and not _tripped:   # pod zábradlím drží Thompson pri tele
		aim_angle = lerp_angle(aim_angle, -PI / 2.0 + 0.3 * facing, minf(1.0, 6.0 * delta))
