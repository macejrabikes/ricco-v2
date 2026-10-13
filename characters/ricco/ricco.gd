extends CharacterBody2D
## Ricco – hráč.
## krok 1: chôdza a skok (podľa "Platformer movement" v Godot docs, tutorials/physics/using_character_body_2d)
## krok 2: animácie (characters/ricco/ricco_frames.tres)
## krok 3: pocit zo skoku (coyote time, jump buffer, variabilná výška)
## krok 4: wall slide + wall jump – len od stien, nie od plošiniek (skupina "platform")
## krok 5: zavesenie na okraj (ledge grab) a vylezenie hore (animácie hang/climb sú zarovnané na roh hrany)
## krok 6: mierenie myšou, streľba z pištole, hod klobúka (bumerang)
## krok 7: zásobník, prebíjanie, vypadnutý zásobník
## krok 7b: zbraň drží ruka ducha zavraždeného Dona (characters/ricco/ghost_hand)
## krok 7c: prebíjanie druhou rukou ducha – starý zásobník vypadne, nový sa zasunie
## Pri behu sa Ricco kýve zo strany na stranu ako tučniak (waddle) – rieši to kód.

enum State { NORMAL, HANG, CLIMB }

signal ammo_changed(mag: int, reserve: int, reloading: bool)

@export var max_speed: float = 140.0       ## px/s pri behu
@export var acceleration: float = 900.0    ## ako rýchlo sa rozbehne
@export var friction: float = 1100.0       ## ako rýchlo zastaví, keď pustíš smer
@export var jump_velocity: float = -320.0  ## záporné = hore (os Y ide v Godote dole)

@export_group("Jump feel")
@export var coyote_time: float = 0.1       ## s – skok ešte funguje chvíľu po zídení z hrany
@export var jump_buffer_time: float = 0.12 ## s – stlačenie skoku tesne pred dopadom sa zaráta
@export_range(0.0, 1.0) var jump_cut: float = 0.45  ## pustenie skoku počas stúpania znásobí rýchlosť týmto (menej = nižší krátky skok)
@export_group("")

@export_group("Wall jump")
@export var wall_slide_speed: float = 60.0              ## max. rýchlosť šmýkania po stene (px/s)
@export var wall_jump_velocity: Vector2 = Vector2(170, -300)  ## x = odraz od steny, y = výška
@export var wall_jump_lock_time: float = 0.15           ## s – po odraze chvíľu nejde riadiť späť ku stene
@export var wall_coyote_time: float = 0.08              ## s – odraz funguje chvíľu aj po pustení steny
@export var wall_slide_offset: float = 0.0              ## px – doladenie posunu obrázka od steny (animácia je zarovnaná na stenu)
@export_group("")

@export_group("Ledge grab")
@export var ledge_reach: float = 14.0      ## px – ako ďaleko pred sebou Ricco hľadá hranu
@export var ledge_hang_depth: float = 38.0 ## px – o koľko sú nohy pod hranou, keď visí
@export var ledge_regrab_time: float = 0.3 ## s – po pustení sa hneď znova nechytí
@export var hang_visual_offset: float = 0.0  ## px – doladenie: posun obrázka od steny pri visení
@export_group("")

@export_group("Weapons")
@export var bullet_scene: PackedScene = preload("res://weapons/pistol/bullet.tscn")
@export var hat_scene: PackedScene = preload("res://weapons/hat/hat_projectile.tscn")
@export var fire_cooldown: float = 0.14       ## s medzi výstrelmi (pištoľ – každé kliknutie = výstrel)
@export var bullet_spread_deg: float = 1.5    ## náhodný rozptyl
@export var recoil_px: float = 3.0            ## o koľko px cukne pištoľ dozadu
@export var shake_strength: float = 2.0       ## zatrasenie kamerou pri výstrele (px)
@export var aim_facing: bool = true           ## Ricco sa pozerá tam, kam mieri (ako v My Friend Pedro)
@export_range(0.0, 90.0) var ground_aim_max_down_deg: float = 50.0  ## na zemi sa nedá mieriť strmšie dole (zbraň by išla do podlahy)
@export var magazine_scene: PackedScene = preload("res://weapons/pistol/magazine_drop.tscn")
@export var mag_size: int = 8                 ## nábojov v zásobníku (Colt 1911: 7+1)
@export var ammo_reserve_start: int = 32      ## náhradné náboje
@export var reload_time: float = 1.0          ## s (pištoľ: vyhodí, nová ruka podá, zasunie)
@export_group("")

@export_group("Waddle")
@export var waddle_angle_deg: float = 7.0  ## max. náklon do strany pri behu
@export var waddle_bob: float = 2.0         ## o koľko px sa pri kroku nadvihne
@export var waddle_step: float = 22.0       ## koľko px prejde za jeden krok
@export_group("")

const HALF_WIDTH := 10.0  ## polomer kapsuly (CollisionShape2D)
const HEIGHT := 38.0      ## výška kapsuly
## Animácia "climb" má framy 96×96 nakreslené tak, že roh hrany je v pixeli (40, 52).
## Tento posun spritu ho zarovná s rohom hrany v hre (rovnako ako pri "hang").
const CLIMB_SPRITE_OFFSET := Vector2(19, -21)
## Kde stojí Ricco v poslednom frame "climb" – o koľko px za hranou (stred tela)
const CLIMB_STAND_DISTANCE := 17.0

@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@onready var aim: Node2D = $Aim
@onready var gun: Sprite2D = $Aim/Gun
@onready var muzzle: Marker2D = $Aim/Gun/Muzzle
@onready var flash: Sprite2D = $Aim/Gun/Muzzle/Flash
@onready var camera: Camera2D = $Camera2D
@onready var mag: Sprite2D = $Aim/Gun/Mag
@onready var offhand: GhostHand = $Aim/Gun/OffHand

## Ktorý frame animácie "hat_throw" je moment, keď klobúk opustí krídlo
const HAT_RELEASE_FRAME := 4

var state: State = State.NORMAL
var facing: float = 1.0             ## 1 = doprava, -1 = doľava
var was_on_floor: bool = true
var coyote_timer: float = 0.0       ## koľko ešte zostáva coyote time
var jump_buffer_timer: float = 0.0  ## koľko ešte „platí“ stlačenie skoku
var wall_timer: float = 0.0         ## koľko ešte platí „bol som na stene“
var wall_normal_x: float = 0.0      ## kam smeruje stena od Ricca (+1 = stena je vľavo, odraz doprava)
var wall_lock_timer: float = 0.0    ## po wall jumpe dočasne ignorujeme smer od hráča
var wall_sliding: bool = false
var ledge_cooldown: float = 0.0
var ledge_top: Vector2 = Vector2.ZERO  ## bod na vrchu hrany, kam Ricco vylezie
var waddle_phase: float = 0.0       ## fáza kolísania (radiány), rastie s prejdenou vzdialenosťou
var aim_dir: Vector2 = Vector2.RIGHT ## smer k myši
var fire_timer: float = 0.0
var shake_timer: float = 0.0
var has_hat: bool = true            ## false = klobúk práve letí
var gun_base_x: float = 0.0         ## pokojová poloha pištole (kvôli cuknutiu pri výstrele)
var ammo_in_mag: int = 0
var ammo_reserve: int = 0
var reloading: bool = false


func _ready() -> void:
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	flash.visible = false
	gun_base_x = gun.position.x
	add_to_group(&"player")
	ammo_in_mag = mag_size
	ammo_reserve = ammo_reserve_start


func _process(delta: float) -> void:
	# zatrasenie kamerou (offset sa po chvíli vráti na nulu)
	if shake_timer > 0.0:
		shake_timer -= delta
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
	else:
		camera.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	ledge_cooldown -= delta
	fire_timer -= delta
	match state:
		State.HANG:
			aim.visible = false
			_process_hang()
			return
		State.CLIMB:
			aim.visible = false
			return  # pohyb rieši animácia climb

	# Gravitácia – get_gravity() berie hodnotu z Project Settings → Physics → 2D.
	# Na zemi sa coyote time nabíja, vo vzduchu odpočítava.
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		velocity += get_gravity() * delta
		coyote_timer -= delta

	# Jump buffer: zapamätáme si stlačenie skoku na krátky čas
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# Stena – len ak to nie je plošinka (stav z posledného move_and_slide)
	var wall_n: float = _jump_wall_normal()
	if wall_n != 0.0:
		wall_timer = wall_coyote_time
		wall_normal_x = wall_n
	else:
		wall_timer -= delta

	# Wall slide: pri páde popri stene sa Ricco šmýka pomaly
	wall_sliding = wall_n != 0.0 and velocity.y > 0.0
	if wall_sliding:
		velocity.y = minf(velocity.y, wall_slide_speed)

	# Skok – ak je stlačenie ešte „živé“ a Ricco je na zemi (alebo práve zišiel z hrany)
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0  # aby sa nedalo skočiť dvakrát z jedného coyote okna
		sprite.play(&"jump")
	# Wall jump – vo vzduchu pri stene: odraz šikmo hore preč od steny
	elif jump_buffer_timer > 0.0 and wall_timer > 0.0:
		velocity = Vector2(wall_normal_x * wall_jump_velocity.x, wall_jump_velocity.y)
		jump_buffer_timer = 0.0
		wall_timer = 0.0
		wall_lock_timer = wall_jump_lock_time
		wall_sliding = false
		_turn(wall_normal_x)
		sprite.play(&"wall_jump")  # krátky odraz nohou od steny, potom jump/fall

	# Variabilná výška: pustíš skok počas stúpania → Ricco spomalí a skok je nižší
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	# Pohyb do strán: -1 vľavo, 0 nič, 1 vpravo
	var direction: float = Input.get_axis("move_left", "move_right")
	if wall_lock_timer > 0.0:
		wall_lock_timer -= delta  # tesne po odraze necháme Ricca letieť (rýchlosť x sa nemení)
	elif direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * max_speed, acceleration * delta)
		if wall_sliding:
			# pri šmýkaní sa Ricco pozerá OD steny (chrbtom k nej), ako Pedro
			if facing != wall_normal_x:
				_turn(wall_normal_x)
		elif not aim_facing and signf(direction) != facing:
			_turn(signf(direction))
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Zavesenie na okraj: vo vzduchu, pri páde (alebo tesne pri vrchole), keď hráč tlačí ku hrane
	if not is_on_floor() and velocity.y > -40.0 and direction != 0.0 and ledge_cooldown <= 0.0 \
			and wall_lock_timer <= 0.0 and _try_grab_ledge(signf(direction)):
		return

	_update_aim()
	_update_weapons()

	move_and_slide()
	_update_animation(direction)
	_update_waddle(delta)
	# pri šmýkaní po stene odsunieme obrázok od steny, aby do nej nezachádzal
	var target_x: float = wall_normal_x * wall_slide_offset if wall_sliding else 0.0
	visual.position.x = lerpf(visual.position.x, target_x, minf(1.0, 25.0 * delta))


## Vráti smer od steny (+1 / -1), ak sa Ricco vo vzduchu dotýka steny, od ktorej sa dá odraziť.
## Plošinky (uzly v skupine "platform") sa nerátajú. 0 = žiadna stena.
func _jump_wall_normal() -> float:
	if is_on_floor() or not is_on_wall():
		return 0.0
	for i in get_slide_collision_count():
		var c: KinematicCollision2D = get_slide_collision(i)
		var n: Vector2 = c.get_normal()
		var collider := c.get_collider() as Node
		if absf(n.x) > 0.7 and collider != null and not collider.is_in_group(&"platform"):
			return signf(n.x)
	return 0.0


## Hľadá hranu pred Riccom tromi lúčmi (Godot docs: tutorials/physics/ray-casting):
##  1. na úrovni hrude musí byť stena,
##  2. nad hlavou musí byť voľno,
##  3. lúč zhora nadol nájde vrch hrany.
## Ak hranu nájde, Ricco sa zavesí a funkcia vráti true.
func _try_grab_ledge(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	var p: Vector2 = global_position
	var reach: float = HALF_WIDTH + ledge_reach
	var head_y: float = p.y - HEIGHT - 8.0
	# 1. stena pred hruďou
	var wall_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
			Vector2(p.x, p.y - HEIGHT + 12.0), Vector2(p.x + dir * reach, p.y - HEIGHT + 12.0), collision_mask, [get_rid()]))
	if wall_hit.is_empty() or absf(wall_hit.normal.x) < 0.7:
		return false
	var wall_x: float = wall_hit.position.x
	# 2. nad hlavou voľno
	var above_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
			Vector2(p.x, head_y), Vector2(p.x + dir * reach, head_y), collision_mask, [get_rid()]))
	if not above_hit.is_empty():
		return false
	# 3. vrch hrany (lúč kúsok za okrajom steny smerom dole)
	var probe_x: float = wall_x + dir * 4.0
	var top_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
			Vector2(probe_x, head_y), Vector2(probe_x, p.y - HEIGHT + 14.0), collision_mask, [get_rid()]))
	if top_hit.is_empty() or top_hit.normal.y > -0.7:
		return false
	var top_y: float = top_hit.position.y
	# 4. hore musí byť miesto, kde sa Ricco postaví
	var stand_x: float = wall_x + dir * CLIMB_STAND_DISTANCE
	# úzka stena/pilier: ak tam nie je zem, postav sa bližšie k okraju
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
			Vector2(stand_x, top_y - 2.0), Vector2(stand_x, top_y + 4.0), collision_mask, [get_rid()]))
	if floor_hit.is_empty():
		stand_x = wall_x + dir * (HALF_WIDTH + 2.0)
	var room_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
			Vector2(stand_x, top_y - 2.0), Vector2(stand_x, top_y - HEIGHT - 2.0), collision_mask, [get_rid()]))
	if not room_hit.is_empty():
		return false

	# Zavesenie
	state = State.HANG
	velocity = Vector2.ZERO
	wall_sliding = false
	ledge_top = Vector2(stand_x, top_y)
	global_position = Vector2(wall_x - dir * (HALF_WIDTH + 0.5), top_y + ledge_hang_depth)
	if facing != dir:
		facing = dir
		visual.scale.x = facing
	visual.rotation = 0.0
	visual.position = Vector2(-dir * hang_visual_offset, 0.0)
	sprite.play(&"hang")
	return true


## Visí na hrane: skok = vylezie hore, smer od steny = pustí sa.
func _process_hang() -> void:
	if Input.is_action_just_pressed("jump"):
		_start_climb()
	elif Input.get_axis("move_left", "move_right") == -facing:
		state = State.NORMAL
		ledge_cooldown = ledge_regrab_time
		sprite.play(&"fall")


## Vylezenie: Ricco stojí na mieste a „lezie“ samotná animácia (je zarovnaná na roh hrany),
## na konci ho presunieme na hranu – takto sa to robí aj v hrách typu Assassin's Creed / Prince of Persia.
func _start_climb() -> void:
	state = State.CLIMB
	visual.position = Vector2.ZERO
	sprite.offset = CLIMB_SPRITE_OFFSET
	sprite.play(&"climb")


func _on_sprite_animation_finished() -> void:
	if state == State.CLIMB and sprite.animation == &"climb":
		_end_climb()


func _end_climb() -> void:
	global_position = ledge_top
	sprite.offset = Vector2.ZERO
	state = State.NORMAL
	velocity = Vector2.ZERO
	was_on_floor = true
	sprite.play(&"idle")


## Otočí Ricca. Všetky animácie sú kreslené smerom doprava,
## doľava ho len zrkadlovo prevrátime cez scale.x.
func _turn(new_facing: float) -> void:
	facing = new_facing
	visual.scale.x = facing
	if is_on_floor():
		sprite.play(&"turn")


func _update_animation(direction: float) -> void:
	var on_floor: bool = is_on_floor()

	if sprite.animation == &"hat_throw" and sprite.is_playing():
		pass  # hod klobúka dobehne aj vo vzduchu
	elif wall_sliding:
		_play(&"wall_slide")
	elif not on_floor and sprite.animation == &"wall_jump" and sprite.is_playing():
		pass  # nech odraz od steny dobehne (~0.15 s)
	elif not on_floor:
		# Stúpa → jump (prehrá sa raz a ostane na poslednom frame), padá → fall (slučka)
		_play(&"jump" if velocity.y < 0.0 else &"fall")
	elif not was_on_floor:
		sprite.play(&"land")
	elif sprite.animation == &"turn" and sprite.is_playing():
		pass  # nech otočka dobehne (trvá ~0.15 s)
	elif sprite.animation == &"land" and sprite.is_playing() and direction == 0.0:
		pass  # dopad dobehne, ak sa hráč nehýbe; pri pohybe hneď prejde na beh
	elif sprite.animation == &"hat_throw" and sprite.is_playing():
		pass  # hod dobehne celý
	elif sprite.animation == &"hat_catch" and sprite.is_playing() and absf(velocity.x) < 10.0:
		pass  # chytenie dobehne, ak Ricco stojí
	elif absf(velocity.x) > 10.0:
		_play(&"run")
	else:
		_play(&"idle" if has_hat else &"idle_nohat")

	was_on_floor = on_floor


## Spustí animáciu len ak už nehrá (inak by sa stále reštartovala od 1. framu).
func _play(anim: StringName) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		if sprite.animation == anim and sprite.sprite_frames.get_animation_loop_mode(anim) == SpriteFrames.LOOP_NONE:
			return  # jednorazová animácia už dohrala – nechaj posledný frame
		sprite.play(anim)


## Kolísanie pri behu: Visual sa otáča okolo nôh (origin je pri nohách),
## jeden krok = polovica sínusovej vlny, takže každý krok je jeden náklon na stranu.
func _update_waddle(delta: float) -> void:
	var running: bool = is_on_floor() and sprite.animation == &"run"
	if running:
		waddle_phase += absf(velocity.x) * delta / waddle_step * PI
		var s: float = sin(waddle_phase)
		visual.rotation = deg_to_rad(waddle_angle_deg) * s
		visual.position.y = -absf(s) * waddle_bob
		# rýchlosť framov podľa rýchlosti behu (pri rozbehu pomalšie)
		sprite.speed_scale = clampf(absf(velocity.x) / max_speed, 0.4, 1.0)
	else:
		# plynulý návrat do rovnej polohy
		visual.rotation = lerpf(visual.rotation, 0.0, minf(1.0, 20.0 * delta))
		visual.position.y = lerpf(visual.position.y, 0.0, minf(1.0, 20.0 * delta))
		sprite.speed_scale = 1.0
		if not is_on_floor():
			waddle_phase = 0.0


## Mierenie: Aim sa otáča k myši. Pri mierení doľava sa zbraň aj s rukou ducha preklopí
## (scale.y = -1), aby nebola hore nohami – deti (ruka, ústie hlavne) sa preklopia s ňou.
func _update_aim() -> void:
	aim_dir = (get_global_mouse_position() - aim.global_position).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2(facing, 0)
	# na zemi obmedzíme mierenie dole, inak by zbraň zachádzala do podlahy
	if is_on_floor():
		var max_down: float = deg_to_rad(ground_aim_max_down_deg)
		var a: float = aim_dir.angle()  # 0 = doprava, PI/2 = dole
		if a > max_down and a <= PI * 0.5:
			aim_dir = Vector2.from_angle(max_down)
		elif a > PI * 0.5 and a < PI - max_down:
			aim_dir = Vector2.from_angle(PI - max_down)
	aim.rotation = aim_dir.angle()
	gun.scale.y = -1.0 if aim_dir.x < 0.0 else 1.0
	var busy: bool = sprite.animation in [&"hat_throw", &"hat_catch"] and sprite.is_playing()
	aim.visible = not busy
	# Ricco sa pozerá tam, kam mieri (okrem šmýkania po stene a hodu)
	if aim_facing and not wall_sliding and not busy and wall_lock_timer <= 0.0:
		var want: float = 1.0 if aim_dir.x >= 0.0 else -1.0
		if want != facing:
			_turn(want)


func _update_weapons() -> void:
	# Streľba – pištoľ: každé kliknutie jeden výstrel (s malým cooldownom)
	if Input.is_action_just_pressed("shoot") and fire_timer <= 0.0 and aim.visible and not reloading:
		if ammo_in_mag > 0:
			_shoot()
		else:
			_start_reload()  # prázdny zásobník → automaticky prebije
	if Input.is_action_just_pressed("reload"):
		_start_reload()
	# Hod klobúka – len keď ho má na hlave
	if Input.is_action_just_pressed("throw_hat") and has_hat and not (sprite.animation == &"hat_throw" and sprite.is_playing()):
		sprite.play(&"hat_throw")


func _shoot() -> void:
	fire_timer = fire_cooldown
	ammo_in_mag -= 1
	ammo_changed.emit(ammo_in_mag, ammo_reserve, false)
	var b := bullet_scene.instantiate()
	b.direction = aim_dir.rotated(deg_to_rad(randf_range(-bullet_spread_deg, bullet_spread_deg)))
	b.shooter = self
	b.global_position = muzzle.global_position
	get_tree().current_scene.add_child(b)
	# šťava: záblesk, cuknutie pištole, zatrasenie kamery
	flash.visible = true
	flash.rotation = randf_range(-0.3, 0.3)
	get_tree().create_timer(0.05).timeout.connect(func(): flash.visible = false)
	gun.position.x = gun_base_x - recoil_px
	create_tween().tween_property(gun, "position:x", gun_base_x, 0.08)
	shake_timer = 0.06


## Prebíjanie (ako naozaj): pištoľ sa nakloní, starý zásobník vykĺzne z pažby a padne na zem,
## druhá ruka ducha priletí s novým zásobníkom, zasunie ho a zmizne. Všetko je jeden Tween
## (Godot docs: classes/class_tween – tween_property / set_parallel / chain / tween_callback).
## Časovanie sa naťahuje podľa reload_time.
const MAG_IN_GRIP := Vector2(-8.5, -1.5)   ## zásobník v pažbe (súradnice zbrane)
const MAG_OUT := Vector2(-8.5, 8.0)        ## vysunutý zásobník tesne pred pustením
const OFFHAND_MAG := Vector2(5, -2)        ## kde drží druhá ruka zásobník (v jej obrázku)
const OFFHAND_START := Vector2(-28, 8)     ## odkiaľ druhá ruka priletí (spoza zbrane, od Ricca)

func _start_reload() -> void:
	if reloading or ammo_reserve <= 0 or ammo_in_mag == mag_size:
		return
	reloading = true
	ammo_changed.emit(ammo_in_mag, ammo_reserve, true)
	var k: float = reload_time / 1.0   # časovanie nižšie je pre 1 s
	var tilt: float = -0.35 * gun.scale.y   # hlaveň mierne hore, pažba k Riccovi
	var under: Vector2 = MAG_IN_GRIP - OFFHAND_MAG + Vector2(0, 7)  # nový zásobník tesne pod pažbou
	var inside: Vector2 = MAG_IN_GRIP - OFFHAND_MAG                 # zasunutý
	mag.position = MAG_IN_GRIP
	mag.visible = true
	offhand.position = OFFHAND_START
	offhand.fade = 0.0
	offhand.visible = true
	var tw := create_tween()
	# 1. naklonenie + starý zásobník vykĺzne
	tw.tween_property(gun, "rotation", tilt, 0.08 * k)
	tw.tween_property(mag, "position", MAG_OUT, 0.08 * k).set_ease(Tween.EASE_IN)
	tw.tween_callback(_drop_magazine)
	# 2. druhá ruka priletí s novým zásobníkom
	tw.tween_property(offhand, "fade", 1.0, 0.12 * k)
	tw.parallel().tween_property(offhand, "position", under, 0.3 * k) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 3. zasunutie (rýchly ťah hore) + cuknutie zbrane
	tw.tween_property(offhand, "position", inside, 0.08 * k).set_ease(Tween.EASE_IN)
	tw.tween_callback(_magazine_inserted)
	tw.tween_property(gun, "rotation", tilt - 0.12 * gun.scale.y, 0.04 * k)
	tw.tween_property(gun, "rotation", tilt, 0.06 * k)
	# 4. ruka odletí a rozplynie sa, zbraň sa vráti
	tw.tween_property(offhand, "position", OFFHAND_START, 0.2 * k).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(offhand, "fade", 0.0, 0.2 * k)
	tw.parallel().tween_property(gun, "rotation", 0.0, 0.16 * k).set_delay(0.04 * k)
	tw.tween_callback(_finish_reload)


## Starý (prázdny) zásobník sa pustí – ďalej padá sám (magazine_drop.gd)
func _drop_magazine() -> void:
	var m := magazine_scene.instantiate()
	get_tree().current_scene.add_child(m)
	m.global_position = mag.to_global(Vector2(2, 4.5))  # stred zásobníka
	m.rotation = mag.global_rotation
	m.velocity = Vector2(-facing * 25.0, 20.0)
	m.spin = randf_range(-6.0, 6.0)
	mag.visible = false


func _magazine_inserted() -> void:
	mag.position = MAG_IN_GRIP
	mag.visible = true
	offhand.get_node("NewMag").visible = false


func _finish_reload() -> void:
	var need: int = mag_size - ammo_in_mag
	var take: int = mini(need, ammo_reserve)
	ammo_in_mag += take
	ammo_reserve -= take
	reloading = false
	offhand.visible = false
	offhand.get_node("NewMag").visible = true
	ammo_changed.emit(ammo_in_mag, ammo_reserve, false)


func _on_sprite_frame_changed() -> void:
	if sprite.animation == &"hat_throw" and sprite.frame == HAT_RELEASE_FRAME and has_hat:
		_launch_hat()


func _launch_hat() -> void:
	has_hat = false
	var h := hat_scene.instantiate()
	get_tree().current_scene.add_child(h)
	var start: Vector2 = global_position + Vector2(facing * 12.0, -30.0)
	var to_mouse: Vector2 = get_global_mouse_position() - start
	h.launch(start, to_mouse if to_mouse.length() > 4.0 else aim_dir, self)  # mieri presne na kurzor
	h.caught.connect(_on_hat_caught)


func _on_hat_caught() -> void:
	has_hat = true
	if is_on_floor() and state == State.NORMAL and absf(velocity.x) < 10.0:
		sprite.play(&"hat_catch")
