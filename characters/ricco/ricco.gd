extends CharacterBody2D
## Ricco – krok 1: chôdza a skok, krok 2: animácie.
## Pohyb vychádza z príkladu "Platformer movement" v Godot docs
## (tutorials/physics/using_character_body_2d), len s plynulým zrýchlením.
## Animácie sú v characters/ricco/ricco_frames.tres (SpriteFrames).
## Pri behu sa Ricco kýve zo strany na stranu ako tučniak (waddle) – rieši to kód,
## nie sprite sheet, aby kroky sedeli s rýchlosťou pohybu.

@export var max_speed: float = 140.0       ## px/s pri behu
@export var acceleration: float = 900.0    ## ako rýchlo sa rozbehne
@export var friction: float = 1100.0       ## ako rýchlo zastaví, keď pustíš smer
@export var jump_velocity: float = -320.0  ## záporné = hore (os Y ide v Godote dole)

@export_group("Waddle")
@export var waddle_angle_deg: float = 7.0  ## max. náklon do strany pri behu
@export var waddle_bob: float = 2.0         ## o koľko px sa pri kroku nadvihne
@export var waddle_step: float = 22.0       ## koľko px prejde za jeden krok
@export_group("")

@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite

var facing: float = 1.0        ## 1 = doprava, -1 = doľava
var was_on_floor: bool = true
var waddle_phase: float = 0.0  ## fáza kolísania (radiány), rastie s prejdenou vzdialenosťou


func _physics_process(delta: float) -> void:
	# Gravitácia – get_gravity() berie hodnotu z Project Settings → Physics → 2D.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Skok
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		sprite.play(&"jump")

	# Pohyb do strán: -1 vľavo, 0 nič, 1 vpravo
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * max_speed, acceleration * delta)
		if signf(direction) != facing:
			_turn(signf(direction))
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	_update_animation(direction)
	_update_waddle(delta)


## Otočí Ricca. Všetky animácie sú kreslené smerom doprava,
## doľava ho len zrkadlovo prevrátime cez scale.x.
func _turn(new_facing: float) -> void:
	facing = new_facing
	visual.scale.x = facing
	if is_on_floor():
		sprite.play(&"turn")


func _update_animation(direction: float) -> void:
	var on_floor: bool = is_on_floor()

	if not on_floor:
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
