extends SceneTree
## Nástroj: vygeneruje levels/range/range.tscn a levels/range/tiles_club.tres – krytú strelnicu klubu Fontana Gun Club
## (tehlová hala s dreveným obkladom, lampy so zeleným tienidlom, drôty s kladkami pod stropom, betónová podlaha).
## Spustenie: godot --headless --path . --script res://tools/build_range.gd
## Všetka grafika je v levels/range/art/ (generuje ju c7/make_range_art.py mimo repa). Podlaha je na y = 0, strop na y = CEIL.
## Zľava doprava:
##   zbrojnica (5 zbraní na doske, F vezme tú najbližšiu) → skrinka s pákou MODE → priečka a čiara palebnej pozície, tabuľa so skóre →
##   pole 1 (x 480–860): koľajnica s vozíkom, vyskakovacie terče na zemi, miesta pre gangstrov →
##   pole 2 (x 880–1280): bedne s nábojmi, sudy a ochoz s plechovkami/fľašami, nad nimi drôt s kladkami a visiacimi terčmi →
##   vrecia s pieskom na konci.
## Terče a gangstrov pridáva za behu levels/range/shooting_range.gd podľa značiek v uzle Spots (skupiny podľa režimu).
## Godot docs: classes/class_packedscene, classes/class_parallax2d, classes/class_marker2d (metadáta: Object.set_meta)

const T := 16
const ART := "res://levels/range/art/"
const L1 := "res://levels/level1/art/"
const END_X := 84                 ## pravý koniec (dlaždice) = 1344 px
const FLOOR_TOP := Vector2i(0, 0) ## súradnice v atlase tiles_club.png
const FLOOR_FILL: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const CEIL := -232.0              ## spodok stropu
const WAINSCOT := -72.0           ## vrch dreveného obkladu
const WIRE_Y := -184.0            ## drôt s kladkami (visiace terče)
const LEFT := -64.0
const RIGHT := 1408.0

## Zbrane na doske v zbrojnici (zľava)
const RACK := ["res://weapons/derringer/derringer.tres", "res://weapons/pistol/pistol.tres", "res://weapons/revolver/revolver.tres",
		"res://weapons/lupara/lupara.tres", "res://weapons/tommy/tommy.tres"]
const RACK_X := [36.0, 74.0, 112.0, 154.0, 200.0]   ## stredy zbraní na doske (px od ľavého okraja zbrojnice)
const ARMORY_X := 16.0
const SWITCH_X := 272.0
const LINE_X := 292.0             ## čiara palebnej pozície

var lvl: Node2D
var solid: TileMapLayer
var _props: Node2D
var _spots: Node2D


func _init() -> void:
	lvl = Node2D.new()
	lvl.name = "ShootingRange"
	lvl.set_script(load("res://levels/range/shooting_range.gd"))
	ResourceSaver.save(_make_tileset(), "res://levels/range/tiles_club.tres")
	_hall()
	_props = _node(Node2D.new(), "Props", lvl)
	_props.z_index = -5
	solid = TileMapLayer.new()
	solid.tile_set = load("res://levels/range/tiles_club.tres")
	_node(solid, "Solid", lvl)
	_spots = _node(Node2D.new(), "Spots", lvl)
	for g in ["CanSpots", "RailSpots", "SwingSpots", "PaperSpots", "PopupSpots", "GangsterSpots"]:
		_node(Node2D.new(), g, _spots)

	_ground()
	_armory()
	_switch()
	_board()
	_field1()
	_field2()
	_lamps()

	var ricco: Node2D = load("res://characters/ricco/ricco.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(ricco, "Ricco", lvl)
	ricco.position = Vector2(150, 0)
	_marker("Spawn", Vector2(150, 0))
	var hud: Node = load("res://ui/hud.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(hud, "HUD", lvl)

	var scene := PackedScene.new()
	print("pack range: ", scene.pack(lvl))
	print("save range: ", ResourceSaver.save(scene, "res://levels/range/range.tscn"))
	lvl.free()
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


func _marker(nm: String, pos: Vector2, parent: Node = null, meta: Dictionary = {}) -> Marker2D:
	var m := Marker2D.new()
	m.position = pos
	for k in meta:
		m.set_meta(k, meta[k])
	_node(m, nm, parent if parent else lvl)
	return m


func _spot(group: String, pos: Vector2, meta: Dictionary = {}) -> void:
	var parent := _spots.get_node(group)
	_marker("%s%d" % [group.trim_suffix("Spots"), parent.get_child_count() + 1], pos, parent, meta)


func _sprite(tex: String, pos: Vector2, parent: Node = null, nm: String = "") -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(tex)
	s.centered = false
	s.position = pos
	_node(s, nm if nm != "" else tex.get_file().get_basename().to_pascal_case(), parent if parent else _props)
	return s


func _strip(tex: String, pos: Vector2, size: Vector2, z: int, nm: String) -> Sprite2D:
	var s := _sprite(tex, pos, lvl, nm)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, size)
	s.z_index = z
	return s


func _glow(pos: Vector2, col: Color, scale_: float, parent: Node = null) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = load(L1 + "glow.png")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.modulate = col
	g.scale = Vector2.ONE * scale_
	g.position = pos
	g.z_index = 5
	_node(g, "Glow", parent if parent else lvl)
	return g


func _block(nm: String, r: Rect2) -> void:
	var b := StaticBody2D.new()
	_node(b, nm, lvl)
	b.position = r.get_center()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	_node(cs, "Shape", b)


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


## Bedňa s nábojmi (30×20) – pevná, dá sa na ňu vyskočiť aj sa za ňou skryť
func _crate(x: float, y_bottom: float) -> void:
	var s := _sprite(ART + "crate_ammo.png", Vector2(x, y_bottom - 20), null, "Crate")
	s.z_index = 4
	_block("CrateBody", Rect2(x, y_bottom - 20, 30, 20))


func _barrel(x: float) -> void:
	var s := _sprite(ART + "drum.png", Vector2(x, -24), null, "Barrel")
	s.z_index = 4
	_block("BarrelBody", Rect2(x, -24, 18, 24))


# ---------------------------------------------------------------- hala (strop, tehly, obklad, okná, nápis)

func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load(ART + "tiles_club.png")
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for x in 4:
		src.create_tile(Vector2i(x, 0))
		var td := src.get_tile_data(Vector2i(x, 0), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full)
	return ts


func _rect(nm: String, r: Rect2, col: Color, z: int) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	p.color = col
	p.z_index = z
	_node(p, nm, lvl)


func _hall() -> void:
	var w: float = RIGHT - LEFT
	_rect("Dark", Rect2(LEFT, -400, w, 400 + CEIL), Color8(20, 16, 18), -32)          # nad stropom (okraj kamery)
	_strip(ART + "wall_brick.png", Vector2(LEFT, CEIL), Vector2(w, WAINSCOT - CEIL), -31, "BrickWall")
	_strip(ART + "wainscot.png", Vector2(LEFT, WAINSCOT), Vector2(w, -WAINSCOT), -30, "Wainscot")
	_strip(ART + "ceiling.png", Vector2(LEFT, CEIL - 40), Vector2(w, 40), -29, "Ceiling")
	_strip(ART + "pipe.png", Vector2(LEFT, -150), Vector2(w, 8), -29, "Pipe")
	for wx in [96.0, 600.0, 1000.0, 1240.0]:      # vysoké okná s mrežami, vonku noc
		var win := _sprite(ART + "window.png", Vector2(wx, -222), lvl, "Window")
		win.z_index = -30
		_glow(Vector2(wx + 20, -196), Color(0.5, 0.6, 0.9, 0.18), 1.2)
	var b := _sprite(ART + "banner.png", Vector2(340, -214), lvl, "Banner")
	b.z_index = -28
	for i in 5:                                    # čísla dráh nad poľom
		var plate := Sprite2D.new()
		plate.texture = load(ART + "lane_plates.png")
		plate.hframes = 6
		plate.frame = i
		plate.position = Vector2(560 + i * 170, -172)
		plate.z_index = -28
		_node(plate, "Lane%d" % (i + 1), lvl)
	var rules := _sprite(ART + "rules.png", Vector2(252, -150), lvl, "Rules")
	rules.z_index = -28
	var light := Sprite2D.new()                    # svetlo strelnice (shooting_range.gd: zelená = strieľaj, červená = čakaj)
	light.texture = load(ART + "range_light.png")
	light.hframes = 2
	light.position = Vector2(490, -100)
	light.z_index = -6
	_node(light, "RangeLight", lvl)


# ---------------------------------------------------------------- podlaha

func _ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1919
	for x in range(-4, END_X + 5):
		solid.set_cell(Vector2i(x, 0), 0, FLOOR_TOP)
		for y in range(1, 6):
			solid.set_cell(Vector2i(x, y), 0, FLOOR_FILL[rng.randi() % FLOOR_FILL.size()])
	for x0 in [-4, END_X]:   # okraje – neviditeľná stena až hore
		_block("Edge", Rect2(x0 * T, -40 * T, 2 * T, 46 * T))


# ---------------------------------------------------------------- zbrojnica (doska so zbraňami)

func _armory() -> void:
	var a := _sprite(ART + "armory.png", Vector2(ARMORY_X, -104), null, "Armory")
	a.z_index = -6
	var rack := _node(Node2D.new(), "Rack", lvl)
	# jedno miesto na F pred celou doskou – vezme sa zbraň najbližšie k Riccovi (shooting_range.gd, meno ukáže nápoveda)
	var spot := Area2D.new()
	spot.set_script(load("res://world/fx/interact_spot.gd"))
	spot.set(&"verb", "TAKE")
	spot.set(&"once", false)
	spot.set(&"hint_offset", Vector2(0, -92))
	spot.position = Vector2(ARMORY_X + 116, -24)
	_node(spot, "Spot", rack)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(200, 48)
	cs.shape = r
	_node(cs, "Shape", spot)
	for i in RACK.size():
		var w: WeaponData = load(RACK[i])
		var cx: float = ARMORY_X + RACK_X[i]
		var g := Sprite2D.new()
		g.texture = w.texture
		g.position = Vector2(cx, -104 + 52)
		g.z_index = -5
		g.set_meta(&"weapon", RACK[i])
		_node(g, "Gun%d" % (i + 1), rack)
	_glow(Vector2(ARMORY_X + 116, -66), Color(1.0, 0.8, 0.5, 0.35), 2.2)


# ---------------------------------------------------------------- skrinka s pákou (prepínanie režimov)

func _switch() -> void:
	var s := Sprite2D.new()
	s.texture = load(ART + "switch_box.png")
	s.hframes = 2
	s.position = Vector2(SWITCH_X, -22)
	s.z_index = -4
	_node(s, "ModeSwitch", lvl)
	var spot := Area2D.new()
	spot.set_script(load("res://world/fx/interact_spot.gd"))
	spot.set(&"verb", "MODE")
	spot.set(&"once", false)
	spot.set(&"hint_offset", Vector2(0, -34))
	_node(spot, "Spot", s)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(26, 44)
	cs.shape = r
	_node(cs, "Shape", spot)
	_glow(Vector2(SWITCH_X + 4, -20), Color(0.5, 1.0, 0.6, 0.18), 0.6, s)


# ---------------------------------------------------------------- palebná čiara a tabuľa

func _board() -> void:
	var line := Polygon2D.new()
	line.polygon = PackedVector2Array([Vector2(LINE_X, 0), Vector2(LINE_X + 4, 0), Vector2(LINE_X + 4, 2), Vector2(LINE_X, 2)])
	line.color = Color8(226, 186, 70)
	line.z_index = 3
	_node(line, "FiringLine", lvl)
	var b := _sprite(ART + "scoreboard.png", Vector2(306, -110), lvl, "Scoreboard")
	b.z_index = -6
	var div := _sprite(ART + "divider.png", Vector2(LINE_X - 10, -58), lvl, "Divider")   # priečka stanovišťa
	div.z_index = -3


# ---------------------------------------------------------------- pole 1: koľajnica, vyskakovacie terče, gangstri

func _field1() -> void:
	_strip(ART + "rail.png", Vector2(490, -4), Vector2(380, 4), 0, "Rail")
	_spot("RailSpots", Vector2(500, 0), {"span": 350.0, "speed": 80.0})
	for x in [530, 610, 690, 770, 850]:
		_spot("PopupSpots", Vector2(x, 0))
	_spot("GangsterSpots", Vector2(640, 0), {"scene": "gangster_coppola"})
	_spot("GangsterSpots", Vector2(800, 0), {"scene": "gangster_tommy"})


# ---------------------------------------------------------------- pole 2: debny, sudy, lávka, žeriav s hákmi

func _field2() -> void:
	# bedne s nábojmi a sudy (plechovky a fľaše na nich)
	_crate(900, 0)
	_crate(900, -20)
	_crate(930, 0)
	_barrel(984)
	_barrel(1152)
	_barrel(1170)
	_crate(1206, 0)
	_crate(1206, -20)
	_crate(1236, 0)
	# oceľový ochoz (jednosmerná plošina so zábradlím) na dvoch stĺpoch
	_oneway(Vector2(1020, -72), 120.0, "Catwalk")
	_strip(ART + "gallery.png", Vector2(1020, -82), Vector2(120, 14), 3, "CatwalkGrate")
	for px in [1024, 1132]:
		var p := _sprite(ART + "post.png", Vector2(px, -68), null, "Post")
		p.region_enabled = true
		p.region_rect = Rect2(0, 0, 6, 68)
		p.z_index = 2
	for p in [Vector2(915, -40), Vector2(945, -20), Vector2(993, -24), Vector2(1040, -72), Vector2(1080, -72), Vector2(1120, -72),
			Vector2(1161, -24), Vector2(1179, -24), Vector2(1221, -40), Vector2(1251, -20)]:
		_spot("CanSpots", p)
	for p in [Vector2(915, -40), Vector2(1060, -72), Vector2(1100, -72), Vector2(1075, 0), Vector2(1221, -40)]:
		_spot("PopupSpots", p)
	_spot("GangsterSpots", Vector2(1090, 0), {"scene": "gangster_coppola"})
	# drôt pod stropom s kladkami – na nich visia papierové terče a hojdajú sa
	_strip(ART + "wire.png", Vector2(570, WIRE_Y - 12), Vector2(730, 2), -8, "Wire")
	for wx in [968.0, 1104.0]:
		var pl := _sprite(ART + "pulley.png", Vector2(wx - 6, WIRE_Y - 14), null, "Pulley")
		pl.z_index = -7
	_spot("SwingSpots", Vector2(968, WIRE_Y - 4), {"rope": 74.0, "swing_deg": 22.0, "swing_period": 3.2})
	_spot("SwingSpots", Vector2(1104, WIRE_Y - 4), {"rope": 40.0, "swing_deg": 28.0, "swing_period": 2.4})
	# vrecia s pieskom na konci (zachytia guľky)
	var sb := _sprite(ART + "sandbags.png", Vector2(1282, -64), null, "Sandbags")
	sb.z_index = 4
	_block("SandbagsBody", Rect2(1286, -60, 52, 60))


# ---------------------------------------------------------------- lampy

func _lamps() -> void:
	for lx in [150.0, 380.0, 620.0, 860.0, 1090.0, 1290.0]:
		var cord := Line2D.new()                   # šnúra zo stropu
		cord.points = PackedVector2Array([Vector2(lx + 11, CEIL), Vector2(lx + 11, -150)])
		cord.width = 1.0
		cord.default_color = Color8(30, 28, 28)
		cord.z_index = -7
		_node(cord, "Cord", lvl)
		var l := _sprite(ART + "lamp.png", Vector2(lx, -150), null, "Lamp")
		l.z_index = -6
		_glow(Vector2(lx + 11, -122), Color(1.0, 0.86, 0.55, 0.6), 2.4)
		_glow(Vector2(lx + 11, -60), Color(1.0, 0.8, 0.5, 0.16), 4.0)
		_glow(Vector2(lx + 11, -4), Color(1.0, 0.78, 0.45, 0.22), 2.6)
