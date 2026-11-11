class_name Progress
## Postup hráča: ktoré zbrane už Ricco našiel (Arsenal v menu ich ukáže, ostatné sú zamknuté)
## a v ktorej kapitole naposledy hral (STORY → CONTINUE ju spustí od začiatku).
## Zbraň sa odomkne, keď ju Ricco prvý raz vezme do ruky (ricco.gd → _equip).
## Ukladá sa do user://progress.cfg cez ConfigFile, všetko je statické ako GameSettings.

const PATH := "user://progress.cfg"

static var unlocked: PackedStringArray = []   ## WeaponData.name odomknutých zbraní
static var seen: PackedStringArray = []       ## zbrane, ktoré si hráč už pozrel v Arsenale (inak svieti NEW)
static var chapter: int = 0                   ## posledná rozohratá kapitola (0 = ešte nehral, CONTINUE sa neukáže)
static var tips: PackedStringArray = []       ## okná „nová schopnosť“, ktoré už hráč videl (ui/dialog/ability_popup.gd)
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  # nová hra – nič odomknuté
	unlocked = PackedStringArray(cfg.get_value("arsenal", "unlocked", []))
	seen = PackedStringArray(cfg.get_value("arsenal", "seen", []))
	chapter = int(cfg.get_value("story", "chapter", 0))
	tips = PackedStringArray(cfg.get_value("tips", "seen", []))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("arsenal", "unlocked", Array(unlocked))
	cfg.set_value("arsenal", "seen", Array(seen))
	cfg.set_value("story", "chapter", chapter)
	cfg.set_value("tips", "seen", Array(tips))
	cfg.save(PATH)


## Kapitola sa začala (volá prvá scéna kapitoly v _ready) – zapamätá sa pre CONTINUE
static func reach_chapter(n: int) -> void:
	ensure_loaded()
	if chapter == n:
		return
	chapter = n
	save()


static func unlock(weapon_name: String) -> void:
	ensure_loaded()
	if weapon_name in unlocked:
		return
	unlocked.append(weapon_name)
	save()


static func is_unlocked(weapon_name: String) -> bool:
	ensure_loaded()
	return weapon_name in unlocked


## Odomknutá, ale v Arsenale ešte nevidená
static func is_new(weapon_name: String) -> bool:
	return is_unlocked(weapon_name) and not weapon_name in seen


static func mark_seen(weapon_name: String) -> void:
	if not is_new(weapon_name):
		return
	seen.append(weapon_name)
	save()


## Okno novej schopnosti (AbilityPopup) sa ukáže len raz
static func tip_seen(id: StringName) -> bool:
	ensure_loaded()
	return String(id) in tips


static func mark_tip(id: StringName) -> void:
	ensure_loaded()
	if String(id) in tips:
		return
	tips.append(String(id))
	save()
