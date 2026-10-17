class_name Player
extends CharacterBody3D
## First-person character. Movement is driven by step(cmd, dt), a deterministic function of the
## previous state and one PlayerCmd, so it can later be run on the server and replayed for prediction.

const WALK_SPEED := 5.25
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.5
const JUMP_VELOCITY := 6.5
const GRAVITY := 20.0
const GROUND_ACCEL := 60.0
const GROUND_FRICTION := 50.0
const AIR_ACCEL := 30.0

const SLIDE_MIN_SPEED := 6.5   # horizontal speed needed to start a slide
const SLIDE_START_SPEED := 9.5
const SLIDE_FRICTION := 7.0
const SLIDE_END_SPEED := 3.5
const SLIDE_MAX_TIME := 1.2
const SLIDE_COOLDOWN := 0.8

const RADIUS := 0.35
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const STAND_EYE := 1.65
const CROUCH_EYE := 0.95

const JUMP_BUFFER_TIME := 0.12
const LAND_SOUND_MIN_SPEED := 4.0
const STEP_STRIDE := 2.4
const MAX_PITCH := deg_to_rad(89.0)

enum Mode {
	LOCAL,          # this machine's own player: gathers input, predicts
	REMOTE_SERVER,  # server-side simulation of a remote client, driven by received commands
	PUPPET,         # client-side view of another player, interpolated from server snapshots
}

const INTERP_DELAY := 0.1  # seconds puppets are rendered in the past
const MAX_CMD_QUEUE := 4
const CMD_REDUNDANCY := 3  # last N commands are re-sent in every packet to survive packet loss
const FLAG_JUMP := 1
const FLAG_SPRINT := 2
const FLAG_CROUCH := 4
const STATE_CROUCHED := 1
const STATE_SLIDING := 2
const STATE_SPRINTING := 4
const STATE_ON_FLOOR := 8
const RECONCILE_EPS := 0.02          # m; smaller prediction errors are ignored
const HISTORY_MAX := 180             # commands kept for replay (3 s)
const CORRECTION_DECAY := 12.0       # 1/s, how fast the visual correction offset fades out
const CORRECTION_SNAP_DISTANCE := 2.0  # m; larger errors are shown instantly

var control: Mode = Mode.LOCAL
var peer_id := 1
var player_name := "Player"
var is_local: bool:
	get:
		return control == Mode.LOCAL

var look_yaw := 0.0
var look_pitch := 0.0

var is_sliding := false
var is_crouched := false
var is_sprinting := false

var _slide_dir := Vector3.ZERO
var _slide_speed := 0.0
var _slide_time := 0.0
var _slide_cooldown := 0.0
var _prev_crouch := false
var _prev_on_floor := true
var _prev_vy := 0.0
var _step_distance := 0.0
var _jump_buffer := 0.0
var _jumped_this_step := false
var _shape := CapsuleShape3D.new()
var _eye_height := STAND_EYE
var _prev_pos := Vector3.ZERO  # body position at the previous physics tick (camera interpolation)
var _curr_pos := Vector3.ZERO
var _cmd_seq := 0
var _sent_cmds: Array = []        # last CMD_REDUNDANCY encoded commands (client -> server)
var _cmd_queue: Array = []        # received encoded commands (server)
var _last_received_seq := 0
var _acked_seq := 0               # server: seq of the last command applied
var _snapshots: Array = []        # puppet: [{t, pos, yaw, pitch}]
var last_server_state: Array = [] # local: most recent snapshot entry for this player
var recon_count := 0              # debug: number of reconciliations so far
var last_error := 0.0             # debug: size of the last prediction error (m)
var rtt_ms := 0.0                 # debug: round trip estimate from command ack times

var _history: Array = []          # client: [{seq, cmd, pos, t}] for commands not yet acknowledged
var _pending_state: Array = []    # client: latest server state for this player, applied next physics tick
var _replaying := false
var _correction := Vector3.ZERO   # visual offset hiding a position correction, decays to zero

@onready var _collision: CollisionShape3D = $Collision
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera
@onready var _hud: CanvasLayer = $HUD
@onready var _debug: Label = $HUD/Debug
@onready var _visual: PlayerVisual = $Visual


func _ready() -> void:
	_shape.radius = RADIUS
	_collision.shape = _shape
	_apply_stance()
	_head.position.y = STAND_EYE
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(46.0)
	floor_stop_on_slope = true
	look_yaw = rotation.y
	_camera.current = is_local
	_camera.fov = Settings.fov
	_hud.visible = is_local
	set_physics_process(control != Mode.PUPPET)
	if not is_local:
		_visual.setup(peer_id, player_name)
	_prev_pos = global_position
	_curr_pos = global_position
	if is_local:
		# The local camera is decoupled from the 60 Hz physics body: it follows an interpolated
		# position and takes mouse look directly, so view rotation never waits for a physics tick.
		_head.top_level = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Teleports the player and resets all movement state.
func teleport(xform: Transform3D) -> void:
	global_transform = Transform3D(Basis.IDENTITY, xform.origin)
	look_yaw = xform.basis.get_euler().y
	look_pitch = 0.0
	rotation.y = look_yaw
	_prev_pos = global_position
	_curr_pos = global_position
	velocity = Vector3.ZERO
	_snapshots.clear()
	_history.clear()
	_pending_state = []
	_correction = Vector3.ZERO
	_end_slide()
	is_crouched = false
	_apply_stance()


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_yaw -= event.relative.x * Settings.mouse_sensitivity
		look_pitch = clampf(look_pitch - event.relative.y * Settings.mouse_sensitivity, -MAX_PITCH, MAX_PITCH)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	_prev_pos = _curr_pos
	if control == Mode.LOCAL:
		_reconcile_pending(delta)
		if Game.net_perturb and _cmd_seq > 0 and _cmd_seq % 240 == 0:
			global_position += Vector3(0.6, 0.0, 0.3)  # test hook: fake a prediction error
		var cmd := _gather_cmd(delta)
		step(cmd, delta)
		_send_cmd(cmd)
		if _jumped_this_step:
			_jump_buffer = 0.0
	elif control == Mode.REMOTE_SERVER:
		# One command per tick; extra backlog is drained faster so latency stays bounded.
		var n := 2 if _cmd_queue.size() > 2 else 1
		for i in n:
			if _cmd_queue.is_empty():
				break
			step(_pop_server_cmd(), delta)
	_curr_pos = global_position


func _process(delta: float) -> void:
	# Camera presentation only; none of this affects simulation.
	if control == Mode.PUPPET:
		_update_puppet()
		return
	var eye := CROUCH_EYE if is_crouched else STAND_EYE
	_eye_height = lerpf(_eye_height, eye, 1.0 - exp(-14.0 * delta))
	if is_local:
		_correction *= exp(-CORRECTION_DECAY * delta)
		var pos := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction()) + _correction
		_head.global_transform = Transform3D(Basis.from_euler(Vector3(look_pitch, look_yaw, 0.0)),
				pos + Vector3.UP * _eye_height)
	else:
		_head.position.y = _eye_height
	var speed := Vector2(velocity.x, velocity.z).length()
	var target_fov := Settings.fov + (5.0 if is_sprinting and speed > WALK_SPEED + 0.5 else 0.0)
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-8.0 * delta))
	_camera.rotation.z = lerpf(_camera.rotation.z, -0.05 if is_sliding else 0.0, 1.0 - exp(-10.0 * delta))
	if is_local:
		_debug.text = "%d FPS\nspeed %.1f m/s\n%s%s%s" % [
			Engine.get_frames_per_second(), speed,
			"slide " if is_sliding else "", "crouch " if is_crouched else "",
			"sprint " if is_sprinting else ""]
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			_debug.text += "\nrtt %d ms  recon %d  err %.2f m" % [rtt_ms, recon_count, last_error]


func _gather_cmd(delta: float) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	if Game.bot_mode:
		return _bot_cmd(delta)
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cmd.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		cmd.sprint = Input.is_action_pressed("sprint")
		cmd.crouch = Input.is_action_pressed("crouch")
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = JUMP_BUFFER_TIME
	cmd.jump = _jump_buffer > 0.0
	return cmd


## Advances the simulation by one fixed tick.
func step(cmd: PlayerCmd, dt: float) -> void:
	rotation.y = cmd.yaw
	if not is_local:
		_head.rotation.x = cmd.pitch
	var on_floor := is_on_floor()
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	_jumped_this_step = false

	# Slide start / update.
	_slide_cooldown = maxf(_slide_cooldown - dt, 0.0)
	var crouch_pressed := cmd.crouch and not _prev_crouch
	_prev_crouch = cmd.crouch
	if not is_sliding and crouch_pressed and on_floor and _slide_cooldown <= 0.0 \
			and horiz.length() >= SLIDE_MIN_SPEED:
		is_sliding = true
		_slide_time = 0.0
		_slide_dir = horiz.normalized()
		_slide_speed = maxf(horiz.length(), SLIDE_START_SPEED)
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

	# Horizontal movement.
	var wish := global_transform.basis * Vector3(cmd.move.x, 0.0, cmd.move.y)
	wish.y = 0.0
	var wish_len := minf(wish.length(), 1.0)
	wish = wish.normalized()
	is_sprinting = cmd.sprint and cmd.move.y < -0.1 and not is_crouched
	var top_speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	if is_sliding:
		horiz = _slide_dir * _slide_speed
	elif on_floor:
		var ground_speed := (CROUCH_SPEED if is_crouched else top_speed) * wish_len
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
			velocity.y = JUMP_VELOCITY
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


func _post_move(dt: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _prev_on_floor and _prev_vy < -LAND_SOUND_MIN_SPEED:
		_sfx("land")
	_prev_on_floor = on_floor
	if on_floor and not is_sliding:
		_step_distance += Vector2(velocity.x, velocity.z).length() * dt
		if _step_distance >= STEP_STRIDE:
			_step_distance = 0.0
			_sfx("step", -8.0 if is_crouched else 0.0)


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


func _sfx(id: String, volume_db: float = 0.0) -> void:
	if _replaying:
		return
	Audio.play(id, null if is_local else global_position, volume_db)


# --- Networking -------------------------------------------------------------------------------

func _bot_cmd(delta: float) -> PlayerCmd:
	# Scripted input for automated network tests (launch arg --bot).
	var t := Time.get_ticks_msec() / 1000.0
	look_yaw += 0.8 * delta
	var cmd := PlayerCmd.new()
	cmd.yaw = look_yaw
	cmd.move = Vector2(0.0, -1.0)
	cmd.sprint = fmod(t, 6.0) < 3.0
	cmd.crouch = fmod(t, 7.0) > 6.0
	cmd.jump = fmod(t, 2.5) < delta
	return cmd


func _encode_cmd(cmd: PlayerCmd) -> Array:
	var flags := (FLAG_JUMP if cmd.jump else 0) | (FLAG_SPRINT if cmd.sprint else 0) 			| (FLAG_CROUCH if cmd.crouch else 0)
	return [_cmd_seq, cmd.move, cmd.yaw, cmd.pitch, flags]


func _decode_cmd(entry: Array) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	cmd.move = entry[1]
	cmd.yaw = entry[2]
	cmd.pitch = entry[3]
	var flags: int = entry[4]
	cmd.jump = flags & FLAG_JUMP != 0
	cmd.sprint = flags & FLAG_SPRINT != 0
	cmd.crouch = flags & FLAG_CROUCH != 0
	return cmd


## Client: records this tick's command for reconciliation and sends it plus the previous ones
## (redundancy against packet loss).
func _send_cmd(cmd: PlayerCmd) -> void:
	_cmd_seq += 1
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return
	_history.append({"seq": _cmd_seq, "cmd": cmd, "pos": global_position, "t": Time.get_ticks_msec()})
	if _history.size() > HISTORY_MAX:
		_history.pop_front()
	_sent_cmds.append(_encode_cmd(cmd))
	if _sent_cmds.size() > CMD_REDUNDANCY:
		_sent_cmds.pop_front()
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
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	if control != Mode.REMOTE_SERVER or entries.size() > CMD_REDUNDANCY:
		return
	for entry in entries:
		if entry is Array and entry.size() == 5 and entry[0] is int and entry[0] > _last_received_seq 				and entry[1] is Vector2 and entry[2] is float and entry[3] is float and entry[4] is int:
			_last_received_seq = entry[0]
			_cmd_queue.append(entry)
	while _cmd_queue.size() > 2 * MAX_CMD_QUEUE:
		_cmd_queue.pop_front()


func _pop_server_cmd() -> PlayerCmd:
	# Drop old commands if a burst built up a huge backlog (the client will be reconciled).
	while _cmd_queue.size() > 2 * MAX_CMD_QUEUE:
		_cmd_queue.pop_front()
	var entry: Array = _cmd_queue.pop_front()
	_acked_seq = entry[0]
	return _decode_cmd(entry)


## Server: compact per-player state for snapshots.
func get_net_state() -> Array:
	var flags := (STATE_CROUCHED if is_crouched else 0) | (STATE_SLIDING if is_sliding else 0) 			| (STATE_SPRINTING if is_sprinting else 0) | (STATE_ON_FLOOR if is_on_floor() else 0)
	var extra := [_slide_dir, _slide_speed, _slide_time, _slide_cooldown, _prev_crouch]
	return [peer_id, global_position, rotation.y, _head.rotation.x, velocity, flags, _acked_seq, extra]


## Client: feed a server snapshot entry for this player.
func push_snapshot(state: Array) -> void:
	if control == Mode.LOCAL:
		last_server_state = state
		_pending_state = state  # applied at the start of the next physics tick (needs the physics delta)
		return
	_snapshots.append({"t": Time.get_ticks_msec() / 1000.0, "pos": state[1], "yaw": state[2], "pitch": state[3]})
	if _snapshots.size() > 20:
		_snapshots.pop_front()
	var flags: int = state[5]
	is_crouched = flags & STATE_CROUCHED != 0
	is_sliding = flags & STATE_SLIDING != 0
	is_sprinting = flags & STATE_SPRINTING != 0
	velocity = state[4]


func _update_puppet() -> void:
	if _snapshots.is_empty():
		return
	var render_t := Time.get_ticks_msec() / 1000.0 - INTERP_DELAY
	while _snapshots.size() >= 3 and _snapshots[1]["t"] <= render_t:
		_snapshots.pop_front()
	var a: Dictionary = _snapshots[0]
	var b: Dictionary = _snapshots[1] if _snapshots.size() > 1 else a
	var f := 1.0
	if b["t"] > a["t"]:
		f = clampf((render_t - a["t"]) / (b["t"] - a["t"]), 0.0, 1.0)
	global_position = a["pos"].lerp(b["pos"], f)
	rotation.y = lerp_angle(a["yaw"], b["yaw"], f)
	_head.rotation.x = lerpf(a["pitch"], b["pitch"], f)
	_visual.set_crouched(is_crouched)


## Drops interpolation history (after a teleport).
func reset_interpolation() -> void:
	_snapshots.clear()


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
	if last_error < RECONCILE_EPS:
		return
	recon_count += 1
	var old_pos := global_position
	_apply_server_state(state)
	_replaying = true
	for r in _history:
		step(r["cmd"], delta)
		r["pos"] = global_position
	_replaying = false
	var shift := global_position - old_pos
	if shift.length() > CORRECTION_SNAP_DISTANCE:
		_correction = Vector3.ZERO
		_prev_pos = global_position
	else:
		_prev_pos += shift
		_correction -= shift
	if Game.net_log:
		print("[RECONCILE] ack=%d err=%.3f replayed=%d" % [ack, last_error, _history.size()])


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
	_apply_stance()
