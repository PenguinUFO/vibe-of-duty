class_name LagComp
extends RefCounted
## Server-side lag compensation. Keeps a short history of every player's hitbox state per server
## tick, and hit-tests rays against analytic hitboxes (a vertical capsule for the body, a sphere
## for the head). The head sphere sits where the third-person mannequin's head is (it follows the
## aim pitch, aiming and crouching). To judge a shot, the server samples every target at the tick the shooter
## was actually looking at (Player's `view_tick`), so players hit what they saw on screen.
##
## The same hitbox geometry is used by clients for their own predicted tracers, with the targets'
## currently displayed positions.

const HISTORY_TICKS := 90  # 1.5 s at 60 Hz
const MAX_REWIND_TICKS := 60
const BODY_RADIUS := 0.38
const HEAD_RADIUS := 0.17

const NECK_GAP := 0.15         # head centre to the top of the body capsule

var _history := {}  # peer_id -> Array of hitbox states (see Player.hitbox_state) with a "tick" key


func record(tick: int, players: Dictionary) -> void:
	for id in players:
		var p = players[id]  # Player (untyped: LagComp stays free of Player, which needs the autoloads)
		if not _history.has(id):
			_history[id] = []
		var h: Array = _history[id]
		var state: Dictionary = p.hitbox_state()
		state["tick"] = tick
		h.append(state)
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
	var near: Dictionary = a if f < 0.5 else b
	return {"pos": (a["pos"] as Vector3).lerp(b["pos"], f), "crouched": near["crouched"], "ads": near["ads"],
			"sliding": near.get("sliding", false),
			"yaw": lerp_angle(a["yaw"], b["yaw"], f), "pitch": lerpf(a["pitch"], b["pitch"], f),
			"vel": (a["vel"] as Vector3).lerp(b["vel"], f)}


# --- Hitbox geometry ----------------------------------------------------------------------------

## Head offset over the feet in the player's frame for a hitbox state: exactly where the mannequin's head is
## (Mannequin.head_offset; the visual blends crouch / ADS over a fraction of a second, the hitbox switches at once).
## It leans with the movement like the body does (Mannequin.run_lean), and back in a slide.
static func head_offset(state: Dictionary) -> Vector3:
	var local_velocity := Basis(Vector3.UP, state["yaw"]).inverse() * (state["vel"] as Vector3)
	var sliding: bool = state.get("sliding", false)
	var lean := Vector2(Mannequin.SLIDE_LEAN, 0.0) if sliding else Mannequin.run_lean(local_velocity)
	var head := Mannequin.head_offset(state["pitch"], 1.0 if state["ads"] else 0.0, 1.0 if state["crouched"] else 0.0, lean)
	return head - Vector3(0.0, Mannequin.SLIDE_DROP if sliding else 0.0, 0.0)


static func head_center(state: Dictionary) -> Vector3:
	return (state["pos"] as Vector3) + Basis(Vector3.UP, state["yaw"]) * head_offset(state)


## Bottom and top centre of the body capsule's axis (the capsule's end caps add BODY_RADIUS). The capsule stays
## vertical but shifts with half of the head's lean, like the chest, and ends at the neck (NECK_GAP under the head
## centre) so the head sphere is never buried in it.
static func body_segment(state: Dictionary) -> Array[Vector3]:
	var head := head_offset(state)
	var lean := head - Mannequin.head_offset(0.0, 0.0, 0.0)
	var shift: Vector3 = Basis(Vector3.UP, state["yaw"]) * Vector3(lean.x, 0.0, lean.z) * 0.5
	var pos: Vector3 = state["pos"] + shift
	var bottom := 0.05 + BODY_RADIUS
	var top := maxf(bottom, head.y - NECK_GAP - BODY_RADIUS)
	return [pos + Vector3(0.0, bottom, 0.0), pos + Vector3(0.0, top, 0.0)]


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
