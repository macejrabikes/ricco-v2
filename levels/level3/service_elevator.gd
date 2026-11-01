extends AnimatableBody2D
## Nákladný výťah v hoteli Majestic (kapitola III – servisné krídlo, hotel.gd). Kabína je pohyblivá plošina:
## Ricco aj mafiáni sa v nej (aj na jej streche) vezú sami – CharacterBody2D na AnimatableBody2D (sync_to_physics).
##   • Kým žije liftboy (operator), výťah jazdí sám po rozpise: zastávky dole → hore → dole, na každej chvíľu stojí
##     s otvorenými dverami. Keď si liftboy Ricca všimne (stav AIM … RECOVER), kabína čaká, kým sa nevybaví.
##   • Keď liftboy padne, výťah poslúcha Ricca: v kabíne panel (F – UP / DOWN), pri dverách na poschodí privolávač
##     (F – CALL). Zastávky v locked_stops (gala) chcú služobný kľúč (has_key nastaví hotel.gd), inak signál locked.
##   • Na streche kabíny je poklop (F – DROP IN): Ricco vkĺzne dnu za chrbát liftboya (tiché zneškodnenie).
##   • Protiváha (counterweight) beží v šachte opačne. Na vrch sa dá postaviť, ale keď sa hýbe a Ricca zasiahne
##     (rebrík v šachte), uberie mu zdravie a zhodí ho z rebríka.
## Šachtové dvere (doors – lift_door.gd) sa otvárajú len na zastávke, kde kabína práve stojí.
## Poloha uzla = stred podlahy kabíny. Deti: tvary Floor, Side, Roof (jednosmerný), Cable (Line2D), Gate (Sprite2D,
## 2 snímky – mriežka otvorená / zatvorená), Panel a Hatch (InteractSpot).
## Godot docs: classes/class_animatablebody2d, tutorials/physics/using_character_body_2d (pohyblivé plošiny)

signal arrived(stop: int)
signal locked(stop: int)

@export var stops: PackedFloat32Array = PackedFloat32Array([0.0])   ## globálne y podlahy kabíny na zastávkach (zdola nahor)
@export var start_stop: int = 0
@export var speed: float = 70.0                  ## px/s
@export var wait_time: float = 5.0               ## s – ako dlho stojí na zastávke (jazda po rozpise)
@export var doors: Array[NodePath] = []          ## šachtové dvere ku každej zastávke (lift_door.gd)
@export var calls: Array[NodePath] = []          ## privolávače pri dverách (InteractSpot) ku každej zastávke
@export var operator: NodePath                   ## liftboy (Gangster) – kým žije, výťah jazdí sám
@export var locked_stops: PackedInt32Array = PackedInt32Array()   ## zastávky len s kľúčom
@export var counterweight: NodePath              ## protiváha (AnimatableBody2D, počiatok = stred spodku)
@export var cw_top: float = 0.0                  ## globálne y spodku protiváhy, keď kabína stojí na zastávke 0
@export var winch_y: float = 0.0                 ## globálne y kladky v strojovni (odtiaľ idú laná)
@export var wheel: NodePath                      ## koleso navijaka v strojovni (točí sa pri jazde)
@export var door_zone: float = 22.0              ## px od hrany kabíny – kto tu stojí, kvôli tomu sa dvere nezavrú

const AWARE_FROM := 2   ## Gangster.State.AIM
const AWARE_TO := 8     ## Gangster.State.RECOVER
const CW_HURT := 2
const DOOR_X := 32.0    ## px od stredu kabíny k dverám (kabína je široká 64)

var has_key: bool = false
var stop_i: int = 0                 ## zastávka, na ktorej stojí (alebo z ktorej ide)
var _target: int = -1               ## kam ide (−1 = stojí)
var _dir: int = 1                   ## smer rozpisu (+1 hore = vyšší index)
var _wait: float = 0.0
var _motor: Node
var _cw: Node2D
var _cw_hurt: Area2D
var _cable: Line2D
var _cw_cable: Line2D
var _wheel: Node2D
var _player: Node2D
var _op: Gangster
var _panel: InteractSpot
var _hatch: InteractSpot


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	stop_i = clampi(start_stop, 0, stops.size() - 1)
	global_position.y = stops[stop_i]
	_cw = get_node_or_null(counterweight) as Node2D
	if _cw:
		_cw_hurt = _cw.get_node_or_null(^"Hurt") as Area2D
		_cw_cable = _cw.get_node_or_null(^"Cable") as Line2D
	_cable = get_node_or_null(^"Cable") as Line2D
	_wheel = get_node_or_null(wheel) as Node2D
	_op = get_node_or_null(operator) as Gangster
	_panel = get_node_or_null(^"Panel") as InteractSpot
	if _panel:
		_panel.once = false
		_panel.used.connect(_on_panel)
	_hatch = get_node_or_null(^"Hatch") as InteractSpot
	if _hatch:
		_hatch.once = false
		_hatch.used.connect(_on_hatch)
	for i in calls.size():
		var c := get_node_or_null(calls[i]) as InteractSpot
		if c:
			var n: int = i
			c.once = false
			c.used.connect(func(): call_to(n))
	_wait = wait_time
	_set_doors()
	_place_cw()
	_update_cables()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if _target >= 0:
		var ty: float = stops[_target]
		var dy: float = ty - global_position.y
		var step: float = speed * delta
		if absf(dy) <= step:
			global_position.y = ty
			_arrive()
		else:
			global_position.y += signf(dy) * step
		if _wheel:
			_wheel.rotation += signf(dy) * speed * delta / 8.0
	elif _auto():
		if not _op_busy():
			_wait -= delta
		if _wait <= 0.0:
			var next: int = stop_i + _dir
			if next < 0 or next >= stops.size():
				_dir = -_dir
				next = stop_i + _dir
			if not _go(next):
				_wait = 0.5   # niekto stojí vo dverách – skúsi o chvíľu
	_place_cw()
	_update_cables()
	_update_spots()
	_check_cw_hit()


## Jazdí sám po rozpise? (liftboy žije)
func _auto() -> bool:
	return _op != null and is_instance_valid(_op) and _op.state != Gangster.State.DEAD


## Liftboy práve bojuje s Riccom – kabína počká
func _op_busy() -> bool:
	var st: int = int(_op.state)
	return st >= AWARE_FROM and st <= AWARE_TO


## Rozbehne sa k zastávke i. false = nedá sa (je tam, alebo niekto stojí vo dverách)
func _go(i: int) -> bool:
	if i < 0 or i >= stops.size() or (i == stop_i and _target < 0):
		return false
	if _target < 0 and _blocked():
		return false
	_target = i
	_close_door(stop_i)
	if _motor == null:
		_motor = Sfx.loop(&"crane_motor", self, Vector2(0, -50), -14.0, &"SFX")
	return true


func _arrive() -> void:
	stop_i = _target
	_target = -1
	_wait = wait_time
	if _motor:
		_motor.queue_free()
		_motor = null
	Sfx.play(&"train_bell", global_position + Vector2(0, -60), -16.0, 0.02)
	_set_doors()
	arrived.emit(stop_i)


## Ricco (alebo mafián) stojí na prahu medzi kabínou a poschodím – kabína by ho privrela
func _blocked() -> bool:
	var door_x: float = global_position.x + DOOR_X
	var y: float = stops[stop_i]
	var who: Array[Node2D] = [_player]
	for n in get_tree().get_nodes_in_group(&"enemies"):
		who.append(n as Node2D)
	for b in who:
		if b == null or not is_instance_valid(b):
			continue
		if absf(b.global_position.x - door_x) < door_zone and absf(b.global_position.y - y) < 20.0:
			if b is Gangster and (b as Gangster).state == Gangster.State.DEAD:
				continue
			return true
	return false


# ---------------------------------------------------------------- Ricco ovláda výťah

## Privolávač pri dverách na poschodí i
func call_to(i: int) -> void:
	if _auto() or _target >= 0:
		return
	if i == stop_i:
		_set_doors()
		return
	_go(i)


## Panel v kabíne: ďalšia zastávka hore (na najvyššej dole)
func _on_panel() -> void:
	if _auto() or _target >= 0:
		return
	var next: int = _panel_target()
	if next in locked_stops and not has_key:
		Sfx.play(&"dry_fire", global_position + Vector2(-20, -30), -6.0)
		locked.emit(next)
		return
	_go(next)


func _panel_target() -> int:
	return stop_i + 1 if stop_i < stops.size() - 1 else stop_i - 1


## Poklop na streche kabíny: Ricco vkĺzne dnu (za liftboya, ktorý sa pozerá k dverám)
func _on_hatch() -> void:
	if _player == null or _target >= 0:
		return
	_player.call(&"set_cutscene", true)
	Sfx.play(&"slot_open", global_position + Vector2(0, -100), -8.0)
	var inside := Vector2(global_position.x - 18.0, global_position.y)
	var tw := create_tween()
	tw.tween_property(_player, "global_position", inside + Vector2(0, -40), 0.15)
	tw.tween_property(_player, "global_position", inside, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _player.call(&"set_cutscene", false))


func _update_spots() -> void:
	var manual: bool = not _auto() and _target < 0
	if _panel:
		var on: bool = manual and _player != null and absf(_player.global_position.y - global_position.y) < 10.0
		_panel.monitoring = on
		if not on:
			_panel.set(&"_inside", false)
		_panel.verb = "UP" if _panel_target() > stop_i else "DOWN"
	if _hatch:
		var roof_y: float = global_position.y - 104.0
		var on2: bool = _target < 0 and _player != null and absf(_player.global_position.y - roof_y) < 6.0
		_hatch.monitoring = on2
		if not on2:
			_hatch.set(&"_inside", false)
	for i in calls.size():
		var c := get_node_or_null(calls[i]) as InteractSpot
		if c:
			var on3: bool = manual and i != stop_i
			c.monitoring = on3
			if not on3:
				c.set(&"_inside", false)


# ---------------------------------------------------------------- dvere, protiváha, laná

func _set_doors() -> void:
	for i in doors.size():
		var d := get_node_or_null(doors[i])
		if d:
			d.call(&"set_open", i == stop_i and _target < 0)
	var gate := get_node_or_null(^"Gate") as Sprite2D
	if gate:
		gate.frame = 1 if _target < 0 else 0


func _close_door(i: int) -> void:
	if i >= 0 and i < doors.size():
		var d := get_node_or_null(doors[i])
		if d:
			d.call(&"set_open", false)
	var gate := get_node_or_null(^"Gate") as Sprite2D
	if gate:
		gate.frame = 0
	Sfx.play(&"door_close", global_position + Vector2(DOOR_X, -40), -10.0)


func _place_cw() -> void:
	if _cw:
		_cw.global_position.y = cw_top + (stops[0] - global_position.y)


func _update_cables() -> void:
	if _cable:
		_cable.points = PackedVector2Array([Vector2(0, -104), Vector2(0, winch_y - global_position.y)])
	if _cw_cable and _cw:
		_cw_cable.points = PackedVector2Array([Vector2(0, -40), Vector2(0, winch_y - _cw.global_position.y)])


## Protiváha v pohybe zasiahla Ricca (na rebríku v šachte) – zraní ho a zhodí z rebríka. Kto stojí na nej, vezie sa.
func _check_cw_hit() -> void:
	if _target < 0 or _cw_hurt == null or _player == null:
		return
	if _player.get(&"state") == 3 or float(_player.get(&"invulnerable_timer")) > 0.0:
		return
	var top: float = _cw.global_position.y - 40.0
	var standing: bool = (_player as CharacterBody2D).is_on_floor() and _player.global_position.y <= top + 3.0
	if standing:
		return
	for b in _cw_hurt.get_overlapping_bodies():
		if b == _player:
			_player.call(&"take_damage", CW_HURT, _cw.global_position + Vector2(0, -20))
			if int(_player.get(&"state")) == 7:   # Ricco.State.LADDER – zhodí ho
				_player.call(&"_leave_ladder", Vector2(60.0, 40.0))
			Sfx.play(&"metal_crash", _cw.global_position, -10.0, 0.1)
			_player.set(&"shake_timer", 0.15)
			return
