extends StaticBody2D
## Cvičný terč (plechovka). Po zásahu sa rozletí na kúsky a po chvíli sa znova objaví.

@export var hp_max: int = 1
@export var respawn_time: float = 2.0

var hp: int
@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	hp = hp_max


func take_hit(damage: int, dir: Vector2) -> void:
	hp -= damage
	if hp > 0:
		sprite.modulate = Color(3, 3, 3)  # biely záblesk
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.1)
		return
	Burst.spawn(get_parent(), global_position, dir + Vector2(0, -0.8), Color(0.75, 0.16, 0.16), 14, 140.0)
	sprite.visible = false
	shape.set_deferred("disabled", true)
	await get_tree().create_timer(respawn_time).timeout
	hp = hp_max
	sprite.visible = true
	shape.set_deferred("disabled", false)
