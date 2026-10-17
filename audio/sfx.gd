class_name Sfx
## Zvuky hry – statické funkcie (netreba autoload), napr. Sfx.play(&"hat_throw", global_position).
## Zbernice (Godot docs: tutorials/audio/audio_buses, classes/class_audioserver):
##   Master ← Music, SFX (zbrane, Ricco, nepriatelia, svet), Ambience (dážď, dav, tunely), UI (menu).
## Hlasitosť každej zbernice je v nastaveniach (GameSettings.volumes, 0–10). Zbernice sa vytvoria pri prvom použití.
## Spomalenie času (duch Dona): nové zvuky na SFX znejú nižšie (pitch) a hudba s prostredím sú tlmené (dolná priepusť).
## Zvuky: CC0 nahrávky (zoznam v README → Credits) + časť generovaná skriptom.
## Súbory: audio/sfx/*.wav, slučky audio/amb/*.ogg.

const BUSES: Array[StringName] = [&"Music", &"SFX", &"Ambience", &"UI"]
const SFX_DIR := "res://audio/sfx/%s.wav"
const AMB_DIR := "res://audio/amb/%s.ogg"
const MAX_DISTANCE := 900.0   ## px – ďalej od kamery 2D zvuk nepočuť

## Výstrel podľa zbrane (WeaponData.name)
const SHOTS := {"Pistol": &"pistol_a", "Revolver": &"revolver_shot", "Tommy gun": &"tommy_shot", "Lupara": &"lupara_shot"}

static var _setup_done: bool = false
static var slowmo: bool = false
static var _lowpass: Dictionary = {}   ## zbernica → AudioEffectLowPassFilter


static func setup() -> void:
	if _setup_done:
		return
	_setup_done = true
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, &"Master")
	for b in [&"Music", &"Ambience", &"SFX"]:
		var f := AudioEffectLowPassFilter.new()
		f.cutoff_hz = 1400.0 if b != &"SFX" else 4500.0
		var i := AudioServer.get_bus_index(b)
		AudioServer.add_bus_effect(i, f)
		AudioServer.set_bus_effect_enabled(i, AudioServer.get_bus_effect_count(i) - 1, false)
		_lowpass[b] = AudioServer.get_bus_effect_count(i) - 1
	apply_volumes()


## Hlasitosti z nastavení (0–10 → dB, 0 = stlmené)
static func apply_volumes() -> void:
	GameSettings.ensure_loaded()
	for b: StringName in [&"Master", &"Music", &"SFX", &"Ambience", &"UI"]:
		var i := AudioServer.get_bus_index(b)
		if i == -1:
			continue
		var v: float = GameSettings.volume(b) / 10.0
		AudioServer.set_bus_mute(i, v <= 0.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


static func stream(sound: StringName) -> AudioStream:
	var path := SFX_DIR % sound   # load() si načítané zvuky pamätá sám (ResourceLoader cache)
	return load(path) if ResourceLoader.exists(path) else null


## Zahrá zvuk. pos = poloha vo svete (2D zvuk, tichne s diaľkou), Vector2.INF = všade rovnako (UI, Ricco).
static func play(sound: StringName, pos: Vector2 = Vector2.INF, volume_db: float = 0.0, pitch_var: float = 0.06, bus: StringName = &"SFX") -> Node:
	setup()
	var s := stream(sound)
	var tree := Engine.get_main_loop() as SceneTree
	if s == null or tree == null:
		return null
	var parent: Node = tree.current_scene if tree.current_scene else tree.root
	var p: Node
	if pos == Vector2.INF:
		var a := AudioStreamPlayer.new()
		a.stream = s
		a.bus = bus
		a.volume_db = volume_db
		a.pitch_scale = _pitch(pitch_var, bus)
		p = a
	else:
		var a2 := AudioStreamPlayer2D.new()
		a2.stream = s
		a2.bus = bus
		a2.volume_db = volume_db
		a2.pitch_scale = _pitch(pitch_var, bus)
		a2.max_distance = MAX_DISTANCE
		a2.attenuation = 1.4
		a2.position = pos
		p = a2
	if bus == &"UI" or tree.paused:
		p.process_mode = Node.PROCESS_MODE_ALWAYS   # menu (a skúška hlasitosti) znie aj počas pauzy
	parent.add_child(p)
	p.connect(&"finished", p.queue_free)
	p.call(&"play")
	return p


static func ui(sound: StringName) -> void:
	play(sound, Vector2.INF, 0.0, 0.02, &"UI")


static func _pitch(v: float, bus: StringName) -> float:
	var k: float = randf_range(1.0 - v, 1.0 + v)
	if slowmo and bus == &"SFX":
		k *= 0.72
	return k


## Slučka (prostredie, tlkot srdca…). Vráti prehrávač – zastaví sa queue_free() alebo stop().
## sound z audio/amb (ogg) alebo audio/sfx (wav – nastaví sa mu opakovanie).
static func loop(sound: StringName, parent: Node, pos: Vector2 = Vector2.INF, volume_db: float = 0.0, bus: StringName = &"Ambience") -> Node:
	setup()
	var s: AudioStream
	if ResourceLoader.exists(AMB_DIR % sound):
		var ogg := (load(AMB_DIR % sound) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		ogg.loop = true
		s = ogg
	else:
		var wav := (stream(sound) as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		s = wav
	var p: Node
	if pos == Vector2.INF:
		var a := AudioStreamPlayer.new()
		a.stream = s
		a.bus = bus
		a.volume_db = volume_db
		p = a
	else:
		var a2 := AudioStreamPlayer2D.new()
		a2.stream = s
		a2.bus = bus
		a2.volume_db = volume_db
		a2.max_distance = MAX_DISTANCE * 1.2
		a2.position = pos
		p = a2
	parent.add_child(p)
	p.call(&"play")
	return p


## Spomalenie času zapnuté/vypnuté (volá focus.gd)
static func set_slowmo(on: bool) -> void:
	setup()
	slowmo = on
	for b in _lowpass:
		var i := AudioServer.get_bus_index(b)
		AudioServer.set_bus_effect_enabled(i, _lowpass[b], on)


## Výstrel zbrane (podľa mena v WeaponData)
static func shot(weapon: Resource, pos: Vector2 = Vector2.INF, volume_db: float = 0.0) -> void:
	if weapon == null:
		return
	play(SHOTS.get(weapon.get(&"name"), &"pistol_a"), pos, volume_db, 0.05)
