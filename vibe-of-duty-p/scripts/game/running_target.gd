class_name RunningTarget
extends Target
## A training target that runs round a circle like a dodging player: every SPEED_CHANGE_MIN..MAX s it picks a new
## speed between a crouch-walk and a sprint (and now and then turns back), and it weaves in and out from the circle.
## It stops while knocked down and runs on when it stands up. Placed at the circle's centre.

const SPEED_CHANGE_MIN := 0.5
const SPEED_CHANGE_MAX := 1.6
const ACCEL := 14.0                 # m/s^2, how fast it reaches the new speed
const REVERSE_CHANCE := 0.15        # chance that a speed change also turns it back
const WEAVE_MIN := 0.6              # m, how far it weaves off the circle...
const WEAVE_MAX := 1.6
const WEAVE_FREQ_MIN := 0.5         # ...and how often (weaves per second)
const WEAVE_FREQ_MAX := 1.4

@export var radius := 7.0

var _angle := 0.0                   # position on the circle (rad)
var _dir := 1.0                     # +1 / -1: which way round
var _speed := 0.0                   # current speed along the circle, m/s
var _target_speed := 4.0
var _change_in := 0.0
var _weave_phase := 0.0
var _weave_freq := 1.0
var _weave_amp := 1.0
var _center := Vector3.ZERO


func _ready() -> void:
	_center = global_position
	super._ready()
	_angle = randf() * TAU
	_place(0.0)


func _process(delta: float) -> void:
	if alive:
		_change_in -= delta
		if _change_in <= 0.0:
			_change_in = randf_range(SPEED_CHANGE_MIN, SPEED_CHANGE_MAX)
			_target_speed = randf_range(Player.CROUCH_SPEED, Player.SPRINT_SPEED)
			if randf() < REVERSE_CHANCE:
				_dir = -_dir
			_weave_freq = randf_range(WEAVE_FREQ_MIN, WEAVE_FREQ_MAX)
			_weave_amp = randf_range(WEAVE_MIN, WEAVE_MAX)
		_speed = move_toward(_speed, _target_speed * _dir, ACCEL * delta)
	else:
		_speed = 0.0
	_place(delta)
	super._process(delta)


## Moves the body (this node: the hitboxes are taken from its position) along the circle plus the weave.
func _place(delta: float) -> void:
	var before := global_position
	_angle += _speed / radius * delta
	_weave_phase += TAU * _weave_freq * delta if alive else 0.0
	var r := radius + sin(_weave_phase) * _weave_amp
	var pos := _center + Vector3(cos(_angle), 0.0, sin(_angle)) * r
	global_position = pos
	if delta > 0.0:
		velocity = (pos - before) / delta
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.3:
		# Faces where it runs (models face -Z).
		global_rotation.y = lerp_angle(global_rotation.y, atan2(-flat.x, -flat.y), 1.0 - exp(-10.0 * delta))
