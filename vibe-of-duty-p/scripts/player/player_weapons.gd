class_name PlayerWeapons
extends PlayerMantle
## Player, part 3 of 9: weapon tick, shots, hoof punches, hit tests (hitscan against LagComp hitboxes), shot cosmetics.
## The parts form a chain of scripts, each extending the previous one (map: player.gd).

const SHOT_LISTENER := &"on_shot"


func _weapon_step(cmd: PlayerCmd, dt: float) -> void:
	var ctx := {
		"peer_id": peer_id,
		"speed": Vector2(velocity.x, velocity.z).length(),
		"crouched": is_crouched,
		"airborne": not is_on_floor(),
		"sprinting": is_sprinting,
		"sliding": is_sliding,
	}
	var events := weapons.tick(cmd, dt, ctx)
	aiming = weapons.ads > 0.5
	for event in events:
		match event["type"]:
			"shot":
				event["view_tick"] = cmd.view_tick
				_on_shot(event)
			"dry":
				_local_sfx("empty")
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


func _local_sfx(id: String) -> void:
	if is_local and not _replaying:
		Audio.play(id)


func _on_shot(event: Dictionary) -> void:
	if _replaying:
		return
	var def := weapons.def_at(event["weapon"])
	var origin := global_position + Vector3.UP * (CROUCH_EYE if is_crouched else STAND_EYE)
	var is_server := multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	var tick := _judge_tick(event["view_tick"], is_server)
	var results: Array = []
	var ends := PackedVector3Array()
	var hits: Array = []
	var damage_by_victim := {}  # peer_id -> {player, damage, head}
	var target_hits := {}  # Target -> {damage, head, marks: [[pos, head]]} (training targets)
	for dir in event["dirs"]:
		var r := _trace(origin, dir, def.max_range, tick, def.penetration)
		# Damage by distance (WeaponDef.falloff_*), less after going through cover.
		var hit_damage := def.damage_at(origin.distance_to(r["pos"])) \
				* (def.penetration_damage if r["through"] else 1.0)
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
		server_shot.emit(self, event["weapon"], origin, ends, hits)
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
		_view.flash(def.muzzle_flash)
		_view.kick(1.0 if def.pellets == 1 else 2.0)
		Audio.play(def.sound_shot, null, def.loudness)
		var muzzle := _view.muzzle_global_position()
		if def.muzzle_flash:
			MuzzleLights.flash(self, muzzle)
		if world != null and world.kill_cam != null:
			world.kill_cam.record_shot(peer_id, event["weapon"], muzzle, ends)
		var scene_root := get_tree().current_scene
		for r in results:
			ShotEffects.spawn_tracer(scene_root, muzzle, r["pos"])
			if r["player"] != null:
				(r["player"] as Player).react_to_shot(origin, r["pos"])
			elif r.get("target") != null:
				(r["target"] as Target).react_to_shot(origin, r["pos"])
			if r.get("entry", Vector3.INF).is_finite():  # went through cover: a hole where it went in
				ShotEffects.spawn_impact(scene_root, r["entry"], -(r["pos"] - origin).normalized())
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


## The blow of a hoof punch: the nearest player or target in a fan of short rays around the view (easier to land
## than a bullet), judged like a shot (LagComp rewind on the server). The server applies the damage; the puncher hears
## the hit at once (predicted), everybody else gets it from the server (server_melee).
func _on_melee(event: Dictionary) -> void:
	if _replaying:
		return
	var origin := global_position + Vector3.UP * (CROUCH_EYE if is_crouched else STAND_EYE)
	var is_server := multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	var tick := _judge_tick(event["view_tick"], is_server)
	var hit := {}
	for offset in MELEE_FAN:
		var r := _trace(origin, Basis.from_euler(Vector3(event["pitch"] + offset.y, event["yaw"] + offset.x, 0.0)) \
				* Vector3.FORWARD, WeaponSim.MELEE_RANGE, tick)
		if r["player"] != null or r.get("target") != null:
			hit = r
			break  # the fan goes from the middle outwards: the first body found is the one punched
	if hit.is_empty():
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
	var origin := global_position + Vector3.UP * (CROUCH_EYE if is_crouched else STAND_EYE)
	if world != null and world.kill_cam != null:
		world.kill_cam.record_shot(peer_id, WeaponSim.MELEE, origin, PackedVector3Array([pos]))
	Audio.play("punch_hit", pos)
	if world != null:
		for id in world.players:
			if id != peer_id:
				(world.players[id] as Player).react_to_shot(origin, pos)


## Which server tick to judge a shot at: the shooter's view tick (server, remote shooters, lag comp on),
## or -1 to use everyone's live positions.
func _judge_tick(view_tick: float, is_server: bool) -> float:
	# The host's own shots too: it sees remote players slightly in the past as well (_buffered_pose).
	if not is_server or control == Mode.PUPPET or world == null or not world.lag_comp_enabled or view_tick <= 0.0:
		return -1.0
	var now := float(world.server_tick + 1)
	return clampf(view_tick, now - LagComp.MAX_REWIND_TICKS, now)


## A shot's path: the first thing hit - level, player (rewound to `tick` when >= 0) or training target. With
## `penetration` > 0 it goes through one penetrable cover (Block.penetrable) up to that thick: then "through" is true
## for what it hits behind, and "entry" is where it went in.
func _trace(origin: Vector3, dir: Vector3, max_range: float, tick: float = -1.0, penetration := 0.0) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var end := origin + dir * max_range
	var world_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, Layers.WORLD))
	var best := max_range
	var pierced_at := INF  # distance where the bullet went into the cover it went through
	var result := {"pos": end, "normal": -dir, "hit": false, "player": null, "zone": "", "through": false}
	if not world_hit.is_empty():
		var entry: Vector3 = world_hit["position"]
		var exit := _cover_exit(world_hit["collider"], entry, dir, penetration)
		if exit.is_finite():
			pierced_at = origin.distance_to(entry)
			var behind := space.intersect_ray(PhysicsRayQueryParameters3D.create(exit + dir * 0.01, end, Layers.WORLD))
			if not behind.is_empty():
				best = origin.distance_to(behind["position"])
				result = {"pos": behind["position"], "normal": behind["normal"], "hit": true, "player": null, "zone": "",
						"collider": behind["collider"]}
			result["through"] = true
			result["entry"] = entry
		else:
			best = origin.distance_to(entry)
			result = {"pos": entry, "normal": world_hit["normal"], "hit": true, "player": null, "zone": "",
					"through": false, "collider": world_hit["collider"]}
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
		var t_body := LagComp.ray_capsule(origin, dir, seg[0], seg[1], LagComp.BODY_RADIUS)
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
			result = {"pos": origin + dir * t, "normal": -dir, "hit": true, "player": other, "zone": zone,
					"through": t > pierced_at, "entry": result.get("entry", Vector3.INF)}
	# Training targets: the same hitboxes, always at their live position (they are not networked).
	for node in get_tree().get_nodes_in_group(Target.GROUP):
		var target := node as Target
		if not target.alive:
			continue
		var t_state := target.hitbox_state()
		var t_head := LagComp.ray_sphere(origin, dir, LagComp.head_center(t_state), LagComp.HEAD_RADIUS)
		var t_seg := LagComp.body_segment(t_state)
		var t_body := LagComp.ray_capsule(origin, dir, t_seg[0], t_seg[1], LagComp.BODY_RADIUS)
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
					"target": target, "through": t_hit > pierced_at, "entry": result.get("entry", Vector3.INF)}
	return result


## Where a bullet that went into `collider` at `entry` comes out of it, or INF if it does not: the collider is not
## penetrable cover, or is thicker than `penetration` (found by a ray back from that far inside).
func _cover_exit(collider: Object, entry: Vector3, dir: Vector3, penetration: float) -> Vector3:
	if penetration <= 0.0 or not (collider is Block and (collider as Block).penetrable):
		return Vector3.INF
	var from := entry + dir * penetration
	var query := PhysicsRayQueryParameters3D.create(from, entry, Layers.WORLD)
	var back := get_world_3d().direct_space_state.intersect_ray(query)
	if back.is_empty() or back["collider"] != collider:
		return Vector3.INF  # still inside it that far in (a ray started inside a shape does not hit it)
	return back["position"]


func _target_state(other: Player, tick: float) -> Dictionary:
	if tick >= 0.0:
		return world.lag_comp.sample(other.peer_id, tick)
	return other.hitbox_state()


## What the hitboxes depend on (LagComp): position, stance, facing, aim pitch, velocity and aiming.
## Puppets report their displayed state, the server its simulation.
func hitbox_state() -> Dictionary:
	var vel := velocity if control != Mode.PUPPET else _puppet_velocity
	return {"pos": global_position, "crouched": is_crouched, "yaw": rotation.y, "pitch": _head.rotation.x,
			"vel": Vector3(vel.x, 0.0, vel.z), "ads": aiming, "sliding": is_sliding}


## A shot that ended at `end` (world) jerks this player's body if it ended on it (cosmetic).
func react_to_shot(origin: Vector3, end: Vector3) -> void:
	if not is_local:
		_visual.react_to_shot(origin, end)


## Cosmetics of somebody else's shot (called by World on clients and on the host).
func show_remote_shot(weapon: int, origin: Vector3, ends: PackedVector3Array) -> void:
	var def := weapons.def_at(weapon)  # with this player's modules (their build is known everywhere)
	if world != null and world.kill_cam != null:
		world.kill_cam.record_shot(peer_id, weapon, origin, ends)
	_visual.set_weapon(weapon, def)
	Audio.play(def.sound_shot, origin, def.loudness)
	var scene_root := get_tree().current_scene
	var muzzle := _visual.muzzle_global_position()
	_visual.show_shot(def.muzzle_flash)  # a suppressor (weapons.cfg): no flash, no light, no trail - only the hit shows
	if def.muzzle_flash:
		MuzzleLights.flash(self, muzzle)
	for i in ends.size():
		if def.tracer:
			ShotEffects.spawn_tracer(scene_root, muzzle, ends[i])
		ShotEffects.spawn_impact(scene_root, ends[i], Vector3.UP)
		if world != null:
			for id in world.players:
				if id != peer_id:
					(world.players[id] as Player).react_to_shot(origin, ends[i])
		if i < 2:  # a shotgun blast would otherwise play eight impacts at once
			Audio.play("impact", ends[i])


## Local player: the server confirmed that one of our shots damaged somebody.
func on_hit_confirmed(killed: bool, head: bool) -> void:
	if _crosshair:
		_crosshair.show_hit(killed, head)
	Audio.play("kill" if killed else "hit")
