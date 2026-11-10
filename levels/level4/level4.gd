class_name Level4
extends Node2D
## Kapitola IV – The Widow (Long Island, sídlo Margaret Vito). Základ kapitoly (statické checkpointy, výbava, hlášky
## ducha) + časť 1: staré mólo pod útesom (scéna pier.tscn – píše ju _art_src/make_pier_scene.py).
## Ricco priviaže čln na začiatku dlhého prehnitého móla, ktoré trčí do mora. Diery v doskách sa dajú preskočiť,
## alebo sa spadne do vody a pláva sa popod mólo (ticho – pod vodou ho nevidno), z vody vedú rebríky na piliere.
## Čajky na doskách (world/npc/pigeons.gd s obrázkom čajok) pri behu vyletia a prezradia ho, prehnitá doska
## cez tretiu dieru (levels/level3/roof_plank.gd) pri behu praskne. Lampáš na stĺpe sa kýve (levels/level4/sway.gd)
## a dá sa zhasnúť klobúkom. Hliadka s baterkou, strážnik fajčí pred búdou (žeravá cigareta), v búde BAIT & TACKLE
## predavač s luparou za pultom. Na zadnej stene búdy visia siete – za nimi tajné dvere do skaly →
## tunel do jaskyne pašerákov (časť 2 – cave.gd) → lodenica s výťahom do sídla (časť 3 – boathouse.gd)
## → pivnica vily: zatopená stará pivnica, vínna pivnica, vinárstvo, knižnica a trofejová izba (časť 4 – cellar.gd)
## → vila: átrium so schodmi, tri poschodia izieb, strecha a kupola so zrkadlovou sieňou (časť 5 – villa.gd)
## → zrkadlová sieň a strecha so stožiarom: boss Margaret Vito (časť 6 – mirror_hall.gd), Mancini ju zastrelí z gondoly
## → útek z horiacej vily pravým krídlom na útes, svitanie, koniec kapitoly (časť 7 – villa_fire.gd).
## Celé mólo je „tma“ (player.dark_area): vidno ťa len vo svetle lampáša, okna búdy a v kuželi baterky.
## Godot docs: classes/class_tween, classes/class_canvaslayer, classes/class_area2d

const PIER_MAP := Rect2i(0, 40, 1440, 620)          ## hranice kamery (px) – vrch dosiek y 538, hladina y 576
const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const PIER := "res://levels/level4/pier.tscn"         ## časť 1: staré mólo a búda s tajnými dverami
const CAVE := "res://levels/level4/cave.tscn"         ## časť 2: jaskyňa pašerákov (prebaľovňa rumu, háky, loď SEA WIDOW)
const BOATHOUSE := "res://levels/level4/boathouse.tscn"   ## časť 3: lodenica v jaskyni a výťah do vínnej pivnice
const CELLAR := "res://levels/level4/cellar.tscn"     ## časť 4: pivnica vily (štyri poschodia, schody, tajný rebrík)
const VILLA := "res://levels/level4/villa.tscn"       ## časť 5: vila (átrium, tri poschodia, strecha, kupola so zrkadlovou sieňou)
const MIRROR_HALL := "res://levels/level4/mirror_hall.tscn"   ## časť 6: zrkadlová sieň a strecha – boss Margaret
const VILLA_FIRE := "res://levels/level4/villa_fire.tscn"     ## časť 7: útek z horiacej vily na útes
const LoadingScreen := preload("res://ui/loading/loading_screen.gd")
const PISTOL := preload("res://weapons/pistol/pistol.tres")          ## Colt 1911
const WINCHESTER := preload("res://weapons/winchester/winchester.tres")   ## Winchester 1897 po Iron Mikeovi
const TOMMY := preload("res://weapons/tommy/tommy.tres")
const FONT := preload("res://ui/fonts/tiny5.ttf")
const NIGHT := Color(0.72, 0.8, 0.86)               ## mafiáni sú v nočnom svetle tmavší (Ricco sa stmavuje sám)
const TOMMY_START_AMMO := 20                        ## Thompson má stále len pár nábojov

## 0 = mólo (pier.gd = tento skript), 1–2 = jaskyňa (cave.gd – tunel, stredná rímsa),
## 3–4 = lodenica (boathouse.gd – dvere na podkroví, suchý dok).
## Statické premenné prežijú smrť (reload scény), úvodné menu ich vynuluje (reset()).
static var checkpoint: int = 0
static var barks: Array[StringName] = []            ## hlášky ducha, ktoré už zazneli (len raz za hru)
static var arrived: bool = false                    ## Riccove myšlienky pri móle už zazneli
static var cave_arrived: bool = false               ## …v jaskyni
static var boathouse_arrived: bool = false          ## …v lodenici
static var cellar_arrived: bool = false             ## …v pivnici vily
static var villa_arrived: bool = false              ## …vo vile
static var margaret_phase: int = 1                  ## boss Margaret – dosiahnutá fáza (po smrti sa pokračuje v nej)
static var margaret_met: bool = false               ## Margaret už privítala Ricca v sieni
static var fire_arrived: bool = false               ## Riccove myšlienky na streche horiacej vily už zazneli
static var ledger_read: bool = false                ## Ricco čítal knihu v kancelárii jaskyne („C.M.“)
static var tommy_ammo: Array = [TOMMY_START_AMMO, 0]  ## náboje Thompsonu [v bubne, v zásobe] – prenesú sa do ďalšej časti
static var carried: Array[WeaponData] = []          ## výbava pri vstupe do časti; prázdne = začiatočná

const ARRIVE: Array[String] = [
	"Long Island. Gold Coast money up on the cliff, a rotten pier down here.",
	"That's Mike's zeppelin tied up by the house. Whoever 'M.' is, she lives right up there.",
]
const DOOR_THOUGHT: Array[String] = [
	"A door in the rock. Nobody hides a door behind fishing nets for the worms.",
]

var player: Node2D
var pcam: PhantomCamera2D
var _leaving: bool = false
var _horn_t: float = 14.0
var _say_queue: Array[String] = []
var _say_busy: float = 0.0
var _ember: Node2D   ## žeravá cigareta fajčiara pred búdou (Smoker/Ember) – otáča sa s ním, po smrti zhasne


## Nová hra / nová kapitola – všetko odznova
static func reset() -> void:
	checkpoint = 0
	arrived = false
	cave_arrived = false
	boathouse_arrived = false
	cellar_arrived = false
	villa_arrived = false
	margaret_phase = 1
	margaret_met = false
	fire_arrived = false
	ledger_read = false
	barks.clear()
	tommy_ammo = [TOMMY_START_AMMO, 0]
	carried.clear()
	Food.reset()   # nesené jedlo (props/food/food.gd)


## Scéna časti kapitoly podľa checkpointu (po smrti sa pokračuje tam)
static func part_for(cp: int) -> String:
	if cp >= 12:
		return VILLA_FIRE
	if cp >= 11:
		return MIRROR_HALL
	if cp >= 8:
		return VILLA
	if cp >= 5:
		return CELLAR
	if cp >= 3:
		return BOATHOUSE
	if cp >= 1:
		return CAVE
	return PIER


func _ready() -> void:
	if checkpoint >= 1:   # zomrel v jaskyni, v lodenici alebo v pivnici → rovno tam
		get_tree().change_scene_to_file.call_deferred(part_for(checkpoint))
		return
	var black := _setup(PIER_MAP)
	if black == null:
		return
	Progress.reach_chapter(4)
	_connect(^"StartBark", func(): _once(&"pier_start", "THE OLD BAIT SHACK AT THE END.\nNOBODY BUYS WORMS AT MIDNIGHT, KID."))
	_connect(^"GullBark", func(): _once(&"gulls", "GULLS. THEY SCREAM LIKE A WIDOW AT A WAKE.\nWALK SOFT (%s) PAST 'EM." % KeyBindings.short(&"sneak")))
	_connect(^"LampBark", func(): _once(&"pier_lamp", "KNOCK THAT LANTERN OUT WITH YOUR HAT\nAND THE FLASHLIGHT'S ALL HE'S GOT."))
	_connect(^"PlankBark", func(): _once(&"rot_plank", "THAT PLANK'S ROTTEN. TIPTOE -\nOR GO FOR A SWIM."))
	_connect(^"WaterBark", func(): _once(&"pier_swim", "IN THE DRINK? SWIM UNDER THE PIER.\nNOBODY LOOKS DOWN. LADDERS ON THE PILES."))
	_connect(^"ShackBark", func(): _once(&"shack", "NETS ON THE BACK WALL...\nWHO HANGS NETS IN A BAIT SHACK?"))
	_ember = get_node_or_null(^"Smoker/Ember") as Node2D
	var spot := get_node_or_null(^"SecretSpot") as InteractSpot
	if spot:
		spot.used.connect(_open_secret)
	Sfx.loop(&"docks", self, Vector2.INF, -6.0)
	Sfx.music(&"night_cafe")
	_fade_in(black)
	if not arrived:
		arrived = true
		_arrive()


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
	# výbava po kapitole III: Colt 1911, Winchester 1897 (po Iron Mikeovi) a Thompson s pár nábojmi;
	# čo Ricco cestou vymenil, ide do ďalšej časti so sebou (carried)
	var list: Array[WeaponData] = [PISTOL, WINCHESTER, TOMMY]
	if not carried.is_empty():
		list.assign(carried)
	player.akimbo_unlocked = checkpoint >= 12   # duch ukáže druhú ruku na úteku z horiacej vily (villa_fire.gd)
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


## Príchod: Ricco stojí na móle pri člne, rozhliadne sa
func _arrive() -> void:
	player.set_cutscene(true)
	await _wait(1.2)
	player.set_cutscene(false)
	await ThoughtBox.think(self, ARRIVE).finished


func _connect(path: NodePath, f: Callable) -> void:
	var a := get_node_or_null(path) as Area2D
	if a:
		a.body_entered.connect(func(b: Node):
			if b == player:
				f.call())


func _process(delta: float) -> void:
	if player == null:
		return
	# hmlový roh z mora občas zatrúbi
	_horn_t -= delta
	if _horn_t <= 0.0:
		_horn_t = randf_range(26.0, 44.0)
		Sfx.play(&"foghorn", Vector2.INF, -16.0, 0.0, &"Ambience")
	_tick_say(delta)
	if _ember and _ember.visible:
		var smoker := _ember.get_parent() as Gangster
		if smoker == null or smoker.state == Gangster.State.DEAD:
			_ember.visible = false
		else:
			_ember.position.x = 7.0 * smoker.facing   # cigareta je pri ústach – na strane, kam sa pozerá


## Hlášky ducha po jednej (aby sa neprekrývali)
func _tick_say(delta: float) -> void:
	_say_busy -= delta
	if _say_busy <= 0.0 and not _say_queue.is_empty():
		_say_busy = 3.4
		bark(_say_queue.pop_front())


## Siete na zadnej stene búdy: Ricco ich odhrnie, za nimi sú dvere do skaly → tunel do jaskyne
func _open_secret() -> void:
	if _leaving:
		return
	var nets := get_node_or_null(^"Nets") as Sprite2D
	if nets:
		nets.frame = 1
	Sfx.play(&"punch_swing", player.global_position + Vector2(20, -30), -8.0)
	player.set_cutscene(true)
	player.sprite.play(player._hat_anim(&"idle"))
	await ThoughtBox.think(self, DOOR_THOUGHT).finished
	player.set_cutscene(false)
	_leave_door(CAVE, 1)


## Odchod dverami: zvuk dverí, Ricco zmizne, stmievačka a ďalšia časť kapitoly (sound = false – bez dverí)
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


## Je mafián na ceste ešte živý?
func alive(path: NodePath) -> bool:
	var g := get_node_or_null(path) as Gangster
	return g != null and g.state != Gangster.State.DEAD

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


## Krátka hláška ducha nad Riccom (nezastaví hru, sama zmizne)
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


## Krátka replika postavy nad jej hlavou (mafiáni) – nezastaví hru, sama zmizne. dy = výška textu nad nohami
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
