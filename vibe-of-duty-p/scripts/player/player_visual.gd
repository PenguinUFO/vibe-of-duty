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
var _weapon := WeaponView.new()
var _tag: Label3D
var _dead := false


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
	_tag = tag
	tag.text = display_name
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0007
	tag.outline_size = 8
	tag.position.y = NAME_TAG_HEIGHT
	add_child(tag)

	_weapon.position = Vector3(0.2, 1.25, -0.2)
	add_child(_weapon)


func set_crouched(crouched: bool) -> void:
	# Placeholder until real crouch animations exist.
	if _model and not _dead:
		_model.scale.y = lerpf(_model.scale.y, 0.65 if crouched else 1.0, 0.3)


func set_weapon(index: int) -> void:
	_weapon.set_weapon(index)


## Pitches the held weapon with the player's aim.
func set_aim_pitch(pitch: float) -> void:
	_weapon.rotation.x = pitch


func show_shot() -> void:
	_weapon.flash()


func muzzle_global_position() -> Vector3:
	return _weapon.muzzle_global_position()


## Placeholder death pose: the body falls over backwards; no ragdoll yet.
func set_dead(dead: bool) -> void:
	_dead = dead
	_weapon.visible = not dead
	if _tag:
		_tag.visible = not dead
	if _model:
		_model.rotation.x = -PI * 0.5 if dead else 0.0
		_model.position.y = 0.25 if dead else 0.0
		_model.scale.y = 1.0
