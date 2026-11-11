extends Node
## Renders the menu panels at the base 1280x720 (canvas_items stretch: every window lays them out at this size) to
## ../shots/ui_<panel>.png and prints each panel's size - a panel taller than 720 does not fit. SHOT_PANEL=build: one.
## SHOT_HOST_MODE=2: the host panel with this game mode chosen (Game.Mode; not saved).
## SHOT_PANEL=lobby (only when asked): the host's lobby after a team match - a vote, 8 players in two teams. Opens a
## server on port 27555 for the time of the shot (the lobby's host is a server).
## Godot_v4.7.2.exe --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=shot_ui

var panels := {"settings": SettingsPanel, "build": BuildPanel, "kid": KidPanel, "host": HostPanel}


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var only := OS.get_environment("SHOT_PANEL")
	if OS.has_environment("SHOT_HOST_MODE"):
		Settings.host_mode = int(OS.get_environment("SHOT_HOST_MODE"))
	if only == "lobby":
		await _lobby(dir)
		get_tree().quit()
		return
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
		if panel is BuildPanel:  # every kit, then the ACR: modules open, one focused, camera close; then the AUG and
			# the M16A1 with them
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
			panel._modules_button.button_pressed = true
			panel._on_part("sight", 1)  # CompM instead of the kit's irons: "кастом"
			panel._pad = true
			(panel._rows["mag"][1] as Control).get_child(1).grab_focus()  # the big magazine: focused, its difference shown
			for f in 60:
				await get_tree().process_frame
			_report("build_mods", panel, dir)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.aug")))  # the AUG's barrel and grip rows
			panel._pad = false
			for f in 60:
				await get_tree().process_frame
			_report("build_mods_aug", panel, dir)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.m16")))  # the M16's barrel, can, stock, sight
			for f in 60:
				await get_tree().process_frame
			_report("build_mods_m16", panel, dir)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.groza")))  # the Groza's can, grip, magazine, sight
			for f in 60:
				await get_tree().process_frame
			_report("build_mods_groza", panel, dir)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.val")))  # the Val's barrel, stock, magazine, sight
			for f in 60:
				await get_tree().process_frame
			_report("build_mods_val", panel, dir)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.p90")))  # the P90's one row: the can
			for f in 60:
				await get_tree().process_frame
			_report("build_mods_p90", panel, dir)
			panel._on_part("kit", kits.find(PartDB.get_part("kit.mp7")))
			panel._on_part("akimbo", 1)  # akimbo: the stock folded and locked, the sights at the irons
			for f in 60:
				await get_tree().process_frame
			print("akimbo: ", Settings.builds[Settings.build_index]["parts"].slice(0, 12))
			_report("build_mp7_akimbo", panel, dir)
		holder.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _lobby(dir: String) -> void:
	Net.host(27555)
	Game.set_mode(Game.Mode.TEAM_DEATHMATCH)
	Game.score_limit = Game.TEAM_SCORE_LIMIT
	Lobby.phase = Lobby.Phase.VOTING
	Lobby.time_left = Lobby.VOTE_TIME
	Lobby.options = Lobby._ballot()
	Lobby.roster = {1: Settings.player_name}
	for i in 7:
		Lobby.roster[100 + i] = Settings.pick_nickname()
	var menu: LobbyMenu = load(Lobby.SCENE).instantiate()
	get_tree().root.add_child(menu)
	for i in 8:
		await get_tree().process_frame
	for id in [102, 103, 104, 105, 106]:
		Net._bot_peers[id] = true  # as BotLauncher's bots
	Lobby.teams.clear()
	Lobby._broadcast()
	for i in 8:
		await get_tree().process_frame
	_report("lobby", menu._panel, dir)
	print("teams dealt: ", Lobby.teams)
	Lobby.server_move(101)
	for i in 8:
		await get_tree().process_frame
	print("teams after moving 101: ", Lobby.teams)  # the server closes with the process (Net.leave would open the menu)


func _report(id: String, panel: Control, dir: String) -> void:
	var fits := panel.position.y >= 0.0 and panel.position.y + panel.size.y <= 720.0
	print("%-16s %d x %d at %d,%d%s" % [id, panel.size.x, panel.size.y, panel.position.x, panel.position.y,
			"" if fits else "  DOES NOT FIT"])
	get_tree().root.get_texture().get_image().save_png(dir.path_join("ui_%s.png" % id))
