class_name OnAir
extends Node
## The gigachurch's broadcast (Docs/LEVEL_GIGACHURCH.md, "Эфир"). The star of the show - world.on_air_id,
## the top of the table, picked by the server (NetWorld._server_pick_star) - is followed by the studio
## cameras, a spot light and the screens. Pure client cosmetics: every machine aims the same props at the
## same star from the same snapshots, nothing is sent for it; bots ignore it, their tests' landmarks stay.
##
## The cameras track the star's body (a dead one too: the show goes on), turning at CAM_SPEED - they
## "strive", they do not snap. The camera with the line of sight is live: its red tally burns, and the feed -
## one SubViewport, FEED_RES, from the live camera's pose - shows on every little TV around the level (owner,
## 2026-11-18: many small screens instead of one big one), rendered only while some TV is near and in view.
## No line of sight from anywhere - the star is backstage: the cameras fall into a slow sweep search, the
## screens dim. Before the first kill the show is off: the screens hold their own colour, the cameras settle
## to their bases. The big screens' tint is the star's zone colour: the colour answers "where", the tally
## and the beam answer "is the show on".
##
## Test hook: ON_AIR_STAR=20 (env) forces the star for the shot tools (the puppet, control=2).

const CAM_SPEED := 2.5        # 1/s of the angle to the star the cameras close (slow: they strive)
const SWEEP_WOBBLE := 1.2     # rad the search sweep swings either side of a camera's base
const FEED_RES := Vector2i(480, 270)
const FEED_RANGE := 45.0      # m: farther than this from the local camera the feed stops rendering
const SPOT := Vector3(25.0, 17.0, 0.0)   # the crossing dome: where the follow spot hangs
const SCREEN_BASE := Color(0.10, 0.10, 0.11)   # the stage screen's own colour, off air
const NO_SIGNAL := Color(0.16, 0.20, 0.30)     # the star is lost to the cameras

## The big screens all over the level (owner, 2026-11-18: the little TVs were too small - these are 3-4x the
## size - and the central screen wall is gone): (position, yaw - where the screen face looks, size in m).
## The transept's arms, the west facade flanking the rose (seen from the whole nave), the narthex, the stage's
## side walls, the backstage, and the chapel piers between the windows. No bodies: pure visuals.
const TVS := [
	[Vector3(25.0, 5.0, -23.6), 0.0, Vector2(4.5, 3.0)], [Vector3(25.0, 5.0, 23.6), PI, Vector2(4.5, 3.0)],
	[Vector3(-49.6, 9.0, -8.0), PI / 2, Vector2(4.5, 3.0)], [Vector3(-49.6, 9.0, 8.0), PI / 2, Vector2(4.5, 3.0)],
	[Vector3(-46.0, 4.0, -17.6), 0.0, Vector2(4.5, 3.0)], [Vector3(-46.0, 4.0, 17.6), PI, Vector2(4.5, 3.0)],
	[Vector3(44.0, 6.0, -8.6), 0.0, Vector2(4.5, 3.0)], [Vector3(44.0, 6.0, 8.6), PI, Vector2(4.5, 3.0)],
	[Vector3(46.4, 4.5, -5.5), PI / 2, Vector2(4.5, 3.0)], [Vector3(46.4, 4.5, 5.5), PI / 2, Vector2(4.5, 3.0)],
	[Vector3(-36.0, 4.0, -26.6), 0.0, Vector2(3.6, 2.4)], [Vector3(-24.0, 4.0, 26.6), PI, Vector2(3.6, 2.4)],
]

## Studio cameras: (position, base yaw). High and out of the way; no bodies, the navmesh ignores them.
const CAMS := [
	[Vector3(-7.15, 9.2, -10.6), 0.0],   # the x -8 column's face, north (the studio wall is gone, 2026-11-18)
	[Vector3(-7.15, 9.2, 10.6), 0.0],    # the x -8 column's face, south
	[Vector3(-40.0, 12.6, -10.6), 0.0],   # the nave's west end, north arcade
	[Vector3(16.0, 12.6, 10.6), PI],      # the nave's east end, south arcade
	[Vector3(25.0, 18.2, -4.6), 0.0],     # the crossing's dome ring, north
	[Vector3(42.0, 12.9, -6.0), PI],      # the stage truss, north
	[Vector3(42.0, 12.9, 6.0), PI],       # the stage truss, south
	[Vector3(-47.5, 8.2, 0.0), 0.0],      # the organ loft
]

var _world: Node                    # NetWorld of the level scene (untyped: its class would not compile here first)
var _cam_root: Array[Node3D] = []
var _cam_base: Array[float] = []
var _cam_yaw: Array[float] = []
var _cam_pitch: Array[float] = []
var _cam_tally: Array[StandardMaterial3D] = []
var _spot: SpotLight3D
var _spot_look := SPOT + Vector3.DOWN * 10.0
var _screen: Block
var _feed: SubViewport
var _feed_cam: Camera3D
var _feed_quads: Array[MeshInstance3D] = []
var _sweep := 0.0
var _feed_on := false


func _ready() -> void:
	_world = get_parent().get_node_or_null("World")
	var forced := OS.get_environment("ON_AIR_STAR")  # the shot tools: aim at a puppet
	if forced != "" and _world != null:
		_world.on_air_id = int(forced)
	if DisplayServer.get_name() == "headless" or _world == null:
		set_process(false)  # a dedicated server runs no cosmetics
		return
	_build_props()


func _process(delta: float) -> void:
	var star := _world.players.get(_world.on_air_id) as Node3D
	if star == null:
		_off_air(delta)
		return
	var aim := star.global_position + Vector3.UP * 1.1
	var live := _live_camera(aim)
	for i in _cam_root.size():
		if live >= 0:
			_aim(i, aim, delta)
		else:
			_sweep += delta
			_cam_root[i].rotation.y = _cam_base[i] + sin(_sweep * 0.3 + i * 1.7) * SWEEP_WOBBLE
			_cam_pitch[i] = lerpf(_cam_pitch[i], -0.2, delta * 2.0)
			_cam_root[i].rotation.x = _cam_pitch[i]
		_cam_tally[i].albedo_color = Color(0.95, 0.05, 0.04) if i == live else Color(0.22, 0.03, 0.03)
	_spot_look = _spot_look.lerp(aim, delta * 3.0)
	if _spot_look != _spot.global_position:
		_spot.look_at(_spot_look)
	_spot.light_energy = 2.5 if live >= 0 else 0.0
	if live >= 0:
		_screens(_zone_color(aim))
		_feed_cam.global_transform = _cam_root[live].global_transform
		_feed_cam.global_position += _feed_cam.global_basis * Vector3(0.0, 0.1, -0.75)  # out past the lens
		_set_feed(_quad_in_view())
	else:
		_screens(NO_SIGNAL)
		_set_feed(false)


## The star's zone by position -> the screens' tint. The map's own zone colours (Docs/LEVEL_GIGACHURCH.md):
## the tint says where the star is even from across the nave.
func _zone_color(pos: Vector3) -> Color:
	if pos.x < -42.0:
		return Color(0.55, 0.60, 0.80) if pos.y > 6.0 else Color(0.85, 0.60, 0.30)  # loft / narthex
	if pos.x > 46.0:
		return Color(0.35, 0.40, 0.50)  # backstage
	if absf(pos.z) > 18.0:
		return Color(0.75, 0.20, 0.15)  # the chapel bands
	if pos.x > 32.0:
		return Color(1.00, 0.70, 0.25)  # the apse, the stage
	if pos.x > 18.0:
		return Color(0.30, 0.45, 0.90)  # the transept
	if absf(pos.z) > 11.0:
		return Color(0.55, 0.60, 0.80)  # the aisles and the galleries
	return Color(0.90, 0.65, 0.35)     # the nave


func _off_air(delta: float) -> void:
	_sweep += delta
	for i in _cam_root.size():
		_cam_yaw[i] = lerp_angle(_cam_yaw[i], _cam_base[i], delta * 2.0)
		_cam_root[i].rotation.y = _cam_yaw[i]
		_cam_pitch[i] = lerpf(_cam_pitch[i], 0.0, delta * 2.0)
		_cam_root[i].rotation.x = _cam_pitch[i]
		_cam_tally[i].albedo_color = Color(0.22, 0.03, 0.03)
	_spot.light_energy = 0.0
	if _screen != null:
		_screen.color = SCREEN_BASE
	_set_feed(false)


## The camera the broadcast cuts to: the nearest one with a clear line to the star (-1: the star is hidden
## from them all). Player capsules are not world geometry, the ray sees only the level.
func _live_camera(aim: Vector3) -> int:
	var space := get_viewport().find_world_3d().direct_space_state
	var live := -1
	var best := INF
	for i in _cam_root.size():
		var from: Vector3 = _cam_root[i].global_position
		if from.distance_to(aim) >= best:
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, aim, Layers.WORLD))
		if hit.is_empty():
			best = from.distance_to(aim)
			live = i
	return live


func _aim(i: int, aim: Vector3, delta: float) -> void:
	var from: Vector3 = _cam_root[i].global_position
	var to := (aim - from).normalized()
	var yaw := atan2(-to.x, -to.z)  # the prop's -Z looks at the star
	var pitch := asin(clampf(to.y, -1.0, 1.0))
	_cam_yaw[i] = lerp_angle(_cam_yaw[i], yaw, delta * CAM_SPEED)
	_cam_pitch[i] = lerpf(_cam_pitch[i], pitch, delta * CAM_SPEED)
	_cam_root[i].rotation.y = _cam_yaw[i]
	_cam_root[i].rotation.x = _cam_pitch[i]


func _screens(tint: Color) -> void:
	if _screen != null:
		_screen.color = tint


func _quad_in_view() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	for quad in _feed_quads:
		var to := quad.global_position - cam.global_position
		if to.length() < FEED_RANGE and to.dot(-cam.global_basis.z) > 0.0:
			return true
	return false


func _set_feed(on: bool) -> void:
	if on == _feed_on:
		return
	_feed_on = on
	_feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	for quad in _feed_quads:
		quad.visible = on


func _build_props() -> void:
	var root := Node3D.new()
	root.name = "OnAirProps"
	add_child(root)
	var body_mat := _flat(Color(0.15, 0.14, 0.14))
	var lens_mat := _flat(Color(0.07, 0.07, 0.08))
	for i in CAMS.size():
		var cam := Node3D.new()
		cam.name = "StudioCam%d" % i
		root.add_child(cam)
		cam.position = CAMS[i][0]
		cam.rotation.y = CAMS[i][1]
		var body := MeshInstance3D.new()
		body.mesh = BoxMesh.new()
		(body.mesh as BoxMesh).size = Vector3(0.45, 0.55, 0.9)
		body.material_override = body_mat
		cam.add_child(body)
		var lens := MeshInstance3D.new()
		lens.mesh = BoxMesh.new()
		(lens.mesh as BoxMesh).size = Vector3(0.28, 0.28, 0.35)
		lens.material_override = lens_mat
		lens.position = Vector3(0.0, 0.0, -0.6)
		cam.add_child(lens)
		var tally := MeshInstance3D.new()
		tally.mesh = BoxMesh.new()
		(tally.mesh as BoxMesh).size = Vector3(0.2, 0.12, 0.2)
		tally.material_override = _tally_mat()
		tally.position = Vector3(0.0, 0.37, -0.2)
		cam.add_child(tally)
		_cam_root.append(cam)
		_cam_base.append(CAMS[i][1])
		_cam_yaw.append(CAMS[i][1])
		_cam_pitch.append(0.0)
		_cam_tally.append(tally.material_override)
	_spot = SpotLight3D.new()
	_spot.position = SPOT
	_spot.light_color = Color(1.0, 0.75, 0.45)
	_spot.light_specular = 0.0
	_spot.light_cull_mask = 15  # both decks, like the floor's own lamps
	_spot.spot_range = 60.0
	_spot.spot_angle = 16.0
	_spot.shadow_enabled = false
	add_child(_spot)
	_screen = get_parent().get_node_or_null("Shell/Geometry/StageScreen") as Block
	_feed = SubViewport.new()
	_feed.size = FEED_RES
	_feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_feed)
	_feed_cam = Camera3D.new()
	_feed_cam.fov = 55.0
	_feed_cam.far = 120.0
	_feed.add_child(_feed_cam)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.albedo_texture = _feed.get_texture()
	quad_mat.disable_fog = true
	var frame_mat := _flat(Color(0.13, 0.12, 0.12))
	for tv in TVS:
		var frame := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(tv[2].x + 0.4, tv[2].y + 0.4, 0.12)
		frame.mesh = box
		frame.material_override = frame_mat
		add_child(frame)
		frame.position = tv[0]
		frame.rotation.y = tv[1]
		var quad := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = tv[2]
		quad.mesh = plane
		quad.material_override = quad_mat
		frame.add_child(quad)
		quad.position = Vector3(0.0, 0.0, 0.07)  # on the frame's screen face
		_feed_quads.append(quad)


func _tally_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.22, 0.03, 0.03)
	m.disable_fog = true
	return m


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m
