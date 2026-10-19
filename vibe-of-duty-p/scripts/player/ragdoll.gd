class_name Ragdoll
extends RefCounted
## The fall of a dead Mannequin: a light Verlet ragdoll of the body's joints (and the dropped gun), simulated on every
## machine on its own (cosmetic; nothing in the game depends on where a body lies). Points are pulled by gravity, held
## together by distance links (the torso is a rigid cluster, limbs are fixed-length bones, the neck gives a little) and
## pushed out of the level by short raycasts against the WORLD layer, with friction. Knees only bend forward. Once the
## body lies still it goes to sleep and costs nothing. Mannequin places its parts on the points (pose_ragdoll).

enum { PELVIS, CHEST, HEAD, HIP_L, KNEE_L, ANKLE_L, HIP_R, KNEE_R, ANKLE_R, SHOULDER_L, ELBOW_L, WRIST_L,
		SHOULDER_R, ELBOW_R, WRIST_R, GUN_BUTT, GUN_MUZZLE, GUN_TOP, COUNT }

const STEP := 1.0 / 120.0
const MAX_STEPS := 4            # per frame (a long frame slows the fall rather than costing more)
const ITERATIONS := 6
const GRAVITY := 11.0           # a bit over g: a 1.8 m body falling at true g looks floaty on screen
const DRAG := 0.3               # per second
const FRICTION := 0.55          # share of the sliding speed lost on each contact step
const SLEEP_SPEED := 0.06       # m/s: slower than this everywhere...
const SLEEP_TIME := 0.4         # ...for this long, and the body stops simulating
const MAX_TIME := 8.0

## Collision radius per point (what keeps limbs out of the floor).
const RADIUS: Array[float] = [0.13, 0.13, 0.12, 0.08, 0.07, 0.05, 0.08, 0.07, 0.05, 0.08, 0.05, 0.045,
		0.08, 0.05, 0.045, 0.03, 0.03, 0.03]
## Inverse mass: the torso is heavy, hands and feet light.
const INV_MASS: Array[float] = [0.4, 0.4, 0.8, 0.6, 0.9, 1.0, 0.6, 0.9, 1.0, 0.7, 1.0, 1.0, 0.7, 1.0, 1.0,
		1.0, 1.0, 1.0]

var pos := PackedVector3Array()
var asleep := false
var impacts := PackedVector3Array()  # where the torso or head hit the ground hard (dust); the owner clears it

var _prev := PackedVector3Array()
var _links: Array[PackedFloat32Array] = []  # [a, b, min length, max length]
var _world: World3D
var _time := 0.0
var _still := 0.0
var _accum := 0.0
var _query := PhysicsRayQueryParameters3D.new()
var _thudded := {}  # points that already raised dust


## `points`: world positions (COUNT of them, in the enum's order); `velocities`: their starting velocities.
func _init(points: PackedVector3Array, velocities: PackedVector3Array, world: World3D) -> void:
	pos = points.duplicate()
	_prev = PackedVector3Array()
	_prev.resize(COUNT)
	for i in COUNT:
		_prev[i] = pos[i] - velocities[i] * STEP
	_world = world
	_query.collision_mask = Layers.WORLD

	var torso := [PELVIS, CHEST, HIP_L, HIP_R, SHOULDER_L, SHOULDER_R]
	for i in torso.size():
		for j in range(i + 1, torso.size()):
			_link(torso[i], torso[j])
	_link(HEAD, CHEST)
	_link(HEAD, SHOULDER_L, 0.05)
	_link(HEAD, SHOULDER_R, 0.05)
	for leg in [[HIP_L, KNEE_L, ANKLE_L], [HIP_R, KNEE_R, ANKLE_R]]:
		_link(leg[0], leg[1])
		_link(leg[1], leg[2])
		_limit(leg[0], leg[2], 0.55)  # the knee folds, but not flat
		_limit(PELVIS, leg[2], 0.35)
	for arm in [[SHOULDER_L, ELBOW_L, WRIST_L], [SHOULDER_R, ELBOW_R, WRIST_R]]:
		_link(arm[0], arm[1])
		_link(arm[1], arm[2])
		_limit(arm[0], arm[2], 0.3)
	_link(GUN_BUTT, GUN_MUZZLE)
	_link(GUN_BUTT, GUN_TOP)
	_link(GUN_MUZZLE, GUN_TOP)


## A link holding its current length (± `slack`).
func _link(a: int, b: int, slack := 0.0) -> void:
	var length := pos[a].distance_to(pos[b])
	_links.append(PackedFloat32Array([a, b, length - slack, length + slack]))


## Only a minimum: `share` of the current length.
func _limit(a: int, b: int, share: float) -> void:
	_links.append(PackedFloat32Array([a, b, pos[a].distance_to(pos[b]) * share, INF]))


## Advances the fall by `delta` seconds (fixed sub-steps).
func step(delta: float) -> void:
	if asleep:
		return
	_time += delta
	_accum = minf(_accum + delta, STEP * MAX_STEPS)
	var fastest := 0.0
	while _accum >= STEP:
		_accum -= STEP
		fastest = maxf(fastest, _substep())
	if fastest < SLEEP_SPEED * STEP:
		_still += delta
	else:
		_still = 0.0
	if _still > SLEEP_TIME or _time > MAX_TIME:
		asleep = true


## One sub-step; returns the largest distance a point moved.
func _substep() -> float:
	var start := pos.duplicate()
	var keep := 1.0 - DRAG * STEP
	var fall := Vector3.DOWN * GRAVITY * STEP * STEP
	for i in COUNT:
		var p := pos[i]
		pos[i] = p + (p - _prev[i]) * keep + fall
		_prev[i] = p
	for n in ITERATIONS:
		for link in _links:
			_solve(int(link[0]), int(link[1]), link[2], link[3])
		_bend_knee(HIP_L, KNEE_L, ANKLE_L)
		_bend_knee(HIP_R, KNEE_R, ANKLE_R)
	var space := _world.direct_space_state if _world else null
	var fastest := 0.0
	for i in COUNT:
		if space:
			_collide(space, i, start[i])
		fastest = maxf(fastest, pos[i].distance_to(start[i]))
	return fastest


func _solve(a: int, b: int, min_length: float, max_length: float) -> void:
	var delta := pos[b] - pos[a]
	var length := delta.length()
	if length < 0.00001:
		return
	var target := clampf(length, min_length, max_length)
	if target == length:
		return
	var wa := INV_MASS[a]
	var wb := INV_MASS[b]
	var correction := delta * ((length - target) / length / (wa + wb))
	pos[a] += correction * wa
	pos[b] -= correction * wb


## A knee bent backwards is mirrored across the hip-ankle line to the front (the torso's forward side); the mirror
## keeps both bone lengths.
func _bend_knee(hip: int, knee: int, ankle: int) -> void:
	var leg := pos[ankle] - pos[hip]
	if leg.length() < 0.001:
		return
	var axis := leg.normalized()
	var right := pos[SHOULDER_R] - pos[SHOULDER_L]
	var up := pos[CHEST] - pos[PELVIS]
	var forward := up.cross(right)  # right x up = back
	var normal := forward - axis * forward.dot(axis)
	if normal.length() < 0.001:
		return
	normal = normal.normalized()
	var depth := (pos[knee] - pos[hip]).dot(normal)
	if depth < 0.0:
		pos[knee] -= normal * (2.0 * depth)


## Keeps point `i` out of the level: a ray from where it was to where it is now (and its radius further down);
## on a hit it sits on the surface, loses the speed into it and some of the sliding speed.
func _collide(space: PhysicsDirectSpaceState3D, i: int, from: Vector3) -> void:
	var r := RADIUS[i]
	_query.from = from
	_query.to = pos[i] + Vector3.DOWN * r
	var hit := space.intersect_ray(_query)
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	var surface: Vector3 = hit["position"] + normal * r
	if (pos[i] - surface).dot(normal) >= 0.0:
		return  # the ray only grazed it through the radius probe: still above the surface
	var speed_in := -(pos[i] - _prev[i]).dot(normal) / STEP
	if i in [PELVIS, CHEST, HEAD] and speed_in > 2.5 and not _thudded.has(i):
		_thudded[i] = true
		impacts.append(surface - normal * r)
	pos[i] = surface
	var v := pos[i] - _prev[i]
	var into := v.dot(normal)
	if into < 0.0:
		v -= normal * into
	v *= 1.0 - FRICTION
	_prev[i] = pos[i] - v
