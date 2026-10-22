class_name BuildPicker
extends CanvasLayer
## In a match: while the local player is dead (over the kill cam) or between matches, a line at the bottom shows the
## build of the next life; keys 1-5 or d-pad left / right pick another saved one (Settings.builds). The server gets it
## at once (NetWorld.send_build) and applies it at the respawn. Editing builds is the main menu's (BuildPanel).
## Created by NetWorld; not on a dedicated server.

var world: NetWorld

var _plate := PanelContainer.new()
var _label := Label.new()


func _ready() -> void:
	layer = 7  # over the kill cam (6)
	_plate.theme_type_variation = "HudPlate"
	_plate.anchor_left = 0.5
	_plate.anchor_right = 0.5
	_plate.anchor_top = 0.8
	_plate.anchor_bottom = 0.8
	_plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # the build's name is the player's
	_plate.add_child(_label)
	_plate.visible = false


func _process(_delta: float) -> void:
	_plate.visible = _shown()
	if _plate.visible:
		var build: Dictionary = Settings.builds[Settings.build_index]
		var names: PackedStringArray = []
		for id in build["parts"]:
			var part := PartDB.get_part(id)
			if part != null and part.cost > 0:
				names.append(part.display_name)
		_label.text = "Сборка %d/%d: %s   [%s]   1–5 / ◀ ▶ — сменить" % [Settings.build_index + 1,
				Settings.BUILD_COUNT, build["name"], ", ".join(names) if not names.is_empty() else "родная туша"]


func _shown() -> bool:
	if world == null or Game.is_test_launch() or get_tree().paused:
		return false
	var me: Player = world.players.get(multiplayer.get_unique_id())
	return me != null and (not me.alive or Game.is_frozen())


func _unhandled_input(event: InputEvent) -> void:
	if not _shown():
		return
	var index := -1
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key >= KEY_1 and key < KEY_1 + Settings.BUILD_COUNT:
			index = key - KEY_1
	elif event is InputEventJoypadButton and event.pressed:
		var button := (event as InputEventJoypadButton).button_index
		if button == JOY_BUTTON_DPAD_LEFT:
			index = posmod(Settings.build_index - 1, Settings.BUILD_COUNT)
		elif button == JOY_BUTTON_DPAD_RIGHT:
			index = posmod(Settings.build_index + 1, Settings.BUILD_COUNT)
	if index < 0 or index == Settings.build_index:
		return
	get_viewport().set_input_as_handled()
	Settings.build_index = index
	Settings.save_builds()
	Audio.play("ui_click")
	world.send_build(Settings.current_build())
