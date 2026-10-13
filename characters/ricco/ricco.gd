extends CharacterBody2D
## Ricco – hráč.
## krok 1: chôdza a skok (podľa "Platformer movement" v Godot docs, tutorials/physics/using_character_body_2d)
## krok 2: animácie (characters/ricco/ricco_frames.tres)
## krok 3: pocit zo skoku (coyote time, jump buffer, variabilná výška)
## krok 4: wall slide + wall jump – len od stien, nie od plošiniek (skupina "platform")
## krok 5: zavesenie na okraj (ledge grab) a vylezenie hore (animácie hang/climb sú zarovnané na roh hrany)
## Pri behu sa Ricco kýve zo strany na stranu ako tučniak (waddle) – rieši to kód.

enum State { NORMAL, HANG, CLIMB }

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


func _ready() -> void:
	sprite.animation_finished.connect(_on_sprite_animation_finished)


func _physics_process(delta: float) -> void:
	ledge_cooldown -= delta
	match state:
		State.HANG:
			_process_hang()
			return
		State.CLIMB:
			return  # pohyb rieši Tween v _start_climb()

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
		elif signf(direction) != facing:
			_turn(signf(direction))
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Zavesenie na okraj: vo vzduchu, pri páde (alebo tesne pri vrchole), keď hráč tlačí ku hrane
	if not is_on_floor() and velocity.y > -40.0 and direction != 0.0 and ledge_cooldown <= 0.0 \
			and wall_lock_timer <= 0.0 and _try_grab_ledge(signf(direction)):
		return

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

	if wall_sliding:
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
	elif absf(velocity.x) > 10.0:
		_play(&"run")
	else:
		_play(&"idle")

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
