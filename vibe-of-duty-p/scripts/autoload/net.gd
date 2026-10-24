extends Node
## Connection management (ENet). Gameplay replication lives in NetWorld (scripts/net/world.gd) and Player.

const DEFAULT_PORT := 27015
const MAX_PLAYERS := 4
const TRAINING_PORT := 27120

signal hosted
signal connected_to_server
signal map_received(path: String)  # client: the server told us its map and rules; load the map (or the lobby) and join
signal connection_failed
signal disconnected
signal peer_joined(id: int)
signal peer_left(id: int)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: connected_to_server.emit())
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		# The newcomer takes our map, match rules and weapon balance (weapons.cfg), loads the map, then reports ready
		# to NetWorld.
		_receive_map.rpc_id(id, Game.map_scene, {"score_limit": Game.score_limit, "match_time": Game.match_time,
				"random_weapons": Game.random_weapons, "weapons": WeaponDB.config_text, "lobby": Lobby.phase})
	peer_joined.emit(id)


## Client: which map the server plays (or that it is in the lobby: then the lobby is loaded instead), and its match rules. Only maps this build has are accepted (never load an
## arbitrary path).
@rpc("authority", "reliable")
func _receive_map(path: String, rules: Dictionary) -> void:
	if not Game.is_map(path):
		push_error("Server plays a map this build does not have: %s" % path)
		leave()
		return
	Game.map_scene = path
	Game.score_limit = int(rules.get("score_limit", Game.SCORE_LIMIT))
	Game.match_time = float(rules.get("match_time", Game.MATCH_TIME))
	Game.random_weapons = bool(rules.get("random_weapons", false))
	Lobby.phase = int(rules.get("lobby", Lobby.Phase.NONE)) as Lobby.Phase
	# The server's weapon numbers and modules: prediction must match its simulation (back to ours on leave()).
	if not WeaponDB.load_text(str(rules.get("weapons", ""))):
		push_error("Server sent no usable weapons.cfg")
		leave()
		return
	map_received.emit(path)


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	hosted.emit()
	return OK


## A server for training alone: listens on this computer only (nobody on the network can join), on the first free
## port from TRAINING_PORT.
func host_training() -> Error:
	var err := ERR_CANT_CREATE
	for port in range(TRAINING_PORT, TRAINING_PORT + 10):
		var peer := ENetMultiplayerPeer.new()
		peer.set_bind_ip("127.0.0.1")
		err = peer.create_server(port, 1)
		if err == OK:
			multiplayer.multiplayer_peer = peer
			hosted.emit()
			return OK
	return err


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	WeaponDB.load_local()  # a server's weapons.cfg is played only on that server
	disconnected.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	WeaponDB.load_local()
	disconnected.emit()
