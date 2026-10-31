class_name Mannequin
extends Node3D
## Blockout human with a pig's head (snout, ears, curly tail - "80% human, 20% pig"): an angular, flat-shaded
## (SUPERHOT-like) mannequin built from low-poly capsules, posed procedurally every frame (no skeleton, no clips).
## Rigid parts - pelvis, torso, neck, head, upper/lower arms, hands, thighs, shins, feet - are placed from joint
## positions that come from a few simple rules:
##   - legs: two-bone IK from the hips to feet planted on the ground (crouching lowers the pelvis, the knees bend);
##   - torso: bends about the spine pivot with the aim pitch (and leans forward when crouching);
##   - weapon: held at the hip or, aiming down sights, with the rear sight under the eye; both arms reach it by IK.
## The head position is a pure function of (pitch, ads, crouch, run lean) - head_offset() - which LagComp uses for the
## head hitbox, so the hitbox matches the body (up to the few centimetres of the walking bob).
##
## Locomotion (animate): a gait cycle whose phase advances with the distance travelled, so a planted foot stays put on
## the ground; the swing foot arcs forward, the pelvis drops at each footfall, sways and twists. Standing, the feet stay
## planted in the world and step back under the body when it turns or drifts. The torso leans with the speed (the
## hitbox leans the same way, run_lean) and, through a spring, with the acceleration; ears and tail flop on springs.
## On death the body becomes a ragdoll (start_ragdoll; the physics is in Ragdoll).
##
## Facing: the mannequin looks along -Z (the player's forward). Units: metres. First-person arms reuse the arm parts
## (make_arm / pose_arm), so the hands look the same in both views.

# --- proportions (1.8 m tall) ---
const PELVIS_STAND := 0.95       # pelvis height standing
const PELVIS_CROUCH := 0.45      # ... crouching (knees deep)
const CROUCH_LEAN := 0.6         # rad the torso leans forward when crouching
const SPINE_PIVOT := 0.12        # spine pivot above the pelvis
const SHOULDER_UP := 0.42        # shoulders above the spine pivot
const SHOULDER_X := 0.2
const HEAD_UP := 0.55            # head centre above the spine pivot (standing: 0.95 + 0.12 + 0.55 = 1.62)
const SPINE_SHARE := 0.6         # share of the aim pitch the torso takes (the head takes the rest)
const ADS_HEAD := Vector3(0.03, -0.04, -0.06)  # the cheek goes down onto the stock while aiming (chest frame)
const HIP_X := 0.1
const THIGH := 0.43
const SHIN := 0.41
const ANKLE_H := 0.08
const UPPER_ARM := 0.29
const FOREARM := 0.27
const WRIST_TO_PALM := 0.05
const HEAD_RADIUS := 0.115

# --- weapon holding ---
const HIP_BUTT := Vector3(-0.05, -0.04, -0.05)  # butt of the stock relative to the right shoulder, in the aim frame
const BUTT := Vector3(0.0, -0.005, -0.38)         # butt of the stock in prefab space (shouldered at the hip too)
const EYE := Vector3(0.0, 0.02, -0.08)          # eye relative to the head centre, in the aim frame
## Hand orientation on the gun, in weapon view space (x right, y up, -z forward).
const RIGHT_FINGERS := Vector3(-0.3, -0.5, -0.8)  # round the front of the pistol grip
const RIGHT_PALM := Vector3(-1.0, 0.0, 0.0)       # palm against its right side
const LEFT_FINGERS := Vector3(1.0, 0.15, -0.3)    # across under the handguard, curling up its right side
const LEFT_PALM := Vector3(0.0, 1.0, 0.0)         # palm up
const RIGHT_POLE := Vector3(0.9, -1.0, 0.3)       # where the elbows point (mannequin space)
const LEFT_POLE := Vector3(-0.8, -1.0, -0.1)
const PUNCH_REACH := Vector3(0.14, -0.04, -0.55)  # the punching hoof from the left shoulder, aim frame (towards the middle)
const BANDOLIER := Vector3(-0.12, 0.22, -0.16)    # chest frame: the loops on the left of the chest a break-open's rounds ride in
const PRESENT_TILT := 0.45                        # rad: shown (present), the barrel up to the left across the chest...
const PRESENT_AT := Vector3(0.0, 0.18, -0.26)     # ...the middle between the hands here (chest frame)

# --- locomotion ---
const STANCE_L := Vector3(-0.13, 0.0, -0.12)  # standing feet (a slightly staggered stance)
const STANCE_R := Vector3(0.13, 0.0, 0.1)
const FOOT_X := 0.12             # feet off the centre line while walking
const STRIDE_WALK := 1.15        # m the body travels in a full gait cycle (two steps) at a walk...
const STRIDE_RUN := 2.0          # ... and at a sprint
const LIFT_WALK := 0.09          # height of the swinging foot
const LIFT_RUN := 0.2
const BOB_WALK := 0.025          # pelvis drop at each footfall
const BOB_RUN := 0.04
const TWIST := 0.15              # rad the pelvis turns with the forward leg
const IDLE_STEP := 0.12          # m a planted foot may lag behind its place under the body before it steps
const IDLE_STEP_TIME := 0.2      # s per idle step
const IDLE_STEP_LIFT := 0.06
const LEAN_PER_SPEED := 0.022    # rad of forward lean per m/s (the hitbox leans too: run_lean)
const LEAN_MAX := 0.16
const SIDE_LEAN_PER_SPEED := 0.012
const SIDE_LEAN_MAX := 0.08
const TUCK_HEIGHT := 0.3         # m the feet draw up in the air (rising; falling, the legs reach down again)
const LAND_DROP_MAX := 0.06      # m the pelvis may sink on landing (within the head hitbox's spare radius)
const PELVIS_DROP_MAX := 0.07    # bob + landing together
const SLIDE_LEAN := 0.5          # rad the torso leans back in a slide (undoing most of the crouch's forward lean)
const SLIDE_DROP := 0.15         # m the pelvis sinks below the crouch in a slide (the hitbox too: LagComp.head_offset)
const SLIDE_LEAD := Vector3(-0.1, 0.0, -0.75)  # sliding: the left leg out in front...
const SLIDE_TUCK := Vector3(0.16, 0.0, 0.08)   # ...the right one folded under

# --- colours ---
# Grim, realistic palette: worn fatigues, dirty pig skin, dull leather. Player colours stay distinct but muted.
const SUIT := Color(0.2, 0.21, 0.17)    # faded olive-grey fatigues
const SKIN := Color(0.6, 0.45, 0.41)    # weathered, dirty pig skin: head, neck, tail
const SNOUT := Color(0.5, 0.34, 0.32)   # snout and ears, a shade darker than the skin
const HOOF := Color(0.36, 0.3, 0.26)   # weathered horn: hands and feet are cloven hooves; light enough for the dark gun
const VISOR := Color(0.03, 0.025, 0.02) # eyes and nostrils
const CHIP := Color(0.1, 0.105, 0.11)    # the "Инженер"'s plate (set_chip): dark metal
const CHIP_SIZE := Vector3(0.064, 0.046, 0.012)
## The chip's wires sticking out of it: colour and bend points, in the plate's frame (z out of the head, -x toward
## the ear).
const CHIP_WIRES := [
	[Color(0.55, 0.1, 0.08), [Vector3(-0.018, 0.012, 0.006), Vector3(-0.022, 0.018, 0.03), Vector3(-0.05, 0.034, 0.042)]],
	[Color(0.05, 0.05, 0.05), [Vector3(-0.024, -0.003, 0.006), Vector3(-0.03, -0.004, 0.026), Vector3(-0.064, -0.01, 0.03)]],
	[Color(0.6, 0.5, 0.1), [Vector3(-0.012, -0.014, 0.006), Vector3(-0.016, -0.02, 0.024), Vector3(-0.04, -0.044, 0.022)]],
]
const CHIP_AT := Vector3(0.085, 0.045, -0.06)  # head frame: between the right ear and the right eye
## The skin of every part (assets/shaders/pig_skin.gdshader): the guns' coarse pixel noise and patches of dirt over
## the part's colour (owner, 2026-10-31).
const SKIN_SHADER := preload("res://assets/shaders/pig_skin.gdshader")
const PALETTE: Array[Color] = [
	Color(0.5, 0.29, 0.17), Color(0.24, 0.34, 0.42), Color(0.36, 0.28, 0.4),
	Color(0.33, 0.39, 0.22), Color(0.52, 0.44, 0.22), Color(0.45, 0.2, 0.19),
]

static var _materials := {}
static var _rim: ShaderMaterial  # readability rim (assets/shaders/player_rim.gdshader), set_rim
static var _rim_on := false
static var _faceted := {}  # shape key -> flat-shaded ArrayMesh (_facet)
## What tells the primitive shapes apart (a missing property reads as null), for the _facet cache key.
const FACET_KEY_PROPS := ["radius", "height", "radial_segments", "rings", "top_radius", "bottom_radius", "size",
		"inner_radius", "outer_radius", "ring_segments", "left_to_right", "cap_top", "cap_bottom", "is_hemisphere",
		"subdivide_width", "subdivide_height", "subdivide_depth"]

var pitch := 0.0      # aim pitch, radians, + = up
var reload := -1.0    # reload progress 0..1, -1 = not reloading
var melee := -1.0     # hoof punch progress 0..1, -1 = not punching
var mantle := 0.0     # 0..1: vaulting pose weight
var mantle_hands: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # world: left and right hand on the ledge
var mantle_top := Vector3.ZERO  # a world point at the height of the ledge's top
var ads := 0.0        # 0..1
var crouch := 0.0     # 0..1
var present := 0.0    # 0..1: the gun held across the chest, its side to the front (the build editor's BuildStage)
var weapon: WeaponView
var def: WeaponDef

var _parts := {}      # name -> MeshInstance3D / Node3D
var _right_arm: Dictionary
var _left_arm: Dictionary
var _ears: Array[Node3D] = []
var _reload_hand := Vector3.ZERO     # left hand target during a reload (gun view space)

# Locomotion state (animate), read by pose().
var _phase := 0.0                 # gait cycle, 0..1 (left foot lands at 0, the right one at 0.5)
var _move := 0.0                  # 0 = standing (planted feet), 1 = walking (gait)
var _dir := Vector3.FORWARD       # direction of travel (mannequin space, flat)
var _feet: Array[Vector3] = [STANCE_L, STANCE_R]  # foot positions on the ground (+ lift in y), mannequin space
var _foot_pitch: Array[float] = [0.0, 0.0]
var _plant: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # standing: where each foot stands (world)
var _step_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _step_t: Array[float] = [-1.0, -1.0]  # idle step progress 0..1, -1 = planted
var _planted := false
var _pelvis_offset := Vector3.ZERO  # bob and sway
var _twist := 0.0
var _prev_vel := Vector3.ZERO
var _lean := Vector2.ZERO           # x: about the right axis (+ = back), y: sideways (+ = to the right)
var _lean_v := Vector2.ZERO
var _ear := Vector2.ZERO            # ear flop: x = tips back, y = tips to the left
var _ear_v := Vector2.ZERO
var _tail_flop := Vector2.ZERO
var _tail_flop_v := Vector2.ZERO
var _last_head := Vector3.INF       # world, at the previous pose (for the ears)
var _head_vel := Vector3.ZERO       # world
var _joints := {}                   # joint name -> position (mannequin space) at the last pose; the ragdoll starts there
var _was_air := false
var _fall_speed := 0.0              # fastest fall of the current flight (m/s), for the landing
var _tuck := 0.0                    # 0 = legs on the ground, 1 = drawn up
var _slide := 0.0                   # 0..1: slide pose weight
var _land := 0.0                    # pelvis offset of the landing squat (m, <= 0)
var _land_v := 0.0
var _head_kick := Vector2.ZERO      # head snap of a hit: x = back, y = sideways (rad)
var _head_kick_v := Vector2.ZERO
var _jolt := 0.0                    # torso turn of a hit (rad about the vertical: the hit shoulder goes back)
var _jolt_v := 0.0
var _ragdoll: Ragdoll
var _ragdoll_parts: Array = []      # [part, frame index, relative transform] for the rigid parts


## Player colour for a peer (torso and shoulders), so players are easy to tell apart.
static func color_for(peer_id: int) -> Color:
	return PALETTE[absi(peer_id) % PALETTE.size()]


## Head centre over the feet in the mannequin's frame (x right, y up, -z forward). Used by the pose and by LagComp.
static func head_offset(aim_pitch: float, ads_amount: float, crouch_amount: float, lean := Vector2.ZERO) -> Vector3:
	var chest := chest_frame(aim_pitch, crouch_amount, lean)
	return chest * (Vector3(0.0, HEAD_UP, 0.0) + ADS_HEAD * ads_amount)


## The torso's frame: origin at the spine pivot, rotated by the aim pitch, the crouch lean and the run lean.
static func chest_frame(aim_pitch: float, crouch_amount: float, lean := Vector2.ZERO) -> Transform3D:
	var pelvis_y := lerpf(PELVIS_STAND, PELVIS_CROUCH, crouch_amount)
	var angle := aim_pitch * SPINE_SHARE - CROUCH_LEAN * crouch_amount + lean.x  # + tilts back (looking up)
	var basis := Basis(Vector3.BACK, -lean.y) * Basis(Vector3.RIGHT, angle)
	return Transform3D(basis, Vector3(0.0, pelvis_y + SPINE_PIVOT, 0.0))


## How far the torso leans when moving at `local_velocity` (x right, z backwards; m/s): forward with the speed,
## into a strafe. The hitbox (LagComp) leans by this too.
static func run_lean(local_velocity: Vector3) -> Vector2:
	var forward := -local_velocity.z
	return Vector2(-clampf(forward * LEAN_PER_SPEED, -LEAN_MAX * 0.5, LEAN_MAX),
			clampf(local_velocity.x * SIDE_LEAN_PER_SPEED, -SIDE_LEAN_MAX, SIDE_LEAN_MAX))


func build(accent: Color) -> void:
	_part("Pelvis", _capsule(0.14, 0.36), SUIT)
	_part("Torso", _capsule(0.2, 0.64), accent)
	_part("Neck", _capsule(0.05, 0.16), SKIN)
	_parts["Head"] = make_head(self)
	_ears = [_parts["Head"].get_node("EarL"), _parts["Head"].get_node("EarR")]
	_part("Tail", _tail(), SKIN)
	for side in ["L", "R"]:
		_part("Hip" + side, _sphere(0.085), SUIT)
		_part("Thigh" + side, _limb(0.085, 0.065, THIGH), SUIT)
		_part("Knee" + side, _sphere(0.066), SUIT)
		_part("Shin" + side, _limb(0.062, 0.045, SHIN), SUIT)
		# Trotter: bare skin from the trouser leg to the ground, two hoof toes pointing forward (cleft between them).
		_part("Foot" + side, _limb(0.048, 0.042, ANKLE_H), SKIN)
		for s in [-1.0, 1.0]:
			var toe := _attach(_parts["Foot" + side], _limb(0.036, 0.02, 0.12), HOOF, Vector3(0.027 * s, -0.008, -0.055))
			toe.rotation = Vector3(-PI * 0.5, 0.06 * s, 0.0)  # along -Z (forward), tips slightly apart
			toe.scale = Vector3(1.0, 1.0, 0.85)  # flatter than round
	_right_arm = make_arm(self, "R", accent)
	_left_arm = make_arm(self, "L", accent)
	(_parts["Torso"] as Node3D).scale = Vector3(1.0, 1.0, 0.7)  # a bit of a belly
	(_parts["Pelvis"] as Node3D).scale = Vector3(1.0, 1.0, 0.75)


## The head on its own (the sphere and the pig face), as every body has it; also the main menu's portrait (PigPortrait).
static func make_head(parent: Node3D) -> MeshInstance3D:
	var head := _new_part(parent, "Head", _sphere(HEAD_RADIUS), SKIN)
	_build_pig_face(head)
	return head


## The "Инженер"'s chip (PartDB.ENGINEER): a dark metal plate on the head between the right ear and the right eye,
## wires sticking out of it.
func set_chip(on: bool) -> void:
	var head: Node3D = _parts["Head"]
	var chip := head.get_node_or_null("Chip")
	if on and chip == null:
		var normal := CHIP_AT.normalized()
		chip = Node3D.new()
		chip.name = "Chip"
		chip.transform = Transform3D(Basis.looking_at(-normal), normal * HEAD_RADIUS)
		var box := BoxMesh.new()
		box.size = CHIP_SIZE
		var metal := StandardMaterial3D.new()
		metal.albedo_color = CHIP
		metal.metallic = 0.8  # sharp and dark: a softer plate catches the build screen's orange rim light as brown
		metal.roughness = 0.25
		metal.metallic_specular = 0.1
		var plate := MeshInstance3D.new()
		plate.mesh = box
		plate.material_override = metal
		chip.add_child(plate)
		for wire: Array in CHIP_WIRES:
			var rubber := StandardMaterial3D.new()
			rubber.albedo_color = wire[0]
			rubber.roughness = 0.6
			var points: Array = wire[1]
			for k in points.size() - 1:
				var from: Vector3 = points[k]
				var along: Vector3 = points[k + 1] - from
				var tube := CylinderMesh.new()
				tube.top_radius = 0.0022
				tube.bottom_radius = 0.0022
				tube.height = along.length() + 0.003  # overlap the bend
				tube.radial_segments = 6
				tube.rings = 1
				var segment := MeshInstance3D.new()
				segment.mesh = tube
				segment.material_override = rubber
				segment.transform = Transform3D(Basis(Quaternion(Vector3.UP, along.normalized())), from + along / 2)
				chip.add_child(segment)
		head.add_child(chip)
	elif not on and chip != null:
		chip.free()


## Anthropomorphic pig, mostly human: the head gets a snout, small dark eyes and floppy ears (cosmetic only - the head
## hitbox stays the HEAD_RADIUS sphere). Head frame: -Z forward.
static func _build_pig_face(head: Node3D) -> void:
	var snout := CylinderMesh.new()
	snout.top_radius = 0.05
	snout.bottom_radius = 0.056
	snout.height = 0.06
	snout.radial_segments = 6
	snout.rings = 0
	var snout_part := _attach(head, snout, SNOUT, Vector3(0.0, -0.025, -0.125))
	snout_part.rotation.x = -PI * 0.5  # cylinder axis along -Z, the wide end at the face
	snout_part.scale = Vector3(1.0, 1.0, 0.8)  # a bit flatter than round
	for s in [-1.0, 1.0]:
		var nostril := _attach(head, _sphere(0.011), VISOR, Vector3(0.018 * s, -0.025, -0.153))
		nostril.scale = Vector3(0.8, 1.3, 0.5)
		_attach(head, _sphere(0.014), VISOR, Vector3(0.042 * s, 0.035, -0.098))
		# The ear hangs from a pivot at its base, so it can flop (animate) without leaving the head.
		var ear := PrismMesh.new()
		ear.size = Vector3(0.075, 0.09, 0.016)
		var tilt := Basis.from_euler(Vector3(-1.05, 0.3 * s, -0.75 * s))  # tilted out, the tip flopping forward
		var base := tilt * Vector3(0.0, -ear.size.y * 0.5, 0.0)
		var pivot := Node3D.new()
		pivot.name = "EarL" if s < 0.0 else "EarR"
		pivot.position = Vector3(0.075 * s, 0.095, -0.02) + base
		head.add_child(pivot)
		var ear_part := _attach(pivot, ear, SNOUT, -base)
		ear_part.basis = tilt


## A small curly tail: a thin torus, placed on the back of the pelvis in pose().
static func _tail() -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.026
	mesh.outer_radius = 0.04
	mesh.rings = 7
	mesh.ring_segments = 4
	return mesh


## Advances the locomotion by `delta` (call every frame before pose()). `velocity`: the body's velocity in its own
## frame (x right, z backwards; m/s). Off the floor or sliding, the legs hold still (the gait phase stops).
func animate(delta: float, velocity: Vector3, on_floor := true, sliding := false) -> void:
	if delta <= 0.0 or _ragdoll != null:
		return
	delta = minf(delta, 0.05)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if speed > 0.1:
		_dir = flat / speed
	var walking := on_floor and not sliding
	var target_move := clampf((speed - 0.3) / 1.2, 0.0, 1.0) if walking else (_move if not on_floor else 0.0)
	_move = move_toward(_move, target_move, delta * 4.0)

	# Gait: the phase runs with the distance travelled, one cycle per stride, so a foot on the ground moves back
	# exactly as fast as the body moves forward (no sliding). duty = share of the cycle a foot is on the ground.
	var run := clampf((speed - 3.0) / 4.0, 0.0, 1.0)
	var stride := lerpf(STRIDE_WALK, STRIDE_RUN, run) * lerpf(1.0, 0.7, crouch)
	if walking:
		_phase = fposmod(_phase + speed * delta / stride, 1.0)
	var duty := lerpf(0.6, 0.42, run)
	var half := duty * stride * 0.5 * clampf(speed / 1.5, 0.0, 1.0)  # short steps when slow
	var lift := lerpf(LIFT_WALK, LIFT_RUN, run) * lerpf(1.0, 0.6, crouch) * clampf(speed / 2.0, 0.3, 1.0)
	var gait: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var gait_pitch: Array[float] = [0.0, 0.0]
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var p := fposmod(_phase + 0.5 * i, 1.0)
		var along: float
		var up := 0.0
		var out := 0.0
		if p < duty:
			along = lerpf(half, -half, p / duty)
		else:
			var q := (p - duty) / (1.0 - duty)
			along = lerpf(-half, half, smoothstep(0.0, 1.0, q))
			up = sin(q * PI) * lift
			out = sin(q * PI) * 0.03  # the swinging foot passes wide of the other one
			gait_pitch[i] = sin(q * TAU) * 0.6 * clampf(speed / 3.0, 0.0, 1.0)  # toes down at push-off, up to land
		gait[i] = Vector3((FOOT_X + out) * s, up, 0.0) + _dir * along

	# Standing: the feet stay where they stand in the world; one steps back under the body when it has turned or
	# drifted too far (one foot at a time, the one that lags most).
	var xf := global_transform
	var to_local := xf.affine_inverse()
	var stance: Array[Vector3] = [STANCE_L, STANCE_R]
	for i in 2:
		var home := xf * stance[i]
		if not _planted or _move > 0.95 or not on_floor or _slide > 0.05 or _plant[i].distance_to(home) > 1.5:
			_plant[i] = home
			_step_t[i] = -1.0
	_planted = true
	if _step_t[0] < 0.0 and _step_t[1] < 0.0:
		var lag := [_flat_distance(_plant[0], xf * stance[0]), _flat_distance(_plant[1], xf * stance[1])]
		var worst := 0 if lag[0] >= lag[1] else 1
		if lag[worst] > IDLE_STEP:
			_step_t[worst] = 0.0
			_step_from[worst] = _plant[worst]
	for i in 2:
		var idle := to_local * _plant[i]
		idle.y = 0.0
		if _step_t[i] >= 0.0:
			_step_t[i] = minf(_step_t[i] + delta / IDLE_STEP_TIME, 1.0)
			var t := smoothstep(0.0, 1.0, _step_t[i])
			idle = to_local * _step_from[i].lerp(xf * stance[i], t)
			idle.y = sin(_step_t[i] * PI) * IDLE_STEP_LIFT
			if _step_t[i] >= 1.0:
				_plant[i] = xf * stance[i]
				_step_t[i] = -1.0
		_feet[i] = idle.lerp(gait[i], _move)
		_foot_pitch[i] = gait_pitch[i] * _move

	# Jump and fall: the legs draw up while rising and reach down again for the ground as the fall gets faster; on
	# landing the pelvis sinks (harder falls deeper) and springs back, the body pitches forward, the ears bounce.
	var vy := velocity.y
	if not on_floor:
		if not _was_air and vy > 1.0:
			_lean_v.x -= 0.8  # takeoff: a forward pitch
		_fall_speed = maxf(_fall_speed, -vy)
		var tuck_target := 1.0 if vy > 0.0 else clampf(1.0 + vy / 6.0, 0.35, 1.0)
		_tuck = move_toward(_tuck, tuck_target, delta * 5.0)
	else:
		if _was_air:
			var impact := clampf(_fall_speed, 0.0, 12.0)
			_land_v -= 0.15 + impact * 0.12
			_lean_v.x -= impact * 0.12
			_ear_v.x -= impact * 0.6
			_tail_flop_v.x += impact * 0.5
			_fall_speed = 0.0
		_tuck = move_toward(_tuck, 0.0, delta * 10.0)
	_was_air = not on_floor
	var land := _spring(Vector2(_land, 0.0), Vector2(_land_v, 0.0), Vector2.ZERO, 3.0, 0.55, delta)
	_land = clampf(land[0].x, -LAND_DROP_MAX, 0.03)
	_land_v = land[1].x
	for i in 2:
		_feet[i].y += TUCK_HEIGHT * _tuck * (1.0 if i == 0 else 0.8)  # one leg a bit lower: less of a puppet
		_foot_pitch[i] += 0.5 * _tuck  # toes hang down

	# Slide: one leg out in front (toes up), the other folded under, the body leaning back; the feet ride along
	# with the body instead of stepping.
	_slide = move_toward(_slide, 1.0 if sliding and on_floor else 0.0, delta * 8.0)
	if _slide > 0.0:
		_feet[0] = _feet[0].lerp(SLIDE_LEAD, _slide)
		_feet[1] = _feet[1].lerp(SLIDE_TUCK, _slide)
		_foot_pitch[0] = lerpf(_foot_pitch[0], -0.6, _slide)
		_foot_pitch[1] = lerpf(_foot_pitch[1], 0.5, _slide)

	# Pelvis: drops at each footfall, sways over the foot on the ground (walking), turns with the forward leg.
	var bob := lerpf(BOB_WALK, BOB_RUN, run) * clampf(speed / 2.0, 0.0, 1.0)
	_pelvis_offset = Vector3(-0.02 * sin(TAU * _phase) * (1.0 - run),
			-bob * (0.5 + 0.5 * cos(2.0 * TAU * _phase)), 0.0) * _move
	_pelvis_offset.y = maxf(_pelvis_offset.y + _land, -PELVIS_DROP_MAX) - SLIDE_DROP * _slide
	_twist = TWIST * cos(TAU * _phase) * _dir.z * _move

	# Lean with the speed, plus (through a springy follow) with the acceleration: into a start, back when stopping.
	var accel := (flat - _prev_vel) / delta
	_prev_vel = flat
	var lean_target := run_lean(flat) + Vector2(clampf(accel.z * 0.012, -0.1, 0.1), clampf(accel.x * 0.006, -0.05, 0.05))
	lean_target = lean_target.lerp(Vector2(SLIDE_LEAN, 0.0), _slide)
	var lean := _spring(_lean, _lean_v, lean_target, 2.6, 0.45, delta)
	_lean = lean[0]
	_lean_v = lean[1]

	# Ears and tail lag behind the head's / body's motion on loose springs, so they flop with every step and stop.
	var head_local := to_local.basis * _head_vel
	var ear := _spring(_ear, _ear_v, Vector2(clampf(-head_local.z * 0.07 + head_local.y * 0.25, -0.3, 0.6),
			clampf(head_local.x * 0.08, -0.4, 0.4)), 3.5, 0.18, delta)
	_ear = ear[0]
	_ear_v = ear[1]
	var wag := sin(TAU * _phase * 2.0) * 0.35 * _move
	var tail := _spring(_tail_flop, _tail_flop_v, Vector2(clampf(-flat.z * 0.06, -0.3, 0.5) + _pelvis_offset.y * 6.0,
			wag + clampf(flat.x * 0.08, -0.4, 0.4)), 4.0, 0.2, delta)
	_tail_flop = tail[0]
	_tail_flop_v = tail[1]
	var kick := _spring(_head_kick, _head_kick_v, Vector2.ZERO, 4.5, 0.35, delta)
	_head_kick = kick[0]
	_head_kick_v = kick[1]
	var jolt := _spring(Vector2(_jolt, 0.0), Vector2(_jolt_v, 0.0), Vector2.ZERO, 3.2, 0.3, delta)
	_jolt = clampf(jolt[0].x, -0.5, 0.5)
	_jolt_v = jolt[1].x


## A bullet hit at `at` (world): the body jerks with the shot (`direction`: world direction the bullet flew) - the
## torso turns away from the hit side and rocks with the push, a head hit snaps the head back. Kicks springs, so
## several pellets add up but stay bounded. The turn hardly moves the head (it is above the spine's axis).
func flinch(direction: Vector3, head_hit: bool, at: Vector3) -> void:
	if _ragdoll != null:
		return
	var d := global_basis.inverse() * direction.normalized()
	var side := (global_transform.affine_inverse() * at).x
	if absf(side) < 0.05:
		side = 0.05 * (1.0 if randf() < 0.5 else -1.0)
	_jolt_v = clampf(_jolt_v - side * d.z * (12.0 if head_hit else 40.0), -9.0, 9.0)
	_lean_v += Vector2(d.z, d.x) * (1.2 if head_hit else 2.2)
	_lean_v = _lean_v.limit_length(4.0)
	_head_kick_v += Vector2(d.z, d.x) * (7.0 if head_hit else 2.0)
	_head_kick_v = _head_kick_v.limit_length(12.0)
	_ear_v += Vector2(d.z, -d.x) * 3.0


## Which part of the body a point (a shot's end, world) is on: "head", "body" or "" (missed it).
func hit_zone(world_pos: Vector3) -> String:
	if _parts["Head"].global_position.distance_to(world_pos) < LagComp.HEAD_RADIUS + 0.06:
		return "head"
	var local := global_transform.affine_inverse() * world_pos
	var axis := Vector2(local.x, local.z).length()
	if axis < LagComp.BODY_RADIUS + 0.08 and local.y > -0.1 and local.y < 1.6:
		return "body"
	return ""


## Poses the whole body (call every frame, after the weapon's owner has set pitch / ads / crouch, and animate()).
func pose() -> void:
	if _ragdoll != null:
		return
	var chest := chest_frame(pitch, crouch, _lean)
	chest.basis = Basis(Vector3.UP, _jolt) * Basis(Vector3.RIGHT, -0.15 * mantle) * chest.basis
	chest.origin += _pelvis_offset
	var pelvis := chest.origin - Vector3(0.0, SPINE_PIVOT, 0.0)
	var twist := Basis(Vector3.UP, _twist)
	_place(_parts["Pelvis"], Transform3D(twist * Basis(Vector3.FORWARD, PI * 0.5), pelvis))
	# Tail ring faces backwards (+Z), on the back of the pelvis; it flops up / down and wags.
	_place(_parts["Tail"], Transform3D(Basis(Vector3.UP, _tail_flop.y) * Basis(Vector3.RIGHT, PI * 0.5 + _tail_flop.x)
			.rotated(Vector3.FORWARD, 0.4), pelvis + twist * Vector3(_tail_flop.y * 0.02, 0.03, 0.135)))
	_place(_parts["Torso"], chest * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.2, 0.0)))
	var head := chest * (Vector3(0.0, HEAD_UP, 0.0) + ADS_HEAD * ads)
	var neck_base := chest * Vector3(0.0, SHOULDER_UP + 0.02, 0.0)
	_segment(_parts["Neck"], neck_base, head - Vector3(0.0, HEAD_RADIUS * 0.6, 0.0))
	# The head looks where the player aims (the torso took only part of the pitch).
	_place(_parts["Head"], Transform3D(Basis(Vector3.BACK, -_head_kick.y) * Basis(Vector3.RIGHT, pitch + _head_kick.x), head))
	for ear in _ears:
		ear.rotation = Vector3(_ear.x, 0.0, _ear.y)
	var head_world := global_transform * head
	if _last_head != Vector3.INF:
		var dt := get_process_delta_time()
		if dt > 0.0:
			_head_vel = _head_vel.lerp((head_world - _last_head) / dt, 0.5)
	_last_head = head_world
	_joints["pelvis"] = pelvis
	_joints["chest"] = neck_base
	_joints["head"] = head

	# Legs: two-bone IK from the hips (turned with the pelvis) to the feet; knees bend forward.
	for i in 2:
		var side := "L" if i == 0 else "R"
		var s := -1.0 if i == 0 else 1.0
		var hip := pelvis + twist * Vector3(HIP_X * s, -0.05, 0.0)
		var foot := _feet[i]
		if mantle > 0.0 and i == 0:
			# Vaulting: near the top the left knee comes up and the foot goes onto the ledge.
			var below := (mantle_top - global_position).dot(global_basis.y)
			var knee_up := mantle * smoothstep(1.0, 0.35, below)
			var ledge := global_transform.affine_inverse() * ((mantle_hands[0] + mantle_hands[1]) * 0.5)
			foot = foot.lerp(Vector3(-0.1, ledge.y, ledge.z + 0.1), knee_up)
		var ankle := Vector3(foot.x, foot.y + ANKLE_H, foot.z)
		var knee := two_bone(hip, ankle, THIGH, SHIN, Vector3(0.15 * s, 0.0, -1.0))
		_place(_parts["Hip" + side], Transform3D(Basis.IDENTITY, hip))
		_segment(_parts["Thigh" + side], hip, knee)
		_place(_parts["Knee" + side], Transform3D(Basis.IDENTITY, knee))
		_segment(_parts["Shin" + side], knee, ankle)
		_place(_parts["Foot" + side], Transform3D(Basis(Vector3.RIGHT, _foot_pitch[i]),
				Vector3(ankle.x, foot.y + ANKLE_H * 0.5, ankle.z)))
		_joints["hip" + side] = hip
		_joints["knee" + side] = knee
		_joints["ankle" + side] = ankle

	# Weapon: at the hip, or with the rear sight under the eye; blended by ads.
	var shoulder_r := chest * Vector3(SHOULDER_X, SHOULDER_UP, 0.0)
	var shoulder_l := chest * Vector3(-SHOULDER_X, SHOULDER_UP, 0.0)
	if weapon == null or def == null or not weapon.visible:
		return
	var aim := Basis(Vector3.RIGHT, pitch)
	var right_view := _view_point(weapon.lever_hand(def.right_hand))
	var hip_xform := Transform3D(aim, shoulder_r + aim * HIP_BUTT - aim * _view_point(BUTT))
	var eye := head + aim * EYE
	var rear_view := _view_point(def.rear_sight)
	var ads_xform := Transform3D(aim, eye + aim * Vector3(0.0, 0.0, -def.eye_relief) - aim * rear_view)
	var weapon_local := hip_xform.interpolate_with(ads_xform, ads)
	var left_view := _view_point(def.left_hand)
	if reload >= 0.0:
		weapon_local = _reload_pose(weapon_local, right_view, chest)
		left_view = _reload_hand
	else:
		weapon.set_mag_shift(Vector3.ZERO)
		weapon.set_break(-1.0)
		weapon.set_shell(-1.0)
		weapon.bolt_pull = 0.0
		var refill := weapon.refill_progress()
		if refill >= 0.0:
			left_view = refill_hand(refill, left_view, weapon_local.affine_inverse() * (chest * BANDOLIER))
	var punch := punch_curve(melee)
	if punch.y > 0.0:
		# Hoof punch: the gun swings out to the side and down about the butt (the stock stays at the shoulder), out of
		# the left hoof's way.
		var butt_point := weapon_local * _view_point(BUTT)
		var swing := Basis(Vector3.UP, -0.3 * punch.y) * Basis(Vector3.RIGHT, -0.35 * punch.y)
		weapon_local = Transform3D(swing, butt_point - swing * butt_point) * weapon_local
	if present > 0.0:
		# Shown: across the chest, the barrel up to the body's left, the gun's right side to the front.
		var tilt := Basis(Vector3(0.0, 0.0, -1.0), Vector3(sin(PRESENT_TILT), cos(PRESENT_TILT), 0.0),
				Vector3(cos(PRESENT_TILT), -sin(PRESENT_TILT), 0.0))
		var held := chest.basis * tilt
		var shown := Transform3D(held, chest * PRESENT_AT - held * ((right_view + left_view) * 0.5))
		weapon_local = weapon_local.interpolate_with(shown, present)
	var right_palm := weapon_local * right_view
	var left_palm := weapon_local * left_view
	var right_fingers := weapon_local.basis * RIGHT_FINGERS
	var right_dir := weapon_local.basis * RIGHT_PALM
	var left_fingers := weapon_local.basis * LEFT_FINGERS
	var left_dir := weapon_local.basis * LEFT_PALM
	if punch.y > 0.0:
		var fist := shoulder_l + aim * PUNCH_REACH
		left_palm = left_palm.lerp(fist, punch.x)
		left_fingers = left_fingers.lerp(aim * Vector3.FORWARD, punch.y)
		left_dir = left_dir.lerp(aim * Vector3.DOWN, punch.y)
	if mantle > 0.0:
		# Vaulting: the gun hangs at the right side, barrel down, both hands on the ledge pulling the body up.
		var slung := chest * Transform3D(Basis(Vector3.RIGHT, -1.3).rotated(Vector3.UP, 0.25),
				Vector3(SHOULDER_X + 0.08, -0.15, 0.02))
		slung = slung * Transform3D(Basis.IDENTITY, -right_view)
		weapon_local = weapon_local.interpolate_with(slung, mantle)
		var to_local := global_transform.affine_inverse()
		var ledge_dir := Vector3.FORWARD
		right_palm = right_palm.lerp(to_local * mantle_hands[1], mantle)
		left_palm = left_palm.lerp(to_local * mantle_hands[0], mantle)
		right_fingers = right_fingers.lerp(ledge_dir, mantle)
		left_fingers = left_fingers.lerp(ledge_dir, mantle)
		right_dir = right_dir.lerp(Vector3.DOWN, mantle)
		left_dir = left_dir.lerp(Vector3.DOWN, mantle)
	weapon.global_transform = global_transform * weapon_local
	pose_arm(_right_arm, shoulder_r, right_palm, right_fingers, right_dir, RIGHT_POLE)
	pose_arm(_left_arm, shoulder_l, left_palm, left_fingers, left_dir, LEFT_POLE)
	var butt := weapon_local * _view_point(BUTT)
	_joints["gun_butt"] = butt
	_joints["gun_muzzle"] = weapon_local * (_view_point(BUTT) + Vector3(0.0, 0.0, -0.55))
	_joints["gun_top"] = weapon_local * (_view_point(BUTT) + Vector3(0.0, 0.1, 0.0))


# --- death ------------------------------------------------------------------------------------------------------------

## Turns the body into a ragdoll from its current pose. `body_velocity`: the body's world velocity at death; `from`:
## the killer's position (world; INF if unknown - the body then just slumps backwards); `head_hit`: the head takes
## the blow.
func start_ragdoll(body_velocity: Vector3, from := Vector3.INF, head_hit := false) -> void:
	if _joints.is_empty():
		pose()
	var local := _ragdoll_rest_points()
	var xf := global_transform
	var points := PackedVector3Array()
	for p in local:
		points.append(xf * p)

	var back := xf.basis.z.normalized()
	var push := back
	var strength := 1.4
	if from.is_finite():
		var away := points[Ragdoll.CHEST] - from
		away.y = 0.0
		if away.length() > 0.01:
			push = away.normalized()
			strength = 3.2
	push = (push + Vector3.UP * 0.15).normalized() * strength
	var side := back.cross(Vector3.UP).normalized() * randf_range(-0.6, 0.6)  # a bit of a turn as it falls
	# How much of the blow each point takes: the upper body is thrown back, the knees buckle the other way, the feet
	# stay put - so it folds at the knees and falls away from the shooter.
	var share := {Ragdoll.HEAD: 1.7 if head_hit else 1.0, Ragdoll.CHEST: 1.0, Ragdoll.SHOULDER_L: 0.9,
			Ragdoll.SHOULDER_R: 0.9, Ragdoll.ELBOW_L: 0.7, Ragdoll.ELBOW_R: 0.7, Ragdoll.WRIST_L: 0.6,
			Ragdoll.WRIST_R: 0.6, Ragdoll.PELVIS: 0.4, Ragdoll.HIP_L: 0.35, Ragdoll.HIP_R: 0.35,
			Ragdoll.KNEE_L: -0.2, Ragdoll.KNEE_R: -0.2, Ragdoll.GUN_BUTT: 0.6, Ragdoll.GUN_MUZZLE: 0.6,
			Ragdoll.GUN_TOP: 0.6}
	var velocities := PackedVector3Array()
	for i in Ragdoll.COUNT:
		var v := body_velocity + push * float(share.get(i, 0.0))
		if i in [Ragdoll.HEAD, Ragdoll.CHEST, Ragdoll.SHOULDER_L, Ragdoll.SHOULDER_R]:
			v += side
		if i in [Ragdoll.KNEE_L, Ragdoll.KNEE_R]:
			v -= back * 0.9
		if i >= Ragdoll.GUN_BUTT:
			v += Vector3.UP * 0.5  # the gun drops out of the hands
		velocities.append(v)
	_ragdoll = Ragdoll.new(points, velocities, get_world_3d())
	var scenery := get_tree().get_first_node_in_group(TrainScenery.GROUP) as TrainScenery if is_inside_tree() else null
	if scenery != null:  # the train map: the ground beside the track rushes past
		_ragdoll.ground_velocity = scenery.ground_velocity()
		_ragdoll.ground_top = TrainScenery.GROUND_Y + 0.1

	# Rigid parts ride on the frame of the points they belong to (as they were placed at death).
	var frames := _ragdoll_frames(local)
	_ragdoll_parts = []
	var rigid := [[_parts["Pelvis"], 0], [_parts["Torso"], 0], [_parts["Tail"], 0], [_parts["HipL"], 0],
			[_parts["HipR"], 0], [_right_arm["shoulder"], 0], [_left_arm["shoulder"], 0], [_parts["Head"], 1],
			[_parts["FootL"], 2], [_parts["FootR"], 3], [_left_arm["hand"], 4], [_right_arm["hand"], 5]]
	for entry in rigid:
		var part: Node3D = entry[0]
		_ragdoll_parts.append([part, entry[1], frames[entry[1]].affine_inverse() * part.transform])
	if weapon != null:
		var weapon_local := xf.affine_inverse() * weapon.global_transform
		_ragdoll_parts.append([weapon, 6, frames[6].affine_inverse() * weapon_local])
	_pose_ragdoll()


func step_ragdoll(delta: float) -> void:
	if _ragdoll == null or _ragdoll.is_resting():
		return
	_ragdoll.step(delta)
	for point in _ragdoll.impacts:
		Dust.burst(self, point, 0.4)
	_ragdoll.impacts.clear()
	_pose_ragdoll()


func stop_ragdoll() -> void:
	_ragdoll = null
	_ragdoll_parts = []
	_planted = false
	_last_head = Vector3.INF
	_head_vel = Vector3.ZERO


func is_ragdoll() -> bool:
	return _ragdoll != null


## The visible part closest to `world_pos` (to stick something on the body so it falls with it).
func part_near(world_pos: Vector3) -> Node3D:
	var best: Node3D = self
	var best_distance := INF
	for part in [_parts["Head"], _parts["Torso"], _parts["Pelvis"], _parts["ThighL"], _parts["ThighR"],
			_parts["ShinL"], _parts["ShinR"], _right_arm["upper_mesh"], _left_arm["upper_mesh"],
			_right_arm["fore_mesh"], _left_arm["fore_mesh"]]:
		var distance := (part as Node3D).global_position.distance_to(world_pos)
		if distance < best_distance:
			best_distance = distance
			best = part
	return best


## The joints of the last pose (mannequin space), in Ragdoll's point order.
func _ragdoll_rest_points() -> PackedVector3Array:
	var chest: Vector3 = _joints["chest"]
	var points := PackedVector3Array([_joints["pelvis"], chest, _joints["head"], _joints["hipL"], _joints["kneeL"],
			_joints["ankleL"], _joints["hipR"], _joints["kneeR"], _joints["ankleR"]])
	for arm in [_left_arm, _right_arm]:
		points.append((arm["shoulder"] as Node3D).position)
		points.append((arm["elbow"] as Node3D).position)
		points.append((arm["hand"] as Node3D).position)
	var front := Vector3(0.15, -0.2, -0.3)  # no gun held (not posed yet): one in front of the chest
	points.append(_joints.get("gun_butt", chest + front))
	points.append(_joints.get("gun_muzzle", chest + front + Vector3(0.0, 0.0, -0.55)))
	points.append(_joints.get("gun_top", chest + front + Vector3.UP * 0.1))
	return points


## Frames the rigid parts ride on: torso, head, feet, hands, gun (built from the points; any space).
static func _ragdoll_frames(p: PackedVector3Array) -> Array[Transform3D]:
	var across := p[Ragdoll.SHOULDER_R] - p[Ragdoll.SHOULDER_L]
	var hips := p[Ragdoll.HIP_R] - p[Ragdoll.HIP_L]
	return [
		_frame(p[Ragdoll.PELVIS], p[Ragdoll.PELVIS], p[Ragdoll.CHEST], across),
		_frame(p[Ragdoll.HEAD], p[Ragdoll.CHEST], p[Ragdoll.HEAD], across),
		_frame(p[Ragdoll.ANKLE_L], p[Ragdoll.ANKLE_L], p[Ragdoll.KNEE_L], hips),
		_frame(p[Ragdoll.ANKLE_R], p[Ragdoll.ANKLE_R], p[Ragdoll.KNEE_R], hips),
		_frame(p[Ragdoll.WRIST_L], p[Ragdoll.ELBOW_L], p[Ragdoll.WRIST_L], across),
		_frame(p[Ragdoll.WRIST_R], p[Ragdoll.ELBOW_R], p[Ragdoll.WRIST_R], across),
		_frame(p[Ragdoll.GUN_BUTT], p[Ragdoll.GUN_BUTT], p[Ragdoll.GUN_TOP], p[Ragdoll.GUN_MUZZLE] - p[Ragdoll.GUN_BUTT]),
	]


## A frame at `origin` whose Y runs from `a` to `b`, with X as close to `x_hint` as it can be.
static func _frame(origin: Vector3, a: Vector3, b: Vector3, x_hint: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var z := x_hint.cross(y)
	if z.length() < 0.0001:
		z = Vector3.BACK.cross(y) if absf(y.z) < 0.9 else Vector3.RIGHT.cross(y)
	z = z.normalized()
	return Transform3D(Basis(y.cross(z), y, z), origin)


## Places every part on the ragdoll's points.
func _pose_ragdoll() -> void:
	var to_local := global_transform.affine_inverse()
	var p := PackedVector3Array()
	for point in _ragdoll.pos:
		p.append(to_local * point)
	var frames := _ragdoll_frames(p)
	for entry in _ragdoll_parts:
		var xform: Transform3D = frames[entry[1]] * entry[2]
		if entry[0] == weapon:
			weapon.global_transform = global_transform * xform
		else:
			(entry[0] as Node3D).transform = xform
	var head_dir := (p[Ragdoll.HEAD] - p[Ragdoll.CHEST]).normalized()
	_segment(_parts["Neck"], p[Ragdoll.CHEST], p[Ragdoll.HEAD] - head_dir * HEAD_RADIUS * 0.6)
	for leg in [["L", Ragdoll.HIP_L, Ragdoll.KNEE_L, Ragdoll.ANKLE_L], ["R", Ragdoll.HIP_R, Ragdoll.KNEE_R, Ragdoll.ANKLE_R]]:
		_segment(_parts["Thigh" + leg[0]], p[leg[1]], p[leg[2]])
		_place(_parts["Knee" + leg[0]], Transform3D(Basis.IDENTITY, p[leg[2]]))
		_segment(_parts["Shin" + leg[0]], p[leg[2]], p[leg[3]])
	for arm in [[_left_arm, Ragdoll.SHOULDER_L, Ragdoll.ELBOW_L, Ragdoll.WRIST_L],
			[_right_arm, Ragdoll.SHOULDER_R, Ragdoll.ELBOW_R, Ragdoll.WRIST_R]]:
		var parts: Dictionary = arm[0]
		_segment(parts["upper_mesh"], p[arm[1]], p[arm[2]])
		_place(parts["elbow"], Transform3D(Basis.IDENTITY, p[arm[2]]))
		_segment(parts["fore_mesh"], p[arm[2]], p[arm[3]])


## Reload (`reload` 0..1): the gun cants and dips about the right hand; the left hand goes to the magazine, pulls it
## out, takes it down to a pouch on the belt and back (the "new" one), seats it and returns to the handguard. The
## magazine rides the hand while it is held. Returns the gun's pose; the left hand's target (gun view space) is left
## in _reload_hand. Guns without a magazine just cant and dip.
func _reload_pose(weapon_local: Transform3D, grip: Vector3, chest: Transform3D) -> Transform3D:
	var r := reload
	var env := smoothstep(0.0, 0.12, r) * (1.0 - smoothstep(0.86, 1.0, r))
	if weapon.loads_shells():
		env = smoothstep(0.0, 1.0, weapon.load_blend)  # one reload a shell: the pose holds through all of them
	weapon.bolt_pull = reload_bolt_pull(r)
	var tilt := Transform3D(Basis.from_euler(Vector3(-0.3 * env, 0.0, 0.6 * env)), Vector3(-0.03, -0.06, 0.08) * env)
	if weapon.tips_mag():  # muzzle up, down off the cheek and out: the magazine slides back past the face, not through it
		tilt = Transform3D(Basis.from_euler(Vector3(0.35 * env, 0.0, 0.4 * env)), Vector3(-0.02, -0.12, -0.08) * env)
	weapon_local = weapon_local * Transform3D(Basis.IDENTITY, grip) * tilt * Transform3D(Basis.IDENTITY, -grip)
	var handguard := _view_point(def.left_hand)
	_reload_hand = handguard
	if weapon.loads_shells():
		var pouch_shells := weapon_local.affine_inverse() * (chest * Vector3(-0.15, -0.32, -0.14))
		var with_shell := shell_hand(r, weapon, handguard, pouch_shells, 1.0)
		_reload_hand = with_shell[0]
		weapon.set_shell(r, with_shell[1])
		return weapon_local
	if weapon.breaks_open():
		var hold := break_hand(r, weapon, handguard, 1.0)
		_reload_hand = hold[0]
		weapon.set_break(r, hold[1])
		return weapon_local
	var pouch := weapon_local.affine_inverse() * (chest * Vector3(-0.15, -0.32, -0.14))
	var handle := _view_point(def.charging_handle) if def.charging_handle.is_finite() else Vector3.INF
	if weapon.tips_mag():
		var tipped := tip_mag_hand(r, weapon, handguard, pouch, handle, 1.0)
		_reload_hand = tipped[0]
		weapon.set_mag_tip(tipped[1], tipped[2], tipped[3])
		return weapon_local
	var mag_grip := weapon.mag_grip_point()
	if not mag_grip.is_finite():
		return weapon_local
	var seated := _view_point(mag_grip)
	var path := reload_hand(r, handguard, seated, pouch, handle, 1.0)
	_reload_hand = path[0]
	weapon.set_mag_shift(_view_point(_reload_hand - seated) if path[1] else Vector3.ZERO)
	return weapon_local


## Hoof punch at progress `m` (-1: none): x = how far the left hoof is out (0 at the gun, 1 at full reach; a short
## pull-back first), y = how far the gun is swung aside. The blow lands at PUNCH_HIT - the moment the server judges it
## (WeaponSim.MELEE_WINDUP) - so the hoof arrives together with the hit. Shared with the first-person arms.
static func punch_curve(m: float) -> Vector2:
	if m < 0.0:
		return Vector2.ZERO
	var hit := WeaponSim.MELEE_WINDUP / (WeaponSim.MELEE_WINDUP + WeaponSim.MELEE_RECOVER)
	var out := 0.0
	if m < hit * 0.4:
		out = -0.2 * smoothstep(0.0, hit * 0.4, m)
	elif m < hit:
		out = lerpf(-0.2, 1.0, smoothstep(hit * 0.4, hit, m))
	elif m < hit + 0.12:
		out = 1.0
	else:
		out = 1.0 - smoothstep(hit + 0.12, 0.8, m)
	var aside := smoothstep(0.0, hit * 0.6, m) * (1.0 - smoothstep(0.7, 1.0, m))
	return Vector2(out, aside)


## The left hand's path through a reload (`r` 0..1), in gun view space - shared by the third-person body and the
## first-person arms: grab the magazine, pull it out, take it down to the pouch and come back with the "new" one,
## seat it, reach over to rack the charging handle (if the gun has one), back to the handguard. `scale`: the gun's
## drawn scale (first-person guns are smaller). Returns [hand position, whether it holds the magazine].
static func reload_hand(r: float, handguard: Vector3, seated: Vector3, pouch: Vector3, handle: Vector3,
		scale: float) -> Array:
	var pulled := seated + Vector3(0.0, -0.22, 0.04) * scale
	var keys := [[0.0, handguard], [0.12, seated], [0.28, pulled], [0.4, pouch], [0.52, pouch], [0.64, pulled],
			[0.74, seated]]
	if handle.is_finite():
		var grab := handle + Vector3(0.0, 0.02, 0.0) * scale  # fingers over the handle from above
		keys.append_array([[0.8, grab], [0.88, grab + Vector3(0.0, 0.0, 0.07) * scale], [0.97, handguard]])
	else:
		keys.append([0.9, handguard])
	var hand: Vector3 = handguard
	for i in keys.size() - 1:
		if r >= keys[i][0] and r < keys[i + 1][0]:
			var t := smoothstep(0.0, 1.0, (r - keys[i][0]) / (keys[i + 1][0] - keys[i][0]))
			hand = (keys[i][1] as Vector3).lerp(keys[i + 1][1], t)
			break
	return [hand, r >= 0.12 and r < 0.74]


## A magazine on top's reload (P90; `r` 0..1), the left hand in gun view space - shared as reload_hand: over the
## magazine, tips its back up off the catch and slides it back off the gun, down to the pouch and back with the "new"
## one, slides it forward under the catch, presses its back down, racks the cocking knob, back. `scale`: the gun's
## drawn scale. Returns [hand position, the magazine's tip, slide, shift] (WeaponView.set_mag_tip).
static func tip_mag_hand(r: float, weapon: WeaponView, rest: Vector3, pouch: Vector3, handle: Vector3,
		scale: float) -> Array:
	var tip := smoothstep(0.08, 0.15, r) * (1.0 - smoothstep(0.66, 0.72, r))
	var slide := WeaponView.MAG_SLIDE * (smoothstep(0.15, 0.27, r) if r < 0.4 else 1.0 - smoothstep(0.58, 0.66, r))
	var on_mag := _view_point(weapon.mag_tip_grip(tip, slide)) * scale  # rides the magazine as it tips and slides
	var off := _view_point(weapon.mag_tip_grip(1.0, WeaponView.MAG_SLIDE)) * scale
	var keys := [[0.0, rest], [0.08, on_mag], [0.27, off], [0.38, pouch], [0.48, pouch], [0.58, off], [0.72, on_mag]]
	if handle.is_finite():
		var grab := handle + Vector3(0.0, 0.02, 0.0) * scale
		keys.append_array([[0.8, grab], [0.88, grab + Vector3(0.0, 0.0, 0.07) * scale], [0.97, rest]])
	else:
		keys.append([0.9, rest])
	var hand: Vector3 = rest
	if (r >= 0.08 and r < 0.27) or (r >= 0.58 and r < 0.72):
		hand = on_mag
	else:
		for i in keys.size() - 1:
			if r >= keys[i][0] and r < keys[i + 1][0]:
				var t := smoothstep(0.0, 1.0, (r - keys[i][0]) / (keys[i + 1][0] - keys[i][0]))
				hand = (keys[i][1] as Vector3).lerp(keys[i + 1][1], t)
				break
	var carried := _view_point((hand - off) / scale) if r >= 0.27 and r < 0.58 else Vector3.ZERO
	return [hand, tip, slide, carried]


## A break-open's reload (`r` 0..1), the left hand in gun view space - shared as reload_hand: the right hand opens it
## (WeaponView.break_open, the case kicks itself out) while the left, the next round already between its fingers,
## goes from the fore-end to the breech, thumbs the round in and back to its hold; the right wrist flicks the barrel
## shut. `scale`: the gun's drawn scale. Returns [hand position, the round's shift (WeaponView.set_break: ZERO when
## the hand is empty)]. The hand then fetches the next round: refill_hand.
static func break_hand(r: float, weapon: WeaponView, rest: Vector3, scale: float) -> Array:
	var open := WeaponView.break_open(r)
	var seated := _view_point(weapon.round_grip_point(0.0, open)) * scale
	var loading := _view_point(weapon.round_grip_point(0.05, open)) * scale
	var keys := [[0.0, rest], [0.24, loading], [0.38, seated], [0.42, seated], [0.66, rest], [1.0, rest]]
	var hand: Vector3 = rest
	for i in keys.size() - 1:
		if r >= keys[i][0] and r < keys[i + 1][0]:
			var t := smoothstep(0.0, 1.0, (r - keys[i][0]) / (keys[i + 1][0] - keys[i][0]))
			hand = (keys[i][1] as Vector3).lerp(keys[i + 1][1], t)
			break
	var holds := r >= WeaponView.EJECT_AT and r < 0.38
	return [hand, _view_point((hand - seated) / scale) if holds else Vector3.ZERO]


## After a break-open's reload (`t` 0..1, WeaponView.refill_progress): the left hand off its hold to the bandolier
## (`bandolier`, gun view space), plucks the next round to hold between its fingers, and back.
static func refill_hand(t: float, rest: Vector3, bandolier: Vector3) -> Vector3:
	if t < 0.45:
		return rest.lerp(bandolier, smoothstep(0.0, 0.45, t))
	return bandolier.lerp(rest, smoothstep(0.55, 1.0, t))


## A lever action's loading, one shell (`r` 0..1), the left hand in gun view space - shared as reload_hand: off the
## fore-end down to the pouch, up with a shell, thumbs it down into the open action's top, back. `scale`: the gun's
## drawn scale. Returns [hand position, the shell's shift (WeaponView.set_shell: INF when the hand is empty)].
static func shell_hand(r: float, weapon: WeaponView, rest: Vector3, pouch: Vector3, scale: float) -> Array:
	var seated := _view_point(weapon.shell_grip_point()) * scale
	var above := seated + Vector3(0.0, 0.05, 0.0) * scale
	var keys := [[0.0, rest], [0.25, pouch], [0.35, pouch], [0.62, above], [0.8, seated], [1.0, rest]]
	var hand: Vector3 = rest
	for i in keys.size() - 1:
		if r >= keys[i][0] and r < keys[i + 1][0]:
			var t := smoothstep(0.0, 1.0, (r - keys[i][0]) / (keys[i + 1][0] - keys[i][0]))
			hand = (keys[i][1] as Vector3).lerp(keys[i + 1][1], t)
			break
	var holds := r >= 0.35 and r < 0.8
	return [hand, _view_point((hand - seated) / scale) if holds else Vector3.INF]


## How far the charging handle is held back at reload progress `r` (the hand racks it in reload_hand, 0.8-0.88).
static func reload_bolt_pull(r: float) -> float:
	if r < 0.0:
		return 0.0
	return smoothstep(0.8, 0.88, r) * (1.0 - smoothstep(0.88, 0.9, r))


## Damped spring step: `x` follows `target` with natural frequency `freq` (Hz) and damping ratio `damping` (< 1
## overshoots and wobbles). Returns [x, velocity]. Implicit (backward) Euler: stable at any frame time - the explicit
## step blew up on long frames (a hitch), the oscillation growing every frame until the view spun around.
static func spring(x: Vector2, v: Vector2, target: Vector2, freq: float, damping: float, dt: float) -> Array:
	var w := TAU * freq
	v = (v + (target - x) * (w * w * dt)) / (1.0 + 2.0 * damping * w * dt + w * w * dt * dt)
	return [x + v * dt, v]


static func _spring(x: Vector2, v: Vector2, target: Vector2, freq: float, damping: float, dt: float) -> Array:
	return spring(x, v, target, freq, damping, dt)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Prefab space (barrel +Z) -> weapon view space (barrel -Z), as WeaponView turns the model.
static func _view_point(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, -p.z)


# --- arms (shared with the first-person arms) ---------------------------------------------------------------------------

## Builds an arm's parts under `parent`; returns the parts for pose_arm. `length_scale` lengthens the bones
## (first-person arms are always "too long").
static func make_arm(parent: Node3D, side: String, accent: Color, length_scale: float = 1.0, thickness: float = 1.0) -> Dictionary:
	var arm := {"side": side, "upper": UPPER_ARM * length_scale, "fore": FOREARM * length_scale}
	arm["shoulder"] = _new_part(parent, "Shoulder" + side, _sphere(0.075 * thickness), accent)
	arm["upper_mesh"] = _new_part(parent, "UpperArm" + side, _limb(0.058 * thickness, 0.046 * thickness, arm["upper"]), SUIT)
	arm["elbow"] = _new_part(parent, "Elbow" + side, _sphere(0.047 * thickness), SUIT)
	arm["fore_mesh"] = _new_part(parent, "Forearm" + side, _limb(0.045 * thickness, 0.033 * thickness, arm["fore"]), SUIT)
	var hand := Node3D.new()
	hand.name = "Hand" + side
	parent.add_child(hand)
	arm["hand"] = hand
	# Hand frame: origin at the wrist, +Y along the fingers, +Z out of the palm. A pig's trotter: a bit of bare skin
	# out of the sleeve, then two hoof toes curled a little towards the palm, round the grip.
	_attach(hand, _limb(0.036, 0.032, 0.05), SKIN, Vector3(0.0, 0.025, 0.0))
	for s in [-1.0, 1.0]:
		var toe := _attach(hand, _limb(0.024, 0.013, 0.07), HOOF, Vector3(0.019 * s, 0.08, 0.008))
		toe.rotation = Vector3(0.35, 0.0, -0.08 * s)  # curled in, the two toes splayed apart (the cleft)
		toe.scale = Vector3(1.0, 1.0, 1.3)  # a bit deeper than wide, like a hoof
	return arm


## Poses an arm (all in the parent's space): two-bone IK from `shoulder` so the palm reaches `palm`, then the hand
## turns so its fingers run along `fingers` with the palm facing `palm_dir`; the elbow points towards `pole`.
static func pose_arm(arm: Dictionary, shoulder: Vector3, palm: Vector3, fingers: Vector3, palm_dir: Vector3, pole: Vector3) -> void:
	var f := fingers.normalized()
	var p := (palm_dir - f * palm_dir.dot(f)).normalized()
	var wrist := palm - f * WRIST_TO_PALM
	var elbow := two_bone(shoulder, wrist, arm["upper"], arm["fore"], pole)
	var reached := elbow + (wrist - elbow).normalized() * float(arm["fore"])
	_place(arm["shoulder"], Transform3D(Basis.IDENTITY, shoulder))
	_segment(arm["upper_mesh"], shoulder, elbow)
	_place(arm["elbow"], Transform3D(Basis.IDENTITY, elbow))
	_segment(arm["fore_mesh"], elbow, reached)
	var hand: Node3D = arm["hand"]
	hand.transform = Transform3D(Basis(f.cross(p).normalized(), f, p), reached)


## Middle joint of a two-bone chain from `root` towards `target` (clamped to reach), bending towards `pole`.
static func two_bone(root: Vector3, target: Vector3, a: float, b: float, pole: Vector3) -> Vector3:
	var to_target := target - root
	var dist := clampf(to_target.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := to_target.normalized() if to_target.length() > 0.0001 else Vector3.DOWN
	var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var bend := pole - dir * pole.dot(dir)
	bend = bend.normalized() if bend.length() > 0.0001 else Vector3.FORWARD
	return root + dir * (a * cos_a) + bend * (a * sqrt(1.0 - cos_a * cos_a))


# --- parts ------------------------------------------------------------------------------------------------------------

func _part(part_name: String, mesh: Mesh, color: Color) -> void:
	_parts[part_name] = _new_part(self, part_name, mesh, color)


static func _new_part(parent: Node3D, part_name: String, mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = _facet(mesh)
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


static func _attach(parent: Node3D, mesh: Mesh, color: Color, offset: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _facet(mesh)
	instance.material_override = _material(color)
	instance.position = offset
	parent.add_child(instance)
	return instance


## Places a capsule part so it spans from `a` to `b` (its axis is local Y), keeping its scale.
static func _segment(part: Node3D, a: Vector3, b: Vector3) -> void:
	var y := b - a
	if y.length() < 0.0001:
		return
	y = y.normalized()
	var x := Vector3.FORWARD.cross(y)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	_place(part, Transform3D(Basis(x, y, z), (a + b) * 0.5))


static func _place(part: Node3D, xform: Transform3D) -> void:
	var s := part.scale
	part.transform = xform
	part.scale = s


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh


## A limb segment: a cylinder tapering from `proximal` to `distal` radius along local Y (from -Y to +Y, i.e. from
## the joint it hangs from towards the next one); the joints are spheres placed separately.
static func _limb(proximal: float, distal: float, length: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = proximal
	mesh.top_radius = distal
	mesh.height = length
	mesh.radial_segments = 5
	mesh.rings = 0
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.2
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh


## SUPERHOT-style low poly: the primitives above have few segments, and every face gets its own normal (flat
## shading), so the body reads as crisp facets instead of smooth capsules. Every body is built from the same few
## shapes, so the results are shared (_faceted): rebuilding them made each new body cost tens of ms (a hitch).
static func _facet(mesh: Mesh) -> Mesh:
	var key := mesh.get_class()
	for prop in FACET_KEY_PROPS:
		key += "|%s" % str(mesh.get(prop))
	if not _faceted.has(key):
		_faceted[key] = _build_facets(mesh)
	return _faceted[key]


static func _build_facets(mesh: Mesh) -> Mesh:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		indices = PackedInt32Array(range(verts.size()))
	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	for i in range(0, indices.size() - 2, 3):
		var a := verts[indices[i]]
		var b := verts[indices[i + 1]]
		var c := verts[indices[i + 2]]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue  # degenerate (capsule / sphere poles)
		n = n.normalized()
		# Keep the primitive's outward side, whatever the winding convention.
		if n.dot(normals[indices[i]] + normals[indices[i + 1]] + normals[indices[i + 2]]) < 0.0:
			n = -n
		for v in [a, b, c]:
			out_verts.append(v)
			out_normals.append(n)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_verts
	out[Mesh.ARRAY_NORMAL] = out_normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return result


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## The PSX mood's readability rim on every body part (Mood): a faint glow on the silhouette's edges.
static func set_rim(on: bool) -> void:
	if on and _rim == null:
		_rim = ShaderMaterial.new()
		_rim.shader = load("res://assets/shaders/player_rim.gdshader")
	_rim_on = on
	for material in _materials.values():
		(material as Material).next_pass = _rim if on else null


## A part's material: its colour under the skin texture (SKIN_SHADER) - matte, dirty; the eyes and nostrils (VISOR)
## wet-looking and clean.
static func _material(color: Color) -> ShaderMaterial:
	if not _materials.has(color):
		var wet := color == VISOR
		var grain: Array = WeaponSkin.noise("skin")
		var material := ShaderMaterial.new()
		material.shader = SKIN_SHADER
		material.set_shader_parameter("grain", grain[0])
		material.set_shader_parameter("gain", 1.0 / grain[1])
		material.set_shader_parameter("dirt_noise", WeaponSkin.noise("dirt")[0])
		material.set_shader_parameter("tint", color)
		material.set_shader_parameter("dirt_amount", 0.0 if wet else 0.55)
		material.set_shader_parameter("roughness_value", 0.35 if wet else 0.92)
		material.set_shader_parameter("specular_value", 0.5 if wet else 0.3)
		material.next_pass = _rim if _rim_on else null
		_materials[color] = material
	return _materials[color]
