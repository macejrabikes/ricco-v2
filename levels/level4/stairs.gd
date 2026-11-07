extends StaticBody2D
## Schodisko vo vile (kapitola IV, časť 5 – átrium): šikmý pás 45° (CollisionPolygon2D vyrobí _ready), ktorý drží
## len Ricca, a to len keď je nad ním. Schody sú „v pozadí“ – popod ne sa po poschodí normálne prechádza.
## Na schody sa naskočí (skok pri spodku – pri dopade je Ricco nad pásom), zhora z ochodze sa na ne vojde samo.
## Kolízia je na vlastnej vrstve (layer_bit): Riccova maska ten bit zapne, len kým je nad pásom (alebo na ňom stojí),
## inak ho vypne – nepriatelia ani guľky schody nevidia (masku 1 majú bez týchto bitov).
## Každé rameno má svoj bit, aby sa ramená nad sebou (cik-cak) navzájom nepletli.
## Godot docs: classes/class_collisionpolygon2d, classes/class_collisionobject2d (set_collision_mask_value)

@export var foot: Vector2           ## spodok ramena (globálne, na podlahe)
@export var top: Vector2            ## vrch ramena (globálne, na podlahe vyššieho poschodia)
@export_range(2, 32) var layer_bit: int = 11
@export var thickness: float = 12.0

const HOLD_MARGIN := 10.0           ## px – na schodoch ostane, kým je nohami najviac toľkoto pod hranou (zostup, snap)
const ENTER_MARGIN := 2.0           ## px – nastúpi, keď je nohami nad hranou (dopad zo skoku, vstup zhora)
const FOOT_ZONE := 12.0             ## px – pri samom spodku sa nenastupuje chôdzou (prejde sa popri)

var player: CharacterBody2D
var _on: bool = false


func _ready() -> void:
	collision_layer = 0
	set_collision_layer_value(layer_bit, true)
	collision_mask = 0
	var dir: float = signf(top.x - foot.x)
	var cp := CollisionPolygon2D.new()
	cp.polygon = PackedVector2Array([foot - global_position, top - global_position,
		top - global_position + Vector2(0, thickness), foot - global_position + Vector2(dir * thickness, 0)])
	add_child(cp)


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
		if player == null:
			return
		player.set_collision_mask_value(layer_bit, false)
	var want: bool = _wants(player.global_position)
	if want != _on:
		_on = want
		player.set_collision_mask_value(layer_bit, want)


## Má byť Ricco na tomto ramene? (nohy = global_position hráča)
func _wants(p: Vector2) -> bool:
	if int(player.get(&"state")) == 3:   # mŕtvy
		return false
	var t: float = inverse_lerp(foot.x, top.x, p.x)
	if t < -0.03 or t > 1.03:
		return false
	var line_y: float = lerpf(foot.y, top.y, clampf(t, 0.0, 1.0))
	if _on:
		return p.y <= line_y + HOLD_MARGIN
	if line_y > foot.y - FOOT_ZONE:          # pri spodku – chôdzou po podlahe sa nenastupuje
		return false
	return p.y <= line_y + ENTER_MARGIN and player.velocity.y >= 0.0
