class_name Explosion
extends Sprite2D
## Výbuch (dynamit, sud whisky, kabína žeriavu): ohnivá guľa z 8 snímok (effects/art/explosion.png), tlaková vlna,
## záblesk cez celú obrazovku, iskry, triesky a dym, ktorý ešte chvíľu stúpa, sadza na palube a zatrasenie kamery.
## Zraní Ricca v dosahu (a odhodí ho), bossa (blast_hit), zabije gangstrov v dosahu (take_hit), rozbije debny (shatter)
## a odpáli sudy (ignite) – reťazová reakcia.
## Použitie: Explosion.spawn(get_tree().current_scene, pos, 1.0)
## Godot docs: classes/class_sprite2d (hframes), classes/class_tween, classes/class_canvaslayer

const SHEET := preload("res://effects/art/explosion.png")
const RING := preload("res://effects/art/shock_ring.png")
const SCORCH := preload("res://effects/art/scorch.png")
const GLOW := preload("res://levels/level1/art/glow.png")
const FRAME_TIME := 0.055
const ENEMY_DAMAGE := 10.0   ## gangster v dosahu výbuchu (3 – 5 HP) neprežije

var size: float = 1.0
var _t: float = 0.0


## size 1 = dynamit (dosah ~48 px). damage = kúsky pizze pre Ricca, boss_damage = HP bossa (0 = bossa nezraní).
static func spawn(parent: Node, pos: Vector2, size_: float = 1.0, damage: int = 2, boss_damage: float = 0.0,
		radius: float = 48.0, flash: bool = true) -> Explosion:
	var e := Explosion.new()
	e.size = size_
	parent.add_child(e)
	e.global_position = pos
	e._boom(damage, boss_damage, radius * size_, flash)
	return e


func _ready() -> void:
	texture = SHEET
	hframes = 8
	frame = 0
	z_index = 9
	offset = Vector2(0, -25)   # spodok ohnivej gule je na y ~57 snímky → výbuch sedí na zemi
	scale = Vector2.ONE * size
	rotation = randf_range(-0.15, 0.15)


func _process(delta: float) -> void:
	_t += delta
	var f: int = int(_t / FRAME_TIME)
	if f >= hframes:
		queue_free()
		return
	frame = f


func _boom(damage: int, boss_damage: float, radius: float, flash: bool) -> void:
	var pos: Vector2 = global_position
	var scene := get_parent()
	var snd := Sfx.play(&"explosion", pos, 2.0 + 2.0 * (size - 1.0), 0.0)
	if snd:
		snd.set(&"pitch_scale", randf_range(1.05, 1.15) / sqrt(size))   # väčší výbuch = hlbší
	# tlaková vlna a záblesk na mieste
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ring := Sprite2D.new()
	ring.texture = RING
	ring.material = m
	ring.z_index = 10
	ring.scale = Vector2(0.2, 0.12) * size
	scene.add_child(ring)
	ring.global_position = pos + Vector2(0, -8)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(2.6, 1.3) * size, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ring.queue_free)
	var glow := Sprite2D.new()
	glow.texture = GLOW
	glow.material = m
	glow.modulate = Color(1.0, 0.7, 0.35, 1.0)
	glow.scale = Vector2.ONE * 2.2 * size
	glow.z_index = 8
	scene.add_child(glow)
	glow.global_position = pos + Vector2(0, -14)
	var tw2 := glow.create_tween()
	tw2.tween_property(glow, "scale", Vector2.ONE * 3.4 * size, 0.15)
	tw2.tween_property(glow, "modulate:a", 0.0, 0.6)
	tw2.tween_callback(glow.queue_free)
	# iskry, triesky, čierne kúsky, dym (ešte chvíľu stúpa)
	Burst.spawn(scene, pos + Vector2(0, -10), Vector2(0, -1), Color(1.0, 0.85, 0.4), int(16 * size), 220.0 * size, Vector2(0, 300), 0.5)
	Burst.spawn(scene, pos + Vector2(0, -6), Vector2(0, -1), Color(0.18, 0.14, 0.12), int(10 * size), 200.0 * size, Vector2(0, 700), 0.8)
	Burst.spawn(scene, pos + Vector2(0, -20), Vector2(0, -1), Color(0.3, 0.29, 0.31, 0.65), int(16 * size), 40.0, Vector2(0, -40), 1.8)
	Burst.spawn(scene, pos + Vector2(0, -30), Vector2(0, -1), Color(0.2, 0.19, 0.21, 0.5), int(10 * size), 25.0, Vector2(-8, -30), 2.6)
	# sadza na palube pod výbuchom
	var floor_hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(pos + Vector2(0, -4), pos + Vector2(0, 40), 1))
	if not floor_hit.is_empty() and floor_hit.normal.y < -0.6:
		var s := Sprite2D.new()
		s.texture = SCORCH
		s.z_index = 1
		s.scale = Vector2(size, 1.0)
		scene.add_child(s)
		s.global_position = floor_hit.position + Vector2(0, -2)
		var tw3 := s.create_tween()
		tw3.tween_interval(25.0)
		tw3.tween_property(s, "modulate:a", 0.0, 3.0)
		tw3.tween_callback(s.queue_free)
	# biely záblesk cez obrazovku
	if flash:
		var layer := CanvasLayer.new()
		layer.layer = 29
		scene.add_child(layer)
		var r := ColorRect.new()
		r.color = Color(1.0, 0.92, 0.75, 0.28 * minf(size, 1.5))
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(r)
		var tw4 := r.create_tween()
		tw4.tween_property(r, "color:a", 0.0, 0.18)
		tw4.tween_callback(layer.queue_free)
	var tree := get_tree()
	# Ricco
	var player := tree.get_first_node_in_group(&"player") as Node2D
	if player and player.get(&"state") != 3:
		var d: Vector2 = (player.global_position + Vector2(0, -16)) - pos
		if damage > 0 and d.length() < radius and not player.get(&"submerged"):
			player.take_damage(damage, pos)
			player.velocity = Vector2(signf(d.x) if d.x != 0.0 else 1.0, -0.8).normalized() * (220.0 + 60.0 * size)
		if d.length() < 360.0 * size:
			player.set(&"shake_timer", 0.3 + 0.15 * size)
			player.set(&"shake_strength", lerpf(5.0 + 2.0 * size, 1.5, clampf(d.length() / (360.0 * size), 0.0, 1.0)))
	# boss
	if boss_damage > 0.0:
		for b in tree.get_nodes_in_group(&"boss"):
			var bn := b as Node2D
			if bn and bn.global_position.distance_to(pos) < radius + 20.0 and bn.has_method(&"blast_hit"):
				bn.blast_hit(boss_damage, Vector2(signf(bn.global_position.x - pos.x), -0.6))
	# gangstri v dosahu (sud benzínu, nádrž s palivom…) – nie bossovia (blast_hit vyššie) ani nezraniteľní (collision_layer 0,
	# napr. Mancini na útese); výbuch bez damage (cutscéna) nezraní nikoho. Meria sa k stredu tela (pôvod gangstra = nohy).
	if damage > 0:
		for g in tree.get_nodes_in_group(&"enemies"):
			var gn := g as CollisionObject2D
			if gn == null or gn.is_in_group(&"boss") or gn.collision_layer == 0 or not gn.has_method(&"take_hit"):
				continue
			var gd: Vector2 = (gn.global_position + Vector2(0, -30)) - pos
			if gd.length() < radius + 12.0:
				gn.take_hit(ENEMY_DAMAGE, Vector2(signf(gd.x) if gd.x != 0.0 else 1.0, -0.6).normalized())
	# debny a sudy v dosahu
	for c in tree.get_nodes_in_group(&"ship_cover"):
		var cn := c as Node2D
		if cn and cn.global_position.distance_to(pos) < radius + 14.0 and cn.has_method(&"shatter"):
			cn.shatter(Vector2(signf(cn.global_position.x - pos.x), -1.0))
	for c in tree.get_nodes_in_group(&"ship_barrel"):
		var bb := c as Node2D
		if bb and bb.global_position.distance_to(pos) < radius + 16.0 and bb.has_method(&"ignite"):
			bb.ignite(0.18)
