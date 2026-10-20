class_name Mood
extends RefCounted
## The PSX style's mood (Settings.psx_style): dusk. Dark doesn't mean grey: the shade and the sky are cold and dark
## blue, and against them stand warm light sources - a low orange sun along the horizon, lamps (MoodLamps here, the
## train's own lamps) and muzzle flashes (MuzzleLights) - with glow, so bright things bloom (and the PSX dither
## bands the halos). Players keep a readability rim (Mannequin.set_rim): seeing the enemy comes first.
## Turned off, everything is as the level was made.
##
## Applied by NetWorld to its level (at load and whenever the graphics settings change). The level's own values are
## kept as metadata on the resources the first time, so switching back and forth always starts from them (the
## Environment is shared with the next load of the same scene).

# Sun: low over the horizon (long shadows, warm streaks of light), its azimuth as the level has it.
const SUN_ELEVATION := 13.0      # degrees
const SUN_ENERGY := 1.5
const SUN_COLOR := Color(1.0, 0.56, 0.32)
# Shade: cold and dim, but not black - corners stay readable.
const AMBIENT_ENERGY := 0.65     # x the level's ambient light
const AMBIENT_COLOR := Color(0.3, 0.35, 0.52)
const AMBIENT_SKY := 0.3
const FOG_DENSITY := 0.006
const FOG_COLOR := Color(0.12, 0.14, 0.22)
const FOG_SUN_SCATTER := 0.12    # the haze glows warm towards the sun (more washes the whole view orange)
const FOG_SKY_AFFECT := 0.35
const SATURATION := 1.05
const CONTRAST := 1.08
const GLOW_INTENSITY := 0.9
const GLOW_THRESHOLD := 1.1      # only what is brighter than white blooms: lamps, flashes, the sun
## Sky shader (assets/shaders/sky_clouds.gdshader): a deep blue dusk with an orange band along the horizon, clouds
## lit warm from below.
const SKY := {
	"zenith_color": Color(0.04, 0.06, 0.13), "horizon_color": Color(0.66, 0.36, 0.22), "horizon_curve": 0.16,
	"ground_color": Color(0.05, 0.06, 0.09), "cloud_coverage": 0.55, "cloud_light": Color(1.0, 0.6, 0.4),
	"cloud_shadow": Color(0.1, 0.11, 0.18), "sun_glow": 1.1, "sun_glow_size": 5.0,
}
const ENV_KEYS := ["ambient_light_energy", "ambient_light_color", "ambient_light_sky_contribution", "tonemap_exposure",
		"fog_density", "fog_light_color", "fog_sun_scatter", "fog_sky_affect", "adjustment_saturation",
		"adjustment_contrast", "glow_enabled", "glow_intensity", "glow_hdr_threshold", "glow_blend_mode", "glow_bloom"]

# Lamps for levels without their own (the train has its Lamps): a few warm, shadowless lights over the play area
# (where the spawn points are), each with a glowing fixture. Kept few: ~0.4 ms per light on integrated graphics.
const LAMPS_MAX := 4
const LAMP_SPACING := 10.0       # m between lamps
const LAMP_HEIGHT := 4.0         # m above the floor, outdoors (on a pole); indoors it hangs under the ceiling
const LAMP_ENERGY := 2.4
const LAMP_RANGE := 12.0
const LAMP_COLOR := Color(1.0, 0.76, 0.48)
const GLOW_EMISSION := 6.0       # fixture brightness (HDR: blooms)
const GLOW_TINT := Color(1.0, 0.55, 0.22)  # fixtures: saturated, so they stay warm (not white) when this bright
const LAMPS_NODE := "MoodLamps"


static func apply(level: Node, env: Environment, sun: DirectionalLight3D, on: bool) -> void:
	Mannequin.set_rim(on)
	if env != null:
		var base: Dictionary = _base(env, ENV_KEYS)
		for key in ENV_KEYS:
			env.set(key, base[key])
		if on:
			env.ambient_light_energy = base["ambient_light_energy"] * AMBIENT_ENERGY
			env.ambient_light_color = AMBIENT_COLOR
			env.ambient_light_sky_contribution = AMBIENT_SKY
			env.fog_density = FOG_DENSITY
			env.fog_light_color = FOG_COLOR
			env.fog_sun_scatter = FOG_SUN_SCATTER
			env.fog_sky_affect = FOG_SKY_AFFECT
			env.adjustment_saturation = SATURATION
			env.adjustment_contrast = CONTRAST
			env.glow_enabled = true
			env.glow_intensity = GLOW_INTENSITY
			env.glow_hdr_threshold = GLOW_THRESHOLD
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
			env.glow_bloom = 0.0
		var sky_material := env.sky.sky_material as ShaderMaterial if env.sky else null
		if sky_material != null:
			var sky_base: Dictionary = _base_params(sky_material, SKY.keys())
			for key in SKY:
				sky_material.set_shader_parameter(key, SKY[key] if on else sky_base[key])
	if sun != null:
		var sun_base: Dictionary = _base(sun, ["light_energy", "light_color", "basis"])
		sun.light_energy = SUN_ENERGY if on else sun_base["light_energy"]
		sun.light_color = SUN_COLOR if on else sun_base["light_color"]
		sun.basis = _low_sun(sun_base["basis"]) if on else sun_base["basis"]
	if level != null and DisplayServer.get_name() != "headless":
		var lamps := level.get_node_or_null(LAMPS_NODE)
		if lamps != null:
			level.remove_child(lamps)
			lamps.queue_free()
		if on:
			_build_lamps_later(level)


## The sun turned down to SUN_ELEVATION over the horizon, keeping the direction it shines from.
static func _low_sun(basis: Basis) -> Basis:
	var dir := -basis.z
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	var e := deg_to_rad(SUN_ELEVATION)
	var low := flat.normalized() * cos(e) + Vector3.DOWN * sin(e)
	return Basis.looking_at(low, Vector3.UP)


## Lamps are placed by raycasts, which only see the level once its bodies are in the physics space: a physics frame
## after load. Skipped if the style was turned off (or the lamps built) meanwhile.
static func _build_lamps_later(level: Node) -> void:
	await level.get_tree().physics_frame
	if is_instance_valid(level) and level.is_inside_tree() and Settings.psx_style 			and level.get_node_or_null(LAMPS_NODE) == null:
		_build_lamps(level)


## Light fixtures: for the train's own lamps just the glowing shades; elsewhere up to LAMPS_MAX lamps of our own,
## spread over the spawn points' area.
static func _build_lamps(level: Node) -> void:
	var root := Node3D.new()
	root.name = LAMPS_NODE
	level.add_child(root)
	var own := level.get_node_or_null("Lamps")
	if own != null:
		for light in own.get_children():
			if light is OmniLight3D:
				_shade(root, (light as Node3D).global_position + Vector3.UP * 0.32, Vector3(0.7, 0.05, 0.3))
		return
	var spawns := level.get_node_or_null("SpawnPoints")
	if spawns == null or spawns.get_child_count() == 0:
		return
	var area := AABB((spawns.get_child(0) as Node3D).global_position, Vector3.ZERO)
	for spawn in spawns.get_children():
		area = area.expand((spawn as Node3D).global_position)
	area = area.grow(2.0)
	var nx := clampi(roundi(area.size.x / LAMP_SPACING), 1, 3)
	var nz := clampi(roundi(area.size.z / LAMP_SPACING), 1, 3)
	while nx * nz > LAMPS_MAX:
		if nx >= nz:
			nx -= 1
		else:
			nz -= 1
	var space := (level as Node3D).get_world_3d().direct_space_state
	for i in nx:
		for k in nz:
			var x := area.position.x + area.size.x * (i + 0.5) / nx
			var z := area.position.z + area.size.z * (k + 0.5) / nz
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, area.end.y + 6.0, z),
					Vector3(x, area.position.y - 6.0, z), Layers.WORLD))
			if down.is_empty():
				continue
			var floor_pos: Vector3 = down["position"]
			var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_pos + Vector3.UP * 0.3,
					floor_pos + Vector3.UP * (LAMP_HEIGHT + 0.5), Layers.WORLD))
			var lamp_pos: Vector3
			if up.is_empty():
				lamp_pos = floor_pos + Vector3.UP * LAMP_HEIGHT
				_pole(root, floor_pos, LAMP_HEIGHT)
			else:
				lamp_pos = (up["position"] as Vector3) + Vector3.DOWN * 0.2
			_shade(root, lamp_pos + Vector3.UP * 0.08, Vector3(0.45, 0.06, 0.45))
			var light := OmniLight3D.new()
			light.light_color = LAMP_COLOR
			light.light_energy = LAMP_ENERGY
			light.omni_range = LAMP_RANGE
			light.omni_attenuation = 1.3
			light.shadow_enabled = false
			root.add_child(light)
			light.global_position = lamp_pos - Vector3.UP * 0.15


## A lamp shade: a dark housing with a glowing underside.
static func _shade(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var housing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size + Vector3(0.06, 0.06, 0.06)
	housing.mesh = box
	housing.material_override = _flat(Color(0.08, 0.08, 0.09))
	root.add_child(housing)
	housing.global_position = pos + Vector3.UP * 0.04
	var bulb := MeshInstance3D.new()
	var panel := BoxMesh.new()
	panel.size = size
	bulb.mesh = panel
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = GLOW_TINT * GLOW_EMISSION
	glow.disable_fog = true  # a lamp shines through the haze
	bulb.material_override = glow
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bulb)
	bulb.global_position = pos


static func _pole(root: Node3D, floor_pos: Vector3, height: float) -> void:
	var pole := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.07
	cylinder.height = height
	cylinder.radial_segments = 6
	pole.mesh = cylinder
	pole.material_override = _flat(Color(0.1, 0.1, 0.11))
	root.add_child(pole)
	pole.global_position = floor_pos + Vector3.UP * height * 0.5


static func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m


## The object's own values of `keys`, remembered the first time.
static func _base(object: Object, keys: Array) -> Dictionary:
	if not object.has_meta(&"mood_base"):
		var values := {}
		for key in keys:
			values[key] = object.get(key)
		object.set_meta(&"mood_base", values)
	return object.get_meta(&"mood_base")


static func _base_params(material: ShaderMaterial, keys: Array) -> Dictionary:
	if not material.has_meta(&"mood_base"):
		var values := {}
		for key in keys:
			values[key] = material.get_shader_parameter(key)
		material.set_meta(&"mood_base", values)
	return material.get_meta(&"mood_base")
