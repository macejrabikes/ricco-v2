class_name BigLou
extends CharacterBody2D
## Big Lou Fontana – boss kapitoly II na palube S.S. Margaret (levels/level2/margaret.gd). Mafiáni nehovoria – ani Lou.
## Telo je z častí ako Gangster (cutout, Godot docs: tutorials/animation/cutout_animation), len ~1,4× väčšie:
## krémový oblek, fedora, cigara, nepriestrelná vesta pod sakom a Thompson s bubnom (characters/lou/*.png).
## Zdravie je rozdelené na tri fázy (značky v páse ui/boss_bar.gd) – pri prechode je Lou chvíľu nezraniteľný.
##
## 1. fáza – krídlo mostíka:
##   mieri (červená čiara) → dlhá dávka, zbraň sa počas nej pomaly otáča za Riccom → pauza, prejde sa po krídle → znova
##   debny na palube (world/ship/ship_crate.gd) guľky postupne rozbijú – za krytom sa nedá sedieť večne
##   Ricco sa dlho skrýva / stojí pod krídlom → hodí dynamit (characters/lou/dynamite.gd)
##   Ricco vylezie až k nemu → úder pažbou, ktorý ho zhodí z krídla
## → zoskočí na palubu (rozdrví debnu) a beží do búdky pri žeriave
## 2. fáza – žeriav (world/ship/crane.gd), z búdky trčí len hlava:
##   sieť ide za Riccom → tieň → vypadne debna (3×) → sieť spustí nízko a zametie palubu (popod ňu sa dá prešmyknúť)
##   Ricco mimo dosahu žeriavu → Thompson / dynamit; tri rýchle zásahy do hlavy → skrčí sa za plech
## → blesk udrie do žeriavu, rameno sa zrúti, výbuch odhodí Lou z búdky (level to režíruje – signál stage(&"lightning"))
## 3. fáza – loď horí, Lou je pripálený a zúrivý, chodí po palube:
##   kráča k Riccovi (debny v ceste rozbije), dávky s kratším mierením, po troch dávkach prebíja bubon
##   rozbeh (dupne, skloní hlavu) – kto stojí, toho zrazí; kto sa po bruchu prešmykne medzi nohami, ten ho podkopne;
##   náraz do steny / stĺpa žeriavu → omámený (hviezdičky) a vesta nepomáha; trojitý dynamit; smeje sa, keď Ricca zraní
##   sudy whisky (world/ship/ship_barrel.gd) vedľa neho = 4 HP
## Smrť: posledná dávka do neba, padne na kolená, na tvár – zo saka sa vykotúľa zapálený dynamit… a z Lou ostane len klobúk.
## Godot docs: classes/class_characterbody2d, classes/class_physicsdirectspacestate2d, classes/class_tween

signal health_changed(health: float, max_health: float)
signal vest_hit        ## guľka sa odrazila od vesty (level dá Riccovi radu: mier na hlavu)
signal threw           ## hodil dynamit
## Udalosti pre level (hlášky ducha, réžia prechodov): to_crane, landed, in_booth, crane_drop, crane_sweep,
## lightning, burnt_up, charge, dazed, reload, dying
signal stage(name: StringName)
signal died

enum State { WAIT, RACK, AIM, BURST, COOLDOWN, WALK, THROW, BASH, STAGGER, DEAD,
		LEAP, RUN, HOP_IN, CRANE, HOLD, BLOWN, LIE, GETUP, ROAR, WINDUP, CHARGE, DAZED, RELOAD, LAUGH }
enum Crane { TRACK, WARN, DROPPED, PREP, LOWER, SWEEP, RAISE }

@export var max_health: float = 36.0
@export_range(0.0, 1.0) var vest_factor: float = 0.25
@export_range(-1.0, 1.0, 2.0) var start_facing: float = -1.0

@export_group("Thompson")
@export var weapon: WeaponData = preload("res://weapons/tommy/tommy.tres")
@export var weapon_texture: Texture2D = preload("res://characters/lou/thompson_drum.png")
@export var aim_time: float = 0.75
@export var aim_turn_speed: float = 130.0     ## °/s pri mierení
@export var burst_turn_speed: float = 60.0    ## °/s počas dávky – dá sa z nej utiecť
@export var burst_count: Vector2i = Vector2i(8, 12)
@export var burst_interval: float = 0.085
@export var spread_deg: float = 4.0
@export var bullet_speed: float = 400.0
@export var cooldown: Vector2 = Vector2(0.9, 1.5)

@export_group("Dynamite & bash")
@export var throw_cooldown: float = 6.0       ## s – najkratší čas medzi dvoma dynamitmi
@export var hide_time: float = 2.4            ## s – takto dlho Ricca nevidí (za krytom) → hodí dynamit
@export var bash_range: float = 36.0
@export var bash_push: Vector2 = Vector2(300, -200)
@export var walk_speed: float = 26.0
@export var walk_span: Vector2 = Vector2(782, 826)   ## px (globálne x) – kade sa môže prechádzať (krídlo mostíka)

@export_group("Phase 2 & 3")
@export var booth_x: float = 628.0            ## px – búdka pri žeriave (2. fáza)
@export var deck_span: Vector2 = Vector2(124, 812)   ## px – paluba v 3. fáze (kajuta na korme … nadstavba)
@export var charge_speed: float = 230.0
@export var charge_cooldown: float = 5.0
@export var stomp_speed: float = 40.0         ## px/s – chôdza v 3. fáze

const BULLET := preload("res://weapons/pistol/bullet.tscn")
const WEAPON_PICKUP := preload("res://weapons/weapon_pickup.gd")
const DROP := preload("res://weapons/pistol/magazine_drop.tscn")
const FLASH := preload("res://weapons/pistol/muzzle_flash_big.png")
const DYNAMITE := preload("res://characters/lou/dynamite.gd")
const ART := "res://characters/lou/"
const COVER_LAYER := 32

# kostra (pri pohľade doprava, päty v počiatku)
const HIP := Vector2(0, -32)
const LEG_FRONT := Vector2(3, -33)
const LEG_BACK := Vector2(-4, -33)
const NECK := Vector2(5, -70)
const HAT_AT := Vector2(5, -98)
const SHOULDER_FRONT := Vector2(3, -66)
const SHOULDER_BACK := Vector2(-3, -66)
const EYE := Vector2(18, -86)
const CIGAR := Vector2(28, -78)
const PIVOT_LEG := Vector2(7, 1)
const PIVOT_TORSO := Vector2(19, 40)
const PIVOT_HEAD := Vector2(16, 32)
const PIVOT_HAT := Vector2(20, 16)
const PIVOT_ARM := Vector2(5, 5)
const ARM_GRIP := Vector2(28, 5)
const REST_AIM := 0.9      ## rad pod vodorovnou – Thompson v pokoji pri bruchu
const DUCK_DEPTH := 30.0   ## px – o toľko sa v búdke skrčí (hlava za plechom)
const LIE_BACK := -14.0    ## px – rig nad zemou, keď leží na chrbte (inak by chrbát trčal pod palubu)
const LIE_FACE := -20.0    ## px – …na bruchu (veľké brucho)

var state: State = State.WAIT
var phase: int = 1
var invulnerable: bool = false
var health: float
var facing: float = -1.0
var timer: float = 0.0
var shots_left: int = 0
var aim_angle: float = PI - REST_AIM
var active: bool = false
var player: Node2D
var crane: Node2D      ## world/ship/crane.gd (skupina „crane“)
var lever: Node2D      ## páka v búdke (skupina „crane_lever“)

var _hidden_t: float = 0.0
var _throw_cd: float = 3.0
var _charge_cd: float = 2.0
var _laugh_cd: float = 0.0
var _bursts: int = 0
var _walk_to: float = NAN
var _walk_phase: float = 0.0
var _smoke_t: float = 2.0
var _flash_t: float = 0.0
var _hurt_t: float = 0.0
var _bashed: bool = false
var _aggro: float = 0.0   ## s – po zásahu strieľa aj keď nie je na obrazovke (Ricco by ho inak ostreľoval spoza okraja)
var _seq: int = 0         ## krok v rámci stavu (skok, rev, prebíjanie…)
var _air: bool = false
var _wing_edge: float = 782.0
var _crane_mode: Crane = Crane.TRACK
var _drops: int = 0
var _sweep_end: float = 0.0
var _out_t: float = 0.0   ## s – Ricco je mimo dosahu žeriavu
var _duck_t: float = 0.0
var _duck: float = 0.0    ## 0–1 ako veľmi je skrčený za plechom búdky
var _head_hits: Array[float] = []
var _lever_want: float = 0.0
var _charge_hit: bool = false
var _charge_t: float = 0.0
var _fallen: bool = false
var _burnt: bool = false
var _ricco_hp: int = -1
var _t: float = 0.0
var _dying: bool = false

var _squash: Node2D
var rig: Node2D
var leg_front: Node2D
var leg_back: Node2D
var torso: Node2D
var head: Node2D
var head_sprite: Sprite2D
var hat: Sprite2D
var arm_front: Node2D
var arm_back: Node2D
var gun: Sprite2D
var hand: Sprite2D
var muzzle: Marker2D
var flash: Sprite2D
var laser: Line2D
var _head_tex: Texture2D
var _held: Sprite2D   ## dynamit v zadnej ruke pri náprahu
var _drum: Sprite2D   ## nový bubon v zadnej ruke pri prebíjaní
var _head_hurt_tex: Texture2D
var _stars: Node2D


func _ready() -> void:
	health = max_health
	collision_layer = 4    # enemies – Riccove guľky
	collision_mask = 1     # world
	floor_snap_length = 8.0
	add_to_group(&"enemies")
	add_to_group(&"boss")
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 14.0
	cap.height = 96.0
	shape.shape = cap
	shape.position = Vector2(4, -48)
	add_child(shape)
	_build_rig()
	_set_facing(start_facing)
	aim_angle = _rest_angle()
	_wing_edge = walk_span.x


# ---------------------------------------------------------------- telo z častí

func _part(parent: Node, file: String, pivot: Vector2, at: Vector2) -> Node2D:
	var holder := Node2D.new()
	holder.position = at
	parent.add_child(holder)
	var s := Sprite2D.new()
	s.texture = load(ART + file + ".png")
	s.centered = false
	s.offset = -pivot
	holder.add_child(s)
	return holder


func _build_rig() -> void:
	_squash = Node2D.new()   # stlačenie pri dopade / dupnutí (rig sám sa zrkadlí a otáča)
	add_child(_squash)
	rig = Node2D.new()
	_squash.add_child(rig)
	arm_back = _part(rig, "arm_back", PIVOT_ARM, SHOULDER_BACK)
	_held = Sprite2D.new()
	_held.texture = load(ART + "dynamite.png")
	_held.position = ARM_GRIP - PIVOT_ARM + Vector2(1, -3)
	_held.visible = false
	arm_back.add_child(_held)
	_drum = Sprite2D.new()
	_drum.texture = load(ART + "drum.png")
	_drum.position = ARM_GRIP - PIVOT_ARM + Vector2(2, 2)
	_drum.visible = false
	arm_back.add_child(_drum)
	leg_back = _part(rig, "leg_back", PIVOT_LEG, LEG_BACK)
	leg_front = _part(rig, "leg", PIVOT_LEG, LEG_FRONT)
	torso = _part(rig, "torso", PIVOT_TORSO, HIP)
	head = _part(rig, "head", PIVOT_HEAD, NECK)
	head_sprite = head.get_child(0) as Sprite2D
	_head_tex = head_sprite.texture
	_head_hurt_tex = load(ART + "head_hurt.png")
	hat = Sprite2D.new()
	hat.texture = load(ART + "hat.png")
	hat.centered = false
	hat.offset = -PIVOT_HAT
	hat.position = HAT_AT
	rig.add_child(hat)
	arm_front = _part(rig, "arm", PIVOT_ARM, SHOULDER_FRONT)
	gun = Sprite2D.new()
	gun.texture = weapon_texture
	gun.centered = false
	gun.position = ARM_GRIP - PIVOT_ARM - weapon.grip_px
	arm_front.add_child(gun)
	hand = Sprite2D.new()   # päsť nad rukoväťou (aby ju „zvierala“)
	hand.texture = load(ART + "arm.png")
	hand.centered = false
	hand.region_enabled = true
	hand.region_rect = Rect2(ARM_GRIP.x - 3, 0, hand.texture.get_width() - ARM_GRIP.x + 3, hand.texture.get_height())
	hand.position = Vector2(ARM_GRIP.x - 3, 0) - PIVOT_ARM
	arm_front.add_child(hand)
	muzzle = Marker2D.new()
	muzzle.position = gun.position + weapon.muzzle_px
	arm_front.add_child(muzzle)
	flash = Sprite2D.new()
	flash.texture = FLASH
	flash.hframes = 3
	flash.centered = false
	flash.offset = Vector2(-3, -12)
	flash.position = Vector2(1, 0)
	flash.visible = false
	muzzle.add_child(flash)
	laser = Line2D.new()
	laser.width = 1.0
	laser.default_color = Color(1.0, 0.15, 0.1, 0.55)
	laser.visible = false
	laser.top_level = true
	add_child(laser)
	# hviezdičky nad hlavou, keď je omámený (mimo rigu – nezrkadlia sa ani neotáčajú)
	_stars = Node2D.new()
	_stars.visible = false
	add_child(_stars)
	for i in 3:
		var s := Sprite2D.new()
		s.texture = load(ART + "star.png")
		_stars.add_child(s)


func _set_facing(f: float) -> void:
	if f == 0.0:
		return
	facing = f
	rig.scale.x = f


## Globálny uhol → rotácia ruky v (prípadne zrkadlenej) kostre
func _arm_rot(global_angle: float) -> float:
	return global_angle if facing > 0.0 else wrapf(PI - global_angle, -PI, PI)


func _rest_angle() -> float:
	return REST_AIM if facing > 0.0 else PI - REST_AIM


## Pripálený oblek a tvár od sadzí (po výbuchu búdky)
func _burn() -> void:
	if _burnt:
		return
	_burnt = true
	(torso.get_child(0) as Sprite2D).texture = load(ART + "torso_burnt.png")
	(arm_front.get_child(0) as Sprite2D).texture = load(ART + "arm_burnt.png")
	hand.texture = load(ART + "arm_burnt.png")
	(arm_back.get_child(0) as Sprite2D).texture = load(ART + "arm_back_burnt.png")
	(leg_front.get_child(0) as Sprite2D).texture = load(ART + "leg_burnt.png")
	(leg_back.get_child(0) as Sprite2D).texture = load(ART + "leg_back_burnt.png")
	_head_tex = load(ART + "head_burnt.png")
	_head_hurt_tex = _head_tex
	head_sprite.texture = _head_tex


func _squish(s: Vector2, t: float = 0.25) -> void:
	_squash.scale = s
	create_tween().tween_property(_squash, "scale", Vector2.ONE, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ťažký dopad – duní paluba, prach, trasie sa kamera; debny pod ním sa rozletia
func _land_heavy(power: float = 1.0) -> void:
	Sfx.play(&"body_thud", global_position, 2.0 * power, 0.08)
	_squish(Vector2(1.18, 0.8))
	var scene := get_tree().current_scene
	Burst.spawn(scene, global_position + Vector2(-14, -2), Vector2(-1, -0.4), Color(0.7, 0.7, 0.74, 0.6), 7, 70.0 * power, Vector2(0, 30), 0.6)
	Burst.spawn(scene, global_position + Vector2(18, -2), Vector2(1, -0.4), Color(0.7, 0.7, 0.74, 0.6), 7, 70.0 * power, Vector2(0, 30), 0.6)
	_shake(0.3, 4.0 * power, 300.0)
	for c in get_tree().get_nodes_in_group(&"ship_cover"):
		var cn := c as Node2D
		if cn and absf(cn.global_position.x - global_position.x - 4.0) < 32.0 and cn.global_position.y > global_position.y - 4.0 \
				and cn.global_position.y < global_position.y + 44.0 and cn.has_method(&"shatter"):
			cn.shatter(Vector2(signf(cn.global_position.x - global_position.x), -1.0))


func _shake(t: float, strength: float, dist: float) -> void:
	if player and player.global_position.distance_to(global_position) < dist:
		player.set(&"shake_timer", t)
		player.set(&"shake_strength", strength)


# ---------------------------------------------------------------- ovládanie z levelu

## Začiatok boja – level ho zavolá, keď Ricco Lou prvý raz uvidí. rack = najprv nabije Thompson (úvod)
func start(rack: bool = true) -> void:
	if state == State.DEAD or active:
		return
	active = true
	if phase == 3:
		state = State.ROAR
		timer = 1.3
		_seq = 0
		return
	if phase == 2:
		state = State.CRANE
		_crane_mode = Crane.TRACK
		timer = 1.0
		return
	if rack:
		state = State.RACK
		timer = 1.0
		Sfx.play(&"slide_rack", global_position + Vector2(0, -50), 0.0, 0.0)
		var tw := create_tween()
		tw.tween_property(self, "aim_angle", _rest_angle() - 1.2 * facing, 0.2)
		tw.tween_property(self, "aim_angle", _rest_angle(), 0.25).set_delay(0.25)
	else:
		state = State.COOLDOWN
		timer = 0.6


## Checkpoint v boji: Lou začne rovno v 2. (v búdke) alebo 3. fáze (pripálený na palube). Volá level pred start().
func setup_phase(p: int, at: Vector2) -> void:
	phase = p
	health = max_health * (4 - p) / 3.0
	global_position = at
	walk_span = deck_span
	if p == 2:
		z_index = -5
	else:
		_enter_phase3()
		_burn()
	health_changed.emit(health, max_health)


## Je Lou na obrazovke? (nestrieľa spoza nej – hráč ho musí vidieť)
func on_screen() -> bool:
	var p: Vector2 = get_global_transform_with_canvas().origin + Vector2(0, -50)
	return get_viewport_rect().grow(-12.0).has_point(p)


## Hranica zdravia aktuálnej fázy (pod ňu nejde – najprv príde prechod)
func _phase_floor() -> float:
	return max_health * (3 - phase) / 3.0


# ---------------------------------------------------------------- hlavná slučka

func _physics_process(delta: float) -> void:
	_t += delta
	if not is_on_floor():
		velocity += get_gravity() * delta
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	if crane == null:
		crane = get_tree().get_first_node_in_group(&"crane") as Node2D
		lever = get_tree().get_first_node_in_group(&"crane_lever") as Node2D
	timer -= delta
	_throw_cd -= delta
	_charge_cd -= delta
	_laugh_cd -= delta
	_aggro -= delta
	_flash_t -= delta
	_duck_t -= delta
	flash.visible = _flash_t > 0.0
	_hurt_t -= delta
	head_sprite.texture = _head_hurt_tex if _hurt_t > 0.0 else _head_tex
	var ricco_ok: bool = player != null and player.get(&"state") != 3   # Ricco žije
	_watch_ricco()

	match state:
		State.WAIT:
			velocity.x = 0.0
			aim_angle = lerp_angle(aim_angle, _rest_angle(), minf(1.0, 6.0 * delta))
		State.RACK:
			velocity.x = 0.0
			if timer <= 0.0:
				state = State.COOLDOWN
				timer = 0.3
		State.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			if ricco_ok:
				_face_player()
				_track_aim(delta, aim_turn_speed * 0.5)
			if timer <= 0.0 and ricco_ok:
				_next_action()
		State.WALK:
			var dx: float = _walk_to - global_position.x
			if absf(dx) < 2.0 or timer <= 0.0:
				velocity.x = 0.0
				state = State.COOLDOWN
				timer = 0.25
			else:
				velocity.x = signf(dx) * (stomp_speed if phase == 3 else walk_speed)
			if ricco_ok:
				_face_player()
				_track_aim(delta, aim_turn_speed * 0.5)
		State.AIM:
			velocity.x = 0.0
			_face_player()
			_track_aim(delta, aim_turn_speed)
			_update_laser(true)
			if not ricco_ok:
				state = State.COOLDOWN
				timer = 1.0
			elif timer <= 0.0:
				state = State.BURST
				shots_left = randi_range(burst_count.x, burst_count.y)
				timer = 0.0
		State.BURST:
			velocity.x = 0.0
			if ricco_ok:
				_track_aim(delta, burst_turn_speed)
			if timer <= 0.0 and shots_left > 0:
				_fire()
				shots_left -= 1
				timer = burst_interval
			elif shots_left <= 0 and timer <= 0.0:
				_bursts += 1
				state = State.COOLDOWN
				timer = randf_range(cooldown.x, cooldown.y)
				if phase == 1 and randf() < 0.5:
					_pick_walk()
		State.THROW:
			velocity.x = 0.0
			# náprah: Thompson sklopí k bruchu, zadná ruka s dynamitom ide za hlavu (_animate) → hod
			aim_angle = lerp_angle(aim_angle, _rest_angle(), minf(1.0, 10.0 * delta))
			_held.visible = true
			if timer <= 0.0:
				_held.visible = false
				_throw()
				state = State.COOLDOWN
				timer = 0.9
		State.BASH:
			if not _bashed:
				# náprah pažbou dozadu (zbraň hore) a výpad k Riccovi, potom švih dopredu (z búdky sa len nakloní)
				aim_angle = lerp_angle(aim_angle, -PI / 2.0 - 0.6 * facing, minf(1.0, 12.0 * delta))
				var gap: float = (player.global_position.x - global_position.x) * facing
				velocity.x = facing * 110.0 if gap > bash_range - 8.0 and phase != 2 else 0.0
				if timer <= 0.0:
					velocity.x = 0.0
					_bash()
			else:
				velocity.x = 0.0
				if timer <= 0.0:
					state = State.COOLDOWN
					timer = 0.5
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
			if timer <= 0.0:
				rig.rotation = 0.0
				state = State.COOLDOWN
				timer = 0.4
		State.LEAP:
			_leap()
		State.RUN:
			var dx: float = booth_x - global_position.x
			velocity.x = signf(dx) * 95.0
			_set_facing(signf(dx))
			aim_angle = lerp_angle(aim_angle, _rest_angle(), minf(1.0, 8.0 * delta))
			if absf(dx) < 26.0:
				# skok do búdky
				state = State.HOP_IN
				velocity = Vector2(dx * 2.6, -170.0)
				_air = false
		State.HOP_IN:
			if not is_on_floor():
				_air = true
			elif _air:
				velocity.x = 0.0
				global_position.x = booth_x
				_squish(Vector2(1.1, 0.88))
				Sfx.play(&"land", global_position, 0.0, 0.1)
				invulnerable = false
				state = State.CRANE
				_crane_mode = Crane.TRACK
				timer = 1.2
				_drops = 0
				_stage(&"in_booth")
		State.CRANE:
			velocity.x = 0.0
			_crane_tick(delta, ricco_ok)
		State.HOLD:
			velocity.x = 0.0
			# panika – páka nereaguje, žeriav sa točí sám
			_lever_want = 0.6 * sin(_t * 22.0)
			aim_angle = lerp_angle(aim_angle, _rest_angle(), minf(1.0, 6.0 * delta))
		State.BLOWN:
			rig.rotation += 13.0 * delta * (signf(velocity.x) if velocity.x != 0.0 else 1.0)
			if not is_on_floor():
				_air = true
			elif _air:
				velocity.x = 0.0
				_land_heavy(1.3)
				state = State.LIE
				timer = 1.3
				rig.rotation = wrapf(rig.rotation, -PI, PI)
				var tl := create_tween()
				tl.tween_property(rig, "rotation", -PI / 2.0 * facing, 0.12)   # leží na chrbte
				tl.parallel().tween_property(rig, "position:y", LIE_BACK, 0.12)
		State.LIE:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if randf() < delta * 6.0:
				Burst.spawn(get_tree().current_scene, global_position + Vector2(randf_range(-40.0, 40.0), -8), Vector2(0, -1),
						Color(0.25, 0.23, 0.24, 0.6), 2, 20.0, Vector2(0, -30), 1.2)
			if timer <= 0.0:
				state = State.GETUP
				timer = 0.7
				Sfx.play(&"slide_getup", global_position, 0.0, 0.1)
				var tw := create_tween()
				tw.tween_property(rig, "rotation", 0.15 * facing, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(rig, "position:y", 0.0, 0.5)
				tw.tween_property(rig, "rotation", 0.0, 0.2)
		State.GETUP:
			velocity.x = 0.0
			if timer <= 0.0:
				if phase == 3 and invulnerable:
					state = State.ROAR   # po výbuchu búdky – rev a 3. fáza
					timer = 1.3
					_seq = 0
					_stage(&"burnt_up")
				else:
					state = State.COOLDOWN
					timer = 0.3
		State.ROAR:
			velocity.x = 0.0
			_roar(delta)
		State.WINDUP:
			velocity.x = 0.0
			_face_player()
			aim_angle = lerp_angle(aim_angle, _rest_angle(), minf(1.0, 10.0 * delta))
			if (_seq == 0 and timer < 0.4) or (_seq == 1 and timer < 0.12):
				_seq += 1   # dupne (ako býk pred útokom)
				_squish(Vector2(1.12, 0.86), 0.18)
				Sfx.play(&"land", global_position, 2.0, 0.1)
				Burst.spawn(get_tree().current_scene, global_position, Vector2(-facing, -0.3), Color(0.7, 0.7, 0.74, 0.6), 6, 60.0, Vector2(0, 30), 0.5)
				_shake(0.12, 2.0, 260.0)
			if timer <= 0.0:
				state = State.CHARGE
				_charge_hit = false
				_charge_t = 0.0
				Sfx.play(&"punch_swing", global_position + Vector2(0, -60), 0.0)
		State.CHARGE:
			_charge(delta)
		State.DAZED:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			aim_angle = lerp_angle(aim_angle, _rest_angle() + 0.5 * facing, minf(1.0, 6.0 * delta))   # Thompson ovisne
			if timer <= 0.0:
				_stars.visible = false
				var tw := create_tween()
				tw.tween_property(rig, "rotation", 0.0, 0.45 if _fallen else 0.2).set_trans(Tween.TRANS_QUAD)
				tw.parallel().tween_property(rig, "position:y", 0.0, 0.45 if _fallen else 0.2)
				if _fallen:
					Sfx.play(&"slide_getup", global_position, 0.0, 0.1)
					state = State.GETUP
					timer = 0.6
				else:
					state = State.COOLDOWN
					timer = 0.4
				_fallen = false
		State.RELOAD:
			velocity.x = 0.0
			_reload()
		State.LAUGH:
			velocity.x = 0.0
			aim_angle = lerp_angle(aim_angle, _rest_angle(), minf(1.0, 8.0 * delta))
			if randf() < delta * 5.0:
				Burst.spawn(get_tree().current_scene, global_position + Vector2((CIGAR.x + 8.0) * facing, CIGAR.y),
						Vector2(facing * 0.3, -1.0), Color(0.8, 0.8, 0.82, 0.45), 2, 18.0, Vector2(-10, -14), 0.8)
			if timer <= 0.0:
				state = State.COOLDOWN
				timer = 0.2
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)

	if state != State.AIM:
		laser.visible = false
	# v rámci krídla mostíka / paluby – ďalej nejde (ani keď ho niečo odsunie)
	if state != State.DEAD and state != State.LEAP and state != State.BLOWN and state != State.HOP_IN:
		var nx: float = global_position.x + velocity.x * delta
		if nx < walk_span.x or nx > walk_span.y:
			if state == State.CHARGE:
				_crash()
			velocity.x = 0.0
	move_and_slide()
	if phase >= 2 and (state == State.WALK or state == State.RUN or state == State.CHARGE):
		_bulldoze()
	_animate(delta)
	# cigara – občas obláčik dymu; pripálený oblek sa ešte dymí
	if state != State.DEAD:
		_smoke_t -= delta
		if _smoke_t <= 0.0:
			_smoke_t = randf_range(1.8, 3.4)
			Burst.spawn(get_tree().current_scene, global_position + Vector2((CIGAR.x + 10.0) * facing, CIGAR.y + _duck * DUCK_DEPTH),
					Vector2(facing * 0.3, -1.0), Color(0.8, 0.8, 0.82, 0.45), 4, 14.0, Vector2(-10, -14), 1.0)
		if _burnt and randf() < delta * 3.0:
			Burst.spawn(get_tree().current_scene, global_position + Vector2(randf_range(-10.0, 14.0), randf_range(-80.0, -30.0)),
					Vector2(0, -1), Color(0.3, 0.28, 0.3, 0.45), 1, 14.0, Vector2(-8, -26), 1.0)
	# vidí ho? (za debnou ho nevidí → po chvíli dynamit)
	if active and ricco_ok and state != State.DEAD:
		_hidden_t = 0.0 if _has_los() else _hidden_t + delta


## Smeje sa, keď Ricca zraní (3. fáza)
func _watch_ricco() -> void:
	if player == null:
		return
	var hp: int = player.get(&"health")
	if _ricco_hp >= 0 and hp < _ricco_hp and phase == 3 and active and _laugh_cd <= 0.0 and hp > 0 \
			and (state == State.COOLDOWN or state == State.WALK or state == State.BURST):
		state = State.LAUGH
		timer = 1.0
		shots_left = 0
		_laugh_cd = 5.0
	_ricco_hp = hp


## Čo ďalej (podľa fázy)
func _next_action() -> void:
	match phase:
		2:
			_next_action_crane()
			return
		3:
			_next_action_deck()
			return
	if not on_screen() and _aggro <= 0.0:
		timer = 0.4
		return
	var d: Vector2 = player.global_position - global_position
	if absf(d.x) < 72.0 and absf(d.y) < 40.0:
		_start_bash()
		return
	var under: bool = d.y > 40.0 and absf(d.x) < 64.0          # Ricco stojí pod krídlom – Thompsonom tam nedostrelí
	var hiding: bool = _hidden_t > hide_time
	var tired: bool = _bursts >= 3 and randf() < 0.45
	if _throw_cd <= 0.0 and (under or hiding or tired):
		if under and global_position.x > walk_span.x + 10.0:
			# pod krídlo sa hodiť nedá – najprv prejde na predný kraj krídla, odtiaľ ho pustí cez zábradlie
			_walk_to = walk_span.x + 4.0
			state = State.WALK
			timer = 2.5
			return
		state = State.THROW
		timer = 0.45
		return
	if under:
		_pick_walk()
		return
	state = State.AIM
	timer = aim_time


## Ricco vyliezol až k nemu – zblízka nestrieľa (ústie by bolo za ním), vykročí a udrie pažbou
func _start_bash() -> void:
	state = State.BASH
	_bashed = false
	timer = 0.34
	Sfx.play(&"punch_swing", global_position + Vector2(0, -60), -4.0)


func _pick_walk() -> void:
	_walk_to = clampf(global_position.x + randf_range(-28.0, 28.0), walk_span.x + 4.0, walk_span.y - 4.0)
	if absf(_walk_to - global_position.x) > 6.0:
		state = State.WALK
		timer = 1.6


func _player_target() -> Vector2:
	var h: float = 26.0
	if player.get(&"state") == 4:
		h = 12.0   # šmyk po bruchu – je nižšie
	elif player.get(&"sneaking"):
		h = 18.0   # prikrčený za debnou
	return player.global_position + Vector2(0, -h)


func _has_los() -> bool:
	var eye := global_position + Vector2(EYE.x * facing, EYE.y + _duck * DUCK_DEPTH)
	var q := PhysicsRayQueryParameters2D.create(eye, _player_target(), 1 | COVER_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _face_player() -> void:
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 3.0 and signf(dx) != facing:
		_set_facing(signf(dx))
		aim_angle = PI - aim_angle


func _track_aim(delta: float, speed: float) -> void:
	var shoulder := global_position + Vector2(SHOULDER_FRONT.x * facing, SHOULDER_FRONT.y)
	var want: float = (_player_target() - shoulder).angle()
	var step: float = deg_to_rad(speed) * delta
	aim_angle = aim_angle + clampf(angle_difference(aim_angle, want), -step, step)


func _update_laser(on: bool) -> void:
	laser.visible = on and fmod(timer, 0.12) > 0.03   # bliká
	if not laser.visible:
		return
	var from := muzzle.global_position
	var to := from + Vector2.from_angle(aim_angle) * 600.0
	var q := PhysicsRayQueryParameters2D.create(from, to, 1 | 2 | COVER_LAYER)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		to = hit.position
	laser.points = PackedVector2Array([from, to])


func _fire() -> void:
	var b := BULLET.instantiate()
	b.direction = Vector2.from_angle(aim_angle + deg_to_rad(randf_range(-spread_deg, spread_deg)))
	b.shooter = self
	b.speed = bullet_speed
	b.lifetime = 1.6
	b.hit_mask = 1 | 2 | COVER_LAYER    # svet (aj debny) + Ricco
	b.modulate = Color(1.0, 0.6, 0.5)
	b.global_position = muzzle.global_position
	get_tree().current_scene.add_child(b)
	_flash_t = 0.05
	flash.frame = randi() % 2
	flash.rotation = randf_range(-0.12, 0.12)
	Sfx.shot(weapon, global_position, -2.0)
	arm_front.position.x = SHOULDER_FRONT.x - 2.0   # spätný ráz
	create_tween().tween_property(arm_front, "position:x", SHOULDER_FRONT.x, 0.07)


## Dynamit: lob tam, kde je (alebo kde sa skrýva) Ricco – dopadne o chvíľu, šnúra syčí. V 3. fáze hneď tri naraz.
func _throw() -> void:
	_throw_cd = throw_cooldown
	_bursts = 0
	_hidden_t = 0.0
	var from := global_position + Vector2(-2.0 * facing, -84.0 + _duck * DUCK_DEPTH)
	var offsets: Array[float] = [0.0]
	if phase == 3:
		offsets = [-40.0, 0.0, 40.0]
	for i in offsets.size():
		var to := player.global_position + Vector2(offsets[i] + randf_range(-10.0, 10.0), -6.0)
		# vysoký oblúk (aspoň 0,8 s), aby preletel ponad kraj krídla a nedopadol Louovi pod nohy
		var t: float = clampf(absf(to.x - from.x) / 230.0, 0.8, 1.15)
		var roll := NAN
		var d_r: Vector2 = player.global_position - global_position
		if phase == 1 and d_r.y > 40.0 and absf(d_r.x) < 64.0:
			# Ricco je pod krídlom: dynamit dopadne pred krídlo a po hojdajúcej sa palube sa skotúľa k nemu
			to = Vector2(walk_span.x - 30.0, player.global_position.y - 6.0)
			t = 0.9
			roll = player.global_position.x
		var g: float = DYNAMITE.GRAVITY
		var v := Vector2((to.x - from.x) / t, (to.y - from.y) / t - 0.5 * g * t)
		var d: Node2D = DYNAMITE.new()
		d.velocity = v
		d.roll_to = roll
		d.fuse = DYNAMITE.FUSE + 0.18 * i
		get_tree().current_scene.add_child(d)
		d.global_position = from
	Sfx.play(&"punch_swing", from, -6.0)
	threw.emit()


## Úder pažbou – kto stojí pred ním, odletí (z krídla dole na palubu)
func _bash() -> void:
	_bashed = true
	timer = 0.45
	var tw := create_tween()
	tw.tween_property(self, "aim_angle", _rest_angle() - 0.2 * facing, 0.08)
	var d: Vector2 = player.global_position - global_position
	var reach: float = bash_range + (30.0 if phase == 2 else 10.0)   # z búdky sa nakloní cez plech
	if signf(d.x) == facing and absf(d.x) < reach and absf(d.y) < 44.0 and player.get(&"state") != 3:
		Sfx.play(&"gun_bash", player.global_position, 0.0)
		if player.has_method(&"take_damage"):
			player.take_damage(1, global_position + Vector2(0, -40))
		player.velocity = Vector2(facing * bash_push.x, bash_push.y)
		Burst.spawn(get_tree().current_scene, player.global_position + Vector2(0, -24), Vector2(facing, -0.4), Color(1, 0.9, 0.5), 7, 90.0)


# ---------------------------------------------------------------- prechod 1 → 2: zoskok z krídla a beh do búdky

func _to_crane() -> void:
	phase = 2
	invulnerable = true
	shots_left = 0
	laser.visible = false
	_held.visible = false
	_wing_edge = walk_span.x
	walk_span = deck_span
	_set_facing(-1.0)
	aim_angle = _rest_angle()
	rig.rotation = 0.0
	state = State.LEAP
	_seq = 0
	timer = 3.0
	_stage(&"to_crane")


func _leap() -> void:
	match _seq:
		0:   # k prednému okraju krídla
			velocity.x = -60.0
			if global_position.x <= _wing_edge or timer <= 0.0:
				velocity.x = 0.0
				_seq = 1
				timer = 0.3
				_squish(Vector2(1.12, 0.84), 0.3)
		1:   # prikrčí sa…
			velocity.x = 0.0
			if timer <= 0.0:
				_seq = 2
				velocity = Vector2(-115.0, -170.0)
				_air = false
				Sfx.play(&"punch_swing", global_position + Vector2(0, -50), -2.0, 0.0)
		2:   # …a skok cez zábradlie dole na palubu
			if not is_on_floor():
				_air = true
			elif _air:
				velocity.x = 0.0
				_land_heavy(1.2)
				_seq = 3
				timer = 0.45
				_stage(&"landed")
		3:
			velocity.x = 0.0
			if timer <= 0.0:
				state = State.RUN


# ---------------------------------------------------------------- 2. fáza: žeriav z búdky

func _next_action_crane() -> void:
	var d: Vector2 = player.global_position - global_position
	if absf(d.x) < 72.0 and absf(d.y) < 40.0:
		_start_bash()
		return
	if _in_reach():
		state = State.CRANE
		_crane_mode = Crane.TRACK
		timer = 0.9
		return
	# Ricco je mimo dosahu žeriavu (korma, záchranný čln, za búdkou)
	if _throw_cd <= 0.0 and (_hidden_t > hide_time * 0.6 or not on_screen() or randf() < 0.35):
		state = State.THROW
		timer = 0.45
		return
	if on_screen() or _aggro > 0.0:
		state = State.AIM
		timer = aim_time
		return
	state = State.CRANE
	_crane_mode = Crane.TRACK
	timer = 0.6


func _in_reach() -> bool:
	if crane == null:
		return false
	var r: Vector2 = crane.reach()
	return player.global_position.x > r.x + 16.0 and player.global_position.x < r.y - 16.0


func _crane_tick(delta: float, ricco_ok: bool) -> void:
	if crane == null or not ricco_ok:
		return
	_face_player()
	aim_angle = lerp_angle(aim_angle, _rest_angle() - 0.25 * facing, minf(1.0, 6.0 * delta))
	var d: Vector2 = player.global_position - global_position
	var low: float = 390.0
	var high: float = 760.0
	var speed_k: float = 1.0 + clampf((24.0 - health) / 24.0, 0.0, 0.5)   # menej zdravia = rýchlejší žeriav
	match _crane_mode:
		Crane.TRACK:
			crane.x_speed = 110.0 * speed_k
			crane.rope_target = 98.0
			crane.target_x = clampf(player.global_position.x + player.velocity.x * 0.3, low, high)
			_lever_want = clampf((crane.target_x - crane.tip_x) * 0.02, -0.6, 0.6)
			if absf(d.x) < 72.0 and absf(d.y) < 40.0:
				_start_bash()
				return
			if not _in_reach():
				_out_t += delta
				if _out_t > 0.8:
					_out_t = 0.0
					state = State.COOLDOWN
					timer = 0.2
				return
			_out_t = 0.0
			if timer <= 0.0:
				# tieň na palube, rinčí reťaz… a debna padá
				_crane_mode = Crane.WARN
				timer = 0.75
				crane.show_shadow(true)
				Sfx.play(&"chain_rattle", crane.net_bottom(), -6.0, 0.1)
				_stage(&"crane_drop")
		Crane.WARN:
			_lever_want = 0.5 * sin(_t * 30.0)
			if timer <= 0.0:
				crane.show_shadow(false)
				crane.drop_cargo()
				_lever_want = -0.6
				_drops += 1
				_crane_mode = Crane.DROPPED
				timer = 0.55
		Crane.DROPPED:
			if timer <= 0.0:
				if _drops >= 3:
					# po troch debnách zametie palubu: rameno na vzdialenejší kraj (za Riccom), sieť dole
					_drops = 0
					_crane_mode = Crane.PREP
					var start: float = high if player.global_position.x < (low + high) / 2.0 else low
					_sweep_end = low if start == high else high
					crane.target_x = start
					crane.x_speed = 170.0
				else:
					_crane_mode = Crane.TRACK
					timer = randf_range(0.9, 1.3) / speed_k
		Crane.PREP:
			_lever_want = signf(crane.target_x - crane.tip_x) * 0.6
			if absf(crane.target_x - crane.tip_x) < 4.0:
				_crane_mode = Crane.LOWER
				crane.rope_target = 170.0
				crane.rope_speed = 140.0
				timer = 1.6
				Sfx.play(&"chain_rattle", crane.tip(), -2.0, 0.0)
		Crane.LOWER:
			_lever_want = 0.4
			if crane.settled() and timer <= 0.8:
				_crane_mode = Crane.SWEEP
				crane.lethal = true
				crane.sweep_dir = signf(_sweep_end - crane.tip_x)
				crane.target_x = _sweep_end
				crane.x_speed = 190.0 * minf(speed_k, 1.3)
				_stage(&"crane_sweep")
		Crane.SWEEP:
			_lever_want = crane.sweep_dir * 0.7 * facing
			if absf(crane.target_x - crane.tip_x) < 3.0:
				crane.lethal = false
				crane.rope_target = 98.0
				crane.rope_speed = 110.0
				_crane_mode = Crane.RAISE
		Crane.RAISE:
			_lever_want = -0.4
			if crane.settled():
				_crane_mode = Crane.TRACK
				state = State.COOLDOWN   # medzičasom sa môže rozhodnúť strieľať
				timer = 0.3


## Prechod 2 → 3: Lou zostane v búdke (nezraniteľný), žeriav sa vymkne – blesk a výbuch režíruje level
func _to_burning() -> void:
	phase = 3
	invulnerable = true
	shots_left = 0
	laser.visible = false
	_held.visible = false
	_duck_t = 0.0
	state = State.HOLD
	if crane:
		crane.lethal = false
		crane.show_shadow(false)
		crane.target_x = crane.reach().x
		crane.x_speed = 160.0
		crane.rope_target = 60.0
	_stage(&"lightning")


## Výbuch kabíny ho vyhodí z búdky (volá level). dir_x = kam letí
func blown(dir_x: float) -> void:
	state = State.BLOWN
	invulnerable = true
	_duck_t = 0.0
	velocity = Vector2(dir_x * 140.0, -300.0)
	_air = false
	z_index = 0
	_burn()
	_hurt_t = 1.0
	Sfx.play(&"impact_body", global_position + Vector2(0, -60), 0.0)


func _enter_phase3() -> void:
	phase = 3
	invulnerable = false
	walk_span = deck_span
	z_index = 0
	vest_factor = 0.5          # vesta je po výbuchu potrhaná
	aim_time = 0.5
	cooldown = Vector2(0.6, 1.1)
	burst_turn_speed = 75.0
	burst_count = Vector2i(7, 10)
	_throw_cd = 4.0
	_charge_cd = 2.0
	_bursts = 0


## Rev: dupne dvakrát, päsť k nebu, para z uší – a ide sa na to
func _roar(delta: float) -> void:
	aim_angle = lerp_angle(aim_angle, -PI / 2.0 + 0.5 * facing, minf(1.0, 8.0 * delta))
	if _seq < 2 and timer < 1.0 - 0.45 * _seq:
		_seq += 1
		_squish(Vector2(1.15, 0.84), 0.2)
		Sfx.play(&"body_thud", global_position, 0.0, 0.1)
		_shake(0.25, 3.5, 400.0)
		Burst.spawn(get_tree().current_scene, global_position, Vector2(0, -1), Color(0.7, 0.7, 0.74, 0.6), 10, 70.0, Vector2(0, 30), 0.6)
	if randf() < delta * 14.0:
		var at: Vector2 = head.global_position + Vector2(randf_range(-4.0, 4.0) * facing, -18.0)
		Burst.spawn(get_tree().current_scene, at, Vector2(randf_range(-1.0, 1.0), -1.0), Color(0.85, 0.85, 0.9, 0.55), 2, 40.0, Vector2(0, -40), 0.6)
	if timer <= 0.0:
		_enter_phase3()
		active = true
		state = State.COOLDOWN
		timer = 0.3


# ---------------------------------------------------------------- 3. fáza: na palube

func _next_action_deck() -> void:
	var d: Vector2 = player.global_position - global_position
	var dist: float = absf(d.x)
	if dist < 64.0 and absf(d.y) < 40.0:
		_start_bash()
		return
	if _bursts >= 3:
		state = State.RELOAD
		timer = 1.8
		_seq = 0
		return
	if _charge_cd <= 0.0 and dist > 90.0 and dist < 320.0 and absf(d.y) < 30.0:
		_charge_cd = charge_cooldown
		state = State.WINDUP
		timer = 0.6
		_seq = 0
		_stage(&"charge")
		return
	if _throw_cd <= 0.0 and dist > 110.0 and (randf() < 0.5 or _hidden_t > hide_time):
		state = State.THROW
		timer = 0.45
		return
	if dist < 280.0 and _has_los() and (on_screen() or _aggro > 0.0):
		state = State.AIM
		timer = aim_time
		return
	# ide za ním
	_walk_to = clampf(player.global_position.x - signf(d.x) * 110.0, walk_span.x + 4.0, walk_span.y - 4.0)
	state = State.WALK
	timer = 1.4


func _charge(delta: float) -> void:
	_charge_t += delta
	velocity.x = move_toward(velocity.x, facing * charge_speed, 900.0 * delta)
	if randf() < delta * 12.0:
		Burst.spawn(get_tree().current_scene, global_position + Vector2(-facing * 10.0, -2), Vector2(-facing, -0.3),
				Color(0.7, 0.7, 0.74, 0.5), 2, 40.0, Vector2(0, 20), 0.4)
	if player and player.get(&"state") != 3:
		var d: Vector2 = player.global_position - global_position
		# Ricco po bruchu prejde popod (medzi nohami), inak ho zrazí
		if not _charge_hit and absf(d.x - 4.0 * facing) < 24.0 and d.y > -74.0 and d.y < 10.0 and player.get(&"state") != 4:
			_charge_hit = true
			player.take_damage(2, global_position + Vector2(0, -40))
			player.velocity = Vector2(facing * 330.0, -210.0)
			Sfx.play(&"gun_bash", player.global_position, 2.0, 0.1)
			Burst.spawn(get_tree().current_scene, player.global_position + Vector2(0, -24), Vector2(facing, -0.4), Color(1, 0.9, 0.5), 10, 120.0)
			_shake(0.25, 4.0, 400.0)
		var past: float = -d.x * facing   # o koľko ho už prebehol
		if (past > 70.0 and _charge_t > 0.3) or _charge_t > 2.4:
			state = State.COOLDOWN
			timer = 0.7


## Narazil v rozbehu (kajuta, nadstavba, stĺp žeriavu) – omámený, vesta nepomáha
func _crash() -> void:
	velocity = Vector2(-facing * 60.0, -80.0)
	Sfx.play(&"metal_crash", global_position + Vector2(facing * 20.0, -40.0), -2.0, 0.1)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(facing * 22.0, -50.0), Vector2(-facing, -0.5), Color(1, 0.9, 0.5), 12, 140.0)
	_shake(0.35, 5.0, 500.0)
	_dazed(1.8, false)


func _dazed(t: float, fallen: bool) -> void:
	state = State.DAZED
	timer = t
	shots_left = 0
	laser.visible = false
	_held.visible = false
	_fallen = fallen
	_stars.visible = true
	_hurt_t = 0.4
	var tw := create_tween()
	if fallen:
		# podkopnutý – padne na tvár
		velocity.x = facing * 120.0
		tw.tween_property(rig, "rotation", PI / 2.0 * facing, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(rig, "position:y", LIE_FACE, 0.35)
		tw.tween_callback(func(): _land_heavy(0.9))
	else:
		tw.tween_property(rig, "rotation", -0.22 * facing, 0.15)
	_stage(&"dazed")


## Bubon von (mag_out) → zadná ruka po nový za opaskom → dnu (mag_in) → záver (slide_rack)
func _reload() -> void:
	aim_angle = lerp_angle(aim_angle, _rest_angle() - 0.55 * facing, 0.2)
	if _seq == 0 and timer < 1.6:
		_seq = 1
		gun.texture = load(ART + "thompson_nodrum.png")
		Sfx.play(&"mag_out", global_position + Vector2(0, -50), 0.0, 0.05)
		var d := DROP.instantiate()
		d.texture = load(ART + "drum.png")
		d.life = 3.0
		get_tree().current_scene.add_child(d)
		d.global_position = gun.global_position + Vector2(10.0 * facing, 6.0)
		d.velocity = Vector2(facing * 30.0, -60.0)
		d.spin = randf_range(-6.0, 6.0)
		_stage(&"reload")
	elif _seq == 1 and timer < 1.15:
		_seq = 2
		_drum.visible = true
	elif _seq == 2 and timer < 0.65:
		_seq = 3
		_drum.visible = false
		gun.texture = weapon_texture
		Sfx.play(&"mag_in", global_position + Vector2(0, -50), 0.0, 0.05)
	elif _seq == 3 and timer < 0.3:
		_seq = 4
		Sfx.play(&"slide_rack", global_position + Vector2(0, -50), 0.0, 0.05)
	if timer <= 0.0:
		_bursts = 0
		state = State.COOLDOWN
		timer = 0.2


## Debny v ceste rozbije, cez nízke prekážky (päta žeriavu) prekročí; v rozbehu do nich narazí
func _bulldoze() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_collider() as Node
		if absf(c.get_normal().x) < 0.5:
			continue
		if n and n.is_in_group(&"ship_cover") and n.has_method(&"shatter"):
			n.shatter(Vector2(facing, -1.0))
			Sfx.play(&"gun_bash", global_position + Vector2(facing * 20.0, -20.0), -4.0, 0.1)
		elif state == State.CHARGE:
			_crash()
			return
		elif is_on_floor():
			velocity.y = -210.0   # prekročí


# ---------------------------------------------------------------- zásahy

## Zásah guľkou s miestom zásahu (weapons/pistol/bullet.gd): vesta pod sakom chráni trup, hlava a nohy naplno
func take_hit_at(damage: float, dir: Vector2, pos: Vector2) -> void:
	if state == State.DEAD:
		return
	var y: float = pos.y - global_position.y - _duck * DUCK_DEPTH
	if invulnerable or (_duck > 0.5 and pos.y > global_position.y - 64.0):
		# odrazí sa (prechod medzi fázami / skrčený za plechom búdky)
		Burst.spawn(get_tree().current_scene, pos, -dir + Vector2(0, -0.4), Color(1.0, 0.85, 0.45), 4, 90.0)
		Sfx.play(&"ricochet_1", pos, -6.0, 0.15)
		return
	if state == State.DAZED:
		_hurt_t = 0.35
		take_hit(damage, dir)   # omámený – vesta je nakrivo, nepomôže
		return
	if y > NECK.y + 3.0 and y < HIP.y + 4.0:
		Burst.spawn(get_tree().current_scene, pos, -dir + Vector2(0, -0.4), Color(1.0, 0.85, 0.45), 7, 110.0)
		Sfx.play(&"vest_hit", pos, -2.0, 0.1)
		vest_hit.emit()
		take_hit(damage * vest_factor, dir, false)
		return
	if y <= NECK.y + 3.0:
		_hurt_t = 0.35   # trafil hlavu – zaťaté zuby
		if phase == 2:
			_head_hit()
	take_hit(damage, dir)


## V búdke: tri rýchle zásahy do hlavy → skrčí sa za plech
func _head_hit() -> void:
	_head_hits.append(_t)
	while not _head_hits.is_empty() and _t - _head_hits[0] > 2.5:
		_head_hits.pop_front()
	if _head_hits.size() >= 3 and state == State.CRANE:
		_head_hits.clear()
		_duck_t = 1.5


func take_hit(damage: float, dir: Vector2, blood: bool = true) -> void:
	if state == State.DEAD or _dying or invulnerable:
		return
	health = maxf(health - damage, _phase_floor())
	health_changed.emit(health, max_health)
	if blood:
		Sfx.play(&"impact_body", global_position + Vector2(0, -60), -2.0)
		Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -64 + _duck * DUCK_DEPTH), dir + Vector2(0, -0.3),
				Color(0.62, 0.05, 0.05), 7, 90.0, Vector2(0, 520), 0.5)
	rig.modulate = Color(3, 3, 3)
	create_tween().tween_property(rig, "modulate", Color.WHITE, 0.12)
	_aggro = 4.0
	if not active and phase == 1:
		start(false)   # vystrelil skôr, ako sa boj začal
	if health <= _phase_floor():
		match phase:
			1:
				_to_crane()
			2:
				_to_burning()
			3:
				_die()


## Výbuch suda / dynamitu (effects/explosion.gd)
func blast_hit(damage: float, dir: Vector2) -> void:
	if invulnerable or _dying or state == State.DEAD:
		return
	_hurt_t = 0.5
	take_hit(damage, dir, false)
	if not _dying and phase == 3 and state != State.CHARGE and state != State.DAZED and state != State.GETUP:
		_stagger(0.6, signf(dir.x))


## Debna zo siete mu spadla na hlavu (Ricco ho nalákal pod sieť)
func cargo_hit(damage: float) -> void:
	if invulnerable or _dying:
		return
	Sfx.play(&"hat_bonk", global_position + Vector2(0, -90), 2.0)
	_hurt_t = 0.6
	_duck_t = 1.0
	take_hit(damage, Vector2.DOWN, false)


## Riccov klobúk: zhodí mu fedoru a zarazí ho
func hat_hit(damage: int, dir: Vector2) -> void:
	if state == State.DEAD or _dying:
		return
	Sfx.play(&"hat_bonk", global_position + Vector2(0, -90))
	if invulnerable:
		return
	_knock_hat(dir)
	take_hit(damage, dir, false)
	if not _dying and phase != 2 and (state == State.COOLDOWN or state == State.AIM or state == State.BURST or state == State.WALK):
		_stagger(0.7, signf(dir.x))


## Šmyk po bruchu do neho – je priťažký na zvalenie, len sa zapotáca. V rozbehu ho však podkopne (padne na tvár)!
func trip(dir: float) -> bool:
	if state == State.DEAD or _dying or invulnerable:
		return false
	if state == State.CHARGE:
		Sfx.play(&"punch_hit", global_position + Vector2(0, -20), 0.0)
		_dazed(2.2, true)
		return true
	if state == State.STAGGER or state == State.DAZED or state == State.GETUP or phase == 2:
		return false
	Sfx.play(&"punch_hit", global_position + Vector2(0, -20), -6.0)
	_stagger(0.6, dir)
	return true


func can_takedown(_from_x: float) -> bool:
	return false


func takedown(_dir: Vector2) -> void:
	pass


func _stagger(t: float, dir: float) -> void:
	state = State.STAGGER
	timer = t
	shots_left = 0
	_held.visible = false
	_drum.visible = false
	gun.texture = weapon_texture
	laser.visible = false
	velocity.x = dir * 40.0
	rig.rotation = 0.08 * dir
	_hurt_t = t * 0.6


func _knock_hat(dir: Vector2) -> void:
	if not hat.visible:
		return
	hat.visible = false
	var d := DROP.instantiate()
	d.texture = hat.texture
	d.life = 4.0
	get_tree().current_scene.add_child(d)
	d.global_position = hat.global_position + Vector2(-PIVOT_HAT.x * facing, -PIVOT_HAT.y + 8.0)
	d.velocity = Vector2(dir.x * 70.0, -190.0)
	d.spin = randf_range(-9.0, 9.0)


func _stage(n: StringName) -> void:
	stage.emit(n)


# ---------------------------------------------------------------- smrť

## Posledná dávka do neba, kolená, tvár… a zapálený dynamit zo saka
func _die() -> void:
	if _dying:
		return
	_dying = true
	state = State.DEAD
	active = false
	invulnerable = true
	laser.visible = false
	_held.visible = false
	_drum.visible = false
	_stars.visible = false
	_duck_t = 0.0
	gun.texture = weapon_texture
	collision_layer = 0   # guľky ním preletia
	velocity.x = 0.0
	_hurt_t = 99.0
	_stage(&"dying")
	Sfx.play(&"enemy_death", global_position, 0.0)
	var fall: float = facing
	var tree := get_tree()
	# zapotáca sa dozadu
	var tw := create_tween()
	tw.tween_property(rig, "rotation", -0.18 * facing, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	# posledná dávka do neba
	var up: float = -PI / 2.0 - 0.25 * facing
	var tw2 := create_tween()
	tw2.tween_property(self, "aim_angle", up, 0.2)
	await tw2.finished
	for i in 7:
		aim_angle = up + randf_range(-0.12, 0.12)
		_fire()
		await tree.create_timer(0.08, false).timeout
	await tree.create_timer(0.35, false).timeout
	# Thompson vyletí z ruky – Ricco si ho môže zobrať
	var p := WEAPON_PICKUP.new()
	p.weapon = weapon
	p.ammo = weapon.mag_size
	p.texture = gun.texture
	p.velocity = Vector2(-facing * 90.0, -200.0)
	p.spin = randf_range(-8.0, 8.0)
	tree.current_scene.add_child(p)
	p.global_position = gun.global_position
	gun.visible = false
	hand.visible = false
	# na kolená
	var tw3 := create_tween()
	tw3.tween_property(rig, "position:y", 18.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw3.parallel().tween_property(leg_front, "rotation", -1.35, 0.25)
	tw3.parallel().tween_property(leg_back, "rotation", -1.2, 0.25)
	tw3.parallel().tween_property(rig, "rotation", 0.0, 0.25)
	tw3.parallel().tween_property(arm_front, "rotation", 1.3, 0.3)
	tw3.parallel().tween_property(arm_back, "rotation", 1.4, 0.3)
	tw3.tween_callback(func():
		Sfx.play(&"land", global_position, 2.0)
		_squish(Vector2(1.08, 0.92)))
	await tw3.finished
	await tree.create_timer(0.7, false).timeout
	# na tvár
	var tw4 := create_tween()
	tw4.tween_property(rig, "rotation", PI / 2.0 * fall, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw4.parallel().tween_property(rig, "position:y", LIE_FACE, 0.45)
	tw4.parallel().tween_property(leg_front, "rotation", 0.0, 0.45)
	tw4.parallel().tween_property(leg_back, "rotation", 0.1, 0.45)
	tw4.parallel().tween_property(head, "rotation", -0.3, 0.45)
	await tw4.finished
	_knock_hat(Vector2(fall, -1))
	_land_heavy(1.1)
	await tree.create_timer(0.6, false).timeout
	# zo saka sa vykotúľa zapálený dynamit…
	var dyn: Node2D = DYNAMITE.new()
	dyn.velocity = Vector2(-fall * 50.0, -40.0)
	dyn.fuse = 1.9
	dyn.damage = 0
	dyn.size = 2.2
	tree.current_scene.add_child(dyn)
	dyn.global_position = global_position + Vector2(fall * 30.0, -12.0)
	dyn.tree_exiting.connect(_vanish, CONNECT_DEFERRED)


## …bum. Z Lou ostane len klobúk, ktorý sa pomaly znesie na palubu.
func _vanish() -> void:
	rig.visible = false
	var scene := get_tree().current_scene
	Burst.spawn(scene, global_position + Vector2(facing * 30.0, -10), Vector2(0, -1), Color(0.25, 0.23, 0.24, 0.6), 20, 50.0, Vector2(0, -30), 2.5)
	var h := Sprite2D.new()
	h.texture = hat.texture
	h.z_index = 3
	scene.add_child.call_deferred(h)
	var x0: float = global_position.x + facing * 26.0
	var y0: float = global_position.y
	h.position = Vector2(x0, y0 - 170.0)   # current_scene je v počiatku
	var tw := create_tween()
	tw.tween_interval(0.5)
	for i in 4:   # kolíše sa zo strany na stranu ako list
		var side: float = 1.0 if i % 2 == 0 else -1.0
		tw.tween_property(h, "position", Vector2(x0 + side * 14.0, y0 - 130.0 + i * 32.0), 0.7).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(h, "rotation", side * 0.35, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(h, "position", Vector2(x0, y0 - 6.0), 0.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(h, "rotation", 0.0, 0.4)
	tw.tween_callback(func(): Sfx.play(&"hat_catch", h.global_position, -6.0, 0.05))
	died.emit()


# ---------------------------------------------------------------- pohyb častí tela

func _animate(delta: float) -> void:
	if state == State.DEAD:
		return
	var moving: bool = absf(velocity.x) > 4.0 and is_on_floor()
	var fast: bool = absf(velocity.x) > 60.0
	if moving:
		_walk_phase += absf(velocity.x) * delta / (11.0 if fast else 8.0)
	else:
		_walk_phase = lerpf(_walk_phase, roundf(_walk_phase / PI) * PI, minf(1.0, 10.0 * delta))
	var swing: float = sin(_walk_phase) * (0.55 if fast else 0.3)
	leg_front.rotation = swing
	leg_back.rotation = -swing
	if not is_on_floor() and (state == State.LEAP or state == State.HOP_IN or state == State.BLOWN):
		leg_front.rotation = -0.5   # nohy pokrčené vo vzduchu
		leg_back.rotation = 0.45
	# skrčenie v búdke
	_duck = move_toward(_duck, 1.0 if _duck_t > 0.0 else 0.0, delta * 6.0)
	if state != State.BLOWN and state != State.LIE and state != State.GETUP and state != State.DAZED:
		rig.position.y = _duck * DUCK_DEPTH
	# predklon v behu / rozbehu, záklon pred rozbehom
	if state == State.RUN or state == State.CHARGE:
		rig.rotation = lerpf(rig.rotation, (0.2 if state == State.CHARGE else 0.1) * facing, minf(1.0, 10.0 * delta))
	elif state == State.WINDUP:
		rig.rotation = lerpf(rig.rotation, -0.08 * facing, minf(1.0, 10.0 * delta))
	elif state == State.COOLDOWN or state == State.WALK or state == State.AIM or state == State.BURST or state == State.CRANE:
		rig.rotation = lerpf(rig.rotation, 0.0, minf(1.0, 10.0 * delta))
	# dýchanie (veľké brucho) a krok; smiech – ramená poskakujú
	var breath: float = roundf(sin(_t * 3.0) * 0.6)
	if state == State.LAUGH:
		breath = roundf(absf(sin(_t * 26.0)) * -2.0)
	elif state == State.ROAR or state == State.WINDUP:
		breath = roundf(sin(_t * 30.0))
	var bob: float = -absf(sin(_walk_phase)) * (2.0 if fast else 1.0) + breath
	torso.position.y = HIP.y + bob
	head.position.y = NECK.y + bob
	hat.position.y = HAT_AT.y + bob
	arm_front.position.y = SHOULDER_FRONT.y + bob
	arm_back.position.y = SHOULDER_BACK.y + bob
	match state:
		State.STAGGER, State.DAZED:
			head.rotation = sin(_t * 20.0) * 0.15
		State.LAUGH:
			head.rotation = -0.3 + sin(_t * 26.0) * 0.06   # hlavu dozadu, chechtá sa
		State.ROAR:
			head.rotation = lerpf(head.rotation, -0.4, minf(1.0, 10.0 * delta))
		State.WINDUP, State.CHARGE:
			head.rotation = lerpf(head.rotation, 0.25, minf(1.0, 10.0 * delta))   # hlavu dole ako býk
		_:
			head.rotation = lerpf(head.rotation, 0.0, minf(1.0, 12.0 * delta))
	hat.rotation = head.rotation * 0.8
	arm_front.rotation = _arm_rot(aim_angle)
	match state:
		State.THROW, State.ROAR:
			# zadná ruka sa napriahne s dynamitom za hlavu / v reve päsť k nebu
			arm_back.rotation = lerp_angle(arm_back.rotation, -2.4, minf(1.0, 12.0 * delta))
		State.LEAP, State.HOP_IN, State.BLOWN, State.LIE:
			arm_back.rotation = lerp_angle(arm_back.rotation, -1.6, minf(1.0, 10.0 * delta))
		State.LAUGH:
			arm_back.rotation = lerp_angle(arm_back.rotation, 0.9 + sin(_t * 26.0) * 0.15, minf(1.0, 12.0 * delta))   # drží sa za brucho
		State.RELOAD:
			var want: float = 1.4 if _seq < 2 else -0.2   # po nový bubon za opasok, potom k zbrani
			arm_back.rotation = lerp_angle(arm_back.rotation, want, minf(1.0, 10.0 * delta))
		State.CRANE, State.HOLD:
			_pull_lever(delta)
		_:
			var fg: Vector2 = gun.to_global(weapon.foregrip_px + Vector2(1, 2))
			var sb: Vector2 = arm_back.global_position
			arm_back.rotation = _arm_rot((fg - sb).angle())
	# hviezdičky krúžia nad hlavou
	if _stars.visible:
		var c: Vector2 = head.global_position - global_position + Vector2(0, -40).rotated(rig.rotation)
		var k: int = 0
		for s in _stars.get_children():
			var a: float = _t * 6.0 + k * TAU / 3.0
			(s as Node2D).position = (c + Vector2(cos(a) * 14.0, sin(a) * 4.0)).round()
			(s as CanvasItem).z_index = 1 if sin(a) > 0.0 else -1
			k += 1


## Zadná ruka na páke žeriavu, páka sa kýve podľa toho, kam Lou rameno ťahá
func _pull_lever(delta: float) -> void:
	if lever == null:
		return
	lever.rotation = lerpf(lever.rotation, _lever_want, minf(1.0, 12.0 * delta))
	var top: Vector2 = lever.global_position + Vector2(0, -14).rotated(lever.rotation)
	var sb: Vector2 = arm_back.global_position
	arm_back.rotation = _arm_rot((top - sb).angle())
