class_name PlayerBots
extends PlayerView
## Player, part 8 of 9: scripted input for automated tests (--bot-* launch arguments).
## The parts form a chain of scripts, each extending the previous one (map: player.gd).

var _bot_select := 0
var _bot_corner := 1      # --bot-course: the loop corner it runs to next
var _bot_stuck := 0.0     # --bot-course: s standing still while trying to run
## --bot-course: corners of the obstacle course loop (x, z), in running order (prefabs/levels/course.tscn).
const COURSE_LOOP: Array[Vector2] = [Vector2(-30, 22), Vector2(30, 22), Vector2(30, -22), Vector2(-30, -22)]


func _bot_cmd(delta: float) -> PlayerCmd:
	# Scripted input for automated network tests (launch args --bot / --bot-aim).
	var t := Time.get_ticks_msec() / 1000.0
	var cmd := PlayerCmd.new()
	if Game.bot_oink:
		_try_oink()
	if Game.bot_aim and world != null:
		return _bot_aim_cmd(t)
	if Game.bot_melee and world != null:
		return _bot_melee_cmd(t)
	if Game.bot_targets:
		return _bot_targets_cmd(t)
	if Game.bot_course:
		return _bot_course_cmd(delta)
	if Game.bot_vault:
		# Runs back and forth over the test ledges, jumping all the time (vaults whenever one is in reach).
		look_yaw = PI if fmod(t, 7.0) >= 3.5 else 0.0  # 3.5 s each way (~18 m): crosses the ledges in both directions
		cmd.yaw = look_yaw
		cmd.move = Vector2(0.0, -1.0)
		cmd.jump = fmod(t, 0.4) < delta
		return cmd
	look_yaw += 0.8 * delta
	cmd.yaw = look_yaw
	cmd.move = Vector2(0.0, -1.0)
	cmd.sprint = fmod(t, 6.0) < 3.0
	cmd.crouch = fmod(t, 7.0) > 6.0
	cmd.jump = fmod(t, 2.5) < delta
	cmd.fire = fmod(t, 4.0) < 2.5
	cmd.aim = fmod(t, 8.0) > 5.5
	cmd.reload = fmod(t, 9.0) < delta
	var sel := int(t / 11.0) % WeaponDB.count()
	if sel != _bot_select:
		_bot_select = sel
		cmd.select = sel
	return cmd


## Runs laps of the obstacle course: down the middle lane of each side (COURSE_LOOP corners, in order), jumping at
## anything knee-high ahead, at edges and when stuck, holding jump in the air (grabs ledges) and crouching under
## anything head-high (a sprint into it slides).
func _bot_course_cmd(delta: float) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	var p := global_position
	var corner: Vector2 = COURSE_LOOP[_bot_corner]
	if Vector2(p.x, p.z).distance_to(corner) < 2.5:
		_bot_corner = (_bot_corner + 1) % COURSE_LOOP.size()
		if _bot_corner == 1:
			Game.count("laps")
			if Game.net_log:
				print("[COURSE] lap done at %.1f s" % (Time.get_ticks_msec() / 1000.0))
		corner = COURSE_LOOP[_bot_corner]
	# Aim at a point 3 m ahead on the side's centre line (not at the corner itself), so it stays in the middle lane.
	var from: Vector2 = COURSE_LOOP[(_bot_corner + COURSE_LOOP.size() - 1) % COURSE_LOOP.size()]
	var along := (corner - from).normalized()
	var here := from + along * clampf((Vector2(p.x, p.z) - from).dot(along), 0.0, from.distance_to(corner))
	var aim := here + along * minf(3.0, here.distance_to(corner))
	look_yaw = atan2(-(aim.x - p.x), -(aim.y - p.z))
	look_pitch = 0.0
	cmd.yaw = look_yaw
	cmd.move = Vector2(0.0, -1.0)
	cmd.sprint = true
	var fwd := Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))
	var space := get_world_3d().direct_space_state
	var ray := func(from: Vector3, to: Vector3) -> bool:
		return not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD, [get_rid()])).is_empty()
	var knee: bool = ray.call(p + Vector3(0, 0.3, 0), p + Vector3(0, 0.3, 0) + fwd)
	var head: bool = ray.call(p + Vector3(0, 1.3, 0), p + Vector3(0, 1.3, 0) + fwd * 1.8)
	var roof: bool = ray.call(p + Vector3(0, 0.9, 0), p + Vector3(0, 1.9, 0))
	var floor_ahead: bool = ray.call(p + Vector3(0, 0.2, 0) + fwd * 0.7, p + Vector3(0, -0.6, 0) + fwd * 0.7)
	var speed := Vector2(velocity.x, velocity.z).length()
	_bot_stuck = _bot_stuck + delta if is_on_floor() and speed < 0.5 and not is_mantling else 0.0
	cmd.crouch = (head and not knee) or roof
	cmd.jump = is_on_floor() and not cmd.crouch and (knee or not floor_ahead or _bot_stuck > 0.3)
	cmd.jump_held = not is_on_floor() or cmd.jump
	return cmd


## Stands still and shoots the training targets in turn, 4 s each: body, then head every other turn.
func _bot_targets_cmd(t: float) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	var targets := get_tree().get_nodes_in_group(Target.GROUP)
	cmd.aim = true
	if not targets.is_empty() and alive:
		var turn := int(t / 4.0)
		var target: Target = targets[turn % targets.size()]
		var state := target.hitbox_state()
		var seg := LagComp.body_segment(state)
		var point := LagComp.head_center(state) if (turn / targets.size()) % 2 == 1 else seg[0].lerp(seg[1], 0.6)
		var eye := global_position + Vector3.UP * STAND_EYE
		var dir := (point - eye).normalized()
		look_yaw = atan2(-dir.x, -dir.z) - weapons.recoil.y
		look_pitch = clampf(asin(dir.y) - weapons.recoil.x, -MAX_PITCH, MAX_PITCH)
		cmd.fire = weapons.ads > 0.95 and target.alive
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
	cmd.reload = weapons.mags[weapons.index] == 0
	return cmd


## Runs at the nearest enemy (as seen on this client's screen), looking at their chest, and punches within reach.
func _bot_melee_cmd(t: float) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	var target: Player = null
	var best := INF
	for id in world.players:
		var other: Player = world.players[id]
		if other != self and other.alive:
			var d := other.global_position.distance_to(global_position)
			if d < best:
				best = d
				target = other
	if target != null and alive:
		var eye := global_position + Vector3.UP * STAND_EYE
		var seg := LagComp.body_segment(target.hitbox_state())
		var dir := ((seg[0] as Vector3).lerp(seg[1], 0.6) - eye).normalized()
		look_yaw = atan2(-dir.x, -dir.z)
		look_pitch = clampf(asin(dir.y), -MAX_PITCH, MAX_PITCH)
		cmd.move = Vector2(0.4 if int(t / 2.0) % 2 == 0 else -0.4, -1.0 if best > 1.2 else 0.0)
		cmd.melee = best < 1.8 and not weapons.is_meleeing()
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
	return cmd


## Strafes around the nearest enemy while aiming at their head and firing (as seen on this client's screen).
func _bot_aim_cmd(t: float) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	var target: Player = null
	var best := INF
	for id in world.players:
		var other: Player = world.players[id]
		if other != self and other.alive:
			var d := other.global_position.distance_to(global_position)
			if d < best:
				best = d
				target = other
	# Close in to ~12 m (so spread alone does not decide the test), then strafe.
	cmd.move = Vector2(1.0 if int(t / 1.5) % 2 == 0 else -1.0, -1.0 if best > 12.0 else 0.0)
	cmd.aim = true
	if target != null and alive:
		var eye := global_position + Vector3.UP * STAND_EYE
		var dir := (LagComp.head_center(target.hitbox_state()) - eye).normalized()  # headshots test the hitbox model
		# Aim at the target, minus the current recoil kick (a human would pull down to compensate).
		look_yaw = atan2(-dir.x, -dir.z) - weapons.recoil.y
		look_pitch = clampf(asin(dir.y) - weapons.recoil.x, -MAX_PITCH, MAX_PITCH)
		cmd.fire = weapons.ads > 0.95
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
	return cmd
