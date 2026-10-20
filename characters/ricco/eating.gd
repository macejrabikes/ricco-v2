class_name RiccoEating
extends Node2D
## Animácie jedenia (kláves V, Food v props/food/food.gd). Uzol je dieťa Riccovho Visual, takže súradnice sú
## „pozerá doprava“ (zrkadlí sa s ním). Hlava sa záklonom otáča okolo nôh: tilt < 0 = hlava dozadu.
## Každé jedlo má vlastnú krátku scénku (tween), v chvíli prehltnutia vyšle `gulped` (Ricco sa vylieči),
## na konci `finished`. Zrušiť sa dá cancel() (zásah, skok) – jedlo vtedy ostane v zásobe.
## Godot docs: classes/class_tween (tween_callback, tween_method, set_parallel), classes/class_sprite2d

signal gulped(kind: StringName)
signal finished

const BEAK := Vector2(8, -20)           ## špička zobáka (z idle obrázka: oranžové pixely 33–39 × 32–34 v 64×64, stred (0, -21))
const HAND := Vector2(11, -11)          ## kde drží jedlo pri tele (plutva)
const SPRITE_POS := Vector2(0, -21)     ## pokojová poloha AnimatedSprite2D v Visual
const DROP := preload("res://weapons/pistol/magazine_drop.tscn")

var tilt: float = 0.0                   ## rad – záklon hlavy (otáča sa celý obrázok okolo nôh)
var squash: Vector2 = Vector2.ONE       ## prehltnutie – obrázok sa na chvíľu stlačí
var shiver: float = 0.0                 ## px – trasenie (espresso, mrazivé spumoni)
var kind: StringName = &""
var _sprite: AnimatedSprite2D
var _tw: Tween
var _item: Sprite2D
var _extra: Array[Node2D] = []
var _active: bool = false


func setup(sprite: AnimatedSprite2D) -> void:
	_sprite = sprite


func is_active() -> bool:
	return _active


func start(k: StringName) -> void:
	cancel()
	kind = k
	_active = true
	_item = _sprite_of(k, HAND)
	_tw = create_tween()
	match k:
		&"pizza": _pizza()
		&"sardines": _sardines()
		&"cannoli": _cannoli()
		&"espresso": _espresso()
		&"salami": _salami()
		&"spumoni": _spumoni()
		&"herring": _herring()
		_: _pizza()
	_tw.tween_callback(_done)


## Prerušené (zásah, skok, cutscéna) – jedlo nezjedol, všetko sa vráti do pokoja
func cancel() -> void:
	if not _active:
		return
	_active = false
	if _tw:
		_tw.kill()
	_cleanup()


func _process(_delta: float) -> void:
	if _sprite == null or not _active and tilt == 0.0 and squash == Vector2.ONE and shiver == 0.0:
		return
	var jitter := Vector2(randf_range(-shiver, shiver), 0.0).round() if shiver > 0.0 else Vector2.ZERO
	_sprite.rotation = tilt
	_sprite.position = SPRITE_POS.rotated(tilt) + jitter
	_sprite.scale = squash


# ---------------------------------------------------------------- pomocné

func _sprite_of(k: StringName, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Food.texture(k)
	s.position = at
	s.z_index = 1
	add_child(s)
	s.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(s, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_extra.append(s)
	return s


## Bod v tomto uzle → svet (na častice a vyhodené obaly)
func _world(p: Vector2) -> Vector2:
	return to_global(p)


func _crumbs(col: Color, n: int = 4) -> void:
	Burst.spawn(get_tree().current_scene, _world(BEAK + Vector2(2, 2)), Vector2(get_parent().scale.x, -0.4), col, n, 40.0, Vector2(0, 260), 0.35)


func _bite(col: Color, shrink_to: float) -> void:
	_tw.tween_property(_item, "position", BEAK + Vector2(4, 1), 0.08)
	_tw.tween_callback(func():
		Sfx.play(&"chomp", Vector2.INF, -6.0, 0.15)
		_crumbs(col)
		squash = Vector2(1.04, 0.97))
	_tw.tween_property(_item, "scale:x", shrink_to, 0.04)
	_tw.tween_callback(func(): squash = Vector2.ONE)
	_tw.tween_property(_item, "position", BEAK + Vector2(7, 2), 0.12)


## Hlt – stlačí sa a (len pri prvom hlte, heal = true) Ricco sa vylieči
func _gulp(heal: bool = true) -> void:
	_tw.tween_callback(func():
		Sfx.play(&"gulp", Vector2.INF, -4.0, 0.1)
		if heal:
			gulped.emit(kind))
	_tw.tween_method(func(v: float): squash = Vector2(1.0 + 0.1 * v, 1.0 - 0.12 * v), 0.0, 1.0, 0.07)
	_tw.tween_method(func(v: float): squash = Vector2(1.0 + 0.1 * v, 1.0 - 0.12 * v), 1.0, 0.0, 0.16).set_trans(Tween.TRANS_BACK)


func _tilt_to(r: float, t: float) -> void:
	_tw.tween_property(self, "tilt", r, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Vyhodí prázdny obal (plechovku, pohár) – odletí dozadu a chvíľu leží na zemi
func _toss(s: Sprite2D) -> void:
	_tw.tween_callback(func():
		if not is_instance_valid(s):
			return
		var d := DROP.instantiate()
		d.texture = s.texture
		d.silent = false
		get_tree().current_scene.add_child(d)
		d.global_position = s.global_position
		d.velocity = Vector2(-get_parent().scale.x * randf_range(50.0, 80.0), -140.0)
		d.spin = randf_range(-10.0, 10.0)
		d.life = 2.5
		s.visible = false)


func _done() -> void:
	_active = false
	_cleanup()
	finished.emit()


func _cleanup() -> void:
	for n in _extra:
		if is_instance_valid(n):
			n.queue_free()
	_extra.clear()
	_item = null
	var back := create_tween().set_parallel(true)
	back.tween_property(self, "tilt", 0.0, 0.12)
	back.tween_property(self, "squash", Vector2.ONE, 0.12)
	back.tween_property(self, "shiver", 0.0, 0.05)
	back.chain().tween_callback(func():
		if _sprite and not _active:
			_sprite.rotation = 0.0
			_sprite.position = SPRITE_POS
			_sprite.scale = Vector2.ONE)


# ---------------------------------------------------------------- jedlá

## Pizza: k zobáku a tri hryzy, kúsok sa zmenšuje
func _pizza() -> void:
	_item.rotation = -0.5
	_tw.tween_property(_item, "position", BEAK + Vector2(7, 2), 0.18).set_trans(Tween.TRANS_QUAD)
	for k in [0.66, 0.33, 0.0]:
		_bite(Color(0.92, 0.7, 0.3), k)
	_gulp()


## Sardinky: strhne viečko, zakloní hlavu, plechovku nad zobák, tri rybky skĺznu dnu, prázdnu plechovku zahodí
func _sardines() -> void:
	_item.texture = Food.texture(&"sardines_closed")
	_tw.tween_interval(0.12)
	_tw.tween_callback(func():
		Sfx.play(&"can_peel", Vector2.INF, -6.0, 0.05)
		_item.texture = Food.texture(&"sardines"))
	_tw.tween_property(_item, "rotation", 0.12, 0.06)
	_tw.tween_property(_item, "rotation", 0.0, 0.08)
	_tw.tween_interval(0.12)
	_tw.set_parallel(true)
	_tilt_to(-0.38, 0.22)
	_tw.tween_property(_item, "position", Vector2(11, -33), 0.22).set_trans(Tween.TRANS_QUAD)
	_tw.tween_property(_item, "rotation", -2.3, 0.22)
	_tw.set_parallel(false)
	for i in 3:
		_tw.tween_callback(_fish_drop.bind(Vector2(7 + i, -31)))
		_tw.tween_interval(0.13)
	_tw.tween_interval(0.12)
	_gulp()
	_tilt_to(0.0, 0.16)
	_toss(_item)


## Jedna rybka vypadne z plechovky a skĺzne do zobáka (v čase záklonu je zobák vyššie)
func _fish_drop(from: Vector2) -> void:
	var f := Sprite2D.new()
	f.texture = Food.texture(&"sardine_fish")
	f.position = from
	f.rotation = 1.3
	f.z_index = 1
	add_child(f)
	_extra.append(f)
	var mouth: Vector2 = BEAK.rotated(tilt) + Vector2(-1, -2)
	var t := create_tween()
	t.tween_property(f, "position", mouth, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(f, "scale", Vector2(0.6, 0.6), 0.14)
	t.tween_callback(func():
		Sfx.play(&"chomp", Vector2.INF, -12.0, 0.2)
		f.visible = false)


## Cannoli: dva hryzy, lieta krém
func _cannoli() -> void:
	_tw.tween_property(_item, "position", BEAK + Vector2(7, 2), 0.16).set_trans(Tween.TRANS_QUAD)
	_bite(Color(0.97, 0.94, 0.86), 0.5)
	_bite(Color(0.8, 0.58, 0.32), 0.0)
	_gulp()


## Espresso: šálka k zobáku, záklon, srknutie, para – po ňom sa Ricco chvíľu trasie a behá rýchlejšie
func _espresso() -> void:
	_tw.tween_property(_item, "position", BEAK + Vector2(5, 4), 0.16)
	_tw.set_parallel(true)
	_tilt_to(-0.22, 0.18)
	_tw.tween_property(_item, "rotation", -0.6, 0.18)
	_tw.set_parallel(false)
	_tw.tween_callback(func():
		Sfx.play(&"slurp", Vector2.INF, -6.0, 0.05)
		Burst.spawn(get_tree().current_scene, _world(BEAK + Vector2(6, -2)), Vector2.UP, Color(0.85, 0.85, 0.9, 0.7), 4, 18.0, Vector2(0, -30), 0.6))
	_tw.tween_interval(0.35)
	_gulp()
	_tw.set_parallel(true)
	_tilt_to(0.0, 0.14)
	_tw.tween_property(_item, "modulate:a", 0.0, 0.14)
	_tw.set_parallel(false)
	_tw.tween_property(self, "shiver", 1.0, 0.02)
	_tw.tween_interval(0.25)
	_tw.tween_property(self, "shiver", 0.0, 0.02)


## Saláma: celú ako rybu – zvislo nad zobák, záklon a skĺzne dnu (dva hlty)
func _salami() -> void:
	_tw.set_parallel(true)
	_tw.tween_property(_item, "position", Vector2(11, -37), 0.2).set_trans(Tween.TRANS_QUAD)
	_tw.tween_property(_item, "rotation", PI / 2.0, 0.2)
	_tilt_to(-0.42, 0.2)
	_tw.set_parallel(false)
	_tw.tween_interval(0.08)
	_tw.set_parallel(true)
	_tw.tween_property(_item, "position", Vector2(3, -26), 0.32).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(_item, "scale", Vector2(0.0, 1.0), 0.32).set_ease(Tween.EASE_IN)
	_tw.set_parallel(false)
	_gulp()
	_gulp(false)
	_tilt_to(0.0, 0.16)


## Spumoni: tri olizy, potom „mozog zamrzne“ – modrý záblesk a trasenie
func _spumoni() -> void:
	_tw.tween_property(_item, "position", BEAK + Vector2(5, 0), 0.16)
	for i in 3:
		_tw.tween_property(_item, "position", BEAK + Vector2(3, 1), 0.07)
		_tw.tween_callback(func(): Sfx.play(&"chomp", Vector2.INF, -14.0, 0.25))
		_tw.tween_property(_item, "scale", Vector2.ONE * (1.0 - 0.25 * (i + 1)), 0.03)
		_tw.tween_property(_item, "position", BEAK + Vector2(6, 1), 0.1)
	_gulp()
	_tw.tween_callback(func(): _sprite.modulate = Color(0.72, 0.9, 1.3))
	_tw.tween_property(self, "shiver", 1.0, 0.02)
	_tw.tween_interval(0.3)
	_tw.tween_property(self, "shiver", 0.0, 0.02)
	_tw.tween_callback(func(): _sprite.modulate = Color.WHITE)


## Sleď v pohári: odklopí vrchnák, vytiahne sleďa za chvost, zakloní sa a pustí ho do zobáka
func _herring() -> void:
	_tw.tween_interval(0.1)
	_tw.tween_callback(func():
		Sfx.play(&"lid_pop", Vector2.INF, -4.0, 0.1)
		_item.texture = Food.texture(&"jar_open")
		var l := Sprite2D.new()
		l.texture = Food.texture(&"jar_lid")
		l.position = _item.position + Vector2(0, -8)
		add_child(l)
		_extra.append(l)
		var lt := create_tween()
		lt.tween_property(l, "position", l.position + Vector2(10, -10), 0.18).set_ease(Tween.EASE_OUT)
		lt.parallel().tween_property(l, "rotation", 3.0, 0.3)
		lt.tween_property(l, "position", l.position + Vector2(16, 20), 0.22).set_ease(Tween.EASE_IN)
		lt.tween_callback(func(): l.visible = false))
	_tw.tween_interval(0.2)
	var fish := Sprite2D.new()
	fish.texture = Food.texture(&"herring_fish")
	fish.position = HAND + Vector2(0, -2)
	fish.visible = false
	fish.z_index = 2
	add_child(fish)
	_extra.append(fish)
	_tw.tween_callback(func(): fish.visible = true)
	_tw.set_parallel(true)
	_tw.tween_property(fish, "position", Vector2(10, -36), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tilt_to(-0.45, 0.25)
	_tw.set_parallel(false)
	_tw.tween_property(fish, "rotation", 0.15, 0.08)
	_tw.tween_property(fish, "rotation", -0.15, 0.08)
	_tw.tween_property(fish, "rotation", 0.0, 0.06)
	_tw.set_parallel(true)
	_tw.tween_property(fish, "position", Vector2(2, -26), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(fish, "scale", Vector2(0.4, 0.2), 0.12).set_ease(Tween.EASE_IN)
	_tw.set_parallel(false)
	_tw.tween_callback(func(): fish.visible = false)
	_gulp()
	_tilt_to(0.0, 0.16)
	_toss(_item)
