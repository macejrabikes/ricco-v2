extends StaticBody2D
## Svetlík v streche krajčírskej dielne (kapitola III – strechy, úsek G). Chodiť sa po ňom dá, ale šmyk po bruchu (S),
## tvrdý dopad alebo guľka sklo rozbijú – Ricco prepadne dnu medzi šijacie stroje. Rinčanie skla počujú gangstri
## v dielni (Gangster.noise) a idú sa pozrieť, kde dopadol.
## Uzol = ľavý horný roh svetlíka. Deti: Sprite (skylight.png), Shape (pevný obdĺžnik cez celý svetlík).
## Godot docs: classes/class_staticbody2d

@export var width: float = 60.0
@export var land_limit: float = 300.0     ## px/s – takto rýchly dopad sklo rozbije
@export var noise_radius: float = 300.0
@export var broken_texture: Texture2D

signal shattered

var _player: CharacterBody2D
var _broken: bool = false
var _fall_vy: float = 0.0


func _physics_process(_delta: float) -> void:
	if _broken:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
		return
	var p: Vector2 = to_local(_player.global_position)
	if p.x < 0.0 or p.x > width:
		_fall_vy = 0.0
		return
	if absf(p.y) < 4.0 and _player.is_on_floor():
		if int(_player.get(&"state")) == 4 or _fall_vy > land_limit:   # Ricco.State.SLIDE
			shatter()
		_fall_vy = 0.0
	elif p.y < 0.0:
		_fall_vy = _player.velocity.y


## Guľka do skla
func take_hit(_damage: float, _dir: Vector2) -> void:
	shatter()


func shatter() -> void:
	if _broken:
		return
	_broken = true
	(get_node(^"Shape") as CollisionShape2D).set_deferred(&"disabled", true)
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s and broken_texture:
		s.texture = broken_texture
	var mid: Vector2 = global_position + Vector2(width / 2.0, 4.0)
	Sfx.play(&"glass_break", mid, 2.0, 0.05)
	Sfx.play(&"glass_break", mid + Vector2(0, 60), -4.0, 0.1)
	Burst.spawn(get_parent(), mid, Vector2.DOWN, Color(0.7, 0.85, 0.95), 16, 120.0, Vector2(0, 500), 0.7)
	Gangster.noise(mid + Vector2(0, 100), noise_radius)
	shattered.emit()
