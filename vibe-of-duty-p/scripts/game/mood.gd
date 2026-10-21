class_name Mood
extends RefCounted
## The PSX style's mood (Settings.psx_style): a cold dusk (Docs/AUTHOR.md: darkness and warm greys, rare accents that
## mean something). The sun is low, pale and weak; the sky, the shade and the haze are dim, desaturated blue-grey. The
## only warm things in the frame are light sources - lamps (MoodLamps here, the train's own lamps) and muzzle flashes
## (MuzzleLights), in Palette.EMBER - so warm light reads as "here", against the cold. Bright lamps get a soft halo
## (halo(): a billboard, far cheaper on integrated graphics than the Environment's glow; the PSX dither bands it).
## Players keep a readability rim (Mannequin.set_rim): seeing the enemy comes first.
## Turned off, everything is as the level was made.
##
## Applied by NetWorld to its level (at load and whenever the graphics settings change). The level's own values are
## kept as metadata on the resources the first time, so switching back and forth always starts from them (the
## Environment is shared with the next load of the same scene).

# Sun: low over the horizon (long shadows), pale and cold, its azimuth as the level has it.
const SUN_ELEVATION := 11.0      # degrees
const SUN_ENERGY := 1.0
const SUN_COLOR := Palette.DUSK_SUN
# Shade: cold and dim, but not black - corners stay readable.
const AMBIENT_ENERGY := 1.2      # x the level's ambient light
const AMBIENT_COLOR := Palette.DUSK_SHADE
const AMBIENT_SKY := 0.25
const FOG_DENSITY := 0.007
const FOG_COLOR := Palette.DUSK_FOG
const FOG_SUN_SCATTER := 0.0     # no glow towards the sun: the haze stays cold
const FOG_SKY_AFFECT := 0.4
const SATURATION := 0.72         # the whole frame leans grey; accents survive it, big areas go muted
const CONTRAST := 1.12
## Sky shader (assets/shaders/sky_clouds.gdshader): a dark blue-grey dusk with a narrow pale band along the horizon,
## clouds barely lit.
const SKY := {
	"zenith_color": Palette.DUSK_ZENITH, "horizon_color": Palette.DUSK_HORIZON, "horizon_curve": 0.1,
	"ground_color": Palette.GREY_0, "cloud_coverage": 0.6, "cloud_light": Color("#5d6670"),
	"cloud_shadow": Color("#12161c"), "sun_glow": 0.35, "sun_glow_size": 8.0,
}
const ENV_KEYS := ["ambient_light_energy", "ambient_light_color", "ambient_light_sky_contribution", "tonemap_exposure",
		"fog_density", "fog_light_color", "fog_sun_scatter", "fog_sky_affect", "adjustment_saturation",
		"adjustment_contrast"]

# Lamps for levels without their own (the train has its Lamps): a few warm, shadowless lights over the play area
# (where the spawn points are), each with a glowing fixture and a halo. All of them burn wherever the camera is: a
# lamp must read as "here" from anywhere on the map (a light costs ~1 ms on integrated graphics only when it covers
# the screen; LAMPS_MAX keeps the count low).
const LAMPS_MAX := 4
const LAMP_SPACING := 10.0       # m between lamps
const LAMP_HEIGHT := 4.0         # m above the floor, outdoors (on a pole); indoors it hangs under the ceiling
const LAMP_ENERGY := 2.4
const LAMP_RANGE := 12.0
const LAMP_COLOR := Color(1.0, 0.72, 0.45)  # Palette.EMBER, lighter: as light it tints, as a colour it would be muddy
const GLOW_EMISSION := 2.6       # fixture brightness (over white: reads as a light source)
const GLOW_TINT := Palette.EMBER  # fixtures: warm, not white, even this bright
const HALO_COLOR := Color(Palette.EMBER, 0.5)
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
	if is_instance_valid(level) and level.is_inside_tree() and Settings.psx_style and \
			level.get_node_or_null(LAMPS_NODE) == null:
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
				_shade(root, (light as Node3D).global_position + Vector3.UP * 0.32, Vector3(0.7, 0.05, 0.3), 1.6)
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
			_shade(root, lamp_pos + Vector3.UP * 0.08, Vector3(0.45, 0.06, 0.45), 2.2)
			var light := OmniLight3D.new()
			light.light_color = LAMP_COLOR
			light.light_energy = LAMP_ENERGY
			light.omni_range = LAMP_RANGE
			light.omni_attenuation = 1.3
			light.shadow_enabled = false
			light.light_specular = 0.0  # matte surfaces: no highlights to compute
			root.add_child(light)
			light.global_position = lamp_pos - Vector3.UP * 0.15


## A lamp shade: a dark housing with a glowing underside, and a halo of `halo_size` m around it.
static func _shade(root: Node3D, pos: Vector3, size: Vector3, halo_size: float) -> void:
	var housing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size + Vector3(0.06, 0.06, 0.06)
	housing.mesh = box
	housing.material_override = _flat(Palette.GREY_0)
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
	var glow_halo := halo(halo_size, HALO_COLOR)
	root.add_child(glow_halo)
	glow_halo.global_position = pos + Vector3.DOWN * 0.12


static var _halo_materials := {}


## A soft round glow facing the camera (additive, fades out where it meets walls): the look of bloom around a lamp
## without a full-screen glow pass.
static func halo(size: float, color: Color) -> MeshInstance3D:
	if not _halo_materials.has(color):
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.25, Color(1, 1, 1, 0.45))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.albedo_texture = texture
		material.albedo_color = color
		material.proximity_fade_enabled = true
		material.proximity_fade_distance = 0.4
		material.no_depth_test = false
		_halo_materials[color] = material
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = _halo_materials[color]
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


static func _pole(root: Node3D, floor_pos: Vector3, height: float) -> void:
	var pole := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.07
	cylinder.height = height
	cylinder.radial_segments = 6
	pole.mesh = cylinder
	pole.material_override = _flat(Palette.GREY_1)
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
