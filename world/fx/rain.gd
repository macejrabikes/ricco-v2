extends CPUParticles2D
## Dážď – kvapky padajú šikmo po celej obrazovke, sleduje kameru (Godot docs: classes/class_cpuparticles2d).

func _ready() -> void:
	texture = preload("res://levels/level1/art/raindrop.png")
	amount = 220
	lifetime = 0.9
	preprocess = 1.0
	local_coords = false
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(420, 2)
	direction = Vector2(0.18, 1.0)
	spread = 2.0
	gravity = Vector2.ZERO
	initial_velocity_min = 430.0
	initial_velocity_max = 520.0
	particle_flag_align_y = true
	color = Color(0.7, 0.78, 0.95, 0.55)
	z_index = 20


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		global_position = cam.get_screen_center_position() + Vector2(-40, -220)
