extends AnimatableBody2D
## Auto prenasledovateľov v naháňačke (levels/level3/chase.gd) – otvorený touring policajtov alebo ľudí Margaret.
## Ide v tom istom pruhu za taxíkom: dobehne zozadu (start), drží sa tesne za ním a strelci vnútri (Gangster, stoja
## na podlahe auta – vrstva CAR_LAYER, od pása dolu ich zakrývajú dvere) strieľajú na Ricca. Občas do taxíka drgne (bumped).
## Šofér (Driver + DriverHit – chase_hitbox.gd): keď ho Ricco trafí, auto sa rozkýve, z kapoty vyrazí dym a auto odpadne
## dozadu aj so strelcami. Keď sú strelci mŕtvi, auto po chvíli odpadne samo; po hold_time tiež (polícia to vzdá).
## Kapota a zložená strecha vzadu sú jednosmerné plošiny – AnimatableBody2D (sync_to_physics) vezie Ricca so sebou.
## Počiatok uzla = ľavý okraj auta na ceste (y = 0). Godot docs: classes/class_animatablebody2d, classes/class_cpuparticles2d

signal finished       ## auto odišlo (vybúrané / odpadlo) – chase.gd pustí ďalšiu vlnu
signal bumped         ## drglo do taxíka – chase.gd zatrasie taxíkom a Riccom

const CAR_LAYER := 256         ## vrstva 9: podlaha auta – stoja na nej len strelci v ňom
const DEAD := 10               ## Gangster.State.DEAD

@export var start_x: float = -420.0
@export var hold_x: float = 30.0            ## px – kde sa drží (ľavý okraj auta); predok je o 184 px ďalej
@export var approach_time: float = 3.2
@export var hold_time: float = 28.0         ## s – potom to vzdá a odpadne
@export var driver_health: float = 2.0
@export var bump_every: Vector2 = Vector2(6.0, 9.0)
@export var bump_reach: float = 16.0        ## px – o koľko sa pri drgnutí pohne dopredu
@export var siren: bool = true

var active: bool = false
var done: bool = false
var _phase: int = 0            ## 0 čaká, 1 dobieha, 2 drží sa, 3 odpadá (vybúrané alebo to vzdal)
var _t: float = 0.0
var _bump_t: float = 0.0
var _bump_k: float = -1.0      ## < 0 = nedrgá; inak čas drgnutia
var _health: float = 2.0
var _wrecked: bool = false
var _gunmen: Array[Node] = []
var _siren: Node
var _fall_v: float = 0.0
var _cleared_t: float = -1.0

@onready var sprite: Sprite2D = $Sprite
@onready var driver: Sprite2D = get_node_or_null(^"Driver") as Sprite2D
@onready var smoke: CPUParticles2D = get_node_or_null(^"Smoke") as CPUParticles2D


func _ready() -> void:
	sync_to_physics = true
	position.x = start_x
	visible = false
	_health = driver_health
	for c in get_children():
		if c.is_in_group(&"enemies"):
			var g := c as CharacterBody2D
			g.collision_mask = CAR_LAYER   # stojí na podlahe auta (Gangster._ready dá 1 – rodič beží po deťoch)
			g.process_mode = Node.PROCESS_MODE_DISABLED   # kým auto nepríde, nestrieľa a guľky ním preletia
			_gunmen.append(g)
	var hit := get_node_or_null(^"DriverHit")
	if hit:
		hit.process_mode = Node.PROCESS_MODE_DISABLED
		hit.connect(&"hit", _on_driver_hit)


## Auto dobehne zozadu (chase.gd ho pošle vo vlne)
func start() -> void:
	if active or done:
		return
	active = true
	visible = true
	_phase = 1
	_t = 0.0
	_bump_t = randf_range(bump_every.x, bump_every.y)
	for g in _gunmen:
		g.process_mode = Node.PROCESS_MODE_INHERIT
	var hit := get_node_or_null(^"DriverHit")
	if hit:
		hit.process_mode = Node.PROCESS_MODE_INHERIT
	if siren:
		_siren = Sfx.loop(&"siren", self, Vector2(110, -60), -10.0, &"SFX")
	Sfx.play(&"klaxon", global_position + Vector2(180, -40), -6.0, 0.05)


func _physics_process(delta: float) -> void:
	if not active:
		return
	_t += delta
	match _phase:
		1:   # dobieha – spomalí na našu rýchlosť (ease out)
			var k: float = clampf(_t / approach_time, 0.0, 1.0)
			position.x = lerpf(start_x, hold_x, 1.0 - (1.0 - k) * (1.0 - k))
			if k >= 1.0:
				_phase = 2
				_t = 0.0
		2:   # drží sa za taxíkom, kolíše sa; občas drgne
			var x: float = hold_x + sin(_t * 1.3) * 9.0
			_bump_t -= delta
			if _bump_t <= 0.0 and _bump_k < 0.0:
				_bump_k = 0.0
			if _bump_k >= 0.0:
				_bump_k += delta
				var b: float = sin(clampf(_bump_k / 0.5, 0.0, 1.0) * PI)
				x += b * (bump_reach + 9.0)
				if _bump_k >= 0.25 and _bump_k - delta < 0.25:
					bumped.emit()
				if _bump_k >= 0.5:
					_bump_k = -1.0
					_bump_t = randf_range(bump_every.x, bump_every.y)
			position.x = x
			if _all_gunmen_dead():
				if _cleared_t < 0.0:
					_cleared_t = 1.6
				_cleared_t -= delta
				if _cleared_t <= 0.0:
					_fall_back(false)
			elif _t >= hold_time:
				_fall_back(false)
		3:   # odpadá dozadu (zrýchľuje), vybúrané sa kýve
			_fall_v += (520.0 if _wrecked else 300.0) * delta
			position.x -= _fall_v * delta
			if _wrecked:
				sprite.rotation = sin(_t * 9.0) * 0.05
			if position.x < -560.0:
				_finish()


func _all_gunmen_dead() -> bool:
	if _gunmen.is_empty():
		return false
	for g in _gunmen:
		if is_instance_valid(g) and int(g.get(&"state")) != DEAD:
			return false
	return true


func _on_driver_hit(damage: float, dir: Vector2) -> void:
	if _wrecked or _phase == 0 or _phase == 3:
		return
	_health -= damage
	Sfx.play(&"impact_body", driver.global_position if driver else global_position, -2.0)
	Burst.spawn(get_tree().current_scene, (driver.global_position if driver else global_position) + Vector2(13, 10),
			dir + Vector2(0, -0.3), Color(0.62, 0.05, 0.05), 6, 90.0, Vector2(0, 520), 0.5)
	if driver:
		driver.modulate = Color(3, 3, 3)
		create_tween().tween_property(driver, "modulate", Color.WHITE, 0.12)
	if _health <= 0.0:
		_fall_back(true)


## Odpadne dozadu – wrecked = šofér zasiahnutý (dym, šmyk, náraz), inak to vzdal / nemá strelcov
func _fall_back(wrecked: bool) -> void:
	if _phase == 3:
		return
	_phase = 3
	_t = 0.0
	_wrecked = wrecked
	_fall_v = 40.0
	if _siren:
		_siren.queue_free()
		_siren = null
	var hit := get_node_or_null(^"DriverHit")
	if hit:
		hit.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	if wrecked:
		sprite.frame = 1
		if driver:
			driver.frame = 1
		if smoke:
			smoke.emitting = true
		Sfx.play(&"tire_skid", global_position + Vector2(90, -20), -2.0)
		Sfx.play(&"metal_crash", global_position + Vector2(90, -20), -10.0, 0.1)
		Burst.spawn(get_tree().current_scene, global_position + Vector2(160, -40), Vector2(1, -0.5), Color(1.0, 0.8, 0.4), 10, 120.0)
	else:
		Sfx.play(&"klaxon_2", global_position + Vector2(180, -40), -8.0, 0.05)


func _finish() -> void:
	if done:
		return
	done = true
	active = false
	finished.emit()
	queue_free()
