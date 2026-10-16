class_name Gangster
extends CharacterBody2D
## Nepriateľ – gangster (človek). Telo je poskladané z častí (cutout animácia, Godot docs:
## tutorials/animation/cutout_animation): nohy, trup, hlava, klobúk, dve ruky. Kód ich hýbe sám:
## nohy sa pri chôdzi kývu, predná ruka so zbraňou mieri presne na Ricca, zadná drží predok zbrane.
##
## Správanie (jednoduchý stavový automat):
##   hliadka → zbadá Ricca (lúč bez steny, dosah, pozerá sa jeho smerom)
##   strelec: mieri (červená čiara – čas uskočiť / šmyknúť sa) → dávka → pauza → znova
##   bitkár:  beží k Riccovi → napriahne sa → úder → oddych
##   zásah: biely záblesk, krv, krátke zakolísanie; klobúk od Ricca ho omráči a zhodí mu klobúk
##   smrť: padne na chrbát, zbraň a klobúk odletia, vypadne krabička nábojov; v test room sa po chvíli objaví znova
## Spomalenie času (Engine.time_scale) spomalí aj jeho a jeho guľky – netreba nič riešiť.

enum State { PATROL, IDLE, AIM, SHOOT, COOLDOWN, CHASE, WINDUP, PUNCH, RECOVER, STUN, DEAD }

@export var kind: String = "tommy"                ## priečinok s časťami tela (characters/gangster/<kind>/)
@export var weapon: WeaponData                    ## zbraň (obrázok, ústie); null = bije päsťami
@export var weapon_texture: Texture2D             ## iný obrázok zbrane (napr. Tommy aj s bubnom)
@export var max_health: int = 3

@export_group("Movement")
@export var walk_speed: float = 35.0
@export var run_speed: float = 0.0                ## > 0 = beží k Riccovi (bitkár)
@export var patrol_time: Vector2 = Vector2(2.0, 4.0)   ## ako dlho ide, kým sa zastaví (náhodne od–do)

@export_group("Shooting")
@export var sight_range: float = 300.0
@export var aim_time: float = 0.7                 ## s mierenia s červenou čiarou pred dávkou
@export var aim_turn_speed: float = 140.0         ## °/s – ako rýchlo sa zbraň otáča za Riccom (dá sa uhnúť)
@export var burst_count: int = 1
@export var burst_interval: float = 0.1
@export var pellets: int = 1
@export var spread_deg: float = 3.0
@export var bullet_speed: float = 380.0           ## pomalšie ako Riccove, aby sa dali preskočiť
@export var bullet_lifetime: float = 1.4
@export var cooldown: Vector2 = Vector2(0.9, 1.4)
@export var preferred_range: float = 0.0          ## > 0 = najprv sa priblíži na túto vzdialenosť (lupara)

@export_group("Melee")
@export var punch_range: float = 30.0
@export var windup_time: float = 0.35
@export var recover_time: float = 0.6

@export_group("Stealth")
@export_range(-1.0, 1.0, 2.0) var start_facing: float = -1.0   ## -1 = doľava, 1 = doprava
@export var needs_light: bool = false             ## v tme (mimo LightZone) Ricca nevidí – okrem tesnej blízkosti
@export var close_sense: float = 34.0             ## px vodorovne – takto blízko (na tej istej úrovni) Ricca vycíti aj v tme / za chrbtom
@export var stationary: bool = false              ## stojí na mieste (napr. kuchár pri pulte) namiesto hliadky
@export var look_back: Vector2 = Vector2.ZERO     ## s – občas sa obzrie dozadu (od–do); 0 = nikdy
@export var patrol_span: float = 0.0              ## px – hliadkuje len ±toľko od miesta, kde začal (0 = kým nenarazí)
@export var flashlight: bool = false              ## svieti si baterkou pred seba – v kuželi Ricca vidno (pivnica)
@export var passive: bool = false                 ## Ricca si nevšíma (napr. vyhadzovač pred pizzeriou) – kým ho Ricco nezasiahne

@export_group("Test room")
@export var respawn_time: float = 6.0             ## s po smrti, kým sa objaví znova (0 = nikdy)

const BULLET := preload("res://weapons/pistol/bullet.tscn")
const DROP := preload("res://weapons/pistol/magazine_drop.tscn")
const AMMO := preload("res://props/ammo/ammo_pickup.tscn")
const FLASH := preload("res://weapons/pistol/muzzle_flash.png")

## Spoločné body kostry (nohy na y = 0, pozerá sa doprava)
const HIP := Vector2(0, -28)
const LEG_FRONT := Vector2(-1, -28)
const LEG_BACK := Vector2(3, -28)
const NECK := Vector2(1, -52)
const HAT_AT := Vector2(1, -65)
const SHOULDER_FRONT := Vector2(2, -48)
const SHOULDER_BACK := Vector2(-2, -48)
const EYE := Vector2(4, -62)
## Pivoty v obrázkoch častí (gangster_parts.py) – rovnaké pre všetkých, trup a klobúk podľa typu
const PIVOT_LEG := Vector2(4, 1)
const PIVOT_HEAD := Vector2(7, 19)
const PIVOT_ARM := Vector2(4, 4)
const ARM_GRIP := Vector2(20, 3)
const RIGS := {
	"tommy": {"torso": Vector2(11, 26), "hat": Vector2(13, 10)},
	"coppola": {"torso": Vector2(11, 26), "hat": Vector2(8, 8)},
	"bruiser": {"torso": Vector2(14, 27)},
}

var state: State = State.PATROL
var health: int
var facing: float = -1.0
var walk_dir: float = -1.0
var timer: float = 0.0
var shots_left: int = 0
var aim_angle: float = PI           ## globálny uhol zbrane
var walk_phase: float = 0.0
var lost_sight: float = 0.0
var home_facing: float = -1.0
var look_timer: float = 0.0
var _alert_mark: Label
var goto_x: float = NAN   ## px – skriptovaný presun (napr. mafián ide zaklopať na dvere); NAN = normálne správanie
var _aggro: float = 0.0   ## s – po zásahu klobúkom vie, kde Ricco je (vidí ho aj v tme a za chrbtom)
var spawn_pos: Vector2
var player: Node2D

var rig: Node2D
var leg_front: Node2D
var leg_back: Node2D
var torso: Node2D
var head: Node2D
var hat: Sprite2D
var arm_front: Node2D
var arm_back: Node2D
var gun: Sprite2D
var muzzle: Marker2D
var flash: Sprite2D
var laser: Line2D
var _flash_t: float = 0.0


func _ready() -> void:
	health = max_health
	spawn_pos = global_position
	collision_layer = 4    # enemies
	collision_mask = 1     # world
	add_to_group(&"enemies")
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 9.0
	cap.height = 66.0
	shape.shape = cap
	shape.position = Vector2(0, -33)
	add_child(shape)
	_build_rig()
	if flashlight:
		_make_flashlight()
	_set_facing(start_facing if start_facing != 0.0 else facing)
	home_facing = facing
	walk_dir = facing
	look_timer = randf_range(look_back.x, look_back.y)
	timer = randf_range(patrol_time.x, patrol_time.y)


# ---------------------------------------------------------------- telo z častí

func _part(parent: Node, file: String, pivot: Vector2, at: Vector2) -> Node2D:
	var holder := Node2D.new()
	holder.position = at
	parent.add_child(holder)
	var path := "res://characters/gangster/%s/%s.png" % [kind, file]
	if ResourceLoader.exists(path):
		var s := Sprite2D.new()
		s.texture = load(path)
		s.centered = false
		s.offset = -pivot
		holder.add_child(s)
	return holder


func _build_rig() -> void:
	var r: Dictionary = RIGS.get(kind, RIGS["tommy"])
	rig = Node2D.new()
	add_child(rig)
	arm_back = _part(rig, "arm_back", PIVOT_ARM, SHOULDER_BACK)
	leg_back = _part(rig, "leg_back", PIVOT_LEG, LEG_BACK)
	leg_front = _part(rig, "leg", PIVOT_LEG, LEG_FRONT)
	torso = _part(rig, "torso", r["torso"], HIP)
	head = _part(rig, "head", PIVOT_HEAD, NECK)
	if r.has("hat"):
		hat = Sprite2D.new()
		hat.texture = load("res://characters/gangster/%s/hat.png" % kind)
		hat.centered = false
		hat.offset = -r["hat"]
		hat.position = HAT_AT
		rig.add_child(hat)
	arm_front = _part(rig, "arm", PIVOT_ARM, SHOULDER_FRONT)
	muzzle = Marker2D.new()
	if weapon:
		gun = Sprite2D.new()
		gun.texture = weapon_texture if weapon_texture else weapon.texture
		gun.centered = false
		gun.position = ARM_GRIP - PIVOT_ARM - weapon.grip_px
		arm_front.add_child(gun)
		# ruka nad rukoväťou (aby ju „zvierala“)
		var hand := Sprite2D.new()
		hand.texture = load("res://characters/gangster/%s/arm.png" % kind)
		hand.centered = false
		hand.region_enabled = true
		hand.region_rect = Rect2(ARM_GRIP.x - 2, 0, hand.texture.get_width() - ARM_GRIP.x + 2, hand.texture.get_height())
		hand.position = Vector2(ARM_GRIP.x - 2, 0) - PIVOT_ARM
		arm_front.add_child(hand)
		muzzle.position = gun.position + weapon.muzzle_px
	else:
		muzzle.position = ARM_GRIP - PIVOT_ARM + Vector2(3, 0)
	arm_front.add_child(muzzle)
	flash = Sprite2D.new()
	flash.texture = FLASH
	flash.position = Vector2(4, 0)
	flash.visible = false
	muzzle.add_child(flash)
	laser = Line2D.new()
	laser.width = 1.0
	laser.default_color = Color(1.0, 0.15, 0.1, 0.55)
	laser.visible = false
	laser.top_level = true   # body v globálnych súradniciach
	add_child(laser)


func _set_facing(f: float) -> void:
	facing = f
	rig.scale.x = f


var _flash: Node2D

## Baterka: kužeľ svetla pred ním (je v kostre, takže sa otáča s ním) + LightZone v kuželi
func _make_flashlight() -> void:
	_flash = Node2D.new()
	_flash.name = "Flashlight"
	_flash.position = Vector2(10, -44)
	rig.add_child(_flash)
	var cone := Sprite2D.new()
	cone.texture = preload("res://levels/level1/art/flashlight_cone.png")
	cone.centered = false
	cone.position = Vector2(0, -24)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cone.material = m
	cone.z_index = 4
	_flash.add_child(cone)
	var zone := Area2D.new()
	zone.set_script(preload("res://world/stealth/light_zone.gd"))
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(120, 44)
	cs.shape = rs
	cs.position = Vector2(64, 12)
	zone.add_child(cs)
	_flash.add_child(zone)


## Globálny uhol → rotácia ruky v (prípadne zrkadlenej) kostre
func _arm_rot(global_angle: float) -> float:
	return global_angle if facing > 0.0 else wrapf(PI - global_angle, -PI, PI)


# ---------------------------------------------------------------- hlavná slučka

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	timer -= delta
	_aggro -= delta
	_flash_t -= delta
	flash.visible = _flash_t > 0.0
	if player == null:
		move_and_slide()
		return
	var sees: bool = state != State.DEAD and _can_see_player()

	match state:
		State.PATROL:
			_patrol(delta)
			if sees: _alert()
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if sees: _alert()
			elif timer <= 0.0:
				state = State.PATROL
				timer = randf_range(patrol_time.x, patrol_time.y)
		State.AIM:
			_face_player()
			if preferred_range > 0.0 and _player_dist() > preferred_range + 20.0 and _ledge_ok(facing):
				velocity.x = facing * walk_speed * 1.4   # lupara: najprv sa priblíži
				timer = maxf(timer, aim_time * 0.6)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
				if timer <= 0.0:
					state = State.SHOOT
					shots_left = burst_count
					timer = 0.0
			_track_aim(delta)
			_update_laser(true)
			if not sees: _lose_sight(delta)
			else: lost_sight = 0.0
		State.SHOOT:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			_track_aim(delta)
			_update_laser(false)
			if timer <= 0.0 and shots_left > 0:
				_fire()
				shots_left -= 1
				timer = burst_interval
			elif shots_left <= 0 and timer <= 0.0:
				state = State.COOLDOWN
				timer = randf_range(cooldown.x, cooldown.y)
		State.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			_face_player()
			_track_aim(delta)
			if timer <= 0.0:
				if sees: _start_aim()
				else:
					state = State.PATROL
					timer = randf_range(patrol_time.x, patrol_time.y)
		State.CHASE:
			_face_player()
			var dx: float = player.global_position.x - global_position.x
			if absf(dx) < punch_range and absf(player.global_position.y - global_position.y) < 40.0:
				velocity.x = 0.0
				state = State.WINDUP
				timer = windup_time
			elif _ledge_ok(signf(dx)):
				velocity.x = signf(dx) * run_speed
			else:
				velocity.x = 0.0
			if not sees: _lose_sight(delta)
			else: lost_sight = 0.0
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if timer <= 0.0:
				state = State.PUNCH
				timer = 0.12
				_punch()
		State.PUNCH:
			if timer <= 0.0:
				state = State.RECOVER
				timer = recover_time
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if timer <= 0.0:
				if sees: state = State.CHASE
				else:
					state = State.PATROL
					timer = randf_range(patrol_time.x, patrol_time.y)
		State.STUN:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			if timer <= 0.0:
				if sees: _alert()
				else: state = State.IDLE
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)

	if state not in [State.AIM]:
		laser.visible = false
	move_and_slide()
	_animate(delta)


func _alert() -> void:
	if state in [State.PATROL, State.IDLE, State.STUN]:
		_show_alert_mark()
	_face_player()
	if run_speed > 0.0:
		state = State.CHASE
	else:
		_start_aim()
	lost_sight = 0.0


## „!“ nad hlavou, keď si Ricca všimne
## Poplach (napr. hosť zvrieskol): na chvíľu vie, kde je Ricco, aj keď je v tme
func alarm() -> void:
	if state == State.DEAD or passive:
		return
	_aggro = maxf(_aggro, 8.0)
	if state in [State.PATROL, State.IDLE]:
		_show_alert_mark()


func _show_alert_mark() -> void:
	if _alert_mark == null:
		_alert_mark = Label.new()
		_alert_mark.text = "!"
		_alert_mark.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
		_alert_mark.add_theme_font_size_override(&"font_size", 16)
		_alert_mark.add_theme_color_override(&"font_color", Color8(255, 214, 90))
		_alert_mark.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
		_alert_mark.add_theme_constant_override(&"outline_size", 4)
		_alert_mark.position = Vector2(-3, -96)
		_alert_mark.z_index = 30
		add_child(_alert_mark)
	_alert_mark.visible = true
	_alert_mark.modulate.a = 1.0
	_alert_mark.position.y = -92.0
	var tw := create_tween()
	tw.tween_property(_alert_mark, "position:y", -100.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(_alert_mark, "modulate:a", 0.0, 0.25)


func _start_aim() -> void:
	state = State.AIM
	timer = aim_time


func _lose_sight(delta: float) -> void:
	lost_sight += delta
	if lost_sight > 1.5:
		state = State.IDLE
		timer = 1.0


func _patrol(delta: float) -> void:
	if not is_nan(goto_x):
		var gdx: float = goto_x - global_position.x
		if absf(gdx) < 4.0:
			velocity.x = 0.0
			goto_x = NAN
			stationary = true
			home_facing = facing
			return
		_set_facing(signf(gdx))
		velocity.x = signf(gdx) * walk_speed
		return
	if stationary:
		_stand(delta)
		return
	if is_on_wall() or not _ledge_ok(walk_dir):
		walk_dir = -walk_dir
	elif patrol_span > 0.0 and (global_position.x - spawn_pos.x) * walk_dir > patrol_span:
		walk_dir = -walk_dir
	_set_facing(walk_dir)
	velocity.x = walk_dir * walk_speed
	var low: float = 0.6 if facing > 0.0 else PI - 0.6   # zbraň šikmo dole pred sebou
	aim_angle = lerp_angle(aim_angle, low, minf(1.0, 6.0 * delta))
	if timer <= 0.0:
		state = State.IDLE
		timer = randf_range(0.8, 1.6)
		if randf() < 0.5:
			walk_dir = -walk_dir


## Stojí na mieste otočený „domov“; ak má look_back, občas sa na chvíľu obzrie dozadu.
func _stand(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	var low: float = 0.6 if facing > 0.0 else PI - 0.6
	aim_angle = lerp_angle(aim_angle, low, minf(1.0, 6.0 * delta))
	if look_back == Vector2.ZERO:
		if facing != home_facing:
			_set_facing(home_facing)
		return
	look_timer -= delta
	if look_timer <= 0.0:
		if facing == home_facing:
			_set_facing(-home_facing)      # obzrie sa
			look_timer = 1.6
		else:
			_set_facing(home_facing)
			look_timer = randf_range(look_back.x, look_back.y)


## Je pred ním zem? (lúč dole kúsok pred nohami) – aby nespadol z plošiny
func _ledge_ok(dir: float) -> bool:
	if not is_on_floor():
		return true
	var from := global_position + Vector2(dir * 14.0, -4.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 14), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _player_target() -> Vector2:
	# hruď/hlava Ricca; pri šmyku je nižšie
	var h: float = 12.0 if player.get("state") == 4 else 26.0
	return player.global_position + Vector2(0, -h)


func _player_dist() -> float:
	return global_position.distance_to(player.global_position)


func _can_see_player() -> bool:
	if player == null or player.get("state") == 3 or passive:   # Ricco mŕtvy / nevšíma si ho
		return false
	if not _on_screen():
		return false   # nestrieľa spoza obrazovky – hráč ho musí vidieť
	var eye := global_position + Vector2(EYE.x * facing, EYE.y)
	var target := _player_target()
	var d: float = eye.distance_to(target)
	if d > sight_range:
		return false
	var dx: float = target.x - global_position.x
	var alerted: bool = state in [State.AIM, State.SHOOT, State.COOLDOWN, State.CHASE, State.WINDUP, State.RECOVER]
	if _aggro > 0.0:
		pass   # nahnevaný (po klobúku) – vie, kde Ricco je
	elif needs_light:
		# zakrádanie: za chrbtom ani v tme nevidí – len keď je Ricco celkom blízko (počuje ho)
		var lit: bool = player.has_method(&"is_lit") and player.is_lit()
		var sense: float = close_sense * (0.45 if player.get(&"sneaking") else 1.0)   # prikrčeného zacíti len celkom zblízka
		var near: bool = absf(dx) < sense and absf(player.global_position.y - global_position.y) < 40.0   # tesne vedľa, na tej istej úrovni
		if not alerted and signf(dx) != facing and not near:
			return false
		if not lit and not near and not (alerted and d < 110.0):
			return false
	elif not alerted and signf(dx) != facing and absf(dx) > 40.0:
		return false   # nevidí za seba
	var q := PhysicsRayQueryParameters2D.create(eye, target, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Je gangster na obrazovke? (Godot docs: CanvasItem.get_global_transform_with_canvas – poloha v okne hry)
func _on_screen() -> bool:
	var p: Vector2 = get_global_transform_with_canvas().origin + Vector2(0, -40)
	var r: Rect2 = get_viewport_rect().grow(-12.0)
	return r.has_point(p)


func _face_player() -> void:
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 2.0 and signf(dx) != facing:
		_set_facing(signf(dx))
		aim_angle = PI - aim_angle   # zbraň ostane namierená rovnako vzhľadom na telo


func _track_aim(delta: float) -> void:
	var shoulder := global_position + Vector2(SHOULDER_FRONT.x * facing, SHOULDER_FRONT.y)
	var want: float = (_player_target() - shoulder).angle()
	var step: float = deg_to_rad(aim_turn_speed) * delta
	aim_angle = aim_angle + clampf(angle_difference(aim_angle, want), -step, step)


func _update_laser(on: bool) -> void:
	laser.visible = on and fmod(timer, 0.12) > 0.03   # bliká
	if not laser.visible:
		return
	var from := muzzle.global_position
	var to := from + Vector2.from_angle(aim_angle) * sight_range
	var q := PhysicsRayQueryParameters2D.create(from, to, 1 | 2)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		to = hit.position
	laser.points = PackedVector2Array([from, to])


func _fire() -> void:
	for i in pellets:
		var b := BULLET.instantiate()
		var a: float = randf_range(-spread_deg, spread_deg) if pellets == 1 \
				else lerpf(-spread_deg / 2.0, spread_deg / 2.0, (i + randf()) / pellets)
		b.direction = Vector2.from_angle(aim_angle + deg_to_rad(a))
		b.shooter = self
		b.speed = bullet_speed * (randf_range(0.85, 1.05) if pellets > 1 else 1.0)
		b.lifetime = bullet_lifetime
		b.hit_mask = 1 | 2     # svet + Ricco
		b.modulate = Color(1.0, 0.6, 0.5)
		b.global_position = muzzle.global_position
		get_tree().current_scene.add_child(b)
	_flash_t = 0.05
	flash.rotation = randf_range(-0.3, 0.3)
	arm_front.position.x = SHOULDER_FRONT.x - 2.0   # spätný ráz
	create_tween().tween_property(arm_front, "position:x", SHOULDER_FRONT.x, 0.08)


func _punch() -> void:
	var dx: float = player.global_position.x - global_position.x
	if signf(dx) == facing and absf(dx) < punch_range + 8.0 and absf(player.global_position.y - global_position.y) < 40.0:
		if player.has_method("take_damage"):
			player.take_damage(1, global_position + Vector2(0, -30))
		Burst.spawn(get_tree().current_scene, player.global_position + Vector2(0, -22), Vector2(facing, -0.3), Color(1, 0.9, 0.5), 6, 80.0)


# ---------------------------------------------------------------- zásahy

## Guľka (alebo broky) od Ricca
func take_hit(damage: int, dir: Vector2) -> void:
	if state == State.DEAD:
		return
	passive = false
	health -= damage
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -44), dir + Vector2(0, -0.3),
			Color(0.62, 0.05, 0.05), 6, 90.0, Vector2(0, 520), 0.5)
	rig.modulate = Color(3, 3, 3)
	create_tween().tween_property(rig, "modulate", Color.WHITE, 0.12)
	if health <= 0:
		_die(dir)
		return
	velocity.x = dir.x * 60.0
	# zásah ho vyruší – otočí sa k Riccovi a začne odznova mieriť (alebo beží k nemu)
	if state in [State.PATROL, State.IDLE]:
		_alert()
	elif state == State.AIM:
		timer = maxf(timer, aim_time * 0.5)


## Dá sa zneškodniť potichu? Zozadu, keď o Riccovi nevie – alebo kedykoľvek, kým je omráčený klobúkom.
func can_takedown(from_x: float) -> bool:
	if state == State.DEAD:
		return false
	if state == State.STUN:
		return true
	var behind: bool = signf(from_x - global_position.x) != facing
	return behind and _aggro <= 0.0 and state in [State.PATROL, State.IDLE]


## Tiché zneškodnenie (Ricco ho omráči úderom krídla) – padne bez krvi, nad hlavou mu zakrúžia hviezdičky
func takedown(dir: Vector2) -> void:
	if state == State.DEAD:
		return
	health = 0
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -66), Vector2.UP,
			Color(1.0, 0.86, 0.35), 8, 60.0, Vector2(0, 60), 0.6)
	rig.modulate = Color(2, 2, 2)
	create_tween().tween_property(rig, "modulate", Color.WHITE, 0.15)
	_die(dir)


## Riccov hodený klobúk: omráči ho a zhodí mu klobúk
func hat_hit(damage: int, dir: Vector2) -> void:
	if state == State.DEAD:
		return
	_knock_hat(dir)
	take_hit(damage, dir)
	if state != State.DEAD:
		state = State.STUN
		timer = 1.4
		laser.visible = false
		_aggro = 6.0   # nasere sa – po omráčení ide po Riccovi


func _knock_hat(dir: Vector2) -> void:
	if hat == null or not hat.visible:
		return
	hat.visible = false
	var d := DROP.instantiate()
	d.texture = hat.texture
	d.life = 3.0
	get_tree().current_scene.add_child(d)
	d.global_position = hat.global_position
	d.velocity = Vector2(dir.x * 60.0, -170.0)
	d.spin = randf_range(-10.0, 10.0)


func _die(dir: Vector2) -> void:
	state = State.DEAD
	laser.visible = false
	if _flash:
		for c in _flash.get_children():
			if c is LightZone:
				c.switch_off()
		_flash.visible = false
	collision_layer = 0   # guľky ním preletia
	var fall: float = signf(dir.x) if dir.x != 0.0 else -facing   # padá v smere strely
	velocity = Vector2(fall * 80.0, -90.0)
	_knock_hat(dir)
	# zbraň vyletí z ruky
	if gun:
		var d := DROP.instantiate()
		d.texture = gun.texture
		d.life = 3.0
		get_tree().current_scene.add_child(d)
		d.global_position = gun.global_position + Vector2(gun.texture.get_width() * 0.5 * facing, 4)
		d.velocity = Vector2(fall * 70.0, -120.0)
		d.spin = randf_range(-8.0, 8.0)
		gun.visible = false
		for c in arm_front.get_children():
			if c is Sprite2D and c != gun and c != flash:
				if (c as Sprite2D).region_enabled:
					c.visible = false
	# padne na chrbát (otáča sa okolo nôh), ruky a nohy ochabnú
	var tw := create_tween().set_parallel(true)
	var lie: float = PI / 2.0 * fall   # rotácia sa skladá až po zrkadlení (scale) → smer je v obrazovke
	tw.tween_property(rig, "rotation", lie, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(rig, "position:y", -4.0, 0.45)
	tw.tween_property(arm_front, "rotation", randf_range(-2.4, -1.6), 0.4)
	tw.tween_property(arm_back, "rotation", randf_range(-2.6, -1.8), 0.4)
	tw.tween_property(leg_front, "rotation", -0.3, 0.4)
	tw.tween_property(leg_back, "rotation", 0.25, 0.4)
	tw.tween_property(head, "rotation", -0.4, 0.4)
	# krabička nábojov
	var a := AMMO.instantiate()
	get_tree().current_scene.add_child.call_deferred(a)
	a.position = global_position + Vector2(0, -8)   # current_scene je v počiatku
	# v test room sa po chvíli objaví znova
	var fade := create_tween()
	fade.tween_interval(3.0)
	fade.tween_property(rig, "modulate:a", 0.0, 1.0)
	fade.tween_callback(_respawn_or_free)


func _respawn_or_free() -> void:
	if respawn_time > 0.0 and scene_file_path != "":
		var t := get_tree().create_timer(maxf(respawn_time - 4.0, 0.1), false)
		var parent := get_parent()
		var path := scene_file_path
		var pos := spawn_pos
		t.timeout.connect(func():
			var g: Node2D = load(path).instantiate()
			g.position = pos
			parent.add_child(g))
	queue_free()


# ---------------------------------------------------------------- pohyb častí tela

func _animate(delta: float) -> void:
	if state == State.DEAD:
		return
	var moving: bool = absf(velocity.x) > 5.0 and is_on_floor()
	if moving:
		walk_phase += absf(velocity.x) * delta / 9.0
	else:
		walk_phase = lerpf(walk_phase, roundf(walk_phase / PI) * PI, minf(1.0, 10.0 * delta))
	var swing: float = sin(walk_phase) * (0.5 if run_speed > 0.0 and state == State.CHASE else 0.4)
	leg_front.rotation = swing
	leg_back.rotation = -swing
	var bob: float = -absf(sin(walk_phase)) * 1.0
	torso.position.y = HIP.y + bob
	head.position.y = NECK.y + bob
	if hat:
		hat.position.y = HAT_AT.y + bob
	# omráčený: hlava sa kýve
	head.rotation = sin(Time.get_ticks_msec() * 0.02) * 0.25 if state == State.STUN else 0.0
	# ruky
	if weapon:
		arm_front.rotation = _arm_rot(aim_angle)
		# zadná ruka k predku zbrane (dvojručné), inak sa kýve
		if weapon.two_handed and gun:
			var fg: Vector2 = gun.to_global(weapon.foregrip_px + Vector2(1, 2))
			var sb: Vector2 = arm_back.global_position
			arm_back.rotation = _arm_rot((fg - sb).angle())
		else:
			arm_back.rotation = PI / 2.0 - 0.2 - swing * 0.6
	else:
		match state:
			State.WINDUP:
				arm_front.rotation = lerp_angle(arm_front.rotation, -2.2, minf(1.0, 14.0 * delta))
				arm_back.rotation = lerp_angle(arm_back.rotation, -0.6, minf(1.0, 10.0 * delta))
			State.PUNCH:
				arm_front.rotation = -0.05
			_:
				var guard: bool = state in [State.CHASE, State.RECOVER]
				arm_front.rotation = lerp_angle(arm_front.rotation, (-0.5 if guard else PI / 2.0 - 0.3) + swing * 0.5, minf(1.0, 10.0 * delta))
				arm_back.rotation = lerp_angle(arm_back.rotation, (-0.3 if guard else PI / 2.0 - 0.1) - swing * 0.5, minf(1.0, 10.0 * delta))
