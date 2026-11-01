class_name IronMike
extends Gangster
## Iron Mike – boss kapitoly III na vrchole svojej rozostavanej veže (levels/level3/tower.gd). Stavbyvedúci mafie:
## oceľová vesta, červená kravata, tvrdý klobúk, sivé fúzy a Winchester 1897 „trench gun“ (pumpovačka, 5 nábojov).
## Telo je z častí ako každý Gangster (kind „mike“), mozog je vlastný. Zdravie má tri fázy (značky v ui/boss_bar.gd),
## pri prechode je chvíľu nezraniteľný (guľky sa odrazia).
##
## 1. fáza – jazdí na poslednom nosníku stavby (topping out – vlajka a stromček) zavesenom na háku vežového žeriavu
##    (world/tower/tower_crane.gd), žeriavnik ho vozí nad palubou a Mike strieľa zhora. Klobúk do háku = nosník sa
##    zakolíše a Mike chvíľu nestrieľa. → popruh praskne, nosník sa nakloní, Mike zletí na palubu (leží, potom vstane)
## 2. fáza – paluba: mieri (červená čiara) → rana brokov → pumpa (prázdna nábojnica vyletí) → po 5 ranách nabíja
##    po jednom náboji (okno na útok – keď Ricco pribehne, nabíjanie preruší a udrie pažbou), Ricca za krytom vyženie
##    kopnutím do vyhne (rozžeravené nity – world/tower/rivet_forge.gd). Šmyk ho podkopne, klobúk omráči,
##    debna zo žeriavu mu na hlavu = 4 HP (cargo_hit).
## 3. fáza – uteká po rebríku na plošinu stožiara pre vzducholoď „M.“; strieľa zhora, keď Ricco lezie, čaká a doberá
##    si ho; pažbou ho zhodí z plošiny. Smrť: Winchester mu vypadne, chytí sa povrazového rebríka gondoly – réžiu
##    (vzducholoď, závoj v okne, pád) robí level (signál stage(&"dying")).
## Godot docs: classes/class_characterbody2d, classes/class_tween

signal health_changed(health: float, max_health: float)
signal died
## Udalosti pre level (hlášky, réžia): ride, lurch, beam_tilt, landed, reload, bash, forge, to_mast, on_mast, taunt, dying
signal stage(name: StringName)

enum Boss { WAIT, RIDE, FALL, AIM, BLAST, PUMP, RELOAD, WALK, BASH, KICK, TO_MAST, CLIMB, SCRIPTED }

const PHASE_HP := 12.0                  ## zdravia na fázu (max_health = 36 → tri fázy)
const PUMP_TEX := preload("res://weapons/winchester/winchester_pump.png")
const BODY_TEX := preload("res://weapons/winchester/winchester_body.png")
const SHELL_TEX := preload("res://weapons/winchester/shell_red.png")

@export_group("Iron Mike")
@export var shells: int = 5                       ## nábojov v zásobníkovej rúrke
@export var pump_time: float = 0.5                ## s – pumpa po výstrele
@export var shell_time: float = 0.42              ## s – jeden náboj pri nabíjaní
@export var bash_range: float = 34.0
@export var deck_span: Vector2 = Vector2(520, 1210)   ## px (globálne x) – kade chodí v 2. fáze
@export var mast_span: Vector2 = Vector2(566, 714)    ## px – plošina stožiara (3. fáza)
@export var mast_ladder: Vector2 = Vector2(731, -780) ## päta rebríka na stožiar (globálne)
@export var mast_top_y: float = -930.0
@export var forge_path: NodePath

var boss: Boss = Boss.WAIT
var phase: int = 1
var invulnerable: bool = false
var active: bool = false
var ride: Node2D                      ## bod na nosníku (1. fáza) – Mike stojí na ňom
var _shells: int = 5
var _hidden_t: float = 0.0
var _kick_cd: float = 4.0
var _walk_t: float = 0.0
var _reload_empty: bool = false
var _taunt_cd: float = 3.0
var _pump: Sprite2D
var _pump_off: float = 0.0
var _forge: Node2D
var hands_up: bool = false   ## level: drží sa povrazového rebríka (smrť)


func _ready() -> void:
	super._ready()
	health = max_health
	add_to_group(&"boss")
	collision_layer = 0   # kým boj nezačne, guľky ním preletia (je skrytý)
	visible = false
	_shells = shells
	if gun:
		gun.texture = BODY_TEX
		_pump = Sprite2D.new()
		_pump.texture = PUMP_TEX
		_pump.centered = false
		_pump.position = weapon.pump_px
		gun.add_child(_pump)
	_forge = get_node_or_null(forge_path) as Node2D


## Začiatok boja vo fáze p (po smrti Ricca pokračuje v dosiahnutej fáze). at = kde stojí (2. a 3. fáza)
func start(p: int, at: Vector2 = Vector2.INF) -> void:
	phase = p
	health = max_health - (p - 1) * PHASE_HP
	health_changed.emit(health, max_health)
	visible = true
	active = true
	collision_layer = 4
	if at != Vector2.INF:
		global_position = at
	if p == 1:
		boss = Boss.RIDE
		_next_action()
	else:
		ride = null
		_next_action()


func _phase_floor() -> float:
	return maxf(max_health - phase * PHASE_HP, 0.0)


func _mobile() -> bool:
	return phase >= 2 and ride == null


func _span() -> Vector2:
	return mast_span if phase == 3 else deck_span


# ---------------------------------------------------------------- hlavná slučka

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	_flash_t -= delta
	flash.visible = _flash_t > 0.0
	_kick_cd -= delta
	_taunt_cd -= delta
	if boss == Boss.SCRIPTED or not visible:
		laser.visible = false
		_animate(delta)
		return
	if ride:   # 1. fáza – stojí na nosníku na háku žeriavu
		global_position = ride.global_position
		rig.rotation = ride.global_rotation if not _tripped else rig.rotation
		velocity = Vector2.ZERO
	elif not is_on_floor():
		velocity += get_gravity() * delta
	timer -= delta
	if player == null or not active:
		_end_frame(delta)
		return
	var los: bool = _has_los()
	_hidden_t = 0.0 if los else _hidden_t + delta

	if state == State.STUN:   # klobúk / podkopnutie (Gangster.hat_hit, trip) – po ňom pokračuje v boji
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
		Boss.FALL:
			if is_on_floor():
				_landed()
		Boss.AIM:
			_face_player()
			_slow_down(delta)
			_track_aim(delta)
			_update_laser(true)
			if _hold_fire():
				_next_action()
			elif timer <= 0.0:
				if los:
					_blast()
				else:
					_next_action()
		Boss.BLAST:
			_slow_down(delta)
			if timer <= 0.0:
				boss = Boss.PUMP
				timer = pump_time
				_pump_action()
		Boss.PUMP:
			_slow_down(delta)
			_track_aim(delta)
			if timer <= 0.0:
				_next_action()
		Boss.RELOAD:
			_slow_down(delta)
			_aim_low(delta)
			if _mobile() and _player_close(bash_range + 14.0):
				stage.emit(&"bash")
				_start_bash()
			elif timer <= 0.0:
				_shell_in()
		Boss.WALK:
			_walk_t -= delta
			var dx: float = player.global_position.x - global_position.x
			var want: float = signf(dx)
			var sp := _span()
			var ok: bool = _ledge_ok(want) and (global_position.x + want * 10.0) > sp.x and (global_position.x + want * 10.0) < sp.y
			_set_facing(want if want != 0.0 else facing)
			velocity.x = want * walk_speed if ok else 0.0
			_aim_low(delta)
			if _walk_t <= 0.0 or not ok or (los and absf(dx) < preferred_range):
				velocity.x = 0.0
				_start_aim()
		Boss.BASH:
			_slow_down(delta)
			if timer <= 0.0:
				_bash_hit()
				boss = Boss.PUMP   # krátke zotavenie
				timer = 0.5
		Boss.KICK:
			var fx: float = _forge.global_position.x - facing * 16.0 if _forge else global_position.x
			if absf(fx - global_position.x) > 4.0 and timer > 0.0:
				_set_facing(signf(fx - global_position.x))
				velocity.x = facing * walk_speed * 1.5 if _ledge_ok(facing) else 0.0
				_aim_low(delta)
			else:
				velocity.x = 0.0
				_kick()
		Boss.TO_MAST:
			var lx: float = mast_ladder.x - global_position.x
			if absf(lx) < 4.0:
				velocity.x = 0.0
				_climb_mast()
			else:
				_set_facing(signf(lx))
				velocity.x = signf(lx) * walk_speed * 2.2
			_aim_low(delta)
		Boss.CLIMB:
			velocity = Vector2.ZERO
	_end_frame(delta)


func _end_frame(delta: float) -> void:
	if boss != Boss.AIM:
		laser.visible = false
	if ride == null and boss != Boss.CLIMB:
		move_and_slide()
	_animate(delta)


func _slow_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)


## Zbraň šikmo dolu pred sebou (chôdza, nabíjanie)
func _aim_low(delta: float) -> void:
	var low: float = 0.8 if facing > 0.0 else PI - 0.8
	aim_angle = lerp_angle(aim_angle, low, minf(1.0, 8.0 * delta))


func _has_los() -> bool:
	if player == null or int(player.get(&"state")) == 3:
		return false
	var eye := global_position + Vector2(EYE.x * facing, EYE.y)
	var q := PhysicsRayQueryParameters2D.create(eye, _player_target(), 1 | COVER_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _player_close(r: float) -> bool:
	var dx: float = player.global_position.x - global_position.x
	return absf(dx) < r and absf(player.global_position.y - global_position.y) < 30.0


## Ricco lezie po rebríku pod ním – nestrieľa (dá mu vyliezť), čaká hore pri rebríku
func _hold_fire() -> bool:
	return phase == 3 and int(player.get(&"state")) == 7 and player.global_position.y > global_position.y + 8.0


# ---------------------------------------------------------------- rozhodovanie

func _next_action() -> void:
	if not active:
		return
	if phase == 3 and int(player.get(&"state")) == 7:   # Ricco lezie – nabije a čaká, občas sa vysmeje
		if _shells < shells:
			_start_reload()
			return
		if _taunt_cd <= 0.0:
			_taunt_cd = 6.0
			stage.emit(&"taunt")
		boss = Boss.WALK if absf(mast_span.y - 10.0 - global_position.x) > 8.0 else Boss.PUMP
		_walk_t = 1.0
		timer = 0.4
		return
	if _mobile() and _player_close(bash_range + 6.0):
		_start_bash()
		return
	if _shells <= 0:
		_start_reload()
		return
	if _mobile() and phase == 2 and _hidden_t > 2.2 and _kick_cd <= 0.0 and _forge and _forge.has_method(&"kick") \
			and absf(_forge.global_position.y - global_position.y) < 20.0:
		boss = Boss.KICK
		timer = 3.0
		return
	if _hidden_t > 1.5 and _shells < shells:
		_start_reload()   # Ricco je za krytom – využije čas a dobije
		return
	if _mobile() and (_hidden_t > 0.6 or absf(player.global_position.x - global_position.x) > preferred_range):
		boss = Boss.WALK
		_walk_t = 2.2
		return
	_start_aim()


func _start_aim() -> void:
	boss = Boss.AIM
	state = State.AIM
	timer = aim_time if phase == 1 else aim_time * (0.85 if phase == 2 else 0.7)


func _blast() -> void:
	boss = Boss.BLAST
	state = State.SHOOT
	timer = 0.08
	_fire()
	_shells -= 1
	Gangster.noise(global_position, 300.0)
	if player.global_position.distance_to(global_position) < 200.0:
		player.set(&"shake_timer", 0.12)


## Pumpa: predpažbie dozadu (prázdna nábojnica vyletí) a dopredu
func _pump_action() -> void:
	if _pump == null:
		return
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func():
		Sfx.play(&"pump_back", global_position, -4.0, 0.05)
		_eject_shell())
	tw.tween_method(_set_pump, 0.0, -weapon.pump_travel, 0.1)
	tw.tween_interval(0.06)
	tw.tween_callback(func(): Sfx.play(&"pump_fwd", global_position, -4.0, 0.05))
	tw.tween_method(_set_pump, -weapon.pump_travel, 0.0, 0.1)


func _set_pump(v: float) -> void:
	_pump_off = v
	if _pump:
		_pump.position = weapon.pump_px + Vector2(v, 0)


func _eject_shell() -> void:
	var d := DROP.instantiate()
	d.texture = SHELL_TEX
	d.life = 1.5
	get_tree().current_scene.add_child(d)
	d.global_position = gun.to_global(Vector2(18, 3))
	d.velocity = Vector2(-facing * randf_range(40.0, 70.0), -120.0)
	d.spin = randf_range(-14.0, 14.0)


func _start_reload() -> void:
	boss = Boss.RELOAD
	state = State.COOLDOWN
	_reload_empty = _shells <= 0
	timer = shell_time + 0.2
	stage.emit(&"reload")


func _shell_in() -> void:
	_shells += 1
	Sfx.play(&"shell_insert", global_position + Vector2(0, -40), -4.0, 0.08)
	if _shells >= shells:
		if _reload_empty:
			_pump_action()
		boss = Boss.PUMP
		timer = 0.45
		return
	# Ricco je na rane a vidno ho – stačí mu aj neplná rúrka
	if _shells >= 2 and _hidden_t <= 0.0 and randf() < 0.35:
		_start_aim()
		return
	timer = shell_time


func _start_bash() -> void:
	boss = Boss.BASH
	state = State.WINDUP
	timer = 0.32
	_face_player()
	Sfx.play(&"punch_swing", global_position, -4.0)


## Úder pažbou – zhodí Ricca dozadu (na plošine stožiara aj dolu)
func _bash_hit() -> void:
	var tw := create_tween()   # švih zbraňou
	tw.tween_property(arm_front, "position:x", SHOULDER_FRONT.x + 5.0, 0.06)
	tw.tween_property(arm_front, "position:x", SHOULDER_FRONT.x, 0.15)
	if not _player_close(bash_range + 8.0) or signf(player.global_position.x - global_position.x) != facing:
		return
	Sfx.play(&"gun_bash", player.global_position, 0.0)
	if player.has_method(&"take_damage"):
		player.take_damage(1, global_position + Vector2(0, -30))
	player.velocity = Vector2(facing * (340.0 if phase == 3 else 260.0), -200.0)
	Burst.spawn(get_tree().current_scene, player.global_position + Vector2(0, -22), Vector2(facing, -0.3), Color(1, 0.9, 0.5), 6, 80.0)


func _kick() -> void:
	_kick_cd = 9.0
	_hidden_t = 0.0
	Sfx.play(&"gun_bash", global_position, -2.0)
	if _forge and _forge.has_method(&"kick"):
		_forge.call(&"kick", player.global_position + Vector2(0, -20))
	stage.emit(&"forge")
	boss = Boss.PUMP
	timer = 0.7
	leg_front.rotation = -0.9   # kopanec (animácia nohu vráti)


# ---------------------------------------------------------------- 1. fáza: nosník na háku

## Nosník sa zakolísal (klobúk do háku) – chvíľu sa drží a nestrieľa
func lurch() -> void:
	if ride == null or not active:
		return
	stage.emit(&"lurch")
	state = State.STUN
	timer = 1.2
	laser.visible = false


## Popruh praskol – Mike zletí z nosníka na palubu
func fall_off(dir: float) -> void:
	ride = null
	boss = Boss.FALL
	state = State.IDLE
	rig.rotation = 0.0
	velocity = Vector2(dir * 60.0, -90.0)
	laser.visible = false


func _landed() -> void:
	Sfx.play(&"body_thud", global_position, 2.0, 0.05)
	Sfx.play(&"metal_crash", global_position, -10.0, 0.1)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -2), Vector2.UP, Color(0.75, 0.7, 0.66, 0.6), 12, 70.0, Vector2(0, 60), 0.6)
	if player:
		player.set(&"shake_timer", 0.25)
	phase = 2
	invulnerable = false
	stage.emit(&"landed")
	boss = Boss.AIM
	super.trip(facing)   # leží na chrbte – chvíľa na útok, potom vstane (Gangster._stand_up)
	timer = 1.6


# ---------------------------------------------------------------- 3. fáza: stožiar

func _to_mast() -> void:
	invulnerable = true
	boss = Boss.TO_MAST
	state = State.IDLE
	laser.visible = false
	stage.emit(&"to_mast")


func _climb_mast() -> void:
	boss = Boss.CLIMB
	_set_facing(-1.0)
	var top := Vector2(mast_span.y - 12.0, mast_top_y)
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", mast_top_y - 6.0, 1.8)
	tw.parallel().tween_method(_climb_pose, 0.0, 1.8, 1.8)
	tw.parallel().tween_callback(func(): Sfx.play(&"ladder_rung", global_position, -6.0)).set_delay(0.4)
	tw.parallel().tween_callback(func(): Sfx.play(&"ladder_rung", global_position, -6.0)).set_delay(1.1)
	tw.tween_property(self, "global_position", top, 0.25)
	tw.tween_callback(func():
		phase = 3
		invulnerable = false
		_shells = shells
		stage.emit(&"on_mast")
		_start_aim())


## Lezie po rebríku – ruky a nohy sa striedajú (t = čas lezenia)
func _climb_pose(t: float) -> void:
	arm_back.rotation = -1.6 + sin(t * 18.0) * 0.4
	arm_front.rotation = -1.4 - sin(t * 18.0) * 0.4
	leg_front.rotation = sin(t * 18.0) * 0.5
	leg_back.rotation = -sin(t * 18.0) * 0.5


# ---------------------------------------------------------------- zásahy

func take_hit_at(damage: float, dir: Vector2, pos: Vector2) -> void:
	if invulnerable or not active:
		Burst.spawn(get_tree().current_scene, pos, -dir + Vector2(0, -0.4), Color(1.0, 0.85, 0.45), 4, 90.0)
		Sfx.play(&"ricochet_1", pos, -6.0, 0.15)
		return
	take_hit(damage, dir)


func take_hit(damage: float, dir: Vector2, blood: bool = true) -> void:
	if state == State.DEAD or invulnerable or not active or boss == Boss.SCRIPTED:
		return
	var floor_hp: float = _phase_floor()
	health = maxf(health - damage, floor_hp)
	health_changed.emit(health, max_health)
	if blood:
		Sfx.play(&"impact_body", global_position + Vector2(0, -40), -2.0)
		Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -44), dir + Vector2(0, -0.3),
				Color(0.62, 0.05, 0.05), 6, 90.0, Vector2(0, 520), 0.5)
	rig.modulate = Color(3, 3, 3)
	create_tween().tween_property(rig, "modulate", Color.WHITE, 0.12)
	if health > floor_hp:
		return
	match phase:
		1:
			invulnerable = true
			state = State.IDLE
			boss = Boss.FALL if ride == null else Boss.RIDE
			laser.visible = false
			stage.emit(&"beam_tilt")   # level: žeriav – popruh praskne, nosník sa nakloní (fall_off)
		2:
			_to_mast()
		3:
			_start_dying()


## Debna zo žeriavu mu dopadla na hlavu (world/tower/falling_load.gd)
func cargo_hit(damage: float) -> void:
	if invulnerable or not active or ride:
		return
	Sfx.play(&"hat_bonk", global_position + Vector2(0, -66), 2.0)
	_knock_hat(Vector2.UP)
	take_hit(damage, Vector2.DOWN, false)
	if active and not invulnerable and boss != Boss.SCRIPTED and state != State.DEAD:
		state = State.STUN
		timer = 1.6


func hat_hit(damage: int, dir: Vector2) -> void:
	if invulnerable or not active or boss == Boss.SCRIPTED:
		Sfx.play(&"hat_bonk", global_position + Vector2(0, -60))
		return
	super.hat_hit(damage, dir)


func trip(dir: float) -> bool:
	if invulnerable or not active or ride or phase < 2 or boss in [Boss.SCRIPTED, Boss.CLIMB, Boss.TO_MAST, Boss.FALL]:
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


## Posledná rana: zbraň mu vypadne, potácavo cúva k povrazovému rebríku gondoly – ďalej režíruje level
func _start_dying() -> void:
	invulnerable = true
	active = false
	boss = Boss.SCRIPTED
	state = State.IDLE
	laser.visible = false
	velocity = Vector2.ZERO
	_drop_gun()
	Sfx.play(&"enemy_death", global_position, -2.0)
	stage.emit(&"dying")
	died.emit()


func _drop_gun() -> void:
	if gun == null or not gun.visible:
		return
	var d := WEAPON_PICKUP.new()
	d.weapon = weapon
	d.ammo = weapon.mag_size
	d.texture = weapon.texture
	d.velocity = Vector2(facing * 50.0, -140.0)
	d.spin = randf_range(-8.0, 8.0)
	get_tree().current_scene.add_child.call_deferred(d)
	d.position = gun.global_position + Vector2(24.0 * facing, 4)
	gun.visible = false
	for c in arm_front.get_children():
		if c is Sprite2D and (c as Sprite2D).region_enabled:
			c.visible = false


# ---------------------------------------------------------------- pohyb častí tela

func _animate(delta: float) -> void:
	if boss == Boss.CLIMB:
		return   # nohy a ruky hýbe tween (_climb_mast)
	if boss == Boss.SCRIPTED and not gun.visible:
		# bez zbrane: ruky hore (drží sa rebríka) alebo voľne – pózy nastavuje level cez hands_up
		super._animate(delta)
		arm_front.rotation = lerp_angle(arm_front.rotation, -1.7 if hands_up else 1.3, minf(1.0, 10.0 * delta))
		arm_back.rotation = lerp_angle(arm_back.rotation, -1.5 if hands_up else 1.5, minf(1.0, 10.0 * delta))
		return
	super._animate(delta)
	# zadná ruka ide s predpažbím (pumpa)
	if gun and weapon.two_handed and _pump_off != 0.0 and not _tripped and not _getting_up:
		var fg: Vector2 = gun.to_global(weapon.foregrip_px + Vector2(1.0 + _pump_off, 2.0))
		arm_back.rotation = _arm_rot((fg - arm_back.global_position).angle())
	if boss == Boss.BASH and not _tripped:   # náprah pažbou – zbraň zdvihnutá
		arm_front.rotation = lerp_angle(arm_front.rotation, -1.2, minf(1.0, 14.0 * delta))

