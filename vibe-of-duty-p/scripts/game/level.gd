extends Node3D
## Test level: places the local player at a random spawn point and respawns them if they fall out.

const KILL_HEIGHT := -20.0

@onready var _player: Player = $Player
@onready var _spawns: Array[Node] = $SpawnPoints.get_children()


func _ready() -> void:
	_respawn()


func _physics_process(_delta: float) -> void:
	if _player.global_position.y < KILL_HEIGHT:
		_respawn()


func _respawn() -> void:
	_player.teleport(_spawns.pick_random().global_transform)
