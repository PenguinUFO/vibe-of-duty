class_name Mood
extends RefCounted
## The PSX style's darker mood (Settings.psx_style): an overcast, dusky version of a level's light - dim cool sun,
## low bluish ambient, a heavier dark haze and a grey sky - with the PSX dither over the frame (Settings) and a
## readability rim on players (Mannequin.set_rim), because in a shooter seeing the enemy matters more than the
## mood. Turned off, everything is as the level was made.
##
## Applied by NetWorld to its level's WorldEnvironment and sun (at load and whenever the graphics settings change).
## The level's own values are kept as metadata on the resources the first time, so switching back and forth always
## starts from them (the Environment is shared with the next load of the same scene).

const SUN_ENERGY := 0.7          # x the level's sun
const SUN_COLOR := Color(0.84, 0.86, 0.95)
const AMBIENT_ENERGY := 0.95     # x the level's ambient light: shade and interiors stay readable
const AMBIENT_COLOR := Color(0.56, 0.58, 0.64)
const EXPOSURE := 1.0           # x the level's exposure
const FOG_DENSITY := 0.0075      # a dark haze: ~20 % at 30 m, ~40 % at 70 m (enemies stay visible across the maps)
const FOG_COLOR := Color(0.28, 0.31, 0.36)
const FOG_SKY_AFFECT := 0.45
const SATURATION := 0.85
const CONTRAST := 1.04
## Sky shader (assets/shaders/sky_clouds.gdshader): low grey overcast.
const SKY := {
	"zenith_color": Color(0.17, 0.2, 0.26), "horizon_color": Color(0.36, 0.39, 0.44),
	"ground_color": Color(0.24, 0.26, 0.29), "cloud_coverage": 0.85, "cloud_light": Color(0.58, 0.6, 0.64),
	"cloud_shadow": Color(0.24, 0.26, 0.31), "sun_glow": 0.18,
}
const ENV_KEYS := ["ambient_light_energy", "ambient_light_color", "tonemap_exposure", "fog_density", "fog_light_color",
		"fog_sky_affect", "adjustment_saturation", "adjustment_contrast"]


static func apply(env: Environment, sun: DirectionalLight3D, on: bool) -> void:
	Mannequin.set_rim(on)
	if env != null:
		var base: Dictionary = _base(env, ENV_KEYS)
		for key in ENV_KEYS:
			env.set(key, base[key])
		if on:
			env.ambient_light_energy = base["ambient_light_energy"] * AMBIENT_ENERGY
			env.ambient_light_color = AMBIENT_COLOR
			env.tonemap_exposure = base["tonemap_exposure"] * EXPOSURE
			env.fog_density = FOG_DENSITY
			env.fog_light_color = FOG_COLOR
			env.fog_sky_affect = FOG_SKY_AFFECT
			env.adjustment_saturation = SATURATION
			env.adjustment_contrast = CONTRAST
		var sky_material := env.sky.sky_material as ShaderMaterial if env.sky else null
		if sky_material != null:
			var sky_base: Dictionary = _base_params(sky_material, SKY.keys())
			for key in SKY:
				sky_material.set_shader_parameter(key, SKY[key] if on else sky_base[key])
	if sun != null:
		var sun_base: Dictionary = _base(sun, ["light_energy", "light_color"])
		sun.light_energy = sun_base["light_energy"] * (SUN_ENERGY if on else 1.0)
		sun.light_color = SUN_COLOR if on else sun_base["light_color"]


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
