extends Node2D
## Plamene v horiacej vile (kapitola IV – útek, villa_fire.gd): stena ohňa, ktorá zatarasí cestu (block = true, aj guľky
## zastaví), alebo nízky oheň na podlahe, cez ktorý sa dá preskočiť (block = false). Kto doň vojde, popáli sa.
## Poloha uzla = stred spodku plameňov. Deti si stavia sám (plamene z levels/level4/art/flames.png, žiara, kolízie).
## Godot docs: classes/class_area2d, classes/class_staticbody2d, classes/class_canvasitemmaterial

const FLAMES := preload("res://levels/level4/art/flames.png")   ## 3 snímky 48 × 262 (ako horiaci záves)
const GLOW := preload("res://levels/level1/art/glow.png")

@export var width: float = 48.0           ## px
@export var height: float = 206.0         ## px – 206 = od podlahy po strop poschodia
@export var block: bool = true            ## stena (nedá sa prejsť) / nízky oheň (dá sa preskočiť)
@export var player_damage: int = 1
@export var crackle: bool = true          ## praskanie ohňa (slučka) – stačí pár stien na poschodie

var _flames: Array[Sprite2D] = []
var _hurt: Area2D
var _anim: float = 0.0
var _cd: float = 0.0
var _glow: Sprite2D


func _ready() -> void:
	_anim = randf() * 3.0
	var n: int = maxi(1, ceili(width / 36.0))
	var step: float = width / n
	for i in n:
		var s := Sprite2D.new()
		s.texture = FLAMES
		s.hframes = 3
		s.centered = false
		s.scale = Vector2((step + 14.0) / 48.0, height / 262.0)
		s.position = Vector2(-width / 2.0 + i * step - 7.0, -height)
		s.z_index = 1
		s.flip_h = i % 2 == 1
		add_child(s)
		_flames.append(s)
	_glow = Sprite2D.new()
	_glow.texture = GLOW
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.modulate = Color(1.0, 0.5, 0.18, 0.7)
	_glow.scale = Vector2.ONE * clampf(maxf(width, height) / 60.0, 1.0, 4.0)
	_glow.position = Vector2(0, -height * 0.4)
	_glow.z_index = 4
	add_child(_glow)
	if block:
		var b := StaticBody2D.new()
		var bs := CollisionShape2D.new()
		var br := RectangleShape2D.new()
		br.size = Vector2(width, height)
		bs.shape = br
		bs.position = Vector2(0, -height / 2.0)
		b.add_child(bs)
		add_child(b)
	_hurt = Area2D.new()
	_hurt.collision_layer = 0
	_hurt.collision_mask = 2
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(width + (16.0 if block else 0.0), height)
	hs.shape = hr
	hs.position = Vector2(0, -height / 2.0)
	_hurt.add_child(hs)
	add_child(_hurt)
	if crackle:
		Sfx.loop(&"fuse", self, global_position + Vector2(0, -height / 2.0), -18.0)


func _process(delta: float) -> void:
	_anim += delta * 10.0
	for i in _flames.size():
		_flames[i].frame = (int(_anim) + i) % 3
	_glow.modulate.a = 0.6 + sin(_anim * 0.9) * 0.1
	_cd -= delta
	if _cd > 0.0:
		return
	for b in _hurt.get_overlapping_bodies():
		if b.is_in_group(&"player") and b.has_method(&"take_damage") and int(b.get(&"state")) != 3:
			_cd = 1.0
			b.call(&"take_damage", player_damage, global_position + Vector2(0, -20.0))
	if randf() < delta * 2.0:   # iskry
		Burst.spawn(get_parent(), global_position + Vector2(randf_range(-width / 2.0, width / 2.0), -randf_range(10.0, height)),
				Vector2.UP, Color(1.0, 0.62, 0.2), 2, 40.0, Vector2(0, -30), 0.8)
