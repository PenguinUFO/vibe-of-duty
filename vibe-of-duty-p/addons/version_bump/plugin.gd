@tool
extends EditorPlugin
## Build version: the export carries application/config/version as it is, and once the export is done its patch
## number goes up by one ("0.1.1" -> "0.1.2") and project.godot is saved, so every build gets its own number. The
## main menu shows it with application/config/version_tag ("v0.1.1-alpha"). The two are kept apart because the
## Windows export writes the version into the .exe properties, which take digits and periods only (a "-alpha" there
## gives "Invalid version number" and 1.0.0.0). Major / minor / the tag are changed by hand in Project Settings.
##
## The exported files are named after the version too: the preset writes "vibe-of-duty-p.exe" / ".pck", which become
## "vibe-of-duty-0.1.1.exe" / ".pck" (the trailing "p" gives way to the version; the .exe finds its .pck by its own
## name, so both are renamed together).

var _export: BumpOnExport


func _enter_tree() -> void:
	_export = BumpOnExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	BumpOnExport.rename_now()  # command line export (--export-release): the editor quits before any timer fires
	remove_export_plugin(_export)
	_export = null


class BumpOnExport extends EditorExportPlugin:
	const RENAME_RETRY := 0.5  # s between attempts
	const RENAME_TRIES := 240  # give up after 2 minutes

	## The export waiting to be renamed: {from, to} (absolute paths without extension).
	static var _pending := {}

	var _path := ""

	func _get_name() -> String:
		return "VersionBump"

	## "1.2.3" -> "1.2.4"; a version that is not three numbers is left alone (empty string returned).
	static func bumped(version: String) -> String:
		var parts := version.split(".")
		if parts.size() != 3:
			return ""
		for part in parts:
			if not part.is_valid_int():
				return ""
		parts[2] = str(parts[2].to_int() + 1)
		return ".".join(parts)

	func _export_begin(_features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
		_path = path

	func _export_end() -> void:
		var version := str(ProjectSettings.get_setting("application/config/version", ""))
		var next := bumped(version)
		if next == "":
			push_warning("Version Bump: application/config/version \"%s\" is not MAJOR.MINOR.PATCH" % version)
			return
		_name_after(version)
		ProjectSettings.set_setting("application/config/version", next)
		ProjectSettings.save()
		print("Version Bump: exported %s, next build is %s" % [version, next])

	## _export_end runs before the export has written the .pck, so the files are renamed later, once they are complete:
	## Windows refuses to rename a file that is still open, and a failed attempt is simply tried again.
	func _name_after(version: String) -> void:
		if _path.get_extension().to_lower() != "exe":
			return  # "Export PCK/ZIP" keeps the name it was given
		var from := _path.get_basename()
		if from.is_relative_path():  # the preset's path is relative to the project folder
			from = ProjectSettings.globalize_path("res://").path_join(from).simplify_path()
		_pending = {"from": from, "to": from.trim_suffix("p") + version}
		_retry.call(RENAME_TRIES)

	static func _retry(tries_left: int) -> void:
		if rename_now() or tries_left <= 0:
			if not _pending.is_empty():
				push_warning("Version Bump: could not rename %s.* to %s.*" % [_pending["from"], _pending["to"]])
				_pending = {}
			return
		var tree := Engine.get_main_loop() as SceneTree
		tree.create_timer(RENAME_RETRY).timeout.connect(_retry.bind(tries_left - 1))

	## Renames the pending build once its .exe and .pck both exist; a debug export's console wrapper (<name>.console.exe,
	## which starts <name>.exe) goes along if there is one. Stops at the first file still open and goes on from there
	## next time. Returns true when nothing is left to rename.
	static func rename_now() -> bool:
		if _pending.is_empty():
			return true
		var from: String = _pending["from"]
		var to: String = _pending["to"]
		if not FileAccess.file_exists(to + ".pck") and not FileAccess.file_exists(from + ".pck"):
			return false
		if not FileAccess.file_exists(to + ".exe") and not FileAccess.file_exists(from + ".exe"):
			return false
		for ext in [".pck", ".console.exe", ".exe"]:  # the .exe last: the export writes it first
			if not FileAccess.file_exists(from + ext):
				continue  # already renamed, or no console wrapper
			if FileAccess.file_exists(to + ext):
				DirAccess.remove_absolute(to + ext)  # the same version exported again
			if DirAccess.rename_absolute(from + ext, to + ext) != OK:
				return false
		print("Version Bump: build saved as %s.exe" % to)
		_pending = {}
		return true
