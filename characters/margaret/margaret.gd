class_name Margaret
extends Gangster
## Margaret Vito – vdova po Donovi, boss kapitoly IV v zrkadlovej sieni pod sklenou kupolou vily (levels/level4/mirror_hall.gd).
## Smútočné šaty po zem, klobúk cloche so závojom, Mauser C96 (10 nábojov, nabíja nabíjacím pásikom). Telo je z častí ako
## každý Gangster (kind „widow“ – sukňa je súčasť torza), mozog je vlastný. Zdravie má tri fázy (značky v ui/boss_bar.gd),
## pri prechode je chvíľu nezraniteľná.
##
## 1. fáza – zrkadlá: Margaret „vystúpi“ zo zrkadla a s ňou jej odrazy v ďalších zrkadlách (decoy – rovnaký skript,
##    rovnaký modrastý nádych skla). Všetky mieria (červená čiara) a strieľajú naraz, no zraní len skutočná – guľky odrazov
##    preletia Riccom. Blesk cez kupolu (signál stage(&"lightning") – záblesk robí level) odrazy na chvíľu zhasne, skutočná
##    ostane. Zásah do skutočnej: zrkadlo za ňou praskne (mirror_broken), stiahne sa do skla a objaví sa inde.
##    Zásah do odrazu: rozletí sa na črepy a Margaret sa vysmeje.
## 2. fáza – oheň: vystúpi zo zrkadla naozaj a kopne do svietnika (stage(&"candle") – level zapáli závesy, oheň sa šíri).
##    Mieri → dávka 3 rán → po 10 ranách nabíja pásikom (okno na útok). Drží si odstup; keď je Ricco pri nej, udrie ho
##    rúčkou pištole a odhodí. Šmyk ju podkopne, klobúk omráči, luster na ňu = veľký zásah.
## 3. fáza – strecha: utečie sklenými dverami (stage(&"to_roof")) k stožiaru vzducholode IRON, vylezie na plošinu
##    a strieľa zhora; kým Ricco lezie, nestrieľa. Blesk do stožiara ju omráči (lightning_stun). Smrť: C96 jej vypadne,
##    réžiu (pád zo strechy) robí level (stage(&"dying")).
## Godot docs: classes/class_characterbody2d, classes/class_tween, classes/class_gdscript (new – odrazy)

signal health_changed(health: float, max_health: float)
signal died
## Udalosti pre level: mirrors, lightning, decoy, mirror_hit, emerge, candle, reload, whip, to_roof, on_mast, taunt, dying
signal stage(name: StringName)
signal mirror_broken(index: int)

enum Boss { WAIT, HIDDEN, MIRROR_AIM, MIRROR_FIRE, EMERGE, AIM, FIRE, RELOAD, WALK, WHIP, TO_MAST, CLIMB, SCRIPTED }

const PHASE_HP := 12.0                     ## zdravia na fázu (max_health = 36 → tri fázy)
const MIRROR_TINT := Color(0.72, 0.84, 1.0)   ## odraz aj ona v zrkadle – rovnaký nádych skla
const MIRROR_HIT_CAP := 3.0                ## v zrkadle vezme jeden zásah najviac toľko (aspoň 4 trafené zrkadlá)
const HIT_CAP := 6.0                       ## inak najviac toľko (luster = pol fázy)
const RUN_TO_MAST := 3.6                   ## × walk_speed – beh na strechu k stožiaru (Ricco je vtedy omráčený – mirror_hall.gd)
const CLIMB_SPEED := 140.0                 ## px/s – lezenie na plošinu stožiara

@export_group("Margaret")
@export var clip: int = 10                       ## nábojov v C96
@export var burst: int = 3                       ## rán v dávke
@export var shot_gap: float = 0.14               ## s medzi ranami dávky
@export var clip_time: float = 1.6               ## s – nabíjanie pásikom
@export var whip_range: float = 30.0
@export var mirror_spots: NodePath                ## uzol s Marker2D pred každým zrkadlom (nohy na podlahe siene)
@export var hall_span: Vector2 = Vector2(80, 1520)   ## px (globálne x) – kade chodí v 2. fáze
@export var mast_span: Vector2 = Vector2(2240, 2340) ## px – plošina stožiara (3. fáza)
@export var mast_ladder: Vector2 = Vector2(2232, 0)  ## päta rebríka na stožiar (globálne)
@export var mast_top_y: float = -160.0

var decoy: bool = false                 ## odraz v zrkadle (vyrobí ho skutočná Margaret)
var real: Margaret                      ## odraz: skutočná Margaret
var boss: Boss = Boss.WAIT
var phase: int = 1
var invulnerable: bool = false
var active: bool = false
var hands_up: bool = false              ## level: padá / drží sa zábradlia (smrť)
var _ammo: int = 10
var _burst_left: int = 0
var _volleys: int = 0
var _lightning_at: float = -1.0
var _mirror: int = -1                   ## pred ktorým zrkadlom práve stojí
var _broken: Array[int] = []
var _decoys: Array[Margaret] = []
var _walk_t: float = 0.0
var _taunt_cd: float = 3.0
var _reveal_t: float = 0.0


func _ready() -> void:
	super._ready()
	health = max_health
	if decoy:   # odraz: je v skupine enemies ako každý mafián (luster, klobúk), guľky ho zasiahnu
		rig.modulate = MIRROR_TINT
		return
	add_to_group(&"boss")
	collision_layer = 0   # kým boj nezačne, guľky ňou preletia (je v zrkadle)
	visible = false
	_ammo = clip


## Začiatok boja vo fáze p (po smrti Ricca pokračuje v dosiahnutej fáze). at = kde stojí (2. a 3. fáza)
func start(p: int, at: Vector2 = Vector2.INF) -> void:
	phase = p
	health = max_health - (p - 1) * PHASE_HP
	health_changed.emit(health, max_health)
	active = true
	_ammo = clip
	if at != Vector2.INF:
		global_position = at
	if p == 1:
		visible = false
		collision_layer = 0
		boss = Boss.HIDDEN
		timer = 1.2
		stage.emit(&"mirrors")
	else:
		visible = true
		collision_layer = 4
		rig.modulate = Color.WHITE
		_start_aim()


func _phase_floor() -> float:
	return maxf(max_health - phase * PHASE_HP, 0.0)


func _span() -> Vector2:
	return mast_span if phase == 3 else hall_span


# ---------------------------------------------------------------- hlavná slučka

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	_flash_t -= delta
	flash.visible = _flash_t > 0.0
	if decoy:
		_decoy_process(delta)
		return
	_taunt_cd -= delta
	_reveal_t -= delta
	if boss == Boss.SCRIPTED or not active:
		laser.visible = false
		if not is_on_floor() and boss != Boss.CLIMB:
			velocity += get_gravity() * delta
		_end_frame(delta)
		return
	if not is_on_floor() and boss != Boss.CLIMB:
		velocity += get_gravity() * delta
	timer -= delta
	if player == null:
		_end_frame(delta)
		return

	if state == State.STUN:   # klobúk / podkopnutie / blesk – po ňom pokračuje v boji
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		laser.visible = false
		if timer <= 0.0 and _tripped:
			_stand_up()
			timer = GETUP_TIME + 0.1
		elif timer <= 0.0 and not _getting_up:
			state = State.AIM
			_start_aim()
		_end_frame(delta)
		return

	match boss:
		Boss.HIDDEN:
			velocity.x = 0.0
			if timer <= 0.0:
				_emerge_in_mirrors()
		Boss.MIRROR_AIM:
			velocity.x = 0.0
			_face_player()
			_track_aim(delta)
			_update_laser(true)
			if _lightning_at >= 0.0 and timer <= _lightning_at:
				_lightning_at = -1.0
				stage.emit(&"lightning")
				reveal()
			if timer <= 0.0:
				boss = Boss.MIRROR_FIRE
				_burst_left = 2
				timer = 0.0
		Boss.MIRROR_FIRE:
			velocity.x = 0.0
			_track_aim(delta)
			if timer <= 0.0:
				if _burst_left > 0:
					_burst_left -= 1
					_shoot()
					for d in _decoys:
						if is_instance_valid(d):
							d.fake_fire()
					timer = 0.26
				else:
					_volleys += 1
					if _volleys >= 2:
						_into_mirrors(0.7)
					else:
						_mirror_aim()
		Boss.EMERGE:
			velocity.x = 0.0
			if timer <= 0.0:
				invulnerable = false
				_start_aim()
		Boss.AIM:
			_face_player()
			_slow_down(delta)
			_track_aim(delta)
			_update_laser(true)
			if _player_close(whip_range + 6.0) and phase >= 2:
				_start_whip()
			elif _hold_fire():
				_next_action()
			elif timer <= 0.0:
				if _has_los():
					boss = Boss.FIRE
					_burst_left = mini(burst, _ammo)
					timer = 0.0
				else:
					_next_action()
		Boss.FIRE:
			_slow_down(delta)
			_track_aim(delta)
			if timer <= 0.0:
				if _burst_left > 0 and _ammo > 0:
					_burst_left -= 1
					_shoot()
					timer = shot_gap
				else:
					boss = Boss.WALK if phase == 2 else Boss.AIM
					_walk_t = randf_range(0.5, 1.1)
					timer = 0.35
					if _ammo <= 0:
						_start_reload()
					elif boss == Boss.AIM:
						_start_aim()
		Boss.RELOAD:
			_slow_down(delta)
			_aim_low(delta)
			if _player_close(whip_range + 10.0):
				_start_whip()
			elif timer <= 0.0:
				_ammo = clip
				Sfx.play(&"slide_rack", global_position + Vector2(0, -40), -6.0, 0.05)
				_next_action()
		Boss.WALK:
			_walk_t -= delta
			var dx: float = player.global_position.x - global_position.x
			var want: float = 0.0
			if absf(dx) > preferred_range + 40.0:
				want = signf(dx)
			elif absf(dx) < preferred_range - 60.0:
				want = -signf(dx)   # drží si odstup – cúva
			var sp := _span()
			var nx: float = global_position.x + want * 12.0
			var ok: bool = want != 0.0 and _ledge_ok(want) and nx > sp.x and nx < sp.y
			_face_player()
			velocity.x = want * walk_speed if ok else 0.0
			_aim_low(delta)
			if _player_close(whip_range + 6.0):
				_start_whip()
			elif _walk_t <= 0.0 or not ok:
				velocity.x = 0.0
				_start_aim()
		Boss.WHIP:
			_slow_down(delta)
			if timer <= 0.0:
				_whip_hit()
				boss = Boss.WALK
				_walk_t = 0.6
		Boss.TO_MAST:
			var lx: float = mast_ladder.x - global_position.x
			if absf(lx) < 4.0:
				velocity.x = 0.0
				_climb_mast()
			else:
				_set_facing(signf(lx))
				velocity.x = signf(lx) * walk_speed * RUN_TO_MAST
			_aim_low(delta)
		Boss.CLIMB:
			velocity = Vector2.ZERO
	_end_frame(delta)


func _end_frame(delta: float) -> void:
	if boss != Boss.AIM and boss != Boss.MIRROR_AIM:
		laser.visible = false
	if boss != Boss.CLIMB:
		move_and_slide()
	_animate(delta)


func _slow_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)


## Pištoľ šikmo dolu pred sebou (chôdza, nabíjanie)
func _aim_low(delta: float) -> void:
	var low: float = 0.7 if facing > 0.0 else PI - 0.7
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


## Ricco lezie po rebríku na stožiar – nestrieľa (dá mu vyliezť), čaká hore
func _hold_fire() -> bool:
	return phase == 3 and int(player.get(&"state")) == 7 and player.global_position.y > global_position.y + 8.0


func _shoot() -> void:
	_fire()
	_ammo -= 1
	Gangster.noise(global_position, 300.0)


# ---------------------------------------------------------------- 1. fáza: zrkadlá

func _spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var root := get_node_or_null(mirror_spots)
	if root:
		for c in root.get_children():
			out.append((c as Node2D).global_position)
	return out


## Vystúpi v jednom zrkadle a jej odrazy v ďalších (čím menej zdravia, tým viac odrazov)
func _emerge_in_mirrors() -> void:
	var spots := _spots()
	var free: Array[int] = []
	for i in spots.size():
		if not _broken.has(i):
			free.append(i)
	if free.is_empty():
		_emerge_for_real()
		return
	free.shuffle()
	# radšej nie hneď pri Riccovi – najprv zrkadlá ďalej ako 70 px
	var px: float = player.global_position.x
	var far: Array = free.filter(func(i: int) -> bool: return absf(spots[i].x - px) > 70.0)
	var near: Array = free.filter(func(i: int) -> bool: return absf(spots[i].x - px) <= 70.0)
	free.assign(far + near)
	_mirror = free[0]
	global_position = spots[_mirror]
	velocity = Vector2.ZERO
	var lost: float = max_health - health
	var n_decoys: int = mini(2 if lost < 6.0 else 3, free.size() - 1)
	for k in n_decoys:
		var d := _make_decoy()
		get_parent().add_child(d)
		d.global_position = spots[free[k + 1]]
		_decoys.append(d)
	_face_player()
	visible = true
	collision_layer = 4
	rig.modulate = Color(MIRROR_TINT, 0.0)
	create_tween().tween_property(rig, "modulate:a", 1.0, 0.4)
	Sfx.play(&"slowmo_out", global_position + Vector2(0, -40), -14.0, 0.1)
	_volleys = 0
	_mirror_aim()


func _mirror_aim() -> void:
	boss = Boss.MIRROR_AIM
	state = State.AIM
	timer = aim_time * 1.5
	_lightning_at = timer * randf_range(0.25, 0.65) if _volleys == 0 or randf() < 0.5 else -1.0


## Odraz – rovnaká postava (rovnaký skript), len klam: mieri a strieľa naraz so skutočnou, guľky nezrania
func _make_decoy() -> Margaret:
	var d := (get_script() as GDScript).new() as Margaret
	d.decoy = true
	d.real = self
	d.kind = kind
	d.weapon = weapon
	d.max_health = 1
	d.aim_time = aim_time
	d.aim_turn_speed = aim_turn_speed
	d.sight_range = sight_range
	d.bullet_speed = bullet_speed
	d.bullet_lifetime = bullet_lifetime
	d.spread_deg = spread_deg
	d.respawn_time = 0.0
	return d


## Stiahne sa do zrkadla (aj s odrazmi) a o chvíľu sa objaví inde
func _into_mirrors(wait: float) -> void:
	boss = Boss.HIDDEN
	state = State.IDLE
	timer = wait
	laser.visible = false
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(rig, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		if boss == Boss.HIDDEN:
			visible = false)
	for d in _decoys:
		if is_instance_valid(d):
			d.vanish()
	_decoys.clear()


## Blesk – odrazy na chvíľu zhasnú, skutočná ostane (level volá aj pri blesku, ktorý nevyvolala ona)
func reveal(t: float = 0.45) -> void:
	if boss != Boss.MIRROR_AIM and boss != Boss.MIRROR_FIRE:
		return
	_reveal_t = t
	for d in _decoys:
		if is_instance_valid(d):
			d.flicker(t)


## Zásah do skutočnej v zrkadle – zrkadlo za ňou praskne
func _mirror_hit() -> void:
	if _mirror >= 0 and not _broken.has(_mirror):
		_broken.append(_mirror)
		mirror_broken.emit(_mirror)
	Sfx.play(&"glass_break", global_position + Vector2(0, -50), 0.0, 0.1)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -50), Vector2.UP, Color(0.8, 0.92, 1.0), 16, 120.0, Vector2(0, 420), 0.6)
	stage.emit(&"mirror_hit")
	if health <= _phase_floor():
		_emerge_for_real()
	else:
		_into_mirrors(0.9)


## Koniec 1. fázy: vystúpi zo zrkadla naozaj (sklo sa rozletí), odrazy sa rozbijú, kopne do svietnika
func _emerge_for_real() -> void:
	phase = 2
	_ammo = clip
	invulnerable = true
	visible = true
	collision_layer = 4
	laser.visible = false
	for d in _decoys:
		if is_instance_valid(d):
			d.shatter(false)
	_decoys.clear()
	var tw := create_tween()
	tw.tween_property(rig, "modulate", Color.WHITE, 0.5)
	Sfx.play(&"glass_break", global_position + Vector2(0, -40), 2.0)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -40), Vector2(facing, -0.4), Color(0.85, 0.95, 1.0), 24, 160.0, Vector2(0, 420), 0.7)
	velocity = Vector2(facing * 90.0, -60.0)
	boss = Boss.EMERGE
	state = State.IDLE
	timer = 1.4
	stage.emit(&"emerge")
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(self) and active:
		leg_front.rotation = -0.9   # kopanec do svietnika (animácia nohu vráti)
		Sfx.play(&"gun_bash", global_position, -4.0)
		stage.emit(&"candle")


# ---------------------------------------------------------------- odraz (decoy)

func _decoy_process(delta: float) -> void:
	if real == null or not is_instance_valid(real) or state == State.DEAD:
		queue_free()
		return
	if player == null:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = 0.0
	timer -= delta
	if real.boss == Boss.MIRROR_AIM or real.boss == Boss.MIRROR_FIRE:
		_face_player()
		_track_aim(delta)
		_update_laser(real.boss == Boss.MIRROR_AIM and _reveal_t <= 0.0)
	else:
		laser.visible = false
	_reveal_t -= delta
	move_and_slide()
	_animate(delta)


func fake_fire() -> void:
	if state == State.DEAD:
		return
	var b := BULLET.instantiate()
	b.direction = Vector2.from_angle(aim_angle + deg_to_rad(randf_range(-spread_deg, spread_deg)))
	b.shooter = self
	b.speed = bullet_speed
	b.lifetime = bullet_lifetime
	b.damage = 0.0
	b.hit_mask = 1        # len svet – guľka odrazu preletí Riccom
	b.modulate = Color(0.7, 0.85, 1.0, 0.6)
	b.global_position = muzzle.global_position
	get_tree().current_scene.add_child(b)
	_flash_t = 0.06
	flash.frame = randi() % 2
	arm_front.position.x = SHOULDER_FRONT.x - 2.0
	create_tween().tween_property(arm_front, "position:x", SHOULDER_FRONT.x, 0.08)


## Blesk – odraz na chvíľu takmer zmizne
func flicker(t: float) -> void:
	_reveal_t = t
	var tw := create_tween()
	tw.tween_property(rig, "modulate:a", 0.08, 0.05)
	tw.tween_interval(t)
	tw.tween_property(rig, "modulate:a", 1.0, 0.15)


func vanish() -> void:
	state = State.DEAD
	collision_layer = 0
	laser.visible = false
	var tw := create_tween()
	tw.tween_property(rig, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


## Odraz trafený – rozletí sa na črepy
func shatter(laugh: bool = true) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	collision_layer = 0
	laser.visible = false
	visible = false
	Sfx.play(&"glass_break", global_position + Vector2(0, -40), -2.0, 0.12)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -40), Vector2.UP, Color(0.75, 0.88, 1.0), 18, 130.0, Vector2(0, 420), 0.6)
	if laugh and real and is_instance_valid(real):
		real._decoy_broken(self)
	queue_free()


func _decoy_broken(d: Margaret) -> void:
	_decoys.erase(d)
	stage.emit(&"decoy")


# ---------------------------------------------------------------- 2. fáza: sieň

func _next_action() -> void:
	if not active:
		return
	if phase == 3 and int(player.get(&"state")) == 7:   # Ricco lezie – nabije a čaká, občas sa vysmeje
		if _ammo < clip:
			_start_reload()
			return
		if _taunt_cd <= 0.0:
			_taunt_cd = 6.0
			stage.emit(&"taunt")
		boss = Boss.AIM
		state = State.AIM
		timer = 0.6
		return
	if _player_close(whip_range + 6.0):
		_start_whip()
		return
	if _ammo <= 0:
		_start_reload()
		return
	if phase == 2 and randf() < 0.45:
		boss = Boss.WALK
		_walk_t = randf_range(0.8, 1.6)
		return
	_start_aim()


func _start_aim() -> void:
	boss = Boss.AIM
	state = State.AIM
	timer = aim_time * (0.9 if phase == 2 else 0.75)


func _start_reload() -> void:
	boss = Boss.RELOAD
	state = State.COOLDOWN
	timer = clip_time
	Sfx.play(&"mag_out", global_position + Vector2(0, -40), -6.0)
	stage.emit(&"reload")


func _start_whip() -> void:
	boss = Boss.WHIP
	state = State.WINDUP
	timer = 0.3
	_face_player()
	Sfx.play(&"punch_swing", global_position, -4.0)
	stage.emit(&"whip")


## Úder rúčkou C96 – odhodí Ricca (na plošine stožiara aj dolu)
func _whip_hit() -> void:
	var tw := create_tween()
	tw.tween_property(arm_front, "position:x", SHOULDER_FRONT.x + 5.0, 0.06)
	tw.tween_property(arm_front, "position:x", SHOULDER_FRONT.x, 0.15)
	if not _player_close(whip_range + 8.0) or signf(player.global_position.x - global_position.x) != facing:
		return
	Sfx.play(&"gun_bash", player.global_position, 0.0)
	if player.has_method(&"take_damage"):
		player.take_damage(1, global_position + Vector2(0, -30))
	player.velocity = Vector2(facing * (320.0 if phase == 3 else 240.0), -180.0)
	Burst.spawn(get_tree().current_scene, player.global_position + Vector2(0, -22), Vector2(facing, -0.3), Color(1, 0.9, 0.5), 6, 80.0)


# ---------------------------------------------------------------- 3. fáza: strecha a stožiar

func _to_mast() -> void:
	invulnerable = true
	boss = Boss.TO_MAST
	state = State.IDLE
	laser.visible = false
	stage.emit(&"to_roof")


func _climb_mast() -> void:
	boss = Boss.CLIMB
	_set_facing(-1.0)
	var top := Vector2(mast_span.y - 14.0, mast_top_y)
	var h: float = absf(global_position.y - mast_top_y)
	var t: float = maxf(h / CLIMB_SPEED, 0.6)
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", mast_top_y - 6.0, t)
	tw.parallel().tween_method(_climb_pose, 0.0, t, t)
	for k in int(t / 0.5):
		tw.parallel().tween_callback(func(): Sfx.play(&"ladder_rung", global_position, -6.0)).set_delay(0.3 + k * 0.5)
	tw.tween_property(self, "global_position", top, 0.25)
	tw.tween_callback(func():
		phase = 3
		invulnerable = false
		_ammo = clip
		stage.emit(&"on_mast")
		_start_aim())


func _climb_pose(t: float) -> void:
	arm_back.rotation = -1.6 + sin(t * 18.0) * 0.4
	arm_front.rotation = -1.4 - sin(t * 18.0) * 0.4
	leg_front.rotation = sin(t * 18.0) * 0.3
	leg_back.rotation = -sin(t * 18.0) * 0.3


## Blesk udrel do stožiara – kým je na plošine, chvíľu sa drží zábradlia a nestrieľa
func lightning_stun() -> void:
	if not active or invulnerable or phase != 3 or boss == Boss.SCRIPTED or boss == Boss.CLIMB:
		return
	state = State.STUN
	timer = 1.6
	laser.visible = false
	_tint_flash(Color(2.2, 2.2, 2.6), 0.4)


# ---------------------------------------------------------------- zásahy

func take_hit_at(damage: float, dir: Vector2, pos: Vector2) -> void:
	if decoy:
		shatter()
		return
	if invulnerable or not active:
		Burst.spawn(get_tree().current_scene, pos, -dir + Vector2(0, -0.4), Color(1.0, 0.85, 0.45), 4, 90.0)
		Sfx.play(&"ricochet_1", pos, -6.0, 0.15)
		return
	take_hit(damage, dir)


func take_hit(damage: float, dir: Vector2, blood: bool = true) -> void:
	if decoy:
		shatter()
		return
	if state == State.DEAD or invulnerable or not active or boss in [Boss.SCRIPTED, Boss.HIDDEN, Boss.EMERGE]:
		return
	var in_mirror: bool = boss == Boss.MIRROR_AIM or boss == Boss.MIRROR_FIRE
	var floor_hp: float = _phase_floor()
	health = maxf(health - minf(damage, MIRROR_HIT_CAP if in_mirror else HIT_CAP), floor_hp)
	health_changed.emit(health, max_health)
	if blood:
		Sfx.play(&"impact_body", global_position + Vector2(0, -40), -2.0)
		Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -44), dir + Vector2(0, -0.3),
				Color(0.62, 0.05, 0.05), 6, 90.0, Vector2(0, 520), 0.5)
	_tint_flash(HIT_RED, 0.18)
	if in_mirror:
		_mirror_hit()
		return
	if health > floor_hp:
		return
	match phase:
		2:
			_to_mast()
		3:
			_start_dying()


func hat_hit(damage: float, dir: Vector2) -> void:
	if decoy:
		shatter()
		return
	if invulnerable or not active or boss in [Boss.SCRIPTED, Boss.HIDDEN, Boss.EMERGE, Boss.CLIMB, Boss.TO_MAST]:
		Sfx.play(&"hat_bonk", global_position + Vector2(0, -60))
		return
	if boss == Boss.MIRROR_AIM or boss == Boss.MIRROR_FIRE:
		take_hit(damage, dir, false)
		return
	super.hat_hit(damage, dir)


func trip(dir: float) -> bool:
	if decoy:
		shatter()
		return true
	if invulnerable or not active or phase < 2 or boss in [Boss.SCRIPTED, Boss.CLIMB, Boss.TO_MAST, Boss.EMERGE]:
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


## Posledná rana: C96 jej vypadne, potáca sa – ďalej režíruje level (pád zo strechy)
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
	d.position = gun.global_position + Vector2(12.0 * facing, 4)
	gun.visible = false
	for c in arm_front.get_children():
		if c is Sprite2D and (c as Sprite2D).region_enabled:
			c.visible = false


# ---------------------------------------------------------------- pohyb častí tela

func _animate(delta: float) -> void:
	if boss == Boss.CLIMB:
		return   # ruky a nohy hýbe tween (_climb_mast)
	if boss == Boss.SCRIPTED and gun and not gun.visible:
		super._animate(delta)
		arm_front.rotation = lerp_angle(arm_front.rotation, -1.7 if hands_up else 1.3, minf(1.0, 10.0 * delta))
		arm_back.rotation = lerp_angle(arm_back.rotation, -1.5 if hands_up else 1.5, minf(1.0, 10.0 * delta))
		return
	super._animate(delta)
	if not _tripped and not _getting_up:
		# dlhá sukňa – kroky sú drobné, spod lemu vykúkajú len lodičky
		leg_front.rotation *= 0.5
		leg_back.rotation *= 0.5
	if boss == Boss.WHIP and not _tripped:   # náprah – pištoľ zdvihnutá rúčkou dopredu
		arm_front.rotation = lerp_angle(arm_front.rotation, -1.2, minf(1.0, 14.0 * delta))
	elif boss == Boss.RELOAD and not _tripped:   # nabíja – druhá ruka k puzdru
		var fg: Vector2 = gun.to_global(Vector2(7, -2)) if gun else global_position
		arm_back.rotation = _arm_rot((fg - arm_back.global_position).angle())
