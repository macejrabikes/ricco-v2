extends Sprite2D
## Zväzok dynamitu, ktorý hodí Big Lou (characters/lou/big_lou.gd). Letí oblúkom, odrazí sa od steny,
## na zemi sa ešte kúsok kotúľa, šnúra syčí a iskrí – po FUSE sekundách vybuchne:
## výbuch robí effects/explosion.gd (Ricca zraní a odhodí, debny rozbije, sudy odpáli, zatrasie kamerou).
## Hodiť späť: keď dynamit leží na zemi a Ricco je pri ňom, nad ním svieti „F – THROW“ (world/fx/interact_spot.gd).
## Ricco ho chytí a hodí oblúkom späť na Lou (throw_back) – na krídle mostíka to krídlo poškodí (big_lou.gd → dynamite_hit),
## na palube zasiahne Lou (boss_damage). Kolízie lúčom ako náboj (Godot docs: tutorials/physics/ray-casting).

const GRAVITY := 600.0
const FUSE := 1.6            ## s od hodu po výbuch
const RADIUS := 48.0         ## px – dosah výbuchu
const DAMAGE := 2            ## kúsky pizze
const BACK_DAMAGE := 4.0     ## HP bossa, keď mu Ricco dynamit hodí späť
const GLOW := preload("res://levels/level1/art/glow.png")

var velocity: Vector2 = Vector2.ZERO
var roll_to: float = NAN    ## px – po dopade sa skotúľa k tomuto x (Ricco sa skrýva pod krídlom mostíka)
var fuse: float = FUSE      ## s – dá sa skrátiť (trojitý hod vo fáze 3)
var size: float = 1.0       ## veľkosť výbuchu (effects/explosion.gd)
var damage: int = DAMAGE    ## kúsky pizze, o ktoré Ricco príde (0 = len efekt)
var boss_damage: float = 0.0  ## HP bossa pri výbuchu (0 = Lou vlastný dynamit nezraní)
var returnable: bool = false  ## dá sa hodiť späť (Louove dynamity v boji)
var thrower: Node2D           ## kto ho hodil (Lou) – naňho letí späť
var _t: float = 0.0
var _back: bool = false       ## letí späť na Lou
var _back_to: Vector2
var _spot: InteractSpot
var _landed: bool = false
var _spark: Sprite2D
var _hiss: Node


func _ready() -> void:
	texture = preload("res://characters/lou/dynamite.png")
	z_index = 6
	_spark = Sprite2D.new()
	_spark.texture = GLOW
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_spark.material = m
	_spark.modulate = Color(1.0, 0.7, 0.3, 0.9)
	_spark.scale = Vector2(0.12, 0.12)
	_spark.position = Vector2(3, -7)
	add_child(_spark)
	_hiss = Sfx.play(&"fuse", global_position, -8.0, 0.05)


func _physics_process(delta: float) -> void:
	_t += delta
	_spark.scale = Vector2.ONE * (0.1 + 0.06 * absf(sin(_t * 30.0)))
	if randf() < 0.5:
		Burst.spawn(get_parent(), global_position + _spark.position.rotated(rotation), Vector2(0, -1),
				Color(1.0, 0.8, 0.4), 1, 30.0, Vector2(0, 60), 0.2)
	if _hiss and is_instance_valid(_hiss):
		_hiss.set(&"position", global_position)
	if _t >= fuse:
		_explode()
		return
	if _spot:
		_spot.global_position = global_position
	if _back:
		_fly_back(delta)
		return
	if _landed and not is_nan(roll_to):
		velocity.x = move_toward(velocity.x, clampf(roll_to - global_position.x, -70.0, 70.0), 300.0 * delta)
	elif _landed:
		velocity.x = move_toward(velocity.x, 0.0, 260.0 * delta)
	if _landed and absf(velocity.x) < 2.0:
		return
	velocity.y += GRAVITY * delta
	rotation += velocity.x * delta * 0.08
	var to: Vector2 = global_position + velocity * delta
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, to + Vector2(0, 5), 1))
	if hit.is_empty():
		global_position = to
		return
	var n: Vector2 = hit.normal
	global_position = hit.position + n * 5.0
	if n.y < -0.6:   # zem / debna – dopadne a kotúľa sa
		if not _landed:
			Sfx.play(&"knock_wood", global_position, -8.0, 0.2)
			velocity.x *= 0.45
			if returnable and thrower and is_instance_valid(thrower):
				_make_spot()
		_landed = true
		velocity.y = 0.0
	else:            # stena – odrazí sa
		velocity = velocity.bounce(n) * 0.4


## Nápoveda „F – THROW“ nad ležiacim dynamitom (oblasť sa netočí s ním – top_level)
func _make_spot() -> void:
	_spot = InteractSpot.new()
	_spot.verb = "THROW"
	_spot.hint_offset = Vector2(0, -26)
	_spot.top_level = true
	add_child(_spot)
	_spot.global_position = global_position
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(44, 34)
	cs.shape = r
	cs.position = Vector2(0, -12)
	_spot.add_child(cs)
	_spot.used.connect(throw_back)


## Ricco ho zdvihne a hodí oblúkom späť na Lou – šnúra horí ďalej, vybuchne pri ňom
func throw_back() -> void:
	if _back or thrower == null or not is_instance_valid(thrower):
		return
	_back = true
	if _spot:
		_spot.queue_free()
		_spot = null
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	if p:
		global_position = p.global_position + Vector2(0, -30)
		if p.has_method(&"throw_pose"):
			p.throw_pose()
	Sfx.play(&"punch_swing", global_position, -2.0, 0.1)
	_back_to = thrower.call(&"dynamite_target") if thrower.has_method(&"dynamite_target") else thrower.global_position + Vector2(0, -40)
	var d: Vector2 = _back_to - global_position
	var t: float = clampf(d.length() / 300.0, 0.55, 1.0)
	velocity = Vector2(d.x / t, d.y / t - 0.5 * GRAVITY * t)
	fuse = _t + t + 0.25   # keby ho minul, vybuchne kúsok za ním
	_landed = false
	damage = 1             # pri Riccovi už nevybuchne – ale keby áno, menej to bolí
	boss_damage = BACK_DAMAGE
	size = 1.2


## Let späť: bez kolízií (ponad zábradlie a krídlo), vybuchne pri Lou
func _fly_back(delta: float) -> void:
	velocity.y += GRAVITY * delta
	rotation += 14.0 * delta
	global_position += velocity * delta
	if thrower and is_instance_valid(thrower) and thrower.has_method(&"dynamite_target"):
		_back_to = thrower.call(&"dynamite_target")
	if global_position.distance_to(_back_to) < 18.0 or (velocity.y > 0.0 and global_position.y > _back_to.y + 6.0):
		_explode()


func _explode() -> void:
	if _hiss and is_instance_valid(_hiss):
		_hiss.queue_free()
	Explosion.spawn(get_parent(), global_position, size, damage, boss_damage, RADIUS)
	if _back and thrower and is_instance_valid(thrower) and thrower.has_method(&"dynamite_hit"):
		thrower.dynamite_hit(global_position)
	queue_free()
