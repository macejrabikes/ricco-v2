extends SceneTree
## Nástroj: vygeneruje levels/level2/margaret.tscn (Kapitola II – finále: paluba S.S. Margaret v búrke, bossfight s Big Lou)
## a levels/level2/tiles_ship.tres.
## Spustenie: godot --headless --path . --script res://tools/build_margaret.gd
## Mapa je v dlaždiciach (16 px), vrch paluby je na y = 0, pod ňou vysoký trup (čiara vody ~104 px pod palubou).
## Zľava doprava (bossfight v2 – široká, voľná paluba, kryt hlavne zo žeriavu):
##   kajuta na korme (dvere z podpalubia – tadiaľ Ricco príde z mraziarne) → záchranný čln na davitoch (plošina) →
##   pár debien MAPLE SYRUP (kryt, world/ship/ship_crate.gd) a sudy ražnej whisky (vybuchnú, world/ship/ship_barrel.gd) →
##   vyvýšený nákladný poklop (plošina) → vysoký nákladný žeriav s dlhým ramenom a sieťou s nákladom (world/ship/crane.gd) →
##   nákladný poklop, z ktorého vylezú Louovi poskoci (HatchSpot) →
##   dlhé krídlo mostíka vysoko nad palubou (Big Lou: Thompson + páka žeriavu) → nadstavba s dvoma poschodiami,
##   mostíkom a komínom → prova s navijakom.
## Pod mapou (y 800+) je kajuta Lou (útek z lode po bossfighte – margaret.gd) a druhá scéna levels/level2/epilogue.tscn
## (záver kapitoly na mori, epilogue.gd) sa generuje tu tiež.
## Obrázky žeriavu, ramena a poklopu kreslí c4/make_crane.py, kajutu, list, čln na spustenie a záver c9/make_escape_art.py,
## vyššiu nadstavbu, dlhé krídlo, pult s pákou, vyšší žeriav a dlhé rameno c11/make_ship_tall.py, ostatné c2/make_ship_art.py.
## Búrka (blesky, hrom) je world/ship/storm.gd, hojdanie mora world/ship/roll.gd, udalosti levels/level2/margaret.gd.
## Godot docs: classes/class_tilemaplayer, class_parallax2d, class_packedscene, class_line2d.

const T := 16
const ART := "res://levels/level2/art/ship/"
const DOCKS_ART := "res://levels/level2/art/docks/"
const L1 := "res://levels/level1/art/"

# súradnice v atlase tiles_ship.png
const DECK := Vector2i(0, 0)
const HULL := Vector2i(1, 0)
const HULL_PORT := Vector2i(2, 0)
const HULL_RED := Vector2i(3, 0)
const HULL_DK := Vector2i(4, 0)

const END_X := 130             ## pravý koniec paluby (dlaždice) = 2080 px
const HULL_ROWS := 9           ## riadky trupu pod palubou (čiara vody na ~104 px, pod ňou vlny)
const BRIDGE_X := 94           ## nadstavba s mostíkom od dlaždice 94 = 1504 px
const HOUSE_W := 432.0         ## px – šírka nadstavby (27 dlaždíc, bridge_tall.png)
const HOUSE_TOP := -176        ## px – strecha stredného poschodia nadstavby = podlaha krídla mostíka a kormidlovne
const WHEEL := Rect2(1528, -248, 312, 72)  ## kormidlovňa na streche nadstavby (pevná)
const WING_W := 112.0          ## px – krídlo mostíka trčí doľava od nadstavby (wing_long.png)
const CRANE_CX := 1000.0       ## px – stred stĺpa žeriavu (crane_tall.png 112×340)
const CRANE_PIVOT := Vector2(1000, -326)   ## čap ramena nad kabínou
const BOOM_LEN := 404.0        ## px od čapu po kladku (boom_long.png 420×20, čap na x 412)
const BOOM_ANGLE := 0.02       ## rad – rameno mieri doľava, takmer vodorovne (kladka na y ≈ −334 – v boji ešte na obrazovke)
const NET_Y := -212.0          ## px – očko siete (v pokoji)
const PLATFORM := Rect2(470, -26, 140, 26)  ## vyvýšený nákladný poklop (hatch_big.png)
const HATCH_X := 1270.0                     ## nákladný poklop, z ktorého lezú poskoci (1. fáza)
const CABIN := Vector2(0, 800)              ## kajuta Lou (cabin.png 640×360): podlaha CABIN.y + 300, strop + 168, steny x 96 a 544
const CABIN_DOOR := Vector2(1615, 0)        ## dvere do kajuty v spodnej nadstavbe (ľavé dvere na bridge_tall.png)
const EPI_ART := "res://levels/level2/art/epilogue/"

var rng := RandomNumberGenerator.new()
var lvl: Node2D
var solid: TileMapLayer
var _props: Node2D


func _init() -> void:
	rng.seed = 1933
	var ts := _make_tileset()
	ResourceSaver.save(ts, "res://levels/level2/tiles_ship.tres")
	ts = load("res://levels/level2/tiles_ship.tres")

	lvl = Node2D.new()
	lvl.name = "Margaret"
	lvl.set_script(load("res://levels/level2/margaret.gd"))

	_sky()
	_props = _node(Node2D.new(), "Props", lvl)
	_props.z_index = -3
	solid = _layer("Solid", ts, 0)

	_build_deck()
	_build_stern()
	_build_cargo()
	_build_crane()
	_build_bridge()
	_build_storm()
	_build_lou()
	_build_cabin()

	_build_food()
	var ricco: Node2D = load("res://characters/ricco/ricco.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(ricco, "Ricco", lvl)
	ricco.position = Vector2(72, 0)
	var hud: Node = load("res://ui/hud.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(hud, "HUD", lvl)

	var scene := PackedScene.new()
	print("pack margaret: ", scene.pack(lvl))
	print("save margaret: ", ResourceSaver.save(scene, "res://levels/level2/margaret.tscn"))
	lvl.free()
	_build_epilogue()
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
	src.texture = load(ART + "tiles_ship.png")
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


func _sprite(tex: String, pos: Vector2, parent: Node = null, nm: String = "") -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(tex if tex.begins_with("res://") else ART + tex)
	s.centered = false
	s.position = pos
	_node(s, nm if nm != "" else tex.get_file().get_basename().to_pascal_case(), parent if parent else _props)
	return s


## Pruh opakovaného obrázka (zábradlie) – region cez celú šírku
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


func _block(nm: String, r: Rect2, parent: Node = null) -> StaticBody2D:
	var b := StaticBody2D.new()
	_node(b, nm, parent if parent else lvl)
	b.position = r.get_center()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	_node(cs, "Shape", b)
	return b


## Jednosmerná plošina (krídlo mostíka, záchranný čln) – zospodu sa na ňu dá vyskočiť
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


## Debna na palube = kryt (pevná, zastaví aj guľky). Telo s obrázkom je jeden uzol „CoverN“ –
## v boji ju Lou Thompsonom postupne rozstrieľa (world/ship/ship_crate.gd).
var _cover_n: int = 0
func _cover(tex: String, x: float, y_bottom: float) -> void:
	_cover_n += 1
	var b := _block("Cover%d" % _cover_n, Rect2(x, y_bottom - 20, 30, 20))
	b.set_script(load("res://world/ship/ship_crate.gd"))   # guľky ju postupne rozbijú
	b.add_to_group(&"ship_cover", true)
	var s := Sprite2D.new()
	s.texture = load(DOCKS_ART + tex)
	s.centered = false
	s.position = Vector2(-15, -10)
	s.z_index = -1
	_node(s, "Sprite", b)


func _parallax(nm: String, scroll: float, z: int, autoscroll: Vector2 = Vector2.ZERO) -> Parallax2D:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scroll, 1.0)
	p.repeat_size = Vector2(640, 0)
	p.repeat_times = 4
	p.autoscroll = autoscroll
	p.z_index = z
	_node(p, nm, lvl)
	return p


# ---------------------------------------------------------------- obloha, mraky, rozbúrené more

func _sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -20
	_node(layer, "Sky", lvl)
	var tr := TextureRect.new()
	tr.texture = load(ART + "sky_storm.png")
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	_node(tr, "Gradient", layer)
	# mraky letia (autoscroll) a hojdajú sa s loďou
	var cl := _parallax("Clouds", 0.08, -31, Vector2(-14, 0))
	var roll_c := Node2D.new()
	roll_c.set_script(load("res://world/ship/roll.gd"))
	roll_c.set("amplitude", 4.0)
	roll_c.set("tilt_deg", 0.6)
	roll_c.add_to_group(&"ship_roll", true)   # pri úteku sa loď nakláňa (margaret.gd → lean_deg)
	_node(roll_c, "Roll", cl)
	var cs := Sprite2D.new()
	cs.texture = load(ART + "clouds_storm.png")
	cs.centered = false
	cs.position = Vector2(-640, -330)
	_node(cs, "Sprite", roll_c)
	# vzdialené more s vlnami – hrebene okolo y = −40, hojdá sa (zdá sa, že sa kolíše loď)
	var sea := _parallax("Sea", 0.3, -29)
	var roll := Node2D.new()
	roll.set_script(load("res://world/ship/roll.gd"))
	_node(roll, "Roll", sea)
	roll.add_to_group(&"ship_roll", true)
	var ss := Sprite2D.new()
	ss.texture = load(ART + "sea_storm.png")
	ss.centered = false
	ss.position = Vector2(-640, -62)
	_node(ss, "Sprite", roll)


# ---------------------------------------------------------------- paluba a trup

func _build_deck() -> void:
	# vysoký trup: dva rady okienok, červený pás pri čiare vody, pod ním tmavé dno (zakryjú ho vlny)
	for x in range(-2, END_X + 2):
		solid.set_cell(Vector2i(x, 0), 0, DECK)
		for y in range(1, HULL_ROWS + 1):
			var t := HULL
			if (y == 2 or y == 4) and x % 3 == 1:
				t = HULL_PORT
			elif y == 6:
				t = HULL_RED
			elif y > 6:
				t = HULL_DK
			solid.set_cell(Vector2i(x, y), 0, t)
	# okraje paluby – ďalej sa nedá (korma / prova)
	_block("WallL", Rect2(-16, -400, 16, 400))
	_block("WallR", Rect2(END_X * T, -400, 16, 400))
	# zábradlie vzadu na boku lode – za nadstavbami aj nákladom (Props má z −3)
	_strip("railing.png", Vector2(0, -18), Vector2(END_X * T, 18), -8, "Railing")
	# vlny pred trupom – popredie, letia a hojdajú sa
	var front := _parallax("WavesFront", 1.0, 12, Vector2(-26, 0))
	var roll := Node2D.new()
	roll.set_script(load("res://world/ship/roll.gd"))
	roll.set("amplitude", 4.0)
	roll.set("tilt_deg", 0.0)
	roll.set("period", 3.2)
	_node(roll, "Roll", front)
	var w := Sprite2D.new()
	w.texture = load(ART + "waves_front.png")
	w.centered = false
	w.position = Vector2(-640, 92)   # hrebene vĺn pri čiare vody (červený pás trupu)
	_node(w, "Sprite", roll)


# ---------------------------------------------------------------- korma: kajuta, záchranný čln

func _build_stern() -> void:
	var house := _sprite("stern_house.png", Vector2(0, -96), null, "SternHouse")
	house.z_index = -4
	_glow(Vector2(73, -84), Color(1.0, 0.8, 0.45, 0.6), 1.1, null, true)   # lampa nad dverami
	_glow(Vector2(23, -59), Color(1.0, 0.8, 0.45, 0.35), 0.6)
	_marker("Spawn11", Vector2(73, 0))
	# záchranný čln na davitoch – lem 48 px nad palubou (z debny naň vyskočíš, odtiaľ lepší uhol na mostík).
	# Davity a čln sú zvlášť a laná sú čiary – na konci kapitoly sa čln s Riccom spustí na more (margaret.gd → _lower_boat).
	var lb := Node2D.new()
	_node(lb, "Lifeboat", lvl)
	lb.position = Vector2(128, -108)
	lb.z_index = -2
	_sprite("lifeboat_davits.png", Vector2.ZERO, lb, "Davits")
	_sprite("lifeboat_boat.png", Vector2(0, 56), lb, "Boat")
	for spec in [["RopeL", 30.0], ["RopeR", 82.0]]:
		var rope := Line2D.new()
		rope.width = 1.0
		rope.default_color = Color8(80, 76, 66)
		rope.points = PackedVector2Array([Vector2(spec[1], 14), Vector2(spec[1], 58)])
		_node(rope, spec[0], lb)
	_oneway(Vector2(132, -48), 104.0, "LifeboatTop")
	# páka, ktorou sa čln spustí (pri úteku – F)
	var lever := _sprite("davit_lever.png", Vector2(248, -26), null, "DavitLever")
	lever.hframes = 2
	lever.z_index = -1
	_marker("LeverSpot", Vector2(256, 0))


# ---------------------------------------------------------------- náklad: debny (kryt), sudy, poklop

## Paluba je voľná – len pár pevných debien; ďalší kryt zhadzuje Lou žeriavom (world/ship/falling_cargo.gd)
func _build_cargo() -> void:
	_cover("crate_maple.png", 360, 0)
	_platform()
	_cover("crate_whisky.png", 1150, 0)
	_cover("crate.png", 1150, -20)
	var hatch := _sprite("hatch.png", Vector2(HATCH_X - 32, -14), null, "Hatch")
	hatch.z_index = -2
	_marker("HatchSpot", Vector2(HATCH_X, 0))   # odtiaľto vylezú poskoci (margaret.gd → _henchmen)
	# sudy whisky – stačí jedna guľka (Barrel1 stojí presne tam, kam dopadne zrútené rameno žeriavu)
	var land: Vector2 = CRANE_PIVOT + Vector2(-sqrt(BOOM_LEN * BOOM_LEN - CRANE_PIVOT.y * CRANE_PIVOT.y), -CRANE_PIVOT.y)
	_barrel("Barrel1", roundf(land.x))
	_barrel("Barrel2", 1330)
	_barrel("Barrel3", 300)


## Vyvýšený nákladný poklop: navrch sa dá vyskočiť (jednosmerná plošina), bočné hrany zastavia guľky (vrstva 32 = kryt)
## a Ricco sa za ne schová ako za debnu. Popred poklop sa dá prejsť (je vzadu na palube) – aj Lou v 3. fáze.
func _platform() -> void:
	var s := _sprite("hatch_big.png", PLATFORM.position - Vector2(0, 2), null, "CargoHatch")
	s.z_index = -2
	_oneway(PLATFORM.position, PLATFORM.size.x, "CargoHatchTop")
	for spec in [["CargoHatchEdgeL", PLATFORM.position.x], ["CargoHatchEdgeR", PLATFORM.end.x - 6]]:
		var w := _block(spec[0], Rect2(spec[1], PLATFORM.position.y, 6, PLATFORM.size.y))
		w.collision_layer = 32
		w.collision_mask = 0


## Sud ražnej whisky: telo na vrstve 4 (Riccove guľky ho zasiahnu, Louove a pohyb prejdú), počiatok = stred spodku
func _barrel(nm: String, cx: float) -> void:
	var b := StaticBody2D.new()
	b.set_script(load("res://world/ship/ship_barrel.gd"))
	b.collision_layer = 4
	b.collision_mask = 0
	b.add_to_group(&"ship_barrel", true)
	_node(b, nm, lvl)
	b.position = Vector2(cx, 0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(14, 22)
	cs.shape = rs
	cs.position = Vector2(0, -11)
	_node(cs, "Shape", b)
	var s := Sprite2D.new()
	s.texture = load(ART + "barrel.png")
	s.centered = false
	s.position = Vector2(-9, -24)
	s.z_index = -1
	_node(s, "Sprite", b)


# ---------------------------------------------------------------- nákladný žeriav (Lou ho ovláda pákou z krídla mostíka)

func _build_crane() -> void:
	# vysoký stĺp stojí vzadu na palube
	var c := _sprite("crane_tall.png", Vector2(CRANE_CX - 56, -340), null, "Crane")
	c.z_index = -3
	# spodná doska podstavca je pevná – Ricco ju preskočí, Lou v rozbehu do nej narazí (omámený)
	_block("CraneBase", Rect2(CRANE_CX - 46, -12, 92, 12))
	_glow(Vector2(CRANE_CX - 42, -317), Color(1.0, 0.85, 0.5, 0.35), 0.8)      # lampa nad oknom kabíny
	_glow(Vector2(CRANE_CX - 24, -304), Color(1.0, 0.85, 0.5, 0.25), 1.0)
	# rameno, lano, sieť a tieň pod sieťou ovláda world/ship/crane.gd (otáča ramenom, hojdá sieťou, púšťa náklad)
	var arm := Node2D.new()
	arm.set_script(load("res://world/ship/crane.gd"))
	_node(arm, "CraneArm", lvl)
	arm.set("pivot", CRANE_PIVOT)
	arm.set("length", BOOM_LEN)
	arm.set("luff", BOOM_ANGLE)
	arm.set("rope", NET_Y - (CRANE_PIVOT.y - BOOM_LEN * sin(BOOM_ANGLE)))
	var boom := Sprite2D.new()
	boom.texture = load(ART + "boom_long.png")
	boom.centered = false
	boom.offset = Vector2(-412, -10)     # otáča sa okolo pravého konca (čap nad kabínou)
	boom.position = CRANE_PIVOT
	boom.rotation = BOOM_ANGLE
	boom.z_index = -3
	_node(boom, "Boom", arm)
	var tip: Vector2 = CRANE_PIVOT + Vector2(-BOOM_LEN, 0).rotated(BOOM_ANGLE)
	var rope := Line2D.new()
	rope.width = 1.0
	rope.default_color = Color8(70, 66, 58)
	rope.points = PackedVector2Array([tip, Vector2(tip.x, NET_Y)])
	_node(rope, "Rope", arm)
	var net := _sprite("net.png", Vector2(tip.x, NET_Y), arm, "Net")
	net.offset = Vector2(-28, 0)
	var sh := _sprite("shadow.png", Vector2(tip.x - 20, -4), arm, "Shadow")
	sh.z_index = 1
	sh.visible = false
	_marker("BoomTip", tip)


# ---------------------------------------------------------------- nadstavba s mostíkom, krídlo (Lou), prova

func _build_bridge() -> void:
	var bx: float = BRIDGE_X * T
	var b := _sprite("bridge_tall.png", Vector2(bx, -312), null, "Bridge")
	b.z_index = -4
	# spodné a stredné poschodie sú jeden pevný blok (pred dvermi kajuty sa dá prejsť až po boji – margaret.gd: _open_house)
	_block("House", Rect2(bx, HOUSE_TOP, HOUSE_W, -HOUSE_TOP))
	_block("Wheelhouse", WHEEL)
	# dlhé krídlo mostíka doľava od kormidlovne, vysoko nad palubou – tu stojí Lou (Thompson + páka žeriavu).
	# Tri dynamity hodené späť ho zničia (margaret.gd → _break_wing): krídlo sa odlomí a Lou spadne na palubu.
	var w := _sprite("wing_long.png", Vector2(bx - WING_W, HOUSE_TOP - 15), null, "Wing")
	w.z_index = -1
	_oneway(Vector2(bx - WING_W, HOUSE_TOP), WING_W, "WingFloor")
	_marker("LouSpot", Vector2(bx - 44, HOUSE_TOP))   # tu stojí Big Lou (_build_lou)
	# pult s pákou žeriavu na pravom konci krídla (za Louovým chrbtom)
	var con := _sprite("crane_console.png", Vector2(bx - 22, HOUSE_TOP - 12), null, "CraneConsole")
	con.z_index = -2
	var lever := _sprite("lever.png", Vector2(bx - 15, HOUSE_TOP - 9), lvl, "Lever")
	lever.offset = Vector2(-2, -16)
	lever.z_index = -3
	lever.add_to_group(&"crane_lever", true)
	# svetlá: okná mostíka, okienka, lampa na stožiari
	for k in 10:
		_glow(Vector2(bx + 43 + 30 * k, -226), Color(1.0, 0.8, 0.45, 0.4), 0.7)
	for px in [bx + 86, bx + 198, bx + 303]:
		_glow(Vector2(px, -66), Color(1.0, 0.8, 0.45, 0.35), 0.5)
	for px in [bx + 75, bx + 219, bx + 363]:
		_glow(Vector2(px, -137), Color(1.0, 0.8, 0.45, 0.3), 0.45)
	_glow(Vector2(bx + 370, -307), Color(1.0, 0.95, 0.8, 0.5), 0.8, null, true)
	var wn := _sprite("winch.png", Vector2(END_X * T - 80, -28), null, "Winch")
	wn.z_index = -2
	# dvere do kajuty Lou – po bossfighte sa otvoria (margaret.gd: _open_house), pred nimi sa Ricco objaví po smrti pri úteku
	_marker("Spawn12", CABIN_DOOR)


# ---------------------------------------------------------------- búrka: dážď, blesky, vlny cez palubu

func _build_storm() -> void:
	for i in 2:   # hustý lejak (dve vrstvy dažďa z prvej kapitoly)
		var r := CPUParticles2D.new()
		r.set_script(load("res://world/fx/rain.gd"))
		_node(r, "Rain%d" % (i + 1), lvl)
	var st := Node.new()
	st.set_script(load("res://world/ship/storm.gd"))
	_node(st, "Storm", lvl)
	# vlna cez zábradlie – obrázok so 4 snímkami, spúšťa margaret.gd
	var sp := Sprite2D.new()
	sp.texture = load(ART + "splash.png")
	sp.hframes = 4
	sp.centered = false
	sp.offset = Vector2(-48, -64)
	sp.visible = false
	sp.z_index = 8
	_node(sp, "Splash", lvl)


# ---------------------------------------------------------------- Big Lou (characters/lou/big_lou.tscn)

## Big Lou stojí na krídle mostíka za zábradlím (krídlo má z −1, Lou −5 → zábradlie je pred jeho nohami)
func _build_lou() -> void:
	var lou: Node2D = load("res://characters/lou/big_lou.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(lou, "BigLou", lvl)
	var bx: float = BRIDGE_X * T
	lou.position = Vector2(bx - 44, HOUSE_TOP)
	lou.z_index = -5
	lou.set("walk_span", Vector2(bx - WING_W + 16, bx - 34))
	lou.set("wing_left", bx - WING_W)
	lou.set("deck_span", Vector2(124, bx - 20))


# ---------------------------------------------------------------- jedlo a lekárničky (props/food/food_pickup.tscn)

## [x, y, druh] – druh "" = jedlo podľa poradia (Food.next_kind – vždy iné), "medkit" = lekárnička. Za behu spadne na zem.
## Rozmiestnenie: paluba (ďalšie jedlo vypadne z Lou počas boja)
const FOOD := [[200.0, -12.0, ""], [540.0, -40.0, "medkit"], [880.0, -12.0, ""], [514.0, CABIN.y + 268.0, "medkit"]]

func _build_food() -> void:
	for i in FOOD.size():
		var f: Array = FOOD[i]
		var p: Node2D = load("res://props/food/food_pickup.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		_node(p, ("Medkit%d" if f[2] == "medkit" else "Food%d") % (i + 1), lvl)
		p.position = Vector2(f[0], f[1])
		if f[2] != "":
			p.set(&"kind", StringName(f[2]))


# ---------------------------------------------------------------- kajuta Lou (útek z lode, list od „M.“)

## Kajuta je pod mapou lode (vlastné hranice kamery v margaret.gd – CABIN_MAP). Ricco sem príde dverami spodnej nadstavby,
## na stole leží list (LetterSpot), na posteli lekárnička. Lampa sa pri otrasoch kýve, oheň nad stropom a dym pridá margaret.gd.
func _build_cabin() -> void:
	var room := _sprite("cabin.png", CABIN, lvl, "Cabin")
	room.z_index = -10
	var fy: float = CABIN.y + 300.0
	_block("CabinFloor", Rect2(CABIN.x, fy, 640, 40))
	_block("CabinCeiling", Rect2(CABIN.x + 80, CABIN.y + 152, 480, 16))
	_block("CabinWallL", Rect2(CABIN.x + 84, CABIN.y + 120, 12, 180))
	_block("CabinWallR", Rect2(CABIN.x + 544, CABIN.y + 120, 12, 180))
	_marker("CabinSpawn", Vector2(CABIN.x + 140, fy))
	_marker("LetterSpot", Vector2(CABIN.x + 362, fy - 34))
	var lamp := _sprite("cabin_lamp.png", Vector2(CABIN.x + 280, CABIN.y + 168), lvl, "CabinLamp")
	lamp.offset = Vector2(-7, 0)
	lamp.z_index = -9
	var lamp_glow := _glow(Vector2(0, 28), Color(1.0, 0.8, 0.45, 0.55), 1.4, lamp, true)
	lamp_glow.position = Vector2(0, 28)
	_glow(Vector2(CABIN.x + 402, fy - 44), Color(0.8, 1.0, 0.6, 0.3), 0.6)                  # zelená lampa na stole
	_glow(Vector2(CABIN.x + 50, fy - 20), Color(1.0, 0.45, 0.15, 0.6), 1.8, null, true)       # oheň v chodbe
	for px in [210.0, 436.0]:
		_glow(Vector2(CABIN.x + px, CABIN.y + 204), Color(0.5, 0.6, 0.9, 0.18), 0.4)          # okienka


# ---------------------------------------------------------------- záver kapitoly II (epilogue.tscn)

## Svitanie na mori: obloha, vzdialená horiaca Margaret, more so zlatým chodníkom, čln s Riccom (a duchom) v popredí.
## Bez kamery – súradnice = obrazovka 640×360. Celý priebeh (výbuch, potopenie, hlášky, titulky) je v epilogue.gd.
func _build_epilogue() -> void:
	lvl = Node2D.new()
	lvl.name = "Epilogue"
	lvl.set_script(load("res://levels/level2/epilogue.gd"))
	var sky := _sprite(EPI_ART + "dawn_sky.png", Vector2.ZERO, lvl, "Sky")
	sky.z_index = -10
	var ship := _sprite(EPI_ART + "margaret_far.png", Vector2(176, 186), lvl, "Margaret")
	ship.hframes = 3
	ship.z_index = -5
	var sea := _sprite(EPI_ART + "dawn_sea.png", Vector2(0, 232), lvl, "Sea")
	sea.z_index = -2
	var boat := Node2D.new()
	_node(boat, "Boat", lvl)
	boat.position = Vector2(96, 300)
	var ricco := AnimatedSprite2D.new()
	ricco.sprite_frames = load("res://characters/ricco/ricco_frames.tres")
	ricco.animation = &"idle"
	ricco.position = Vector2(46, -14)   # stred snímky je 21 px nad nohami (ako v ricco.tscn) – nohy sú v člne
	_node(ricco, "Ricco", boat)
	var ghost := _sprite("res://characters/don/ghost_don.png", Vector2(66, -84), boat, "Ghost")
	ghost.modulate.a = 0.0
	var hull := _sprite("res://levels/level2/art/ship/lifeboat_boat.png", Vector2(0, -6), boat, "Hull")
	hull.z_index = 1
	var waves := Sprite2D.new()
	waves.texture = load(EPI_ART + "dawn_waves.png")
	waves.centered = false
	waves.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	waves.region_enabled = true
	waves.region_rect = Rect2(0, 0, 640, 24)
	waves.position = Vector2(0, 306)
	waves.z_index = 3
	_node(waves, "Waves", lvl)
	var scene := PackedScene.new()
	print("pack epilogue: ", scene.pack(lvl))
	print("save epilogue: ", ResourceSaver.save(scene, "res://levels/level2/epilogue.tscn"))
	lvl.free()
