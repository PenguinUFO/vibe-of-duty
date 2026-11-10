class_name PlayerHealth
extends PlayerMovement
## Player, part 5 of 9: damage, regeneration, death, respawn, ammo pickup, kid mode, oink.
## The parts form a chain of scripts, each extending the previous one (map: player.gd).

## Server: applies damage; returns true if this killed the player. `regen_block`: health does not come back for at least
## this long (a wounding weapon, WeaponDef.regen_block).
func server_damage(amount: float, regen_block := 0.0) -> bool:
	if not alive:
		return false
	health = maxi(health - roundi(amount), 0)
	_regen_wait = maxf(regen_delay, maxf(regen_block, _regen_wait))
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


## Server, every tick: health comes back regen_delay s (kid mode: shorter) after the last damage, REGEN_PER_SECOND HP per second.
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
		healed_total += mini(whole, max_health - health)
		health = mini(health + whole, max_health)
		_regen_carry -= whole


## Server: picks up an ammo bag - one magazine more for the weapon in the hands (the only one of the build), up to its
## reserve_max. False (the bag stays) when its reserve is already full. The owner's client learns of it through the
## weapon state in the snapshots (its prediction is corrected, as for any server-side change).
func server_take_ammo() -> bool:
	if not alive:
		return false
	var def := weapons.current()
	var room := def.reserve_max - weapons.reserves[weapons.index]
	if room <= 0:
		return false
	weapons.reserves[weapons.index] += mini(def.mag_size, room)
	bags_total += 1
	return true


## Kid mode (Settings.toughness: sent to the server on join and whenever the player changes it, even mid-match):
## t = (max health, regeneration delay, damage multiplier from behind). Current health keeps its share of the maximum.
func set_toughness(t: Vector3) -> void:
	t = clamp_toughness(t)
	var old_max := max_health
	base_max_health = int(t.x)
	base_regen_delay = t.y
	back_damage = t.z
	_apply_stats()
	if health > 0:
		health = clampi(roundi(health * float(max_health) / old_max), 1, max_health)
	_last_health = health


## The build for this life (PartDB part ids; sanitized here): the weapon with its modules. Called right before respawn
## (NetWorld._apply_respawn), the same on every machine.
func set_build(parts: Array) -> void:
	build = PartDB.sanitize(parts)
	weapons.defs.clear()
	for i in WeaponDB.count():
		weapons.defs.append(WeaponDB.make_def(i, PartDB.weapon_modules(build)))
	weapons.build_weapon = WeaponDB.index_of(build[0])
	weapons.reset()  # the weapon, its magazine and reserve as built (a first spawn has no respawn to reset them)
	if Game.dry_reserve:
		weapons.reserves.fill(0)
	_apply_stats()
	health = mini(health, max_health)


## Max health and regeneration delay: kid mode's ("Хардкор": HARDCORE_HEALTH for everybody).
func _apply_stats() -> void:
	max_health = base_max_health
	if Game.hardcore and not Game.training:
		max_health = HARDCORE_HEALTH
	regen_delay = base_regen_delay
	_regen_wait = minf(_regen_wait, regen_delay)


## What the server accepts from a player: no less health, no slower regeneration and no more damage than normal.
static func clamp_toughness(t: Vector3) -> Vector3:
	if not t.is_finite():
		t = Vector3(MAX_HEALTH, REGEN_DELAY, 1.0)  # clampf passes NaN on
	return Vector3(clampf(roundf(t.x), MAX_HEALTH, KID_HEALTH_MAX), clampf(t.y, 0.0, REGEN_DELAY), clampf(t.z, 0.0, 1.0))


## Server: damage multiplier for a shot fired from `from` (world). Kid mode takes less from behind: none at the
## sides (90 deg off the view: body_yaw, the yaw of the last command), fading to back_damage at BACK_FULL_ANGLE and
## beyond.
func damage_mult_from(from: Vector3) -> float:
	if back_damage >= 1.0:
		return 1.0
	var to := Gravity.frame(global_position).inverse() * (from - global_position)  # in the frame, like the yaw
	if Vector2(to.x, to.z).length() < 0.01:
		return 1.0
	var off := absf(angle_difference(body_yaw, AimAssist.yaw_of(Vector3(to.x, 0.0, to.z).normalized())))
	var behind := clampf((off - PI / 2.0) / (BACK_FULL_ANGLE - PI / 2.0), 0.0, 1.0)
	return lerpf(1.0, back_damage, behind)


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
	if Game.dry_reserve:  # test: the magazine only, then the ЧМП
		weapons.reserves.fill(0)
	teleport(xform)
	_visual.set_dead(false)
	_visual.set_akimbo(weapons.is_akimbo(), false)  # a new life: the left gun is back in the hand, nothing thrown
	_puppet_akimbo = weapons.is_akimbo()
	if _view:
		_view.set_weapon(weapons.index, weapons.current())
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
## (NetWorld.server_oink, which also enforces the cooldown). One press in FART_CHANCE farts instead; the presser
## rolls it, so everyone hears the same thing.
func _try_oink() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not alive or world == null or now < _next_oink:
		return
	_next_oink = now + NetWorld.OINK_COOLDOWN
	var fart := randf() < NetWorld.FART_CHANCE
	play_oink(fart)
	if multiplayer.is_server():
		world.server_oink(peer_id, fart)
	else:
		world.request_oink.rpc_id(1, fart)


## Snort or fart (audioSFX/player); others hear it from where the head is.
func play_oink(fart: bool = false) -> void:
	var voice := "pig fart" if fart else "pig snort"
	if not is_local:
		Game.count("oinks_heard")
	if Game.net_log:
		print("[%d] oink from %d (%s)" % [multiplayer.get_unique_id(), peer_id, voice])
	Audio.play(voice, null if is_local else global_position + Vector3.UP * 1.5)
