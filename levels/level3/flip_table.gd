extends Node2D
## Stôl, ktorý sa dá prevrátiť na bok (kapitola III – klub The Blue Canary): pokrový stôl v herni prevráti Ricco (F),
## písací stôl v kancelárii prevráti Sal, keď sa pri poplachu zamkne (club_back.gd). Doska postavená na bok je vysoký
## kryt (vrstva 6 – zastaví guľky aj pohľad) a zároveň pevná prekážka (vrstva 1 – Ricco ani mafiáni cez ňu neprejdú,
## dá sa na ňu vyskočiť). Karty, žetóny a papiere sa rozletia, hluk počuje celá miestnosť.
## Stôl sa prevráti od toho, kto ho prevracia – Ricco (Spot) ho zhodí od seba, Sal (flip() z kódu) smerom k Riccovi,
## aby sa skryl za dosku; flip_dir smer určí napevno. Nakloní sa okolo nohy na strane pádu,
## dopadne doskou na tú stranu (obrázok prevráteného stola sa podľa smeru zrkadlí), pruží a zvíri prach.
## Poloha uzla = stred stola na podlahe. Deti: Sprite (stôl), Cover (StaticBody2D, vrstva 6 – Shape vypnutý, kým stôl
## stojí), voliteľne Spot (InteractSpot – nápoveda „F – FLIP“).
## Godot docs: classes/class_collisionshape2d (set_deferred disabled), classes/class_tween, classes/class_node (reparent)

signal flipped

@export var flipped_texture: Texture2D
@export var flipped_offset: Vector2 = Vector2(-47, -46)   ## poloha obrázka prevráteného stola voči uzlu (pred posunom tip_shift)
@export var noise_radius: float = 300.0
@export var flip_dir: float = 0.0     ## kam padne doska: -1 doľava, 1 doprava, 0 = podľa toho, kto prevracia (Ricco / niekto iný)
@export var tip_shift: float = 26.0   ## px – o koľko sa prevrátený stôl posunie na stranu pádu (doska skončí pri kraji stola)
@export var wall_px: float = 46.0     ## stĺpec dosky v obrázku prevráteného stola (x) – tam bude pevná stena
@export var solid: bool = true        ## prevrátený stôl je aj pevná prekážka (vrstva 1), nielen kryt

const WORLD_LAYER := 1
const TIP_TIME := 0.16     ## s – naklonenie okolo nohy
const TIP_ANGLE := 0.6     ## rad – kam sa nakloní, kým sa obrázok vymení za prevrátený

var is_flipped: bool = false
var _pivot: Node2D         ## okolo neho sa stôl nakláňa a pruží (sprite je jeho dieťa)


func _ready() -> void:
	var spot := get_node_or_null(^"Spot") as InteractSpot
	if spot:
		spot.used.connect(flip.bind(false, true))
	var s := get_node_or_null(^"Sprite") as Sprite2D
	if s:
		_pivot = Node2D.new()
		_pivot.name = &"Pivot"
		add_child(_pivot)
		move_child(_pivot, s.get_index())
		s.reparent(_pivot)   # pivot je v počiatku – sprite ostane, kde bol


## quiet = bez zvuku, hluku a animácie (stôl už je prevrátený, keď sa scéna načíta – kancelária zamknutá od začiatku);
## by_player = prevracia Ricco (doska padne od neho), inak niekto, kto sa pred Riccom kryje (doska padne k nemu)
func flip(quiet: bool = false, by_player: bool = false) -> void:
	if is_flipped:
		return
	is_flipped = true
	var spot := get_node_or_null(^"Spot")
	if spot:
		spot.queue_free()
	var dir: float = _fall_dir(by_player)
	var s := _sprite()
	if quiet or s == null or _pivot == null:
		_land(dir, true)
		return
	# 1. naklonenie okolo nohy na strane pádu; karty a žetóny sa zošmyknú
	var half: float = s.texture.get_width() / 2.0 if s.texture else 40.0
	_pivot.position = Vector2(dir * half, 0.0)
	s.position -= _pivot.position
	Sfx.play(&"plank_creak", global_position + Vector2(0, -20), -6.0, 0.1)
	Burst.spawn(get_parent(), global_position + Vector2(0, -32), Vector2(dir, -1.4).normalized(), Color(0.95, 0.92, 0.85), 12, 140.0, Vector2(0, 400), 0.8)
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation", dir * TIP_ANGLE, TIP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_land.bind(dir, false))


## 2. dopad: obrázok prevráteného stola (zrkadlený podľa smeru), pruženie, prach, rana a zapnutý kryt aj stena
func _land(dir: float, quiet: bool) -> void:
	var s := _sprite()
	if s and flipped_texture:
		if _pivot:
			_pivot.rotation = 0.0
			_pivot.position = Vector2.ZERO
		s.texture = flipped_texture
		var x: float = flipped_offset.x - tip_shift          # padá doľava = obrázok, ako je
		if dir > 0.0:                                          # doprava = zrkadlovo
			x = -(flipped_offset.x + flipped_texture.get_width()) + tip_shift
		s.flip_h = dir > 0.0
		s.position = Vector2(x, flipped_offset.y)
	var cs := get_node_or_null(^"Cover/Shape") as CollisionShape2D
	if cs:
		var wall: float = flipped_offset.x - tip_shift + wall_px + 0.5
		cs.position.x = wall if dir < 0.0 else -wall
		cs.set_deferred(&"disabled", false)
	var cover := get_node_or_null(^"Cover") as StaticBody2D
	if cover and solid:
		cover.collision_layer |= WORLD_LAYER
	if quiet:
		return
	if _pivot:   # pruženie – doska dopadne, stlačí sa a narovná (okolo spodku stola)
		_pivot.scale = Vector2(1.12, 0.82)
		var tw := create_tween()
		tw.tween_property(_pivot, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"crate_break", global_position + Vector2(0, -20), -4.0, 0.1)
	Sfx.play(&"body_thud", global_position, -6.0, 0.1)
	var at: Vector2 = global_position + Vector2((cs.position.x if cs else 0.0), -2.0)
	Burst.spawn(get_parent(), at + Vector2(-8, 0), Vector2(-1, -0.3).normalized(), Color(0.55, 0.5, 0.45, 0.6), 8, 70.0, Vector2(0, 60), 0.6)
	Burst.spawn(get_parent(), at + Vector2(8, 0), Vector2(1, -0.3).normalized(), Color(0.55, 0.5, 0.45, 0.6), 8, 70.0, Vector2(0, 60), 0.6)
	Gangster.noise(global_position, noise_radius)
	flipped.emit()


func _sprite() -> Sprite2D:
	if _pivot:
		return _pivot.get_node_or_null(^"Sprite") as Sprite2D
	return get_node_or_null(^"Sprite") as Sprite2D


## Kam padne doska: flip_dir, inak od Ricca (prevracia on – ostane za stolom) alebo k Riccovi (kryje sa pred ním niekto iný)
func _fall_dir(by_player: bool) -> float:
	if flip_dir != 0.0:
		return signf(flip_dir)
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	if p and absf(p.global_position.x - global_position.x) > 0.5:
		var away: float = signf(global_position.x - p.global_position.x)
		return away if by_player else -away
	return -1.0
