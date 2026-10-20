extends SceneTree
## Nástroj: vygeneruje levels/level2/docks.tscn (Kapitola II – prístav, móla v hmle) a levels/level2/tiles_docks.tres.
## Spustenie: godot --headless --path . --script res://tools/build_docks.gd
## Mapa je v dlaždiciach (16 px). Hladina vody je na y = 0, paluba mól o dlaždicu vyššie (y = −16), dno na y = 80.
## Ide sa zľava doprava:
##   nábrežie s pašeráckym kanálom (sem vedie tunel z krypty) → mólo 1 s dokárom s hákom a lampášom (popod mólo sa pláva) →
##   rybárska loď s lampášom (rybár s luparou – zozadu ho zložíš, lupara je tvoja) →
##   mólo 2 so psom na reťazi (zacíti ťa, pod vodou nie) a dvoma strelcami; po móloch prechádza lúč majáka →
##   voda medzi mólom 2 a Pier 13 – na preplávanie (v diaľke maják na skale a loď S.S. Margaret, za oknom mostíka Big Lou) →
##   Pier 13: dokár s hákom, strelec pred skladom Fontana Shipping → dvere skladu = koniec časti.
## Udalosti (duch, lupara, Lou, koniec) sú v levels/level2/docks.gd.
## Godot docs: classes/class_tilemaplayer, class_parallax2d, class_packedscene, class_cpuparticles2d.

const T := 16
const ART := "res://levels/level2/art/docks/"
const L1 := "res://levels/level1/art/"
const L2 := "res://levels/level2/art/"

# súradnice v atlase tiles_docks.png
const QUAY_TOP := Vector2i(0, 0)
const QUAY := Vector2i(1, 0)
const QUAY_WET := Vector2i(2, 0)
const BED_TOP := Vector2i(3, 0)
const BED := [Vector2i(4, 0), Vector2i(4, 0), Vector2i(4, 0), Vector2i(7, 0)]
const ROCK_TOP := Vector2i(5, 0)
const ROCK := Vector2i(6, 0)

const END_X := 157            ## pravý koniec levelu (dlaždice)
const DECK_Y := -16           ## px – vrch paluby mól
const BED_ROW := 5            ## riadok dna (y = 80 px)
const QUAY1 := 14             ## nábrežie na začiatku: x < 14
const QUAY2 := 141            ## nábrežie na konci: x ≥ 141 (sklad Fontana Shipping)
## Mólá [od, do] v dlaždiciach – medzi nimi voda (tadiaľ sa skáče do vody; cez palubu sa dá len vyskočiť zospodu)
const PIERS := [[16, 26], [28, 40], [64, 100], [113, 139]]
const BOAT_X := 44            ## rybárska loď (16 dlaždíc, 44–60), z oboch strán 4 dlaždice vody
const LIGHTHOUSE_X := 106.5   ## odtiaľ (dlaždica) dopadá lúč majáka na móla – samotný maják je v diaľke (FarLighthouse)
const LIGHTHOUSE_PARALLAX := 0.3   ## maják v diaľke sa posúva pomalšie ako loď
const SHIP_PARALLAX := 0.45   ## loď v diaľke – vodorovne sa posúva pomalšie

var rng := RandomNumberGenerator.new()
var lvl: Node2D
var solid: TileMapLayer
var _props_root: Node2D


func _init() -> void:
	rng.seed = 1932
	var ts := _make_tileset()
	ResourceSaver.save(ts, "res://levels/level2/tiles_docks.tres")
	ts = load("res://levels/level2/tiles_docks.tres")

	lvl = Node2D.new()
	lvl.name = "Docks"
	lvl.set_script(load("res://levels/level2/docks.gd"))

	_sky()
	_props_root = _node(Node2D.new(), "Props", lvl)
	_props_root.z_index = -5
	solid = _layer("Solid", ts, 0)

	_build_ground()
	_build_start()
	_build_piers()
	_build_boat()
	_build_pier2()
	_build_lighthouse()
	_build_pier13()
	_water()
	_fog()

	_build_food()
	var ricco: Node2D = load("res://characters/ricco/ricco.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(ricco, "Ricco", lvl)
	ricco.position = Vector2(4 * T, DECK_Y)
	var hud: Node = load("res://ui/hud.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(hud, "HUD", lvl)

	var scene := PackedScene.new()
	print("pack docks: ", scene.pack(lvl))
	print("save docks: ", ResourceSaver.save(scene, "res://levels/level2/docks.tscn"))
	lvl.free()
	quit()


# ---------------------------------------------------------------- pomocné (ako v build_level2.gd)

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


func _layer(nm: String, ts: TileSet, z: int) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = ts
	l.z_index = z
	_node(l, nm, lvl)
	return l


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


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load(ART + "tiles_docks.png")
	src.texture_region_size = Vector2i(T, T)
	for x in 8:
		src.create_tile(Vector2i(x, 0))
	ts.add_source(src, 0)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for x in 8:
		var td := src.get_tile_data(Vector2i(x, 0), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full)
	return ts


func _fill(x0: int, y0: int, x1: int, y1: int, tiles) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var t: Vector2i = tiles if tiles is Vector2i else tiles[rng.randi() % tiles.size()]
			solid.set_cell(Vector2i(x, y), 0, t)


func _sprite(tex: String, pos: Vector2, parent: Node = null, nm: String = "") -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(tex if tex.begins_with("res://") else ART + tex)
	s.centered = false
	s.position = pos
	_node(s, nm if nm != "" else tex.get_file().get_basename().to_pascal_case(), parent if parent else _props_root)
	return s


## Pruh opakovaného obrázka (paluba, voda) – region cez celú šírku
func _strip(tex: String, pos: Vector2, size: Vector2, z: int, nm: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(ART + tex)
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


## Jednosmerná plošina (paluba mólu, lode) – z vody sa na ňu dá vyskočiť zospodu
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


## Debna na palube – pevná (kryt aj schod)
func _crate(tex: String, x: float, y_bottom: float) -> void:
	var s := _sprite(tex, Vector2(x, y_bottom - 20), null, "Crate")
	s.z_index = -1
	_block("CrateBody", Rect2(x, y_bottom - 20, 30, 20))


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


## Strelec s revolverom (ako na cintoríne)
func _gunman(nm: String, pos: Vector2, face: float, props: Dictionary) -> Node2D:
	var p := {"kind": "tommy", "weapon": load("res://weapons/revolver/revolver.tres"), "pellets": 1, "spread_deg": 3.0,
			"bullet_lifetime": 1.4, "preferred_range": 0.0, "cooldown": Vector2(1.0, 1.5), "sight_range": 280.0, "aim_time": 0.75}
	p.merge(props, true)
	return _enemy("gangster_coppola", nm, pos, face, p)


## Dokár s lodným hákom a lampášom – bitkár, hák má dlhší dosah a Ricca pritiahne
func _docker(nm: String, x: float, span: float) -> Node2D:
	return _enemy("gangster_bruiser", nm, Vector2(x * T, DECK_Y), -1.0, {"kind": "dock", "hook": true, "punch_range": 46.0,
			"flashlight": true, "patrol_span": span, "walk_speed": 28.0, "max_health": 4})


# ---------------------------------------------------------------- obloha, vzdialený prístav, more, loď

func _sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -20
	_node(layer, "Sky", lvl)
	var tr := TextureRect.new()
	tr.texture = load(L2 + "sky.png")
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	_node(tr, "Gradient", layer)
	var mg := Sprite2D.new()
	mg.texture = load(L1 + "glow.png")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mg.material = m
	mg.modulate = Color(0.65, 0.82, 0.82, 0.35)
	mg.scale = Vector2(2.4, 2.4)
	mg.position = Vector2(520, 54)
	_node(mg, "MoonGlow", layer)
	var moon := Sprite2D.new()
	moon.texture = load(L1 + "moon.png")
	moon.scale = Vector2(2, 2)
	moon.position = Vector2(520, 54)
	_node(moon, "Moon", layer)
	# druhá strana zálivu (sklady, žeriavy) a vzdialená hladina – obzor na y = −44
	for spec in [["Harbor", "far_harbor.png", 0.2, -44.0 - 112.0, -30], ["Sea", "sea_far.png", 0.25, -44.0, -29]]:
		var p := Parallax2D.new()
		p.scroll_scale = Vector2(spec[2], 1.0)
		p.repeat_size = Vector2(640, 0)
		p.repeat_times = 4
		p.z_index = spec[4]
		_node(p, "Far" + spec[0], lvl)
		var s := Sprite2D.new()
		s.texture = load(ART + spec[1])
		s.centered = false
		s.position = Vector2(-640, spec[3])
		_node(s, "Sprite", p)
	# S.S. Margaret v diaľke – na mostíku za oknom Big Lou (cigara mu občas zažiari, docks.gd)
	var ship_p := Parallax2D.new()
	ship_p.scroll_scale = Vector2(SHIP_PARALLAX, 1.0)
	ship_p.z_index = -28
	_node(ship_p, "FarShip", lvl)
	var ship := Sprite2D.new()
	ship.texture = load(ART + "ship_bg.png")
	ship.centered = false
	ship.position = Vector2(1080, -44 - 94 + 3)    # vodorys lode (y 94 v obrázku) na obzore
	_node(ship, "Ship", ship_p)
	var cigar := _glow(Vector2(147, 46), Color(1.0, 0.45, 0.2, 0.0), 0.12, ship)
	cigar.name = "Cigar"
	cigar.z_index = 0
	var bridge := _glow(Vector2(145, 36), Color(0.9, 0.85, 0.6, 0.35), 0.5, ship)
	bridge.name = "BridgeLamp"
	bridge.z_index = 0
	# bója so zvonom ďaleko na vode
	var buoy_p := Parallax2D.new()
	buoy_p.scroll_scale = Vector2(0.6, 1.0)
	buoy_p.z_index = -27
	_node(buoy_p, "FarBuoy", lvl)
	var b := Sprite2D.new()
	b.texture = load(ART + "buoy.png")
	b.centered = false
	b.position = Vector2(560, -44 + 4 - 24)
	b.scale = Vector2(0.7, 0.7)
	_node(b, "Buoy", buoy_p)


# ---------------------------------------------------------------- nábrežia, dno

func _build_ground() -> void:
	_fill(-4, BED_ROW, END_X + 4, BED_ROW, BED_TOP)
	_fill(-4, BED_ROW + 1, END_X + 4, BED_ROW + 4, BED)
	for x0x1 in [[-4, QUAY1 - 1], [QUAY2, END_X + 4]]:
		_fill(x0x1[0], -1, x0x1[1], -1, QUAY_TOP)
		_fill(x0x1[0], 0, x0x1[1], BED_ROW - 1, QUAY_WET)
	# okraje levelu – neviditeľná stena až hore
	for x0 in [-2, END_X]:
		_block("Edge", Rect2(x0 * T, -40 * T, 2 * T, 46 * T))


# ---------------------------------------------------------------- 1. nábrežie s kanálom (sem vedie tunel z krypty)

func _build_start() -> void:
	var c := _sprite("culvert.png", Vector2(-1 * T, DECK_Y - 120), null, "Culvert")
	c.z_index = -6
	_marker("Spawn4", Vector2(3.5 * T, DECK_Y))
	_sprite("bollard.png", Vector2(10 * T, DECK_Y - 10), null, "Bollard")
	_glow(Vector2(3 * T, DECK_Y - 20), Color(0.6, 0.8, 0.8, 0.12), 3.0)   # mesačné svetlo na hmle pri štarte
	_trigger("SwimBark", Vector2(15 * T, 40), Vector2(2 * T, 80))       # prvý skok do vody


# ---------------------------------------------------------------- mólá (paluba, koly, vzpery)

func _build_piers() -> void:
	for pr in PIERS:
		var x0: float = pr[0] * T
		var x1: float = pr[1] * T
		_oneway(Vector2(x0, DECK_Y), x1 - x0, "Deck")
		_strip("deck.png", Vector2(x0, DECK_Y), Vector2(x1 - x0, 8), -1, "DeckBoards")
		var k := 0
		var px: float = x0 + 6.0
		while px < x1 - 4.0:
			var pile := _sprite("pile.png", Vector2(px, DECK_Y + 8), null, "Pile")
			pile.z_index = -2
			if k % 2 == 0 and px + 32.0 < x1:
				var br := _sprite("brace.png", Vector2(px + 4.0, DECK_Y + 8), null, "Brace")
				br.z_index = -3
			k += 1
			px += 32.0
		# predné koly (bližšie k nám, tmavšie) – pod mólom pôsobí hĺbka
		px = x0 + 22.0
		while px < x1 - 4.0:
			var fp := _sprite("pile.png", Vector2(px, DECK_Y + 8), lvl, "FrontPile")
			fp.z_index = 4
			fp.modulate = Color(0.55, 0.6, 0.62)
			px += 64.0
	# mólo 1: debny whisky pri vstupe, bitky, dokár s hákom a lampášom
	_crate("crate_whisky.png", 17 * T, DECK_Y)
	_crate("crate_whisky.png", 19 * T, DECK_Y)
	_crate("crate.png", 19 * T, DECK_Y - 20)
	for bx in [22, 30, 38]:
		_sprite("bollard.png", Vector2(bx * T, DECK_Y - 10), null, "Bollard")
	_docker("Docker1", 32, 100.0)


# ---------------------------------------------------------------- 2. rybárska loď (rybár s luparou)

func _build_boat() -> void:
	var x0: float = BOAT_X * T
	# obrázok 256×132: paluba na y = 108 → v hre −16 (ako mólá, z vody sa na ňu vyskočí), ponor na y = 124 → hladina
	var s := _sprite("boat.png", Vector2(x0, -124), lvl, "Boat")
	# kormidlovňa je vľavo, korma vpravo – odtiaľ sa Ricco dostane k rybárovi zozadu
	s.z_index = -1
	_oneway(Vector2(x0 + 4, DECK_Y), 248.0, "BoatDeck")
	# lampáš na ramene sťažňa (v obrázku boat.png na x 128, y 20) – svetlo okolo lode aj na vode
	var lamp := Vector2(x0 + 128, -124 + 20)
	_glow(lamp, Color(1.0, 0.8, 0.45, 0.65), 1.2, null, true)
	_glow(Vector2(lamp.x, 0), Color(1.0, 0.75, 0.45, 0.18), 2.4)
	_light(Rect2(x0 - 4, -130, 264, 150))
	# rybár (lupara) stojí na korme pri sieťach, pozerá na mólo 1 a chytá ryby (menej si všíma okolie) –
	# zozadu (sprava, z vody na korme) sa dá zložiť
	_enemy("gangster_coppola", "Fisherman", Vector2(x0 + 196, DECK_Y), -1.0, {"stationary": true, "look_back": Vector2(7.0, 11.0), "close_sense": 18.0})


# ---------------------------------------------------------------- 3. mólo 2: pes na reťazi, strelci, lúč majáka

func _build_pier2() -> void:
	_trigger("Checkpoint5", Vector2(65 * T, -40), Vector2(16, 200))
	_marker("Spawn5", Vector2(65.5 * T, DECK_Y))
	_trigger("LightBark", Vector2(66 * T, -40), Vector2(16, 200))
	_trigger("DogBark", Vector2(67.5 * T, -40), Vector2(16, 200))
	var dog := CharacterBody2D.new()
	dog.set_script(load("res://world/npc/dog.gd"))
	_node(dog, "Dog", lvl)
	dog.position = Vector2(71 * T, DECK_Y)
	var post := _sprite("bollard.png", Vector2(71 * T - 5, DECK_Y - 10), null, "DogPost")
	post.z_index = -1
	_gunman("Gunman1", Vector2(80 * T, DECK_Y), -1.0, {"stationary": true, "look_back": Vector2(5.0, 8.0)})
	_crate("crate_maple.png", 84 * T, DECK_Y)
	_crate("crate_whisky.png", 86 * T, DECK_Y)
	_crate("crate.png", 86 * T, DECK_Y - 20)
	_gunman("Gunman2", Vector2(93 * T, DECK_Y), 1.0, {"patrol_span": 70.0, "walk_speed": 30.0})
	for bx in [67, 76, 90, 98]:
		_sprite("bollard.png", Vector2(bx * T, DECK_Y - 10), null, "Bollard")


# ---------------------------------------------------------------- 4. voda pred Pier 13 (v diaľke maják na skale a loď s Lou)

func _build_lighthouse() -> void:
	var lx: float = LIGHTHOUSE_X * T
	# maják ďaleko na skalke pri obzore (y = −44) – menší, v hmle, posúva sa pomalšie (parallax)
	var far := Parallax2D.new()
	far.scroll_scale = Vector2(LIGHTHOUSE_PARALLAX, 1.0)
	far.z_index = -29
	_node(far, "FarLighthouse", lvl)
	var rock := Polygon2D.new()
	rock.polygon = PackedVector2Array([Vector2(546, -43), Vector2(552, -47), Vector2(560, -49), Vector2(572, -48),
			Vector2(580, -45), Vector2(586, -43)])
	rock.color = Color8(22, 28, 36)
	_node(rock, "Rock", far)
	var lh := Sprite2D.new()
	lh.texture = load(ART + "lighthouse.png")
	lh.centered = false
	lh.scale = Vector2(0.4, 0.4)              # 48×190 → 19×76
	lh.position = Vector2(565 - 9.6, -48 - 76)
	lh.modulate = Color(0.46, 0.53, 0.62)     # v hmle – stmavený do modra ako druhá strana zálivu
	_node(lh, "Tower", far)
	var lamp := Marker2D.new()   # lampa majáka – odtiaľ vychádza lúč (Beam.source)
	lamp.position = Vector2(565, -48 - 76 + 10)   # lampa v obrázku na (24, 26) × 0.4
	_node(lamp, "Lamp", far)
	_glow(lamp.position, Color(1.0, 0.9, 0.6, 0.45), 0.7, far)
	# lúč: škvrna dopadá na móla okolo lx (svetlo, v ktorom ťa vidno), kužeľ sa kreslí od vzdialenej lampy
	var beam := Node2D.new()
	beam.set_script(load("res://world/fx/lighthouse_beam.gd"))
	_node(beam, "Beam", lvl)
	beam.position = Vector2(lx, -196)
	beam.set("source", NodePath("../FarLighthouse/Lamp"))
	beam.set("source_scale", 0.4)
	# medzi mólom 2 a Pier 13 je len voda (13 dlaždíc) – preplávať, v lúči sa ponoriť. Uprostred plávania duch
	# ukáže Lou na lodi v diaľke; checkpoint je tiež vo vode (na móle by Ricco ožil pri strážach)
	_trigger("Checkpoint6", Vector2(lx, 16), Vector2(3 * T, 96))
	_marker("Spawn6", Vector2(lx, 6))
	_trigger("LouView", Vector2(lx, 16), Vector2(8 * T, 96))


# ---------------------------------------------------------------- 5. Pier 13 a sklad Fontana Shipping (koniec)

func _build_pier13() -> void:
	var arch := _sprite("pier_sign.png", Vector2(113 * T, DECK_Y - 86), null, "PierSign")
	arch.z_index = -1
	_docker("Docker2", 125, 110.0)
	_crate("crate_whisky.png", 131 * T, DECK_Y)
	_crate("crate_whisky.png", 133 * T, DECK_Y)
	_crate("crate_maple.png", 133 * T, DECK_Y - 20)
	for bx in [118, 128, 138]:
		_sprite("bollard.png", Vector2(bx * T, DECK_Y - 10), null, "Bollard")
	# sklad na nábreží – svetlo nad dverami, strelec pred ním pozerá na mólo
	var wx: float = QUAY2 * T + 8
	var wh := _sprite("warehouse_end.png", Vector2(wx, DECK_Y - 150), null, "Warehouse")
	wh.z_index = -6
	var door := Vector2(wx + 112, DECK_Y - 24)
	_glow(Vector2(wx + 112, DECK_Y - 58), Color(1.0, 0.8, 0.45, 0.7), 1.3, null, true)
	_glow(Vector2(wx + 112, DECK_Y - 6), Color(1.0, 0.75, 0.45, 0.25), 2.4)
	_light(Rect2(wx + 112 - 3 * T, DECK_Y - 72, 6 * T, 72))
	_trigger("ExitDoor", door, Vector2(24, 48))
	_gunman("Gunman3", Vector2(138 * T, DECK_Y), -1.0, {"stationary": true, "look_back": Vector2(6.0, 9.0)})


# ---------------------------------------------------------------- voda (WaterZone + priesvitná vrstva navrchu)

func _water() -> void:
	var zone := Node2D.new()
	zone.set_script(load("res://world/water/water_zone.gd"))
	var depth: float = BED_ROW * T
	var rects: Array[Rect2] = [Rect2(QUAY1 * T, 0, (QUAY2 - QUAY1) * T, depth)]
	var tops: Array[bool] = [true]
	zone.set("rects", rects)
	zone.set("open_top", tops)
	_node(zone, "Water", lvl)
	# vrstva vody navrchu (Ricco pod hladinou je modrastý), hladina s vlnkami
	_strip("water_deep.png", Vector2(QUAY1 * T, 2), Vector2((QUAY2 - QUAY1) * T, depth - 2), 6, "WaterDeep")
	_strip("water_surface.png", Vector2(QUAY1 * T, -3), Vector2((QUAY2 - QUAY1) * T, 8), 6, "WaterSurface")


# ---------------------------------------------------------------- hmla nad vodou

func _fog() -> void:
	for spec in [["FogBack", -40.0, -11, 0.06, 24.0], ["FogFront", -4.0, 7, 0.07, 8.0]]:
		var p := CPUParticles2D.new()
		p.texture = load(L1 + "glow.png")
		p.amount = 80
		p.lifetime = 10.0
		p.preprocess = 10.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2((END_X + 4) * T / 2.0, spec[4])
		p.direction = Vector2(1, 0)
		p.spread = 10.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 9.0
		p.scale_amount_min = 1.2
		p.scale_amount_max = 2.8
		p.color = Color(0.6, 0.78, 0.82, spec[3])
		p.position = Vector2((END_X - 4) * T / 2.0, spec[1])
		p.z_index = spec[2]
		_node(p, spec[0], lvl)


# ---------------------------------------------------------------- jedlo a lekárničky (props/food/food_pickup.tscn)

## [x, y, druh] – druh "" = jedlo podľa poradia (Food.next_kind – vždy iné), "medkit" = lekárnička. Za behu spadne na zem.
## Rozmiestnenie: móla
const FOOD := [[25 * T, DECK_Y - 12.0, ""], [75 * T, DECK_Y - 12.0, ""], [125 * T, DECK_Y - 12.0, "medkit"]]

func _build_food() -> void:
	for i in FOOD.size():
		var f: Array = FOOD[i]
		var p: Node2D = load("res://props/food/food_pickup.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		_node(p, ("Medkit%d" if f[2] == "medkit" else "Food%d") % (i + 1), lvl)
		p.position = Vector2(f[0], f[1])
		if f[2] != "":
			p.set(&"kind", StringName(f[2]))
