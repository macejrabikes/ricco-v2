extends Node2D
## Zamatový záves v zrkadlovej sieni (kapitola IV – boss Margaret, 2. fáza): kopnutý svietnik ho zapáli, oheň ide
## od spodku hore, popáli Ricca, keď do neho vojde, a po čase dohorí na čierne cáre. Susedné závesy zapaľuje level
## (mirror_hall.gd – oheň sa šíri). Poloha uzla = horný stred závesu (garniža).
## Deti (píše ich _art_src/make_mirror_hall_scene.py): Sprite (2 snímky: záves / ohorené cáre),
## Flames (3 snímky plameňov – striedajú sa), Glow (žiara), Hurt (Area2D na spodku – tu páli).
## Godot docs: classes/class_area2d, classes/class_tween

signal ignited
signal burnt_out

@export var height: float = 262.0        ## px – dĺžka závesu (od garniže po zem)
@export var burn_time: float = 22.0      ## s – ako dlho horí, kým z neho ostanú cáre
@export var player_damage: int = 1

enum S { HANGING, BURNING, BURNT }

var state: S = S.HANGING
var _t: float = 0.0
var _anim: float = 0.0
var _hurt_cd: float = 0.0
var _flames: Sprite2D
var _glow: CanvasItem
var _sprite: Sprite2D
var _hurt: Area2D
var _crackle: Node


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_flames = get_node_or_null(^"Flames") as Sprite2D
	_glow = get_node_or_null(^"Glow") as CanvasItem
	_hurt = get_node_or_null(^"Hurt") as Area2D
	if _flames:
		_flames.visible = false
	if _glow:
		_glow.visible = false


func is_burning() -> bool:
	return state == S.BURNING


func ignite() -> void:
	if state != S.HANGING:
		return
	state = S.BURNING
	_t = 0.0
	if _flames:
		_flames.visible = true
		_flames.scale.y = 0.3
		create_tween().tween_property(_flames, "scale:y", 1.0, 2.5).set_trans(Tween.TRANS_SINE)
	if _glow:
		_glow.visible = true
		_glow.modulate.a = 0.0
		create_tween().tween_property(_glow, "modulate:a", 1.0, 1.5)
	Sfx.play(&"fuse", global_position + Vector2(0, height - 40.0), -6.0, 0.1)
	_crackle = Sfx.loop(&"fuse", self, global_position + Vector2(0, height * 0.6), -16.0)
	ignited.emit()


func _process(delta: float) -> void:
	if state != S.BURNING:
		return
	_t += delta
	_anim += delta * 10.0
	if _flames:
		_flames.frame = int(_anim) % 3
	if _glow:
		_glow.scale = Vector2.ONE * (1.0 + sin(_anim * 0.7) * 0.06)
	_hurt_cd -= delta
	if _hurt and _hurt_cd <= 0.0:
		for b in _hurt.get_overlapping_bodies():
			if b.is_in_group(&"player") and b.has_method(&"take_damage") and int(b.get(&"state")) != 3:
				_hurt_cd = 1.0
				b.call(&"take_damage", player_damage, global_position + Vector2(0, height - 30.0))
	if randf() < delta * 3.0:   # iskry a popol
		Burst.spawn(get_parent(), global_position + Vector2(randf_range(-14.0, 14.0), randf_range(height * 0.3, height - 10.0)),
				Vector2.UP, Color(1.0, 0.62, 0.2), 3, 40.0, Vector2(0, -30), 0.8)
	if _t >= burn_time:
		_burn_out()


func _burn_out() -> void:
	state = S.BURNT
	if _sprite:
		_sprite.frame = 1
	if _crackle and is_instance_valid(_crackle):
		_crackle.queue_free()
	var tw := create_tween().set_parallel(true)
	if _flames:
		tw.tween_property(_flames, "modulate:a", 0.0, 1.2)
	if _glow:
		tw.tween_property(_glow, "modulate:a", 0.0, 1.5)
	Burst.spawn(get_parent(), global_position + Vector2(0, height * 0.5), Vector2.UP, Color(0.3, 0.28, 0.3, 0.6), 12, 30.0, Vector2(0, -20), 1.2)
	burnt_out.emit()
