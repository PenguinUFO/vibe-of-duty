@tool
extends EditorPlugin
## Build version: the export carries application/config/version as it is (the main menu shows it), and once the
## export is done the patch number goes up by one ("0.1.1-alpha" -> "0.1.2-alpha") and project.godot is saved, so
## every build gets its own number. Major / minor / the "-alpha" suffix are changed by hand in Project Settings.

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = BumpOnExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class BumpOnExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "VersionBump"

	## "1.2.3-tag" -> "1.2.4-tag"; a version without three numbers is left alone (empty string returned).
	static func bumped(version: String) -> String:
		var dash := version.find("-")
		var numbers := version if dash < 0 else version.left(dash)
		var suffix := "" if dash < 0 else version.substr(dash)
		var parts := numbers.split(".")
		if parts.size() != 3:
			return ""
		for part in parts:
			if not part.is_valid_int():
				return ""
		parts[2] = str(parts[2].to_int() + 1)
		return ".".join(parts) + suffix

	func _export_end() -> void:
		var version := str(ProjectSettings.get_setting("application/config/version", ""))
		var next := bumped(version)
		if next == "":
			push_warning("Version Bump: application/config/version \"%s\" is not MAJOR.MINOR.PATCH[-tag]" % version)
			return
		ProjectSettings.set_setting("application/config/version", next)
		ProjectSettings.save()
		print("Version Bump: exported %s, next build is %s" % [version, next])
