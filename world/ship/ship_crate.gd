extends StaticBody2D
## Debna na palube S.S. Margaret = kryt (vrstva sveta – zastaví guľky aj pohľad, dá sa na ňu vyskočiť).
## Guľky (weapons/pistol/bullet.gd → take_hit_at) ju postupne rozbijú: odletujú triesky, debna sa trasie a tmavne,
## pri hp 0 sa rozletí (shatter) – niekedy z nej vypadne krabička nábojov. Dynamit ju rozbije hneď.
## Debna položená na nej spadne o poschodie nižšie. Uzol „Sprite“ s obrázkom vytvára tools/build_margaret.gd.
## Godot docs: classes/class_staticbody2d, classes/class_tween

signal broken

@export var hp: float = 10.0
@export_range(0.0, 1.0) var ammo_chance: float = 0.5   ## šanca, že z rozbitej debny vypadnú náboje

const DROP := preload("res://weapons/pistol/magazine_drop.tscn")
const AMMO := preload("res://props/ammo/ammo_pickup.tscn")
const SPLINTERS := preload("res://characters/lou/splinters.png")
const SIZE := Vector2(30, 20)

var _max: float
var _sprite: Sprite2D
var _base_x: float
var _dead: bool = false


func _ready() -> void:
	_max = hp
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	if _sprite:
		_base_x = _sprite.position.x


## Zásah guľkou (Lou aj Ricco) – triesky, trasenie, debna tmavne
func take_hit_at(damage: float, dir: Vector2, pos: Vector2) -> void:
	if _dead:
		return
	hp -= damage
	Burst.spawn(get_parent(), pos, -dir + Vector2(0, -0.5), Color(0.62, 0.45, 0.27), 4, 70.0, Vector2(0, 400), 0.4)
	Sfx.play(&"knock_wood", pos, -12.0, 0.2)
	if _sprite:
		_sprite.position.x = _base_x + signf(dir.x)
		create_tween().tween_property(_sprite, "position:x", _base_x, 0.08)
		_sprite.modulate = Color.WHITE.lerp(Color(0.55, 0.5, 0.46), clampf(1.0 - hp / _max, 0.0, 1.0))
	if hp <= 0.0:
		shatter(dir)


## Rozletí sa na triesky (aj od výbuchu dynamitu)
func shatter(dir: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	_dead = true
	var scene := get_tree().current_scene
	var c: Vector2 = global_position
	Sfx.play(&"crate_break", c, -2.0, 0.08)
	Burst.spawn(scene, c, Vector2(0, -1), Color(0.55, 0.5, 0.42, 0.6), 12, 60.0, Vector2(0, 80), 0.7)
	for i in 7:
		var d := DROP.instantiate()
		var at := AtlasTexture.new()
		at.atlas = SPLINTERS
		at.region = Rect2((i % 4) * 8, 0, 8, 8)
		d.texture = at
		d.silent = true
		d.life = randf_range(2.0, 3.5)
		scene.add_child(d)
		d.global_position = c + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 6.0))
		d.velocity = Vector2(dir.x * 60.0 + randf_range(-90.0, 90.0), randf_range(-240.0, -120.0))
		d.spin = randf_range(-16.0, 16.0)
	if randf() < ammo_chance:
		var a := AMMO.instantiate()
		scene.add_child.call_deferred(a)
		a.position = c + Vector2(0, -4)   # current_scene je v počiatku
	# debna navrchu spadne dole
	for n in get_tree().get_nodes_in_group(&"ship_cover"):
		var top := n as Node2D
		if top and top != self and absf(top.global_position.x - c.x) < 6.0 \
				and absf(top.global_position.y - (c.y - SIZE.y)) < 3.0 and top.has_method(&"drop_down"):
			top.drop_down(SIZE.y)
	broken.emit()
	queue_free()


## Spodnú debnu rozbili – táto spadne o dy nižšie (a s ňou aj debna navrchu – veža z troch)
func drop_down(dy: float) -> void:
	for n in get_tree().get_nodes_in_group(&"ship_cover"):
		var top := n as Node2D
		if top and top != self and absf(top.global_position.x - global_position.x) < 6.0 \
				and absf(top.global_position.y - (global_position.y - SIZE.y)) < 3.0 and top.has_method(&"drop_down"):
			top.drop_down(dy)
			break
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + dy, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Sfx.play(&"land", global_position, -4.0, 0.1))
