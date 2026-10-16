class_name MenuItem
extends Button
## Jedna položka pause menu (štýl „minimal“, zarovnaná doprava).
## Vybraná položka: zlatý text, zlatý pásik vpravo a tenká čiara pod textom.
## Položka s hodnotou (value) sa mení šípkami doľava/doprava alebo kliknutím → signál changed(dir).
## Kreslí sa celá cez _draw (Godot docs: tutorials/2d/custom_drawing_in_2d), Button rieši myš a klávesnicu.

signal changed(dir: int)

const CREAM := Color8(245, 235, 209)
const BRASS := Color8(199, 153, 71)
const BRASS_D := Color8(92, 69, 31)
const DIM := Color8(150, 140, 120)
const BAR_GAP := 6.0      ## medzera medzi textom a pásikom vpravo

var label: String = ""
var value: String = ""    ## prázdne = obyčajné tlačidlo
var selectable: bool = true  ## false = len riadok textu (napr. zoznam ovládania)
var font_size: int = 8       ## úvodné menu má väčšie písmo (16)
var choices: PackedStringArray = []   ## neprázdne = rolovacie menu (Enter / klik ho otvorí, šípky doľava/doprava prepínajú)
var on_hover: Callable                ## náhľad možnosti (index) pri prechode po rolovacom menu


func _init(label_: String = "", value_: String = "") -> void:
	label = label_
	value = value_


func _ready() -> void:
	flat = true
	custom_minimum_size = Vector2(0, font_size + 4)
	for s: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	if selectable:
		focus_mode = Control.FOCUS_ALL
		mouse_entered.connect(grab_focus)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	else:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: String) -> void:
	value = v
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if value == "" or not has_focus():
		return
	if event.is_action_pressed(&"ui_left"):
		changed.emit(-1)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		changed.emit(1)
		accept_event()


func _pressed() -> void:
	if choices.size() > 0:
		var cur: int = maxi(0, choices.find(value))
		var dd := MenuDropdown.open(self, choices, cur)
		dd.picked.connect(func(i: int): changed.emit(i - choices.find(value)))
	elif value != "":
		changed.emit(1)


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var sel: bool = selectable and has_focus()
	var right: float = size.x - 3.0 - BAR_GAP * font_size / 8.0
	var base_y: float = roundf((size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	var x: float = right
	if value != "":
		var v: String = ("< %s >" % value) if sel else value
		if choices.size() > 0:
			# rolovacie menu: hodnota v rámčeku so šípkou dole
			var tri: float = 4.0 * font_size / 8.0
			var tw: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var box := Rect2(right - tw - tri - 10.0, base_y - font_size, tw + tri + 10.0, font_size + 4.0)
			draw_rect(box, Color(0, 0, 0, 0.35))
			draw_rect(box, BRASS if sel else BRASS_D, false, 1.0)
			draw_string(font, Vector2(roundf(box.position.x + 3.0), base_y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, CREAM if sel else DIM)
			var tx: float = box.end.x - tri - 3.0
			var ty: float = base_y - font_size * 0.55
			draw_colored_polygon(PackedVector2Array([Vector2(tx, ty), Vector2(tx + tri, ty), Vector2(tx + tri / 2.0, ty + tri * 0.7)]), BRASS if sel else DIM)
			x = box.position.x + 9.0 - 12.0 * font_size / 8.0
		else:
			x -= font.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2(roundf(x), base_y), v, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, CREAM if (sel or not selectable) else DIM)
		x -= 12.0 * font_size / 8.0
	var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	x -= w
	var col: Color = BRASS if sel else DIM
	draw_string(font, Vector2(roundf(x), base_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
	if sel:
		draw_rect(Rect2(size.x - 3.0, base_y - font_size + 1.0, 3.0, font_size + 1.0), BRASS)   # pásik vpravo
		draw_rect(Rect2(roundf(x) - 6.0, base_y + 2.0, right - roundf(x) + 6.0, 1.0), BRASS_D)  # čiara pod textom
