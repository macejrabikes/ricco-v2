extends StaticBody2D
## Cvičný terč (plechovka, na strelnici aj fľaša). Po zásahu sa rozletí na kúsky a po chvíli sa znova objaví.
## Na strelnici (levels/range/shooting_range.gd, skupina shooting_range) pripočíta body.

@export var hp_max: int = 1
@export var respawn_time: float = 2.0
@export var debris_color: Color = Color(0.75, 0.16, 0.16)   ## farba úlomkov (fľaša = zelená/hnedá)
@export var break_sound: StringName = &""                   ## zvuk rozbitia (fľaša = glass_break)
@export var points: int = 10

var hp: float
@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	hp = hp_max


func take_hit(damage: float, dir: Vector2) -> void:
	if not sprite.visible:   # už rozbitá (ďalší brok z tej istej rany)
		return
	hp -= maxf(damage, 1.0)   # plechovku zhodí každý zásah, aj slabý z diaľky
	if hp > 0:
		sprite.modulate = Color(3, 3, 3)  # biely záblesk
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.1)
		return
	Burst.spawn(get_parent(), global_position, dir + Vector2(0, -0.8), debris_color, 14, 140.0)
	if break_sound != &"":
		Sfx.play(break_sound, global_position, -4.0, 0.12)
	get_tree().call_group(&"shooting_range", &"add_score", points, global_position + Vector2(0, -14))
	sprite.visible = false
	shape.set_deferred("disabled", true)
	await get_tree().create_timer(respawn_time, false).timeout  # počas pauzy stojí
	hp = hp_max
	sprite.visible = true
	shape.set_deferred("disabled", false)
