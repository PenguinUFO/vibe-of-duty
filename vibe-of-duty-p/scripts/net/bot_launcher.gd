class_name BotLauncher
## Bots for a hosted game (HostPanel "Боты", a dedicated server's --bots=N; Docs/BOTS.md): each bot is another copy
## of the game without a window that joins this server as a player - an archetype bot (--bot-style, --bot-skill),
## a random style and kit each, a random nickname. Started when the server opens, killed when it closes; a bot also
## quits by itself when it loses the server (Game._ready), so none outlives a crashed host.
##
## How many (want): the number the host asked for; in team mode (Game.teams) as many as fill both teams - every seat
## no human sits in. sync() brings the running bots to that number whenever the players or the mode change (Net,
## Lobby): a human joined - a bot leaves (one of the team the human is about to take), a human left - a bot comes.
## A bot proves itself to the server with the key it was started with (--bot-key, Net._identify).

const MAX_LAUNCHES := 64     # bots started per game: a bot that keeps dying is not started for ever
const KILL_AFTER_MS := 3000  # a dropped bot quits by itself (it lost the server); still running this long after - killed
const MAX_FPS := 60          # a bot's frames per second: headless, uncapped, it spun ~50 % of a core idle (60: ~30 %);
                            # its moves are made in the physics tick, which this does not touch

static var _active := false  # a game with bots is on (start ... stop)
static var _count := 0       # the bots the host asked for (not the team mode's fill)
static var _skill := "average"
static var _secret := ""
static var _bots := {}       # key -> {"pid": int, "peer": int (0: not joined yet), "name": String}
static var _dying := {}      # pid -> ms it was dropped at
static var _styles: Array = []
static var _serial := 0
static var _launched := 0


## The server opened: `count` bots of `skill` (BotProfiles.SKILLS) from now on, in team mode as many as fill the teams.
static func start(count: int, skill: String) -> void:
	stop()
	_active = true
	_count = clampi(count, 0, Net.MAX_PLAYERS - 1)
	_skill = skill
	_secret = "%08x%08x" % [randi(), randi()]
	_styles = BotProfiles.STYLES.keys()
	_styles.shuffle()
	_launched = 0
	if not Net.disconnected.is_connected(stop):
		Net.disconnected.connect(stop)
	sync()


## How many bots there should be now.
static func want() -> int:
	if Game.teams:
		return maxi(Net.MAX_PLAYERS - Net.humans(), 0)
	return _count


## Starts or drops bots until there are want() of them.
static func sync() -> void:
	if not _active or not Net.is_server():
		return
	var now := Time.get_ticks_msec()
	for pid: int in _dying.keys():
		if not OS.is_process_running(pid):
			_dying.erase(pid)
		elif now - int(_dying[pid]) > KILL_AFTER_MS:
			OS.kill(pid)
			_dying.erase(pid)
	for key: String in _bots.keys():
		if not OS.is_process_running(_bots[key]["pid"]):  # died on its own
			_bots.erase(key)
	var target := want()
	while _bots.size() > target:
		_remove(_pick_extra())
	while _bots.size() < target and _launched < MAX_LAUNCHES:
		_launch()


## Net: a peer says it is the bot started with `key`. True if it is one of ours that has not joined yet.
static func claim(key: String, peer: int) -> bool:
	if key == "" or not _bots.has(key) or _bots[key]["peer"] != 0:
		return false
	_bots[key]["peer"] = peer
	return true


## Net: a peer left - if it was a bot, it is gone from the list (its process quits by itself).
static func peer_left(peer: int) -> void:
	for key: String in _bots.keys():
		if _bots[key]["peer"] == peer:
			_dying[_bots[key]["pid"]] = Time.get_ticks_msec()
			_bots.erase(key)


## Kills the bots started here (the server closed).
static func stop() -> void:
	for key: String in _bots:
		_dying[_bots[key]["pid"]] = 0
	for pid: int in _dying:
		if OS.is_process_running(pid):
			OS.kill(pid)
	_bots.clear()
	_dying.clear()
	_active = false


## The bot to drop: one that has not joined yet; in team mode one of the team the next human takes
## (NetWorld.server_join_team, in the lobby Lobby.join_team), so the teams stay even; else any.
static func _pick_extra() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var world: NetWorld = null
	if tree.current_scene != null:
		world = tree.current_scene.get_node_or_null("World") as NetWorld
	var team := -1
	if world != null:
		team = world.server_join_team(false)
	elif Game.teams and Lobby.phase != Lobby.Phase.NONE:
		team = Lobby.join_team(false)
	var pick := ""
	for key: String in _bots:
		var peer: int = _bots[key]["peer"]
		if peer == 0:
			return key
		var its_team := -1
		if world != null and world.players.has(peer):
			its_team = (world.players[peer] as Player).team
		elif world == null:
			its_team = Lobby.teams.get(peer, -1)
		if pick == "" or (team >= 0 and its_team == team):
			pick = key
	return pick


static func _remove(key: String) -> void:
	var bot: Dictionary = _bots[key]
	_bots.erase(key)
	if bot["peer"] != 0:
		_dying[bot["pid"]] = Time.get_ticks_msec()
		Net.drop(bot["peer"])  # it quits on losing the server; killed outright, its body would stand until the timeout
	elif OS.is_process_running(bot["pid"]):
		OS.kill(bot["pid"])


static func _launch() -> void:
	_launched += 1
	_serial += 1
	var kits := PartDB.for_slot("kit")
	var names: Array = [Settings.player_name]
	for other: String in _bots:
		names.append(_bots[other]["name"])
	var bot_name := Settings.pick_nickname()
	for attempt in 10:  # no two alike, nor the host's
		if not names.has(bot_name):
			break
		bot_name = Settings.pick_nickname()
	var key := "%s-%d" % [_secret, _serial]
	var args := PackedStringArray()
	if OS.has_feature("editor"):  # run from the editor: the executable is the editor, it needs the project
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--headless", "--max-fps", str(MAX_FPS), "--", "--join=127.0.0.1", "--port=%d" % Game.launch_port,
			"--bot-style=%s" % _styles[_serial % _styles.size()], "--bot-skill=%s" % _skill,
			"--build=%s" % kits.pick_random().id, "--name=%s" % bot_name, "--bot-key=%s" % key])
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid > 0:
		_bots[key] = {"pid": pid, "peer": 0, "name": bot_name}
	else:
		push_error("Could not start a bot process")
