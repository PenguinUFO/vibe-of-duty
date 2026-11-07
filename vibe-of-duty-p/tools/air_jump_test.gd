extends SceneTree
## Checks the "Прыг-Прыг" (PartDB.JET_HOOVES) with vaulting: on the test level, in front of a WALL_H wall -
## too high for a jump and a vault from the ground (PlayerMantle.MANTLE_MAX_HEIGHT) - a pig jumps, jumps again in the
## air and holds jump pushing on. With the hooves it must end up on top of the wall, without them not. Prints PASS /
## FAIL lines.
## Run: Godot_v4.7.2.exe --headless --path vibe-of-duty-p --script res://tools/air_jump_test.gd

const WALL_H := 3.8
const DT := 1.0 / 60.0


func _initialize() -> void:
	var level: Node = load("res://prefabs/levels/test_level.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await physics_frame
	var world = level.get_node("World")
	var p = load("res://prefabs/player/player.tscn").instantiate()
	p.control = 1  # REMOTE_SERVER: simulated here, stepped by hand (no commands queued)
	p.peer_id = 40
	p.world = world
	level.get_node("Players").add_child(p)
	world.players[p.peer_id] = p
	var cmd_script = load("res://scripts/player/player_cmd.gd")
	var start := Vector3(-0.2, 1.5, 22.0)  # in the open south of the middle; facing +x, the wall's face at x = 0.3
	p.teleport(Transform3D(Basis(Vector3.UP, -PI / 2.0), start))
	for i in 60:  # down onto the floor (is_on_floor() is only known after a step)
		p.step(cmd_script.new(), DT)
		await physics_frame
	var floor_y: float = p.global_position.y
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(4.0, WALL_H, 6.0)
	wall.add_child(shape)
	wall.position = Vector3(2.3, floor_y + WALL_H / 2.0, 22.0)
	level.add_child(wall)
	await physics_frame
	var fails := 0
	for hooves in [true, false]:
		p.set_build(["kit.ak", "jet_hooves"] if hooves else ["kit.ak"])
		var yaw := -PI / 2.0  # facing +x, at the wall
		p.teleport(Transform3D(Basis(Vector3.UP, yaw), Vector3(start.x, floor_y + 0.05, start.z)))
		for i in 10:
			p.step(cmd_script.new(), DT)
			await physics_frame
		var top := 0.0
		for tick in 150:
			var cmd = cmd_script.new()
			cmd.yaw = yaw
			cmd.move = Vector2(0.0, -1.0 if tick > 2 and not p.is_on_floor() else 0.0)  # push on in the air only
			cmd.jump = tick == 0 or tick == 22  # the second press near the first jump's top
			cmd.jump_held = tick < 120
			p.step(cmd, DT)
			await physics_frame
			top = maxf(top, p.global_position.y - floor_y)
		var feet: float = p.global_position.y - floor_y
		var on_top: bool = feet > WALL_H - 0.1 and p.is_on_floor()
		var ok: bool = on_top == hooves
		fails += 0 if ok else 1
		print("%s %s: feet %.2f m over the floor (highest %.2f), on the %.1f m wall: %s" % ["PASS" if ok else "FAIL",
				"jet hooves" if hooves else "no hooves", feet, top, WALL_H, str(on_top)])
	print("AIR JUMP TEST: %s" % ("PASS" if fails == 0 else "%d FAIL" % fails))
	quit()
