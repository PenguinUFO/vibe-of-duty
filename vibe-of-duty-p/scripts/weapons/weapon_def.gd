class_name WeaponDef
extends RefCounted
## Static tuning data for one weapon. Angles are stored in radians, durations in seconds
## (WeaponSim converts durations to physics ticks).

var id := ""
var display_name := ""
var scene_path := ""          # model scene (prefabs/weapons); its barrel points to +Z
var muzzle := Vector3.ZERO    # muzzle position in prefab space (before the 180 deg turn to face -Z)
var rear_sight := Vector3(0.0, 0.17, 0.0)   # top of the rear sight in prefab space (ADS alignment)
var front_sight := Vector3(0.0, 0.17, 0.5)  # top of the front sight / barrel end in prefab space
var eye_relief := 0.15                       # distance from the camera to the rear sight while aiming (m)
var right_hand := Vector3(0.0, -0.055, -0.045)  # prefab space: middle of the right palm on the pistol grip
var left_hand := Vector3(0.0, 0.0, 0.35)        # prefab space: middle of the left palm under the handguard
var ejection_port := Vector3.INF     # prefab space: where spent casings fly out (INF: none)
var charging_handle := Vector3.INF   # prefab space: a charging handle added to the model, cycling with each shot
var bolt_travel := 0.07              # how far the handle goes back (m)

var damage := 25.0
var pellets := 1
var max_range := 150.0
var fire_interval := 0.1
var automatic := true
var mag_size := 30
var reserve_start := 120
var reload_time := 2.0
var equip_time := 0.4

var ads_time := 0.2
var ads_fov_mult := 0.75
var ads_move_mult := 0.7

var spread_hip := deg_to_rad(2.0)   # cone half angle
var spread_ads := deg_to_rad(0.3)
var spread_move := deg_to_rad(1.5)  # added at walking speed
var spread_air := deg_to_rad(3.0)

var recoil_pitch := 0.008           # view kick up per shot
var recoil_yaw := 0.003             # random sideways kick per shot (+-)
var recoil_recover := 0.8           # rad/s back towards zero when not firing

var sound_shot := "shot"
var hip_offset := Vector3(0.17, -0.19, -0.32)  # viewmodel position relative to the camera


func fire_ticks() -> int:
	return maxi(1, roundi(fire_interval * 60.0))


func reload_ticks() -> int:
	return maxi(1, roundi(reload_time * 60.0))


func equip_ticks() -> int:
	return maxi(1, roundi(equip_time * 60.0))
