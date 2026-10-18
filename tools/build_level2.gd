extends SceneTree
## Nástroj: vygeneruje levels/level2/level2.tscn (Kapitola II – cintorín, Donov pohreb) a levels/level2/tiles_cemetery.tres.
## Spustenie: godot --headless --path . --script res://tools/build_level2.gd
## Mapa je zadaná v dlaždiciach (16 px). Zem je na y = 0, hore sú záporné riadky. Ide sa zľava doprava:
##   brána → hrobník s lampášom a otvorený hrob (úkryt) → kôlňa s revolverom → mauzóleá (plošiny) →
##   strecha veľkého mauzólea (Ricco s duchom sleduje pohreb) → pohreb pred kostolom (smútiaci, kňaz, mafiáni) →
##   konáre starého duba ponad pohreb → rodinná hrobka → krypta so svetlom vo dverách = cesta ďalej.
## Udalosti (duch, zápalky Pier 13, revolver, koniec) sú v levels/level2/level2.gd.
## Godot docs: classes/class_tilemaplayer, class_tileset, class_parallax2d, class_packedscene, class_cpuparticles2d.

const T := 16
const ART := "res://levels/level2/art/"
const L1 := "res://levels/level1/art/"

# súradnice v atlase tiles_cemetery.png
const GRASS := Vector2i(0, 0)
const DIRT := Vector2i(1, 0)
const DIRT_BG := Vector2i(2, 0)     ## tmavá hlina – zadná stena hrobu (bez kolízie)
const PIT_FLOOR := Vector2i(3, 0)
const WALL := Vector2i(4, 0)
const WALL_CAP := Vector2i(5, 0)
const PATH := Vector2i(6, 0)
const DIRT_VAR := [Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(7, 0), Vector2i(1, 1)]
const BONE := Vector2i(0, 1)        ## hlina s kosťou – len zopár kusov

const END_X := 140                ## pravý koniec levelu (dlaždice)
const PIT := Vector2i(31, 3)      ## otvorený hrob: x 31–33, hĺbka 3 dlaždice (48 px – hrobník Ricca dole nevidí ani nezacíti)
const PED := 36                   ## px – štít mauzólea nad telom (pozri make_art.py)
## Mauzóleá a hrobky: [obrázok, x, šírka, výška (dlaždice), posun obrázka]. Telo = pevná kolízia, strecha = plošina.
const TOMBS := [
	["mausoleum_s.png", 66, 4, 3, Vector2(-6, -PED)],
	["mausoleum_m.png", 73, 5, 4, Vector2(-6, -PED)],
	["mausoleum_l.png", 81, 7, 6, Vector2(-6, -PED)],   # C – vyhliadka na pohreb
	["tomb_low.png", 88, 2, 2, Vector2(-2, -2)],        # schod naspäť na C (z pohrebu)
	["family_tomb.png", 115, 5, 4, Vector2(-6, -20)],   # D – za strážnikom pohrebu
]
const LAMP_L := 97     ## lampy pri pohrebe (dlaždica) – svetlo ±2,5 dlaždice
const LAMP_R := 107
const CRYPT_X := 128   ## krypta (6 dlaždíc) – dvere v strede = východ

var rng := RandomNumberGenerator.new()
var lvl: Node2D
var back: TileMapLayer
var solid: TileMapLayer
var _props_root: Node2D


func _init() -> void:
	rng.seed = 1931
	var ts := _make_tileset()
	ResourceSaver.save(ts, "res://levels/level2/tiles_cemetery.tres")
	ts = load("res://levels/level2/tiles_cemetery.tres")

	lvl = Node2D.new()
	lvl.name = "Level2"
	lvl.set_script(load("res://levels/level2/level2.gd"))

	_sky()
	back = _layer("Back", ts, -10)
	_props_root = _node(Node2D.new(), "Props", lvl)
	_props_root.z_index = -5
	solid = _layer("Solid", ts, 0)

	_build_ground()
	_build_entrance()
	_build_gravedigger()
	_build_mausoleums()
	_build_funeral()
	_build_crypt()
	_fog()

	var ricco: Node2D = load("res://characters/ricco/ricco.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(ricco, "Ricco", lvl)
	ricco.position = Vector2(5 * T, 0)
	var hud: Node = load("res://ui/hud.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_node(hud, "HUD", lvl)

	var scene := PackedScene.new()
	print("pack: ", scene.pack(lvl))
	print("save: ", ResourceSaver.save(scene, "res://levels/level2/level2.tscn"))
	lvl.free()
	quit()


# ---------------------------------------------------------------- pomocné (ako v build_level1.gd)

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
	src.texture = load(ART + "tiles_cemetery.png")
	src.texture_region_size = Vector2i(T, T)
	for y in 2:
		for x in 8:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for c in [GRASS, PIT_FLOOR, WALL, WALL_CAP, PATH] + DIRT_VAR:
		var td := src.get_tile_data(c, 0)
		if td.get_collision_polygons_count(0) > 0:
			continue
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full)
	return ts


func _fill(layer: TileMapLayer, x0: int, y0: int, x1: int, y1: int, tiles) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var t: Vector2i = tiles if tiles is Vector2i else tiles[rng.randi() % tiles.size()]
			layer.set_cell(Vector2i(x, y), 0, t)


func _sprite(tex: String, pos: Vector2, parent: Node = null, nm: String = "") -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(tex if tex.begins_with("res://") else ART + tex)
	s.centered = false
	s.position = pos
	_node(s, nm if nm != "" else tex.get_file().get_basename().to_pascal_case(), parent if parent else _props_root)
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


## Pevné teleso (mauzóleum, múr) – kolízia na vrstve sveta, dá sa na ňom stáť aj chytiť hrany
func _block(nm: String, r: Rect2) -> void:
	var b := StaticBody2D.new()
	_node(b, nm, lvl)
	b.position = r.get_center()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	_node(cs, "Shape", b)


## Jednosmerná plošina (konár) – dá sa na ňu vyskočiť zospodu
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


## Mafián s revolverom (prví strelci v hre) – telo podľa kind, revolver vypadne, keď zomrie
func _gunman(nm: String, pos: Vector2, face: float, props: Dictionary) -> Node2D:
	var p := {"kind": "tommy", "weapon": load("res://weapons/revolver/revolver.tres"), "pellets": 1, "spread_deg": 3.0,
			"bullet_lifetime": 1.4, "preferred_range": 0.0, "cooldown": Vector2(1.0, 1.5), "sight_range": 280.0, "aim_time": 0.75}
	p.merge(props, true)
	return _enemy("gangster_coppola", nm, pos, face, p)


## Smútiaci (world/npc/guest.gd) – ľudia v čiernom; keď zbadajú Ricca na svetle, „!“ a privolajú mafiánov
func _mourner(tex: String, x: float, face: float) -> void:
	var g := Sprite2D.new()
	g.set_script(load("res://world/npc/guest.gd"))
	g.texture = load(ART + "mourners/%s.png" % tex)
	g.hframes = 4
	g.centered = false
	var fw: float = g.texture.get_width() / 4.0
	g.offset = Vector2(-fw / 2.0, -g.texture.get_height())
	g.flip_h = face < 0.0
	g.position = Vector2(x * T, 0)
	g.z_index = -3
	_node(g, "Mourner", lvl)


func _tomb(i: int, x: float, z: int = 0) -> void:
	var tex: Texture2D = load(ART + "tomb_%d.png" % i)
	var s := _sprite("tomb_%d.png" % i, Vector2(x * T, -tex.get_height() + 1), null, "Tomb")
	s.z_index = z


func _chalk(pos: Vector2, text: String, seed_: int) -> void:
	var c := Node2D.new()
	c.set_script(load("res://world/fx/chalk_text.gd"))
	c.set("text", text)
	c.set("seed_value", seed_)
	c.position = pos
	c.rotation = rng.randf_range(-0.035, 0.01)
	c.z_index = -4
	_node(c, "Chalk", lvl)


# ---------------------------------------------------------------- obloha, mesto a hroby v pozadí

func _sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -20
	_node(layer, "Sky", lvl)
	var tr := TextureRect.new()
	tr.texture = load(ART + "sky.png")
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	_node(tr, "Gradient", layer)
	var mg := Sprite2D.new()   # žiara okolo mesiaca
	mg.texture = load(L1 + "glow.png")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mg.material = m
	mg.modulate = Color(0.65, 0.82, 0.82, 0.35)
	mg.scale = Vector2(2.4, 2.4)
	mg.position = Vector2(560, 58)
	_node(mg, "MoonGlow", layer)
	var moon := Sprite2D.new()
	moon.texture = load(L1 + "moon.png")
	moon.scale = Vector2(2, 2)
	moon.position = Vector2(560, 58)
	_node(moon, "Moon", layer)
	# vzdialené mesto a kopec s hrobmi (parallax) – vodorovne pomalšie, zvisle s kamerou
	for spec in [["City", "far_city.png", Vector2(0.2, 1.0), -200.0, -30], ["Graves", "far_graves.png", Vector2(0.5, 1.0), -128.0, -28]]:
		var p := Parallax2D.new()
		p.scroll_scale = spec[2]
		p.repeat_size = Vector2(640, 0)
		p.repeat_times = 4
		p.z_index = spec[4]
		_node(p, "Far" + spec[0], lvl)
		var s := Sprite2D.new()
		s.texture = load(ART + spec[1])
		s.centered = false
		s.position = Vector2(-640, spec[3])
		_node(s, "Sprite", p)
	# veľký gotický kostol za pohrebom (ružicové okno, svetlo v oknách)
	var church := _sprite("cathedral.png", Vector2(103 * T - 150, -24 - 340), lvl, "Cathedral")
	church.z_index = -20
	_glow(Vector2(103 * T, -24 - 340 + 197), Color(0.75, 0.45, 0.6, 0.35), 1.6, church).position = Vector2(150, 197)
	_glow(Vector2.ZERO, Color(1.0, 0.7, 0.35, 0.25), 1.4, church).position = Vector2(150, 300)
	# rad vzdialených hrobov za kovaným plotom (opakovaný pás cez celý level)
	var fence := Sprite2D.new()
	fence.texture = load(ART + "fence_row.png")
	fence.centered = false
	fence.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	fence.region_enabled = true
	fence.region_rect = Rect2(0, 0, (END_X + 4) * T, 56)
	fence.position = Vector2(-2 * T, -54)
	fence.z_index = -12
	_node(fence, "FenceRow", lvl)


# ---------------------------------------------------------------- zem, múry, otvorený hrob

func _build_ground() -> void:
	_fill(solid, -4, 0, END_X + 4, 0, GRASS)
	_fill(solid, -4, 1, END_X + 4, 6, DIRT_VAR)
	for b in [Vector2i(14, 3), Vector2i(47, 2), Vector2i(77, 4), Vector2i(103, 2), Vector2i(126, 3)]:
		solid.set_cell(b, 0, BONE)
	# vyšliapaná cestička od brány k pohrebu
	_fill(solid, 8, 0, 20, 0, PATH)
	# otvorený hrob – jama (zadná stena tmavá hlina bez kolízie), dno je pevné
	for x in range(PIT.x, PIT.x + 3):
		for y in range(0, PIT.y):
			solid.erase_cell(Vector2i(x, y))
			back.set_cell(Vector2i(x, y), 0, DIRT_BG)
		solid.set_cell(Vector2i(x, PIT.y), 0, PIT_FLOOR)
	# múr cintorína na začiatku a na konci + neviditeľná stena až hore (cez múr sa nepreskočí)
	for x0 in [-2, END_X]:
		_fill(solid, x0, -4, x0 + 1, -1, WALL)
		_fill(solid, x0, -5, x0 + 1, -5, WALL_CAP)
		_block("Edge", Rect2(x0 * T, -40 * T, 2 * T, 35 * T))


# ---------------------------------------------------------------- 1. brána

func _build_entrance() -> void:
	_sprite("gate.png", Vector2(10 * T, -112), null, "Gate")   # v rekvizitách za Riccom – prejde ňou
	_trigger("GateBark", Vector2(17 * T, -2 * T), Vector2(16, 4 * T))
	_sprite("dead_tree_0.png", Vector2(3 * T - 81, -237), null, "DeadTree").z_index = -3   # holé stromy (kmeň na dlaždici 3 a 136)
	_sprite("dead_tree_1.png", Vector2(136 * T - 67, -195), null, "DeadTree").z_index = -3
	for t in [[1, 19.0], [0, 21.5], [3, 24.0], [5, 26.5], [6, 36.5], [2, 38.5], [4, 40.0]]:
		_tomb(t[0], t[1])
	_glow(Vector2(4 * T, -20), Color(0.6, 0.8, 0.8, 0.12), 3.0)   # mesačné svetlo na hmle pri štarte


# ---------------------------------------------------------------- 2. hrobník, otvorený hrob, kôlňa s revolverom

func _build_gravedigger() -> void:
	_sprite("mound.png", Vector2(34.2 * T, -33), null, "Mound")
	_chalk(Vector2(25.5, -5.2) * T, "HIDE IN THE OPEN GRAVE", 21)
	# hrobník (robotník s čapicou) – hliadka s lampášom; pri hrobe sa otočí (nevidí dolu do jamy)
	_enemy("gangster_bruiser", "Gravedigger", Vector2(45 * T, 0), -1.0, {"patrol_span": 150.0, "walk_speed": 26.0, "flashlight": true, "kind": "dock", "max_health": 4})
	# kôlňa so svetlom vo dverách a otvorená skrinka – v nej revolver .38 (pridá level2.gd)
	_sprite("shed.png", Vector2(54 * T, -84), null, "Shed").z_index = -1
	_glow(Vector2(54 * T + 69, -84 + 53), Color(1.0, 0.75, 0.4, 0.55), 1.3, null, true)
	_light(Rect2(57.5 * T, -48, 2 * T, 48))
	_sprite("locker.png", Vector2(61 * T, -44), null, "Locker")
	_marker("RevolverSpot", Vector2(61.6 * T, -6))
	_trigger("Checkpoint1", Vector2(63 * T, -2 * T), Vector2(16, 4 * T))
	_marker("Spawn1", Vector2(63.5 * T, 0))
	for t in [[7, 51.0], [3, 63.5]]:
		_tomb(t[0], t[1])


# ---------------------------------------------------------------- 3. mauzóleá (plošiny) a vyhliadka

func _build_mausoleums() -> void:
	for m in TOMBS:
		var x: int = m[1]
		var w: int = m[2]
		var h: int = m[3]
		_sprite(m[0], Vector2(x * T, -h * T) + m[4], null, m[0].get_basename().to_pascal_case())
		_block("Body", Rect2(x * T, -h * T, w * T, h * T))
	for t in [[0, 71.0], [5, 79.2]]:
		_tomb(t[0], t[1])
	# strecha veľkého mauzólea – Ricco s duchom pozerajú na pohreb
	_trigger("FuneralView", Vector2(85 * T, -6 * T - 24), Vector2(6 * T, 40))
	_marker("Spawn2", Vector2(84 * T, -6 * T))


# ---------------------------------------------------------------- 4. pohreb pred kostolom

func _build_funeral() -> void:
	# starý dub: hrubé konáre = cesta horou ponad pohreb (v tme, smútiaci hore nevidia)
	_sprite("oak.png", Vector2(90 * T, -200), null, "Oak").z_index = -2
	_oneway(Vector2(90.5 * T, -112), 8 * T, "BranchL")
	_oneway(Vector2(101 * T, -128), 12 * T, "BranchR")
	# truhla nad hrobom s vencom, sviečky, kopa hliny (z = 0: cez dlaždice zeme – vidno jamu)
	var coffin := Sprite2D.new()
	coffin.texture = load(ART + "coffin.png")
	coffin.centered = false
	coffin.position = Vector2(101 * T, -21)
	_node(coffin, "Coffin", lvl)
	for cx in [99.6, 105.2]:
		_sprite("candles.png", Vector2(cx * T, -12), null, "Candles")
		_glow(Vector2(cx * T + 9, -10), Color(1.0, 0.75, 0.4, 0.4), 0.7, null, true)
	# lampy – svetlo pri smútiacich
	for lx in [LAMP_L, LAMP_R]:
		_sprite("lamp_post.png", Vector2(lx * T - 8, -64), null, "LampPost")
		_glow(Vector2(lx * T, -55), Color(1.0, 0.82, 0.5, 0.6), 2.2)
		_glow(Vector2(lx * T, -6), Color(1.0, 0.75, 0.45, 0.22), 2.0)
		_light(Rect2((lx - 2.5) * T, -72, 5 * T, 72))
	# smútiaci: vľavo otočení k hrobu, vpravo kňaz s knihou a ďalší
	for m in [["man_0", 96.6, 1.0], ["woman_0", 97.8, 1.0], ["man_1", 99.0, 1.0],
			["priest", 106.0, -1.0], ["woman_1", 107.2, -1.0], ["man_2", 108.4, -1.0], ["woman_2", 109.6, -1.0]]:
		_mourner(m[0], m[1], m[2])
	# mafián vzadu za smútiacimi – zapáli si a odhodí zápalky (stopa Pier 13, level2.gd)
	_gunman("Smoker", Vector2(95.5 * T, 0), 1.0, {"stationary": true})
	# strážnik pohrebu s lampášom – pozerá smerom k bráne, občas sa obzrie
	_gunman("FuneralGuard", Vector2(110.5 * T, 0), -1.0, {"stationary": true, "flashlight": true, "look_back": Vector2(4.0, 7.0)})
	_trigger("Checkpoint3", Vector2(121 * T, -2 * T), Vector2(16, 4 * T))
	_marker("Spawn3", Vector2(121.5 * T, 0))


# ---------------------------------------------------------------- 5. krypta = východ

func _build_crypt() -> void:
	var c := _sprite("crypt.png", Vector2(CRYPT_X * T - 6, -5 * T - PED), null, "Crypt")
	c.z_index = -1
	var door := Vector2((CRYPT_X + 3) * T, -24)
	_glow(door, Color(1.0, 0.72, 0.38, 0.7), 1.8, null, true)
	_glow(door + Vector2(0, 22), Color(1.0, 0.72, 0.38, 0.3), 2.6)
	_light(Rect2((CRYPT_X + 1.5) * T, -64, 3 * T, 64))
	_trigger("CryptExit", door, Vector2(20, 48))
	# stráž s palicou pred kryptou – pozerá do svetla vo dverách, občas sa obzrie
	_enemy("gangster_slugger", "CryptGuard", Vector2(125.5 * T, 0), 1.0, {"stationary": true, "look_back": Vector2(5.0, 9.0)})
	for t in [[1, 122.5], [4, 135.0], [2, 137.0]]:
		_tomb(t[0], t[1])


# ---------------------------------------------------------------- hmla pri zemi

func _fog() -> void:
	for spec in [["FogBack", -40.0, -11, 0.05, 20.0], ["FogFront", -6.0, 6, 0.07, 8.0]]:
		var p := CPUParticles2D.new()
		p.texture = load(L1 + "glow.png")
		p.amount = 70
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
		p.scale_amount_max = 2.6
		p.color = Color(0.62, 0.8, 0.8, spec[3])
		p.position = Vector2((END_X - 4) * T / 2.0, spec[1])
		p.z_index = spec[2]
		_node(p, spec[0], lvl)
