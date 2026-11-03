extends Node2D
## Policajt na motorke v naháňačke (levels/level3/chase.gd). Ide vo vedľajšom pruhu (za taxíkom – menší, tmavší, bez
## kolízie s taxíkom), predbehne taxík a jazdí pred ním; otočí sa a strieľa z pištole dozadu na Ricca. Pred ranou mieri
## (červená čiara ako u gangstrov – čas zohnúť sa za kabínu taxíka). Zásah do jazdca (Hit – chase_hitbox.gd) ho zhodí:
## motorka sa prevráti a odletí dozadu. Po hold_time policajt pridá plyn a ujde dopredu.
## Počiatok uzla = cesta pod motorkou (vľavo dole obrázka). Godot docs: classes/class_line2d, classes/class_tween

signal finished

const BULLET := preload("res://weapons/pistol/bullet.tscn")
const FLASH := preload("res://weapons/pistol/muzzle_flash_big.png")

@export var start_x: float = -140.0
@export var hold_x: float = 470.0
@export var approach_time: float = 4.0
@export var hold_time: float = 22.0
@export var health: float = 2.0
@export var aim_time: float = 0.7
@export var shoot_every: Vector2 = Vector2(1.5, 2.3)
@export var bullet_speed: float = 360.0

var active: bool = false
var done: bool = false
var _phase: int = 0            ## 0 čaká, 1 dobieha, 2 jazdí pred taxíkom, 3 zasiahnutý, 4 uteká dopredu
var _t: float = 0.0
var _shoot_t: float = 1.5
var _aim_t: float = -1.0
var _player: Node2D
var _laser: Line2D
var _flash: Sprite2D
var _engine: Node
var _v: float = 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
@onready var hit: StaticBody2D = $Hit


func _ready() -> void:
	position.x = start_x
	visible = false
	hit.process_mode = Node.PROCESS_MODE_DISABLED
	hit.connect(&"hit", _on_hit)
	_laser = Line2D.new()
	_laser.width = 1.0
	_laser.default_color = Color(1.0, 0.15, 0.1, 0.55)
	_laser.top_level = true
	_laser.visible = false
	_laser.z_index = 5
	add_child(_laser)
	_flash = Sprite2D.new()
	_flash.texture = FLASH
	_flash.hframes = 3
	_flash.centered = false
	_flash.offset = Vector2(-3, -12)
	_flash.scale = Vector2(-0.7, 0.7)   # strieľa doľava (dozadu)
	_flash.visible = false
	muzzle.add_child(_flash)


func start() -> void:
	if active or done:
		return
	active = true
	visible = true
	_phase = 1
	_t = 0.0
	hit.process_mode = Node.PROCESS_MODE_INHERIT
	_engine = Sfx.loop(&"moto_engine", self, Vector2(40, -20), -8.0, &"SFX")


func _physics_process(delta: float) -> void:
	if not active:
		return
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	match _phase:
		1:
			var k: float = clampf(_t / approach_time, 0.0, 1.0)
			position.x = lerpf(start_x, hold_x, 1.0 - (1.0 - k) * (1.0 - k))
			if k >= 1.0:
				_phase = 2
				_t = 0.0
		2:
			position.x = hold_x + sin(_t * 0.9) * 22.0
			position.y = sin(_t * 7.0) * 0.6
			_update_gun(delta)
			if _t >= hold_time and _aim_t < 0.0:
				_phase = 4
				_t = 0.0
				sprite.frame = 0
		3:   # zrazený – prevrátená motorka zostáva vzadu
			_v += 500.0 * delta
			position.x -= _v * delta
			if position.x < -200.0:
				_finish()
		4:   # pridá plyn a ujde dopredu
			_v += 260.0 * delta
			position.x += _v * delta
			if position.x > 760.0:
				_finish()


func _update_gun(delta: float) -> void:
	if _player == null or int(_player.get(&"state")) == 3:
		_laser.visible = false
		return
	var target: Vector2 = _player.global_position + Vector2(0, -20)
	if _aim_t >= 0.0:
		_aim_t += delta
		_laser.visible = true
		_laser.points = PackedVector2Array([muzzle.global_position, muzzle.global_position + (target - muzzle.global_position).normalized() * 420.0])
		if _aim_t >= aim_time:
			_fire(target)
			_aim_t = -1.0
			_laser.visible = false
			_shoot_t = randf_range(shoot_every.x, shoot_every.y)
			get_tree().create_timer(0.35, false).timeout.connect(func(): if _phase == 2: sprite.frame = 0)
		return
	_shoot_t -= delta
	if _shoot_t <= 0.0:
		_aim_t = 0.0
		sprite.frame = 1


func _fire(target: Vector2) -> void:
	var b := BULLET.instantiate()
	b.direction = (target - muzzle.global_position).normalized().rotated(deg_to_rad(randf_range(-3.0, 3.0)))
	b.shooter = hit
	b.speed = bullet_speed
	b.lifetime = 1.6
	b.hit_mask = 1 | 2 | 32   # svet + Ricco + kryt
	b.modulate = Color(1.0, 0.6, 0.5)
	b.global_position = muzzle.global_position
	get_tree().current_scene.add_child(b)
	_flash.visible = true
	_flash.frame = randi() % 2
	get_tree().create_timer(0.06, false).timeout.connect(func(): _flash.visible = false)
	Sfx.play(&"pistol_b", muzzle.global_position, -4.0, 0.05)


func _on_hit(damage: float, dir: Vector2) -> void:
	if _phase != 1 and _phase != 2:
		return
	health -= damage
	Sfx.play(&"impact_body", hit.global_position, -2.0)
	Burst.spawn(get_tree().current_scene, hit.global_position + Vector2(0, -10), dir + Vector2(0, -0.3), Color(0.62, 0.05, 0.05), 6, 90.0, Vector2(0, 520), 0.5)
	sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if health > 0.0:
		return
	_phase = 3
	_v = 60.0
	_laser.visible = false
	sprite.frame = 2
	hit.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	for w in get_children():
		if w.is_in_group(&"spin_wheels"):
			w.visible = false
	if _engine:
		_engine.queue_free()
		_engine = null
	Sfx.play(&"tire_skid", global_position + Vector2(40, -10), -4.0)
	Sfx.play(&"metal_crash", global_position + Vector2(40, -10), -12.0, 0.1)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(40, -10), Vector2(-1, -0.6), Color(1.0, 0.8, 0.4), 10, 120.0)


func _finish() -> void:
	if done:
		return
	done = true
	active = false
	_laser.visible = false
	finished.emit()
	queue_free()
