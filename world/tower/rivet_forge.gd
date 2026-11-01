extends Node2D
## Vyhňa na nity (kapitola III – veža Iron Mikea). Kôš so žeravým uhlím na nohách; poloha uzla = zem pod ňou (stred).
## toss_to ≠ 0: ohrievač každých toss_interval s hodí nitu oblúkom chytačovi (catcher – nitovač s vedrom) o toss_to px
##   ďalej – kto vojde do oblúka, popáli sa. Keď je chytač mŕtvy (alebo ho nemá), prestane.
## kick(target): Iron Mike do nej kopne – vyletí spŕška nít smerom k Riccovi (IronMike._kick), vyhňa sa zakolíše.
## Deti: Sprite (forge.png, 2 snímky – pahreba bliká), Glow. Godot docs: classes/class_tween

const RIVET := preload("res://world/tower/hot_rivet.gd")
const TOP := Vector2(0, -21)   ## odkiaľ nity vyletia (vrch koša)

@export var toss_to: float = 0.0
@export var toss_interval: float = 1.8
@export var catcher: NodePath
@export var kick_count: int = 7

var _t: float = 1.0
var _anim: float = 0.0
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite") as Sprite2D


func _process(delta: float) -> void:
	_anim += delta
	if _sprite and _sprite.hframes > 1:
		_sprite.frame = int(_anim * 5.0) % 2
	if toss_to == 0.0:
		return
	var c := get_node_or_null(catcher) as Gangster
	if c == null or c.state == Gangster.State.DEAD or int(c.state) >= 2 and int(c.state) <= 8:
		return   # chytač je mŕtvy alebo bojuje
	_t -= delta
	if _t <= 0.0:
		_t = toss_interval
		var target := global_position + Vector2(toss_to, -44.0)
		var r = _throw(target, 1.0)
		r.catch_x = target.x
		Sfx.play(&"punch_swing", global_position, -16.0, 0.2)


## Nita oblúkom do bodu target za čas t (s)
func _throw(target: Vector2, t: float) -> Node2D:
	var r = RIVET.new()
	var from: Vector2 = global_position + TOP
	r.velocity = Vector2((target.x - from.x) / t, (target.y - from.y - 0.5 * RIVET.GRAVITY * t * t) / t)
	get_tree().current_scene.add_child(r)
	r.global_position = from
	return r


func kick(target: Vector2) -> void:
	Sfx.play(&"metal_crash", global_position, -8.0, 0.1)
	Sfx.play(&"steam_hiss", global_position, -10.0, 0.1)
	Burst.spawn(get_tree().current_scene, global_position + TOP, Vector2.UP, Color(1.0, 0.6, 0.25), 14, 120.0, Vector2(0, 200), 0.6)
	var d: float = maxf(absf(target.x - global_position.x), 40.0)
	for i in kick_count:
		var spread: float = lerpf(-0.45, 0.45, float(i) / maxf(kick_count - 1, 1)) * d + randf_range(-8.0, 8.0)
		var t: float = clampf(d / 200.0, 0.55, 1.1) * randf_range(0.9, 1.15)
		_throw(target + Vector2(spread, randf_range(-10.0, 10.0)), t)
	var tw := create_tween()
	tw.tween_property(self, "rotation", 0.25 * signf(target.x - global_position.x), 0.08)
	tw.tween_property(self, "rotation", -0.12 * signf(target.x - global_position.x), 0.18)
	tw.tween_property(self, "rotation", 0.0, 0.25)
