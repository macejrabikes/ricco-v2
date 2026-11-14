class_name DeathPrompt
extends CanvasLayer
## Po smrti: chvíľu sa pozerá na pád, potom dole naskočí [F] / [LMB] TRY AGAIN – stlačením sa hneď začne znova
## od posledného checkpointu, inak sa scéna reštartuje sama po delay s (ricco.gd → respawn_delay).
## Počas pauzy stojí (pause menu). Volá ricco.gd → _die().

const READY_AFTER := 0.7   ## s – skôr sa nedá preskočiť (aby to hráč nestlačil omylom v prestrelke)

var _delay: float = 2.5
var _t: float = 0.0
var _done: bool = false
var _hint: InteractHint
var _wrap: Control


static func start(from: Node, delay: float) -> DeathPrompt:
	var d := DeathPrompt.new()
	d._delay = delay
	from.get_tree().current_scene.add_child(d)
	return d


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_wrap = Control.new()   # mizne / naskočí celé (InteractHint si modulate pulzuje sám)
	_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wrap.modulate.a = 0.0
	root.add_child(_wrap)
	_hint = InteractHint.new()
	_wrap.add_child(_hint)
	_hint.set_hint([KeyBindings.short(&"takedown"), KeyBindings.short(&"shoot")], "TRY AGAIN")


func _process(delta: float) -> void:
	_t += delta
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_hint.position = Vector2((vp.x - _hint.size.x) / 2.0, vp.y * 0.78).floor()
	if _t >= READY_AFTER:
		_wrap.modulate.a = move_toward(_wrap.modulate.a, 1.0, delta * 5.0)
		if Input.is_action_just_pressed(&"takedown") or Input.is_action_just_pressed(&"shoot") \
				or Input.is_action_just_pressed(&"jump") or Input.is_action_just_pressed(&"ui_accept"):
			_restart()
	if _t >= _delay:
		_restart()


func _restart() -> void:
	if _done:
		return
	_done = true
	get_tree().reload_current_scene()
