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
var subtitle: String = ""            ## malý riadok pod textom (napr. názov kapitoly pod CHAPTER I)
var subtitle_size: int = 8
var steps: int = 0                   ## > 0 = posuvník (hlasitosť) s hodnotou 0..steps namiesto textu
var level: int = 0                   ## hodnota posuvníka
var _drag: bool = false              ## ťahá sa posuvník myšou


func _init(label_: String = "", value_: String = "") -> void:
	label = label_
	value = value_


func _ready() -> void:
	flat = true
	custom_minimum_size = Vector2(0, font_size + 4 + (subtitle_size + 3 if subtitle != "" else 0))
	if steps > 0:   # posuvník potrebuje miesto: popis + šípky + dráha + číslo (inak by stĺpec popis orezal)
		var f: Font = get_theme_default_font()
		custom_minimum_size.x = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x \
				+ f.get_string_size("100%", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + _slider_w() + 30.0 * _sc() + BAR_GAP * _sc() + 3.0
	for s: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	if selectable:
		focus_mode = Control.FOCUS_ALL
		mouse_entered.connect(grab_focus)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		focus_entered.connect(func(): Sfx.ui(&"ui_move"))      # zvuky menu (audio/sfx.gd)
		pressed.connect(func(): Sfx.ui(&"ui_select"))
		changed.connect(func(_d: int): Sfx.ui(&"ui_move"))
	else:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: String) -> void:
	value = v
	queue_redraw()


func set_level(v: int) -> void:
	level = clampi(v, 0, steps)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if steps > 0:
		_slider_input(event)
		return
	if value == "" or not has_focus():
		return
	if event.is_action_pressed(&"ui_left"):
		changed.emit(-1)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		changed.emit(1)
		accept_event()


## Posuvník: šípky (aj podržané – echo), klik alebo ťahanie myšou po dráhe nastaví hodnotu
func _slider_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _slider_hit().has_point(event.position):
			_drag = true
			grab_focus()
			_slide_to(event.position.x)
			accept_event()
		elif not event.pressed and _drag:
			_drag = false
			accept_event()
	elif event is InputEventMouseMotion and _drag:
		_slide_to(event.position.x)
		accept_event()
	elif has_focus() and event.is_action_pressed(&"ui_left", true):
		if level > 0:
			changed.emit(-1)
		accept_event()
	elif has_focus() and event.is_action_pressed(&"ui_right", true):
		if level < steps:
			changed.emit(1)
		accept_event()


func _slide_to(x: float) -> void:
	var r := _slider_rect()
	var v: int = clampi(roundi((x - r.position.x) / r.size.x * steps), 0, steps)
	if v != level:
		changed.emit(v - level)


func _pressed() -> void:
	if steps > 0:
		if level < steps:
			changed.emit(1)
		return
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
	var text_h: float = size.y - (subtitle_size + 3 if subtitle != "" else 0)   # podnadpis zaberá spodok
	var base_y: float = roundf((text_h + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	var x: float = right
	if steps > 0:
		x = _draw_slider(font, sel, right, base_y)
	elif value != "":
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
	if subtitle != "":
		# podnadpis malým písmom pod čiarou, zarovnaný doprava ako text
		var sw: float = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size).x
		var sy: float = base_y + 4.0 + font.get_ascent(subtitle_size)
		draw_string(font, Vector2(roundf(right - sw), roundf(sy)), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size, CREAM if sel else DIM)


# --- posuvník -----------------------------------------------------------------

func _sc() -> float:
	return font_size / 8.0


func _base_y() -> float:
	var font: Font = get_theme_default_font()
	return roundf((size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)


func _slider_w() -> float:
	return 49.0 * _sc()   # 10 zárezov po 5 px (posledný bez medzery)


## Obdĺžnik dráhy posuvníka (vpravo je ešte číslo „100%“)
func _slider_rect() -> Rect2:
	var font: Font = get_theme_default_font()
	var s := _sc()
	var right: float = size.x - 3.0 - BAR_GAP * s
	var num_w: float = font.get_string_size("100%", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var w := _slider_w()
	var h: float = font_size
	var x0: float = roundf(right - num_w - 7.0 * s - w)
	return Rect2(x0, roundf(_base_y() - h), w, h)


func _slider_hit() -> Rect2:
	return _slider_rect().grow_individual(6.0 * _sc(), size.y, 6.0 * _sc(), size.y)


## Nakreslí posuvník + číslo, vráti x, kde končí (naľavo od neho ide popis)
func _draw_slider(font: Font, sel: bool, right: float, base_y: float) -> float:
	var s := _sc()
	var r := _slider_rect()
	var on_col: Color = BRASS if sel else DIM
	var off_col: Color = BRASS_D if sel else Color(BRASS_D, 0.7)
	# číslo vpravo (0 = OFF)
	var txt: String = "OFF" if level == 0 else "%d%%" % roundi(level * 100.0 / steps)
	var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(roundf(right - tw), base_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, CREAM if sel else DIM)
	var cy: float = r.position.y + r.size.y / 2.0 + s
	# zárezy: 10 políčok, plné zlaté, prázdne len obrys (vybraný posledný plný svieti krémovo)
	for i in steps:
		var rr := Rect2(r.position.x + i * 5.0 * s, roundf(cy - 3.0 * s), 4.0 * s, 6.0 * s)
		if i < level:
			draw_rect(rr, on_col if i < level - 1 or not sel else CREAM)
		else:
			draw_rect(rr.grow(-0.5), off_col, false, 1.0)
	if sel:   # malé šípky po stranách dráhy (miesto je vyhradené, nič sa neposúva)
		var a: float = 2.0 * s
		var lx: float = r.position.x - 5.0 * s
		var rx: float = r.end.x + 4.0 * s
		var col: Color = BRASS if level > 0 else BRASS_D
		draw_colored_polygon(PackedVector2Array([Vector2(lx, cy), Vector2(lx + a, cy - a), Vector2(lx + a, cy + a)]), col)
		col = BRASS if level < steps else BRASS_D
		draw_colored_polygon(PackedVector2Array([Vector2(rx + a, cy), Vector2(rx, cy - a), Vector2(rx, cy + a)]), col)
	return r.position.x - 14.0 * s
