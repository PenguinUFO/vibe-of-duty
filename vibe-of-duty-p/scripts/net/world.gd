extends Node
## Per-level network layer: spawns/despawns players, runs the server snapshot broadcast and
## returns everyone to the menu on disconnect.
##
## Flow: client loads the level -> sends _client_ready -> server spawns the player, tells the new
## client about everyone already present and tells everyone else about the newcomer.
## Server -> clients: snapshots (unreliable, SNAPSHOT_INTERVAL ticks apart).
## Client -> server: PlayerCmd packets (see Player.submit_cmds).

const PLAYER_SCENE := preload("res://prefabs/player/player.tscn")
const SNAPSHOT_INTERVAL := 2  # physics ticks between snapshots (60 Hz / 2 = 30 Hz)
const KILL_HEIGHT := -20.0

var players: Dictionary = {}  # peer_id -> Player
var _ready_peers: Array[int] = []  # server: peers whose level has finished loading
var _tick := 0
var _log_timer := 0.0

@onready var _players_root: Node = $"../Players"
@onready var _spawns: Array[Node] = $"../SpawnPoints".get_children()


func _ready() -> void:
	Net.peer_left.connect(_on_peer_left)
	Net.disconnected.connect(_on_disconnected)
	if multiplayer.is_server():
		if not Game.dedicated:
			_server_add_player(1, Settings.player_name)
	else:
		_client_ready.rpc_id(1, Settings.player_name)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("leave"):
		Net.leave()  # emits Net.disconnected -> back to the menu


func _physics_process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_tick += 1
	for id in players:
		var player: Player = players[id]
		if player.global_position.y < KILL_HEIGHT:
			_server_respawn(id)
	if _tick % SNAPSHOT_INTERVAL == 0:
		_broadcast_snapshot()


func _process(delta: float) -> void:
	if not Game.net_log:
		return
	_log_timer += delta
	if _log_timer < 1.0:
		return
	_log_timer = 0.0
	var parts: PackedStringArray = []
	for id in players:
		var p: Player = players[id]
		parts.append("%d(%s)=(%.2f, %.2f, %.2f)" % [id, Player.Mode.keys()[p.control], p.global_position.x,
				p.global_position.y, p.global_position.z])
	var role := "SERVER" if multiplayer.is_server() else "CLIENT %d" % multiplayer.get_unique_id()
	print("[%s] t=%.1f %s" % [role, Time.get_ticks_msec() / 1000.0, " ".join(parts)])


# --- Server --------------------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _client_ready(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		return
	_server_add_player(id, player_name.left(24))


func _server_add_player(id: int, player_name: String) -> void:
	var xform := _random_spawn()
	# Tell the newcomer about everyone already here (their current position), then add the newcomer.
	if id != 1:
		for other_id in players:
			var other: Player = players[other_id]
			_spawn_player.rpc_id(id, other_id, other.player_name, other.global_transform)
	_spawn_player(id, player_name, xform)
	for peer in _ready_peers:
		_spawn_player.rpc_id(peer, id, player_name, xform)
	if id != 1:
		_spawn_player.rpc_id(id, id, player_name, xform)
		_ready_peers.append(id)


func _server_respawn(id: int) -> void:
	var xform := _random_spawn()
	players[id].teleport(xform)
	for peer in _ready_peers:
		_teleport_player.rpc_id(peer, id, xform)


func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server():
		return
	_ready_peers.erase(id)
	_despawn_player(id)
	for peer in _ready_peers:
		_despawn_player.rpc_id(peer, id)


func _broadcast_snapshot() -> void:
	if _ready_peers.is_empty():
		return
	var states: Array = []
	for id in players:
		states.append((players[id] as Player).get_net_state())
	for peer in _ready_peers:
		if Game.sim_lag_ms > 0:
			_send_snapshot_delayed(peer, states)
		else:
			_receive_snapshot.rpc_id(peer, states)


func _send_snapshot_delayed(peer: int, states: Array) -> void:
	await get_tree().create_timer(Game.sim_lag_ms / 1000.0).timeout
	if multiplayer.has_multiplayer_peer() and peer in _ready_peers:
		_receive_snapshot.rpc_id(peer, states)


func _random_spawn() -> Transform3D:
	return _spawns.pick_random().global_transform


# --- Client (also called locally on the server) ---------------------------------------------------

@rpc("authority", "reliable")
func _spawn_player(id: int, player_name: String, xform: Transform3D) -> void:
	if players.has(id):
		return
	var player: Player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	player.peer_id = id
	player.player_name = player_name
	if id == multiplayer.get_unique_id():
		player.control = Player.Mode.LOCAL
	elif multiplayer.is_server():
		player.control = Player.Mode.REMOTE_SERVER
	else:
		player.control = Player.Mode.PUPPET
	_players_root.add_child(player)
	player.teleport(xform)
	players[id] = player


@rpc("authority", "reliable")
func _despawn_player(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)


@rpc("authority", "reliable")
func _teleport_player(id: int, xform: Transform3D) -> void:
	if players.has(id):
		players[id].teleport(xform)


@rpc("authority", "unreliable_ordered")
func _receive_snapshot(states: Array) -> void:
	for state in states:
		if state is Array and state.size() == 8 and players.has(state[0]):
			(players[state[0]] as Player).push_snapshot(state)


func _on_disconnected() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(Game.MENU_SCENE)
