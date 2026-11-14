extends CanvasLayer
## HUD (náboje, spomalenie a plagát bežia aj počas pauzy, aby bolo vidno zmenu nastavení) – náboje (ui/ammo_panel.gd), spomalenie (ui/focus_meter.gd), zdravie – plagát WANTED (ui/health_poster.gd),
## dočasný zoznam ovládania (ui/controls_help.gd). Neskôr: štýl/combo, reputácia u Dona.


## Doplnky HUD (vytvorené v kóde, netreba meniť hud.tscn): varovania pri málo zdraví a nábojoch,
## aktuálny cieľ + pečiatka CHECKPOINT vpravo hore, šípka „kam ďalej“ (ui/hud/*.gd)
func _ready() -> void:
	for extra: Control in [LowWarnings.new(), ObjectiveBox.new(), GuideArrow.new()]:
		add_child(extra)
		move_child(extra, 0)   # pod pause menu a retro filter
