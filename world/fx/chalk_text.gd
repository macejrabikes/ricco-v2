@tool
class_name ChalkText
extends Node2D
## Nápis kriedou na stene – každé písmeno je trochu inak natočené a posunuté (ako keď to niekto
## naozaj písal rukou), krieda je nerovnomerná (slabší druhý ťah, prach okolo) a pod prvým riadkom
## je rýchlo načmáraná čiara. Kreslí sa v _draw (Godot docs: classes/class_canvasitem – draw_char).

@export_multiline var text: String = "CHALK":
	set(v):
		text = v
		queue_redraw()
@export var font_size: int = 16
@export var color: Color = Color(0.93, 0.92, 0.86, 0.85)
@export var jitter: float = 1.0          ## px – o koľko poskakujú písmená hore/dole
@export var tilt: float = 0.07           ## rad – max. natočenie písmena
@export var underline: bool = true
@export var seed_value: int = 1:
	set(v):
		seed_value = v
		queue_redraw()

const FONT := preload("res://ui/fonts/tiny5.ttf")


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var line_h: float = font_size * 1.15
	var y: float = font_size
	var first_width: float = 0.0
	var lines := text.split("\n")
	for li in lines.size():
		var x: float = rng.randf_range(-2.0, 2.0)
		var slope: float = rng.randf_range(-0.025, 0.025)   # riadok mierne stúpa / klesá
		for ch in lines[li]:
			var w: float = FONT.get_char_size(ch.unicode_at(0), font_size).x
			if ch != " ":
				var p := Vector2(x, y + x * slope + rng.randf_range(-jitter, jitter))
				var rot: float = rng.randf_range(-tilt, tilt)
				var a: float = color.a * rng.randf_range(0.75, 1.0)
				draw_set_transform(p, rot, Vector2.ONE)
				draw_char(FONT, Vector2.ZERO, ch, font_size, Color(color, a))
				# druhý, slabší ťah kriedy kúsok vedľa
				draw_char(FONT, Vector2(1, 0), ch, font_size, Color(color, a * 0.25))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				# kriedový prach
				for i in 2:
					draw_rect(Rect2(p + Vector2(rng.randf_range(0, w), rng.randf_range(-font_size * 0.7, 2.0)), Vector2.ONE),
							Color(color, a * 0.3))
			x += w + rng.randf_range(0.0, 1.0)
		if li == 0:
			first_width = x
		y += line_h + rng.randf_range(-1.0, 1.0)
	if underline and first_width > 0.0:
		# rýchla čiara pod prvým riadkom (dva ťahy)
		var uy: float = font_size + 4.0
		var pts := PackedVector2Array()
		var steps: int = maxi(4, int(first_width / 12.0))
		for i in steps + 1:
			var t: float = float(i) / steps
			pts.append(Vector2(t * first_width, uy + sin(t * 9.0 + seed_value) * 1.2 + t * 1.5))
		draw_polyline(pts, Color(color, color.a * 0.55), 1.0)
