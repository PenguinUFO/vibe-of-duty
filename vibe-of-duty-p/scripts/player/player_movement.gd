class_name PlayerMovement
extends PlayerWeapons
## Player, part 4 of 9: step(): walking, sprint, slide, crouch, jump; stance; teleport.
## The parts form a chain of scripts, each extending the previous one (map: player.gd).

## Teleports the player and resets all movement state.
func teleport(xform: Transform3D) -> void:
	global_transform = Transform3D(Basis.IDENTITY, xform.origin)
	look_yaw = xform.basis.get_euler().y
	look_pitch = 0.0
	rotation.y = look_yaw
	_prev_pos = global_position
	_curr_pos = global_position
	_prev_yaw = rotation.y
	_curr_yaw = rotation.y
	velocity = Vector3.ZERO
	is_mantling = false
	_floor_y = global_position.y
	_snapshots.clear()
	_history.clear()
	_pending_state = []
	_correction = Vector3.ZERO
	_end_slide()
	is_crouched = false
	_apply_stance()


## Advances the simulation by one fixed tick.
func step(cmd: PlayerCmd, dt: float) -> void:
	if not alive or Game.is_frozen():
		var dead := PlayerCmd.new()  # a dead player keeps looking where they were, but can do nothing
		dead.yaw = cmd.yaw
		dead.pitch = cmd.pitch
		cmd = dead
	rotation.y = cmd.yaw
	if not is_local:
		_head.rotation.x = cmd.pitch
	var on_floor := is_on_floor()
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	_jumped_this_step = false

	# A vault in progress overrides normal movement (and blocks shooting / aiming).
	_mantle_cooldown = maxi(_mantle_cooldown - 1, 0)
	if is_mantling:
		_mantle_update(dt)
		_weapon_step(_mantle_weapon_cmd(cmd), dt)
		return

	# Slide start / update.
	_slide_cooldown = maxf(_slide_cooldown - dt, 0.0)
	var crouch_pressed := cmd.crouch and not _prev_crouch
	_prev_crouch = cmd.crouch
	var heft := weapons.current().move_speed_mult  # a heavy weapon: a sprint is slower, so is the slide it starts
	if not is_sliding and crouch_pressed and on_floor and _slide_cooldown <= 0.0 \
			and horiz.length() >= SLIDE_MIN_SPEED * heft:
		is_sliding = true
		_slide_time = 0.0
		_slide_dir = horiz.normalized()
		_slide_speed = maxf(horiz.length(), SLIDE_START_SPEED * heft)
		_sfx("slide")
	var slide_finished := false
	if is_sliding:
		_slide_time += dt
		_slide_speed -= SLIDE_FRICTION * dt
		slide_finished = not cmd.crouch or not on_floor or _slide_speed < SLIDE_END_SPEED \
				or _slide_time > SLIDE_MAX_TIME

	# Stance (capsule height).
	if cmd.crouch or is_sliding:
		is_crouched = true
	elif is_crouched and _can_stand():
		is_crouched = false
	_apply_stance()

	# Jumping at a tall obstacle vaults over it instead.
	var wants_vault := cmd.jump or (cmd.jump_held and not on_floor and cmd.move.y < -0.1)
	if wants_vault and not cmd.crouch and _mantle_cooldown <= 0 and _try_start_mantle(cmd):
		_jumped_this_step = true
		_end_slide()
		is_crouched = _mantle_low
		_apply_stance()
		_sfx("jump")
		_weapon_step(_mantle_weapon_cmd(cmd), dt)
		return

	# Horizontal movement.
	var wish := global_transform.basis * Vector3(cmd.move.x, 0.0, cmd.move.y)
	wish.y = 0.0
	var wish_len := minf(wish.length(), 1.0)
	wish = wish.normalized()
	var firing := weapons.wants_fire(cmd)
	is_sprinting = cmd.sprint and cmd.move.y < -0.1 and not is_crouched and not cmd.aim and not firing \
			and not weapons.is_meleeing()
	var top_speed: float = (SPRINT_SPEED * mods["sprint_mult"] if is_sprinting else WALK_SPEED) * mods["speed_mult"]
	if is_sliding:
		horiz = _slide_dir * _slide_speed
	elif on_floor:
		var ground_speed: float = (CROUCH_SPEED * mods["speed_mult"] if is_crouched else top_speed) * wish_len \
				* weapons.speed_mult()
		var rate := GROUND_ACCEL if wish_len > 0.0 else GROUND_FRICTION
		horiz = horiz.move_toward(wish * ground_speed, rate * dt)
	elif wish_len > 0.0:
		var add := clampf(top_speed * wish_len - horiz.dot(wish), 0.0, AIR_ACCEL * dt)
		horiz += wish * add
	velocity.x = horiz.x
	velocity.z = horiz.z

	# Vertical movement.
	if on_floor:
		velocity.y = 0.0
		if cmd.jump:
			velocity.y = JUMP_VELOCITY * mods["jump_mult"]
			_jumped_this_step = true
			slide_finished = is_sliding or slide_finished
			_sfx("jump")
	else:
		velocity.y -= GRAVITY * dt
	if slide_finished:
		_end_slide()

	_prev_vy = velocity.y
	move_and_slide()
	_post_move(dt)
	_weapon_step(cmd, dt)


func _post_move(dt: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _prev_on_floor and _prev_vy < -LAND_SOUND_MIN_SPEED:
		_sfx("land", mods["land_db"])
	if on_floor and not _prev_on_floor and is_local and not _replaying:
		_land_impact = maxf(_land_impact, -_prev_vy)
	_prev_on_floor = on_floor
	if on_floor:
		_floor_y = global_position.y
	if on_floor and not is_sliding:
		_step_distance += Vector2(velocity.x, velocity.z).length() * dt
		if _step_distance >= STEP_STRIDE:
			_step_distance = 0.0
			_sfx("step", -8.0 if is_crouched else 0.0)
			if not _replaying:
				_bob_side = -_bob_side


func _end_slide() -> void:
	if is_sliding:
		is_sliding = false
		_slide_cooldown = SLIDE_COOLDOWN


func _can_stand() -> bool:
	return not test_move(global_transform, Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT))


func _apply_stance() -> void:
	var h := CROUCH_HEIGHT if is_crouched else STAND_HEIGHT
	_shape.height = h
	_collision.position.y = h * 0.5
	_stance_crouched = is_crouched
