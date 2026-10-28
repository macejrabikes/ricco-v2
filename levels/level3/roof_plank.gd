extends StaticBody2D
## Úzka doska cez medzeru medzi strechami (kapitola III – strechy, úsek F). Jednosmerná plošina (skupina „platform“).
## Kto po nej ide potichu (zakrádanie C / pomaly), toho unesie – len trochu zavŕzga. Kto po nej beží alebo na ňu
## doskočí, toho nevydrží: zapraská, zlomí sa a Ricco spadne do dvora (hore sa vylezie po rebríku). Praskot počujú
## gangstri v okolí (Gangster.noise). Po chvíli tam niekto (hra) položí novú dosku.
## Uzol = ľavý koniec dosky na úrovni vrchu (y = strecha). Deti: Sprite (plank.png), Shape (jednosmerná, šírka length).
## Godot docs: classes/class_staticbody2d, classes/class_tween

@export var length: float = 160.0        ## px
@export var run_limit: float = 70.0      ## px/s – rýchlejšie = beží (zakrádanie je 58)
@export var break_time: float = 0.45     ## s behu po doske, kým praskne
@export var land_limit: float = 260.0    ## px/s – takto rýchly dopad ju zlomí hneď
@export var respawn: float = 5.0         ## s – potom je doska znova na mieste

signal broke

var _player: CharacterBody2D
var _stress: float = 0.0
var _creak_t: float = 0.0
var _fall_vy: float = 0.0
var _broken: bool = false
var _sprite: Sprite2D
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group(&"platform")
	_sprite = get_node(^"Sprite") as Sprite2D
	_shape = get_node(^"Shape") as CollisionShape2D


func _physics_process(delta: float) -> void:
	if _broken:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
		return
	var p: Vector2 = to_local(_player.global_position)
	var over: bool = p.x > -4.0 and p.x < length + 4.0
	var on: bool = over and _player.is_on_floor() and absf(p.y) < 4.0
	if not on:
		if over and p.y < 0.0:
			_fall_vy = _player.velocity.y   # rýchlosť tesne pred dopadom
		_stress = maxf(0.0, _stress - delta)
		_sprite.position.y = move_toward(_sprite.position.y, 0.0, delta * 20.0)
		return
	# prehne sa pod ním (najviac v strede)
	var mid: float = 1.0 - absf(p.x / length - 0.5) * 2.0
	_sprite.position.y = move_toward(_sprite.position.y, 2.0 * mid, delta * 20.0)
	if _fall_vy > land_limit:
		_crack()
		return
	_fall_vy = 0.0
	var running: bool = absf(_player.velocity.x) > run_limit and not _player.get(&"sneaking")
	if running:
		_stress += delta
		if _stress >= break_time:
			_crack()
			return
	else:
		_stress = maxf(0.0, _stress - delta * 0.5)
	# vŕzganie: pri behu hlasno a často, potichu len občas
	_creak_t -= delta
	if _creak_t <= 0.0 and absf(_player.velocity.x) > 5.0:
		_creak_t = 0.22 if running else randf_range(0.7, 1.2)
		Sfx.play(&"plank_creak", global_position + Vector2(p.x, 0), -2.0 if running else -14.0, 0.15)


func _crack() -> void:
	_broken = true
	_stress = 0.0
	_shape.set_deferred(&"disabled", true)
	Sfx.play(&"crate_break", global_position + Vector2(length / 2.0, 0), 0.0, 0.05)
	Gangster.noise(global_position + Vector2(length / 2.0, 0), 320.0)
	Burst.spawn(get_parent(), global_position + Vector2(length / 2.0, 2), Vector2.DOWN, Color(0.55, 0.42, 0.26), 10, 80.0)
	broke.emit()
	# zlomí sa v strede: doska sa preklopí okolo ľavého konca a padá do dvora
	var tw := create_tween()
	tw.tween_property(_sprite, "rotation", 1.2, 0.35).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_sprite, "position:y", 30.0, 0.35)
	tw.tween_property(_sprite, "position:y", 520.0, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.9)
	tw.tween_interval(respawn)
	tw.tween_callback(_restore)


func _restore() -> void:
	_sprite.rotation = 0.0
	_sprite.position = Vector2.ZERO
	_shape.set_deferred(&"disabled", false)
	_broken = false
	_fall_vy = 0.0
	create_tween().tween_property(_sprite, "modulate:a", 1.0, 0.4)
