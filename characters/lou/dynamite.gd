extends Sprite2D
## Zväzok dynamitu, ktorý hodí Big Lou (characters/lou/big_lou.gd). Letí oblúkom, odrazí sa od steny,
## na zemi sa ešte kúsok kotúľa, šnúra syčí a iskrí – po FUSE sekundách vybuchne:
## výbuch robí effects/explosion.gd (Ricca zraní a odhodí, debny rozbije, sudy odpáli, zatrasie kamerou).
## Kolízie lúčom ako náboj (Godot docs: tutorials/physics/ray-casting).

const GRAVITY := 600.0
const FUSE := 1.6            ## s od hodu po výbuch
const RADIUS := 48.0         ## px – dosah výbuchu
const DAMAGE := 2            ## kúsky pizze
const GLOW := preload("res://levels/level1/art/glow.png")

var velocity: Vector2 = Vector2.ZERO
var roll_to: float = NAN    ## px – po dopade sa skotúľa k tomuto x (Ricco sa skrýva pod krídlom mostíka)
var fuse: float = FUSE      ## s – dá sa skrátiť (trojitý hod vo fáze 3)
var size: float = 1.0       ## veľkosť výbuchu (effects/explosion.gd)
var damage: int = DAMAGE    ## kúsky pizze, o ktoré Ricco príde (0 = len efekt)
var boss_damage: float = 0.0  ## HP bossa pri výbuchu (0 = Lou vlastný dynamit nezraní)
var _t: float = 0.0
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
		_landed = true
		velocity.y = 0.0
	else:            # stena – odrazí sa
		velocity = velocity.bounce(n) * 0.4


func _explode() -> void:
	if _hiss and is_instance_valid(_hiss):
		_hiss.queue_free()
	Explosion.spawn(get_parent(), global_position, size, damage, boss_damage, RADIUS)
	queue_free()
