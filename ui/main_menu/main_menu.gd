extends Control
## Úvodné menu – zobrazí sa po spustení hry (Project Settings → Run → Main Scene).
## Pozadie žije: mesto sa pomaly posúva (world/fx/scroll_loop.gd), občas blysne, okná zhasínajú a rozsvecujú sa,
## po mokrej ulici prejde auto (Ford A) so svetlami, prší, neón bliká, Ricco stojí pod lampou.
## Nadpis RICCO sa na začiatku rozsvieti ako neón. Menu vpravo, väčšie písmo, za ním tmavý prechod.
## Stránky nastavení a ovládania sú spoločné s pause menu (ui/pause_menu/menu_pages.gd).
##   STORY – NEW STORY (od kapitoly I), CONTINUE (posledná rozohratá kapitola – Progress.chapter, od jej začiatku),
##           CHAPTERS – výber kapitoly: veľké CHAPTER I, pod ním malým názov
##           (I Pizzeria Don Vito, II cintorín a prístav, III New York)
##   ARSENAL – všetky zbrane a ich štatistiky (zamknuté sú zakryté)
##   SHOOTING RANGE – strelnica: všetky zbrane, terče, režimy pákou (levels/range/shooting_range.gd)

const LoadingScreen := preload("res://ui/loading/loading_screen.gd")
const LEVEL_1 := "res://levels/level1/level1.tscn"
const LEVEL_2 := "res://levels/level2/level2.tscn"
const LEVEL_3 := "res://levels/level3/intro.tscn"
## Kapitoly: číslo, názov a prvá scéna (CHAPTERS a CONTINUE)
const CHAPTERS: Array[Array] = [
	["CHAPTER I", "THE DON'S GHOST", LEVEL_1],
	["CHAPTER II", "WHARF RATS", LEVEL_2],
	["CHAPTER III", "THE BIG APPLE", LEVEL_3],
]
const SHOOTING_RANGE := "res://levels/range/range.tscn"
const WINDOW_LIT := preload("res://levels/level1/art/window_lit.png")
const GLOW := preload("res://levels/level1/art/glow.png")
## Okná na budovách v pozadí (menu_buildings.png má všetky tmavé, tieto sa rozsvecujú)
const WINDOWS: Array[Vector2] = [Vector2(14, 140), Vector2(14, 192), Vector2(14, 244), Vector2(58, 140), Vector2(58, 192), Vector2(58, 244), Vector2(414, 108), Vector2(414, 160), Vector2(414, 212), Vector2(458, 108), Vector2(458, 160), Vector2(458, 212), Vector2(502, 108), Vector2(502, 160), Vector2(502, 212), Vector2(546, 108), Vector2(546, 160), Vector2(546, 212), Vector2(590, 108), Vector2(590, 160), Vector2(590, 212), Vector2(140, 196), Vector2(352, 196)]

enum Page { MAIN, STORY, CHAPTERS, SETTINGS, CONTROLS, AUDIO }

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
	Sfx.music(&"menu_jazz")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fullscreen"):
		GameSettings.fullscreen = not GameSettings.fullscreen
		GameSettings.apply_display(get_tree().root)
		GameSettings.save()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause") and page != Page.MAIN:
		if pages.esc_back.is_valid():
			pages.esc_back.call()   # o stránku späť (napr. DISPLAY → SETTINGS → hlavná)
		else:
			_show_page(Page.MAIN)
		get_viewport().set_input_as_handled()


func _show_page(p: Page) -> void:
	page = p
	match p:
		Page.MAIN:
			pages.clear()
			var first := pages.item("STORY", _show_page.bind(Page.STORY))
			pages.item("ARSENAL", _open_arsenal)
			pages.item("SHOOTING RANGE", _start.bind(SHOOTING_RANGE))
			pages.item("SETTINGS", _show_page.bind(Page.SETTINGS))
			pages.item("QUIT", func(): get_tree().quit())
			pages.hint("ENTER  SELECT     F11  FULLSCREEN")
			pages.focus(first)
		Page.STORY:
			pages.clear()
			pages.esc_back = _show_page.bind(Page.MAIN)
			pages.title("STORY")
			Progress.ensure_loaded()
			var first: MenuItem = null
			var last: int = clampi(Progress.chapter, 0, CHAPTERS.size())
			if last > 0:   # CONTINUE len keď už niečo rozohral – pod ním malým, ktorá kapitola
				var ch: Array = CHAPTERS[last - 1]
				first = pages.item_sub("CONTINUE", "%s - %s" % [ch[0], ch[1]], _start.bind(ch[2]))
			var new_story := pages.item("NEW STORY", _start.bind(LEVEL_1))
			pages.item("CHAPTERS", _show_page.bind(Page.CHAPTERS))
			pages.spacer(6)
			pages.item("BACK", _show_page.bind(Page.MAIN))
			pages.hint("ENTER  SELECT     ESC  BACK")
			pages.focus(first if first else new_story)
		Page.CHAPTERS:
			pages.clear()
			pages.esc_back = _show_page.bind(Page.STORY)
			pages.title("CHAPTERS")
			var first: MenuItem = null
			for ch: Array in CHAPTERS:
				var it := pages.item_sub(ch[0], ch[1], _start.bind(ch[2]))
				pages.spacer(2)
				if first == null:
					first = it
			pages.spacer(4)
			pages.item("BACK", _show_page.bind(Page.STORY))
			pages.hint("ENTER  SELECT     ESC  BACK")
			pages.focus(first)
		Page.SETTINGS:
			pages.settings_page(_show_page.bind(Page.MAIN), _show_page.bind(Page.AUDIO))
		Page.AUDIO:
			pages.audio_page(_show_page.bind(Page.SETTINGS))
		Page.CONTROLS:
			pages.controls_page(_show_page.bind(Page.MAIN))


## Arsenal – stena so zbraňami (ui/arsenal/arsenal.gd), po zatvorení späť na hlavnú stránku
func _open_arsenal() -> void:
	pages.clear()
	var a := Arsenal.new()
	add_child(a)
	move_child(a, fade.get_index())   # pod stmievaním
	a.closed.connect(func():
		a.queue_free()
		_show_page(Page.MAIN))


## Stmavne a prepne na level (čierna clona navrchu, načítanie na pozadí – ui/loading/loading_screen.gd)
func _start(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	Level1.checkpoint = 0   # nová hra začína na ulici
	Level1.intro_done = false
	Level1.cellar_arrived = false
	Level1.catacombs_seen = false
	Level2.reset()
	Level3.reset()
	get_viewport().gui_release_focus()
	LoadingScreen.go(get_tree(), path, 0.4)


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
