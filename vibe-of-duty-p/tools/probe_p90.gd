extends Node
## One-off: the p90 GLB's real nesting (who parents the can meshes).

func _ready() -> void:
	var model: Node = (load("res://assets/models/p90/p90.glb") as PackedScene).instantiate()
	add_child(model)
	_walk(model, 0)
	get_tree().quit()


func _walk(node: Node, depth: int) -> void:
	print("%s%s (%s)" % ["  ".repeat(depth), node.name, node.get_class()])
	for child in node.get_children():
		_walk(child, depth + 1)
