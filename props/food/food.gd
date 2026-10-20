class_name Food
## Jedlo, ktoré Ricco nosí so sebou (najviac 3 kusy) a zje klávesom V (akcia „eat“).
## Druhy sa striedajú: každé nájdené jedlo je ďalšie v poradí KINDS (pizza → sardinky → cannoli → …).
## Obrázky sú v props/food/food.png (políčka 16×16, poradie = FRAME), kreslí ich c4/make_food_art.py.
## Nesené jedlo ostane aj po prechode do ďalšej časti levelu; vyprázdni ho Level2.reset() (nová hra).
## Animácie jedenia: characters/ricco/eating.gd. Zdvihnutie aj lekárnička (kind = "medkit"): props/food/food_pickup.tscn.
## Godot docs: tutorials/scripting/gdscript/static_typing (static var), classes/class_atlastexture

const SHEET := preload("res://props/food/food.png")
const MAX_CARRIED := 3
## Poradie, v akom sa druhy striedajú
const KINDS: Array[StringName] = [&"pizza", &"sardines", &"cannoli", &"espresso", &"salami", &"spumoni", &"herring"]
## Koľko kúskov zdravia (z 8) vráti
const HEAL := {&"pizza": 2, &"sardines": 2, &"cannoli": 2, &"espresso": 1, &"salami": 2, &"spumoni": 2, &"herring": 3}
## Políčko v food.png
const FRAME := {&"pizza": 0, &"sardines": 1, &"cannoli": 2, &"espresso": 3, &"salami": 4, &"spumoni": 5, &"herring": 6,
		&"medkit": 7, &"sardines_closed": 8, &"jar_open": 9, &"jar_lid": 10, &"herring_fish": 11, &"sardine_fish": 12}
const ESPRESSO_TIME := 6.0     ## s – po espresse Ricco chvíľu behá rýchlejšie
const ESPRESSO_SPEED := 1.2

static var carried: Array[StringName] = []
static var _next: int = 0


## Ďalší druh v poradí (pri každom nájdenom jedle iný)
static func next_kind() -> StringName:
	var k: StringName = KINDS[_next % KINDS.size()]
	_next += 1
	return k


static func can_carry() -> bool:
	return carried.size() < MAX_CARRIED


static func reset() -> void:
	carried.clear()
	_next = 0


## Obrázok jedného políčka (jedlo, plechovka, rybička…)
static func texture(kind: StringName) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = SHEET
	t.region = Rect2(FRAME.get(kind, 0) * 16, 0, 16, 16)
	return t
