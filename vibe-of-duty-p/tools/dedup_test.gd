extends Node

func _ready() -> void:
	var scene: PackedScene = load("res://tools/dedup_test.glb")
	var model := scene.instantiate()
	add_child(model)
	for child in model.get_children():
		print("%s: %s" % [child.name, ", ".join(c.name for c in child.get_children())])
	get_tree().quit()
