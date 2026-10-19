extends Node2D
## Otáčajúci sa lúč majáka (prístav). Uzol určuje, kam škvrna dopadá (x = stred dráhy škvrny); kužeľ sa kreslí
## od lampy `source` (maják v diaľke na Parallax2D – jeho global_position už obsahuje posun), inak od uzla. Lúč sa točí dookola – zboku ho vidno ako kužeľ,
## ktorého svetelná škvrna prejde po móloch zďaleka až k majáku, na chvíľu zmizne (svieti na nás / od nás) a ide na druhú stranu.
## V škvrne je LightZone (world/stealth/light_zone.gd) – kto v nej stojí alebo pláva na hladine, toho mafiáni vidia.
## Pod hladinou (Ricco.submerged) ho nevidno ani v lúči.
## Godot docs: classes/class_polygon2d, classes/class_area2d, classes/class_canvasitemmaterial, classes/class_parallax2d

@export var reach: float = 620.0         ## px vodorovne – najďalej, kam škvrna dopadne
@export var ground_y: float = -16.0      ## globálne y, kde škvrna dopadá (paluba mól)
@export var period: float = 18.0         ## s na jednu otáčku
@export var phase: float = 0.0           ## rad – začiatočný uhol
@export var zone_up: float = 80.0        ## px – svetlo nad škvrnou (postava na palube)
@export var zone_down: float = 40.0      ## px – pod škvrnou (Ricco na hladine pod mólom)
@export var source: NodePath             ## lampa, od ktorej sa kreslí kužeľ (prázdne = od tohto uzla)
@export var source_scale: float = 1.0    ## veľkosť záblesku a hrúbka kužeľa pri lampe (vzdialený maják = menší)

const GLOW := preload("res://levels/level1/art/glow.png")

var angle: float = 0.0
var _beam: Polygon2D
var _flare: Sprite2D
var _spot: Sprite2D
var _zone: Area2D
var _shape: RectangleShape2D
var _src: Node2D


func _ready() -> void:
	angle = phase
	if not source.is_empty():
		_src = get_node_or_null(source) as Node2D
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam = Polygon2D.new()
	_beam.material = add
	_beam.z_index = 5
	add_child(_beam)
	_flare = _glow(Color(1.0, 0.92, 0.65, 0.8), 1.0)
	_spot = _glow(Color(1.0, 0.9, 0.6, 0.45), 1.0)
	_spot.top_level = true
	_zone = Area2D.new()
	_zone.set_script(preload("res://world/stealth/light_zone.gd"))
	_zone.top_level = true
	var cs := CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_shape.size = Vector2(60, zone_up + zone_down)
	cs.shape = _shape
	_zone.add_child(cs)
	add_child(_zone)
	_update()


func _glow(col: Color, s: float) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = GLOW
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.modulate = col
	g.scale = Vector2(s, s)
	g.z_index = 6
	add_child(g)
	return g


func _physics_process(delta: float) -> void:
	angle = wrapf(angle + TAU / period * delta, 0.0, TAU)
	_update()


## cos(uhol) = ako veľmi lúč mieri do strany (−1 vľavo … 1 vpravo), sin(uhol) > 0 = mieri k nám
func _update() -> void:
	var side: float = cos(angle)
	var toward: float = sin(angle)
	var spot_x: float = global_position.x + reach * side
	var w: float = 50.0 + 90.0 * absf(side)                  # škvrna je ďalej širšia
	var tip := Vector2(spot_x, ground_y) - global_position
	var o := Vector2.ZERO                                     # lampa (v súradniciach tohto uzla)
	if _src != null:
		o = _src.global_position - global_position
	var hw: float = 3.0 * source_scale
	var a_tip: float = clampf(absf(side) * 1.6, 0.0, 1.0)      # kolmo na nás / od nás je kužeľ skrátený a slabší
	_beam.polygon = PackedVector2Array([o + Vector2(0, -hw), o + Vector2(0, hw), tip + Vector2(w * 0.5, 4), tip + Vector2(-w * 0.5, 4)])
	_beam.vertex_colors = PackedColorArray([Color(1.0, 0.9, 0.6, 0.38 * a_tip), Color(1.0, 0.9, 0.6, 0.38 * a_tip),
			Color(1.0, 0.85, 0.5, 0.16 * a_tip), Color(1.0, 0.85, 0.5, 0.16 * a_tip)])
	# záblesk lampy, keď lúč mieri k nám
	var f: float = maxf(toward, 0.0) * (1.0 - absf(side))
	_flare.position = o
	_flare.scale = Vector2.ONE * (0.5 + 1.8 * f) * source_scale
	_flare.modulate.a = 0.45 + 0.5 * f
	_spot.global_position = Vector2(spot_x, ground_y - 4.0)
	_spot.scale = Vector2(w / 60.0, 0.45)
	_spot.modulate.a = 0.5 * a_tip
	_shape.size = Vector2(w, zone_up + zone_down)
	_zone.global_position = Vector2(spot_x, ground_y + (zone_down - zone_up) * 0.5)
	# keď lúč mieri skoro kolmo na nás / od nás, na móla nedopadá – zónu odsunie preč (body_exited príde samo)
	if absf(side) < 0.12:
		_zone.global_position.y += 100000.0
