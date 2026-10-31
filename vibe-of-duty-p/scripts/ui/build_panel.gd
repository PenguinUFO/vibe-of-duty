class_name BuildPanel
extends PanelContainer
## Builds, opened by the main menu's "Сборка" (Docs/LOADOUT.md "Экран сборки"): the BUILD_COUNT saved builds, one tab
## each; the open one is also the one played (Settings.build_index). The whole screen: on the left the kits
## (weapons.cfg [kit.<id>]; the weapons stay under the hood), the "Модули" button and the weapon's bars (StatBars), in
## the middle the pig holding the build's weapon (BuildStage: it comes in on the weapon while the pointer or the
## gamepad's focus is on the left), on the right the organs (PartDB.INERT_SLOTS: saved, not played yet - but the
## "Инженер"). Every slot is a row of buttons, one per part, the pressed one in the build; no numbers and no
## descriptions (owner, 2026-10-31). "Модули" opens the module slots under it - only with the "Инженер" (else grey);
## a kit with changed modules reads "<name> кастом". Under the pointer (or focus) a kit or a module shows on the bars
## what it would change. Another kit resets the modules to its own; a part that would go over PartDB.BUDGET is
## refused, a module whose "requires" is not in the build is greyed out, a slot the build's parts "exclude" is locked
## at its default. Saved to user://builds.cfg on every change.

signal closed

const SCREEN_MARGIN := 16.0
const SIDE_WIDTH := 400.0   # the weapon column...
const BODY_WIDTH := 270.0   # ...and the organs'

var _tabs: Array[Button] = []
var _name_edit := LineEdit.new()
var _tokens := Label.new()
var _note := Label.new()
var _weapon_column := VBoxContainer.new()
var _weapon_side: Control   # the whole left side: the camera comes in on the weapon while the pointer is over it
var _body_column := VBoxContainer.new()
var _stats := StatBars.new()
var _stage := BuildStage.new()
var _rows := {}               # slot -> [its Label, its HFlowContainer of buttons]
var _rows_for := ""           # the weapon the module rows were made for
var _modules_button := Button.new()
var _modules_open := false    # the module slots shown (with the "Инженер")
var _hover_slot := ""         # the part under the pointer / focus: its slot and index, "" for none
var _hover_index := -1
var _pad := false             # the gamepad was used last (the camera follows the focus, not the pointer)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = SCREEN_MARGIN
	offset_top = SCREEN_MARGIN
	offset_right = -SCREEN_MARGIN
	offset_bottom = -SCREEN_MARGIN

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	var title := Label.new()
	title.text = "СБОРКА"
	title.theme_type_variation = "PanelTitle"
	title.custom_minimum_size.x = 160
	top.add_child(title)
	var group := ButtonGroup.new()
	for i in Settings.BUILD_COUNT:
		var tab := Button.new()
		tab.text = str(i + 1)
		tab.toggle_mode = true
		tab.button_group = group
		tab.custom_minimum_size.x = 48
		tab.pressed.connect(func() -> void:
			Audio.play("ui_click")
			_select(i))
		top.add_child(tab)
		_tabs.append(tab)
	_name_edit.max_length = 24
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(text: String) -> void:
		Settings.builds[Settings.build_index]["name"] = text
		Settings.save_builds())
	top.add_child(_name_edit)
	top.add_child(_tokens)

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 12)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(middle)
	var left := VBoxContainer.new()  # the weapon and its modules (scrolling), its bars always in sight under them
	left.custom_minimum_size.x = SIDE_WIDTH
	left.add_theme_constant_override("separation", 10)
	middle.add_child(left)
	_weapon_side = left
	var weapon_scroll := ScrollContainer.new()
	weapon_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	weapon_scroll.follow_focus = true
	left.add_child(weapon_scroll)
	left.add_child(_stats)
	_weapon_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_column.add_theme_constant_override("separation", 6)
	weapon_scroll.add_child(_weapon_column)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(_stage)
	var body_side := ScrollContainer.new()
	body_side.custom_minimum_size.x = BODY_WIDTH
	body_side.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_side.follow_focus = true
	middle.add_child(body_side)
	_body_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_column.add_theme_constant_override("separation", 6)
	body_side.add_child(_body_column)

	_add_row(_weapon_column, "kit")
	_modules_button.text = "Модули"
	_modules_button.toggle_mode = true
	_modules_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_modules_button.toggled.connect(func(on: bool) -> void:
		Audio.play("ui_click")
		_modules_open = on
		_refresh())
	_weapon_column.add_child(_modules_button)
	for slot: String in PartDB.WEAPON_SLOTS.slice(1):
		if not slot in PartDB.HIDDEN_SLOTS:
			_add_row(_weapon_column, slot)
	for slot: String in PartDB.BODY_SLOTS:
		if not slot in PartDB.HIDDEN_SLOTS:
			_add_row(_body_column, slot)

	var bottom := HBoxContainer.new()
	box.add_child(bottom)
	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size.x = 160
	back.pressed.connect(func() -> void:
		Audio.play("ui_click")
		closed.emit())
	bottom.add_child(back)
	_note.add_theme_color_override("font_color", UiTheme.DANGER)
	bottom.add_child(_note)
	_select(Settings.build_index)
	if Settings.has_gamepad():
		_tabs[Settings.build_index].grab_focus.call_deferred()


## A slot's title and its row of part buttons (made in _refresh: a module slot's depend on the weapon).
func _add_row(column: VBoxContainer, slot: String) -> void:
	var label := Label.new()
	label.text = PartDB.SLOT_NAMES[slot]
	label.theme_type_variation = "Hint"
	column.add_child(label)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	column.add_child(flow)
	_rows[slot] = [label, flow]


func _select(index: int) -> void:
	Settings.build_index = index
	Settings.save_builds()
	_tabs[index].button_pressed = true
	_name_edit.text = Settings.builds[index]["name"]
	_note.text = ""
	_refresh()


## The build with `slot`'s part number `index` in (another kit: its weapon with its modules).
func _with_part(slot: String, index: int) -> Array:
	var parts: Array = Settings.builds[Settings.build_index]["parts"].duplicate()
	var part: PartDef = PartDB.options(slot, parts[0])[index]
	if slot == "kit":
		var native := PartDB.default_build(part.id)
		for i in PartDB.WEAPON_SLOTS.size():
			parts[i] = native[i]
	parts[PartDB.SLOTS.find(slot)] = part.id
	return parts


func _on_part(slot: String, index: int) -> void:
	var parts := _with_part(slot, index)
	if PartDB.cost(parts) > PartDB.BUDGET:
		_note.text = "Не хватает токенов."
		_refresh()  # back to the part it had
		return
	_note.text = ""
	# Drops modules whose requirement just went (e.g. a magazine for another caliber); keeps the organs.
	Settings.builds[Settings.build_index]["parts"] = PartDB.sanitize(parts, true)
	Settings.save_builds()
	Audio.play("ui_click")
	_refresh()


func _hover(slot: String, index: int) -> void:
	if slot == _hover_slot and index == _hover_index:
		return
	_hover_slot = slot
	_hover_index = index
	_show_stats()


func _refresh() -> void:
	var parts: Array = Settings.builds[Settings.build_index]["parts"]
	var locked := {}  # slots a part of the build excludes
	for id in parts:
		var part := PartDB.get_part(str(id))
		if part != null and part.excludes != "":
			for slot in part.excludes.split(","):
				locked[slot] = true
	if _rows_for != parts[0]:
		_rows_for = parts[0]
		_hover_slot = ""
		for slot: String in _rows:
			_make_buttons(slot)
	var engineer: bool = parts.has(PartDB.ENGINEER)
	if not engineer:
		_modules_open = false
	_modules_button.set_pressed_no_signal(_modules_open)
	_modules_button.disabled = not engineer
	_modules_button.tooltip_text = "" if engineer else "Открывается с аугментацией «Инженер»"
	for slot: String in _rows:
		var options := PartDB.options(slot, parts[0])
		var label: Label = _rows[slot][0]
		var flow: HFlowContainer = _rows[slot][1]
		label.visible = options.size() > 1 and (not WeaponDB.MODULE_SLOTS.has(slot) or _modules_open)
		flow.visible = label.visible
		var i := 0
		for button: Button in flow.get_children():
			var part := options[i]
			button.set_pressed_no_signal(parts.has(part.id))
			button.disabled = (locked.has(slot) and i > 0) or (part.requires != "" and not parts.has(part.requires))
			if slot == "kit":
				button.text = PartDB.kit_name(parts) if button.button_pressed else part.display_name
			i += 1
	_tokens.text = "Токены: %d / %d" % [PartDB.cost(parts), PartDB.BUDGET]
	_stage.show_build(parts)
	_show_stats()


## `slot`'s buttons for the build's weapon (a slot with nothing to choose, one part or none, is hidden: _refresh).
func _make_buttons(slot: String) -> void:
	var label: Label = _rows[slot][0]
	var flow: HFlowContainer = _rows[slot][1]
	for child in flow.get_children():
		flow.remove_child(child)
		child.queue_free()
	var options := PartDB.options(slot, _rows_for)
	for i in options.size():
		var button := Button.new()
		button.toggle_mode = true
		button.text = options[i].display_name
		button.pressed.connect(func() -> void: _on_part(slot, i))
		button.mouse_entered.connect(_hover.bind(slot, i))
		button.focus_entered.connect(_hover.bind(slot, i))
		button.mouse_exited.connect(_hover.bind("", -1))
		button.focus_exited.connect(_hover.bind("", -1))
		flow.add_child(button)


## The weapon's bars, with the difference the kit or module under the pointer would make (an organ: none).
func _show_stats() -> void:
	var parts: Array = Settings.builds[Settings.build_index]["parts"]
	var current := _def_of(parts)
	var other: WeaponDef = null
	if _hover_slot == "kit" or PartDB.WEAPON_SLOTS.has(_hover_slot):
		var options := PartDB.options(_hover_slot, parts[0])
		if _hover_index < options.size():
			other = _def_of(PartDB.sanitize(_with_part(_hover_slot, _hover_index)))
	_stats.show_def(current, other)


static func _def_of(parts: Array) -> WeaponDef:
	return WeaponDB.make_def(WeaponDB.index_of(parts[0]), PartDB.weapon_modules(parts))


func _process(_delta: float) -> void:
	if _pad:
		var focus := get_viewport().gui_get_focus_owner()
		_stage.close = focus != null and _weapon_side.is_ancestor_of(focus)
	else:
		_stage.close = _weapon_side.get_global_rect().has_point(get_global_mouse_position())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_pad = false
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_pad = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Esc / B: back to the main menu
		get_viewport().set_input_as_handled()
		closed.emit()
