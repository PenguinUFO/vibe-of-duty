extends Node
## Runs tools/<name>.gd (a Node script: shot_level, shot, shot_fp, shot_sight, shot_model, shot_plan) as the main scene,
## so the autoloads (Settings, Game...) exist: under --script they don't and the game's scripts fail to compile.
##   Godot_v4.7.2.exe --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=shot_level
## Env vars of the tool (SHOT_MAP=...) work as before. --tool makes it a test launch: nothing is saved to the profile.


func _ready() -> void:
	var path := "res://tools/%s.gd" % Game.tool_run
	if Game.tool_run == "" or not ResourceLoader.exists(path):
		push_error("run_tool: pass -- --tool=name (tools/<name>.gd), got '%s'" % Game.tool_run)
		get_tree().quit(1)
		return
	await get_tree().process_frame  # the root is no longer busy: the tool may add its scene to it
	var tool: Node = load(path).new()
	add_child(tool)
