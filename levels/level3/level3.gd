class_name Level3
extends Node2D
## Kapitola III – The Big Apple. Základ kapitoly (statické checkpointy, výbava, hlášky ducha), každá časť z neho dedí.
## Po úvode pri Soche slobody (intro.gd) je časť 1+2 jedna mapa (street.gd): Ricco pristane v člne z Margaret pri nábrežnej
## stene, vylezie po železnom rebríku (world/fx/ladder.gd) na promenádu (lampy, lavička, strážnik s baterkou) a ide rovno
## do ulice a po strechách, odtiaľ po ďalších strechách k stanici Delancey St (časť 3 – roofs.gd), nadzemkou do Harlemu (časť 4 – train.gd)
## a do jazzového klubu The Blue Canary (časť 5 – club.gd: ulica a sála, časť 6 – club_back.gd: zákulisie, Sal),
## potom zadným vchodom do hotela Majestic (časť 7 – hotel.gd: kuchyňa, práčovňa, nákladný výťah) a na gala „M.“
## v Starlight Room a na strechu s nápisom MAJESTIC (časť 8 – hotel_gala.gd) a za svitania na vrchol rozostavaného
## mrakodrapu Iron Mikea (časť 9 – tower.gd: boss Iron Mike, vzducholoď „M.“) a naháňačka taxíkom za vzducholoďou
## cez Manhattan na Queensboro Bridge (časť 10 – chase.gd: zápcha na moste, boss Police Chief Murphy) → kapitola IV.
## Scény píše Claude priamo ako .tscn (_art_src/make_city_scene.py, make_roofs_scene.py, make_train_scene.py… mimo repa),
## len úvod generuje tools/build_level3.gd.
## Godot docs: classes/class_tween, classes/class_canvaslayer, classes/class_area2d

const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const STREET := "res://levels/level3/street.tscn"   ## časť 1+2: rieka → nábrežie → ulica → požiarne schodisko → strechy
const ROOFS := "res://levels/level3/roofs.tscn"     ## časť 3: strechy (billboard, holubník, dielňa, nádrž) → stanica Delancey St
const TRAIN := "res://levels/level3/train.tscn"     ## časť 4: nadzemka do Harlemu (strechy vozňov, vozeň s cestujúcimi)
const CLUB := "res://levels/level3/club.tscn"       ## časť 5: Lenox Ave a sála klubu The Blue Canary
const CLUB_BACK := "res://levels/level3/club_back.tscn"   ## časť 6: zákulisie, pivnica, herňa a kancelária Velvet Sala
const HOTEL := "res://levels/level3/hotel.tscn"     ## časť 7: hotel Majestic – ulička, kuchyňa, poschodie, práčovňa, výťah
const HOTEL_GALA := "res://levels/level3/hotel_gala.tscn"   ## časť 8: gala v Starlight Room, strecha s nápisom MAJESTIC
const TOWER := "res://levels/level3/tower.tscn"     ## časť 9: veža Iron Mikea – oceľová kostra, žeriav, boss, vzducholoď
const CHASE := "res://levels/level3/chase.tscn"     ## časť 10: taxík za vzducholoďou, zápcha na Queensboro Bridge, Chief Murphy
const LoadingScreen := preload("res://ui/loading/loading_screen.gd")
const REVOLVER := preload("res://weapons/revolver/revolver.tres")
const LUPARA := preload("res://weapons/lupara/lupara.tres")
const TOMMY := preload("res://weapons/tommy/tommy.tres")
const GHOST := preload("res://characters/don/ghost_don.png")
const GLOW := preload("res://levels/level1/art/glow.png")
const FONT := preload("res://ui/fonts/tiny5.ttf")
const NIGHT := Color(0.72, 0.8, 0.86)               ## mafiáni sú v nočnom svetle tmavší (Ricco sa stmavuje sám)
const TOMMY_START_AMMO := 20                        ## náboje do Thompsonu sú v kapitole III vzácne – len to, čo ostalo v bubne

## 0 = v člne pri stene, 1 = hore na promenáde, 2 = začiatok ulice, 3 = strecha pizzerie, 4 = strecha holičstva (všetko street.gd),
## 5–8 = strechy (roofs.gd: za dverami schodiska, za doskou, strecha dielne, požiarne schodisko),
## 9–13 = nadzemka (train.gd – strecha vozňa 1, potom pred vozňami 3, 4, 5 a 6),
## 14–16 = klub (club.gd – stanica 125 St, vnútri, lávka nad sálou),
## 17–21 = zákulisie (club_back.gd – zákulisie, šatne, pivnica, šachta pri herni, strecha),
## 22–25 = hotel (hotel.gd – ulička, príjem / galéria, poschodie, práčovňa),
## 26–29 = gala (hotel_gala.gd – špajza čašníkov, Starlight Room, balkón, strecha),
## 30–32 = veža (tower.gd – stavenisko, 3. poschodie, vrchol – boj s Iron Mikeom),
## 33–36 = naháňačka (chase.gd – taxík, most po nehode, stred mosta, pred zábranami – boj s Chiefom Murphym).
## Statické premenné prežijú smrť (reload scény), úvodné menu a koniec kapitoly II ich vynulujú (reset()).
static var checkpoint: int = 0
static var arrived: bool = false                    ## Riccove myšlienky po pristátí už zazneli
static var barks: Array[StringName] = []            ## hlášky ducha, ktoré už zazneli (len raz za hru)
static var street_arrived: bool = false             ## Riccove myšlienky na začiatku ulice už zazneli
static var tommy_ammo: Array = [TOMMY_START_AMMO, 0]  ## náboje Thompsonu [v bubne, v zásobe] – prenesú sa do ďalšej časti
static var roofs_arrived: bool = false              ## Riccove myšlienky na začiatku striech už zazneli
static var train_arrived: bool = false              ## Riccove myšlienky na streche vlaku už zazneli
static var club_arrived: bool = false               ## Riccove myšlienky pred klubom už zazneli
static var club_back_arrived: bool = false          ## Riccove myšlienky v zákulisí už zazneli
static var club_loud: bool = false                  ## v sále bol poplach – Sal sa v kancelárii zamkne (club_back.gd)
static var hotel_arrived: bool = false              ## Riccove myšlienky v uličke za hotelom už zazneli
static var lift_key: bool = false                   ## Ricco má kľúč od nákladného výťahu (hotel.gd – búdka predáka práčovne)
static var hotel_loud: bool = false                 ## v hoteli bol poplach – na gale sú bossovia pripravení (hotel_gala.gd)
static var gala_arrived: bool = false               ## Riccove myšlienky v špajzi čašníkov už zazneli
static var toast_done: bool = false                 ## prípitok Iron Mikea na gale už bol (po smrti sa neopakuje)
static var tower_arrived: bool = false              ## Riccove myšlienky na stavenisku veže už zazneli
static var mike_phase: int = 0                      ## dosiahnutá fáza boja s Iron Mikeom (po smrti pokračuje v nej; 0 = ešte nezačal)
static var mike_revealed: bool = false              ## Mike už raz vyšiel na nosníku hore (po smrti bez úvodu)
static var chase_arrived: bool = false              ## úvod naháňačky (taxikár, Riccove myšlienky) už bol
static var chase_wave: int = 0                      ## dosiahnutá vlna prenasledovateľov v taxíku (po smrti pokračuje od nej)
static var murphy_phase: int = 0                    ## dosiahnutá fáza boja s Chiefom Murphym (0 = ešte nezačal)
static var murphy_revealed: bool = false            ## Murphy už raz zakričal z voza (po smrti bez úvodu)
static var carried: Array[WeaponData] = []          ## výbava pri vstupe do časti (napr. Colt 1911 namiesto revolvera); prázdne = začiatočná

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
	street_arrived = false
	roofs_arrived = false
	train_arrived = false
	club_arrived = false
	club_back_arrived = false
	club_loud = false
	hotel_arrived = false
	lift_key = false
	hotel_loud = false
	gala_arrived = false
	toast_done = false
	tower_arrived = false
	mike_phase = 0
	mike_revealed = false
	chase_arrived = false
	chase_wave = 0
	murphy_phase = 0
	murphy_revealed = false
	barks.clear()
	tommy_ammo = [TOMMY_START_AMMO, 0]
	carried.clear()
	Food.reset()   # nesené jedlo (props/food/food.gd)


## Scéna časti kapitoly podľa checkpointu (po smrti sa pokračuje tam)
static func part_for(cp: int) -> String:
	if cp >= 33:
		return CHASE
	if cp >= 30:
		return TOWER
	if cp >= 26:
		return HOTEL_GALA
	if cp >= 22:
		return HOTEL
	if cp >= 17:
		return CLUB_BACK
	if cp >= 14:
		return CLUB
	if cp >= 9:
		return TRAIN
	if cp >= 5:
		return ROOFS
	return STREET


## Spoločný začiatok každej časti kapitoly: hráč, kamera, výbava, tma, spawn podľa checkpointu, noc na nepriateľoch.
## Vráti čiernu clonu (stiahne ju _fade_in), null = v scéne nie je hráč.
func _setup(map: Rect2i) -> ColorRect:
	var black := _fade_rect()
	black.color.a = 1.0
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return null
	pcam = player.get_node(^"PhantomCamera2D")
	_set_limits(map)
	var help := get_node_or_null(^"HUD/ControlsHelp") as Control
	if help:
		help.visible = false
	# výbava z kapitoly II: revolver, lupara a Thompson po Lou – do neho len pár nábojov (krabičky sú vzácne);
	# čo Ricco cestou vymenil (Colt 1911 z nadzemky), ide do ďalšej časti so sebou (carried)
	var list: Array[WeaponData] = [REVOLVER, LUPARA, TOMMY]
	if not carried.is_empty():
		list.assign(carried)
	player.set_loadout(list)
	var ti: int = list.find(TOMMY)
	if ti >= 0:
		player.weapon_ammo[ti] = tommy_ammo.duplicate()
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
	return black


func _fade_in(black: ColorRect) -> void:
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(black, "color:a", 0.0, 1.0)
	tw.tween_callback(black.get_parent().queue_free)


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
	_tick_say(delta)


## Hlášky ducha po jednej (aby sa neprekrývali)
func _tick_say(delta: float) -> void:
	_say_busy -= delta
	if _say_busy <= 0.0 and not _say_queue.is_empty():
		_say_busy = 3.4
		bark(_say_queue.pop_front())


## Odchod dverami: zvuk dverí, Ricco zmizne, stmievačka a ďalšia časť kapitoly (sound = false – bez dverí, napr. z nástupišťa)
func _leave_door(path: String, cp: int, sound: bool = true) -> void:
	if _leaving:
		return
	_leaving = true
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	if sound:
		Sfx.play(&"door_open", player.global_position, -6.0)
	var black := _fade_rect()
	var tw := create_tween()
	tw.tween_property(player, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(black, "color:a", 1.0, 0.8)
	await tw.finished
	_go_next(path, cp)


## Do ďalšej časti kapitoly: checkpoint jej začiatku, výbava a náboje Thompsonu idú so sebou
func _go_next(path: String, cp: int) -> void:
	checkpoint = maxi(checkpoint, cp)
	carried.assign(player.loadout)
	var ti: int = carried.find(TOMMY)
	if ti >= 0:
		tommy_ammo = (player.weapon_ammo[ti] as Array).duplicate()
	LoadingScreen.go(get_tree(), path, 0.4)


## Zatiaľ koniec kapitoly: TO BE CONTINUED a späť do menu
func _to_be_continued() -> void:
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


## Krátka replika postavy nad jej hlavou (mafiáni, krajčír, motorovodič) – nezastaví hru, sama zmizne.
## dy = výška textu nad nohami postavy (stojaca ~84 px, kľačiaca menej)
func _speak(who: Node2D, t: String, dy: float = 84.0) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", 8)
	l.add_theme_color_override(&"font_color", Color8(245, 232, 200))
	l.add_theme_color_override(&"font_outline_color", Color8(20, 14, 12))
	l.add_theme_constant_override(&"outline_size", 4)
	l.z_index = 40
	add_child(l)
	l.reset_size()
	var follow := func(): if is_instance_valid(l) and is_instance_valid(who): l.global_position = (who.global_position + Vector2(-l.size.x / 2.0, -dy - l.size.y + 14.0)).round()
	follow.call()
	var tw := create_tween()
	tw.tween_method(func(_v: float): follow.call(), 0.0, 1.0, 2.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(2.4)
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
