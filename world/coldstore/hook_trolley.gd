extends Node2D
## Jeden vozík na koľajnici s hákmi (world/coldstore/hook_rail.gd). Počiatok uzla je úchyt háku –
## tu sa drží Ricco (characters/ricco/ricco.gd – _process_hook). Na háku môže visieť polovica mäsa (carcass.gd).

var velocity: Vector2 = Vector2.ZERO   ## px/s – rýchlosť koľajnice (Ricco ju dostane, keď zoskočí)
var carcass: Node2D                    ## mäso na háku (null = voľný hák, dá sa chytiť)
var shown: bool = true                 ## false = vozík je práve „v stene“ (koniec slučky)
