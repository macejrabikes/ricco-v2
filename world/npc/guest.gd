class_name Guest
extends Sprite2D
## Hosť na oslave v pizzerii (nie mafián). Pohráva sa s pohárom / je / tancuje (snímky vedľa seba v obrázku).
## Keď uvidí Ricca na svetle, zľakne sa („!“ nad hlavou) a privolá mafiánov (Gangster.alarm) – Ricco sa musí držať v tme.

@export var loop: bool = false           ## true = snímky stále dookola (tanec, harmonika); false = občas sa napije
@export var fps: float = 5.0
@export var witness: bool = true         ## zbadá Ricca a spustí poplach
@export var see_range: float = 150.0     ## px vodorovne
@export var alarm_range: float = 520.0   ## px – ktorí mafiáni počujú krik

static var _last_alert_ms: int = -100000   ## zvuk „!“ naraz len raz

var _t: float = 0.0
var _seq: Array = []      ## [snímka, trvanie]
var _i: int = 0
var _cool: float = 0.0
var _check: float = 0.0
var player: Node2D
var _mark: Label


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_t = randf_range(0.0, 3.0)


func _process(delta: float) -> void:
	_animate(delta)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D   # Ricco môže byť v strome až po hosťoch
	if not witness or player == null:
		return
	_cool -= delta
	_check -= delta
	if _cool > 0.0 or _check > 0.0:
		return
	_check = 0.15
	if player.get(&"in_cutscene") or player.get(&"state") == 3:
		return
	var d: Vector2 = player.global_position - global_position
	if absf(d.x) < see_range and absf(d.y) < 70.0 and player.has_method(&"is_lit") and player.is_lit():
		_scream()


func _animate(delta: float) -> void:
	if hframes <= 1:
		return
	_t -= delta
	if _t > 0.0:
		return
	if loop:
		frame = (frame + 1) % hframes
		_t = 1.0 / fps
		return
	# pohár ku ústam: 0 (dlho) → 1 → 2 (chvíľu) → 3 → 0
	frame = (frame + 1) % hframes
	match frame:
		0: _t = randf_range(1.5, 4.5)
		2: _t = randf_range(0.6, 1.2)
		_: _t = 0.14


func _scream() -> void:
	_cool = 8.0
	var now := Time.get_ticks_msec()
	if now - _last_alert_ms > 600:
		_last_alert_ms = now
		Sfx.play(&"alert", global_position + Vector2(0, -40), -4.0, 0.02)
	_show_mark()
	for g in get_tree().get_nodes_in_group(&"enemies"):
		if g.has_method(&"alarm") and (g as Node2D).global_position.distance_to(global_position) < alarm_range:
			g.alarm()
	# leknutie – poskočí
	var tw := create_tween()
	tw.tween_property(self, "offset:y", offset.y - 4.0, 0.08)
	tw.tween_property(self, "offset:y", offset.y, 0.12)


## „!“ nad hlavou (ako u mafiánov)
func _show_mark() -> void:
	if _mark == null:
		_mark = Label.new()
		_mark.text = "!"
		_mark.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
		_mark.add_theme_font_size_override(&"font_size", 16)
		_mark.add_theme_color_override(&"font_color", Color8(255, 214, 90))
		_mark.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
		_mark.add_theme_constant_override(&"outline_size", 4)
		_mark.z_index = 30
		add_child(_mark)
	var top: float = get_rect().position.y
	_mark.visible = true
	_mark.modulate.a = 1.0
	_mark.position = Vector2(-3, top - 12.0)
	var tw := create_tween()
	tw.tween_property(_mark, "position:y", top - 18.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(_mark, "modulate:a", 0.0, 0.25)
