extends Area2D
## Oheň na palube (po výbuchu sudu, zrútenom žeriave) – plamene z animovaného pásu (fire_small/fire_big, 6 snímok),
## mihotavé svetlo a praskanie. Ricca popáli (1 kúsok pizze, potom má chvíľu nesmrteľnosť – musí cez oheň preskočiť).
## Big Lou je ohňovzdorný (v 3. fáze ním kráča). harmful = false → len kulisa (horiaca kabína, mostík).
## lifetime 0 = horí stále. Počiatok = stred spodku. Godot docs: classes/class_area2d, classes/class_sprite2d (hframes)

const SMALL := preload("res://levels/level2/art/ship/fire_small.png")
const BIG := preload("res://levels/level2/art/ship/fire_big.png")
const GLOW := preload("res://levels/level1/art/glow.png")
const FPS := 11.0

@export var width: float = 40.0
@export var lifetime: float = 0.0
@export var big: bool = false
@export var harmful: bool = true
@export var sound: bool = true

var _flames: Array[Sprite2D] = []
var _glow: Sprite2D
var _t: float = 0.0
var _dying: bool = false
var _loop: Node


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 if harmful else 0
	monitorable = false
	if z_index == 0:
		z_index = 2
	var tex: Texture2D = BIG if big else SMALL
	var fw: float = tex.get_width() / 6.0
	var n: int = maxi(1, ceili(width / (fw * 0.7)))
	for i in n:
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = 6
		s.frame = randi() % 6
		s.centered = false
		s.offset = Vector2(-fw / 2.0, -tex.get_height() + 1)
		s.position = Vector2(lerpf(-width / 2.0 + fw * 0.35, width / 2.0 - fw * 0.35, (i + 0.5) / n) if n > 1 else 0.0, 0)
		s.scale = Vector2.ONE * randf_range(0.8, 1.05)
		s.flip_h = randf() < 0.5
		s.set_meta(&"phase", randf() * 6.0)
		add_child(s)
		_flames.append(s)
	_glow = Sprite2D.new()
	_glow.texture = GLOW
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.modulate = Color(1.0, 0.55, 0.2, 0.55)
	_glow.position = Vector2(0, -tex.get_height() * 0.4)
	_glow.scale = Vector2.ONE * (0.6 + width / 40.0) * (1.4 if big else 1.0)
	add_child(_glow)
	if harmful:
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(maxf(width - 8.0, 8.0), 14.0)
		cs.shape = r
		cs.position = Vector2(0, -7)
		add_child(cs)
	if sound:
		_loop = Sfx.loop(&"fire_loop", self, Vector2.ZERO, -8.0 if big else -12.0, &"SFX")
	# rozhorí sa
	scale = Vector2(1.0, 0.1)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	for s in _flames:
		s.frame = int(_t * FPS + float(s.get_meta(&"phase"))) % 6
	_glow.modulate.a = 0.45 + 0.15 * sin(_t * 23.0) + 0.08 * sin(_t * 7.0)
	if randf() < delta * 5.0 * _flames.size():   # iskry a dym stúpajú
		var x: float = randf_range(-width / 2.0, width / 2.0)
		Burst.spawn(get_parent(), global_position + Vector2(x, -12.0 * scale.y), Vector2(0, -1), Color(1.0, 0.7, 0.3), 1, 40.0, Vector2(6, -60), 0.6)
		if randf() < 0.35:
			Burst.spawn(get_parent(), global_position + Vector2(x, -24.0 * scale.y), Vector2(0, -1), Color(0.22, 0.2, 0.22, 0.5), 1, 18.0, Vector2(-6, -24), 1.6)
	if lifetime > 0.0 and _t >= lifetime and not _dying:
		_dying = true
		var tw := create_tween()
		tw.tween_property(self, "scale:y", 0.0, 1.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)
	if harmful and not _dying:
		for b in get_overlapping_bodies():
			if b.has_method(&"take_damage") and b.get(&"state") != 3 and b.get(&"invulnerable_timer") <= 0.0:
				b.take_damage(1, global_position + Vector2(0, 10))
				var away: float = signf(b.global_position.x - global_position.x)
				b.set(&"velocity", Vector2((away if away != 0.0 else 1.0) * 140.0, -170.0))   # odskočí od ohňa
