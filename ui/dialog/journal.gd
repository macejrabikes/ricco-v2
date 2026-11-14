class_name Journal
## Denník v pause menu (JOURNAL): dokumenty, ktoré už Ricco v hre čítal, sa dajú pozrieť znova.
## Zapisuje ich ReadCard.open / open_card (ui/dialog/read_card.gd) do Progress.docs (cesta k obrázku alebo meno karty).
## Nový dokument netreba pridávať sem – ukáže sa aj sám (názov z mena súboru); tu mu stačí dať pekný názov.

const MATCHBOOK := "matchbook"   ## zápalky Fontana Shipping (kreslená karta s nápismi – Level2.matchbook_card)

## cesta / meno → [názov v denníku, kapitola]
const ENTRIES := {
	"res://levels/level2/art/street/newspaper.png": ["THE MORNING PAPER", "II"],
	MATCHBOOK: ["FONTANA MATCHBOOK", "II"],
	"res://levels/level2/art/cold/ledger_big.png": ["BIG LOU'S LEDGER", "II"],
	"res://levels/level2/art/ship/letter_big.png": ["LETTER FROM THE SHIP", "II"],
	"res://levels/level3/art/club_back/telegram_big.png": ["TELEGRAM", "III"],
	"res://levels/level3/art/club_back/invite_big.png": ["GALA INVITATION", "III"],
	"res://levels/level3/art/club_back/photo_big.png": ["PHOTOGRAPH", "III"],
	"res://levels/level3/art/hotel/menu_big.png": ["HOTEL MENU", "III"],
	"res://levels/level3/art/hotel/key_big.png": ["ELEVATOR KEY", "III"],
	"res://levels/level3/art/gala/place_card_big.png": ["PLACE CARD", "III"],
	"res://levels/level4/art/ledger_big.png": ["SMUGGLERS' LEDGER", "IV"],
	"res://levels/level4/art/letter_big.png": ["LETTER IN THE VILLA", "IV"],
}


## Prečítané dokumenty, ktoré sa dajú ukázať (v poradí čítania)
static func available() -> PackedStringArray:
	Progress.ensure_loaded()
	var out := PackedStringArray()
	for id in Progress.docs:
		if id == MATCHBOOK or ResourceLoader.exists(id):
			out.append(id)
	return out


static func title(id: String) -> String:
	if ENTRIES.has(id):
		return ENTRIES[id][0]
	return id.get_file().get_basename().trim_suffix("_big").replace("_", " ").to_upper()


static func chapter(id: String) -> String:
	if ENTRIES.has(id):
		return ENTRIES[id][1]
	const ROMAN := ["I", "II", "III", "IV"]
	for i in ROMAN.size():   # levels/level3/… → III
		if id.contains("/level%d/" % (i + 1)):
			return ROMAN[i]
	return ""


## Ukáže dokument znova (nezapíše sa druhý raz), hra po zatvorení ostane v pauze
static func open(parent: Node, id: String) -> ReadCard:
	var c: ReadCard
	if id == MATCHBOOK:
		c = ReadCard.open_card(parent, Level2.matchbook_card())
	elif ResourceLoader.exists(id):
		c = ReadCard.open(parent, load(id) as Texture2D, false)
	if c:
		c.keep_paused = true
	return c
