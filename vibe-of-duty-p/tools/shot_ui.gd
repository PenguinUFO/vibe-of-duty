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
		if panel is BuildPanel:  # every kit, then the ACR with the "Свинжинер": modules open, one focused, camera close;
			# then the AUG and the M16A1 with them
			var kits := PartDB.options("kit", "")
			for i in kits.size():
				panel._on_part("kit", i)
				for f in 30:
					await get_tree().process_frame
				_report("build_" + kits[i].id.trim_prefix("kit."), panel, dir)
			panel._kits.show_popup()  # the open list, the pointer on a kit: its difference on the bars
			panel._kits.get_popup().set_focused_item(4)
			for f in 30:
				await get_tree().process_frame
			_report("build_kit_list", panel, dir)
			panel._kits.get_popup().index_pressed.emit(4)  # picked from the list, as a click does
			panel._kits.get_popup().hide()
			print("picked: ", PartDB.kit_name(Settings.builds[Settings.build_index]["parts"]))
			panel._on_part("kit", kits.find(PartDB.get_part("kit.acr")))
			panel._on_part("head", PartDB.options("head", "").find(PartDB.get_part(PartDB.ENGINEER)))
			panel._modules_button.button_pressed = true
			panel._on_part("sight", 1)  # CompM instead of the kit's irons: "кастом"
			panel._pad = true
			(panel._rows["mag"][1] as Control).get_child(1).grab_focus()  # the big magazine: focused, its difference shown
			for f in 60:
				await get_tree().process_frame
			_report("build_engineer", panel, dir)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.aug")))  # the AUG's barrel and grip rows
			panel._pad = false
			for f in 60:
				await get_tree().process_frame
			_report("build_engineer_aug", panel, dir)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.m16")))  # the M16's barrel, can, stock, sight
			for f in 60:
				await get_tree().process_frame
			_report("build_engineer_m16", panel, dir)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.groza")))  # the Groza's can, grip, magazine, sight
			for f in 60:
				await get_tree().process_frame
			_report("build_engineer_groza", panel, dir)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.val")))  # the Val's barrel, stock, magazine, sight
			for f in 60:
				await get_tree().process_frame
			_report("build_engineer_val", panel, dir)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.p90")))  # the P90's one row: the can
			for f in 60:
				await get_tree().process_frame
			_report("build_engineer_p90", panel, dir)
			panel._on_part("hands", 0)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.mp7")))  # akimbo: grey without the "Руки-Хрюки"...
			var akimbo_on := (panel._rows["akimbo"][1] as Control).get_child(1) as Button
			for f in 30:
				await get_tree().process_frame
			print("akimbo grey: ", akimbo_on.disabled, " tip: ", akimbo_on.tooltip_text)
			_report("build_mp7_no_arms", panel, dir)
			panel._on_part("hands", PartDB.options("hands", "").find(PartDB.get_part(PartDB.PIG_ARMS)))
			panel._on_part("akimbo", 1)  # ...with them: the stock folded and locked, the sights at the irons
			for f in 60:
				await get_tree().process_frame
			print("akimbo: ", Settings.builds[Settings.build_index]["parts"].slice(0, 12))
			_report("build_mp7_akimbo", panel, dir)
			panel._on_part("hands", 0)  # the arms off: the module goes, the stock stays
			print("arms off: ", Settings.builds[Settings.build_index]["parts"].slice(0, 12))
			# The head's list: open, then the pointer on an item - and on the closed list: their tooltips.
			var head: OptionButton = panel._augments["head"]
			head.show_popup()
			await get_tree().process_frame
			await get_tree().process_frame
			var list := head.get_popup()
			await _point(Vector2(list.position) + Vector2(40.0, list.size.y - 24.0))
			_report("build_augment_tip", panel, dir)
			list.hide()
			await _point(head.get_global_rect().get_center())
			_report("build_augment_closed_tip", panel, dir)
		holder.queue_free()
		await get_tree().process_frame
	get_tree().quit()


## The pointer moved to `at` (the window's pixels) and left there until a tooltip comes up.
func _point(at: Vector2) -> void:
	for nudge: Vector2 in [Vector2(-2.0, 0.0), Vector2.ZERO]:
		var motion := InputEventMouseMotion.new()
		motion.position = at + nudge
		motion.global_position = at + nudge
		get_tree().root.push_input(motion)
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout


func _report(id: String, panel: Control, dir: String) -> void:
	var fits := panel.position.y >= 0.0 and panel.position.y + panel.size.y <= 720.0
	print("%-16s %d x %d at %d,%d%s" % [id, panel.size.x, panel.size.y, panel.position.x, panel.position.y,
			"" if fits else "  DOES NOT FIT"])
	get_tree().root.get_texture().get_image().save_png(dir.path_join("ui_%s.png" % id))
