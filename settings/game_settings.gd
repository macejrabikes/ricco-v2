class_name GameSettings
## Nastavenia hry. Zatiaľ len štýl HUD, neskôr hlasitosť, ovládanie, obrazovka…
## Ukladajú sa do user://settings.cfg cez ConfigFile (Godot docs: classes/class_configfile).
## Všetko je statické, takže netreba autoload – stačí GameSettings.hud_style kdekoľvek.

enum HudStyle { NOIR, MINIMAL }

const PATH := "user://settings.cfg"

static var hud_style: HudStyle = HudStyle.NOIR
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


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # zachová ostatné hodnoty, ak súbor existuje
	cfg.set_value("hud", "style", hud_style)
	cfg.save(PATH)
