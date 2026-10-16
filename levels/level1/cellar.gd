extends Level1
## Pivnica pod pizzeriou – samostatná mapa (P2): staré pašerácke tunely z prohibície ako bludisko.
## Ricco zíde po schodoch z herne, ide po krvavej stope (kvapky = správna cesta) až do Donovej skrýše.
## Hliadky s baterkou (kužeľ svetla = vidia ťa), stráž pri mrežiach, nízky oblúk (šmyk), šachta (odrazy od stien).
## Don, duch a prvá prestrelka: levels/level1/don_cutscene.gd. Scénu generuje tools/build_level1.gd (konštanta MAZE).
##
## Checkpointy (Level1.checkpoint): 3 = príchod do pivnice, 4 = dolný tunel (C), 5 = po cutscéne (Ricco má pištoľ).

const MAP := Rect2i(0, 0, 1600, 512)


func _ready() -> void:
	var black := _fade_rect()
	black.color.a = 1.0
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	pcam = player.get_node(^"PhantomCamera2D")
	_set_limits(MAP)
	var help := get_node_or_null(^"HUD/ControlsHelp") as Control
	if help:
		help.visible = false
	checkpoint = maxi(checkpoint, 3)
	if checkpoint < 5:
		var empty: Array[WeaponData] = []
		player.set_loadout(empty)
		player.focus.unlocked = false
	player.dark_area = true
	player.light_zones = 0
	var spawn := get_node_or_null(^"TunnelSpawn" if checkpoint == 4 else ^"CellarSpawn") as Node2D
	if spawn and checkpoint < 5:
		player.global_position = spawn.global_position
	pcam.teleport_position.call_deferred()
	var cp := get_node_or_null(^"TunnelCheckpoint") as Area2D
	if cp:
		cp.body_entered.connect(func(b: Node):
			if b == player:
				checkpoint = maxi(checkpoint, 4))
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(black, "color:a", 0.0, 0.8)
	tw.tween_callback(black.get_parent().queue_free)
	if checkpoint == 3 and not cellar_arrived:
		cellar_arrived = true
		_arrive()


## Príchod: Ricco zíde posledné schody a zbadá krv
func _arrive() -> void:
	player.set_cutscene(true)
	var target: Vector2 = player.global_position
	player.global_position = target + Vector2(-64, -48)
	player.sprite.play(player._hat_anim(&"run"))
	var tw := create_tween()
	tw.tween_property(player, "global_position", target, 0.9)
	await tw.finished
	player.sprite.play(player._hat_anim(&"idle"))
	await get_tree().create_timer(0.4).timeout
	speech(player, "BOSS...? YOU DOWN HERE?", Color8(245, 235, 209), 2.4, -64.0)
	await get_tree().create_timer(2.4).timeout
	speech(player, "...BLOOD. HE'S HURT.\nI GOTTA FOLLOW IT.", Color8(245, 235, 209), 2.8, -64.0)
	await get_tree().create_timer(0.6).timeout
	player.set_cutscene(false)
