class_name PigPortrait
extends TextureRect
## The main menu's pig: the players' own head (Mannequin.make_head - the same low-poly sphere, snout, eyes and ears
## every body has) rendered once in its own SubViewport (own 3D world, studio lights, transparent background) into a
## still picture. The picture is kept for the rest of the session, so going back to the menu does not render it again.

const RENDER_SIZE := Vector2i(1024, 1024)
const HEAD_YAW := -0.5      # turned towards the menu column (screen left)
const HEAD_ROLL := 0.08
const CAMERA_POS := Vector3(0.0, 0.035, -0.66)  # in front of the face (the head looks along -Z)
const CAMERA_TARGET := Vector3(0.0, 0.025, 0.0)

static var _picture: Texture2D

var _viewport: SubViewport


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	modulate.a = 0.0
	if DisplayServer.get_name() == "headless":
		return  # nothing renders (dedicated server, headless test runs)
	if _picture == null:
		await _render()
	texture = _picture
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(self, "modulate:a", 1.0, 0.5)


func _render() -> void:
	_viewport = SubViewport.new()
	_viewport.size = RENDER_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.58, 0.62)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var camera := Camera3D.new()
	camera.fov = 28.0
	_viewport.add_child(camera)
	camera.look_at_from_position(CAMERA_POS, CAMERA_TARGET)

	# Warm key from the upper left of the picture (the menu side), cool low fill from the right, orange rim from
	# behind (the UI accent) to cut the head out of the dark background.
	_light(Vector3(0.6, 0.65, -0.55), Color(1.0, 0.94, 0.86), 1.6)
	_light(Vector3(-0.8, -0.15, -0.5), Color(0.7, 0.8, 1.0), 0.4)
	_light(Vector3(-0.6, 0.5, 0.8), Color(1.0, 0.62, 0.3), 2.6)
	_light(Vector3(0.7, 0.3, 0.7), Color(1.0, 0.7, 0.45), 1.4)

	var pivot := Node3D.new()
	pivot.rotation = Vector3(0.0, HEAD_YAW, HEAD_ROLL)
	_viewport.add_child(pivot)
	Mannequin.make_head(pivot)

	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_picture = ImageTexture.create_from_image(_viewport.get_texture().get_image())
	_viewport.queue_free()
	_viewport = null


## A directional light shining from `from` (a direction towards the light).
func _light(from: Vector3, color: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	_viewport.add_child(light)
	light.look_at_from_position(from.normalized(), Vector3.ZERO)
