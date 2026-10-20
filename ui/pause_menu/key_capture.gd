class_name KeyCapture
extends Node
## Zachytí jeden kláves alebo tlačidlo myši pre prestavenie ovládania (ui/pause_menu/menu_pages.gd – keyboard_page).
## Beží aj počas pauzy (process_mode ALWAYS), udalosť zachytí v _input – menu ani pauza ju nedostanú.
## ESC zruší. Godot docs: tutorials/inputs/inputevent (poradie _input → _gui_input → _unhandled_input)

signal done(code: int)

const CANCEL := -999


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var mb := event as InputEventMouseButton
	if key and (not key.pressed or key.echo):
		get_viewport().set_input_as_handled()
		return
	if mb and not mb.pressed:
		get_viewport().set_input_as_handled()
		return
	if key == null and mb == null:
		return   # pohyb myši atď.
	get_viewport().set_input_as_handled()
	var code: int = CANCEL
	if key and key.physical_keycode == KEY_ESCAPE:
		code = CANCEL
	else:
		code = KeyBindings.code_of(event)
		if code == -999:
			return   # koliesko myši – čakaj ďalej
	done.emit(code)
	queue_free()
