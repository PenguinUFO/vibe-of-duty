class_name WeaponSim
extends RefCounted
## Deterministic per-player weapon state machine, advanced once per physics tick from a PlayerCmd.
## Client and server run the same code, so ammo, cooldowns, spread and recoil can be predicted and
## replayed during reconciliation. All randomness is seeded from (peer_id, shot counter).

const MAX_RECOIL := 0.2  # rad
## A semi-automatic weapon: a press this long (s) before the next shot is allowed is kept and fires then, held or not
## (fire_queued) - a tap during the cooldown is not lost.
const FIRE_BUFFER := 0.2
## Hoof punch (the hands slot, Docs/LOADOUT.md): wind-up, the blow, recovery. No shooting, aiming or reloading
## meanwhile; it cancels a reload (the magazine is not lost, the reload starts over).
const MELEE := -2              # "weapon" index of a punch in damage and kill events (-1 = suicide)
const MELEE_WINDUP := 0.15     # s from the press to the blow
const MELEE_RECOVER := 0.5     # s after the blow until the gun is back
const MELEE_DAMAGE := 100.0    # 2 punches kill (150 HP)
const MELEE_RANGE := 0.9       # m from the eye
const MELEE_PAD := 0.1         # m a punch widens the body by (PlayerWeapons._trace)
const MELEE_NAME := "копыто"   # kill feed
const PIG_ARMS_NAME := "Хрюкаут"  # kill feed: a punch of the "Руки-Хрюки"
## The "Гренадир"'s grenade (Docs/LOADOUT.md): G down - the cannon comes out of the chest and stays out while G is
## held; G up - it launches (not before it is all the way out) and folds back. No shooting, aiming or reloading
## meanwhile; a reload pauses and goes on after. One a life (grenades_max), not refilled.
const GRENADE := -3            # "weapon" index of a grenade in damage and kill events
const GRENADE_OUT := 0.15      # s from the press to the launch
const GRENADE_BACK := 0.2      # s after the launch until the gun is back
const GRENADE_NAME := "граната"  # kill feed
## The "Черепно-мозговой пистолет" (Docs/LOADOUT.md): a gun in the left eye socket with endless rounds, weak. It takes
## over when the weapon is empty to the last round of its reserve and gives it back once a reload (R, by hand) puts
## rounds in it. From the hip only; it fires while the hands reload. Training (endless reserve): the key 1 toggles it.
const CMP := -4                # "weapon" index of its shots in damage and kill events (its numbers: WeaponDB.cmp_def)
const CMP_NAME := "ЧМП"        # kill feed
const BOMB := -5               # "weapon" index of the "Хрях-бабах" in damage and kill events
const BOMB_NAME := "хрях-бабах"  # kill feed
## Akimbo (WeaponDef.akimbo, Docs/LOADOUT.md): a copy of the weapon in the left hand with one magazine, fired by the
## aim button (cmd.aim), never reloaded. Empty - or R, which then reloads the right one - it is thrown away and the
## weapon plays as usual again. Meanwhile no sights, no punch, the spread x akimbo_spread; an empty right one only
## clicks (no reload by itself: that would throw the left one away).

var index := 0
var mags := PackedInt32Array()
var reserves := PackedInt32Array()
var cooldown := 0.0     # ticks until the next shot is allowed (fractional: a shot adds its interval, the rest carries)
var burst := 0          # ticks the trigger has held a weapon that can fire (WeaponDef.fire_ticks: a ramping rate)
var reload_ticks := 0   # ticks left in the current reload (0 = not reloading)
var switch_ticks := 0   # ticks left in the current equip animation
var shots := 0          # shots fired so far (seeds spread)
var ads := 0.0          # 0..1 aim-down-sights blend
var recoil := Vector2.ZERO  # x: view pitch kick, y: view yaw kick (rad)
## The part of `recoil` the player has pulled against with the look while firing (same signs as recoil, never more).
## It does not come back: when the recovery starts it moves from the kick into the look (look_shift), so the view stays
## where the player held it and only the rest returns. Untouched recoil returns in full, as before.
var recoil_held := Vector2.ZERO
var look_prev := Vector2.ZERO  # (pitch, yaw) of the last tick's command
var look_known := false        # look_prev is set (not on the first tick of a life)
## Out of this tick, not state: how much the owner's look (pitch, yaw) must turn so the view stays put, the held recoil
## having been taken out of `recoil` (Player applies it to look_pitch / look_yaw; the server's next commands carry it).
var look_shift := Vector2.ZERO
var fire_prev := false
var fire_queued := false  # a semi-automatic press during the cooldown, fires when it ends (FIRE_BUFFER)
var melee_ticks := 0    # ticks left in the current punch (0 = not punching)
var grenades := 0       # grenades left this life
var grenade_ticks := 0  # ticks left in the current launch (0 = not launching); held at the launch while G is down
var cmp := false        # the ЧМП shoots instead of the weapon
var left_mag := 0       # rounds in the akimbo's left gun (0: none in the hand)
var left_cooldown := 0.0  # the left gun's cooldown, burst, trigger and queued press: as the right one's above
var left_burst := 0
var left_prev := false
var left_queued := false
## Reloads do not use up the reserve (training: the range never runs dry). Set the same on the client and the
## server (training is played alone, both are this machine); not part of to_array.
var infinite_reserve := false
## The build's weapon numbers (Player.set_build, PartDB.DEFAULT_MODS): set the same on every machine when the player
## (re)spawns, constant for a life; not part of to_array.
var reload_mult := 1.0
var ads_time_mult := 1.0
var spread_hip_mult := 1.0
var spread_ads_mult := 1.0
## This player's weapons with the build's modules (WeaponDB.make_def), by weapon index; empty: the base ones.
var defs: Array[WeaponDef] = []
## The build's weapon (WeaponDB index): the only one the player holds (one weapon per build, Docs/LOADOUT.md), set
## with defs. Switching to another is refused; PlayerCmd.select stays for a second weapon some day.
var build_weapon := 0
## Grenades a life starts with (the build's PartDB.GRENADIER: 1), set with defs; not part of to_array.
var grenades_max := 0
## The build has the ЧМП (PartDB.SKULL_PISTOL), set with defs; not part of to_array.
var cmp_part := false


func _init() -> void:
	reset()


func reset() -> void:
	index = build_weapon
	mags = PackedInt32Array()
	reserves = PackedInt32Array()
	for i in WeaponDB.count():
		mags.append(def_at(i).mag_size)
		reserves.append(def_at(i).reserve_start)
	cooldown = 0.0
	burst = 0
	reload_ticks = 0
	switch_ticks = 0
	shots = 0
	ads = 0.0
	recoil = Vector2.ZERO
	recoil_held = Vector2.ZERO
	look_known = false
	look_shift = Vector2.ZERO
	fire_prev = false
	fire_queued = false
	melee_ticks = 0
	grenades = grenades_max
	grenade_ticks = 0
	cmp = false
	left_mag = current().mag_size if current().akimbo else 0
	left_cooldown = 0.0
	left_burst = 0
	left_prev = false
	left_queued = false


static func melee_total_ticks() -> int:
	return roundi((MELEE_WINDUP + MELEE_RECOVER) * 60.0)


static func melee_windup_ticks() -> int:
	return roundi(MELEE_WINDUP * 60.0)


static func grenade_total_ticks() -> int:
	return roundi((GRENADE_OUT + GRENADE_BACK) * 60.0)


static func grenade_out_ticks() -> int:
	return roundi(GRENADE_OUT * 60.0)


func current() -> WeaponDef:
	return def_at(index)


func def_at(weapon: int) -> WeaponDef:
	if weapon == CMP:
		return WeaponDB.cmp_def()
	return defs[weapon] if weapon >= 0 and weapon < defs.size() else WeaponDB.get_def(weapon)


## What a pull of the trigger shoots: the ЧМП when it is on, else the weapon.
func firing_def() -> WeaponDef:
	return WeaponDB.cmp_def() if cmp else current()


func is_reloading() -> bool:
	return reload_ticks > 0


func is_equipping() -> bool:
	return switch_ticks > 0


func is_meleeing() -> bool:
	return melee_ticks > 0


## The akimbo's left gun is in the hand.
func is_akimbo() -> bool:
	return left_mag > 0


func is_launching() -> bool:
	return grenade_ticks > 0


## The cannon is out and waits for G to be let go.
func is_grenade_ready() -> bool:
	return grenade_ticks > 0 and grenade_ticks == grenade_total_ticks() - grenade_out_ticks()


## Launch progress 0..1 (-1: none); the grenade leaves at GRENADE_OUT / (GRENADE_OUT + GRENADE_BACK).
func grenade_progress() -> float:
	return 1.0 - float(grenade_ticks) / float(grenade_total_ticks()) if grenade_ticks > 0 else -1.0


## Punch progress 0..1 (-1: none); the blow lands at MELEE_WINDUP / (MELEE_WINDUP + MELEE_RECOVER).
func melee_progress() -> float:
	return 1.0 - float(melee_ticks) / float(melee_total_ticks()) if melee_ticks > 0 else -1.0


func reload_progress() -> float:
	return 1.0 - float(reload_ticks) / float(_reload_ticks()) if reload_ticks > 0 else -1.0


func equip_progress() -> float:
	return 1.0 - float(switch_ticks) / float(current().equip_ticks()) if switch_ticks > 0 else -1.0


## True if holding fire this tick would shoot (used to cancel sprinting).
func wants_fire(cmd: PlayerCmd) -> bool:
	return cmd.fire and (cmp or mags[index] > 0 and reload_ticks == 0) and switch_ticks == 0 and melee_ticks == 0 \
			and grenade_ticks == 0


func speed_mult() -> float:
	return current().move_speed_mult * lerpf(1.0, current().ads_move_mult, ads)


## Current cone half angle in radians for the HUD crosshair and for shooting.
func spread_angle(speed: float, crouched: bool, airborne: bool) -> float:
	var def := firing_def()
	var hip := def.spread_hip * spread_hip_mult * (def.akimbo_spread if is_akimbo() else 1.0)
	var s := lerpf(hip, def.spread_ads * spread_ads_mult, ads)
	s += def.spread_move * clampf(speed / 5.0, 0.0, 1.6) * (1.0 - 0.6 * ads)
	if airborne:
		s += def.spread_air
	if crouched:
		s *= 0.7
	return s


## Advances one tick. ctx: {peer_id, speed, crouched, airborne, sprinting, sliding, mantling}.
## Returns events: {"type": "shot", "weapon": int, "dirs": Array[Vector3]}, "dry", "reload_start", "reload_end", "equip",
## "melee_start", {"type": "melee", "pitch": float, "yaw": float} (the blow), "grenade_start",
## {"type": "grenade", "pitch": float, "yaw": float} (the launch), {"type": "akimbo_drop", "rounds": int} (the left gun thrown away, with
## this many still in it: 0 - emptied, more - R); a shot of the
## akimbo's left gun has "left": true.
func tick(cmd: PlayerCmd, dt: float, ctx: Dictionary) -> Array:
	var events: Array = []
	var def := current()
	_track_held(cmd)

	if cooldown > 0.0:
		cooldown -= 1.0
	if left_cooldown > 0.0:
		left_cooldown -= 1.0
	if switch_ticks > 0:
		switch_ticks -= 1
	if reload_ticks > 0 and def.reload_single and cmd.fire and not fire_prev and mags[index] > 0 and grenade_ticks == 0:
		reload_ticks = 0  # a tube magazine: a shot stops the loading, what is in stays
		events.append({"type": "reload_end"})
	if reload_ticks > 0 and grenade_ticks == 0:  # a launch pauses the reload
		reload_ticks -= 1
		if reload_ticks == 0:
			var take := mini(def.mag_size - mags[index], reserves[index])
			if def.reload_single:
				take = mini(take, 1)
			mags[index] += take
			if not infinite_reserve:
				reserves[index] -= take
			if def.reload_single and mags[index] < def.mag_size and reserves[index] > 0:
				reload_ticks = _reload_ticks()  # the next round
			else:
				events.append({"type": "reload_end"})

	# The ЧМП: on with the weapon empty to the last round, off once a reload put rounds in it. Training never runs dry:
	# there the key 1 (cmd.cmp) toggles it.
	if cmp_part:
		if infinite_reserve:
			if cmd.cmp:
				cmp = not cmp
		elif not cmp and mags[index] == 0 and reserves[index] == 0 and left_mag == 0:
			cmp = true
		elif cmp and mags[index] > 0:
			cmp = false

	# Grenade: the cannon is out GRENADE_OUT after G goes down and stays out while it is held; it fires when G is let go
	# (owner, 2026-11-02), aimed where the player looks at that moment. Not while vaulting (the hands are on the ledge)
	# or punching.
	if grenade_ticks > 0:
		if is_grenade_ready() and cmd.grenade:
			pass  # held: the cannon waits
		elif is_grenade_ready():
			grenade_ticks -= 1
			events.append({"type": "grenade", "pitch": cmd.pitch, "yaw": cmd.yaw})
		else:
			grenade_ticks -= 1
			if is_grenade_ready() and not cmd.grenade:
				grenade_ticks -= 1  # let go before it was out: it fires the moment it is
				events.append({"type": "grenade", "pitch": cmd.pitch, "yaw": cmd.yaw})
	elif cmd.grenade and grenades > 0 and melee_ticks == 0 and switch_ticks == 0 and not ctx["mantling"]:
		grenades -= 1
		grenade_ticks = grenade_total_ticks()
		events.append({"type": "grenade_start"})

	# Hoof punch: the blow lands MELEE_WINDUP after the press, aimed where the player looks at that moment.
	if melee_ticks > 0:
		melee_ticks -= 1
		if melee_ticks == melee_total_ticks() - melee_windup_ticks():
			events.append({"type": "melee", "pitch": cmd.pitch, "yaw": cmd.yaw})
	elif cmd.melee and switch_ticks == 0 and grenade_ticks == 0 and left_mag == 0 and not ctx["sliding"]:
		melee_ticks = melee_total_ticks()
		reload_ticks = 0
		events.append({"type": "melee_start"})

	# Weapon switch.
	if melee_ticks == 0 and grenade_ticks == 0 and cmd.select >= 0 and cmd.select != index and cmd.select == build_weapon:
		index = cmd.select
		def = current()
		switch_ticks = def.equip_ticks()
		reload_ticks = 0
		cooldown = maxf(cooldown, float(def.equip_ticks()))
		ads = 0.0
		events.append({"type": "equip"})

	# Aim down sights (not while sprinting, reloading or equipping).
	var want_ads: bool = cmd.aim and not cmp and left_mag == 0 and switch_ticks == 0 and reload_ticks == 0 and melee_ticks == 0 and grenade_ticks == 0 \
			and not ctx["sprinting"]
	ads = move_toward(ads, 1.0 if want_ads else 0.0, dt / (def.ads_time * ads_time_mult))

	# Manual reload.
	if cmd.reload and reload_ticks == 0 and switch_ticks == 0 and melee_ticks == 0 and grenade_ticks == 0 \
			and mags[index] < def.mag_size and reserves[index] > 0:
		if left_mag > 0:
			_drop_left(events)  # the hand is needed for the reload
		reload_ticks = _reload_ticks()
		events.append({"type": "reload_start"})

	# Fire (the ЧМП's while the hands reload too).
	var fired := false
	var gun := firing_def()
	burst = burst + 1 if wants_fire(cmd) else 0
	if gun.automatic or switch_ticks > 0 or (reload_ticks > 0 and not cmp) or melee_ticks > 0 or grenade_ticks > 0:
		fire_queued = false
	elif cmd.fire and not fire_prev and cooldown > 0.0 and cooldown <= FIRE_BUFFER * 60.0:
		fire_queued = true
	if (cmd.fire or fire_queued) and switch_ticks == 0 and (reload_ticks == 0 or cmp) and melee_ticks == 0 and grenade_ticks == 0 \
			and cooldown <= 0.0 and (gun.automatic or not fire_prev or fire_queued):
		fire_queued = false
		if cmp or mags[index] > 0:
			fired = true
			if not cmp:
				mags[index] -= 1
			cooldown += gun.fire_ticks(burst / 60.0)
			events.append(_shot(cmd, ctx, gun, false))
		else:
			if not fire_prev:
				events.append({"type": "dry"})
			if reserves[index] > 0 and left_mag == 0:  # empty magazine: reload automatically
				reload_ticks = _reload_ticks()
				events.append({"type": "reload_start"})
	fire_prev = cmd.fire

	# The akimbo's left gun: the aim button is its trigger (the same rules as the right one's above).
	var left_fired := false
	if left_mag > 0:
		var can_fire := switch_ticks == 0 and melee_ticks == 0 and grenade_ticks == 0
		left_burst = left_burst + 1 if cmd.aim and can_fire else 0
		if gun.automatic or not can_fire:
			left_queued = false
		elif cmd.aim and not left_prev and left_cooldown > 0.0 and left_cooldown <= FIRE_BUFFER * 60.0:
			left_queued = true
		if (cmd.aim or left_queued) and can_fire and left_cooldown <= 0.0 and (gun.automatic or not left_prev or left_queued):
			left_queued = false
			left_fired = true
			left_mag -= 1
			left_cooldown += gun.fire_ticks(left_burst / 60.0)
			events.append(_shot(cmd, ctx, gun, true))
			if left_mag == 0:
				_drop_left(events)  # empty: thrown away
	left_prev = cmd.aim

	if not fired:
		cooldown = maxf(cooldown, 0.0)  # the carried remainder is for a burst, not a credit after a pause
	if not left_fired:
		left_cooldown = maxf(left_cooldown, 0.0)
	if not fired and not left_fired and cooldown == 0.0 and left_cooldown == 0.0:
		if recoil_held != Vector2.ZERO:  # what was pulled against stays: it moves from the kick into the look
			recoil -= recoil_held
			look_shift = recoil_held
			look_prev += recoil_held  # the next command's look already has it
			recoil_held = Vector2.ZERO
		recoil = recoil.move_toward(Vector2.ZERO, gun.recoil_recover * dt)
	return events


## In a burst (the trigger held, a cooldown running), the look's motion against the kick (down against the kick up, sideways against
## the side one) counts as held recoil; with it again lets it go. Never more than the kick itself. Once the shots stop,
## the look moves freely: pulling down during the return moves the view, it is not taken for holding.
func _track_held(cmd: PlayerCmd) -> void:
	look_shift = Vector2.ZERO
	var look := Vector2(cmd.pitch, cmd.yaw)
	var moved := Vector2(look.x - look_prev.x, angle_difference(look_prev.y, look.y)) if look_known else Vector2.ZERO
	look_prev = look
	look_known = true
	var trigger := cmd.fire or cmd.aim and left_mag > 0
	if not trigger or cooldown <= 0.0 and left_cooldown <= 0.0:  # not in a burst: the look's motion is the player's
		return
	recoil_held.x = _clamp_held(recoil_held.x - moved.x, recoil.x)
	recoil_held.y = _clamp_held(recoil_held.y - moved.y, recoil.y)


static func _clamp_held(held: float, kick: float) -> float:
	return clampf(held, minf(kick, 0.0), maxf(kick, 0.0))


## A shot of `gun` (`left`: the akimbo's left gun) along the view with this tick's spread; the kick goes into the view
## (both guns' into the same one).
func _shot(cmd: PlayerCmd, ctx: Dictionary, gun: WeaponDef, left: bool) -> Dictionary:
	shots += 1
	var angle := spread_angle(ctx["speed"], ctx["crouched"], ctx["airborne"])
	var rng := RandomNumberGenerator.new()
	var dirs: Array[Vector3] = []
	var pitch := cmd.pitch + recoil.x
	var yaw := cmd.yaw + recoil.y
	if gun.pellet_spread > 0.0:
		# A shotgun: the aim's spread moves the whole pattern, the pellets spread round its middle.
		rng.seed = hash([ctx["peer_id"], shots, -1])
		var middle := _spread_dir(pitch, yaw, angle, rng)
		pitch = asin(clampf(middle.y, -1.0, 1.0))
		yaw = atan2(-middle.x, -middle.z)
		angle = gun.pellet_spread
	for i in gun.pellets:
		rng.seed = hash([ctx["peer_id"], shots, i])
		dirs.append(_spread_dir(pitch, yaw, angle, rng))
	rng.seed = hash([ctx["peer_id"], shots, 99])
	recoil.x = minf(recoil.x + gun.recoil_pitch * (1.0 - 0.35 * ads), MAX_RECOIL)
	recoil.y = clampf(recoil.y + rng.randf_range(-1.0, 1.0) * gun.recoil_yaw, -MAX_RECOIL, MAX_RECOIL)
	var event := {"type": "shot", "weapon": CMP if cmp else index, "dirs": dirs}
	if left:
		event["left"] = true
	return event


## The akimbo's left gun out of the hand (empty, or R): the weapon is a single one again.
func _drop_left(events: Array) -> void:
	events.append({"type": "akimbo_drop", "rounds": left_mag})
	left_mag = 0
	left_cooldown = 0.0
	left_burst = 0
	left_queued = false


func _reload_ticks() -> int:
	return maxi(1, roundi(current().reload_ticks() * reload_mult))


## Direction for view angles (pitch, yaw) with a random offset inside a cone of half angle `angle`.
static func _spread_dir(pitch: float, yaw: float, angle: float, rng: RandomNumberGenerator) -> Vector3:
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var theta := rng.randf() * TAU
	var r := sqrt(rng.randf()) * angle
	var local := Vector3(sin(r) * cos(theta), sin(r) * sin(theta), -cos(r))
	return (basis * local).normalized()


func to_array() -> Array:
	return [index, Array(mags), Array(reserves), cooldown, reload_ticks, switch_ticks, shots, ads, recoil, fire_prev,
			melee_ticks, burst, grenades, grenade_ticks, cmp, fire_queued, left_mag, left_cooldown, left_burst, left_prev,
			left_queued, recoil_held, look_prev, look_known]


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
	burst = a[11]
	grenades = a[12]
	grenade_ticks = a[13]
	cmp = a[14]
	fire_queued = a[15]
	left_mag = a[16]
	left_cooldown = a[17]
	left_burst = a[18]
	left_prev = a[19]
	left_queued = a[20]
	recoil_held = a[21]
	look_prev = a[22]
	look_known = a[23]
