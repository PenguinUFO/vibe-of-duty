class_name PlayerNet
extends PlayerHealth
## Player, part 6 of 9: commands to the server, snapshots, reconciliation, interpolation of other players.
## The parts form a chain of scripts, each extending the previous one (map: player.gd).

func _encode_cmd(cmd: PlayerCmd) -> Array:
	var flags := 0
	flags |= FLAG_JUMP if cmd.jump else 0
	flags |= FLAG_SPRINT if cmd.sprint else 0
	flags |= FLAG_CROUCH if cmd.crouch else 0
	flags |= FLAG_JUMP_HELD if cmd.jump_held else 0
	flags |= FLAG_FIRE if cmd.fire else 0
	flags |= FLAG_AIM if cmd.aim else 0
	flags |= FLAG_RELOAD if cmd.reload else 0
	flags |= FLAG_MELEE if cmd.melee else 0
	flags |= (cmd.select + 1) << FLAG_SELECT_SHIFT
	return [_cmd_seq, cmd.move, cmd.yaw, cmd.pitch, flags, cmd.view_tick]


func _decode_cmd(entry: Array) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	cmd.move = entry[1]
	cmd.yaw = entry[2]
	cmd.pitch = entry[3]
	var flags: int = entry[4]
	cmd.jump = flags & FLAG_JUMP != 0
	cmd.sprint = flags & FLAG_SPRINT != 0
	cmd.crouch = flags & FLAG_CROUCH != 0
	cmd.jump_held = flags & FLAG_JUMP_HELD != 0
	cmd.fire = flags & FLAG_FIRE != 0
	cmd.aim = flags & FLAG_AIM != 0
	cmd.reload = flags & FLAG_RELOAD != 0
	cmd.melee = flags & FLAG_MELEE != 0
	cmd.select = ((flags >> FLAG_SELECT_SHIFT) & SELECT_MASK) - 1
	cmd.view_tick = entry[5]
	return cmd


## Client: records this tick's command for reconciliation and sends it plus the previous ones
## (redundancy against packet loss).
func _send_cmd(cmd: PlayerCmd) -> void:
	_cmd_seq += 1
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return
	_history.append({"seq": _cmd_seq, "cmd": cmd, "pos": global_position, "w": weapons.to_array(),
			"t": Time.get_ticks_msec()})
	if _history.size() > HISTORY_MAX:
		_history.pop_front()
	_sent_cmds.append(_encode_cmd(cmd))
	if _sent_cmds.size() > CMD_REDUNDANCY:
		_sent_cmds.pop_front()
	if Game.sim_loss > 0.0 and randf() * 100.0 < Game.sim_loss:
		return  # test hook: this packet is "lost" on the way to the server
	if Game.sim_lag_ms > 0:
		_send_delayed(_sent_cmds.duplicate())
	else:
		submit_cmds.rpc_id(1, _sent_cmds)


func _send_delayed(entries: Array) -> void:
	await get_tree().create_timer(Game.sim_lag_ms / 1000.0).timeout
	if multiplayer.has_multiplayer_peer():
		submit_cmds.rpc_id(1, entries)


@rpc("any_peer", "unreliable_ordered")
func submit_cmds(entries: Array) -> void:
	# Out of the tree: the level is being left (Lobby) and cmds still arrive for a moment.
	if not is_inside_tree() or not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	if control != Mode.REMOTE_SERVER or entries.size() > CMD_REDUNDANCY:
		return
	for entry in entries:
		if entry is Array and entry.size() == 6 and entry[0] is int and entry[0] > _last_received_seq \
				and entry[1] is Vector2 and entry[2] is float and entry[3] is float and entry[4] is int \
				and entry[5] is float:
			_last_received_seq = entry[0]
			_cmd_queue.append(entry)
	queue_peak = maxi(queue_peak, _cmd_queue.size())
	while _cmd_queue.size() > MAX_CMD_QUEUE:
		_cmd_queue.pop_front()
		cmds_dropped += 1


func _pop_server_cmd() -> PlayerCmd:
	var next_seq: int = _cmd_queue[0][0]
	if _acked_seq > 0 and next_seq > _acked_seq + 1:
		# A command never arrived (packet loss / reordering). Simulate the missing tick anyway with a repeat
		# of the previous input, so the server keeps exactly one step per client tick and stays in lockstep with
		# the client's prediction; the client is corrected if the guess was wrong.
		_acked_seq += 1
		gaps_filled += 1
		var filler := PlayerCmd.new()
		filler.move = _last_cmd.move
		filler.yaw = _last_cmd.yaw
		filler.pitch = _last_cmd.pitch
		filler.sprint = _last_cmd.sprint
		filler.crouch = _last_cmd.crouch
		filler.fire = _last_cmd.fire
		filler.aim = _last_cmd.aim
		return filler  # no jump / reload / melee / weapon switch: one-shot events are not repeated
	var entry: Array = _cmd_queue.pop_front()
	_acked_seq = entry[0]
	_last_cmd = _decode_cmd(entry)
	return _last_cmd


## The ledge height of a vault in a snapshot entry (get_net_state: extra -> mantle -> the pull-up point).
static func _snapshot_mantle_top(state: Array) -> Vector3:
	var extra: Array = state[7]
	var mantle: Array = extra[6]
	return mantle[5]


## Server: compact per-player state for snapshots.
func get_net_state() -> Array:
	var flags := 0
	flags |= STATE_CROUCHED if is_crouched else 0
	flags |= STATE_SLIDING if is_sliding else 0
	flags |= STATE_SPRINTING if is_sprinting else 0
	flags |= STATE_ON_FLOOR if is_on_floor() else 0
	flags |= weapons.index << STATE_WEAPON_SHIFT
	flags |= STATE_RELOADING if weapons.is_reloading() else 0
	flags |= STATE_ADS if weapons.ads > 0.5 else 0
	flags |= STATE_MANTLING if is_mantling else 0
	flags |= STATE_MELEE if weapons.is_meleeing() else 0
	var mantle := [is_mantling, _mantle_tick, _mantle_total, _mantle_rise, _mantle_from, _mantle_up, _mantle_to, _mantle_dir,
			_mantle_cooldown, _floor_y]
	var extra := [_slide_dir, _slide_speed, _slide_time, _slide_cooldown, _prev_crouch, weapons.to_array(), mantle]
	return [peer_id, global_position, body_yaw, _head.rotation.x, velocity, flags, _acked_seq, extra, health]


## Client: feed a server snapshot entry for this player.
func push_snapshot(state: Array, tick: int) -> void:
	if control == Mode.LOCAL:
		last_server_state = state
		health = state[8]
		_pending_state = state  # applied at the start of the next physics tick (needs the physics delta)
		return
	# Their last command the server has simulated; the host's own player has none, its steps are the server ticks.
	var seq: int = state[6] if state[6] > 0 else tick
	_buffer_pose(seq, state[1], state[2], state[3], tick)
	var flags: int = state[5]
	_puppet_sounds(flags, state[4])
	is_crouched = flags & STATE_CROUCHED != 0
	is_sliding = flags & STATE_SLIDING != 0
	is_sprinting = flags & STATE_SPRINTING != 0
	is_mantling = flags & STATE_MANTLING != 0
	_visual.set_mantling(is_mantling, _snapshot_mantle_top(state))
	velocity = state[4]
	weapons.index = (flags >> STATE_WEAPON_SHIFT) & SELECT_MASK
	_visual.set_weapon(weapons.index, weapons.current())
	aiming = flags & STATE_ADS != 0
	_visual.set_ads(aiming)
	health = state[8]
	if health <= 0 and alive:
		die("", 0.0)  # missed the death event (e.g. joined late)


func _update_puppet() -> void:
	var delta := get_process_delta_time()
	var shown := _buffered_pose(delta)
	if shown.is_empty():
		return
	var previous_pos := global_position
	global_position = shown["pos"]
	_orient(shown["yaw"])
	_head.rotation.x = shown["pitch"]
	shown_tick = shown["tick"]
	# Velocity of the displayed movement (smooth, unlike the snapshot velocity): drives the body and hitboxes.
	if delta > 0.0 and previous_pos.distance_to(global_position) < 2.0:
		var drawn_vel := (global_position - previous_pos) / delta
		_puppet_velocity = _puppet_velocity.lerp(drawn_vel.slide(body_up()), 1.0 - exp(-12.0 * delta))
	_visual.set_crouched(is_crouched)
	_visual.set_sliding(is_sliding)
	_visual.set_aim_pitch(_head.rotation.x)
	_visual.update_motion(delta, global_transform.basis.inverse() * _puppet_velocity, _puppet_on_floor)
	# Footsteps of other players, from their displayed movement.
	var moved := (global_position - previous_pos).slide(body_up()).length()
	if _puppet_on_floor and not is_sliding and moved < 1.0:
		_step_distance += moved
		if _step_distance >= STEP_STRIDE:
			_step_distance = 0.0
			Audio.play("pig step", global_position, -8.0 if is_crouched else 0.0)
	if _stance_crouched != is_crouched:
		_apply_stance()


## Drops interpolation history (after a teleport).
func reset_interpolation() -> void:
	_snapshots.clear()


## Host: buffers a remote player's pose after each of their commands (drawn by _process via _buffered_pose).
func _record_host_sample() -> void:
	_buffer_pose(_acked_seq, global_position, body_yaw, _head.rotation.x, float(world.server_tick) if world else 0.0)


## Puts a pose of another player into the buffer. `seq` counts their steady 60 Hz steps (their command number, or
## the server tick for the host's own player): the pose is timed by it rather than by when it got here, so jitter
## on the way (their client -> server -> us) does not show as uneven movement. `tick`: the server tick of the pose.
func _buffer_pose(seq: int, pos: Vector3, yaw: float, pitch: float, tick: float) -> void:
	var seq_time := seq / float(Engine.physics_ticks_per_second)
	var sample := Time.get_ticks_usec() / 1e6 - seq_time
	if is_inf(_seq_offset) or absf(sample - _seq_offset) > 0.25:
		_seq_offset = sample  # first pose, or a long stall: start over
		_jitter = 0.0
		_snapshots.clear()
	else:
		_seq_offset += (sample - _seq_offset) * 0.03  # follows the latency, averages the jitter out
		# Recent worst case, forgotten slowly (half-life ~20 s at 60 poses/s) so the delay below stays steady.
		_jitter = maxf(absf(sample - _seq_offset), _jitter * 0.9995)
	_snapshots.append({"t": _seq_offset + seq_time, "pos": pos, "yaw": yaw, "pitch": pitch, "tick": tick})
	if _snapshots.size() > 40:
		_snapshots.pop_front()


## The buffered pose _interp_delay in the past: {pos, yaw, pitch, tick}, or {} when there is none. The delay is
## one 60 Hz step plus the recent jitter (a few ms on a LAN), and changes slowly so the speed does not jump.
func _buffered_pose(delta: float) -> Dictionary:
	if _snapshots.is_empty():
		return {}
	var target := clampf(1.0 / Engine.physics_ticks_per_second + _jitter + 0.008, INTERP_MIN_DELAY, INTERP_MAX_DELAY)
	# Changing the delay by r s/s changes the drawn speed by r: grow quickly enough to cover worse jitter, but no
	# more than 5%; shrink barely noticeably.
	_interp_delay = move_toward(_interp_delay, target, delta * (0.05 if target > _interp_delay else 0.01))
	var render_t := Time.get_ticks_usec() / 1e6 - _interp_delay  # usec: a 1 ms clock is +-15% speed noise at 144 FPS
	while _snapshots.size() >= 3 and _snapshots[1]["t"] <= render_t:
		_snapshots.pop_front()
	var a: Dictionary = _snapshots[0]
	var b: Dictionary = _snapshots[1] if _snapshots.size() > 1 else a
	var f := 1.0
	if b["t"] > a["t"]:
		f = clampf((render_t - a["t"]) / (b["t"] - a["t"]), 0.0, 1.0)
	return {"pos": (a["pos"] as Vector3).lerp(b["pos"], f), "yaw": lerp_angle(a["yaw"], b["yaw"], f),
			"pitch": lerpf(a["pitch"], b["pitch"], f), "tick": lerpf(a["tick"], b["tick"], f)}


## Client-side prediction check. The server state corresponds to our command number `ack`; we compare it with
## what we predicted after the same command. On mismatch we adopt the server state and replay all commands
## the server has not seen yet, then hide the position jump behind a decaying visual offset.
func _reconcile_pending(delta: float) -> void:
	if _pending_state.is_empty():
		return
	var state := _pending_state
	_pending_state = []
	var ack: int = state[6]
	if ack == 0:
		return
	while not _history.is_empty() and _history[0]["seq"] < ack:
		_history.pop_front()
	if _history.is_empty() or _history[0]["seq"] != ack:
		return  # nothing to compare against (e.g. right after a teleport)
	var record: Dictionary = _history.pop_front()
	rtt_ms = float(Time.get_ticks_msec() - record["t"])
	last_error = (record["pos"] as Vector3).distance_to(state[1])
	if last_error < RECONCILE_EPS and record["w"] == (state[7] as Array)[5]:
		return
	recon_count += 1
	var old_pos := global_position
	_apply_server_state(state)
	_replaying = true
	for r in _history:
		step(r["cmd"], delta)
		r["pos"] = global_position
		r["w"] = weapons.to_array()
	_replaying = false
	var shift := global_position - old_pos
	if shift.length() > CORRECTION_SNAP_DISTANCE:
		_correction = Vector3.ZERO
		_prev_pos = global_position
	else:
		_prev_pos += shift
		_correction -= shift
	if Game.net_log:
		print("[RECONCILE] ack=%d err=%.3f weapon_match=%s replayed=%d" % [ack, last_error,
				str(record["w"] == (state[7] as Array)[5]), _history.size()])
		print("  client pos ", record["pos"], " server pos ", state[1], " client w ", record["w"], " server w ", (state[7] as Array)[5])


func _apply_server_state(state: Array) -> void:
	global_position = state[1]
	velocity = state[4]
	var flags: int = state[5]
	is_crouched = flags & STATE_CROUCHED != 0
	is_sliding = flags & STATE_SLIDING != 0
	var extra: Array = state[7]
	_slide_dir = extra[0]
	_slide_speed = extra[1]
	_slide_time = extra[2]
	_slide_cooldown = extra[3]
	_prev_crouch = extra[4]
	weapons.from_array(extra[5])
	var mantle: Array = extra[6]
	is_mantling = mantle[0]
	_mantle_tick = mantle[1]
	_mantle_total = mantle[2]
	_mantle_rise = mantle[3]
	_mantle_from = mantle[4]
	_mantle_up = mantle[5]
	_mantle_to = mantle[6]
	_mantle_dir = mantle[7]
	_mantle_cooldown = mantle[8]
	_floor_y = mantle[9]
	_orient(body_yaw)
	_apply_stance()


## Sounds of another player, derived from changes between snapshots (their simulation does not run here).
func _puppet_sounds(flags: int, new_velocity: Vector3) -> void:
	var on_floor := flags & STATE_ON_FLOOR != 0
	if _puppet_on_floor and not on_floor and new_velocity.dot(Gravity.up(global_position)) > 2.0:
		Audio.play("jump", global_position)
	elif on_floor and not _puppet_on_floor:
		Audio.play("land", global_position, mods["land_db"])
	_puppet_on_floor = on_floor
	var sliding := flags & STATE_SLIDING != 0
	if sliding and not _puppet_sliding:
		Audio.play("slide", global_position)
	_puppet_sliding = sliding
	var reloading := flags & STATE_RELOADING != 0
	if reloading and not _puppet_reloading:
		Audio.play("reload", global_position)
	_puppet_reloading = reloading
	_visual.set_reloading(reloading)
	var meleeing := flags & STATE_MELEE != 0
	if meleeing and not _puppet_meleeing:
		Audio.play("punch", global_position)
	_puppet_meleeing = meleeing
	_visual.set_meleeing(meleeing)
