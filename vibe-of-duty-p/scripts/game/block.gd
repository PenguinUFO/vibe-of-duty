@tool
class_name Block
extends StaticBody3D
## Blockout box: visual mesh + matching collision. Swap for real meshes when building the final level.

const GRID_TEXTURE_PATH := "res://assets/placeholder/grid.png"

static var _materials := {}  # Color -> StandardMaterial3D, shared by all blocks of that colour

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
		material.albedo_texture = load(GRID_TEXTURE_PATH)
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.roughness = 1.0
		_materials[tint] = material
	return _materials[tint]
