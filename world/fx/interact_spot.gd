class_name InteractSpot
extends Area2D
## Miesto, kde Ricco niečo použije klávesom použiť (F, settings/key_bindings.gd): keď stojí v oblasti,
## nad miestom svieti nápoveda „[F] READ“ (veľké písmo, pulzuje – nedá sa prehliadnuť); po stlačení signál used. Tvar (CollisionShape2D) pridá ten, kto ho vytvára.
## Godot docs: classes/class_area2d

signal used

@export var verb: String = "USE"          ## slovo v nápovede (READ, OPEN…)
@export var hint_offset: Vector2 = Vector2(0, -30)
@export var once: bool = true             ## po použití zmizne nápoveda aj oblasť

const FONT := preload("res://ui/fonts/tiny5.ttf")

var _player: Node2D
var _inside: bool = false
var _hint: Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b: Node): if b.is_in_group(&"player"): _player = b as Node2D; _inside = true)
	body_exited.connect(func(b: Node): if b.is_in_group(&"player"): _inside = false)
	_hint = Label.new()
	_hint.add_theme_font_override(&"font", FONT)
	_hint.add_theme_font_size_override(&"font_size", 16)
	_hint.add_theme_color_override(&"font_color", Color8(255, 214, 90))
	_hint.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	_hint.add_theme_constant_override(&"outline_size", 4)
	_hint.z_index = 40
	_hint.visible = false
	add_child(_hint)


func _process(_delta: float) -> void:
	var can: bool = _inside and _player and _player.get(&"state") == 0 and not _player.get(&"in_cutscene")
	_hint.visible = can
	if not can:
		return
	_hint.text = "[%s] %s" % [KeyBindings.short(&"takedown"), verb]
	_hint.reset_size()
	var t: float = Time.get_ticks_msec() * 0.008
	_hint.position = (hint_offset - Vector2(_hint.size.x / 2.0, 8.0) + Vector2(0, sin(t) * 1.5)).round()
	_hint.modulate = Color(1, 1, 1).lerp(Color(1.5, 1.5, 1.3), 0.5 + 0.5 * sin(t * 0.8))   # jemne pulzuje
	if Input.is_action_just_pressed(&"takedown"):
		used.emit()
		if once:
			_inside = false
			set_process(false)
			_hint.visible = false
