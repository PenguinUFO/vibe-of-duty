class_name WeaponDef
extends RefCounted
## Tuning data for one weapon. Angles are stored in radians, durations in seconds (WeaponSim converts durations to
## physics ticks). The balance numbers come from assets/data/weapons.cfg (WeaponDB.apply_config), with the build's
## modules applied (WeaponDB.make_def); the geometry (model, sights, hands) is set in WeaponDB's code.

var id := ""
var display_name := ""
var info := ""                # one line for the build editor
var scene_path := ""          # model scene (prefabs/weapons); its barrel points to +Z
var model_variants := {}      # group node in the model -> the one child kept (the others go): a module's model
var model_scale := 1.0        # the model drawn this much bigger than life; the points below are already scaled
var finish := ""              # "chrome": the model's metal is chromed (WeaponSkin); "": the usual skins
                              # (WeaponDB), bolt_travel is not (it moves a part inside the model)
var muzzle := Vector3.ZERO    # muzzle position in prefab space (before the 180 deg turn to face -Z)
var rear_sight := Vector3(0.0, 0.17, 0.0)   # top of the rear sight in prefab space (ADS alignment; the post's tip flush with it)
var front_sight := Vector3(0.0, 0.17, 0.5)  # top of the front sight / barrel end in prefab space
var eye_relief := 0.15                       # distance from the camera to the rear sight while aiming (m)
var sight := ""                 # optic on the gun (SightModels; "": iron sights), set by its sight module
var sight_offset := Vector3.ZERO  # the optic's model moved by this (life size: a rail higher than the PDW's)
var scope := false              # a magnified scope: aimed, the view goes through ScopeOverlay, not the model
var right_hand := Vector3(0.0, -0.055, -0.045)  # prefab space: middle of the right palm on the pistol grip
var left_hand := Vector3(0.0, 0.0, 0.35)        # prefab space: middle of the left palm under the handguard
var ejection_port := Vector3.INF     # prefab space: where spent casings fly out (INF: none)
var charging_handle := Vector3.INF   # prefab space: a charging handle added to the model, cycling with each shot
var bolt_travel := 0.07              # how far the handle goes back (m)
var handle_reciprocates := true      # false: the handle stays put on shots (ACR), only the reload racks it
var break_hinge := Vector3.INF       # prefab space: a break-open's hinge pin (Contender; INF: none) - "Break" turns about it
var chamber := Vector3.INF           # prefab space: the case head of the round in a break-open's chamber
var forend := Vector3.INF            # prefab space: where the left hand takes a break-open's fore-end to drop the barrel
var lever_pivot := Vector3.INF       # prefab space: a lever action's pivot (Winchester 1887; INF: none) - "Lever" turns about it
var shell_port := Vector3.INF        # prefab space: where a lever action's shells go in by hand and the spent hull flies out
var mag_hinge := Vector3.INF         # prefab space: a magazine on top (P90; INF: none) - the catch at its front's bottom:
                                     # its back tips up about it, then it slides back off (WeaponView.set_mag_tip)
var eject_down := false              # the empties drop out of the bottom (the P90, behind the grip), not thrown to the right

var damage := 25.0
var pellets := 1
var pellet_spread := 0.0      # rad: the pellets' cone round where the shot goes (the choke's pattern; the aim's own
                              # spread moves the whole pattern)
var reload_single := false    # reloads a round at a time (reload_time each), a shot stops it (a tube magazine)
var max_range := 150.0
var fire_interval := 0.1
var fire_interval_ramped := 0.0  # s between shots after fire_ramp_time of fire in a burst (0: no ramp)
var fire_ramp_time := 0.0
var automatic := true
var mag_size := 30
var reserve_start := 120
var reserve_max := 180        # most rounds in reserve: ammo bags (AmmoBags) top it up to this
var reload_time := 2.0
var equip_time := 0.4

var ads_time := 0.2
var ads_fov_mult := 0.75
var ads_move_mult := 0.7
var move_speed_mult := 1.0  # walk, sprint and crouch speed with it in hand (the heavier, the slower)

var spread_hip := deg_to_rad(2.0)   # cone half angle
var spread_ads := deg_to_rad(0.3)
var spread_move := deg_to_rad(1.5)  # added at walking speed
var spread_air := deg_to_rad(3.0)

var recoil_pitch := 0.008           # view kick up per shot
var recoil_yaw := 0.003             # random sideways kick per shot (+-)
var recoil_recover := 0.8           # rad/s back towards zero when not firing

var falloff_ranges := PackedFloat32Array()  # m: beyond each, damage drops to the matching falloff_mults share
var falloff_mults := PackedFloat32Array()
var penetration := 0.0         # m of penetrable cover a bullet goes through (one per shot)
var penetration_damage := 0.5  # damage x this after going through
var loudness := 0.0            # dB on the shot sound
var muzzle_flash := true
var tracer := true             # others see the bullet's trail
var armor_piercing := false    # the body parts' protection does not hold it (PlayerHealth.damage_taken_mult)
var head_mult := 1.15          # damage x this on a head hit (NetWorld.HEAD_DAMAGE_MULT; 1: the head as the body)
var regen_block := 0.0         # s a hit keeps the victim's health from coming back (0: their own delay)

var sound_shot := "shot"
var hip_offset := Vector3(0.17, -0.19, -0.32)  # viewmodel position relative to the camera


## Damage of a body hit at `distance` m (before head and cover multipliers).
func damage_at(distance: float) -> float:
	var mult := 1.0
	for i in mini(falloff_ranges.size(), falloff_mults.size()):
		if distance > falloff_ranges[i]:
			mult = falloff_mults[i]
	return damage * mult


## Ticks between shots, fractional: WeaponSim carries the remainder over, so any rate is exact on average. `held` - s
## of fire in this burst: a ramping rate (fire_ramp_time > 0) climbs from fire_interval to fire_interval_ramped.
func fire_ticks(held := 0.0) -> float:
	var rate := 1.0 / fire_interval
	if fire_ramp_time > 0.0 and fire_interval_ramped > 0.0:
		rate = lerpf(rate, 1.0 / fire_interval_ramped, clampf(held / fire_ramp_time, 0.0, 1.0))
	return maxf(60.0 / rate, 1.0)


func reload_ticks() -> int:
	return maxi(1, roundi(reload_time * 60.0))


func equip_ticks() -> int:
	return maxi(1, roundi(equip_time * 60.0))
