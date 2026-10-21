class_name GameHud
extends CanvasLayer
## Match-level HUD (not part of the player): match clock, own score, kill feed, scoreboard (hold Tab
## or between matches) and the end-of-match banner. Lives under NetWorld; not created on a
## dedicated server.

const FEED_MAX := 6
const FEED_TIME := 6.0
const BOARD_REFRESH := 0.25

var world: NetWorld

var _top: PanelContainer  # plate with the clock and the own score
var _timer_label: Label
var _score_label: Label
var _feed: VBoxContainer
var _board_panel: PanelContainer
var _board_grid: GridContainer
var _banner: Label
var _board_timer := 0.0


func _ready() -> void:
	layer = 5
	_top = PanelContainer.new()
	_top.theme_type_variation = "HudPlate"
	_top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_top.offset_top = 10.0
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 0)
	_top.add_child(top_box)
	_timer_label = _make_label(30)
	_timer_label.add_theme_font_override("font", UiTheme.heavy_font())
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_box.add_child(_timer_label)
	_score_label = _make_label(14)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	top_box.add_child(_score_label)

	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.offset_right = -16.0
	_feed.offset_top = 16.0
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.add_theme_constant_override("separation", 4)
	add_child(_feed)

	_banner = _make_label(40)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 110.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	add_child(_banner)

	_board_panel = PanelContainer.new()
	_board_panel.set_anchors_preset(Control.PRESET_CENTER)
	_board_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_board_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.PANEL, 0.8)
	style.set_content_margin_all(18.0)
	style.set_corner_radius_all(6)
	_board_panel.add_theme_stylebox_override("panel", style)
	_board_grid = GridContainer.new()
	_board_grid.columns = 5
	_board_grid.add_theme_constant_override("h_separation", 48)
	_board_grid.add_theme_constant_override("v_separation", 6)
	_board_panel.add_child(_board_grid)
	_board_panel.visible = false
	add_child(_board_panel)
	refresh()


func _process(delta: float) -> void:
	# Clients count the clock down locally between the server's once-a-second corrections.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		if Game.state == Game.State.PLAYING:
			Game.time_left = maxf(Game.time_left - delta, 0.0)
		elif Game.state == Game.State.ENDED:
			Game.intermission_left = maxf(Game.intermission_left - delta, 0.0)
	_update_labels()
	var show_board := Input.is_action_pressed("scoreboard") or Game.state == Game.State.ENDED
	_board_panel.visible = show_board
	if show_board:
		_board_timer -= delta
		if _board_timer <= 0.0:
			_board_timer = BOARD_REFRESH
			_rebuild_board()


## Called when scores or the match state changed.
func refresh() -> void:
	if _timer_label == null:
		return
	_update_labels()
	_rebuild_board()


## One kill feed line on a plate: killer, weapon, a headshot mark, victim (or "victim погиб" for a suicide). Lines about
## the local player get the accent plate and their names highlighted.
func add_kill(killer: String, victim: String, weapon: String, headshot: bool, involves_me: bool) -> void:
	var entry := PanelContainer.new()
	entry.theme_type_variation = "FeedEntryMine" if involves_me else "FeedEntry"
	entry.size_flags_horizontal = Control.SIZE_SHRINK_END
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	entry.add_child(row)
	var name_color := UiTheme.HIGHLIGHT if involves_me else UiTheme.TEXT
	if killer == "":
		row.add_child(_feed_label(victim, name_color))
		row.add_child(_feed_label("погиб", UiTheme.TEXT_DIM, 13))
	else:
		row.add_child(_feed_label(killer, name_color))
		row.add_child(_feed_label(weapon, UiTheme.TEXT_DIM, 13))
		if headshot:
			row.add_child(HeadshotMark.new())
		row.add_child(_feed_label(victim, name_color))
	_feed.add_child(entry)
	entry.modulate.a = 0.0
	entry.create_tween().tween_property(entry, "modulate:a", 1.0, 0.15)
	while _feed.get_child_count() > FEED_MAX:
		var oldest := _feed.get_child(0)
		_feed.remove_child(oldest)
		oldest.queue_free()
	var fade := entry.create_tween()
	fade.tween_interval(FEED_TIME)
	fade.tween_property(entry, "modulate:a", 0.0, 0.4)
	fade.tween_callback(entry.queue_free)


func _feed_label(text: String, color: Color, font_size := 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiTheme.bold_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func clear_feed() -> void:
	for child in _feed.get_children():
		child.queue_free()


func _update_labels() -> void:
	var ended := Game.state == Game.State.ENDED
	var seconds := ceili(Game.time_left)
	_timer_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	var mine: Dictionary = Game.scores.get(multiplayer.get_unique_id(), {"kills": 0, "deaths": 0})
	_score_label.text = "УБИЙСТВА %d / %d    СМЕРТИ %d" % [mine["kills"], Game.score_limit, mine["deaths"]]
	_top.visible = not Game.training  # training: no match to count down or score
	# The last half minute in red (the label's own colour is near white, so the tint gives the red).
	_timer_label.self_modulate = UiTheme.DANGER if Game.state == Game.State.PLAYING and Game.time_left <= 30.0 else Color.WHITE
	_banner.visible = ended
	if ended:
		var names: PackedStringArray = []
		for id in Game.winners:
			names.append(_player_name(id))
		_banner.text = "МАТЧ ОКОНЧЕН\n%s %s\nСледующий матч через %d" % [", ".join(names) if not names.is_empty() else "Никто не",
				"побеждает" if names.size() <= 1 else "побеждают", ceili(Game.intermission_left)]


func _rebuild_board() -> void:
	if _board_grid == null or not _board_panel.visible:
		return
	for child in _board_grid.get_children():
		_board_grid.remove_child(child)
		child.queue_free()
	for header in ["Игрок", "Очки", "Убийства", "Смерти", "К/Д"]:
		var h := _make_label(20)
		h.text = header
		h.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		_board_grid.add_child(h)
	var rows: Array = []
	for id in world.players:
		var entry: Dictionary = Game.scores.get(id, {"kills": 0, "deaths": 0})
		rows.append({"id": id, "name": (world.players[id] as Player).player_name, "kills": entry["kills"], "deaths": entry["deaths"],
				"score": Game.score_of(entry), "kd": Game.kd_of(entry)})
	rows.sort_custom(Game.ranks_above)
	var me := multiplayer.get_unique_id()
	for row in rows:
		for text in [row["name"], str(row["score"]), str(row["kills"]), str(row["deaths"]), "%.2f" % row["kd"]]:
			var cell := _make_label(20)
			cell.text = text
			if row["id"] == me:
				cell.add_theme_color_override("font_color", UiTheme.HIGHLIGHT)
			_board_grid.add_child(cell)


func _player_name(id: int) -> String:
	return (world.players[id] as Player).player_name if world.players.has(id) else "Игрок"


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.theme_type_variation = "HudLabel"
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
