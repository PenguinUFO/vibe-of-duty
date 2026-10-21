class_name ShotEffects
extends RefCounted
## Cosmetic one-shot effects (tracers, impacts). Nothing here affects gameplay or the simulation.

const TRACER_LIFETIME := 0.07
const IMPACT_LIFETIME := 0.12

static var _tracer_material: StandardMaterial3D
static var _impact_material: StandardMaterial3D


static func spawn_tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	if _tracer_material == null:
		_tracer_material = _emissive(Color(1.0, 0.78, 0.5))  # Palette.EMBER, lightened: a streak of light
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, length)
	mesh.material = _tracer_material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	var mid := (from + to) * 0.5
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT
	node.global_transform = Transform3D(Basis.IDENTITY, mid).looking_at(to, up)
	node.global_position = mid
	_free_after(node, TRACER_LIFETIME)


static func spawn_impact(parent: Node, pos: Vector3, normal: Vector3) -> void:
	if _impact_material == null:
		_impact_material = _emissive(Color(1.0, 0.8, 0.4))
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	mesh.material = _impact_material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.global_position = pos + normal * 0.02
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ZERO, IMPACT_LIFETIME)
	tween.tween_callback(node.queue_free)


static func _emissive(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


static func _free_after(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds).timeout.connect(node.queue_free)
