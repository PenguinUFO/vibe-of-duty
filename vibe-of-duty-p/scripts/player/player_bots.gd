class_name PlayerBots
extends PlayerView
## Player, part 8 of 9: scripted input for automated tests (--bot-* launch arguments).
## The parts form a chain of scripts, each extending the previous one (map: player.gd).

var _bot_select := 0
var _bot_corner := 1      # --bot-course: the loop corner it runs to next
var _bot_stuck := 0.0     # --bot-course: s standing still while trying to run
var _ttk_start := -1      # --bot-ttk: physics frame of the kill's first shot (-1: not shooting yet)
var _ttk_shots := 0       # --bot-ttk: shots_total at that shot
var _ttk_aim_points: Array[Vector3] = []  # --bot-ttk: the target's body point over the last --bot-react s
var _ttk_seen := -1       # --bot-ttk: physics frame the target stood up at (-1: down)
# --bot-style (archetype bots, BotProfiles; Docs/BOTS.md):
var _arch_rng := RandomNumberGenerator.new()
var _arch_target: Player = null
var _arch_seen := false              # the target was in sight last tick
var _arch_hist: Array[Vector3] = []  # the target's aim point, a tick each, newest last (it sees it `react` s late)
var _arch_notice := 0.0              # s left before it reacts to the target that came into sight
var _arch_aim := Vector2.ZERO        # (yaw, pitch) of its hands, before the recoil
var _arch_noise := Vector2.ZERO      # rad: the aim's wander (yaw, pitch)
var _arch_head := false              # aims at the head now
var _arch_head_time := 0.0
var _arch_strafe := 1.0              # strafe direction
var _arch_strafe_time := 0.0
var _arch_crouch := false
var _arch_crouch_time := 0.0
var _arch_shots := 0                 # shots in this burst
var _arch_pause := 0.0               # s until the next burst
var _arch_mag := -1                  # rounds in the magazine last tick (fewer now: a shot went out); -1: not started
## --bot-course: corners of the obstacle course loop (x, z), in running order (prefabs/levels/course.tscn).
const COURSE_LOOP: Array[Vector2] = [Vector2(-30, 22), Vector2(30, 22), Vector2(30, -22), Vector2(-30, -22)]


func _bot_cmd(delta: float) -> PlayerCmd:
	# Scripted input for automated network tests (launch args --bot / --bot-aim).
	var t := Time.get_ticks_msec() / 1000.0
	var cmd := PlayerCmd.new()
	if Game.bot_oink:
		_try_oink()
	if Game.bot_style != "" and world != null:
		return _bot_arch_cmd(delta)
	if Game.bot_aim and world != null:
		return _bot_aim_cmd(t)
	if Game.bot_melee and world != null:
		return _bot_melee_cmd(t)
	if Game.bot_statue:
		return _bot_statue_cmd(t)
	if Game.bot_ttk != "":
		return _bot_ttk_cmd()
	if Game.bot_targets:
		return _bot_targets_cmd(t)
	if Game.bot_course:
		return _bot_course_cmd(delta)
	if not is_nan(Game.bot_climb):
		look_yaw = Game.bot_climb
		cmd.yaw = look_yaw
		cmd.move = Vector2(0.0, -1.0 if not is_on_floor() else 0.0)  # jump first, then push on (as a player does)
		cmd.jump = fmod(t, 1.5) < delta
		cmd.jump_held = true
		return cmd
	if Game.bot_idle != "":
		cmd.yaw = look_yaw
		cmd.crouch = Game.bot_idle == "crouch"
		return cmd
	if not is_nan(Game.bot_run):
		# Runs round the ring station (or straight on) at a fixed yaw, sprinting, jumping every 2 s (vaults anything in
		# reach) and sliding now and then.
		look_yaw = Game.bot_run
		cmd.yaw = look_yaw
		cmd.move = Vector2(0.0, -1.0)
		cmd.sprint = fmod(t, 5.0) < 4.5  # past the crouch press: a slide needs a sprint's speed
		cmd.crouch = fmod(t, 5.0) > 4.4
		cmd.jump = fmod(t, 2.0) < delta
		cmd.jump_held = true
		return cmd
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
	cmd.fire = fmod(t, 4.0) < 2.5 and _bot_trigger()
	cmd.aim = fmod(t, 8.0) > 5.5
	cmd.reload = fmod(t, 9.0) < delta
	var sel := int(t / 11.0) % WeaponDB.count()
	if sel != _bot_select:
		_bot_select = sel
		cmd.select = sel
	return cmd


## Looks at the statue (PigStatue) all the time, fires at it for 0.4 s every 10 s and strafes left and right: the
## statue should turn on it and shoot it dead.
func _bot_statue_cmd(t: float) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	var statue := get_tree().get_first_node_in_group(PigStatue.GROUP) as PigStatue
	if statue != null:
		var dir := (statue.chest_point() - (global_position + body_up() * STAND_EYE)).normalized()
		dir = Gravity.frame(global_position).inverse() * dir  # look angles are in the gravity frame
		look_yaw = atan2(-dir.x, -dir.z)
		look_pitch = clampf(asin(dir.y), -MAX_PITCH, MAX_PITCH)
		cmd.fire = fmod(t, 10.0) < 0.4 and alive and _bot_trigger()
	cmd.move = Vector2(1.0 if int(t / 1.5) % 2 == 0 else -1.0, 0.0)
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
	return cmd


## Whether the trigger may be held this tick: a semi-automatic weapon needs it let go between shots.
func _bot_trigger() -> bool:
	return weapons.current().automatic or not weapons.fire_prev


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
		var eye := global_position + body_up() * STAND_EYE
		var dir := (point - eye).normalized()
		dir = Gravity.frame(global_position).inverse() * dir  # look angles are in the gravity frame
		look_yaw = atan2(-dir.x, -dir.z) - weapons.recoil.y
		look_pitch = clampf(asin(dir.y) - weapons.recoil.x, -MAX_PITCH, MAX_PITCH)
		cmd.fire = weapons.ads > 0.95 and target.alive and _bot_trigger()
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
	cmd.reload = weapons.mags[weapons.index] == 0
	return cmd


## Shoots the body of one target (--bot-ttk) from a full magazine each time it stands up, pulling down Game.bot_recoil
## of the kick, aiming where the target was --bot-react s ago; from the hip (--bot-hip) or aiming, standing or strafing (--bot-strafe: 1 s each way). Counts each kill
## (Game.stats): ttk_ms from the first shot, ttk_full_ms from the target standing up (the aiming time included),
## its shots.
func _bot_ttk_cmd() -> PlayerCmd:
	var cmd := PlayerCmd.new()
	var target := get_tree().current_scene.find_child(Game.bot_ttk, true, false) as Target
	for other in get_tree().get_nodes_in_group(Target.GROUP):
		if other != target:  # the nearer targets (and the runner) stand in the line of fire of the farther ones
			other.remove_from_group(Target.GROUP)
			other.visible = false
	if target != null and alive:
		var seg := LagComp.body_segment(target.hitbox_state())
		_ttk_aim_points.append((seg[0] as Vector3).lerp(seg[1], 0.6))
		var late := roundi(Game.bot_react * Engine.physics_ticks_per_second)  # aims where it was `late` ticks ago
		while _ttk_aim_points.size() > late + 1:
			_ttk_aim_points.pop_front()
		var aim: Vector3 = _ttk_aim_points[0]
		if late > 0 and _ttk_aim_points.size() > 1:  # leads it as it was moving then: misses only its changes
			aim += (_ttk_aim_points[1] - _ttk_aim_points[0]) * late
		var dir := (aim - (global_position + body_up() * STAND_EYE)).normalized()
		dir = Gravity.frame(global_position).inverse() * dir  # look angles are in the gravity frame
		look_yaw = atan2(-dir.x, -dir.z) - weapons.recoil.y * Game.bot_recoil
		look_pitch = clampf(asin(dir.y) - weapons.recoil.x * Game.bot_recoil, -MAX_PITCH, MAX_PITCH)
		var frame := Engine.get_physics_frames()
		if target.alive:
			if _ttk_seen < 0:
				_ttk_seen = frame
			if _ttk_start < 0 and shots_total > _ttk_shots:
				_ttk_start = frame - 1  # the shot went out last tick
			cmd.aim = not Game.bot_hip
			cmd.fire = (Game.bot_hip or weapons.ads > 0.95) and weapons.mags[weapons.index] > 0 and _bot_trigger()
			cmd.reload = weapons.mags[weapons.index] == 0  # the magazine ran out before the kill: part of its time
			if Game.bot_strafe:
				cmd.move = Vector2(1.0 if int(frame / Engine.physics_ticks_per_second) % 2 == 0 else -1.0, 0.0)
		else:
			if _ttk_start >= 0:
				var rate := float(Engine.physics_ticks_per_second)
				Game.count("ttk_kills")
				Game.count("ttk_ms", roundi((frame - 1 - _ttk_start) * 1000.0 / rate))
				Game.count("ttk_full_ms", roundi((frame - 1 - _ttk_seen) * 1000.0 / rate))
				Game.count("ttk_shots", shots_total - _ttk_shots)
				_ttk_start = -1
			_ttk_seen = -1
			_ttk_shots = shots_total
			weapons.reserves[weapons.index] = weapons.current().reserve_max  # the test runs out of nothing
			cmd.reload = weapons.mags[weapons.index] < weapons.current().mag_size
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
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
		var eye := global_position + body_up() * STAND_EYE
		var seg := LagComp.body_segment(target.hitbox_state())
		var dir := ((seg[0] as Vector3).lerp(seg[1], 0.6) - eye).normalized()
		dir = Gravity.frame(global_position).inverse() * dir  # look angles are in the gravity frame
		look_yaw = atan2(-dir.x, -dir.z)
		look_pitch = clampf(asin(dir.y), -MAX_PITCH, MAX_PITCH)
		cmd.move = Vector2(0.4 if int(t / 2.0) % 2 == 0 else -0.4, -1.0 if best > melee_reach() - 0.8 else 0.0)
		cmd.melee = best < melee_reach() - 0.2 and not weapons.is_meleeing()
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
		var eye := global_position + body_up() * STAND_EYE
		var dir := (LagComp.head_center(target.hitbox_state()) - eye).normalized()  # headshots test the hitbox model
		if weapons.is_launching():
			dir = (target.global_position - eye).normalized()  # a grenade: at the feet (the loft carries it on a bit)
		dir = Gravity.frame(global_position).inverse() * dir  # look angles are in the gravity frame
		# Aim at the target, minus the current recoil kick (a human would pull down to compensate).
		look_yaw = atan2(-dir.x, -dir.z) - weapons.recoil.y
		look_pitch = clampf(asin(dir.y) - weapons.recoil.x, -MAX_PITCH, MAX_PITCH)
		cmd.fire = weapons.ads > 0.95 and _bot_trigger()
		if weapons.is_akimbo():  # no sights: both triggers from the hip, the left one let go between shots too
			cmd.fire = _bot_trigger()
			cmd.aim = weapons.current().automatic or not weapons.left_prev
		cmd.grenade = weapons.grenades > 0 and best > 5.0 and best < 14.0  # the grenade: once a life, mid range
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
	return cmd


## An archetype bot (--bot-style, --bot-skill; BotProfiles, Docs/BOTS.md): picks the nearest enemy in sight (else walks
## at the nearest one), notices it `react` s late, turns at most `turn` deg/s towards where it was `react` s ago (leading
## `lead` of its motion), with a wandering aim error (`noise`), pulls down `recoil` of the kick. Fires when it thinks the
## aim is within `gate` body widths, in bursts or holding the trigger; keeps its distance, strafes, crouches, jumps and
## punches as its style says. Sees what this client shows (other players interpolated), like a human.
func _bot_arch_cmd(delta: float) -> PlayerCmd:
	var cmd := PlayerCmd.new()
	var style := BotProfiles.style(Game.bot_style)
	var skill := BotProfiles.skill(Game.bot_skill)
	if _arch_mag < 0:
		_arch_rng.seed = hash(Settings.player_name) ^ Time.get_ticks_usec()
		_arch_aim = Vector2(look_yaw, look_pitch)
	if not alive:
		_arch_target = null
		_arch_hist.clear()
		_arch_mag = 0
		_arch_aim = Vector2(look_yaw, look_pitch)
		cmd.yaw = look_yaw
		cmd.pitch = look_pitch
		return cmd
	var eye := global_position + body_up() * (CROUCH_EYE if is_crouched else STAND_EYE)
	var space := get_world_3d().direct_space_state
	# The target: the nearest enemy in sight; none in sight - the nearest one, to walk to.
	var target: Player = null
	var seen := false
	var best := INF
	for id in world.players:
		var other: Player = world.players[id]
		if other == self or not other.alive:
			continue
		var d := other.global_position.distance_to(global_position)
		var other_seg := LagComp.body_segment(other.hitbox_state())
		var chest: Vector3 = (other_seg[0] as Vector3).lerp(other_seg[1], 0.6)
		var visible := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, chest, Layers.WORLD)).is_empty()
		if (visible and not seen) or (visible == seen and d < best):
			target = other
			seen = visible
			best = d
	if target != _arch_target or (seen and not _arch_seen):
		_arch_notice = skill["react"] * _arch_rng.randf_range(0.8, 1.2)
		_arch_hist.clear()
	_arch_target = target
	_arch_seen = seen
	# Where it aims on the body (chosen anew every second).
	_arch_head_time -= delta
	if _arch_head_time <= 0.0:
		_arch_head_time = 1.0
		_arch_head = _arch_rng.randf() < skill["head"]
	var fighting := false
	var dist := best
	var shot := weapons.mags[weapons.index] < _arch_mag
	_arch_mag = weapons.mags[weapons.index]
	if target != null:
		var state := target.hitbox_state()
		var seg := LagComp.body_segment(state)
		_arch_hist.append(LagComp.head_center(state) if _arch_head else (seg[0] as Vector3).lerp(seg[1], 0.6))
		var late := roundi(skill["react"] * Engine.physics_ticks_per_second)
		while _arch_hist.size() > late + 1:
			_arch_hist.pop_front()
		var point: Vector3 = _arch_hist[0]
		if _arch_hist.size() > 1:  # leads its motion as it was then: `lead` of it
			point += (_arch_hist[1] - _arch_hist[0]) * (_arch_hist.size() - 1) * skill["lead"]
		# The hands' wander: a slow random walk round the point (Ornstein-Uhlenbeck, 0.35 s).
		var sigma := deg_to_rad(skill["noise"])
		var tau := 0.35
		for i in 2:
			_arch_noise[i] += -_arch_noise[i] / tau * delta + sigma * sqrt(2.0 * delta / tau) * _arch_rng.randfn()
		var dir := Gravity.frame(global_position).inverse() * (point - eye).normalized()  # look angles: gravity frame
		var clean := Vector2(atan2(-dir.x, -dir.z), asin(clampf(dir.y, -1.0, 1.0)))
		var want := clean + _arch_noise
		if seen:
			_arch_notice -= delta
		var step := deg_to_rad(skill["turn"]) * delta
		if seen and _arch_notice <= 0.0:
			var off := Vector2(angle_difference(_arch_aim.x, want.x), want.y - _arch_aim.y)
			if off.length() > step:
				off = off.normalized() * step
			_arch_aim += off
			fighting = true
		elif not seen:  # walks to it, looking its way
			_arch_aim.x = rotate_toward(_arch_aim.x, clean.x, step)
			_arch_aim.y = move_toward(_arch_aim.y, 0.0, step)
		_arch_aim.y = clampf(_arch_aim.y, -MAX_PITCH, MAX_PITCH)
		look_yaw = _arch_aim.x - weapons.recoil.y * skill["recoil"]
		look_pitch = clampf(_arch_aim.y - weapons.recoil.x * skill["recoil"], -MAX_PITCH, MAX_PITCH)
		if fighting:
			# Fires when it thinks it is on: the view (with the recoil it did not pull down) within `gate` body widths
			# (0.7 m) of where its hands mean to be - the wander it does not feel, so that is where it misses.
			var view := Vector2(look_yaw + weapons.recoil.y, look_pitch + weapons.recoil.x)
			var err := Vector2(angle_difference(view.x, want.x) * cos(want.y), want.y - view.y).length()
			var on: bool = err < style["gate"] * atan(0.35 / maxf(dist, 0.5))
			cmd.aim = dist >= style["ads_from"]
			var ready: bool = not cmd.aim or weapons.ads > 0.95
			if shot:
				_arch_shots += 1
				if style["burst"] > 0 and _arch_shots >= style["burst"]:
					_arch_pause = style["pause"] * _arch_rng.randf_range(0.8, 1.2)
					_arch_shots = 0
			_arch_pause -= delta
			cmd.fire = on and ready and _arch_pause <= 0.0 and _bot_trigger()
			if weapons.is_akimbo():  # no sights: both triggers from the hip, the left one let go between shots too
				cmd.fire = on and _arch_pause <= 0.0 and _bot_trigger()
				cmd.aim = on and (weapons.current().automatic or not weapons.left_prev)
			if not cmd.fire and _arch_pause <= 0.0:
				_arch_shots = 0  # let go on its own: the next press is a new burst
			cmd.melee = style["melee"] and dist < melee_reach() - 0.2 and not weapons.is_meleeing()
	# Out of a fight: a half-empty magazine is reloaded.
	if not fighting and weapons.mags[weapons.index] < weapons.current().mag_size / 2.0:
		cmd.reload = true
	# Movement (x: right, y: back), relative to where it looks.
	var keep: float = style["keep"]
	var forward := 0.0
	if target != null:
		if not seen or dist > keep + 2.0:
			forward = -1.0
		elif style["back_off"] > 0.0 and dist < style["back_off"]:
			forward = 1.0
	var side := 0.0
	if fighting:
		_arch_strafe_time -= delta
		if _arch_strafe_time <= 0.0:
			_arch_strafe = -_arch_strafe
			_arch_strafe_time = style["strafe_time"] * _arch_rng.randf_range(0.6, 1.4)
		side = _arch_strafe * style["strafe"]
		_arch_crouch_time -= delta
		if _arch_crouch_time <= 0.0:
			_arch_crouch_time = 1.5 * _arch_rng.randf_range(0.6, 1.4)
			_arch_crouch = _arch_rng.randf() < style["crouch"]
		cmd.crouch = _arch_crouch
		cmd.jump = _arch_rng.randf() < style["jump"] * delta
		cmd.jump_held = cmd.jump
	if style["stand_fire"] and cmd.fire:
		forward = 0.0
		side = 0.0
	cmd.move = Vector2(side, forward)
	if style["sprint"] and forward < 0.0 and (not seen or dist > keep + 6.0) and not cmd.fire:
		cmd.sprint = true
		cmd.aim = false
		cmd.crouch = false
	cmd.yaw = look_yaw
	cmd.pitch = look_pitch
	return cmd
