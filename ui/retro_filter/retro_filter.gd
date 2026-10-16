extends CanvasLayer
## Retro filter (starý film) – zapína sa v pause menu → Settings → RETRO FILTER.
## Vrstva 6: nad hrou aj nad spomalením (5), pod HUD (10).

@onready var rect: ColorRect = $Rect


func _ready() -> void:
	GameSettings.ensure_loaded()


func _process(_delta: float) -> void:
	visible = GameSettings.retro_filter
