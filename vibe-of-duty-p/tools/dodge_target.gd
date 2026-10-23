extends Target
## Test only (prefabs/levels/ttk.tscn, the TTK balance test): a target that runs round its node's position (the
## shooter stands there) at `radius`, like a dodging player: every SPEED_CHANGE_MIN..MAX s a new speed between a
## crouch-walk and a sprint, now and then turning back; it weaves in and out from the circle; every DASH_MIN..MAX s it
## dashes - at once at slide speed for DASH_TIME s, half the time the other way. Stops while knocked down.

const SPEED_CHANGE_MIN := 0.5
const SPEED_CHANGE_MAX := 1.6
const ACCEL := 14.0                 # m/s^2 to a new speed (a dash skips it)
const REVERSE_CHANCE := 0.15
const WEAVE_MIN := 0.6              # m off the circle...
const WEAVE_MAX := 1.6
const WEAVE_FREQ_MIN := 0.5         # ...weaves per second
const WEAVE_FREQ_MAX := 1.4
const DASH_MIN := 1.2               # s between dashes
const DASH_MAX := 2.5
const DASH_TIME := 0.35
const DASH_SPEED := Player.SLIDE_START_SPEED

@export var radius := 10.0

var _angle := -PI / 2.0             # starts in front of the shooter (-Z)
var _dir := 1.0
var _speed := 0.0
var _target_speed := 4.0
var _change_in := 0.0
var _dash_in := 1.0
var _dash_left := 0.0
var _weave_phase := 0.0
var _weave_freq := 1.0
var _weave_amp := 1.0
var _center := Vector3.ZERO


func _ready() -> void:
	_center = global_position
	super._ready()
	_place(0.0)


func _physics_process(delta: float) -> void:
	if alive:
		_change_in -= delta
		if _change_in <= 0.0:
			_change_in = randf_range(SPEED_CHANGE_MIN, SPEED_CHANGE_MAX)
			_target_speed = randf_range(Player.CROUCH_SPEED, Player.SPRINT_SPEED)
			if randf() < REVERSE_CHANCE:
				_dir = -_dir
			_weave_freq = randf_range(WEAVE_FREQ_MIN, WEAVE_FREQ_MAX)
			_weave_amp = randf_range(WEAVE_MIN, WEAVE_MAX)
		_dash_in -= delta
		if _dash_in <= 0.0:
			_dash_in = randf_range(DASH_MIN, DASH_MAX)
			_dash_left = DASH_TIME
			if randf() < 0.5:
				_dir = -_dir
		if _dash_left > 0.0:
			_dash_left -= delta
			_speed = DASH_SPEED * _dir
		else:
			_speed = move_toward(_speed, _target_speed * _dir, ACCEL * delta)
	else:
		_speed = 0.0
	_place(delta)


func _place(delta: float) -> void:
	var before := global_position
	_angle += _speed / radius * delta
	if alive:
		_weave_phase += TAU * _weave_freq * delta
	var r := radius + sin(_weave_phase) * _weave_amp
	global_position = _center + Vector3(cos(_angle), 0.0, sin(_angle)) * r
	if delta > 0.0:
		velocity = (global_position - before) / delta
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.3:
		global_rotation.y = atan2(-flat.x, -flat.y)
