extends Node
## Match state (Free-for-All). Stub: server-authoritative logic is added in later stages.

enum State { MENU, LOBBY, PLAYING, ENDED }

signal state_changed(new_state: State)
signal score_changed(peer_id: int)

const MENU_SCENE := "res://prefabs/ui/main_menu.tscn"
const LEVEL_SCENE := "res://prefabs/levels/test_level.tscn"
const SCORE_LIMIT := 20
const MATCH_TIME := 600.0  # seconds

# Launch arguments (pass after "--"): --server (dedicated, no local player), --port=N,
# --join=IP (skip the menu), --name=Name, --bot (scripted input for tests), --netlog (periodic net debug prints),
# --lag=MS and --perturb (network simulation for tests).
var dedicated := false
var bot_mode := false
var net_log := false
var auto_join := ""
var net_perturb := false  # --perturb: client injects fake prediction errors (reconciliation test)
var sim_lag_ms := 0       # --lag=MS: artificial one-way delay on cmds (client) and snapshots (server)
var launch_port := Net.DEFAULT_PORT
var state: State = State.MENU
var scores: Dictionary = {}  # peer_id -> {"kills": int, "deaths": int}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--server":
			dedicated = true
		elif arg == "--bot":
			bot_mode = true
		elif arg == "--netlog":
			net_log = true
		elif arg == "--perturb":
			net_perturb = true
		elif arg.begins_with("--lag="):
			sim_lag_ms = int(arg.trim_prefix("--lag="))
		elif arg.begins_with("--join="):
			auto_join = arg.trim_prefix("--join=")
		elif arg.begins_with("--port="):
			launch_port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--name="):
			Settings.player_name = arg.trim_prefix("--name=")
	if dedicated:
		var err := Net.host(launch_port)
		if err != OK:
			push_error("Dedicated server failed to start: %s" % error_string(err))
			get_tree().quit(1)
			return
		print("Dedicated server listening on port %d" % launch_port)
		get_tree().change_scene_to_file.call_deferred(LEVEL_SCENE)


func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func reset_scores() -> void:
	scores.clear()


func ensure_player(peer_id: int) -> void:
	if not scores.has(peer_id):
		scores[peer_id] = {"kills": 0, "deaths": 0}


func add_kill(killer_id: int, victim_id: int) -> void:
	ensure_player(killer_id)
	ensure_player(victim_id)
	if killer_id != victim_id:
		scores[killer_id]["kills"] += 1
	scores[victim_id]["deaths"] += 1
	score_changed.emit(killer_id)
	score_changed.emit(victim_id)
