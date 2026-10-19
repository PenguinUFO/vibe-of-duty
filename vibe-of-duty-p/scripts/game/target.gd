class_name Target
extends Node3D
## Training target: a player model (PlayerVisual) that is shot like a player - the same analytic hitboxes
## (LagComp: body capsule, head sphere), the same damage and head multiplier, as much health as a player
## (Player.MAX_HEALTH). Every hit leaves a mark on the body (yellow: head, red: body) and a floating damage number;
## the health is shown over the head. Marks and numbers keep their screen size at any distance. At 0 health it falls over and stands up again RISE_DELAY s later, healed and
## with the marks cleared.
##
## Shots reach it through Player._trace (all nodes in GROUP) on the server, which in training is this machine.
## Not networked: training is played alone (Net.host_training).

const GROUP := "training_targets"
const RISE_DELAY := 3.0
const MARKS_MAX := 60
const MARK_PIXELS := 24          # hit mark texture size; drawn at a fixed screen size, readable at 75 m too
const MARK_PIXEL_SIZE := 0.00045
const BODY_SURFACE := 0.26     # marks sit just in front of the model, this far from the body axis (the hitbox
const HEAD_SURFACE := 0.2       # capsule is wider); depth-tested, so walls and the gun in hand cover them
const BURST_GAP := 0.35         # s: hits closer together than this add up in one damage number
const NUMBER_TIME := 1.0       # s a damage number floats up and fades
const HEAD_COLOR := Color(1.0, 0.85, 0.2)
const BODY_COLOR := Color(0.95, 0.15, 0.1)

## Colour seed of the model (Mannequin.color_for), so targets are told apart.
@export var color_id := 7

var health := Player.MAX_HEALTH
var alive := true
var velocity := Vector3.ZERO   # moving targets (RunningTarget) lean the hitbox like a running player

var _visual := PlayerVisual.new()
var _marks: Array[Node3D] = []
var _number_side := 1.0           # damage numbers alternate left / right of the target
var _burst_label: Label3D         # the damage number of the current burst (_float_number)
var _burst_total := 0
var _burst_head := false
var _burst_time := -10.0
var _burst_tween: Tween
var _health_label := Label3D.new()

static var _mark_tex: ImageTexture


func _ready() -> void:
	add_to_group(GROUP)
	add_child(_visual)
	_visual.setup(color_id, "")
	_visual.set_weapon(0)
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.fixed_size = true
	_health_label.pixel_size = 0.0008
	_health_label.outline_size = 8
	_health_label.position.y = PlayerVisual.NAME_TAG_HEIGHT
	add_child(_health_label)
	_update_health_label()


func _process(delta: float) -> void:
	_visual.update_motion(delta, Vector3.ZERO)


## A shot that ended at `end` (world) jerks the body if it ended on it (cosmetic).
func react_to_shot(origin: Vector3, end: Vector3) -> void:
	_visual.react_to_shot(origin, end)


## The hitboxes, like Player.hitbox_state.
func hitbox_state() -> Dictionary:
	return {"pos": global_position, "crouched": false, "yaw": global_rotation.y, "pitch": 0.0,
			"vel": Vector3(velocity.x, 0.0, velocity.z), "ads": false}


## A pellet hit at `pos` (on the hitbox, from LagComp): leaves a mark on the model.
func add_mark(pos: Vector3, head: bool) -> void:
	if not alive:
		return
	var state := hitbox_state()
	var surface: Vector3
	if head:
		var center := LagComp.head_center(state)
		surface = center + (pos - center).normalized() * HEAD_SURFACE
	else:
		var seg := LagComp.body_segment(state)
		var axis := Geometry3D.get_closest_point_to_segment(pos, seg[0], seg[1])
		var out := pos - axis
		surface = axis + (out.normalized() if out.length() > 0.001 else Vector3.ZERO) * BODY_SURFACE
	var mark := Sprite3D.new()
	mark.texture = _mark_texture()
	mark.modulate = HEAD_COLOR if head else BODY_COLOR
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.fixed_size = true
	mark.pixel_size = MARK_PIXEL_SIZE
	mark.shaded = false
	_visual.attach_to_body(mark, surface)  # falls with the body
	_marks.append(mark)
	if _marks.size() > MARKS_MAX:
		_marks.pop_front().queue_free()


## The damage of one shot (all its pellets that hit): a floating number, and the fall at 0 health.
## Returns true if this shot knocked the target down.
func take_damage(amount: float, head: bool) -> bool:
	if not alive:
		return false
	var dealt := mini(roundi(amount), health)
	health -= dealt
	_float_number(dealt, head)
	if Game.net_log:
		print("[TARGET %s] -%d%s, %d left" % [name, dealt, " head" if head else "", health])
	_update_health_label()
	if health > 0:
		return false
	alive = false
	_visual.set_dead(true)
	_health_label.visible = false
	Audio.play("death", global_position)
	get_tree().create_timer(RISE_DELAY).timeout.connect(_rise)
	return true


func _rise() -> void:
	if not is_inside_tree():
		return
	for mark in _marks:
		mark.queue_free()
	_marks.clear()
	health = Player.MAX_HEALTH
	alive = true
	_visual.set_dead(false)
	_health_label.visible = true
	_update_health_label()
	Audio.play("spawn", global_position)


func _update_health_label() -> void:
	_health_label.text = "%d" % health
	var f := float(health) / Player.MAX_HEALTH
	_health_label.modulate = Color(1.0, 0.35, 0.3).lerp(Color(0.7, 1.0, 0.6), f)


## Shows the damage beside the target. Hits closer together than BURST_GAP add up in one number (an automatic
## burst reads as one total instead of a pile of overlapping "-28"s); a new burst starts a new number.
func _float_number(amount: int, head: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if is_instance_valid(_burst_label) and now - _burst_time < BURST_GAP:
		_burst_total += amount
		_burst_head = _burst_head or head
	else:
		_burst_label = Label3D.new()
		_burst_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_burst_label.no_depth_test = true  # floats in the air beside the target, never inside anything
		_burst_label.fixed_size = true
		_burst_label.outline_size = 12
		_burst_label.render_priority = 10
		get_tree().current_scene.add_child(_burst_label)
		_burst_total = amount
		_burst_head = head
		_number_side = -_number_side  # bursts alternate sides
	_burst_time = now
	var label := _burst_label
	label.text = "-%d" % _burst_total
	label.pixel_size = 0.0016 if _burst_head else 0.0013
	label.modulate = HEAD_COLOR if _burst_head else Color.WHITE
	# Beside the head, drifting up and outwards. Offsets in camera-right units scaled with the distance: the same
	# spread on screen near and far.
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_transform.basis.x if camera else Vector3.RIGHT
	var spread := 0.05 * (camera.global_position.distance_to(global_position) if camera else 10.0)
	var start := global_position + Vector3.UP * (PlayerVisual.NAME_TAG_HEIGHT - 0.4) + right * _number_side * spread
	label.global_position = start
	if _burst_tween:
		_burst_tween.kill()  # each hit of the burst restarts the float, so the total stays readable
	_burst_tween = label.create_tween().set_parallel()
	_burst_tween.tween_property(label, "global_position", start + right * _number_side * spread * 0.6
			+ Vector3.UP * spread * 0.8, NUMBER_TIME)
	_burst_tween.tween_property(label, "modulate:a", 0.0, NUMBER_TIME).set_ease(Tween.EASE_IN)
	_burst_tween.chain().tween_callback(label.queue_free)


## A round dot with a dark rim (tinted by the sprite's modulate).
static func _mark_texture() -> ImageTexture:
	if _mark_tex == null:
		var image := Image.create(MARK_PIXELS, MARK_PIXELS, false, Image.FORMAT_RGBA8)
		var c := (MARK_PIXELS - 1) * 0.5
		for y in MARK_PIXELS:
			for x in MARK_PIXELS:
				var d := Vector2(x - c, y - c).length() / (MARK_PIXELS * 0.5)
				if d <= 0.62:
					image.set_pixel(x, y, Color.WHITE)
				elif d <= 0.95:
					image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.85))
				else:
					image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
		_mark_tex = ImageTexture.create_from_image(image)
	return _mark_tex
