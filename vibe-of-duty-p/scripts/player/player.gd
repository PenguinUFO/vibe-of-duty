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
const LAND_SOUND_MIN_SPEED := 4.0
const STEP_STRIDE := 2.4
const MAX_PITCH := deg_to_rad(89.0)
const STICK_LOOK_SPEED := Vector2(3.2, 2.2)  # rad/s at full right-stick deflection (yaw, pitch), stick sensitivity 1
const STICK_CURVE := 2.0                      # response curve: small deflections turn slowly for fine aim

enum Mode {
	LOCAL,          # this machine's own player: gathers input, predicts
	REMOTE_SERVER,  # server-side simulation of a remote client, driven by received commands
	PUPPET,         # client-side view of another player, interpolated from server snapshots
}

## Other players are drawn slightly in the past from a buffer of their poses, so they move smoothly despite network
## jitter. The delay adapts (_buffered_pose): one 60 Hz step plus how late poses have recently been.
const INTERP_MIN_DELAY := 0.03   # s
const INTERP_MAX_DELAY := 0.2
const MAX_CMD_QUEUE := 120        # received commands kept per player (2 s); beyond that the oldest are dropped
const CMD_BUDGET_PER_TICK := 1.1  # server steps a client may take per tick (10% slack lets bursts catch up, caps speed hacks)
const CMD_BUDGET_MAX := 8.0
const CMD_REDUNDANCY := 3  # last N commands are re-sent in every packet to survive packet loss
const FLAG_JUMP := 1
const FLAG_SPRINT := 2
const FLAG_CROUCH := 4
const FLAG_FIRE := 8
const FLAG_AIM := 16
const FLAG_RELOAD := 32
const FLAG_JUMP_HELD := 256
const FLAG_SELECT_SHIFT := 6  # 2 bits: weapon index + 1, 0 = no switch
const STATE_CROUCHED := 1
const STATE_SLIDING := 2
const STATE_SPRINTING := 4
const STATE_ON_FLOOR := 8
const STATE_WEAPON_SHIFT := 4  # 2 bits: current weapon index
const STATE_RELOADING := 64
const STATE_ADS := 128
const STATE_MANTLING := 256
const MAX_HEALTH := 100
const KID_HEALTH_MULT := 2
# Health regeneration (server), as in Call of Duty: Modern Warfare III (2023) after its Season 2 patch: it starts 3 s
# after the last damage and comes back at 75 of 150 HP per second, i.e. half a normal player's health per second (empty
# to full in 2 s). Kid mode heals at the same HP per second (the same damage takes as long to heal), only starting sooner.
const REGEN_DELAY := 3.0
const REGEN_PER_SECOND := MAX_HEALTH * 0.5   # HP per second, the same for everybody
const KID_REGEN_DELAY := REGEN_DELAY * 2.0 / 3.0  # kid mode: health starts coming back sooner (2 s)
const HURT_SHADER := preload("res://assets/shaders/hurt_vignette.gdshader")  # local HUD: hit flash and low health
const RECONCILE_EPS := 0.02          # m; smaller prediction errors are ignored
const HISTORY_MAX := 180             # commands kept for replay (3 s)
const CORRECTION_DECAY := 12.0       # 1/s, how fast the visual correction offset fades out
const CORRECTION_SNAP_DISTANCE := 2.0  # m; larger errors are shown instantly

## Server only: a shot was fired. `hits` = [{player_id, zone, pos}] (damage comes with stage 5).
signal server_shot(player: Player, weapon: int, origin: Vector3, ends: PackedVector3Array, hits: Array)

var control: Mode = Mode.LOCAL
var peer_id := 1
var player_name := "Игрок"
var is_local: bool:
	get:
		return control == Mode.LOCAL

var look_yaw := 0.0
var _sprint_latched := false  # gamepad sprint (Y / L3) stays on until the player stops moving forward
var _pad_look := false  # the gamepad was used last (not the mouse): aim assist is on
var _next_oink := 0.0     # s (ticks clock) when F may oink again
var _aim_assist := AimAssist.new()
var look_pitch := 0.0

var is_sliding := false
var is_crouched := false
var _puppet_velocity := Vector3.ZERO  # puppets: smoothed velocity of the displayed movement
var aiming := false  # sights raised (ADS over half way); puppets take it from the snapshot flags
var is_sprinting := false
var is_mantling := false
var gaps_filled := 0   # debug (server): lost commands replaced by a repeat of the previous one
var cmds_dropped := 0  # debug (server): commands discarded because the queue overflowed
var queue_peak := 0
var mantle_count := 0  # debug: vaults started (counted on replays too)

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
var _prev_yaw := 0.0            # body yaw at the previous / current physics tick (host: smooth remote players)
var _curr_yaw := 0.0
var _seq_offset := INF          # other player: local clock minus their 60 Hz step clock, smoothed (_buffer_pose)
var _jitter := 0.0              # other player: how far recent poses were off that clock (s, slowly forgotten)
var _interp_delay := 0.06       # other player: how far in the past they are drawn right now (s)
var shown_tick := 0.0           # other player: server tick of the pose drawn this frame (0 = none yet)
var _cmd_seq := 0
var _sent_cmds: Array = []        # last CMD_REDUNDANCY encoded commands (client -> server)
var _cmd_queue: Array = []        # received encoded commands (server)
var _last_received_seq := 0
var _last_cmd := PlayerCmd.new()  # server: previously applied command (used to fill gaps)
var _step_budget := 0.0
var _acked_seq := 0               # server: seq of the last command applied
var _snapshots: Array = []        # other player: buffered poses [{t, pos, yaw, pitch, tick}] (_buffer_pose)
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
var max_health := MAX_HEALTH  # kid mode doubles it
var kid_mode := false
var alive := true
var spawn_protect := 0      # server: ticks of invulnerability left after a respawn
var _regen_wait := 0.0      # server: seconds until health starts coming back
var _regen_carry := 0.0     # server: fraction of a health point regenerated but not yet added
var killed_by := ""         # local HUD: who killed us
var death_time_left := 0.0  # local HUD: respawn countdown
var shots_total := 0   # server stats (for tests / netlog)
var hits_total := 0
var head_hits_total := 0
var _shown_pitch := 0.0  # host: aim pitch of a remote player as drawn (_buffered_pose)
var _view: WeaponView
var _arms: FirstPersonArms
var _crosshair: Crosshair
var _ammo_hud: HudAmmo
var _health_hud: HudHealth
var _damage_dirs: DamageIndicator
var _hurt_rect: ColorRect  # HURT_SHADER vignette
var _death_label: Label
var _hurt_alpha := 0.0
var _last_health := MAX_HEALTH
var _debug_timer := 0.0
var _stance_crouched := false
var _sprint_blend := 0.0
var _view_recoil := Vector2.ZERO
var _look_delta := Vector2.ZERO
var _turn_rate := 0.0  # rad/s the stick (and aim assist) turns the view, smoothed; F3 only
var _prev_look := Vector2.ZERO
var _retract := 0.0
# First-person camera effects (_update_camera_fx; cosmetic: shots go where the look angles point, not the camera).
var _cam_roll := 0.0             # death tilt / slide lean
var _cam_land := 0.0             # landing dip (m) and its spring velocity
var _cam_land_v := 0.0
var _land_impact := 0.0          # fall speed of a landing not yet shown (set by the simulation)
var _bob_amount := 0.0
var _bob_side := 1.0             # which foot the current step is on
var _punch := Vector2.ZERO       # damage jolt: x = pitch, y = roll (rad)
var _punch_v := Vector2.ZERO
var _mantle_view := 0.0          # vaulting: gun lowered, hands on the ledge, view pitched down
var _ledge_set := false
var _dust_t := 0.0               # to the next slide dust puff (s)
var _bot_select := 0
var _bot_corner := 1      # --bot-course: the loop corner it runs to next
var _bot_stuck := 0.0     # --bot-course: s standing still while trying to run
## --bot-course: corners of the obstacle course loop (x, z), in running order (prefabs/levels/course.tscn).
const COURSE_LOOP: Array[Vector2] = [Vector2(-30, 22), Vector2(30, 22), Vector2(30, -22), Vector2(-30, -22)]
var _mantle_tick := 0
var _mantle_total := 0
var _mantle_rise := 0
var _mantle_cooldown := 0
var _floor_y := 0.0  # height of the last ground we stood on (limits how high jump + vault can reach)
var _mantle_from := Vector3.ZERO
var _mantle_up := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_dir := Vector3.ZERO
var _probe_shape := CapsuleShape3D.new()
var _probe_crouch_shape := CapsuleShape3D.new()
var _mantle_low := false  # the vault being started ends crouched (set by _try_start_mantle, used the same tick)
var _vault_note := ""        # local debug: why the last vault attempt failed
var _vault_note_until := 0
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
var _debug_shown := false  # F3
@onready var _visual: PlayerVisual = $Visual


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
	_camera.current = is_local
	_camera.fov = Settings.fov
	_hud.visible = is_local
	set_physics_process(control != Mode.PUPPET)
	if not is_local:
		_visual.setup(peer_id, player_name)
		_visual.set_weapon(weapons.index)
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
		_view.set_weapon(weapons.index)
		# First-person arms made from the same character as the body other players see.
		_arms = FirstPersonArms.new()
		_camera.add_child(_arms)
		_arms.setup(peer_id, _view)
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
	_curr_yaw = rotation.y


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
		_stick_look(delta)
		_view_recoil = _view_recoil.lerp(weapons.recoil, 1.0 - exp(-25.0 * delta))
		_correction *= exp(-CORRECTION_DECAY * delta)
		var pos := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction()) + _correction
		var view_angles := Vector3(look_pitch + _view_recoil.x, look_yaw + _view_recoil.y, 0.0)
		_head.global_transform = Transform3D(Basis.from_euler(view_angles), pos + Vector3.UP * _eye_height)
	else:
		_head.position.y = _eye_height
		# Server-simulated remote player seen on the host: drive its body like a puppet's. The physics body moves
		# at 60 Hz, and in uneven steps when their commands arrive in bursts; the model is drawn from the buffered
		# poses instead (_buffered_pose), smoothly at any frame rate. The host's shots are judged at shown_tick.
		var shown := _buffered_pose(delta)
		if not shown.is_empty():
			_visual.position = global_transform.basis.inverse() * (shown["pos"] - global_position)
			_visual.rotation.y = angle_difference(rotation.y, shown["yaw"])
			shown_tick = shown["tick"]
		_shown_pitch = shown.get("pitch", _head.rotation.x)
		_visual.set_aim_pitch(_shown_pitch)
		_visual.set_ads(aiming)
		_visual.set_crouched(is_crouched)
		_visual.set_sliding(is_sliding)
		_visual.set_reloading(weapons.is_reloading())
		_visual.set_mantling(is_mantling, _mantle_up.y)
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


## Right-stick look (the mouse turns the view in _unhandled_input). Slower while aiming, like the mouse.
## With the stick (not the mouse) the aim assist slows it down over an enemy and follows a moving one.
func _stick_look(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or Game.bot_mode or not alive:
		_aim_assist.target_id = -1
		return
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if stick != Vector2.ZERO:
		_pad_look = true
	var turn := Vector2.ZERO
	if _pad_look:
		turn = _aim_assist.update(_head.global_position, look_yaw, look_pitch, weapons.ads,
				stick != Vector2.ZERO or move != Vector2.ZERO, Settings.effective_aim_assist(), _assist_targets(), _assist_visible,
				Settings.aim_assist_reach())
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
		# Any other action ends a latched sprint; press Y / L3 again to sprint on.
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("crouch") or cmd.fire or cmd.aim \
				or cmd.reload or cmd.select >= 0:
			_sprint_latched = false
		cmd.sprint = Input.is_action_pressed("sprint") or _sprint_latched
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


func _sfx(id: String, volume_db: float = 0.0) -> void:
	if _replaying:
		return
	Audio.play(id, null if is_local else global_position, volume_db)


# --- Networking -------------------------------------------------------------------------------

func _bot_cmd(delta: float) -> PlayerCmd:
	# Scripted input for automated network tests (launch args --bot / --bot-aim).
	var t := Time.get_ticks_msec() / 1000.0
	var cmd := PlayerCmd.new()
	if Game.bot_oink:
		_try_oink()
	if Game.bot_aim and world != null:
		return _bot_aim_cmd(t)
	if Game.bot_targets:
		return _bot_targets_cmd(t)
	if Game.bot_course:
		return _bot_course_cmd(delta)
	if Game.bot_vault:
		# Runs back and forth over the test ledges, jumping all the time (vaults whenever one is in reach).
		look_yaw = PI if fmod(t, 7.0) >= 3.5 else 0.0  # 3.5 s each way (~18 m): crosses the ledges in both directions
		cmd.yaw = look_yaw
		cmd.move = Vector2(0.0, -1.0)
		cmd.jump = fmod(t, 0.4) < delta
		return cmd
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


## Runs laps of the obstacle course: down the middle lane of each side (COURSE_LOOP corners, in order), jumping at
## anything knee-high ahead, at edges and when stuck, holding jump in the air (grabs ledges) and crouching under
## anything head-high (a sprint into it slides).
func _bot_course_cmd(delta: float) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	var p := global_position
	var corner: Vector2 = COURSE_LOOP[_bot_corner]
	if Vector2(p.x, p.z).distance_to(corner) < 2.5:
		_bot_corner = (_bot_corner + 1) % COURSE_LOOP.size()
		if _bot_corner == 1 and Game.net_log:
			print("[COURSE] lap done at %.1f s" % (Time.get_ticks_msec() / 1000.0))
		corner = COURSE_LOOP[_bot_corner]
	# Aim at a point 3 m ahead on the side's centre line (not at the corner itself), so it stays in the middle lane.
	var from: Vector2 = COURSE_LOOP[(_bot_corner + COURSE_LOOP.size() - 1) % COURSE_LOOP.size()]
	var along := (corner - from).normalized()
	var here := from + along * clampf((Vector2(p.x, p.z) - from).dot(along), 0.0, from.distance_to(corner))
	var aim := here + along * minf(3.0, here.distance_to(corner))
	look_yaw = atan2(-(aim.x - p.x), -(aim.y - p.z))
	look_pitch = 0.0
	cmd.yaw = look_yaw
	cmd.move = Vector2(0.0, -1.0)
	cmd.sprint = true
	var fwd := Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))
	var space := get_world_3d().direct_space_state
	var ray := func(from: Vector3, to: Vector3) -> bool:
		return not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD, [get_rid()])).is_empty()
	var knee: bool = ray.call(p + Vector3(0, 0.3, 0), p + Vector3(0, 0.3, 0) + fwd)
	var head: bool = ray.call(p + Vector3(0, 1.3, 0), p + Vector3(0, 1.3, 0) + fwd * 1.8)
	var roof: bool = ray.call(p + Vector3(0, 0.9, 0), p + Vector3(0, 1.9, 0))
	var floor_ahead: bool = ray.call(p + Vector3(0, 0.2, 0) + fwd * 0.7, p + Vector3(0, -0.6, 0) + fwd * 0.7)
	var speed := Vector2(velocity.x, velocity.z).length()
	_bot_stuck = _bot_stuck + delta if is_on_floor() and speed < 0.5 and not is_mantling else 0.0
	cmd.crouch = (head and not knee) or roof
	cmd.jump = is_on_floor() and not cmd.crouch and (knee or not floor_ahead or _bot_stuck > 0.3)
	cmd.jump_held = not is_on_floor() or cmd.jump
	return cmd


## Stands still and shoots the training targets in turn, 4 s each: body, then head every other turn.
func _bot_targets_cmd(t: float) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	var targets := get_tree().get_nodes_in_group(Target.GROUP)
	cmd.aim = true
	if not targets.is_empty() and alive:
		var turn := int(t / 4.0)
		var target: Target = targets[turn % targets.size()]
		var state := target.hitbox_state()
		var seg := LagComp.body_segment(state)
		var point := LagComp.head_center(state) if (turn / targets.size()) % 2 == 1 else seg[0].lerp(seg[1], 0.6)
		var eye := global_position + Vector3.UP * STAND_EYE
		var dir := (point - eye).normalized()
		look_yaw = atan2(-dir.x, -dir.z) - weapons.recoil.y
		look_pitch = clampf(asin(dir.y) - weapons.recoil.x, -MAX_PITCH, MAX_PITCH)
		cmd.fire = weapons.ads > 0.95 and target.alive
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
	cmd.reload = weapons.mags[weapons.index] == 0
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
		var dir := (LagComp.head_center(target.hitbox_state()) - eye).normalized()  # headshots test the hitbox model
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
	flags |= FLAG_JUMP_HELD if cmd.jump_held else 0
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
	cmd.jump_held = flags & FLAG_JUMP_HELD != 0
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
		return filler  # no jump / reload / weapon switch: one-shot events are not repeated
	var entry: Array = _cmd_queue.pop_front()
	_acked_seq = entry[0]
	_last_cmd = _decode_cmd(entry)
	return _last_cmd


## The ledge height of a vault in a snapshot entry (get_net_state: extra -> mantle -> the pull-up point).
static func _snapshot_mantle_top(state: Array) -> float:
	var extra: Array = state[7]
	var mantle: Array = extra[6]
	return (mantle[5] as Vector3).y


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
	var mantle := [is_mantling, _mantle_tick, _mantle_total, _mantle_rise, _mantle_from, _mantle_up, _mantle_to, _mantle_dir,
			_mantle_cooldown, _floor_y]
	var extra := [_slide_dir, _slide_speed, _slide_time, _slide_cooldown, _prev_crouch, weapons.to_array(), mantle]
	return [peer_id, global_position, rotation.y, _head.rotation.x, velocity, flags, _acked_seq, extra, health]


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
	weapons.index = (flags >> STATE_WEAPON_SHIFT) & 3
	_visual.set_weapon(weapons.index)
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
	rotation.y = shown["yaw"]
	_head.rotation.x = shown["pitch"]
	shown_tick = shown["tick"]
	# Velocity of the displayed movement (smooth, unlike the snapshot velocity): drives the body and hitboxes.
	if delta > 0.0 and previous_pos.distance_to(global_position) < 2.0:
		var drawn_vel := (global_position - previous_pos) / delta
		_puppet_velocity = _puppet_velocity.lerp(Vector3(drawn_vel.x, 0.0, drawn_vel.z), 1.0 - exp(-12.0 * delta))
	_visual.set_crouched(is_crouched)
	_visual.set_sliding(is_sliding)
	_visual.set_aim_pitch(_head.rotation.x)
	_visual.update_motion(delta, global_transform.basis.inverse() * _puppet_velocity, _puppet_on_floor)
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


## Host: buffers a remote player's pose after each of their commands (drawn by _process via _buffered_pose).
func _record_host_sample() -> void:
	_buffer_pose(_acked_seq, global_position, rotation.y, _head.rotation.x, float(world.server_tick) if world else 0.0)


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
	var events := weapons.tick(cmd, dt, ctx)
	aiming = weapons.ads > 0.5
	for event in events:
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
	var target_hits := {}  # Target -> {damage, head, marks: [[pos, head]]} (training targets)
	for dir in event["dirs"]:
		var r := _trace(origin, dir, def.max_range, tick)
		results.append(r)
		ends.append(r["pos"])
		var target: Target = r.get("target")
		if target != null:
			var t_head: bool = r["zone"] == "head"
			var t_entry: Dictionary = target_hits.get_or_add(target, {"damage": 0.0, "head": false, "marks": []})
			t_entry["damage"] += def.damage * (NetWorld.HEAD_DAMAGE_MULT if t_head else 1.0)
			t_entry["head"] = t_entry["head"] or t_head
			t_entry["marks"].append([r["pos"], t_head])
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
		for hit in hits:
			head_hits_total += 1 if hit["zone"] == "head" else 0
		server_shot.emit(self, event["weapon"], origin, ends, hits)
		if world != null:
			for victim_id in damage_by_victim:
				var entry: Dictionary = damage_by_victim[victim_id]
				world.server_apply_damage(self, entry["player"], entry["damage"], entry["head"], event["weapon"])
		for target in target_hits:
			var t_entry: Dictionary = target_hits[target]
			for mark in t_entry["marks"]:
				(target as Target).add_mark(mark[0], mark[1])
			var knocked: bool = (target as Target).take_damage(t_entry["damage"], t_entry["head"])
			if is_local:
				on_hit_confirmed(knocked, t_entry["head"])
	if is_local:
		_view.flash()
		_view.kick(1.0 if def.pellets == 1 else 2.0)
		Audio.play(def.sound_shot)
		var muzzle := _view.muzzle_global_position()
		if world != null and world.kill_cam != null:
			world.kill_cam.record_shot(peer_id, event["weapon"], muzzle, ends)
		var scene_root := get_tree().current_scene
		for r in results:
			ShotEffects.spawn_tracer(scene_root, muzzle, r["pos"])
			if r["player"] != null:
				(r["player"] as Player).react_to_shot(origin, r["pos"])
			elif r.get("target") != null:
				(r["target"] as Target).react_to_shot(origin, r["pos"])
			if r["hit"] and r["player"] == null and r.get("target") == null:
				ShotEffects.spawn_impact(scene_root, r["pos"], r["normal"])
				Audio.play("impact", r["pos"])


## Which server tick to judge a shot at: the shooter's view tick (server, remote shooters, lag comp on),
## or -1 to use everyone's live positions.
func _judge_tick(view_tick: float, is_server: bool) -> float:
	# The host's own shots too: it sees remote players slightly in the past as well (_buffered_pose).
	if not is_server or control == Mode.PUPPET or world == null or not world.lag_comp_enabled or view_tick <= 0.0:
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
		var t_head := LagComp.ray_sphere(origin, dir, LagComp.head_center(state), LagComp.HEAD_RADIUS)
		var seg := LagComp.body_segment(state)
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
	# Training targets: the same hitboxes, always at their live position (they are not networked).
	for node in get_tree().get_nodes_in_group(Target.GROUP):
		var target := node as Target
		if not target.alive:
			continue
		var t_state := target.hitbox_state()
		var t_head := LagComp.ray_sphere(origin, dir, LagComp.head_center(t_state), LagComp.HEAD_RADIUS)
		var t_seg := LagComp.body_segment(t_state)
		var t_body := LagComp.ray_capsule(origin, dir, t_seg[0], t_seg[1], LagComp.BODY_RADIUS)
		var t_hit := -1.0
		var t_zone := ""
		if t_head >= 0.0 and (t_body < 0.0 or t_head <= t_body + 0.0001):
			t_hit = t_head
			t_zone = "head"
		elif t_body >= 0.0:
			t_hit = t_body
			t_zone = "body"
		if t_hit >= 0.0 and t_hit < best:
			best = t_hit
			result = {"pos": origin + dir * t_hit, "normal": -dir, "hit": true, "player": null, "zone": t_zone,
					"target": target}
	return result


func _target_state(other: Player, tick: float) -> Dictionary:
	if tick >= 0.0:
		return world.lag_comp.sample(other.peer_id, tick)
	return other.hitbox_state()


## What the hitboxes depend on (LagComp): position, stance, facing, aim pitch, velocity and aiming.
## Puppets report their displayed state, the server its simulation.
func hitbox_state() -> Dictionary:
	var vel := velocity if control != Mode.PUPPET else _puppet_velocity
	return {"pos": global_position, "crouched": is_crouched, "yaw": rotation.y, "pitch": _head.rotation.x,
			"vel": Vector3(vel.x, 0.0, vel.z), "ads": aiming, "sliding": is_sliding}


## A shot that ended at `end` (world) jerks this player's body if it ended on it (cosmetic).
func react_to_shot(origin: Vector3, end: Vector3) -> void:
	if not is_local:
		_visual.react_to_shot(origin, end)


## Cosmetics of somebody else's shot (called by World on clients and on the host).
func show_remote_shot(weapon: int, origin: Vector3, ends: PackedVector3Array) -> void:
	var def := WeaponDB.get_def(weapon)
	if world != null and world.kill_cam != null:
		world.kill_cam.record_shot(peer_id, weapon, origin, ends)
	_visual.set_weapon(weapon)
	_visual.show_shot()
	Audio.play(def.sound_shot, origin)
	var scene_root := get_tree().current_scene
	var muzzle := _visual.muzzle_global_position()
	for i in ends.size():
		ShotEffects.spawn_tracer(scene_root, muzzle, ends[i])
		ShotEffects.spawn_impact(scene_root, ends[i], Vector3.UP)
		if world != null:
			for id in world.players:
				if id != peer_id:
					(world.players[id] as Player).react_to_shot(origin, ends[i])
		if i < 2:  # a shotgun blast would otherwise play eight impacts at once
			Audio.play("impact", ends[i])


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
	_ammo_hud.set_state(def.display_name, weapons.mags[weapons.index], def.mag_size, weapons.reserves[weapons.index],
			weapons.is_reloading())
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


## F3 line: "mouse" (no assist), "pad" (assist ready, no target) or the target it is working on right now.
func _assist_debug() -> String:
	if not _pad_look:
		return "assist off (mouse)"
	if _aim_assist.target_id < 0:
		return "assist: no target"
	var target_name: String = world.players[_aim_assist.target_id].player_name \
			if world != null and world.players.has(_aim_assist.target_id) else str(_aim_assist.target_id)
	return "assist: %s  strength %.2f  stick x%.2f" % [target_name, _aim_assist.strength, _aim_assist.slowdown]
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_debug.text += "\nrtt %d ms  recon %d  err %.2f m" % [rtt_ms, recon_count, last_error]


func debug_weapon_string() -> String:
	return "w%d mag=%d/%d shots=%d mv=%d drop=%d gaps=%d qpeak=%d" % [weapons.index, weapons.mags[weapons.index], weapons.reserves[weapons.index],
			weapons.shots, mantle_count, cmds_dropped, gaps_filled, queue_peak]


# --- Health, death, respawn ---------------------------------------------------------------------------

## Server: applies damage; returns true if this killed the player.
func server_damage(amount: float) -> bool:
	if not alive:
		return false
	health = maxi(health - roundi(amount), 0)
	_regen_wait = KID_REGEN_DELAY if kid_mode else REGEN_DELAY
	_regen_carry = 0.0
	if health == 0:
		alive = false
		return true
	return false


## `from`: the killer's position (world; INF if unknown) and `head_hit` - which way and how hard the body falls.
func die(by: String, respawn_delay: float, from := Vector3.INF, head_hit := false) -> void:
	if not alive and respawn_delay <= 0.0:
		return
	alive = false
	health = 0
	killed_by = by
	death_time_left = respawn_delay
	_visual.set_dead(true, from, head_hit)
	Audio.play("death", null if is_local else global_position)


## Server, every tick: health comes back REGEN_DELAY s (kid mode: KID_REGEN_DELAY) after the last damage, REGEN_PER_SECOND HP per second.
## Clients see it in the snapshots (health is part of every player's state).
func server_regen(delta: float) -> void:
	if not alive or health >= max_health:
		_regen_carry = 0.0
		return
	if _regen_wait > 0.0:
		_regen_wait -= delta
		return
	_regen_carry += REGEN_PER_SECOND * delta
	var whole := int(_regen_carry)
	if whole > 0:
		health = mini(health + whole, max_health)
		_regen_carry -= whole


## Kid mode (chosen by the player, sent to the server on join): more health. Call before the first respawn / snapshot.
func set_kid_mode(on: bool) -> void:
	kid_mode = on
	max_health = MAX_HEALTH * (KID_HEALTH_MULT if on else 1)
	health = max_health
	_last_health = max_health


func respawn(xform: Transform3D) -> void:
	alive = true
	health = max_health
	_last_health = max_health
	_regen_wait = 0.0
	_regen_carry = 0.0
	killed_by = ""
	death_time_left = 0.0
	if _damage_dirs:
		_damage_dirs.clear()
	_punch = Vector2.ZERO
	_punch_v = Vector2.ZERO
	_cam_land = 0.0
	_cam_land_v = 0.0
	weapons.reset()
	teleport(xform)
	_visual.set_dead(false)
	if _view:
		_view.set_weapon(weapons.index)
	if is_local and world != null and world.kill_cam != null:
		world.kill_cam.stop()
	Audio.play("spawn", null if is_local else global_position)


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


## Local player: the server says we were just hit by a shooter standing at `from` (for the damage direction arcs).
func on_damaged_from(from: Vector3) -> void:
	if _damage_dirs:
		_damage_dirs.add(from)
	if alive and _camera:
		# The view jolts away from the shooter: pitches up for a hit from the front, rolls for one from the side.
		var local := _camera.global_basis.inverse() * (from - _camera.global_position)
		var flat := Vector2(local.x, local.z)
		if flat.length() > 0.01:
			flat = flat.normalized()
			_punch_v += Vector2(-flat.y * 0.5, flat.x * 0.6)
			_punch_v = _punch_v.limit_length(1.2)


## Local player: the server confirmed that one of our shots damaged somebody.
func on_hit_confirmed(killed: bool, head: bool) -> void:
	if _crosshair:
		_crosshair.show_hit(killed, head)
	Audio.play("kill" if killed else "hit")


## F / d-pad up: the local player oinks. Heard at once here; the server passes it on to everyone else
## (NetWorld.server_oink, which also enforces the cooldown).
func _try_oink() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not alive or world == null or now < _next_oink:
		return
	_next_oink = now + NetWorld.OINK_COOLDOWN
	play_oink()
	if multiplayer.is_server():
		world.server_oink(peer_id)
	else:
		world.request_oink.rpc_id(1)


## Each player has their own pig voice (by peer id); others hear it from where the head is.
func play_oink() -> void:
	var voice: String = ["oink", "oink2", "oink3"][absi(peer_id) % 3]
	if Game.net_log:
		print("[%d] oink from %d (%s)" % [multiplayer.get_unique_id(), peer_id, voice])
	Audio.play(voice, null if is_local else global_position + Vector3.UP * 1.5)


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
	_visual.set_reloading(reloading)


# --- Vaulting ------------------------------------------------------------------------------------------

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
		_sfx("land", -6.0)


## While vaulting you cannot shoot, aim or reload (weapon switching still works).
func _mantle_weapon_cmd(cmd: PlayerCmd) -> PlayerCmd:
	var weapon_cmd := PlayerCmd.new()
	weapon_cmd.yaw = cmd.yaw
	weapon_cmd.pitch = cmd.pitch
	weapon_cmd.select = cmd.select
	return weapon_cmd
