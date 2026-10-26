extends Node2D
## Železný rebrík na čele steny (kapitola III – nábrežná stena, neskôr požiarne schodiská).
## Ricco (characters/ricco/ricco.gd, stav LADDER) sa ho chytí: zo zeme alebo z vody skokom, vo vzduchu pri páde sám,
## zhora šmykom (S) pri hrane. Lezie skokom (W / medzerník) hore a šmykom (S) dole; hore sa vyšvihne na hranu
## (animácia climb ako pri chytení hrany). Smer od steny = pustí sa, smer od steny + skok = odskočí.
## Poloha uzla = horný roh steny (x = čelo steny, y = vrch). side = na ktorej strane rebríka je stena (+1 = vpravo).
## Obrázok (world/fx/art/ladder.png) sa opakuje po celej dĺžke, nad hranou sú madlá (ladder_top.png).

const LADDER_TEX := preload("res://world/fx/art/ladder.png")
const TOP_TEX := preload("res://world/fx/art/ladder_top.png")

@export var length: float = 120.0   ## px – ako hlboko pod hranu rebrík siaha (pod hladinu kúsok navyše)
@export var side: float = 1.0       ## +1 = stena je vpravo od rebríka (Ricco sa pozerá doprava)


func _ready() -> void:
	add_to_group(&"ladders")
	var s := Sprite2D.new()
	s.texture = LADDER_TEX
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 20, length)
	s.position = Vector2(-side * 11.0 - 10.0, 0.0)   # tesne pred čelom steny
	s.z_index = -1
	add_child(s)
	var t := Sprite2D.new()
	t.texture = TOP_TEX
	t.centered = false
	t.position = s.position + Vector2(0, -15)
	t.z_index = -1
	add_child(t)
