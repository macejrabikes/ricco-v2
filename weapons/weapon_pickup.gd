extends Area2D
## Zbraň na zemi – vypadne gangstrovi z ruky, keď zomrie. Odletí, raz odskočí a ostane ležať.
## Keď cez ňu Ricco prejde, zoberie ju sám (má voľné miesto vo výbave → hneď ju vezme do ruky,
## alebo takú už má → vyberie z nej náboje). Keď je miesto plné, ukáže sa „F“ a F ju vymení:
## Ricco vezme túto a jeho stará zbraň ostane ležať namiesto nej.
## Bez zbrane (prológ, Ricco ešte nemá ducha Dona) ostane ležať.
## Godot docs: classes/class_area2d – body_entered, get_overlapping_bodies

var weapon: WeaponData
var ammo: int = 0                 ## koľko nábojov v nej ostalo (gangster = jeden zásobník)
var texture: Texture2D            ## obrázok na zemi (inak weapon.texture)
var velocity: Vector2 = Vector2.ZERO
var spin: float = 0.0

const PICKUP_DELAY := 0.35        ## s – kým sa dá zobrať (aby bolo vidno, ako vyletí z ruky)
const TAKE := 1                   ## Ricco.Pickup.TAKE
const SWAP := 2                   ## Ricco.Pickup.SWAP

var _t: float = 0.0
var _bounces: int = 0
var _sprite: Sprite2D
var _hint: Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2     # Ricco
	_sprite = Sprite2D.new()
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24.0, 14.0)
	shape.shape = rect
	add_child(shape)
	_hint = Label.new()   # rovnaký štýl ako nápoveda zneškodnenia nad gangstrom
	_hint.text = KeyBindings.short(&"takedown")
	_hint.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
	_hint.add_theme_font_size_override(&"font_size", 8)
	_hint.add_theme_color_override(&"font_color", Color8(255, 214, 90))
	_hint.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	_hint.add_theme_constant_override(&"outline_size", 4)
	_hint.z_index = 40
	_hint.visible = false
	add_child(_hint)
	_set_weapon(weapon, ammo, texture)
	add_to_group(&"weapon_pickups")
	body_entered.connect(_try_pickup)


func _set_weapon(w: WeaponData, a: int, tex: Texture2D = null) -> void:
	weapon = w
	ammo = a
	_sprite.texture = tex if tex else w.texture


func _physics_process(delta: float) -> void:
	_t += delta
	_update_swap()
	if _t >= PICKUP_DELAY and _t - delta < PICKUP_DELAY:
		for b in get_overlapping_bodies():   # Ricco už môže stáť na mieste, kam padla
			_try_pickup(b)
	if _bounces >= 2:
		_sprite.position.y = -2.0 + roundf(sin(_t * 4.0) * 1.0)   # pohupkáva sa ako krabička nábojov
		return
	velocity.y += 900.0 * delta
	_sprite.rotation += spin * delta
	var to: Vector2 = global_position + velocity * delta
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, to + Vector2(0, 5), 1))
	if hit.is_empty():
		global_position = to
		return
	global_position = hit.position - Vector2(0, 5)
	_bounces += 1
	if _bounces == 1:
		Sfx.play(&"mag_drop", global_position, -6.0, 0.15)
	_sprite.flip_h = velocity.x < 0.0
	velocity = Vector2(velocity.x * 0.4, -velocity.y * 0.3)
	spin *= 0.3
	if _bounces >= 2:
		_sprite.rotation = 0.0   # leží na zemi hlavňou do strany


func _try_pickup(body: Node) -> void:
	if _t < PICKUP_DELAY or not body.has_method("pick_up_weapon"):
		return
	if body.pick_up_weapon(weapon, ammo):
		Burst.spawn(get_parent(), global_position, Vector2.UP, Color(0.84, 0.67, 0.28), 6, 50.0, Vector2(0, 100), 0.3)
		queue_free()


## Plná výbava: kým Ricco stojí na zbrani, svieti „F“; F = výmena (zneškodnenie gangstra má prednosť).
func _update_swap() -> void:
	var player: Node = null
	if _t >= PICKUP_DELAY:
		for b in get_overlapping_bodies():
			if b.has_method("swap_weapon") and b.pickup_mode(weapon) == SWAP and b.takedown_target == null and _nearest_to(b):
				player = b
	_hint.visible = player != null
	if player == null:
		return
	_hint.position = Vector2(-_hint.size.x / 2.0, -22.0 + sin(_t * 8.0) * 1.5)
	if not Input.is_action_just_pressed(&"takedown"):
		return
	var old: Array = player.swap_weapon(weapon, ammo)
	if old.is_empty():
		return
	_set_weapon(old[0], old[1])
	_sprite.flip_h = player.global_position.x > global_position.x
	Burst.spawn(get_parent(), global_position, Vector2.UP, Color(0.84, 0.67, 0.28), 6, 50.0, Vector2(0, 100), 0.3)


## Leží viac zbraní na sebe? „F“ ukáže a vymení len tá najbližšia k Riccovi.
func _nearest_to(player: Node2D) -> bool:
	var d: float = global_position.distance_to(player.global_position)
	for p in get_tree().get_nodes_in_group(&"weapon_pickups"):
		if p != self and p.overlaps_body(player) and p.global_position.distance_to(player.global_position) < d:
			return false
	return true
