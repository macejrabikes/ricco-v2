class_name Level3
extends Node2D
## Kapitola III – The Big Apple. Časť 1: nábrežná stena pri East River (po úvode pri Soche slobody – intro.gd).
## Ricco pristane v člne z Margaret pri kamennej stene, vylezie po železnom rebríku (world/fx/ladder.gd) na promenádu
## (lampa, lavička, strážnik s baterkou) a ide ďalej do ulice k nájomnému domu. Ulica, požiarne schodisko a strechy
## so šnúrami sú ďalší krok – zatiaľ tam kapitola končí nápisom TO BE CONTINUED.
## Celé nábrežie je „tma“ (player.dark_area): vidno ťa len na svetle lámp a v kuželi baterky.
## Scénu generuje tools/build_level3.gd – úpravy mapy rob tam, inak sa pri ďalšom generovaní prepíšu.
## Godot docs: classes/class_tween, classes/class_canvaslayer, classes/class_area2d

const MAP := Rect2i(0, -420, 1600, 516)             ## hranice kamery (px) – hladina je na y = 0, dno na y = 96
const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const LoadingScreen := preload("res://ui/loading/loading_screen.gd")
const REVOLVER := preload("res://weapons/revolver/revolver.tres")
const LUPARA := preload("res://weapons/lupara/lupara.tres")
const TOMMY := preload("res://weapons/tommy/tommy.tres")
const GHOST := preload("res://characters/don/ghost_don.png")
const GLOW := preload("res://levels/level1/art/glow.png")
const FONT := preload("res://ui/fonts/tiny5.ttf")
const NIGHT := Color(0.72, 0.8, 0.86)               ## mafiáni sú v nočnom svetle tmavší (Ricco sa stmavuje sám)
const TOMMY_START_AMMO := 20                        ## náboje do Thompsonu sú v kapitole III vzácne – len to, čo ostalo v bubne

## 0 = v člne pri stene, 1 = hore na promenáde. Statické premenné prežijú smrť (reload scény),
## úvodné menu a koniec kapitoly II ich vynulujú (reset()).
static var checkpoint: int = 0
static var arrived: bool = false                    ## Riccove myšlienky po pristátí už zazneli
static var barks: Array[StringName] = []            ## hlášky ducha, ktoré už zazneli (len raz za hru)

const ARRIVE: Array[String] = [
	"New York. Smells like fish, coal smoke and money.",
	"Somewhere up there's a hotel called the Majestic. And a guy who signs his letters 'M.'",
]

var player: Node2D
var pcam: PhantomCamera2D
var _leaving: bool = false
var _horn_t: float = 12.0
var _say_queue: Array[String] = []
var _say_busy: float = 0.0


## Nová hra / nová kapitola – všetko odznova
static func reset() -> void:
	checkpoint = 0
	arrived = false
	barks.clear()
	Food.reset()   # nesené jedlo (props/food/food.gd)


func _ready() -> void:
	var black := _fade_rect()
	black.color.a = 1.0
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	pcam = player.get_node(^"PhantomCamera2D")
	_set_limits(MAP)
	var help := get_node_or_null(^"HUD/ControlsHelp") as Control
	if help:
		help.visible = false
	# výbava z kapitoly II: revolver, lupara a Thompson po Lou – do neho len pár nábojov (krabičky sú vzácne)
	var list: Array[WeaponData] = [REVOLVER, LUPARA, TOMMY]
	player.set_loadout(list)
	player.weapon_ammo[2] = [TOMMY_START_AMMO, 0]
	player.focus.unlocked = true
	player.dark_area = true
	player.light_zones = 0
	var spawn := get_node_or_null(NodePath("Spawn%d" % checkpoint)) as Node2D
	if spawn:
		player.global_position = spawn.global_position
	pcam.teleport_position.call_deferred()
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var rig := g.get(&"rig") as Node2D
		if rig:
			rig.modulate = NIGHT
	_connect(^"LadderBark", func(): _once(&"ladder", "UP THE LADDER, KID.\n%s TO CLIMB." % KeyBindings.short(&"jump")))
	_connect(^"GuardBark", func(): _once(&"guard", "A FLATFOOT WITH A FLASHLIGHT.\nWAIT TILL HE TURNS AROUND."))
	_connect(^"Checkpoint1", func(): checkpoint = maxi(checkpoint, 1))
	_connect(^"ExitStreet", _on_exit)
	Sfx.loop(&"docks", self, Vector2.INF, -6.0)
	Sfx.music(&"rainy_noir")
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(black, "color:a", 0.0, 1.0)
	tw.tween_callback(black.get_parent().queue_free)
	if checkpoint == 0 and not arrived:
		arrived = true
		_arrive()


## Pristátie: Ricco stojí v člne, rozhliadne sa, duch ho privíta
func _arrive() -> void:
	player.set_cutscene(true)
	await _wait(1.2)
	player.set_cutscene(false)
	await ThoughtBox.think(self, ARRIVE).finished
	_once(&"welcome", "WELCOME TO NEW YORK, KID.\nWIPE YOUR FEET.")


func _connect(path: NodePath, f: Callable) -> void:
	var a := get_node_or_null(path) as Area2D
	if a:
		a.body_entered.connect(func(b: Node):
			if b == player:
				f.call())


func _process(delta: float) -> void:
	if player == null:
		return
	# lodná siréna z rieky občas zatrúbi
	_horn_t -= delta
	if _horn_t <= 0.0:
		_horn_t = randf_range(24.0, 40.0)
		Sfx.play(&"foghorn", Vector2.INF, -14.0, 0.0, &"Ambience")
	# hlášky ducha po jednej (aby sa neprekrývali)
	_say_busy -= delta
	if _say_busy <= 0.0 and not _say_queue.is_empty():
		_say_busy = 3.4
		bark(_say_queue.pop_front())


## Koniec časti: ulica a strechy sú ďalší krok – zatiaľ TO BE CONTINUED a späť do menu
func _on_exit() -> void:
	if _leaving:
		return
	_leaving = true
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	var black := _fade_rect()
	var cont := _title_label("TO BE CONTINUED...", 16, Color8(245, 235, 209), 0)
	black.add_child(cont)
	var tw := create_tween()
	tw.tween_property(player, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(black, "color:a", 1.0, 1.0)
	tw.tween_property(cont, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.5)
	tw.tween_property(cont, "modulate:a", 0.0, 0.8)
	await tw.finished
	reset()
	LoadingScreen.go(get_tree(), MAIN_MENU, 0.6)


# ---------------------------------------------------------------- duch a hlášky

## Hláška ducha do radu – zaznie, keď dobehne predošlá
func say(t: String) -> void:
	_say_queue.append(t)


## Hláška len raz za hru (prežije smrť – statické barks)
func _once(key: StringName, t: String) -> void:
	if key in barks:
		return
	barks.append(key)
	say(t)


## Krátka hláška ducha nad Riccom (ako v kapitole II – nezastaví hru, sama zmizne)
func bark(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", 8)
	l.add_theme_color_override(&"font_color", Color8(200, 244, 250))
	l.add_theme_color_override(&"font_outline_color", Color8(10, 24, 34))
	l.add_theme_constant_override(&"outline_size", 4)
	l.z_index = 40
	add_child(l)
	l.reset_size()
	var follow := func(): if is_instance_valid(l) and is_instance_valid(player): l.global_position = (player.global_position + Vector2(-l.size.x / 2.0, -78.0 - l.size.y + 18.0)).round()
	follow.call()
	var tw := create_tween()
	tw.tween_method(func(_v: float): follow.call(), 0.0, 1.0, 3.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(2.7)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- pomocné

func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


func _title_label(t: String, size: int, col: Color, dy: float) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)   # cez celú obrazovku, text v strede
	l.offset_top = dy
	l.offset_bottom = dy
	l.modulate.a = 0.0
	return l


func _set_limits(r: Rect2i) -> void:
	pcam.limit_left = r.position.x
	pcam.limit_top = r.position.y
	pcam.limit_right = r.end.x
	pcam.limit_bottom = r.end.y


func _fade_rect() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	return r
