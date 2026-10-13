class_name GhostHand
extends Node2D
## Ruka ducha zavraždeného Dona – drží Riccovi zbraň.
## Obrázok je nakreslený v súradniciach pištole (pažba je pod dlaňou),
## takže uzol stačí dať ako dieťa zbrane. Pri mierení doľava sa preklopí spolu so zbraňou.
## Rovnaký skript používa aj druhá ruka (ghost_offhand.tscn), ktorá pri prebíjaní podá nový zásobník.
## Ruka jemne pulzuje (priesvitnosť) a z rukáva odletujú duchovské chuchvalce (Wisps).

@export var pulse_speed: float = 3.0              ## ako rýchlo pulzuje
@export_range(0.0, 1.0) var pulse_amount: float = 0.18  ## o koľko sa mení priesvitnosť
@export_range(0.0, 1.0) var fade: float = 1.0  ## celková viditeľnosť (na objavenie/zmiznutie ruky tweenom)

@onready var wisps: CPUParticles2D = $Wisps

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	modulate.a = fade * (1.0 - pulse_amount * (0.5 + 0.5 * sin(_t * pulse_speed)))
	wisps.emitting = is_visible_in_tree()
