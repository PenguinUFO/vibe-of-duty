class_name PlayerView
extends PlayerNet
## Player, part 7 of 9: local camera effects, viewmodel, HUD, F3 overlay, stick look and aim assist.
## The parts form a chain of scripts, each extending the previous one (map: player.gd).

## Right-stick look (the mouse turns the view in _unhandled_input). Slower while aiming, like the mouse.
## With the stick (not the mouse) the aim assist slows it down over an enemy and follows a moving one.
func _stick_look(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or Game.bot_mode or not alive:
		_aim_assist.target_id = -1
		return
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO:
		_pad_look = true
	var turn := Vector2.ZERO
	if _pad_look:
		turn = _aim_assist.update(_head.global_position, look_yaw, look_pitch, weapons.ads,
				Settings.effective_aim_assist(), _assist_targets(), _assist_visible,
				Settings.aim_assist_reach(), Settings.aim_assist_range())
	if stick != Vector2.ZERO:
		stick = stick.normalized() * pow(stick.length(), STICK_CURVE)
		var speed := STICK_LOOK_SPEED * Settings.stick_sensitivity * _aim_assist.slowdown \
				* lerpf(1.0, weapons.current().ads_fov_mult, weapons.ads)
		turn -= stick * speed * delta
	look_yaw += turn.x
	look_pitch = clampf(look_pitch + turn.y, -MAX_PITCH, MAX_PITCH)
	_turn_rate = lerpf(_turn_rate, turn.length() / maxf(delta, 0.0001), 1.0 - exp(-8.0 * delta))


## Aim assist targets: every other living player, as a line from mid-torso to the head centre (the hitboxes).
func _assist_targets() -> Array:
	var targets := []
	if world == null:
		return targets
	for id in world.players:
		var other = world.players[id]
		if not is_instance_valid(other) or other == self or not other.alive:
			continue
		var state: Dictionary = other.hitbox_state()
		var body := LagComp.body_segment(state)
		targets.append({"id": id, "a": body[0].lerp(body[1], 0.6), "b": LagComp.head_center(state)})
	for node in get_tree().get_nodes_in_group(Target.GROUP):  # training targets
		var target := node as Target
		if target.alive:
			var t_state := target.hitbox_state()
			var t_body := LagComp.body_segment(t_state)
			targets.append({"id": 100000 + target.get_instance_id() % 100000, "a": t_body[0].lerp(t_body[1], 0.6),
					"b": LagComp.head_center(t_state)})
	return targets


func _assist_visible(eye: Vector3, point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(eye, point, Layers.WORLD, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _build_hud() -> void:
	_hurt_rect = ColorRect.new()
	_hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette := ShaderMaterial.new()
	vignette.shader = HURT_SHADER
	_hurt_rect.material = vignette
	_hurt_rect.visible = false
	_hud.add_child(_hurt_rect)
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_hud.add_child(_crosshair)
	_damage_dirs = DamageIndicator.new()
	_damage_dirs.camera = _camera
	_hud.add_child(_damage_dirs)

	_ammo_hud = HudAmmo.new()
	_ammo_hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_hud.offset_left = -HudAmmo.SIZE.x - 24.0
	_ammo_hud.offset_top = -HudAmmo.SIZE.y - 20.0
	_ammo_hud.offset_right = -24.0
	_ammo_hud.offset_bottom = -20.0
	_hud.add_child(_ammo_hud)

	_health_hud = HudHealth.new()
	_health_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health_hud.offset_left = 24.0
	_health_hud.offset_top = -HudHealth.SIZE.y - 20.0
	_health_hud.offset_right = 24.0 + HudHealth.SIZE.x
	_health_hud.offset_bottom = -20.0
	_hud.add_child(_health_hud)

	_death_label = _make_hud_label(40)
	_death_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.visible = false
	_hud.add_child(_death_label)


func _make_hud_label(font_size: int) -> Label:
	var label := Label.new()
	label.theme_type_variation = "HudLabel"
	label.add_theme_font_size_override("font_size", font_size)
	return label


## Local player's view: a dip on landing (deeper for a harder fall; the gun jolts too), a light bob in step with
## the footsteps (Settings.view_bob; almost none while aiming), a short jolt when hit, and the vault (gun lowered,
## both hands on the ledge, view pitched down). Only the camera moves: aim and shots stay on the look angles.
func _update_camera_fx(delta: float, speed: float) -> void:
	var dt := minf(delta, 0.05)
	if _land_impact > 0.0:
		var impact := clampf(_land_impact, 0.0, 14.0)
		_cam_land_v -= impact * 0.045
		_view.land_jolt(impact / 8.0)
		if impact > 3.0:
			Dust.burst(self, global_position, (impact - 3.0) / 4.0)
		_land_impact = 0.0
	_dust_t -= dt
	if is_sliding and is_on_floor() and _dust_t <= 0.0:
		_dust_t = 0.05
		Dust.trail(self, global_position, Vector3(velocity.x, 0.0, velocity.z))
	var land := Mannequin.spring(Vector2(_cam_land, 0.0), Vector2(_cam_land_v, 0.0), Vector2.ZERO, 3.5, 0.55, dt)
	_cam_land = clampf(land[0].x, -0.12, 0.05)
	_cam_land_v = land[1].x

	var walking := alive and is_on_floor() and not is_sliding and not is_mantling
	var bob_target := Settings.view_bob * clampf(speed / WALK_SPEED, 0.0, 1.3) * (1.0 - 0.85 * weapons.ads) if walking else 0.0
	_bob_amount = move_toward(_bob_amount, bob_target, dt * 4.0)
	var step := _step_distance / STEP_STRIDE  # 0 at each footfall (the step sound)
	var sway := sin(PI * step) * _bob_side * _bob_amount
	var bob := Vector3(0.008 * sway, -0.014 * _bob_amount * (0.5 + 0.5 * cos(TAU * step)), 0.0)

	var punch := Mannequin.spring(_punch, _punch_v, Vector2.ZERO, 5.0, 0.5, dt)
	_punch = (punch[0] as Vector2).clamp(Vector2(-0.06, -0.06), Vector2(0.06, 0.06))  # 3.4 degrees at most
	_punch_v = punch[1]

	if is_mantling and not _ledge_set:
		var forward := Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))
		var right := forward.cross(Vector3.UP)
		var center := _mantle_up + forward * 0.45
		_arms.ledge_hands = [center - right * 0.22, center + right * 0.22]
	_ledge_set = is_mantling
	_mantle_view = move_toward(_mantle_view, 1.0 if is_mantling and alive else 0.0, dt * 8.0)
	_view.lowered = _mantle_view
	_arms.ledge_weight = _mantle_view

	_camera.position = bob + Vector3(0.0, _cam_land - 0.04 * _mantle_view, 0.0)
	_camera.rotation = Vector3(_punch.x - 0.12 * _mantle_view, 0.0, _cam_roll + _punch.y + 0.004 * sway)


func _update_viewmodel(delta: float, speed: float) -> void:
	_view.set_weapon(weapons.index)
	_view.visible = alive
	_arms.visible = alive
	var look := Vector2(look_yaw, look_pitch)
	_look_delta = (look - _prev_look) / maxf(delta, 0.0001) * delta
	_look_delta.x = wrapf(_look_delta.x, -PI, PI)
	_prev_look = look
	_sprint_blend = move_toward(_sprint_blend, 1.0 if (is_sprinting or is_mantling) else 0.0, delta * 6.0)
	# Pull the weapon back when a wall is right in front of the camera.
	var cam_pos := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(cam_pos, cam_pos + forward * 1.2, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var wanted := 0.0
	if not hit.is_empty():
		wanted = clampf(1.1 - cam_pos.distance_to(hit["position"]), 0.0, 0.45)
	_retract = lerpf(_retract, wanted, 1.0 - exp(-18.0 * delta))
	_view.update_pose(delta, weapons.ads, weapons.reload_progress(), weapons.equip_progress(), _sprint_blend,
			speed, is_on_floor(), _look_delta, _retract)
	_arms.reload = weapons.reload_progress() if alive else -1.0
	_arms.pose()  # the hands follow the gun


func _update_hud(speed: float, delta: float) -> void:
	var def := weapons.current()
	_ammo_hud.set_state(def.display_name, weapons.mags[weapons.index], def.mag_size,
			HudAmmo.INFINITE if weapons.infinite_reserve else weapons.reserves[weapons.index], weapons.is_reloading())
	var spread := weapons.spread_angle(speed, is_crouched, not is_on_floor())
	var fov_rad := deg_to_rad(_camera.fov)
	var px := tan(spread) / tan(fov_rad * 0.5) * get_viewport().get_visible_rect().size.y * 0.5
	_crosshair.update_state(px if alive else 0.0, weapons.ads if alive else 1.0,
			weapons.reload_progress() if alive else -1.0)
	_ammo_hud.visible = alive
	_health_hud.set_health(health, max_health)
	if health < _last_health:
		_hurt_alpha = minf(1.0, 0.45 + 2.0 * float(_last_health - health) / max_health)
		if alive:
			Audio.play("hurt")
	_last_health = health
	_hurt_alpha = maxf(_hurt_alpha - delta * 1.6, 0.0)
	# Low health holds the vignette in, pulsing; dead (no kill cam) keeps it fully in.
	var low := clampf(1.0 - float(health) / (max_health * HudHealth.LOW), 0.0, 1.0)
	low *= 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 7.0)
	if not alive:
		low = 1.0
	_hurt_rect.visible = _hurt_alpha > 0.0 or low > 0.0
	var vignette := _hurt_rect.material as ShaderMaterial
	vignette.set_shader_parameter("hurt", _hurt_alpha)
	vignette.set_shader_parameter("low", low)
	death_time_left = maxf(death_time_left - delta, 0.0)
	_death_label.visible = not alive
	if not alive:
		_death_label.text = "ВЫ ПОГИБЛИ\n%s\nВозрождение через %.1f" % ["Вас убил %s" % killed_by if killed_by != "" else "", death_time_left]
	_debug_timer -= delta
	if _debug_timer > 0.0:
		return  # the debug overlay changes every frame; 10 Hz is plenty and saves text re-layout
	_debug_timer = 0.1
	if not _debug_shown:
		_debug.text = "Esc меню   Tab счёт"  # F3 (debug overlay) works, but is not advertised
		return
	var vault_line := "\nvault: %s" % _vault_note if Time.get_ticks_msec() < _vault_note_until else ""
	_debug.text = "%d FPS\nскорость %.1f м/с\n%s%s%s\nEsc меню   Tab счёт" % [
		Engine.get_frames_per_second(), speed,
		"подкат " if is_sliding else "", "присед " if is_crouched else "",
		"бег " if is_sprinting else ""]
	_debug.text += vault_line
	_debug.text += "\nsens: mouse x%.2f  stick x%.2f  view turn %.0f deg/s" % [
			Settings.mouse_sensitivity / 0.0025, Settings.stick_sensitivity, rad_to_deg(_turn_rate)]
	for device in Input.get_connected_joypads():
		# Raw stick values next to what the actions see: tells an engine / driver problem from a game one.
		_debug.text += "\npad%d L(%.2f %.2f) R(%.2f %.2f)  move(%.2f %.2f) look(%.2f %.2f)  %s" % [device,
				Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y),
				Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y),
				Input.get_vector("move_left", "move_right", "move_forward", "move_back").x,
				Input.get_vector("move_left", "move_right", "move_forward", "move_back").y,
				Input.get_vector("look_left", "look_right", "look_up", "look_down").x,
				Input.get_vector("look_left", "look_right", "look_up", "look_down").y,
				_assist_debug()]
		_debug.text += "\n" + Settings.focus_debug()
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_debug.text += "\nrtt %d ms  recon %d  err %.2f m" % [rtt_ms, recon_count, last_error]


## F3 line: "mouse" (no assist), "pad" (assist ready, no target) or the target it is working on right now.
func _assist_debug() -> String:
	if not _pad_look:
		return "assist off (mouse)"
	if _aim_assist.target_id < 0:
		return "assist: no target"
	var target_name: String = world.players[_aim_assist.target_id].player_name \
			if world != null and world.players.has(_aim_assist.target_id) else str(_aim_assist.target_id)
	return "assist: %s  strength %.2f  stick x%.2f" % [target_name, _aim_assist.strength, _aim_assist.slowdown]


func debug_weapon_string() -> String:
	return "w%d mag=%d/%d shots=%d mv=%d drop=%d gaps=%d qpeak=%d" % [weapons.index, weapons.mags[weapons.index], weapons.reserves[weapons.index],
			weapons.shots, mantle_count, cmds_dropped, gaps_filled, queue_peak]


## Local, dead on the train map's moving ground (beside the track): the capsule lies still on the solid plane under
## it, but the body rides away with the scenery (Ragdoll.ground_velocity), so the death view does too - speeding up
## over about a second, as the body tumbles before it lies on the ground.
func _update_death_drift(delta: float) -> void:
	if global_position.y > TrainScenery.GROUND_Y + 0.3:
		return
	var scenery := get_tree().get_first_node_in_group(TrainScenery.GROUP) as TrainScenery
	if scenery == null:
		return
	_death_drift_v = _death_drift_v.lerp(scenery.ground_velocity(), 1.0 - exp(-3.0 * delta))
	_death_drift += _death_drift_v * delta


## The pose as drawn on this machine, for the kill cam (KillCam): [feet position, yaw, aim pitch, crouched, aiming,
## alive, weapon index, reload progress (-1: none), sliding].
func drawn_pose() -> Array:
	var pos := global_position
	var yaw := rotation.y
	var pitch := _head.rotation.x
	if is_local:
		pos = _head.global_position - Vector3.UP * _eye_height
		yaw = look_yaw
		pitch = look_pitch
	elif control == Mode.REMOTE_SERVER:
		pos = _visual.global_position
		yaw = rotation.y + _visual.rotation.y
		pitch = _shown_pitch
	var reload := weapons.reload_progress() if control != Mode.PUPPET else _visual.reload_progress()
	return [pos, yaw, pitch, is_crouched, aiming if not is_local else weapons.ads > 0.5, alive, weapons.index, reload,
			is_sliding]


## While the kill cam plays, its stand-ins replace everybody's body and its camera the local player's view.
func set_kill_cam(on: bool) -> void:
	_visual.visible = not on
	if is_local:
		_hud.visible = not on
		if not on:
			_camera.make_current()
