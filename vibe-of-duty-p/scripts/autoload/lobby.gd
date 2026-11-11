extends Node
## The lobby between matches (Docs/DESIGN.md, «Лобби»). The server owns it; clients get its state through _sync.
##
## WAITING: a host just created the game - the map chosen in HostPanel, everyone waits until the host presses Start.
## VOTING: after every match (NetWorld, at the end of the intermission) - VOTE_MAPS random maps and "random" on the
## ballot, VOTE_TIME s to vote, then the most voted map is played (a tie: one of the tied at random). The host may
## start it earlier; a dedicated server just waits for the clock.
## In either phase the host may switch the game mode (Game.mode()) and pick the map itself: in WAITING that is
## the map, in VOTING it overrides the ballot (host_map; "" = the vote decides).
## Team mode (Game.teams): the teams are made here (teams) - everybody in the roster is dealt out as NetWorld would
## (join_team), and the host may move anyone to the other team (server_move; e.g. the humans against the bots): a bot
## then goes the other way to keep the teams even. The match plays these teams (NetWorld.server_join_team); they stay
## for the next lobby.
## Every peer shows the lobby scene (LobbyMenu) while a phase is on; Start sends everybody to the map, where NetWorld
## takes over as on a normal join. Automated tests (bots, --summary) and training skip the lobby: the next match starts
## in place, as before (enabled()).

enum Phase { NONE, WAITING, VOTING }

## Scenes change deferred: the vote opens inside NetWorld's physics step, which must not lose its level halfway.
const SCENE := "res://prefabs/ui/lobby.tscn"
const VOTE_TIME := 45.0   # s in the lobby after a match (vote, builds)
const VOTE_MAPS := 2      # random maps on the ballot, plus RANDOM
const RANDOM := "random"  # the ballot's "any map" choice

signal changed  # phase, roster, ballot or votes changed (LobbyMenu rebuilds)

var phase := Phase.NONE
var roster := {}                 # peer_id -> name, the players in the lobby (server-made, synced)
var options: Array[String] = []  # VOTING: map paths on the ballot, the last one RANDOM
var votes := {}                  # VOTING: peer_id -> index in options
var time_left := 0.0             # VOTING: seconds until the vote ends (clients count down locally between syncs)
var host_map := ""               # VOTING: the map the host picked over the vote ("" = the vote decides)
var teams := {}                  # team mode: peer_id -> 0 / 1 (server-made, synced; kept from lobby to lobby)
var bots: Array = []             # peer ids of the roster's bots (BotLauncher's; synced, for the list)
var _sync_timer := 0.0


func _ready() -> void:
	Net.peer_left.connect(_on_peer_left)
	Net.disconnected.connect(_reset)


## Whether matches go through the lobby: not on training maps, and not in automated tests (bots, --summary), which
## expect the next match to start in place.
func enabled() -> bool:
	return not Game.training and not Game.bot_mode and Game.summary_time <= 0.0


func is_host() -> bool:
	return Net.is_server() and not Game.dedicated


func _process(delta: float) -> void:
	if phase != Phase.VOTING:
		return
	time_left = maxf(time_left - delta, 0.0)
	if not Net.is_server():
		return
	if time_left <= 0.0:
		server_start()
		return
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_broadcast()  # once a second: the clock


# --- Server --------------------------------------------------------------------------------------

## Host: the game was just created - wait for the host's Start on the map chosen in HostPanel (Game.map_scene).
func server_open_waiting() -> void:
	teams.clear()
	_open(Phase.WAITING, {})
	get_tree().change_scene_to_file.call_deferred(SCENE)


## Server: a match is over - everybody back to the lobby to vote for the next map. `names`: peer_id -> name of those
## playing (kept, so nobody vanishes from the list until their lobby loads).
func server_open_vote(names: Dictionary) -> void:
	_open(Phase.VOTING, names)
	options = _ballot()
	time_left = VOTE_TIME
	if Game.net_log:
		print("[LOBBY] vote %s" % str(options))
	_go_lobby.rpc()
	get_tree().change_scene_to_file.call_deferred(SCENE)
	_broadcast()


func _open(new_phase: Phase, names: Dictionary) -> void:
	phase = new_phase
	roster = names.duplicate()
	options.clear()
	votes.clear()
	host_map = ""
	if not Game.dedicated and not roster.has(1):
		roster[1] = NetWorld.unique_name(Settings.player_name, roster.values())
	Game.set_state(Game.State.LOBBY)
	changed.emit()


## VOTE_MAPS random maps (not the one just played, when there are enough), then RANDOM.
func _ballot() -> Array[String]:
	var maps := Game.list_maps()
	if maps.size() > VOTE_MAPS:
		maps.erase(Game.map_scene)
	maps.shuffle()
	var ballot: Array[String] = maps.slice(0, VOTE_MAPS)
	ballot.append(RANDOM)
	return ballot


## Server (the host's Start, or the vote's clock): everybody to the map.
func server_start() -> void:
	if not Net.is_server() or phase == Phase.NONE:
		return
	if phase == Phase.VOTING:
		Game.map_scene = host_map if host_map != "" else _vote_result()
	phase = Phase.NONE
	if Game.net_log:
		print("[LOBBY] start %s teams=%s" % [Game.map_scene, str(teams) if Game.teams else "-"])
	_go_map.rpc(Game.map_scene)
	get_tree().change_scene_to_file.call_deferred(Game.map_scene)


## The most voted choice (a tie, or no votes at all: one of the tied at random); RANDOM is any map not on the ballot.
func _vote_result() -> String:
	var counts := vote_counts()
	var best: int = counts.max()
	var top: Array[int] = []
	for i in counts.size():
		if counts[i] == best:
			top.append(i)
	var choice: String = options[top.pick_random()]
	if choice != RANDOM:
		return choice
	var rest := Game.list_maps().filter(func(path: String) -> bool: return not options.has(path))
	if rest.is_empty():
		rest = Game.list_maps()
	return rest.pick_random()


## Votes per ballot entry.
func vote_counts() -> Array[int]:
	var counts: Array[int] = []
	counts.resize(options.size())
	counts.fill(0)
	for id in votes:
		if votes[id] >= 0 and votes[id] < counts.size():
			counts[votes[id]] += 1
	return counts


func _broadcast() -> void:
	_sync_timer = 1.0
	_deal()
	bots = roster.keys().filter(Net.is_bot)
	_sync.rpc(phase, roster, options, votes, time_left, Game.map_scene, host_map, Game.mode(), Game.hardcore,
			Game.score_limit, teams, bots)
	changed.emit()


## Team mode: the team a newcomer to the roster takes, by NetWorld's rule - a human the team with fewer humans, a bot
## the smaller team; a tie - the smaller team, then the one with fewer bots, then any.
func join_team(bot: bool) -> int:
	var size := team_sizes()
	var humans := [0, 0]
	for id in roster:
		if teams.has(id) and not Net.is_bot(id):
			humans[teams[id]] += 1
	if not bot and humans[0] != humans[1]:
		return 0 if humans[0] < humans[1] else 1
	if size[0] != size[1]:
		return 0 if size[0] < size[1] else 1
	if humans[0] != humans[1]:
		return 0 if humans[0] > humans[1] else 1
	return randi() % 2


## Players of the roster in each team.
func team_sizes() -> Array[int]:
	var size: Array[int] = [0, 0]
	for id in roster:
		if teams.has(id):
			size[teams[id]] += 1
	return size


## Server, team mode: everybody in the roster has a team (the humans are dealt first), nobody else does.
func _deal() -> void:
	if not Game.teams:
		return
	for id in teams.keys():
		if not roster.has(id):
			teams.erase(id)
	var ids := roster.keys()
	ids.sort()
	for bot: bool in [false, true]:
		for id: int in ids:
			if not teams.has(id) and Net.is_bot(id) == bot:
				teams[id] = join_team(bot)
	_even_out(0)


## Server: bots go from the bigger team to the smaller one until the teams are even (or the bigger has no bot to
## give). `keep`: a peer left where it is - the one the host has just moved.
func _even_out(keep: int) -> void:
	for step in Net.MAX_PLAYERS:
		var size := team_sizes()
		if absi(size[0] - size[1]) < 2:
			return
		var big := 0 if size[0] > size[1] else 1
		var moved := false
		for id: int in roster:
			if id != keep and teams.get(id, -1) == big and Net.is_bot(id):
				teams[id] = 1 - big
				moved = true
				break
		if not moved:
			return


## Host, team mode: player `id` to the other team; a bot takes their place there, if the teams came out uneven.
func server_move(id: int) -> void:
	if not is_host() or phase == Phase.NONE or not Game.teams or not teams.has(id):
		return
	teams[id] = 1 - int(teams[id])
	_even_out(id)
	_broadcast()


func _on_peer_left(id: int) -> void:
	teams.erase(id)
	if not Net.is_server() or phase == Phase.NONE:
		return
	roster.erase(id)
	votes.erase(id)
	_broadcast()


## Client -> server: this client's lobby has loaded.
@rpc("any_peer", "reliable")
func _hello(player_name: String) -> void:
	if not Net.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if phase == Phase.NONE:  # the lobby ended while it was loading: _go_map (server_start) is already on its way there
		return
	if not roster.has(id):
		roster[id] = NetWorld.unique_name(player_name, roster.values())
	_broadcast()


## Client -> server: a vote (or a changed vote) for ballot entry `index`.
@rpc("any_peer", "reliable")
func _request_vote(index: int) -> void:
	if Net.is_server():
		_server_vote(multiplayer.get_remote_sender_id(), index)


func _server_vote(id: int, index: int) -> void:
	if phase != Phase.VOTING or index < 0 or index >= options.size() or not roster.has(id):
		return
	votes[id] = index
	_broadcast()


## Host: the next map. WAITING: `path` is the map; VOTING: it overrides the vote ("" gives the choice back to the vote).
func server_set_map(path: String) -> void:
	if not is_host() or phase == Phase.NONE or (path != "" and not Game.list_maps().has(path)):
		return
	if phase == Phase.WAITING:
		if path != "":
			Game.map_scene = path
	else:
		host_map = path
	_broadcast()


## Host: the game mode of the next match (Game.Mode). The team mode has its own kill limit (the host's settings) and
## its bots: as many as fill the teams (BotLauncher).
func server_set_mode(mode: int) -> void:
	if not is_host() or phase == Phase.NONE:
		return
	Game.set_mode(mode)
	Game.score_limit = Settings.host_team_score_limit if Game.teams else Settings.host_score_limit
	BotLauncher.sync()
	_broadcast()


## Host: the "Хардкор" checkbox of the next match (Game.hardcore).
func server_set_hardcore(on: bool) -> void:
	if not is_host() or phase == Phase.NONE:
		return
	Game.hardcore = on
	_broadcast()


# --- Every peer ----------------------------------------------------------------------------------

## LobbyMenu: the lobby scene has loaded here.
func entered() -> void:
	if not Net.is_server():
		_hello.rpc_id(1, Settings.player_name)


## This machine's vote.
func vote(index: int) -> void:
	if Net.is_server():
		_server_vote(multiplayer.get_unique_id(), index)
	else:
		_request_vote.rpc_id(1, index)


func my_vote() -> int:
	return votes.get(multiplayer.get_unique_id(), -1)


@rpc("authority", "reliable")
func _go_lobby() -> void:
	phase = Phase.VOTING  # the real state follows in _sync
	Game.set_state(Game.State.LOBBY)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file.call_deferred(SCENE)


@rpc("authority", "reliable")
func _go_map(path: String) -> void:
	if not Game.is_map(path):
		push_error("Server plays a map this build does not have: %s" % path)
		Net.leave()
		return
	phase = Phase.NONE
	Game.map_scene = path
	if Game.net_log:
		print("[LOBBY %d] to map %s" % [multiplayer.get_unique_id(), path])
	get_tree().change_scene_to_file.call_deferred(path)


@rpc("authority", "reliable")
func _sync(new_phase: int, new_roster: Dictionary, new_options: Array, new_votes: Dictionary, new_time_left: float,
		map: String, new_host_map: String, mode: int, hardcore: bool, score_limit: int, new_teams: Dictionary,
		new_bots: Array) -> void:
	if phase == Phase.NONE:  # already on the way to the map
		return
	phase = new_phase as Phase
	roster = new_roster
	options.assign(new_options)
	votes = new_votes
	time_left = new_time_left
	host_map = new_host_map if Game.is_map(new_host_map) else ""
	Game.set_mode(mode)
	Game.hardcore = hardcore
	Game.score_limit = maxi(score_limit, 1)
	teams = new_teams
	bots = new_bots
	if Game.is_map(map):
		Game.map_scene = map
	changed.emit()


func _reset() -> void:
	phase = Phase.NONE
	teams.clear()
	bots.clear()
	roster.clear()
	options.clear()
	votes.clear()
	host_map = ""
