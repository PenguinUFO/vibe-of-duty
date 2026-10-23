class_name WeaponSkin
extends RefCounted
## Textures on the weapon models, after the train's (Block): a coarse, pixelated grey noise tinted by the part's own
## colour, here one of three - metal (mottled, worn), wood (grain along the barrel), polymer (fine grit) - mapped in
## the part's space (assets/shaders/weapon_skin.gdshader). WeaponView.set_weapon swaps every plain material of the
## model for its skin; the kind comes from the material's name (the generators in tools/ name them after their keys).

const SHADER := preload("res://assets/shaders/weapon_skin.gdshader")
const SIZE := 32                # px; tiles seamlessly
const TILES_PER_METRE := 8.0    # 32 px over 12.5 cm: a texel is 4 mm - chunky up close, as the train's walls
const POLYMER_NAMES: Array[String] = ["fde", "grip", "rubber", "polymer"]
## kind -> octaves [lattice cells along u (the barrel), across (v), weight], contrast.
const KINDS := {
	"metal": {"octaves": [[2, 2, 0.35], [8, 8, 0.25], [SIZE, SIZE, 0.4]], "contrast": 0.55},
	"wood": {"octaves": [[2, 2, 0.25], [2, 16, 0.35], [4, SIZE, 0.25], [SIZE, SIZE, 0.15]], "contrast": 0.55},
	"polymer": {"octaves": [[4, 4, 0.5], [SIZE, SIZE, 0.5]], "contrast": 0.16},
}

static var _textures := {}   # kind -> [ImageTexture, mean]
static var _materials := {}  # [kind, colour, metallic, roughness] -> ShaderMaterial


## Swaps the plain materials under `root` for their skins (glass, unshaded dots and the like stay as they are).
static func apply(root: Node) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(i) as StandardMaterial3D
			if source == null or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
					or source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				continue
			mesh_instance.set_surface_override_material(i, _skin(source))


static func _skin(source: StandardMaterial3D) -> ShaderMaterial:
	var kind := _kind(source)
	var key := [kind, source.albedo_color, source.metallic, source.roughness]
	if not _materials.has(key):
		var texture: Array = _texture(kind)
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("grain", texture[0])
		material.set_shader_parameter("gain", 1.0 / texture[1])
		material.set_shader_parameter("tint", source.albedo_color)
		material.set_shader_parameter("metallic_value", source.metallic)
		material.set_shader_parameter("roughness_value", source.roughness)
		material.set_shader_parameter("tiles_per_metre", TILES_PER_METRE)
		_materials[key] = material
	return _materials[key]


## "wood"; polymer by name, or a magazine that is not steel (PMAG, the AK's bakelite); everything else metal.
static func _kind(source: StandardMaterial3D) -> String:
	var name := source.resource_name
	if name == "wood":
		return "wood"
	if name in POLYMER_NAMES or (name == "mag" and source.metallic < 0.2):
		return "polymer"
	return "metal"


## The kind's noise (as Block's: value noise on wrapping lattices, so the tile has no seams) and its mean brightness.
static func _texture(kind: String) -> Array:
	if _textures.has(kind):
		return _textures[kind]
	var spec: Dictionary = KINDS[kind]
	var octaves: Array = spec["octaves"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var lattices := []
	for octave in octaves:
		var values := PackedFloat32Array()
		for i in int(octave[0]) * int(octave[1]):
			values.append(rng.randf())
		lattices.append(values)
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)  # L8 has no sRGB view: it would be read as linear
	var total := 0.0
	for y in SIZE:
		for x in SIZE:
			var sum := 0.0
			for o in octaves.size():
				var cu: int = octaves[o][0]
				var cv: int = octaves[o][1]
				var values: PackedFloat32Array = lattices[o]
				var fu := float(x) * cu / SIZE
				var fv := float(y) * cv / SIZE
				var u0 := int(fu) % cu
				var v0 := int(fv) % cv
				var u1 := (u0 + 1) % cu
				var v1 := (v0 + 1) % cv
				var tu := smoothstep(0.0, 1.0, fu - floorf(fu))
				var tv := smoothstep(0.0, 1.0, fv - floorf(fv))
				var top := lerpf(values[v0 * cu + u0], values[v0 * cu + u1], tu)
				var bottom := lerpf(values[v1 * cu + u0], values[v1 * cu + u1], tu)
				sum += lerpf(top, bottom, tv) * float(octaves[o][2])
			var value := 1.0 - float(spec["contrast"]) * sum
			total += pow(value, 2.2)  # the shader reads it as sRGB: the mean that matters is the linear one
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	_textures[kind] = [ImageTexture.create_from_image(image), total / (SIZE * SIZE)]
	return _textures[kind]
