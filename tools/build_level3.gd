extends SceneTree
## Nástroj: vygeneruje levels/level3/intro.tscn (úvod kapitoly III – čln popri Soche slobody) a
## levels/level3/waterfront.tscn (Kapitola III – nábrežná stena pri East River).
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
