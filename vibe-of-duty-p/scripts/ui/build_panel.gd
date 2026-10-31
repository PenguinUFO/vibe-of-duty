class_name BuildPanel
extends PanelContainer
## Builds, opened by the main menu's "Сборка" (Docs/LOADOUT.md): the BUILD_COUNT saved builds, one tab each; the open
## one is also the one played (Settings.build_index). Columns: the weapon and its modules (weapons.cfg), the body (hidden
## while PartDB.HIDDEN_SLOTS hides all of it), the weapon's picture (WeaponPreview, redrawn on every change). Each list
## slot lists its parts (a module slot: the build weapon's; another weapon resets them to its base ones) with their
## token price; a part that would go over PartDB.BUDGET is refused, a module whose "requires" is not in the build is
## greyed out (and falls back to the default when its requirement goes). The card slots (PartDB.CARD_SLOTS: the
## suppressor, a conversion, the stock, the big magazine) are cards, not lists (owner, 2026-10-23, as Black Ops 2's):
## pressed, the slot's "on" module is in; pressed again, out; a weapon without one hides it. A slot with more modules
## shows a card for each but the first, one row, and one at a time is in (the sight: CompM or ACOG, owner 2026-10-27);
## pressing another swaps it. A slot the build's parts
## "exclude" is locked at its default. Under the weapon - its numbers with this build. Saved to user://builds.cfg on
## every change.

signal closed

const SCREEN_MARGIN := 16.0  # px kept free above and below the panel (the base screen is 720 px tall)

var _tabs: Array[Button] = []
var _name_edit := LineEdit.new()
var _pickers := {}            # slot -> OptionButton (all but the card's)
var _cards := {}              # card slot (PartDB.CARD_SLOTS) -> [its Label, its row of Buttons: one per 'on' module]
var _tokens := Label.new()
var _stats := Label.new()
var _scroll := ScrollContainer.new()  # the slots, numbers and picture: scrolls when they are taller than the screen
var _info := Label.new()
var _note := Label.new()
var _preview := WeaponPreview.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(1100, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "СБОРКА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "PanelTitle"
	box.add_child(title)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	var group := ButtonGroup.new()
	for i in Settings.BUILD_COUNT:
		var tab := Button.new()
		tab.text = str(i + 1)
		tab.toggle_mode = true
		tab.button_group = group
		tab.custom_minimum_size.x = 56
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

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true  # gamepad: the focused picker scrolls into view
	box.add_child(_scroll)
	_scroll.add_child(columns)
	columns.minimum_size_changed.connect(_fit_height, CONNECT_DEFERRED)
	for slots in [PartDB.WEAPON_SLOTS, PartDB.BODY_SLOTS]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		column.add_child(grid)
		for slot: String in slots:
			if slot in PartDB.HIDDEN_SLOTS:
				continue
			var label := Label.new()
			label.text = PartDB.SLOT_NAMES[slot]
			grid.add_child(label)
			if slot in PartDB.CARD_SLOTS:
				var row := HBoxContainer.new()  # its cards: _refresh (as many as the build weapon has)
				row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_theme_constant_override("separation", 6)
				grid.add_child(row)
				_cards[slot] = [label, row]
				continue
			var picker := OptionButton.new()  # its items: _refresh (module slots list the build weapon's)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			picker.item_selected.connect(func(index: int) -> void: _on_part(slot, index))
			grid.add_child(picker)
			_pickers[slot] = picker
		column.visible = slots.any(func(slot: String) -> bool: return not slot in PartDB.HIDDEN_SLOTS)  # the body, hidden
		if slots == PartDB.WEAPON_SLOTS:
			_stats.theme_type_variation = "Hint"
			_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(_stats)
		else:
			_info.theme_type_variation = "Hint"
			_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(_info)

	_preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	columns.add_child(_preview)

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


## The scroll as tall as the slots and numbers, but no taller than the screen leaves for it; the panel shrinks back too.
func _fit_height() -> void:
	if not is_inside_tree():
		return
	var columns := _scroll.get_child(0) as Control
	var rest := get_combined_minimum_size().y - _scroll.custom_minimum_size.y  # title, tabs, note, Back, margins
	var room := get_viewport_rect().size.y - 2.0 * SCREEN_MARGIN - rest
	_scroll.custom_minimum_size.y = minf(columns.get_combined_minimum_size().y, room)
	reset_size()
	position.y = (get_viewport_rect().size.y - size.y) / 2.0  # reset_size keeps the top: centre again


func _select(index: int) -> void:
	Settings.build_index = index
	Settings.save_builds()
	_tabs[index].button_pressed = true
	_name_edit.text = Settings.builds[index]["name"]
	_note.text = ""
	_refresh()


func _on_part(slot: String, index: int) -> void:
	var parts: Array = Settings.builds[Settings.build_index]["parts"].duplicate()
	var part: PartDef = PartDB.options(slot, parts[0])[index]
	if slot == "weapon" and part.id != parts[0]:
		var native := PartDB.default_build(part.id)  # another weapon: its modules start from the base ones
		for i in PartDB.WEAPON_SLOTS.size():
			parts[i] = native[i]
	parts[PartDB.SLOTS.find(slot)] = part.id
	var fixed := PartDB.sanitize(parts)  # drops modules whose requirement just went (e.g. a magazine for another caliber)
	if PartDB.cost(parts) > PartDB.BUDGET:
		_note.text = "Не хватает токенов."
		_refresh()  # back to the part it had
		return
	_note.text = ""
	Settings.builds[Settings.build_index]["parts"] = fixed
	Settings.save_builds()
	Audio.play("ui_click")
	_refresh()


func _refresh() -> void:
	var parts: Array = Settings.builds[Settings.build_index]["parts"]
	var lines: PackedStringArray = []
	var locked := {}  # slots a part of the build excludes
	for id in parts:
		var part := PartDB.get_part(str(id))
		if part != null and part.excludes != "":
			for slot in part.excludes.split(","):
				locked[slot] = true
	for slot: String in _cards:
		var label: Label = _cards[slot][0]
		var row: HBoxContainer = _cards[slot][1]
		var card_options := PartDB.options(slot, parts[0])
		label.visible = card_options.size() > 1  # a weapon without this card hides its row
		row.visible = label.visible
		while row.get_child_count() < card_options.size() - 1:
			_add_card(row, slot, row.get_child_count() + 1)
		for i in row.get_child_count():
			var card: Button = row.get_child(i)
			card.visible = i + 1 < card_options.size()
			if not card.visible:
				continue
			var on: PartDef = card_options[i + 1]
			card.set_pressed_no_signal(parts.has(on.id))
			card.disabled = locked.has(slot)  # another card excludes it (the Хрюгер: the snail)
			card.text = "%s %s  (%d)" % ["●" if card.button_pressed else "○", on.display_name, PartDB.price(on)]
			card.tooltip_text = on.info
	for i in PartDB.SLOTS.size():
		var slot := PartDB.SLOTS[i]
		if slot in PartDB.CARD_SLOTS or slot in PartDB.HIDDEN_SLOTS:
			continue
		var picker: OptionButton = _pickers[slot]
		var options := PartDB.options(slot, parts[0])
		picker.clear()
		for part in options:
			picker.add_item("%s  (%d)" % [part.display_name, PartDB.price(part)])
		if options.is_empty():
			picker.add_item("—")  # this weapon has no modules for the slot
		picker.disabled = options.size() < 2 or locked.has(slot)
		for j in options.size():
			picker.set_item_disabled(j, options[j].requires != "" and not parts.has(options[j].requires))
			if options[j].id == parts[i]:
				picker.select(j)
				if options[j].cost > 0 and PartDB.BODY_SLOTS.has(slot):
					lines.append("%s — %s" % [options[j].display_name, options[j].info])
	_tokens.text = "Токены: %d / %d" % [PartDB.cost(parts), PartDB.BUDGET]
	_info.text = "\n".join(lines) if not lines.is_empty() else "Родная туша: без органов и имплантов."
	_stats.text = _weapon_stats(parts)
	_preview.show_build(parts)  # lists the card's words too, when it is on (a module with a price)


## The card for `slot`'s module number `index` (its "on" one when it is the only card): pressed, that module is in
## (whichever of the slot's was); pressed again, the slot's default.
func _add_card(row: HBoxContainer, slot: String, index: int) -> void:
	var card := Button.new()
	card.toggle_mode = true
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 40
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.clip_text = true
	card.toggled.connect(func(on: bool) -> void: _on_part(slot, index if on else 0))
	row.add_child(card)


## "450", or "450→600 за 1.0 с" for a ramping rate.
func _fire_rate_text(def: WeaponDef) -> String:
	var text := "%.0f" % (60.0 / def.fire_interval)
	if def.fire_ramp_time > 0.0 and def.fire_interval_ramped > 0.0:
		text += "→%.0f за %.1f с" % [60.0 / def.fire_interval_ramped, def.fire_ramp_time]
	return text


## The weapon's numbers with this build: its modules and the organs that touch it.
func _weapon_stats(parts: Array) -> String:
	var def := WeaponDB.make_def(WeaponDB.index_of(parts[0]), PartDB.weapon_modules(parts))
	var mods := PartDB.mods(parts)
	var falloff: PackedStringArray = []
	for i in mini(def.falloff_ranges.size(), def.falloff_mults.size()):
		falloff.append("%.0f с %.0f м" % [def.damage * def.falloff_mults[i], def.falloff_ranges[i]])
	var lines: PackedStringArray = [
		def.info,
		"Урон %.0f%s%s%s%s" % [def.damage, " × %d дробин" % def.pellets if def.pellets > 1 else "",
				(", " + ", ".join(falloff)) if not falloff.is_empty() else "",
				" · в голову как в тело" if def.head_mult <= 1.0 else "",
				" · раненый не лечится %.0f с" % def.regen_block if def.regen_block > 0.0 else ""],
		"Темп %s выстр/мин · магазин %d · запас %d" % [_fire_rate_text(def), def.mag_size, def.reserve_start],
		"Перезарядка %.2f с · прицеливание %.2f с · зум ×%.1f" % [def.reload_time * mods["reload_mult"],
				def.ads_time * mods["ads_time_mult"], 1.0 / def.ads_fov_mult],
		"Скорость ×%.2f, в прицеле ×%.2f · смена %.2f с" % [def.move_speed_mult,
				def.move_speed_mult * def.ads_move_mult, def.equip_time],
		"Отдача %.2f° · разброс %.1f° / %.2f°" % [rad_to_deg(def.recoil_pitch),
				rad_to_deg(def.spread_hip) * mods["spread_hip_mult"], rad_to_deg(def.spread_ads) * mods["spread_ads_mult"]],
		"Пробитие %.2f м (урон ×%.1f)%s%s" % [def.penetration, def.penetration_damage,
				"" if def.muzzle_flash else " · без вспышки", " · бронебойный" if def.armor_piercing else ""],
	]
	for i in range(1, PartDB.WEAPON_SLOTS.size()):
		var part := PartDB.get_part(parts[i])
		if part != null and part.cost > 0:
			lines.append("%s — %s" % [part.display_name, part.info])
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Esc / B: back to the main menu
		get_viewport().set_input_as_handled()
		closed.emit()
