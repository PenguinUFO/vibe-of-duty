class_name PlayerHealth
extends PlayerMovement
## Player, part 5 of 9: damage, regeneration, death, respawn, ammo pickup, kid mode, oink.
## The parts form a chain of scripts, each extending the previous one (map: player.gd).

## Server: applies damage; returns true if this killed the player.
func server_damage(amount: float) -> bool:
	if not alive:
		return false
	health = maxi(health - roundi(amount), 0)
	_regen_wait = KID_REGEN_DELAY if kid_mode else REGEN_DELAY
	_regen_carry = 0.0
	if health == 0:
		alive = false
		return true
	return false


## `from`: the killer's position (world; INF if unknown) and `head_hit` - which way and how hard the body falls.
func die(by: String, respawn_delay: float, from := Vector3.INF, head_hit := false) -> void:
	if not alive and respawn_delay <= 0.0:
		return
	alive = false
	health = 0
	killed_by = by
	death_time_left = respawn_delay
	_visual.set_dead(true, from, head_hit)
	Audio.play("death", null if is_local else global_position)


## Server, every tick: health comes back REGEN_DELAY s (kid mode: KID_REGEN_DELAY) after the last damage, REGEN_PER_SECOND HP per second.
## Clients see it in the snapshots (health is part of every player's state).
func server_regen(delta: float) -> void:
	if not alive or health >= max_health:
		_regen_carry = 0.0
		return
	if _regen_wait > 0.0:
		_regen_wait -= delta
		return
	_regen_carry += REGEN_PER_SECOND * delta
	var whole := int(_regen_carry)
	if whole > 0:
		health = mini(health + whole, max_health)
		_regen_carry -= whole


## Server: picks up an ammo bag - one magazine more for every weapon, up to its reserve_max. False (the bag stays)
## when every reserve is already full. The owner's client learns of it through the weapon state in the snapshots
## (its prediction is corrected, as for any server-side change).
func server_take_ammo() -> bool:
	if not alive:
		return false
	var took := false
	for i in WeaponDB.count():
		var def := WeaponDB.get_def(i)
		var room := def.reserve_max - weapons.reserves[i]
		if room > 0:
			weapons.reserves[i] += mini(def.mag_size, room)
			took = true
	return took


## Kid mode (chosen by the player, sent to the server on join): more health. Call before the first respawn / snapshot.
func set_kid_mode(on: bool) -> void:
	kid_mode = on
	max_health = MAX_HEALTH * (KID_HEALTH_MULT if on else 1)
	health = max_health
	_last_health = max_health


func respawn(xform: Transform3D) -> void:
	alive = true
	health = max_health
	_last_health = max_health
	_regen_wait = 0.0
	_regen_carry = 0.0
	killed_by = ""
	death_time_left = 0.0
	if _damage_dirs:
		_damage_dirs.clear()
	_punch = Vector2.ZERO
	_punch_v = Vector2.ZERO
	_cam_land = 0.0
	_cam_land_v = 0.0
	_death_drift = Vector3.ZERO
	_death_drift_v = Vector3.ZERO
	weapons.reset()
	teleport(xform)
	_visual.set_dead(false)
	if _view:
		_view.set_weapon(weapons.index)
	if is_local and world != null and world.kill_cam != null:
		world.kill_cam.stop()
	Audio.play("spawn", null if is_local else global_position)


## Local player: the server says we were just hit by a shooter standing at `from` (for the damage direction arcs).
func on_damaged_from(from: Vector3) -> void:
	if _damage_dirs:
		_damage_dirs.add(from)
	if alive and _camera:
		# The view jolts away from the shooter: pitches up for a hit from the front, rolls for one from the side.
		var local := _camera.global_basis.inverse() * (from - _camera.global_position)
		var flat := Vector2(local.x, local.z)
		if flat.length() > 0.01:
			flat = flat.normalized()
			_punch_v += Vector2(-flat.y * 0.5, flat.x * 0.6)
			_punch_v = _punch_v.limit_length(1.2)


## F / d-pad up: the local player oinks. Heard at once here; the server passes it on to everyone else
## (NetWorld.server_oink, which also enforces the cooldown).
func _try_oink() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not alive or world == null or now < _next_oink:
		return
	_next_oink = now + NetWorld.OINK_COOLDOWN
	play_oink()
	if multiplayer.is_server():
		world.server_oink(peer_id)
	else:
		world.request_oink.rpc_id(1)


## Each player has their own pig voice (by peer id); others hear it from where the head is.
func play_oink() -> void:
	var voice: String = ["oink", "oink2", "oink3"][absi(peer_id) % 3]
	if not is_local:
		Game.count("oinks_heard")
	if Game.net_log:
		print("[%d] oink from %d (%s)" % [multiplayer.get_unique_id(), peer_id, voice])
	Audio.play(voice, null if is_local else global_position + Vector3.UP * 1.5)
