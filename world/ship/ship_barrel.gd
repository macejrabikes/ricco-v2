extends StaticBody2D
## Sud whisky na palube S.S. Margaret – stačí jedna guľka a vybuchne (effects/explosion.gd), na palube po ňom chvíľu horí oheň
## (world/ship/deck_fire.gd). Výbuch zraní aj Big Lou – keď ho Ricco nechá prejsť popri sude, ide to rýchlejšie.
## Výbuch v okolí (dynamit, iný sud) ho odpáli s malým oneskorením → reťazová reakcia.
## Vrstva 4 (ako nepriatelia): Riccove guľky a klobúk ho zasiahnu, Louove a pohyb ním prejdú. Počiatok = stred spodku.
## Uzol „Sprite“ vytvára tools/build_margaret.gd. Godot docs: classes/class_staticbody2d, classes/class_tween

signal exploded

const FIRE := preload("res://world/ship/deck_fire.gd")

@export var blast_size: float = 1.3
@export var boss_damage: float = 4.0
@export var fire_time: float = 14.0   ## s – ako dlho po výbuchu horí paluba (0 = navždy)

var _done: bool = false


func take_hit_at(_damage: float, _dir: Vector2, _pos: Vector2) -> void:
	explode()


func take_hit(_damage: float, _dir: Vector2 = Vector2.ZERO) -> void:
	explode()


func hat_hit(_damage: float, _dir: Vector2) -> void:
	explode()


## Odpáli ho iný výbuch – chvíľu syčí (iskry), potom bum
func ignite(delay: float = 0.15) -> void:
	if _done:
		return
	_done = true
	Burst.spawn(get_parent(), global_position + Vector2(0, -20), Vector2(0, -1), Color(1.0, 0.8, 0.4), 4, 60.0, Vector2(0, 200), 0.3)
	get_tree().create_timer(delay, false).timeout.connect(_boom)


func explode() -> void:
	if _done:
		return
	_done = true
	_boom()


func _boom() -> void:
	var scene := get_tree().current_scene
	var pos: Vector2 = global_position
	collision_layer = 0
	Explosion.spawn(scene, pos, blast_size, 2, boss_damage, 56.0)
	# horiaca whisky sa rozleje po palube
	var f := FIRE.new()
	f.width = 44.0
	f.lifetime = fire_time
	scene.add_child.call_deferred(f)
	f.position = pos
	# obruče a doštičky sudu
	for i in 5:
		Burst.spawn(scene, pos + Vector2(randf_range(-6.0, 6.0), -12.0), Vector2(randf_range(-1.0, 1.0), -1.0),
				Color(0.45, 0.28, 0.16), 2, 200.0, Vector2(0, 600), 0.8)
	exploded.emit()
	queue_free()
