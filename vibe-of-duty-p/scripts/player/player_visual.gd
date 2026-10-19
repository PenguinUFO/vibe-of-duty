class_name PlayerVisual
extends Node3D
## Third-person body of another player: a blockout Mannequin (scripts/player/mannequin.gd) holding the weapon, and a
## name tag. Everything here is cosmetic and fed from data every machine already has (velocity, stance and aiming
## flags, aim pitch, weapon, shot events); gameplay never depends on it. The head hitbox (LagComp) uses the same
## Mannequin.head_offset as the pose, so it matches the body. The legs are driven by this node's own movement on
## screen (measured each frame), so any mover - a puppet, a replay ghost, a running target - walks right.

const NAME_TAG_HEIGHT := 2.15
const CROUCH_FREQ := 3.2      # Hz: going down / up follows a spring, with a little dip past the end
const CROUCH_DAMPING := 0.6
const ADS_BLEND_TIME := 0.15  # s to raise / lower the weapon

var _mannequin: Mannequin
var _weapon := WeaponView.new()
var _tag: Label3D
var _dead := false
var _pitch := 0.0
var _crouch_target := false
var _crouch_v := 0.0
var _sliding := false
var _last_pos := Vector3.INF
var _velocity := Vector3.ZERO     # world, of this node as drawn (smoothed)
var _air := false
var _fall_speed := 0.0            # fastest fall of the current flight (dust on landing)
var _dust_t := 0.0
var _reloading := false
var _reload_t := -1.0             # s into the reload being shown, -1 = none
var _mantling := false
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


## Reloading (from the snapshot flags): plays the reload over the weapon's reload time. When it stops early (or
## the flag arrives late) the animation hurries to its end instead of snapping.
func set_reloading(reloading: bool) -> void:
	if reloading and not _reloading and not _dead:
		_reload_t = 0.0
	_reloading = reloading


## Vaulting (from the snapshot flags); `top_y`: world height of the ledge's top. The hands go onto the ledge in
## front of the body as it is when the vault starts.
func set_mantling(mantling: bool, top_y: float) -> void:
	if mantling and not _mantling and _mannequin:
		var forward := -global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := forward.cross(Vector3.UP)
		var center := global_position + forward * 0.5  # just past the edge (the capsule, radius 0.35, stops short of the wall)
		_mannequin.mantle_hands = [Vector3(center.x, top_y, center.z) - right * 0.2,
				Vector3(center.x, top_y, center.z) + right * 0.2]
		_mannequin.mantle_top = top_y
	_mantling = mantling


## Sliding: the legs hold still instead of running.
func set_sliding(sliding: bool) -> void:
	_sliding = sliding


## Whether the player aims down sights (from the snapshot flags).
func set_ads(aiming: bool) -> void:
	_ads_target = aiming


## Poses the body for this frame (or moves the ragdoll on). The legs follow this node's movement as measured here;
## `_local_velocity` (the caller's idea of it) is not needed for that.
func update_motion(delta: float, _local_velocity: Vector3, on_floor: bool = true) -> void:
	if _mannequin == null:
		return
	_measure(delta)
	if _dead:
		_mannequin.step_ragdoll(delta)
		return
	if delta > 0.0:
		var w := TAU * CROUCH_FREQ
		var target := 1.0 if _crouch_target else 0.0
		_crouch_v += (w * w * (target - _mannequin.crouch) - 2.0 * CROUCH_DAMPING * w * _crouch_v) * minf(delta, 0.05)
		_mannequin.crouch = clampf(_mannequin.crouch + _crouch_v * minf(delta, 0.05), -0.08, 1.08)
	_mannequin.ads = move_toward(_mannequin.ads, 1.0 if _ads_target and not _mantling else 0.0, delta / ADS_BLEND_TIME)
	_mannequin.pitch = _pitch
	_mannequin.mantle = move_toward(_mannequin.mantle, 1.0 if _mantling else 0.0, delta * (10.0 if _mantling else 5.0))
	_update_reload(delta)
	_update_air(on_floor)
	_mannequin.animate(delta, global_basis.inverse() * _velocity, not _air, _sliding)
	_mannequin.pose()


func _update_reload(delta: float) -> void:
	if _reload_t < 0.0:
		_mannequin.reload = -1.0
		return
	var length := WeaponDB.get_def(_weapon.weapon_index).reload_time
	_reload_t += delta * (1.0 if _reloading else 3.0)
	if _reload_t >= length:
		_reload_t = -1.0
		_mannequin.reload = -1.0
	else:
		_mannequin.reload = _reload_t / length


## In the air or not: the caller's `on_floor` (players know it) or this node's own vertical movement (replay
## ghosts, targets); once off the ground it stays airborne until a short ray finds the floor under the feet.
func _update_air(on_floor: bool) -> void:
	var vy := _velocity.y
	if _air:
		_fall_speed = maxf(_fall_speed, -vy)
		_air = not (vy <= 0.5 and _floor_below(0.15))
		if not _air and _fall_speed > 3.0 and visible:
			Dust.burst(self, global_position, (_fall_speed - 3.0) / 4.0)
	else:
		_air = not on_floor or vy > 1.5 or (vy < -2.5 and not _floor_below(0.3))
		_fall_speed = 0.0
	_dust_t -= get_process_delta_time()
	var flat := Vector3(_velocity.x, 0.0, _velocity.z)
	if _sliding and not _air and flat.length() > 2.0 and _dust_t <= 0.0 and visible:
		_dust_t = 0.05
		Dust.trail(self, global_position, flat)


func _floor_below(depth: float) -> bool:
	var from := global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, global_position + Vector3.DOWN * depth, Layers.WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## A shot from `origin` that ended at `end` (world): if it ended on this body, the body flinches.
func react_to_shot(origin: Vector3, end: Vector3) -> void:
	if _mannequin == null or _dead or not visible:
		return
	var zone := _mannequin.hit_zone(end)
	if zone != "":
		_mannequin.flinch(end - origin, zone == "head", end)


## Velocity of this node as drawn, smoothed; a jump of more than a few metres (teleport, respawn) is not movement.
func _measure(delta: float) -> void:
	var pos := global_position
	if _last_pos.is_finite() and delta > 0.0:
		var v := (pos - _last_pos) / delta
		if v.length() < 25.0:
			_velocity = _velocity.lerp(v, 1.0 - exp(-15.0 * delta))
	_last_pos = pos


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


## Death: the body falls as a ragdoll (Mannequin.start_ragdoll), away from `from` (the killer's position, world;
## INF if unknown) - harder for a head shot; alive again, it stands up at once.
func set_dead(dead: bool, from := Vector3.INF, head_hit := false) -> void:
	if dead == _dead:
		return
	_dead = dead
	if _tag:
		_tag.visible = not dead
	if _mannequin == null:
		return
	if dead:
		_mannequin.start_ragdoll(_velocity, from, head_hit)
	else:
		_mannequin.stop_ragdoll()
		_crouch_v = 0.0
	_reload_t = -1.0
	_reloading = false
	_mantling = false
	_mannequin.mantle = 0.0


## Sticks `node` onto the body part nearest to `world_pos` (it then falls with that part).
func attach_to_body(node: Node3D, world_pos: Vector3) -> void:
	var part: Node3D = _mannequin.part_near(world_pos) if _mannequin else self
	part.add_child(node)
	node.global_position = world_pos
