class_name Gangster
extends CharacterBody2D
## Nepriateľ – gangster (človek). Telo je poskladané z častí (cutout animácia, Godot docs:
## tutorials/animation/cutout_animation): nohy, trup, hlava, klobúk, dve ruky. Kód ich hýbe sám:
## nohy sa pri chôdzi kývu, predná ruka so zbraňou mieri presne na Ricca, zadná drží predok zbrane.
##
## Správanie (jednoduchý stavový automat):
##   hliadka → zbadá Ricca (lúč bez steny, dosah, pozerá sa jeho smerom)
##   strelec: mieri (červená čiara – čas uskočiť / šmyknúť sa) → dávka → pauza → znova
##   bitkár:  beží k Riccovi → napriahne sa → úder → oddych
##            noví bitkári (dock, toro, bouncer, slugger) majú ruky z dvoch častí (nadlaktie + predlaktie s päsťou)
##            a pózy pokoj / kryt / náprah / úder; slugger drží palicu obomi rukami (dve kosti, IK k palici)
##   zásah: biely záblesk, krv, krátke zakolísanie; klobúk od Ricca ho omráči a zhodí mu klobúk
##   smrť: padne na chrbát, zbraň a klobúk odletia, vypadne krabička nábojov; v test room sa po chvíli objaví znova
##   kamaráti: keď niekoho vedľa zložíš (aj potichu), blízky to počuje a ten, čo sa tam pozerá, to vidí → vie o Riccovi;
##             ďalší v okolí (aj výstrel – Gangster.noise) sa s „?“ idú pozrieť (INVESTIGATE), potom sa vrátia na miesto
##   nechodia cez seba: na hliadke sa pri kamarátovi otočia, pri behu za Riccom sa nezhlukujú
##   prekážky: keď idú za Riccom alebo sa idú pozrieť, nízku prekážku (debna, sud – do HOP_MAX) preskočia (_try_hop)
##             a zoskočia aj z debny (_ledge_ok s väčším dosahom); na hliadke sa pri stene stále otočia
##   zásah: kto dostane guľku, vie odkiaľ prišla (_aggro) – otočí sa a strieľa späť aj z tmy; keď Ricca nevidí
##          (schoval sa za debnu), ide sa pozrieť tam, kde ho naposledy videl (_last_seen)
## Spomalenie času (Engine.time_scale) spomalí aj jeho a jeho guľky – netreba nič riešiť.

enum State { PATROL, IDLE, AIM, SHOOT, COOLDOWN, CHASE, WINDUP, PUNCH, RECOVER, STUN, DEAD, INVESTIGATE }

@export var kind: String = "tommy"                ## priečinok s časťami tela (characters/gangster/<kind>/)
@export var weapon: WeaponData                    ## zbraň (obrázok, ústie); null = bije päsťami
@export var weapon_texture: Texture2D             ## iný obrázok zbrane (napr. Tommy aj s bubnom)
@export var max_health: int = 3

@export_group("Movement")
@export var walk_speed: float = 35.0
@export var run_speed: float = 0.0                ## > 0 = beží k Riccovi (bitkár)
@export var patrol_time: Vector2 = Vector2(2.0, 4.0)   ## ako dlho ide, kým sa zastaví (náhodne od–do)

@export_group("Shooting")
@export var sight_range: float = 300.0
@export var aim_time: float = 0.7                 ## s mierenia s červenou čiarou pred dávkou
@export var aim_turn_speed: float = 140.0         ## °/s – ako rýchlo sa zbraň otáča za Riccom (dá sa uhnúť)
@export var burst_count: int = 1
@export var burst_interval: float = 0.1
@export var pellets: int = 1
@export var spread_deg: float = 3.0
@export var bullet_speed: float = 380.0           ## pomalšie ako Riccove, aby sa dali preskočiť
@export var bullet_lifetime: float = 1.4
@export var bullet_damage: float = 0.0            ## > 0 = guľka vezme toľko kúskov pizze (odstreľovač so Springfieldom 2)
@export var drops_weapon: bool = true             ## false = zbraň po smrti nevypadne (Ricco ju nevie použiť – Springfield)
@export var cooldown: Vector2 = Vector2(0.9, 1.4)
@export var preferred_range: float = 0.0          ## > 0 = najprv sa priblíži na túto vzdialenosť (lupara)

@export_group("Melee")
@export var punch_range: float = 30.0
@export var windup_time: float = 0.35
@export var recover_time: float = 0.6
@export var melee_damage: int = 1                 ## koľko životov vezme úder (palica 2)
@export var hook: bool = false                    ## dokár s lodným hákom (<kind>/hook.png): úder Ricca zachytí a pritiahne k sebe
@export var hook_pull: float = 260.0              ## px/s – najväčšia rýchlosť, ktorou ho hák pritiahne

@export_group("Stealth")
@export_range(-1.0, 1.0, 2.0) var start_facing: float = -1.0   ## -1 = doľava, 1 = doprava
@export var needs_light: bool = false             ## v tme (mimo LightZone) Ricca nevidí – okrem tesnej blízkosti
@export var close_sense: float = 34.0             ## px vodorovne – takto blízko (na tej istej úrovni) Ricca vycíti aj v tme / za chrbtom
@export var stationary: bool = false              ## stojí na mieste (napr. kuchár pri pulte) namiesto hliadky
@export var look_back: Vector2 = Vector2.ZERO     ## s – občas sa obzrie dozadu (od–do); 0 = nikdy
@export var patrol_span: float = 0.0              ## px – hliadkuje len ±toľko od miesta, kde začal (0 = kým nenarazí)
@export var flashlight: bool = false              ## svieti si baterkou pred seba – v kuželi Ricca vidno (pivnica)
@export var passive: bool = false                 ## Ricca si nevšíma (napr. vyhadzovač pred pizzeriou) – kým ho Ricco nezasiahne
@export var relentless: bool = false              ## stále vie, kde Ricco je, a ide po ňom (poskoci Big Lou na lodi – nedajú sa zaskočiť zozadu)
@export var whistle: bool = false                 ## policajt: keď Ricca prvý raz zbadá, zapíska a privolá ostatných v okolí (WHISTLE_RANGE)

@export_group("Armor & cold")
@export var vest: bool = false                    ## nepriestrelná vesta (dobová, plátovaná pod sakom) – do trupu len vest_factor damage, hlava a nohy nie
@export_range(0.0, 1.0) var vest_factor: float = 0.2
@export var trip_time: float = 1.3                ## s – ako dlho leží po podkopnutí (Riccov šmyk po bruchu), potom vstáva (GETUP_TIME)
@export var cold_breath: bool = false             ## v mraziarni mu od úst stúpa para

@export_group("Test room")
@export var respawn_time: float = 6.0             ## s po smrti, kým sa objaví znova (0 = nikdy)

const BULLET := preload("res://weapons/pistol/bullet.tscn")
const DROP := preload("res://weapons/pistol/magazine_drop.tscn")
const AMMO := preload("res://props/ammo/ammo_pickup.tscn")
const WEAPON_PICKUP := preload("res://weapons/weapon_pickup.gd")
const FLASH := preload("res://weapons/pistol/muzzle_flash_big.png")

## Spoločné body kostry (nohy na y = 0, pozerá sa doprava)
const HIP := Vector2(0, -28)
const LEG_FRONT := Vector2(-1, -28)
const LEG_BACK := Vector2(3, -28)
const NECK := Vector2(1, -52)
const HAT_AT := Vector2(1, -65)
const SHOULDER_FRONT := Vector2(2, -48)
const SHOULDER_BACK := Vector2(-2, -48)
const EYE := Vector2(4, -62)
## Pivoty v obrázkoch častí (gangster_parts.py) – rovnaké pre všetkých, trup a klobúk podľa typu
const PIVOT_LEG := Vector2(4, 1)
const PIVOT_HEAD := Vector2(7, 19)
const PIVOT_ARM := Vector2(4, 4)
const ARM_GRIP := Vector2(20, 3)
## Ruka z dvoch častí (upper.png + fore.png): rameno v PIVOT_UPPER, lakeť o UPPER_LEN ďalej,
## predlaktie má lakeť v PIVOT_FORE a stred päste o FORE_LEN ďalej
const PIVOT_UPPER := Vector2(4, 4)
const PIVOT_FORE := Vector2(3, 5)
const UPPER_LEN := 8.0
const FORE_LEN := 12.0
const BAT_GRIP := Vector2(6, 4)                  ## úchop palice v bat.png
const HOOK_GRIP := Vector2(3, 3)                 ## úchop rúčky v hook.png
const COVER_LAYER := 32                          ## vrstva 6: kryt, ktorý zastaví pohľad aj guľky, ale nie postavy (visiace mäso, debny na páse)
const RIGS := {
	"tommy": {"torso": Vector2(11, 26), "hat": Vector2(13, 10)},
	"coppola": {"torso": Vector2(11, 26), "hat": Vector2(8, 8)},
	"bruiser": {"torso": Vector2(14, 27)},
	"dock": {"torso": Vector2(14, 28), "hat": Vector2(8, 8)},
	"toro": {"torso": Vector2(14, 28)},
	"bouncer": {"torso": Vector2(14, 28), "hat": Vector2(11, 8)},
	"slugger": {"torso": Vector2(14, 28), "hat": Vector2(8, 8)},
	"cop": {"torso": Vector2(11, 26), "hat": Vector2(8, 8)},   # policajt v kapitole III (modrá uniforma, čiapka)
	"tux": {"torso": Vector2(11, 26), "hat": Vector2(8, 8)},   # ochrankár v smokingu (kapitola III – nadzemka, Colt 1911)
	"sal": {"torso": Vector2(11, 26), "hat": Vector2(8, 8)},   # Velvet Sal (kapitola III – klub The Blue Canary, fialový zamat)
	"butcher": {"torso": Vector2(14, 28), "hat": Vector2(8, 8)},   # mäsiar v hotelovej kuchyni (biela zástera, sekáčik – kapitola III)
	"bellhop": {"torso": Vector2(11, 26), "hat": Vector2(8, 8)},   # liftboy / poslíček hotela Majestic (bordová uniforma)
	"riveter": {"torso": Vector2(14, 28), "hat": Vector2(8, 8)},   # nitovač na stavbe veže Iron Mikea (biela košeľa, traky, baretka)
	"smuggler": {"torso": Vector2(14, 28), "hat": Vector2(8, 8)},   # pašerák rumu z Long Islandu (pletená čiapka, sveter – kapitola IV)
	"keeper": {"torso": Vector2(14, 28), "hat": Vector2(8, 8)},   # hájnik panstva Vito (kapitola IV – tvídové sako, placatá čiapka, Winchester)
	"chief": {"torso": Vector2(11, 26), "hat": Vector2(8, 8)},   # Police Chief Murphy – biela čiapka, dvojradový kabát (kapitola III – most) – characters/murphy/
	"mike": {"torso": Vector2(11, 26), "hat": Vector2(8, 8)},   # Iron Mike – stavbyvedúci (vesta, kravata, tvrdý klobúk) – characters/iron_mike/
	"widow": {"torso": Vector2(23, 28), "hat": Vector2(8, 8)},   # Margaret Vito – smútočné šaty po zem (sukňa je v torze), cloche so závojom – characters/margaret/
	"mancini": {"torso": Vector2(11, 26), "hat": Vector2(8, 8)},   # consigliere Salvatore Mancini – sivý trojdielny oblek, okuliare, fedora (kapitola IV – útes) – _art_src/make_mancini_parts.py
}
## Pózy dvojdielnych rúk: [nadlaktie predné, predlaktie predné, nadlaktie zadné, predlaktie zadné, náklon px]
## uhly sú v kostre otočenej doprava (0 = vpred, PI/2 = dole), predlaktie má globálny uhol
const POSE_IDLE := [1.75, 1.35, 1.65, 1.3, 0.0]
const POSE_GUARD := [0.95, -1.25, 0.45, -0.75, 0.0]     # päste pri brade
const POSE_WINDUP := [2.9, -1.95, 0.55, -0.6, -2.0]     # ruka nad hlavou, zaklonený
const POSE_PUNCH := [-0.05, -0.05, 2.3, -1.1, 3.0]      # vystretá ruka, naklonený vpred
## Palica: [ruky voči prednému plecu, uhol palice, náklon px]
const BAT_IDLE := [Vector2(9, 7), -2.55, 0.0]           # opretá o plece (jednou rukou)
const BAT_GUARD := [Vector2(3, -3), -1.85, 0.0]         # postoj pálkara
const BAT_WINDUP := [Vector2(-7, -7), -2.85, -2.0]      # zaklonená za hlavou
const BAT_SWING := [Vector2(15, 5), 0.35, 3.0]          # švih šikmo dole (na Riccovu hlavu)
const BAT_FOLLOW := [Vector2(10, -4), -0.9, 2.0]        # dotiahnutie

static var _last_alert_ms: int = -10000   ## zvuk „!“ naraz len raz

const HEAR_SCUFFLE := 64.0     ## px – zápas / pád kamaráta tesne vedľa počuje vždy (aj potichu zneškodneného)
const SEE_BODY := 200.0        ## px – pád kamaráta vidí, ak sa tým smerom pozerá a nič nie je medzi nimi
const HEAR_BODY := 150.0       ## px – pád kamaráta počuje → ide sa pozrieť
const KEEP_APART := 22.0       ## px – takto blízko pri kamarátovi sa na hliadke otočí
const WHISTLE_RANGE := 480.0   ## px – píšťalku policajta počujú všetci do tejto vzdialenosti
const DARK_SIGHT := 80.0       ## px – v tme (needs_light) rozozná Ricca pred sebou do tejto vzdialenosti, aj prikrčeného
const HEAR_STEPS := 90.0       ## px – za chrbtom počuje Riccove kroky, keď nejde potichu (zakrádanie: close_sense · 0,45)
const HOP_MAX := 46.0          ## px – najvyššia prekážka, ktorú preskočí (dve debny na palube)
const CHASE_DROP := 64.0       ## px – z takej výšky zoskočí, keď ide za Riccom (z debny dole)
const HIT_AGGRO := 5.0         ## s – po zásahu vie, kde Ricco je (aj v tme)

var state: State = State.PATROL
var health: float   ## damage zbraní je desatinný (WeaponData.damage, pokles so vzdialenosťou)
var facing: float = -1.0
var walk_dir: float = -1.0
var timer: float = 0.0
var shots_left: int = 0
var aim_angle: float = PI           ## globálny uhol zbrane
var walk_phase: float = 0.0
var _tripped: bool = false          ## leží po podkopnutí (trip)
var _getting_up: bool = false       ## práve vstáva (pózy robí tween v _stand_up)
var _getup_tween: Tween
var lost_sight: float = 0.0
var home_facing: float = -1.0
var look_timer: float = 0.0
var _alert_mark: Label
var goto_x: float = NAN   ## px – skriptovaný presun (napr. mafián ide zaklopať na dvere); NAN = normálne správanie
var _whistled: bool = false   ## policajt už zapískal (len raz)
var _relentless_t: float = 0.0
var _aggro: float = 0.0   ## s – po zásahu klobúkom vie, kde Ricco je (vidí ho aj v tme a za chrbtom)
var _investigate_x: float = 0.0   ## px – kam sa ide pozrieť (počul výstrel / pád kamaráta)
var _investigate_phase: int = 0   ## 0 = zarazí sa, 1 = ide tam, 2 = obzerá sa, 3 = vracia sa
var _question_mark: Label
var _breath_t: float = 0.0
var _hop_dir: float = 0.0       ## smer skoku cez prekážku (0 = neskáče)
var _hop_speed: float = 0.0
var _hop_air: bool = false      ## už je vo vzduchu (pristátie skok ukončí)
var _hop_cool: float = 0.0
var _last_seen: Vector2 = Vector2.INF   ## kde Ricca naposledy videl
var spawn_pos: Vector2
var player: Node2D

var rig: Node2D
var leg_front: Node2D
var leg_back: Node2D
var torso: Node2D
var head: Node2D
var hat: Sprite2D
var arm_front: Node2D
var arm_back: Node2D
var fore_front: Node2D   ## predlaktia (len dvojdielne ruky)
var fore_back: Node2D
var bat: Sprite2D
var _segmented: bool = false
var _lean: float = 0.0
var _hand: Vector2 = BAT_IDLE[0]
var _bat_angle: float = BAT_IDLE[1]
var gun: Sprite2D
var muzzle: Marker2D
var flash: Sprite2D
var laser: Line2D
var _flash_t: float = 0.0


func _ready() -> void:
	health = max_health
	spawn_pos = global_position
	collision_layer = 4    # enemies
	collision_mask = 1     # world
	floor_max_angle = deg_to_rad(50.0)   # schody sú 45° rampa (tools/build_level1.gd – _stair_ramp)
	floor_snap_length = 16.0
	add_to_group(&"enemies")
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 9.0
	cap.height = 66.0
	shape.shape = cap
	shape.position = Vector2(0, -33)
	add_child(shape)
	_build_rig()
	if flashlight:
		_make_flashlight()
	_set_facing(start_facing if start_facing != 0.0 else facing)
	home_facing = facing
	walk_dir = facing
	look_timer = randf_range(look_back.x, look_back.y)
	timer = randf_range(patrol_time.x, patrol_time.y)


# ---------------------------------------------------------------- telo z častí

func _part(parent: Node, file: String, pivot: Vector2, at: Vector2) -> Node2D:
	var holder := Node2D.new()
	holder.position = at
	parent.add_child(holder)
	var path := "res://characters/gangster/%s/%s.png" % [kind, file]
	if ResourceLoader.exists(path):
		var s := Sprite2D.new()
		s.texture = load(path)
		s.centered = false
		s.offset = -pivot
		holder.add_child(s)
	return holder


func _build_rig() -> void:
	var r: Dictionary = RIGS.get(kind, RIGS["tommy"])
	rig = Node2D.new()
	add_child(rig)
	_segmented = weapon == null and ResourceLoader.exists("res://characters/gangster/%s/upper.png" % kind)
	if _segmented:
		arm_back = _part(rig, "upper_back", PIVOT_UPPER, SHOULDER_BACK)
		fore_back = _part(arm_back, "fore_back", PIVOT_FORE, Vector2(UPPER_LEN, 0))
	else:
		arm_back = _part(rig, "arm_back", PIVOT_ARM, SHOULDER_BACK)
	leg_back = _part(rig, "leg_back", PIVOT_LEG, LEG_BACK)
	leg_front = _part(rig, "leg", PIVOT_LEG, LEG_FRONT)
	torso = _part(rig, "torso", r["torso"], HIP)
	var vest_path := "res://characters/gangster/%s/vest.png" % kind
	if vest and ResourceLoader.exists(vest_path):
		var vs := Sprite2D.new()
		vs.texture = load(vest_path)
		vs.centered = false
		vs.offset = -r["torso"]
		torso.add_child(vs)
	head = _part(rig, "head", PIVOT_HEAD, NECK)
	if r.has("hat"):
		hat = Sprite2D.new()
		hat.texture = load("res://characters/gangster/%s/hat.png" % kind)
		hat.centered = false
		hat.offset = -r["hat"]
		hat.position = HAT_AT
		rig.add_child(hat)
	if _segmented:
		arm_front = _part(rig, "upper", PIVOT_UPPER, SHOULDER_FRONT)
		fore_front = _part(arm_front, "fore", PIVOT_FORE, Vector2(UPPER_LEN, 0))
		var bat_path := "res://characters/gangster/%s/bat.png" % kind
		if ResourceLoader.exists(bat_path):
			bat = Sprite2D.new()
			bat.texture = load(bat_path)
			bat.centered = false
			bat.offset = -BAT_GRIP
			bat.position = Vector2(FORE_LEN, 0)
			fore_front.add_child(bat)
			fore_front.move_child(bat, 0)   # päsť ostane nad rúčkou
		var hook_path := "res://characters/gangster/%s/hook.png" % kind
		if hook and ResourceLoader.exists(hook_path):
			var hk := Sprite2D.new()
			hk.texture = load(hook_path)
			hk.centered = false
			hk.offset = -HOOK_GRIP
			hk.position = Vector2(FORE_LEN, 0)
			hk.rotation = -PI / 2.0   # rúčka v pästi, hák smeruje po predlaktí ďalej
			fore_front.add_child(hk)
			fore_front.move_child(hk, 0)
	else:
		arm_front = _part(rig, "arm", PIVOT_ARM, SHOULDER_FRONT)
	if _segmented:   # hneď v pokoji (inak by prvý snímok trčali ruky dopredu)
		_bend_arm(arm_front, fore_front, POSE_IDLE[0], POSE_IDLE[1], 1.0)
		_bend_arm(arm_back, fore_back, POSE_IDLE[2], POSE_IDLE[3], 1.0)
		if bat:
			_animate_bat(1.0, 0.0)
	muzzle = Marker2D.new()
	if weapon:
		gun = Sprite2D.new()
		gun.texture = weapon_texture if weapon_texture else weapon.texture
		gun.centered = false
		gun.position = ARM_GRIP - PIVOT_ARM - weapon.grip_px
		arm_front.add_child(gun)
		# ruka nad rukoväťou (aby ju „zvierala“)
		var hand := Sprite2D.new()
		hand.texture = load("res://characters/gangster/%s/arm.png" % kind)
		hand.centered = false
		hand.region_enabled = true
		hand.region_rect = Rect2(ARM_GRIP.x - 2, 0, hand.texture.get_width() - ARM_GRIP.x + 2, hand.texture.get_height())
		hand.position = Vector2(ARM_GRIP.x - 2, 0) - PIVOT_ARM
		arm_front.add_child(hand)
		muzzle.position = gun.position + weapon.muzzle_px
	else:
		muzzle.position = ARM_GRIP - PIVOT_ARM + Vector2(3, 0)
	arm_front.add_child(muzzle)
	flash = Sprite2D.new()
	flash.texture = FLASH
	flash.hframes = 3
	flash.centered = false
	flash.offset = Vector2(-3, -12)
	flash.scale = Vector2.ONE * (1.2 if pellets > 1 else 0.75)
	flash.position = Vector2(1, 0)
	flash.visible = false
	muzzle.add_child(flash)
	laser = Line2D.new()
	laser.width = 1.0
	laser.default_color = Color(1.0, 0.15, 0.1, 0.55)
	laser.visible = false
	laser.top_level = true   # body v globálnych súradniciach
	add_child(laser)


func _set_facing(f: float) -> void:
	facing = f
	rig.scale.x = f


var _flash: Node2D
var _wall_cover: float = 0.0   ## 0–1: nakoľko ho zakrýva predná stena (prierez vozňa/miestnosti) – set_wall_cover


## Prierez: keď je predná stena zatvorená (Ricco je vonku), nevidno cez ňu baterku ani „?“/„!“ nad hlavou.
## Volá to level (napr. train.gd) každý snímok podľa priehľadnosti steny; 0 = všetko vidno, 1 = schované.
func set_wall_cover(a: float) -> void:
	_wall_cover = a
	var k: float = 1.0 - a
	if _flash:
		_flash.modulate.a = k
	if _alert_mark:
		_alert_mark.self_modulate.a = k
	if _question_mark:
		_question_mark.self_modulate.a = k

## Baterka: kužeľ svetla pred ním (je v kostre, takže sa otáča s ním) + LightZone v kuželi
func _make_flashlight() -> void:
	_flash = Node2D.new()
	_flash.name = "Flashlight"
	_flash.position = Vector2(10, -44)
	rig.add_child(_flash)
	var cone := Sprite2D.new()
	cone.texture = preload("res://levels/level1/art/flashlight_cone.png")
	cone.centered = false
	cone.position = Vector2(0, -24)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cone.material = m
	cone.z_index = 4
	_flash.add_child(cone)
	var zone := Area2D.new()
	zone.set_script(preload("res://world/stealth/light_zone.gd"))
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(120, 44)
	cs.shape = rs
	cs.position = Vector2(64, 12)
	zone.add_child(cs)
	_flash.add_child(zone)


## Globálny uhol → rotácia ruky v (prípadne zrkadlenej) kostre
func _arm_rot(global_angle: float) -> float:
	return global_angle if facing > 0.0 else wrapf(PI - global_angle, -PI, PI)


# ---------------------------------------------------------------- hlavná slučka

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	timer -= delta
	_aggro -= delta
	if relentless and state != State.DEAD:
		_aggro = maxf(_aggro, 1.0)
	_hop_cool -= delta
	_flash_t -= delta
	flash.visible = _flash_t > 0.0
	if player == null:
		move_and_slide()
		return
	var sees: bool = state != State.DEAD and _can_see_player()
	if relentless and not sees and state in [State.PATROL, State.IDLE, State.INVESTIGATE]:
		_relentless_t -= delta
		if _relentless_t <= 0.0:   # Ricca nevidí (ďaleko, za krytom) – ide tam, kde je teraz
			_relentless_t = 0.8
			if state == State.INVESTIGATE and _investigate_phase == 1:
				_investigate_x = player.global_position.x   # už ide – len si opraví cieľ
			else:
				hear(player.global_position)
	if sees:
		_last_seen = player.global_position

	match state:
		State.PATROL:
			_patrol(delta)
			if sees: _alert()
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if sees: _alert()
			elif timer <= 0.0:
				state = State.PATROL
				timer = randf_range(patrol_time.x, patrol_time.y)
		State.AIM:
			_face_player()
			if preferred_range > 0.0 and _player_dist() > preferred_range + 20.0 and _ledge_ok(facing, CHASE_DROP):
				velocity.x = facing * walk_speed * 1.4   # lupara: najprv sa priblíži
				timer = maxf(timer, aim_time * 0.6)
				if is_on_wall():
					_try_hop(facing, walk_speed * 1.4)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
				if timer <= 0.0:
					state = State.SHOOT
					shots_left = burst_count
					timer = 0.0
			_track_aim(delta)
			_update_laser(true)
			if not sees: _lose_sight(delta)
			else: lost_sight = 0.0
		State.SHOOT:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			_track_aim(delta)
			_update_laser(false)
			if timer <= 0.0 and shots_left > 0:
				_fire()
				shots_left -= 1
				timer = burst_interval
			elif shots_left <= 0 and timer <= 0.0:
				state = State.COOLDOWN
				timer = randf_range(cooldown.x, cooldown.y)
		State.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			_face_player()
			_track_aim(delta)
			if timer <= 0.0:
				if sees: _start_aim()
				else:
					state = State.PATROL
					timer = randf_range(patrol_time.x, patrol_time.y)
		State.CHASE:
			_face_player()
			var dx: float = player.global_position.x - global_position.x
			if absf(dx) < punch_range and absf(player.global_position.y - global_position.y) < 40.0:
				velocity.x = 0.0
				state = State.WINDUP
				timer = windup_time
			elif _ledge_ok(signf(dx), CHASE_DROP) and not _ally_ahead(signf(dx), 18.0, true):
				velocity.x = signf(dx) * run_speed
				if is_on_wall():
					_try_hop(signf(dx), run_speed)   # debna v ceste – preskočí ju
			else:
				velocity.x = 0.0
			if not sees: _lose_sight(delta)
			else: lost_sight = 0.0
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if timer <= 0.0:
				state = State.PUNCH
				timer = 0.12
				_punch()
		State.PUNCH:
			if timer <= 0.0:
				state = State.RECOVER
				timer = recover_time
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if timer <= 0.0:
				if sees: state = State.CHASE
				else:
					state = State.PATROL
					timer = randf_range(patrol_time.x, patrol_time.y)
		State.STUN:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			if timer <= 0.0 and _tripped:
				_stand_up()
				timer = GETUP_TIME + 0.1
			elif timer <= 0.0:
				if sees: _alert()
				else: state = State.IDLE
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		State.INVESTIGATE:
			if sees: _alert()
			else: _investigate(delta)

	if state not in [State.AIM]:
		laser.visible = false
	# skok cez prekážku: vo vzduchu drží smer (stav by ho inak zabrzdil a spadol by späť pred debnu)
	if _hop_dir != 0.0:
		if state == State.DEAD or state == State.STUN or (_hop_air and is_on_floor()):
			_hop_dir = 0.0
		else:
			_hop_air = _hop_air or not is_on_floor()
			velocity.x = _hop_dir * _hop_speed
	move_and_slide()
	_animate(delta)
	# para od úst v mraze
	if cold_breath and state != State.DEAD:
		_breath_t -= delta
		if _breath_t <= 0.0:
			_breath_t = randf_range(2.0, 3.6)
			Burst.spawn(get_tree().current_scene, global_position + Vector2((EYE.x + 4.0) * facing, EYE.y + 6.0), Vector2(facing, -0.4),
					Color(0.9, 0.96, 1.0, 0.35), 5, 16.0, Vector2(0, -8), 1.1)


func _alert() -> void:
	if state in [State.PATROL, State.IDLE, State.STUN, State.INVESTIGATE]:
		_show_alert_mark()
	if whistle and not _whistled:
		_blow_whistle()
	if _question_mark:
		_question_mark.visible = false
	_face_player()
	if run_speed > 0.0:
		state = State.CHASE
	else:
		_start_aim()
	lost_sight = 0.0


## Policajná píšťalka: ostrý trilok, všetci v okolí vedia, kde Ricco je (alarm)
func _blow_whistle() -> void:
	_whistled = true
	Sfx.play(&"whistle", global_position + Vector2(0, -56), -2.0)
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var g := n as Gangster
		if g and g != self and g.global_position.distance_to(global_position) < WHISTLE_RANGE:
			g.alarm()


## „!“ nad hlavou, keď si Ricca všimne
## Poplach (napr. hosť zvrieskol): na chvíľu vie, kde je Ricco, aj keď je v tme
func alarm() -> void:
	if state == State.DEAD or passive:
		return
	_aggro = maxf(_aggro, 8.0)
	if state in [State.PATROL, State.IDLE]:
		_show_alert_mark()


func _show_alert_mark() -> void:
	# krátky tón k výkričníku – naraz len jeden, aj keď si Ricca všimne celá partia
	var now := Time.get_ticks_msec()
	if now - _last_alert_ms > 600:
		_last_alert_ms = now
		Sfx.play(&"alert", global_position + Vector2(0, -60), -4.0, 0.02)
	if _alert_mark == null:
		_alert_mark = Label.new()
		_alert_mark.text = "!"
		_alert_mark.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
		_alert_mark.add_theme_font_size_override(&"font_size", 16)
		_alert_mark.add_theme_color_override(&"font_color", Color8(255, 214, 90))
		_alert_mark.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
		_alert_mark.add_theme_constant_override(&"outline_size", 4)
		_alert_mark.position = Vector2(-3, -96)
		_alert_mark.z_index = 30
		_alert_mark.self_modulate.a = 1.0 - _wall_cover
		add_child(_alert_mark)
	_alert_mark.visible = true
	_alert_mark.modulate.a = 1.0
	_alert_mark.position.y = -92.0
	var tw := create_tween()
	tw.tween_property(_alert_mark, "position:y", -100.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(_alert_mark, "modulate:a", 0.0, 0.25)


func _start_aim() -> void:
	state = State.AIM
	timer = aim_time


func _lose_sight(delta: float) -> void:
	lost_sight += delta
	if lost_sight > 1.5:
		state = State.IDLE
		timer = 1.0
		if _last_seen != Vector2.INF and absf(_last_seen.x - global_position.x) > 24.0:
			hear(_last_seen)   # schoval sa – ide sa pozrieť, kde ho naposledy videl (preskočí aj debny)


func _patrol(delta: float) -> void:
	if not is_nan(goto_x):
		var gdx: float = goto_x - global_position.x
		if absf(gdx) < 4.0:
			velocity.x = 0.0
			goto_x = NAN
			stationary = true
			home_facing = facing
			return
		_set_facing(signf(gdx))
		velocity.x = signf(gdx) * walk_speed
		return
	if stationary:
		_stand(delta)
		return
	if is_on_wall() or not _ledge_ok(walk_dir) or _ally_ahead(walk_dir, KEEP_APART):
		walk_dir = -walk_dir
	elif patrol_span > 0.0 and (global_position.x - spawn_pos.x) * walk_dir > patrol_span:
		walk_dir = -walk_dir
	_set_facing(walk_dir)
	velocity.x = walk_dir * walk_speed
	var low: float = 0.6 if facing > 0.0 else PI - 0.6   # zbraň šikmo dole pred sebou
	aim_angle = lerp_angle(aim_angle, low, minf(1.0, 6.0 * delta))
	if timer <= 0.0:
		state = State.IDLE
		timer = randf_range(0.8, 1.6)
		if randf() < 0.5:
			walk_dir = -walk_dir


## Stojí na mieste otočený „domov“; ak má look_back, občas sa na chvíľu obzrie dozadu.
func _stand(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	var low: float = 0.6 if facing > 0.0 else PI - 0.6
	aim_angle = lerp_angle(aim_angle, low, minf(1.0, 6.0 * delta))
	if look_back == Vector2.ZERO:
		if facing != home_facing:
			_set_facing(home_facing)
		return
	look_timer -= delta
	if look_timer <= 0.0:
		if facing == home_facing:
			_set_facing(-home_facing)      # obzrie sa
			look_timer = 1.6
		else:
			_set_facing(home_facing)
			look_timer = randf_range(look_back.x, look_back.y)


# ---------------------------------------------------------------- kamaráti a hluk

## Hluk (napr. Riccov výstrel): gangstri do vzdialenosti radius sa idú pozrieť, odkiaľ prišiel
static func noise(pos: Vector2, radius: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	radius = _masked(tree, pos, radius)
	for n in tree.get_nodes_in_group(&"enemies"):
		var g := n as Gangster
		if g and g.global_position.distance_to(pos) < radius:
			g.hear(pos)


## Hluk pri hučiacom stroji (skupina „noise_masks“ – napr. čerpadlo v pivnici vily, levels/level4/pump.gd) počuť len zblízka:
## každý taký uzol má mask(pos, radius) -> float a vráti zmenšený dosah zvuku
static func _masked(tree: SceneTree, pos: Vector2, radius: float) -> float:
	for m in tree.get_nodes_in_group(&"noise_masks"):
		if m.has_method(&"mask"):
			radius = m.mask(pos, radius)
	return radius


## Riccov výstrel: kto má výhľad na ústie (pozerá sa tým smerom a nič nie je medzi nimi), uvidí záblesk aj v tme
## a vie, kde Ricco je; ostatní do radius výstrel počujú a idú sa pozrieť
static func gunshot(pos: Vector2, radius: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	Guest.panic(pos, radius)   # smútiaci (world/npc/guest.gd, flee) pred streľbou utečú
	radius = _masked(tree, pos, radius)   # záblesk (_sees_flash) vidno aj tak, len rana sa stratí v hluku
	for n in tree.get_nodes_in_group(&"enemies"):
		var g := n as Gangster
		if g == null or g.state == State.DEAD or g.passive:
			continue
		var d: float = g.global_position.distance_to(pos)
		if d > radius:
			continue
		if g._sees_flash(pos):
			g._aggro = maxf(g._aggro, 3.0)
			if g.state in [State.PATROL, State.IDLE, State.INVESTIGATE]:
				g._set_facing(signf(pos.x - g.global_position.x) if absf(pos.x - g.global_position.x) > 2.0 else g.facing)
				g._show_alert_mark()
		else:
			g.hear(pos)


func _sees_flash(pos: Vector2) -> bool:
	var eye := global_position + Vector2(EYE.x * facing, EYE.y)
	var dx: float = pos.x - global_position.x
	if eye.distance_to(pos) > sight_range * 1.4 or (absf(dx) > 30.0 and signf(dx) != facing and state not in [State.INVESTIGATE]):
		return false
	var q := PhysicsRayQueryParameters2D.create(eye, pos + Vector2(0, -19), 1 | COVER_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Počul niečo na pos – zarazí sa („?“), ide sa tam pozrieť, obzrie sa a vráti sa
func hear(pos: Vector2) -> void:
	if passive or state not in [State.PATROL, State.IDLE, State.INVESTIGATE]:
		return
	_investigate_x = pos.x
	_investigate_phase = 0
	timer = 0.5
	if state != State.INVESTIGATE:
		_show_question_mark()
	state = State.INVESTIGATE
	if absf(pos.x - global_position.x) > 2.0:
		_set_facing(signf(pos.x - global_position.x))


## Zložili ho – kto to videl alebo počul tesne vedľa, vie o Riccovi; kto len počul, ide sa pozrieť
func _notify_allies(quiet: bool) -> void:
	var space := get_world_2d().direct_space_state
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var g := n as Gangster
		if g == null or g == self or g.state == State.DEAD or g.passive:
			continue
		var d: float = g.global_position.distance_to(global_position)
		var dx: float = global_position.x - g.global_position.x
		var looking: bool = absf(dx) < 4.0 or signf(dx) == g.facing
		var clear: bool = space.intersect_ray(PhysicsRayQueryParameters2D.create(
				g.global_position + Vector2(0, -60), global_position + Vector2(0, -40), 1)).is_empty()
		if clear and (d < HEAR_SCUFFLE or (looking and d < SEE_BODY)):
			g._aggro = maxf(g._aggro, 4.0)   # videl to – vie, kde je Ricco (aj v tme)
			g._set_facing(signf(dx) if dx != 0.0 else g.facing)
			if g.state in [State.PATROL, State.IDLE, State.INVESTIGATE]:
				g._show_alert_mark()
		elif d < (HEAR_BODY * (0.6 if quiet else 1.0)):
			g.hear(global_position)


## Je pred ním (v smere dir) kamarát bližšie ako dist? chasing = počíta len toho, kto je bližšie k Riccovi
func _ally_ahead(dir: float, dist: float, chasing: bool = false) -> bool:
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var g := n as Gangster
		if g == null or g == self or g.state == State.DEAD:
			continue
		var dx: float = g.global_position.x - global_position.x
		if signf(dx) == dir and absf(dx) < dist and absf(g.global_position.y - global_position.y) < 24.0:
			if not chasing or g.state in [State.CHASE, State.WINDUP, State.PUNCH, State.RECOVER]:
				return true
	return false


func _investigate(delta: float) -> void:
	var low: float = 0.6 if facing > 0.0 else PI - 0.6
	aim_angle = lerp_angle(aim_angle, low, minf(1.0, 6.0 * delta))
	match _investigate_phase:
		0:   # zarazí sa
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if timer <= 0.0:
				_investigate_phase = 1
				timer = 6.0
		1:   # ide tam (opatrne, trochu rýchlejšie ako na hliadke)
			var dx: float = _investigate_x - global_position.x
			var blocked: bool = is_on_wall() and not _try_hop(signf(dx), walk_speed * 1.3) and _hop_dir == 0.0
			if absf(dx) < 10.0 or timer <= 0.0 or blocked or not _ledge_ok(signf(dx), CHASE_DROP) or _ally_ahead(signf(dx), KEEP_APART):
				velocity.x = 0.0
				_investigate_phase = 2
				timer = 2.4
				look_timer = 0.8
			else:
				_set_facing(signf(dx))
				velocity.x = signf(dx) * (maxf(run_speed, walk_speed * 2.2) if relentless else walk_speed * 1.3)
		2:   # obzerá sa
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			look_timer -= delta
			if look_timer <= 0.0:
				_set_facing(-facing)
				look_timer = 0.8
			if timer <= 0.0:
				_investigate_phase = 3
				timer = 8.0
		3:   # vracia sa (stráž na svoje miesto, hliadka pokračuje)
			var hx: float = spawn_pos.x - global_position.x
			var blocked: bool = is_on_wall() and not _try_hop(signf(hx), walk_speed) and _hop_dir == 0.0
			if not stationary or absf(hx) < 4.0 or timer <= 0.0 or blocked or not _ledge_ok(signf(hx), CHASE_DROP):
				velocity.x = 0.0
				if stationary:
					_set_facing(home_facing)
				if _question_mark:
					_question_mark.visible = false
				state = State.PATROL
				timer = randf_range(patrol_time.x, patrol_time.y)
			else:
				_set_facing(signf(hx))
				velocity.x = signf(hx) * walk_speed


## „?“ nad hlavou – niečo počul, ešte nevie čo
func _show_question_mark() -> void:
	if _question_mark == null:
		_question_mark = Label.new()
		_question_mark.text = "?"
		_question_mark.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
		_question_mark.add_theme_font_size_override(&"font_size", 16)
		_question_mark.add_theme_color_override(&"font_color", Color8(200, 200, 210))
		_question_mark.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
		_question_mark.add_theme_constant_override(&"outline_size", 4)
		_question_mark.position = Vector2(-4, -100)
		_question_mark.z_index = 30
		_question_mark.self_modulate.a = 1.0 - _wall_cover
		add_child(_question_mark)
	_question_mark.visible = true
	_question_mark.modulate.a = 1.0
	Sfx.play(&"alert", global_position + Vector2(0, -60), -12.0, 0.02)


## Je pred ním zem? (lúč dole kúsok pred nohami) – aby nespadol z plošiny
## drop = ako hlboko môže byť zem (na hliadke 14 px, keď ide za Riccom CHASE_DROP – zoskočí z debny)
func _ledge_ok(dir: float, drop: float = 14.0) -> bool:
	if not is_on_floor():
		return true
	var from := global_position + Vector2(dir * 14.0, -4.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, drop), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Prekážka pred ním (debna, sud): ak je nízka (do HOP_MAX) a nad ňou je voľno, vyskočí na ňu / cez ňu.
## Výšku zistí lúčmi pred sebou po 4 px nahor. Vráti true, ak skočil. Godot docs: classes/class_physicsdirectspacestate2d
func _try_hop(dir: float, speed: float) -> bool:
	if dir == 0.0 or not is_on_floor() or _hop_cool > 0.0 or _hop_dir != 0.0:
		return false
	var space := get_world_2d().direct_space_state
	var base := global_position
	var low := PhysicsRayQueryParameters2D.create(base + Vector2(0, -6), base + Vector2(dir * 22.0, -6), 1)
	low.exclude = [get_rid()]
	if space.intersect_ray(low).is_empty():
		return false
	var h: float = 10.0
	while h <= HOP_MAX:
		var q := PhysicsRayQueryParameters2D.create(base + Vector2(0, -h), base + Vector2(dir * 26.0, -h), 1)
		q.exclude = [get_rid()]
		if space.intersect_ray(q).is_empty():
			break
		h += 4.0
	if h > HOP_MAX:
		return false   # vysoká stena – neskočí
	# nad sebou aj nad prekážkou musí byť miesto (strop, plošina)
	var top: float = -66.0 - h - 6.0
	var up := PhysicsRayQueryParameters2D.create(base + Vector2(0, -60), base + Vector2(dir * 20.0, top), 1)
	up.exclude = [get_rid()]
	if not space.intersect_ray(up).is_empty():
		return false
	velocity.y = -sqrt(2.0 * get_gravity().y * (h + 12.0))
	_hop_dir = dir
	_hop_speed = maxf(speed, 60.0)
	_hop_air = false
	_hop_cool = 0.5
	_set_facing(dir)
	return true


func _player_target() -> Vector2:
	# hruď/hlava Ricca; pri šmyku je nižšie, skrčený za krytom tiež (pohľad aj guľky zastaví kryt)
	var h: float = 26.0
	if player.get("state") == 4:
		h = 12.0
	elif player.get(&"ducked"):
		h = 10.0
	return player.global_position + Vector2(0, -h)


func _player_dist() -> float:
	return global_position.distance_to(player.global_position)


func _can_see_player() -> bool:
	if player == null or player.get("state") == 3 or passive:   # Ricco mŕtvy / nevšíma si ho
		return false
	if not _on_screen():
		return false   # nestrieľa spoza obrazovky – hráč ho musí vidieť
	if player.get(&"submerged"):
		return false   # Ricco je pod hladinou – nevidno ho
	var eye := global_position + Vector2(EYE.x * facing, EYE.y)
	var target := _player_target()
	var d: float = eye.distance_to(target)
	if d > sight_range:
		return false
	var dx: float = target.x - global_position.x
	var alerted: bool = state in [State.AIM, State.SHOOT, State.COOLDOWN, State.CHASE, State.WINDUP, State.RECOVER]
	if _aggro > 0.0:
		pass   # nahnevaný (po klobúku) – vie, kde Ricco je
	elif needs_light:
		# zakrádanie: za chrbtom ani v tme nevidí – len keď je Ricco celkom blízko (počuje ho)
		# v tme pred sebou ho rozozná zblízka (DARK_SIGHT) – aj prikrčeného; zakrádanie len tlmí kroky (počuť ho za chrbtom)
		var lit: bool = player.has_method(&"is_lit") and player.is_lit()
		var dy: float = absf(player.global_position.y - global_position.y)
		var ahead: bool = signf(dx) == facing
		var pv: Variant = player.get(&"velocity")
		var moving: bool = pv is Vector2 and absf((pv as Vector2).x) > 20.0
		var sense: float = close_sense
		if player.get(&"sneaking"):
			sense = close_sense * 0.45   # potichu – za chrbtom ho počuje len celkom zblízka
		elif moving:
			sense = maxf(close_sense, HEAR_STEPS)   # normálne kroky počuť ďalej
		var near: bool = absf(dx) < sense and dy < 40.0   # tesne vedľa, na tej istej úrovni
		if ahead and absf(dx) < DARK_SIGHT and dy < 60.0:
			near = true   # stojí mu pred nosom – v tme ho vidí aj prikrčeného
		if state == State.INVESTIGATE and absf(dx) < 70.0:
			near = true   # pozorne sa obzerá – zblízka si ho všimne aj v tme
		if not alerted and not ahead and not near:
			return false
		if not lit and not near and not (alerted and d < 110.0):
			return false
	elif not alerted and signf(dx) != facing and absf(dx) > 40.0:
		return false   # nevidí za seba
	var q := PhysicsRayQueryParameters2D.create(eye, target, 1 | COVER_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Je gangster na obrazovke? (Godot docs: CanvasItem.get_global_transform_with_canvas – poloha v okne hry)
func _on_screen() -> bool:
	var p: Vector2 = get_global_transform_with_canvas().origin + Vector2(0, -40)
	var r: Rect2 = get_viewport_rect().grow(-12.0)
	return r.has_point(p)


func _face_player() -> void:
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 2.0 and signf(dx) != facing:
		_set_facing(signf(dx))
		aim_angle = PI - aim_angle   # zbraň ostane namierená rovnako vzhľadom na telo


func _track_aim(delta: float) -> void:
	var shoulder := global_position + Vector2(SHOULDER_FRONT.x * facing, SHOULDER_FRONT.y)
	var want: float = (_player_target() - shoulder).angle()
	var step: float = deg_to_rad(aim_turn_speed) * delta
	aim_angle = aim_angle + clampf(angle_difference(aim_angle, want), -step, step)


func _update_laser(on: bool) -> void:
	laser.visible = on and fmod(timer, 0.12) > 0.03   # bliká
	if not laser.visible:
		return
	var from := muzzle.global_position
	var to := from + Vector2.from_angle(aim_angle) * sight_range
	var q := PhysicsRayQueryParameters2D.create(from, to, 1 | 2)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		to = hit.position
	laser.points = PackedVector2Array([from, to])


func _fire() -> void:
	for i in pellets:
		var b := BULLET.instantiate()
		var a: float = randf_range(-spread_deg, spread_deg) if pellets == 1 \
				else lerpf(-spread_deg / 2.0, spread_deg / 2.0, (i + randf()) / pellets)
		b.direction = Vector2.from_angle(aim_angle + deg_to_rad(a))
		b.shooter = self
		b.speed = bullet_speed * (randf_range(0.85, 1.05) if pellets > 1 else 1.0)
		b.lifetime = bullet_lifetime
		if bullet_damage > 0.0:
			b.damage = bullet_damage
		b.hit_mask = 1 | 2 | COVER_LAYER     # svet + Ricco + kryt (mäso, debny)
		b.modulate = Color(1.0, 0.6, 0.5)
		b.global_position = muzzle.global_position
		get_tree().current_scene.add_child(b)
	_flash_t = 0.06
	flash.frame = randi() % 2
	flash.rotation = randf_range(-0.12, 0.12)
	Sfx.shot(weapon, global_position, -3.0)
	Guest.panic(global_position, 400.0)
	arm_front.position.x = SHOULDER_FRONT.x - 2.0   # spätný ráz
	create_tween().tween_property(arm_front, "position:x", SHOULDER_FRONT.x, 0.08)


func _punch() -> void:
	var dx: float = player.global_position.x - global_position.x
	Sfx.play(&"punch_swing", global_position, -4.0)
	if bat:
		_bat_smear()
	if signf(dx) == facing and absf(dx) < punch_range + 8.0 and absf(player.global_position.y - global_position.y) < 40.0:
		Sfx.play(&"punch_hit", global_position)
		if player.has_method("take_damage"):
			player.take_damage(melee_damage, global_position + Vector2(0, -30))
		if hook:
			# hák zachytí Ricca a strhne ho k dokárovi (namiesto odhodenia) – presne pred neho, nie cez neho:
			# rýchlosť, z ktorej ho trenie zastaví na ~22 px od dokára (v² = 2·trenie·dráha)
			var fr: float = player.ground_friction() if player.has_method(&"ground_friction") else 1100.0
			var v: float = minf(sqrt(2.0 * fr * maxf(absf(dx) - 22.0, 0.0)), hook_pull)
			player.velocity = Vector2(-facing * v, -40.0 if v > 0.0 else 0.0)
			Sfx.play(&"hook_catch", player.global_position, -3.0)
		Burst.spawn(get_tree().current_scene, player.global_position + Vector2(0, -22), Vector2(facing, -0.3), Color(1, 0.9, 0.5), 6, 80.0)


## Šmuha za palicou pri švihu – oblúk od náprahu po úder, rýchlo zmizne
func _bat_smear() -> void:
	var c: Vector2 = SHOULDER_FRONT + Vector2(float(BAT_SWING[2]), 0.0) + (BAT_SWING[0] as Vector2)
	var a0: float = BAT_WINDUP[1]
	var a1: float = BAT_SWING[1]
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 12
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / n)
		outer.append(c + Vector2.from_angle(a) * 38.0)
		inner.append(c + Vector2.from_angle(a) * (18.0 + 6.0 * i / n))
	for i in n + 1:
		cols.append(Color(1.0, 0.96, 0.88, 0.1 + 0.45 * i / n))
	for i in range(n, -1, -1):
		cols.append(Color(1.0, 0.96, 0.88, 0.1 + 0.45 * i / n))
	inner.reverse()
	var p := Polygon2D.new()
	p.polygon = outer + inner
	p.vertex_colors = cols
	rig.add_child(p)
	rig.move_child(p, arm_front.get_index())   # pod rukou s palicou
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 0.0, 0.16)
	tw.tween_callback(p.queue_free)


# ---------------------------------------------------------------- zásahy

## Guľka (alebo broky) od Ricca
## Zásah guľkou aj s miestom zásahu (weapons/pistol/bullet.gd). Vesta chráni trup (od krku po opasok) – iskry, zlomok damage.
func take_hit_at(damage: float, dir: Vector2, pos: Vector2) -> void:
	var y: float = pos.y - global_position.y
	if vest and state != State.DEAD and y > NECK.y + 2.0 and y < HIP.y + 6.0:
		Burst.spawn(get_tree().current_scene, pos, -dir + Vector2(0, -0.4), Color(1.0, 0.85, 0.45), 7, 110.0)
		Sfx.play(&"vest_hit", pos, -2.0, 0.1)
		take_hit(damage * vest_factor, dir, false)
		return
	take_hit(damage, dir)


const HIT_RED := Color(2.2, 0.42, 0.38)   ## farba tela hneď po zásahu (potom sa vráti k pôvodnej)
var _tint_tw: Tween
var _base_tint: Color = Color.WHITE


## Krátke zafarbenie tela (zásah, omráčenie) – potom späť na pôvodnú farbu (napr. NIGHT na cintoríne, nie biela)
## Godot docs: classes/class_tween
func _tint_flash(col: Color, t: float) -> void:
	if _tint_tw and _tint_tw.is_running():
		_tint_tw.kill()   # ešte doznieva predchádzajúci – základ ostáva
	else:
		_base_tint = rig.modulate
	rig.modulate = col
	_tint_tw = create_tween()
	_tint_tw.tween_property(rig, "modulate", _base_tint, t)


func take_hit(damage: float, dir: Vector2, blood: bool = true) -> void:
	if state == State.DEAD:
		return
	passive = false
	health -= damage
	if blood:
		Sfx.play(&"impact_body", global_position + Vector2(0, -40), -2.0)
		Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -44), dir + Vector2(0, -0.3),
				Color(0.62, 0.05, 0.05), 6, 90.0, Vector2(0, 520), 0.5)
	_tint_flash(HIT_RED, 0.22)   # zásah = krátko sčervenie
	if health <= 0:
		_die(dir)
		return
	velocity.x = dir.x * 60.0
	# vie, odkiaľ guľka prišla – aj z tmy (needs_light) Ricca uvidí a strieľa späť
	_aggro = maxf(_aggro, HIT_AGGRO)
	if is_instance_valid(player):
		_last_seen = player.global_position
	# zásah ho vyruší – otočí sa k Riccovi a začne odznova mieriť (alebo beží k nemu)
	if state in [State.PATROL, State.IDLE, State.INVESTIGATE]:
		_alert()
	elif state == State.AIM:
		timer = maxf(timer, aim_time * 0.5)


## Dá sa zneškodniť potichu? Zozadu, keď o Riccovi nevie – alebo kedykoľvek, kým je omráčený klobúkom.
func can_takedown(from_x: float) -> bool:
	if state == State.DEAD:
		return false
	if state == State.STUN:
		return true
	var behind: bool = signf(from_x - global_position.x) != facing
	return behind and _aggro <= 0.0 and state in [State.PATROL, State.IDLE, State.INVESTIGATE]


## Tiché zneškodnenie (Ricco ho omráči úderom krídla) – padne bez krvi, nad hlavou mu zakrúžia hviezdičky
func takedown(dir: Vector2) -> void:
	if state == State.DEAD:
		return
	health = 0
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -66), Vector2.UP,
			Color(1.0, 0.86, 0.35), 8, 60.0, Vector2(0, 60), 0.6)
	_tint_flash(Color(2, 2, 2), 0.15)
	_die(dir, true)


## Podkopnutie: Ricco do neho vletí šmykom po bruchu – nohy mu podrazí, padne na chrbát (hlavou proti smeru šmyku),
## klobúk mu odletí. Kým leží (trip_time), nestrieľa a dá sa zneškodniť (F). Potom sa postaví a ide po Riccovi.
## Vráti true, ak ho naozaj zvalil.
func trip(dir: float) -> bool:
	if state == State.DEAD or _tripped:
		return false
	_tripped = true
	passive = false
	state = State.STUN
	timer = trip_time
	shots_left = 0
	laser.visible = false
	_aggro = 6.0
	if _question_mark:
		_question_mark.visible = false
	velocity.x = dir * 50.0
	_knock_hat(Vector2(dir, -1.0))
	Sfx.play(&"takedown", global_position + Vector2(0, -20), -4.0)
	Sfx.play(&"land", global_position, -2.0, 0.1)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(-dir * 20.0, -2), Vector2(-dir, -0.5),
			Color(0.75, 0.75, 0.8, 0.6), 8, 50.0, Vector2(0, 40), 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(rig, "rotation", -PI / 2.0 * dir * 0.94, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(leg_front, "rotation", -0.5 * dir * facing, 0.25)
	tw.tween_property(leg_back, "rotation", -0.3 * dir * facing, 0.25)
	tw.tween_property(arm_front, "rotation", -2.0, 0.3)
	tw.tween_property(arm_back, "rotation", -2.3, 0.3)
	return true


const GETUP_TIME := 0.72   ## s – vstávanie po podkopnutí (posadí sa → kľakne → postaví sa)

## Po podkopnutí vstane: posadí sa a opiera sa rukami za sebou, pritiahne nohy a kľakne si, odrazí sa a postaví sa.
## Kostra sa otáča okolo nôh, preto sa pri sede a kľaku posúva (bok ostane pri zemi). Uhly končatín sú v kostre
## otočenej podľa facing (rig.scale.x) – svetový uhol = rotácia kostry + facing · uhol časti.
func _stand_up() -> void:
	var d: float = -signf(rig.rotation) if rig.rotation != 0.0 else facing   # smer k nohám (kam išiel Riccov šmyk)
	var f: float = facing
	_tripped = false
	_getting_up = true
	if _getup_tween:
		_getup_tween.kill()
	# 1) posadí sa – trup zaklonený, nohy vystreté po zemi, ruky za sebou opreté o zem
	var r1: float = -d * 0.45
	var arm1: float = _arm_local(PI / 2.0 + d * 0.64, r1, f)
	# 2) kľakne si – predklon nad nohami, predná noha pokrčená vpred, zadné koleno na zemi, ruka na kolene
	var r2: float = d * 0.25
	var arm2: float = _arm_local(PI / 2.0 - d * 0.785, r2, f)
	var tw := create_tween()
	_getup_tween = tw
	tw.tween_property(rig, "rotation", r1, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rig, "position", Vector2(-11.8 * d, 20.2), 0.22)
	tw.parallel().tween_property(leg_front, "rotation", -0.95 * d * f, 0.22)
	tw.parallel().tween_property(leg_back, "rotation", -1.1 * d * f, 0.22)
	tw.parallel().tween_property(arm_front, "rotation", arm1, 0.18)
	tw.parallel().tween_property(arm_back, "rotation", arm1 + 0.15, 0.18)
	tw.parallel().tween_property(head, "rotation", d * f * 0.2, 0.22)   # hlava ešte ovisnutá
	tw.tween_interval(0.08)
	tw.tween_callback(func():
		Sfx.play(&"land", global_position, -10.0, 0.1)
		Burst.spawn(get_tree().current_scene, global_position + Vector2(-d * 10.0, -2), Vector2(0, -1),
				Color(0.75, 0.75, 0.8, 0.5), 5, 30.0, Vector2(0, 30), 0.5))
	tw.tween_property(rig, "rotation", r2, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(rig, "position", Vector2(-14.9 * d, 11.1), 0.2)
	tw.parallel().tween_property(leg_front, "rotation", -1.03 * d * f, 0.2)
	tw.parallel().tween_property(leg_back, "rotation", 0.11 * d * f, 0.2)
	tw.parallel().tween_property(arm_front, "rotation", arm2, 0.2)
	tw.parallel().tween_property(arm_back, "rotation", arm2 + 0.3, 0.2)
	tw.parallel().tween_property(head, "rotation", 0.0, 0.2)
	# 3) odrazí sa a postaví (trochu prestrelí a dorovná sa)
	tw.tween_property(rig, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rig, "position", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(leg_front, "rotation", 0.0, 0.2)
	tw.parallel().tween_property(leg_back, "rotation", 0.0, 0.2)
	tw.tween_callback(func():
		_getting_up = false
		_getup_tween = null)


## Uhol ruky v kostre pre svetový uhol w (0 = doprava, PI/2 = dole) pri rotácii kostry r – ruka smeruje po svojej osi x,
## v zrkadlenej kostre (facing −1) sa jej uhol prevráti: svet = r + PI − uhol
func _arm_local(w: float, r: float, f: float) -> float:
	return (w - r) if f > 0.0 else (PI + r - w)


## Riccov hodený klobúk: omráči ho a zhodí mu klobúk
func hat_hit(damage: int, dir: Vector2) -> void:
	if state == State.DEAD:
		return
	_knock_hat(dir)
	Sfx.play(&"hat_bonk", global_position + Vector2(0, -60))
	take_hit(damage, dir)
	if state != State.DEAD:
		state = State.STUN
		timer = 1.4
		laser.visible = false
		_aggro = 6.0   # nasere sa – po omráčení ide po Riccovi


func _knock_hat(dir: Vector2) -> void:
	if hat == null or not hat.visible:
		return
	hat.visible = false
	var d := DROP.instantiate()
	d.texture = hat.texture
	d.life = 3.0
	get_tree().current_scene.add_child(d)
	d.global_position = hat.global_position
	d.velocity = Vector2(dir.x * 60.0, -170.0)
	d.spin = randf_range(-10.0, 10.0)


func _die(dir: Vector2, quiet: bool = false) -> void:
	state = State.DEAD
	if _question_mark:
		_question_mark.visible = false
	_notify_allies(quiet)
	Sfx.play(&"enemy_death", global_position, -2.0)
	laser.visible = false
	if _flash:
		for c in _flash.get_children():
			if c is LightZone:
				c.switch_off()
		_flash.visible = false
	collision_layer = 0   # guľky ním preletia
	var fall: float = signf(dir.x) if dir.x != 0.0 else -facing   # padá v smere strely
	if _tripped and rig.rotation != 0.0:
		fall = signf(rig.rotation)   # už leží – ostane ležať na tú istú stranu
	_tripped = false
	if _getup_tween:   # zložený počas vstávania
		_getup_tween.kill()
		_getup_tween = null
	_getting_up = false
	velocity = Vector2(fall * 80.0, -90.0)
	_knock_hat(dir)
	# zbraň vyletí z ruky a ostane ležať – Ricco ju môže zobrať (weapons/weapon_pickup.gd)
	if gun and drops_weapon:
		var d := WEAPON_PICKUP.new()
		d.weapon = weapon
		d.ammo = weapon.mag_size
		d.texture = gun.texture
		d.velocity = Vector2(fall * 70.0, -120.0)
		d.spin = randf_range(-8.0, 8.0)
		get_tree().current_scene.add_child.call_deferred(d)
		d.position = gun.global_position + Vector2(gun.texture.get_width() * 0.5 * facing, 4)   # current_scene je v počiatku
		gun.visible = false
		for c in arm_front.get_children():
			if c is Sprite2D and c != gun and c != flash:
				if (c as Sprite2D).region_enabled:
					c.visible = false
	# padne na chrbát (otáča sa okolo nôh), ruky a nohy ochabnú
	var tw := create_tween().set_parallel(true)
	var lie: float = PI / 2.0 * fall   # rotácia sa skladá až po zrkadlení (scale) → smer je v obrazovke
	tw.tween_property(rig, "rotation", lie, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(rig, "position:y", -4.0, 0.45)
	tw.tween_property(arm_front, "rotation", randf_range(-2.4, -1.6), 0.4)
	tw.tween_property(arm_back, "rotation", randf_range(-2.6, -1.8), 0.4)
	tw.tween_property(leg_front, "rotation", -0.3, 0.4)
	tw.tween_property(leg_back, "rotation", 0.25, 0.4)
	tw.tween_property(head, "rotation", -0.4, 0.4)
	# krabička nábojov – len od toho, kto mal strelnú zbraň (päste, palica a hák nemajú čo stratiť)
	if weapon:
		var a := AMMO.instantiate()
		get_tree().current_scene.add_child.call_deferred(a)
		a.position = global_position + Vector2(0, -8)   # current_scene je v počiatku
	# v test room sa po chvíli objaví znova
	var fade := create_tween()
	fade.tween_interval(3.0)
	fade.tween_property(rig, "modulate:a", 0.0, 1.0)
	fade.tween_callback(_respawn_or_free)


func _respawn_or_free() -> void:
	if respawn_time > 0.0 and scene_file_path != "":
		var t := get_tree().create_timer(maxf(respawn_time - 4.0, 0.1), false)
		var parent := get_parent()
		var path := scene_file_path
		var pos := spawn_pos
		t.timeout.connect(func():
			var g: Node2D = load(path).instantiate()
			g.position = pos
			parent.add_child(g))
	queue_free()


# ---------------------------------------------------------------- pohyb častí tela

func _animate(delta: float) -> void:
	if state == State.DEAD:
		return
	if _tripped:   # leží na chrbte (podkopnutý) – telo sa nehýbe
		rig.position.y = -3.0
		return
	if _getting_up:   # vstáva – pózy robí tween (_stand_up)
		return
	# na schodoch (45° rampa) je spodok kapsuly ~4 px nad svahom a schodíky sú pod rampou ešte 0–4 px –
	# postava ide o 6 px nižšie, aby stála na schodíkoch, nie nad nimi
	rig.position.y = 6.0 if is_on_floor() and get_floor_normal().y > -0.9 else 0.0
	var moving: bool = absf(velocity.x) > 5.0 and is_on_floor()
	if moving:
		walk_phase += absf(velocity.x) * delta / 9.0
	else:
		walk_phase = lerpf(walk_phase, roundf(walk_phase / PI) * PI, minf(1.0, 10.0 * delta))
	var swing: float = sin(walk_phase) * (0.5 if run_speed > 0.0 and state == State.CHASE else 0.4)
	leg_front.rotation = swing
	leg_back.rotation = -swing
	var bob: float = -absf(sin(walk_phase)) * 1.0
	torso.position.y = HIP.y + bob
	head.position.y = NECK.y + bob
	if hat:
		hat.position.y = HAT_AT.y + bob
	# omráčený: hlava sa kýve
	head.rotation = sin(Time.get_ticks_msec() * 0.02) * 0.25 if state == State.STUN else 0.0
	# ruky
	if weapon:
		arm_front.rotation = _arm_rot(aim_angle)
		# zadná ruka k predku zbrane (dvojručné), inak sa kýve
		if weapon.two_handed and gun:
			var fg: Vector2 = gun.to_global(weapon.foregrip_px + Vector2(1, 2))
			var sb: Vector2 = arm_back.global_position
			arm_back.rotation = _arm_rot((fg - sb).angle())
		else:
			arm_back.rotation = PI / 2.0 - 0.2 - swing * 0.6
	elif _segmented:
		_animate_arms(delta, swing)
	else:
		match state:
			State.WINDUP:
				arm_front.rotation = lerp_angle(arm_front.rotation, -2.2, minf(1.0, 14.0 * delta))
				arm_back.rotation = lerp_angle(arm_back.rotation, -0.6, minf(1.0, 10.0 * delta))
			State.PUNCH:
				arm_front.rotation = -0.05
			_:
				var guard: bool = state in [State.CHASE, State.RECOVER]
				arm_front.rotation = lerp_angle(arm_front.rotation, (-0.5 if guard else PI / 2.0 - 0.3) + swing * 0.5, minf(1.0, 10.0 * delta))
				arm_back.rotation = lerp_angle(arm_back.rotation, (-0.3 if guard else PI / 2.0 - 0.1) - swing * 0.5, minf(1.0, 10.0 * delta))


## Dvojdielne ruky: pózy podľa stavu, plynulo k nim; palicu držia obe ruky (IK)
func _animate_arms(delta: float, swing: float) -> void:
	if bat:
		_animate_bat(delta, swing)
		return
	var pose: Array = POSE_IDLE
	var rate: float = 10.0
	match state:
		State.WINDUP:
			pose = POSE_WINDUP
			rate = 12.0
		State.PUNCH:
			pose = POSE_PUNCH
			rate = 40.0
		State.CHASE, State.RECOVER:
			pose = POSE_GUARD
	var sw: float = swing * (0.2 if pose == POSE_GUARD else 0.5)
	var k: float = minf(1.0, rate * delta)
	_bend_arm(arm_front, fore_front, pose[0] + sw, pose[1] + sw, k)
	_bend_arm(arm_back, fore_back, pose[2] - sw, pose[3] - sw, k)
	_set_lean(lerpf(_lean, pose[4], k))


func _animate_bat(delta: float, swing: float) -> void:
	var pose: Array = BAT_IDLE
	var rate: float = 8.0
	match state:
		State.CHASE:
			pose = BAT_GUARD
		State.WINDUP:
			pose = BAT_WINDUP
			rate = 10.0
		State.PUNCH:
			pose = BAT_SWING
			rate = 40.0
		State.RECOVER:
			pose = BAT_FOLLOW if timer > recover_time * 0.5 else BAT_GUARD
	var k: float = minf(1.0, rate * delta)
	_hand = _hand.lerp(pose[0], k)
	_bat_angle = lerpf(_bat_angle, pose[1], k)   # bez zalomenia uhla – švih ide hore a cez hlavu
	_set_lean(lerpf(_lean, pose[2], k))
	var bend: float = 1.0 if _bat_angle > -1.5 else -1.0
	var f: Array = _ik(_hand, bend)
	arm_front.rotation = f[0]
	fore_front.rotation = f[1] - f[0]
	bat.rotation = _bat_angle - f[1]
	if pose == BAT_IDLE:
		_bend_arm(arm_back, fore_back, POSE_IDLE[2] - swing * 0.5, POSE_IDLE[3] - swing * 0.5, k)
	else:
		# zadná ruka chytí palicu kúsok bližšie k rúčke
		var grip2: Vector2 = SHOULDER_FRONT - SHOULDER_BACK + _hand - Vector2.from_angle(_bat_angle) * 4.0
		var b: Array = _ik(grip2, bend)
		arm_back.rotation = b[0]
		fore_back.rotation = b[1] - b[0]


func _bend_arm(up: Node2D, fore: Node2D, a1: float, a2: float, k: float) -> void:
	up.rotation = lerp_angle(up.rotation, a1, k)
	fore.rotation = lerp_angle(fore.rotation, a2 - a1, k)


## Dve kosti (nadlaktie + predlaktie) k bodu t voči plecu → [uhol nadlaktia, uhol predlaktia]
func _ik(t: Vector2, bend: float) -> Array:
	var d: float = clampf(t.length(), absf(UPPER_LEN - FORE_LEN) + 0.01, UPPER_LEN + FORE_LEN - 0.01)
	var c: float = clampf((UPPER_LEN * UPPER_LEN + d * d - FORE_LEN * FORE_LEN) / (2.0 * UPPER_LEN * d), -1.0, 1.0)
	var a1: float = t.angle() + acos(c) * bend
	var elbow := Vector2.from_angle(a1) * UPPER_LEN
	return [a1, (t - elbow).angle()]


## Náklon tela (px): hlava a ramená sa posunú celé, trup napoly – na celé pixely
func _set_lean(l: float) -> void:
	_lean = l
	var px: float = roundf(l)
	torso.position.x = HIP.x + roundf(l * 0.5)
	head.position.x = NECK.x + px
	if hat:
		hat.position.x = HAT_AT.x + px
	arm_front.position.x = SHOULDER_FRONT.x + px
	arm_back.position.x = SHOULDER_BACK.x + px
