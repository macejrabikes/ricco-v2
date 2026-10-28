extends Guest
## Čašník v klube The Blue Canary (kapitola III) – chodí s táckou medzi stolmi sem a tam, občas zastane pri stole.
## Je svedok ako hostia (world/npc/guest.gd): keď uvidí Ricca na svetle, skríkne a privolá mafiánov.
## Snímky chôdze idú dookola (loop), keď stojí, ukazuje snímku 0. Obrázok pozerá doprava.

@export var span: float = 120.0     ## px – ako ďaleko od začiatku chodí na každú stranu
@export var speed: float = 26.0     ## px/s

var walking: bool = true            ## false = zastal (poplach – ClubLevel ho pošle von)
var _home_x: float = 0.0
var _dir: float = 1.0
var _pause: float = 0.0


func _ready() -> void:
	super._ready()
	_home_x = position.x
	_dir = -1.0 if flip_h else 1.0


func _process(delta: float) -> void:
	super._process(delta)
	if dead or not walking:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	position.x += _dir * speed * delta
	if (position.x - _home_x) * _dir > span:
		_dir = -_dir
		_pause = randf_range(1.0, 2.4)
	elif randf() < delta * 0.12:
		_pause = randf_range(1.2, 2.6)   # zastane pri stole
	flip_h = _dir < 0.0


func _animate(delta: float) -> void:
	if _pause > 0.0 or not walking:
		frame = 0
		return
	super._animate(delta)
