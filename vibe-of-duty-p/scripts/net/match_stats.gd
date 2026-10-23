class_name MatchStats
extends RefCounted
## Server: records how live players fight, for balance (TTK, which weapon and cards win) - one file per server run,
## user://stats/<date>_<time>.jsonl, one JSON object per line ("e" = event). Format and the report - Docs/STATS.md;
## the report: tools/stats_report.py. Owned by NetWorld; off on training maps and in automated tests (--stats: on).
##
## Engagement: the damage a player takes from the moment they were last at full health. Its start is where the TTK
## of a kill is counted from (per attacker: their first hit on the victim in it).

const DIR := "user://stats"
const BURST_GAP := 1.0  # s without a shot: the next shot starts a new burst (the "opened fire" moment of a TTK)

var _file: FileAccess
var _t0 := 0           # ms (ticks clock) when the file was opened
var _match := 0        # number of the match in this file, from 1
var _match_start := 0  # ms
var _lives := {}       # peer_id -> {p (name), start, variant, kills, shots, hits, head, dmg_out, dmg_in}
var _engaged := {}     # victim peer_id -> {attacker peer_id -> {first, hits, head, dmg}}
var _bursts := {}      # peer_id -> {start, last, shots}


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


## A new life (first spawn, respawn, a new match): what it plays. A life still running ends ("match").
func spawned(player: Player) -> void:
	if _lives.has(player.peer_id):
		_end_life(player.peer_id, "match")
	_lives[player.peer_id] = {"p": player.player_name, "start": _now(), "variant": PartDB.variant_name(player.build), "kills": 0, "shots": 0,
			"hits": 0, "head": 0, "dmg_out": 0, "dmg_in": 0}
	_engaged.erase(player.peer_id)
	# Damage they did in their last life stays on its victims, but as somebody else's (dmg_others): a kill in this
	# life times from this life's first hit.
	for by: Dictionary in _engaged.values():
		if by.has(player.peer_id):
			var old: Dictionary = by.get_or_add("%d:old" % player.peer_id, {"dmg": 0})
			old["dmg"] += int(by[player.peer_id]["dmg"])
			by.erase(player.peer_id)
	_bursts.erase(player.peer_id)
	_write({"e": "spawn", "m": _match, "p": player.player_name, "id": player.peer_id,
			"w": _lives[player.peer_id]["variant"], "build": player.build})


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
		life["hits"] += hits.size()
		for hit in hits:
			life["head"] += 1 if hit["zone"] == "head" else 0


## Damage the victim took (`hp_before` - their health now), with the state of both at that moment.
func damaged(attacker: Player, victim: Player, hp_before: int, head: bool, weapon: int) -> void:
	var now := _now()
	var amount := hp_before - victim.health
	if hp_before >= victim.max_health:
		_engaged.erase(victim.peer_id)  # was at full health: a new engagement
	var by: Dictionary = _engaged.get_or_add(victim.peer_id, {})
	var mine: Dictionary = by.get_or_add(attacker.peer_id, {"first": now, "hits": 0, "head": 0, "dmg": 0})
	mine["hits"] += 1
	mine["head"] += 1 if head else 0
	mine["dmg"] += amount
	if _lives.has(attacker.peer_id):
		_lives[attacker.peer_id]["dmg_out"] += amount
	if _lives.has(victim.peer_id):
		_lives[victim.peer_id]["dmg_in"] += amount
	_write({"e": "hit", "m": _match, "a": attacker.player_name, "v": victim.player_name,
			"aw": _variant(attacker), "vw": _variant(victim), "gun": _weapon_id(attacker, weapon), "dmg": amount,
			"hp": victim.health, "head": head, "dist": snappedf(_distance(attacker, victim), 0.1),
			"a_state": _state(attacker), "v_state": _state(victim)})


## A death: TTK and how the fight went. weapon -1: suicide / fell off the map.
func killed(killer: Player, victim: Player, weapon: int, head: bool) -> void:
	var now := _now()
	var line := {"e": "kill", "m": _match, "k": killer.player_name, "v": victim.player_name, "kw": _variant(killer),
			"vw": _variant(victim), "gun": _weapon_id(killer, weapon), "head": head,
			"v_life": (now - int(_lives.get(victim.peer_id, {}).get("start", now))) / 1000.0}
	if killer != victim:
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
		line.merge({"dist": snappedf(_distance(killer, victim), 0.1),
				"ttk": (now - int(mine["first"])) / 1000.0,      # killer's first hit -> death
				"ttk_fire": (now - opened) / 1000.0,             # killer opened fire (burst) -> death
				"hits": mine["hits"], "head_hits": mine["head"], "shots": int(burst.get("shots", 0)),
				"dmg": mine["dmg"], "dmg_others": others, "v_dmg_to_k": int(back.get("dmg", 0)),
				"k_hp": killer.health, "k_max": killer.max_health,
				"k_life": (now - int(_lives.get(killer.peer_id, {}).get("start", now))) / 1000.0,
				"k_state": _state(killer), "v_state": _state(victim)})
		if _lives.has(killer.peer_id):
			_lives[killer.peer_id]["kills"] += 1
	_write(line)
	_engaged.erase(victim.peer_id)
	_end_life(victim.peer_id, "death")


func left(id: int) -> void:
	_end_life(id, "leave")
	_engaged.erase(id)
	_bursts.erase(id)


func _end_life(id: int, reason: String) -> void:
	if not _lives.has(id):
		return
	var life: Dictionary = _lives[id]
	_lives.erase(id)
	_write({"e": "life", "m": _match, "p": life["p"], "w": life["variant"],
			"end": reason, "dur": (_now() - int(life["start"])) / 1000.0, "kills": life["kills"],
			"shots": life["shots"], "hits": life["hits"], "head": life["head"], "dmg_out": life["dmg_out"],
			"dmg_in": life["dmg_in"]})


func _variant(player: Player) -> String:
	return _lives[player.peer_id]["variant"] if _lives.has(player.peer_id) else PartDB.variant_name(player.build)


static func _weapon_id(player: Player, weapon: int) -> String:
	if weapon == WeaponSim.MELEE:
		return "melee"
	if weapon < 0:
		return "self"
	return player.weapons.def_at(weapon).id


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
