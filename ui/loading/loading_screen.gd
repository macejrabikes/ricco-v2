extends CanvasLayer
## Prechod medzi scénami (štart hry, pivnica, návrat do menu, reštart): čierna clona úplne navrchu
## (nad HUD, myšlienkami aj stmievaním levelov), kurzor sa skryje, scéna sa načíta na pozadí
## a clona sa zdvihne až keď sa nová scéna ustáli – nič nepreblikne (dážď, kurzor, kamera na zlom mieste).
## Vpravo dole beží Ricco a vedľa neho je nápis LOADING s bežiacimi bodkami (návrh C).
## Clona visí na koreni stromu (nie v scéne), takže výmenu scény prežije.
## Použitie: const LoadingScreen := preload("res://ui/loading/loading_screen.gd")
##           LoadingScreen.go(get_tree(), "res://levels/level1/level1.tscn")
## Godot docs: tutorials/io/background_loading, classes/class_resourceloader (load_threaded_request),
## classes/class_scenetree (change_scene_to_packed), classes/class_input (mouse_mode)

const SELF_PATH := "res://ui/loading/loading_screen.gd"
const LAYER := 128           ## nad všetkým (pauza 50, stmievanie levelov 45)
const FADE_IN := 0.25        ## s – stmavnutie starej scény
const FADE_OUT := 0.3        ## s – odhalenie novej scény
const SETTLE_FRAMES := 6     ## snímky novej scény pod clonou (kamera, spawn, prvé kroky fyziky)
const MIN_BLACK := 0.4       ## s – clona je čierna aspoň takto dlho (inak by len preblikla)
const FRAMES := preload("res://characters/ricco/ricco_frames.tres")
const FONT := preload("res://ui/fonts/tiny5.ttf")
const TEXT_COLOR := Color8(150, 140, 120)
const RICCO_POS := Vector2(607, 325)   ## stred 64×64 snímky – viditeľný Ricco končí 16 px od pravého a 12 px od spodného okraja
const DOT_TIME := 0.25       ## s – ďalšia bodka za LOADING

static var busy: bool = false   ## práve prebieha prechod – ďalší sa nezačne

var _root: Control       ## celá clona (čierna + Ricco + nápis) – stmieva sa cez modulate
var _label: Label
var _dots_t: float = 0.0
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


## Prepne na scénu path. fade_in = 0 → clona hneď čierna (keď je obraz už stmavnutý, napr. zostup do pivnice).
static func go(tree: SceneTree, path: String, fade_in: float = FADE_IN) -> void:
	if busy:
		return
	busy = true
	var ls: CanvasLayer = load(SELF_PATH).new()
	tree.root.add_child(ls)
	ls.call(&"_run", path, fade_in)


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS   # beží aj v pauze
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # počas prechodu sa nedá klikať do menu
	_root.modulate.a = 0.0
	add_child(_root)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(black)
	var ricco := AnimatedSprite2D.new()
	ricco.sprite_frames = FRAMES
	ricco.position = RICCO_POS
	_root.add_child(ricco)
	ricco.play(&"run")
	_label = Label.new()
	_label.add_theme_font_override(&"font", FONT)
	_label.add_theme_font_size_override(&"font_size", 8)
	_label.add_theme_color_override(&"font_color", TEXT_COLOR)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.text = "LOADING . . ."
	_root.add_child(_label)
	# nápis končí 10 px vľavo od Ricca, zarovnaný na plnú dĺžku (bodky ho neposúvajú)
	_label.position = (Vector2(RICCO_POS.x - 17.0 - 10.0, 337.0) - Vector2(_label.get_minimum_size().x, 0)).round()
	_label.text = "LOADING"


func _process(delta: float) -> void:
	_dots_t += delta
	var n: int = int(_dots_t / DOT_TIME) % 4
	_label.text = "LOADING" + " .".repeat(n)


func _run(path: String, fade_in: float) -> void:
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if fade_in > 0.0:
		await _fade(1.0, fade_in).finished
	else:
		_root.modulate.a = 1.0
	var t0: int = Time.get_ticks_msec()
	# načítanie na pozadí – obraz nezamrzne
	var packed: PackedScene
	if ResourceLoader.load_threaded_request(path) == OK:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
	var tree := get_tree()
	var old := tree.current_scene
	tree.paused = false        # nová scéna nezačína v pauze ani spomalená
	Engine.time_scale = 1.0
	tree.change_scene_to_packed(packed)
	while tree.current_scene == null or tree.current_scene == old:
		await tree.process_frame
	for i in SETTLE_FRAMES:
		await tree.process_frame
	while Time.get_ticks_msec() - t0 < MIN_BLACK * 1000.0:
		await tree.process_frame
	Input.mouse_mode = _mouse_before
	await _fade(0.0, FADE_OUT).finished
	busy = false
	queue_free()


func _fade(to: float, time: float) -> Tween:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_root, "modulate:a", to, time)
	return tw
