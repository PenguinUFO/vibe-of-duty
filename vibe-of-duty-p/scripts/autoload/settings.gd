extends Node
## Player-facing settings, persisted to user://settings.cfg.

const SAVE_PATH := "user://settings.cfg"
const BUS_NAMES: Array[StringName] = [&"Master", &"SFX", &"Music", &"UI"]
# Index = Settings.shadow_quality: off / medium / high.
const SHADOW_ATLAS_SIZES := [1024, 1024, 2048]
const SHADOW_MAX_DISTANCES := [0.0, 40.0, 70.0]

signal changed
signal graphics_changed  # shadow / AA / scale / vsync settings were applied

var mouse_sensitivity := 0.0025  # radians per pixel
var fov := 90.0
var player_name := "Player"
var volumes := {&"Master": 1.0, &"SFX": 1.0, &"Music": 0.7, &"UI": 1.0}  # linear 0..1

var antialiasing := 1    # 0 = off, 1 = FXAA
var shadow_quality := 2  # 0 = off, 1 = medium (1024 px, 40 m), 2 = high (2048 px, 70 m)
var render_scale := 1.0  # 3D resolution scale; below 1.0 uses FSR 1
var vsync := true


func _ready() -> void:
	load_settings()
	apply_audio()
	apply_graphics()


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


## Gives a level's directional light the shadow settings of the chosen quality.
func apply_sun(light: DirectionalLight3D) -> void:
	light.shadow_enabled = shadow_quality > 0
	if shadow_quality > 0:
		light.directional_shadow_max_distance = SHADOW_MAX_DISTANCES[shadow_quality]


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "antialiasing", antialiasing)
	cfg.set_value("video", "shadow_quality", shadow_quality)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("player", "name", player_name)
	for bus in BUS_NAMES:
		cfg.set_value("audio", String(bus), volumes[bus])
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	mouse_sensitivity = cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)
	fov = cfg.get_value("video", "fov", fov)
	antialiasing = clampi(cfg.get_value("video", "antialiasing", antialiasing), 0, 1)
	shadow_quality = clampi(cfg.get_value("video", "shadow_quality", shadow_quality), 0, 2)
	render_scale = clampf(cfg.get_value("video", "render_scale", render_scale), 0.5, 1.0)
	vsync = cfg.get_value("video", "vsync", vsync)
	player_name = cfg.get_value("player", "name", player_name)
	for bus in BUS_NAMES:
		volumes[bus] = cfg.get_value("audio", String(bus), volumes[bus])
