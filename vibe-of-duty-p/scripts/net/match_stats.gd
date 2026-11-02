class_name MatchStats
extends RefCounted
## Server: records how live players fight, for balance (TTK, which weapon and cards win) - one file per server run,
## user://stats/<date>_<time>.jsonl, one JSON object per line ("e" = event). Format and the report - Docs/STATS.md;
## the report: tools/stats_report.py. Owned by NetWorld; only when the host asks
## (Game.record_stats: host panel -> Тестирование, --stats), never on training maps.
##
## Engagement: the damage a player takes from the moment they were last at full health. Its start is where the TTK
## of a kill is counted from (per attacker: their first hit on the victim in it).

const DIR := "user://stats"
const BURST_GAP := 1.0  # s without a shot: the next shot starts a new burst (the "opened fire" moment of a TTK)
const POS_EVERY := 2.5  # s between the "pos" lines (where everybody alive is: heat maps)
const CALM_GAP := 5.0   # s after a hit (either way) or a spawn that still count as being in a fight

var _file: FileAccess
var _t0 := 0           # ms (ticks clock) when the file was opened
var _match := 0        # number of the match in this file, from 1
var _match_start := 0  # ms
# peer_id -> {player, p (name), start, variant, kills, shots, hits, head, dmg_out, dmg_in, and the player's counters at
# the spawn: healed0, bags0, dry0; fight (ms of the last hit either way, or the spawn), contact (ms of the first hit,
# -1: none yet), calm (ms more than CALM_GAP away from any hit)}
var _lives := {}
var _engaged := {}     # victim peer_id -> {attacker peer_id -> {first, hits, head, dmg, angle}}
var _heal_at := {}     # victim peer_id -> their healed_total when the engagement began
var _bursts := {}      # peer_id -> {start, last, shots}
var _died_at := {}     # peer_id -> ms of their last death
var _last_pos := -1000000  # ms of the last "pos" line


## Opens a new file and writes the session line: build version, the weapons.cfg in play (its hash: balance changes
## between sessions), map and rules.
func open() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR.path_join(Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_") + ".jsonl")
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("MatchStats: cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	_t0 = Time.get_ticks_msec()
	print("Match stats: %s" % ProjectSettings.globalize_path(path))
	_write({"e": "session", "date": Time.get_datetime_string_from_system(),
			"version": str(ProjectSettings.get_setting("application/config/version", "")),
			"weapons_md5": WeaponDB.config_text.md5_text(), "map": Game.map_scene.get_file().get_basename(),
			"random_weapons": Game.random_weapons, "score_limit": Game.score_limit, "match_time": Game.match_time,
			"dedicated": Game.dedicated})


func close() -> void:
	if _file != null:
		for id in _lives.keys():
			_end_life(id, "quit")
		_file.close()
		_file = null


func match_started(players: Dictionary) -> void:
	_match += 1
	_match_start = _now()
	_engaged.clear()
	_write({"e": "match_start", "m": _match, "players": players.size()})


## `players`: peer_id -> Player; scores and winners from Game.
func match_ended(players: Dictionary, reason: String) -> void:
	var table: Array = []
	for id in Game.scores:
		var entry: Dictionary = Game.scores[id]
		var player: Player = players.get(id)
		table.append({"p": player.player_name if player != null else str(id), "kills": entry["kills"],
				"deaths": entry["deaths"], "win": Game.winners.has(id)})
	_write({"e": "match_end", "m": _match, "reason": reason, "dur": (_now() - _match_start) / 1000.0,
			"scores": table})
	for id in _lives.keys():
		_end_life(id, "match")


## A player joined the server (their first spawn follows).
func joined(player: Player) -> void:
	_write({"e": "join", "m": _match, "p": player.player_name, "id": player.peer_id, "ping": _ping(player),
			"playing": Game.state == Game.State.PLAYING})


## A player left: how they were doing (their kills and deaths this match, place among everybody here), and how much
## of the match was left.
func left(player: Player) -> void:
	var id := player.peer_id
	var entry: Dictionary = Game.scores.get(id, {"kills": 0, "deaths": 0})
	var place := 1
	for other in Game.scores:
		place += 1 if int(Game.scores[other]["kills"]) > int(entry["kills"]) else 0
	_write({"e": "leave", "m": _match, "p": player.player_name, "id": id, "kills": entry["kills"],
			"deaths": entry["deaths"], "place": place, "players": Game.scores.size(),
			"playing": Game.state == Game.State.PLAYING, "time_left": snappedf(Game.time_left, 1.0),
			"alive": player.alive})
	_end_life(id, "leave")
	_engaged.erase(id)
	_heal_at.erase(id)
	_bursts.erase(id)
	_died_at.erase(id)


## The player picked another build (for their next life): what it was, and how long after their death (null: alive).
func build_changed(player: Player, was: Array) -> void:
	var died: int = _died_at.get(player.peer_id, -1)
	_write({"e": "build", "m": _match, "p": player.player_name, "w": PartDB.variant_name(player.wanted_build),
			"was": PartDB.variant_name(was), "alive": player.alive,
			"dead_for": (_now() - died) / 1000.0 if not player.alive and died >= 0 else null})


## Every server tick: every POS_EVERY s of a match, where everybody alive is.
func tick(players: Dictionary) -> void:
	var now := _now()
	if Game.state != Game.State.PLAYING or now - _last_pos < POS_EVERY * 1000.0:
		return
	_last_pos = now
	var at := {}
	for id in players:
		var player: Player = players[id]
		if player.alive:
			at[player.player_name] = _pos(player)
	if not at.is_empty():
		_write({"e": "pos", "m": _match, "at": at})


## A new life (first spawn, respawn, a new match): what it plays and where - `spot` from NetWorld._pick_spawn (the
## point, the nearest living player, how many of them see it). A life still running ends ("match").
func spawned(player: Player, spot: Dictionary) -> void:
	if _lives.has(player.peer_id):
		_end_life(player.peer_id, "match")
	_lives[player.peer_id] = {"player": player, "p": player.player_name, "start": _now(),
			"variant": PartDB.variant_name(player.build), "kills": 0, "shots": 0, "hits": 0, "head": 0, "dmg_out": 0,
			"dmg_in": 0, "healed0": player.healed_total, "bags0": player.bags_total, "dry0": player.dry_total,
			"fight": _now(), "contact": -1, "calm": 0}
	_engaged.erase(player.peer_id)
	_heal_at.erase(player.peer_id)
	# Damage they did in their last life stays on its victims, but as somebody else's (dmg_others): a kill in this
	# life times from this life's first hit.
	for by: Dictionary in _engaged.values():
		if by.has(player.peer_id):
			var old: Dictionary = by.get_or_add("%d:old" % player.peer_id, {"dmg": 0})
			old["dmg"] += int(by[player.peer_id]["dmg"])
			by.erase(player.peer_id)
	_bursts.erase(player.peer_id)
	_write({"e": "spawn", "m": _match, "p": player.player_name, "id": player.peer_id,
			"w": _lives[player.peer_id]["variant"], "build": player.build, "pt": spot["pt"], "pos": _pos(player),
			"near": snappedf(spot["near"], 0.1) if spot["near"] != INF else null, "seen": spot["seen"],
			"ping": _ping(player)})


func shot(shooter: Player, hits: Array) -> void:
	var now := _now()
	var burst: Dictionary = _bursts.get_or_add(shooter.peer_id, {"start": now, "last": -1e9, "shots": 0})
	if now - int(burst["last"]) > BURST_GAP * 1000.0:
		burst["start"] = now
		burst["shots"] = 0
	burst["last"] = now
	burst["shots"] += 1
	var life: Dictionary = _lives.get(shooter.peer_id, {})
	if not life.is_empty():
		life["shots"] += 1
		# Per shot, not per pellet: a shotgun blast that lands counts once (accuracy stays <= 100%).
		life["hits"] += 1 if not hits.is_empty() else 0
		life["head"] += 1 if hits.any(func(hit): return hit["zone"] == "head") else 0


## Damage the victim took (`hp_before` - their health now), with the state of both at that moment. The attacker's
## first hit in an engagement also notes where the victim was looking (did they see who shot them).
func damaged(attacker: Player, victim: Player, hp_before: int, head: bool, weapon: int) -> void:
	var now := _now()
	var amount := hp_before - victim.health
	if hp_before >= victim.max_health or not _engaged.has(victim.peer_id):
		_engaged[victim.peer_id] = {}  # was at full health: a new engagement
		_heal_at[victim.peer_id] = victim.healed_total
	var by: Dictionary = _engaged[victim.peer_id]
	if not by.has(attacker.peer_id):
		by[attacker.peer_id] = {"first": now, "hits": 0, "head": 0, "dmg": 0, "angle": _view_angle(victim, attacker)}
	var mine: Dictionary = by[attacker.peer_id]
	mine["hits"] += 1
	mine["head"] += 1 if head else 0
	mine["dmg"] += amount
	if _lives.has(attacker.peer_id):
		_lives[attacker.peer_id]["dmg_out"] += amount
		_fought(_lives[attacker.peer_id], now, true)
	if _lives.has(victim.peer_id):
		_lives[victim.peer_id]["dmg_in"] += amount
		_fought(_lives[victim.peer_id], now, true)
	_write({"e": "hit", "m": _match, "a": attacker.player_name, "v": victim.player_name,
			"aw": _variant(attacker), "vw": _variant(victim), "gun": _weapon_id(attacker, weapon), "dmg": amount,
			"hp": victim.health, "head": head, "dist": snappedf(_distance(attacker, victim), 0.1),
			"a_state": _state(attacker), "v_state": _state(victim), "ping": _ping(attacker),
			"rewind": roundi(attacker.judge_rewind_ms)})


## A death: TTK and how the fight went. weapon -1: the map killed them (`cause`: NetWorld._server_suicide).
func killed(killer: Player, victim: Player, weapon: int, head: bool, cause := "") -> void:
	var now := _now()
	_died_at[victim.peer_id] = now
	var line := {"e": "kill", "m": _match, "k": killer.player_name, "v": victim.player_name, "kw": _variant(killer),
			"vw": _variant(victim), "gun": _weapon_id(killer, weapon), "head": head,
			"v_life": (now - int(_lives.get(victim.peer_id, {}).get("start", now))) / 1000.0, "v_pos": _pos(victim),
			"v_ping": _ping(victim), "v_mag": victim.weapons.mags[victim.weapons.index]}
	if killer == victim:
		line["cause"] = cause if cause != "" else "self"
	else:
		var by: Dictionary = _engaged.get(victim.peer_id, {})
		var mine: Dictionary = by.get(killer.peer_id, {"first": now, "hits": 0, "head": 0, "dmg": 0})
		var others := 0
		for id in by:  # peer ids, and "<id>:old" for damage from an attacker's last life
			if str(id) != str(killer.peer_id):
				others += int(by[id]["dmg"])
		# Did the victim fight back: their damage to the killer in the killer's own engagement.
		var back: Dictionary = _engaged.get(killer.peer_id, {}).get(victim.peer_id, {})
		var burst: Dictionary = _bursts.get(killer.peer_id, {})
		var opened := mini(int(burst.get("start", mine["first"])), int(mine["first"]))
		var replied: bool = not back.is_empty()
		line.merge({"dist": snappedf(_distance(killer, victim), 0.1), "k_pos": _pos(killer),
				"ttk": (now - int(mine["first"])) / 1000.0,      # killer's first hit -> death
				"ttk_fire": (now - opened) / 1000.0,             # killer opened fire (burst) -> death
				"hits": mine["hits"], "head_hits": mine["head"], "shots": int(burst.get("shots", 0)),
				"dmg": mine["dmg"], "dmg_others": others, "v_dmg_to_k": int(back.get("dmg", 0)),
				"k_hp": killer.health, "k_max": killer.max_health,
				"k_life": (now - int(_lives.get(killer.peer_id, {}).get("start", now))) / 1000.0,
				"k_state": _state(killer), "v_state": _state(victim),
				"k_ping": _ping(killer), "rewind": roundi(killer.judge_rewind_ms),  # of the killing shot / punch
				"v_healed": victim.healed_total - int(_heal_at.get(victim.peer_id, victim.healed_total)),
				"v_angle": mine.get("angle"),  # where the victim looked at the killer's first hit
				"v_hit_first": replied and int(back["first"]) < int(mine["first"]),
				"v_reply": (now - int(back["first"])) / 1000.0 if replied else null})
		if _lives.has(killer.peer_id):
			_lives[killer.peer_id]["kills"] += 1
	_write(line)
	_engaged.erase(victim.peer_id)
	_heal_at.erase(victim.peer_id)
	_end_life(victim.peer_id, "death")


func _end_life(id: int, reason: String) -> void:
	if not _lives.has(id):
		return
	var life: Dictionary = _lives[id]
	_lives.erase(id)
	var now := _now()
	_fought(life, now, false)
	var line := {"e": "life", "m": _match, "p": life["p"], "w": life["variant"],
			"end": reason, "dur": (now - int(life["start"])) / 1000.0, "kills": life["kills"],
			"shots": life["shots"], "hits": life["hits"], "head": life["head"], "dmg_out": life["dmg_out"],
			"dmg_in": life["dmg_in"], "calm": int(life["calm"]) / 1000.0,
			"contact": (int(life["contact"]) - int(life["start"])) / 1000.0 if int(life["contact"]) >= 0 else null}
	var player: Player = life["player"] if is_instance_valid(life["player"]) else null
	if player != null:
		var weapons := player.weapons
		line.merge({"ping": _ping(player), "healed": player.healed_total - int(life["healed0"]),
				"bags": player.bags_total - int(life["bags0"]), "dry": player.dry_total - int(life["dry0"]),
				"mag": weapons.mags[weapons.index], "reserve": weapons.reserves[weapons.index]})
	_write(line)


## A hit in this life at `now` (`hit`), or its end: the quiet stretch since the last one, past CALM_GAP, is calm.
func _fought(life: Dictionary, now: int, hit: bool) -> void:
	life["calm"] += maxi(now - int(life["fight"]) - int(CALM_GAP * 1000.0), 0)
	if hit:
		life["fight"] = now
		if int(life["contact"]) < 0:
			life["contact"] = now


func _variant(player: Player) -> String:
	return _lives[player.peer_id]["variant"] if _lives.has(player.peer_id) else PartDB.variant_name(player.build)


static func _weapon_id(player: Player, weapon: int) -> String:
	if weapon == WeaponSim.MELEE:
		return "melee"
	if weapon == WeaponSim.GRENADE:
		return "grenade"
	if weapon < 0:
		return "self"
	return player.weapons.def_at(weapon).id


## Round trip to the player's machine, ms (ENet's running average); 0 for the host's own player, null if unknown.
static func _ping(p: Player) -> Variant:
	var mp := p.multiplayer
	if p.peer_id == mp.get_unique_id():
		return 0
	var enet := mp.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or not mp.get_peers().has(p.peer_id):
		return null
	return enet.get_peer(p.peer_id).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)


## Degrees between where `p` looks and the eyes of `other`: 0 - dead centre, past about half the FOV - off screen.
static func _view_angle(p: Player, other: Player) -> float:
	var state := p.hitbox_state()
	var look := LagComp.body_basis(state) * Basis(Vector3.RIGHT, state["pitch"]) * Vector3.FORWARD
	return snappedf(rad_to_deg(look.angle_to(other.eye_position() - p.eye_position())), 1.0)


## Feet position, to 0.1 m: [x, y, z].
static func _pos(p: Player) -> Array:
	var at := p.global_position  # float components: a snapped Vector3 is float32 again (-18.2000007629395)
	return [snappedf(at.x, 0.1), snappedf(at.y, 0.1), snappedf(at.z, 0.1)]


static func _distance(a: Player, b: Player) -> float:
	return a.global_position.distance_to(b.global_position)


## What a player was doing: horizontal speed (m/s), sights up, crouched, sliding, sprinting, in the air, reloading.
static func _state(p: Player) -> Dictionary:
	return {"speed": snappedf(Vector2(p.velocity.x, p.velocity.z).length(), 0.1), "ads": p.aiming,
			"crouch": p.is_crouched, "slide": p.is_sliding, "sprint": p.is_sprinting, "air": not p.is_on_floor(),
			"reload": p.weapons.is_reloading()}


func _now() -> int:
	return Time.get_ticks_msec() - _t0


func _write(data: Dictionary) -> void:
	if _file == null:
		return
	data["t"] = _now() / 1000.0
	_file.store_line(JSON.stringify(data))
	_file.flush()  # a crash or a closed window keeps everything so far
