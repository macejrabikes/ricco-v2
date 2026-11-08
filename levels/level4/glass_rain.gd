extends Node2D
## Padajúce sklo zo stropu zimnej záhrady (kapitola IV – útek z horiacej vily): kým je Ricco v izbe, každú chvíľu
## praskne tabuľa nad ním (cinknutie a iskrička pod stropom = varovanie), o chvíľu letí dolu črep. Kto pod ním
## stojí, porežie sa (1 zásah). Kto beží, uhne.
## Izba = obdĺžnik x_min…x_max, ceiling_y…floor_y v súradniciach sveta. Godot docs: classes/class_sprite2d

signal first_shard   ## prvý črep (level povie hlášku)

const SHARD := preload("res://levels/level4/art/glass_shard.png")

@export var x_min: float = 0.0
@export var x_max: float = 1200.0
@export var ceiling_y: float = 360.0
@export var floor_y: float = 560.0
@export var interval: float = 1.3       ## s – ako často (náhodne ±30 %)
@export var warn_time: float = 0.45     ## s – od cinknutia po pád

var _t: float = 1.0
var _shards: Array[Dictionary] = []    ## {s: Sprite2D, v: float, wait: float}
var _player: Node2D
var _first: bool = true


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		if _player == null:
			return
	var p: Vector2 = _player.global_position
	var inside: bool = p.x >= x_min and p.x <= x_max and p.y > ceiling_y and p.y <= floor_y + 4.0
	if inside and int(_player.get(&"state")) != 3:
		_t -= delta
		if _t <= 0.0:
			_t = interval * randf_range(0.7, 1.3)
			var vx: float = (_player as CharacterBody2D).velocity.x if _player is CharacterBody2D else 0.0
			_spawn(clampf(p.x + vx * 0.5 + randf_range(-40.0, 40.0), x_min + 8.0, x_max - 8.0))
	for i in range(_shards.size() - 1, -1, -1):
		var d: Dictionary = _shards[i]
		var s: Sprite2D = d.s
		if d.wait > 0.0:
			d.wait -= delta
			s.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.05)
			continue
		s.modulate.a = 1.0
		d.v += 1100.0 * delta
		s.position.y += d.v * delta
		s.rotation += delta * 6.0
		var hit: bool = false
		if _player and absf(s.global_position.x - _player.global_position.x) < 9.0 \
				and s.global_position.y > _player.global_position.y - 42.0 and s.global_position.y < _player.global_position.y:
			hit = true
			if _player.has_method(&"take_damage") and int(_player.get(&"state")) != 3:
				_player.call(&"take_damage", 1, s.global_position)
		if hit or s.global_position.y >= floor_y:
			Sfx.play(&"glass_break", s.global_position, -6.0, 0.15)
			Burst.spawn(get_parent(), Vector2(s.global_position.x, minf(s.global_position.y, floor_y)), Vector2.UP,
					Color(0.85, 0.95, 1.0), 6, 90.0, Vector2(0, 400), 0.5)
			s.queue_free()
			_shards.remove_at(i)


func _spawn(x: float) -> void:
	var s := Sprite2D.new()
	s.texture = SHARD
	s.z_index = 3
	add_child(s)
	s.global_position = Vector2(x, ceiling_y + 8.0)
	_shards.append({"s": s, "v": 0.0, "wait": warn_time})
	Sfx.play(&"glass_break", s.global_position, -18.0, 0.3)   # prasklo – varovanie
	Burst.spawn(get_parent(), s.global_position, Vector2.DOWN, Color(0.9, 0.97, 1.0), 2, 30.0, Vector2(0, 100), 0.3)
	if _first:
		_first = false
		first_shard.emit()
