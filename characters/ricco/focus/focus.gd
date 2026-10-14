class_name Focus
extends Node
## Spomalenie času („focus“) – duch Dona na chvíľu spomalí svet okolo Ricca (ako v My Friend Pedro).
##  - Shift (akcia "focus") zapne/vypne spomalenie,
##  - kým beží, míňa sa ukazovateľ; keď dôjde, spomalenie skončí samo,
##  - po skončení sa ukazovateľ po chvíli pomaly dobíja (neskôr aj za zabitia/štýl),
##  - obrazovka sa odfarbí do modra, okraje stmavnú a za Riccom ostávajú duchovské odlesky.
## Spomalenie = Engine.time_scale (Godot docs: classes/class_engine – ovplyvní delta v _process,
## _physics_process, Timer aj Tween). Ukazovateľ a prechody bežia v reálnom čase
## (Tween.set_ignore_time_scale), aby sa spomalenie nespomaľovalo samo.

signal changed(value: float, active: bool)

@export_range(0.05, 1.0) var slow_scale: float = 0.3   ## rýchlosť sveta počas spomalenia
@export var duration: float = 4.0          ## s (reálne) – plný ukazovateľ vydrží toľko
@export var recharge_time: float = 12.0    ## s (reálne) – z prázdneho na plný
@export var recharge_delay: float = 0.8    ## s – po skončení chvíľu nič, potom sa dobíja
@export_range(0.0, 1.0) var min_to_start: float = 0.15  ## pod touto hodnotou sa nedá zapnúť
@export var blend_time: float = 0.18       ## s – prechod do/zo spomalenia
@export var afterimage_interval: float = 0.05  ## s (reálne) – ako často ostane odlesok
@export var afterimage_life: float = 0.35      ## s (reálne)

@onready var overlay_rect: ColorRect = $Overlay/Rect

var meter: float = 1.0
var active: bool = false
var _since_end: float = 99.0
var _afterimage_timer: float = 0.0
var _tween: Tween


func _ready() -> void:
	_ensure_input()
	overlay_rect.visible = false
	_set_strength(0.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # pri zmene levelu nesmie ostať svet spomalený


## Akcia "focus" (Shift). Zatiaľ sa pridá v kóde, neskôr ju presunieme do Project Settings → Input Map.
static func _ensure_input() -> void:
	if InputMap.has_action(&"focus"):
		return
	InputMap.add_action(&"focus")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SHIFT
	InputMap.action_add_event(&"focus", ev)


func _process(delta: float) -> void:
	var real: float = delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	if Input.is_action_just_pressed(&"focus"):
		if active:
			stop()
		elif meter >= min_to_start:
			start()
	if active:
		meter = maxf(meter - real / duration, 0.0)
		if meter <= 0.0:
			stop()
		_afterimage_timer -= real
		if _afterimage_timer <= 0.0:
			_afterimage_timer = afterimage_interval
			_spawn_afterimage()
	else:
		_since_end += real
		if _since_end >= recharge_delay:
			meter = minf(meter + real / recharge_time, 1.0)
	changed.emit(meter, active)


func start() -> void:
	active = true
	_afterimage_timer = 0.0
	overlay_rect.visible = true
	_blend(slow_scale, 1.0)


func stop() -> void:
	active = false
	_since_end = 0.0
	_blend(1.0, 0.0)


func _blend(time_scale: float, strength: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_tween.tween_property(Engine, "time_scale", time_scale, blend_time)
	_tween.tween_method(_set_strength, _get_strength(), strength, blend_time)
	if strength == 0.0:
		_tween.chain().tween_callback(func(): overlay_rect.visible = false)


func _get_strength() -> float:
	return overlay_rect.material.get_shader_parameter("strength")


func _set_strength(v: float) -> void:
	overlay_rect.material.set_shader_parameter("strength", v)


## Duchovský odlesok: kópia aktuálneho frame-u Ricca, modrá, postupne zmizne.
func _spawn_afterimage() -> void:
	var ricco := get_parent() as CharacterBody2D
	if ricco == null or ricco.velocity.length() < 30.0:
		return  # pri státí by sa odlesky kopili na jednom mieste
	var spr: AnimatedSprite2D = ricco.sprite
	var img := Sprite2D.new()
	img.texture = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	img.offset = spr.offset
	img.centered = spr.centered
	img.modulate = Color(0.45, 0.85, 1.0, 0.55)
	img.z_index = -1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	img.material = mat
	get_tree().current_scene.add_child(img)
	img.global_transform = spr.global_transform
	var tw := img.create_tween().set_ignore_time_scale(true)
	tw.tween_property(img, "modulate:a", 0.0, afterimage_life)
	tw.tween_callback(img.queue_free)
