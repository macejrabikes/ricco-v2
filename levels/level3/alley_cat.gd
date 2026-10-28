extends StaticBody2D
## Mačka spí na smetiaku vedľa uhoľnej šachty pred klubom (kapitola III – Lenox Avenue). Kto okolo nej beží
## (nie potichu – zakrádanie C), toho zacíti: vyskočí, zhodí veko smetiaka (rinčanie – Gangster.noise) a utečie.
## Vyľaká ju aj hodený klobúk alebo guľka vedľa nej (vrstva 4 ako nepriatelia) – dá sa to urobiť zďaleka, napr.
## z konštrukcie nadzemky. Vyhadzovači pri dverách sa idú pozrieť, čo sa deje (club.gd – signál startled).
## Deti: Sprite (2 snímky – spí / vyľakaná, pozerá doprava), Shape. Poloha uzla = stred mačky.
## Godot docs: classes/class_tween

signal startled

@export var wake_range: float = 70.0    ## px – takto blízko zobudia mačku normálne kroky
@export var sneak_range: float = 18.0   ## px – potichu (alebo keď Ricco stojí) až tesne pri nej

var _gone: bool = false
var _player: Node2D
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 4   # zasiahne ju klobúk aj Riccova guľka
	collision_mask = 0
	_sprite = get_node(^"Sprite") as Sprite2D


func hat_hit(_damage: int, dir: Vector2) -> void:
	if not _gone:
		_startle(signf(dir.x) if dir.x != 0.0 else 1.0)


func take_hit(_damage: float, dir: Vector2) -> void:
	hat_hit(0, dir)


func _process(_delta: float) -> void:
	if _gone:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		return
	var d: Vector2 = _player.global_position - global_position
	if absf(d.y) > 60.0 or _player.get(&"in_cutscene"):
		return
	var v: Variant = _player.get(&"velocity")
	var moving: bool = v is Vector2 and absf((v as Vector2).x) > 20.0
	var r: float = sneak_range if _player.get(&"sneaking") or not moving else wake_range
	if absf(d.x) < r:
		_startle(-signf(d.x) if d.x != 0.0 else 1.0)


func _startle(dir: float) -> void:
	_gone = true
	(get_node(^"Shape") as CollisionShape2D).set_deferred(&"disabled", true)
	_sprite.frame = 1
	_sprite.flip_h = dir < 0.0
	Sfx.play(&"beam_clang", global_position, -14.0, 0.15)
	Gangster.noise(global_position, 220.0)
	startled.emit()
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 14.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y + 24.0, 0.2).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "position:x", position.x + dir * 40.0, 0.35)
	tw.tween_property(self, "position:x", position.x + dir * 240.0, 0.8)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)
