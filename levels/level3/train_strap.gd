extends Node2D
## Remienok pod stropom vozňa nadzemky (kapitola III – train.tscn). Ricco sa ho chytí vo vzduchu ako háku na mäso
## (characters/ricco/ricco.gd – grab_hook / _process_hook): visí, môže strieľať, skok so smerom = preskočí na ďalší remienok
## (sú 44 px od seba), šmyk (S) = pustí sa. Zo zeme nedočiahne – vyskočí sa z lavice.
## Kto visí, má nohy 79 px nad podlahou – nad hlavami stojacich cestujúcich: nezbadajú ho (Guest – do 70 px)
## a svetlo lámp (LightZone siaha 60 px nad podlahu) ho nechytí.
## Rovnako fungujú háky rekvizitného ťahu v klube The Blue Canary a svorky na rúrach v pivnici (club.tscn, club_back.tscn –
## iný obrázok cez texture).
## Poloha uzla = krúžok (úchyt). Godot docs: classes/class_tween

const TEX := preload("res://levels/level3/art/train/strap.png")

@export var texture: Texture2D   ## iný obrázok (háky rekvizitného ťahu v klube, svorky na rúrach) – krúžok musí byť tiež na (4, 9)

var velocity: Vector2 = Vector2.ZERO   ## remienok stojí – Ricco si ju pri zoskoku pripočíta (ricco.gd číta get(&"velocity"))

var _sprite: Sprite2D
var _player: Node2D
var _held: bool = false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = texture if texture else TEX
	_sprite.centered = false
	_sprite.position = Vector2(-4, -9)   # krúžok je v obrázku na (4, 9), remeň siaha hore k tyči pod stropom
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		if _player == null:
			return
	var held: bool = _player.get(&"_hook") == self
	if held != _held:
		_held = held
		_jiggle()
	if held or not _player.can_grab_hook():
		return
	if _player.hook_hand().distance_to(global_position) < _player.hook_reach:
		_player.grab_hook(self)


## Remeň sa pri chytení / pustení natiahne a pruží späť
func _jiggle() -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "scale:y", 1.12 if _held else 0.92, 0.06)
	tw.tween_property(_sprite, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
