class_name TrainScenery
extends Node3D
## The world rushing past the train map: ground, track bed, forest and, now and then, a tunnel through a hill.
## The train itself stands still (physics, netcode and lag compensation stay simple); everything here moves along +Z
## (the train "runs" towards -Z). Purely visual: every machine animates its own copy, so the phase of the forest and
## the tunnels differs between players; nothing gameplay-related depends on it. Not built on a dedicated server.
##
## Cost: the forest is a few MultiMesh chunks of low-poly blockout trees built from primitives (one draw call per
## tree type and surface per chunk) that wrap around from the back to the front; the ground and track scroll in a
## shader.

const GROUND_Y := -1.45         # top of the ground and the track bed (the car floors are at 0)
const CHUNK_LEN := 80.0         # forest chunk length (m)
const CHUNKS := 8               # chunks from FRONT backwards; they wrap around
const FRONT := -380.0           # z of the front edge of the forest strip
const CLEAR_X := 9.0            # no trees closer to the track than this
const FOREST_X := 120.0         # forest half width
const TREES_PER_CHUNK := 72
const BUSHES_PER_CHUNK := 40
const ROCKS_PER_CHUNK := 8
const TUNNEL_LEN := 150.0
const TUNNEL_W := 13.0          # inner width
const TUNNEL_H := 11.0          # inner height (well above the train roof)
const HILL_W := 70.0            # hill each side of the tunnel
const HILL_H := 26.0
const TUNNEL_START := -420.0    # where a tunnel appears (its centre)
const TUNNEL_END := 420.0       # where it is put away
const TUNNEL_GAP := Vector2(22.0, 45.0)  # seconds between tunnels
const FIRST_TUNNEL := 12.0
const TUNNEL_AMBIENT := 0.15    # share of the ambient light left inside a tunnel
const TUNNEL_FOG_DENSITY := 0.012
const TUNNEL_FOG_COLOR := Color(0.06, 0.06, 0.07)
const FOREST_VISIBLE := 260.0   # chunks farther than this (in the haze) are not drawn
## The train's lamps (OmniLights, ~0.4 ms each on integrated graphics) only burn in tunnels: in daylight the windows
## light the cars well enough.
const LAMP_ENERGY := 1.4

@export var speed := 22.0       # m/s (about 80 km/h)
@export var train_z0 := -60.0   # train extent along z (set by tools/make_train_map.py)
@export var train_z1 := 45.0

var _chunks: Array[Node3D] = []
var _scroll_materials: Array[ShaderMaterial] = []
var _scroll := 0.0
var _tunnel: Node3D
var _tunnel_z := 0.0
var _next_tunnel := FIRST_TUNNEL
var _rng := RandomNumberGenerator.new()
var _env: Environment
var _base_ambient := 1.0
var _base_fog := 0.0
var _base_fog_color := Color.WHITE
var _lamps: Array[OmniLight3D] = []
var _darkness := 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_rng.seed = 7341  # the same forest on every machine (only its phase differs)
	var world_env := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if world_env:
		_env = world_env.environment
		_base_ambient = _env.ambient_light_energy
		_base_fog = _env.fog_density
		_base_fog_color = _env.fog_light_color
	for lamp in get_node("../Lamps").get_children() if has_node("../Lamps") else []:
		_lamps.append(lamp)
		lamp.visible = false
	_build_ground()
	_build_forest()
	_build_tunnel()


func _exit_tree() -> void:
	if _env:  # the Environment resource is shared with the next load of the scene
		_env.ambient_light_energy = _base_ambient
		_env.fog_density = _base_fog
		_env.fog_light_color = _base_fog_color


func _process(delta: float) -> void:
	var step := speed * delta
	_scroll += step
	for material in _scroll_materials:
		material.set_shader_parameter("scroll", _scroll)
	var strip := CHUNKS * CHUNK_LEN
	for chunk in _chunks:
		chunk.position.z += step
		if chunk.position.z > FRONT + strip:
			chunk.position.z -= strip
	_update_tunnel(delta, step)


# --- ground and track -------------------------------------------------------------------------------------------------

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FOREST_X * 2.0 + 200.0, CHUNKS * CHUNK_LEN + 300.0)
	plane.subdivide_depth = 0
	ground.mesh = plane
	ground.position = Vector3(0.0, GROUND_Y, FRONT + CHUNKS * CHUNK_LEN * 0.5)
	ground.material_override = _scroll_material(GROUND_SHADER)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var bed := MeshInstance3D.new()
	var strip := PlaneMesh.new()
	strip.size = Vector2(10.0, CHUNKS * CHUNK_LEN + 300.0)
	bed.mesh = strip
	bed.position = Vector3(0.0, GROUND_Y + 0.03, ground.position.z)
	bed.material_override = _scroll_material(TRACK_SHADER)
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bed)

	# Rails look the same wherever they are: they stand still.
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.35, 0.33, 0.32)
	rail_mat.metallic = 0.6
	rail_mat.roughness = 0.4
	for x in [-0.75, 0.75]:
		var rail := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.14, strip.size.y)
		rail.mesh = box
		rail.material_override = rail_mat
		rail.position = Vector3(x, GROUND_Y + 0.12, ground.position.z)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rail)


func _scroll_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	_scroll_materials.append(material)
	return material


# --- forest -----------------------------------------------------------------------------------------------------------

func _build_forest() -> void:
	var kinds: Array[Dictionary] = [
		{"mesh": _pine(), "count": TREES_PER_CHUNK / 2, "scale": Vector2(0.8, 1.35), "shadow": true},
		{"mesh": _broadleaf(), "count": TREES_PER_CHUNK / 2, "scale": Vector2(0.8, 1.3), "shadow": true},
		{"mesh": _bush(), "count": BUSHES_PER_CHUNK, "scale": Vector2(0.7, 1.5), "shadow": false},
		{"mesh": _rock(), "count": ROCKS_PER_CHUNK, "scale": Vector2(0.6, 1.8), "shadow": false},
	]
	for c in CHUNKS:
		var chunk := Node3D.new()
		chunk.position.z = FRONT + c * CHUNK_LEN
		add_child(chunk)
		_chunks.append(chunk)
		for kind in kinds:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = kind["mesh"]
			multimesh.instance_count = kind["count"]
			for i in multimesh.instance_count:
				# Denser near the track, where the players actually look.
				var side := -1.0 if _rng.randf() < 0.5 else 1.0
				var x := side * lerpf(CLEAR_X, FOREST_X, pow(_rng.randf(), 1.8))
				var scale_range: Vector2 = kind["scale"]
				var s := _rng.randf_range(scale_range.x, scale_range.y)
				var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
				multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, GROUND_Y, _rng.randf() * CHUNK_LEN)))
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = FOREST_VISIBLE + CHUNK_LEN  # measured to the chunk's centre
			instance.visibility_range_end_margin = 20.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			chunk.add_child(instance)


# Blockout vegetation: primitives merged into one mesh per kind, one surface per colour, flat shaded (low-poly look).

const TRUNK := Color(0.33, 0.22, 0.14)
const PINE := Color(0.15, 0.29, 0.15)
const LEAVES := Color(0.29, 0.41, 0.15)
const BUSH := Color(0.24, 0.37, 0.14)
const STONE := Color(0.45, 0.44, 0.42)


func _pine() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_surface(mesh, TRUNK, [[_cone(0.28, 0.18, 3.2, 6), Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))]])
	_surface(mesh, PINE, [
		[_cone(2.6, 0.0, 4.2, 7), Transform3D(Basis.IDENTITY, Vector3(0, 4.0, 0))],
		[_cone(2.0, 0.0, 3.6, 7), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 6.0, 0))],
		[_cone(1.3, 0.0, 3.0, 7), Transform3D(Basis(Vector3.UP, 0.8), Vector3(0, 7.9, 0))],
	])
	return mesh


func _broadleaf() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_surface(mesh, TRUNK, [[_cone(0.32, 0.2, 4.4, 6), Transform3D(Basis.IDENTITY, Vector3(0, 2.2, 0))]])
	_surface(mesh, LEAVES, [
		[_ball(2.6), Transform3D(Basis.IDENTITY, Vector3(0, 5.8, 0))],
		[_ball(1.9), Transform3D(Basis(Vector3.UP, 1.0), Vector3(1.5, 5.0, 0.6))],
		[_ball(1.7), Transform3D(Basis(Vector3.UP, 2.0), Vector3(-1.3, 5.3, -0.7))],
	])
	return mesh


func _bush() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_surface(mesh, BUSH, [
		[_ball(0.9), Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0))],
		[_ball(0.7), Transform3D(Basis.IDENTITY, Vector3(0.7, 0.45, 0.2))],
		[_ball(0.6), Transform3D(Basis.IDENTITY, Vector3(-0.6, 0.4, -0.3))],
	])
	return mesh


func _rock() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_surface(mesh, STONE, [[_ball(1.0), Transform3D(Basis.IDENTITY.scaled(Vector3(1.4, 0.7, 1.0)), Vector3(0, 0.3, 0))]])
	return mesh


## Merges primitives [[mesh, transform], ...] into one flat-shaded surface of `color`.
func _surface(target: ArrayMesh, color: Color, pieces: Array) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces:
		tool.append_from(piece[0], 0, piece[1])
	tool.deindex()          # every face gets its own vertices...
	tool.generate_normals()  # ...so the normals are per face: faceted, low-poly shading
	tool.commit(target)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	target.surface_set_material(target.get_surface_count() - 1, material)


func _cone(bottom: float, top: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


func _ball(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.8
	mesh.radial_segments = 7
	mesh.rings = 4
	return mesh


# --- tunnel -----------------------------------------------------------------------------------------------------------

func _build_tunnel() -> void:
	_tunnel = Node3D.new()
	_tunnel.visible = false
	add_child(_tunnel)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.32, 0.31, 0.3)
	concrete.roughness = 0.95
	var hill := StandardMaterial3D.new()
	hill.albedo_color = Color(0.3, 0.38, 0.24)
	hill.roughness = 1.0
	var half := TUNNEL_W * 0.5
	var base := GROUND_Y
	# Lining: walls and vault.
	_tunnel_box(Vector3(-half - 0.5, base + TUNNEL_H * 0.5, 0.0), Vector3(1.0, TUNNEL_H, TUNNEL_LEN), concrete)
	_tunnel_box(Vector3(half + 0.5, base + TUNNEL_H * 0.5, 0.0), Vector3(1.0, TUNNEL_H, TUNNEL_LEN), concrete)
	_tunnel_box(Vector3(0.0, base + TUNNEL_H + 0.5, 0.0), Vector3(TUNNEL_W + 2.0, 1.0, TUNNEL_LEN), concrete)
	# The hill around it (a bit shorter than the lining, so the portals stick out).
	var hill_len := TUNNEL_LEN - 6.0
	_tunnel_box(Vector3(-half - 1.0 - HILL_W * 0.5, base + HILL_H * 0.5, 0.0), Vector3(HILL_W, HILL_H, hill_len), hill)
	_tunnel_box(Vector3(half + 1.0 + HILL_W * 0.5, base + HILL_H * 0.5, 0.0), Vector3(HILL_W, HILL_H, hill_len), hill)
	var top_h := HILL_H - TUNNEL_H - 1.0
	_tunnel_box(Vector3(0.0, base + TUNNEL_H + 1.0 + top_h * 0.5, 0.0), Vector3(TUNNEL_W + 2.0, top_h, hill_len), hill)
	# Portal frames at both ends.
	for end in [-1.0, 1.0]:
		var z: float = end * (TUNNEL_LEN * 0.5 - 0.75)
		_tunnel_box(Vector3(-half - 1.5, base + TUNNEL_H * 0.5 + 0.5, z), Vector3(3.0, TUNNEL_H + 1.0, 1.5), concrete)
		_tunnel_box(Vector3(half + 1.5, base + TUNNEL_H * 0.5 + 0.5, z), Vector3(3.0, TUNNEL_H + 1.0, 1.5), concrete)
		_tunnel_box(Vector3(0.0, base + TUNNEL_H + 1.5, z), Vector3(TUNNEL_W + 6.0, 2.0, 1.5), concrete)
	# Lamps along both walls (unshaded: no real lights, just bright spots passing the windows).
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(1.0, 0.8, 0.45)
	var lamps := MultiMesh.new()
	lamps.transform_format = MultiMesh.TRANSFORM_3D
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.15, 0.25, 1.2)
	lamps.mesh = lamp_mesh
	var per_side := int(TUNNEL_LEN / 12.0)
	lamps.instance_count = per_side * 2
	for i in per_side:
		var z := -TUNNEL_LEN * 0.5 + 6.0 + i * 12.0
		lamps.set_instance_transform(i * 2, Transform3D(Basis.IDENTITY, Vector3(-half + 0.05, base + 5.0, z)))
		lamps.set_instance_transform(i * 2 + 1, Transform3D(Basis.IDENTITY, Vector3(half - 0.05, base + 5.0, z)))
	var lamp_instance := MultiMeshInstance3D.new()
	lamp_instance.multimesh = lamps
	lamp_instance.material_override = lamp_mat
	lamp_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tunnel.add_child(lamp_instance)


func _tunnel_box(center: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = center
	_tunnel.add_child(mesh_instance)  # casts shadows: the vault darkens the train as it goes in


func _update_tunnel(delta: float, step: float) -> void:
	if _tunnel.visible:
		_tunnel_z += step
		_tunnel.position.z = _tunnel_z
		if _tunnel_z > TUNNEL_END:
			_tunnel.visible = false
			_next_tunnel = _rng.randf_range(TUNNEL_GAP.x, TUNNEL_GAP.y)
	else:
		_next_tunnel -= delta
		if _next_tunnel <= 0.0:
			_tunnel_z = TUNNEL_START
			_tunnel.position.z = _tunnel_z
			_tunnel.visible = true
	# How much of the train is inside: ambient light and haze follow it (the vault's shadow does the sunlight).
	var inside := 0.0
	if _tunnel.visible:
		var a := maxf(train_z0, _tunnel_z - TUNNEL_LEN * 0.5)
		var b := minf(train_z1, _tunnel_z + TUNNEL_LEN * 0.5)
		inside = clampf((b - a) / (train_z1 - train_z0), 0.0, 1.0)
	_darkness = move_toward(_darkness, inside, delta * 2.0)
	if _env:
		_env.ambient_light_energy = _base_ambient * lerpf(1.0, TUNNEL_AMBIENT, _darkness)
		_env.fog_density = lerpf(_base_fog, TUNNEL_FOG_DENSITY, _darkness)
		_env.fog_light_color = _base_fog_color.lerp(TUNNEL_FOG_COLOR, _darkness)
	for lamp in _lamps:
		lamp.visible = _darkness > 0.01
		lamp.light_energy = LAMP_ENERGY * _darkness


const GROUND_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float scroll = 0.0;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
varying vec2 world_xz;
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 p = world_xz - vec2(0.0, scroll);
	float n = noise(p * 0.08) * 0.6 + noise(p * 0.5) * 0.3 + noise(p * 3.0) * 0.1;
	vec3 grass = mix(vec3(0.16, 0.25, 0.1), vec3(0.3, 0.38, 0.16), n);
	vec3 dirt = vec3(0.3, 0.26, 0.2);
	ALBEDO = mix(grass, dirt, smoothstep(0.62, 0.78, noise(p * 0.03 + 7.0)) * 0.6);
	ROUGHNESS = 1.0;
}
"""

const TRACK_SHADER := """
shader_type spatial;
uniform float scroll = 0.0;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
varying vec2 world_xz;
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 p = world_xz - vec2(0.0, scroll);
	vec3 gravel = mix(vec3(0.33, 0.32, 0.3), vec3(0.45, 0.43, 0.4), hash(floor(p * 9.0)));
	float sleeper = step(fract(p.y / 0.65), 0.38) * step(abs(p.x), 1.3);
	ALBEDO = mix(gravel, vec3(0.28, 0.2, 0.14), sleeper);
	ROUGHNESS = 1.0;
}
"""
