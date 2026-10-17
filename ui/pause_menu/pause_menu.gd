extends CanvasLayer
## Pause menu – ESC alebo P. Hra sa zastaví (get_tree().paused, Godot docs: tutorials/scripting/pausing_games),
## pozadie sa rozmaže a stmaví (pause_blur.gdshader), menu je vpravo (štýl „minimal“, po anglicky).
## Stránky: hlavná (Resume, Settings, Controls, Restart, Main menu, Quit), nastavenia, ovládanie
## (nastavenia a ovládanie sú spoločné s úvodným menu – ui/pause_menu/menu_pages.gd).
## Tento uzol má process_mode = ALWAYS, takže beží aj počas pauzy.
## F11 prepína celú obrazovku kedykoľvek (aj bez menu).

const FADE_TIME := 0.15
const BLUR := 2.5
const DIM := 0.55

enum Page { MAIN, SETTINGS, CONTROLS, AUDIO }

const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"

@onready var blur: ColorRect = $Blur
@onready var root: Control = $Root
@onready var column: VBoxContainer = $Root/Column

var page: Page = Page.MAIN
var is_open: bool = false
var _tween: Tween
var pages: MenuPages


func _ready() -> void:
	GameSettings.ensure_loaded()
	GameSettings.apply_display(get_tree().root)
	visible = false
	_set_fade(0.0)
	pages = MenuPages.new(column, _after_settings)
	pages.item_size = 16   # rovnako veľké písmo ako v úvodnom menu
	pages.title_size = 24


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fullscreen"):
		GameSettings.fullscreen = not GameSettings.fullscreen
		_apply_and_save()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		if not is_open:
			open()
		elif page == Page.AUDIO:
			_show_page(Page.SETTINGS)
		elif page != Page.MAIN:
			_show_page(Page.MAIN)
		else:
			close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open or get_tree().paused:
		return
	is_open = true
	get_tree().paused = true
	visible = true
	_show_page(Page.MAIN)
	_fade_to(1.0)


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_viewport().gui_release_focus()
	_fade_to(0.0).tween_callback(func():
		visible = false
		get_tree().paused = false)


func _fade_to(v: float) -> Tween:
	if _tween:
		_tween.kill()
	# menu beží počas pauzy aj spomalenia → tween ignoruje Engine.time_scale
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_method(_set_fade, _get_fade(), v, FADE_TIME)
	return _tween


var _fade: float = 0.0

func _get_fade() -> float:
	return _fade


func _set_fade(v: float) -> void:
	_fade = v
	var m := blur.material as ShaderMaterial
	m.set_shader_parameter(&"blur", BLUR * v)
	m.set_shader_parameter(&"dim", DIM * v)
	root.modulate.a = v
	root.position.x = roundf((1.0 - v) * 8.0)   # menu jemne pricestuje sprava


# ---------------------------------------------------------------- stránky

func _show_page(p: Page) -> void:
	page = p
	match p:
		Page.MAIN:
			pages.clear()
			pages.title("PAUSED")
			var first := pages.item("RESUME", close)
			pages.item("SETTINGS", _show_page.bind(Page.SETTINGS))
			pages.item("CONTROLS", _show_page.bind(Page.CONTROLS))
			pages.item("RESTART", _restart)
			pages.item("MAIN MENU", _to_main_menu)
			pages.item("QUIT GAME", func(): get_tree().quit())
			pages.hint("ESC / P  RESUME     ENTER  SELECT")
			pages.focus(first)
		Page.SETTINGS:
			pages.settings_page(_show_page.bind(Page.MAIN), _show_page.bind(Page.AUDIO))
		Page.AUDIO:
			pages.audio_page(_show_page.bind(Page.SETTINGS))
		Page.CONTROLS:
			pages.controls_page(_show_page.bind(Page.MAIN))


func _apply_and_save() -> void:
	GameSettings.apply_display(get_tree().root)
	GameSettings.save()
	_after_settings()


## Po zmene nastavení: zoznam ovládania vľavo dole sa zobrazí/skryje hneď
func _after_settings() -> void:
	var help := get_parent().get_node_or_null(^"ControlsHelp") as Control
	if help:
		help.visible = GameSettings.show_controls


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _to_main_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MAIN_MENU)
