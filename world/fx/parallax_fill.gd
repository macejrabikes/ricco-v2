extends RefCounted
## Pozadie bez „diery“ dole: každá opakovaná vrstva pozadia (Parallax2D s repeat_size.x, z_index < 0) dostane
## pod svoj obrázok pás vo farbe jeho spodného riadku, ktorý siaha DEPTH px nadol. Keď kamera ide nižšie
## (strechy, jama, plávanie pod mólom), neukáže sa spodná hrana mesta a pod ňou obloha s ďalším mestom.
## Vrstvy, ktorých spodný riadok je skoro celý priehľadný (mraky), sa nepredlžujú.
## Volá ricco.gd (_ready, deferred) – Ricco je v každom leveli.
## Godot docs: classes/class_parallax2d, classes/class_polygon2d

const DEPTH := 2400.0
const META := &"parallax_fill_done"


static func apply(root: Node) -> void:
	if root == null or root.has_meta(META):
		return
	root.set_meta(META, true)
	for p in root.find_children("*", "Parallax2D", true, false):
		var layer := p as Parallax2D
		if layer.repeat_size.x <= 0.0 or layer.z_index >= 0:
			continue
		for s in layer.find_children("*", "Sprite2D", true, false):
			_extend(s as Sprite2D)


static func _extend(s: Sprite2D) -> void:
	if s.texture == null:
		return
	var img := s.texture.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	var w: int = img.get_width()
	var y: int = img.get_height() - 1
	var sum := Color(0, 0, 0, 0)
	var n: int = 0
	for x in w:
		var c := img.get_pixel(x, y)
		if c.a > 0.05:
			sum += c
			n += 1
	if n < int(w * 0.9):
		return   # spodok je priehľadný (mraky) – nepredlžovať
	var col := sum / float(n)
	col.a = minf(col.a, 1.0)
	var r: Rect2 = s.get_rect()
	var fill := Polygon2D.new()
	fill.name = "FillBelow"
	fill.color = col
	fill.polygon = PackedVector2Array([
		Vector2(r.position.x, r.end.y - 1.0), Vector2(r.end.x, r.end.y - 1.0),
		Vector2(r.end.x, r.end.y + DEPTH), Vector2(r.position.x, r.end.y + DEPTH)])
	fill.show_behind_parent = true
	s.add_child(fill)
