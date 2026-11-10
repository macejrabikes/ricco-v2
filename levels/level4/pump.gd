extends StaticBody2D
## Čerpadlo v zatopenej pivnici vily (kapitola IV – cellar.tscn). Vito ním tlačí morskú vodu do starej pivnice
## (hadica vedie do bazéna) – kým beží, voda stojí vysoko. Hučí: výstrely a iný hluk do mask_reach od neho gangstri
## počujú len do masked_radius (Gangster._masked – skupina „noise_masks“; záblesk z hlavne vidno aj tak).
## Vypnúť: páčka (cellar.gd – PumpSpot „SWITCH OFF“) alebo prestreliť (iskry, para). Ticho zalarmuje strážcov okolo
## (Gangster.noise) a voda pomaly odtečie (drain_to za drain_time): hýbe sa WaterZone (rects[0]), hladina
## (WaterSurface), hĺbka (WaterDeep), plávajúce sudy (bob.gd – skupina „floaters“, set_base) aj lampa na kábli (water_y).
## Vrstva 4 ako nepriatelia: zasiahne ho Riccova guľka aj klobúk, mafiánske guľky nie.
## Godot docs: classes/class_staticbody2d, classes/class_tween (tween_method), classes/class_audiostreamplayer2d

signal stopped(broken: bool)

@export var mask_reach: float = 320.0       ## px od čerpadla – tu sa hluk stráca v hukote
@export var masked_radius: float = 110.0    ## px – kam až počuť výstrel pri bežiacom čerpadle
@export var drain_to: float = 982.0         ## globálne y – kam klesne hladina (dno bazéna = voda zmizne)
@export var drain_time: float = 14.0        ## s
@export var floor_y: float = 982.0          ## globálne y dna – plávajúce sudy naň dosadnú
@export var alarm_radius: float = 260.0     ## px – koho zalarmuje, keď čerpadlo stíchne
@export var sound_db: float = -14.0
@export var water_path: NodePath = ^"../Water"
@export var surface_path: NodePath = ^"../WaterSurface"
@export var deep_path: NodePath = ^"../WaterDeep"
@export var lamp_path: NodePath = ^"../WaterLamp"

const PUFF_EVERY := 1.4    ## s – obláčik z výfuku, kým beží

var running: bool = true
var _loop: AudioStreamPlayer2D
var _puff_t: float = 0.0
var _wz: WaterZone
var _rect0: Rect2
var _bottom: float = 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group(&"noise_masks")
	_loop = Sfx.loop(&"crane_motor", self, Vector2(0, -6), sound_db, &"SFX") as AudioStreamPlayer2D


## Gangster._masked: hluk blízko bežiaceho čerpadla počuť len do masked_radius
func mask(pos: Vector2, radius: float) -> float:
	if running and pos.distance_to(global_position) < mask_reach:
		return minf(radius, masked_radius)
	return radius


func take_hit(_damage: float, _dir: Vector2) -> void:
	switch_off(true)


func hat_hit(_damage: float, _dir: Vector2) -> void:
	Sfx.play(&"hat_bonk", global_position, -6.0, 0.1)   # klobúk stroj nezastaví


func _physics_process(delta: float) -> void:
	if not running:
		return
	_puff_t += delta
	if _puff_t >= PUFF_EVERY:   # sivý obláčik z výfuku – vidno, že stroj beží
		_puff_t = 0.0
		Burst.spawn(get_parent(), global_position + Vector2(18, -22), Vector2.UP, Color(0.62, 0.62, 0.6, 0.5), 3, 26.0, Vector2(0, -50), 0.7)


## Vypnúť (páčka) alebo rozbiť (guľka). Potom ticho, alarm a voda odteká.
func switch_off(broken: bool = false) -> void:
	if not running:
		return
	running = false
	remove_from_group(&"noise_masks")
	if is_instance_valid(_loop):   # motor dobehne
		var tw := create_tween()
		tw.tween_property(_loop, "pitch_scale", 0.5, 1.4)
		tw.parallel().tween_property(_loop, "volume_db", -60.0, 1.4)
		tw.tween_callback(_loop.queue_free)
	if broken:
		Sfx.play(&"metal_crash", global_position, -10.0, 0.1)
		Sfx.play(&"steam_hiss", global_position, -6.0)
		Burst.spawn(get_parent(), global_position + Vector2(0, -10), Vector2.UP, Color(1.0, 0.85, 0.4), 12, 120.0, Vector2(0, 300), 0.4)
		Burst.spawn(get_parent(), global_position + Vector2(18, -22), Vector2.UP, Color(0.85, 0.85, 0.85, 0.6), 10, 50.0, Vector2(0, -60), 1.2)
	else:
		Sfx.play(&"slot_open", global_position, -4.0)
	Gangster.noise(global_position, alarm_radius)   # zrazu ticho – strážcovia okolo sa idú pozrieť
	stopped.emit(broken)
	_drain()


func _drain() -> void:
	_wz = get_node_or_null(water_path) as WaterZone
	if _wz == null or _wz.rects.is_empty():
		return
	_rect0 = _wz.rects[0]
	var top: float = _rect0.position.y + _wz.global_position.y
	_bottom = _rect0.end.y + _wz.global_position.y
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_method(_set_level, top, minf(drain_to, _bottom), drain_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Hladina na globálnom y = level: voda (WaterZone) aj všetko, čo na nej je
func _set_level(level: float) -> void:
	var top: float = minf(level, _bottom)
	var r := _rect0
	r.position.y = top - _wz.global_position.y
	r.size.y = maxf(0.0, _bottom - top)
	_wz.rects[0] = r
	var surf := get_node_or_null(surface_path) as Node2D
	if surf:
		surf.position.y = top - 3.0   # na dne ostane tenká mláka
	var deep := get_node_or_null(deep_path) as Sprite2D
	if deep:
		deep.position.y = top + 2.0
		deep.region_rect.size.y = maxf(0.0, _bottom - top - 2.0)
		deep.visible = deep.region_rect.size.y > 0.5
	var afloat: bool = top - 4.0 < floor_y - 10.0
	for b in get_tree().get_nodes_in_group(&"floaters"):
		b.set_base(minf(top - 4.0, floor_y - 10.0), afloat)
	var lamp := get_node_or_null(lamp_path)
	if lamp:
		lamp.set(&"water_y", top)
