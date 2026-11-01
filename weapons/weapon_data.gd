class_name WeaponData
extends Resource
## Údaje o zbrani – jeden .tres súbor na zbraň (Godot docs: tutorials/scripting/resources).
## Používa ich Ricco (ruka ducha, prebíjanie, HUD) aj nepriatelia (obrázok, streľba).
## Súradnice „px“ sú pixely v obrázku zbrane (ľavý horný roh = 0, 0), zbraň mieri doprava.

## Druhý režim streľby (kláves FIRE MODE, predvolene B):
##   SEMI   – samopal strieľa po jednom (Thompson mal prepínač FULL AUTO / SEMI, dávkový režim nemal)
##   DOUBLE – dvojhlavňová brokovnica vystrelí obe hlavne naraz (2× toľko brokov)
enum AltMode { NONE, SEMI, DOUBLE }

@export var name: String = "Pistol"
@export var texture: Texture2D
@export var slot_name: String = "SIDEARM"          ## SIDEARM / PRIMARY (neskôr výber výbavy)

@export_group("Hold")
@export var grip_px: Vector2 = Vector2(4, 6)        ## kde ju drží ruka (vrch rukoväte)
@export var muzzle_px: Vector2 = Vector2(22.5, 2.5) ## ústie hlavne
@export var two_handed: bool = false                ## druhá ruka drží predok zbrane
@export var foregrip_px: Vector2 = Vector2.ZERO     ## kde ju drží druhá ruka

@export_group("Fire")
@export var automatic: bool = false       ## true = strieľa, kým držíš tlačidlo
@export var fire_cooldown: float = 0.14   ## s medzi výstrelmi
@export var pellets: int = 1              ## brokovnica = viac broky naraz
@export var pellet_scale: float = 1.0     ## veľkosť guľky na obrazovke (broky sú menšie než guľka z pištole)
@export var alt_mode: AltMode = AltMode.NONE
@export var spread_deg: float = 1.5       ## rozptyl (pri brokoch celý vejár)
@export var damage: float = 1.0       ## zásah zblízka (gangster má 3 životy, bitkár 5)
@export var bullet_speed: float = 650.0
@export var bullet_lifetime: float = 1.5  ## s – ako dlho guľka letí (potom už je mimo obrazovky)
@export var effective_range: float = 260.0 ## px – do tejto vzdialenosti plný damage
@export var falloff_range: float = 160.0   ## px – za effective_range damage rýchlo klesne na 10 % (Bullet.MIN_DAMAGE)
@export var recoil_px: float = 3.0
@export var shake: float = 2.0            ## zatrasenie kamerou

@export_group("Accuracy")
## Každý výstrel ide trochu inam (spread_deg). Pri streľbe za sebou sa rozptyl zväčšuje (samopal) –
## o spread_bloom_deg za výstrel, najviac o spread_max_deg; keď prestaneš strieľať, klesá o bloom_recover_deg za sekundu.
@export var spread_bloom_deg: float = 0.0
@export var spread_max_deg: float = 0.0
@export var bloom_recover_deg: float = 20.0

@export_group("Ammo")
@export var mag_size: int = 8
@export var reserve_start: int = 32
@export var reserve_max: int = 64         ## viac nábojov v zálohe Ricco neunesie (krabičky, zbrane zo zeme)
@export var reload_time: float = 1.0
@export var mag_texture: Texture2D        ## zásobník v zbrani / to, čo vypadne (prázdny zásobník, nábojnica, brok)
@export var mag_px: Vector2 = Vector2(3, 5)        ## kde je zásobník (ľavý horný roh)
@export var mag_out: Vector2 = Vector2(0, 9.5)     ## kam sa vysunie pred pustením
@export var mag_visible: bool = true               ## zásobník je vidno aj mimo prebíjania
@export var drop_count: int = 1                    ## koľko kúskov vypadne (revolver 6 nábojníc)
@export var new_mag_texture: Texture2D             ## čo prinesie druhá ruka (nový zásobník, broky, rýchlonabíjač)

@export_group("Break open")
## Lámacia zbraň (derringer): pri prebíjaní sa hlavne vyklopia na pánte hore, nábojnice vypadnú (mag_px = komora).
## Oba obrázky sú rovnako veľké ako texture – rám bez hlavní a hlavne bez rámu. null = zbraň sa nelomí.
@export var frame_texture: Texture2D
@export var barrel_texture: Texture2D
@export var hinge_px: Vector2 = Vector2.ZERO       ## pánt – okolo neho sa hlavne otáčajú
@export var open_deg: float = 35.0                 ## o koľko sa hlavne vyklopia

@export_group("Pump")
## Pumpovačka (Winchester 1897): po každom výstrele druhá ruka potiahne predpažbie (pumpu) dozadu – vyletí nábojnica – a dopredu.
## pump_body_texture = zbraň bez pumpy, pump_texture = samotná pumpa (jej ľavý horný roh je v zbrani na pump_px).
## null = zbraň nemá pumpu. Nepriatelia kreslia celú zbraň (texture).
@export var pump_texture: Texture2D
@export var pump_body_texture: Texture2D
@export var pump_px: Vector2 = Vector2.ZERO
@export var pump_travel: float = 5.0               ## px – o koľko ide pumpa dozadu
@export var pump_delay: float = 0.12               ## s po výstrele, kým potiahne
@export var pump_time: float = 0.24                ## s – celý ťah (dozadu aj dopredu)
## Nabíja sa po jednom náboji (reload_time = jeden náboj) – streľba nabíjanie preruší, zbraň vystrelí, čo v nej je
@export var shell_reload: bool = false
