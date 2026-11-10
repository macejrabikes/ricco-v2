extends CharacterBody2D
## Ricco – hráč.
## krok 1: chôdza a skok (podľa "Platformer movement" v Godot docs, tutorials/physics/using_character_body_2d)
## krok 2: animácie (characters/ricco/ricco_frames.tres)
## krok 3: pocit zo skoku (coyote time, jump buffer, variabilná výška)
## krok 4: wall slide + wall jump – len od stien, nie od plošiniek (skupina "platform")
## krok 5: zavesenie na okraj (ledge grab) a vylezenie hore (animácie hang/climb sú zarovnané na roh hrany)
## krok 6: mierenie myšou, streľba z pištole, hod klobúka (bumerang)
## krok 7: zásobník, prebíjanie, vypadnutý zásobník
## krok 7b: zbraň drží ruka ducha zavraždeného Dona (characters/ricco/ghost_hand)
## krok 7c: prebíjanie druhou rukou ducha – starý zásobník vypadne, nový sa zasunie
## krok 8: spomalenie času cez ducha Dona (characters/ricco/focus)
## krok 9: zdravie (HP) – zásah, krátka nesmrteľnosť s blikaním, smrť a reštart levelu
## krok 10: nový beh (labky sa striedajú), cúvanie = beh pustený odzadu, prach pri dopade labky
## krok 11: animácie bez klobúka (kým letí), krv a červený záblesk pri zásahu, bez poskoku
## krok 12: šmyk po bruchu (S / Ctrl / šípka dole) – nižší, rýchly, dá sa pri ňom strieľať všetkými smermi
## krok 13: viac zbraní (weapons/*.tres – WeaponData): pištoľ, revolver, Tommy gun, lupara; 1–3 / koliesko / Q
## krok 14: zbrane zo zeme (weapons/weapon_pickup.gd), výbava = 1 bočná (kláves 1) + 2 hlavné (2, 3), F = výmena
## krok 15: derringer a lupara (lámacie prebíjanie – hlavne sa vyklopia), rozptyl rastie pri streľbe za sebou (WeaponData Accuracy)
## krok 17: plávanie v hlbokej vode (world/water/water_zone.gd) – S = ponor, medzerník = hore / vyskočiť, pod vodou ho nevidno
## krok 16: pocit zásahu (silné zatrasenie, červené okraje obrazovky, hitstop), schody ako šikmá rampa, výstrel počujú gangstri
## krok 18: ľad (dlaždica s vlastnými dátami "ice" alebo telo v skupine "ice") – kĺže sa, šmyk po bruchu je dlhší a rýchlejší;
##          háky na mäso na koľajnici (world/coldstore/hook_rail.gd) – chytí sa vo vzduchu a vezie sa, dá sa pri tom strieľať
## krok 19: rebrík na stene (world/fx/ladder.gd) – skok pri rebríku = chytí sa, W / medzerník hore, S dole, hore sa vyšvihne na hranu
## krok 20: markíza ako trampolína (world/fx/awning.gd – bounce), šnúra s prádlom = jazda na kladke (world/fx/clothesline.gd,
##          rovnako ako hák na mäso – grab_hook / _process_hook)
## krok 21: animácia lezenia po rebríku (sprites/ladder.png – bokom čelom k stene, snímky podľa prelezenej vzdialenosti)
## krok 22: akimbo – druhá ruka ducha drží druhú bočnú zbraň (kláves B pri bočnej zbrani, odomkne sa v kapitole IV).
##          Obe mieria na myš a strieľajú striedavo; zásobník je dvojnásobný, prebíjanie dlhšie, rozptyl väčší.
## Pri behu sa Ricco kýve zo strany na stranu ako tučniak (waddle) – rieši to kód.

enum State { NORMAL, HANG, CLIMB, DEAD, SLIDE, SWIM, HOOK, LADDER }

signal ammo_changed(mag: int, reserve: int, reloading: bool)
signal weapon_changed(weapon: WeaponData)
signal health_changed(health: int, max_health: int)
signal died
signal shot_fired   ## každý výstrel (zameriavač naň krátko „odskočí“)
signal fire_mode_changed(alt: bool)   ## B prepol režim streľby (HUD ukáže pečiatku AUTO/SEMI, 1x/2x)
signal food_changed ## zobral alebo zjedol jedlo (HUD sloty – ui/food_slots.gd)

@export var max_speed: float = 140.0       ## px/s pri behu
@export var sneak_speed: float = 58.0      ## px/s pri zakrádaní (C) – pomalšie, prikrčený, gangstri ho tak ľahko nezacítia
@export var slide_trip_speed: float = 90.0  ## px/s – od tejto rýchlosti šmyk po bruchu podkopne mafiána
@export var takedown_range: float = 44.0   ## px – takto blízko zozadu sa dá gangster potichu zneškodniť
@export var acceleration: float = 900.0    ## ako rýchlo sa rozbehne
@export var friction: float = 1100.0       ## ako rýchlo zastaví, keď pustíš smer
@export var jump_velocity: float = -320.0  ## záporné = hore (os Y ide v Godote dole)

@export_group("Jump feel")
@export var coyote_time: float = 0.1       ## s – skok ešte funguje chvíľu po zídení z hrany
@export var jump_buffer_time: float = 0.12 ## s – stlačenie skoku tesne pred dopadom sa zaráta
@export_range(0.0, 1.0) var jump_cut: float = 0.45  ## pustenie skoku počas stúpania znásobí rýchlosť týmto (menej = nižší krátky skok)
@export_group("")

@export_group("Wall jump")
@export var wall_slide_speed: float = 60.0              ## max. rýchlosť šmýkania po stene (px/s)
@export var wall_jump_velocity: Vector2 = Vector2(170, -300)  ## x = odraz od steny, y = výška
@export var wall_jump_lock_time: float = 0.15           ## s – po odraze chvíľu nejde riadiť späť ku stene
@export var wall_coyote_time: float = 0.08              ## s – odraz funguje chvíľu aj po pustení steny
@export var wall_slide_offset: float = 0.0              ## px – doladenie posunu obrázka od steny (animácia je zarovnaná na stenu)
@export_group("")

@export_group("Ledge grab")
@export var ledge_reach: float = 14.0      ## px – ako ďaleko pred sebou Ricco hľadá hranu
@export var ledge_hang_depth: float = 38.0 ## px – o koľko sú nohy pod hranou, keď visí
@export var ledge_regrab_time: float = 0.3 ## s – po pustení sa hneď znova nechytí
@export var hang_visual_offset: float = 0.0  ## px – doladenie: posun obrázka od steny pri visení
@export_group("")

@export_group("Weapons")
@export var bullet_scene: PackedScene = preload("res://weapons/pistol/bullet.tscn")
@export var hat_scene: PackedScene = preload("res://weapons/hat/hat_projectile.tscn")
## Výbava – zbrane, ktoré Ricco nosí: najprv bočná (SIDEARM, kláves 1), potom max. 2 hlavné (PRIMARY, klávesy 2 a 3).
## Prepína sa 1–3, kolieskom, Q = posledná.
@export var loadout: Array[WeaponData] = [
	preload("res://weapons/derringer/derringer.tres"),
	preload("res://weapons/tommy/tommy.tres"), preload("res://weapons/lupara/lupara.tres")]
@export var shake_strength: float = 2.0       ## zatrasenie kamerou pri výstrele (px)
@export var camera_lean: Vector2 = Vector2(72, 32)   ## px – kamera sa vysunie k myši: myš vpravo → Ricco je vľavo od stredu
@export var camera_lean_speed: float = 5.0      ## ako rýchlo sa kamera presunie, keď myš prejde na druhú stranu
@export var aim_facing: bool = true           ## Ricco sa pozerá tam, kam mieri (ako v My Friend Pedro)
@export_range(0.0, 90.0) var ground_aim_max_down_deg: float = 50.0  ## na zemi sa nedá mieriť strmšie dole (zbraň by išla do podlahy)
@export var magazine_scene: PackedScene = preload("res://weapons/pistol/magazine_drop.tscn")
## Akimbo (druhá bočná zbraň v druhej ruke ducha) sa dá zapnúť klávesom B – level to odomkne (kapitola IV, útek z vily)
@export var akimbo_unlocked: bool = false
@export_group("")

@export_group("Health")
@export var max_health: int = 8               ## 8 = celá pizza v HUD (1 zásah = 1 kúsok)
@export var invulnerable_time: float = 1.0    ## s po zásahu, kedy Ricca nič nezraní (sčervenie a postupne zbledne)
@export var hurt_knockback: Vector2 = Vector2(70, 0)  ## odhodenie od zdroja zásahu (y = 0 → bez poskoku)
@export var respawn_delay: float = 2.5        ## s po smrti, kým sa level reštartuje
@export_group("")

@export_group("Belly slide")
@export var slide_speed: float = 250.0        ## px/s na začiatku šmyku (najmenej; z behu sa pridá slide_boost)
@export var slide_boost: float = 80.0         ## px/s navyše k rýchlosti behu
@export var slide_friction: float = 170.0     ## px/s² – ako rýchlo sa šmyk spomaľuje
@export var slide_min_speed: float = 45.0     ## px/s – pod touto rýchlosťou sa Ricco postaví
@export var slide_aim_height: float = 11.0    ## px nad zemou – kde je zbraň počas šmyku
@export var crawl_speed: float = 55.0         ## px/s – pod nízkym stropom sa Ricco plazí po bruchu (dá sa riadiť)
@export_group("")

@export_group("Swim")
@export var swim_speed: float = 95.0       ## px/s pod vodou
@export var swim_accel: float = 420.0      ## ako rýchlo sa rozpláva
@export var swim_drag: float = 240.0       ## ako rýchlo zastaví, keď pustíš smer
@export var swim_jump: float = -290.0      ## vyskočenie z hladiny (px/s, záporné = hore)
@export var float_depth: float = 16.0      ## px – o koľko sú nohy pod hladinou, keď pláva na hladine
@export_group("")

@export_group("Ice")
@export var ice_acceleration: float = 260.0   ## px/s² – rozbeh na ľade (nohy sa šmýkajú)
@export var ice_friction: float = 120.0       ## px/s² – zastavenie na ľade (ešte kus sa kĺže)
@export var ice_slide_friction: float = 36.0  ## px/s² – šmyk po bruchu na ľade (tučniak je doma – ide skoro donekonečna)
@export var ice_slide_boost: float = 70.0     ## px/s navyše na začiatku šmyku na ľade
@export_group("")

@export_group("Meat hook")
@export var hook_hang: float = 49.0       ## px – o koľko sú nohy pod úchytom háku
@export var hook_reach: float = 18.0      ## px – takto blízko pri úchyte sa hák chytí
@export var hook_jump: float = -250.0     ## px/s – zoskok z háku (skok)
@export var hook_regrab_time: float = 0.35  ## s – po pustení sa hneď znova nechytí
@export_group("")

@export_group("Ladder")
@export var ladder_speed: float = 74.0    ## px/s – lezenie po rebríku hore aj dole
@export var ladder_regrab_time: float = 0.3  ## s – po pustení sa hneď znova nechytí
@export_group("")

@export_group("Waddle")
@export var waddle_angle_deg: float = 4.0  ## max. náklon do strany pri behu
@export var waddle_bob: float = 1.0         ## o koľko px sa pri kroku nadvihne
@export var waddle_step: float = 22.0       ## koľko px prejde za jeden krok
@export_group("")

const HALF_WIDTH := 10.0  ## polomer kapsuly (CollisionShape2D)
const HEIGHT := 38.0      ## výška kapsuly
## Animácia "climb" má framy 96×96 nakreslené tak, že roh hrany je v pixeli (40, 52).
## Tento posun spritu ho zarovná s rohom hrany v hre (rovnako ako pri "hang").
const CLIMB_SPRITE_OFFSET := Vector2(19, -21)
const HOOK_SPRITE_OFFSET := Vector2(-14, 0)   ## animácia hook má úchyt v plutve 14 px vpravo od stredu – hák je presne nad Riccom
## Kde stojí Ricco v poslednom frame "climb" – o koľko px za hranou (stred tela)
const CLIMB_STAND_DISTANCE := 17.0

@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@onready var aim: Node2D = $Aim
@onready var gun: Sprite2D = $Aim/Gun
@onready var muzzle: Marker2D = $Aim/Gun/Muzzle
@onready var flash: Sprite2D = $Aim/Gun/Muzzle/Flash
@onready var camera: Camera2D = $Camera2D
@onready var pcam: PhantomCamera2D = $PhantomCamera2D   ## Phantom Camera – sleduje Ricca s tlmením (addons/phantom_camera)
@onready var mag: Sprite2D = $Aim/Gun/Mag
@onready var offhand: GhostHand = $Aim/Gun/OffHand
@onready var ghost_hand: GhostHand = $Aim/Gun/GhostHand
@onready var focus: Focus = $Focus  ## spomalenie času (duch Dona) – Shift
@onready var body_shape: CollisionShape2D = $CollisionShape2D

## Ktorý frame animácie "hat_throw" je moment, keď klobúk opustí krídlo
const HAT_RELEASE_FRAME := 4
## Najkratší šmyk (s) – aj keď hráč hneď pustí kláves
const SLIDE_MIN_TIME := 0.3
## Kamera mieri na stred Ricca (nie na jeho nohy)
const CAMERA_Y := -20.0
const SLOPE_SINK := 4.0   ## px – o koľko je spodok kapsuly na 45° svahu nad ním: r · (√2 − 1)

var state: State = State.NORMAL
var facing: float = 1.0             ## 1 = doprava, -1 = doľava
var was_on_floor: bool = true
var coyote_timer: float = 0.0       ## koľko ešte zostáva coyote time
var jump_buffer_timer: float = 0.0  ## koľko ešte „platí“ stlačenie skoku
var wall_timer: float = 0.0         ## koľko ešte platí „bol som na stene“
var wall_normal_x: float = 0.0      ## kam smeruje stena od Ricca (+1 = stena je vľavo, odraz doprava)
var wall_lock_timer: float = 0.0    ## po wall jumpe dočasne ignorujeme smer od hráča
var wall_sliding: bool = false
var ledge_cooldown: float = 0.0
var _last_wall_x: float = 0.0   ## smer od steny pri poslednej kontrole nízkej steny
var ledge_top: Vector2 = Vector2.ZERO  ## bod na vrchu hrany, kam Ricco vylezie
var waddle_phase: float = 0.0       ## fáza kolísania (radiány), rastie s prejdenou vzdialenosťou
var aim_dir: Vector2 = Vector2.RIGHT ## smer k myši
var fire_timer: float = 0.0
var shake_timer: float = 0.0
var _lean: Vector2 = Vector2.ZERO
var light_zones: int = 0      ## v koľkých LightZone (svetlo lampy, pece…) práve stojí
var dark_area: bool = false   ## level to zapne v interiéri – mimo svetla je Ricco v tme a gangstri ho nevidia
var in_cutscene: bool = false ## počas cutscény hráč Ricca neovláda (pohyb robí scéna)
var sneaking: bool = false    ## drží C – prikrčený, pomalší
var _sneak_on: bool = false   ## režim TOGGLE (Settings → Controls): C zapne / vypne zakrádanie
var takedown_target: Node2D   ## gangster, ktorého sa dá práve zneškodniť (ukáže sa nápoveda)
var _takedown_t: float = 0.0  ## s – prebieha úder
var _slide_t: float = 0.0     ## s – ako dlho už šmyk trvá
var submerged: bool = false   ## celý pod hladinou – gangstri ho nevidia
var on_ice: bool = false      ## stojí (alebo sa šmýka) na ľade
var _hook: Node2D             ## hák na mäso, na ktorom visí (world/coldstore/hook_rail.gd)
var _hook_cooldown: float = 0.0
var _hook_t: float = 0.0
var _ladder: Node2D           ## rebrík, na ktorom práve je (world/fx/ladder.gd)
var _ladder_cooldown: float = 0.0
var _ladder_step: float = 0.0 ## px – prelezená vzdialenosť od poslednej priečky (cinknutie železa)
var _ladder_dist: float = 0.0 ## px – prelezená vzdialenosť celkom (snímky animácie ladder)
var _swim_cooldown: float = 0.0   ## s – po vyskočení z vody hneď znova nespadne do plávania
var _bubble_t: float = 0.0
var has_hat: bool = true            ## false = klobúk práve letí
var gun_base_x: float = 0.0         ## pokojová poloha pištole (kvôli cuknutiu pri výstrele)
var ammo_in_mag: int = 0
var ammo_reserve: int = 0
var reloading: bool = false
var weapon: WeaponData                ## zbraň v ruke
var weapon_index: int = 0
var last_weapon_index: int = 0
var weapon_ammo: Array = []           ## pre každú zbraň výbavy [v zásobníku, rezerva]
var _reload_tween: Tween
var _barrels: Sprite2D                ## hlavne lámacej zbrane počas prebíjania (dieťa Gun, otáča sa na pánte)
var _pump: Sprite2D                   ## pumpa pumpovačky (dieťa Gun) – po výstrele ide dozadu a dopredu
var _pump_tween: Tween
var _reload_cancel: bool = false      ## pumpovačka: streľba počas nabíjania – dobije náboj v ruke a prestane
var _reload_empty: bool = false       ## nabíjanie začalo s prázdnou zbraňou – na konci treba potiahnuť pumpu
var _bloom: float = 0.0               ## ° – rozptyl navyše zo streľby za sebou (WeaponData.spread_bloom_deg)
var alt_fire: Dictionary = {}         ## WeaponData → true = druhý režim (WeaponData.alt_mode); pamätá sa pre každú zbraň
var _heat: float = 0.0                ## zahriatie hlavne pri streľbe dávkou – viac dymu, po dávke z hlavne chvíľu stúpa dym
var _wisp_t: float = 0.0
var _swap_tween: Tween
var holstered: bool = false           ## zbraň je schovaná (X) – nestrieľa, ruka ducha zmizne
var _holstering: bool = false         ## práve ju schováva (animácia ešte beží, Aim je viditeľný)
var _holster_tween: Tween
var _takedown_frame: int = -1
var _holster_after_reload: bool = false
var eating: bool = false              ## práve je (V, props/food/food.gd) – nestrieľa, ide pomaly
var _eat: RiccoEating                 ## animácie jedenia (characters/ricco/eating.gd)
var _espresso_t: float = 0.0          ## s – po espresse behá rýchlejšie
var in_cover: bool = false            ## drží C tesne pri nízkom kryte (debna, náhrobok, pult)
var ducked: bool = false              ## skrčený za krytom – nízka kapsula, gangstri mieria nižšie (do krytu)
var cover_side: float = 0.0           ## kde je kryt (+1 vpravo, -1 vľavo)
var _cover_pop: float = 0.0           ## s – po výstrele z krytu je chvíľu vystrčený
var cover_shape: CapsuleShape2D       ## nízka kapsula pri skrčení za krytom
var mag_size: int:                    ## pre HUD – veľkosť zásobníka zbrane v ruke (akimbo = oba zásobníky spolu)
	get: return _mag_cap(weapon) if weapon else 0
var reload_time: float:
	get: return weapon.reload_time * (AKIMBO_RELOAD if is_akimbo() else 1.0) if weapon else 1.0
var health: int = 0
var run_backwards: bool = false   ## beh pustený odzadu (Ricco ide opačne, než sa pozerá)
var invulnerable_timer: float = 0.0
const HURT_TINT := Color(1.0, 0.32, 0.3)   ## farba Ricca hneď po zásahu
var slide_dust_timer: float = 0.0
var stand_shape: Shape2D             ## kapsula postavy (pri šmyku sa vymení za nízku)
var slide_shape: CapsuleShape2D      ## ležiaca kapsula pri šmyku
var aim_base_y: float = 0.0


var _takedown_hint: Label

func _ready() -> void:
	_ensure_actions()
	# schody: cez schodíky je neviditeľná šikmá rampa (tools/build_level1.gd – _stair_ramp), Ricco po nej ide plynule
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 16.0         # pri zostupe ostane prilepený na rampe (ani na hornej hrane schodov nevyskočí)
	floor_constant_speed = true      # hore aj dole rovnako rýchlo
	_add_takedown_anim()
	_add_throw_walk_anim()
	_add_hook_anim()
	_add_ladder_anim()
	_takedown_hint = Label.new()
	_takedown_hint.text = KeyBindings.short(&"takedown")
	_takedown_hint.add_theme_font_override(&"font", preload("res://ui/fonts/tiny5.ttf"))
	_takedown_hint.add_theme_font_size_override(&"font_size", 8)
	_takedown_hint.add_theme_color_override(&"font_color", Color8(255, 214, 90))
	_takedown_hint.add_theme_color_override(&"font_outline_color", Color8(14, 10, 12))
	_takedown_hint.add_theme_constant_override(&"outline_size", 4)
	_takedown_hint.top_level = true
	_takedown_hint.z_index = 40
	_takedown_hint.visible = false
	add_child(_takedown_hint)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	flash.visible = false
	_setup_flash()
	add_to_group(&"player")
	_barrels = Sprite2D.new()
	_barrels.centered = false
	_barrels.visible = false
	gun.add_child(_barrels)
	_pump = Sprite2D.new()
	_pump.centered = false
	_pump.visible = false
	gun.add_child(_pump)
	gun.move_child(_pump, mag.get_index() + 1)   # nad telom zbrane, pod rukou ducha
	_setup_akimbo()
	for w in loadout:
		weapon_ammo.append([w.mag_size, w.reserve_start])
	_equip(0, false)
	health = max_health
	stand_shape = body_shape.shape
	slide_shape = CapsuleShape2D.new()
	slide_shape.radius = 12.0
	slide_shape.height = 36.0   # ležiaca kapsula (otočená o 90°), 24 px vysoká ako ležiaci Ricco
	aim_base_y = aim.position.y
	cover_shape = CapsuleShape2D.new()
	cover_shape.radius = HALF_WIDTH
	cover_shape.height = COVER_HEIGHT
	_eat = RiccoEating.new()
	visual.add_child(_eat)
	_eat.setup(sprite)
	_eat.gulped.connect(_on_gulped)
	_eat.finished.connect(_on_eat_finished)


func _process(delta: float) -> void:
	_update_camera_lean(delta)
	# v tme stmavne – hráč vidí, že je skrytý
	var shade := Color.WHITE if is_lit() else Color(0.48, 0.48, 0.64)
	visual.modulate = visual.modulate.lerp(shade, 1.0 - exp(-10.0 * delta))
	aim.modulate = visual.modulate
	# zatrasenie kamerou (offset sa po chvíli vráti na nulu)
	var shake := Vector2.ZERO
	if shake_timer > 0.0:
		shake_timer -= delta
		var fade: float = minf(1.0, shake_timer / 0.1)   # ku koncu doznieva
		shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength * fade
	# spätný ráz: kamera cukne proti smeru streľby a pruží späť
	_cam_kick = _cam_kick.lerp(Vector2.ZERO, 1.0 - exp(-14.0 * delta))
	camera.offset = shake + _cam_kick
	_update_hurt_overlay()


## Všetky akcie (aj zakrádanie, zneškodnenie, holster, výber zbrane) a ich klávesy nastaví KeyBindings
## (settings/key_bindings.gd, prestaviteľné v Settings → Controls → Keyboard).
static func _ensure_actions() -> void:
	GameSettings.ensure_loaded()


func _throwing() -> bool:
	return sprite.animation in [&"hat_throw", &"hat_throw_walk"] and sprite.is_playing()


## Hod klobúka za chôdze – horná časť z hodu, nohy z behu (sprites/hat_throw_walk.png)
func _add_throw_walk_anim() -> void:
	var sf := sprite.sprite_frames
	if sf.has_animation(&"hat_throw_walk"):
		return
	var tex: Texture2D = load("res://characters/ricco/sprites/hat_throw_walk.png")
	sf.add_animation(&"hat_throw_walk")
	sf.set_animation_loop(&"hat_throw_walk", false)
	sf.set_animation_speed(&"hat_throw_walk", sf.get_animation_speed(&"hat_throw"))
	for i in int(tex.get_width() / 64.0):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 64, 0, 64, 64)
		sf.add_frame(&"hat_throw_walk", at)


## Animácia úderu krídlom pri zneškodnení – snímky z hodu (throw.png) bez snehovej gule
func _add_takedown_anim() -> void:
	var sf := sprite.sprite_frames
	if sf.has_animation(&"takedown"):
		return
	var tex: Texture2D = load("res://characters/ricco/sprites/throw.png")
	sf.add_animation(&"takedown")
	sf.set_animation_loop(&"takedown", false)
	sf.set_animation_speed(&"takedown", 14.0)
	for cell in [Vector2i(3, 0), Vector2i(0, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(3, 1)]:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(cell.x * 64, cell.y * 64, 64, 64)
		sf.add_frame(&"takedown", at)


## Visenie na háku – jedna plutva hore na háku (sprites/hook.png, 2 snímky), úchyt je v obrázku na (46, 4)
func _add_hook_anim() -> void:
	var sf := sprite.sprite_frames
	if sf.has_animation(&"hook"):
		return
	var tex: Texture2D = load("res://characters/ricco/sprites/hook.png")
	sf.add_animation(&"hook")
	sf.set_animation_loop(&"hook", true)
	sf.set_animation_speed(&"hook", 3.0)
	for i in 2:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 64, 0, 64, 64)
		sf.add_frame(&"hook", at)


## Lezenie po rebríku – bokom, čelom k stene, plutvy a labky sa striedajú (sprites/ladder.png, 4 snímky, zarovnané ako hang).
## Snímky neidú časom, ale podľa prelezenej vzdialenosti (_process_ladder) – keď stojí, ostane na mieste.
func _add_ladder_anim() -> void:
	var sf := sprite.sprite_frames
	if sf.has_animation(&"ladder"):
		return
	var tex: Texture2D = load("res://characters/ricco/sprites/ladder.png")
	sf.add_animation(&"ladder")
	sf.set_animation_loop(&"ladder", true)
	sf.set_animation_speed(&"ladder", 0.0)
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 64, 0, 64, 64)
		sf.add_frame(&"ladder", at)


## Zakrádanie: kto drží C na zemi, ide pomaly a prikrčene. V režime TOGGLE (GameSettings.sneak_toggle)
## ho C zapne a ďalšie C vypne; vypne ho aj skok, šmyk, plávanie, visenie a cutscéna.
func _update_sneak() -> void:
	var can: bool = is_on_floor() and state == State.NORMAL and not in_cutscene
	if not GameSettings.sneak_toggle:
		_sneak_on = false
		sneaking = Input.is_action_pressed(&"sneak") and can
		return
	if Input.is_action_just_pressed(&"sneak"):
		_sneak_on = not _sneak_on
	if state != State.NORMAL or in_cutscene:
		_sneak_on = false
	sneaking = _sneak_on and can


## Nájde gangstra, ktorého sa dá zneškodniť (zozadu alebo omráčeného), a po stlačení F (bez zbrane aj ľavé tlačidlo) ho zloží
func _update_takedown() -> void:
	takedown_target = null
	if not is_on_floor() or state != State.NORMAL:
		_takedown_hint.visible = false
		return
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var e := g as Node2D
		if e == null or not e.has_method(&"can_takedown"):
			continue
		var dx: float = e.global_position.x - global_position.x
		if absf(dx) < takedown_range and absf(e.global_position.y - global_position.y) < 24.0 and e.can_takedown(global_position.x):
			takedown_target = e
			break
	_takedown_hint.visible = takedown_target != null
	if takedown_target == null:
		return
	var key: String = KeyBindings.short(&"takedown")
	_takedown_hint.text = key if weapon != null and not holstered else "%s / %s" % [key, KeyBindings.short(&"shoot")]
	_takedown_hint.global_position = takedown_target.global_position + Vector2(-_takedown_hint.size.x / 2.0, -88 + sin(Time.get_ticks_msec() * 0.008) * 1.5)
	var press: bool = Input.is_action_just_pressed(&"takedown") or ((weapon == null or holstered) and Input.is_action_just_pressed(&"shoot"))
	if not press:
		return
	var dir: float = signf(takedown_target.global_position.x - global_position.x)
	if dir != facing:
		facing = dir
		visual.scale.x = facing
	velocity.x = dir * 60.0
	sprite.play(&"takedown")
	_takedown_t = 0.3
	shake_timer = 0.08
	shake_strength = 1.5
	takedown_target.takedown(Vector2(dir, -0.2))
	_takedown_frame = Engine.get_physics_frames()   # to isté kliknutie už zbraň nevytiahne
	Sfx.play(&"takedown", global_position)
	takedown_target = null


## Cutscéna: vypne ovládanie a fyziku (pohyb a animácie robí scéna), skryje zbraň
func set_cutscene(on: bool) -> void:
	in_cutscene = on
	if on:
		_cancel_eat()
		_set_duck(false)
	set_physics_process(not on)
	velocity = Vector2.ZERO
	visual.position = Vector2.ZERO
	aim.visible = not on and weapon != null and not holstered
	if on:
		sprite.speed_scale = 1.0
		sprite.play(_hat_anim(&"idle"))


## Je Ricco na svetle? (mimo interiéru vždy áno) – gangstri s needs_light ho v tme nevidia
func is_lit() -> bool:
	return not dark_area or light_zones > 0


var camera_bias: Vector2 = Vector2(0, CAMERA_Y)   ## px – posun stredu kamery od Ricca; level ho môže zmeniť (bossfight na lodi – margaret.gd)


## Kamera „visí“ pred Riccom v smere myši (so zbraňou) alebo v smere pohľadu (bez zbrane),
## aby bolo vidieť viac toho, kam mieri. Posun ide do follow_offset Phantom Camery, tlmenie robí ona.
func _update_camera_lean(delta: float) -> void:
	var dir := Vector2.ZERO
	if in_cutscene:
		dir = Vector2(facing * 0.6, 0.0)
	elif state != State.DEAD:
		if weapon != null:
			var to_mouse: Vector2 = get_global_mouse_position() - (global_position + camera_bias)
			if to_mouse.length() > 8.0:
				dir = to_mouse.normalized()
		else:
			dir = Vector2(facing, 0.0)
	var target := dir * camera_lean
	_lean = _lean.lerp(target, 1.0 - exp(-camera_lean_speed * delta))
	pcam.follow_offset = camera_bias + _lean


func _physics_process(delta: float) -> void:
	ledge_cooldown -= delta
	fire_timer -= delta
	_espresso_t -= delta
	if weapon:
		_bloom = maxf(_bloom - weapon.bloom_recover_deg * delta, 0.0)
	_update_heat(delta)
	_update_invulnerability(delta)
	_swim_cooldown -= delta
	_hook_cooldown -= delta
	_ladder_cooldown -= delta
	if state in [State.NORMAL, State.SLIDE] and _swim_cooldown <= 0.0 and _water_index(global_position + Vector2(0, -14)) >= 0:
		_start_swim()
	match state:
		State.DEAD:
			aim.visible = false
			if not is_on_floor():
				velocity += get_gravity() * delta
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			move_and_slide()
			return
		State.HANG:
			aim.visible = false
			_process_hang()
			return
		State.CLIMB:
			aim.visible = false
			return  # pohyb rieši animácia climb
		State.SLIDE:
			_process_slide(delta)
			return
		State.SWIM:
			_process_swim(delta)
			return
		State.HOOK:
			_process_hook(delta)
			return
		State.LADDER:
			_process_ladder(delta)
			return

	# rebrík: skok pri ňom (alebo pád popri ňom) = chytí sa, S pri jeho vrchu = zlezie dole
	if _try_ladder():
		return

	# Gravitácia – get_gravity() berie hodnotu z Project Settings → Physics → 2D.
	# Na zemi sa coyote time nabíja, vo vzduchu odpočítava.
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		velocity += get_gravity() * delta
		coyote_timer -= delta

	# Jump buffer: zapamätáme si stlačenie skoku na krátky čas
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# Stena – len ak to nie je plošinka (stav z posledného move_and_slide)
	var wall_n: float = _jump_wall_normal()
	# Nízka stena (plot, debny): jej vrch je na dosah → žiadny odraz ani šmýkanie, Ricco sa chytí hrany
	var ledge_near: bool = wall_n != 0.0 and _wall_ledge_near(-wall_n)
	if ledge_near:
		wall_n = 0.0
		wall_timer = 0.0
	if wall_n != 0.0:
		wall_timer = wall_coyote_time
		wall_normal_x = wall_n
	else:
		wall_timer -= delta

	# Wall slide: pri páde popri stene sa Ricco šmýka pomaly
	wall_sliding = wall_n != 0.0 and velocity.y > 0.0
	if wall_sliding:
		velocity.y = minf(velocity.y, wall_slide_speed)

	# Skok – ak je stlačenie ešte „živé“ a Ricco je na zemi (alebo práve zišiel z hrany)
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0  # aby sa nedalo skočiť dvakrát z jedného coyote okna
		_sneak_on = false   # skok zakrádanie vypne
		_cancel_eat()
		sprite.play(_hat_anim(&"jump"))
		Sfx.play(&"jump", Vector2.INF, -6.0)
	# Wall jump – vo vzduchu pri stene: odraz šikmo hore preč od steny
	elif jump_buffer_timer > 0.0 and wall_timer > 0.0:
		velocity = Vector2(wall_normal_x * wall_jump_velocity.x, wall_jump_velocity.y)
		jump_buffer_timer = 0.0
		wall_timer = 0.0
		wall_lock_timer = wall_jump_lock_time
		wall_sliding = false
		_turn(wall_normal_x)
		sprite.play(&"wall_jump")  # krátky odraz nohou od steny, potom jump/fall
		Sfx.play(&"wall_jump", Vector2.INF, -4.0)

	# Variabilná výška: pustíš skok počas stúpania → Ricco spomalí a skok je nižší
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	# Šmyk po bruchu – len na zemi
	if Input.is_action_just_pressed(&"slide") and is_on_floor() and jump_buffer_timer <= 0.0 \
			and not _throwing() and _slide_room(_slide_dir()):
		_cancel_eat()
		_set_duck(false)
		_start_slide()
		return

	# Pohyb do strán: -1 vľavo, 0 nič, 1 vpravo
	var direction: float = Input.get_axis("move_left", "move_right")
	if wall_lock_timer > 0.0:
		wall_lock_timer -= delta  # tesne po odraze necháme Ricca letieť (rýchlosť x sa nemení)
	elif _takedown_t > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)   # počas úderu stojí
	elif direction != 0.0:
		var top_speed: float = sneak_speed if sneaking else max_speed
		if eating:
			top_speed *= 0.45
		elif _espresso_t > 0.0:
			top_speed *= Food.ESPRESSO_SPEED
		if sprite.animation in [&"slide_end", &"slide_end_nohat"] and sprite.is_playing():
			top_speed *= 0.35   # ešte vstáva – nerozbehne sa hneď naplno
		velocity.x = move_toward(velocity.x, direction * top_speed, (ice_acceleration if on_ice else acceleration) * delta)
		if wall_sliding:
			# pri šmýkaní sa Ricco pozerá OD steny (chrbtom k nej), ako Pedro
			if facing != wall_normal_x:
				_turn(wall_normal_x)
		elif not aim_facing and signf(direction) != facing:
			_turn(signf(direction))
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction() * delta)

	# Zavesenie na okraj: vo vzduchu, pri páde (alebo tesne pri vrchole), keď hráč tlačí ku hrane
	var grab_dir: float = signf(direction) if direction != 0.0 else (-_last_wall_x if ledge_near else 0.0)
	if not is_on_floor() and velocity.y > -40.0 and grab_dir != 0.0 and ledge_cooldown <= 0.0 \
			and wall_lock_timer <= 0.0 and _try_grab_ledge(grab_dir):
		return

	_unstick(delta)
	_update_sneak()
	_update_cover(delta)
	_takedown_t -= delta
	_update_eat()
	if not eating:
		_update_takedown()
	else:
		_takedown_hint.visible = false
	_update_aim()
	if not eating:
		_update_weapons()

	var was_air: bool = not is_on_floor()
	var fall_vy: float = velocity.y
	move_and_slide()
	_update_ice()
	if was_air and is_on_floor() and fall_vy > 220.0:
		Sfx.play(&"land", Vector2.INF, -8.0 + minf(fall_vy / 100.0, 6.0))
	_update_animation(direction)
	_update_waddle(delta)
	_update_crouch(delta)
	# pri šmýkaní po stene odsunieme obrázok od steny, aby do nej nezachádzal
	var target_x: float = wall_normal_x * wall_slide_offset if wall_sliding else 0.0
	visual.position.x = lerpf(visual.position.x, target_x, minf(1.0, 25.0 * delta))


## Je vrch steny pred Riccom na dosah (nízka stena – plot, debny)? Lúč zhora nadol tesne za čelom steny:
## ak narazí na vrch v pásme od kúsok nad hlavou po pás, je to hrana na chytenie. Pri vysokej stene
## lúč začína vnútri steny a nič nenájde → normálny odraz od steny (wall jump).
func _wall_ledge_near(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	var p: Vector2 = global_position
	var wall: Dictionary = {}
	for hy in [6.0, 20.0, 34.0]:
		wall = space.intersect_ray(PhysicsRayQueryParameters2D.create(
				Vector2(p.x, p.y - hy), Vector2(p.x + dir * (HALF_WIDTH + 6.0), p.y - hy), collision_mask, [get_rid()]))
		if not wall.is_empty():
			break
	if wall.is_empty():
		return false
	var x: float = wall.position.x + dir * 3.0
	var top := space.intersect_ray(PhysicsRayQueryParameters2D.create(
			Vector2(x, p.y - HEIGHT - 26.0), Vector2(x, p.y - 2.0), collision_mask, [get_rid()]))
	_last_wall_x = -dir
	if top.is_empty() or top.normal.y > -0.7:
		return false
	# nad nájdeným vrchom musí byť voľno (inak je to len škára medzi dlaždicami vo vysokej stene)
	var q := PhysicsPointQueryParameters2D.new()
	q.position = top.position + Vector2(0, -3)
	q.collision_mask = collision_mask
	return space.intersect_point(q, 1).is_empty()


## Vráti smer od steny (+1 / -1), ak sa Ricco vo vzduchu dotýka steny, od ktorej sa dá odraziť.
## Plošinky (uzly v skupine "platform") sa nerátajú. 0 = žiadna stena.
func _jump_wall_normal() -> float:
	if is_on_floor() or not is_on_wall():
		return 0.0
	for i in get_slide_collision_count():
		var c: KinematicCollision2D = get_slide_collision(i)
		var n: Vector2 = c.get_normal()
		var collider := c.get_collider() as Node
		if absf(n.x) > 0.7 and collider != null and not collider.is_in_group(&"platform"):
			return signf(n.x)
	return 0.0


## Hľadá hranu pred Riccom tromi lúčmi (Godot docs: tutorials/physics/ray-casting):
##  1. na úrovni hrude musí byť stena,
##  2. nad hlavou musí byť voľno,
##  3. lúč zhora nadol nájde vrch hrany.
## Ak hranu nájde, Ricco sa zavesí a funkcia vráti true.
func _try_grab_ledge(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	var p: Vector2 = global_position
	var reach: float = HALF_WIDTH + ledge_reach
	var head_y: float = p.y - HEIGHT - 8.0
	# tesne pod nohami je zem (schody, nízky schod) → nie je čo chytať, Ricco len zíde / vyjde
	var below := space.intersect_ray(PhysicsRayQueryParameters2D.create(p, p + Vector2(0, 22), collision_mask, [get_rid()]))
	if not below.is_empty():
		return false
	# 1. stena pred hruďou (alebo nižšie – keď Ricco vyskočí skoro nad hranu, chytí sa jej aj tak)
	var wall_hit: Dictionary = {}
	for hy in [HEIGHT - 12.0, 16.0, 6.0]:
		wall_hit = space.intersect_ray(PhysicsRayQueryParameters2D.create(
				Vector2(p.x, p.y - hy), Vector2(p.x + dir * reach, p.y - hy), collision_mask, [get_rid()]))
		if not wall_hit.is_empty():
			break
	if wall_hit.is_empty() or absf(wall_hit.normal.x) < 0.7:
		return false
	var wall_x: float = wall_hit.position.x
	# 2. nad hlavou voľno
	var above_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
			Vector2(p.x, head_y), Vector2(p.x + dir * reach, head_y), collision_mask, [get_rid()]))
	if not above_hit.is_empty():
		return false
	# 3. vrch hrany (lúč kúsok za okrajom steny smerom dole)
	var probe_x: float = wall_x + dir * 4.0
	var top_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
			Vector2(probe_x, head_y), Vector2(probe_x, p.y - 2.0), collision_mask, [get_rid()]))
	if top_hit.is_empty() or top_hit.normal.y > -0.7:
		return false
	var top_y: float = top_hit.position.y
	# 4. hore musí byť miesto, kde sa Ricco postaví
	var stand_x: float = wall_x + dir * CLIMB_STAND_DISTANCE
	# úzka stena/pilier: ak tam nie je zem, postav sa bližšie k okraju
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
			Vector2(stand_x, top_y - 2.0), Vector2(stand_x, top_y + 4.0), collision_mask, [get_rid()]))
	if floor_hit.is_empty():
		stand_x = wall_x + dir * (HALF_WIDTH + 2.0)
	var room_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
			Vector2(stand_x, top_y - 2.0), Vector2(stand_x, top_y - HEIGHT - 2.0), collision_mask, [get_rid()]))
	if not room_hit.is_empty():
		return false

	# Zavesenie
	state = State.HANG
	Sfx.play(&"ledge_grab", Vector2.INF, -4.0)
	velocity = Vector2.ZERO
	wall_sliding = false
	ledge_top = Vector2(stand_x, top_y)
	global_position = Vector2(wall_x - dir * (HALF_WIDTH + 0.5), top_y + ledge_hang_depth)
	if facing != dir:
		facing = dir
		visual.scale.x = facing
	visual.rotation = 0.0
	visual.position = Vector2(-dir * hang_visual_offset, 0.0)
	sprite.play(&"hang")
	return true


## Visí na hrane: skok = vylezie hore, smer od steny = pustí sa.
func _process_hang() -> void:
	if Input.is_action_just_pressed("jump"):
		_start_climb()
	elif Input.get_axis("move_left", "move_right") == -facing:
		state = State.NORMAL
		ledge_cooldown = ledge_regrab_time
		sprite.play(_hat_anim(&"fall"))


## Vylezenie: Ricco stojí na mieste a „lezie“ samotná animácia (je zarovnaná na roh hrany),
## na konci ho presunieme na hranu – takto sa to robí aj v hrách typu Assassin's Creed / Prince of Persia.
func _start_climb() -> void:
	Sfx.play(&"climb", Vector2.INF, -6.0)
	state = State.CLIMB
	visual.position = Vector2.ZERO
	sprite.offset = CLIMB_SPRITE_OFFSET
	sprite.play(&"climb")


func _on_sprite_animation_finished() -> void:
	if state == State.CLIMB and sprite.animation == &"climb":
		_end_climb()
	elif state == State.SLIDE and sprite.animation in [&"slide_start", &"slide_start_nohat"]:
		sprite.play(_hat_anim(&"slide"))


func _end_climb() -> void:
	global_position = ledge_top
	sprite.offset = Vector2.ZERO
	state = State.NORMAL
	velocity = Vector2.ZERO
	was_on_floor = true
	sprite.play(&"idle")


## Otočí Ricca. Všetky animácie sú kreslené smerom doprava,
## doľava ho len zrkadlovo prevrátime cez scale.x.
func _turn(new_facing: float) -> void:
	facing = new_facing
	visual.scale.x = facing
	if is_on_floor():
		sprite.play(_hat_anim(&"turn"))


func _update_animation(direction: float) -> void:
	var on_floor: bool = is_on_floor()

	if sprite.animation == &"takedown" and sprite.is_playing():
		pass  # úder krídlom dobehne
	elif _throwing():
		pass  # hod klobúka dobehne aj vo vzduchu
	elif on_floor and sprite.animation in [&"hurt", &"hurt_nohat"] and sprite.is_playing() and direction == 0.0:
		pass  # krátke zľaknutie po zásahu dobehne, ak sa hráč nehýbe
	elif wall_sliding:
		_play(&"wall_slide")
	elif not on_floor and sprite.animation == &"wall_jump" and sprite.is_playing():
		pass  # nech odraz od steny dobehne (~0.15 s)
	elif not on_floor:
		# Stúpa → jump (prehrá sa raz a ostane na poslednom frame), padá → fall (slučka)
		_play(_hat_anim(&"jump" if velocity.y < 0.0 else &"fall"))
	elif not was_on_floor:
		sprite.play(_hat_anim(&"land"))
	elif sprite.animation in [&"turn", &"turn_nohat"] and sprite.is_playing():
		pass  # nech otočka dobehne (trvá ~0.15 s)
	elif sprite.animation in [&"land", &"land_nohat"] and sprite.is_playing() and direction == 0.0:
		pass  # dopad dobehne, ak sa hráč nehýbe; pri pohybe hneď prejde na beh
	elif _throwing():
		pass  # hod dobehne celý
	elif sprite.animation == &"hat_catch" and sprite.is_playing() and absf(velocity.x) < 10.0:
		pass  # chytenie dobehne, ak Ricco stojí
	elif sprite.animation in [&"slide_end", &"slide_end_nohat"] and sprite.is_playing():
		pass  # postavenie sa po šmyku dobehne vždy (aj keď hráč beží ďalej)
	elif absf(velocity.x) > 10.0:
		_play_run(signf(velocity.x) != facing)
	else:
		_play(&"idle" if has_hat else &"idle_nohat")

	was_on_floor = on_floor


## Spustí animáciu len ak už nehrá (inak by sa stále reštartovala od 1. framu).
func _play(anim: StringName) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		if sprite.animation == anim and sprite.sprite_frames.get_animation_loop_mode(anim) == SpriteFrames.LOOP_NONE:
			return  # jednorazová animácia už dohrala – nechaj posledný frame
		sprite.play(anim)


## Beh: dopredu normálne, pri cúvaní (pozerá sa na myš, ide opačne) tá istá animácia odzadu.
## Godot docs: AnimatedSprite2D.play_backwards().
func _play_run(backwards: bool) -> void:
	var anim: StringName = _hat_anim(&"run")
	if sprite.animation == anim and sprite.is_playing() and backwards == run_backwards:
		return
	run_backwards = backwards
	if backwards:
		sprite.play_backwards(anim)
	else:
		sprite.play(anim)


## Kým klobúk letí, použi verziu animácie bez klobúka (ak existuje, napr. run → run_nohat).
func _hat_anim(anim: StringName) -> StringName:
	if not has_hat:
		var bare := StringName(String(anim) + "_nohat")
		if sprite.sprite_frames.has_animation(bare):
			return bare
	return anim


## Prikrčenie pri zakrádaní: obrázok sa zníži a mierne rozšíri, beh je pomalší a kolíše menej
func _update_crouch(delta: float) -> void:
	var want := Vector2(1.12, 0.62) if ducked else (Vector2(1.08, 0.84) if sneaking else Vector2.ONE)
	var cur := Vector2(absf(visual.scale.x), visual.scale.y)
	cur = cur.lerp(want, minf(1.0, 14.0 * delta))
	visual.scale = Vector2(cur.x * facing, cur.y)
	if sneaking and sprite.animation in [&"run", &"run_nohat"]:
		sprite.speed_scale = 0.55


## Kolísanie pri behu: Visual sa otáča okolo nôh (origin je pri nohách),
## jeden krok = polovica sínusovej vlny, takže každý krok je jeden náklon na stranu.
func _update_waddle(delta: float) -> void:
	var running: bool = is_on_floor() and sprite.animation in [&"run", &"run_nohat"]
	# na schodoch (45° rampa) je spodok kapsuly ~4 px nad svahom – obrázok ide nižšie, aby stál na schodíkoch
	var slope_dy: float = SLOPE_SINK if is_on_floor() and get_floor_normal().y > -0.9 else 0.0
	if running:
		waddle_phase += absf(velocity.x) * delta / waddle_step * PI
		var s: float = sin(waddle_phase) * (0.4 if sneaking else 1.0)
		visual.rotation = deg_to_rad(waddle_angle_deg) * s
		visual.position.y = -absf(s) * waddle_bob + slope_dy
		# rýchlosť framov podľa rýchlosti behu (pri rozbehu pomalšie)
		sprite.speed_scale = clampf(absf(velocity.x) / max_speed, 0.4, 1.0)
	else:
		# plynulý návrat do rovnej polohy
		visual.rotation = lerpf(visual.rotation, 0.0, minf(1.0, 20.0 * delta))
		visual.position.y = lerpf(visual.position.y, slope_dy, minf(1.0, 20.0 * delta))
		sprite.speed_scale = 1.0
		if not is_on_floor():
			waddle_phase = 0.0


## Mierenie: Aim sa otáča k myši. Pri mierení doľava sa zbraň aj s rukou ducha preklopí
## (scale.y = -1), aby nebola hore nohami – deti (ruka, ústie hlavne) sa preklopia s ňou.
func _update_aim() -> void:
	aim_dir = (get_global_mouse_position() - aim.global_position).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2(facing, 0)
	# na zemi obmedzíme mierenie dole, inak by zbraň zachádzala do podlahy
	if is_on_floor():
		var max_down: float = deg_to_rad(ground_aim_max_down_deg)
		var a: float = aim_dir.angle()  # 0 = doprava, PI/2 = dole
		if a > max_down and a <= PI * 0.5:
			aim_dir = Vector2.from_angle(max_down)
		elif a > PI * 0.5 and a < PI - max_down:
			aim_dir = Vector2.from_angle(PI - max_down)
	aim.rotation = aim_dir.angle()
	gun.scale.y = -1.0 if aim_dir.x < 0.0 else 1.0
	_update_akimbo_pose()
	var busy: bool = sprite.animation in [&"hat_throw", &"hat_throw_walk", &"hat_catch"] and sprite.is_playing() or eating
	aim.visible = not busy and weapon != null and (not holstered or _holstering)
	# Ricco sa pozerá tam, kam mieri (okrem šmýkania po stene a hodu)
	if aim_facing and state in [State.NORMAL, State.HOOK] and not wall_sliding and not busy:
		var want: float = 1.0 if aim_dir.x >= 0.0 else -1.0
		if want != facing:
			_turn(want)


func _update_weapons() -> void:
	# Schovať / vytiahnuť zbraň (X); zo schovanej ju vytiahne aj streľba (prvé kliknutie nevystrelí)
	if Input.is_action_just_pressed(&"holster") and weapon:
		if holstered:
			_draw_weapon()
		elif _holster_after_reload:
			_holster_after_reload = false   # rozmyslel si to počas prebíjania
		else:
			_holster()
	if holstered:
		if Input.is_action_just_pressed(&"shoot") and _takedown_frame != Engine.get_physics_frames():
			_draw_weapon()
		elif Input.is_action_just_pressed(&"reload"):
			_draw_weapon()
	# Streľba – samopal strieľa, kým držíš; ostatné zbrane každé kliknutie jeden výstrel
	var pull: bool = false
	if weapon and not holstered:   # bez zbrane (začiatok levelu 1) sa len hádže klobúk
		var auto: bool = weapon.automatic and not is_alt_fire()   # samopal prepnutý na SEMI strieľa po jednom
		pull = Input.is_action_pressed("shoot") if auto else Input.is_action_just_pressed("shoot")
	if reloading and weapon and weapon.shell_reload and ammo_in_mag > 0 and Input.is_action_just_pressed("shoot"):
		_reload_cancel = true   # pumpovačka: streľba preruší nabíjanie po náboji, ktorý má ruka práve pri otvore
	if pull and fire_timer <= 0.0 and aim.visible and not reloading:
		if ammo_in_mag > 0:
			_shoot()
		elif Input.is_action_just_pressed("shoot"):
			if ammo_reserve <= 0 and not reloading:
				Sfx.play(&"dry_fire")   # nič v zásobníku ani v zálohe – cvak
			_start_reload()  # prázdny zásobník → automaticky prebije
	if Input.is_action_just_pressed("reload") and not holstered:
		_start_reload()
	# Hod klobúka – len keď ho má na hlave
	if Input.is_action_just_pressed("throw_hat") and has_hat and state == State.NORMAL \
			and not _throwing():
		# za chôdze hod s krokmi (nohy sa hýbu), v stoji klasický hod
		sprite.play(&"hat_throw_walk" if is_on_floor() and absf(velocity.x) > 25.0 else &"hat_throw")


func _shoot() -> void:
	var alt: bool = is_alt_fire()
	var semi: bool = alt and weapon.alt_mode == WeaponData.AltMode.SEMI
	# obe hlavne naraz (lupara 2x) – len keď sú v nej dva náboje, inak normálny výstrel
	var shells: int = 2 if alt and weapon.alt_mode == WeaponData.AltMode.DOUBLE and ammo_in_mag >= 2 else 1
	fire_timer = maxf(weapon.fire_cooldown, 0.1) if semi else weapon.fire_cooldown
	# akimbo: strieľa striedavo predná a zadná zbraň – každá má čas na spätný ráz, takže idú rýchlejšie za sebou
	var duo: bool = is_akimbo()
	var back: bool = duo and _akimbo_back_next
	if duo:
		fire_timer = weapon.fire_cooldown * AKIMBO_COOLDOWN
		_akimbo_back_next = not _akimbo_back_next
	var from: Vector2 = _gun2_muzzle.global_position if back else muzzle.global_position
	if in_cover:
		_cover_pop = COVER_POP_TIME   # vystrčí sa nad kryt a chvíľu ostane hore
		_set_duck(false)
	ammo_in_mag -= shells
	_store_ammo()
	ammo_changed.emit(ammo_in_mag, ammo_reserve, false)
	var pellets: int = weapon.pellets * shells
	for i in pellets:
		var b := bullet_scene.instantiate()
		# broky sa rozložia do vejára, jedna guľka má len malý náhodný rozptyl;
		# po jednom (SEMI) je samopal presnejší, dve hlavne naraz rozhodia vejár o trochu širšie
		var spread: float = (weapon.spread_deg * (0.6 if semi else 1.0) + _bloom) * (1.2 if shells == 2 else 1.0) \
				* (AKIMBO_SPREAD if duo else 1.0)
		var a: float = randf_range(-spread, spread) if pellets == 1 \
				else lerpf(-spread / 2.0, spread / 2.0, (i + randf()) / pellets)
		b.direction = aim_dir.rotated(deg_to_rad(a))
		b.scale = Vector2.ONE * weapon.pellet_scale
		b.shooter = self
		b.damage = weapon.damage
		b.speed = weapon.bullet_speed * (randf_range(0.85, 1.05) if pellets > 1 else 1.0)
		b.lifetime = weapon.bullet_lifetime
		b.effective_range = weapon.effective_range
		b.falloff_range = weapon.falloff_range
		b.global_position = from
		get_tree().current_scene.add_child(b)
	_bloom = minf(_bloom + weapon.spread_bloom_deg * (0.5 if semi else 1.0), weapon.spread_max_deg)
	# šťava: zvuk, záblesk (3 snímky + žiara + dym), cuknutie a nadhodenie zbrane, zatrasenie kamery
	Sfx.shot(weapon)
	if shells == 2:
		Sfx.shot(weapon)   # druhá hlaveň v tom istom okamihu – hlasnejšia, hrubšia rana
	var recoil: float = weapon.recoil_px * (1.5 if shells == 2 else 1.0)
	if back:
		_akimbo_shot(recoil)
	else:
		_muzzle_flash(1.35 if shells == 2 else 1.0)
		gun.position.x = gun_base_x - recoil
		var kick: float = -0.045 * recoil * gun.scale.y   # hlaveň vyskočí hore
		if _recoil_tween:
			_recoil_tween.kill()
		_recoil_tween = create_tween().set_parallel(true)
		gun.rotation = kick
		_recoil_tween.tween_property(gun, "position:x", gun_base_x, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_recoil_tween.tween_property(gun, "rotation", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if weapon.recoil_px >= 6.0 and is_on_floor():
		velocity.x -= aim_dir.x * 60.0 * shells   # lupara odtlačí Ricca (obe hlavne dvakrát viac)
	shake_timer = 0.12 * (1.5 if shells == 2 else 1.0)
	shake_strength = weapon.shake * 1.4 * (1.4 if shells == 2 else 1.0)
	_cam_kick = -aim_dir * (2.5 + recoil * 1.3)
	Gangster.gunshot(global_position, SHOT_NOISE)   # výstrel počuť ďaleko, záblesk vidno aj v tme
	shot_fired.emit()
	if weapon.pump_texture:
		_pump_action()


# ---------------------------------------------------------------- schovanie zbrane

## Ruka ducha so zbraňou sa stiahne k Riccovi a zmizne (počas prebíjania až keď dobije)
func _holster() -> void:
	if holstered or weapon == null:
		return
	if reloading:
		_holster_after_reload = true
		return
	holstered = true
	_holstering = true
	if _holster_tween:
		_holster_tween.kill()
	_holster_tween = create_tween()
	_holster_tween.tween_property(aim, "scale", Vector2(0.15, 0.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_holster_tween.tween_callback(func():
		_holstering = false
		aim.visible = false
		aim.scale = Vector2.ONE)
	Sfx.play(&"mag_in", global_position, -10.0, 0.05)
	ammo_changed.emit(ammo_in_mag, ammo_reserve, false)


## Zbraň vyskočí z Ricca späť do ruky ducha
func _draw_weapon(animate: bool = true) -> void:
	if not holstered:
		return
	holstered = false
	_holstering = false
	if _holster_tween:
		_holster_tween.kill()
	aim.scale = Vector2.ONE
	if weapon == null:
		return
	aim.visible = true
	fire_timer = maxf(fire_timer, 0.12)
	if animate:
		aim.scale = Vector2(0.2, 0.2)
		_holster_tween = create_tween()
		_holster_tween.tween_property(aim, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play(&"slide_rack", global_position, -12.0, 0.05)


# ---------------------------------------------------------------- záblesk z hlavne
const FLASH_TEX := preload("res://weapons/pistol/muzzle_flash_big.png")
const GLOW_TEX := preload("res://levels/level1/art/glow.png")
const FLASH_SCALE := {"Derringer": 0.9, "Pistol": 1.1, "Revolver": 1.35, "Tommy gun": 1.0, "Lupara": 1.8, "Winchester": 1.7, "Springfield": 1.5,
		"Winchester 1894": 1.35, "Mauser C96": 1.0}
var _flash_glow: Sprite2D
var _flash_light: PointLight2D   ## záblesk na okamih osvetlí okolie (aj v tme – CanvasModulate „Darkness“)
# Jeden tween na každú časť záblesku: nový výstrel starý zruší. Inak pri dávke dobehol tween
# z predošlého výstrelu a zhasol svetlo / skryl záblesk, ktorý práve rozsvietil nový výstrel.
var _flash_tw: Tween
var _glow_tw: Tween
var _light_tw: Tween
var _recoil_tween: Tween
var _cam_kick: Vector2 = Vector2.ZERO   ## px – spätný ráz kamery (_process ho vracia na nulu)

func _setup_flash() -> void:
	flash.texture = FLASH_TEX
	flash.hframes = 3
	flash.centered = false
	flash.offset = Vector2(-3, -12)   # ústie je vľavo v strede obrázka
	flash.position = Vector2(1, 0)
	_flash_glow = Sprite2D.new()
	_flash_glow.texture = GLOW_TEX
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash_glow.material = m
	_flash_glow.modulate = Color(1.0, 0.75, 0.4, 0.8)
	_flash_glow.scale = Vector2.ONE * 0.6
	_flash_glow.position = Vector2(6, 0)
	_flash_glow.visible = false
	muzzle.add_child(_flash_glow)
	_flash_light = PointLight2D.new()
	_flash_light.texture = GLOW_TEX
	_flash_light.color = Color(1.0, 0.78, 0.45)
	_flash_light.energy = 0.0
	_flash_light.texture_scale = 2.4
	_flash_light.position = Vector2(8, 0)
	_flash_light.enabled = false
	muzzle.add_child(_flash_light)


func _muzzle_flash(boost: float = 1.0) -> void:
	var k: float = FLASH_SCALE.get(weapon.name, 0.8) * boost
	flash.scale = Vector2(k, k * randf_range(0.85, 1.15))
	flash.rotation = randf_range(-0.12, 0.12)
	flash.frame = 0
	flash.visible = true
	_flash_glow.visible = true
	_flash_glow.scale = Vector2.ONE * 0.9 * k
	# okolie sa na okamih rozsvieti (steny, mafiáni v tme)
	_flash_light.enabled = true
	_flash_light.energy = (1.1 + 0.3 * k) * randf_range(0.85, 1.1)   # pri dávke svetlo trochu bliká
	_flash_light.texture_scale = 2.0 + 1.4 * k
	if _light_tw:
		_light_tw.kill()
	_light_tw = create_tween()
	_light_tw.tween_property(_flash_light, "energy", 0.0, 0.2).set_delay(0.06)
	_light_tw.tween_callback(func(): _flash_light.enabled = false)
	# záblesk drží dlhšie (~0,14 s), žiara dohasína plynulo
	if _flash_tw:
		_flash_tw.kill()
	_flash_tw = create_tween()
	_flash_tw.tween_interval(0.045)
	_flash_tw.tween_callback(func(): flash.frame = 1)
	_flash_tw.tween_interval(0.045)
	_flash_tw.tween_callback(func(): flash.frame = 2)
	_flash_tw.tween_interval(0.05)
	_flash_tw.tween_callback(func(): flash.visible = false)
	_flash_glow.modulate.a = 0.9
	if _glow_tw:
		_glow_tw.kill()
	_glow_tw = create_tween()
	_glow_tw.tween_property(_flash_glow, "modulate:a", 0.0, 0.16).set_delay(0.05)
	_glow_tw.tween_callback(func(): _flash_glow.visible = false)
	Burst.spawn(get_tree().current_scene, muzzle.global_position, aim_dir,
			Color(1.0, 0.8, 0.4), 5 if k < 1.2 else 10, 110.0, Vector2(0, 120), 0.22)   # iskry z ústia
	# dym: samopal začína slabšie, ale s dlhšou dávkou ho pribúda (hlaveň sa zahrieva)
	var smoke: float = k
	if weapon.automatic:
		_heat = minf(_heat + 1.0, HEAT_MAX)
		smoke = k * (0.6 + 0.08 * _heat)
	GunSmoke.spawn(get_tree().current_scene, muzzle.global_position, aim_dir, smoke)


const HEAT_MAX := 10.0      ## po ~10 výstreloch dávkou je dymu najviac
const HEAT_COOL := 4.0      ## o koľko za sekundu hlaveň chladne
const HEAT_WISP := 4.0      ## od tohto zahriatia po dávke z hlavne stúpa tenký dym

## Rozpálená hlaveň po dávke: kým sa nestrieľa, z ústia stúpajú tenké pásiky dymu
func _update_heat(delta: float) -> void:
	if _heat <= 0.0:
		return
	_heat = maxf(_heat - HEAT_COOL * delta, 0.0)
	_wisp_t -= delta
	if _heat > HEAT_WISP and fire_timer < -0.1 and aim.visible and _wisp_t <= 0.0:
		_wisp_t = 0.07
		GunSmoke.wisp(get_tree().current_scene, muzzle.global_position, clampf((_heat - HEAT_WISP) / 4.0, 0.3, 1.0))


## Prebíjanie (ako naozaj): zbraň sa nakloní, starý zásobník (bubon, nábojnice, broky) vykĺzne a padne na zem,
## druhá ruka ducha priletí s novým, zasunie ho a zmizne (pri dvojručných zbraniach sa vráti na predok zbrane).
## Všetko je jeden Tween (Godot docs: classes/class_tween – tween_property / parallel / tween_callback).
## Časovanie sa naťahuje podľa reload_time zbrane. Miesta berie z WeaponData (mag_px, mag_out).
const OFFHAND_MAG := Vector2(5, -2)        ## kde drží druhá ruka zásobník (v jej obrázku)
const OFFHAND_START := Vector2(-28, 8)     ## odkiaľ druhá ruka priletí (spoza zbrane, od Ricca)
const OFFHAND_GRIP := Vector2(7, 5)        ## bod dlane v obrázku druhej ruky (drží ním predok zbrane)

func _start_reload() -> void:
	if weapon == null or reloading or ammo_reserve <= 0 or ammo_in_mag == mag_size:
		return
	reloading = true
	ammo_changed.emit(ammo_in_mag, ammo_reserve, true)
	if is_akimbo():
		_akimbo_reload_out()
	if weapon.frame_texture:
		_start_break_reload()
		return
	if weapon.shell_reload:
		_start_shell_reload()
		return
	var k: float = reload_time / 1.0   # časovanie nižšie je pre 1 s (akimbo trvá dlhšie – prebíja obe)
	var tilt: float = -0.35 * gun.scale.y   # hlaveň mierne hore, pažba k Riccovi
	var mag_in: Vector2 = _gun_px(weapon.mag_px)
	var inside: Vector2 = mag_in - OFFHAND_MAG + (Vector2(0, 0) if weapon.mag_visible else Vector2(0, -2))  # zasunutý
	var under: Vector2 = inside + (Vector2(0, -9) if weapon.mag_from_top else Vector2(0, 7))   # nový zásobník tesne pod (nad) miestom
	mag.texture = weapon.mag_texture
	mag.position = mag_in
	mag.visible = true
	var hand: Node = offhand.get_node("NewMag")
	hand.texture = weapon.new_mag_texture
	hand.visible = true
	var from: Vector2 = offhand.position if (weapon.two_handed and offhand.visible) else OFFHAND_START
	offhand.position = from
	if not (weapon.two_handed and offhand.visible):
		offhand.fade = 0.0
	offhand.visible = true
	var tw := create_tween()
	_reload_tween = tw
	# 1. naklonenie + starý zásobník vykĺzne
	tw.tween_property(gun, "rotation", tilt, 0.08 * k)
	tw.parallel().tween_property(offhand, "position", OFFHAND_START, 0.12 * k)   # druhá ruka pustí predok
	tw.tween_property(mag, "position", mag_in + weapon.mag_out, 0.08 * k).set_ease(Tween.EASE_IN)
	tw.tween_callback(_drop_magazine)
	# 2. druhá ruka priletí s novým zásobníkom
	tw.tween_property(offhand, "fade", 1.0, 0.12 * k)
	tw.parallel().tween_property(offhand, "position", under, 0.3 * k) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 3. zasunutie (rýchly ťah hore) + cuknutie zbrane
	tw.tween_property(offhand, "position", inside, 0.08 * k).set_ease(Tween.EASE_IN)
	tw.tween_callback(_magazine_inserted)
	tw.tween_property(gun, "rotation", tilt - 0.12 * gun.scale.y, 0.04 * k)
	tw.tween_property(gun, "rotation", tilt, 0.06 * k)
	# 4. ruka sa vráti na predok zbrane (dvojručné) alebo odletí a rozplynie sa
	if weapon.two_handed:
		tw.tween_property(offhand, "position", _offhand_rest(), 0.16 * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(offhand, "position", OFFHAND_START, 0.2 * k).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(offhand, "fade", 0.0, 0.2 * k)
	tw.parallel().tween_property(gun, "rotation", 0.0, 0.16 * k).set_delay(0.04 * k)
	tw.tween_callback(_finish_reload)


## Lámacia zbraň (derringer, lupara): hlavne sa na pánte vyklopia (derringer hore, lupara dole), prázdne
## nábojnice vypadnú z komôr, druhá ruka ducha zasunie nové náboje a hlavne sa zaklapnú. Hlavne sú samostatný Sprite (_barrels)
## nad rámom (weapon.frame_texture), otáča sa okolo weapon.hinge_px.
func _start_break_reload() -> void:
	var k: float = reload_time / 1.0
	var tilt: float = -0.25 * gun.scale.y
	var open: float = -deg_to_rad(weapon.open_deg)   # v priestore zbrane: záporný uhol = ústie hore, kladný = dole
	var chamber: Vector2 = _gun_px(weapon.mag_px)
	gun.texture = weapon.frame_texture
	_barrels.texture = weapon.barrel_texture
	_barrels.offset = -weapon.hinge_px
	_barrels.position = _gun_px(weapon.hinge_px)
	_barrels.rotation = 0.0
	_barrels.visible = true
	mag.texture = weapon.mag_texture
	mag.position = chamber
	mag.visible = false
	var hand: Node = offhand.get_node("NewMag")
	hand.texture = weapon.new_mag_texture
	hand.visible = true
	var from: Vector2 = offhand.position if (weapon.two_handed and offhand.visible) else OFFHAND_START
	offhand.position = from
	if not (weapon.two_handed and offhand.visible):
		offhand.fade = 0.0
	offhand.visible = true
	var inside: Vector2 = chamber - OFFHAND_MAG
	var tw := create_tween()
	_reload_tween = tw
	# 1. naklonenie + hlavne sa vyklopia → nábojnice vypadnú
	tw.tween_property(gun, "rotation", tilt, 0.08 * k)
	tw.parallel().tween_property(offhand, "position", OFFHAND_START, 0.12 * k)   # druhá ruka pustí predpažbie
	tw.tween_property(_barrels, "rotation", open, 0.09 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_drop_magazine)
	# 2. druhá ruka priletí s dvoma nábojmi a zasunie ich do komôr
	tw.tween_property(offhand, "fade", 1.0, 0.12 * k)
	tw.parallel().tween_property(offhand, "position", inside + Vector2(-6, 6), 0.3 * k) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(offhand, "position", inside, 0.08 * k).set_ease(Tween.EASE_IN)
	tw.tween_callback(_magazine_inserted)
	# 3. hlavne sa zaklapnú (cvak) a zbraň cukne; dvojručná: ruka chytí predpažbie a zavrie ich ním,
	#    inak ruka odletí a rozplynie sa
	if weapon.two_handed:
		tw.tween_property(offhand, "position", _offhand_rest(), 0.12 * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_barrels, "rotation", 0.0, 0.07 * k).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(offhand, "position", OFFHAND_START, 0.16 * k).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(offhand, "fade", 0.0, 0.16 * k)
		tw.tween_property(_barrels, "rotation", 0.0, 0.06 * k).set_ease(Tween.EASE_IN)
	tw.tween_callback(_close_barrels)
	tw.tween_property(gun, "rotation", tilt - 0.12 * gun.scale.y, 0.04 * k)
	tw.tween_property(gun, "rotation", 0.0, 0.14 * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish_reload)


func _close_barrels() -> void:
	Sfx.play(&"mag_in", Vector2.INF, -4.0, 0.1)
	gun.texture = weapon.texture
	_barrels.visible = false
	_barrels.rotation = 0.0


# ---------------------------------------------------------------- pumpovačka (Winchester 1897)

## Po výstrele druhá ruka ducha potiahne pumpu dozadu (vyletí nábojnica) a dopredu (náboj do komory).
## delay < 0 = weapon.pump_delay (po výstrele chvíľu počká, kým zbraň „dosadne“)
func _pump_action(delay: float = -1.0) -> void:
	if weapon == null or weapon.pump_texture == null:
		return
	if _pump_tween:
		_pump_tween.kill()
	var rest: Vector2 = _pump_rest()
	var hand: Vector2 = _offhand_rest()
	var back := Vector2(-weapon.pump_travel, 0.0)
	var t: float = weapon.pump_time * 0.5
	_pump.position = rest
	_pump.rotation = 0.0
	var tw := create_tween()
	_pump_tween = tw
	tw.tween_interval(weapon.pump_delay if delay < 0.0 else delay)
	if weapon.lever_action:   # páka (Winchester 1894): ruka so spúšťou ju stiahne dole a vráti hore, druhá drží predok
		var down: float = -deg_to_rad(weapon.lever_deg)   # zadok páky (slučka) ide dole – zrkadlenie rieši gun.scale.y
		var grip: Vector2 = _ghost_grip_rest()
		var drop := Vector2(0.0, 2.0)
		tw.tween_callback(func(): Sfx.play(&"pump_back", Vector2.INF, -6.0, 0.12))
		tw.tween_property(_pump, "rotation", down, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ghost_hand, "position", grip + drop, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_eject_shell)
		tw.tween_callback(func(): Sfx.play(&"pump_fwd", Vector2.INF, -5.0, 0.12))
		tw.tween_property(_pump, "rotation", 0.0, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ghost_hand, "position", grip, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): _pump_tween = null)
		return
	if weapon.bolt_action:   # závorník (Springfield): ruka k rúčke, hore, dozadu, dopredu, dole, späť na predok
		var tb: float = weapon.pump_time / 5.0
		_bolt_open_steps(tw, tb, true)
		_bolt_close_steps(tw, tb)
		tw.tween_callback(func(): _pump_tween = null)
		return
	tw.tween_callback(func(): Sfx.play(&"pump_back", Vector2.INF, -5.0, 0.05))
	tw.tween_property(_pump, "position", rest + back, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(offhand, "position", hand + back, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_eject_shell)
	tw.tween_callback(func(): Sfx.play(&"pump_fwd", Vector2.INF, -4.0, 0.05))
	tw.tween_property(_pump, "position", rest, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(offhand, "position", hand, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _pump_tween = null)


## Pokojová poloha _pump v zbrani. Páka sa otáča okolo čapu – Sprite2D.offset (nastavený pri výmene zbrane) posunie
## obrázok tak, aby bol čap v počiatku spritu, a sprite stojí na mieste čapu. Godot docs: classes/class_sprite2d (offset)
func _pump_rest() -> Vector2:
	if weapon.lever_action:
		return _gun_px(weapon.pump_px + weapon.lever_pivot_px)
	return _gun_px(weapon.pump_px)


## Kde je ruka ducha (drží zbraň za krk pažby), keď nič nerobí
func _ghost_grip_rest() -> Vector2:
	return _gun_px(weapon.grip_px) + Vector2(-10, -6)


## Závorník: kde je druhá ruka, keď drží rúčku závorníka, ktorý je na mieste at (súradnice ako _pump.position)
func _bolt_hand(at: Vector2) -> Vector2:
	return at + weapon.bolt_knob_px - OFFHAND_GRIP


## Závorník otvorený (zdvihnutý a dozadu)
func _bolt_open_pos() -> Vector2:
	return _gun_px(weapon.pump_px) + Vector2(-weapon.pump_travel, -weapon.bolt_lift)


## Do tweenu pridá otvorenie závorníka: ruka prejde k rúčke, zdvihne ju a potiahne dozadu (eject = vyletí nábojnica).
## Trvá 2,5 × t. Godot docs: classes/class_tween (tween_property, parallel)
func _bolt_open_steps(tw: Tween, t: float, eject: bool) -> void:
	var rest: Vector2 = _gun_px(weapon.pump_px)
	var up := Vector2(0.0, -weapon.bolt_lift)
	tw.tween_property(offhand, "position", _bolt_hand(rest), t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Sfx.play(&"pump_back", Vector2.INF, -8.0, 0.05))
	tw.tween_property(_pump, "position", rest + up, t * 0.5)
	tw.parallel().tween_property(offhand, "position", _bolt_hand(rest + up), t * 0.5)
	tw.tween_property(_pump, "position", _bolt_open_pos(), t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(offhand, "position", _bolt_hand(_bolt_open_pos()), t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if eject:
		tw.tween_callback(_eject_shell)


## Do tweenu pridá zatvorenie závorníka: dopredu, sklopiť rúčku a ruka späť na predok zbrane. Trvá 2,5 × t.
func _bolt_close_steps(tw: Tween, t: float) -> void:
	var rest: Vector2 = _gun_px(weapon.pump_px)
	var up := Vector2(0.0, -weapon.bolt_lift)
	tw.tween_callback(func(): Sfx.play(&"pump_fwd", Vector2.INF, -7.0, 0.05))
	tw.tween_property(_pump, "position", rest + up, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(offhand, "position", _bolt_hand(rest + up), t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_pump, "position", rest, t * 0.5)
	tw.parallel().tween_property(offhand, "position", _bolt_hand(rest), t * 0.5)
	tw.tween_property(offhand, "position", _offhand_rest(), t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Vystrelená nábojnica vyletí z okienka pri puzdre (mag_px) hore a dozadu
func _eject_shell() -> void:
	if weapon == null or weapon.mag_texture == null:
		return
	var m := magazine_scene.instantiate()
	m.texture = weapon.mag_texture
	get_tree().current_scene.add_child(m)
	m.global_position = gun.to_global(_gun_px(weapon.mag_px))
	m.velocity = Vector2(-facing * randf_range(40.0, 75.0), randf_range(-130.0, -85.0))
	m.spin = randf_range(-12.0, 12.0)


## Pumpovačka sa nabíja po jednom náboji: druhá ruka pustí pumpu, prinesie náboj k otvoru pod puzdrom a zasunie ho –
## znova a znova, kým je miesto a náboje. Streľba to preruší (dobije sa ešte náboj v ruke). Ak bola zbraň celkom prázdna,
## na konci potiahne pumpu (náboj do komory).
func _start_shell_reload() -> void:
	_reload_cancel = false
	_reload_empty = ammo_in_mag == 0
	if _pump_tween:   # pumpa / páka ešte dobieha – dorovnať
		_pump_tween.kill()
		_pump_tween = null
		_pump.position = _pump_rest()
		_pump.rotation = 0.0
		ghost_hand.position = _ghost_grip_rest()
	offhand.visible = true
	offhand.fade = 1.0
	var tw := create_tween()
	_reload_tween = tw
	if weapon.bolt_action:   # Springfield: najprv otvoriť závorník – náboje idú zhora do puzdra
		_bolt_open_steps(tw, weapon.reload_time * 0.4, false)
	tw.tween_property(gun, "rotation", 0.2 * gun.scale.y, 0.08)   # ústie trochu dole, otvor k ruke
	tw.tween_callback(_load_one_shell)


func _load_one_shell() -> void:
	if weapon == null or not weapon.shell_reload:
		return
	var k: float = weapon.reload_time
	var port: Vector2 = _gun_px(weapon.mag_px) - OFFHAND_MAG
	var hand: Node = offhand.get_node("NewMag")
	hand.texture = weapon.new_mag_texture
	hand.visible = true
	var from_dir := Vector2(-5.0, 9.0)   # pumpovačka: náboj ide zdola do otvoru pod puzdrom (páka: do dvierok na boku)
	if weapon.bolt_action:
		from_dir = Vector2(-4.0, -9.0)   # závorník: zhora do otvoreného puzdra
	var tw := create_tween()
	_reload_tween = tw
	tw.tween_property(offhand, "position", port + from_dir, 0.45 * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(offhand, "position", port, 0.2 * k).set_ease(Tween.EASE_IN)
	tw.tween_callback(_shell_in)
	tw.tween_property(gun, "rotation", 0.2 * gun.scale.y - 0.06 * gun.scale.y, 0.05 * k)
	tw.tween_property(gun, "rotation", 0.2 * gun.scale.y, 0.1 * k)
	tw.parallel().tween_property(offhand, "position", port + from_dir * 0.75, 0.15 * k)
	tw.tween_callback(_after_shell)


func _shell_in() -> void:
	Sfx.play(&"shell_insert", Vector2.INF, -3.0)
	offhand.get_node("NewMag").visible = false
	if ammo_reserve > 0 and ammo_in_mag < mag_size:
		ammo_in_mag += 1
		ammo_reserve -= 1
		_store_ammo()
		ammo_changed.emit(ammo_in_mag, ammo_reserve, true)


func _after_shell() -> void:
	if not _reload_cancel and ammo_in_mag < mag_size and ammo_reserve > 0:
		_load_one_shell()
		return
	var tw := create_tween()
	_reload_tween = tw
	if weapon.bolt_action:   # závorník zatvoriť – náboj do komory
		tw.tween_property(gun, "rotation", 0.0, 0.12)
		tw.parallel().tween_property(offhand, "position", _bolt_hand(_bolt_open_pos()), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_bolt_close_steps(tw, weapon.reload_time * 0.4)
		tw.tween_callback(_finish_shell_reload)
		return
	tw.tween_property(offhand, "position", _offhand_rest(), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(gun, "rotation", 0.0, 0.14)
	tw.tween_callback(_finish_shell_reload)


func _finish_shell_reload() -> void:
	reloading = false
	_reload_tween = null
	offhand.get_node("NewMag").visible = false
	offhand.position = _offhand_rest()
	ammo_changed.emit(ammo_in_mag, ammo_reserve, false)
	if _reload_empty and ammo_in_mag > 0 and not weapon.bolt_action:   # z prázdnej zbrane – náboj do komory (závorník už zavrel)
		_pump_action(0.0)
		fire_timer = maxf(fire_timer, weapon.pump_time + 0.05)
	_reload_empty = false
	if _holster_after_reload:
		_holster_after_reload = false
		_holster()


## Starý zásobník / nábojnice / broky sa pustia – ďalej padajú samé (magazine_drop.gd)
func _drop_magazine() -> void:
	Sfx.play(&"cylinder_spin" if weapon.name == "Revolver" else &"mag_out", Vector2.INF, -4.0)
	var center: Vector2 = mag.texture.get_size() / 2.0
	for i in weapon.drop_count:
		var m := magazine_scene.instantiate()
		m.texture = weapon.mag_texture
		get_tree().current_scene.add_child(m)
		m.global_position = mag.to_global(center)
		m.rotation = mag.global_rotation
		m.velocity = Vector2(-facing * randf_range(15.0, 45.0), randf_range(-20.0, 25.0))
		m.spin = randf_range(-8.0, 8.0)
	mag.visible = false


func _magazine_inserted() -> void:
	Sfx.play(&"shell_insert" if weapon.name in ["Lupara", "Derringer"] else &"mag_in", Vector2.INF, -3.0)
	mag.position = _gun_px(weapon.mag_px)
	mag.texture = weapon.mag_texture
	mag.visible = weapon.mag_visible
	offhand.get_node("NewMag").visible = false


func _finish_reload() -> void:
	if weapon.name in ["Pistol", "Tommy gun"]:
		Sfx.play(&"slide_rack", Vector2.INF, -5.0)
	var need: int = mag_size - ammo_in_mag
	var take: int = mini(need, ammo_reserve)
	ammo_in_mag += take
	ammo_reserve -= take
	_store_ammo()
	reloading = false
	_reload_tween = null
	offhand.get_node("NewMag").visible = false
	offhand.visible = weapon.two_handed
	offhand.fade = 1.0
	if is_akimbo():
		_akimbo_reload_in()
	ammo_changed.emit(ammo_in_mag, ammo_reserve, false)
	if _holster_after_reload:
		_holster_after_reload = false
		_holster()


# ---------------------------------------------------------------- akimbo (dve bočné zbrane)
## Druhá ruka ducha drží druhú, rovnakú bočnú zbraň (duch si ju „vyčaruje“ – netreba zbierať druhú). Zadná zbraň je
## kúsok vpredu a vyššie (AKIMBO_OFF), za Riccom (z_index -1) a tmavšia – je ďalej od kamery. Obe mieria na myš
## a strieľajú striedavo (predná, zadná, …). Náboje sú spoločné: ammo_in_mag = oba zásobníky spolu (mag_size je
## dvojnásobný), rezerva je jedna. Pri prebíjaní zadná zbraň pustí svoj zásobník a počká (zošedne), kým druhá ruka
## dobije prednú – preto to trvá dlhšie (AKIMBO_RELOAD). Len bočné zbrane (SIDEARM) – dvojručné by nedržal.
## Godot docs: classes/class_sprite2d (z_index, self_modulate), classes/class_tween

const AKIMBO_OFF := Vector2(3, -6)            ## px – zadná zbraň voči prednej (v priestore Aim, pri mierení doľava sa y otočí)
const AKIMBO_SHADE := Color(0.72, 0.72, 0.8)  ## zadná zbraň a ruka sú tmavšie
const AKIMBO_COOLDOWN := 0.6                  ## × fire_cooldown – striedavá streľba je rýchlejšia
const AKIMBO_SPREAD := 1.5                    ## × rozptyl – z dvoch zbraní naraz sa mieri horšie
const AKIMBO_RELOAD := 1.5                    ## × reload_time – prebíja obe
const GHOST_HAND_SCENE := preload("res://characters/ricco/ghost_hand/ghost_hand.tscn")

static var akimbo: bool = false   ## hráč má akimbo zapnuté (pamätá sa medzi časťami kapitoly); platí len pri bočnej zbrani
var _gun2: Sprite2D               ## zadná zbraň (dieťa Aim)
var _gun2_mag: Sprite2D
var _gun2_hand: GhostHand
var _gun2_muzzle: Marker2D
var _gun2_flash: Sprite2D
var _gun2_x: float = 0.0          ## px – posun zadnej zbrane dozadu (spätný ráz, prebíjanie, objavenie)
var _gun2_tween: Tween
var _gun2_flash_tw: Tween
var _akimbo_back_next: bool = false   ## ďalší výstrel ide zo zadnej zbrane


## Akimbo práve platí (zapnuté, odomknuté a v ruke je bočná zbraň)
func is_akimbo() -> bool:
	return akimbo and akimbo_unlocked and weapon != null and weapon.slot_name == "SIDEARM"


## Dá sa akimbo prepnúť klávesom B (nie počas prebíjania – zásobníky by sa pomiešali)
func can_akimbo() -> bool:
	return akimbo_unlocked and weapon != null and weapon.slot_name == "SIDEARM" and not reloading and not holstered


## Koľko nábojov sa zmestí do zbrane w (pri akimbo dva zásobníky)
func _mag_cap(w: WeaponData) -> int:
	return w.mag_size * (2 if akimbo and akimbo_unlocked and w.slot_name == "SIDEARM" else 1)


## Zapne / vypne akimbo. Pri vypnutí sa náboje z druhého zásobníka vrátia do rezervy.
func set_akimbo(on: bool) -> void:
	akimbo = on
	_store_ammo()
	if not on:
		for i in loadout.size():
			var w: WeaponData = loadout[i]
			var extra: int = weapon_ammo[i][0] - w.mag_size
			if extra > 0:
				weapon_ammo[i] = [w.mag_size, weapon_ammo[i][1] + extra]
		if weapon:
			ammo_in_mag = weapon_ammo[weapon_index][0]
			ammo_reserve = weapon_ammo[weapon_index][1]
	_akimbo_back_next = false
	_update_akimbo_gun(true)
	if weapon and weapon.slot_name == "SIDEARM":
		Sfx.play(&"slide_rack" if on else &"mag_in", global_position, -6.0, 0.05)
	fire_mode_changed.emit(is_akimbo())
	ammo_changed.emit(ammo_in_mag, ammo_reserve, reloading)


func _setup_akimbo() -> void:
	_gun2 = Sprite2D.new()
	_gun2.z_index = -1   # za Riccom – je to vzdialenejšia ruka
	_gun2.self_modulate = AKIMBO_SHADE
	_gun2.visible = false
	aim.add_child(_gun2)
	aim.move_child(_gun2, 0)
	_gun2_mag = Sprite2D.new()
	_gun2_mag.centered = false
	_gun2_mag.show_behind_parent = true
	_gun2_mag.self_modulate = AKIMBO_SHADE
	_gun2.add_child(_gun2_mag)
	_gun2_hand = GHOST_HAND_SCENE.instantiate() as GhostHand
	(_gun2_hand.get_node(^"Hand") as CanvasItem).self_modulate = AKIMBO_SHADE
	_gun2.add_child(_gun2_hand)
	_gun2_muzzle = Marker2D.new()
	_gun2.add_child(_gun2_muzzle)
	_gun2_flash = Sprite2D.new()
	_gun2_flash.texture = FLASH_TEX
	_gun2_flash.hframes = 3
	_gun2_flash.centered = false
	_gun2_flash.offset = Vector2(-3, -12)
	_gun2_flash.position = Vector2(1, 0)
	_gun2_flash.visible = false
	_gun2_muzzle.add_child(_gun2_flash)


## Zadná zbraň podľa zbrane v ruke (alebo sa schová, ak akimbo neplatí). animate = vysunie sa spoza Ricca.
func _update_akimbo_gun(animate: bool = false) -> void:
	if _gun2 == null:
		return
	if _gun2_tween:
		_gun2_tween.kill()
		_gun2_tween = null
	if not is_akimbo():
		_gun2.visible = false
		return
	_gun2.texture = weapon.texture
	_gun2.rotation = 0.0
	_gun2_mag.texture = weapon.mag_texture
	_gun2_mag.position = _gun_px(weapon.mag_px)
	_gun2_mag.visible = weapon.mag_visible
	_gun2_hand.position = _ghost_grip_rest()
	_gun2_muzzle.position = _gun_px(weapon.muzzle_px)
	_gun2_flash.visible = false
	_gun2_x = 0.0
	_gun2.modulate.a = 1.0
	_gun2.visible = true
	if animate:
		_gun2_x = -10.0
		_gun2.modulate.a = 0.0
		_gun2_tween = create_tween().set_parallel(true)
		_gun2_tween.tween_property(self, "_gun2_x", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_gun2_tween.tween_property(_gun2, "modulate:a", 1.0, 0.1)
	_update_akimbo_pose()


## Zadná zbraň ide s prednou (aj pri jej poskočení pri výmene); pri mierení doľava sa preklopí ako predná
func _update_akimbo_pose() -> void:
	if _gun2 == null or not _gun2.visible:
		return
	_gun2.scale.y = gun.scale.y
	_gun2.position = Vector2(gun_base_x + AKIMBO_OFF.x + _gun2_x, gun.position.y + AKIMBO_OFF.y * gun.scale.y)


## Výstrel zo zadnej zbrane: záblesk, iskry, dym a spätný ráz len na nej (svetlo záblesku je spoločné)
func _akimbo_shot(recoil: float) -> void:
	var k: float = FLASH_SCALE.get(weapon.name, 0.8)
	_gun2_flash.scale = Vector2(k, k * randf_range(0.85, 1.15))
	_gun2_flash.rotation = randf_range(-0.12, 0.12)
	_gun2_flash.frame = 0
	_gun2_flash.visible = true
	if _gun2_flash_tw:
		_gun2_flash_tw.kill()
	_gun2_flash_tw = create_tween()
	_gun2_flash_tw.tween_interval(0.045)
	_gun2_flash_tw.tween_callback(func(): _gun2_flash.frame = 1)
	_gun2_flash_tw.tween_interval(0.045)
	_gun2_flash_tw.tween_callback(func(): _gun2_flash.frame = 2)
	_gun2_flash_tw.tween_interval(0.05)
	_gun2_flash_tw.tween_callback(func(): _gun2_flash.visible = false)
	_flash_light.enabled = true
	_flash_light.energy = (1.1 + 0.3 * k) * randf_range(0.85, 1.1)
	_flash_light.texture_scale = 2.0 + 1.4 * k
	if _light_tw:
		_light_tw.kill()
	_light_tw = create_tween()
	_light_tw.tween_property(_flash_light, "energy", 0.0, 0.2).set_delay(0.06)
	_light_tw.tween_callback(func(): _flash_light.enabled = false)
	var at: Vector2 = _gun2_muzzle.global_position
	Burst.spawn(get_tree().current_scene, at, aim_dir, Color(1.0, 0.8, 0.4), 5 if k < 1.2 else 10, 110.0, Vector2(0, 120), 0.22)
	GunSmoke.spawn(get_tree().current_scene, at, aim_dir, k)
	if _gun2_tween:
		_gun2_tween.kill()
	_gun2_x = -recoil
	_gun2.rotation = -0.045 * recoil * gun.scale.y
	_gun2_tween = create_tween().set_parallel(true)
	_gun2_tween.tween_property(self, "_gun2_x", 0.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gun2_tween.tween_property(_gun2, "rotation", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Začiatok prebíjania: zadná zbraň sa nakloní, pustí zásobník (nábojnice) a stiahne sa dozadu – čaká na druhú ruku
func _akimbo_reload_out() -> void:
	if _gun2_tween:
		_gun2_tween.kill()
	var tilt: float = -0.35 * gun.scale.y
	_gun2_tween = create_tween()
	_gun2_tween.tween_property(_gun2, "rotation", tilt, 0.08)
	_gun2_tween.tween_callback(_akimbo_drop_mag)
	_gun2_tween.tween_property(self, "_gun2_x", -6.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gun2_tween.parallel().tween_property(_gun2, "modulate:a", 0.4, 0.18)


func _akimbo_drop_mag() -> void:
	if weapon == null or weapon.mag_texture == null:
		return
	var center: Vector2 = weapon.mag_texture.get_size() / 2.0
	for i in weapon.drop_count:
		var m := magazine_scene.instantiate()
		m.texture = weapon.mag_texture
		get_tree().current_scene.add_child(m)
		m.global_position = _gun2.to_global(_gun_px(weapon.mag_px) + center)
		m.rotation = _gun2.global_rotation
		m.velocity = Vector2(-facing * randf_range(15.0, 45.0), randf_range(-20.0, 25.0))
		m.spin = randf_range(-8.0, 8.0)
	_gun2_mag.visible = false


## Koniec prebíjania: zadná zbraň je zase nabitá a vráti sa na miesto
func _akimbo_reload_in() -> void:
	if _gun2_tween:
		_gun2_tween.kill()
	_gun2_mag.visible = weapon.mag_visible
	Sfx.play(&"mag_in", Vector2.INF, -8.0, 0.1)
	_gun2_tween = create_tween().set_parallel(true)
	_gun2_tween.tween_property(_gun2, "rotation", 0.0, 0.12)
	_gun2_tween.tween_property(self, "_gun2_x", 0.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gun2_tween.tween_property(_gun2, "modulate:a", 1.0, 0.1)


# ---------------------------------------------------------------- výbava (viac zbraní)

## Pixel v obrázku zbrane → súradnice uzla Gun (obrázok je centrovaný)
func _gun_px(px: Vector2) -> Vector2:
	return px - weapon.texture.get_size() / 2.0


## Kde druhá ruka drží predok dvojručnej zbrane
func _offhand_rest() -> Vector2:
	return _gun_px(weapon.foregrip_px) - OFFHAND_GRIP


## Vezme do ruky zbraň z výbavy. Prebíjanie sa preruší (náboje ostanú, ako boli).
## Ruka ducha drží každú zbraň za rukoväť na tom istom mieste – zbraň sa posunie podľa grip_px.
const PISTOL_GRIP := Vector2(25.5, -0.5)   ## kde je vrch rukoväte voči Aim (ako pri pištoli na x = 33)

func _equip(i: int, animate: bool = true) -> void:
	if loadout.is_empty():
		return
	i = posmod(i, loadout.size())
	if weapon and i == weapon_index:
		return
	if holstered:
		_draw_weapon(false)   # nová zbraň (zdvihnutá zo zeme) je hneď v ruke
	_holster_after_reload = false
	if weapon:
		last_weapon_index = weapon_index
		_store_ammo()
	if _reload_tween:
		_reload_tween.kill()
		_reload_tween = null
	reloading = false
	weapon_index = i
	weapon = loadout[i]
	Progress.unlock(weapon.name)   # prvý raz v ruke → odomknutá v Arsenale
	_bloom = 0.0
	_barrels.visible = false   # prerušené lámacie prebíjanie
	_barrels.rotation = 0.0
	if _pump_tween:
		_pump_tween.kill()
		_pump_tween = null
	ammo_in_mag = weapon_ammo[i][0]
	ammo_reserve = weapon_ammo[i][1]
	gun.texture = weapon.texture
	gun.rotation = 0.0
	if weapon.pump_texture:   # pumpovačka: telo zvlášť, pumpa ako samostatný obrázok (hýbe sa)
		gun.texture = weapon.pump_body_texture if weapon.pump_body_texture else weapon.texture
		_pump.texture = weapon.pump_texture
		_pump.offset = -weapon.lever_pivot_px if weapon.lever_action else Vector2.ZERO   # páka sa otáča okolo čapu
		_pump.rotation = 0.0
		_pump.position = _pump_rest()
	_pump.visible = weapon.pump_texture != null
	gun.position = PISTOL_GRIP - _gun_px(weapon.grip_px)
	gun_base_x = gun.position.x
	ghost_hand.position = _ghost_grip_rest()
	muzzle.position = _gun_px(weapon.muzzle_px)
	mag.texture = weapon.mag_texture
	mag.position = _gun_px(weapon.mag_px)
	mag.visible = weapon.mag_visible
	offhand.get_node("NewMag").visible = false
	offhand.visible = weapon.two_handed
	offhand.fade = 1.0
	offhand.position = _offhand_rest() if weapon.two_handed else OFFHAND_START
	fire_timer = maxf(fire_timer, 0.12)
	_akimbo_back_next = false
	_update_akimbo_gun()
	if animate:   # zbraň vyskočí zdola (krátke „vytiahnutie“)
		if _swap_tween:
			_swap_tween.kill()
		gun.position.y += 8.0
		gun.modulate.a = 0.0
		_swap_tween = create_tween().set_parallel(true)
		_swap_tween.tween_property(gun, "position:y", gun.position.y - 8.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_swap_tween.tween_property(gun, "modulate:a", 1.0, 0.08)
	weapon_changed.emit(weapon)
	ammo_changed.emit(ammo_in_mag, ammo_reserve, false)


func _store_ammo() -> void:
	if weapon:
		weapon_ammo[weapon_index] = [ammo_in_mag, ammo_reserve]


## Nová výbava (napr. level začína bez zbrane: set_loadout([])). Náboje sa nastavia na začiatočné.
func set_loadout(list: Array[WeaponData]) -> void:
	if _reload_tween:
		_reload_tween.kill()
		_reload_tween = null
	reloading = false
	loadout = list
	weapon_ammo.clear()
	for w in loadout:
		weapon_ammo.append([_mag_cap(w), w.reserve_start])   # akimbo – obe bočné nabité
	weapon = null
	weapon_index = 0
	last_weapon_index = 0
	if loadout.is_empty():
		offhand.visible = false
		ammo_in_mag = 0
		ammo_reserve = 0
		weapon_changed.emit(null)
		ammo_changed.emit(0, 0, false)
	else:
		_equip(0, false)


## Zdvihne zbraň (napr. duch Dona podá Colt, alebo zbraň po gangstrovi) a hneď ju vezme do ruky.
func give_weapon(w: WeaponData) -> void:
	var i: int = loadout.find(w)
	if i < 0:
		loadout.append(w)
		weapon_ammo.append([w.mag_size, w.reserve_start])
		i = loadout.size() - 1
	_equip(i)


## 1–3 = zbraň z výbavy (1 bočná, 2–3 hlavné), koliesko myši = ďalšia/predošlá, Q = posledná použitá (klávesy z KeyBindings)
func _weapon_switch_input(event: InputEvent) -> void:
	if state == State.DEAD:
		return
	for n in 3:
		if event.is_action_pressed(StringName("weapon_%d" % (n + 1))) and n < loadout.size():
			_draw_weapon()
			_equip(n)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"fire_mode") and weapon and weapon.alt_mode != WeaponData.AltMode.NONE:
		alt_fire[weapon] = not is_alt_fire()
		Sfx.play(&"dry_fire", global_position, -8.0, 0.05)   # cvaknutie prepínača
		fire_mode_changed.emit(is_alt_fire())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"fire_mode") and can_akimbo():
		set_akimbo(not akimbo)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"weapon_last"):
		_draw_weapon()
		_equip(last_weapon_index)
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_draw_weapon()
			_equip(weapon_index + 1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_draw_weapon()
			_equip(weapon_index - 1)


## Snímky behu, v ktorých dopadne labka (na ne patrí obláčik prachu)
const RUN_STEP_FRAMES: Array[int] = [0, 5]

func _on_sprite_frame_changed() -> void:
	if sprite.animation in [&"run", &"run_nohat"] and sprite.frame in RUN_STEP_FRAMES and is_on_floor():
		Sfx.play(&"step_1" if sprite.frame == 0 else &"step_2", Vector2.INF, -14.0 if sneaking else -8.0, 0.1)
		var back := Vector2(-signf(velocity.x), -0.4).normalized()
		Burst.spawn(get_tree().current_scene, global_position + Vector2(signf(velocity.x) * 6.0, -1.0), back,
				Color(0.78, 0.74, 0.68, 0.8), 4, 28.0, Vector2(0, -25), 0.4)
	if sprite.animation in [&"hat_throw", &"hat_throw_walk"] and sprite.frame == HAT_RELEASE_FRAME and has_hat:
		_launch_hat()


func _launch_hat() -> void:
	has_hat = false
	Sfx.play(&"hat_throw", Vector2.INF, -2.0)
	var h := hat_scene.instantiate()
	get_tree().current_scene.add_child(h)
	var start: Vector2 = global_position + Vector2(facing * 12.0, -30.0)
	var to_mouse: Vector2 = get_global_mouse_position() - start
	h.launch(start, to_mouse if to_mouse.length() > 4.0 else aim_dir, self)  # mieri presne na kurzor
	h.caught.connect(_on_hat_caught)


func _on_hat_caught() -> void:
	has_hat = true
	Sfx.play(&"hat_catch", Vector2.INF, -4.0)
	if is_on_floor() and state == State.NORMAL and absf(velocity.x) < 10.0:
		sprite.play(&"hat_catch")


# ---------------------------------------------------------------- šmyk po bruchu

## Šmyk: Ricco skočí na brucho a kĺže sa (tučniak na ľade). Je nižší (prekĺzne popod prekážky),
## nedá sa riadiť, ale dá sa strieľať všetkými smermi – Ricco sa pri tom neotáča.
## Skok šmyk ukončí (rýchlosť ostane), pustenie klávesu alebo spomalenie → postaví sa,
## ale len ak má nad sebou miesto. Pri zídení z hrany normálne padá.
## Smer šmyku: kam hráč tlačí, inak kam sa Ricco hýbe, inak kam sa pozerá
func _slide_dir() -> float:
	var input_dir: float = signf(Input.get_axis("move_left", "move_right"))
	return input_dir if input_dir != 0.0 else (signf(velocity.x) if absf(velocity.x) > 20.0 else facing)


## Dá sa šmyknúť? Tesne pred Riccom nesmie byť stena ani prekážka (debna) – inak by šmyk hneď skončil
## (Godot docs: PhysicsBody2D.test_move – skúsi posun bez pohnutia telom).
func _slide_room(dir: float) -> bool:
	var probe := Transform2D(PI / 2.0, global_position + Vector2(0, -slide_shape.radius - 1.0))
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = slide_shape
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	q.transform = probe.translated(Vector2(dir * 10.0, 0))
	return _only_platforms(get_world_2d().direct_space_state.intersect_shape(q, 4))


func _start_slide() -> void:
	var dir: float = _slide_dir()
	_slide_t = 0.0
	state = State.SLIDE
	var run_speed: float = absf(velocity.x) if signf(velocity.x) == dir else 0.0
	velocity.x = dir * maxf(run_speed + slide_boost + (ice_slide_boost if on_ice else 0.0), slide_speed)
	velocity.y = 0.0
	wall_sliding = false
	facing = dir
	visual.scale.x = facing
	visual.rotation = 0.0
	visual.position = Vector2.ZERO
	sprite.speed_scale = 1.0
	sprite.offset = Vector2.ZERO
	_set_slide_shape(true)
	sprite.play(_hat_anim(&"slide_start"))
	Sfx.play(&"belly_slide", Vector2.INF, -2.0)
	Burst.spawn(get_tree().current_scene, global_position + Vector2(-dir * 4.0, -1.0), Vector2(-dir, -0.5).normalized(),
			_slide_dust_color(0.8), 6, 45.0, Vector2(0, -25), 0.4)


func _process_slide(delta: float) -> void:
	velocity += get_gravity() * delta
	velocity.x = move_toward(velocity.x, 0.0, (ice_slide_friction if on_ice else slide_friction) * delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	_update_aim()
	_update_weapons()
	move_and_slide()
	_update_ice()
	_slide_trip()

	if not is_on_floor():
		if _can_stand():   # zišiel z hrany → normálny pád
			_end_slide(false)
		return
	if jump_buffer_timer > 0.0 and _can_stand():
		_end_slide(false)
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		sprite.play(_hat_anim(&"jump"))
		return
	_slide_t += delta
	# šmyk trvá aspoň chvíľu (pustenie klávesy hneď po štarte ho neutne uprostred animácie)
	# na ľade sa šmýka ďalej aj po pustení klávesy (zastaví ho až trenie, alebo vyskočí)
	var want_up: bool = absf(velocity.x) < slide_min_speed or (not Input.is_action_pressed(&"slide") and _slide_t > SLIDE_MIN_TIME and not on_ice)
	var room: bool = _can_stand()
	if want_up and room:
		_end_slide(true)
		return
	# pod nízkym stropom sa nedá postaviť → plazí sa po bruchu tam, kam hráč tlačí (nezasekne sa)
	if not room and absf(velocity.x) <= crawl_speed:
		var dir: float = signf(Input.get_axis("move_left", "move_right"))
		velocity.x = dir * crawl_speed
		if dir != 0.0 and dir != facing:
			facing = dir
			visual.scale.x = facing
		if sprite.animation == _hat_anim(&"slide_start"):
			sprite.play(_hat_anim(&"slide"))
		sprite.speed_scale = 0.5 if dir != 0.0 else 0.0
	# klobúk sa vrátil (alebo odletel) počas šmyku → prepni s/bez klobúka na tom istom snímku
	if sprite.animation in [&"slide", &"slide_nohat"] and sprite.animation != _hat_anim(&"slide"):
		var fr: int = sprite.frame
		sprite.play(_hat_anim(&"slide"))
		sprite.frame = fr
	# prach spod brucha
	slide_dust_timer -= delta
	if slide_dust_timer <= 0.0 and absf(velocity.x) > 60.0:
		slide_dust_timer = 0.07
		Burst.spawn(get_tree().current_scene, global_position + Vector2(-facing * 12.0, -1.0), Vector2(-facing, -0.6).normalized(),
				_slide_dust_color(0.6), 2, 30.0, Vector2(0, -20), 0.3)
	was_on_floor = true


## Prach spod brucha – na ľade biele ľadové triesky
## Podkopnutie: šmyk po bruchu do mafiána ho zvalí na chrbát (Gangster.trip) – kým leží, dá sa zneškodniť (F).
## Šmyk sa pri tom trochu spomalí.
func _slide_trip() -> void:
	if absf(velocity.x) < slide_trip_speed or not is_on_floor():
		return
	var dir: float = signf(velocity.x)
	for g in get_tree().get_nodes_in_group(&"enemies"):
		var e := g as Node2D
		if e == null or not e.has_method(&"trip"):
			continue
		var dx: float = e.global_position.x - global_position.x
		if absf(dx) < 18.0 and signf(dx) == dir and absf(e.global_position.y - global_position.y) < 16.0:
			if e.trip(dir):
				velocity.x *= 0.7
				shake_timer = 0.1
				shake_strength = 2.0


func _slide_dust_color(a: float) -> Color:
	return Color(0.86, 0.95, 1.0, a) if on_ice else Color(0.78, 0.74, 0.68, a)


func _end_slide(get_up: bool) -> void:
	state = State.NORMAL
	sprite.speed_scale = 1.0
	_set_slide_shape(false)
	if get_up:
		sprite.play(_hat_anim(&"slide_end"))
		Sfx.play(&"slide_getup", Vector2.INF, -8.0)


## Vymení kapsulu: stojaca (zvislá) ↔ ležiaca (vodorovná, pri zemi). Zbraň ide nižšie k zemi.
func _set_slide_shape(sliding: bool) -> void:
	if sliding:
		body_shape.shape = slide_shape
		body_shape.rotation = PI / 2.0
		body_shape.position = Vector2(0, -slide_shape.radius)
		aim.position.y = -slide_aim_height
		_fit_slide_shape()
	else:
		body_shape.shape = stand_shape
		body_shape.rotation = 0.0
		body_shape.position = Vector2(0, -HEIGHT / 2.0)
		aim.position.y = aim_base_y


## Ležiaca kapsula je širšia ako stojaci Ricco – keď sa šmykne tesne pri stene, posunie ho kúsok od nej,
## aby neuviazol v stene.
func _fit_slide_shape() -> void:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = slide_shape
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	for dx in [0.0, 2.0, -2.0, 4.0, -4.0, 6.0, -6.0, 8.0, -8.0, 10.0, -10.0, 12.0, -12.0]:
		q.transform = Transform2D(PI / 2.0, global_position + Vector2(dx, -slide_shape.radius - 0.5))
		if _only_platforms(space.intersect_shape(q, 4)):
			global_position.x += dx
			return


## Zmestí sa tu Ricco postavený? (Godot docs: classes/class_physicsdirectspacestate2d – intersect_shape)
## Tenké jednosmerné plošinky (skupina "platform") sa nerátajú – cez tie sa dá postaviť zospodu.
func _can_stand() -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = stand_shape
	q.transform = Transform2D(0.0, global_position + Vector2(0, -HEIGHT / 2.0 - 1.0))
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	return _only_platforms(get_world_2d().direct_space_state.intersect_shape(q, 4))


func _only_platforms(hits: Array[Dictionary]) -> bool:
	for h in hits:
		var c := h.collider as Node
		if c == null or not c.is_in_group(&"platform"):
			return false
	return true


# ---------------------------------------------------------------- jedlo (V)

## Zje prvé jedlo zo zásoby (Food.carried) – len na zemi, keď nie je celý zdravý a nič iné nerobí.
## Počas jedenia nestrieľa a ide pomaly; skok, šmyk alebo zásah ho preruší (jedlo ostane v zásobe).
func _update_eat() -> void:
	if eating or not Input.is_action_just_pressed(&"eat"):
		return
	if Food.carried.is_empty():
		return
	if health >= max_health or not is_on_floor() or reloading or _throwing() or _takedown_t > 0.0:
		Sfx.play(&"ui_back", Vector2.INF, -14.0, 0.0)   # teraz nie (je sýty alebo práve niečo robí)
		return
	eating = true
	aim.visible = false
	_eat.start(Food.carried[0])


func _cancel_eat() -> void:
	if not eating:
		return
	eating = false
	_eat.cancel()


func _on_gulped(kind: StringName) -> void:
	var i: int = Food.carried.find(kind)
	if i >= 0:
		Food.carried.remove_at(i)
	heal(Food.HEAL.get(kind, 2))
	if kind == &"espresso":
		_espresso_t = Food.ESPRESSO_TIME
	food_changed.emit()
	Burst.spawn(get_tree().current_scene, global_position + Vector2(0, -34), Vector2.UP, Color(0.95, 0.35, 0.4), 6, 40.0, Vector2(0, -20), 0.6)


func _on_eat_finished() -> void:
	eating = false


# ---------------------------------------------------------------- krytie (C pri nízkej prekážke)

const COVER_REACH := 8.0      ## px – kryt môže byť takto ďaleko od kapsuly
const COVER_MIN_H := 12.0     ## px – nižšie veci (schod) nie sú kryt
const COVER_MAX_H := 32.0     ## px – vyššie sa dá schovať aj postojačky (stena), skrčenie netreba
const COVER_HEIGHT := 22.0    ## px – výška kapsuly skrčeného Ricca
const COVER_POP_TIME := 0.5   ## s – po výstrele ostane vystrčený nad krytom
const COVER_LAYER := 32

## Pri zakrádaní (C) tesne pri nízkej prekážke sa Ricco skrčí: nízka kapsula, guľky z druhej strany
## zastaví kryt (gangstri mieria do výšky skrčeného – characters/gangster/gangster.gd _player_target).
## Výstrel ho na chvíľu vystrčí nad kryt.
func _update_cover(delta: float) -> void:
	_cover_pop -= delta
	var side: float = 0.0
	if sneaking and is_on_floor() and state == State.NORMAL:
		for s: float in [facing, -facing]:
			if _cover_at(s):
				side = s
				break
	in_cover = side != 0.0
	cover_side = side
	_set_duck(in_cover and _cover_pop <= 0.0)


## Je na strane s nízka prekážka (vrch 12–32 px nad nohami)? Godot docs: classes/class_physicsdirectspacestate2d
func _cover_at(s: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from: Vector2 = global_position + Vector2(0, -6)
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, from + Vector2(s * (HALF_WIDTH + COVER_REACH), 0), 1 | COVER_LAYER))
	if hit.is_empty():
		return false
	var x: float = hit.position.x + s * 3.0
	var top := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, global_position.y - COVER_MAX_H - 12.0), Vector2(x, global_position.y - 2.0), 1 | COVER_LAYER))
	if top.is_empty():
		return false
	var h: float = global_position.y - top.position.y
	return h >= COVER_MIN_H and h <= COVER_MAX_H


## Poistka: keď sa Ricco ocitne vnútri pevného telesa (padla naňho debna, posunula sa plošina…), chvíľu počká
## a potom ho vysadí na najbližšie voľné miesto nad ním alebo vedľa neho. Godot docs: classes/class_physicsdirectspacestate2d
var _stuck_t: float = 0.0

func _embedded(at: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = body_shape.shape
	q.transform = Transform2D(0.0, at + body_shape.position)
	q.collision_mask = 1
	q.margin = -1.0
	q.exclude = [get_rid()]
	for h in get_world_2d().direct_space_state.intersect_shape(q, 4):
		if not (h.collider as Node).is_in_group(&"platform"):
			return true
	return false


func _unstick(delta: float) -> void:
	if not _embedded(global_position):
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t < 0.25:
		return
	_stuck_t = 0.0
	for d in range(4, 72, 4):
		for off in [Vector2(0, -d), Vector2(-d, 0), Vector2(d, 0)]:
			if not _embedded(global_position + off):
				global_position += off
				velocity = Vector2.ZERO
				return


func _set_duck(on: bool) -> void:
	if on == ducked or (not on and not _can_stand()):
		return
	ducked = on
	body_shape.shape = cover_shape if on else stand_shape
	body_shape.position = Vector2(0, -(COVER_HEIGHT if on else HEIGHT) / 2.0)


# ---------------------------------------------------------------- zdravie

## Zásah: uberie zdravie, odhodí Ricca od zdroja (from), na chvíľu je nesmrteľný a bliká.
## from = odkiaľ prišiel zásah (napr. pozícia guľky); Vector2.INF = bez odhodenia.
func take_damage(amount: int = 1, from: Vector2 = Vector2.INF) -> void:
	if state == State.DEAD or invulnerable_timer > 0.0 or amount <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_cancel_eat()
	_blood_fx(from)
	_hurt_fx(health == 0)
	if health == 0:
		_die()
		return
	Sfx.play(&"hurt")
	invulnerable_timer = invulnerable_time
	if from != Vector2.INF and state == State.NORMAL:
		var away: float = signf(global_position.x - from.x)
		velocity = Vector2((away if away != 0.0 else -facing) * hurt_knockback.x, hurt_knockback.y)
	if state == State.NORMAL:
		sprite.play(_hat_anim(&"hurt"))   # zľakne sa, klobúk poskočí a dopadne späť


const SHOT_NOISE := 520.0   ## px – do tejto vzdialenosti gangstri počujú výstrel (skoro celá obrazovka na každú stranu)
const HURT_SHADER := """
shader_type canvas_item;
// červené okraje obrazovky pri zásahu (a slabo pulzujúce, keď Riccovi zostáva málo zdravia)
uniform float strength = 0.0;
void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(1.0, 0.8);
	float v = smoothstep(0.22, 0.62, length(d));
	COLOR = vec4(0.72, 0.02, 0.04, v * strength);
}
"""

var _hurt_rect: ColorRect
var _hurt_flash: float = 0.0   ## 0–1, po zásahu rýchlo klesne


## Pocit zásahu: silné zatrasenie kamery, červené okraje obrazovky a na okamih zastavený svet (hitstop)
func _hurt_fx(fatal: bool) -> void:
	shake_timer = 0.32 if fatal else 0.24
	shake_strength = 5.0 if fatal else 3.5
	if _hurt_rect == null:
		var layer := CanvasLayer.new()
		layer.layer = 30
		add_child(layer)
		_hurt_rect = ColorRect.new()
		_hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = HURT_SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		_hurt_rect.material = m
		layer.add_child(_hurt_rect)
	_hurt_flash = 1.0
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(self, "_hurt_flash", 0.0, 0.5).set_delay(0.06)
	# hitstop: svet na zlomok sekundy takmer stojí (nie počas spomalenia – to má vlastný time_scale)
	if is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 0.05
		get_tree().create_timer(0.08 if fatal else 0.06, true, false, true).timeout.connect(func():
			if is_equal_approx(Engine.time_scale, 0.05):
				Engine.time_scale = 1.0)


func _update_hurt_overlay() -> void:
	if _hurt_rect == null:
		return
	var low: float = 0.0   # málo zdravia → okraje slabo pulzujú ako tlkot srdca
	if state != State.DEAD and health > 0 and health <= 2:
		low = 0.22 + 0.12 * maxf(0.0, sin(Time.get_ticks_msec() * 0.006))
	(_hurt_rect.material as ShaderMaterial).set_shader_parameter(&"strength", maxf(_hurt_flash * 0.8, low))


## Guľka od gangstra (bullet.gd volá take_hit na všetkom, čo zasiahne)
func take_hit(damage: int, dir: Vector2) -> void:
	take_damage(damage, global_position - dir * 30.0)


## Doplní zbraň z výbavy na začiatočné náboje (strelnica – zbrojnica). Vráti false, ak ju nemá alebo je plná.
func refill_weapon(w: WeaponData) -> bool:
	var i: int = loadout.find(w)
	if i < 0:
		return false
	_store_ammo()
	var full: Array = [_mag_cap(w), maxi(weapon_ammo[i][1], w.reserve_start)]
	if weapon_ammo[i][0] >= full[0] and weapon_ammo[i][1] >= full[1]:
		return false
	weapon_ammo[i] = full
	if i == weapon_index and not reloading:
		ammo_in_mag = full[0]
		ammo_reserve = full[1]
	elif i == weapon_index:
		ammo_reserve = full[1]   # práve prebíja – zásobník dobije sám
		weapon_ammo[i][0] = ammo_in_mag
	Sfx.play(&"pickup_ammo")
	ammo_changed.emit(ammo_in_mag, ammo_reserve, reloading)
	return true


## Je zbraň v ruke prepnutá na druhý režim streľby (WeaponData.alt_mode)?
func is_alt_fire() -> bool:
	return weapon != null and weapon.alt_mode != WeaponData.AltMode.NONE and alt_fire.get(weapon, false)


## Meno režimu pre HUD: AUTO/SEMI (samopal), 1x/2x (dvojhlavňovka), DUO (akimbo), "" = zbraň má len jeden režim
func fire_mode_label() -> String:
	if weapon == null:
		return ""
	if is_akimbo():
		return "DUO"
	match weapon.alt_mode:
		WeaponData.AltMode.SEMI:
			return "SEMI" if is_alt_fire() else "AUTO"
		WeaponData.AltMode.DOUBLE:
			return "2x" if is_alt_fire() else "1x"
	return ""


## Krabička nábojov: každá zbraň dostane jeden zásobník navyše
## Náboje z krabičky. Vráti false, ak Ricco nemá zbraň (krabička ostane ležať).
func add_ammo() -> bool:
	if loadout.is_empty():
		return false
	_store_ammo()
	Sfx.play(&"pickup_ammo")
	for i in loadout.size():
		weapon_ammo[i][1] = mini(weapon_ammo[i][1] + loadout[i].mag_size, loadout[i].reserve_max)
	ammo_reserve = weapon_ammo[weapon_index][1]
	ammo_changed.emit(ammo_in_mag, ammo_reserve, reloading)
	return true


const MAX_PRIMARY := 2   ## hlavné zbrane vo výbave (klávesy 2 a 3)

enum Pickup { NONE, TAKE, SWAP }

## Čo sa stane so zbraňou na zemi: NONE = nič (prológ bez zbrane, smrť), TAKE = zoberie ju sám
## (už ju má → náboje, alebo má voľné miesto), SWAP = miesto je plné, F ju vymení za zbraň vo výbave.
func pickup_mode(w: WeaponData) -> Pickup:
	if loadout.is_empty() or state == State.DEAD:
		return Pickup.NONE
	if loadout.has(w):
		return Pickup.TAKE
	if w.slot_name == "SIDEARM":
		return Pickup.SWAP if _slot_index("SIDEARM") >= 0 else Pickup.TAKE
	var primaries: int = loadout.filter(func(x: WeaponData) -> bool: return x.slot_name != "SIDEARM").size()
	return Pickup.SWAP if primaries >= MAX_PRIMARY else Pickup.TAKE


## Zbraň zo zeme (weapons/weapon_pickup.gd). Novú zbraň pridá do výbavy a hneď ju vezme do ruky
## (plný zásobník, zvyšok do rezervy); ak ju už má, len si vezme náboje. Vráti false, ak ju nezobral.
func pick_up_weapon(w: WeaponData, ammo: int) -> bool:
	if pickup_mode(w) != Pickup.TAKE:
		return false
	_store_ammo()
	var i: int = loadout.find(w)
	if i >= 0:
		weapon_ammo[i][1] = mini(weapon_ammo[i][1] + ammo, w.reserve_max)
		ammo_reserve = weapon_ammo[weapon_index][1]
		Sfx.play(&"pickup_ammo")
		ammo_changed.emit(ammo_in_mag, ammo_reserve, reloading)
		return true
	i = 0 if w.slot_name == "SIDEARM" else loadout.size()   # bočná je vždy prvá (kláves 1)
	loadout.insert(i, w)
	weapon_ammo.insert(i, [mini(ammo, w.mag_size), clampi(ammo - w.mag_size, 0, w.reserve_max)])
	if i <= weapon_index:
		weapon_index += 1
	Sfx.play(&"slide_rack", Vector2.INF, -4.0)
	_equip(i)
	return true


## Výmena so zbraňou zo zeme (F): nová zbraň zaberie miesto rovnakého druhu – hlavnú v ruke,
## inak prvú hlavnú. Vráti [stará zbraň, jej náboje spolu], ktorú si zbraň na zemi „vezme“.
func swap_weapon(w: WeaponData, ammo: int) -> Array:
	if pickup_mode(w) != Pickup.SWAP:
		return []
	_store_ammo()
	var i: int = _slot_index("SIDEARM")
	if w.slot_name != "SIDEARM":
		i = weapon_index if weapon.slot_name != "SIDEARM" else _slot_index("PRIMARY")
	var old: WeaponData = loadout[i]
	var old_ammo: int = weapon_ammo[i][0] + weapon_ammo[i][1]
	loadout[i] = w
	weapon_ammo[i] = [mini(ammo, w.mag_size), clampi(ammo - w.mag_size, 0, w.reserve_max)]
	if i == weapon_index:
		weapon = null   # _equip by inak novú zbraň nevzal (rovnaký index) a prepísal by jej náboje
	Sfx.play(&"slide_rack", Vector2.INF, -4.0)
	_equip(i)
	return [old, old_ammo]


## Index prvej zbrane daného druhu („SIDEARM“, inak hlavná), -1 = nemá
func _slot_index(slot: String) -> int:
	for i in loadout.size():
		if (loadout[i].slot_name == "SIDEARM") == (slot == "SIDEARM"):
			return i
	return -1


func heal(amount: int = 1) -> void:
	if state == State.DEAD or amount <= 0 or health == max_health:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func _update_invulnerability(delta: float) -> void:
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		# po zásahu Ricco sčervenie a počas nezraniteľnosti plynulo bledne (jemne pulzuje) – žiadne blikanie viditeľnosti
		var k: float = clampf(invulnerable_timer / maxf(invulnerable_time, 0.01), 0.0, 1.0)
		var pulse: float = 0.75 + 0.25 * cos(invulnerable_timer * TAU * 4.0)
		sprite.modulate = Color.WHITE.lerp(HURT_TINT, k * pulse)
	elif sprite.modulate != Color.WHITE:
		sprite.modulate = Color.WHITE


func _die() -> void:
	state = State.DEAD
	_hook = null
	_ladder = null
	invulnerable_timer = 0.0
	reloading = false
	if focus.active:
		focus.stop()
	sprite.offset = Vector2.ZERO
	visual.rotation = 0.0
	velocity = Vector2(-facing * 60.0, -160.0)
	sprite.play(&"death")
	Sfx.play(&"death")
	died.emit()
	get_tree().create_timer(respawn_delay, false).timeout.connect(get_tree().reload_current_scene)  # počas pauzy stojí


## TEST, kým nie sú nepriatelia: K = zásah, H = vyliečenie (aj v zozname ovládania)
func _unhandled_input(event: InputEvent) -> void:
	_weapon_switch_input(event)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_K:
		take_damage(1, global_position + Vector2(facing * 20.0, 0))
	elif key.keycode == KEY_H:
		heal(1)


## Krv pri zásahu: kvapky vyletia od zdroja zásahu a padajú, Ricco na chvíľu sčervenie.
func _blood_fx(from: Vector2) -> void:
	var chest: Vector2 = global_position + Vector2(0, -20)
	var away := Vector2(-facing, -0.6) if from == Vector2.INF else (chest - from).normalized()
	away = (away + Vector2(0, -0.5)).normalized()
	Burst.spawn(get_tree().current_scene, chest, away, Color(0.62, 0.04, 0.06), 10, 90.0, Vector2(0, 520), 0.55)
	Burst.spawn(get_tree().current_scene, chest, away, Color(0.85, 0.12, 0.1), 5, 50.0, Vector2(0, 520), 0.4)
	# červený nádych robí _update_invulnerability (plynulo, bez blikania)


# ---------------------------------------------------------------- plávanie

const SWIM_SPRITE_OFFSET := Vector2(0, 6)   ## animácia swim je kreslená vyššie ako ležiaca kapsula
## preload namiesto class_name – build levelu (--headless --script) funguje aj pred prvým otvorením editora
const WaterZoneScript := preload("res://world/water/water_zone.gd")


func _water() -> WaterZoneScript:
	return get_tree().get_first_node_in_group(&"water") as WaterZoneScript


func _water_index(p: Vector2) -> int:
	var w := _water()
	return w.find(p) if w else -1


func _start_swim() -> void:
	if state == State.SLIDE:
		_slide_t = 0.0
	state = State.SWIM
	_set_slide_shape(true)
	aim.visible = false
	wall_sliding = false
	sprite.speed_scale = 1.0
	sprite.offset = SWIM_SPRITE_OFFSET
	sprite.play(&"swim")
	if velocity.y > 120.0:
		_splash(velocity.y)
	velocity.y *= 0.3   # voda pád pribrzdí


func _end_swim() -> void:
	state = State.NORMAL
	submerged = false
	_swim_cooldown = 0.3
	_set_slide_shape(false)
	sprite.offset = Vector2.ZERO
	visual.rotation = 0.0
	aim.visible = weapon != null and not holstered


## Na hladine pláva (nadnáša ho), S ho ponorí, pod vodou pláva na všetky strany (medzerník = hore).
## Na hladine medzerník = vyskočí z vody; keď pláva ku nízkemu okraju, sám sa naň vyšvihne.
func _process_swim(delta: float) -> void:
	var w := _water()
	var i: int = w.find(global_position + Vector2(0, -12)) if w else -1
	if i < 0:
		_end_swim()   # vyplával z vody (napr. dole po schodoch von)
		return
	var surface: float = w.surface_y(i)
	var depth: float = INF if surface == INF else global_position.y - surface   # INF pod stropom (sifón)
	var at_surface: bool = depth < float_depth + 8.0
	var dir := Vector2(Input.get_axis(&"move_left", &"move_right"), 0.0)
	if Input.is_action_pressed(&"slide"):
		dir.y = 1.0
	elif Input.is_action_pressed(&"jump") and not at_surface:
		dir.y = -1.0
	if at_surface and Input.is_action_just_pressed(&"jump"):
		if _try_ladder():   # z vody rovno na rebrík
			return
		_leave_water(Vector2(dir.x * 110.0, swim_jump))
		return
	if dir.y > 0.0 or not at_surface:
		# pod vodou: voľný pohyb, bez ovládania pomaly stúpa k hladine
		if dir != Vector2.ZERO:
			velocity = velocity.move_toward(dir.normalized() * swim_speed, swim_accel * delta)
		else:
			velocity = velocity.move_toward(Vector2(0, -14.0), swim_drag * delta)
	else:
		# na hladine: pláva do strán a hojdá sa na vlnkách
		velocity.x = move_toward(velocity.x, dir.x * swim_speed * 0.85, (swim_accel if dir.x != 0.0 else swim_drag) * delta)
		var target: float = surface + float_depth + sin(Time.get_ticks_msec() * 0.004) * 1.5
		velocity.y = clampf((target - global_position.y) * 8.0, -90.0, 90.0)
	move_and_slide()
	# na hladine pri nízkom okraji (breh jamy) → vyšvihne sa von
	if at_surface and dir.x != 0.0 and is_on_wall() and _water_index(global_position + Vector2(dir.x * 18.0, -30)) < 0 \
			and _ledge_low(dir.x, surface):
		_leave_water(Vector2(dir.x * 100.0, -270.0))
		return
	if dir.x != 0.0 and signf(dir.x) != facing:
		facing = signf(dir.x)
		visual.scale.x = facing
	# telo sa nakloní v smere plávania (hore / dole)
	var tilt: float = 0.0
	if not at_surface and velocity.length() > 20.0:
		tilt = clampf(atan2(velocity.y, absf(velocity.x) + 30.0), -0.9, 0.9) * facing
	visual.rotation = lerp_angle(visual.rotation, tilt, 1.0 - exp(-10.0 * delta))
	sprite.speed_scale = 0.5 + velocity.length() / swim_speed
	submerged = depth > 26.0
	if submerged:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble_t = randf_range(0.5, 1.1)
			Burst.spawn(get_tree().current_scene, global_position + Vector2(facing * 14.0, -18.0), Vector2.UP,
					Color(0.75, 0.88, 1.0, 0.7), 2, 18.0, Vector2(0, -40), 0.9)


## Je okraj pred Riccom nízko nad hladinou (dá sa naň vyšvihnúť)? Lúč zhora nadol tesne za stenou.
func _ledge_low(dir: float, surface: float) -> bool:
	if surface == INF:
		return false
	var x: float = global_position.x + dir * (HALF_WIDTH + 14.0)
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, surface - 30.0), Vector2(x, surface + 4.0), collision_mask, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return not hit.is_empty()


func _leave_water(v: Vector2) -> void:
	_end_swim()
	velocity = v
	_splash(220.0)
	sprite.play(_hat_anim(&"jump"))
	Sfx.play(&"jump", Vector2.INF, -6.0)


func _splash(strength: float) -> void:
	var w := _water()
	var i: int = w.find(global_position + Vector2(0, -12)) if w else -1
	var y: float = w.surface_y(i) if i >= 0 else global_position.y
	if y == INF:
		return
	Burst.spawn(get_tree().current_scene, Vector2(global_position.x, y), Vector2.UP, Color(0.7, 0.85, 1.0, 0.85),
			int(clampf(strength / 30.0, 5.0, 14.0)), clampf(strength * 0.6, 60.0, 160.0), Vector2(0, 420), 0.5)
	Sfx.play(&"splash", Vector2.INF, -4.0)


# ---------------------------------------------------------------- ľad

## Stojí na ľade? Pozrie dlaždicu pod nohami (vlastné dáta "ice" v TileSete) alebo telo v skupine "ice" (zamrznutá debna).
## Godot docs: classes/class_tilemaplayer (local_to_map), classes/class_tiledata (get_custom_data)
func _update_ice() -> void:
	on_ice = false
	if not is_on_floor():
		return
	for i in get_slide_collision_count():
		var c: KinematicCollision2D = get_slide_collision(i)
		if c.get_normal().y > -0.7:
			continue
		var col: Object = c.get_collider()
		if col is TileMapLayer:
			var tl := col as TileMapLayer
			if tl.tile_set == null or tl.tile_set.get_custom_data_layer_by_name("ice") < 0:
				continue
			# dlaždicu nájdeme podľa bodu dotyku (kúsok pod ním) – get_coords_for_body_rid vracia pri zlúčených
			# fyzikálnych kvadrantoch len prvú dlaždicu kvadrantu (docs: classes/class_tilemaplayer#physics_quadrant_size)
			var td: TileData = tl.get_cell_tile_data(tl.local_to_map(tl.to_local(c.get_position() + Vector2(0, 2))))
			if td and td.get_custom_data(&"ice"):
				on_ice = true
		elif col is Node and (col as Node).is_in_group(&"ice"):
			on_ice = true


## Trenie pod nohami (na ľade menšie) – dokár s hákom podľa neho vypočíta, ako silno Ricca pritiahne
func ground_friction() -> float:
	return ice_friction if on_ice else friction


# ---------------------------------------------------------------- markíza (world/fx/awning.gd)

## Odrazí ho hore (pružná markíza). v = rýchlosť (px/s, záporné = hore). Len keď normálne stojí/beží.
func bounce(v: float) -> void:
	if state != State.NORMAL or in_cutscene:
		return
	velocity.y = v
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_sneak_on = false
	sprite.play(_hat_anim(&"jump"))


# ---------------------------------------------------------------- hák na mäso (world/coldstore/hook_rail.gd)

## Môže sa chytiť háku? Pýta sa koľajnica – len vo vzduchu a nie hneď po pustení.
func can_grab_hook() -> bool:
	return state == State.NORMAL and not is_on_floor() and _hook_cooldown <= 0.0 and not in_cutscene


## Bod, ktorým sa drží háku (labky nad hlavou)
func hook_hand() -> Vector2:
	return global_position + Vector2(0, -hook_hang)


func grab_hook(h: Node2D) -> void:
	_hook = h
	_hook_t = 0.0
	state = State.HOOK
	velocity = Vector2.ZERO
	wall_sliding = false
	_sneak_on = false
	visual.position = Vector2.ZERO
	visual.rotation = 0.0
	sprite.offset = HOOK_SPRITE_OFFSET
	sprite.speed_scale = 1.0
	sprite.play(&"hook")
	Sfx.play(&"hook_grab", hook_hand(), -4.0, 0.1)


## Pustí hák (skok, šmyk, koniec koľajnice). v = rýchlosť po pustení.
func release_hook(v: Vector2 = Vector2.ZERO) -> void:
	if state != State.HOOK:
		return
	_hook = null
	state = State.NORMAL
	sprite.offset = Vector2.ZERO
	_hook_cooldown = hook_regrab_time
	velocity = v
	sprite.play(_hat_anim(&"jump" if v.y < 0.0 else &"fall"))


## Visí na háku a vezie sa s ním. Skok = zoskočí (aj s rýchlosťou koľajnice), šmyk (S) = pustí sa. Strieľa sa normálne
## (zbraň drží ruka ducha).
func _process_hook(delta: float) -> void:
	if not is_instance_valid(_hook):
		release_hook()
		return
	_hook_t += delta
	var hv: Variant = _hook.get(&"velocity")
	var v: Vector2 = hv if hv is Vector2 else Vector2.ZERO
	global_position = _hook.global_position + Vector2(0, hook_hang)
	velocity = v
	aim.visible = weapon != null and not holstered
	if Input.is_action_just_pressed("jump"):
		var dir: float = Input.get_axis("move_left", "move_right")
		release_hook(Vector2(v.x + dir * 100.0, hook_jump))
		Sfx.play(&"jump", Vector2.INF, -6.0)
		return
	if Input.is_action_just_pressed(&"slide"):
		release_hook(Vector2(v.x, 0.0))
		return
	_update_aim()
	_update_weapons()


# ---------------------------------------------------------------- rebrík (world/fx/ladder.gd)

## Chytí sa rebríka? Zdola skokom (zo zeme, z člna aj z vody), vo vzduchu pri páde sám, zhora S tesne pri hrane.
func _try_ladder() -> bool:
	if _ladder_cooldown > 0.0 or in_cutscene:
		return false
	for n in get_tree().get_nodes_in_group(&"ladders"):
		var l := n as Node2D
		var top: Vector2 = l.global_position
		var side: float = l.get(&"side")
		var length: float = l.get(&"length")
		var p: Vector2 = global_position
		# zhora: stojí na hrane pri rebríku a stlačí S
		if is_on_floor() and Input.is_action_just_pressed(&"slide") and absf(p.y - top.y) < 6.0 \
				and (p.x - top.x) * side > -4.0 and (p.x - top.x) * side < 26.0:
			_grab_ladder(l, top.y + ledge_hang_depth + 6.0)
			return true
		var gx: float = top.x - side * (HALF_WIDTH + 0.5)
		if absf(p.x - gx) > 14.0 or p.y < top.y + ledge_hang_depth or p.y > top.y + length + 12.0:
			continue
		if Input.is_action_just_pressed(&"jump") or (state == State.NORMAL and not is_on_floor() and velocity.y > 30.0):
			_grab_ladder(l, p.y)
			return true
	return false


func _grab_ladder(l: Node2D, y: float) -> void:
	if state == State.SWIM:
		_end_swim()
	_cancel_eat()
	_set_duck(false)
	_sneak_on = false
	_ladder = l
	state = State.LADDER
	velocity = Vector2.ZERO
	wall_sliding = false
	jump_buffer_timer = 0.0
	var top: Vector2 = l.global_position
	var side: float = l.get(&"side")
	facing = side
	visual.scale.x = facing
	visual.rotation = 0.0
	visual.position = Vector2.ZERO
	sprite.offset = Vector2.ZERO
	sprite.speed_scale = 1.0
	global_position = Vector2(top.x - side * (HALF_WIDTH + 0.5), clampf(y, top.y + ledge_hang_depth + 1.0, top.y + l.get(&"length")))
	sprite.play(&"ladder")
	sprite.pause()
	_ladder_dist = 0.0
	aim.visible = false
	_takedown_hint.visible = false
	Sfx.play(&"ledge_grab", Vector2.INF, -6.0)


## Pustí rebrík. v = rýchlosť po pustení (odskok / pád).
func _leave_ladder(v: Vector2) -> void:
	_ladder = null
	state = State.NORMAL
	_ladder_cooldown = ladder_regrab_time
	visual.position = Vector2.ZERO
	velocity = v
	aim.visible = weapon != null and not holstered
	sprite.play(_hat_anim(&"jump" if v.y < 0.0 else &"fall"))


## Na rebríku: W / medzerník hore, S dole, smer do strany = pustí sa (so skokom odskočí). Smerom k stene sa pustí len
## vtedy, keď tam stena naozaj nie je (voľný rebrík v šachte, otvor, dvere) – inak by ho pustil pri každom stlačení.
## Hore sa vyšvihne na hranu rovnakou animáciou ako pri chytení hrany (climb), dole pustí rebrík (zem, voda). Na rebríku nestrieľa.
func _process_ladder(delta: float) -> void:
	if not is_instance_valid(_ladder):
		_leave_ladder(Vector2.ZERO)
		return
	aim.visible = false
	var top: Vector2 = _ladder.global_position
	var length: float = _ladder.get(&"length")
	var dir: float = Input.get_axis(&"move_left", &"move_right")
	if dir != 0.0 and (signf(dir) == -facing or not test_move(global_transform, Vector2(facing * 6.0, 0.0))):
		var d: float = signf(dir)
		var jump: bool = Input.is_action_pressed(&"jump")
		_leave_ladder(Vector2(d * (130.0 if jump else 40.0), -220.0 if jump else 0.0))
		if jump:
			if d != facing:
				_turn(d)
			Sfx.play(&"jump", Vector2.INF, -6.0)
		return
	var vy: float = 0.0
	if Input.is_action_pressed(&"jump"):
		vy = -ladder_speed
	elif Input.is_action_pressed(&"slide"):
		vy = ladder_speed
	global_position.y += vy * delta
	# hore: vyšvihne sa na hranu (Ricco je v polohe ako pri visení na hrane, animácia climb je na ňu zarovnaná)
	if global_position.y <= top.y + ledge_hang_depth:
		global_position = Vector2(top.x - facing * (HALF_WIDTH + 0.5), top.y + ledge_hang_depth)
		ledge_top = Vector2(top.x + facing * CLIMB_STAND_DISTANCE, top.y)
		_ladder = null
		_ladder_cooldown = ladder_regrab_time
		_start_climb()
		return
	# dole: koniec rebríka – pustí sa (dopadne na zem / do vody)
	if global_position.y >= top.y + length:
		global_position.y = top.y + length
		if vy > 0.0:
			_leave_ladder(Vector2.ZERO)
			return
	# plutvy a labky sa pri lezení striedajú (snímok každých 8 px), na každej priečke cinkne železo
	visual.position.y = 0.0
	if vy != 0.0:
		_ladder_step += absf(vy) * delta
		_ladder_dist += absf(vy) * delta
		sprite.frame = int(_ladder_dist / 8.0) % 4
		if _ladder_step >= 16.0:
			_ladder_step = 0.0
			Sfx.play(&"ladder_rung", Vector2.INF, -12.0, 0.08)   # železná priečka (4 varianty)
