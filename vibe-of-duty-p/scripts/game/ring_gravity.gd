class_name RingGravity
extends Node3D
## Put in a ring station level: while it is in the tree, up (Gravity) points at the ring's axis, a line along Z
## through this node. `radius`: the rim floor's distance from the axis.

@export var radius := 30.0


func _enter_tree() -> void:
	Gravity.ring_radius = radius
	Gravity.ring_axis_y = position.y


func _exit_tree() -> void:
	Gravity.ring_radius = 0.0
	Gravity.ring_axis_y = 0.0
