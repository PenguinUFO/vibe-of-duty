class_name DayCycle
extends Node
## A day over the match (the killhouse: morning at the start, night at the end - the owner). Read
## Docs/LEVEL_KILLHOUSE.md first; update it with any change here.
## `keys` are points of the day: {"at": share of the match 0..1, "lamps": x the level's lamp energy, and any of
## LevelMood's values}. Between two keys every value is blended; two keys at the same "at" are a cut (the sun gone
## below the horizon, the moon up - while neither shines). Whatever a key lacks is taken from the key before it.
## The level's LevelMood is rewritten with the blend and the light reapplied (Mood.apply_light) every STEP seconds -
## so the day lives in the PSX style; with the style off the level keeps its own light (Mood's rule).
## - The clock is the match's (Game.time_left of Game.match_time): the server sends it, every machine sees the same
##   sky with nothing more sent, a late joiner too. Between matches (the scoreboard) - the last key; outside a match
##   (the menu, training) - the first.
## Put it in the level next to LevelMood.

const STEP := 0.5  # s between updates: the sun moves ~0.15 deg in that time in a 10-minute match
const PLAYING := 2  # Game.State.PLAYING (not named: tools load this without the autoloads)

@export var keys: Array[Dictionary] = []
@export var lamps_path := ^"../Shell/Lamps"

## Tools (screenshots): the share of the match the day is read at instead of the clock (negative: off).
var time_override := -1.0

var _mood: LevelMood
var _lamps: Array[OmniLight3D] = []
var _lamp_energy: Array[float] = []
var _wait := 0.0
var _last := -1.0


func _ready() -> void:
	_mood = get_node_or_null("../LevelMood") as LevelMood
	var lamps := get_node_or_null(lamps_path)
	if lamps:
		for light in lamps.get_children():
			if light is OmniLight3D:
				_lamps.append(light)
				_lamp_energy.append((light as OmniLight3D).light_energy)
	_apply(_now())


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = STEP
	var t := _now()
	if absf(t - _last) > 0.0005:
		_apply(t)


## The share of the match gone (0 - its start, 1 - its end).
func _now() -> float:
	if time_override >= 0.0:
		return clampf(time_override, 0.0, 1.0)
	var game := get_node_or_null(^"/root/Game")  # not Game: tools load this without the autoloads
	if game == null:
		return 0.0
	if game.is_frozen():
		return 1.0
	if game.state != PLAYING or game.training:
		return 0.0
	return clampf(1.0 - game.time_left / maxf(game.match_time, 1.0), 0.0, 1.0)


func _apply(t: float) -> void:
	_last = t
	if keys.is_empty() or _mood == null:
		return
	var values := blend(t)
	var lamps: float = values.get("lamps", 1.0)
	values.erase("lamps")
	values.erase("at")
	_mood.values = values
	for i in _lamps.size():
		_lamps[i].light_energy = _lamp_energy[i] * lamps
	var level := get_parent()
	var env_node := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var settings := get_node_or_null(^"/root/Settings")
	var on: bool = settings.psx_style if settings != null else true
	Mood.apply_light(level, env_node.environment if env_node else null, level.get_node_or_null("Sun") as DirectionalLight3D,
			on)


## The day's values at share `t` of the match.
func blend(t: float) -> Dictionary:
	var full: Array[Dictionary] = []  # each key with what it lacks filled in from the one before
	var last := {}
	for key in keys:
		last = _merge(last, key)
		full.append(last)
	if t <= float(full[0]["at"]):
		return full[0].duplicate(true)
	for i in range(full.size() - 1):
		var a: Dictionary = full[i]
		var b: Dictionary = full[i + 1]
		if t < float(b["at"]):
			var span := float(b["at"]) - float(a["at"])
			return _mix(a, b, (t - float(a["at"])) / span if span > 0.0 else 1.0)
	return full[-1].duplicate(true)


static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for name in over:
		if over[name] is Dictionary and out.get(name) is Dictionary:
			out[name] = _merge(out[name], over[name])
		else:
			out[name] = over[name]
	return out


static func _mix(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var out := {}
	for name in b:
		var x = a.get(name, b[name])
		var y = b[name]
		if y is Dictionary:
			out[name] = _mix(x, y, w)
		elif y is Color:
			out[name] = (x as Color).lerp(y, w)
		elif y is float or y is int:  # a scene stores 10.0 as 10
			out[name] = lerpf(float(x), float(y), w)
		else:
			out[name] = y if w >= 0.5 else x
	return out
