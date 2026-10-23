class_name PlayerMantle
extends PlayerBase
## Player, part 2 of 9: vaulting over obstacles: finding a ledge and the vault itself.
## The parts form a chain of scripts, each extending the previous one (map: player.gd).

# Vaulting (mantle) over tall obstacles. Heights are measured from the player's feet.
const MANTLE_MIN_HEIGHT := 1.0        # lower ledges are simply jumped onto
const MANTLE_MAX_HEIGHT := 2.8        # jump + pull-up: covers the 2.6 m cover walls of the test level
const MANTLE_REACH := 1.1             # how far in front of the body the wall may be (m)
const MANTLE_RISE_SPEED := 5.5        # m/s while pulling up
const MANTLE_FORWARD_TICKS := 14      # ticks to step onto the ledge
const MANTLE_COOLDOWN_TICKS := 18
const MANTLE_EXIT_SPEED := 2.5
const MANTLE_MIN_TOP := 0.15          # m; a thinner wall top (a railing) cannot be stood on
const MANTLE_NARROW_TOP := 0.9        # m; a narrower top is stood on in its middle (see _try_start_mantle)
const MANTLE_MAX_DROP := 1.5          # m; a railing is vaulted over if there is floor at most this far below its top


## Looks for a vaultable ledge in front of the player and, if one is found, starts the mantle.
## Depends only on the world geometry, the position and cmd.yaw, so client and server agree.
func _try_start_mantle(cmd: PlayerCmd) -> bool:
	if cmd.move.y > 0.5:
		return _vault_fail("moving backwards")
	var space := get_world_3d().direct_space_state
	var feet := global_position
	var facing := Basis(Vector3.UP, cmd.yaw) * Vector3.FORWARD

	# 1. A wall in front of the body (at knee, waist and chest height).
	var wall := {}
	for height in [0.4, 0.9, 1.4]:
		var origin: Vector3 = feet + Vector3.UP * height
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + facing * MANTLE_REACH, Layers.WORLD))
		if not hit.is_empty() and absf(hit["normal"].y) < 0.3:
			wall = hit
			break
	if wall.is_empty():
		return _vault_fail("no wall within %.1f m ahead (face the wall)" % MANTLE_REACH)
	var wall_normal: Vector3 = wall["normal"]
	var inward := -Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()

	# 2. The top surface of the obstacle, probed from above just inside its face (not deeper: a railing is 8 cm, and
	# probing past it would find the floor behind it instead of its top).
	var probe: Vector3 = wall["position"] + inward * 0.03
	var top_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(probe.x, feet.y + MANTLE_MAX_HEIGHT + 0.4, probe.z), Vector3(probe.x, feet.y, probe.z), Layers.WORLD))
	if top_hit.is_empty() or top_hit["normal"].y < 0.7:
		return _vault_fail("no flat top to climb onto")
	var top_y: float = top_hit["position"].y
	# Measured from the ground we last stood on, so jumping first does not extend the reach beyond a vault.
	var ledge_height := top_y - _floor_y
	if ledge_height > MANTLE_MAX_HEIGHT:
		return _vault_fail("too high (%.1f m, max %.1f)" % [ledge_height, MANTLE_MAX_HEIGHT])
	if top_y - feet.y < 0.3:
		return _vault_fail("low ledge (%.1f m): just jump" % ledge_height)
	# A low ledge standing on the ground is simply jumped onto. One hanging in the air (a catwalk above a crate)
	# is not: the body hits its edge on the way up, so it is vaulted whatever its height.
	if ledge_height < MANTLE_MIN_HEIGHT and not _open_below(space, feet, facing, wall["position"]):
		return _vault_fail("low ledge (%.1f m): just jump" % ledge_height)
	# The pull-up rises straight up from where we stand: a ceiling over us ends it. Otherwise the probe from above
	# finds the roof on top of that ceiling (a cabin, a hold) and the vault goes through it.
	var column := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.5,
			Vector3(feet.x, top_y + 0.05, feet.z), Layers.WORLD))
	if not column.is_empty():
		return _vault_fail("ceiling overhead")

	# 3. Where we end up: on top of the ledge, a body radius behind its edge, stepping on with a little speed. On a
	# narrow top (a partition, a carriage side, a cover wall) on the middle of it instead, standing still, so the
	# step does not carry us off the far side.
	var width := 0.0  # how far the top reaches in from the wall face
	while width < MANTLE_NARROW_TOP and not _top_at(space, wall["position"] + inward * (width + 0.03), top_y).is_empty():
		width += 0.03
	var narrow := width < MANTLE_NARROW_TOP
	var exit_dir := Vector3.ZERO if narrow else inward
	var target: Vector3 = wall["position"] + inward * (width * 0.5 if narrow else RADIUS + 0.2)
	var over := width < MANTLE_MIN_TOP
	if over:
		# Too thin to stand on (a railing): vault over it onto whatever is right behind it, at most MANTLE_MAX_DROP
		# below its top. The vault carries us over at the railing's height; we then drop onto the floor behind.
		target = wall["position"] + inward * (width + RADIUS + 0.15)
		var land := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(target.x, top_y, target.z),
				Vector3(target.x, top_y - MANTLE_MAX_DROP, target.z), Layers.WORLD))
		if land.is_empty() or land["normal"].y < 0.7:
			return _vault_fail("top is too thin to stand on (%.2f m), nothing to land on behind it" % width)
		exit_dir = inward
		target.y = top_y  # carried over the top; the drop to the floor behind is an ordinary fall
	else:
		var target_hit := _top_at(space, target, top_y)
		if target_hit.is_empty():
			return _vault_fail("top is too thin to stand on")
		target.y = target_hit["position"].y

	# 4. Head room: along the pull-up column and at the destination. Where there is only room to crouch (a wall
	# under a catwalk), the vault ends crouched; the player stands up by themselves once there is room again.
	var up_point := Vector3(feet.x, top_y + 0.02, feet.z)
	_mantle_low = not _capsule_clear(up_point) or not _capsule_clear(target + Vector3.UP * 0.02)
	if _mantle_low and (not _capsule_clear(up_point, true) or not _capsule_clear(target + Vector3.UP * 0.02, true)):
		return _vault_fail("no head room, not even crouched")

	is_mantling = true
	mantle_count += 1
	_mantle_from = feet
	_mantle_up = up_point
	_mantle_to = target + Vector3.UP * 0.02
	_mantle_dir = exit_dir
	_mantle_tick = 0
	_mantle_rise = clampi(ceili((up_point.y - feet.y) / MANTLE_RISE_SPEED * 60.0), 8, 40)
	_mantle_total = _mantle_rise + MANTLE_FORWARD_TICKS
	return true


## True when the obstacle whose face is at `face` does not reach down to knee height in front of the feet: there
## is open space under its edge (it overhangs).
func _open_below(space: PhysicsDirectSpaceState3D, feet: Vector3, facing: Vector3, face: Vector3) -> bool:
	var reach := Vector2(face.x - feet.x, face.z - feet.z).length() + 0.1
	var knee := feet + Vector3.UP * 0.3
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(knee, knee + facing * reach, Layers.WORLD)).is_empty()


## The obstacle's top surface straight below `point` (near `top_y`), or {} if there is none.
func _top_at(space: PhysicsDirectSpaceState3D, point: Vector3, top_y: float) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(point.x, top_y + 0.4, point.z), Vector3(point.x, top_y - 0.3, point.z), Layers.WORLD))


## Records why a vault was refused (shown in the debug overlay of the local player) and returns false.
func _vault_fail(reason: String) -> bool:
	if is_local and not _replaying:
		_vault_note = reason
		_vault_note_until = Time.get_ticks_msec() + 2000
	return false


func _capsule_clear(feet_position: Vector3, crouched: bool = false) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _probe_crouch_shape if crouched else _probe_shape
	params.transform = Transform3D(Basis.IDENTITY, feet_position + Vector3.UP * ((CROUCH_HEIGHT if crouched else STAND_HEIGHT) * 0.5))
	params.collision_mask = Layers.PLAYER_MOVE_MASK
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func _mantle_update(dt: float) -> void:
	_mantle_tick += 1
	var target: Vector3
	if _mantle_tick <= _mantle_rise:
		target = _mantle_from.lerp(_mantle_up, float(_mantle_tick) / float(_mantle_rise))
	else:
		var f := float(_mantle_tick - _mantle_rise) / float(_mantle_total - _mantle_rise)
		target = _mantle_up.lerp(_mantle_to, 1.0 - (1.0 - f) * (1.0 - f))  # ease out
	velocity = (target - global_position) / dt
	global_position = target
	is_sprinting = false
	if _mantle_tick >= _mantle_total:
		is_mantling = false
		_mantle_cooldown = MANTLE_COOLDOWN_TICKS
		_floor_y = global_position.y
		velocity = _mantle_dir * MANTLE_EXIT_SPEED
		_sfx("land", -6.0 + mods["land_db"])


## While vaulting you cannot shoot, aim or reload (weapon switching still works).
func _mantle_weapon_cmd(cmd: PlayerCmd) -> PlayerCmd:
	var weapon_cmd := PlayerCmd.new()
	weapon_cmd.yaw = cmd.yaw
	weapon_cmd.pitch = cmd.pitch
	weapon_cmd.select = cmd.select
	return weapon_cmd
