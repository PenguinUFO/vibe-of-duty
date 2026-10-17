class_name NetWorld
extends Node
## Per-level network layer: spawns/despawns players, runs the server snapshot broadcast, applies
## damage / deaths / respawns (server authority), keeps the lag-compensation history and returns
## everyone to the menu on disconnect.
##
## Flow: client loads the level -> sends _client_ready -> server spawns the player, tells the new
## client about everyone already present and tells everyone else about the newcomer.
## Server -> clients: snapshots (unreliable, SNAPSHOT_INTERVAL ticks apart), events (reliable).
## Client -> server: PlayerCmd packets (see Player.submit_cmds).

const PLAYER_SCENE := preload("res://prefabs/player/player.tscn")
const SNAPSHOT_INTERVAL := 2  # physics ticks between snapshots (60 Hz / 2 = 30 Hz)
const KILL_HEIGHT := -20.0
const RESPAWN_DELAY := 3.0
const SPAWN_PROTECTION_TICKS := 120
const HEAD_DAMAGE_MULT := 2.0

var players: Dictionary = {}  # peer_id -> Player
var server_tick := 0          # server: number of physics ticks simulated so far
var lag_comp := LagComp.new()
var lag_comp_enabled := true

var _ready_peers: Array[int] = []  # server: peers whose level has finished loading
var _last_snap_tick := 0           # client: tick of the most recent snapshot...
var _last_snap_time := 0.0         # ...and when it arrived (seconds)
var _log_timer := 0.0

@onready var _players_root: Node = $"../Players"
@onready var _spawns: Array[Node] = $"../SpawnPoints".get_children()


func _ready() -> void:
	lag_comp_enabled = Game.lag_comp_enabled
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
	# Runs after every Player has stepped this tick (Players come before World in the scene tree).
	server_tick += 1
	for id in players.keys():
		var player: Player = players[id]
		player.spawn_protect = maxi(player.spawn_protect - 1, 0)
		if player.alive and player.global_position.y < KILL_HEIGHT:
			_server_suicide(player)
	lag_comp.record(server_tick, players)
	if server_tick % SNAPSHOT_INTERVAL == 0:
		_broadcast_snapshot()


func _process(_delta: float) -> void:
	if not Game.net_log:
		return
	_log_timer += _delta
	if _log_timer < 1.0:
		return
	_log_timer = 0.0
	var parts: PackedStringArray = []
	for id in players:
		var p: Player = players[id]
		parts.append("%d(%s)=(%.1f, %.1f, %.1f) hp=%d %s srv_shots=%d srv_hits=%d" % [id, Player.Mode.keys()[p.control],
				p.global_position.x, p.global_position.y, p.global_position.z, p.health, p.debug_weapon_string(),
				p.shots_total, p.hits_total])
	var role := "SERVER" if multiplayer.is_server() else "CLIENT %d" % multiplayer.get_unique_id()
	var scores := " scores=%s" % str(Game.scores) if multiplayer.is_server() else ""
	print("[%s] t=%.1f %s%s" % [role, Time.get_ticks_msec() / 1000.0, " ".join(parts), scores])


## Client: the server tick whose world state the local player currently sees on screen (puppets are
## drawn Player.INTERP_DELAY in the past). Sent with every command so the server can rewind targets.
func get_view_tick() -> float:
	if _last_snap_tick == 0:
		return 0.0
	var render_time := Time.get_ticks_msec() / 1000.0 - Player.INTERP_DELAY
	return float(_last_snap_tick) + (render_time - _last_snap_time) * 60.0


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
	var xform := _pick_spawn(-1)
	# Tell the newcomer about everyone already here (their current position), then add the newcomer.
	if id != 1:
		for other_id in players:
			var other: Player = players[other_id]
			_spawn_player.rpc_id(id, other_id, other.player_name, other.global_transform)
	_spawn_player(id, player_name, xform)
	Game.ensure_player(id)
	for peer in _ready_peers:
		_spawn_player.rpc_id(peer, id, player_name, xform)
	if id != 1:
		_spawn_player.rpc_id(id, id, player_name, xform)
		_ready_peers.append(id)


func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server():
		return
	_ready_peers.erase(id)
	lag_comp.forget(id)
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
			_send_snapshot_delayed(peer, server_tick, states)
		else:
			_receive_snapshot.rpc_id(peer, server_tick, states)


func _send_snapshot_delayed(peer: int, tick: int, states: Array) -> void:
	await get_tree().create_timer(Game.sim_lag_ms / 1000.0).timeout
	if multiplayer.has_multiplayer_peer() and peer in _ready_peers:
		_receive_snapshot.rpc_id(peer, tick, states)


## Spawn point farthest from living players (two best candidates, picked at random).
func _pick_spawn(exclude_id: int) -> Transform3D:
	var scored: Array = []
	for spawn in _spawns:
		var nearest := INF
		for id in players:
			var other: Player = players[id]
			if id != exclude_id and other.alive:
				nearest = minf(nearest, other.global_position.distance_to(spawn.global_position))
		scored.append({"xform": spawn.global_transform, "score": nearest})
	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	return scored[randi() % mini(2, scored.size())]["xform"]


## Server: apply a shooter's damage to a victim (called by Player after a shot is judged).
func server_apply_damage(attacker: Player, victim: Player, amount: float, head: bool, weapon: int) -> void:
	if not victim.alive or victim.spawn_protect > 0 or attacker == victim:
		return
	var killed := victim.server_damage(amount)
	if attacker.control == Player.Mode.LOCAL:
		attacker.on_hit_confirmed(killed, head)  # the host is the shooter
	elif attacker.peer_id in _ready_peers:
		_hit_confirm.rpc_id(attacker.peer_id, killed, head)
	if killed:
		_server_kill(attacker, victim, weapon, head)


func _server_suicide(player: Player) -> void:
	player.server_damage(9999.0)
	_server_kill(player, player, -1, false)


func _server_kill(killer: Player, victim: Player, weapon: int, head: bool) -> void:
	Game.add_kill(killer.peer_id, victim.peer_id)
	_apply_death(victim.peer_id, killer.peer_id, weapon, head, RESPAWN_DELAY)
	for peer in _ready_peers:
		_player_died.rpc_id(peer, victim.peer_id, killer.peer_id, weapon, head, RESPAWN_DELAY)
	var victim_id := victim.peer_id
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(func() -> void: _server_respawn(victim_id))


func _server_respawn(id: int) -> void:
	if not players.has(id):
		return
	var player: Player = players[id]
	var xform := _pick_spawn(id)
	player.spawn_protect = SPAWN_PROTECTION_TICKS
	lag_comp.clear(id)
	_apply_respawn(id, xform)
	for peer in _ready_peers:
		_player_respawned.rpc_id(peer, id, xform)


# --- Client (also called locally on the server) ---------------------------------------------------

@rpc("authority", "reliable")
func _spawn_player(id: int, player_name: String, xform: Transform3D) -> void:
	if players.has(id):
		return
	var player: Player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	player.peer_id = id
	player.player_name = player_name
	player.world = self
	if id == multiplayer.get_unique_id():
		player.control = Player.Mode.LOCAL
	elif multiplayer.is_server():
		player.control = Player.Mode.REMOTE_SERVER
	else:
		player.control = Player.Mode.PUPPET
	_players_root.add_child(player)
	player.teleport(xform)
	players[id] = player
	if multiplayer.is_server():
		player.server_shot.connect(_on_server_shot)


## Server: relay a shot to everyone except the shooter, who already showed it (prediction).
func _on_server_shot(shooter: Player, weapon: int, origin: Vector3, ends: PackedVector3Array, _hits: Array) -> void:
	for peer in _ready_peers:
		if peer != shooter.peer_id:
			_remote_shot.rpc_id(peer, shooter.peer_id, weapon, origin, ends)
	if not Game.dedicated and shooter.control != Player.Mode.LOCAL:
		shooter.show_remote_shot(weapon, origin, ends)  # the host machine sees clients' shots too


@rpc("authority", "unreliable")
func _remote_shot(shooter_id: int, weapon: int, origin: Vector3, ends: PackedVector3Array) -> void:
	if players.has(shooter_id) and shooter_id != multiplayer.get_unique_id():
		(players[shooter_id] as Player).show_remote_shot(weapon, origin, ends)


@rpc("authority", "reliable")
func _hit_confirm(killed: bool, head: bool) -> void:
	var me := multiplayer.get_unique_id()
	if players.has(me):
		(players[me] as Player).on_hit_confirmed(killed, head)


@rpc("authority", "reliable")
func _player_died(victim_id: int, killer_id: int, weapon: int, head: bool, delay: float) -> void:
	_apply_death(victim_id, killer_id, weapon, head, delay)


func _apply_death(victim_id: int, killer_id: int, _weapon: int, _head: bool, delay: float) -> void:
	if not players.has(victim_id):
		return
	var killer_name := ""
	if killer_id != victim_id and players.has(killer_id):
		killer_name = (players[killer_id] as Player).player_name
	(players[victim_id] as Player).die(killer_name, delay)


@rpc("authority", "reliable")
func _player_respawned(id: int, xform: Transform3D) -> void:
	_apply_respawn(id, xform)


func _apply_respawn(id: int, xform: Transform3D) -> void:
	if players.has(id):
		(players[id] as Player).respawn(xform)


@rpc("authority", "reliable")
func _despawn_player(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)


@rpc("authority", "unreliable_ordered")
func _receive_snapshot(tick: int, states: Array) -> void:
	_last_snap_tick = tick
	_last_snap_time = Time.get_ticks_msec() / 1000.0
	for state in states:
		if state is Array and state.size() == 9 and players.has(state[0]):
			(players[state[0]] as Player).push_snapshot(state)


func _on_disconnected() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(Game.MENU_SCENE)
