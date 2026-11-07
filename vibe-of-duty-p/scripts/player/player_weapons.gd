class_name PlayerWeapons
extends PlayerMantle
## Player, part 3 of 9: weapon tick, shots, hoof punches, hit tests (hitscan against LagComp hitboxes), shot cosmetics.
## The parts form a chain of scripts, each extending the previous one (map: player.gd).

const SHOT_LISTENER := &"on_shot"
## The ЧМП's shot seen from the eyes (camera frame): the flash and the trail start here, by the left eye, low.
const CMP_VIEW := Vector3(-0.05, -0.03, -0.15)


func _weapon_step(cmd: PlayerCmd, dt: float) -> void:
	var ctx := {
		"peer_id": peer_id,
		"speed": flat_speed(),
		"crouched": is_crouched,
		"airborne": not is_on_floor(),
		"sprinting": is_sprinting,
		"sliding": is_sliding,
		"mantling": is_mantling,
	}
	var events := weapons.tick(cmd, dt, ctx)
	aiming = weapons.ads > 0.5
	if cmd.grenade and not _replaying and alive and not bomb_armed and build.has(PartDB.BOMB) and world != null \
			and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		world.grenades.server_arm_bomb(self)
	for event in events:
		match event["type"]:
			"shot":
				event["view_tick"] = cmd.view_tick
				_on_shot(event)
			"dry":
				_local_sfx("empty")
				if not _replaying and weapons.reserves[weapons.index] == 0 and multiplayer.has_multiplayer_peer() 						and multiplayer.is_server():
					dry_total += 1
			"reload_start":
				_local_sfx("reload")
			"equip":
				_local_sfx("equip")
				if _view:
					_view.set_weapon(weapons.index, weapons.current())
			"melee_start":
				_sfx("punch")
			"melee":
				event["view_tick"] = cmd.view_tick
				_on_melee(event)
			"grenade_start":
				_sfx("cannon_out")
			"grenade":
				_on_grenade(event)
			"akimbo_drop":
				if not _replaying and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
					Game.count("akimbo_drops")
					if world != null and world._stats != null:
						world._stats.akimbo_drop(self, event["rounds"])
				# Thrown away: the shooter's from the first-person gun (others' bodies - PlayerVisual.set_akimbo).
				if is_local and not _replaying and _left_view != null:
					DroppedGun.toss(self, _left_view, velocity)


func _local_sfx(id: String) -> void:
	if is_local and not _replaying:
		Audio.play(id)


func _on_shot(event: Dictionary) -> void:
	if _replaying:
		return
	var def := weapons.def_at(event["weapon"])
	var left: bool = event.get("left", false)  # the akimbo's left gun
	var origin := eye_position()
	var is_server := multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	var tick := _judge_tick(event["view_tick"], is_server)
	var results: Array = []
	var ends := PackedVector3Array()
	var hits: Array = []
	var damage_by_victim := {}  # peer_id -> {player, damage, head}
	var target_hits := {}  # Target -> {damage, head, marks: [[pos, head]]} (training targets)
	var frame := Gravity.frame(global_position)  # the shot's directions are in the gravity frame (like the look angles)
	for local_dir in event["dirs"]:
		var dir: Vector3 = frame * local_dir
		var r := _trace(origin, dir, def.max_range, tick)
		var hit_damage := def.damage_at(origin.distance_to(r["pos"]))  # by distance (WeaponDef.falloff_*)
		results.append(r)
		ends.append(r["pos"])
		var target: Target = r.get("target")
		if target != null:
			var t_head: bool = r["zone"] == "head"
			var t_entry: Dictionary = target_hits.get_or_add(target, {"damage": 0.0, "head": false, "marks": []})
			t_entry["damage"] += hit_damage * (def.head_mult if t_head else 1.0)
			t_entry["head"] = t_entry["head"] or t_head
			t_entry["marks"].append([r["pos"], t_head])
		var victim: Player = r["player"]
		if victim != null:
			var head: bool = r["zone"] == "head"
			hits.append({"player_id": victim.peer_id, "zone": r["zone"], "pos": r["pos"]})
			var entry: Dictionary = damage_by_victim.get_or_add(victim.peer_id, {"player": victim, "damage": 0.0, "head": false})
			entry["damage"] += hit_damage * (def.head_mult if head else 1.0)
			entry["head"] = entry["head"] or head
	if is_server:
		shots_total += 1
		hits_total += hits.size()
		for hit in hits:
			head_hits_total += 1 if hit["zone"] == "head" else 0
		if event["weapon"] == WeaponSim.CMP:
			Game.count("cmp_shots")
			Game.count("cmp_hits", hits.size())
		if left:
			Game.count("akimbo_left_shots")
			Game.count("akimbo_left_hits", hits.size())
		server_shot.emit(self, event["weapon"], origin, ends, hits, left)
		if world != null:
			for victim_id in damage_by_victim:
				var entry: Dictionary = damage_by_victim[victim_id]
				world.server_apply_damage(self, entry["player"], entry["damage"], entry["head"], event["weapon"])
		_tell_shot_level(results)
		for target in target_hits:
			var t_entry: Dictionary = target_hits[target]
			for mark in t_entry["marks"]:
				(target as Target).add_mark(mark[0], mark[1])
			var knocked: bool = (target as Target).take_damage(t_entry["damage"], t_entry["head"])
			if is_local:
				on_hit_confirmed(knocked, t_entry["head"])
	if is_local:
		var cmp: bool = event["weapon"] == WeaponSim.CMP  # the hands hold the empty weapon still: only a small flash
		var gun := _left_view if left else _view
		if not cmp:
			gun.flash(def.muzzle_flash)
			gun.kick(1.0 if def.pellets == 1 else 2.0)
		Audio.play(def.sound_shot, null, def.loudness, def.sound_pitch)
		var muzzle := _camera.global_transform * CMP_VIEW if cmp else gun.muzzle_global_position()
		if def.muzzle_flash:
			MuzzleLights.flash(self, muzzle)
		if world != null and world.kill_cam != null:
			world.kill_cam.record_shot(peer_id, event["weapon"], muzzle, ends, left)
		var scene_root := get_tree().current_scene
		for r in results:
			ShotEffects.spawn_tracer(scene_root, muzzle, r["pos"])
			if r["player"] != null:
				(r["player"] as Player).react_to_shot(origin, r["pos"])
			elif r.get("target") != null:
				(r["target"] as Target).react_to_shot(origin, r["pos"])
			if r["hit"] and r["player"] == null and r.get("target") == null:
				ShotEffects.spawn_impact(scene_root, r["pos"], r["normal"])
				Audio.play("impact", r["pos"])


## Server: level pieces that react to being shot (PigStatue) carry a Callable in their collider's SHOT_LISTENER
## metadata; it gets the shooter once per shot, however many pellets hit.
func _tell_shot_level(results: Array) -> void:
	var told := {}
	for r in results:
		var collider: Object = r.get("collider")
		if r["player"] != null or collider == null or told.has(collider) or not collider.has_meta(SHOT_LISTENER):
			continue
		told[collider] = true
		(collider.get_meta(SHOT_LISTENER) as Callable).call(self)


func melee_reach() -> float:
	return WeaponSim.MELEE_RANGE + mods["melee_range_add"]


## The fan of a punch along a view: the first body found (it goes from the middle outwards), else the middle ray's
## _trace - no body in it, its "pos" where the punch ends.
func _melee_fan(pitch: float, yaw: float, tick: float) -> Dictionary:
	var origin := eye_position()
	var frame := Gravity.frame(global_position)
	var middle := {}
	for offset in MELEE_FAN:
		var r := _trace(origin, frame * Basis.from_euler(Vector3(pitch + offset.y, yaw + offset.x, 0.0)) * Vector3.FORWARD,
				melee_reach(), tick, WeaponSim.MELEE_PAD + mods["melee_pad"])
		if r["player"] != null or r.get("target") != null:
			return r
		if middle.is_empty():
			middle = r
	return middle


## The blow of a hoof punch: the nearest player or target in a fan of short rays around the view (easier to land
## than a bullet), judged like a shot (LagComp rewind on the server). The server applies the damage; the puncher hears
## the hit at once (predicted), everybody else gets it from the server (server_melee).
func _on_melee(event: Dictionary) -> void:
	if _replaying:
		return
	var origin := eye_position()
	var is_server := multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	var tick := _judge_tick(event["view_tick"], is_server)
	var hit := _melee_fan(event["pitch"], event["yaw"], tick)
	if is_server:
		server_punch.emit(self, hit)
	if hit["player"] == null and hit.get("target") == null:
		return
	var head: bool = hit["zone"] == "head"
	var damage: float = WeaponSim.MELEE_DAMAGE * mods["melee_damage_mult"] * (NetWorld.HEAD_DAMAGE_MULT if head else 1.0)
	if is_local:
		Audio.play("punch_hit", hit["pos"])
		if hit["player"] != null:
			(hit["player"] as Player).react_to_shot(origin, hit["pos"])
		else:
			(hit["target"] as Target).react_to_shot(origin, hit["pos"])
		if world != null and world.kill_cam != null:
			world.kill_cam.record_shot(peer_id, WeaponSim.MELEE, origin, PackedVector3Array([hit["pos"]]))
	if not is_server:
		return
	Game.count("melee_hits")
	server_melee.emit(self, hit["pos"])
	if hit["player"] != null:
		if world != null:
			world.server_apply_damage(self, hit["player"], damage, head, WeaponSim.MELEE)
	else:
		var target: Target = hit["target"]
		target.add_mark(hit["pos"], head)
		var knocked := target.take_damage(damage, head)
		if is_local:
			on_hit_confirmed(knocked, head)


## Cosmetics of somebody else's punch that landed at `pos` (called by World on clients and on the host).
func show_remote_melee(pos: Vector3) -> void:
	var origin := eye_position()
	if world != null and world.kill_cam != null:
		world.kill_cam.record_shot(peer_id, WeaponSim.MELEE, origin, PackedVector3Array([pos]))
	Audio.play("punch_hit", pos)
	if world != null:
		for id in world.players:
			if id != peer_id:
				(world.players[id] as Player).react_to_shot(origin, pos)


## The launch of the "Гренадир"'s grenade (Docs/LOADOUT.md): out of the chest cannon, along the view lofted up, plus
## the player's own velocity. The server launches it for everybody (Grenades); the shooter's client at once on its own
## (prediction). It also ends the spawn protection, as shooting does not (owner, 2026-11-02).
func _on_grenade(event: Dictionary) -> void:
	if _replaying or world == null:
		return
	var launch := grenade_launch(event["pitch"], event["yaw"])
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		spawn_protect = 0
		world.grenades.server_launch(self, launch[0], launch[1])
	elif is_local:
		world.grenades.predict(self, launch[0], launch[1])
	if is_local:
		Audio.play("grenade_launch")
		_view.kick(2.0)
		if world.kill_cam != null:
			world.kill_cam.record_shot(peer_id, WeaponSim.GRENADE, launch[0], PackedVector3Array([launch[1]]))
		cannon_smoke(launch[0], launch[1])


## [where the grenade leaves the chest cannon (world), its velocity] for a launch at these look angles. The same on every
## machine for the same state (the body's position and stance, not the drawn pose); not out of the far side of a wall
## the chest is pressed against.
func grenade_launch(pitch: float, yaw: float) -> Array[Vector3]:
	var frame := Gravity.frame(global_position)
	var chest := global_position + frame.y * (GRENADE_CHEST_CROUCH if is_crouched else GRENADE_CHEST)
	var forward := frame * Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var origin := chest + forward * GRENADE_OUT
	var blocked := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(chest, origin + forward * Grenade.RADIUS, Layers.WORLD))
	if not blocked.is_empty():
		origin = chest
	var loft := deg_to_rad(WeaponDB.grenade("loft", 10.0))
	var dir := frame * Basis.from_euler(Vector3(minf(pitch + loft, PI * 0.5), yaw, 0.0)) * Vector3.FORWARD
	return [origin, dir * WeaponDB.grenade("speed", 18.0) + velocity]


## Smoke out of the cannon after a launch at `origin` going off at `vel` (cosmetic): a puff at the muzzle, then the
## empty barrel smokes for a moment.
func cannon_smoke(origin: Vector3, vel: Vector3) -> void:
	var out := vel.normalized()
	Dust.puff(self, origin, out * 3.0, 0.35, 0.5)
	MuzzleLights.flash(self, origin)
	for k in 4:
		get_tree().create_timer(0.15 + 0.2 * k).timeout.connect(func() -> void:
			if is_inside_tree():
				Dust.puff(self, _cannon_muzzle(), body_up() * 0.4, 0.12, 0.8))


## Where the chest cannon's muzzle is now (world): on the drawn body, or in the first-person view.
func _cannon_muzzle() -> Vector3:
	if is_local and _cannon_view != null:
		return _cannon_view.muzzle_global_position()
	return _visual.cannon_muzzle_position()


## Cosmetics of somebody else's launch (called by Grenades on clients and on the host).
func show_remote_grenade(origin: Vector3, vel: Vector3) -> void:
	if world != null and world.kill_cam != null:
		world.kill_cam.record_shot(peer_id, WeaponSim.GRENADE, origin, PackedVector3Array([vel]))
	Audio.play("grenade_launch", origin)
	cannon_smoke(origin, vel)


## Which server tick to judge a shot at: the shooter's view tick (server, remote shooters, lag comp on),
## or -1 to use everyone's live positions.
func _judge_tick(view_tick: float, is_server: bool) -> float:
	judge_rewind_ms = 0.0
	# The host's own shots too: it sees remote players slightly in the past as well (_buffered_pose).
	if not is_server or control == Mode.PUPPET or world == null or not world.lag_comp_enabled or view_tick <= 0.0:
		return -1.0
	var now := float(world.server_tick + 1)
	var tick := clampf(view_tick, now - LagComp.MAX_REWIND_TICKS, now)
	judge_rewind_ms = (now - tick) * 1000.0 / Engine.physics_ticks_per_second
	return tick


## A shot's path: the first thing hit - level, player (rewound to `tick` when >= 0) or training target. Bullets do
## not go through cover (owner, 2026-10-31: no penetration; a special weapon may get it, decided one by one).
## `pad`: m the body is widened by, for a ray that misses the real hitboxes (a punch).
func _trace(origin: Vector3, dir: Vector3, max_range: float, tick: float = -1.0, pad := 0.0) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var end := origin + dir * max_range
	var world_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, Layers.WORLD))
	var best := max_range
	var result := {"pos": end, "normal": -dir, "hit": false, "player": null, "zone": ""}
	if not world_hit.is_empty():
		best = origin.distance_to(world_hit["position"])
		result = {"pos": world_hit["position"], "normal": world_hit["normal"], "hit": true, "player": null, "zone": "",
				"collider": world_hit["collider"]}
	if world == null:
		return result
	# Players are hit-tested analytically (see LagComp), at their rewound position when `tick` >= 0.
	for id in world.players:
		var other: Player = world.players[id]
		if other == self or not other.alive:
			continue
		var state := _target_state(other, tick)
		if state.is_empty():
			continue
		var t_head := LagComp.ray_sphere(origin, dir, LagComp.head_center(state), LagComp.HEAD_RADIUS)
		var seg := LagComp.body_segment(state)
		var t_body := _body_hit(origin, dir, seg, t_head, pad)
		var t := -1.0
		var zone := ""
		if t_head >= 0.0 and (t_body < 0.0 or t_head <= t_body + 0.0001):
			t = t_head
			zone = "head"
		elif t_body >= 0.0:
			t = t_body
			zone = "body"
		if t >= 0.0 and t < best:
			best = t
			result = {"pos": origin + dir * t, "normal": -dir, "hit": true, "player": other, "zone": zone}
	# Training targets: the same hitboxes, always at their live position (they are not networked).
	for node in get_tree().get_nodes_in_group(Target.GROUP):
		var target := node as Target
		if not target.alive:
			continue
		var t_state := target.hitbox_state()
		var t_head := LagComp.ray_sphere(origin, dir, LagComp.head_center(t_state), LagComp.HEAD_RADIUS)
		var t_seg := LagComp.body_segment(t_state)
		var t_body := _body_hit(origin, dir, t_seg, t_head, pad)
		var t_hit := -1.0
		var t_zone := ""
		if t_head >= 0.0 and (t_body < 0.0 or t_head <= t_body + 0.0001):
			t_hit = t_head
			t_zone = "head"
		elif t_body >= 0.0:
			t_hit = t_body
			t_zone = "body"
		if t_hit >= 0.0 and t_hit < best:
			best = t_hit
			result = {"pos": origin + dir * t_hit, "normal": -dir, "hit": true, "player": null, "zone": t_zone,
					"target": target}
	return result


## The ray against a body (`seg`). The real hitboxes come first, so that the pad never turns a head hit into a body one.
static func _body_hit(origin: Vector3, dir: Vector3, seg: Array, t_head: float, pad: float) -> float:
	var t := LagComp.ray_capsule(origin, dir, seg[0], seg[1], LagComp.BODY_RADIUS)
	if t < 0.0 and t_head < 0.0 and pad > 0.0:
		t = LagComp.ray_capsule(origin, dir, seg[0], seg[1], LagComp.BODY_RADIUS + pad)
	return t


func _target_state(other: Player, tick: float) -> Dictionary:
	if tick >= 0.0:
		return world.lag_comp.sample(other.peer_id, tick)
	return other.hitbox_state()


## What the hitboxes depend on (LagComp): position, stance, facing, aim pitch, velocity and aiming.
## Puppets report their displayed state, the server its simulation.
func hitbox_state() -> Dictionary:
	var vel := velocity if control != Mode.PUPPET else _puppet_velocity
	var local_vel := Gravity.frame(global_position).inverse() * vel  # in the gravity frame, like the yaw
	return {"pos": global_position, "crouched": is_crouched, "yaw": body_yaw, "pitch": _head.rotation.x,
			"vel": Vector3(local_vel.x, 0.0, local_vel.z), "ads": aiming, "sliding": is_sliding}


## A shot that ended at `end` (world) jerks this player's body if it ended on it (cosmetic).
func react_to_shot(origin: Vector3, end: Vector3) -> void:
	if not is_local:
		_visual.react_to_shot(origin, end)


## Cosmetics of somebody else's shot (called by World on clients and on the host); `left`: the akimbo's left gun.
func show_remote_shot(weapon: int, origin: Vector3, ends: PackedVector3Array, left := false) -> void:
	var def := weapons.def_at(weapon)  # with this player's modules (their build is known everywhere)
	if world != null and world.kill_cam != null:
		world.kill_cam.record_shot(peer_id, weapon, origin, ends, left)
	var cmp := weapon == WeaponSim.CMP  # out of the left eye; the weapon in the hands stays as it is
	if not cmp:
		_visual.set_weapon(weapon, def)
	Audio.play(def.sound_shot, origin, def.loudness, def.sound_pitch)
	var scene_root := get_tree().current_scene
	var muzzle := _visual.eye_gun_muzzle_position() if cmp else _visual.muzzle_global_position(left)
	if not cmp:
		_visual.show_shot(def.muzzle_flash, left)  # a suppressor (weapons.cfg): no flash, no light, no trail - only the hit shows
	if def.muzzle_flash:
		MuzzleLights.flash(self, muzzle)
	for i in ends.size():
		if def.tracer:
			ShotEffects.spawn_tracer(scene_root, muzzle, ends[i])
		ShotEffects.spawn_impact(scene_root, ends[i], Gravity.up(ends[i]))
		if world != null:
			for id in world.players:
				if id != peer_id:
					var other := world.players[id] as Player
					other.react_to_shot(origin, ends[i])
		if i < 2:  # a shotgun blast would otherwise play eight impacts at once
			Audio.play("impact", ends[i])


## Whether a bullet from `origin` to `end` came close to the eyes (a hit on this player always does).
func bullet_near(origin: Vector3, end: Vector3) -> bool:
	var eye := eye_position()
	return eye.distance_to(Geometry3D.get_closest_point_to_segment(eye, origin, end)) <= NEAR_RADIUS


## Local player: the server confirmed that one of our shots damaged somebody.
func on_hit_confirmed(killed: bool, head: bool) -> void:
	if _crosshair:
		_crosshair.show_hit(killed, head)
	Audio.play("kill" if killed else "hit")
