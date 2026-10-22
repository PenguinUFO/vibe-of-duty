class_name WeaponSim
extends RefCounted
## Deterministic per-player weapon state machine, advanced once per physics tick from a PlayerCmd.
## Client and server run the same code, so ammo, cooldowns, spread and recoil can be predicted and
## replayed during reconciliation. All randomness is seeded from (peer_id, shot counter).

const MAX_RECOIL := 0.2  # rad
## Hoof punch (the hands slot, Docs/LOADOUT.md): wind-up, the blow, recovery. No shooting, aiming or reloading
## meanwhile; it cancels a reload (the magazine is not lost, the reload starts over).
const MELEE := -2              # "weapon" index of a punch in damage and kill events (-1 = suicide)
const MELEE_WINDUP := 0.15     # s from the press to the blow
const MELEE_RECOVER := 0.5     # s after the blow until the gun is back
const MELEE_DAMAGE := 75.0     # 2 punches kill (150 HP)
const MELEE_RANGE := 2.0       # m from the eye
const MELEE_NAME := "копыто"   # kill feed

var index := 0
var mags := PackedInt32Array()
var reserves := PackedInt32Array()
var cooldown := 0       # ticks until the next shot is allowed
var reload_ticks := 0   # ticks left in the current reload (0 = not reloading)
var switch_ticks := 0   # ticks left in the current equip animation
var shots := 0          # shots fired so far (seeds spread)
var ads := 0.0          # 0..1 aim-down-sights blend
var recoil := Vector2.ZERO  # x: view pitch kick, y: view yaw kick (rad)
var fire_prev := false
var melee_ticks := 0    # ticks left in the current punch (0 = not punching)
## Reloads do not use up the reserve (training: the range never runs dry). Set the same on the client and the
## server (training is played alone, both are this machine); not part of to_array.
var infinite_reserve := false


func _init() -> void:
	reset()


func reset() -> void:
	index = 0
	mags = PackedInt32Array()
	reserves = PackedInt32Array()
	for i in WeaponDB.count():
		mags.append(WeaponDB.get_def(i).mag_size)
		reserves.append(WeaponDB.get_def(i).reserve_start)
	cooldown = 0
	reload_ticks = 0
	switch_ticks = 0
	shots = 0
	ads = 0.0
	recoil = Vector2.ZERO
	fire_prev = false
	melee_ticks = 0


static func melee_total_ticks() -> int:
	return roundi((MELEE_WINDUP + MELEE_RECOVER) * 60.0)


static func melee_windup_ticks() -> int:
	return roundi(MELEE_WINDUP * 60.0)


func current() -> WeaponDef:
	return WeaponDB.get_def(index)


func is_reloading() -> bool:
	return reload_ticks > 0


func is_equipping() -> bool:
	return switch_ticks > 0


func is_meleeing() -> bool:
	return melee_ticks > 0


## Punch progress 0..1 (-1: none); the blow lands at MELEE_WINDUP / (MELEE_WINDUP + MELEE_RECOVER).
func melee_progress() -> float:
	return 1.0 - float(melee_ticks) / float(melee_total_ticks()) if melee_ticks > 0 else -1.0


func reload_progress() -> float:
	return 1.0 - float(reload_ticks) / float(current().reload_ticks()) if reload_ticks > 0 else -1.0


func equip_progress() -> float:
	return 1.0 - float(switch_ticks) / float(current().equip_ticks()) if switch_ticks > 0 else -1.0


## True if holding fire this tick would shoot (used to cancel sprinting).
func wants_fire(cmd: PlayerCmd) -> bool:
	return cmd.fire and mags[index] > 0 and reload_ticks == 0 and switch_ticks == 0 and melee_ticks == 0


func speed_mult() -> float:
	return lerpf(1.0, current().ads_move_mult, ads)


## Current cone half angle in radians for the HUD crosshair and for shooting.
func spread_angle(speed: float, crouched: bool, airborne: bool) -> float:
	var def := current()
	var s := lerpf(def.spread_hip, def.spread_ads, ads)
	s += def.spread_move * clampf(speed / 5.0, 0.0, 1.6) * (1.0 - 0.6 * ads)
	if airborne:
		s += def.spread_air
	if crouched:
		s *= 0.7
	return s


## Advances one tick. ctx: {peer_id, speed, crouched, airborne, sprinting, sliding}.
## Returns events: {"type": "shot", "weapon": int, "dirs": Array[Vector3]}, "dry", "reload_start", "reload_end", "equip",
## "melee_start", {"type": "melee", "pitch": float, "yaw": float} (the blow).
func tick(cmd: PlayerCmd, dt: float, ctx: Dictionary) -> Array:
	var events: Array = []
	var def := current()

	cooldown = maxi(cooldown - 1, 0)
	if switch_ticks > 0:
		switch_ticks -= 1
	if reload_ticks > 0:
		reload_ticks -= 1
		if reload_ticks == 0:
			var take := mini(def.mag_size - mags[index], reserves[index])
			mags[index] += take
			if not infinite_reserve:
				reserves[index] -= take
			events.append({"type": "reload_end"})

	# Hoof punch: the blow lands MELEE_WINDUP after the press, aimed where the player looks at that moment.
	if melee_ticks > 0:
		melee_ticks -= 1
		if melee_ticks == melee_total_ticks() - melee_windup_ticks():
			events.append({"type": "melee", "pitch": cmd.pitch, "yaw": cmd.yaw})
	elif cmd.melee and switch_ticks == 0 and not ctx["sliding"]:
		melee_ticks = melee_total_ticks()
		reload_ticks = 0
		events.append({"type": "melee_start"})

	# Weapon switch.
	if melee_ticks == 0 and cmd.select >= 0 and cmd.select != index and cmd.select < WeaponDB.count():
		index = cmd.select
		def = current()
		switch_ticks = def.equip_ticks()
		reload_ticks = 0
		cooldown = maxi(cooldown, def.equip_ticks())
		ads = 0.0
		events.append({"type": "equip"})

	# Aim down sights (not while sprinting, reloading or equipping).
	var want_ads: bool = cmd.aim and switch_ticks == 0 and reload_ticks == 0 and melee_ticks == 0 and not ctx["sprinting"]
	ads = move_toward(ads, 1.0 if want_ads else 0.0, dt / def.ads_time)

	# Manual reload.
	if cmd.reload and reload_ticks == 0 and switch_ticks == 0 and melee_ticks == 0 and mags[index] < def.mag_size and reserves[index] > 0:
		reload_ticks = def.reload_ticks()
		events.append({"type": "reload_start"})

	# Fire.
	var fired := false
	if cmd.fire and switch_ticks == 0 and reload_ticks == 0 and melee_ticks == 0 and cooldown == 0 and (def.automatic or not fire_prev):
		if mags[index] > 0:
			fired = true
			mags[index] -= 1
			shots += 1
			cooldown = def.fire_ticks()
			var angle := spread_angle(ctx["speed"], ctx["crouched"], ctx["airborne"])
			var rng := RandomNumberGenerator.new()
			var dirs: Array[Vector3] = []
			for i in def.pellets:
				rng.seed = hash([ctx["peer_id"], shots, i])
				dirs.append(_spread_dir(cmd.pitch + recoil.x, cmd.yaw + recoil.y, angle, rng))
			events.append({"type": "shot", "weapon": index, "dirs": dirs})
			rng.seed = hash([ctx["peer_id"], shots, 99])
			recoil.x = minf(recoil.x + def.recoil_pitch * (1.0 - 0.35 * ads), MAX_RECOIL)
			recoil.y = clampf(recoil.y + rng.randf_range(-1.0, 1.0) * def.recoil_yaw, -MAX_RECOIL, MAX_RECOIL)
		else:
			if not fire_prev:
				events.append({"type": "dry"})
			if reserves[index] > 0:  # empty magazine: reload automatically
				reload_ticks = def.reload_ticks()
				events.append({"type": "reload_start"})
	fire_prev = cmd.fire

	if not fired and cooldown == 0:
		recoil = recoil.move_toward(Vector2.ZERO, def.recoil_recover * dt)
	return events


## Direction for view angles (pitch, yaw) with a random offset inside a cone of half angle `angle`.
static func _spread_dir(pitch: float, yaw: float, angle: float, rng: RandomNumberGenerator) -> Vector3:
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var theta := rng.randf() * TAU
	var r := sqrt(rng.randf()) * angle
	var local := Vector3(sin(r) * cos(theta), sin(r) * sin(theta), -cos(r))
	return (basis * local).normalized()


func to_array() -> Array:
	return [index, Array(mags), Array(reserves), cooldown, reload_ticks, switch_ticks, shots, ads, recoil, fire_prev,
			melee_ticks]


func from_array(a: Array) -> void:
	index = a[0]
	mags = PackedInt32Array(a[1])
	reserves = PackedInt32Array(a[2])
	cooldown = a[3]
	reload_ticks = a[4]
	switch_ticks = a[5]
	shots = a[6]
	ads = a[7]
	recoil = a[8]
	fire_prev = a[9]
	melee_ticks = a[10]
