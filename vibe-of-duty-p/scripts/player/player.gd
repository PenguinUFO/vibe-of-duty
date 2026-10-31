class_name Player
extends PlayerBots
## First-person character. Movement is driven by step(cmd, dt), a deterministic function of the previous state and
## one PlayerCmd, so the server can run it and the client can replay it for prediction.
##
## The class is a chain of scripts, each extending the previous one; a part calls only itself and the parts above it
## in this list. Other scripts use only Player.
##   player_base.gd      PlayerBase      constants, all state (vars), node references
##   player_mantle.gd    PlayerMantle    vaulting over obstacles
##   player_weapons.gd   PlayerWeapons   weapon tick, shots, hit tests, shot cosmetics
##   player_movement.gd  PlayerMovement  step(): walk, sprint, slide, crouch, jump; teleport
##   player_health.gd    PlayerHealth    damage, regeneration, death, respawn, ammo pickup, kid mode, oink
##   player_net.gd       PlayerNet       commands, snapshots, reconciliation, interpolation of other players
##   player_view.gd      PlayerView      camera effects, viewmodel, HUD, F3 overlay, stick look, aim assist
##   player_bots.gd      PlayerBots      scripted input for tests (--bot-*)
##   player.gd           Player          Godot callbacks (_ready, input, physics, process), input gathering

func _ready() -> void:
	_shape.radius = RADIUS
	_probe_shape.radius = RADIUS - 0.03
	_probe_shape.height = STAND_HEIGHT - 0.06
	_probe_crouch_shape.radius = RADIUS - 0.03
	_probe_crouch_shape.height = CROUCH_HEIGHT - 0.06
	_collision.shape = _shape
	_apply_stance()
	_head.position.y = STAND_EYE
	collision_mask = Layers.PLAYER_MOVE_MASK
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(46.0)
	floor_stop_on_slope = true
	look_yaw = rotation.y
	body_yaw = rotation.y
	weapons.infinite_reserve = Game.training  # training maps: ammo never runs out (only reloads)
	_camera.current = is_local
	_camera.fov = Settings.fov
	_hud.visible = is_local
	set_physics_process(control != Mode.PUPPET)
	if not is_local:
		_visual.setup(peer_id, player_name)
		_visual.set_weapon(weapons.index, weapons.current())
	_prev_pos = global_position
	_curr_pos = global_position
	_prev_yaw = rotation.y
	_curr_yaw = rotation.y
	if is_local:
		# The local camera is decoupled from the 60 Hz physics body: it follows an interpolated
		# position and takes mouse look directly, so view rotation never waits for a physics tick.
		_head.top_level = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_view = WeaponView.new()
		_view.is_viewmodel = true
		_camera.add_child(_view)
		_view.set_weapon(weapons.index, weapons.current())
		# First-person arms made from the same character as the body other players see.
		_arms = FirstPersonArms.new()
		_camera.add_child(_arms)
		_arms.setup(peer_id, _view)
		_build_hud()
		_prev_look = Vector2(look_yaw, look_pitch)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_debug_shown = not _debug_shown  # developer overlay: fps, speed, network stats
		_debug_timer = 0.0
	if event.is_action_pressed("oink") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_try_oink()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := Settings.mouse_sensitivity * lerpf(1.0, weapons.current().ads_fov_mult, weapons.ads)
		look_yaw -= event.relative.x * sens
		look_pitch = clampf(look_pitch - event.relative.y * sens, -MAX_PITCH, MAX_PITCH)
		if event.relative.length() > 2.0:
			_pad_look = false  # aiming with the mouse: no aim assist
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		_pad_look = true


func _physics_process(delta: float) -> void:
	_prev_pos = _curr_pos
	_prev_yaw = _curr_yaw
	if control == Mode.LOCAL:
		_reconcile_pending(delta)
		if Game.net_perturb and _cmd_seq > 0 and _cmd_seq % 240 == 0:
			global_position += Vector3(0.6, 0.0, 0.3)  # test hook: fake a prediction error
		var cmd := _gather_cmd(delta)
		cmd.view_tick = world.get_view_tick() if world != null else 0.0
		step(cmd, delta)
		_send_cmd(cmd)
		if _jumped_this_step:
			_jump_buffer = 0.0
	elif control == Mode.REMOTE_SERVER:
		# One command per tick; a backlog (e.g. after a network burst) is worked off with spare budget.
		_step_budget = minf(_step_budget + CMD_BUDGET_PER_TICK, CMD_BUDGET_MAX)
		while _step_budget >= 1.0 and not _cmd_queue.is_empty():
			_step_budget -= 1.0
			step(_pop_server_cmd(), delta)
			_record_host_sample()
	_curr_pos = global_position
	_curr_yaw = body_yaw


func _process(delta: float) -> void:
	# Camera presentation only; none of this affects simulation.
	if control == Mode.PUPPET:
		_update_puppet()
		return
	var eye := 0.35 if not alive else (CROUCH_EYE if is_crouched else STAND_EYE)
	_eye_height = lerpf(_eye_height, eye, 1.0 - exp(-14.0 * delta))
	var speed := flat_speed()
	var def := weapons.current()
	if is_local:
		_stick_look(delta)
		_view_recoil = _view_recoil.lerp(weapons.recoil, 1.0 - exp(-25.0 * delta))
		_correction *= exp(-CORRECTION_DECAY * delta)
		if not alive:
			_update_death_drift(delta)
		var pos := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction()) + _correction + _death_drift
		var view_angles := Vector3(look_pitch + _view_recoil.x, look_yaw + _view_recoil.y, 0.0)
		var frame := Gravity.frame(pos)
		_head.global_transform = Transform3D(frame * Basis.from_euler(view_angles), pos + frame.y * _eye_height)
	else:
		_head.position.y = _eye_height
		# Server-simulated remote player seen on the host: drive its body like a puppet's. The physics body moves
		# at 60 Hz, and in uneven steps when their commands arrive in bursts; the model is drawn from the buffered
		# poses instead (_buffered_pose), smoothly at any frame rate. The host's shots are judged at shown_tick.
		var shown := _buffered_pose(delta)
		if not shown.is_empty():
			_visual.position = global_transform.basis.inverse() * (shown["pos"] - global_position)
			_visual.rotation.y = angle_difference(body_yaw, shown["yaw"])
			shown_tick = shown["tick"]
		_shown_pitch = shown.get("pitch", _head.rotation.x)
		_visual.set_aim_pitch(_shown_pitch)
		_visual.set_ads(aiming)
		_visual.set_crouched(is_crouched)
		_visual.set_sliding(is_sliding)
		_visual.set_reloading(weapons.is_reloading())
		_visual.set_meleeing(weapons.is_meleeing())
		_visual.set_mantling(is_mantling, _mantle_up)
		_visual.update_motion(delta, global_transform.basis.inverse() * velocity, is_on_floor())
	var sprinting_fov := 5.0 if is_sprinting and speed > WALK_SPEED + 0.5 else 0.0
	var target_fov := lerpf(Settings.fov, Settings.fov * def.ads_fov_mult, weapons.ads) + sprinting_fov
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-8.0 * delta))
	_cam_roll = lerpf(_cam_roll, 0.7 if not alive else (-0.05 if is_sliding else 0.0), 1.0 - exp(-10.0 * delta))
	_camera.rotation.z = _cam_roll
	if is_local:
		_update_camera_fx(delta, speed)
		_update_viewmodel(delta, speed)
		_update_hud(speed, delta)


func _gather_cmd(delta: float) -> PlayerCmd:
	if Game.bot_mode:
		return _bot_cmd(delta)
	var cmd := PlayerCmd.new()
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cmd.move =Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		# Gamepad: a press of Y (or L3) sprints until you stop pushing forward, so the thumb is free for the look stick.
		if Input.is_action_just_pressed("sprint_toggle"):
			_sprint_latched = true
		if cmd.move.y > -0.3:
			_sprint_latched = false
		cmd.crouch = Input.is_action_pressed("crouch")
		cmd.jump_held = Input.is_action_pressed("jump")
		cmd.fire = Input.is_action_pressed("fire")
		cmd.aim = Input.is_action_pressed("aim")
		cmd.reload = Input.is_action_just_pressed("reload")
		cmd.melee = Input.is_action_just_pressed("melee")
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = JUMP_BUFFER_TIME
		# Any other action ends a latched sprint; press Y / L3 again to sprint on.
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("crouch") or cmd.fire or cmd.aim \
				or cmd.reload or cmd.melee:
			_sprint_latched = false
		cmd.sprint = Input.is_action_pressed("sprint") or _sprint_latched
	cmd.jump = _jump_buffer > 0.0
	return cmd
