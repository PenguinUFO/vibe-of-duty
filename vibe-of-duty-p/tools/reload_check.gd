extends Node
## Akimbo reload timings from the real WeaponSim, no bots and no scene: for every akimbo weapon, and for a drum (the
## Striker) alone, the length of a reload, when each gun's own part starts (WeaponSim.reload_progress_right/left - the
## HUD plates and the gun that comes up), the rounds in each magazine second by second and the reserve after it.
##   Godot_v4.7.2.exe --headless --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=reload_check

const TICKS := 60.0
const CASES: Array = [  # [weapon index (WeaponDB), modules, title]
	[2, ["luger.akimbo.on"], "Luger akimbo"],
	[4, ["mp7.akimbo.on"], "MP7 akimbo"],
	[14, ["deagle.akimbo.on"], "Desert Eagle akimbo"],
	[13, ["striker.conversion.bulldog", "striker.akimbo.on"], "Striker Bulldog akimbo, a drum"],
	[13, ["striker.conversion.bulldog"], "Striker Bulldog alone, a drum"],
]
const MAX_TICKS := 60 * 60


func _ready() -> void:
	for c: Array in CASES:
		_check(c[0], c[1], c[2])
	get_tree().quit()


func _check(weapon: int, modules: Array, title: String) -> void:
	var def := WeaponDB.make_def(weapon, modules)
	var sim := WeaponSim.new()
	sim.defs.clear()
	for i in WeaponDB.count():
		sim.defs.append(WeaponDB.make_def(i, modules))
	sim.build_weapon = weapon
	sim.reset()
	sim.mags[weapon] = 0  # both drums empty: the longest reload there is
	sim.left_mag = 0
	var reserve := sim.reserves[weapon]
	var cmd := PlayerCmd.new()
	var ctx := {"peer_id": 0, "speed": 0.0, "crouched": false, "airborne": false, "sprinting": false,
			"sliding": false, "mantling": false}
	cmd.reload = true
	sim.tick(cmd, 1.0 / TICKS, ctx)
	cmd.reload = false
	var ticks := 0
	var right_from := -1
	var left_from := -1
	var half := -1
	var lines: Array[String] = []
	while sim.reload_ticks > 0 and ticks < MAX_TICKS:
		var events := sim.tick(cmd, 1.0 / TICKS, ctx)
		ticks += 1
		if right_from < 0 and sim.is_reloading_right():
			right_from = ticks
		if left_from < 0 and sim.is_reloading_left():
			left_from = ticks
		for e: Dictionary in events:
			if e["type"] == "reload_half":
				half = ticks
		if ticks % int(TICKS) == 0:
			lines.append("  %4.0f s  right %2d/%d  left %2d/%d  progress %+.2f / %+.2f" % [ticks / TICKS,
					sim.mags[weapon], def.mag_size, sim.left_mag, def.mag_size,
					sim.reload_progress_right(), sim.reload_progress_left()])
	print("%s: %.2f s, the right gun from %.2f s, %s, reload_half at %s, reserve %d -> %d" % [
			title, ticks / TICKS, right_from / TICKS,
			"the left from %.2f s" % (left_from / TICKS) if left_from > 0 else "no left gun",
			"%.2f s" % (half / TICKS) if half > 0 else "none", reserve, sim.reserves[weapon]])
	for line in lines:
		print(line)
