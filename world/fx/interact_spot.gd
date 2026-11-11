class_name InteractSpot
extends Area2D
## Miesto, kde Ricco niečo použije klávesom použiť (F, settings/key_bindings.gd): keď stojí v oblasti,
## nad miestom svieti nápoveda – tabuľka [F] READ (world/fx/interact_hint.gd); po stlačení signál used.
## Vec, ku ktorej miesto patrí, jemne žiari (world/fx/interact_glow.gd) – ďaleko slabo, pri nej silnejšie.
## Ktorá vec: glow_target, inak sa nájde sama (obrázok, ktorý leží hlavne v oblasti miesta); keď žiadny nie je
## (vec je namaľovaná v pozadí), svieti mäkký ovál cez oblasť. Tvar (CollisionShape2D) pridá ten, kto ho vytvára.
## Godot docs: classes/class_area2d

signal used

@export var verb: String = "USE"          ## slovo v nápovede (READ, OPEN…)
@export var hint_offset: Vector2 = Vector2(0, -30)
@export var once: bool = true             ## po použití zmizne nápoveda aj oblasť
@export var glow: bool = true             ## vec okolo miesta jemne žiari
@export var glow_target: NodePath         ## ktorý obrázok žiari (prázdne = nájde sa sám)

var _player: Node2D
var _inside: bool = false
var _hint: InteractHint
var _glow: InteractGlow


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b: Node): if b.is_in_group(&"player"): _player = b as Node2D; _inside = true)
	body_exited.connect(func(b: Node): if b.is_in_group(&"player"): _inside = false)
	_hint = InteractHint.new()
	_hint.visible = false
	add_child(_hint)
	if glow:
		_setup_glow.call_deferred()   # až keď je scéna celá (obrázky vecí môžu pribudnúť po mieste)


func _exit_tree() -> void:
	if is_instance_valid(_glow) and _glow.get_parent() != self:
		_glow.queue_free()   # žiara visí na obrázku veci – s miestom zmizne aj ona


func _process(_delta: float) -> void:
	var can: bool = _can_use()
	_hint.visible = can
	if not can:
		return
	_hint.set_hint([KeyBindings.short(&"takedown")], verb)
	var t: float = Time.get_ticks_msec() * 0.008
	_hint.position = (hint_offset - _hint.size / 2.0 + Vector2(0, sin(t) * 1.5)).round()
	if Input.is_action_just_pressed(&"takedown"):
		used.emit()
		if once:
			_inside = false
			set_process(false)
			_hint.visible = false


func _can_use() -> bool:
	return _inside and monitoring and _player != null and is_instance_valid(_player) \
			and _player.get(&"state") == 0 and not _player.get(&"in_cutscene")


## Pre žiaru: OFF (použité, vypnuté, v cutscéne), NEAR (Ricco stojí pri nej), inak FAR
func glow_state() -> int:
	if not is_inside_tree() or not is_processing() or not monitoring or not is_visible_in_tree():
		return InteractGlow.OFF
	if _player and is_instance_valid(_player) and _player.get(&"in_cutscene"):
		return InteractGlow.OFF
	return InteractGlow.NEAR if _can_use() else InteractGlow.FAR


func _setup_glow() -> void:
	if not is_inside_tree():
		return
	var target := get_node_or_null(glow_target) as CanvasItem if not glow_target.is_empty() else _find_target()
	if target:
		_glow = InteractGlow.attach(target, glow_state)
	if _glow == null:
		var r: Rect2 = _zone()
		var local := Rect2(to_local(r.position), r.size)   # miesto sa neotáča ani nezväčšuje
		_glow = InteractGlow.blob(self, local, glow_state)


## Oblasť miesta v globálnych súradniciach (z CollisionShape2D)
func _zone() -> Rect2:
	var r := Rect2()
	var first := true
	for c in get_children():
		var cs := c as CollisionShape2D
		if cs == null or cs.shape == null:
			continue
		var sr: Rect2 = cs.get_global_transform() * cs.shape.get_rect()
		r = sr if first else r.merge(sr)
		first = false
	if first:
		r = Rect2(global_position - Vector2(12, 24), Vector2(24, 24))
	return r


## Obrázok veci: Sprite2D / AnimatedSprite2D, ktorý leží aspoň z 55 % v oblasti miesta (o kúsok väčšej);
## z takých ten, čo jej zaberá najviac. Pozadia, postavy a svetlá (ADD) sa preskočia.
func _find_target() -> CanvasItem:
	var zone: Rect2 = _zone().grow(6.0)
	var best: CanvasItem = null
	var best_area: float = 0.0
	var stack: Array[Node] = [get_tree().current_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_in_group(&"player") or n.is_in_group(&"enemies") or n is InteractGlow or n is CanvasLayer:
			continue
		stack.append_array(n.get_children())
		if not (n is Sprite2D or n is AnimatedSprite2D):
			continue
		var ci := n as CanvasItem
		if not ci.is_visible_in_tree():
			continue
		var mat := ci.material as CanvasItemMaterial
		if mat and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			continue
		var r: Rect2 = _sprite_rect(n as Node2D)
		var area: float = r.get_area()
		if area <= 0.0 or area > InteractGlow.MAX_PIXELS:
			continue
		var inside: float = r.intersection(zone).get_area()
		if inside / area >= 0.55 and inside > best_area:
			best = ci
			best_area = inside
	return best


func _sprite_rect(n: Node2D) -> Rect2:
	var local := Rect2()
	if n is Sprite2D:
		local = (n as Sprite2D).get_rect()
	else:
		var a := n as AnimatedSprite2D
		if a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
			return Rect2()
		var tex: Texture2D = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		if tex == null:
			return Rect2()
		var sz: Vector2 = tex.get_size()
		local = Rect2(a.offset - (sz / 2.0 if a.centered else Vector2.ZERO), sz)
	return n.get_global_transform() * local
