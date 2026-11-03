class_name DroppedGun
extends RigidBody3D
## The akimbo's left gun thrown away empty (Docs/LOADOUT.md, "Акимбо"): tossed out of the left hand to the side and
## down, it tumbles onto the floor and lies there. Nobody can pick it up. Cosmetic, on every machine on its own: the
## shooter's from the first-person gun, the others' from the body's (PlayerVisual). Falls along Gravity (the station's
## floor too), collides with the level only; gone after LIFETIME s, the oldest first past MAX.

const LIFETIME := 30.0
const MAX := 16
const GRAVITY := 9.8
const TOSS := Vector3(-1.6, 0.6, -0.4)  # m/s in the gun's frame at the moment it is let go: out to the left, up, forward
const SPIN := Vector3(4.0, 2.0, 6.0)     # rad/s, about the gun's axes

static var _all: Array[DroppedGun] = []

var _age := 0.0


## Throws a copy of `from`'s gun (a WeaponView, as it is posed now) out of the hand; `velocity_base`: the thrower's
## velocity (world).
static func toss(context: Node, from: WeaponView, velocity_base: Vector3) -> void:
	if not context.is_inside_tree() or from.def == null:
		return
	var root := context.get_tree().current_scene
	if root == null:
		return
	var gun := DroppedGun.new()
	root.add_child(gun)
	var xform := from.global_transform.orthonormalized()  # a first-person gun is drawn smaller: life size on the floor
	gun.global_transform = xform
	gun._setup(from)
	gun.linear_velocity = velocity_base + xform.basis * TOSS
	gun.angular_velocity = xform.basis * SPIN
	_all.append(gun)
	while _all.size() > MAX:
		var oldest: DroppedGun = _all.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


func _setup(from: WeaponView) -> void:
	collision_layer = 0
	collision_mask = Layers.WORLD
	gravity_scale = 0.0  # Gravity's own direction (_physics_process)
	continuous_cd = true
	var view := WeaponView.new()
	add_child(view)
	view.set_weapon(from.weapon_index, from.def)
	# A box round the model (its meshes, in the gun's frame) for the floor to hold.
	var box := AABB()
	var first := true
	for node in view.find_children("*", "VisualInstance3D", true, false):
		var mesh := node as VisualInstance3D
		if not mesh.is_visible_in_tree():
			continue
		var aabb := (view.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	if first:
		box = AABB(Vector3(-0.03, -0.08, -0.12), Vector3(0.06, 0.16, 0.24))
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size.max(Vector3.ONE * 0.02)
	shape.shape = box_shape
	shape.position = box.get_center()
	add_child(shape)
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.2
	physics_material_override.friction = 0.8


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		_all.erase(self)
		queue_free()
		return
	if not sleeping:
		apply_central_force(-Gravity.up(global_position) * GRAVITY * mass)
