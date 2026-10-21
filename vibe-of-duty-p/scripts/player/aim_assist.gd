class_name AimAssist
extends RefCounted
## Read Docs/AIM_ASSIST.md first (how it works, where its settings live, pitfalls); update it with any behaviour change.
## Gamepad aim assist for the local player. Player only uses it while the view is turned with the stick; the mouse
## gets none. Two parts, both only near a visible enemy and fading out towards the edge of a small cone around it:
##  - slowdown: the stick turns slower over a target, so it is easier to stop on it;
##  - tracking: the view follows part of the target's motion across the screen (its strafing and our own movement),
##    so a moving target stays under the crosshair - standing still and with the stick released too.
##  - pull (kid mode only, ADS only, rate in Settings.kid_ads_pull): the view is drawn towards the nearest point of the target line, gradually,
##    so the crosshair settles on the target instead of stopping next to it.
## No snapping onto a target. It only moves the client's camera; the server traces the shot from the view the client
## sends, exactly as for a player who aims well.
##
## A target is a line from mid-torso to the head centre (the hitboxes): the assist works on whichever point of it the
## crosshair is nearest, so it holds the head as well as the body and never drags the aim between them.

const OVERALL := 0.8                # overall strength: scales slowdown and tracking (the setting multiplies this)
const RANGE := 60.0
const RADIUS := 0.9                 # m around the target line where the assist works (at hip)
const ADS_RADIUS_MULT := 1.3        # the cone is a bit wider in ADS
const MAX_ANGLE := deg_to_rad(9.0)  # cone cap for close targets
const SLOWDOWN := 0.5               # stick speed multiplier on the target line at full strength (hip)
const ADS_SLOWDOWN := 0.38
const TRACKING := 0.55              # share of the target's angular motion followed at full strength (hip)
const ADS_TRACKING := 0.7
const STICKY := 0.75                # the current target's score is multiplied by this (no flicking between two)
const MAX_TRACK_STEP := 0.15        # rad; a larger jump of the target direction (respawn, teleport) is not followed

## Stick speed multiplier for this frame (1 = no slowdown).
var slowdown := 1.0
## Debug: 0 outside any cone .. 1 on the target line.
var strength := 0.0
var target_id := -1

var _t := 0.0                    # point on the target line we follow (0 torso .. 1 head)
var _last_dir := Vector3.ZERO    # direction from the eye to that point last frame


## targets: [{id, a, b}] - each target's line in world space (a torso, b head). `visible` is called as
## visible(eye, point) -> bool for the best candidate only. `reach` widens the cone (kid mode: 2); `max_range`: how
## far targets are assisted (kid mode: no limit, INF); `pull`: the ADS pull rate, 1/s (in full ADS the aim
## error shrinks by e every 1/pull s; 0 = none).
## Returns the tracking turn (yaw, pitch) to add this frame.
func update(eye: Vector3, yaw: float, pitch: float, ads: float, amount: float, targets: Array,
		visible: Callable, reach: float = 1.0, max_range: float = RANGE, pull: float = 0.0,
		delta: float = 0.0) -> Vector2:
	slowdown = 1.0
	strength = 0.0
	if amount <= 0.0:
		target_id = -1
		return Vector2.ZERO
	amount *= OVERALL
	var forward := Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.FORWARD
	var best: Dictionary = {}
	var best_score := 1.0
	var best_t := 0.0
	for target in targets:
		var t := closest_t(eye, forward, target["a"], target["b"])
		var to: Vector3 = (target["a"] as Vector3).lerp(target["b"], t) - eye
		var dist := to.length()
		if dist > max_range or dist < 0.5:
			continue
		var cone := minf(atan(RADIUS * reach * lerpf(1.0, ADS_RADIUS_MULT, ads) / dist), MAX_ANGLE * reach)
		var score := forward.angle_to(to) / cone
		if target["id"] == target_id:
			score *= STICKY
		if score < best_score:
			best = target
			best_score = score
			best_t = t
	if best.is_empty() or not visible.call(eye, (best["a"] as Vector3).lerp(best["b"], best_t)):
		target_id = -1
		return Vector2.ZERO

	strength = 1.0 - pow(best_score, 4.0)  # full over most of the cone, fading out only near its edge
	slowdown = lerpf(1.0, lerpf(SLOWDOWN, ADS_SLOWDOWN, ads), minf(strength * amount, 1.0))  # amount > 1 (kid mode) must not overshoot
	var turn := Vector2.ZERO
	if best["id"] == target_id:
		# Where the point we were on has moved to, as seen from the eye (our own turning does not count).
		var dir := ((best["a"] as Vector3).lerp(best["b"], _t) - eye).normalized()
		var step := Vector2(angle_difference(yaw_of(_last_dir), yaw_of(dir)), pitch_of(dir) - pitch_of(_last_dir))
		if step.length() < MAX_TRACK_STEP:
			turn = step * minf(lerpf(TRACKING, ADS_TRACKING, ads) * strength * amount, 1.0)
	target_id = best["id"]
	_t = best_t
	_last_dir = ((best["a"] as Vector3).lerp(best["b"], best_t) - eye).normalized()
	if pull > 0.0 and ads > 0.0:
		var error := Vector2(angle_difference(yaw, yaw_of(_last_dir)), pitch_of(_last_dir) - pitch)
		turn += error * (1.0 - exp(-pull * ads * strength * delta))
	return turn


## Parameter (0..1) of the point of segment a-b closest to the ray origin + s * dir (`dir` normalised).
static func closest_t(origin: Vector3, dir: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var w := a - origin
	var along := ab.dot(dir)
	var denom := ab.dot(ab) - along * along
	if denom < 1e-6:
		return 0.5  # the segment is parallel to the ray
	return clampf((w.dot(dir) * along - w.dot(ab)) / denom, 0.0, 1.0)


## Yaw and pitch of a direction, in the convention of Player.look_yaw / look_pitch (forward is -Z).
static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func pitch_of(dir: Vector3) -> float:
	return asin(clampf(dir.y, -1.0, 1.0))
