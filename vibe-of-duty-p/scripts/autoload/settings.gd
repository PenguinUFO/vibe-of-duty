extends Node
## Player-facing settings, persisted to user://settings.cfg.

const SAVE_PATH := "user://settings.cfg"
const BUS_NAMES: Array[StringName] = [&"Master", &"SFX", &"Music", &"UI"]

signal changed

var mouse_sensitivity := 0.0025  # radians per pixel
var fov := 90.0
var player_name := "Player"
var volumes := {&"Master": 1.0, &"SFX": 1.0, &"Music": 0.7, &"UI": 1.0}  # linear 0..1


func _ready() -> void:
	load_settings()
	apply_audio()


func set_volume(bus: StringName, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	apply_audio()
	changed.emit()


func apply_audio() -> void:
	for bus in BUS_NAMES:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(volumes.get(bus, 1.0)))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "fov", fov)
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
	player_name = cfg.get_value("player", "name", player_name)
	for bus in BUS_NAMES:
		volumes[bus] = cfg.get_value("audio", String(bus), volumes[bus])
