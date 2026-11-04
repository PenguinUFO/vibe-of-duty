class_name ScopeBlur
extends MeshInstance3D
## Aimed through a magnified optic, the world round its window goes out of focus (assets/shaders/scope_blur.gdshader).
## Not a 1x one (owner, 2026-11-05): a red dot is shot with both eyes on the world. Hidden otherwise: then it costs
## nothing - the screen copy it reads is made only while it is drawn.

const SHADER := preload("res://assets/shaders/scope_blur.gdshader")
## ads_zoom: 1x sights have the usual aim's 0.75..0.85, magnified ones 0.5 (the Swarovski 1.5x) and less.
const MAGNIFIED_BELOW := 0.6

var _material := ShaderMaterial.new()


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)  # the shader's clip space: the whole screen
	mesh = quad
	_material.shader = SHADER
	_material.render_priority = Material.RENDER_PRIORITY_MIN
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	position = Vector3(0.0, 0.0, -1.0)
	visible = false


## Follows `view`'s window on `camera`'s screen at this aim blend.
func follow(view: WeaponView, camera: Camera3D, ads: float) -> void:
	var window := view.window_on_screen(camera)
	var magnified := view.visible and view.def.ads_fov_mult < MAGNIFIED_BELOW
	var amount := smoothstep(WeaponView.LENS_CLEAR_FROM, 0.95, ads) if magnified else 0.0
	visible = window.size != Vector2.ZERO and amount > 0.0
	if visible:
		var round := is_equal_approx(window.size.x, window.size.y)
		_material.set_shader_parameter("center", window.position)
		_material.set_shader_parameter("box", Vector2.ZERO if round else window.size)
		_material.set_shader_parameter("radius", window.size.x if round else 0.0)
		_material.set_shader_parameter("amount", amount)
