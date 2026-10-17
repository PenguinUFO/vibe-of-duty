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
const FLAG_FIRE := 8
const FLAG_AIM := 16
const FLAG_RELOAD := 32
const FLAG_SELECT_SHIFT := 6  # 2 bits: weapon index + 1, 0 = no switch
const STATE_CROUCHED := 1
const STATE_SLIDING := 2
const STATE_SPRINTING := 4
const STATE_ON_FLOOR := 8
const STATE_WEAPON_SHIFT := 4  # 2 bits: current weapon index
const STATE_RELOADING := 64
const STATE_ADS := 128
const MAX_HEALTH := 100
const RECONCILE_EPS := 0.02          # m; smaller prediction errors are ignored
const HISTORY_MAX := 180             # commands kept for replay (3 s)
const CORRECTION_DECAY := 12.0       # 1/s, how fast the visual correction offset fades out
const CORRECTION_SNAP_DISTANCE := 2.0  # m; larger errors are shown instantly

## Server only: a shot was fired. `hits` = [{player_id, zone, pos}] (damage comes with stage 5).
signal server_shot(player: Player, weapon: int, origin: Vector3, ends: PackedVector3Array, hits: Array)

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

var weapons := WeaponSim.new()
var world: NetWorld
var health := MAX_HEALTH
var alive := true
var spawn_protect := 0      # server: ticks of invulnerability left after a respawn
var killed_by := ""         # local HUD: who killed us
var death_time_left := 0.0  # local HUD: respawn countdown
var shots_total := 0   # server stats (for tests / netlog)
var hits_total := 0
var _view: WeaponView
var _crosshair: Crosshair
var _ammo_label: Label
var _health_label: Label
var _hurt_rect: ColorRect
var _death_label: Label
var _hurt_alpha := 0.0
var _last_health := MAX_HEALTH
var _debug_timer := 0.0
var _stance_crouched := false
var _sprint_blend := 0.0
var _view_recoil := Vector2.ZERO
var _look_delta := Vector2.ZERO
var _prev_look := Vector2.ZERO
var _retract := 0.0
var _bot_select := 0
var _puppet_on_floor := true
var _puppet_sliding := false
var _puppet_reloading := false
var _puppet_last_pos := Vector3.ZERO
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
		_visual.set_weapon(weapons.index)
	_prev_pos = global_position
	_curr_pos = global_position
	if is_local:
		# The local camera is decoupled from the 60 Hz physics body: it follows an interpolated
		# position and takes mouse look directly, so view rotation never waits for a physics tick.
		_head.top_level = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_view = WeaponView.new()
		_view.is_viewmodel = true
		_camera.add_child(_view)
		_view.set_weapon(weapons.index)
		_build_hud()
		_prev_look = Vector2(look_yaw, look_pitch)


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
		var sens := Settings.mouse_sensitivity * lerpf(1.0, weapons.current().ads_fov_mult, weapons.ads)
		look_yaw -= event.relative.x * sens
		look_pitch = clampf(look_pitch - event.relative.y * sens, -MAX_PITCH, MAX_PITCH)


func _physics_process(delta: float) -> void:
	_prev_pos = _curr_pos
	if control == Mode.LOCAL:
		_reconcile_pending(delta)
		if Game.net_perturb and _cmd_seq > 0 and _cmd_seq % 240 == 0:
			global_position += Vector3(0.6, 0.0, 0.3)  # test hook: fake a prediction error
		var cmd := _gather_cmd(delta)
		cmd.view_tick = world.get_view_tick() if world != null and not multiplayer.is_server() else 0.0
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
	var eye := 0.35 if not alive else (CROUCH_EYE if is_crouched else STAND_EYE)
	_eye_height = lerpf(_eye_height, eye, 1.0 - exp(-14.0 * delta))
	var speed := Vector2(velocity.x, velocity.z).length()
	var def := weapons.current()
	if is_local:
		_view_recoil = _view_recoil.lerp(weapons.recoil, 1.0 - exp(-25.0 * delta))
		_correction *= exp(-CORRECTION_DECAY * delta)
		var pos := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction()) + _correction
		var view_angles := Vector3(look_pitch + _view_recoil.x, look_yaw + _view_recoil.y, 0.0)
		_head.global_transform = Transform3D(Basis.from_euler(view_angles), pos + Vector3.UP * _eye_height)
	else:
		_head.position.y = _eye_height
	var sprinting_fov := 5.0 if is_sprinting and speed > WALK_SPEED + 0.5 else 0.0
	var target_fov := lerpf(Settings.fov, Settings.fov * def.ads_fov_mult, weapons.ads) + sprinting_fov
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-8.0 * delta))
	_camera.rotation.z = lerpf(_camera.rotation.z, 0.7 if not alive else (-0.05 if is_sliding else 0.0), 1.0 - exp(-10.0 * delta))
	if is_local:
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
		cmd.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		cmd.sprint = Input.is_action_pressed("sprint")
		cmd.crouch = Input.is_action_pressed("crouch")
		cmd.fire = Input.is_action_pressed("fire")
		cmd.aim = Input.is_action_pressed("aim")
		cmd.reload = Input.is_action_just_pressed("reload")
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = JUMP_BUFFER_TIME
		var count := WeaponDB.count()
		for i in count:
			if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
				cmd.select = i
		if Input.is_action_just_pressed("weapon_next"):
			cmd.select = (weapons.index + 1) % count
		elif Input.is_action_just_pressed("weapon_prev"):
			cmd.select = (weapons.index + count - 1) % count
	cmd.jump = _jump_buffer > 0.0
	return cmd


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
	var firing := weapons.wants_fire(cmd)
	is_sprinting = cmd.sprint and cmd.move.y < -0.1 and not is_crouched and not cmd.aim and not firing
	var top_speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	if is_sliding:
		horiz = _slide_dir * _slide_speed
	elif on_floor:
		var ground_speed := (CROUCH_SPEED if is_crouched else top_speed) * wish_len * weapons.speed_mult()
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
	_weapon_step(cmd, dt)


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
	_stance_crouched = is_crouched


func _sfx(id: String, volume_db: float = 0.0) -> void:
	if _replaying:
		return
	Audio.play(id, null if is_local else global_position, volume_db)


# --- Networking -------------------------------------------------------------------------------

func _bot_cmd(delta: float) -> PlayerCmd:
	# Scripted input for automated network tests (launch args --bot / --bot-aim).
	var t := Time.get_ticks_msec() / 1000.0
	var cmd := PlayerCmd.new()
	if Game.bot_aim and world != null:
		return _bot_aim_cmd(t)
	look_yaw += 0.8 * delta
	cmd.yaw = look_yaw
	cmd.move = Vector2(0.0, -1.0)
	cmd.sprint = fmod(t, 6.0) < 3.0
	cmd.crouch = fmod(t, 7.0) > 6.0
	cmd.jump = fmod(t, 2.5) < delta
	cmd.fire = fmod(t, 4.0) < 2.5
	cmd.aim = fmod(t, 8.0) > 5.5
	cmd.reload = fmod(t, 9.0) < delta
	var sel := int(t / 11.0) % WeaponDB.count()
	if sel != _bot_select:
		_bot_select = sel
		cmd.select = sel
	return cmd


## Strafes around the nearest enemy while aiming at their head and firing (as seen on this client's screen).
func _bot_aim_cmd(t: float) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	var target: Player = null
	var best := INF
	for id in world.players:
		var other: Player = world.players[id]
		if other != self and other.alive:
			var d := other.global_position.distance_to(global_position)
			if d < best:
				best = d
				target = other
	# Close in to ~12 m (so spread alone does not decide the test), then strafe.
	cmd.move = Vector2(1.0 if int(t / 1.5) % 2 == 0 else -1.0, -1.0 if best > 12.0 else 0.0)
	cmd.aim = true
	if target != null and alive:
		var eye := global_position + Vector3.UP * STAND_EYE
		var dir := (target.global_position + Vector3.UP * 1.5 - eye).normalized()
		# Aim at the target, minus the current recoil kick (a human would pull down to compensate).
		look_yaw = atan2(-dir.x, -dir.z) - weapons.recoil.y
		look_pitch = clampf(asin(dir.y) - weapons.recoil.x, -MAX_PITCH, MAX_PITCH)
		cmd.fire = weapons.ads > 0.95
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
	return cmd


func _encode_cmd(cmd: PlayerCmd) -> Array:
	var flags := 0
	flags |= FLAG_JUMP if cmd.jump else 0
	flags |= FLAG_SPRINT if cmd.sprint else 0
	flags |= FLAG_CROUCH if cmd.crouch else 0
	flags |= FLAG_FIRE if cmd.fire else 0
	flags |= FLAG_AIM if cmd.aim else 0
	flags |= FLAG_RELOAD if cmd.reload else 0
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
	cmd.fire = flags & FLAG_FIRE != 0
	cmd.aim = flags & FLAG_AIM != 0
	cmd.reload = flags & FLAG_RELOAD != 0
	cmd.select = ((flags >> FLAG_SELECT_SHIFT) & 3) - 1
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
		if entry is Array and entry.size() == 6 and entry[0] is int and entry[0] > _last_received_seq \
				and entry[1] is Vector2 and entry[2] is float and entry[3] is float and entry[4] is int \
				and entry[5] is float:
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


func get_net_state() -> Array:
	var flags := 0
	flags |= STATE_CROUCHED if is_crouched else 0
	flags |= STATE_SLIDING if is_sliding else 0
	flags |= STATE_SPRINTING if is_sprinting else 0
	flags |= STATE_ON_FLOOR if is_on_floor() else 0
	flags |= weapons.index << STATE_WEAPON_SHIFT
	flags |= STATE_RELOADING if weapons.is_reloading() else 0
	flags |= STATE_ADS if weapons.ads > 0.5 else 0
	var extra := [_slide_dir, _slide_speed, _slide_time, _slide_cooldown, _prev_crouch, weapons.to_array()]
	return [peer_id, global_position, rotation.y, _head.rotation.x, velocity, flags, _acked_seq, extra, health]


## Client: feed a server snapshot entry for this player.
func push_snapshot(state: Array) -> void:
	if control == Mode.LOCAL:
		last_server_state = state
		health = state[8]
		_pending_state = state  # applied at the start of the next physics tick (needs the physics delta)
		return
	_snapshots.append({"t": Time.get_ticks_msec() / 1000.0, "pos": state[1], "yaw": state[2], "pitch": state[3]})
	if _snapshots.size() > 20:
		_snapshots.pop_front()
	var flags: int = state[5]
	_puppet_sounds(flags, state[4])
	is_crouched = flags & STATE_CROUCHED != 0
	is_sliding = flags & STATE_SLIDING != 0
	is_sprinting = flags & STATE_SPRINTING != 0
	velocity = state[4]
	weapons.index = (flags >> STATE_WEAPON_SHIFT) & 3
	_visual.set_weapon(weapons.index)
	health = state[8]
	if health <= 0 and alive:
		die("", 0.0)  # missed the death event (e.g. joined late)


func _update_puppet() -> void:
	if _snapshots.is_empty():
		return
	var previous_pos := global_position
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
	_visual.set_aim_pitch(_head.rotation.x)
	# Footsteps of other players, from their displayed movement.
	var moved := Vector2(global_position.x - previous_pos.x, global_position.z - previous_pos.z).length()
	if _puppet_on_floor and not is_sliding and moved < 1.0:
		_step_distance += moved
		if _step_distance >= STEP_STRIDE:
			_step_distance = 0.0
			Audio.play("step", global_position, -8.0 if is_crouched else 0.0)
	if _stance_crouched != is_crouched:
		_apply_stance()


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
	_apply_stance()


# --- Weapons ----------------------------------------------------------------------------------------

func _weapon_step(cmd: PlayerCmd, dt: float) -> void:
	var ctx := {
		"peer_id": peer_id,
		"speed": Vector2(velocity.x, velocity.z).length(),
		"crouched": is_crouched,
		"airborne": not is_on_floor(),
		"sprinting": is_sprinting,
	}
	for event in weapons.tick(cmd, dt, ctx):
		match event["type"]:
			"shot":
				event["view_tick"] = cmd.view_tick
				_on_shot(event)
			"dry":
				_local_sfx("empty")
			"reload_start":
				_local_sfx("reload")
			"equip":
				_local_sfx("equip")
				if _view:
					_view.set_weapon(weapons.index)


func _local_sfx(id: String) -> void:
	if is_local and not _replaying:
		Audio.play(id)


func _on_shot(event: Dictionary) -> void:
	if _replaying:
		return
	var def := WeaponDB.get_def(event["weapon"])
	var origin := global_position + Vector3.UP * (CROUCH_EYE if is_crouched else STAND_EYE)
	var is_server := multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	var tick := _judge_tick(event["view_tick"], is_server)
	var results: Array = []
	var ends := PackedVector3Array()
	var hits: Array = []
	var damage_by_victim := {}  # peer_id -> {player, damage, head}
	for dir in event["dirs"]:
		var r := _trace(origin, dir, def.max_range, tick)
		results.append(r)
		ends.append(r["pos"])
		var victim: Player = r["player"]
		if victim != null:
			var head: bool = r["zone"] == "head"
			hits.append({"player_id": victim.peer_id, "zone": r["zone"], "pos": r["pos"]})
			var entry: Dictionary = damage_by_victim.get_or_add(victim.peer_id, {"player": victim, "damage": 0.0, "head": false})
			entry["damage"] += def.damage * (NetWorld.HEAD_DAMAGE_MULT if head else 1.0)
			entry["head"] = entry["head"] or head
	if is_server:
		shots_total += 1
		hits_total += hits.size()
		server_shot.emit(self, event["weapon"], origin, ends, hits)
		if world != null:
			for victim_id in damage_by_victim:
				var entry: Dictionary = damage_by_victim[victim_id]
				world.server_apply_damage(self, entry["player"], entry["damage"], entry["head"], event["weapon"])
	if is_local:
		_view.flash()
		_view.kick(1.0 if def.pellets == 1 else 2.0)
		Audio.play(def.sound_shot)
		var muzzle := _view.muzzle_global_position()
		var scene_root := get_tree().current_scene
		for r in results:
			ShotEffects.spawn_tracer(scene_root, muzzle, r["pos"])
			if r["hit"] and r["player"] == null:
				ShotEffects.spawn_impact(scene_root, r["pos"], r["normal"])
				Audio.play("impact", r["pos"])


## Which server tick to judge a shot at: the shooter's view tick (server, remote shooters, lag comp on),
## or -1 to use everyone's live positions.
func _judge_tick(view_tick: float, is_server: bool) -> float:
	if not is_server or control != Mode.REMOTE_SERVER or world == null or not world.lag_comp_enabled or view_tick <= 0.0:
		return -1.0
	var now := float(world.server_tick + 1)
	return clampf(view_tick, now - LagComp.MAX_REWIND_TICKS, now)


func _trace(origin: Vector3, dir: Vector3, max_range: float, tick: float = -1.0) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range, Layers.WORLD)
	var world_hit := get_world_3d().direct_space_state.intersect_ray(query)
	var best := max_range
	var result := {"pos": origin + dir * max_range, "normal": -dir, "hit": false, "player": null, "zone": ""}
	if not world_hit.is_empty():
		best = origin.distance_to(world_hit["position"])
		result = {"pos": world_hit["position"], "normal": world_hit["normal"], "hit": true, "player": null, "zone": ""}
	if world == null:
		return result
	# Players are hit-tested analytically (see LagComp), at their rewound position when `tick` >= 0.
	for id in world.players:
		var other: Player = world.players[id]
		if other == self or not other.alive:
			continue
		var state := _target_state(other, tick)
		if state.is_empty():
			continue
		var pos: Vector3 = state["pos"]
		var crouched: bool = state["crouched"]
		var t_head := LagComp.ray_sphere(origin, dir, LagComp.head_center(pos, crouched), LagComp.HEAD_RADIUS)
		var seg := LagComp.body_segment(pos, crouched)
		var t_body := LagComp.ray_capsule(origin, dir, seg[0], seg[1], LagComp.BODY_RADIUS)
		var t := -1.0
		var zone := ""
		if t_head >= 0.0 and (t_body < 0.0 or t_head <= t_body + 0.0001):
			t = t_head
			zone = "head"
		elif t_body >= 0.0:
			t = t_body
			zone = "body"
		if t >= 0.0 and t < best:
			best = t
			result = {"pos": origin + dir * t, "normal": -dir, "hit": true, "player": other, "zone": zone}
	return result


func _target_state(other: Player, tick: float) -> Dictionary:
	if tick >= 0.0:
		return world.lag_comp.sample(other.peer_id, tick)
	return {"pos": other.global_position, "crouched": other.is_crouched}


## Cosmetics of somebody else's shot (called by World on clients and on the host).
func show_remote_shot(weapon: int, origin: Vector3, ends: PackedVector3Array) -> void:
	var def := WeaponDB.get_def(weapon)
	_visual.set_weapon(weapon)
	_visual.show_shot()
	Audio.play(def.sound_shot, origin)
	var scene_root := get_tree().current_scene
	var muzzle := _visual.muzzle_global_position()
	for i in ends.size():
		ShotEffects.spawn_tracer(scene_root, muzzle, ends[i])
		ShotEffects.spawn_impact(scene_root, ends[i], Vector3.UP)
		if i < 2:  # a shotgun blast would otherwise play eight impacts at once
			Audio.play("impact", ends[i])


func _build_hud() -> void:
	_hurt_rect = ColorRect.new()
	_hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt_rect.color = Color(0.8, 0.0, 0.0, 0.0)
	_hud.add_child(_hurt_rect)
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_hud.add_child(_crosshair)

	_ammo_label = _make_hud_label(28)
	_ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ammo_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ammo_label.offset_right = -32.0
	_ammo_label.offset_bottom = -24.0
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_ammo_label)

	_health_label = _make_hud_label(34)
	_health_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_health_label.offset_left = 32.0
	_health_label.offset_bottom = -24.0
	_hud.add_child(_health_label)

	_death_label = _make_hud_label(40)
	_death_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.visible = false
	_hud.add_child(_death_label)


func _make_hud_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label


func _update_viewmodel(delta: float, speed: float) -> void:
	_view.set_weapon(weapons.index)
	_view.visible = alive
	var look := Vector2(look_yaw, look_pitch)
	_look_delta = (look - _prev_look) / maxf(delta, 0.0001) * delta
	_look_delta.x = wrapf(_look_delta.x, -PI, PI)
	_prev_look = look
	_sprint_blend = move_toward(_sprint_blend, 1.0 if is_sprinting else 0.0, delta * 6.0)
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


func _update_hud(speed: float, delta: float) -> void:
	var def := weapons.current()
	_ammo_label.text = "%s\n%d / %d%s" % [def.display_name, weapons.mags[weapons.index], weapons.reserves[weapons.index],
			"   RELOADING" if weapons.is_reloading() else ""]
	var spread := weapons.spread_angle(speed, is_crouched, not is_on_floor())
	var fov_rad := deg_to_rad(_camera.fov)
	var px := tan(spread) / tan(fov_rad * 0.5) * get_viewport().get_visible_rect().size.y * 0.5
	_crosshair.update_state(px if alive else 0.0, weapons.ads if alive else 1.0)
	_ammo_label.visible = alive
	_health_label.text = "HP %d" % health
	_health_label.modulate = Color.WHITE if health > 30 else Color(1.0, 0.35, 0.3)
	if health < _last_health:
		_hurt_alpha = minf(0.55, 0.2 + float(_last_health - health) / MAX_HEALTH)
		if alive:
			Audio.play("hurt")
	_last_health = health
	_hurt_alpha = maxf(_hurt_alpha - delta * 1.2, 0.0)
	_hurt_rect.color.a = _hurt_alpha if alive else 0.35
	death_time_left = maxf(death_time_left - delta, 0.0)
	_death_label.visible = not alive
	if not alive:
		_death_label.text = "YOU DIED\n%s\nRespawn in %.1f" % ["Killed by %s" % killed_by if killed_by != "" else "", death_time_left]
	_debug_timer -= delta
	if _debug_timer > 0.0:
		return  # the debug overlay changes every frame; 10 Hz is plenty and saves text re-layout
	_debug_timer = 0.1
	_debug.text = "%d FPS\nspeed %.1f m/s\n%s%s%s\nEsc menu   Tab scores   F10 leave" % [
		Engine.get_frames_per_second(), speed,
		"slide " if is_sliding else "", "crouch " if is_crouched else "",
		"sprint " if is_sprinting else ""]
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_debug.text += "\nrtt %d ms  recon %d  err %.2f m" % [rtt_ms, recon_count, last_error]


func debug_weapon_string() -> String:
	return "w%d mag=%d/%d shots=%d" % [weapons.index, weapons.mags[weapons.index], weapons.reserves[weapons.index],
			weapons.shots]


# --- Health, death, respawn ---------------------------------------------------------------------------

## Server: applies damage; returns true if this killed the player.
func server_damage(amount: float) -> bool:
	if not alive:
		return false
	health = maxi(health - roundi(amount), 0)
	if health == 0:
		alive = false
		return true
	return false


func die(by: String, respawn_delay: float) -> void:
	if not alive and respawn_delay <= 0.0:
		return
	alive = false
	health = 0
	killed_by = by
	death_time_left = respawn_delay
	_visual.set_dead(true)
	Audio.play("death", null if is_local else global_position)


func respawn(xform: Transform3D) -> void:
	alive = true
	health = MAX_HEALTH
	_last_health = MAX_HEALTH
	killed_by = ""
	death_time_left = 0.0
	weapons.reset()
	teleport(xform)
	_visual.set_dead(false)
	if _view:
		_view.set_weapon(weapons.index)
	Audio.play("spawn", null if is_local else global_position)


## Local player: the server confirmed that one of our shots damaged somebody.
func on_hit_confirmed(killed: bool, head: bool) -> void:
	if _crosshair:
		_crosshair.show_hit(killed or head)
	Audio.play("kill" if killed else "hit")


## Sounds of another player, derived from changes between snapshots (their simulation does not run here).
func _puppet_sounds(flags: int, new_velocity: Vector3) -> void:
	var on_floor := flags & STATE_ON_FLOOR != 0
	if _puppet_on_floor and not on_floor and new_velocity.y > 2.0:
		Audio.play("jump", global_position)
	elif on_floor and not _puppet_on_floor:
		Audio.play("land", global_position)
	_puppet_on_floor = on_floor
	var sliding := flags & STATE_SLIDING != 0
	if sliding and not _puppet_sliding:
		Audio.play("slide", global_position)
	_puppet_sliding = sliding
	var reloading := flags & STATE_RELOADING != 0
	if reloading and not _puppet_reloading:
		Audio.play("reload", global_position)
	_puppet_reloading = reloading
