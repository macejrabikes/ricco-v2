class_name KeyBindings
## Ovládanie z klávesnice a myši: zoznam akcií, predvolené klávesy, prestavenie (Settings → Controls → Keyboard)
## a uloženie do user://settings.cfg (sekcia [keys]). Akcie, ktoré nie sú v project.godot, pridá za behu.
## Prvý kláves akcie je „hlavný“ – ten sa v menu prestavuje, ďalšie sú náhradné (napr. šípky).
## Keď nový kláves už patrí inej akcii, akcie si ho vymenia (nikdy nie sú dve akcie na jednom klávese).
## Všetko je statické – stačí KeyBindings.text(&"jump") kdekoľvek.
## Godot docs: classes/class_inputmap, classes/class_inputeventkey, classes/class_inputeventmousebutton

## Udalosť je číslo: >= 0 = fyzický kláves (Key), < 0 = tlačidlo myši (-1 ľavé, -2 pravé, -3 stredné…)
const ACTIONS := [
	[&"move_left", "MOVE LEFT", [KEY_A, KEY_LEFT]],
	[&"move_right", "MOVE RIGHT", [KEY_D, KEY_RIGHT]],
	[&"jump", "JUMP / CLIMB", [KEY_SPACE, KEY_W, KEY_UP]],
	[&"slide", "BELLY SLIDE", [KEY_S, KEY_DOWN, KEY_CTRL]],
	[&"sneak", "SNEAK", [KEY_C, KEY_ALT]],
	[&"shoot", "SHOOT", [-MOUSE_BUTTON_LEFT]],
	[&"throw_hat", "THROW HAT", [-MOUSE_BUTTON_RIGHT, KEY_E]],
	[&"reload", "RELOAD", [KEY_R]],
	[&"holster", "HOLSTER / DRAW", [KEY_X]],
	[&"eat", "EAT (HEAL)", [KEY_V]],
	[&"focus", "SLOW-MO", [KEY_SHIFT]],
	[&"takedown", "INTERACT / TAKEDOWN", [KEY_F]],
	[&"weapon_1", "SIDEARM", [KEY_1]],
	[&"weapon_2", "PRIMARY 1", [KEY_2]],
	[&"weapon_3", "PRIMARY 2", [KEY_3]],
	[&"weapon_last", "LAST WEAPON", [KEY_Q]],
	[&"pause", "PAUSE", [KEY_ESCAPE, KEY_P]],
	[&"fullscreen", "FULLSCREEN", [KEY_F11]],
]
const SECTION := "keys"

static var _binds: Dictionary = {}   ## akcia → Array[int] (aktuálne klávesy)
static var _done: bool = false


## Pridá chýbajúce akcie a nastaví im klávesy (predvolené alebo uložené). Volá ho GameSettings.ensure_loaded().
static func ensure(cfg: ConfigFile = null) -> void:
	if _done:
		return
	_done = true
	for row in ACTIONS:
		var a: StringName = row[0]
		var list: Array = row[2].duplicate()
		if cfg and cfg.has_section_key(SECTION, String(a)):
			var saved = cfg.get_value(SECTION, String(a))
			if saved is Array and not saved.is_empty():
				list = saved.duplicate()
		_binds[a] = list
		_apply(a)


static func defaults_of(action: StringName) -> Array:
	for row in ACTIONS:
		if row[0] == action:
			return row[2]
	return []


static func save_to(cfg: ConfigFile) -> void:
	for a in _binds:
		cfg.set_value(SECTION, String(a), _binds[a])


static func codes(action: StringName) -> Array:
	return _binds.get(action, defaults_of(action))


## Nový hlavný kláves akcie. Keď ho mala iná akcia, dostane namiesto neho starý hlavný kláves tejto akcie.
static func rebind(action: StringName, code: int) -> void:
	var mine: Array = codes(action).duplicate()
	var old: int = mine[0] if not mine.is_empty() else code
	if old == code:
		return
	for a in _binds:
		if a == action:
			continue
		var other: Array = _binds[a]
		var i: int = other.find(code)
		if i < 0:
			continue
		other.remove_at(i)
		if i == 0 or other.is_empty():
			other.insert(0, old)   # výmena – akcia nesmie ostať bez klávesu
		elif not other.has(old):
			other.insert(i, old)
		_apply(a)
	mine.erase(code)
	if mine.is_empty():
		mine.append(code)
	else:
		mine[0] = code
	_binds[action] = mine
	_apply(action)


static func reset_all() -> void:
	for row in ACTIONS:
		_binds[row[0]] = row[2].duplicate()
		_apply(row[0])


static func _apply(action: StringName) -> void:
	if Engine.is_editor_hint():
		return   # @tool skripty (nápisy kriedou) v editore – InputMap editora nemeníme
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_erase_events(action)
	for c: int in _binds[action]:
		InputMap.action_add_event(action, event_for(c))


static func event_for(code: int) -> InputEvent:
	if code < 0:
		var m := InputEventMouseButton.new()
		m.button_index = -code as MouseButton
		return m
	var k := InputEventKey.new()
	k.physical_keycode = code as Key
	return k


## Číslo udalosti z toho, čo hráč stlačil (pri prestavovaní); -999 = nedá sa použiť
static func code_of(event: InputEvent) -> int:
	var k := event as InputEventKey
	if k:
		return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	var m := event as InputEventMouseButton
	if m and m.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return -m.button_index
	return -999


static func name_of(code: int) -> String:
	if code < 0:
		match -code:
			MOUSE_BUTTON_LEFT: return "LEFT MOUSE"
			MOUSE_BUTTON_RIGHT: return "RIGHT MOUSE"
			MOUSE_BUTTON_MIDDLE: return "MIDDLE MOUSE"
			_: return "MOUSE %d" % -code
	var s := OS.get_keycode_string(code as Key).to_upper()
	return s if s != "" else "KEY %d" % code


## „A / LEFT“ – max klávesov naraz (menu aj nápovedy)
static func text(action: StringName, most: int = 2) -> String:
	var parts: PackedStringArray = []
	for c: int in codes(action):
		if parts.size() >= most:
			break
		parts.append(name_of(c))
	return " / ".join(parts)


## Len hlavný kláves (napr. do nápovedy nad mafiánom: „F“)
static func main(action: StringName) -> String:
	var c: Array = codes(action)
	return name_of(c[0]) if not c.is_empty() else "?"


## Krátky názov hlavného klávesu do malých nápovied v hre (myš = LMB / RMB / MMB)
static func short(action: StringName) -> String:
	var c: Array = codes(action)
	if c.is_empty():
		return "?"
	match c[0]:
		-MOUSE_BUTTON_LEFT: return "LMB"
		-MOUSE_BUTTON_RIGHT: return "RMB"
		-MOUSE_BUTTON_MIDDLE: return "MMB"
	return name_of(c[0])
