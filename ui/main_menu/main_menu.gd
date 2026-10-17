extends Control
## Úvodné menu – zobrazí sa po spustení hry (Project Settings → Run → Main Scene).
## Pozadie žije: mesto sa pomaly posúva (world/fx/scroll_loop.gd), občas blysne, okná zhasínajú a rozsvecujú sa,
## po mokrej ulici prejde auto (Ford A) so svetlami, prší, neón bliká, Ricco stojí pod lampou.
## Nadpis RICCO sa na začiatku rozsvieti ako neón. Menu vpravo, väčšie písmo, za ním tmavý prechod.
## Stránky nastavení a ovládania sú spoločné s pause menu (ui/pause_menu/menu_pages.gd).
##   START GAME – level 1 (Pizzeria Don Vito)
##   DEBUG ROOM – testovacia miestnosť (gangstri, terče, všetky zbrane)

const LEVEL_1 := "res://levels/level1/level1.tscn"
const DEBUG_ROOM := "res://levels/test_room/test_room.tscn"
const WINDOW_LIT := preload("res://levels/level1/art/window_lit.png")
const GLOW := preload("res://levels/level1/art/glow.png")
## Okná na budovách v pozadí (menu_buildings.png má všetky tmavé, tieto sa rozsvecujú)
const WINDOWS: Array[Vector2] = [Vector2(14, 140), Vector2(14, 192), Vector2(14, 244), Vector2(58, 140), Vector2(58, 192), Vector2(58, 244), Vector2(414, 108), Vector2(414, 160), Vector2(414, 212), Vector2(458, 108), Vector2(458, 160), Vector2(458, 212), Vector2(502, 108), Vector2(502, 160), Vector2(502, 212), Vector2(546, 108), Vector2(546, 160), Vector2(546, 212), Vector2(590, 108), Vector2(590, 160), Vector2(590, 212), Vector2(140, 196), Vector2(352, 196)]

enum Page { MAIN, SETTINGS, CONTROLS, AUDIO }

@onready var column: VBoxContainer = $Root/Column
@onready var fade: ColorRect = $Fade
@onready var title: Label = $Title
@onready var title_glow: TextureRect = $Title/Glow
@onready var lightning: ColorRect = $Lightning
@onready var windows_root: Node2D = $World/Windows
@onready var car: Node2D = $World/Car

var page: Page = Page.MAIN
var pages: MenuPages
var _leaving: bool = false
var _windows: Array[Sprite2D] = []
var _window_t: float = 1.0
var _lightning_t: float = 6.0
var _car_t: float = 3.0


func _ready() -> void:
	GameSettings.ensure_loaded()
	GameSettings.apply_display(get_tree().root)
	get_tree().paused = false
	Engine.time_scale = 1.0
	pages = MenuPages.new(column, Callable())
	pages.item_size = 16
	pages.title_size = 24
	_show_page(Page.MAIN)
	_make_windows()
	car.visible = false
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 0.6)
	_title_flicker_in()
	Sfx.loop(&"rain", self, Vector2.INF, -10.0)   # dážď za oknom


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fullscreen"):
		GameSettings.fullscreen = not GameSettings.fullscreen
		GameSettings.apply_display(get_tree().root)
		GameSettings.save()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause") and page != Page.MAIN:
		_show_page(Page.SETTINGS if page == Page.AUDIO else Page.MAIN)
		get_viewport().set_input_as_handled()


func _show_page(p: Page) -> void:
	page = p
	match p:
		Page.MAIN:
			pages.clear()
			var first := pages.item("START GAME", _start.bind(LEVEL_1))
			pages.item("DEBUG ROOM", _start.bind(DEBUG_ROOM))
			pages.item("SETTINGS", _show_page.bind(Page.SETTINGS))
			pages.item("CONTROLS", _show_page.bind(Page.CONTROLS))
			pages.item("QUIT", func(): get_tree().quit())
			pages.hint("ENTER  SELECT     F11  FULLSCREEN")
			pages.focus(first)
		Page.SETTINGS:
			pages.settings_page(_show_page.bind(Page.MAIN), _show_page.bind(Page.AUDIO))
		Page.AUDIO:
			pages.audio_page(_show_page.bind(Page.SETTINGS))
		Page.CONTROLS:
			pages.controls_page(_show_page.bind(Page.MAIN))


## Stmavne a prepne na level
func _start(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	Level1.checkpoint = 0   # nová hra začína na ulici
	Level1.intro_done = false
	Level1.cellar_arrived = false
	get_viewport().gui_release_focus()
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.4)
	tw.tween_callback(func(): get_tree().change_scene_to_file(path))


# ---------------------------------------------------------------- živé pozadie

func _process(delta: float) -> void:
	# okná: občas niekto zhasne alebo rozsvieti
	_window_t -= delta
	if _window_t <= 0.0 and not _windows.is_empty():
		_window_t = randf_range(0.6, 2.0)
		var w: Sprite2D = _windows.pick_random()
		w.visible = not w.visible
	# blesk: dva rýchle záblesky oblohy
	_lightning_t -= delta
	if _lightning_t <= 0.0:
		_lightning_t = randf_range(7.0, 14.0)
		var tw := create_tween()
		tw.tween_property(lightning, "color:a", 0.35, 0.04)
		tw.tween_property(lightning, "color:a", 0.0, 0.08)
		tw.tween_interval(0.07)
		tw.tween_property(lightning, "color:a", 0.5, 0.03)
		tw.tween_property(lightning, "color:a", 0.0, 0.5)
	# auto prejde po ulici
	_car_t -= delta
	if _car_t <= 0.0:
		_car_t = randf_range(9.0, 15.0)
		_drive_car()
	# nadpis jemne „dýcha“ ako neón
	if title_glow.modulate.a > 0.0:
		title_glow.modulate.a = 0.35 + 0.08 * sin(Time.get_ticks_msec() * 0.003)


func _make_windows() -> void:
	for pos in WINDOWS:
		var s := Sprite2D.new()
		s.texture = WINDOW_LIT
		s.centered = false
		s.position = pos
		s.visible = randf() < 0.5
		var g := Sprite2D.new()   # teplá žiara okolo okna
		g.texture = GLOW
		g.material = _add_mat()
		g.modulate = Color(1.0, 0.7, 0.35, 0.22)
		g.position = Vector2(13, 16)
		g.scale = Vector2(0.9, 0.9)
		s.add_child(g)
		windows_root.add_child(s)
		_windows.append(s)


func _add_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _drive_car() -> void:
	var right: bool = randf() < 0.5
	car.visible = true
	car.scale.x = 1.0 if right else -1.0
	car.position = Vector2(-110.0 if right else 750.0, 322.0)
	var tw := create_tween()
	tw.tween_property(car, "position:x", 750.0 if right else -110.0, randf_range(3.2, 4.5))
	tw.tween_callback(func(): car.visible = false)


## Nadpis sa rozsvieti ako neón: pár zablikaní, potom svieti
func _title_flicker_in() -> void:
	title.modulate.a = 0.0
	title_glow.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	for a in [1.0, 0.0, 0.8, 0.1, 1.0, 0.3, 1.0]:
		tw.tween_callback(func():
			title.modulate.a = a
			title_glow.modulate.a = a * 0.4)
		tw.tween_interval(randf_range(0.04, 0.12))
