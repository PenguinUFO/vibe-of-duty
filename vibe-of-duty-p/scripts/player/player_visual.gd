class_name PlayerVisual
extends Node3D
## Third-person body of another player: a blockout Mannequin (scripts/player/mannequin.gd) holding the weapon, and a
## name tag. Everything here is cosmetic and fed from data every machine already has (velocity, stance and aiming
## flags, aim pitch, weapon, shot events); gameplay never depends on it. The head hitbox (LagComp) uses the same
## Mannequin.head_offset as the pose, so it matches the body.

const NAME_TAG_HEIGHT := 2.15
const CROUCH_TIME := 0.18     # s to go down / up
const ADS_BLEND_TIME := 0.15  # s to raise / lower the weapon

var _mannequin: Mannequin
var _weapon := WeaponView.new()
var _tag: Label3D
var _dead := false
var _pitch := 0.0
var _crouch_target := false
var _ads_target := false
var _tag_check := 0.0           # seconds to the next occlusion test of the name tag


static func preload_scenes() -> void:
	pass  # the mannequin is built from primitives; WeaponDB preloads the weapon scenes


func setup(peer_id: int, display_name: String) -> void:
	_mannequin = Mannequin.new()
	add_child(_mannequin)
	_mannequin.build(Mannequin.color_for(peer_id))
	_weapon.top_level = true  # placed by the mannequin every frame
	add_child(_weapon)
	_mannequin.weapon = _weapon

	_tag = Label3D.new()
	_tag.text = display_name
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0007
	_tag.outline_size = 8
	_tag.position.y = NAME_TAG_HEIGHT
	add_child(_tag)


func set_weapon(index: int) -> void:
	_weapon.set_weapon(index)
	if _mannequin:
		_mannequin.def = WeaponDB.get_def(index)


## Aim pitch of the player in radians (positive = up).
func set_aim_pitch(pitch: float) -> void:
	_pitch = pitch


func set_crouched(crouched: bool) -> void:
	_crouch_target = crouched


## Whether the player aims down sights (from the snapshot flags).
func set_ads(aiming: bool) -> void:
	_ads_target = aiming


## Poses the body for this frame. `local_velocity`: x = right, z = backwards in the player's frame (m/s).
## (Locomotion - stepping legs - comes with the procedural animation; for now the body stands.)
func update_motion(delta: float, _local_velocity: Vector3, _on_floor: bool = true) -> void:
	if _mannequin == null or _dead:
		return
	_mannequin.crouch = move_toward(_mannequin.crouch, 1.0 if _crouch_target else 0.0, delta / CROUCH_TIME)
	_mannequin.ads = move_toward(_mannequin.ads, 1.0 if _ads_target else 0.0, delta / ADS_BLEND_TIME)
	_mannequin.pitch = _pitch
	_mannequin.pose()


## The name tag is drawn over everything, so it is hidden while a wall is between it and the camera.
func _process(delta: float) -> void:
	if _tag == null or _dead:
		return
	_tag_check -= delta
	if _tag_check > 0.0:
		return
	_tag_check = 0.12
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var head := global_position + Vector3.UP * 1.6
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, head, Layers.WORLD)
	_tag.visible = get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func show_shot() -> void:
	_weapon.flash()


func muzzle_global_position() -> Vector3:
	return _weapon.muzzle_global_position()


## Placeholder death pose: the body falls over backwards (a ragdoll comes with the procedural animation).
func set_dead(dead: bool) -> void:
	_dead = dead
	_weapon.visible = not dead
	if _tag:
		_tag.visible = not dead
	if _mannequin:
		_mannequin.rotation.x = -PI * 0.5 if dead else 0.0
		_mannequin.position.y = 0.25 if dead else 0.0
