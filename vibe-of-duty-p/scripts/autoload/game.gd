extends Node
## Match state (Free-for-All): scores, timer, winner. The server owns it; clients receive it through NetWorld RPCs.

enum State { MENU, LOBBY, PLAYING, ENDED }

signal state_changed(new_state: State)
signal score_changed(peer_id: int)

const MENU_SCENE := "res://prefabs/ui/main_menu.tscn"
const MAPS_DIR := "res://prefabs/levels"
const DEFAULT_MAP := "res://prefabs/levels/train.tscn"
const NOT_MAPS: Array[String] = ["block"]  # scenes in MAPS_DIR that are building blocks, not maps (and any *_shell)
## Training maps (main menu -> Тренировка), in menu order. Not offered when creating a game; played alone on a
## local-only server (Net.host_training).
const TRAINING_MAPS: Array[String] = ["range", "course", "test_level"]
## Developer test maps: never offered in the menus, only reachable with --map= (dedicated server) or --training=.
## arena: a small walled box with nothing between the spawns, for automated netcode / kill cam / combat tests.
## ttk: the TTK balance test (--bot-ttk): targets at 10 / 20 / 40 / 80 m and dodgers running round the shooter there.
const TEST_MAPS: Array[String] = ["arena", "ttk"]
const TRAINING_INFO := {
	"range": "Мишени на дистанциях от 5 до 75 м и бегущая мишень",
	"course": "Площадка по кругу: стены, поручни, туннели, ямы, склоны, брёвна, ступени. На каждом снаряде несколько вариантов рядом — что получается, а что уже нет",
	"test_level": "Укрытия, уступы и склоны: проверка движения и залезания",
}
const SCORE_LIMIT := 20
const MATCH_TIME := 600.0  # seconds
const INTERMISSION_TIME := 10.0  # seconds between the end of a match and the next one

# Launch arguments (pass after "--"): --server (dedicated, no local player), --port=N,
# --join=IP (skip the menu), --training=map (skip the menu, train on that map), --name=Name, --map=file_name (map of a dedicated server, e.g. --map=train),
# --bot (scripted input for tests), --netlog (periodic net debug prints),
# --lag=MS and --perturb (network simulation for tests), --score-limit=N, --match-time=S, --intermission=S (match rules),
# --summary=S (after S s print one [SUMMARY] line with this machine's results, then quit: compact output for tests),
# --random-weapons (the FFA random weapon mode on a dedicated server), --stats (record MatchStats).
var dedicated := false
var bot_mode := false
var net_log := false
var auto_join := ""
var auto_training := ""   # --training=map: skip the menu, start that training map (e.g. --training=range)
var bot_vault := false     # --bot-vault: bots run back and forth over the test ledges (vault test)
var test_spawn := Vector3.INF  # set by --bot-vault / --test-spawn=x,y,z: everybody spawns here
var test_build: Array = []     # --build=part,part,...: the build bots play (PartDB ids, SLOTS order); native without it
var bot_aim := false       # --bot-aim: bots strafe and shoot at the nearest enemy
var bot_course := false    # --bot-course: bots run the obstacle course (course test)
var bot_targets := false   # --bot-targets: bots shoot the training targets in turn (training range test)
var bot_ttk := ""          # --bot-ttk=NODE: --bot-targets shoot only that target's body and time each kill (balance test)
var bot_react := 0.0       # --bot-react=S: --bot-ttk aims where the target was this long ago (a human's reaction)
var bot_hip := false       # --bot-hip: --bot-ttk shoots from the hip
var bot_strafe := false    # --bot-strafe: --bot-ttk strafes left and right while shooting
var bot_recoil := 1.0      # --bot-recoil=X: share of the recoil kick the bots pull down (1: all, 0: none)
var bot_oink := false      # --bot-oink: bots also oink (F) whenever the cooldown allows (oink network test)
var bot_melee := false     # --bot-melee: bots run at the nearest enemy and punch (melee test)
var bot_statue := false    # --bot-statue: bots shoot the statue (PigStatue) now and then and strafe (statue test)
var bot_idle := ""         # --bot-idle / --bot-idle=crouch: bots stand still (crouched) - the train's tunnel test
var bot_climb := NAN       # --bot-climb=DEG: bots face this yaw, jump every 1.5 s and push on in the air (a hatch, a ledge step)
var lag_comp_enabled := true  # --no-lagcomp: server judges shots at live positions (for comparison tests)
var net_perturb := false  # --perturb: client injects fake prediction errors (reconciliation test)
var sim_loss := 0.0        # --loss=PERCENT: client drops this share of its command packets (packet-loss test)
var sim_lag_ms := 0       # --lag=MS: artificial one-way delay on cmds (client) and snapshots (server)
var summary_time := 0.0   # --summary=S: seconds after the level starts to print the [SUMMARY] line and quit (NetWorld)
var record_stats := false  # the server records MatchStats (host panel -> Тестирование; --stats)
## Test counters for the [SUMMARY] line (Game.count): laps, target_hits, oinks_heard, kill_cams, bags_dropped, bags_taken,
## statue_shots, statue_hits, statue_kills.
var stats := {}
var launch_port := Net.DEFAULT_PORT
var map_scene := DEFAULT_MAP  # the map being played: chosen by the host, sent to clients by Net
var training := false         # playing a training map alone (no match clock or score on the HUD)
## Game mode "FFA random weapon" (host panel): every life gets a random weapon and cards instead of the
## player's build (RandomWeapons). Chosen by the host, sent to clients by Net.
var random_weapons := false
var score_limit := SCORE_LIMIT
var match_time := MATCH_TIME
var intermission_time := INTERMISSION_TIME
var state: State = State.MENU
var time_left := MATCH_TIME       # seconds left in the running match
var intermission_left := 0.0      # seconds until the next match starts (while ENDED)
var winners: Array = []           # peer ids of the winners of the last match
var scores: Dictionary = {}  # peer_id -> {"kills": int, "deaths": int}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--server":
			dedicated = true
		elif arg == "--bot":
			bot_mode = true
		elif arg == "--netlog":
			net_log = true
		elif arg == "--bot-course":
			bot_mode = true
			bot_course = true
		elif arg == "--bot-targets":
			bot_mode = true
			bot_targets = true
		elif arg == "--bot-oink":
			bot_mode = true
			bot_oink = true
		elif arg == "--bot-idle" or arg == "--bot-idle=crouch":
			bot_mode = true
			bot_idle = "crouch" if arg.ends_with("crouch") else "stand"
		elif arg.begins_with("--bot-climb="):
			bot_mode = true
			bot_climb = deg_to_rad(arg.get_slice("=", 1).to_float())
		elif arg == "--bot-melee":
			bot_mode = true
			bot_melee = true
		elif arg == "--bot-statue":
			bot_mode = true
			bot_statue = true
		elif arg == "--bot-aim":
			bot_mode = true
			bot_aim = true
		elif arg == "--bot-vault":
			bot_mode = true
			bot_vault = true
			test_spawn = Vector3(23.0, 0.05, -0.5)
		elif arg.begins_with("--test-spawn="):  # everybody spawns here (tests: walk a bot along a map's edges)
			var xyz := arg.trim_prefix("--test-spawn=").split(",")
			test_spawn = Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
		elif arg == "--random-weapons":
			random_weapons = true
		elif arg == "--stats":
			record_stats = true
		elif arg == "--no-lagcomp":
			lag_comp_enabled = false
		elif arg == "--perturb":
			net_perturb = true
		elif arg.begins_with("--loss="):
			sim_loss = clampf(float(arg.trim_prefix("--loss=")), 0.0, 90.0)
		elif arg.begins_with("--lag="):
			sim_lag_ms = int(arg.trim_prefix("--lag="))
		elif arg.begins_with("--score-limit="):
			score_limit = maxi(1, int(arg.trim_prefix("--score-limit=")))
		elif arg.begins_with("--match-time="):
			match_time = maxf(1.0, float(arg.trim_prefix("--match-time=")))
		elif arg.begins_with("--build="):
			test_build = Array(arg.trim_prefix("--build=").split(","))
		elif arg.begins_with("--bot-ttk="):
			bot_mode = true
			bot_targets = true
			bot_ttk = arg.trim_prefix("--bot-ttk=")
		elif arg.begins_with("--bot-react="):
			bot_react = maxf(float(arg.trim_prefix("--bot-react=")), 0.0)
		elif arg == "--bot-hip":
			bot_hip = true
		elif arg == "--bot-strafe":
			bot_strafe = true
		elif arg.begins_with("--bot-recoil="):
			bot_recoil = clampf(float(arg.trim_prefix("--bot-recoil=")), 0.0, 1.0)
		elif arg.begins_with("--summary="):
			summary_time = maxf(1.0, float(arg.trim_prefix("--summary=")))
		elif arg.begins_with("--intermission="):
			intermission_time = maxf(0.5, float(arg.trim_prefix("--intermission=")))
		elif arg.begins_with("--training="):
			auto_training = arg.trim_prefix("--training=")
		elif arg.begins_with("--join="):
			auto_join = arg.trim_prefix("--join=")
		elif arg.begins_with("--port="):
			launch_port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--name="):
			Settings.player_name = arg.trim_prefix("--name=")
		elif arg.begins_with("--map="):
			var path := MAPS_DIR.path_join(arg.trim_prefix("--map=") + ".tscn")
			if is_map(path):
				map_scene = path
			else:
				push_error("Unknown map %s; maps: %s" % [path, ", ".join(list_maps())])
	if dedicated:
		var err := Net.host(launch_port)
		if err != OK:
			push_error("Dedicated server failed to start: %s" % error_string(err))
			get_tree().quit(1)
			return
		print("Dedicated server listening on port %d" % launch_port)
		print("Map: %s" % map_scene)
		get_tree().change_scene_to_file.call_deferred(map_scene)


## The maps to play matches on: the scenes in MAPS_DIR except the building blocks and the training maps. Dropping a
## new level scene there adds a map. `with_training` includes the training and test maps too.
static func list_maps(with_training := false) -> Array[String]:
	var maps: Array[String] = []
	for file in DirAccess.get_files_at(MAPS_DIR):
		file = file.trim_suffix(".remap")  # exported builds list "x.tscn.remap"
		var base := file.get_basename()
		if file.get_extension() == "tscn" and not NOT_MAPS.has(base) and not base.ends_with("_shell") and \
				(with_training or not (TRAINING_MAPS.has(base) or TEST_MAPS.has(base))):
			maps.append(MAPS_DIR.path_join(file))
	maps.sort()
	return maps


## The training maps, in menu order.
static func list_training_maps() -> Array[String]:
	var maps: Array[String] = []
	for base in TRAINING_MAPS:
		var path := MAPS_DIR.path_join(base + ".tscn")
		if list_maps(true).has(path):
			maps.append(path)
	return maps


## Started by a test command line (bots, a dedicated server, --join / --training): nothing is saved to the player's
## profile then (Settings.save_settings).
func is_test_launch() -> bool:
	return bot_mode or dedicated or auto_join != "" or auto_training != "" or summary_time > 0.0


## Adds to a test counter (stats), printed by --summary.
func count(key: String, amount := 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


static func is_map(path: String) -> bool:
	return list_maps(true).has(path)


## "res://prefabs/levels/train.tscn" -> "Поезд" (a map without a Russian name shows its file name).
const MAP_NAMES := {"train": "Поезд", "plane": "Самолёт", "tower": "Небоскрёб", "killhouse": "Киллхаус", "chernobyl": "Чернобыль", "elysium": "Элизиум", "test_level": "Полигон", "range": "Стрельбище", "course": "Полоса препятствий"}

static func map_name(path: String) -> String:
	var base := path.get_file().get_basename()
	return MAP_NAMES.get(base, base.capitalize())


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


## Score: +1 per kill, −1 per any death (suicides included).
func score_of(entry: Dictionary) -> int:
	return entry["kills"] - entry["deaths"]


## K/D ratio; with no deaths it is just the kill count.
func kd_of(entry: Dictionary) -> float:
	return float(entry["kills"]) / maxi(entry["deaths"], 1)


## True between matches (the scoreboard is shown and nobody can move or shoot).
func is_frozen() -> bool:
	return state == State.ENDED


## Starts a fresh match: clears scores and the clock.
func reset_match() -> void:
	scores.clear()
	winners = []
	time_left = match_time
	intermission_left = 0.0
	set_state(State.PLAYING)


## Ends the running match and picks the winners (most points; ties broken by more kills, then shared).
func end_match() -> void:
	winners = leaders()
	intermission_left = intermission_time
	set_state(State.ENDED)


## Ranking order: points, then kills. Equal points and kills mean equal deaths too — a shared place.
func ranks_above(a: Dictionary, b: Dictionary) -> bool:
	var pa := score_of(a)
	var pb := score_of(b)
	return pa > pb or (pa == pb and a["kills"] > b["kills"])


func leaders() -> Array:
	var result: Array = []
	for id in scores:
		if result.is_empty() or ranks_above(scores[id], scores[result[0]]):
			result = [id]
		elif not ranks_above(scores[result[0]], scores[id]):
			result.append(id)
	return result


func top_kills() -> int:
	var best := 0
	for id in scores:
		best = maxi(best, scores[id]["kills"])
	return best
