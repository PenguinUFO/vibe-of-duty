class_name BuildPanel
extends PanelContainer
## Builds, opened by the main menu's "Сборка" (Docs/LOADOUT.md): the BUILD_COUNT saved builds, one tab each; the open
## one is also the one played (Settings.build_index). For every body slot a list of parts with their token price;
## a part that would go over PartDB.BUDGET is refused. Saved to user://builds.cfg on every change.

signal closed

var _tabs: Array[Button] = []
var _name_edit := LineEdit.new()
var _pickers := {}            # slot -> OptionButton
var _tokens := Label.new()
var _info := Label.new()
var _note := Label.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(640, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "СБОРКА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "PanelTitle"
	box.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	var group := ButtonGroup.new()
	for i in Settings.BUILD_COUNT:
		var tab := Button.new()
		tab.text = str(i + 1)
		tab.toggle_mode = true
		tab.button_group = group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func() -> void:
			Audio.play("ui_click")
			_select(i))
		tabs.add_child(tab)
		_tabs.append(tab)

	_name_edit.max_length = 24
	_name_edit.text_changed.connect(func(text: String) -> void:
		Settings.builds[Settings.build_index]["name"] = text
		Settings.save_builds())
	box.add_child(_name_edit)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	box.add_child(grid)
	for slot in PartDB.SLOTS:
		var label := Label.new()
		label.text = PartDB.SLOT_NAMES[slot]
		grid.add_child(label)
		var picker := OptionButton.new()
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for part in PartDB.for_slot(slot):
			picker.add_item("%s  (%d)" % [part.display_name, part.cost])
		picker.disabled = picker.item_count < 2  # the weapon: only the AK for now
		picker.item_selected.connect(func(index: int) -> void: _on_part(slot, index))
		grid.add_child(picker)
		_pickers[slot] = picker

	box.add_child(_tokens)
	_info.theme_type_variation = "Hint"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	_note.add_theme_color_override("font_color", UiTheme.DANGER)
	box.add_child(_note)

	var back := Button.new()
	back.text = "Назад"
	back.pressed.connect(func() -> void:
		Audio.play("ui_click")
		closed.emit())
	box.add_child(back)
	_select(Settings.build_index)
	if Settings.has_gamepad():
		_tabs[Settings.build_index].grab_focus.call_deferred()


func _select(index: int) -> void:
	Settings.build_index = index
	Settings.save_builds()
	_tabs[index].button_pressed = true
	_name_edit.text = Settings.builds[index]["name"]
	_note.text = ""
	_refresh()


func _on_part(slot: String, index: int) -> void:
	var parts: Array = Settings.builds[Settings.build_index]["parts"].duplicate()
	var slot_index := PartDB.SLOTS.find(slot)
	parts[slot_index] = PartDB.for_slot(slot)[index].id
	if PartDB.cost(parts) > PartDB.BUDGET:
		_note.text = "Не хватает токенов."
		_refresh()  # back to the part it had
		return
	_note.text = ""
	Settings.builds[Settings.build_index]["parts"] = parts
	Settings.save_builds()
	Audio.play("ui_click")
	_refresh()


func _refresh() -> void:
	var parts: Array = Settings.builds[Settings.build_index]["parts"]
	var lines: PackedStringArray = []
	for i in PartDB.SLOTS.size():
		var slot := PartDB.SLOTS[i]
		var options := PartDB.for_slot(slot)
		for j in options.size():
			if options[j].id == parts[i]:
				(_pickers[slot] as OptionButton).select(j)
				if options[j].cost > 0:
					lines.append("%s — %s" % [options[j].display_name, options[j].info])
	_tokens.text = "Токены: %d / %d" % [PartDB.cost(parts), PartDB.BUDGET]
	_info.text = "\n".join(lines) if not lines.is_empty() else "Родная туша: без органов и имплантов."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Esc / B: back to the main menu
		get_viewport().set_input_as_handled()
		closed.emit()
