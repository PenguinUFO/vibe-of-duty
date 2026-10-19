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
const SNAPSHOT_INTERVAL := 1  # physics ticks between snapshots (60 Hz: others can be drawn only ~30 ms behind)
const KILL_HEIGHT := -20.0

## Below this height a living player dies (fell off the map). Maps may raise it: on the train the ground beside the
## track is deadly (it rushes past at 80 km/h).
@export var kill_height := KILL_HEIGHT
const RESPAWN_DELAY := 3.0
const SPAWN_PROTECTION_TICKS := 120
const HEAD_DAMAGE_MULT := 2.0
const NAME_MAX := 24  # characters, like the main menu's name field
const OINK_COOLDOWN := 0.8  # s between two oinks (F) of one player

var players: Dictionary = {}  # peer_id -> Player
var server_tick := 0          # server: number of physics ticks simulated so far
var lag_comp := LagComp.new()
var lag_comp_enabled := true

var _ready_peers: Array[int] = []  # server: peers whose level has finished loading
var _last_oink := {}               # server: peer_id -> time (s) of their last oink
var _last_snap_tick := 0           # client: tick of the most recent snapshot...
var _last_snap_time := 0.0         # ...and when it arrived (seconds)
var hud: GameHud
var kill_cam: KillCam
var pause_menu: PauseMenu
var _log_timer := 0.0

@onready var _players_root: Node = $"../Players"
@onready var _spawns: Array[Node] = $"../SpawnPoints".get_children()


func _ready() -> void:
	lag_comp_enabled = Game.lag_comp_enabled
	Game.reset_match()
	if not Game.dedicated:
		hud = GameHud.new()
		hud.world = self
		add_child(hud)
		pause_menu = PauseMenu.new()
		add_child(pause_menu)
		kill_cam = KillCam.new()
		kill_cam.world = self
		add_child(kill_cam)
		Audio.play_music_id("game")
		# Load everything the first shot / first opponent would otherwise load mid-match (a hitch).
		WeaponDB.preload_scenes()
		PlayerVisual.preload_scenes()
	Settings.graphics_changed.connect(_apply_sun)
	_apply_sun()
	Net.peer_left.connect(_on_peer_left)
	Net.disconnected.connect(_on_disconnected)
	if multiplayer.is_server():
		if not Game.dedicated:
			_server_add_player(1, _unique_name(Settings.player_name), Settings.kid_mode)
	else:
		_client_ready.rpc_id(1, Settings.player_name, Settings.kid_mode)


## Gives the level's sun the shadow settings of the current graphics quality.
func _apply_sun() -> void:
	var sun := get_node_or_null("../Sun") as DirectionalLight3D
	if sun:
		Settings.apply_sun(sun)


func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_server_match_clock(delta)
	# Runs after every Player has stepped this tick (Players come before World in the scene tree).
	server_tick += 1
	for id in players.keys():
		var player: Player = players[id]
		player.spawn_protect = maxi(player.spawn_protect - 1, 0)
		if player.alive and player.global_position.y < kill_height:
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
		parts.append("%d(%s)=(%.1f, %.1f, %.1f) hp=%d %s srv_shots=%d srv_hits=%d heads=%d" % [id, Player.Mode.keys()[p.control],
				p.global_position.x, p.global_position.y, p.global_position.z, p.health, p.debug_weapon_string(),
				p.shots_total, p.hits_total, p.head_hits_total])
	var role := "SERVER" if multiplayer.is_server() else "CLIENT %d" % multiplayer.get_unique_id()
	var scores := " scores=%s" % str(Game.scores) if multiplayer.is_server() else ""
	print("[%s] t=%.1f state=%d left=%.0f %s%s" % [role, Time.get_ticks_msec() / 1000.0, Game.state,
			Game.time_left if Game.state == Game.State.PLAYING else Game.intermission_left, " ".join(parts), scores])


## The server tick the local player sees the others at (they are drawn slightly in the past, Player._buffered_pose):
## the average over them. Sent with every command so the server can rewind targets to what was on screen; 0 when
## nobody else is shown (shots are then judged against live positions).
func get_view_tick() -> float:
	var total := 0.0
	var count := 0
	for id in players:
		var p: Player = players[id]
		if p.control != Player.Mode.LOCAL and p.shown_tick > 0.0:
			total += p.shown_tick
			count += 1
	return total / count if count > 0 else 0.0


# --- Server --------------------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _client_ready(player_name: String, kid_mode: bool = false) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		return
	_server_add_player(id, _unique_name(player_name), kid_mode)


## Server: the name a joining player gets: as sent, or with "_2", "_3"... when someone here already has it (any
## letter case), shortened to fit the 24 characters of the name field.
func _unique_name(wanted: String) -> String:
	var base := wanted.strip_edges().left(NAME_MAX)
	if base == "":
		base = "Игрок"
	var taken := {}
	for other_id in players:
		taken[(players[other_id] as Player).player_name.to_lower()] = true
	if not taken.has(base.to_lower()):
		return base
	var n := 2
	while true:
		var suffix := "_%d" % n
		var candidate := base.left(NAME_MAX - suffix.length()) + suffix
		if not taken.has(candidate.to_lower()):
			return candidate
		n += 1
	return base


func _server_add_player(id: int, player_name: String, kid_mode: bool) -> void:
	if Game.net_log:
		print("[SERVER] player %d joined as %s" % [id, player_name])
	var xform := _pick_spawn(-1)
	# Tell the newcomer about everyone already here (their current position), then add the newcomer.
	if id != 1:
		for other_id in players:
			var other: Player = players[other_id]
			_spawn_player.rpc_id(id, other_id, other.player_name, other.global_transform, other.kid_mode)
	_spawn_player(id, player_name, xform, kid_mode)
	Game.ensure_player(id)
	for peer in _ready_peers:
		_spawn_player.rpc_id(peer, id, player_name, xform, kid_mode)
	if id != 1:
		_spawn_player.rpc_id(id, id, player_name, xform, kid_mode)
		_ready_peers.append(id)
		_sync_scores.rpc_id(id, Game.scores)
		_sync_match.rpc_id(id, Game.state, Game.time_left, Game.intermission_left, Game.winners)
	_broadcast_scores()


func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server():
		return
	_ready_peers.erase(id)
	lag_comp.forget(id)
	_despawn_player(id)
	for peer in _ready_peers:
		_despawn_player.rpc_id(peer, id)
	Game.scores.erase(id)
	_broadcast_scores()


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
	if Game.test_spawn != Vector3.INF:
		return Transform3D(Basis.IDENTITY, Game.test_spawn)
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
	var from := attacker.global_position + Vector3.UP * Player.STAND_EYE  # for the victim's damage direction arc
	if victim.control == Player.Mode.LOCAL:
		victim.on_damaged_from(from)  # the host is the victim
	elif victim.peer_id in _ready_peers:
		_damaged_from.rpc_id(victim.peer_id, from)
	if killed:
		_server_kill(attacker, victim, weapon, head)


func _server_suicide(player: Player) -> void:
	player.server_damage(9999.0)
	_server_kill(player, player, -1, false)


func _server_kill(killer: Player, victim: Player, weapon: int, head: bool) -> void:
	Game.add_kill(killer.peer_id, victim.peer_id)
	_broadcast_scores()
	_apply_death(victim.peer_id, killer.peer_id, weapon, head, RESPAWN_DELAY)
	for peer in _ready_peers:
		_player_died.rpc_id(peer, victim.peer_id, killer.peer_id, weapon, head, RESPAWN_DELAY)
	var victim_id := victim.peer_id
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(func() -> void: _server_respawn(victim_id, false))
	if Game.state == Game.State.PLAYING and Game.top_kills() >= Game.score_limit:
		_server_end_match("score limit")


## Server: respawns a player. `force` also resets a living player (new match); otherwise only the dead are
## respawned, and not between matches (the next match respawns everybody).
func _server_respawn(id: int, force: bool) -> void:
	if not players.has(id):
		return
	var player: Player = players[id]
	if not force and (player.alive or Game.is_frozen()):
		return
	var xform := _pick_spawn(id)
	player.spawn_protect = SPAWN_PROTECTION_TICKS
	player.alive = true
	lag_comp.clear(id)
	_apply_respawn(id, xform)
	for peer in _ready_peers:
		_player_respawned.rpc_id(peer, id, xform)


# --- Match flow (server) ----------------------------------------------------------------------------

func _server_match_clock(delta: float) -> void:
	if Game.state == Game.State.PLAYING:
		Game.time_left = maxf(Game.time_left - delta, 0.0)
		if Game.time_left <= 0.0:
			_server_end_match("time limit")
	elif Game.state == Game.State.ENDED:
		Game.intermission_left = maxf(Game.intermission_left - delta, 0.0)
		if Game.intermission_left <= 0.0:
			_server_start_match()
	if server_tick % 60 == 0:
		_broadcast_match()  # once a second: clients count down locally in between


func _server_end_match(reason: String) -> void:
	Game.end_match()
	Audio.play("match_end")
	if Game.net_log:
		print("[MATCH] ended (%s) winners=%s scores=%s" % [reason, str(Game.winners), str(Game.scores)])
	_broadcast_match()
	_apply_match_state()


func _server_start_match() -> void:
	Game.reset_match()
	Audio.play("match_start")
	for id in players.keys():
		Game.ensure_player(id)
	if Game.net_log:
		print("[MATCH] started")
	_broadcast_scores()
	_broadcast_match()
	_apply_match_state()
	for id in players.keys():
		_server_respawn(id, true)


func _broadcast_scores() -> void:
	for peer in _ready_peers:
		_sync_scores.rpc_id(peer, Game.scores)
	_apply_match_state()


func _broadcast_match() -> void:
	for peer in _ready_peers:
		_sync_match.rpc_id(peer, Game.state, Game.time_left, Game.intermission_left, Game.winners)


## Lets the HUD on this machine (host or client) know that scores/state changed.
func _apply_match_state() -> void:
	if hud:
		hud.refresh()


# --- Client (also called locally on the server) ---------------------------------------------------

@rpc("authority", "reliable")
func _spawn_player(id: int, player_name: String, xform: Transform3D, kid_mode: bool = false) -> void:
	if players.has(id):
		return
	var player: Player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	player.peer_id = id
	player.player_name = player_name
	player.set_kid_mode(kid_mode)
	player.world = self
	if id == multiplayer.get_unique_id():
		player.control = Player.Mode.LOCAL
	elif multiplayer.is_server():
		player.control = Player.Mode.REMOTE_SERVER
	else:
		player.control = Player.Mode.PUPPET
	_players_root.add_child(player)
	player.teleport(xform)
	if kill_cam != null and kill_cam.is_playing():
		player.set_kill_cam(true)
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


## Client -> server: the sender pressed F (oink).
@rpc("any_peer", "reliable")
func request_oink() -> void:
	if multiplayer.is_server():
		server_oink(multiplayer.get_remote_sender_id())


## Passes an oink on to everyone but the player (who already heard it). The cooldown is checked here too, so a
## modified client cannot spam it.
func server_oink(id: int) -> void:
	if not players.has(id) or not (players[id] as Player).alive:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_oink.get(id, -1000.0)) < OINK_COOLDOWN - 0.15:  # some slack for network jitter
		return
	_last_oink[id] = now
	for peer in _ready_peers:
		if peer != id:
			_oink.rpc_id(peer, id)
	if not Game.dedicated and id != multiplayer.get_unique_id():
		(players[id] as Player).play_oink()  # the host machine hears clients too


@rpc("authority", "reliable")
func _oink(id: int) -> void:
	if players.has(id) and id != multiplayer.get_unique_id():
		(players[id] as Player).play_oink()


@rpc("authority", "reliable")
func _hit_confirm(killed: bool, head: bool) -> void:
	var me := multiplayer.get_unique_id()
	if players.has(me):
		(players[me] as Player).on_hit_confirmed(killed, head)


@rpc("authority", "unreliable")
func _damaged_from(from: Vector3) -> void:
	var me := multiplayer.get_unique_id()
	if players.has(me):
		(players[me] as Player).on_damaged_from(from)


@rpc("authority", "reliable")
func _player_died(victim_id: int, killer_id: int, weapon: int, head: bool, delay: float) -> void:
	_apply_death(victim_id, killer_id, weapon, head, delay)


func _apply_death(victim_id: int, killer_id: int, weapon: int, head: bool, delay: float) -> void:
	if not players.has(victim_id):
		return
	var victim: Player = players[victim_id]
	var killer_name := ""
	if killer_id != victim_id and players.has(killer_id):
		killer_name = (players[killer_id] as Player).player_name
	victim.die(killer_name, delay)
	if kill_cam != null and victim.is_local and killer_name != "":
		kill_cam.start(killer_id)
	if hud:
		var me := multiplayer.get_unique_id()
		var weapon_name := WeaponDB.get_def(weapon).display_name if weapon >= 0 else ""
		hud.add_kill(killer_name, victim.player_name, weapon_name, head, killer_id == me or victim_id == me)


@rpc("authority", "reliable")
func _sync_scores(scores: Dictionary) -> void:
	Game.scores = scores.duplicate(true)
	_apply_match_state()


@rpc("authority", "reliable")
func _sync_match(state: int, time_left: float, intermission_left: float, winners: Array) -> void:
	var was_ended := Game.state == Game.State.ENDED
	Game.time_left = time_left
	Game.intermission_left = intermission_left
	Game.winners = winners
	Game.set_state(state as Game.State)
	if state == Game.State.PLAYING and was_ended:
		Audio.play("match_start")
		if hud:
			hud.clear_feed()
	elif state == Game.State.ENDED and not was_ended:
		Audio.play("match_end")
	if Game.net_log and not multiplayer.is_server():
		print("[CLIENT %d] match state=%d time_left=%.0f winners=%s" % [multiplayer.get_unique_id(), state, time_left, str(winners)])
	_apply_match_state()


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
			(players[state[0]] as Player).push_snapshot(state, tick)


func _on_disconnected() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(Game.MENU_SCENE)
