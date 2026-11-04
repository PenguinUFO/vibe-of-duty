class_name ViewmodelSpace
extends Node3D
## Child of the camera, parent of the first-person gun and arms: gives them a field of view of their own, whatever the
## camera's (Settings.fov, a scope's zoom), for the price of a scale. Sideways and up stretched by the ratio of the two
## views' tangents, depth left alone: on the screen that is the same as drawing them with `view_fov` - with no second
## camera or viewport. Everything inside poses in this space as if the camera had `view_fov`; a global position of a
## part (a muzzle) is where it shows on the screen, against the world.

var blur := ScopeBlur.new()  # not stretched: it draws in screen space


func _init() -> void:
	add_child(blur)


func fit(camera_fov: float, view_fov: float) -> void:
	var stretch := tan(deg_to_rad(camera_fov) * 0.5) / tan(deg_to_rad(view_fov) * 0.5)
	scale = Vector3(stretch, stretch, 1.0)
