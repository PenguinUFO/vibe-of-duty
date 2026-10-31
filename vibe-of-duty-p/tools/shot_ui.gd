extends Node
## Renders the menu panels at the base 1280x720 (canvas_items stretch: every window lays them out at this size) to
## ../shots/ui_<panel>.png and prints each panel's size - a panel taller than 720 does not fit. SHOT_PANEL=build: one.
## Godot_v4.7.2.exe --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=shot_ui

var panels := {"settings": SettingsPanel, "build": BuildPanel, "kid": KidPanel}


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var only := OS.get_environment("SHOT_PANEL")
	for id: String in panels:
		if only != "" and id != only:
			continue
		var holder := Control.new()  # as the menus hold them: a full-screen control
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		get_tree().root.add_child(holder)
		var panel: Control = panels[id].new()
		holder.add_child(panel)
		for i in 4:
			await get_tree().process_frame
		_report(id, panel, dir)
		if panel is BuildPanel:  # every weapon: the stats and slots differ (a test launch: builds are not saved)
			var parts: Array = Settings.builds[Settings.build_index]["parts"]
			for i in PartDB.options("weapon", parts[0]).size():
				panel._on_part("weapon", i)
				for f in 3:
					await get_tree().process_frame
				_report("build_" + str(Settings.builds[Settings.build_index]["parts"][0]), panel, dir)
			var options := PartDB.options("weapon", parts[0])
			panel._on_part("weapon", options.find(PartDB.get_part("acr")))  # the tallest: every card on
			for slot: String in PartDB.CARD_SLOTS:
				if PartDB.options(slot, "acr").size() > 1:
					panel._on_part(slot, 1)
			for f in 3:
				await get_tree().process_frame
			_report("build_acr_all", panel, dir)
		holder.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _report(id: String, panel: Control, dir: String) -> void:
	var fits := panel.position.y >= 0.0 and panel.position.y + panel.size.y <= 720.0
	print("%-16s %d x %d at %d,%d%s" % [id, panel.size.x, panel.size.y, panel.position.x, panel.position.y,
			"" if fits else "  DOES NOT FIT"])
	get_tree().root.get_texture().get_image().save_png(dir.path_join("ui_%s.png" % id))
