class_name LagComp
extends RefCounted
## Server-side lag compensation. Keeps a short history of every player's position and stance per
## server tick, and hit-tests rays against analytic hitboxes (a vertical capsule for the body, a
## sphere for the head). To judge a shot, the server samples every target at the tick the shooter
## was actually looking at (Player's `view_tick`), so players hit what they saw on screen.
##
## The same hitbox geometry is used by clients for their own predicted tracers, with the targets'
## currently displayed positions.

const HISTORY_TICKS := 90  # 1.5 s at 60 Hz
const MAX_REWIND_TICKS := 60
const BODY_RADIUS := 0.38
const HEAD_RADIUS := 0.17

var _history := {}  # peer_id -> Array of {tick, pos, crouched}


func record(tick: int, players: Dictionary) -> void:
	for id in players:
		var p: Player = players[id]
		if not _history.has(id):
			_history[id] = []
		var h: Array = _history[id]
		h.append({"tick": tick, "pos": p.global_position, "crouched": p.is_crouched})
		if h.size() > HISTORY_TICKS:
			h.pop_front()


func forget(peer_id: int) -> void:
	_history.erase(peer_id)


## Drops a player's history (after a teleport/respawn) so nobody is hit where they used to be.
func clear(peer_id: int) -> void:
	_history[peer_id] = []


## Position/stance of `peer_id` at (fractional) server tick `tick`; {} if unknown.
func sample(peer_id: int, tick: float) -> Dictionary:
	var h: Array = _history.get(peer_id, [])
	if h.is_empty():
		return {}
	var first: Dictionary = h[0]
	var last: Dictionary = h[h.size() - 1]
	if tick <= first["tick"]:
		return first
	if tick >= last["tick"]:
		return last
	var i := clampi(int(floor(tick)) - int(first["tick"]), 0, h.size() - 2)
	var a: Dictionary = h[i]
	var b: Dictionary = h[i + 1]
	var f := clampf((tick - float(a["tick"])) / maxf(float(b["tick"] - a["tick"]), 1.0), 0.0, 1.0)
	return {"pos": (a["pos"] as Vector3).lerp(b["pos"], f), "crouched": a["crouched"] if f < 0.5 else b["crouched"]}


# --- Hitbox geometry ----------------------------------------------------------------------------

## Bottom and top centre of the body capsule's axis (the capsule's end caps add BODY_RADIUS).
static func body_segment(pos: Vector3, crouched: bool) -> Array[Vector3]:
	var height := 1.0 if crouched else 1.5
	return [pos + Vector3(0.0, 0.05 + BODY_RADIUS, 0.0), pos + Vector3(0.0, 0.05 + height - BODY_RADIUS, 0.0)]


static func head_center(pos: Vector3, crouched: bool) -> Vector3:
	return pos + Vector3(0.0, (Player.CROUCH_EYE if crouched else Player.STAND_EYE) + 0.03, 0.0)


## Distance along the ray to the sphere, or -1 for a miss. `dir` must be normalised.
static func ray_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float) -> float:
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	if c > 0.0 and b > 0.0:
		return -1.0
	var disc := b * b - c
	if disc < 0.0:
		return -1.0
	return maxf(-b - sqrt(disc), 0.0)


## Distance along the ray to a vertical capsule (axis from `bottom` to `top`, same x/z), or -1 for a miss.
static func ray_capsule(origin: Vector3, dir: Vector3, bottom: Vector3, top: Vector3, radius: float) -> float:
	var best := INF
	# Cylindrical side: a circle test in the XZ plane, clipped to the axis segment.
	var ox := origin.x - bottom.x
	var oz := origin.z - bottom.z
	var a := dir.x * dir.x + dir.z * dir.z
	if a > 1e-8:
		var b := ox * dir.x + oz * dir.z
		var c := ox * ox + oz * oz - radius * radius
		var disc := b * b - a * c
		if disc >= 0.0:
			var t := (-b - sqrt(disc)) / a
			if t >= 0.0:
				var y := origin.y + dir.y * t
				if y >= bottom.y and y <= top.y:
					best = t
	# End caps (a union of convex pieces: the first hit is the minimum over the pieces).
	var t_bottom := ray_sphere(origin, dir, bottom, radius)
	if t_bottom >= 0.0:
		best = minf(best, t_bottom)
	var t_top := ray_sphere(origin, dir, top, radius)
	if t_top >= 0.0:
		best = minf(best, t_top)
	return -1.0 if best == INF else best
