extends Node2D
## Markíza nad obchodom – pružná plachta ako trampolína (kapitola III, ulica): keď na ňu Ricco dopadne, odrazí ho vysoko hore
## (characters/ricco/ricco.gd – bounce), plachta sa prehne. Navrch sa dá vyskočiť z debny alebo koša.
## Uzol je v ľavom hornom rohu obrázka (pri stene), plocha na dopad je o surface px nižšie (predná hrana).
## Plocha je jednosmerná plošina (skupina "platform") – zospodu sa cez ňu prejde.
## Godot docs: classes/class_staticbody2d, classes/class_tween

@export var texture: Texture2D
@export var surface: float = 18.0      ## px pod uzlom – plocha, na ktorú Ricco dopadne
@export var bounce: float = -430.0     ## px/s – rýchlosť odrazu (záporné = hore)

var _sprite: Sprite2D
var _player: Node2D
var _width: float = 0.0
var _cool: float = 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.centered = false
	add_child(_sprite)
	_width = texture.get_width() if texture else 64.0
	var body := StaticBody2D.new()
	body.add_to_group(&"platform")
	body.position = Vector2(0, surface)
	add_child(body)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(_width - 8.0, 4)
	cs.shape = r
	cs.position = Vector2(_width / 2.0, 2)
	cs.one_way_collision = true
	body.add_child(cs)


func _physics_process(delta: float) -> void:
	_cool -= delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		return
	if _cool > 0.0 or not (_player as CharacterBody2D).is_on_floor():
		return
	var p: Vector2 = to_local(_player.global_position)
	if p.x < 4.0 or p.x > _width - 4.0 or absf(p.y - surface) > 3.0:
		return
	_cool = 0.25
	_player.bounce(bounce)
	Sfx.play(&"land", global_position + Vector2(p.x, surface), -2.0, 0.15)
	# plachta sa prehne a vráti
	var tw := create_tween()
	tw.tween_property(_sprite, "scale:y", 1.35, 0.06)
	tw.tween_property(_sprite, "scale:y", 0.9, 0.1)
	tw.tween_property(_sprite, "scale:y", 1.0, 0.12)
