class_name Sfx
## Zvuky hry – statické funkcie (netreba autoload), napr. Sfx.play(&"hat_throw", global_position).
## Zbernice (Godot docs: tutorials/audio/audio_buses, classes/class_audioserver):
##   Master ← Music, SFX (zbrane, Ricco, nepriatelia, svet), Ambience (dážď, dav, tunely), UI (menu).
## Hlasitosť každej zbernice je v nastaveniach (GameSettings.volumes, 0–10). Zbernice sa vytvoria pri prvom použití.
## Spomalenie času (duch Dona): nové zvuky na SFX znejú nižšie (pitch) a hudba s prostredím sú tlmené (dolná priepusť).
## Zvuky: CC0 nahrávky (zoznam v README → Credits) + časť generovaná skriptom.
## Súbory: audio/sfx/*.wav, slučky audio/amb/*.ogg, hudba audio/music/*.ogg.
## Varianty: ak existuje meno_2.wav (meno_3.wav…), každé zahranie vyberie inú (AudioStreamRandomizer,
##   docs: classes/class_audiostreamrandomizer) – výstrely tak neznejú ako „guľomet jednej vzorky“.
## Mix (docs: tutorials/audio/audio_effects): výstrely na SFX na chvíľu stíšia hudbu a prostredie
##   (kompresor so sidechain = SFX) a Master má tvrdý obmedzovač, aby sa nič neprebudilo do skreslenia.

const BUSES: Array[StringName] = [&"Music", &"SFX", &"Ambience", &"UI"]
const SFX_DIR := "res://audio/sfx/%s.wav"
const AMB_DIR := "res://audio/amb/%s.ogg"
const MUSIC_DIR := "res://audio/music/%s.ogg"
const MUSIC_DB := -9.0   ## hudba je podklad – pod efektmi a prostredím
const MAX_DISTANCE := 900.0   ## px – ďalej od kamery 2D zvuk nepočuť

## Výstrel podľa zbrane (WeaponData.name); nepriateľská pištoľ má vlastný hlas (pistol_b), aby sa dala rozoznať od Riccovej
const SHOTS := {"Derringer": &"pistol_c", "Pistol": &"pistol_a", "Revolver": &"revolver_shot", "Tommy gun": &"tommy_shot", "Lupara": &"lupara_shot",
		"Winchester": &"lupara_shot", "Springfield": &"rifle_shot", "Winchester 1894": &"winchester94_shot",
		"Mauser C96": &"c96_shot"}
## Winchester 1897 (Iron Mike) – zatiaľ hlas brokovnice ako lupara. Pušky majú vlastné nahrávky (Sonniss GDC, _art_src/make_rifle_shots.py):
## Springfield = M1917 Enfield (.30-06), Winchester 1894 = Model 1894, Mauser C96 (Margaret) = ostrý štek Walther PPQ
const ENEMY_SHOTS := {"Pistol": &"pistol_b"}

static var _setup_done: bool = false
static var slowmo: bool = false
static var _lowpass: Dictionary = {}   ## zbernica → AudioEffectLowPassFilter
static var _variants: Dictionary = {}  ## zvuk → AudioStream (Randomizer, ak má varianty)
static var _music: AudioStreamPlayer   ## práve hrajúca hudba (žije v koreni stromu, prežije zmenu scény)
static var _music_name: StringName = &""


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
	# Výstrel stíši hudbu a prostredie: kompresor počúva zbernicu SFX (sidechain) – docs: classes/class_audioeffectcompressor
	for b in [&"Music", &"Ambience"]:
		var c := AudioEffectCompressor.new()
		c.sidechain = &"SFX"
		c.threshold = -16.0
		c.ratio = 4.0 if b == &"Ambience" else 3.0
		c.attack_us = 800.0
		c.release_ms = 280.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index(b), c)
	# Strop na Master: veľa výstrelov naraz sa zrazí na −0,5 dB namiesto praskania – docs: classes/class_audioeffecthardlimiter
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	lim.release = 0.12
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Master"), lim)
	apply_volumes()


## Hlasitosti z nastavení (0–10 → dB, 0 = stlmené). Krivka (v/10)^1,5: ucho vníma hlasitosť logaritmicky,
## takže pri lineárnej amplitúde bolo 6–10 skoro rovnako hlasné a dole to skákalo. Teraz je každý krok počuteľný
## (10 → 0 dB, 8 → −2,9 dB, 5 → −9 dB, 2 → −21 dB, 1 → −30 dB). Godot docs: classes/class_@globalscope#class-globalscope-method-linear-to-db
static func apply_volumes() -> void:
	GameSettings.ensure_loaded()
	for b: StringName in [&"Master", &"Music", &"SFX", &"Ambience", &"UI"]:
		var i := AudioServer.get_bus_index(b)
		if i == -1:
			continue
		var v: float = GameSettings.volume(b) / 10.0
		AudioServer.set_bus_mute(i, v <= 0.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(pow(v, 1.5), 0.001)))


static func stream(sound: StringName) -> AudioStream:
	if _variants.has(sound):
		return _variants[sound]
	var s: AudioStream = _wav(sound)
	if s != null and ResourceLoader.exists(SFX_DIR % (String(sound) + "_2")):
		var r := AudioStreamRandomizer.new()
		r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		r.random_pitch = 1.0          # výšku mení _pitch() (aj kvôli spomaleniu)
		r.random_volume_offset_db = 1.5
		r.add_stream(-1, s)
		var n := 2
		while ResourceLoader.exists(SFX_DIR % ("%s_%d" % [sound, n])):
			r.add_stream(-1, _wav(StringName("%s_%d" % [sound, n])))
			n += 1
		s = r
	_variants[sound] = s
	return s


## Jedna vzorka bez variantov (load() si načítané zvuky pamätá sám – ResourceLoader cache)
static func _wav(sound: StringName) -> AudioStreamWAV:
	var path := SFX_DIR % sound
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
		var wav := _wav(sound).duplicate() as AudioStreamWAV
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
	var n: String = weapon.get(&"name")
	var sound: StringName = ENEMY_SHOTS.get(n, SHOTS.get(n, &"pistol_a")) if pos != Vector2.INF else SHOTS.get(n, &"pistol_a")
	play(sound, pos, volume_db, 0.04)


## Hudba na pozadí (audio/music/meno.ogg, zbernica Music), plynulé prelínanie zo starej skladby.
## Rovnaká skladba hrá ďalej bez prerušenia (napr. ulica → pivnica). &"" = stíšiť a vypnúť.
## Prehrávač je v koreni stromu, takže zmena scény hudbu neutne – docs: tutorials/scripting/singletons_autoload
static func music(track: StringName, fade: float = 1.5) -> void:
	setup()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or (track == _music_name and is_instance_valid(_music)):
		return
	if is_instance_valid(_music):
		var old := _music
		var tw := old.create_tween()
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.tween_callback(old.queue_free)
	_music = null
	_music_name = track
	if track == &"" or not ResourceLoader.exists(MUSIC_DIR % track):
		return
	var ogg := (load(MUSIC_DIR % track) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	ogg.loop = true
	var a := AudioStreamPlayer.new()
	a.stream = ogg
	a.bus = &"Music"
	a.volume_db = -40.0
	a.process_mode = Node.PROCESS_MODE_ALWAYS   # hrá aj v pauze
	a.autoplay = true                           # spustí sa po vložení do stromu
	tree.root.add_child.call_deferred(a)        # odložene – v _ready() scény je koreň ešte zaneprázdnený
	tree.create_tween().bind_node(a).tween_property(a, "volume_db", MUSIC_DB, fade)
	_music = a
