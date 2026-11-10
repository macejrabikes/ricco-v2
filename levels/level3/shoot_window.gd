extends StaticBody2D
## Sklenené okno, ktoré sa dá prestreliť (kapitola III – okno Salovej kancelárie na požiarne schodisko, club_back.gd).
## Kým je celé, je pevné (vrstva 1 – Ricco neprejde, guľky ho trafia). Guľka (take_hit / take_hit_at) alebo klobúk
## (hat_hit) ho rozbije: obrázok rozbitého skla, črepy, zvuk, hluk; tvar sa vypne a dá sa prejsť von. Signál broken.
## glint() – sklo sa zaleskne (nápoveda, že ho treba prestreliť).
## Deti: Sprite (Sprite2D s obrázkom celého skla), Shape (CollisionShape2D). Godot docs: classes/class_staticbody2d

signal broken

@export var broken_texture: Texture2D
@export var noise_radius: float = 260.0

var is_broken: bool = false
var _glint: Tween


func take_hit_at(damage: float, dir: Vector2, _pos: Vector2) -> void:
	take_hit(damage, dir)


func take_hit(_damage: float, dir: Vector2) -> void:
	shatter(dir)


func hat_hit(_damage: int, dir: Vector2) -> void:
	shatter(dir)


func shatter(dir: Vector2 = Vector2.RIGHT) -> void:
	if is_broken:
		return
	is_broken = true
	if _glint:
		_glint.kill()
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s:
		s.modulate = Color.WHITE
		if broken_texture:
			s.texture = broken_texture
	var cs := get_node_or_null(^"Shape") as CollisionShape2D
	if cs:
		cs.set_deferred(&"disabled", true)
	var mid: Vector2 = global_position + (cs.position if cs else Vector2.ZERO)
	Sfx.play(&"glass_break", mid, 0.0, 0.08)
	for k in 3:   # črepy po celej výške okna
		Burst.spawn(get_parent(), mid + Vector2(0, (k - 1) * 28.0), Vector2(signf(dir.x) if dir.x != 0.0 else 1.0, -0.3).normalized(),
				Color(0.75, 0.9, 1.0), 8, 150.0, Vector2(0, 500), 0.7)
	Gangster.noise(mid, noise_radius)
	broken.emit()


## Sklo sa opakovane zaleskne (nápoveda „prestreľ ma“), kým sa nerozbije
func glint() -> void:
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s == null or is_broken:
		return
	if _glint:
		_glint.kill()
	_glint = create_tween().set_loops()
	_glint.tween_property(s, "modulate", Color(2.2, 2.4, 2.6), 0.25)
	_glint.tween_property(s, "modulate", Color.WHITE, 0.35)
	_glint.tween_interval(1.2)
