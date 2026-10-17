class_name PlayerVisual
extends Node3D
## Third-person body of a non-local player. Currently a Synty character prefab (static pose, no
## animations yet) plus a name tag. Swap CHARACTER_SCENES to change the models; gameplay does not
## depend on anything in here.

const CHARACTER_SCENES: Array[String] = [
	"res://assets/Prefabs/Characters/Characters/Character_MilitaryMale_01.tscn",
	"res://assets/Prefabs/Characters/Characters/Character_MercenaryMale_01.tscn",
	"res://assets/Prefabs/Characters/Characters/Character_MilitaryFemale_01.tscn",
	"res://assets/Prefabs/Characters/Characters/Character_MercenaryFemale_01.tscn",
]
const MODEL_YAW_OFFSET := PI  # Synty models face +Z, the player's forward is -Z
const NAME_TAG_HEIGHT := 2.15

var _model: Node3D


func setup(peer_id: int, display_name: String) -> void:
	var scene: PackedScene = load(CHARACTER_SCENES[peer_id % CHARACTER_SCENES.size()])
	_model = scene.instantiate()
	# The prefab root is a physics body with its own collider; the player already has one.
	if _model is CollisionObject3D:
		_model.collision_layer = 0
		_model.collision_mask = 0
	for shape in _model.find_children("*", "CollisionShape3D", true, false):
		shape.queue_free()
	_model.rotation.y = MODEL_YAW_OFFSET
	add_child(_model)

	var tag := Label3D.new()
	tag.text = display_name
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0007
	tag.outline_size = 8
	tag.position.y = NAME_TAG_HEIGHT
	add_child(tag)


func set_crouched(crouched: bool) -> void:
	# Placeholder until real crouch animations exist.
	if _model:
		_model.scale.y = lerpf(_model.scale.y, 0.65 if crouched else 1.0, 0.3)
