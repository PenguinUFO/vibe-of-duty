extends Node
## One-off: replicate WeaponView's variant freeing and report what survives.

func _ready() -> void:
	for mods in [["groza.suppressor.on"], ["groza.grip.on"], ["groza.sight.po", "groza.suppressor.on"]]:
		var def := WeaponDB.make_def(11, mods)
		var model: Node = (load("res://assets/models/groza/groza.glb") as PackedScene).instantiate()
		add_child(model)
		for group: String in def.model_variants:
			var holder := model.get_node_or_null(group)
			for child in holder.get_children():
				if child.name != str(def.model_variants[group]):
					child.free()
		var muzzle := model.get_node_or_null("Muzzle")
		var names: Array[String] = []
		for child in muzzle.get_children():
			names.append("%s(%d)" % [child.name, child.get_child_count()])
		print("%s -> Muzzle: %s" % [mods, names])
		model.queue_free()
	get_tree().quit()
