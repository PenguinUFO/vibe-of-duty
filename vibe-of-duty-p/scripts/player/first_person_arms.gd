class_name FirstPersonArms
extends Node3D
## First-person arms of the local player: the mannequin's arm parts (Mannequin.make_arm), child of the camera.
## They are not animated on their own: every frame, after WeaponView has posed the viewmodel (hip / ADS blend,
## recoil, sway, reload dip, wall retraction), both arms reach for the weapon by IK - right palm on the pistol grip,
## left palm under the handguard (WeaponDef.right_hand / left_hand) - so the hands follow the gun.

const SHOULDER_R := Vector3(0.19, -0.27, 0.05)  # camera space; below and just behind the eye, out of view
const SHOULDER_L := Vector3(-0.2, -0.27, 0.05)
const LENGTH_SCALE := 1.3   # first-person arms are always "too long": the gun sits further out than in real life
const THICKNESS := 0.8      # and a bit slimmer, or they fill the screen
const RIGHT_POLE := Vector3(1.0, -1.0, 0.25)
const LEFT_POLE := Vector3(-0.6, -1.0, 0.0)
const POUCH := Vector3(-0.2, -0.6, -0.2)  # camera space: where the left hand swaps magazines, below the view
const PUNCH := Vector3(-0.1, -0.15, -0.56)  # camera space: the left hoof at full reach of a punch, just below the middle

var _weapon: WeaponView
var ledge_weight := 0.0                                 # 0..1: hands go from the gun to the ledge (vaulting)
var reload := -1.0                                      # reload progress 0..1 (-1: none): the left hand reloads
var melee := -1.0                                       # punch progress 0..1 (-1: none): the left hoof punches
var ledge_hands: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # world: left, right
var _right: Dictionary
var _left: Dictionary


func setup(peer_id: int, weapon: WeaponView) -> void:
	_weapon = weapon
	var accent := Mannequin.color_for(peer_id)
	_right = Mannequin.make_arm(self, "R", accent, LENGTH_SCALE, THICKNESS)
	_left = Mannequin.make_arm(self, "L", accent, LENGTH_SCALE, THICKNESS)
	for mesh in find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # floating arms


## Reload: the left hand follows Mannequin.reload_hand (gun view space) - to the magazine, down out of view to a
## pouch and back, the handle - and carries the magazine while it holds it. Returns the hand's target.
func _reload_hand(def: WeaponDef, handguard: Vector3, s: float) -> Vector3:
	var mag_grip := _weapon.mag_grip_point()
	if not mag_grip.is_finite():
		return handguard
	var seated := Mannequin._view_point(mag_grip) * s
	var xform := transform.affine_inverse() * _weapon.transform
	var pouch := xform.affine_inverse() * POUCH  # pouch is in arms (camera) space
	var handle := Mannequin._view_point(def.charging_handle) * s if def.charging_handle.is_finite() else Vector3.INF
	var path := Mannequin.reload_hand(reload, handguard, seated, pouch, handle, s)
	var hand: Vector3 = path[0]
	_weapon.set_mag_shift(Mannequin._view_point((hand - seated) / s) if path[1] else Vector3.ZERO)
	return hand


## Call after the viewmodel has been posed for this frame.
func pose() -> void:
	if _weapon == null or _weapon.weapon_index < 0:
		return
	var def := _weapon.def
	var xform := transform.affine_inverse() * _weapon.transform  # both are children of the camera
	var s := WeaponView.VIEWMODEL_SCALE
	var right := Mannequin._view_point(def.right_hand) * s
	var left := Mannequin._view_point(def.left_hand) * s
	var right_palm := xform * right
	if reload >= 0.0:
		left = _reload_hand(def, left, s)
	else:
		_weapon.set_mag_shift(Vector3.ZERO)
	var left_palm := xform * left
	var right_fingers := xform.basis * Mannequin.RIGHT_FINGERS
	var left_fingers := xform.basis * Mannequin.LEFT_FINGERS
	var right_dir := xform.basis * Mannequin.RIGHT_PALM
	var left_dir := xform.basis * Mannequin.LEFT_PALM
	var punch := Mannequin.punch_curve(melee)
	if punch.y > 0.0:
		left_palm = left_palm.lerp(PUNCH, punch.x)
		left_fingers = left_fingers.lerp(Vector3.FORWARD, punch.y)
		left_dir = left_dir.lerp(Vector3.DOWN, punch.y)
	if ledge_weight > 0.0:
		# Vaulting: palms flat on the ledge, fingers over its edge.
		var to_arms := global_basis.inverse()
		var forward := to_arms * (-global_basis.z).slide(Vector3.UP).normalized()
		var down := to_arms * Vector3.DOWN
		right_palm = right_palm.lerp(to_local(ledge_hands[1]), ledge_weight)
		left_palm = left_palm.lerp(to_local(ledge_hands[0]), ledge_weight)
		right_fingers = right_fingers.lerp(forward, ledge_weight)
		left_fingers = left_fingers.lerp(forward, ledge_weight)
		right_dir = right_dir.lerp(down, ledge_weight)
		left_dir = left_dir.lerp(down, ledge_weight)
	Mannequin.pose_arm(_right, SHOULDER_R, right_palm, right_fingers, right_dir, RIGHT_POLE)
	Mannequin.pose_arm(_left, SHOULDER_L, left_palm, left_fingers, left_dir, LEFT_POLE)
