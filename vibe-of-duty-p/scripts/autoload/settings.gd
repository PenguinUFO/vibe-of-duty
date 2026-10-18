extends Node
## Player-facing settings, persisted to user://settings.cfg.

const SAVE_PATH := "user://settings.cfg"
const BUS_NAMES: Array[StringName] = [&"Master", &"SFX", &"Music", &"UI"]
# Index = Settings.shadow_quality: off / medium / high.
const SHADOW_ATLAS_SIZES := [1024, 1024, 2048]
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
var player_name := "Player"
var server_address := "127.0.0.1"  # last address typed in the main menu
var kid_mode := false  # unlocked with a code in the main menu; more health, stronger and wider aim assist
var volumes := {&"Master": 1.0, &"SFX": 1.0, &"Music": 0.7, &"UI": 1.0}  # linear 0..1

var antialiasing := 1    # 0 = off, 1 = FXAA
var shadow_quality := 2  # 0 = off, 1 = medium (1024 px, 40 m), 2 = high (2048 px, 70 m)
var render_scale := 1.0  # 3D resolution scale; below 1.0 uses FSR 1
var vsync := true
var fullscreen := false
var window_size := Vector2i(1280, 720)  # windowed resolution (one of WINDOW_SIZES)

# Last host settings (HostPanel).
var host_map := "res://prefabs/levels/train.tscn"
var host_score_limit := 20
var host_match_minutes := 10
var host_port := 27015


func _ready() -> void:
	load_settings()
	apply_audio()
	apply_graphics()
	apply_display()
	_bind_gamepad()


## Gamepad bindings (Xbox layout names; other pads map to the same positions). Added here rather than in the project's
## input map so the whole layout is readable in one place:
##   left stick move, right stick look, A jump, B crouch, Y or L3 sprint (latches until you stop), RT fire, LT aim,
##   X reload, d-pad right next weapon, Back scoreboard, Start pause menu. Menus: d-pad / left stick, A accept, B back.
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
		"pause": [JOY_BUTTON_START],
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


## True when a gamepad is connected (menus then put the focus on a button, so the d-pad can navigate).
func has_gamepad() -> bool:
	return not Input.get_connected_joypads().is_empty()


## Aim assist strength actually used: kid mode doubles it (AimAssist keeps the resulting effect in sane bounds).
func effective_aim_assist() -> float:
	return aim_assist * (2.0 if kid_mode else 1.0)


## Aim assist range and cone width multiplier: kid mode reaches twice as far and works twice as wide.
func aim_assist_reach() -> float:
	return 2.0 if kid_mode else 1.0


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
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS_SIZES[shadow_quality], true)
	graphics_changed.emit()


## Fullscreen (borderless, at the desktop resolution) or a window of window_size, centered on its screen.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
	var screen := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(area.position + (area.size - window_size) / 2)


## Gives a level's directional light the shadow settings of the chosen quality.
func apply_sun(light: DirectionalLight3D) -> void:
	light.shadow_enabled = shadow_quality > 0
	if shadow_quality > 0:
		light.directional_shadow_max_distance = SHADOW_MAX_DISTANCES[shadow_quality]


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "stick_sensitivity", stick_sensitivity)
	cfg.set_value("input", "aim_assist", aim_assist)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "antialiasing", antialiasing)
	cfg.set_value("video", "shadow_quality", shadow_quality)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "window_size", window_size)
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "server_address", server_address)
	cfg.set_value("player", "kid_mode", kid_mode)
	cfg.set_value("host", "map", host_map)
	cfg.set_value("host", "score_limit", host_score_limit)
	cfg.set_value("host", "match_minutes", host_match_minutes)
	cfg.set_value("host", "port", host_port)
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
	antialiasing = clampi(cfg.get_value("video", "antialiasing", antialiasing), 0, 1)
	shadow_quality = clampi(cfg.get_value("video", "shadow_quality", shadow_quality), 0, 2)
	render_scale = clampf(cfg.get_value("video", "render_scale", render_scale), 0.5, 1.0)
	vsync = cfg.get_value("video", "vsync", vsync)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	var saved_size = cfg.get_value("video", "window_size", window_size)
	if saved_size is Vector2i and WINDOW_SIZES.has(saved_size):
		window_size = saved_size
	player_name = cfg.get_value("player", "name", player_name)
	server_address = cfg.get_value("player", "server_address", server_address)
	kid_mode = cfg.get_value("player", "kid_mode", kid_mode)
	host_map = cfg.get_value("host", "map", host_map)
	host_score_limit = clampi(cfg.get_value("host", "score_limit", host_score_limit), 1, 100)
	host_match_minutes = clampi(cfg.get_value("host", "match_minutes", host_match_minutes), 1, 60)
	host_port = clampi(cfg.get_value("host", "port", host_port), 1024, 65535)
	for bus in BUS_NAMES:
		volumes[bus] = cfg.get_value("audio", String(bus), volumes[bus])
