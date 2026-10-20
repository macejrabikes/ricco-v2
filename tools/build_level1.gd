extends SceneTree
## Nástroj: vygeneruje levels/level1/level1.tscn (ulica, zadný dvor, interiér pizzerie) a levels/level1/tiles_exterior.tres.
## Spustenie: godot --headless --path . --script res://tools/build_level1.gd
## Mapa je zadaná obdĺžnikmi v dlaždiciach (16 px). Zem je na y = 0, hore sú záporné riadky.
## Godot docs: classes/class_tilemaplayer, class_tileset, class_tilesetatlassource, class_parallax2d, class_packedscene.

const T := 16
const ART := "res://levels/level1/art/"

# súradnice v atlase tiles_exterior.png
const SIDEWALK := Vector2i(0, 0)
const FILL := Vector2i(1, 0)
const BRICKS := [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
const CAP := Vector2i(5, 0)
const FENCE := Vector2i(6, 0)
const FENCE_TOP := Vector2i(7, 0)
const CRATES := [Vector2i(0, 1), Vector2i(1, 1)]
const GRATE := Vector2i(2, 1)
const RAIL := Vector2i(3, 1)
const AWN := [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
const SILL := Vector2i(7, 1)
const BG_BRICKS := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]
const BG_PLASTER := Vector2i(3, 2)
const PIPE := Vector2i(4, 2)

# súradnice v atlase tiles_interior.png (zdroj 1)
const I_WOOD := Vector2i(0, 0)
const I_UNDER := Vector2i(1, 0)
const I_CHECKER := Vector2i(2, 0)
const I_DARK := Vector2i(3, 0)
const I_BEAM := Vector2i(4, 0)
const I_COUNTER := Vector2i(5, 0)
const I_SHELF := Vector2i(6, 0)
const I_WALL := Vector2i(7, 0)
const I_PAPER := [Vector2i(0, 1), Vector2i(1, 1)]
const I_WAINSCOT_TOP := Vector2i(2, 1)
const I_WAINSCOT := Vector2i(3, 1)
const I_KTILE := Vector2i(4, 1)
const I_KWALL := Vector2i(5, 1)
const I_PLANKS := [Vector2i(6, 1), Vector2i(7, 1)]
const I_PAPER_TOP := Vector2i(0, 2)
const I_KBAND := Vector2i(1, 2)
const I_PASSAGE := Vector2i(2, 2)
const I_RAIL := Vector2i(3, 2)
const I_BALCONY := Vector2i(4, 2)
const I_PILLAR := Vector2i(5, 2)
const I_STONE_BG := Vector2i(6, 2)
const I_STONE := Vector2i(7, 2)
const I_NOSE := [Vector2i(0, 3), Vector2i(1, 3)]        ## jemné schodíky po rampe (bez kolízie): klesajú doprava / doľava
const I_STAIR_TOP := [Vector2i(2, 3), Vector2i(3, 3)]   ## vrchný blok schodu pod schodíkmi
const I_STAIR_FILL := Vector2i(4, 3)                    ## kameň pod schodmi
const I_DUCT := Vector2i(5, 3)        ## vetracie potrubie – plech (pevný)
const I_DUCT_IN := Vector2i(6, 3)     ## vnútro potrubia (pozadie)
const I_DUCT_END := Vector2i(7, 3)    ## otvorený koniec potrubia (pozadie; alternatíva 1 = zrkadlovo)

# súradnice v atlase tiles_tunnel.png (zdroj 2) – pivnica
const TN_BRICK := [Vector2i(0, 0), Vector2i(1, 0)]
const TN_FLOOR := Vector2i(2, 0)
const TN_CEIL := Vector2i(3, 0)
const TN_EARTH := Vector2i(4, 0)
const TN_PLANK := Vector2i(5, 0)
const TN_RUBBLE := Vector2i(6, 0)
const TN_BARS := Vector2i(7, 0)
const TN_BG := [Vector2i(0, 1), Vector2i(1, 1)]
const TN_BG_PIPE := Vector2i(2, 1)
const TN_BG_RIB := Vector2i(3, 1)
const TN_WATER := Vector2i(4, 1)
const TN_BG_WET := Vector2i(6, 1)
const TN_BG_POST := Vector2i(7, 1)
const TN_STEP := Vector2i(0, 2)
const TN_GRATE := Vector2i(1, 2)
const TN_CRATE := Vector2i(2, 2)
const TN_VOID := Vector2i(3, 2)
const TN_NOSE := [Vector2i(0, 3), Vector2i(1, 3)]       ## jemné schodíky po rampe (bez kolízie): klesajú doprava / doľava
const TN_STAIR_TOP := [Vector2i(2, 3), Vector2i(3, 3)]  ## vrchný blok schodu pod schodíkmi
const TN_STAIR_FILL := Vector2i(4, 3)                   ## kameň pod schodmi
const TN_STAIR_FLAT := Vector2i(5, 3)                   ## najvyšší schod (rovný vrch)
const TN_DEEP := Vector2i(5, 1)       ## hlboká voda (plávanie)
const TN_OSSUARY := [Vector2i(4, 2), Vector2i(5, 2)]   ## kostnica: výklenok s lebkou, stena z kostí
const TN_SURFACE := Vector2i(6, 2)    ## hladina nad hlbokou vodou
const CATACOMB := Rect2i(17, 19, 113, 13)   ## zatopené katakomby (pozadie z kostnice)

## Pivnica P2 – pašerácke tunely (samostatná scéna levels/level1/cellar.tscn). 1 znak = 1 dlaždica:
## # stena  . tunel  ^ schod  R zával  | mreže  x debna  ~ voda (hladina)  % hlboká voda (pláva sa)  = rošt  - doska  c sviečka
## S štart  D Don  E dvere von  K kam pribehnú gangstri  G hliadka s baterkou  g stráž (chrbtom doprava)
## b žiarovka (svetlo)  o kvapka krvi (správna cesta)  r potkan  L pálenica  X krieda „slepá ulička“
const MAZE := """...#############################################################################################################################################################################################
...#############################################################################################################################################################################################
..................b.................b...................b...............RRR#####################################################################################################################
^.....................................................................X.RRR#####################################################################################################################
^^......................................................................RRR#####################################################################################################################
^^^.....................................................................RRR#####################################################################################################################
^^^^....................................................................RRR#####################################################################################################################
^^^^^.S...o.........o.........o.G.......o..o..................r.........RRR#####################################################################################################################
############################################...#################################################################################################################################################
############################################...##########################W######################################################################################################################
############################################...#################################################################################################################################################
###............b.............###......b........................|........RRR#####################################################################.....................b....##........##...b....##
###..........................###...............................|........RRR#####################################################################..........................##........##........##
###..........................###...............................|........RRR#####################################################################..............................................##
###..........................###...............................|........RRR#####################################################################..............................................##
###............................................................|........RRR#####################################################################..............................................##
###.......o.......o...r...o.......o...o...o.........g..........|......o.RRR#####################################################################.....Ko.......................................##
#####....#######################################################################################################################################....####^.....................................##
#####....#######################################################################################################################################....####^^....................................##
#####....######################################################...........##..................##################################################....####^^^...................................##
##..b........................######........######.........................##..................############..........................b..........#....####^^^^..................................##
##...........................######........######.........................##..................############.....................................#....####^^^^^.........................------..##
##...........................######........######.........................##..................############.....................................#....####^^^^^^......------....................##
##...........x...............######........######.........................##..................############..........................................####^^^^^^^...............................##
##..........xx...............######...c....######.........................##........G.........############.....x......---...---...xx................####^^^^^^^^........................x.....##
##.L........xx...c...........######...##...######.........rc.o............##..==============..############...oxx.cg..............cxx....o.G.r.......####^^^^^^^^^.o....r........D......xx....E##
##################~~~~~~~~~~~######~~~##~~~######~~~~~~~~######~~~~~~~~~~~##~~~~~~~~~~~~~~~~~~##%%%%%%%%%%~~~#######~~~~~~~~~~~~~###############################################################
##################%%%%%%%%%%%######%%%##%%%######%%%%%%%%######%%%%%%%%%%%##%%%%%%%%%%%%%%%%%%##%%%%%%%%%%%%%#######%%%%%%%%%%%%%###############################################################
##################%%%%%%%%%%%%%%%%%%%%##%%%######%%%%%%%%######%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#######%%%%%%%%%%%%%###############################################################
##################%%%%%%%%%%%%%%%%%%%%##%%%%%%%%%%%%%%%%%######%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#######%%%%%%%%%%%%%###############################################################
##################%%%%%%%%%%%%%%%%%%%%##%%%%%%%%%%%%%%%%%######%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#######%%%%%%%%%%%%%###############################################################
################################################################################################################################################################################################"""

## Interiér leží napravo od exteriéru (kamera ho odtiaľ nevidí); Ricco sa doň dostane oknom (prechod v level1.gd).
## Vnútri je to jeden súvislý priestor (žiadne ďalšie prechody).
const SX0 := -80         ## začiatok ulice (ľavá stena je o 2 dlaždice ďalej)
const PZ := 64           ## pizzeria Don Vito na ulici (ľavý okraj markízy)
const DINE_GALLERY := -10   ## riadok galérie pri okne (reštaurácia)
const DINE_BEAM := -12      ## riadok trámov nad hosťami
const IX0 := 142         ## ľavá stena interiéru (jedáleň je široká, nech sa hostia aj nápisy zmestia)
const IX1 := 399         ## pravý koniec (stena pivnice)
const TOP := -18         ## riadok stropu (jedáleň … herňa)
const CX0 := 282         ## začiatok herne (za priečkou skladu)
const BALCONY_Y := -8    ## riadok podlahy balkóna / lávky v sklade
const BALCONY_X1 := 328  ## koniec balkóna – odtiaľ sa zoskočí do tmy pri schodoch
const STAIRS_X := 342    ## prvý schod dole do pivnice
const CELLAR_FLOOR := 6  ## riadok dlážky pivnice (o 6 dlaždíc nižšie)
const CELLAR_TOP := -10  ## riadok stropu pivnice
const KX0 := 350         ## pravá stena herne = začiatok pivnice pod ňou
const KX1 := IX1
const DON_X := 368
const VENT_Y := -14       ## horný riadok vnútra vetracieho potrubia (vnútro 2 dlaždice = 32 px → len plazenie)
const VENT_X0 := 198      ## vstup v jedálni na konci trámu B
const VENT_X1 := 213      ## koniec v kuchyni – vypadne sa na policu nad kuchárom

var rng := RandomNumberGenerator.new()
var lvl: Node2D
var back: TileMapLayer
var solid: TileMapLayer
var plats: TileMapLayer
var _wanted_yard: int = 0
var _src := 0         ## zdroj dlaždíc pre _fill (0 = exteriér, 1 = interiér)


func _init() -> void:
	rng.seed = 1931
	var ts := _make_tileset()
	ResourceSaver.save(ts, "res://levels/level1/tiles_exterior.tres")
	ts = load("res://levels/level1/tiles_exterior.tres")

	lvl = Node2D.new()
	lvl.name = "Level1"
	lvl.set_script(load("res://levels/level1/level1.gd"))

	_sky()
	back = _layer("Back", ts, -10)
	_props_root = _node(Node2D.new(), "Props", lvl)
	_props_root.z_index = -5
	solid = _layer("Solid", ts, 0)
	plats = _layer("Platforms", ts, 0)
	plats.add_to_group(&"platform", true)

	_build_street()
	_build_yard()
	_build_interior()
	_hints()

	var rain := CPUParticles2D.new()
	rain.set_script(load("res://world/fx/rain.gd"))
	_node(rain, "Rain", lvl)

	_trigger("WindowEnter", Vector2(131 * T, -16 * T - 24), Vector2(40, 48))   # okno na dvore → interiér
	_trigger("Checkpoint2", Vector2(282.5 * T, -2 * T), Vector2(24, 4 * T))     # za dverami herne
	_trigger("KnockTrigger", Vector2(273.5 * T, -5 * T), Vector2(12 * T, 10 * T))   # zadná časť skladu – mafián ide zaklopať
	_trigger("CellarDescent", Vector2((STAIRS_X + 0.5) * T, -1.5 * T), Vector2(16, 3 * T))   # hore na schodoch do pivnice
	for sp in [["InteriorSpawn", Vector2((IX0 + 5) * T, DINE_GALLERY * T)], ["CasinoSpawn", Vector2((CX0 + 1.5) * T, -6 * T)]]:
		var m := Marker2D.new()
		_node(m, sp[0], lvl)
		m.position = sp[1]

	_build_food()
	var ricco: Node2D = load("res://characters/ricco/ricco.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(ricco, "Ricco", lvl)
	ricco.position = Vector2((SX0 + 6) * T, 0)
	var hud: Node = load("res://ui/hud.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(hud, "HUD", lvl)

	var scene := PackedScene.new()
	var err := scene.pack(lvl)
	print("pack: ", err)
	print("save: ", ResourceSaver.save(scene, "res://levels/level1/level1.tscn"))
	lvl.free()
	_build_cellar_scene(ts)
	quit()


# ---------------------------------------------------------------- pomocné

var _props_root: Node2D

func _node(n: Node, nm: String, parent: Node) -> Node:
	n.name = nm
	parent.add_child(n)
	_own(n)
	return n


## owner = lvl, aby sa uzol uložil do scény (inštancie scén len samé, nie ich deti)
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


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load(ART + "tiles_exterior.png")
	src.texture_region_size = Vector2i(T, T)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for y in 3:
		for x in 8:
			var c := Vector2i(x, y)
			src.create_tile(c)
	ts.add_source(src, 0)
	for c in [SIDEWALK, FILL, CAP, FENCE, FENCE_TOP] + BRICKS + CRATES:
		_poly(src, c, full, false)
	_poly(src, GRATE, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -4), Vector2(-8, -4)]), true)
	for c in AWN:
		_poly(src, c, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 0), Vector2(-8, 0)]), true)
	_poly(src, SILL, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -5), Vector2(-8, -5)]), true)
	# interiér
	var isrc := TileSetAtlasSource.new()
	isrc.texture = load(ART + "tiles_interior.png")
	isrc.texture_region_size = Vector2i(T, T)
	for y in 4:
		for x in 8:
			isrc.create_tile(Vector2i(x, y))
	ts.add_source(isrc, 1)
	for c in [I_WOOD, I_UNDER, I_CHECKER, I_DARK, I_BEAM, I_WALL, I_BALCONY, I_STONE, I_STAIR_FILL, I_DUCT] + I_STAIR_TOP:
		_poly(isrc, c, full, false)
	isrc.get_tile_data(I_DUCT_END, isrc.create_alternative_tile(I_DUCT_END)).flip_h = true
	_poly(isrc, I_COUNTER, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -4), Vector2(-8, -4)]), true)
	_poly(isrc, I_SHELF, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -5), Vector2(-8, -5)]), true)
	# pivnica – pašerácke tunely
	var tsrc := TileSetAtlasSource.new()
	tsrc.texture = load(ART + "tiles_tunnel.png")
	tsrc.texture_region_size = Vector2i(T, T)
	for y in 4:
		for x in 8:
			tsrc.create_tile(Vector2i(x, y))
	ts.add_source(tsrc, 2)
	for c in [TN_BRICK[0], TN_BRICK[1], TN_FLOOR, TN_CEIL, TN_EARTH, TN_RUBBLE, TN_BARS, TN_STEP, TN_CRATE, TN_STAIR_FILL, TN_STAIR_FLAT] + TN_STAIR_TOP:
		_poly(tsrc, c, full, false)
	_poly(tsrc, TN_PLANK, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -3), Vector2(-8, -3)]), true)
	_poly(tsrc, TN_GRATE, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -4), Vector2(-8, -4)]), true)
	return ts


func _poly(src: TileSetAtlasSource, c: Vector2i, pts: PackedVector2Array, one_way: bool) -> void:
	var td := src.get_tile_data(c, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, pts)
	td.set_collision_polygon_one_way(0, 0, one_way)


func _fill(layer: TileMapLayer, x0: int, y0: int, x1: int, y1: int, tiles) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var t: Vector2i = tiles if tiles is Vector2i else tiles[rng.randi() % tiles.size()]
			layer.set_cell(Vector2i(x, y), _src, t)


func _sprite(tex: String, pos: Vector2, parent: Node = null, nm: String = "") -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(ART + tex)
	s.centered = false
	s.position = pos
	_node(s, nm if nm != "" else tex.get_basename().to_pascal_case(), parent if parent else _props_root)
	return s


func _glow(pos: Vector2, col: Color, scale_: float, parent: Node = null) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = load(ART + "glow.png")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.modulate = col
	g.scale = Vector2.ONE * scale_
	g.position = pos
	g.z_index = 5
	_node(g, "Glow", parent if parent else lvl)
	return g


# ---------------------------------------------------------------- obloha a mesto v pozadí

func _sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -20
	_node(layer, "Sky", lvl)
	var tr := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color8(14, 12, 26))
	g.set_color(1, Color8(58, 36, 50))     # nízko nad mestom teplé svetlo ulíc
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 64
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	_node(tr, "Gradient", layer)
	var moon := Sprite2D.new()
	moon.texture = load(ART + "moon.png")
	moon.position = Vector2(470, 60)
	_node(moon, "Moon", layer)
	for spec in [["Far", "skyline_far.png", Vector2(0.2, 0.35), -235.0], ["Mid", "skyline_mid.png", Vector2(0.45, 0.6), -215.0]]:
		var p := Parallax2D.new()
		p.scroll_scale = spec[2]
		p.repeat_size = Vector2(640, 0)
		p.repeat_times = 4
		p.z_index = -30
		_node(p, "Skyline" + spec[0], lvl)
		var s := Sprite2D.new()
		s.texture = load(ART + spec[1])
		s.centered = false
		s.position = Vector2(-640, spec[3])
		_node(s, "Sprite", p)


# ---------------------------------------------------------------- 1. ulica

func _build_street() -> void:
	# zem: chodník + základ, ľavá stena (roh budovy) – ulica začína ďaleko vľavo (SX0)
	_fill(solid, SX0 - 2, 0, 150, 0, SIDEWALK)
	_fill(solid, SX0 - 2, 1, 150, 4, FILL)
	_fill(solid, SX0 - 2, -26, SX0 - 1, -1, BRICKS)
	# fasády domov v pozadí (rôzne výšky) + rímsy
	for b in [[SX0, -57, 13], [-56, -36, 18], [-35, -5, 11], [-4, 29, 14], [30, 61, 12], [62, 95, 16]]:
		_fill(back, b[0], -b[2], b[1], -1, BG_BRICKS)
		_fill(back, b[0], -b[2] - 1, b[1], -b[2] - 1, CAP)
		for wx in range(b[0] + 2, b[1] - 1, 5):
			for wy in range(-b[2] + 2, -6, 4):
				var lit: bool = rng.randf() < 0.45
				if wy == -10 and wx >= PZ and wx < PZ + 9:
					continue   # nad pizzeriou je štít (randf sa volá aj tak, aby ostatné okná ostali rovnaké)
				_sprite("window_lit.png" if lit else "window_dark.png", Vector2(wx * T, wy * T), null, "Window")
				if lit:
					_glow(Vector2(wx * T + 13, wy * T + 16), Color(1.0, 0.7, 0.35, 0.18), 0.9)
	for px in [-57, -36, -5, 29, 61]:
		_fill(back, px, -11, px, -1, PIPE)
	# --- nová prvá časť: skok cez debny, vyšší skok, požiarne schody ponad zátarasu z debien
	_fill(solid, -70, -1, -69, -1, CRATES)
	_fill(solid, -69, -2, -69, -2, CRATES)
	_fill(solid, -62, -3, -62, -1, CRATES)
	for p in [[-55, -51, -3], [-49, -45, -6]]:
		_fill(plats, p[0], p[2], p[1], p[2], GRATE)
		_fill(back, p[0], p[2] - 1, p[1], p[2] - 1, RAIL)
	_sprite("ladder.png", Vector2(-50 * T + 2, -6 * T), null, "Ladder")
	_fill(solid, -44, -7, -42, -1, CRATES)          # zátarasa z debien (vykladal sa náklaďák) – dá sa len prejsť hore
	_fill(solid, -30, -1, -30, -1, CRATES)
	# holičstvo (zatvorené, roleta) s markízou
	_sprite("shop_barbiere.png", Vector2(-24 * T + 8, -88), null, "Barbiere")
	_fill(plats, -24, -6, -24, -6, AWN[0])
	_fill(plats, -23, -6, -17, -6, AWN[1])
	_fill(plats, -16, -6, -16, -6, AWN[2])
	# --- pôvodná ulica
	_fill(solid, 22, -1, 23, -1, CRATES)
	_fill(solid, 23, -2, 23, -2, CRATES)
	# pizzeria Don Vito: svieti, vnútri súkromná oslava, pred dverami vyhadzovač
	# fasáda je 88 px vysoká – dvere (~80 px) musia byť vyššie ako vyhadzovač
	_sprite("shopfront.png", Vector2(PZ * T + 8, -88), null, "Shopfront")
	_fill(plats, PZ, -6, PZ, -6, AWN[0])
	_fill(plats, PZ + 1, -6, PZ + 7, -6, AWN[1])
	_fill(plats, PZ + 8, -6, PZ + 8, -6, AWN[2])
	_glow(Vector2(PZ * T + 48, -44), Color(1.0, 0.7, 0.35, 0.45), 2.8)         # teplé svetlo z výkladu
	_glow(Vector2(PZ * T + 112, -40), Color(1.0, 0.7, 0.35, 0.3), 1.6)
	_sprite("sign_board.png", Vector2(PZ * T + 8, -146), null, "SignBoard")
	for lx in [22, 98]:   # lampy nad štítom svietia naň
		_glow(Vector2(PZ * T + 8 + lx + 8, -138), Color(1.0, 0.85, 0.55, 0.5), 1.0)
	var neon := Sprite2D.new()
	neon.set_script(load("res://world/fx/neon_flicker.gd"))
	neon.set("on_texture", load(ART + "neon_blade_on.png"))
	neon.set("off_texture", load(ART + "neon_blade_off.png"))
	neon.texture = load(ART + "neon_blade_on.png")
	neon.centered = false
	neon.position = Vector2(PZ * T + 136, -182)
	_node(neon, "Neon", _props_root)
	_glow(Vector2(14, 31), Color(1.0, 0.25, 0.25, 0.5), 1.8, neon)
	_enemy("gangster_bruiser", Vector2((PZ + 9) * T + 4, 0), -1.0, {"passive": true, "stationary": true, "needs_light": false, "kind": "bouncer"})
	var bouncer := lvl.get_child(lvl.get_child_count() - 1)
	bouncer.name = "Bouncer"
	_trigger("BouncerTalk", Vector2((PZ + 4) * T, -30), Vector2(48, 60))
	# lampy so svetlom
	for lx in [SX0 + 4, -59, -28, 10, 50, 84]:
		_sprite("streetlamp.png", Vector2(lx * T, -86), null, "Lamp")
		_glow(Vector2(lx * T + 7, -76), Color(1.0, 0.78, 0.45, 0.55), 2.6)
		_glow(Vector2(lx * T + 7, -4), Color(1.0, 0.7, 0.4, 0.25), 2.0)   # svetlo na chodníku
	# smetiaky (dá sa na ne vyskočiť – jednosmerné)
	for bx in [-34, -12, 31, 46, 104]:
		_bin(Vector2(bx * T, 0))
	# plagáty
	_sprite("poster_chianti.png", Vector2(12 * T, -64), null, "Poster")
	_sprite("poster_chianti.png", Vector2(-40 * T, -150), null, "Poster")
	# WANTED plagáty – každý s inou náhodnou tvárou (poster_wanted_0..5.png)
	var faces: Array[int] = [0, 1, 2, 3, 4, 5]
	for i in range(faces.size() - 1, 0, -1):   # zamiešanie podľa seedu levelu
		var j := rng.randi_range(0, i)
		var tmp := faces[i]
		faces[i] = faces[j]
		faces[j] = tmp
	var spots: Array[Vector2] = [Vector2(-66 * T, -66), Vector2(26 * T, -66), Vector2(56 * T, -64), Vector2(58 * T + 6, -60), Vector2(90 * T, -66)]
	for i in spots.size():
		_sprite("poster_wanted_%d.png" % faces[i], spots[i], null, "Wanted")
	_wanted_yard = faces[spots.size()]
	# plot na konci ulice – 4 dlaždice (64 px): treba sa chytiť hrany
	_fill(solid, 96, -3, 97, -1, FENCE)
	_fill(solid, 96, -4, 97, -4, FENCE_TOP)


func _bin(pos: Vector2) -> void:
	var b := StaticBody2D.new()
	b.position = pos + Vector2(0, -20)
	b.add_to_group(&"platform", true)
	_node(b, "TrashBin", _props_root)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 4)
	cs.shape = r
	cs.position = Vector2(7, 2)
	cs.one_way_collision = true
	_node(cs, "Shape", b)
	var s := Sprite2D.new()
	s.texture = load(ART + "trash_bin.png")
	s.centered = false
	_node(s, "Sprite", b)


## Jednosmerná plošina z rekvizity (stôl, pult, sporák…) – dá sa na ňu vyskočiť zospodu
func _oneway(pos: Vector2, width: float, nm: String, tex: String = "", tex_offset: Vector2 = Vector2.ZERO) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.position = pos
	b.add_to_group(&"platform", true)
	_node(b, nm, _props_root)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 4)
	cs.shape = r
	cs.position = Vector2(width / 2.0, 2)
	cs.one_way_collision = true
	_node(cs, "Shape", b)
	if tex != "":
		var s := Sprite2D.new()
		s.texture = load(ART + tex)
		s.centered = false
		s.position = tex_offset
		_node(s, "Sprite", b)
	return b


# ---------------------------------------------------------------- 2. zadný dvor

func _build_yard() -> void:
	# zadná stena pizzerie v pozadí (vysoká)
	_fill(back, 98, -24, 133, -1, BG_BRICKS)
	_fill(back, 98, -25, 133, -25, CAP)
	_fill(back, 100, -24, 100, -1, PIPE)
	# požiarne schody: rošty (jednosmerné) + zábradlie + rebríky
	for p in [[102, 106, -3], [108, 112, -6], [102, 106, -9], [108, 112, -12]]:
		_fill(plats, p[0], p[2], p[1], p[2], GRATE)
		_fill(back, p[0], p[2] - 1, p[1], p[2] - 1, RAIL)
	for l in [[107, -6], [107, -12]]:
		_sprite("ladder.png", Vector2(l[0] * T + 2, l[1] * T), null, "Ladder")
	_sprite("window_lit.png", Vector2(109 * T, -16 * T), null, "Window")
	_glow(Vector2(109 * T + 13, -16 * T + 16), Color(1.0, 0.7, 0.35, 0.3), 1.2)
	# debny na dvore
	_fill(solid, 115, -1, 116, -1, CRATES)
	_sprite("poster_wanted_%d.png" % _wanted_yard, Vector2(113 * T, -64), null, "Wanted")
	# nízky oblúk (treba sa šmyknúť) a šachta medzi múrmi (odraz od steny)
	_fill(solid, 128, -14, 129, -3, BRICKS)
	_fill(solid, 128, -15, 129, -15, CAP)
	_fill(solid, 134, -26, 137, -1, BRICKS)
	# okno, cez ktoré Ricco vlezie (koniec tejto časti)
	_sprite("window_lit.png", Vector2(130 * T + 3, -18 * T), null, "WindowEnd")
	var wg := _glow(Vector2(131 * T + 8, -17 * T), Color(1.0, 0.75, 0.4, 0.75), 2.4)
	wg.set_script(load("res://world/fx/flicker.gd"))   # teplé svetlo z okna – sem treba vliezť
	# svetlo z okna dopadá na múr šachty pod ním (mäkké žiary, nie ostrý kužeľ)
	for i in 3:
		_glow(Vector2(131 * T + 6 - i * 6, -14 * T + i * 40), Color(1.0, 0.72, 0.4, 0.22 - i * 0.05), 1.6 - i * 0.2)
	_fill(plats, 130, -16, 131, -16, SILL)
	_glow(Vector2(117 * T, -40), Color(1.0, 0.7, 0.4, 0.2), 3.0)


# ---------------------------------------------------------------- 3. interiér (jeden súvislý priestor)
## Prológ bez zbrane – zakrádanie. Po vlezení oknom je všetko jedna budova bez ďalších prechodov:
## jedáleň → kuchyňa → sklad → (hore lávka / dole dvere) → herňa s balkónom → schody dole → pivnica.
## V interiéri je tma (CanvasModulate „Darkness“, zapne ju level1.gd), gangstri s needs_light vidia Ricca
## len vo svetle (LightZone) alebo celkom zblízka a nikdy nie za chrbtom. Kamera mení hranice plynule
## (CameraZone) – dole do pivnice sa posunie nižšie.

func _build_interior() -> void:
	_src = 1
	# obal hornej časti: tma nad stropom, strop, ľavá stena, dlážka
	_fill(solid, IX0 - 2, -30, IX1 + 2, TOP - 1, I_DARK)
	_fill(solid, IX0, TOP, KX0 - 1, TOP, I_BEAM)
	_fill(solid, IX0 - 2, TOP, IX0 + 1, -1, I_WALL)
	_fill(solid, IX0 - 2, 0, 203, 0, I_WOOD)
	_fill(solid, 204, 0, 241, 0, I_CHECKER)
	_fill(solid, 242, 0, STAIRS_X - 1, 0, I_WOOD)
	_fill(solid, IX0 - 2, 1, STAIRS_X - 1, 12, I_UNDER)
	# priečky s dverami (otvor 5 dlaždíc = 80 px, mafián s klobúkom má ~75 px) – z ďalšej miestnosti presvitá svetlo
	for px in [202, 240]:
		_fill(solid, px, TOP + 1, px + 1, -6, I_WALL)
		_fill(back, px, -5, px + 1, -1, I_PASSAGE)
		_sprite("door_frame.png", Vector2(px * T - 4, -86), null, "DoorFrame")
		_glow(Vector2(px * T + 16, -30), Color(1.0, 0.72, 0.4, 0.22), 1.4)
	# sklad → herňa: dvere dole aj otvor hore (lávka → balkón)
	# sklad → herňa: len oceľové dvere dole (K2 – treba správne zaklopať), hore je priečka plná
	_fill(solid, 280, TOP + 1, 281, -6, I_WALL)
	_fill(back, 280, -5, 281, -1, I_PASSAGE)   # vyšší otvor (80 px) – zmestí sa ním aj mafián
	_glow(Vector2(281 * T, -30), Color(1.0, 0.72, 0.4, 0.15), 1.2)
	_build_dining()
	_build_kitchen()
	_build_vent()
	_build_storage()
	_build_casino()
	_build_stairwell()
	_src = 0
	# kamera: hore jedáleň … herňa, dole schodisko a pivnica
	_camera_zone("ZoneUpper", Rect2(IX0 * T, -40 * T, (KX1 + 3 - IX0) * T, 52 * T), Rect2i(IX0 * T, (TOP - 2) * T, (KX0 + 2 - IX0) * T, (-TOP + 2) * T + 80))
	# tma v interiéri (vypnutá – zapne ju level pri vstupe)
	var dark := CanvasModulate.new()
	dark.color = Color(0.52, 0.47, 0.55)
	dark.visible = false
	_node(dark, "Darkness", lvl)


## Reštaurácia – súkromná oslava (H2): dole je jasno a plno hostí (Guest – zbadajú Ricca na svetle a zvrieskajú),
## hore je tma: galéria pri okne → trám → zavesená polica → trám. Pred dverami do kuchyne visí lampa nad barom –
## klobúkom ju treba zhasnúť a potom zozadu zneškodniť mafiána pri bare.
func _build_dining() -> void:
	_fill(back, IX0 + 2, TOP + 1, 201, TOP + 1, I_PAPER_TOP)
	_fill(back, IX0 + 2, TOP + 2, 201, -4, I_PAPER)
	_fill(back, IX0 + 2, -3, 201, -3, I_WAINSCOT_TOP)
	_fill(back, IX0 + 2, -2, 201, -1, I_WAINSCOT)
	# okno, ktorým Ricco vliezol (svieti mesiac) – hore nad galériou
	_sprite("window_night.png", Vector2((IX0 + 3) * T + 3, -14 * T), null, "Window")
	_glow(Vector2((IX0 + 3) * T + 16, -12 * T), Color(0.45, 0.55, 1.0, 0.3), 1.8)
	# tmavá cesta hore: galéria → dlhý trám A → zavesená polica → trám B nad barom
	# (trámy visia na stĺpikoch len na koncoch – nápisy kriedou sú na stene medzi nimi a nič ich nepreškrtne)
	_fill(solid, IX0 + 2, DINE_GALLERY, IX0 + 9, DINE_GALLERY, I_BALCONY)
	_fill(back, IX0 + 2, DINE_GALLERY - 1, IX0 + 9, DINE_GALLERY - 1, I_RAIL)
	_fill(back, IX0 + 7, DINE_GALLERY + 1, IX0 + 7, -1, I_PILLAR)
	for bm in [[155, 176], [184, 200]]:
		_fill(solid, bm[0], DINE_BEAM, bm[1], DINE_BEAM, I_BEAM)
		for px in [bm[0], bm[1]]:
			_fill(back, px, TOP + 1, px, DINE_BEAM - 1, I_PILLAR)   # trám visí na stĺpikoch od stropu
	_oneway(Vector2(179 * T, DINE_GALLERY * T), 48, "HangingShelf", "hanging_shelf.png", Vector2(0, -28))
	_fill(back, 179, TOP + 1, 179, DINE_GALLERY - 3, I_PILLAR)
	_fill(back, 181, TOP + 1, 181, DINE_GALLERY - 3, I_PILLAR)
	for gx in [IX0 + 4, 177]:
		_sprite("garland.png", Vector2(gx * T + 8, (TOP + 3) * T), null, "Garland")
	for i in 6:
		_sprite("photo_%d.png" % (i % 2), Vector2((157 + i * 3) * T + 1, -8 * T), null, "Photo")
	# dole: lampy (pod trámom visia z trámu), svetlo celého parketu
	_pendant(Vector2(153 * T + 8, -170), true, (TOP + 1) * T)
	for lx in [161, 170]:
		_pendant(Vector2(lx * T + 8, -150), true, (DINE_BEAM + 1) * T)
	_pendant(Vector2(180 * T + 8, -136), true, DINE_GALLERY * T + 12)   # visí zo zavesenej police
	_light(Rect2((IX0 + 2) * T, -6 * T, (189 - IX0 - 2) * T, 6 * T))
	# hostia v skupinkách: pri stene, parket s harmonikárom, banket, kokteil pri polici
	_guest("eat_04", Vector2((IX0 + 3) * T, 0), 1.0)   # pri stene na stoličke
	_guest("stand_00", Vector2((IX0 + 6) * T, 0), 1.0)
	_guest("stand_01", Vector2((IX0 + 8) * T, 0), -1.0)
	_guest("stand_04", Vector2(153 * T, 0), 1.0)
	_guest("dance", Vector2(156 * T + 8, 0), 1.0, true)
	_guest("accordion", Vector2(160 * T + 8, 0), -1.0, true)
	var banquet := _sprite("banquet.png", Vector2(163 * T, -34), null, "Banquet")
	banquet.z_index = -2
	for e in [[164, "eat_00", 1.0], [166.5, "eat_05", 1.0], [169, "eat_01", 1.0], [171.5, "eat_02", -1.0], [174, "eat_03", -1.0]]:
		_guest(e[1], Vector2(e[0] * T + 8, 0), e[2], false, -3)
	_guest("stand_02", Vector2(178 * T, 0), 1.0)
	_guest("stand_05", Vector2(180 * T, 0), -1.0)
	_guest("stand_03", Vector2(183 * T, 0), 1.0)
	_guest("stand_06", Vector2(185 * T, 0), -1.0)
	# bar pri kuchyni – mafián chrbtom k miestnosti, nad ním lampa (zhasnúť klobúkom!)
	_sprite("bar_shelf.png", Vector2(194 * T, -116), null, "BarShelf")
	_oneway(Vector2(194 * T, -44), 112, "Bar", "bar_counter.png")
	for cx in [196, 199]:
		_sprite("chianti_candle.png", Vector2(cx * T, -62), null, "Candle")
		_glow(Vector2(cx * T + 4, -62), Color(1.0, 0.7, 0.35, 0.4), 0.7)
	_hat_lamp(Vector2(200 * T + 8, -120), Rect2(193 * T, -5 * T, 11 * T, 5 * T), (DINE_BEAM + 1) * T)   # šnúra vpravo od nápisu kriedou
	_enemy("gangster_bruiser", Vector2(193 * T + 8, 0), 1.0, {"stationary": true, "kind": "dock"})


## Hosť na oslave (world/npc/guest.gd) – obrázok so 4 snímkami vedľa seba, stojí nohami na pos
func _guest(tex: String, pos: Vector2, face: float, loop: bool = false, z: int = -3) -> void:
	var g := Sprite2D.new()
	g.set_script(load("res://world/npc/guest.gd"))
	g.texture = load(ART + "guests/%s.png" % tex)
	g.hframes = 4
	g.centered = false
	var fw: float = g.texture.get_width() / 4.0
	g.offset = Vector2(-fw / 2.0, -g.texture.get_height())
	g.flip_h = face < 0.0
	g.set("loop", loop)
	g.position = pos
	g.z_index = z
	_node(g, "Guest", lvl)


## Lampa, ktorú zhasne hodený klobúk (world/fx/hat_lamp.gd): telo na vrstve nepriateľov + kužeľ, žiara, svetlo
func _hat_lamp(pos: Vector2, light: Rect2, top: float = (TOP + 1) * T) -> void:
	var cord := Line2D.new()
	cord.points = PackedVector2Array([Vector2(pos.x, top), Vector2(pos.x, pos.y)])
	cord.width = 1.0
	cord.default_color = Color8(30, 26, 26)
	_node(cord, "Cord", _props_root)
	var b := StaticBody2D.new()
	b.set_script(load("res://world/fx/hat_lamp.gd"))
	_node(b, "HatLamp", lvl)
	b.position = pos
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(20, 14)
	cs.shape = rs
	cs.position = Vector2(0, 4)
	_node(cs, "Shape", b)
	var s := Sprite2D.new()
	s.texture = load(ART + "pendant_lamp.png")
	s.centered = false
	s.position = Vector2(-8, 0)
	s.z_index = -5
	_node(s, "Lamp", b)
	var cone := Sprite2D.new()
	cone.texture = load(ART + "light_cone.png")
	cone.centered = false
	cone.position = Vector2(-56, 8)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cone.material = m
	cone.z_index = 4
	cone.scale.y = minf(1.0, (-pos.y - 8.0) / 150.0)
	_node(cone, "Cone", b)
	_glow(Vector2(0, 8), Color(1.0, 0.85, 0.55, 0.55), 1.2, b)
	var a := Area2D.new()
	a.set_script(load("res://world/stealth/light_zone.gd"))
	_node(a, "Light", b)
	a.position = light.get_center() - pos
	var lcs := CollisionShape2D.new()
	var lrs := RectangleShape2D.new()
	lrs.size = light.size
	lcs.shape = lrs
	_node(lcs, "Shape", a)


## Kuchyňa – pec (svieti), kuchár pri pulte otočený chrbtom, polica hore = tmavá cesta; vzadu umývačka riadu
func _build_kitchen() -> void:
	_fill(back, 204, TOP + 1, 239, -6, I_KWALL)
	_fill(back, 204, -5, 239, -5, I_KBAND)
	_fill(back, 204, -4, 239, -1, I_KTILE)
	# pec + oheň + svetlo
	_sprite("oven.png", Vector2(205 * T, -100), null, "Oven")
	var fire := _sprite("oven_fire.png", Vector2(205 * T + 22, -42), null, "OvenFire")
	fire.set_script(load("res://world/fx/flicker.gd"))
	var og := _glow(Vector2(205 * T + 42, -30), Color(1.0, 0.5, 0.2, 0.6), 3.2)
	og.set_script(load("res://world/fx/flicker.gd"))
	_light(Rect2(204 * T, -7 * T, 8 * T, 7 * T))
	# debny pri peci = schod na policu
	_src = 0
	for c in [[212, -1], [213, -1], [213, -2], [213, -3]]:
		_fill(solid, c[0], c[1], c[0], c[1], CRATES)
	_src = 1
	# pult s pizzou, lampa visí pod policou (svetlo len pod ňou)
	_oneway(Vector2(223 * T, -34), 112, "Counter", "kitchen_counter.png")
	_sprite("pizza_counter.png", Vector2(225 * T, -42), null, "Pizza")
	_pendant(Vector2(226 * T, -70), true, -5 * T + 3)
	_light(Rect2(219 * T, -4 * T, 10 * T, 4 * T))
	# panvice a polica hore (cesta v tme ponad kuchára)
	_sprite("pans.png", Vector2(215 * T, -10 * T), null, "Pans")
	_fill(plats, 214, -5, 231, -5, I_SHELF)
	_sprite("jars.png", Vector2(216 * T, -5 * T - 12), null, "Jars")
	_sprite("jars.png", Vector2(222 * T, -5 * T - 12), null, "Jars")
	_enemy("gangster_bruiser", Vector2(221 * T + 8, 0), 1.0, {"stationary": true, "look_back": Vector2(4.0, 7.0), "kind": "toro"})
	# zadná časť: vrecia, sudy, druhý gangster si chodí sem a tam v tme
	_sprite("flour_sacks.png", Vector2(234 * T, -18), null, "Flour")
	_sprite("barrel.png", Vector2(238 * T, -24), null, "Barrel")
	_enemy("gangster_bruiser", Vector2(235 * T, 0), -1.0, {"patrol_span": 40.0, "walk_speed": 22.0})


## Vetracie potrubie pod stropom: z trámu B nad barom cez priečku do kuchyne (vnútro 32 px – Ricco sa musí
## šmyknúť dnu a plaziť sa). Na konci v kuchyni vypadne na tmavú policu nad kuchárom – obíde bar aj dvere.
func _build_vent() -> void:
	_fill(solid, VENT_X0, VENT_Y - 1, VENT_X1, VENT_Y - 1, I_DUCT)   # plech hore (aj cez priečku)
	_fill(solid, VENT_X0, VENT_Y + 2, VENT_X1, VENT_Y + 2, I_DUCT)   # dno (v jedálni nadväzuje na trám B)
	for y in [VENT_Y, VENT_Y + 1]:
		for x in range(VENT_X0, VENT_X1 + 1):
			solid.erase_cell(Vector2i(x, y))
			back.set_cell(Vector2i(x, y), 1, I_DUCT_IN)
		back.set_cell(Vector2i(VENT_X0, y), 1, I_DUCT_END)
		back.set_cell(Vector2i(VENT_X1, y), 1, I_DUCT_END, 1)
	# vytrhnutá mriežka opretá na tráme pri vstupe
	_sprite("vent_grille.png", Vector2((VENT_X0 - 1) * T + 2, (VENT_Y + 2) * T - 28), null, "VentGrille")


## Sklad – debny, sudy, polica s lampou pod ňou, strážca hliadkuje; vzadu veža z debien na lávku do herne
func _build_storage() -> void:
	_fill(back, 242, TOP + 1, 279, -1, I_PLANKS)
	_src = 0
	for c in [[244, -1], [245, -1], [246, -1], [244, -2], [245, -2], [244, -3]]:
		_fill(solid, c[0], c[1], c[0], c[1], CRATES)
	_src = 1
	for bx in [248, 249]:
		_sprite("barrel.png", Vector2(bx * T, -24), null, "Barrel")
	_sprite("flour_sacks.png", Vector2(263 * T, -18), null, "Flour")
	# polica (jednosmerná) – nad svetlom lampy, ktorá visí pod ňou
	_fill(plats, 247, -5, 266, -5, I_SHELF)
	_sprite("jars.png", Vector2(250 * T, -5 * T - 12), null, "Jars")
	_sprite("flour_sacks.png", Vector2(260 * T, -5 * T - 18), null, "Flour")
	_pendant(Vector2(257 * T + 8, -70), true, -5 * T + 3)
	_light(Rect2(253 * T, -4 * T, 10 * T, 4 * T))
	_enemy("gangster_slugger", Vector2(257 * T, 0), -1.0, {"patrol_span": 110.0, "walk_speed": 28.0})
	# police ako schody na lávku (jednosmerné – dole sa dá prejsť, mafián tade chodí k dverám herne)
	_fill(plats, 265, -3, 266, -3, I_SHELF)
	_fill(plats, 267, -6, 268, -6, I_SHELF)
	# lávka pod stropom (plná) – tmavý úkryt nad dverami herne
	_fill(solid, 269, BALCONY_Y, 279, BALCONY_Y, I_BALCONY)
	_fill(back, 269, BALCONY_Y - 1, 279, BALCONY_Y - 1, I_RAIL)
	_fill(back, 274, BALCONY_Y + 1, 274, -1, I_PILLAR)


## Oceľové dvere s okienkom (world/fx/speakeasy_door.gd) + skrytá krieda s rytmom (ukáže sa po ukážke)
func _speakeasy_door() -> void:
	var d := StaticBody2D.new()
	d.set_script(load("res://world/fx/speakeasy_door.gd"))
	_node(d, "SpeakeasyDoor", lvl)
	d.position = Vector2(281 * T, 0)
	var sp := Sprite2D.new()
	sp.texture = load(ART + "steel_door.png")
	sp.hframes = 3
	sp.centered = false
	sp.position = Vector2(-16, -80)
	sp.z_index = -4
	_node(sp, "Sprite", d)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(32, 80)
	cs.shape = rs
	cs.position = Vector2(0, -40)
	_node(cs, "Shape", d)
	d.set("doorman_path", NodePath("../Doorman"))
	d.set("messenger_scene", load("res://characters/gangster/gangster_bruiser.tscn"))
	d.set("messenger_from", Vector2(251 * T, 0))   # za debnami pri dverách z kuchyne (mimo obrazovky)
	d.set("hint_path", NodePath("../KnockHint"))
	var h := Node2D.new()
	_node(h, "KnockHint", lvl)
	h.z_index = -4
	h.visible = false
	_chalk(h, Vector2(271.2, -7.5) * T, "F - KNOCK LIKE HE DID:\nKNOCK KNOCK . . .\nKNOCK KNOCK KNOCK", 77)


## Zadná herňa – nelegálne stoly dole (gangstri hrajú, svetlo len nad stolmi), hore tmavý balkón s hliadkou.
## Hliadku sa dá omráčiť klobúkom a dorobiť (F), alebo sa k nej prikradnúť zozadu.
func _build_casino() -> void:
	_fill(back, CX0, TOP + 1, KX0 - 1, TOP + 1, I_PAPER_TOP)
	_fill(back, CX0, TOP + 2, KX0 - 1, -4, I_PAPER)
	_fill(back, CX0, -3, KX0 - 1, -3, I_WAINSCOT_TOP)   # obklad ide aj nad schodiskom (zadná stena herne pokračuje)
	_fill(back, CX0, -2, KX0 - 1, -1, I_WAINSCOT)
	# balkón (plný) so zábradlím a stĺpmi
	_fill(solid, CX0 + 3, BALCONY_Y, BALCONY_X1, BALCONY_Y, I_BALCONY)
	_fill(back, CX0 + 3, BALCONY_Y - 1, BALCONY_X1, BALCONY_Y - 1, I_RAIL)
	# tmavý kút za dverami: dve police ako schody na balkón
	_fill(plats, CX0, -3, CX0 + 1, -3, I_SHELF)
	_fill(plats, CX0 + 1, -6, CX0 + 2, -6, I_SHELF)
	_sprite("jars.png", Vector2(CX0 * T, -3 * T - 12), null, "Jars")
	for px in [291, 300, 311, 322]:
		_fill(back, px, BALCONY_Y + 1, px, -1, I_PILLAR)
	# výzdoba na balkóne: portrét Dona, nástenné lampy (len žiara, nie svetlo – balkón je tmavý)
	_sprite("don_portrait.png", Vector2(297 * T, (BALCONY_Y - 6) * T), null, "DonPortrait")
	for sx in [289, 305, 320]:
		_sprite("wall_sconce.png", Vector2(sx * T, (BALCONY_Y - 5) * T), null, "Sconce")
		_glow(Vector2(sx * T + 5, (BALCONY_Y - 5) * T + 4), Color(1.0, 0.8, 0.5, 0.25), 0.9)
	# bar vľavo pod balkónom (barman sa pozerá do herne)
	_sprite("bar_shelf.png", Vector2(286 * T, -116), null, "BarShelf")
	_oneway(Vector2(286 * T, -44), 112, "Bar", "bar_counter.png")
	for cx in [288, 291]:
		_sprite("chianti_candle.png", Vector2(cx * T, -62), null, "Candle")
		_glow(Vector2(cx * T + 4, -62), Color(1.0, 0.7, 0.35, 0.4), 0.7)
	_light(Rect2(286 * T, -5 * T, 8 * T, 5 * T))
	# vyhadzovač hneď za dverami (pozerá na dvere, kým sa neotvoria)
	_enemy("gangster_bruiser", Vector2(CX0 * T + 40, 0), -1.0, {"stationary": true, "kind": "bouncer"})
	lvl.get_child(lvl.get_child_count() - 1).name = "Doorman"
	_speakeasy_door()
	# stoly – každý pod zelenou lampou, okolo dvaja hráči otočení k stolu
	for t in [[294, "card_table.png", 64], [305, "roulette.png", 72], [316, "card_table.png", 64]]:
		var tx: int = t[0]
		var w: int = t[2]
		var ty: int = -30 if w == 64 else -32
		_sprite(t[1], Vector2(tx * T, ty), null, "Table")
		_sprite("money.png", Vector2(tx * T + w / 2.0 - 7, ty - 4), null, "Money")
		_pendant(Vector2(tx * T + w / 2.0, -90), true, (BALCONY_Y + 1) * T)
		_light(Rect2(tx * T - 40, -5 * T, w + 80, 5 * T))
	_smoke(Vector2(301 * T, -70))
	_smoke(Vector2(318 * T, -70))
	# hráči – každý pri inom stole, ďaleko od seba (nie na kope)
	_enemy("gangster_bruiser", Vector2(293 * T, 0), 1.0, {"stationary": true, "kind": "toro"})
	_enemy("gangster_bruiser", Vector2(310 * T + 8, 0), -1.0, {"stationary": true, "look_back": Vector2(5.0, 9.0), "kind": "dock"})
	_enemy("gangster_bruiser", Vector2(321 * T + 8, 0), -1.0, {"stationary": true, "kind": "toro"})
	# hliadka na balkóne
	_enemy("gangster_slugger", Vector2(300 * T, BALCONY_Y * T), -1.0, {"patrol_span": 80.0, "walk_speed": 26.0})
	for i in 3:
		_sprite("photo_%d.png" % (i % 2), Vector2((330 + i * 4) * T, -6 * T), null, "Photo")


## Schody dole z herne – tmavé schodisko; hore na ňom začne prechod do pivnice (samostatná mapa, levels/level1/cellar.tscn)
func _build_stairwell() -> void:
	for i in 6:
		_fill(solid, STAIRS_X + i, i + 2, STAIRS_X + i, 12, I_STAIR_FILL)
		solid.set_cell(Vector2i(STAIRS_X + i, i + 1), 1, I_STAIR_TOP[0])
	for i in 7:
		solid.set_cell(Vector2i(STAIRS_X + i, i), 1, I_NOSE[0])   # jemné schodíky presne po rampe (bez kolízie)
	# šikmá rampa cez hrany schodov (45°) – po schodoch sa ide plynule, nie skokmi po 16 px
	_stair_ramp(PackedVector2Array([Vector2(STAIRS_X * T, 0), Vector2((STAIRS_X + 7) * T, 7 * T), Vector2(STAIRS_X * T, 7 * T)]))
	_fill(solid, STAIRS_X, 7, KX0 + 1, 12, I_UNDER)
	_fill(solid, KX0, TOP, KX0 + 1, 6, I_WALL)
	_fill(solid, KX0 + 2, TOP, KX1 + 2, 12, I_DARK)
	_fill(back, STAIRS_X, 0, KX0 - 1, 6, I_STONE_BG)   # pod úrovňou podlahy kameň (aj riadok podlahy – inak tam bola diera)
	# dole sa stráca v tme (čierny prechod cez spodné schody)
	var fade := _sprite("stair_fade.png", Vector2((STAIRS_X + 2) * T, 1 * T), null, "StairFade")
	fade.z_index = 3
	_glow(Vector2((STAIRS_X + 3) * T, 4 * T), Color(1.0, 0.75, 0.45, 0.18), 1.6)   # slabé svetlo zdola (Donova žiarovka)


## Neviditeľná šikmá rampa cez schody (Godot docs: classes/class_collisionpolygon2d). Postavy majú
## floor_max_angle 50°, takže po 45° rampe chodia ako po zemi; schodíky sú len obrázok pod ňou.
## Bežný postup v 2D plošinovkách – kolízia schodov ako svah, kresba ako schody.
func _stair_ramp(pts: PackedVector2Array) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	_node(b, "StairRamp", lvl)
	var cp := CollisionPolygon2D.new()
	cp.polygon = pts
	_node(cp, "Shape", b)


## Dlaždica schodu (znak ^): vnútro je kameň, vrchný blok pod schodíkmi má len posledný schodík,
## najvyšší schod má rovný vrch
func _stair_tile(x: int, y: int) -> Vector2i:
	if _mz_solid(x, y - 1):
		return TN_STAIR_FILL
	if _mz(x - 1, y - 1) == "^":
		return TN_STAIR_TOP[0]
	if _mz(x + 1, y - 1) == "^":
		return TN_STAIR_TOP[1]
	return TN_STAIR_FLAT


## Rampy cez schody v pivnici (znak ^): pri každom schode, za ktorým je o riadok nižšie ďalší schod
## alebo zem, vyplní trojuholník nad nižším políčkom – spolu tvoria jeden 45° svah po hranách schodov.
func _maze_ramps() -> void:
	var tris: Array[PackedVector2Array] = []
	for y in _maze.size():
		for x in _maze[y].length():
			if _mz(x, y) != "^" or _mz_solid(x, y - 1):
				continue   # len vrchný schod v stĺpci
			for dir in [1, -1]:
				var nx: int = x + dir
				if _mz_solid(nx, y) or not _mz_solid(nx, y + 1):
					continue   # vedľa nie je o riadok nižšie povrch
				var edge: float = (x + (1 if dir > 0 else 0)) * T   # hrana schodu
				tris.append(PackedVector2Array([Vector2(edge, y * T), Vector2(edge + dir * T, (y + 1) * T), Vector2(edge, (y + 1) * T)]))
				solid.set_cell(Vector2i(nx, y), 2, TN_NOSE[0 if dir > 0 else 1])   # kresba schodíkov presne po rampe
	for t in tris:
		_stair_ramp(t)


## Miesto, kde leží Don: kaluž krvi so špliechancami, kabát, klobúk, pištoľ, prevrátená stolička,
## rozbitá fľaša, diery po guľkách v stene, duch (cutscéna)
func _build_don(at: Vector2, top_y: float) -> void:
	var don := Node2D.new()
	don.set_script(load("res://levels/level1/don_cutscene.gd"))
	_node(don, "DonScene", lvl)
	don.position = at
	var holes := _cs_sprite(don, "BulletHoles", ART + "bullet_holes.png", Vector2(-40, -112))
	holes.z_index = -6
	var smear := _cs_sprite(don, "Smear", "res://characters/don/blood_smear.png", Vector2(-16, -64))
	smear.z_index = -6
	var pool := _cs_sprite(don, "Pool", "res://characters/don/blood_pool.png", Vector2(-48, -8))
	pool.z_index = -4
	_cs_sprite(don, "Chair", ART + "chair_tipped.png", Vector2(52, -20))
	_cs_sprite(don, "Bottle", ART + "broken_bottle.png", Vector2(-74, -8))
	_cs_sprite(don, "Coat", "res://characters/don/don_coat.png", Vector2(22, -12))
	_cs_sprite(don, "Hat", "res://characters/don/don_hat.png", Vector2(-66, -10))
	_cs_sprite(don, "Body", "res://characters/don/don_dying.png", Vector2(-38, -36))
	var gun := _cs_sprite(don, "Gun", "res://weapons/pistol/pistol.png", Vector2(14, -5))
	gun.rotation = 0.25
	var gg := Sprite2D.new()
	gg.texture = load(ART + "glow.png")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gg.material = m
	gg.modulate = Color(0.45, 0.9, 1.0, 0.8)
	gg.scale = Vector2(1.6, 2.2)
	gg.position = Vector2(0, -42)
	gg.z_index = 6
	_node(gg, "GhostGlow", don)
	var ghost := Sprite2D.new()
	ghost.texture = load("res://characters/don/ghost_don.png")
	ghost.position = Vector2(0, -42)
	ghost.z_index = 7
	_node(ghost, "Ghost", don)
	# holá žiarovka nad Donom
	var cord := Line2D.new()
	cord.points = PackedVector2Array([Vector2(at.x, top_y), Vector2(at.x, at.y - 120)])
	cord.width = 1.0
	cord.default_color = Color8(30, 26, 26)
	_node(cord, "Cord", _props_root)
	_sprite("bulb.png", Vector2(at.x - 4, at.y - 120), null, "Bulb")
	var bglow := _glow(Vector2.ZERO, Color(1.0, 0.85, 0.55, 0.6), 2.4, don)
	bglow.name = "BulbGlow"
	bglow.position = Vector2(0, -114)
	var cone := _sprite("light_cone.png", Vector2(at.x - 56, at.y - 112), null, "Cone")
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cone.material = cm
	cone.z_index = 4
	cone.scale.y = 112.0 / 150.0


func _cs_sprite(parent: Node, nm: String, path: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.position = pos
	_node(s, nm, parent)
	return s


## Nápis kriedou (world/fx/chalk_text.gd) – väčšie, rukou písané písmená
func _chalk(parent: Node, pos: Vector2, text: String, seed_: int) -> void:
	var c := Node2D.new()
	c.set_script(load("res://world/fx/chalk_text.gd"))
	c.set("text", text)
	c.set("seed_value", seed_)
	c.position = pos
	c.rotation = rng.randf_range(-0.035, 0.01)
	_node(c, "Chalk", parent)


## Oblasť, v ktorej kamera dostane iné hranice (world/fx/camera_zone.gd)
func _camera_zone(nm: String, area: Rect2, limits: Rect2i) -> void:
	var z := Area2D.new()
	z.set_script(load("res://world/fx/camera_zone.gd"))
	z.set("limits", limits)
	_node(z, nm, lvl)
	z.position = area.get_center()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = area.size
	cs.shape = rs
	_node(cs, "Shape", z)


## Dym z cigár nad stolmi (pomalé sivé obláčiky)
func _smoke(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = load(ART + "glow.png")
	p.amount = 14
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(180, 20)
	p.direction = Vector2(1, -0.2)
	p.spread = 30.0
	p.gravity = Vector2(0, -3)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.color = Color(0.75, 0.72, 0.7, 0.07)
	p.position = pos
	p.z_index = 6
	_node(p, "Smoke", lvl)


## Visiaca lampa: šnúra od stropu (alebo od police), tienidlo; ak svieti, aj kužeľ a žiara
func _pendant(pos: Vector2, lit: bool, top: float = TOP * T + 16) -> void:
	var cord := Line2D.new()
	cord.points = PackedVector2Array([Vector2(pos.x, top), Vector2(pos.x, pos.y)])
	cord.width = 1.0
	cord.default_color = Color8(30, 26, 26)
	_node(cord, "Cord", _props_root)
	_sprite("pendant_lamp.png", pos + Vector2(-8, 0), null, "Lamp")
	if lit:
		var cone := _sprite("light_cone.png", pos + Vector2(-56, 8), null, "Cone")
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		cone.material = m
		cone.z_index = 4
		cone.scale.y = minf(1.0, (-pos.y - 8.0) / 150.0)   # kužeľ končí na dlážke
		_glow(pos + Vector2(0, 8), Color(1.0, 0.85, 0.55, 0.55), 1.2)


## Oblasť svetla – tu Ricca vidno (world/stealth/light_zone.gd)
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


func _enemy(scene: String, pos: Vector2, face: float, props: Dictionary) -> void:
	var g: Node2D = load("res://characters/gangster/%s.tscn" % scene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	g.set("start_facing", face)
	g.set("needs_light", true)
	g.set("respawn_time", 0.0)
	for k in props:
		g.set(k, props[k])
	_node(g, scene.to_pascal_case(), lvl)
	g.position = pos


# ---------------------------------------------------------------- nápisy kriedou (tutoriál)

func _hints() -> void:
	var hints := [
		[Vector2(SX0 + 2, -5), "A / D  -  MOVE"],
		[Vector2(-70, -7), "SPACE  -  JUMP"],
		[Vector2(-65, -8), "HOLD SPACE  -  JUMP HIGHER"],
		[Vector2(-54, -12), "BLOCKED? GO OVER IT.\nJUMP UP THROUGH THE GRATES"],
		[Vector2(76, -8), "JUMP AT AN EDGE  -  GRAB IT\nSPACE  -  CLIMB UP"],
		[Vector2(114, -6), "S / CTRL  -  BELLY SLIDE"],
		[Vector2(116, -13), "WALL JUMP:\nJUMP AT THE WALL,\nTHEN PRESS SPACE AGAIN"],
		[Vector2(122, -24), "UP TO THE WINDOW!"],
		[Vector2(156.3, -16.6), "NO GUN? STAY UP HERE IN THE DARK.\nDOWN IN THE LIGHT EVERYBODY SEES YOU."],
		[Vector2(185.4, -16.6), "RIGHT MOUSE / E  -  THROW HAT\nPUT OUT THAT LAMP FIRST"],
		[Vector2(182.3, -10.7), "{SNEAK}\nF  -  TAKE HIM DOWN FROM BEHIND"],
		[Vector2(216, -14), "THEY DON'T SEE BEHIND THEM...\nUNTIL THEY TURN AROUND."],
		[Vector2(243, -13), "THE HIGH ROAD IS DARKER."],
		[Vector2(283, -15), "A HAT TO THE HEAD STUNS HIM.\nTHEN F  -  FINISH THE JOB."],
	]
	var parent := Node2D.new()
	_node(parent, "Hints", lvl)
	parent.z_index = -4
	for i in hints.size():
		_chalk(parent, hints[i][0] * T, hints[i][1], 11 + i)


# ================================================================ PIVNICA (samostatná scéna)

var _maze: Array[String] = []
var water: TileMapLayer


func _mz(x: int, y: int) -> String:
	if y < 0 or y >= _maze.size() or x < 0 or x >= _maze[y].length():
		return "#"
	return _maze[y][x]


## Je políčko pevné (stena, schod, zával, mreže, debna)?
func _mz_solid(x: int, y: int) -> bool:
	return _mz(x, y) in ["#", "^", "R", "|", "x"]


func _build_cellar_scene(ts: TileSet) -> void:
	_maze.assign(MAZE.strip_edges().split("\n"))
	_src = 2
	lvl = Node2D.new()
	lvl.name = "Cellar"
	lvl.set_script(load("res://levels/level1/cellar.gd"))
	var bgc := CanvasLayer.new()
	bgc.layer = -20
	_node(bgc, "Black", lvl)
	var bgr := ColorRect.new()
	bgr.color = Color8(12, 9, 11)
	bgr.set_anchors_preset(Control.PRESET_FULL_RECT)
	_node(bgr, "Rect", bgc)
	back = _layer("Back", ts, -10)
	_props_root = _node(Node2D.new(), "Props", lvl)
	_props_root.z_index = -5
	solid = _layer("Solid", ts, 0)
	plats = _layer("Platforms", ts, 0)
	plats.add_to_group(&"platform", true)
	water = _layer("Water", ts, 6)
	var h := _maze.size()
	var w := _maze[0].length()
	for y in h:
		for x in w:
			var c := _mz(x, y)
			var cell := Vector2i(x, y)
			if c == "#":
				var t: Vector2i
				if not _mz_solid(x, y + 1):
					t = TN_CEIL
				elif not _mz_solid(x, y - 1):
					t = TN_FLOOR
				else:
					var near := false
					for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1)]:
						if not _mz_solid(x + d.x, y + d.y):
							near = true
					t = TN_BRICK[rng.randi() % 2] if near else TN_EARTH
				solid.set_cell(cell, 2, t)
				continue
			# všetko ostatné má za sebou pozadie tunela
			var bgt: Vector2i = TN_BG[rng.randi() % 2]
			if x % 9 == 0:
				bgt = TN_BG_RIB
			elif _mz_solid(x, y - 1) and rng.randf() < 0.18:
				bgt = TN_BG_PIPE
			elif rng.randf() < 0.06:
				bgt = TN_BG_WET
			elif x % 13 == 5 and not _mz_solid(x, y + 1):
				bgt = TN_BG_POST
			if y <= 2 and x <= 2:
				bgt = TN_VOID   # schodisko hore do herne – tma
			if CATACOMB.has_point(cell):
				var r := rng.randf()
				bgt = TN_OSSUARY[0] if r < 0.55 else (TN_OSSUARY[1] if r < 0.75 else TN_BG[rng.randi() % 2])
			back.set_cell(cell, 2, bgt)
			match c:
				"^": solid.set_cell(cell, 2, _stair_tile(x, y))
				"R": solid.set_cell(cell, 2, TN_RUBBLE)
				"|": solid.set_cell(cell, 2, TN_BARS)
				"x": solid.set_cell(cell, 2, TN_CRATE)
				"=": plats.set_cell(cell, 2, TN_GRATE)
				"-": plats.set_cell(cell, 2, TN_PLANK)
				"~": water.set_cell(cell, 2, TN_SURFACE if _mz(x, y + 1) == "%" else TN_WATER)
				"%": water.set_cell(cell, 2, TN_DEEP)
	_maze_ramps()
	_water_zone()
	# objekty podľa znakov
	for y in h:
		for x in w:
			var c := _mz(x, y)
			var foot := Vector2((x + 0.5) * T, (y + 1) * T)   # stred spodku políčka = zem
			match c:
				"S": _marker("CellarSpawn", foot)
				"K": _marker("EnemySpawn", foot)
				"b": _bulb(Vector2((x + 0.5) * T, y * T), _floor_below(x, y))
				"o": _sprite("blood_drop.png", foot + Vector2(-3, -3), null, "Blood")
				"c":
					_sprite("chianti_candle.png", foot + Vector2(-4, -18), null, "Candle")
					var cg := _glow(foot + Vector2(0, -16), Color(1.0, 0.65, 0.3, 0.5), 1.5)
					cg.set_script(load("res://world/fx/flicker.gd"))
				"r":
					var rat := Sprite2D.new()
					rat.set_script(load("res://world/npc/rat.gd"))
					rat.texture = load(ART + "rat.png")
					rat.hframes = 2
					rat.offset = Vector2(0, -4)
					rat.position = foot
					_node(rat, "Rat", lvl)
				"L":
					_sprite("still.png", foot + Vector2(-8, -48), null, "Still")
					var sg := _glow(foot + Vector2(8, -4), Color(1.0, 0.55, 0.2, 0.5), 1.4)
					sg.set_script(load("res://world/fx/flicker.gd"))
				"G": _enemy("gangster_bruiser", foot, 1.0, {"patrol_span": 150.0, "walk_speed": 26.0, "flashlight": true, "kind": "dock"})
				"g": _enemy("gangster_slugger", foot, 1.0, {"stationary": true, "look_back": Vector2(6.0, 10.0)})
				"X": _chalk(_props_root, Vector2(x * T, y * T), "X", 90)
				"D": _cellar_don(x, y, foot)
				"E":
					var door := _sprite("cellar_door.png", foot + Vector2(-16, -56), lvl, "CellarDoor")
					door.z_index = -5
					var dg := _glow(foot + Vector2(0, -30), Color(0.5, 0.6, 1.0, 0.5), 1.6)
					dg.name = "CellarDoorGlow"
					dg.visible = false
					_trigger("CellarExit", foot + Vector2(0, -28), Vector2(28, 56))
	# pavučiny v rohoch
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if _mz(x, y) == "." and _mz_solid(x - 1, y) and _mz_solid(x, y - 1) and rng.randf() < 0.5:
				_sprite("cobweb.png", Vector2(x * T, y * T), null, "Cobweb")
	# checkpoint dole v C (pod šachtou z B-vľavo)
	_marker("TunnelSpawn", Vector2(6.5 * T, 26 * T))
	_trigger("TunnelCheckpoint", Vector2(6.5 * T, 24 * T), Vector2(64, 64))
	_trigger("CatacombsTrigger", Vector2(15.5 * T, 23 * T), Vector2(32, 64))   # pred zatopenou kostnicou – Ricco sa zháči
	# nápisy kriedou
	var hints := Node2D.new()
	_node(hints, "Hints", lvl)
	hints.z_index = -4
	_chalk(hints, Vector2(16, 12.2) * T, "TOO LOW? S / CTRL -\nSLIDE UNDER THE ARCH", 81)
	_chalk(hints, Vector2(130, 21) * T, "UP THE SHAFT:\nWALL JUMP, WALL JUMP...", 82)
	_chalk(hints, Vector2(53, 12) * T, "NO WAY THROUGH THE BARS.", 83)
	_chalk(hints, Vector2(19.3, 20.6) * T, "S  -  DIVE\nUNDER WATER\nNOBODY SEES YOU", 84)
	var fh := Node2D.new()
	_node(fh, "FightHints", lvl)
	fh.z_index = -4
	fh.visible = false
	_chalk(fh, Vector2(153.5, 12.2) * T, "LEFT MOUSE  -  SHOOT\nR  -  RELOAD", 41)
	_chalk(fh, Vector2(156, 15.2) * T, "SHIFT  -  SLOW DOWN TIME\n(THE DON'S GHOST)", 42)
	var dark := CanvasModulate.new()
	dark.color = Color(0.46, 0.42, 0.5)
	_node(dark, "Darkness", lvl)
	var ricco: Node2D = load("res://characters/ricco/ricco.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(ricco, "Ricco", lvl)
	ricco.position = Vector2(6.5 * T, 8 * T)
	var hud: Node = load("res://ui/hud.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(hud, "HUD", lvl)
	var scene := PackedScene.new()
	print("pack cellar: ", scene.pack(lvl))
	print("save cellar: ", ResourceSaver.save(scene, "res://levels/level1/cellar.tscn"))
	lvl.free()
	_src = 0


## Hlboká voda (znak %) – stĺpce vody spojí do obdĺžnikov pre WaterZone (world/water/water_zone.gd).
## Hladina (~) je v polovici políčka; pod nízkym stropom (sifón) voda siaha až po strop a hladina nie je.
func _water_zone() -> void:
	var cols: Array = []   # [x, hore px, dole px, má hladinu]
	for x in _maze[0].length():
		var y := 0
		while y < _maze.size():
			if _mz(x, y) in ["~", "%"]:
				var y0 := y
				var deep := false
				while _mz(x, y) in ["~", "%"]:
					deep = deep or _mz(x, y) == "%"
					y += 1
				if deep:
					var open := _mz(x, y0) == "~" or not _mz_solid(x, y0 - 1)
					cols.append([x, y0 * T + (8 if _mz(x, y0) == "~" else 0), y * T, open])
			y += 1
	var zone := Node2D.new()
	zone.set_script(load("res://world/water/water_zone.gd"))
	var rects: Array[Rect2] = []
	var tops: Array[bool] = []
	for c in cols:
		var n := rects.size()
		if n > 0 and rects[n - 1].end.x == c[0] * T and rects[n - 1].position.y == c[1] and rects[n - 1].end.y == c[2] and tops[n - 1] == c[3]:
			rects[n - 1].size.x += T
		else:
			rects.append(Rect2(c[0] * T, c[1], T, c[2] - c[1]))
			tops.append(c[3])
	zone.set("rects", rects)
	zone.set("open_top", tops)
	_node(zone, "Water", lvl)


func _marker(nm: String, pos: Vector2) -> void:
	var m := Marker2D.new()
	_node(m, nm, lvl)
	m.position = pos


## Prvý pevný riadok pod políčkom (px – povrch zeme)
func _floor_below(x: int, y: int) -> float:
	var yy := y
	while yy < _maze.size() and not _mz_solid(x, yy):
		yy += 1
	return yy * T


## Holá žiarovka pod stropom tunela: šnúra, žiarovka, žiara, kužeľ a svetlo (LightZone) až po zem
func _bulb(top: Vector2, floor_y: float) -> void:
	var y := top.y + 18.0
	var cord := Line2D.new()
	cord.points = PackedVector2Array([top, Vector2(top.x, y)])
	cord.width = 1.0
	cord.default_color = Color8(30, 26, 26)
	_node(cord, "Cord", _props_root)
	_sprite("bulb.png", Vector2(top.x - 4, y), null, "Bulb")
	var gl := _glow(Vector2(top.x, y + 6), Color(1.0, 0.85, 0.55, 0.55), 1.6)
	gl.set_script(load("res://world/fx/flicker.gd"))
	var cone := _sprite("light_cone.png", Vector2(top.x - 56, y + 8), null, "Cone")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cone.material = m
	cone.z_index = 4
	cone.scale.y = (floor_y - y - 8.0) / 150.0
	_light(Rect2(top.x - 3 * T, y, 6 * T, floor_y - y))


## Donova skrýša: Don, cutscéna, spúšť pred ním
func _cellar_don(x: int, y: int, foot: Vector2) -> void:
	var top := 0
	var yy := y
	while yy > 0 and not _mz_solid(x, yy - 1):
		yy -= 1
	top = yy
	_build_don(foot, top * T)
	_trigger("DonTrigger", foot + Vector2(-3 * T, -30), Vector2(24, 60))
	for wx in [x - 6, x - 2, x + 2]:   # regály spolu za Donom – nie za policami (tie by cez ne prechádzali)
		_sprite("wine_rack.png", Vector2(wx * T, foot.y - 88), null, "WineRack")
	for b in [[x + 2, 0], [x + 3, 0], [x + 2.5, -1], [x + 10, 0], [x + 11.2, 0]]:
		_sprite("barrel.png", Vector2(b[0] * T, foot.y - 24 + b[1] * 24), null, "Barrel")


# ---------------------------------------------------------------- jedlo a lekárničky (props/food/food_pickup.tscn)

## [x, y, druh] – druh "" = jedlo podľa poradia (Food.next_kind – vždy iné), "medkit" = lekárnička. Za behu spadne na zem.
## Rozmiestnenie: ulica → jedáleň → herňa
const FOOD := [[186 * T, -12.0, ""], [250 * T, -12.0, ""], [288 * T, -12.0, "medkit"]]

func _build_food() -> void:
	for i in FOOD.size():
		var f: Array = FOOD[i]
		var p: Node2D = load("res://props/food/food_pickup.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		_node(p, ("Medkit%d" if f[2] == "medkit" else "Food%d") % (i + 1), lvl)
		p.position = Vector2(f[0], f[1])
		if f[2] != "":
			p.set(&"kind", StringName(f[2]))
