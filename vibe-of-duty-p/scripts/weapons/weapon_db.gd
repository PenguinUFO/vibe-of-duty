class_name WeaponDB
extends RefCounted
## The list of weapons. Slot N on the keyboard = index N-1 here.
## Geometry (model, sights, hands) is set in code below; the balance numbers and the modules (Docs/LOADOUT.md) come
## from assets/data/weapons.cfg - or a weapons.cfg next to the game's .exe - and a client plays the server's copy
## (load_text, sent on join by Net). A player's own numbers: make_def (base + the build's modules).

const CONFIG_PATH := "res://assets/data/weapons.cfg"
const CONFIG_OVERRIDE := "weapons.cfg"  # next to the exported .exe
const MODULE_SLOTS: Array[String] = ["caliber", "mag", "stock", "grip", "barrel", "muzzle", "sight", "ammo"]
## Modules' geometry (the config holds only their numbers), WeaponDef properties set on top of the base weapon's: an
## optic's model (SightModels) and the aim line through it, prefab space like _build_geometry's iron sights; a model
## variant (model_variants, merged into the base's); a muzzle that moved. A key ending in "_add" adds to the property
## (after every module's plain keys are set).
const MODULE_GEOMETRY := {
	"ak.sight.kobra": {"sight": "kobra", "rear_sight": Vector3(0.0, 0.15, 0.0),
			"front_sight": Vector3(0.0, 0.15, 0.1), "eye_relief": 0.22},
	"ak.sight.pso": {"sight": "pso", "scope": true, "rear_sight": Vector3(0.035, 0.155, -0.16),
			"front_sight": Vector3(0.035, 0.155, 0.24), "eye_relief": 0.06},
	"pdw.mag.20": {"model_variants": {"Mags": "PDW_Mag_20"}},
	"pdw.sight.compm": {"sight": "compm", "rear_sight": Vector3(0.0, 0.098, -0.06),
			"front_sight": Vector3(0.0, 0.098, 0.06), "eye_relief": 0.255},  # the eye where it is with the irons
	"pdw.stock.folded": {"model_variants": {"Stock": "Folded"}},
	"ak.muzzle.brake": {"model_variants": {"Muzzle": "Brake"}, "muzzle": Vector3(0.0, 0.045, 0.6)},
	"ak.muzzle.pbs": {"model_variants": {"Muzzle": "PBS"}, "muzzle": Vector3(0.0, 0.045, 0.73),
			"sound_shot": "shot_suppressed"},
	# The PH IDW's base wears the suppressor (owner, 2026-10-23); this module takes it off.
	"pdw.muzzle.thread": {"model_variants": {"Muzzle": "Thread"}, "muzzle": Vector3(0.0, 0.02, 0.236),
			"sound_shot": "shot"},
	"luger.mag.32": {"model_variants": {"Mags": "Luger_Mag_32"}},
	"luger.stock.board": {"model_variants": {"Stock": "Board"}, "eye_relief": 0.3},  # the cheek on the board
	"luger.barrel.150": {"model_variants": {"Barrel": "B150"}, "muzzle": Vector3(0.0, 0.03, 0.16),
			"front_sight": Vector3(0.0, 0.05, 0.152)},
	"luger.barrel.200": {"model_variants": {"Barrel": "B200", "Toggle/LinkRear/Sight": "Plain"},
			"muzzle": Vector3(0.0, 0.03, 0.21), "rear_sight": Vector3(0.0, 0.05, 0.0485),
			"front_sight": Vector3(0.0, 0.05, 0.202), "eye_relief_add": 0.136},  # the notch moved 0.136 m forward
	"mp7.mag.30": {"model_variants": {"Mags": "MP7_Mag_30"}},
	"mp7.mag.20": {"model_variants": {"Mags": "MP7_Mag_20"}},
	"mp7.stock.extended": {"model_variants": {"Stock": "Extended"}, "eye_relief_add": 0.1},  # the gun 0.223 m further out
	"mp7.grip.folded": {"model_variants": {"Foregrip": "Folded"}, "left_hand": Vector3(0.0, -0.02, 0.16)},  # on the folded grip
	"mp7.muzzle.suppressor": {"model_variants": {"Muzzle": "Can"}, "muzzle": Vector3(0.0, 0.0217, 0.3198),
			"sound_shot": "shot_suppressed"},
	# The PDW's CompM on the MP7's rail (0.0031 higher), the flip-up sights folded under it.
	"mp7.sight.compm": {"sight": "compm", "sight_offset": Vector3(0.0, 0.0031, 0.0),
			"model_variants": {"Sights": "Down"}, "rear_sight": Vector3(0.0, 0.1011, -0.06),
			"front_sight": Vector3(0.0, 0.1011, 0.06), "eye_relief": 0.202},  # the eye where it is with the irons
	"acr.barrel.105": {"model_variants": {"Barrel": "B105"}, "muzzle": Vector3(0.0, 0.05, 0.447)},
	"acr.barrel.185": {"model_variants": {"Barrel": "B185"}, "muzzle": Vector3(0.0, 0.05, 0.637)},
	"acr.stock.folded": {"model_variants": {"Stock": "Folded"}},
	# Every barrel has its own muzzle group (the others are gone by then); the can is 0.103 m longer than the brake.
	"acr.muzzle.suppressor": {"model_variants": {"Barrel/B105/Muzzle": "Can", "Barrel/B145/Muzzle": "Can",
			"Barrel/B185/Muzzle": "Can"}, "muzzle_add": Vector3(0.0, 0.0, 0.103), "sound_shot": "shot_suppressed"},
}
## Points in prefab space: scaled by WeaponDef.model_scale (WeaponDB keeps them life size, as the model is built).
const SCALED_POINTS: Array[String] = ["muzzle", "rear_sight", "front_sight", "right_hand", "left_hand",
		"ejection_port", "charging_handle"]
const MODULE_SLOT_NAMES := {"caliber": "Калибр", "mag": "Магазин", "stock": "Приклад", "grip": "Рукоятка", "barrel": "Ствол",
		"muzzle": "Дульное", "sight": "Прицел", "ammo": "Патрон"}

static var _defs: Array[WeaponDef] = []
static var _base := {}       # weapon id -> its config section (config units)
static var _modules := {}    # "ak.mag.drum75" -> {id, weapon, slot, name, info, cost, requires, values}
static var _module_ids: Array[String] = []  # in file order: the first of each slot is its default
static var config_text := ""  # the config in play (sent to clients)
static var _loaded := false
static var version := 0       # +1 on every config loaded (PartDB rebuilds its module list)


static func count() -> int:
	_build()
	return _defs.size()


## Loads every weapon prefab up front so the first switch/shot does not hitch.
static func preload_scenes() -> void:
	for i in count():
		load(get_def(i).scene_path)


## The base weapon (no modules).
static func get_def(index: int) -> WeaponDef:
	_build()
	return _defs[clampi(index, 0, _defs.size() - 1)]


## The index of the weapon with this id (0, the first, if there is none).
static func index_of(id: String) -> int:
	_build()
	for i in _defs.size():
		if _defs[i].id == id:
			return i
	return 0


## The weapon with these modules (ids as in modules_for; unknown or other weapons' ids are skipped).
static func make_def(index: int, module_ids: Array) -> WeaponDef:
	var base := get_def(index)
	var values: Dictionary = (_base.get(base.id, {}) as Dictionary).duplicate(true)
	for id in module_ids:
		var module: Dictionary = _modules.get(str(id), {})
		if module.get("weapon", "") == base.id:
			_apply_module(values, module["values"])
	var def := WeaponDef.new()
	for prop in base.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			def.set(prop["name"], base.get(prop["name"]))
	_write(def, values)
	for adding in [false, true]:
		for id in module_ids:
			var geometry: Dictionary = MODULE_GEOMETRY.get(str(id), {})
			for key: String in geometry:
				if key.ends_with("_add") != adding:
					continue
				var value: Variant = geometry[key]
				var prop := key.trim_suffix("_add")
				if prop in SCALED_POINTS or (adding and prop == "eye_relief"):  # an added relief follows a sight that moved
					value = value * def.model_scale
				if adding:
					value = def.get(prop) + value
				elif value is Dictionary:
					value = (def.get(prop) as Dictionary).merged(value, true)  # a new one: the base's stays as it is
				def.set(prop, value)
	return def


## Modules of `weapon_id` for `slot`, the default first: [{id, weapon, slot, name, info, cost, requires, values}].
static func modules_for(weapon_id: String, slot: String) -> Array:
	_build()
	var list := []
	for id in _module_ids:
		var module: Dictionary = _modules[id]
		if module["weapon"] == weapon_id and module["slot"] == slot:
			list.append(module)
	return list


static func get_module(id: String) -> Dictionary:
	_build()
	return _modules.get(id, {})


## This machine's own config: weapons.cfg next to the .exe if there is one, else the built-in one.
static func load_local() -> void:
	var path := CONFIG_PATH
	if not OS.has_feature("editor"):
		var beside := OS.get_executable_path().get_base_dir().path_join(CONFIG_OVERRIDE)
		if FileAccess.file_exists(beside):
			path = beside
	load_text(FileAccess.get_file_as_string(path))


## Takes a config (this machine's, or the server's on join). False, and nothing changes, if it does not parse.
static func load_text(text: String) -> bool:
	_loaded = true  # a config given before the first use (the server's) is not replaced by the local one
	if _defs.is_empty():
		_build_geometry()
	var cfg := ConfigFile.new()
	if text == "" or cfg.parse(text) != OK:
		push_error("weapons.cfg: cannot parse")
		return false
	_base.clear()
	_modules.clear()
	_module_ids.clear()
	for section in cfg.get_sections():
		var values := {}
		for key in cfg.get_section_keys(section):
			values[key] = cfg.get_value(section, key)
		var path := section.split(".")
		if path.size() == 1:
			_base[section] = values
		elif path.size() == 3 and MODULE_SLOTS.has(path[1]):
			var module := {"id": section, "weapon": path[0], "slot": path[1],
					"name": str(values.get("name", path[2])), "info": str(values.get("info", "")),
					"cost": int(values.get("cost", 0)),
					"requires": path[0] + "." + str(values["requires"]) if values.has("requires") else "",
					"values": {}}
			for key in values:
				if not key in ["name", "info", "cost", "requires"]:
					module["values"][key] = values[key]
			_modules[section] = module
			_module_ids.append(section)
		else:
			push_error("weapons.cfg: unknown section [%s]" % section)
	config_text = text
	version += 1
	for def in _defs:
		_write(def, _base.get(def.id, {}))
	return true


static func _apply_module(values: Dictionary, changes: Dictionary) -> void:
	for key: String in changes:
		if key.ends_with("_mult"):
			var base_key := key.trim_suffix("_mult")
			var current: Variant = values.get(base_key, 0.0)
			if current is Array:
				var scaled := []
				for v in current:
					scaled.append(float(v) * float(changes[key]))
				values[base_key] = scaled
			else:
				values[base_key] = float(current) * float(changes[key])
		else:
			values[key] = changes[key]


## Config values (config units, see weapons.cfg) -> the weapon's numbers.
static func _write(def: WeaponDef, v: Dictionary) -> void:
	def.display_name = str(v.get("name", def.display_name))
	def.info = str(v.get("info", def.info))
	def.damage = float(v.get("damage", def.damage))
	def.pellets = int(v.get("pellets", def.pellets))
	if v.has("fire_rate"):
		def.fire_interval = 60.0 / maxf(float(v["fire_rate"]), 1.0)
	if v.has("fire_rate_max"):
		def.fire_interval_ramped = 60.0 / maxf(float(v["fire_rate_max"]), 1.0)
	def.fire_ramp_time = float(v.get("fire_ramp", def.fire_ramp_time))
	def.automatic = bool(v.get("automatic", def.automatic))
	def.mag_size = maxi(roundi(float(v.get("mag_size", def.mag_size))), 1)
	def.reserve_start = roundi(float(v.get("reserve_start", def.reserve_start)))
	def.reserve_max = roundi(float(v.get("reserve_max", def.reserve_max)))
	def.reload_time = float(v.get("reload_time", def.reload_time))
	def.equip_time = float(v.get("equip_time", def.equip_time))
	def.ads_time = maxf(float(v.get("ads_time", def.ads_time)), 0.01)
	def.ads_fov_mult = float(v.get("ads_zoom", def.ads_fov_mult))
	def.ads_move_mult = float(v.get("ads_move", def.ads_move_mult))
	def.move_speed_mult = float(v.get("move_speed", def.move_speed_mult))
	def.spread_hip = deg_to_rad(float(v.get("spread_hip", rad_to_deg(def.spread_hip))))
	def.spread_ads = deg_to_rad(float(v.get("spread_ads", rad_to_deg(def.spread_ads))))
	def.spread_move = deg_to_rad(float(v.get("spread_move", rad_to_deg(def.spread_move))))
	def.spread_air = deg_to_rad(float(v.get("spread_air", rad_to_deg(def.spread_air))))
	def.recoil_pitch = deg_to_rad(float(v.get("recoil_up", rad_to_deg(def.recoil_pitch))))
	def.recoil_yaw = deg_to_rad(float(v.get("recoil_side", rad_to_deg(def.recoil_yaw))))
	def.recoil_recover = deg_to_rad(float(v.get("recoil_recover", rad_to_deg(def.recoil_recover))))
	def.max_range = float(v.get("range", def.max_range))
	def.falloff_ranges = PackedFloat32Array(v.get("falloff_ranges", def.falloff_ranges))
	def.falloff_mults = PackedFloat32Array(v.get("falloff_mults", def.falloff_mults))
	def.penetration = float(v.get("penetration", def.penetration))
	def.penetration_damage = float(v.get("penetration_damage", def.penetration_damage))
	def.loudness = float(v.get("loudness", def.loudness))
	def.muzzle_flash = bool(v.get("muzzle_flash", def.muzzle_flash))
	def.tracer = bool(v.get("tracer", def.tracer))
	def.armor_piercing = bool(v.get("armor_piercing", def.armor_piercing))


static func _build() -> void:
	if _loaded:
		return
	_loaded = true
	if _defs.is_empty():
		_build_geometry()
	load_local()


## What the config does not hold: the model and the points on it.
static func _build_geometry() -> void:
	var rifle := WeaponDef.new()
	rifle.id = "ak"
	rifle.display_name = "АК"
	rifle.scene_path = "res://prefabs/weapons/ak_blockout.tscn"  # tools/make_ak_blockout.py
	rifle.model_variants = {"Muzzle": "Slant"}
	rifle.muzzle = Vector3(0.0, 0.045, 0.565)
	rifle.rear_sight = Vector3(0.0, 0.118, 0.28)   # top of the rear leaf (the post's tip flush with it)
	rifle.front_sight = Vector3(0.0, 0.118, 0.5)   # tip of the front post
	rifle.eye_relief = 0.46  # eye over the stock comb, behind the receiver
	rifle.right_hand = Vector3(0.0, -0.055, -0.062)
	rifle.left_hand = Vector3(0.0, 0.0, 0.35)
	rifle.ejection_port = Vector3(-0.027, 0.058, 0.07)  # right side of the receiver (prefab -x = the shooter's right)
	rifle.charging_handle = Vector3(-0.036, 0.062, 0.13)
	rifle.sound_shot = "shot"
	rifle.hip_offset = Vector3(0.15, -0.19, -0.36)
	_defs.append(rifle)

	var pdw := WeaponDef.new()
	pdw.id = "pdw"
	pdw.display_name = "PH IDW"
	pdw.scene_path = "res://prefabs/weapons/pdw_blockout.tscn"  # tools/make_pdw_blockout.py
	pdw.model_variants = {"Stock": "Extended", "Mags": "PDW_Mag_32", "Muzzle": "Suppressor"}  # .45 with the can
	pdw.muzzle = Vector3(0.0, 0.02, 0.385)
	pdw.rear_sight = Vector3(0.0, 0.086, -0.115)  # top of the rear ears (the post's tip flush with them)
	pdw.front_sight = Vector3(0.0, 0.086, 0.115)   # tip of the front post
	pdw.eye_relief = 0.2  # over the stock, in front of the butt (behind it the U butt framed the whole view)
	pdw.right_hand = Vector3(0.0, -0.085, -0.1)
	pdw.left_hand = Vector3(0.0, -0.08, 0.076)    # the left hand holds the magazine well
	pdw.ejection_port = Vector3(-0.023, 0.04, 0.03)
	pdw.charging_handle = Vector3(-0.026, 0.03, 0.09)  # in the slot forward on the right (the photo shows the slot)
	pdw.bolt_travel = 0.045
	pdw.sound_shot = "shot_suppressed"
	pdw.hip_offset = Vector3(0.12, -0.155, -0.42)  # short: further out than the AK, so its muzzle is where the AK's is
	_defs.append(pdw)

	var luger := WeaponDef.new()
	luger.id = "luger"
	luger.display_name = "Люгер"
	luger.scene_path = "res://prefabs/weapons/luger_blockout.tscn"  # tools/make_luger_blockout.py
	luger.model_variants = {"Barrel": "B100", "Toggle/LinkRear/Sight": "Notch", "Stock": "None", "Mags": "Luger_Mag_8"}
	luger.muzzle = Vector3(0.0, 0.03, 0.11)
	luger.rear_sight = Vector3(0.0, 0.05, -0.0875)  # the notch's ears' tops on the toggle (it rises with every shot)
	luger.front_sight = Vector3(0.0, 0.05, 0.102)
	luger.eye_relief = 0.38  # arms out, a little bent
	luger.model_scale = 1.2  # life size it is a toy next to a pig, and the two fists hid it
	luger.right_hand = Vector3(0.0, -0.035, -0.06)   # the middle of the grip
	luger.left_hand = Vector3(0.0, -0.08, -0.078)   # cupped under the right hand and the magazine's base
	luger.ejection_port = Vector3(0.0, 0.045, -0.01)    # up out of the open toggle
	luger.charging_handle = Vector3(-0.017, 0.0384, -0.059)  # the right knob: the hand racks the toggle (no handle added)
	luger.bolt_travel = 0.045
	luger.sound_shot = "shot_pistol"
	luger.hip_offset = Vector3(0.13, -0.15, -0.36)
	_defs.append(luger)

	var acr := WeaponDef.new()
	acr.id = "acr"
	acr.display_name = "ACR"
	acr.scene_path = "res://prefabs/weapons/acr_blockout.tscn"  # tools/make_acr_blockout.py
	acr.model_variants = {"Barrel": "B145", "Barrel/B105/Muzzle": "Brake", "Barrel/B145/Muzzle": "Brake",
			"Barrel/B185/Muzzle": "Brake", "Stock": "Extended", "Mags": "ACR_Mag_30"}
	acr.muzzle = Vector3(0.0, 0.05, 0.548)
	acr.rear_sight = Vector3(0.0, 0.113, -0.05)   # top of the rear ears (the post's tip flush with them)
	acr.front_sight = Vector3(0.0, 0.113, 0.31)   # tip of the front post
	acr.eye_relief = 0.15  # cheek on the comb
	acr.right_hand = Vector3(0.0, -0.04, -0.076)
	acr.left_hand = Vector3(0.0, 0.015, 0.29)
	acr.ejection_port = Vector3(-0.027, 0.06, 0.06)
	acr.charging_handle = Vector3(0.03, 0.083, 0.2)  # forward on the left, under the rail
	acr.handle_reciprocates = false
	acr.bolt_travel = 0.08
	acr.sound_shot = "shot"
	acr.hip_offset = Vector3(0.15, -0.19, -0.36)
	_defs.append(acr)

	var mp7 := WeaponDef.new()
	mp7.id = "mp7"
	mp7.display_name = "MP7"
	mp7.scene_path = "res://prefabs/weapons/mp7_blockout.tscn"  # tools/make_mp7_blockout.py
	mp7.model_variants = {"Stock": "Collapsed", "Foregrip": "Unfolded", "Muzzle": "Hider", "Sights": "Up",
			"Mags": "MP7_Mag_40"}
	mp7.muzzle = Vector3(0.0, 0.0217, 0.2106)
	mp7.rear_sight = Vector3(0.0, 0.104, -0.132)  # top of the rear ears (the post's tip flush with them)
	mp7.front_sight = Vector3(0.0, 0.104, 0.108)  # tip of the front post
	mp7.eye_relief = 0.13  # the stock in: the cheek right behind the receiver
	mp7.right_hand = Vector3(0.0, -0.045, -0.047)  # the middle of the grip
	mp7.left_hand = Vector3(0.0, -0.05, 0.124)     # on the foregrip
	mp7.ejection_port = Vector3(-0.022, 0.04, 0.015)
	mp7.charging_handle = Vector3(0.0, 0.058, -0.18)  # at the rear under the rail, as an AR's
	mp7.handle_reciprocates = false
	mp7.bolt_travel = 0.04
	mp7.sound_shot = "shot"
	mp7.hip_offset = Vector3(0.12, -0.155, -0.42)
	_defs.append(mp7)

	for def in _defs:
		for prop in SCALED_POINTS:
			def.set(prop, def.get(prop) * def.model_scale)
