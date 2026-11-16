extends Node
## Prints a weapon model's node tree, its metadata (a GLB's "travel"), the meshes' boxes and the build's slots with
## their parts: checks that Godot has what WeaponView animates and what the editor offers.
##   Godot_v4.7.2.exe --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=dump_model
## SHOT_WEAPON=<index> picks the weapon (default 14, the Desert Eagle).


func _ready() -> void:
	var index := int(OS.get_environment("SHOT_WEAPON")) if OS.has_environment("SHOT_WEAPON") else 14
	var def := WeaponDB.get_def(index)
	print("%s  %s  scale %s" % [def.id, def.scene_path, def.model_scale])
	var model: Node = (load(def.scene_path) as PackedScene).instantiate()
	add_child(model)
	_dump(model, 0)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		print("  mesh %-14s %s" % [node.name, (node as MeshInstance3D).get_aabb()])
	var bolt := model.get_node_or_null("Bolt")
	print("bolt: %s  travel %s" % [bolt, bolt.get_meta("extras", {}) if bolt else "-"])
	print("hammer: %s  trigger: %s" % [model.get_node_or_null("Hammer"), model.get_node_or_null("Trigger")])
	print("mags: %s" % [model.find_children("*_Mag_*", "Node3D", true, false)])
	for slot in PartDB.WEAPON_SLOTS.slice(1):
		var ids := []
		for part in PartDB.options(slot, def.id):
			ids.append("%s (%s)" % [part.id, part.display_name])
		if not ids.is_empty():
			print("  slot %-9s %s" % [slot, ", ".join(ids)])
	get_tree().quit()


func _dump(node: Node, depth: int) -> void:
	print("%s%s (%s) pos %s rot %s" % ["  ".repeat(depth), node.name, node.get_class(), node.position, node.rotation])
	for child in node.get_children():
		_dump(child, depth + 1)
