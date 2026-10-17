class_name WeaponDB
extends RefCounted
## The list of weapons. Slot N on the keyboard = index N-1 here.

const PREFAB_DIR := "res://assets/Prefabs/Weapons/"

static var _defs: Array[WeaponDef] = []


static func count() -> int:
	_build()
	return _defs.size()


## Loads every weapon prefab up front so the first switch/shot does not hitch.
static func preload_scenes() -> void:
	for i in count():
		load(get_def(i).scene_path)


static func get_def(index: int) -> WeaponDef:
	_build()
	return _defs[clampi(index, 0, _defs.size() - 1)]


static func _build() -> void:
	if not _defs.is_empty():
		return

	var rifle := WeaponDef.new()
	rifle.id = "rifle"
	rifle.display_name = "AR-01"
	rifle.scene_path = PREFAB_DIR + "SM_Wep_Rifle_Assault_01.tscn"
	rifle.muzzle = Vector3(0.0, 0.085, 0.665)
	rifle.sight_height = 0.17
	rifle.damage = 28.0
	rifle.fire_interval = 0.085
	rifle.automatic = true
	rifle.mag_size = 30
	rifle.reserve_start = 120
	rifle.reload_time = 2.3
	rifle.equip_time = 0.45
	rifle.ads_time = 0.2
	rifle.ads_fov_mult = 0.75
	rifle.ads_move_mult = 0.7
	rifle.spread_hip = deg_to_rad(2.2)
	rifle.spread_ads = deg_to_rad(0.25)
	rifle.recoil_pitch = 0.0085
	rifle.recoil_yaw = 0.0035
	rifle.recoil_recover = 0.8
	rifle.sound_shot = "shot"
	rifle.hip_offset = Vector3(0.17, -0.19, -0.30)
	_defs.append(rifle)

	var shotgun := WeaponDef.new()
	shotgun.id = "shotgun"
	shotgun.display_name = "SG-12"
	shotgun.scene_path = PREFAB_DIR + "SM_Wep_Shotgun_01.tscn"
	shotgun.muzzle = Vector3(0.0, 0.06, 0.86)
	shotgun.sight_height = 0.12
	shotgun.damage = 12.0
	shotgun.pellets = 8
	shotgun.max_range = 45.0
	shotgun.fire_interval = 0.85
	shotgun.automatic = false
	shotgun.mag_size = 6
	shotgun.reserve_start = 24
	shotgun.reload_time = 2.6
	shotgun.equip_time = 0.55
	shotgun.ads_time = 0.25
	shotgun.ads_fov_mult = 0.85
	shotgun.ads_move_mult = 0.8
	shotgun.spread_hip = deg_to_rad(5.0)
	shotgun.spread_ads = deg_to_rad(3.5)
	shotgun.spread_move = deg_to_rad(1.0)
	shotgun.recoil_pitch = 0.05
	shotgun.recoil_yaw = 0.01
	shotgun.recoil_recover = 1.2
	shotgun.sound_shot = "shot_shotgun"
	shotgun.hip_offset = Vector3(0.17, -0.18, -0.30)
	_defs.append(shotgun)

	var pistol := WeaponDef.new()
	pistol.id = "pistol"
	pistol.display_name = "P-45"
	pistol.scene_path = PREFAB_DIR + "SM_Wep_Pistol_Heavy_01.tscn"
	pistol.muzzle = Vector3(0.0, 0.06, 0.296)
	pistol.sight_height = 0.105
	pistol.damage = 34.0
	pistol.max_range = 100.0
	pistol.fire_interval = 0.18
	pistol.automatic = false
	pistol.mag_size = 12
	pistol.reserve_start = 60
	pistol.reload_time = 1.5
	pistol.equip_time = 0.3
	pistol.ads_time = 0.12
	pistol.ads_fov_mult = 0.9
	pistol.ads_move_mult = 0.9
	pistol.spread_hip = deg_to_rad(1.6)
	pistol.spread_ads = deg_to_rad(0.3)
	pistol.recoil_pitch = 0.02
	pistol.recoil_yaw = 0.005
	pistol.recoil_recover = 1.5
	pistol.sound_shot = "shot_pistol"
	pistol.hip_offset = Vector3(0.15, -0.16, -0.28)
	_defs.append(pistol)
