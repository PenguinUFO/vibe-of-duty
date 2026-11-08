extends Node
## Checks the recoil return (WeaponSim.recoil_held): a burst of each automatic weapon with the look pulling against `k`
## of the kick, then the trigger let go. Where the view ends up (look + recoil, degrees from where it started):
## untouched (k 0) - back at the start; held (k 1) - stays there too; half held - the same; held too much (k 1.3) -
## stays as low as it was pulled (no return up); moved down during the return - the view goes down by that. Prints
## PASS / FAIL lines.
##   Godot_v4.7.2.exe --headless --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=recoil_test

const FIRE_TICKS := 90     # 1.5 s on the trigger
const AFTER_TICKS := 240   # 4 s after: the return is over
const PULL_AFTER := 0.05   # rad pulled down during the return (the last case)


func _ready() -> void:
	var fails := 0
	for weapon in WeaponDB.count():
		var def := WeaponDB.make_def(weapon, [])
		if not def.automatic:
			continue
		for k: float in [0.0, 0.5, 1.0, 1.3]:
			var r := _burst(weapon, k, 0.0)
			var end: Vector2 = r["end"]
			var peak: float = r["peak"]
			# During the burst a held view stays near the start; after it, nothing returns but the unheld kick.
			var ok := absf(end.x) < 0.0005 and absf(end.y) < 0.0005 if k <= 1.0 \
					else end.x < 0.0  # over-held: as low (and as far to the side) as the player pulled it
			fails += 0 if ok else 1
			print("%s %-8s k %.1f: view ends %+.3f° pitch, %+.3f° yaw (peak kick %.2f°)" % ["PASS" if ok else "FAIL",
					def.id, k, rad_to_deg(end.x), rad_to_deg(end.y), rad_to_deg(peak)])
		var moved := _burst(weapon, 0.0, PULL_AFTER)
		var moved_end: Vector2 = moved["end"]
		var ok_moved := absf(moved_end.x + PULL_AFTER) < 0.0005
		fails += 0 if ok_moved else 1
		print("%s %-8s pulled %.1f° down during the return: view ends %+.3f°" % ["PASS" if ok_moved else "FAIL",
				def.id, rad_to_deg(PULL_AFTER), rad_to_deg(moved_end.x)])
	print("recoil_test: %s" % ("PASS" if fails == 0 else "%d FAIL" % fails))
	get_tree().quit(0 if fails == 0 else 1)


## The view's end (look + recoil) - start, as (pitch, yaw), and the biggest pitch kick; the look holds `k` of the kick
## while firing (as the bots: look = aim - k * recoil) and moves `pull` down evenly over the first second after.
func _burst(weapon: int, k: float, pull: float) -> Dictionary:
	var sim := WeaponSim.new()
	sim.build_weapon = weapon
	sim.infinite_reserve = true
	sim.reset()
	sim.ads = 1.0
	var look := Vector2.ZERO  # (pitch, yaw), starting at 0
	var aim := Vector2.ZERO   # where the player wants the view
	var ctx := {"peer_id": 7, "speed": 0.0, "crouched": false, "airborne": false, "mantling": false, "sliding": false,
			"sprinting": false}
	var peak := 0.0
	for t in FIRE_TICKS + AFTER_TICKS:
		var firing := t < FIRE_TICKS
		if firing:
			look = aim - sim.recoil * k
		elif t < FIRE_TICKS + 60:
			look.x -= pull / 60.0
		var cmd := PlayerCmd.new()
		cmd.pitch = look.x
		cmd.yaw = look.y
		cmd.fire = firing
		cmd.aim = true
		sim.tick(cmd, 1.0 / 60.0, ctx)
		look += sim.look_shift
		if firing:
			aim += sim.look_shift  # a bot's aim point is in the look's terms: the shift moved both
		peak = maxf(peak, sim.recoil.x)
	return {"end": look + sim.recoil, "peak": peak}
