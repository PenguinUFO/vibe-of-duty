extends SceneTree
## Checks the ring station's hit geometry (Gravity): two players at points round the drum - one across it, over the
## other's head - and shots from one's eyes at the other's head and chest must hit that zone; the hitbox head must
## sit where the drawn body's head is. Prints PASS / FAIL lines.
## Run: Godot_v4.7.2.exe --headless --path vibe-of-duty-p --script res://tools/ring_hit_test.gd

const R := 26.0


func _initialize() -> void:
	var level: Node = load("res://prefabs/levels/station.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await physics_frame
	var world = level.get_node("World")
	var scene: PackedScene = load("res://prefabs/player/player.tscn")
	var players: Array = []
	for i in 2:
		var p = scene.instantiate()
		p.control = 1  # REMOTE_SERVER: simulated here, a body drawn
		p.peer_id = 30 + i
		p.world = world
		level.get_node("Players").add_child(p)
		world.players[p.peer_id] = p
		players.append(p)
	var lag_comp = load("res://scripts/net/lag_comp.gd")
	var fails := 0
	# (shooter s, z, yaw; target s, z, yaw): the floor at s, facing yaw in the frame there.
	var cases := [[0.0, 0.0, 0.0, 8.0, 1.0, 1.0], [0.0, -3.0, 0.0, 66.0, -1.0, 2.5], [20.0, -2.5, 0.0, -8.0, -1.5, 0.4],
			[60.0, 6.0, 1.0, 100.0, -5.0, -2.0]]
	for c in cases:
		_put(players[0], c[0], c[1], c[2])
		_put(players[1], c[3], c[4], c[5])
		for i in 3:
			await physics_frame
		var shooter = players[0]  # untyped (and LagComp loaded below): naming the classes would compile them before the autoloads
		var target = players[1]
		var state: Dictionary = target.hitbox_state()
		var head: Vector3 = lag_comp.head_center(state)
		var seg: Array = lag_comp.body_segment(state)
		var chest := (seg[0] as Vector3).lerp(seg[1], 0.6)
		var eye: Vector3 = shooter.eye_position()
		for aim in [[head, "head"], [chest, "body"]]:
			var dir: Vector3 = ((aim[0] as Vector3) - eye).normalized()
			var r: Dictionary = shooter._trace(eye, dir, 300.0)
			var ok: bool = r["player"] == target and r["zone"] == aim[1]
			fails += 0 if ok else 1
			print("%s shot from s %.1f at s %.1f, %s: got %s %s (%.1f m)" % ["PASS" if ok else "FAIL", c[0], c[3], aim[1],
					"target" if r["player"] == target else str(r.get("collider")), r["zone"], eye.distance_to(r["pos"])])
		# The hitbox's head against the drawn one (Mannequin, at rest: within a few cm).
		var drawn: Vector3 = target._visual._mannequin._parts["Head"].global_position
		var off: float = drawn.distance_to(head)
		fails += 0 if off < 0.12 else 1
		print("%s head hitbox %.3f m off the drawn head (s %.1f), up %s" % ["PASS" if off < 0.12 else "FAIL", off, c[3],
				str(target.body_up())])
	print("RING HIT TEST: %s" % ("PASS" if fails == 0 else "%d FAIL" % fails))
	quit()


func _put(p, s: float, z: float, yaw: float) -> void:
	var a := s / R
	var pos := Vector3(R * sin(a), R - R * cos(a), z) + Gravity.up(Vector3(R * sin(a), R - R * cos(a), z)) * 0.02
	p.teleport(Transform3D(Gravity.frame(pos) * Basis(Vector3.UP, yaw), pos))
