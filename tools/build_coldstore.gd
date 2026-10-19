extends SceneTree
## Nástroj: vygeneruje levels/level2/coldstore.tscn (Kapitola II – mraziareň Fontana Shipping, návrh A) a tiles_cold.tres.
## Spustenie: godot --headless --path . --script res://tools/build_coldstore.gd
## Mapa je v dlaždiciach (16 px), podlaha je na y = 0. Ide sa zľava doprava cez šesť miestností:
##   1. príjem tovaru (sem vedú dvere skladu z Pier 13) – debny whisky sa prebaľujú do rybích, dokár s hákom, strelec pri stole →
##   2. mraziareň 1 – ľad, koľajnica s hákmi na mäso (chytíš sa a vezieš ponad hliadky), mafián vo veste, studené lampy →
##   3. chodba s potrubím – rúry nízko nad zemou, popod ne len šmykom po ľade, z rúr syčí para →
##   4. mraziareň 2 – veľká hala: regály ako schody, druhá koľajnica, lávka hore, strelec vo veste, lupara, rozbitá debna „rybí“ whisky →
##   5. kancelária Lou (hore na lávke) – účtovná kniha = stopa, strážca vo veste →
##   6. tunel k lodi – kovové schody dolu, pás s debnami do podpalubia, na konci vráta k S.S. Margaret = koniec časti.
## Udalosti (duch, kniha, koniec) sú v levels/level2/coldstore.gd.
## Godot docs: classes/class_tilemaplayer, classes/class_tileset (custom data), classes/class_packedscene

const T := 16
const ART := "res://levels/level2/art/cold/"
const DOCKS_ART := "res://levels/level2/art/docks/"
const L1 := "res://levels/level1/art/"

# súradnice v atlase tiles_cold.png
const ICE_TOP := Vector2i(0, 0)
const ICE := Vector2i(1, 0)
const CONC_TOP := Vector2i(2, 0)
const CONC := Vector2i(3, 0)
const WALL := Vector2i(4, 0)
const WALL_FROST := Vector2i(5, 0)
const WOOD_TOP := Vector2i(6, 0)
const BRICK := Vector2i(7, 0)

const END_X := 312            ## pravý koniec levelu (dlaždice)
## Miestnosti: [od x, po x (bez), horný riadok vnútra, podlaha, pozadie, posun pozadia zhora]
const R1 := [0, 42, -10, "conc", "bg_receiving.png", 0]
const R2 := [44, 110, -14, "ice", "bg_freezer.png", 64]
const R3 := [112, 152, -5, "ice", "bg_pipes.png", 0]
const R4 := [152, 236, -18, "ice", "bg_freezer.png", 0]
const R5 := [237, 252, -15, "wood", "bg_office.png", 8]
const R6 := [252, 312, -12, "conc", "bg_tunnel.png", 0]
const OFFICE_Y := -128        ## px – podlaha kancelárie a lávka v hale 2
const RAIL1_Y := -176         ## px – koľajnica v mraziarni 1
const RAIL2_Y := -200         ## px – koľajnica v hale 2
const BELT := [270, 300]      ## pás v tuneli (dlaždice)
const DOCK_Y := -32           ## px – vyvýšená rampa pri vrátach k lodi
const COLD := Color(0.8, 0.88, 0.96)   ## studený odtieň mafiánov (nastaví coldstore.gd)

var rng := RandomNumberGenerator.new()
var lvl: Node2D
var solid: TileMapLayer
var _props_root: Node2D


func _init() -> void:
	rng.seed = 1929
	var ts := _make_tileset()
	ResourceSaver.save(ts, "res://levels/level2/tiles_cold.tres")
	ts = load("res://levels/level2/tiles_cold.tres")

	lvl = Node2D.new()
	lvl.name = "ColdStore"
	lvl.set_script(load("res://levels/level2/coldstore.gd"))

	_backgrounds()
	_props_root = _node(Node2D.new(), "Props", lvl)
	_props_root.z_index = -5
	solid = _layer("Solid", ts, 0)

	_build_shell()
	_build_receiving()
	_build_freezer1()
	_build_pipes()
	_build_hall()
	_build_office()
	_build_tunnel()
	_frost()

	var ricco: Node2D = load("res://characters/ricco/ricco.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(ricco, "Ricco", lvl)
	ricco.position = Vector2(3 * T, 0)
	var hud: Node = load("res://ui/hud.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(hud, "HUD", lvl)

	var scene := PackedScene.new()
	print("pack coldstore: ", scene.pack(lvl))
	print("save coldstore: ", ResourceSaver.save(scene, "res://levels/level2/coldstore.tscn"))
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


## TileSet: jedna fyzikálna vrstva (všetko pevné) + vlastné dáta "ice" (Ricco sa na takej dlaždici kĺže)
func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "ice")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	var src := TileSetAtlasSource.new()
	src.texture = load(ART + "tiles_cold.png")
	src.texture_region_size = Vector2i(T, T)
	for x in 8:
		src.create_tile(Vector2i(x, 0))
	ts.add_source(src, 0)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for x in 8:
		var td := src.get_tile_data(Vector2i(x, 0), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full)
		td.set_custom_data("ice", Vector2i(x, 0) in [ICE_TOP, ICE])
	return ts


func _fill(x0: int, y0: int, x1: int, y1: int, t: Vector2i) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			solid.set_cell(Vector2i(x, y), 0, t)


func _carve(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			solid.erase_cell(Vector2i(x, y))


func _sprite(tex: String, pos: Vector2, parent: Node = null, nm: String = "", z: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(tex if tex.begins_with("res://") else ART + tex)
	s.centered = false
	s.position = pos
	s.z_index = z
	_node(s, nm if nm != "" else tex.get_file().get_basename().to_pascal_case(), parent if parent else _props_root)
	return s


## Pruh opakovaného obrázka (pozadie, lávka, ľad) – region cez celú šírku
func _strip(tex: String, pos: Vector2, size: Vector2, z: int, nm: String, region_y: float = 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(tex if tex.begins_with("res://") else ART + tex)
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2(0, region_y), size)
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


func _light(r: Rect2, nm: String = "LightZone") -> Area2D:
	var a := Area2D.new()
	a.set_script(load("res://world/stealth/light_zone.gd"))
	_node(a, nm, lvl)
	a.position = r.get_center()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	_node(cs, "Shape", a)
	return a


func _block(nm: String, r: Rect2) -> StaticBody2D:
	var b := StaticBody2D.new()
	_node(b, nm, lvl)
	b.position = r.get_center()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	_node(cs, "Shape", b)
	return b


## Jednosmerná plošina (regál, lávka) – zospodu sa cez ňu dá vyskočiť
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


## Debna (30×20) – pevná, kryt aj schod
func _crate(tex: String, x: float, y_bottom: float) -> void:
	var path: String = tex if tex.begins_with("res://") else ART + tex
	var s := _sprite(path, Vector2(x, y_bottom - 20), null, "Crate", 1)
	s.z_index = -1
	_block("CrateBody", Rect2(x, y_bottom - 20, 30, 20))


func _enemy(scene: String, nm: String, pos: Vector2, face: float, props: Dictionary) -> Node2D:
	var g: Node2D = load("res://characters/gangster/%s.tscn" % scene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	g.set("start_facing", face)
	g.set("needs_light", true)
	g.set("respawn_time", 0.0)
	g.set("cold_breath", true)
	for k in props:
		g.set(k, props[k])
	_node(g, nm, lvl)
	g.position = pos
	return g


## Strelec s revolverom
func _gunman(nm: String, pos: Vector2, face: float, props: Dictionary) -> Node2D:
	var p := {"kind": "tommy", "weapon": load("res://weapons/revolver/revolver.tres"), "pellets": 1, "spread_deg": 3.0,
			"bullet_lifetime": 1.4, "preferred_range": 0.0, "cooldown": Vector2(1.0, 1.5), "sight_range": 280.0, "aim_time": 0.75}
	p.merge(props, true)
	return _enemy("gangster_coppola", nm, pos, face, p)


## Dokár s hákom na mäso a baterkou (ako v prístave)
func _docker(nm: String, x: float, span: float, y: float = 0.0) -> Node2D:
	return _enemy("gangster_bruiser", nm, Vector2(x * T, y), -1.0, {"kind": "dock", "hook": true, "punch_range": 46.0,
			"flashlight": true, "patrol_span": span, "walk_speed": 28.0, "max_health": 4})


## Studená lampa v klietke, ktorú zhasne klobúk alebo guľka (world/fx/hat_lamp.gd): telo + kužeľ + žiara + svetlo.
## light = oblasť svetla v globálnych súradniciach; warm = teplá žiarovka (kancelária, príjem)
func _lamp(pos: Vector2, light: Rect2, top: float, warm: bool = false) -> void:
	var cord := Line2D.new()
	cord.points = PackedVector2Array([Vector2(pos.x, top), Vector2(pos.x, pos.y)])
	cord.width = 1.0
	cord.default_color = Color8(30, 34, 38)
	_node(cord, "Cord", _props_root)
	var b := StaticBody2D.new()
	b.set_script(load("res://world/fx/hat_lamp.gd"))
	_node(b, "Lamp", lvl)
	b.position = pos
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(20, 14)
	cs.shape = rs
	cs.position = Vector2(0, 5)
	_node(cs, "Shape", b)
	var s := Sprite2D.new()
	s.texture = load(L1 + "pendant_lamp.png") if warm else load(ART + "cold_lamp.png")
	s.centered = false
	s.position = Vector2(-8 if warm else -9, 0)
	s.z_index = -4
	_node(s, "Fixture", b)
	var cone := Sprite2D.new()
	cone.texture = load(L1 + "light_cone.png")
	cone.centered = false
	cone.position = Vector2(-56, 10)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cone.material = m
	cone.z_index = 4
	cone.modulate = Color(1, 1, 1) if warm else Color(0.62, 0.8, 1.0)
	cone.scale.y = minf(1.0, (light.end.y - pos.y - 10.0) / 150.0)
	_node(cone, "Cone", b)
	_glow(Vector2(0, 8), Color(1.0, 0.85, 0.55, 0.55) if warm else Color(0.7, 0.88, 1.0, 0.6), 1.2, b)
	var a := Area2D.new()
	a.set_script(load("res://world/stealth/light_zone.gd"))
	_node(a, "Light", b)
	a.position = light.get_center() - pos
	var lcs := CollisionShape2D.new()
	var lrs := RectangleShape2D.new()
	lrs.size = light.size
	lcs.shape = lrs
	_node(lcs, "Shape", a)


## Koľajnica s hákmi (world/coldstore/hook_rail.gd)
func _rail(nm: String, x0: float, x1: float, y: float, speed: float, pattern: String, drop: float, phase: float) -> void:
	var r := Node2D.new()
	r.set_script(load("res://world/coldstore/hook_rail.gd"))
	r.set("length", (x1 - x0) * T)
	r.set("speed", speed)
	r.set("pattern", pattern)
	r.set("carcass_drop", drop)
	r.set("phase", phase)
	_node(r, nm, lvl)
	r.position = Vector2(x0 * T, y)
	# závesy koľajnice do stropu
	var px: float = x0 * T + 24.0
	while px < x1 * T:
		var h := Line2D.new()
		h.points = PackedVector2Array([Vector2(px, y - 80), Vector2(px, y - 3)])
		h.width = 2.0
		h.default_color = Color8(40, 46, 52)
		_node(h, "RailHanger", _props_root)
		px += 128.0


## Regál s policami (jednosmerné plošiny) – schody hore k hákom / na lávku
func _rack(nm: String, x0: float, x1: float, shelves: Array) -> void:
	for xp in [x0 * T + 1, x1 * T - 3]:
		var post := Line2D.new()
		post.points = PackedVector2Array([Vector2(xp, 0), Vector2(xp, float(shelves[-1]) - 6.0)])
		post.width = 3.0
		post.default_color = Color8(54, 62, 68)
		_node(post, nm + "Post", _props_root)
	for sy in shelves:
		_oneway(Vector2(x0 * T, sy), (x1 - x0) * T, nm + "Shelf")
		_strip("catwalk.png", Vector2(x0 * T, sy), Vector2((x1 - x0) * T, 6), -1, nm + "Board")
		# zamrznuté debny na polici (len obrázok – za Riccom)
		var cx: float = x0 * T + 6.0
		while cx + 30.0 < x1 * T - 4.0:
			if rng.randf() < 0.6:
				var c := _sprite("crate_frozen.png" if rng.randf() < 0.6 else "crate_fish.png", Vector2(cx, sy - 20), null, "RackCrate")
				c.z_index = -3
				c.modulate = Color(0.7, 0.76, 0.82)
			cx += 34.0


## Pozadie miestnosti (opakovaný obrázok za všetkým)
func _room_bg(r: Array, nm: String) -> void:
	var x0: float = r[0] * T
	var w: float = (r[1] - r[0]) * T
	var h: float = -r[2] * T
	if r == R5:
		h = -r[2] * T + OFFICE_Y
	var y: float = OFFICE_Y - h if r == R5 else -h
	if r == R5:   # aj za dverami z lávky
		x0 -= T
		w += T
	_strip(r[4], Vector2(x0, y), Vector2(w, h), -10, nm, r[5])


# ---------------------------------------------------------------- pozadia a obal (steny, podlahy, stropy)

func _backgrounds() -> void:
	# tma za stenami (aby medzi miestnosťami nesvietilo pozadie projektu)
	var layer := CanvasLayer.new()
	layer.layer = -20
	_node(layer, "Back", lvl)
	var cr := ColorRect.new()
	cr.color = Color8(8, 10, 14)
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	_node(cr, "Dark", layer)


func _build_shell() -> void:
	_fill(-3, -20, END_X + 3, 4, WALL)
	for r in [R1, R2, R3, R4, R6]:
		_carve(r[0], r[2], r[1] - 1, -1)
		var top: Vector2i = ICE_TOP if r[3] == "ice" else CONC_TOP
		var fill: Vector2i = ICE if r[3] == "ice" else CONC
		_fill(r[0], 0, r[1] - 1, 0, top)
		_fill(r[0], 1, r[1] - 1, 3, fill)
		if r[3] == "ice":
			_fill(r[0] - 1, r[2] - 1, r[1], r[2] - 1, WALL_FROST)
	# dvere príjem → mraziareň 1 (6 dlaždíc vysoké), prielez mraziareň 1 → potrubie (2 dlaždice – len šmykom)
	_carve(42, -6, 43, -1)
	_fill(42, 0, 43, 0, CONC_TOP)
	_carve(110, -2, 111, -1)
	_fill(110, 0, 111, 0, ICE_TOP)
	# kancelária nad tunelom: podlaha z dreva na y = −128, vľavo stena s dverami na lávku
	_carve(R5[0], R5[2], R5[1] - 1, -9)
	_carve(236, -14, 236, -9)
	_fill(236, -8, R5[1] - 1, -8, WOOD_TOP)
	# pás v tuneli je namiesto podlahy (telo pásu je v diere), za ním vyvýšená rampa k vrátam
	_carve(BELT[0], 0, BELT[1] - 1, 0)
	_fill(BELT[1], -2, END_X - 1, -2, CONC_TOP)
	_fill(BELT[1], -1, END_X - 1, 0, CONC)
	for r in [R1, R2, R3, R4, R5, R6]:
		_room_bg(r, "Bg")
	# cencúle pod stropom mraziarní
	for r in [R2, R3, R4]:
		_strip("icicles.png", Vector2(r[0] * T, r[2] * T), Vector2((r[1] - r[0]) * T, 12), -2, "Icicles")


# ---------------------------------------------------------------- 1. príjem tovaru (sem vedú dvere skladu)

func _build_receiving() -> void:
	_sprite(L1 + "steel_door.png", Vector2(0, -80), null, "BackDoor", -4)
	_glow(Vector2(2 * T, -40), Color(1.0, 0.8, 0.5, 0.15), 2.0)
	_marker("Spawn7", Vector2(3.5 * T, 0))
	_sprite("sign_receiving.png", Vector2(6 * T, -122), null, "SignReceiving", -4)
	# prebaľovanie: whisky z debien ide do rybích debien (stopa – duch to okomentuje)
	_crate(DOCKS_ART + "crate_whisky.png", 8 * T, 0)
	_crate(DOCKS_ART + "crate_whisky.png", 10 * T, 0)
	_crate("crate_fish.png", 10 * T, -20)
	_crate("crate_fish.png", 12 * T, 0)
	_sprite("hand_truck.png", Vector2(14.5 * T, -32), null, "HandTruck", -2)
	_sprite(L1 + "barrel.png", Vector2(16 * T, -24), null, "Barrel", -2)
	_trigger("CrateBark", Vector2(9 * T, -40), Vector2(2 * T, 80))
	_lamp(Vector2(22 * T, -112), Rect2(16 * T, -100, 12 * T, 100), -160, true)
	_docker("Docker3", 22, 90.0)
	_crate("crate_plain.png", 28 * T, 0)
	_crate("crate_plain.png", 30 * T, 0)
	_crate("crate_fish.png", 30 * T, -20)
	# predák pri stole s lampou (svieti len okolo stola)
	_sprite("desk.png", Vector2(33 * T, -30), null, "ForemanDesk", -2)
	_sprite("banker_lamp.png", Vector2(34 * T, -42), null, "DeskLamp", -1)
	_glow(Vector2(34 * T + 6, -36), Color(1.0, 0.85, 0.5, 0.5), 1.0, null, true)
	_light(Rect2(32 * T, -72, 9 * T, 72))
	_gunman("Gunman4", Vector2(37 * T, 0), -1.0, {"stationary": true, "look_back": Vector2(5.0, 8.0)})
	# dvere do mraziarne 1 – rám s pásovým závesom (pásy sú pred Riccom)
	_sprite("freezer_door.png", Vector2(41.5 * T, -104), lvl, "FreezerDoor1", 3)
	_sprite("sign_freezer1.png", Vector2(42 * T - 8, -124), lvl, "SignFreezer1", 1)
	_glow(Vector2(43 * T, -40), Color(0.6, 0.85, 1.0, 0.18), 2.2)


# ---------------------------------------------------------------- 2. mraziareň 1 – háky na koľajnici, vesta

func _build_freezer1() -> void:
	_trigger("Checkpoint8", Vector2(45 * T, -60), Vector2(16, 120))
	_marker("Spawn8", Vector2(45.5 * T, 0))
	_trigger("IceBark", Vector2(46 * T, -60), Vector2(16, 120))
	_sprite("thermometer.png", Vector2(47 * T, -96), null, "Thermometer", -4)
	# schody z debien k hákom (vrch najvyššej je na y = −80)
	for k in 4:
		for h in k + 1:
			_crate("crate_frozen.png", (49 + k * 2) * T, -20 * h)
	_trigger("HookBark", Vector2(50 * T, -60), Vector2(16, 120))
	# koľajnica: mäso dosahuje skoro po zem (kryt), voľné háky sú vysoko nad hlavami mafiánov
	_rail("Rail1", 44.5, 109.5, RAIL1_Y, 55.0, "CCHCHCCH", 66.0, 0.0)
	_trigger("VestBark", Vector2(60 * T, -60), Vector2(16, 120))
	_lamp(Vector2(66 * T, -128), Rect2(59 * T, -100, 14 * T, 100), -224)
	_lamp(Vector2(90 * T, -128), Rect2(83 * T, -100, 14 * T, 100), -224)
	_enemy("gangster_bruiser", "VestBrute", Vector2(78 * T, 0), 1.0, {"kind": "bouncer", "vest": true, "patrol_span": 150.0,
			"walk_speed": 26.0, "max_health": 5, "run_speed": 95.0})
	_crate("crate_frozen.png", 97 * T, 0)
	_crate("crate_fish.png", 99 * T, 0)
	_crate("crate_frozen.png", 99 * T, -20)
	_lamp(Vector2(103 * T, -128), Rect2(100 * T, -100, 10 * T, 100), -224)
	_gunman("Gunman5", Vector2(105 * T, 0), -1.0, {"stationary": true, "look_back": Vector2(6.0, 9.0)})
	# prielez do chodby s potrubím (2 dlaždice vysoký – len šmykom)
	_sprite("hatch.png", Vector2(110 * T - 6, -40), lvl, "Hatch", 1)
	_trigger("PipeBark", Vector2(106.5 * T, -60), Vector2(16, 120))


# ---------------------------------------------------------------- 3. chodba s potrubím – len šmykom po ľade

func _build_pipes() -> void:
	for seg in [[112, 120], [125, 131], [137, 147]]:
		var x0: float = seg[0] * T
		var w: float = (seg[1] - seg[0]) * T
		_block("Pipes", Rect2(x0, R3[2] * T, w, -R3[2] * T - 28))
		_strip("pipes_low.png", Vector2(x0, -58), Vector2(w, 30), 2, "PipeBundle")
		for hx in range(int(x0) + 8, int(x0 + w), 48):
			var h := Line2D.new()
			h.points = PackedVector2Array([Vector2(hx, R3[2] * T), Vector2(hx, -58)])
			h.width = 2.0
			h.default_color = Color8(40, 44, 48)
			_node(h, "PipeHanger", _props_root)
	# para z rúr v medzerách (syčí – coldstore.gd)
	for vx in [122.5, 134.0, 149.5]:
		var p := CPUParticles2D.new()
		p.texture = load(ART + "puff.png")
		p.amount = 14
		p.lifetime = 1.6
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(6, 2)
		p.direction = Vector2(0, 1)
		p.spread = 25.0
		p.gravity = Vector2(0, -20)
		p.initial_velocity_min = 10.0
		p.initial_velocity_max = 24.0
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.6
		p.color = Color(0.85, 0.92, 1.0, 0.22)
		p.position = Vector2(vx * T, R3[2] * T + 4)
		p.z_index = 3
		_node(p, "Steam", lvl)
		_marker("Vent", Vector2(vx * T, -40))
	_glow(Vector2(128 * T, -10), Color(0.5, 0.7, 0.9, 0.12), 3.0)


# ---------------------------------------------------------------- 4. mraziareň 2 – veľká hala, regály, lávka

func _build_hall() -> void:
	_trigger("Checkpoint9", Vector2(153 * T, -60), Vector2(16, 120))
	_marker("Spawn9", Vector2(149.5 * T, 0))
	_sprite("sign_freezer2.png", Vector2(154 * T, -150), null, "SignFreezer2", -4)
	_lamp(Vector2(157 * T, -140), Rect2(152 * T, -100, 10 * T, 100), -288)
	_gunman("Gunman6", Vector2(159 * T, 0), -1.0, {"stationary": true, "look_back": Vector2(5.0, 8.0)})
	# ľavý regál – schody k hákom
	_rack("RackL", 163, 169, [-44, -88])
	_rail("Rail2", 160.5, 228.5, RAIL2_Y, 55.0, "CHCCHCH", 66.0, 20.0)
	# rozbitá „rybia“ debna – vnútri whisky (duch)
	_sprite("crate_cod_broken.png", Vector2(173 * T, -26), null, "BrokenCrate", -1)
	_trigger("RyeBark", Vector2(174 * T, -40), Vector2(2 * T, 80))
	_crate("crate_frozen.png", 181 * T, 0)
	_crate("crate_frozen.png", 181 * T, -20)
	_crate("crate_fish.png", 205 * T, 0)
	_lamp(Vector2(193 * T, -150), Rect2(185 * T, -100, 16 * T, 100), -288)
	_gunman("VestGunman", Vector2(192 * T, 0), 1.0, {"vest": true, "patrol_span": 130.0, "walk_speed": 28.0, "max_health": 4,
			"flashlight": true})
	# lávka hore (y = −128) k dverám kancelárie, podpery do zeme
	_oneway(Vector2(200 * T, OFFICE_Y), 36 * T, "Catwalk")
	_strip("catwalk.png", Vector2(200 * T, OFFICE_Y), Vector2(36 * T, 6), 1, "CatwalkFloor")
	_strip("catwalk_rail.png", Vector2(200 * T, OFFICE_Y - 18), Vector2(36 * T, 18), -1, "CatwalkRail")
	for px in [201, 214, 226]:
		var post := Line2D.new()
		post.points = PackedVector2Array([Vector2(px * T, OFFICE_Y + 6), Vector2(px * T, 0)])
		post.width = 3.0
		post.default_color = Color8(54, 62, 68)
		_node(post, "CatwalkPost", _props_root)
	# pravý regál pod lávkou – druhá cesta hore (po zemi okolo lupary)
	_rack("RackR", 229, 236, [-44, -88])
	_lamp(Vector2(221 * T, OFFICE_Y + 10), Rect2(213 * T, -100, 14 * T, 100), OFFICE_Y + 6)
	_enemy("gangster_coppola", "Lupara1", Vector2(223 * T, 0), -1.0, {"stationary": true, "look_back": Vector2(6.0, 10.0)})
	_lamp(Vector2(214 * T, -232), Rect2(207 * T, -214, 14 * T, 86), -288)
	_gunman("Gunman7", Vector2(222 * T, OFFICE_Y), 1.0, {"patrol_span": 80.0, "walk_speed": 26.0})
	_trigger("Checkpoint10", Vector2(234 * T, OFFICE_Y - 40), Vector2(16, 80))
	_marker("Spawn10", Vector2(233 * T, OFFICE_Y))
	_sprite("sign_office.png", Vector2(231 * T, -240), null, "SignOffice", -4)


# ---------------------------------------------------------------- 5. kancelária Lou – účtovná kniha

func _build_office() -> void:
	var y: float = OFFICE_Y
	_sprite("office_window.png", Vector2(246 * T, y - 84), null, "OfficeWindow", -4)
	_sprite("calendar.png", Vector2(243 * T, y - 74), null, "Calendar", -4)
	_sprite("photo_ship.png", Vector2(240 * T, y - 70), null, "ShipPhoto", -4)
	_sprite("coat_rack.png", Vector2(237.3 * T, y - 60), null, "CoatRack", -3)
	_sprite("safe.png", Vector2(249.5 * T, y - 30), null, "Safe", -2)
	_sprite("filing_cabinet.png", Vector2(248 * T - 4, y - 38), null, "Cabinet", -3)
	_sprite("desk.png", Vector2(241 * T, y - 30), null, "LouDesk", -2)
	_sprite("banker_lamp.png", Vector2(244 * T, y - 42), null, "BankerLamp", -1)
	_glow(Vector2(244 * T + 6, y - 36), Color(0.6, 1.0, 0.7, 0.35), 0.8)
	_marker("LedgerSpot", Vector2(242 * T + 8, y - 30))
	_lamp(Vector2(244 * T, y - 96), Rect2(R5[0] * T, y - 112, (R5[1] - R5[0]) * T, 112), R5[2] * T, true)
	_enemy("gangster_bruiser", "OfficeGuard", Vector2(239.5 * T, y), -1.0, {"kind": "bouncer", "vest": true, "stationary": true,
			"look_back": Vector2(6.0, 9.0), "max_health": 5, "run_speed": 95.0, "cold_breath": false})


# ---------------------------------------------------------------- 6. tunel k lodi – schody, pás, vráta

func _build_tunnel() -> void:
	# kovové schody z kancelárie dolu (neviditeľná 45° rampa + obrázok)
	var b := StaticBody2D.new()
	_node(b, "StairRamp", lvl)
	var cp := CollisionPolygon2D.new()
	cp.polygon = PackedVector2Array([Vector2(252 * T, OFFICE_Y), Vector2(260 * T, 0), Vector2(252 * T, 0)])
	_node(cp, "Shape", b)
	_sprite("stairs_metal.png", Vector2(252 * T, OFFICE_Y), lvl, "Stairs", -1)
	_lamp(Vector2(265 * T, -150), Rect2(259 * T, -100, 12 * T, 100), R6[2] * T)
	_docker("Docker4", 265, 60.0)
	# pás – telo v diere podlahy, vrch na y = 0; debny na páse idú do podpalubia
	var belt := StaticBody2D.new()
	belt.set_script(load("res://world/coldstore/conveyor.gd"))
	var blen: float = (BELT[1] - BELT[0]) * T
	belt.set("speed", 45.0)
	belt.set("length", blen)
	_node(belt, "Conveyor", lvl)
	belt.position = Vector2(BELT[0] * T, 0)
	var bcs := CollisionShape2D.new()
	var brs := RectangleShape2D.new()
	brs.size = Vector2(blen, 16)
	bcs.shape = brs
	bcs.position = Vector2(blen / 2.0, 8)
	_node(bcs, "Shape", belt)
	var bs := Sprite2D.new()
	bs.texture = load(ART + "conveyor.png")
	bs.centered = false
	bs.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bs.region_enabled = true
	bs.region_rect = Rect2(0, 0, blen, 12)
	bs.position = Vector2(0, 0)
	_node(bs, "Belt", belt)
	for k in 4:
		var c := AnimatableBody2D.new()
		c.position = Vector2(40 + k * 124, -20)
		_node(c, "BeltCrate", belt)
		var ccs := CollisionShape2D.new()
		var crs := RectangleShape2D.new()
		crs.size = Vector2(30, 20)
		ccs.shape = crs
		ccs.position = Vector2(15, 10)
		_node(ccs, "Shape", c)
		var cs := Sprite2D.new()
		cs.texture = load(ART + ("crate_whisky.png" if k % 2 == 0 else "crate_fish.png"))
		cs.centered = false
		cs.z_index = -1
		_node(cs, "Sprite", c)
	# otvor do podpalubia (debny v ňom zmiznú), rampa s vrátami k lodi
	_sprite("hold_hatch.png", Vector2(BELT[1] * T - 4, -52), lvl, "HoldHatch", 2)
	_lamp(Vector2(303 * T, -150), Rect2(298 * T, -140, 10 * T, 140 + DOCK_Y), R6[2] * T)
	_gunman("Gunman8", Vector2(304 * T, DOCK_Y), -1.0, {"stationary": true, "look_back": Vector2(4.0, 7.0)})
	_sprite("gangway.png", Vector2(305 * T, DOCK_Y - 128), null, "Gangway", -4)
	_glow(Vector2(308.5 * T, DOCK_Y - 60), Color(0.5, 0.6, 0.8, 0.2), 2.2)
	_trigger("ExitDoor", Vector2(310 * T, DOCK_Y - 40), Vector2(2 * T, 80))


# ---------------------------------------------------------------- námraza vo vzduchu (mraziarne)

func _frost() -> void:
	for r in [R2, R4]:
		var p := CPUParticles2D.new()
		p.texture = load(ART + "puff.png")
		var w: float = (r[1] - r[0]) * T
		p.amount = int(w / 14.0)
		p.lifetime = 8.0
		p.preprocess = 8.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(w / 2.0, 4)
		p.direction = Vector2(0.3, 1)
		p.spread = 20.0
		p.gravity = Vector2(0, 6)
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 12.0
		p.scale_amount_min = 0.15
		p.scale_amount_max = 0.35
		p.color = Color(0.9, 0.96, 1.0, 0.55)
		p.position = Vector2(r[0] * T + w / 2.0, r[2] * T + 8)
		p.z_index = 3
		_node(p, "Frost", lvl)
		# mrazivá para pri zemi
		var f := CPUParticles2D.new()
		f.texture = load(L1 + "glow.png")
		f.amount = int(w / 40.0)
		f.lifetime = 9.0
		f.preprocess = 9.0
		f.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		f.emission_rect_extents = Vector2(w / 2.0, 6)
		f.direction = Vector2(1, 0)
		f.spread = 15.0
		f.gravity = Vector2.ZERO
		f.initial_velocity_min = 2.0
		f.initial_velocity_max = 6.0
		f.scale_amount_min = 0.8
		f.scale_amount_max = 1.6
		f.color = Color(0.75, 0.88, 0.96, 0.06)
		f.position = Vector2(r[0] * T + w / 2.0, -10)
		f.z_index = 6
		_node(f, "FloorMist", lvl)
