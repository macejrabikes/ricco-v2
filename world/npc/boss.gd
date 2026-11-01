extends Guest
## Boss jednej z rodín pri dlhom stole na gale „M.“ (kapitola III – hotel_gala.gd). Nebojuje – na to má bodyguardov.
## Riccu nezbadá ako svedok (witness = false v scéne), pri poplachu sa skrčí pod stôl (skupina „seated“).
## Keď ho Ricco zastrelí, duch Dona nehreší ako pri nevinných – bossovia nie sú nevinní.
## Godot docs: tutorials/scripting/gdscript/gdscript_basics (dedičnosť, prepisovanie funkcií)

const BOSS_LINES := [
	"ONE LESS CHAIR AT THE TABLE.",
	"HE SOLD ME OUT IN '24.\nNOW WE'RE EVEN.",
	"THE FAMILIES WILL REMEMBER THIS, KID.",
]

static var _boss_n: int = 0


## Žiadne karhanie – ostatní hostia pri stole to videli (Guest.take_hit už zvreskol), duch sa len uškrnie
func _scold() -> void:
	var scene := get_tree().current_scene
	if scene.has_method(&"bark"):
		scene.bark(BOSS_LINES[_boss_n % BOSS_LINES.size()])
		_boss_n += 1
