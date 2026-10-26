extends Node
## Player-facing settings, persisted to user://settings.cfg.

const SAVE_PATH := "user://settings.cfg"
## Saved builds (Docs/LOADOUT.md): edited in BuildPanel, picked in BuildPicker. Their own file, so a broken build list
## never costs the player their settings.
const BUILDS_PATH := "user://builds.cfg"
const BUILD_COUNT := 5
## Funny nicknames, one per line: a player who never entered a name gets a random one (pick_nickname). A plain text
## file, so the export preset includes assets/data/*.txt.
const NICKNAMES_PATH := "res://assets/data/nicknames.txt"
## Shown in the window title and the main menu. Set at runtime rather than as application/config/name, which also
## names the user:// folder (renaming it would lose the saved settings).
const GAME_TITLE := "Press F to Хрючево"
## The game's font, for every text: menus and HUD take it from the project theme (project.godot gui/theme/custom_font);
## it is also made the engine's fallback font, which Label3D (name tags, damage numbers, signs) and anything else
## without a theme uses.
const GAME_FONT := UiTheme.GAME_FONT
const BUS_NAMES: Array[StringName] = [&"Master", &"SFX", &"Music", &"UI"]
# Index = Settings.shadow_quality: off / medium / high.
const SHADOW_ATLAS_SIZES := [1024, 2048, 4096]
const SHADOW_MAX_DISTANCES := [0.0, 40.0, 70.0]
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160),
]

signal changed
signal graphics_changed  # shadow / AA / scale / vsync settings were applied

var mouse_sensitivity := 0.0025  # radians per pixel
var stick_sensitivity := 1.0     # gamepad look speed multiplier (1 = Player.STICK_LOOK_SPEED)
var aim_assist := 1.0            # gamepad aim assist strength, 0 = off (AimAssist)
var fov := 90.0
var view_bob := 1.0              # first-person camera bob strength, 0 = off (Player._update_camera_fx)
var player_name := "Игрок"
## The name is the player's: loaded from settings.cfg, or used to start / join a game. Until then it is a random
## nickname, picked anew every launch and not saved.
var name_chosen := false
var server_address := "127.0.0.1"  # last address typed in the join panel
## Servers connected to successfully, newest first, unique by address: [{"address": String, "name": String}].
## The name is the player's own label for it (JoinPanel); empty until they type one.
var recent_servers: Array = []
const RECENT_SERVERS_MAX := 10
var kid_mode := false  # unlocked with a code (KidModeEntry); its parameters below, edited in KidPanel
var kid_health := 300            # max health (PlayerBase.MAX_HEALTH .. KID_HEALTH_MAX)
var kid_regen_delay := 2.0       # s after damage before health comes back (0 .. PlayerBase.REGEN_DELAY)
var kid_assist_mult := 2.0       # aim assist strength multiplier (AimAssist keeps the effect in sane bounds)
var kid_assist_reach := 2.0      # aim assist cone width multiplier
var kid_assist_unlimited := true # aim assist has no range limit (otherwise AimAssist.RANGE)
var kid_ads_pull := 4.0          # 1/s, ADS pull towards the target (AimAssist), 0 = off
var kid_back_damage := 0.5       # damage multiplier for shots from behind (Player.damage_mult_from), 1 = normal
const KID_DEFAULTS := {"kid_health": 300, "kid_regen_delay": 2.0, "kid_assist_mult": 2.0, "kid_assist_reach": 2.0,
		"kid_assist_unlimited": true, "kid_ads_pull": 4.0,
		"kid_back_damage": 0.5}
const KID_ASSIST_MULT_MAX := 3.0
const KID_ADS_PULL_MAX := 10.0
var volumes := {&"Master": 1.0, &"SFX": 1.0, &"Music": 0.7, &"UI": 1.0}  # linear 0..1
var builds: Array = []   # BUILD_COUNT x {"name": String, "parts": Array (PartDB ids, sanitized)}
var build_index := 0     # the build played (sent on join, changed with BuildPicker)

var antialiasing := 1    # 0 = off, 1 = FXAA
var shadow_quality := 2  # 0 = off, 1 = medium (2048 px, 40 m), 2 = high (4096 px, 70 m)
var render_scale := 1.0  # 3D resolution scale; below 1.0 uses FSR 1
var vsync := true
var psx_style := true    # PSX look: a darker mood (Mood) and the colour dither over the 3D frame (_psx_layer)
var fullscreen := false
var window_size := Vector2i(1280, 720)  # windowed resolution (one of WINDOW_SIZES)

# Last host settings (HostPanel).
var host_map := "res://prefabs/levels/train.tscn"
var host_score_limit := 20
var host_match_minutes := 10
var host_port := 27015
var host_random_weapons := false  # the FFA random weapon mode (Game.random_weapons)


var _psx_layer: CanvasLayer  # full-screen PSX post-process (assets/shaders/psx_post.gdshader), under every UI layer


func _ready() -> void:
	var font := load(GAME_FONT) as Font
	if font:
		ThemeDB.fallback_font = font
	ThemeDB.get_default_theme().merge_with(UiTheme.build())  # every control, CanvasLayers included, falls back to it
	load_settings()
	load_builds()
	if not name_chosen:
		player_name = pick_nickname()
	apply_audio()
	apply_graphics()
	apply_display()
	_bind_gamepad()


## A random nickname from NICKNAMES_PATH ("Игрок" if the list is missing).
func pick_nickname() -> String:
	var file := FileAccess.open(NICKNAMES_PATH, FileAccess.READ)
	if file == null:
		return "Игрок"
	var names: Array[String] = []
	for line in file.get_as_text().split("\n", false):
		if line.strip_edges() != "":
			names.append(line.strip_edges())
	return names.pick_random() if not names.is_empty() else "Игрок"


## Gamepad bindings (Xbox layout names; other pads map to the same positions). Added here rather than in the project's
## input map so the whole layout is readable in one place:
##   left stick move, right stick look, A jump, B crouch, Y or L3 sprint (latches until you stop), RT fire, LT aim,
##   X reload, R3 hoof punch (V on the keyboard), d-pad right next weapon, d-pad up oink (F on the keyboard), Back
##   scoreboard, Start pause menu. Menus: d-pad / left stick, A accept, B back.
func _bind_gamepad() -> void:
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "aim": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	}
	for action in axes:
		_ensure_action(action, 0.25 if action.begins_with("look") or action.begins_with("move") else 0.4)
		var event := InputEventJoypadMotion.new()
		event.axis = axes[action][0]
		event.axis_value = axes[action][1]
		InputMap.action_add_event(action, event)
	var buttons := {
		"jump": [JOY_BUTTON_A], "crouch": [JOY_BUTTON_B], "sprint_toggle": [JOY_BUTTON_Y, JOY_BUTTON_LEFT_STICK],
		"reload": [JOY_BUTTON_X], "weapon_next": [JOY_BUTTON_DPAD_RIGHT], "scoreboard": [JOY_BUTTON_BACK],
		"pause": [JOY_BUTTON_START], "oink": [JOY_BUTTON_DPAD_UP], "melee": [JOY_BUTTON_RIGHT_STICK],
	}
	for action in buttons:
		_ensure_action(action)
		for button in buttons[action]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
	# Menus: A accepts, B goes back (Godot's ui_accept / ui_cancel come without gamepad buttons). The pause menu opens
	# on its own action (Esc / Start), because B is crouch in game.
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var ui_event := InputEventJoypadButton.new()
		ui_event.button_index = pair[1]
		InputMap.action_add_event(pair[0], ui_event)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", escape)
	var oink_key := InputEventKey.new()  # Press F to Хрючево: the player oinks, everyone nearby hears it
	oink_key.physical_keycode = KEY_F
	InputMap.action_add_event("oink", oink_key)
	var melee_key := InputEventKey.new()  # hoof punch, as melee in Call of Duty
	melee_key.physical_keycode = KEY_V
	InputMap.action_add_event("melee", melee_key)


func _ensure_action(action: String, deadzone: float = 0.5) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	else:
		InputMap.action_set_deadzone(action, deadzone)


## Debug (F3): how often the game lost the OS focus. (With input_devices/joypads/ignore_joypad_on_unfocused_application
## the engine drops all gamepad input while unfocused; that setting is off, the pad froze with it.)
var focus_losses := 0
var last_focus_loss := 0.0  # seconds the last loss lasted
var _focus_lost_at := -1.0


func _notification(what: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()  # settings changed since the last Back press survive closing the window
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focus_losses += 1
		_focus_lost_at = now
		print("[focus] lost at %.2f s" % now)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and _focus_lost_at >= 0.0:
		last_focus_loss = now - _focus_lost_at
		_focus_lost_at = -1.0
		print("[focus] back at %.2f s, after %.2f s" % [now, last_focus_loss])


func focus_debug() -> String:
	var state := "yes" if _focus_lost_at < 0.0 else "NO (%.1f s)" % (Time.get_ticks_msec() / 1000.0 - _focus_lost_at)
	return "focus %s  lost %dx  last %.2f s" % [state, focus_losses, last_focus_loss]


## After a successful connection: moves `address` to the top of recent_servers (keeping its name) and saves.
func remember_server(address: String) -> void:
	var label := ""
	for i in range(recent_servers.size() - 1, -1, -1):
		if recent_servers[i]["address"] == address:
			label = recent_servers[i]["name"]
			recent_servers.remove_at(i)
	recent_servers.push_front({"address": address, "name": label})
	recent_servers.resize(mini(recent_servers.size(), RECENT_SERVERS_MAX))
	save_settings()


func rename_server(address: String, label: String) -> void:
	for entry in recent_servers:
		if entry["address"] == address:
			entry["name"] = label.strip_edges().left(32)
	save_settings()


func forget_server(address: String) -> void:
	recent_servers = recent_servers.filter(func(entry: Dictionary) -> bool: return entry["address"] != address)
	save_settings()


## True when a gamepad is connected (menus then put the focus on a button, so the d-pad can navigate).
func has_gamepad() -> bool:
	return not Input.get_connected_joypads().is_empty()


## Aim assist strength actually used: kid mode multiplies it (AimAssist keeps the resulting effect in sane bounds).
func effective_aim_assist() -> float:
	return aim_assist * (kid_assist_mult if kid_mode else 1.0)


## Aim assist cone width multiplier.
func aim_assist_reach() -> float:
	return kid_assist_reach if kid_mode else 1.0


## How far aim assist reaches (m): kid mode may have no limit, anyone in sight is assisted.
func aim_assist_range() -> float:
	return INF if kid_mode and kid_assist_unlimited else AimAssist.RANGE


## ADS pull towards the target, 1/s: kid mode only, scaled by the aim assist setting.
func aim_assist_pull() -> float:
	return kid_ads_pull * aim_assist if kid_mode else 0.0


## The player's max health, regeneration delay and damage multiplier from behind, as sent to the server (NetWorld;
## it clamps them).
func toughness() -> Vector3:
	if kid_mode:
		return Vector3(kid_health, kid_regen_delay, kid_back_damage)
	return Vector3(PlayerBase.MAX_HEALTH, PlayerBase.REGEN_DELAY, 1.0)


func reset_kid() -> void:
	for key in KID_DEFAULTS:
		set(key, KID_DEFAULTS[key])


func set_volume(bus: StringName, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	apply_audio()
	changed.emit()


func apply_audio() -> void:
	for bus in BUS_NAMES:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(volumes.get(bus, 1.0)))


## Applies the global graphics settings; levels re-fit their sun through graphics_changed.
func apply_graphics() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_tree().root
	window.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if antialiasing == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	window.scaling_3d_scale = render_scale
	window.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	_update_psx_layer()
	# Adaptive: synced while the game keeps up, and a frame that misses the refresh is shown at once (a brief tear)
	# instead of waiting for the next one - plain vsync drops to 30 FPS whenever 60 is not quite reached.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE if vsync else DisplayServer.VSYNC_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS_SIZES[shadow_quality], true)
	graphics_changed.emit()


## The PSX dither over the 3D frame: a full-screen rect on a CanvasLayer below the menus and the HUD (layer -1), so
## it reads the frame before any UI is drawn. Full resolution - only the colours are stepped and dithered.
func _update_psx_layer() -> void:
	if _psx_layer == null:
		_psx_layer = CanvasLayer.new()
		_psx_layer.layer = -1
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/shaders/psx_post.gdshader")
		rect.material = material
		_psx_layer.add_child(rect)
		add_child(_psx_layer)
	_psx_layer.visible = psx_style


## Fullscreen (borderless, at the desktop resolution) or a window of window_size, centered on its screen.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_title(GAME_TITLE)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
	var screen := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(area.position + (area.size - window_size) / 2)


## Gives a level's directional light the shadow settings of the chosen quality. Always 4 cascades: with 2 (the levels'
## own setting) the far one is coarse, and 20-50 m off the low sun's shadow edges went to steps and light leaked under
## roofs and along walls (owner's screenshots, the train, the plane, the tower; no cost measured on shot_level).
func apply_sun(light: DirectionalLight3D) -> void:
	light.shadow_enabled = shadow_quality > 0
	if shadow_quality > 0:
		light.directional_shadow_max_distance = SHADOW_MAX_DISTANCES[shadow_quality]
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


## The build to play: the picked saved one; in test launches --build=... or the native build (tests never depend on
## the player's saved builds).
func current_build() -> Array:
	if Game.is_test_launch():
		return PartDB.sanitize(Game.test_build)
	return builds[build_index]["parts"]


func load_builds() -> void:
	builds.clear()
	for i in BUILD_COUNT:
		builds.append({"name": "Сборка %d" % (i + 1), "parts": PartDB.default_build()})
	var cfg := ConfigFile.new()
	if cfg.load(BUILDS_PATH) != OK:
		return
	for i in BUILD_COUNT:
		var section := "build_%d" % i
		builds[i]["name"] = str(cfg.get_value(section, "name", builds[i]["name"])).left(24)
		builds[i]["parts"] = PartDB.sanitize(cfg.get_value(section, "parts", []))
	build_index = clampi(int(cfg.get_value("builds", "index", 0)), 0, BUILD_COUNT - 1)


func save_builds() -> void:
	if Game.is_test_launch():
		return  # as save_settings: test runs never write the player's profile
	var cfg := ConfigFile.new()
	cfg.set_value("builds", "index", build_index)
	for i in BUILD_COUNT:
		cfg.set_value("build_%d" % i, "name", builds[i]["name"])
		cfg.set_value("build_%d" % i, "parts", builds[i]["parts"])
	cfg.save(BUILDS_PATH)


func save_settings() -> void:
	if Game.is_test_launch():
		return  # automated test runs (bots, --join, --training, servers) share the player's profile: never write it
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "stick_sensitivity", stick_sensitivity)
	cfg.set_value("input", "aim_assist", aim_assist)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "view_bob", view_bob)
	cfg.set_value("video", "antialiasing", antialiasing)
	cfg.set_value("video", "shadow_quality", shadow_quality)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "psx_style", psx_style)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "window_size", window_size)
	if name_chosen:
		cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "server_address", server_address)
	cfg.set_value("player", "recent_servers", recent_servers)
	cfg.set_value("player", "kid_mode", kid_mode)
	for key in KID_DEFAULTS:
		cfg.set_value("kid", key, get(key))
	cfg.set_value("host", "map", host_map)
	cfg.set_value("host", "score_limit", host_score_limit)
	cfg.set_value("host", "match_minutes", host_match_minutes)
	cfg.set_value("host", "port", host_port)
	cfg.set_value("host", "random_weapons", host_random_weapons)
	for bus in BUS_NAMES:
		cfg.set_value("audio", String(bus), volumes[bus])
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	mouse_sensitivity = cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)
	stick_sensitivity = clampf(cfg.get_value("input", "stick_sensitivity", stick_sensitivity), 0.2, 3.0)
	aim_assist = clampf(cfg.get_value("input", "aim_assist", aim_assist), 0.0, 1.0)
	fov = cfg.get_value("video", "fov", fov)
	view_bob = clampf(cfg.get_value("video", "view_bob", view_bob), 0.0, 1.0)
	antialiasing = clampi(cfg.get_value("video", "antialiasing", antialiasing), 0, 1)
	shadow_quality = clampi(cfg.get_value("video", "shadow_quality", shadow_quality), 0, 2)
	render_scale = clampf(cfg.get_value("video", "render_scale", render_scale), 0.5, 1.0)
	vsync = cfg.get_value("video", "vsync", vsync)
	psx_style = cfg.get_value("video", "psx_style", psx_style)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	var saved_size = cfg.get_value("video", "window_size", window_size)
	if saved_size is Vector2i and WINDOW_SIZES.has(saved_size):
		window_size = saved_size
	var saved_name := str(cfg.get_value("player", "name", "")).strip_edges()
	if saved_name != "":
		player_name = saved_name
		name_chosen = true
	server_address = cfg.get_value("player", "server_address", server_address)
	recent_servers = []
	var saved_servers = cfg.get_value("player", "recent_servers", [])
	if saved_servers is Array:
		for entry in saved_servers:
			if entry is Dictionary and entry.get("address") is String and entry.get("name", "") is String \
					and recent_servers.size() < RECENT_SERVERS_MAX:
				recent_servers.append({"address": entry["address"], "name": entry.get("name", "")})
	kid_mode = cfg.get_value("player", "kid_mode", kid_mode)
	kid_health = clampi(cfg.get_value("kid", "kid_health", kid_health), PlayerBase.MAX_HEALTH, PlayerBase.KID_HEALTH_MAX)
	kid_regen_delay = clampf(cfg.get_value("kid", "kid_regen_delay", kid_regen_delay), 0.0, PlayerBase.REGEN_DELAY)
	kid_assist_mult = clampf(cfg.get_value("kid", "kid_assist_mult", kid_assist_mult), 1.0, KID_ASSIST_MULT_MAX)
	kid_assist_reach = clampf(cfg.get_value("kid", "kid_assist_reach", kid_assist_reach), 1.0, KID_ASSIST_MULT_MAX)
	kid_assist_unlimited = cfg.get_value("kid", "kid_assist_unlimited", kid_assist_unlimited)
	kid_ads_pull = clampf(cfg.get_value("kid", "kid_ads_pull", kid_ads_pull), 0.0, KID_ADS_PULL_MAX)
	kid_back_damage = clampf(cfg.get_value("kid", "kid_back_damage", kid_back_damage), 0.0, 1.0)
	host_map = cfg.get_value("host", "map", host_map)
	host_score_limit = clampi(cfg.get_value("host", "score_limit", host_score_limit), 1, 100)
	host_match_minutes = clampi(cfg.get_value("host", "match_minutes", host_match_minutes), 1, 60)
	host_port = clampi(cfg.get_value("host", "port", host_port), 1024, 65535)
	host_random_weapons = bool(cfg.get_value("host", "random_weapons", host_random_weapons))
	for bus in BUS_NAMES:
		volumes[bus] = cfg.get_value("audio", String(bus), volumes[bus])
