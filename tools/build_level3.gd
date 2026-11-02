extends SceneTree
## Nástroj: vygeneruje levels/level3/intro.tscn (úvod kapitoly III – čln popri Soche slobody).
## Spustenie: godot --headless --path . --script res://tools/build_level3.gd
## Nábrežie a ulica sú jedna mapa levels/level3/street.tscn – tú píše Claude priamo (_art_src/make_city_scene.py mimo repa),
## tento nástroj ju už negeneruje.
## Udalosti úvodu sú v levels/level3/intro.gd.
## Godot docs: classes/class_packedscene, classes/class_sprite2d

const INTRO_ART := "res://levels/level3/art/intro/"
const L1 := "res://levels/level1/art/"
const L2 := "res://levels/level2/art/"

var lvl: Node2D


func _init() -> void:
	_build_intro()
	quit()


# ---------------------------------------------------------------- pomocné

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
	s.texture = load(tex)
	s.centered = false
	s.position = pos
	_node(s, nm if nm != "" else tex.get_file().get_basename().to_pascal_case(), parent if parent else lvl)
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
