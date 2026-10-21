@tool
class_name Block
extends StaticBody3D
## Blockout box: visual mesh + matching collision. Swap for real meshes when building the final level.
## Surfaces get a coarse, pixelated grey noise (the owner's look, Docs/AUTHOR.md) tinted by the block's colour.

const NOISE_SIZE := 64           # px; tiles seamlessly
const NOISE_METRES := 4.0        # one tile over this many metres: 16 px per metre
const NOISE_CONTRAST := 0.45    # darkest texel = 1 - this (x the block's colour)

static var _materials := {}  # Color -> StandardMaterial3D, shared by all blocks of that colour
static var _noise: ImageTexture

@export var size := Vector3.ONE:
	set(value):
		size = value
		_rebuild()
@export var color := Color(0.6, 0.6, 0.6):
	set(value):
		color = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	var box := BoxMesh.new()
	box.size = size
	$Mesh.mesh = box
	box.material = _material_for(color)
	var shape := BoxShape3D.new()
	shape.size = size
	$Collision.shape = shape


static func _material_for(tint: Color) -> StandardMaterial3D:
	if not _materials.has(tint):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.albedo_texture = _noise_texture()
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE / NOISE_METRES
		material.roughness = 1.0
		_materials[tint] = material
	return _materials[tint]


## Blotchy grey noise with per-texel grain: value noise on wrapping lattices (so the tile has no seams), the coarse
## octaves for stains, the last one a texel apart for grit.
static func _noise_texture() -> ImageTexture:
	if _noise != null:
		return _noise
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var octaves := [[4, 0.35], [8, 0.2], [16, 0.15], [NOISE_SIZE, 0.3]]  # lattice cells per tile, weight
	var lattices := []
	for octave in octaves:
		var cells: int = octave[0]
		var values := PackedFloat32Array()
		for i in cells * cells:
			values.append(rng.randf())
		lattices.append(values)
	var image := Image.create_empty(NOISE_SIZE, NOISE_SIZE, false, Image.FORMAT_L8)
	for y in NOISE_SIZE:
		for x in NOISE_SIZE:
			var sum := 0.0
			for o in octaves.size():
				var cells: int = octaves[o][0]
				var values: PackedFloat32Array = lattices[o]
				var fx := float(x) * cells / NOISE_SIZE
				var fy := float(y) * cells / NOISE_SIZE
				var x0 := int(fx) % cells
				var y0 := int(fy) % cells
				var x1 := (x0 + 1) % cells
				var y1 := (y0 + 1) % cells
				var tx := smoothstep(0.0, 1.0, fx - floorf(fx))
				var ty := smoothstep(0.0, 1.0, fy - floorf(fy))
				var top := lerpf(values[y0 * cells + x0], values[y0 * cells + x1], tx)
				var bottom := lerpf(values[y1 * cells + x0], values[y1 * cells + x1], tx)
				sum += lerpf(top, bottom, ty) * octaves[o][1]
			image.set_pixel(x, y, Color.from_hsv(0.0, 0.0, 1.0 - NOISE_CONTRAST * sum))
	image.generate_mipmaps()
	_noise = ImageTexture.create_from_image(image)
	return _noise
