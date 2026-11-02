extends Node2D
## Holuby na streche (kapitola III), čajky na móle (kapitola IV – texture). Kým Ricco ide potichu (zakrádanie, pomalá chôdza), zobú ďalej.
## Keď okolo nich prebehne alebo vedľa nich dopadne, s trepotom vyletia – gangstri v okolí to počujú
## a idú sa pozrieť, kde Ricco je (Gangster.noise). Duch: „Watch the pigeons, kid. They squawk like stool pigeons.“
## Uzol je na rímse/streche pod nohami prvého holuba, ďalšie sedia doprava (spread).
## Godot docs: classes/class_sprite2d, classes/class_tween

signal scattered

@export var count: int = 4
@export var spread: float = 36.0         ## px – šírka kŕdľa
@export var noise_radius: float = 360.0  ## px – kto do takej vzdialenosti počuje trepot krídel
@export var texture: Texture2D           ## iný kŕdeľ (4 snímky vedľa seba ako pigeons.png) – napr. čajky na móle (kapitola IV)

const TEX := preload("res://levels/level3/art/street/pigeons.png")
const NEAR := 46.0          ## px od okraja kŕdľa – tu si Ricca všimnú
const RUN_SPEED := 75.0     ## px/s – rýchlejšie ako zakrádanie (sneak_speed 58) = splašia sa

var _birds: Array[Sprite2D] = []
var _player: Node2D
var _flown: bool = false
var _peck_t: float = 0.5


func _ready() -> void:
	var tex: Texture2D = texture if texture else TEX
	for i in count:
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = 4
		s.centered = false
		s.offset = Vector2(-tex.get_width() / 8.0, -tex.get_height())   # holub 10×8 → (−5, −8)
		s.position = Vector2(spread * i / maxf(1.0, count - 1.0) + randf_range(-2, 2), 0)
		s.flip_h = randf() < 0.5
		add_child(s)
		_birds.append(s)


func _physics_process(delta: float) -> void:
	if _flown:
		return
	# zobanie – občas niektorý skloní hlavu
	_peck_t -= delta
	if _peck_t <= 0.0:
		_peck_t = randf_range(0.3, 0.9)
		var b: Sprite2D = _birds.pick_random()
		b.frame = 1 - b.frame
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		return
	var p: Vector2 = to_local(_player.global_position)
	if p.x < -NEAR or p.x > spread + NEAR or absf(p.y) > 40.0:
		return
	var body := _player as CharacterBody2D
	var loud: bool = absf(body.velocity.x) > RUN_SPEED or (not body.is_on_floor() and body.velocity.y > 160.0)
	if loud:   # prebehol alebo vedľa nich dopadol – zakrádaním sa dá prejsť aj pomedzi ne
		scatter()


## Vyletia preč od Ricca, trepot počujú gangstri
func scatter() -> void:
	if _flown:
		return
	_flown = true
	var away: float = 1.0
	if _player and is_instance_valid(_player):
		away = signf(global_position.x + spread / 2.0 - _player.global_position.x)
		if away == 0.0:
			away = 1.0
		Gangster.noise(_player.global_position, noise_radius)
	Sfx.play(&"pigeon_flap", global_position + Vector2(spread / 2.0, -6), -2.0, 0.1)
	scattered.emit()
	for b in _birds:
		b.flip_h = away < 0.0
		var target: Vector2 = b.position + Vector2(away * randf_range(140, 260), randf_range(-220, -150))
		var tw := create_tween()
		tw.tween_interval(randf_range(0.0, 0.15))
		tw.tween_property(b, "position", target, randf_range(1.2, 1.7)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_method(func(t: float): b.frame = 2 + (int(t * 14.0) % 2), 0.0, 1.0, 1.5)
		tw.tween_callback(b.queue_free)
