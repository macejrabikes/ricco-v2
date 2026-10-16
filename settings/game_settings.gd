class_name GameSettings
## Nastavenia hry: štýl HUD, veľkosť HP plagátu, celá obrazovka, škálovanie, retro filter, zoznam ovládania,
## zameriavač (štýl a veľkosť).
## Ukladajú sa do user://settings.cfg cez ConfigFile (Godot docs: classes/class_configfile).
## Všetko je statické, takže netreba autoload – stačí GameSettings.hud_style kdekoľvek.
## Mení sa v pause menu → Settings (ui/pause_menu).

enum HudStyle { NOIR, MINIMAL }

const PATH := "user://settings.cfg"
const PORTRAIT_SCALES: Array[float] = [1.0, 1.5, 2.0]
const CROSSHAIRS: Array[String] = ["CROSS", "RING", "SIGHTS", "GHOST"]   ## ui/cursor/reticle_*.png
const CROSSHAIR_SIZES: Array[String] = ["VERY SMALL", "SMALL", "MEDIUM", "LARGE"]
const CROSSHAIR_SCALES: Array[float] = [1.0, 1.0, 1.5, 2.0]   ## VERY SMALL = menšie obrázky (reticle_*_tiny.png), polovičné voči SMALL

static var hud_style: HudStyle = HudStyle.NOIR
static var portrait_scale: float = 1.5   ## veľkosť HP plagátu (1.0 – 2.0)
static var fullscreen: bool = false
static var pixel_perfect: bool = true    ## true = celé násobky (ostré pixely), false = roztiahnuť na celé okno
static var show_controls: bool = true    ## zoznam ovládania vľavo dole
static var retro_filter: bool = false    ## starý film – sépia, zrno, vinetácia
static var crosshair: int = 0            ## index do CROSSHAIRS (GHOST = polopriesvitný)
static var crosshair_size: int = 2       ## index do CROSSHAIR_SIZES (predvolene MEDIUM)
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  # prvé spustenie – ostávajú predvolené hodnoty
	var style: int = cfg.get_value("hud", "style", HudStyle.NOIR)
	hud_style = HudStyle.MINIMAL if style == HudStyle.MINIMAL else HudStyle.NOIR
	portrait_scale = clampf(float(cfg.get_value("hud", "portrait_scale", portrait_scale)), 1.0, 2.0)
	show_controls = bool(cfg.get_value("hud", "show_controls", show_controls))
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	pixel_perfect = bool(cfg.get_value("display", "pixel_perfect", pixel_perfect))
	retro_filter = bool(cfg.get_value("display", "retro_filter", retro_filter))
	crosshair = clampi(int(cfg.get_value("cursor", "crosshair", crosshair)), 0, CROSSHAIRS.size() - 1)
	crosshair_size = clampi(int(cfg.get_value("cursor", "crosshair_size_v2", crosshair_size)), 0, CROSSHAIR_SIZES.size() - 1)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # zachová ostatné hodnoty, ak súbor existuje
	cfg.set_value("hud", "style", hud_style)
	cfg.set_value("hud", "portrait_scale", portrait_scale)
	cfg.set_value("hud", "show_controls", show_controls)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "pixel_perfect", pixel_perfect)
	cfg.set_value("display", "retro_filter", retro_filter)
	cfg.set_value("cursor", "crosshair", crosshair)
	cfg.set_value("cursor", "crosshair_size_v2", crosshair_size)
	cfg.save(PATH)


## Celá obrazovka a škálovanie (Godot docs: classes/class_window – mode, content_scale_stretch;
## tutorials/rendering/multiple_resolutions). Pixel perfect = len celé násobky 640×360
## (v okne, ktoré nie je presným násobkom, ostanú čierne okraje), inak sa obraz roztiahne na celé okno.
## Hra spustená v okne editora (Game → Embed) nemôže meniť režim okna – celá obrazovka tam nefunguje.
static func embedded_in_editor() -> bool:
	return Engine.is_embedded_in_editor()


static func apply_display(win: Window) -> void:
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_perfect else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if embedded_in_editor():
		return
	var is_full: bool = win.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	if fullscreen and not is_full:
		win.mode = Window.MODE_FULLSCREEN
	elif not fullscreen and is_full:
		win.mode = Window.MODE_WINDOWED
