@tool
extends EditorPlugin
## Build version: the export carries application/config/version as it is, and once the export is done its patch
## number goes up by one ("0.1.1" -> "0.1.2") and project.godot is saved, so every build gets its own number. The
## main menu shows it with application/config/version_tag ("v0.1.1-alpha"). The two are kept apart because the
## Windows export writes the version into the .exe properties, which take digits and periods only (a "-alpha" there
## gives "Invalid version number" and 1.0.0.0). Major / minor / the tag are changed by hand in Project Settings.

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

	func _export_end() -> void:
		var version := str(ProjectSettings.get_setting("application/config/version", ""))
		var next := bumped(version)
		if next == "":
			push_warning("Version Bump: application/config/version \"%s\" is not MAJOR.MINOR.PATCH" % version)
			return
		ProjectSettings.set_setting("application/config/version", next)
		ProjectSettings.save()
		print("Version Bump: exported %s, next build is %s" % [version, next])
