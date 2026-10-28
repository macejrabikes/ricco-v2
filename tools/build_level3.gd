extends SceneTree
## Nástroj: vygeneruje levels/level3/intro.tscn (úvod kapitoly III – čln popri Soche slobody),
## levels/level3/waterfront.tscn (nábrežná stena pri East River) a levels/level3/street.tscn
## (daždivá ulica → požiarne schodisko → strechy so šnúrami – časť STREET nižšie).
## Spustenie: godot --headless --path . --script res://tools/build_level3.gd
## Súradnice v px. Hladina rieky je na y = 0, dno na y = 96, vrch nábrežnej steny (promenáda) na y = −104.
## Ide sa zľava doprava:
##   rieka – Ricco stojí v záchrannom člne z Margaret pri stene → železný rebrík na čele steny (world/fx/ladder.gd) →
##   promenáda: lampa, lavička, strážnik s baterkou → druhá lampa → nájomný dom (začiatok ulice), dvere obchodu = koniec časti.
## Mierka podľa postáv (návrh strechy_AC_vyssie.png): poschodie domu 120 px, okno 30×54, dvere 84 px (mafián ~75 px).
## Udalosti (hlášky ducha, koniec) sú v levels/level3/level3.gd, úvod v levels/level3/intro.gd.
## Godot docs: classes/class_parallax2d, class_packedscene, class_staticbody2d

const ART := "res://levels/level3/art/waterfront/"
const INTRO_ART := "res://levels/level3/art/intro/"
const L1 := "res://levels/level1/art/"
const L2 := "res://levels/level2/art/"

const END_X := 1600.0         ## pravý koniec časti
const WALL_X := 448.0         ## čelo nábrežnej steny (vľavo od neho je rieka)
const WALL_TOP := -104.0      ## promenáda
const BED_Y := 96.0           ## dno rieky
const BOAT_X := 322.0         ## záchranný čln (112 px) – pravý koniec tesne pri rebríku
const HOUSE_X := 1300.0       ## nájomný dom na konci nábrežia (256×440)

var lvl: Node2D
var _props: Node2D


func _init() -> void:
	_build_waterfront()
	_build_intro()
	_build_street()
	quit()


# ---------------------------------------------------------------- pomocné (ako v build_docks.gd)

func _node(n: Node, nm: String, parent: Node) -> Node:
	n.name = nm
	parent.add_child(n)
	_own(n)
	return n


func _own(n: Node) -> void:
	n.owner = lvl
	if n.scene_file_path != "":
		return
	for c in n.get_children():
		_own(c)


func _sprite(tex: String, pos: Vector2, parent: Node = null, nm: String = "") -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(tex if tex.begins_with("res://") else ART + tex)
	s.centered = false
	s.position = pos
	_node(s, nm if nm != "" else tex.get_file().get_basename().to_pascal_case(), parent if parent else _props)
	return s


## Pruh opakovaného obrázka (stena, chodník, zábradlie, voda) – region cez celú šírku
func _strip(tex: String, pos: Vector2, size: Vector2, z: int, nm: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(tex if tex.begins_with("res://") else ART + tex)
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, size)
	s.position = pos
	s.z_index = z
	_node(s, nm, lvl)
	return s


func _glow(pos: Vector2, col: Color, scale_: float, parent: Node = null, flicker: bool = false) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = load(L1 + "glow.png")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.modulate = col
	g.scale = Vector2.ONE * scale_
	g.position = pos
	g.z_index = 5
	if flicker:
		g.set_script(load("res://world/fx/flicker.gd"))
	_node(g, "Glow", parent if parent else lvl)
	return g


func _light(r: Rect2) -> void:
	var a := Area2D.new()
	a.set_script(load("res://world/stealth/light_zone.gd"))
	_node(a, "LightZone", lvl)
	a.position = r.get_center()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	_node(cs, "Shape", a)


func _block(nm: String, r: Rect2) -> void:
	var b := StaticBody2D.new()
	_node(b, nm, lvl)
	b.position = r.get_center()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	_node(cs, "Shape", b)


## Jednosmerná plošina (paluba člna) – z vody sa na ňu dá vyskočiť zospodu
func _oneway(pos: Vector2, width: float, nm: String) -> void:
	var b := StaticBody2D.new()
	b.position = pos
	b.add_to_group(&"platform", true)
	_node(b, nm, lvl)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 4)
	cs.shape = r
	cs.position = Vector2(width / 2.0, 2)
	cs.one_way_collision = true
	_node(cs, "Shape", b)


func _trigger(nm: String, pos: Vector2, size: Vector2) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	_node(a, nm, lvl)
	a.position = pos
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	_node(cs, "Shape", a)
	return a


func _marker(nm: String, pos: Vector2) -> void:
	var m := Marker2D.new()
	_node(m, nm, lvl)
	m.position = pos


func _enemy(scene: String, nm: String, pos: Vector2, face: float, props: Dictionary) -> Node2D:
	var g: Node2D = load("res://characters/gangster/%s.tscn" % scene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	g.set("start_facing", face)
	g.set("needs_light", true)
	g.set("respawn_time", 0.0)
	for k in props:
		g.set(k, props[k])
	_node(g, nm, lvl)
	g.position = pos
	return g


func _parallax(nm: String, tex: String, scroll: float, pos: Vector2, z: int, repeat: bool = true) -> Parallax2D:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scroll, 1.0)
	if repeat:
		p.repeat_size = Vector2(640, 0)
		p.repeat_times = 4
	p.z_index = z
	_node(p, nm, lvl)
	var s := Sprite2D.new()
	s.texture = load(tex)
	s.centered = false
	s.position = pos
	_node(s, "Sprite", p)
	return p


# ---------------------------------------------------------------- NÁBREŽIE (waterfront.tscn)

func _build_waterfront() -> void:
	lvl = Node2D.new()
	lvl.name = "Waterfront"
	lvl.set_script(load("res://levels/level3/level3.gd"))
	_sky()
	_props = _node(Node2D.new(), "Props", lvl)
	_props.z_index = -5
	_build_river()
	_build_wall()
	_build_promenade()
	_build_house()
	_build_food()
	var ricco: Node2D = load("res://characters/ricco/ricco.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(ricco, "Ricco", lvl)
	ricco.position = Vector2(BOAT_X + 50, -1)
	var hud: Node = load("res://ui/hud.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(hud, "HUD", lvl)
	var scene := PackedScene.new()
	print("pack waterfront: ", scene.pack(lvl))
	print("save waterfront: ", ResourceSaver.save(scene, "res://levels/level3/waterfront.tscn"))
	lvl.free()


## Nočná obloha s mesiacom (CanvasLayer – nehýbe sa), za riekou Manhattan a Brooklynský most (parallax)
func _sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -20
	_node(layer, "Sky", lvl)
	var tr := TextureRect.new()
	tr.texture = load(INTRO_ART + "ny_sky.png")
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	_node(tr, "Gradient", layer)
	var mg := Sprite2D.new()
	mg.texture = load(L1 + "glow.png")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mg.material = m
	mg.modulate = Color(0.85, 0.82, 0.65, 0.3)
	mg.scale = Vector2(2.4, 2.4)
	mg.position = Vector2(90, 50)
	_node(mg, "MoonGlow", layer)
	var moon := Sprite2D.new()
	moon.texture = load(L1 + "moon.png")
	moon.scale = Vector2(2, 2)
	moon.position = Vector2(90, 50)
	_node(moon, "Moon", layer)
	# obzor (druhý breh) na y = −40: panoráma, rieka pri obzore, most
	_parallax("FarCity", ART + "skyline.png", 0.15, Vector2(-640, -40 - 130), -30)
	_parallax("FarRiver", ART + "river_far.png", 0.2, Vector2(-640, -40), -29)
	_parallax("Bridge", ART + "bridge.png", 0.3, Vector2(-120, -44 - 108), -28, false)


func _build_river() -> void:
	# dno a okraj levelu
	_block("Bed", Rect2(-64, BED_Y, WALL_X + 64, 64))
	_block("EdgeLeft", Rect2(-32, -600, 32, 760))
	_block("EdgeRight", Rect2(END_X, -600, 32, 760))
	var zone := Node2D.new()
	zone.set_script(load("res://world/water/water_zone.gd"))
	var rects: Array[Rect2] = [Rect2(0, 0, WALL_X, BED_Y)]
	var tops: Array[bool] = [true]
	zone.set("rects", rects)
	zone.set("open_top", tops)
	_node(zone, "Water", lvl)
	# vrstva vody navrchu (Ricco pod hladinou je modrastý), hladina s vlnkami – obrázky z prístavu v kapitole II
	_strip(L2 + "docks/water_deep.png", Vector2(0, 2), Vector2(WALL_X, BED_Y - 2), 6, "WaterDeep")
	_strip(L2 + "docks/water_surface.png", Vector2(0, -3), Vector2(WALL_X, 8), 6, "WaterSurface")
	# záchranný čln z Margaret – Ricco v ňom stojí (nohy 13 px pod okrajom), pravý koniec tesne pri rebríku
	var hull := _sprite(L2 + "ship/lifeboat_boat.png", Vector2(BOAT_X, -14), lvl, "Lifeboat")
	hull.z_index = 1
	_oneway(Vector2(BOAT_X + 4, -1), 104.0, "BoatDeck")
	_marker("Spawn0", Vector2(BOAT_X + 50, -1))
	_trigger("LadderBark", Vector2(BOAT_X + 100, -30), Vector2(24, 60))


## Kamenná stena od rieky po promenádu, pod hladinou tmavšia, riasy pri hladine, rímsa navrchu, železný rebrík na čele
func _build_wall() -> void:
	_block("Wall", Rect2(WALL_X, WALL_TOP, END_X + 64 - WALL_X, BED_Y - WALL_TOP + 64))
	_strip("seawall.png", Vector2(WALL_X, WALL_TOP + 8), Vector2(END_X - WALL_X, -WALL_TOP - 8), -2, "Seawall")
	var under := _strip("seawall.png", Vector2(WALL_X, 0), Vector2(END_X - WALL_X, BED_Y + 32), -2, "SeawallUnder")
	under.modulate = Color(0.45, 0.55, 0.68)
	_strip("algae.png", Vector2(WALL_X, -24), Vector2(END_X - WALL_X, 24), -1, "Algae")
	_strip("coping.png", Vector2(WALL_X - 2, WALL_TOP), Vector2(END_X - WALL_X + 2, 8), -1, "Coping")
	var ladder := Node2D.new()
	ladder.set_script(load("res://world/fx/ladder.gd"))
	ladder.set("length", -WALL_TOP + 22.0)   # kúsok pod hladinu – z vody sa ho dá chytiť
	ladder.set("side", 1.0)
	_node(ladder, "Ladder", lvl)
	ladder.position = Vector2(WALL_X, WALL_TOP)


## Promenáda: zábradlie (za Riccom), lampa so svetlom, lavička, strážnik s baterkou hliadkuje
func _build_promenade() -> void:
	_strip("railing.png", Vector2(WALL_X + 40, WALL_TOP - 24), Vector2(HOUSE_X - 60 - WALL_X, 24), -3, "Railing")
	_trigger("Checkpoint1", Vector2(WALL_X + 40, WALL_TOP - 40), Vector2(16, 80))
	_marker("Spawn1", Vector2(WALL_X + 40, WALL_TOP))
	for lx in [640.0, 1180.0]:
		var post := _sprite(L2 + "lamp_post.png", Vector2(lx - 8, WALL_TOP - 64), null, "LampPost")
		post.z_index = -3
		_glow(Vector2(lx, WALL_TOP - 58), Color(1.0, 0.82, 0.5, 0.7), 1.2, null, true)
		_glow(Vector2(lx, WALL_TOP - 6), Color(1.0, 0.75, 0.45, 0.22), 2.6)
		_light(Rect2(lx - 44, WALL_TOP - 90, 88, 90))
	var bench := _sprite("bench.png", Vector2(720, WALL_TOP - 22), null, "Bench")
	bench.z_index = -3
	_trigger("GuardBark", Vector2(WALL_X + 60, WALL_TOP - 40), Vector2(16, 80))
	# strážnik s revolverom a baterkou – hliadkuje medzi lavičkou a druhou lampou (zozadu sa dá zložiť, klobúk ho omráči)
	_enemy("gangster_coppola", "Guard", Vector2(900, WALL_TOP), -1.0, {"kind": "tommy",
			"weapon": load("res://weapons/revolver/revolver.tres"), "pellets": 1, "spread_deg": 3.0, "bullet_lifetime": 1.4,
			"flashlight": true, "patrol_span": 150.0, "walk_speed": 30.0, "sight_range": 260.0, "aim_time": 0.8,
			"cooldown": Vector2(1.0, 1.5)})


## Nájomný dom na konci nábrežia – začiatok ulice. Dvere obchodu = koniec časti (zatiaľ TO BE CONTINUED).
func _build_house() -> void:
	var h := _sprite("tenement.png", Vector2(HOUSE_X, WALL_TOP - 440), null, "Tenement")
	h.z_index = -6
	_glow(Vector2(HOUSE_X + 100, WALL_TOP - 40), Color(1.0, 0.8, 0.5, 0.25), 3.0)   # svetlo z výkladu
	_light(Rect2(HOUSE_X + 10, WALL_TOP - 80, 180, 80))
	_trigger("ExitStreet", Vector2(HOUSE_X + 211, WALL_TOP - 30), Vector2(30, 60))


## [x, y, druh] – druh "" = jedlo podľa poradia (Food.next_kind), "medkit" = lekárnička. Za behu spadne na zem.
const FOOD := [[740.0, WALL_TOP - 30.0, ""]]

func _build_food() -> void:
	for i in FOOD.size():
		var f: Array = FOOD[i]
		var p: Node2D = load("res://props/food/food_pickup.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		_node(p, ("Medkit%d" if f[2] == "medkit" else "Food%d") % (i + 1), lvl)
		p.position = Vector2(f[0], f[1])
		if f[2] != "":
			p.set(&"kind", StringName(f[2]))


# ---------------------------------------------------------------- ÚVOD (intro.tscn) – bez kamery, súradnice = obrazovka

func _build_intro() -> void:
	lvl = Node2D.new()
	lvl.name = "Intro"
	lvl.set_script(load("res://levels/level3/intro.gd"))
	var sky := _sprite(INTRO_ART + "ny_sky.png", Vector2.ZERO, lvl, "Sky")
	sky.z_index = -10
	var mg := _glow(Vector2(520, 60), Color(0.85, 0.82, 0.65, 0.3), 2.4)
	mg.name = "MoonGlow"
	mg.z_index = -9
	var moon := Sprite2D.new()
	moon.texture = load(L1 + "moon.png")
	moon.scale = Vector2(2, 2)
	moon.position = Vector2(520, 60)
	moon.z_index = -9
	_node(moon, "Moon", lvl)
	var city := _sprite(INTRO_ART + "ny_skyline.png", Vector2(0, 120), lvl, "Skyline")
	city.z_index = -8
	var statue := _sprite(INTRO_ART + "liberty.png", Vector2(16, 50), lvl, "Liberty")
	statue.z_index = -7
	var torch := _glow(Vector2(113, -154), Color(1.0, 0.75, 0.35, 0.6), 0.6, statue, true)   # plameň fakle (v obrázku na 113, 16)
	torch.position = Vector2(113, 16)
	torch.z_index = 0
	var ferry := _sprite(INTRO_ART + "ferry.png", Vector2(250, 248), lvl, "Ferry")
	ferry.z_index = -7
	var sea := _sprite(INTRO_ART + "ny_sea.png", Vector2(0, 270), lvl, "Sea")
	sea.z_index = -6
	# čln ako v závere kapitoly II (epilogue) – Ricco, duch, trup
	var boat := Node2D.new()
	_node(boat, "Boat", lvl)
	boat.position = Vector2(-130, 318)
	var ricco := AnimatedSprite2D.new()
	ricco.sprite_frames = load("res://characters/ricco/ricco_frames.tres")
	ricco.animation = &"idle"
	ricco.position = Vector2(46, -14)
	_node(ricco, "Ricco", boat)
	var ghost := _sprite("res://characters/don/ghost_don.png", Vector2(66, -84), boat, "Ghost")
	ghost.modulate.a = 0.0
	var hull := _sprite(L2 + "ship/lifeboat_boat.png", Vector2(0, -6), boat, "Hull")
	hull.z_index = 1
	var waves := Sprite2D.new()
	waves.texture = load(INTRO_ART + "ny_waves.png")
	waves.centered = false
	waves.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	waves.region_enabled = true
	waves.region_rect = Rect2(0, 0, 640, 24)
	waves.position = Vector2(0, 330)
	waves.z_index = 3
	_node(waves, "Waves", lvl)
	var scene := PackedScene.new()
	print("pack intro: ", scene.pack(lvl))
	print("save intro: ", ResourceSaver.save(scene, "res://levels/level3/intro.tscn"))
	lvl.free()


# ---------------------------------------------------------------- ULICA A STRECHY (street.tscn)
# Ulica je na y = 0 (vrch chodníka). Fasády domov sú pozadie – chodí sa po strechách (jednosmerné plošiny),
# po plošinách požiarneho schodiska a po markízach (trampolína). Dom = [x, šírka, výška strechy nad ulicou, obrázok].
# Obrázok domu (make_ch3_street_art.py) má nad strechou ešte 34 px (rímsa, komíny) – SROOF.

const SART := "res://levels/level3/art/street/"
const S_END := 1980.0
const SROOF := 34.0
const HOUSES := [
	[100.0, 500.0, 480.0, "bldg_a.png"],    # A – Pizzeria Napoli, požiarne schodisko, holuby na streche
	[720.0, 280.0, 360.0, "bldg_b.png"],    # B – Chop Suey, vodná nádrž
	[1000.0, 380.0, 600.0, "bldg_c.png"],   # C – holičstvo, najvyšší (rebrík na boku nad strechou B)
	[1560.0, 420.0, 456.0, "bldg_d.png"],   # D – lahôdky, dvere schodiska na streche = koniec časti
]
## Markízy [x, obrázok] – vrch obrázka na y = −96, plocha na dopad o 18 px nižšie (y = −78)
const AWNINGS := [[110.0, "awning_red.png"], [730.0, "awning_green.png"], [1010.0, "awning_blue.png"]]
## Neóny nad výkladmi [stred x, meno]
const NEONS := [[350.0, "pizzeria", Color(0.4, 1.0, 0.55)], [860.0, "chopsuey", Color(1.0, 0.35, 0.35)], [1190.0, "barber", Color(0.45, 0.7, 1.0)]]
## Plošiny požiarnych schodísk [x od, x do, y]
const ESCAPES := [
	[330.0, 540.0, -136.0], [340.0, 545.0, -256.0], [330.0, 520.0, -376.0],   # pizzeria
	[1580.0, 1720.0, -230.0],                                                  # lahôdky (cesta späť z ulice)
]
## Rebríky [roh x, roh y, strana (1 = rebrík vľavo od rohu), dĺžka] – world/fx/ladder.gd
const S_LADDERS := [
	[360.0, -256.0, 1.0, 120.0], [520.0, -376.0, -1.0, 120.0], [360.0, -480.0, 1.0, 104.0],   # pizzeria: plošina → plošina → strecha
	[868.0, -476.0, 1.0, 116.0],                                                               # vodná nádrž na streche B
	[1000.0, -600.0, 1.0, 240.0],                                                              # bok holičstva nad strechou B
	[1720.0, -230.0, -1.0, 220.0], [1600.0, -456.0, 1.0, 226.0],                              # lahôdky: z ulice na plošinu → strecha
]
## Šnúry s prádlom [stĺp hore x, stĺp dole x, strecha hore y, strecha dole y, kusov prádla]
const LINES := [[578.0, 800.0, -480.0, -360.0, 5], [1356.0, 1640.0, -600.0, -456.0, 6]]
const POLE_TIE := 62.0   ## px nad strechou sa šnúra viaže na stĺp


func _build_street() -> void:
	lvl = Node2D.new()
	lvl.name = "Street"
	lvl.set_script(load("res://levels/level3/street.gd"))
	_street_sky()
	_props = _node(Node2D.new(), "Props", lvl)
	_props.z_index = -5
	# ulica a okraje
	_block("Ground", Rect2(-64, 0, S_END + 128, 64))
	_block("EdgeLeft", Rect2(-32, -900, 32, 964))
	_block("EdgeRight", Rect2(S_END, -900, 32, 964))
	_strip(SART + "street.png", Vector2(-64, 0), Vector2(S_END + 128, 64), -1, "StreetTiles")
	_street_houses()
	_street_escapes()
	_street_lines()
	_street_props()
	_street_lights()
	_street_enemies()
	_street_triggers()
	_street_food()
	var rain := CPUParticles2D.new()
	rain.set_script(load("res://world/fx/rain.gd"))
	_node(rain, "Rain", lvl)
	var ricco: Node2D = load("res://characters/ricco/ricco.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(ricco, "Ricco", lvl)
	ricco.position = Vector2(40, 0)
	var hud: Node = load("res://ui/hud.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(hud, "HUD", lvl)
	var scene := PackedScene.new()
	print("pack street: ", scene.pack(lvl))
	print("save street: ", ResourceSaver.save(scene, "res://levels/level3/street.tscn"))
	lvl.free()


## Obloha s mesiacom (nehýbe sa), za domami panoráma Manhattanu a bližšie siluety domov (parallax)
func _street_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -20
	_node(layer, "Sky", lvl)
	var tr := TextureRect.new()
	tr.texture = load(INTRO_ART + "ny_sky.png")
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	_node(tr, "Gradient", layer)
	var mg := Sprite2D.new()
	mg.texture = load(L1 + "glow.png")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mg.material = m
	mg.modulate = Color(0.85, 0.82, 0.65, 0.3)
	mg.scale = Vector2(2.4, 2.4)
	mg.position = Vector2(470, 56)
	_node(mg, "MoonGlow", layer)
	var moon := Sprite2D.new()
	moon.texture = load(L1 + "moon.png")
	moon.scale = Vector2(2, 2)
	moon.position = Vector2(470, 56)
	_node(moon, "Moon", layer)
	_parallax("FarCity", ART + "skyline.png", 0.1, Vector2(-640, -560), -30)
	_parallax("Backdrop", SART + "backdrop.png", 0.45, Vector2(-640, -420), -28)


func _street_houses() -> void:
	for h in HOUSES:
		var img := _sprite(SART + h[3], Vector2(h[0], -h[2] - SROOF), null, h[3].get_basename().to_pascal_case())
		img.z_index = -6
		_oneway(Vector2(h[0], -h[2]), h[1], "Roof" + h[3].get_basename().right(1).to_upper())
	# bok holičstva nad strechou Chop Suey (stena – zastaví Ricca na streche B, rebrík je na nej)
	_block("WallC", Rect2(1000, -600, 6, 240))
	for a in AWNINGS:
		var aw := Node2D.new()
		aw.set_script(load("res://world/fx/awning.gd"))
		aw.set("texture", load(SART + a[1]))
		_node(aw, "Awning" + a[1].get_basename().get_slice("_", 1).capitalize(), lvl)
		aw.position = Vector2(a[0], -96)
		aw.z_index = -3
	for n in NEONS:
		var on: Texture2D = load(SART + "neon_%s_on.png" % n[1])
		var neon := Sprite2D.new()
		neon.set_script(load("res://world/fx/neon_flicker.gd"))
		neon.set("on_texture", on)
		neon.set("off_texture", load(SART + "neon_%s_off.png" % n[1]))
		neon.texture = on
		neon.centered = false
		neon.position = Vector2(roundf(n[0] - on.get_width() / 2.0), -111)
		neon.z_index = -4
		_node(neon, "Neon" + n[1].capitalize(), lvl)
		var c: Color = n[2]
		_glow(Vector2(on.get_width() / 2.0, 8), Color(c.r, c.g, c.b, 0.45), 1.6, neon)
	var wanted := _sprite(SART + "wanted.png", Vector2(548, -72), null, "Wanted")
	wanted.z_index = -4


## Požiarne schodiská: plošiny (jednosmerné, zábradlie za Riccom) + rebríky medzi nimi
func _street_escapes() -> void:
	var i := 0
	for e in ESCAPES:
		i += 1
		var w: float = e[1] - e[0]
		var rail := _strip(SART + "fire_escape.png", Vector2(e[0], e[2] - 16), Vector2(w, 20), -3, "Escape%d" % i)
		rail.z_index = -3
		for bx in [e[0] + 6, e[1] - 18]:
			var br := _sprite(SART + "fe_bracket.png", Vector2(bx, e[2] + 3), null, "Bracket")
			br.z_index = -4
		_oneway(Vector2(e[0], e[2]), w, "EscapePlatform%d" % i)
	i = 0
	for l in S_LADDERS:
		i += 1
		var lad := Node2D.new()
		lad.set_script(load("res://world/fx/ladder.gd"))
		lad.set("length", l[3])
		lad.set("side", l[2])
		_node(lad, "Ladder%d" % i, lvl)
		lad.position = Vector2(l[0], l[1])


## Šnúry s prádlom medzi strechami – stĺpy na oboch koncoch, kladka čaká hore (world/fx/clothesline.gd)
func _street_lines() -> void:
	var i := 0
	for l in LINES:
		i += 1
		for p in [[l[0], l[2]], [l[1], l[3]]]:
			var pole := _sprite(SART + "pole.png", Vector2(p[0], p[1] - 64), null, "Pole")
			pole.z_index = -3
		var line := Node2D.new()
		line.set_script(load("res://world/fx/clothesline.gd"))
		var top := Vector2(l[0] + 7, l[2] - POLE_TIE)
		var bottom := Vector2(l[1] + 7, l[3] - POLE_TIE)
		line.set("end", bottom - top)
		line.set("clothes", l[4])
		line.set("cloth_seed", i * 7)
		_node(line, "Clothesline%d" % i, lvl)
		line.position = top
	# ozdobné šnúry nad uličkou (nižšie, nedá sa po nich jazdiť)
	var deco := Line2D.new()
	deco.points = PackedVector2Array([Vector2(540, -250), Vector2(660, -236), Vector2(720, -244)])
	deco.width = 1.0
	deco.default_color = Color8(150, 140, 124)
	deco.z_index = -5
	_node(deco, "DecoLine", lvl)
	for k in 4:
		var c := _sprite(SART + "clothes.png", Vector2(560 + k * 38, -249 + k * 3), null, "DecoCloth")
		c.region_enabled = true
		c.region_rect = Rect2(((k * 2 + 1) % 6) * 14, 0, 14, 18)
		c.z_index = -5


## Debny a koše na ulici (kryt, schod na markízu), vodná nádrž, dvere na strechách, holuby
func _street_props() -> void:
	# pri pizzerii: kôš a debny ako schody – z vrchnej debny sa dá vyskočiť na markízu
	_solid_prop("trash_can.png", Vector2(214, 0), "TrashCan")
	_solid_prop("crate.png", Vector2(238, 0), "Crate")
	_solid_prop("crate.png", Vector2(266, 0), "Crate2")
	_solid_prop("crate.png", Vector2(266, -28), "Crate3")   # dve debny na sebe – z nich je markíza na skok
	_solid_prop("trash_can.png", Vector2(1394, 0), "TrashCan2")
	# vodná nádrž na streche Chop Suey – strieška je plošina (navrchu krabička nábojov)
	var wt := _sprite(SART + "water_tower.png", Vector2(860, -490), null, "WaterTower")
	wt.z_index = -4
	_oneway(Vector2(868, -476), 82.0, "TowerTop")
	# dvere schodiska na strechách holičstva a lahôdok (žiarovka nad dverami)
	for d in [[1200.0, -600.0, "RoofDoorC"], [1900.0, -456.0, "RoofDoorD"]]:
		var rd := _sprite(SART + "roof_door.png", Vector2(d[0], d[1] - 64), null, d[2])
		rd.z_index = -4
		_glow(Vector2(d[0] + 28, d[1] - 53), Color(1.0, 0.85, 0.55, 0.6), 0.9, null, true)
		_glow(Vector2(d[0] + 28, d[1] - 20), Color(1.0, 0.8, 0.5, 0.18), 2.4)
		_light(Rect2(d[0] - 40, d[1] - 80, 136, 80))
	# holuby: na streche pizzerie (pri ceste k šnúre – ukážka) a na nádrži (pri krabičke nábojov)
	for pg in [[470.0, -480.0, 4, "PigeonsA"], [884.0, -476.0, 3, "PigeonsTower"], [1080.0, -600.0, 4, "PigeonsC"]]:
		var flock := Node2D.new()
		flock.set_script(load("res://world/npc/pigeons.gd"))
		flock.set("count", pg[2])
		_node(flock, pg[3], lvl)
		flock.position = Vector2(pg[0], pg[1])


func _solid_prop(tex: String, pos: Vector2, nm: String) -> void:
	var t: Texture2D = load(SART + tex)
	var s := _sprite(SART + tex, Vector2(pos.x, pos.y - t.get_height()), null, nm)
	s.z_index = -2
	_block(nm + "Body", Rect2(pos.x + 1, pos.y - t.get_height() + 2, t.get_width() - 2, t.get_height() - 2))


## Svetlo: výklady obchodov, lampy na ulici
func _street_lights() -> void:
	for h in HOUSES:
		if h[3] == "bldg_d.png":
			continue   # lahôdky sú zatvorené – výklad nesvieti
		var sw: float = roundf(h[1] * 0.62)
		_glow(Vector2(h[0] + 14 + sw / 2.0, -40), Color(1.0, 0.8, 0.5, 0.22), 3.0)
		_light(Rect2(h[0] + 14, -74, sw, 74))
	for lx in [650.0, 1470.0]:
		var post := _sprite(L2 + "lamp_post.png", Vector2(lx - 8, -64), null, "LampPost")
		post.z_index = -3
		_glow(Vector2(lx, -58), Color(1.0, 0.82, 0.5, 0.7), 1.2, null, true)
		_glow(Vector2(lx, -6), Color(1.0, 0.75, 0.45, 0.22), 2.6)
		_light(Rect2(lx - 44, -90, 88, 90))


## Policajti dole v ulici (kind „cop“, revolver, baterka, píšťalka) a mafiáni na strechách
func _street_enemies() -> void:
	var revolver: WeaponData = load("res://weapons/revolver/revolver.tres")
	var cop := {"kind": "cop", "weapon": revolver, "pellets": 1, "spread_deg": 3.0, "bullet_lifetime": 1.4,
			"flashlight": true, "whistle": true, "walk_speed": 30.0, "sight_range": 260.0, "aim_time": 0.85,
			"cooldown": Vector2(1.0, 1.5), "preferred_range": 0.0}
	var c1 := cop.duplicate()
	c1["patrol_span"] = 60.0
	_enemy("gangster_coppola", "Cop1", Vector2(660, 0), -1.0, c1)
	var c2 := cop.duplicate()
	c2["patrol_span"] = 140.0
	_enemy("gangster_coppola", "Cop2", Vector2(1300, 0), 1.0, c2)
	# strecha B: brokovník s luparou (gangster_coppola má luparu), stojí otočený k holičstvu, občas sa obzrie
	_enemy("gangster_coppola", "RoofB", Vector2(940, -360), 1.0, {"stationary": true, "look_back": Vector2(3.0, 5.0)})
	# strecha C: strelec s revolverom hliadkuje okolo dverí so žiarovkou
	_enemy("gangster_coppola", "RoofC", Vector2(1250, -600), -1.0, {"weapon": revolver, "pellets": 1, "spread_deg": 3.0,
			"bullet_lifetime": 1.4, "preferred_range": 0.0, "patrol_span": 70.0, "walk_speed": 30.0})
	# strecha D: brokovník pri dverách schodiska, pozerá sa smerom, odkiaľ Ricco prichádza
	_enemy("gangster_coppola", "RoofD", Vector2(1840, -456), -1.0, {"stationary": true, "look_back": Vector2(2.5, 4.5)})


func _street_triggers() -> void:
	_marker("Spawn2", Vector2(40, 0))
	_marker("Spawn3", Vector2(200, -480))
	_marker("Spawn4", Vector2(1040, -600))
	_trigger("StreetBark", Vector2(150, -40), Vector2(16, 80))
	_trigger("AwningBark", Vector2(200, -40), Vector2(16, 80))
	_trigger("WantedThought", Vector2(560, -40), Vector2(20, 80))
	_trigger("Checkpoint3", Vector2(380, -520), Vector2(40, 80))
	_trigger("LineBark", Vector2(540, -520), Vector2(16, 80))
	_trigger("Checkpoint4", Vector2(1030, -640), Vector2(30, 80))
	_trigger("ExitRoof", Vector2(1928, -486), Vector2(20, 60))


## [x, y, druh] – druh "" = jedlo podľa poradia (Food.next_kind), "medkit" = lekárnička
const S_FOOD := [[300.0, -146.0, ""], [760.0, -370.0, ""], [1340.0, -610.0, "medkit"]]

func _street_food() -> void:
	for i in S_FOOD.size():
		var f: Array = S_FOOD[i]
		var p: Node2D = load("res://props/food/food_pickup.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		_node(p, ("StreetMedkit%d" if f[2] == "medkit" else "StreetFood%d") % (i + 1), lvl)
		p.position = Vector2(f[0], f[1])
		if f[2] != "":
			p.set(&"kind", StringName(f[2]))
	# tajomstvo: krabička nábojov (aj do Thompsonu) na striežke vodnej nádrže
	var ammo: Node2D = load("res://props/ammo/ammo_pickup.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(ammo, "SecretAmmo", lvl)
	ammo.position = Vector2(930, -486)
