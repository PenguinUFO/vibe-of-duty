class_name LobbyMenu
extends Control
## The lobby screen (prefabs/ui/lobby.tscn; the state is the Lobby autoload's). Waiting for the host: the map and the
## rules, the host's "Начать". After a match: the ballot (a button per map with its votes, the own vote lit) and the
## clock; the host can start before it runs out. Always: the players, "Сборка" (BuildPanel; not in the FFA random
## weapon mode) and "Покинуть". A dedicated server loads the scene too, but shows nothing.

var _box: VBoxContainer
var _panel: PanelContainer
var _status: Label
var _ballot: HBoxContainer
var _players: VBoxContainer
var _start: Button
var _sub: BuildPanel  # the open build editor, or null
var _focused := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Lobby.entered()
	if Game.dedicated:
		return
	Audio.play_music_id("menu")
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UiTheme.BG
	add_child(bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(620, 0)
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)

	var title := Label.new()
	title.text = "ЛОББИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "PanelTitle"
	_box.add_child(title)
	var rules := Label.new()
	rules.text = "До %d убийств · %d мин%s" % [Game.score_limit, roundi(Game.match_time / 60.0),
			" · FFA рандомное оружие" if Game.random_weapons else ""]
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.theme_type_variation = "Hint"
	_box.add_child(rules)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.theme_type_variation = "Heading"
	_box.add_child(_status)
	_ballot = HBoxContainer.new()
	_ballot.add_theme_constant_override("separation", 10)
	_box.add_child(_ballot)

	var heading := Label.new()
	heading.text = "Игроки"
	heading.theme_type_variation = "Heading"
	_box.add_child(heading)
	_players = VBoxContainer.new()
	_players.add_theme_constant_override("separation", 4)
	_box.add_child(_players)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	_box.add_child(buttons)
	_add_button(buttons, "Покинуть", Net.leave)  # Net.disconnected -> back to the main menu
	if not Game.random_weapons:  # FFA random weapon: the server picks every life's weapon
		_add_button(buttons, "Сборка", _open_builds)
	if Lobby.is_host():
		_start = _add_button(buttons, "Начать", Lobby.server_start)

	Net.disconnected.connect(_on_disconnected)
	Lobby.changed.connect(_refresh)
	_refresh()
	UiTheme.pop_in(_panel)


func _process(_delta: float) -> void:
	if _status != null and Lobby.phase == Lobby.Phase.VOTING:
		_status.text = "Голосование за карту: %d с" % ceili(Lobby.time_left)


func _refresh() -> void:
	if _box == null:
		return
	var voting := Lobby.phase == Lobby.Phase.VOTING
	if not voting:
		_status.text = "Карта: %s" % Game.map_name(Game.map_scene)
	if _start != null:
		_start.text = "Начать сейчас" if voting else "Начать"
	_build_ballot(voting)
	_build_players()
	if not _focused and Settings.has_gamepad() and _sub == null:
		_focused = true
		var first: Control = _ballot.get_child(0) if _ballot.get_child_count() > 0 else _start
		if first != null:
			first.grab_focus.call_deferred()


## A button per ballot entry: the map's name and its votes; this machine's vote is pressed.
func _build_ballot(voting: bool) -> void:
	_ballot.visible = voting
	var counts := Lobby.vote_counts()
	var mine := Lobby.my_vote()
	var focus_index := -1
	for i in _ballot.get_child_count():
		if _ballot.get_child(i).has_focus():
			focus_index = i
	for child in _ballot.get_children():
		_ballot.remove_child(child)
		child.queue_free()
	if not voting:
		return
	for i in Lobby.options.size():
		var path := Lobby.options[i]
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = i == mine
		button.text = "%s\n%s" % ["Случайная" if path == Lobby.RANDOM else Game.map_name(path), _votes_text(counts[i])]
		button.custom_minimum_size = Vector2(0, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			Audio.play("ui_click")
			Lobby.vote(i))
		_ballot.add_child(button)
		if i == focus_index:
			button.grab_focus.call_deferred()


static func _votes_text(n: int) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return "%d голос" % n
	if n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14]:
		return "%d голоса" % n
	return "%d голосов" % n


## The players by peer id (the host first); this machine's own line in the highlight colour.
func _build_players() -> void:
	for child in _players.get_children():
		_players.remove_child(child)
		child.queue_free()
	var ids := Lobby.roster.keys()
	ids.sort()
	var me := multiplayer.get_unique_id()
	for id in ids:
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # a nickname
		label.text = "%s%s" % [Lobby.roster[id], "  · хост" if id == 1 else ""]
		if id == me:
			label.add_theme_color_override("font_color", UiTheme.HIGHLIGHT)
		_players.add_child(label)
	var count := Label.new()
	count.text = "%d / %d" % [ids.size(), Net.MAX_PLAYERS]
	count.theme_type_variation = "Hint"
	_players.add_child(count)


func _add_button(parent: Container, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		Audio.play("ui_click")
		action.call())
	parent.add_child(button)
	return button


func _open_builds() -> void:
	_panel.visible = false
	_sub = BuildPanel.new()
	_sub.closed.connect(_close_builds)
	add_child(_sub)
	UiTheme.pop_in(_sub)


## The build edited here is the one played from the map's first spawn (NetWorld sends Settings.current_build()).
func _close_builds() -> void:
	if _sub == null:
		return
	_sub.queue_free()
	_sub = null
	_panel.visible = true
	_focused = false
	_refresh()


func _on_disconnected() -> void:
	get_tree().change_scene_to_file(Game.MENU_SCENE)
