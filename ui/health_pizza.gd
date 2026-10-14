extends Control
## Zdravie Ricca ako pizza vľavo hore – Ricco miluje pizzu, každý zásah zje jeden kúsok.
##  NOIR    – krémový lístok s červeno-bielym obrúskom (pizzeria), pizza a „6/8“ čiernym
##  MINIMAL – len pizza a číslo s obrysom
## Efekty: zjedený kúsok odletí a zmizne, pizza sa pri zásahu zatrasie,
## pri málo zdraví bliká načerveno, vyliečený kúsok sa plynulo objaví.
## Obrázky: ui/hud_pizza.png (snímka 0 = tanier, 1–8 = kúsky, 9 = silueta pizze).

const PIZZA: Texture2D = preload("res://ui/hud_pizza.png")
const SLICE := Vector2(24, 24)
const SLICES := 8
const MARGIN := Vector2(8, 8)

const PAPER := Color8(232, 222, 196)
const PAPER_DD := Color8(196, 184, 156)
const INK := Color8(22, 20, 18)
const STAMP := Color8(176, 32, 30)
const CLOTH_RED := Color8(176, 40, 36)
const CLOTH_WHITE := Color8(236, 228, 210)
const CREAM := Color8(245, 235, 209)
const RED := Color8(255, 82, 66)

var health: int = 8
var max_health: int = 8
var _lost_slice: int = -1     ## kúsok, ktorý práve odletel
var _lost_t: float = 1.0
var _gain_slice: int = -1     ## kúsok, ktorý práve pribudol
var _gain_t: float = 1.0
var _shake_t: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	GameSettings.ensure_loaded()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = MARGIN
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		player.health_changed.connect(_on_health_changed)
		health = player.health
		max_health = player.max_health


func _on_health_changed(new_health: int, new_max: int) -> void:
	if new_health < health:
		_lost_slice = _slice_index(new_health)   # posledný zjedený kúsok
		_lost_t = 0.0
		_shake_t = 0.0
	elif new_health > health:
		_gain_slice = _slice_index(new_health - 1)
		_gain_t = 0.0
	health = new_health
	max_health = new_max


## Zdravie môže byť iné ako 8 – kúsky sa rozdelia pomerne
func _slices_for(hp: int) -> int:
	return ceili(float(hp) / float(max_health) * SLICES) if max_health > 0 else 0


func _slice_index(hp: int) -> int:
	return clampi(_slices_for(hp + 1) - 1, 0, SLICES - 1)


func _process(delta: float) -> void:
	var real: float = delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_time += real
	_lost_t = minf(_lost_t + real / 0.45, 1.0)
	_gain_t = minf(_gain_t + real / 0.3, 1.0)
	_shake_t = minf(_shake_t + real / 0.25, 1.0)
	queue_redraw()


func _draw() -> void:
	var noir: bool = GameSettings.hud_style == GameSettings.HudStyle.NOIR
	var low: bool = health > 0 and health <= maxi(1, int(max_health / 4.0))
	var blink: bool = low and fmod(_time, 0.5) < 0.25
	var shake := Vector2.ZERO
	if _shake_t < 1.0:
		shake = Vector2(roundf(sin(_shake_t * 40.0) * 2.0 * (1.0 - _shake_t)), 0)
	var text := "%d/%d" % [health, max_health]
	var pizza_pos: Vector2
	if noir:
		var w: float = 4 + 28 + 5 + PixelDigits.text_width("88/88") + 5
		var h: float = 36
		size = Vector2(w + 2, h + 2)
		draw_rect(Rect2(2, 2, w, h), Color(0, 0, 0, 0.45))          # tieň
		draw_rect(Rect2(0, 0, w, h), PAPER)
		for x in range(0, int(w), 3):
			draw_rect(Rect2(x, 0, 1, 1), PAPER_DD)
			draw_rect(Rect2(x + 1, h - 1, 1, 1), PAPER_DD)
		draw_rect(Rect2(2, 2, w - 4, 1), INK)
		draw_rect(Rect2(2, h - 3, w - 4, 1), INK)
		# červeno-biely kockovaný obrúsok
		var cloth := Rect2(4, 4, 28, 28)
		for cy in 7:
			for cx in 7:
				draw_rect(Rect2(cloth.position + Vector2(cx * 4, cy * 4), Vector2(4, 4)), CLOTH_RED if (cx + cy) % 2 == 0 else CLOTH_WHITE)
		pizza_pos = cloth.position + Vector2(2, 2)
		var tc: Color = STAMP if (health == 0 or blink) else INK
		PixelDigits.draw_text(self, text, Vector2(37, 15), tc, 1, false)
	else:
		size = Vector2(24 + 4 + PixelDigits.text_width("88/88") + 2, 26)
		pizza_pos = Vector2(1, 1)
		PixelDigits.draw_text(self, text, Vector2(29, 10), RED if (health == 0 or blink) else CREAM, 1, true)

	pizza_pos += shake
	_draw_frame(0, pizza_pos, Color.WHITE)                       # tanier
	var shown: int = _slices_for(health)
	for i in shown:
		var c := Color.WHITE
		if i == _gain_slice and _gain_t < 1.0:
			c = Color(1, 1, 1, _gain_t)   # vyliečený kúsok sa objaví
		_draw_frame(1 + i, pizza_pos, c)
	if blink:                                                    # málo zdravia → červený nádych
		_draw_frame(SLICES + 1, pizza_pos, Color(1, 0.1, 0.05, 0.35))
	# zjedený kúsok odletí smerom od stredu a zmizne
	if _lost_t < 1.0 and _lost_slice >= 0:
		var ang: float = (float(_lost_slice) + 0.5) / SLICES * TAU
		var dir := Vector2(sin(ang), -cos(ang))
		var off: Vector2 = (dir * 10.0 * _lost_t + Vector2(0, 8.0 * _lost_t * _lost_t)).round()
		_draw_frame(1 + _lost_slice, pizza_pos + off, Color(1, 1, 1, 1.0 - _lost_t))


func _draw_frame(i: int, pos: Vector2, modulate_color: Color) -> void:
	draw_texture_rect_region(PIZZA, Rect2(pos, SLICE), Rect2(Vector2(i * SLICE.x, 0), SLICE), modulate_color)
