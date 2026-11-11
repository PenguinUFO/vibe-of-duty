extends Node
## Connection management (ENet). Gameplay replication lives in NetWorld (scripts/net/world.gd) and Player.

const DEFAULT_PORT := 27015
const MAX_PLAYERS := 8  # the host included when it plays (not --server)
## Connections the server takes over MAX_PLAYERS: in a game filled up with bots a joining human gets in first, a bot
## then leaves (BotLauncher). The seats themselves are counted in _identify.
const SPARE_PEERS := 4
const TRAINING_PORT := 27120
## A silent peer is dropped after this long (ENet's own limits are 5-30 s: a crashed host left its clients frozen for
## half a minute). ENet drops between the two once its resends ran out.
const TIMEOUT_MIN_MS := 4000
const TIMEOUT_MAX_MS := 8000

signal hosted
signal connected_to_server
signal map_received(path: String)  # client: the server told us its map and rules; load the map (or the lobby) and join
signal connection_failed
signal disconnected
signal peer_joined(id: int)
signal peer_left(id: int)

var _bot_peers := {}    # server: peer id -> true, the bots BotLauncher started (they said so, _identify)
var _human_peers := {}  # server: peer id -> true, everybody else who has a seat
var _connected := {}    # server: peer id -> true, the peers not yet told gone (_forget)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func() -> void:
		_identify.rpc_id(1, Game.bot_key)
		connected_to_server.emit())
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _on_peer_connected(id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	# A client has a link only to the server (id 1); the other players are relayed.
	var link := enet.get_peer(id) if enet != null and (multiplayer.is_server() or id == 1) else null
	if link != null:
		link.set_timeout(0, TIMEOUT_MIN_MS, TIMEOUT_MAX_MS)  # 0: ENet's own number of resends
	if multiplayer.is_server():
		_connected[id] = true
	peer_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	_forget(id)
	BotLauncher.sync()  # team mode: a bot takes the place of a human who left


## Server: peer `id` is gone - its seat is free and everybody is told (peer_left), once. On a client: the server's
## word that somebody left.
func _forget(id: int) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not _connected.erase(id):
		return
	_bot_peers.erase(id)
	_human_peers.erase(id)
	BotLauncher.peer_left(id)
	peer_left.emit(id)


## Client -> server, first thing after connecting: who this is - a bot BotLauncher started (its key) or a player ("").
## The server gives them a seat or drops them (full), then sends its map and rules (_receive_map).
## Seats: MAX_PLAYERS in all, bots hold theirs. Team mode: a human gets in while humans are fewer than MAX_PLAYERS -
## a bot leaves for them (BotLauncher.sync).
@rpc("any_peer", "reliable")
func _identify(bot_key: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if _bot_peers.has(id) or _human_peers.has(id):
		return
	var bot := BotLauncher.claim(bot_key, id)
	var taken := humans() + (0 if not bot and Game.teams else _bot_peers.size())
	if taken >= MAX_PLAYERS:
		drop(id)
		BotLauncher.sync()
		return
	if bot:
		_bot_peers[id] = true
	else:
		_human_peers[id] = true
	# The newcomer takes our map, match rules and weapon balance (weapons.cfg), loads the map, then reports ready
	# to NetWorld.
	_receive_map.rpc_id(id, Game.map_scene, {"score_limit": Game.score_limit, "match_time": Game.match_time,
			"random_weapons": Game.random_weapons, "teams": Game.teams, "hardcore": Game.hardcore,
			"weapons": WeaponDB.config_text, "lobby": Lobby.phase})
	BotLauncher.sync()


## Server: the players who are not BotLauncher's bots, the host included when it plays.
func humans() -> int:
	return _human_peers.size() + (0 if Game.dedicated else 1)


func is_bot(id: int) -> bool:
	return _bot_peers.has(id)


## Server: disconnects a peer (no seat for them, or a bot that has to go) at once: they are out of the game before the
## next snapshot (peer_left is emitted here, whether or not the engine reports the disconnect itself).
func drop(id: int) -> void:
	if _connected.has(id):
		(multiplayer as SceneMultiplayer).disconnect_peer(id)
	_forget(id)


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
	Game.teams = bool(rules.get("teams", false))
	Game.hardcore = bool(rules.get("hardcore", false))
	Lobby.phase = int(rules.get("lobby", Lobby.Phase.NONE)) as Lobby.Phase
	# The server's weapon numbers and modules: prediction must match its simulation (back to ours on leave()).
	if not WeaponDB.load_text(str(rules.get("weapons", ""))):
		push_error("Server sent no usable weapons.cfg")
		leave()
		return
	map_received.emit(path)


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS + SPARE_PEERS)
	if err != OK:
		return err
	_bot_peers.clear()
	_human_peers.clear()
	_connected.clear()
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
