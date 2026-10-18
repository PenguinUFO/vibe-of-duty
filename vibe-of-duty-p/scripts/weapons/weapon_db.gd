class_name WeaponDB
extends RefCounted
## The list of weapons. Slot N on the keyboard = index N-1 here.

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
	rifle.id = "ak"
	rifle.display_name = "AK"
	rifle.scene_path = "res://prefabs/weapons/ak_blockout.tscn"  # tools/make_ak_blockout.py
	rifle.muzzle = Vector3(0.0, 0.045, 0.565)
	rifle.rear_sight = Vector3(0.0, 0.112, 0.28)   # bottom of the rear notch
	rifle.front_sight = Vector3(0.0, 0.11, 0.5)    # tip of the front post
	rifle.eye_relief = 0.46  # eye over the stock comb, behind the receiver
	rifle.right_hand = Vector3(0.0, -0.055, -0.045)
	rifle.left_hand = Vector3(0.0, 0.0, 0.35)
	rifle.damage = 28.0
	rifle.fire_interval = 0.1
	rifle.automatic = true
	rifle.mag_size = 30
	rifle.reserve_start = 120
	rifle.reload_time = 2.4
	rifle.equip_time = 0.45
	rifle.ads_time = 0.22
	rifle.ads_fov_mult = 0.75
	rifle.ads_move_mult = 0.7
	rifle.spread_hip = deg_to_rad(2.2)
	rifle.spread_ads = deg_to_rad(0.25)
	rifle.recoil_pitch = 0.0095
	rifle.recoil_yaw = 0.0015
	rifle.recoil_recover = 0.8
	rifle.sound_shot = "shot"
	rifle.hip_offset = Vector3(0.15, -0.19, -0.36)
	_defs.append(rifle)
