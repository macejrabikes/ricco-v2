class_name Objectives
## Aktuálny cieľ (vpravo hore v HUD – ui/hud/objective_box.gd) a kam ukazuje šípka „kam ďalej“ (ui/hud/guide_arrow.gd).
## Ciele sa nezapisujú v leveloch – vyberajú sa podľa toho, čo už levely ukladajú: checkpoint kapitoly
## (Level1–4.checkpoint) a pár príznakov (Level2.clue_found, ledger_read, escape_stage…). Platí POSLEDNÉ pravidlo, ktoré sedí.
##
## Pravidlo: [od_checkpointu, podmienka (Callable alebo null), text, ciele]
## Ciele = mená uzlov v scéne, skúšajú sa po poradí, prvý nájdený vyhráva:
##   "@next"        → najbližší ďalší checkpoint v scéne (Checkpoint{n+1}, …Up, …Roof)
##   "@spot:READ"   → InteractSpot s týmto slovom, ktorý sa ešte dá použiť
##   "MenoUzla"     → ľubovoľný uzol (find_child), napr. ExitDoor
## Prázdne ciele = šípka sa neukáže (boss, naháňačka).
## Nový cieľ = nový riadok v _rules().

const NEXT := "@next"


## Text a cieľový uzol pre aktuálnu scénu ({} = žiadny cieľ – úvod, menu, cutscéna)
static func current(scene: Node) -> Dictionary:
	if scene == null:
		return {}
	var cp: int = _checkpoint(scene)
	if cp < 0:
		return {}
	var pick: Array = []
	for r in _rules(scene):
		if cp >= int(r[0]) and (r[1] == null or (r[1] as Callable).call()):
			pick = r
	if pick.is_empty():
		return {}
	return {"text": pick[2], "targets": pick[3], "cp": cp}


static func _checkpoint(scene: Node) -> int:
	if scene is Level1:
		return Level1.checkpoint
	if scene is Level2:
		return Level2.checkpoint
	if scene is Level3:
		return Level3.checkpoint
	if scene is Level4:
		return Level4.checkpoint
	return -1


static func _rules(scene: Node) -> Array:
	if scene is Level1:
		return [
			[0, null, "Get inside Don Vito's pizzeria", ["WindowEnter"]],
			[1, null, "Sneak through the back of the restaurant", [NEXT]],
			[2, null, "Find the Don - he's somewhere downstairs", [NEXT]],
			[3, null, "Follow the blood trail through the tunnels", ["TunnelCheckpoint", "DonTrigger"]],
			[4, null, "Follow the blood trail to the Don", ["DonTrigger"]],
			[5, null, "Fight your way out of the cellar", ["CellarExit"]],
		]
	if scene is Level2:
		return [
			[0, null, "Get into the cemetery", ["InsideGate"]],
			[0, func(): return Level2.street_done, "Sneak through the cemetery", ["@spot:TAKE", NEXT]],
			[1, null, "Find the Don's funeral", [NEXT]],
			[2, null, "Watch the funeral from the shadows", [NEXT]],
			[2, func(): return Level2.funeral_seen and not Level2.clue_found, "Find what the mobster threw away", ["@spot:PICK UP"]],
			[0, func(): return Level2.clue_found and Level2.checkpoint < 4, "Get to the crypt - it leads to the docks", ["CryptExit"]],
			[4, null, "Find Pier 13", [NEXT, "ExitDoor"]],
			[7, null, "Find Big Lou's office in the cold store", [NEXT, "@spot:READ"]],
			[7, func(): return Level2.ledger_read, "Get to the S.S. Margaret before 2:00", ["ExitDoor"]],
			[11, null, "Take down Big Lou", []],
			[11, func(): return Level2.escape_stage >= 1, "Search Lou's cabin under the bridge", ["@spot:ENTER", "@spot:READ"]],
			[11, func(): return Level2.escape_stage >= 2, "Get to the lifeboat - the ship is going down!", ["@spot:LOWER"]],
		]
	if scene is Level3:
		return [
			[0, null, "Climb up to the promenade", [NEXT]],
			[1, null, "Head up to the rooftops", [NEXT]],
			[3, null, "Cross the rooftops of the Lower East Side", [NEXT]],
			[5, null, "Reach the El station at Delancey St", [NEXT]],
			[9, null, "Make your way to the front car", [NEXT]],
			[14, null, "Get backstage at The Blue Canary", [NEXT]],
			[17, null, "Find Velvet Sal", [NEXT]],
			[22, null, "Find a way up to the Starlight Room", [NEXT]],
			[22, func(): return Level3.checkpoint >= 25 and not Level3.lift_key, "Find the freight elevator key", ["@spot:TAKE", NEXT]],
			[26, null, "Crash M.'s gala", [NEXT]],
			[28, null, "Get to the roof", [NEXT]],
			[30, null, "Climb Iron Mike's tower", [NEXT]],
			[32, null, "Take down Iron Mike", []],
			[33, null, "Stay on the taxi - follow the airship", []],
			[34, null, "Cross the Queensboro Bridge", [NEXT]],
			[36, null, "Take down Chief Murphy", []],
		]
	if scene is Level4:
		return [
			[0, null, "Sneak along the old pier", [NEXT]],
			[1, null, "Get through the smugglers' cave", [NEXT]],
			[3, null, "Take the freight elevator up to the villa", [NEXT, "@spot:GO UP"]],
			[5, null, "Climb up through the villa cellars", [NEXT]],
			[8, null, "Reach the mirror hall at the top of the villa", [NEXT]],
			[11, null, "Face Margaret Vito", []],
			[12, null, "Get out of the burning villa!", [NEXT]],
		]
	return []


## Prvý cieľ zo zoznamu, ktorý v scéne existuje (null = nič)
static func find_target(scene: Node, targets: Array, cp: int) -> Node2D:
	for t in targets:
		var s: String = t
		var n: Node2D = null
		if s == NEXT:
			for suffix in ["", "Up", "Roof"]:
				n = scene.find_child("Checkpoint%d%s" % [cp + 1, suffix], true, false) as Node2D
				if n:
					break
			if n == null:   # ďalší checkpoint je až v ďalšej časti kapitoly → východ z tejto (ExitRoof, ExitBoathouse…)
				n = _exit(scene)
		elif s.begins_with("@spot:"):
			n = _spot(scene, s.substr(6))
		else:
			n = scene.find_child(s, true, false) as Node2D
		if n and n.is_inside_tree():
			return n
	return null


static func _spot(scene: Node, verb: String) -> Node2D:
	for n in scene.find_children("*", "Area2D", true, false):
		var s := n as InteractSpot
		if s and s.verb == verb and s.glow_state() != InteractGlow.OFF:
			return s
	return null


static func _exit(scene: Node) -> Node2D:
	for n in scene.get_children():
		if n is Node2D and String(n.name).begins_with("Exit"):
			return n
	return null
