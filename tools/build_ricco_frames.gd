extends SceneTree
## Nástroj: znovu vytvorí characters/ricco/ricco_frames.tres zo sprite sheetov.
## Spustenie: godot --headless --path . --script res://tools/build_ricco_frames.gd
# [name, sheet, frames, fps, loop, (voliteľne) veľkosť framu – predvolene 64]
var ANIMS := [
	["idle",        "idle_hurt",   [0,1,2,3,4,5],                 5.0,  true],
	["hurt",        "hurt",        [0,1,2],                      14.0, false],  # zľaknutie, klobúk poskočí a dopadne
	["hurt_nohat",  "hurt_nohat",  [0,1,2],                      14.0, false],
	["run",         "run",         range(10),                    10.0, true],  # telo zo SOČ animácie, nové labky a plutva
	["jump",        "jump",        [3,4,5],                      14.0, false],
	["fall",        "jump",        [6,7,8,9,10,11],              12.0, true],
	["land",        "jump",        [12,13,14],                   18.0, false],
	["turn",        "turn",        [0,1,2],                      20.0, false],
	["slide_start", "slide",       [1,2,3,4],                    16.0, false],
	["slide",       "slide",       [5,6,7,8,9],                  12.0, true],
	["slide_end",   "slide",       [10,11,12,13,14,15],          18.0, false],
	["flip",        "flip",        [0,1,2,3,4,5,6,7,8,9],        24.0, false],
	["swim",        "swim",        [0,1,2,3,4,5,6],              10.0, true],
	["throw",       "throw",       [0,1,2,3,4,5,6,7],            16.0, false],
	["grab",        "grab",        [0,1,2,3],                    14.0, false],
	["grab_hold",   "grab",        [8,9,10,11,12,13,14,15],       8.0, true],
	["shield_walk", "shield_walk", [0,1,2,3,4,5,6,7],            10.0, true],
	["celebrate",   "celebrate",   [0,1,2,3,4,5,6,7],            10.0, false],
	["death",       "death",       range(16),                    12.0, false],
	["wall_slide",  "wall_slide",  [0,1],                         5.0, true],
	["wall_jump",   "wall_jump",   [0],                           7.0, false],
	["hat_throw",   "hat_throw",   [0,1,2,3,4,5],                12.0, false],
	["hat_catch",   "hat_catch",   [0,1,2,4,5,6,7],              12.0, false],
	["idle_nohat",  "idle_nohat",  [0],                           1.0, true],
	# bez klobúka (kým letí hodený klobúk) – hlava dokreslená namiesto klobúka
	["run_nohat",   "run_nohat",   range(10),                    10.0, true],
	["jump_nohat",  "jump_nohat",  [3,4,5],                      14.0, false],
	["fall_nohat",  "jump_nohat",  [6,7,8,9,10,11],              12.0, true],
	["land_nohat",  "jump_nohat",  [12,13,14],                   18.0, false],
	["turn_nohat",  "turn_nohat",  [0,1,2],                      20.0, false],
	["slide_start_nohat", "slide_nohat", [1,2,5,6],              16.0, false],  # skok na brucho (bez snímok 3, 4)
	["slide_nohat",       "slide_nohat", [5,6,7,8,9],            12.0, true],
	["slide_end_nohat",   "slide_nohat", [10,11,12,13,14,15],    18.0, false],
	["hang",        "hang",        [0],                           1.0, true],
	["climb",       "climb",       [0,1,2],                      10.0, false, 96],
]

func _init() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for a in ANIMS:
		var tex: Texture2D = load("res://characters/ricco/sprites/%s.png" % a[1])
		var size: int = a[5] if a.size() > 5 else 64
		var cols: int = tex.get_width() / size
		sf.add_animation(a[0])
		sf.set_animation_speed(a[0], a[3])
		sf.set_animation_loop_mode(a[0], SpriteFrames.LOOP_LINEAR if a[4] else SpriteFrames.LOOP_NONE)
		for i in a[2]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((i % cols) * size, (i / cols) * size, size, size)
			sf.add_frame(a[0], at)
	var err := ResourceSaver.save(sf, "res://characters/ricco/ricco_frames.tres")
	print("saved: ", err, " anims: ", sf.get_animation_names())
	quit()
