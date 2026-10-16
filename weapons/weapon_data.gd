class_name WeaponData
extends Resource
## Údaje o zbrani – jeden .tres súbor na zbraň (Godot docs: tutorials/scripting/resources).
## Používa ich Ricco (ruka ducha, prebíjanie, HUD) aj nepriatelia (obrázok, streľba).
## Súradnice „px“ sú pixely v obrázku zbrane (ľavý horný roh = 0, 0), zbraň mieri doprava.

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
@export var spread_deg: float = 1.5       ## rozptyl (pri brokoch celý vejár)
@export var damage: int = 1
@export var bullet_speed: float = 650.0
@export var bullet_lifetime: float = 1.2  ## s – kratšie = menší dostrel (broky)
@export var recoil_px: float = 3.0
@export var shake: float = 2.0            ## zatrasenie kamerou

@export_group("Ammo")
@export var mag_size: int = 8
@export var reserve_start: int = 32
@export var reload_time: float = 1.0
@export var mag_texture: Texture2D        ## zásobník v zbrani / to, čo vypadne (prázdny zásobník, nábojnica, brok)
@export var mag_px: Vector2 = Vector2(3, 5)        ## kde je zásobník (ľavý horný roh)
@export var mag_out: Vector2 = Vector2(0, 9.5)     ## kam sa vysunie pred pustením
@export var mag_visible: bool = true               ## zásobník je vidno aj mimo prebíjania
@export var drop_count: int = 1                    ## koľko kúskov vypadne (revolver 6 nábojníc)
@export var new_mag_texture: Texture2D             ## čo prinesie druhá ruka (nový zásobník, broky, rýchlonabíjač)
