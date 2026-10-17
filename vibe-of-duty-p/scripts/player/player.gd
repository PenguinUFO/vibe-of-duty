class_name Player
extends CharacterBody3D
## First-person character. Movement is driven by step(cmd, dt), a deterministic function of the
## previous state and one PlayerCmd, so it can later be run on the server and replayed for prediction.

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
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

@export var is_local := true

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

@onready var _collision: CollisionShape3D = $Collision
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera
@onready var _hud: CanvasLayer = $HUD
@onready var _debug: Label = $HUD/Debug


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
	if not is_local:
		return
	_prev_pos = _curr_pos
	step(_gather_cmd(delta), delta)
	_curr_pos = global_position
	if _jumped_this_step:
		_jump_buffer = 0.0


func _process(delta: float) -> void:
	# Camera presentation only; none of this affects simulation.
	var eye := CROUCH_EYE if is_crouched else STAND_EYE
	_eye_height = lerpf(_eye_height, eye, 1.0 - exp(-14.0 * delta))
	if is_local:
		var pos := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
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


func _gather_cmd(delta: float) -> PlayerCmd:
	var cmd := PlayerCmd.new()
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
	Audio.play(id, null if is_local else global_position, volume_db)
