class_name WeaponDB
extends RefCounted
## The list of weapons. Slot N on the keyboard = index N-1 here.
## Geometry (model, sights, hands) is set in code below; the balance numbers and the modules (Docs/LOADOUT.md) come
## from assets/data/weapons.cfg - or a weapons.cfg next to the game's .exe - and a client plays the server's copy
## (load_text, sent on join by Net). A player's own numbers: make_def (base + the build's modules).

const CONFIG_PATH := "res://assets/data/weapons.cfg"
const CONFIG_OVERRIDE := "weapons.cfg"  # next to the exported .exe
const MODULE_SLOTS: Array[String] = ["barrel", "suppressor", "conversion", "stock", "mag", "grip", "muzzle", "sight", "ammo",
		"akimbo"]
## The Luger drawn bigger than life: life size it is a toy next to a pig, and the two fists hid it.
const LUGER_SCALE := 1.2
## The Luger's tangent rear sight on its 200 mm artillery barrel: this far (life size) ahead of the P08's notch on the
## toggle, where the eye relief was set.
const LUGER_SIGHT_AHEAD := 0.136
## Modules' geometry (the config holds only their numbers), WeaponDef properties set on top of the base weapon's: an
## optic's model (SightModels) and the aim line through it, prefab space like _build_geometry's iron sights; a model
## variant (model_variants, merged into the base's); a muzzle that moved. A key ending in "_add" adds to the property
## (after every module's plain keys are set).
const MODULE_GEOMETRY := {
	"ak.sight.kobra": {"sight": "kobra", "rear_sight": Vector3(0.0, 0.15, 0.0),
			"front_sight": Vector3(0.0, 0.15, 0.1), "eye_relief": 0.22},
	"ak.sight.pso": {"sight": "pso", "scope": true, "rear_sight": Vector3(0.035, 0.155, -0.16),
			"front_sight": Vector3(0.035, 0.155, 0.24), "eye_relief": 0.06},
	# The ACOG on the ACR's rail, its axis 36 mm over it; the irons folded under it. The eye 6 cm behind the eyepiece
	# (the real one's relief is ~4 cm): the cheek where it is with the irons, give or take.
	"acr.sight.acog": {"sight": "acog", "model_variants": {"Sights": "Down"}, "rear_sight": Vector3(0.0, 0.131, -0.075),
			"front_sight": Vector3(0.0, 0.131, 0.05), "eye_relief": 0.06},
	# The same ACOG on the PH IDW's rail (0.027 lower; its fixed irons stay, under the ACOG's 7 degrees) and the MP7's
	# (0.0239 lower, the flip-ups folded). The eye as on the ACR, 6 cm behind the eyepiece.
	"pdw.sight.acog": {"sight": "acog", "sight_offset": Vector3(0.0, -0.027, 0.0),
			"rear_sight": Vector3(0.0, 0.104, -0.075), "front_sight": Vector3(0.0, 0.104, 0.05), "eye_relief": 0.06},
	"mp7.sight.acog": {"sight": "acog", "sight_offset": Vector3(0.0, -0.0239, 0.0), "model_variants": {"Sights": "Down"},
			"rear_sight": Vector3(0.0, 0.1071, -0.075), "front_sight": Vector3(0.0, 0.1071, 0.05), "eye_relief": 0.06},
	# The PH IDW's CompM on the ACR's rail (0.027 higher), the flip-ups folded (the rear's ears would be in its ocular).
	# The eye where it is with the irons (0.15 behind the rear sight at z -0.05).
	"acr.sight.compm": {"sight": "compm", "sight_offset": Vector3(0.0, 0.027, 0.0), "model_variants": {"Sights": "Down"},
			"rear_sight": Vector3(0.0, 0.125, -0.06), "front_sight": Vector3(0.0, 0.125, 0.06), "eye_relief": 0.14},
	"pdw.sight.compm": {"sight": "compm", "rear_sight": Vector3(0.0, 0.098, -0.06),
			"front_sight": Vector3(0.0, 0.098, 0.06), "eye_relief": 0.255},  # the eye where it is with the irons
	# The PH IDW's CompM and the ACR's ACOG on the Mk 14's rail (its top 0.0896: 0.0216 over the PH IDW's, 0.0054 under
	# the ACR's), forward over the receiver's front (z +0.13), the aperture cranked down; the eye where it is with the
	# irons, ACOG: 6 cm behind its eyepiece, as on the ACR.
	"mk14.sight.compm": {"sight": "compm", "sight_offset": Vector3(0.0, 0.0216, 0.13), "model_variants": {"Sights": "Down"},
			"rear_sight": Vector3(0.0, 0.1196, 0.07), "front_sight": Vector3(0.0, 0.1196, 0.19), "eye_relief": 0.205},
	"mk14.sight.acog": {"sight": "acog", "sight_offset": Vector3(0.0, -0.0054, 0.13),
			"model_variants": {"Sights": "Down", "FrontSight": "Off"},  # the post showed at the 4x view's bottom
			"rear_sight": Vector3(0.0, 0.1256, 0.055), "front_sight": Vector3(0.0, 0.1256, 0.18), "eye_relief": 0.06},
	"pdw.stock.folded": {"model_variants": {"Stock": "Folded"}},
	"ak.mag.rpk40": {"model_variants": {"Mags": "AK_Mag_40"}},
	"acr.mag.40": {"model_variants": {"Mags": "ACR_Mag_40"}},
	"ak.muzzle.brake": {"model_variants": {"Muzzle": "Brake"}, "muzzle": Vector3(0.0, 0.045, 0.6)},
	"ak.suppressor.on": {"model_variants": {"Muzzle": "PBS"}, "muzzle": Vector3(0.0, 0.045, 0.73),
			"sound_shot": "shot_suppressed"},
	"luger.mag.32": {"model_variants": {"Mags": "Luger_Mag_32"}},
	# Хрюгер (owner's fantasy, 2026-10-23): the Luger blown up for .50 Action Express, chromed.
	# Its 200 mm barrel scaled with it; the tangent sight 0.136 m ahead of the toggle's notch goes further forward with
	# the gun, the eye stays by the hands - the relief grows by the gun's 40%.
	"luger.conversion.khruger": {"model_scale": LUGER_SCALE * 1.4, "finish": "chrome", "sound_shot": "shot",
			"eye_relief_add": LUGER_SIGHT_AHEAD * 0.4 / 1.4},
	"luger.stock.board": {"model_variants": {"Stock": "Board"}, "eye_relief": 0.3 + LUGER_SIGHT_AHEAD * LUGER_SCALE},  # the cheek on the board
	"mp7.stock.collapsed": {"model_variants": {"Stock": "Collapsed"}, "eye_relief_add": -0.1},  # the gun 0.223 m nearer
	"mp7.grip.folded": {"model_variants": {"Foregrip": "Folded"}, "left_hand": Vector3(0.0, -0.02, 0.16)},  # on the folded grip
	"mp7.akimbo.on": {"model_variants": {"Foregrip": "Folded"}},  # no second hand on it: only the look, not the numbers
	"mp7.suppressor.on": {"model_variants": {"Muzzle": "Can"}, "muzzle": Vector3(0.0, 0.0217, 0.3198),
			"sound_shot": "shot_suppressed"},
	# The PDW's CompM on the MP7's rail (0.0031 higher), the flip-up sights folded under it.
	"mp7.sight.compm": {"sight": "compm", "sight_offset": Vector3(0.0, 0.0031, 0.0),
			"model_variants": {"Sights": "Down"}, "rear_sight": Vector3(0.0, 0.1011, -0.06),
			"front_sight": Vector3(0.0, 0.1011, 0.06), "eye_relief": 0.202},  # the eye where it is with the irons
	"acr.stock.collapsed": {"model_variants": {"Stock/Extended/Butt": "In"}},  # slid in along the beam
	# Every barrel has its own muzzle group (the others are gone by then); the can is 0.103 m longer than the brake.
	"acr.suppressor.on": {"model_variants": {"Barrel/B105/Muzzle": "Can", "Barrel/B145/Muzzle": "Can",
			"Barrel/B185/Muzzle": "Can"}, "muzzle_add": Vector3(0.0, 0.0, 0.103), "sound_shot": "shot_suppressed"},
	# AUG (tools/make_aug_blockout.py): the base is the A1 - 508 mm, the integral 1.5x scope, the Steyr grip. The
	# Commando's barrel 158 mm shorter; the .300 BLK's can 0.131 longer than the hider.
	"aug.barrel.b350": {"model_variants": {"Barrel": "B350"}, "muzzle": Vector3(0.0, 0.0361, 0.2296)},
	"aug.suppressor.blk": {"model_variants": {"Barrel/B508/Muzzle": "Can", "Barrel/B350/Muzzle": "Can"},
			"muzzle_add": Vector3(0.0, 0.0, 0.1313), "sound_shot": "shot_suppressed"},
	# The A3 upper (its rail's top 0.0861) and, on the 508, the handguard with rails. The PDW's CompM 0.0181 higher,
	# over the rail's back, the flip-ups folded; the eye at the cheek (z -0.215) as with the scope and the irons.
	"aug.sight.compm": {"sight": "compm", "sight_offset": Vector3(0.0, 0.0181, -0.07),
			"model_variants": {"Upper": "A3", "Upper/A3/Sights": "Down", "Barrel/B508/Front": "Rail"},
			"rear_sight": Vector3(0.0, 0.1161, -0.13), "front_sight": Vector3(0.0, 0.1161, -0.01), "eye_relief": 0.085},
	"aug.sight.iron": {"sight": "",
			"model_variants": {"Upper": "A3", "Upper/A3/Sights": "Up", "Barrel/B508/Front": "Rail"},
			"rear_sight": Vector3(0.0, 0.1041, -0.1136), "front_sight": Vector3(0.0, 0.1041, 0.1172), "eye_relief": 0.1016},
	# The ACR's ACOG on the A3's rail (0.0089 lower), over the rail's back: the eye at the cheek, 6 cm behind its
	# eyepiece, as on the ACR.
	"aug.sight.acog": {"sight": "acog", "sight_offset": Vector3(0.0, -0.0089, -0.08),
			"model_variants": {"Upper": "A3", "Upper/A3/Sights": "Down", "Barrel/B508/Front": "Rail"},
			"rear_sight": Vector3(0.0, 0.1221, -0.155), "front_sight": Vector3(0.0, 0.1221, -0.03), "eye_relief": 0.06},
	# Off: the A1's grip folded forward under the barrel, the tactical one taken off; the left hand up under the barrel.
	"aug.grip.off": {"model_variants": {"Barrel/B508/Front/Bare/Grip": "Folded", "Barrel/B508/Front/Rail/Grip": "Off",
			"Barrel/B350/Grip": "Off"}, "left_hand_add": Vector3(0.0, 0.05, 0.03)},
	"aug.mag.42": {"model_variants": {"Mags": "AUG_Mag_42"}},
	# M16A1 (tools/make_m16_blockout.py): the base is the 603 - 20", the A1 stock, the irons on the carry handle. The
	# 653's barrel brings its round handguard and the CAR stock, the front 140 mm shorter; the left hand on its handguard.
	"m16.barrel.b368": {"model_variants": {"Barrel": "B368", "Stock": "CAR"}, "muzzle": Vector3(0.0, 0.0548, 0.5414),
			"left_hand": Vector3(0.0, 0.0263, 0.235)},
	"m16.stock.collapsed": {"model_variants": {"Stock/CAR/Slide": "In"}},  # slid in along the tube
	# The HEL-E4A over the barrel's end, its collar just ahead of the front sight base: 0.1319 past the birdcage.
	"m16.suppressor.hel": {"model_variants": {"Barrel/B508/Muzzle": "Can", "Barrel/B368/Muzzle": "Can"},
			"muzzle_add": Vector3(0.0, 0.0, 0.1319), "sound_shot": "shot_suppressed"},
	# The Colt 3x20 on the carry handle, its axis 24 mm over the irons' line (clear of the rear sight's ears); the eye
	# 4 cm behind its eyepiece - the cheek off the comb, as with any optic on the handle.
	"m16.sight.colt": {"sight": "colt", "rear_sight": Vector3(0.0, 0.142, -0.07), "front_sight": Vector3(0.0, 0.142, 0.075),
			"eye_relief": 0.04},
	# The P90's can over its hider (tools/make_p90_blockout.py): its end 0.318 ahead of the origin.
	"p90.suppressor.on": {"model_variants": {"Muzzle": "Can"}, "muzzle": Vector3(0.0, 0.0209, 0.318),
			"sound_shot": "shot_suppressed"},
	# Гроза (tools/make_groza_blockout.py): the base is the short barrel with its compensator, the irons in the carry
	# frame. The can 0.2519 past the compensator, the muzzle grip's housing 0.0807; the left hand on the fore grip.
	"groza.suppressor.on": {"model_variants": {"Muzzle": "Can"}, "muzzle": Vector3(0.0, 0.0295, 0.3678),
			"sound_shot": "shot_suppressed"},
	"groza.grip.on": {"model_variants": {"Muzzle": "Grip"}, "muzzle": Vector3(0.0, 0.0295, 0.1966),
			"left_hand": Vector3(0.0, -0.0428, 0.1368)},
	"groza.mag.40": {"model_variants": {"Mags": "Groza_Mag_40"}},
	# The PO 4x34 on the carry frame's bar, its axis 17 mm over the irons' line; no eye cup (owner): the eye 8 cm
	# behind the eyepiece (closer, its bell filled the screen).
	"groza.sight.po": {"sight": "po", "rear_sight": Vector3(0.0, 0.1397, -0.109), "front_sight": Vector3(0.0, 0.1397, 0.0),
			"eye_relief": 0.08},
	# АС ВАЛ (tools/make_val_blockout.py): the base is the can, the wire stock, the 20, the irons. The Vikhr's short barrel
	# brings its own irons, the rear one on the receiver: the eye stays at the cheek; the left hand on its handguard.
	"val.barrel.short": {"model_variants": {"Barrel": "Short"}, "muzzle": Vector3(0.0, 0.0174, 0.2778), "sound_shot": "shot",
			"rear_sight": Vector3(0.0, 0.0639, 0.0728), "front_sight": Vector3(0.0, 0.0639, 0.2298), "eye_relief": 0.2329,
			"left_hand": Vector3(0.0, 0.0, 0.1809)},
	"val.stock.wood": {"model_variants": {"Stock": "Wood"}, "right_hand": Vector3(0.0, -0.0587, -0.0634)},
	"val.mag.10": {"model_variants": {"Mags": "Val_Mag_10"}},
	"val.mag.30": {"model_variants": {"Mags": "Val_Mag_30"}},
	# The Groza's PO on the Kobra's side mount: its axis 34 mm over the receiver's top, over the receiver's back. The eye
	# 8 cm behind the eyepiece, as on the Groza. After val.barrel.short in a build: these points are the last set.
	"val.sight.po": {"sight": "po_side", "sight_offset": Vector3(0.0, -0.0597, -0.02),
			"rear_sight": Vector3(0.0, 0.08, -0.129), "front_sight": Vector3(0.0, 0.08, -0.02), "eye_relief": 0.08},
	# Armsel Striker (tools/make_striker_blockout.py): the base is the Striker body, the stock out. The Bulldog: the
	# same drum, its own block body without a stock, the 7.8" barrel; held out further, the eye 0.38 behind the strap.
	"striker.conversion.bulldog": {"model_variants": {"Body": "Bulldog"}, "muzzle": Vector3(0.0, 0.0458, 0.3029),
			"rear_sight": Vector3(0.0, 0.0843, 0.0418), "front_sight": Vector3(0.0, 0.0843, 0.264), "eye_relief": 0.38,
			"right_hand": Vector3(0.0, -0.0346, -0.0711), "left_hand": Vector3(0.0, -0.0022, 0.2217),
			"hip_offset": Vector3(0.16, -0.14, -0.3)},
	# Folded over the top, the butt flat over the shroud: the eye looks along the folded arm, over the irons.
	"striker.stock.folded": {"model_variants": {"Body/Striker/Stock": "Folded"},
			"rear_sight": Vector3(0.0, 0.107, -0.05), "front_sight": Vector3(0.0, 0.107, 0.2), "eye_relief": 0.2},
}
## Points in prefab space: scaled by WeaponDef.model_scale (WeaponDB keeps them life size, as the model is built).
const SCALED_POINTS: Array[String] = ["muzzle", "rear_sight", "front_sight", "right_hand", "left_hand",
		"ejection_port", "charging_handle", "break_hinge", "chamber", "forend", "lever_pivot", "shell_port", "mag_hinge",
		"shell_grip", "shell_from"]
const MODULE_SLOT_NAMES := {"barrel": "Ствол", "suppressor": "Глушитель", "conversion": "Переделка", "mag": "Магазин", "stock": "Приклад", "grip": "Рукоятка",
		"muzzle": "Дульное", "sight": "Прицел", "ammo": "Патрон", "akimbo": "Акимбо"}

static var _defs: Array[WeaponDef] = []
static var _base := {}       # weapon id -> its config section (config units)
static var _modules := {}    # "ak.mag.drum75" -> {id, weapon, slot, name, info, requires, values}
static var _module_ids: Array[String] = []  # in file order: the first of each slot is its default
static var _kits := []        # [kit.<id>] sections in file order (kits())
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


## A number of the grenade (weapons.cfg [grenade]: speed, fuse, blast_damage, ...), `fallback` if not set.
static func grenade(key: String, fallback: float) -> float:
	_build()
	return float((_base.get("grenade", {}) as Dictionary).get(key, fallback))


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
				if prop == "model_scale":  # a bigger gun: the points the base scaled grow with it
					for point in SCALED_POINTS:
						def.set(point, def.get(point) * float(value) / def.model_scale)
				if prop in SCALED_POINTS or (adding and prop == "eye_relief"):  # an added relief follows a sight that moved
					value = value * def.model_scale
				if adding:
					value = def.get(prop) + value
				elif value is Dictionary:
					value = (def.get(prop) as Dictionary).merged(value, true)  # a new one: the base's stays as it is
				def.set(prop, value)
	return def


## Modules of `weapon_id` for `slot`, the default first: [{id, weapon, slot, name, info, cost, requires, excludes,
## hidden, values}].
static func modules_for(weapon_id: String, slot: String) -> Array:
	_build()
	var list := []
	for id in _module_ids:
		var module: Dictionary = _modules[id]
		if module["weapon"] == weapon_id and module["slot"] == slot:
			list.append(module)
	return list


## The kits (weapons.cfg [kit.<id>]), in the config's order: [{id, name, weapon, modules (full module ids)}].
static func kits() -> Array:
	_build()
	return _kits


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
	_kits.clear()
	for section in cfg.get_sections():
		var values := {}
		for key in cfg.get_section_keys(section):
			values[key] = cfg.get_value(section, key)
		var path := section.split(".")
		if path.size() == 1:
			_base[section] = values
		elif path.size() == 2 and path[0] == "kit":
			var weapon := str(values.get("weapon", ""))
			var modules := []
			for module in values.get("modules", []):
				modules.append(weapon + "." + str(module))
			_kits.append({"id": section, "name": str(values.get("name", path[1])), "weapon": weapon, "modules": modules})
		elif path.size() == 3 and MODULE_SLOTS.has(path[1]):
			var module := {"id": section, "weapon": path[0], "slot": path[1],
					"name": str(values.get("name", path[2])), "info": str(values.get("info", "")),
					"requires": _part_id(path[0], str(values.get("requires", ""))),
					"forces": _part_id(path[0], str(values.get("forces", ""))),
					"excludes": str(values.get("excludes", "")), "hidden": bool(values.get("hidden", false)), "values": {}}
			for key in values:
				if not key in ["name", "info", "requires", "forces", "excludes", "hidden"]:
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


## A part id from the config: "slot.name" is a module of `weapon`, a bare id any other part.
static func _part_id(weapon: String, id: String) -> String:
	return weapon + "." + id if "." in id else id


static func _apply_module(values: Dictionary, changes: Dictionary) -> void:
	for key: String in changes:
		if key.ends_with("_add"):
			var added := key.trim_suffix("_add")
			values[added] = float(values.get(added, 0.0)) + float(changes[key])
		elif key.ends_with("_mult"):
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
	def.pellet_spread = deg_to_rad(float(v.get("pellet_spread", rad_to_deg(def.pellet_spread))))
	def.reload_single = bool(v.get("reload_single", def.reload_single))
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
	def.loudness = float(v.get("loudness", def.loudness))
	def.muzzle_flash = bool(v.get("muzzle_flash", def.muzzle_flash))
	def.tracer = bool(v.get("tracer", def.tracer))
	def.head_mult = float(v.get("head_mult", def.head_mult))
	def.regen_block = float(v.get("regen_block", def.regen_block))
	def.sound_pitch = float(v.get("sound_pitch", def.sound_pitch))
	def.akimbo = bool(v.get("akimbo", def.akimbo))
	def.akimbo_spread = float(v.get("akimbo_spread", def.akimbo_spread))
	def.akimbo_reload = float(v.get("akimbo_reload", def.akimbo_reload))


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
	rifle.display_name = "Хрюкашников"
	rifle.scene_path = "res://prefabs/weapons/ak_blockout.tscn"  # tools/make_ak_blockout.py
	rifle.model_variants = {"Muzzle": "Slant", "Mags": "AK_Mag_30"}
	rifle.muzzle = Vector3(0.0, 0.045, 0.565)
	rifle.rear_sight = Vector3(0.0, 0.118, 0.28)   # top of the rear leaf (the post's tip flush with it)
	rifle.front_sight = Vector3(0.0, 0.118, 0.5)   # tip of the front post
	rifle.eye_relief = 0.46  # eye over the stock comb, behind the receiver
	rifle.right_hand = Vector3(0.0, -0.055, -0.062)
	rifle.left_hand = Vector3(0.0, 0.0, 0.35)
	rifle.ejection_port = Vector3(-0.027, 0.058, 0.07)  # right side of the receiver (prefab -x = the shooter's right)
	rifle.charging_handle = Vector3(-0.036, 0.062, 0.13)
	rifle.sound_shot = "shot"
	rifle.hip_offset = Vector3(0.17, -0.165, -0.24)
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
	pdw.hip_offset = Vector3(0.16, -0.14, -0.3)  # short: further out than the AK, so its muzzle is where the AK's is
	_defs.append(pdw)

	var luger := WeaponDef.new()
	luger.id = "luger"
	luger.display_name = "Хрюгер"
	luger.scene_path = "res://prefabs/weapons/luger_blockout.tscn"  # tools/make_luger_blockout.py
	# The artillery model's 200 mm barrel (owner, 2026-10-23): its tangent sight replaces the toggle's notch.
	luger.model_variants = {"Barrel": "B200", "Toggle/LinkRear/Sight": "Plain", "Stock": "None", "Mags": "Luger_Mag_8"}
	luger.muzzle = Vector3(0.0, 0.03, 0.21)
	luger.rear_sight = Vector3(0.0, 0.05, 0.0485)  # the tangent sight's ears' tops
	luger.front_sight = Vector3(0.0, 0.05, 0.202)
	luger.eye_relief = 0.38 + LUGER_SIGHT_AHEAD * LUGER_SCALE  # arms out, a little bent: 0.38 behind the toggle's notch
	luger.model_scale = LUGER_SCALE
	luger.right_hand = Vector3(0.0, -0.035, -0.06)   # the middle of the grip
	luger.left_hand = Vector3(0.0, -0.08, -0.078)   # cupped under the right hand and the magazine's base
	luger.ejection_port = Vector3(0.0, 0.045, -0.01)    # up out of the open toggle
	luger.charging_handle = Vector3(-0.017, 0.0384, -0.059)  # the right knob: the hand racks the toggle (no handle added)
	luger.bolt_travel = 0.045
	luger.sound_shot = "shot_pistol"
	luger.hip_offset = Vector3(0.15, -0.13, -0.3)
	_defs.append(luger)

	var acr := WeaponDef.new()
	acr.id = "acr"
	acr.display_name = "ACR"
	acr.scene_path = "res://prefabs/weapons/acr_blockout.tscn"  # tools/make_acr_blockout.py
	acr.model_variants = {"Barrel": "B145", "Barrel/B105/Muzzle": "Brake", "Barrel/B145/Muzzle": "Brake",
			"Barrel/B185/Muzzle": "Brake", "Stock": "Extended", "Stock/Extended/Butt": "Out", "Stock/Folded/Butt": "In",
			"Mags": "ACR_Mag_30", "Sights": "Up"}
	acr.muzzle = Vector3(0.0, 0.05, 0.548)
	acr.rear_sight = Vector3(0.0, 0.113, -0.05)   # top of the rear ears (the post's tip flush with them)
	acr.front_sight = Vector3(0.0, 0.113, 0.31)   # tip of the front post
	acr.eye_relief = 0.15  # cheek on the comb
	acr.right_hand = Vector3(0.0, -0.04, -0.076)
	acr.left_hand = Vector3(0.0, 0.015, 0.29)
	acr.ejection_port = Vector3(-0.027, 0.06, 0.06)
	acr.charging_handle = Vector3(0.03, 0.0695, 0.2)  # forward on the left, under the top's bevel
	acr.handle_reciprocates = false
	acr.bolt_travel = 0.08
	acr.sound_shot = "shot"
	acr.hip_offset = Vector3(0.17, -0.165, -0.24)
	_defs.append(acr)

	var mp7 := WeaponDef.new()
	mp7.id = "mp7"
	mp7.display_name = "MP7"
	mp7.scene_path = "res://prefabs/weapons/mp7_blockout.tscn"  # tools/make_mp7_blockout.py
	mp7.model_variants = {"Stock": "Extended", "Foregrip": "Unfolded", "Muzzle": "Hider", "Sights": "Up",
			"Mags": "MP7_Mag_40"}
	mp7.muzzle = Vector3(0.0, 0.0217, 0.2106)
	mp7.rear_sight = Vector3(0.0, 0.104, -0.132)  # top of the rear ears (the post's tip flush with them)
	mp7.front_sight = Vector3(0.0, 0.104, 0.108)  # tip of the front post
	mp7.eye_relief = 0.23  # the stock out (0.223 m on its rods): 0.1 further than the cheek right behind the receiver
	mp7.right_hand = Vector3(0.0, -0.045, -0.047)  # the middle of the grip
	mp7.left_hand = Vector3(0.0, -0.05, 0.124)     # on the foregrip
	mp7.ejection_port = Vector3(-0.022, 0.04, 0.015)
	mp7.charging_handle = Vector3(0.0, 0.058, -0.18)  # at the rear under the rail, as an AR's
	mp7.handle_reciprocates = false
	mp7.bolt_travel = 0.04
	mp7.sound_shot = "shot"
	mp7.hip_offset = Vector3(0.16, -0.14, -0.3)
	_defs.append(mp7)

	var contender := WeaponDef.new()
	contender.id = "contender"
	contender.display_name = "Contender"
	contender.scene_path = "res://prefabs/weapons/contender_blockout.tscn"  # tools/make_contender_blockout.py
	contender.muzzle = Vector3(0.0, 0.0438, 0.335)
	contender.rear_sight = Vector3(0.0, 0.069, 0.002)   # the rear leaf's ears' tops (the blade's tip flush with them)
	contender.front_sight = Vector3(0.0, 0.069, 0.314)  # the front blade's tip
	contender.eye_relief = 0.48  # arms out, as the Luger's: the eye ~0.48 behind the trigger
	contender.right_hand = Vector3(0.0, -0.03, -0.054)  # the middle of the grip
	contender.left_hand = Vector3(0.0, -0.075, -0.07)   # cupped under the right hand
	contender.break_hinge = Vector3(0.0, 0.0149, 0.0231)
	contender.chamber = Vector3(0.0, 0.0438, -0.019)
	contender.forend = Vector3(0.0, 0.0, 0.17)  # under the fore-end, two thirds along it
	contender.sound_shot = "shot"
	contender.hip_offset = Vector3(0.15, -0.13, -0.3)
	_defs.append(contender)

	var winchester := WeaponDef.new()
	winchester.id = "winchester"
	winchester.display_name = "Winchester 1887"
	winchester.scene_path = "res://prefabs/weapons/winchester_blockout.tscn"  # tools/make_winchester_blockout.py
	winchester.muzzle = Vector3(0.0, 0.073, 0.64)
	winchester.rear_sight = Vector3(0.0, 0.0895, 0.094)  # the top of the receiver front's cheeks round the slot
	winchester.front_sight = Vector3(0.0, 0.0895, 0.625)  # the bead's top (the hammer stays under the eye's line to the slot)
	winchester.eye_relief = 0.22  # the cheek on the comb's nose; at 0.42 (near the butt) the gun was a speck, the hand in view
	winchester.right_hand = Vector3(0.0, -0.024, -0.061)  # on the wrist, the fingers in the lever's loop
	winchester.left_hand = Vector3(0.0, 0.028, 0.27)     # under the fore-end
	winchester.lever_pivot = Vector3(0.0, 0.012, 0.07)
	winchester.shell_port = Vector3(0.0, 0.092, 0.07)  # the open action's top
	winchester.sound_shot = "shot_shotgun"
	winchester.hip_offset = Vector3(0.17, -0.165, -0.24)
	_defs.append(winchester)

	var mk14 := WeaponDef.new()
	mk14.id = "mk14"
	mk14.display_name = "MK14"
	mk14.scene_path = "res://prefabs/weapons/mk14_blockout.tscn"  # tools/make_mk14_blockout.py
	mk14.model_variants = {"Mags": "Mk14_Mag_20", "Sights": "Up", "FrontSight": "On"}
	mk14.muzzle = Vector3(0.0, 0.063, 0.647)
	mk14.rear_sight = Vector3(0.0, 0.097, 0.025)   # the rear aperture's middle (the post's tip in it)
	mk14.front_sight = Vector3(0.0, 0.097, 0.546)  # the front post's tip
	mk14.eye_relief = 0.16  # cheek on the rest, the eye close behind the aperture
	mk14.right_hand = Vector3(0.0, -0.042, -0.067)  # the middle of the grip
	mk14.left_hand = Vector3(0.0, 0.003, 0.34)      # under the handguard
	mk14.ejection_port = Vector3(-0.012, 0.072, 0.09)  # up and right out of the receiver's top
	mk14.charging_handle = Vector3(-0.026, 0.05, 0.1)  # the op-rod handle on the right, rides the bolt
	mk14.bolt_travel = 0.09
	mk14.sound_shot = "shot"
	mk14.hip_offset = Vector3(0.17, -0.165, -0.24)
	_defs.append(mk14)

	var p90 := WeaponDef.new()
	p90.id = "p90"
	p90.display_name = "P90"
	p90.scene_path = "res://prefabs/weapons/p90_blockout.tscn"  # tools/make_p90_blockout.py
	p90.model_variants = {"Muzzle": "Hider"}
	p90.sight = "ring"  # the integral ring sight: its housing is the gun's, SightModels draws the glass and the reticle
	p90.muzzle = Vector3(0.0, 0.0209, 0.1678)
	p90.rear_sight = Vector3(0.0, 0.0871, -0.0272)  # the sight window's middle, its back
	p90.front_sight = Vector3(0.0, 0.0871, 0.1254)  # and its front
	p90.eye_relief = 0.12  # cheek forward on the butt's top: at 0.2 the window was a slot in a black box
	p90.right_hand = Vector3(0.0, -0.024, -0.038)  # the grip between the thumb hole and the trigger hole
	p90.left_hand = Vector3(0.0, -0.024, 0.093)    # under the front, behind the hook
	p90.ejection_port = Vector3(0.0, -0.063, -0.166)  # the chute in the bottom behind the grip
	p90.eject_down = true
	p90.charging_handle = Vector3(0.034, 0.0163, 0.0768)  # the left knob under the sight (the model's "Handle")
	p90.handle_reciprocates = false
	p90.bolt_travel = 0.08
	p90.mag_hinge = Vector3(0.0, 0.0361, 0.0825)
	p90.sound_shot = "shot"
	p90.hip_offset = Vector3(0.16, -0.14, -0.3)
	_defs.append(p90)

	var aug := WeaponDef.new()
	aug.id = "aug"
	aug.display_name = "AUG"
	aug.scene_path = "res://prefabs/weapons/aug_blockout.tscn"  # tools/make_aug_blockout.py
	aug.model_variants = {"Upper": "A1", "Upper/A3/Sights": "Up", "Barrel": "B508", "Barrel/B508/Muzzle": "Hider",
			"Barrel/B350/Muzzle": "Hider", "Barrel/B508/Front": "Bare", "Barrel/B508/Front/Bare/Grip": "Unfolded",
			"Barrel/B508/Front/Rail/Grip": "On", "Barrel/B350/Grip": "On", "Mags": "AUG_Mag_30"}
	# The A1's integral 1.5x scope (SightModels "swarovski"), seen as the ACOG: the world through its tube.
	aug.sight = "swarovski"
	aug.muzzle = Vector3(0.0, 0.0361, 0.3874)
	aug.rear_sight = Vector3(0.0, 0.1064, -0.1407)  # the scope's axis at the eyepiece
	aug.front_sight = Vector3(0.0, 0.1064, 0.0678)  # and at the objective
	aug.eye_relief = 0.0745  # the cheek on the butt, ~75 mm behind the eyepiece
	aug.right_hand = Vector3(0.0, -0.043, -0.0598)  # the middle of the grip
	aug.left_hand = Vector3(0.0, -0.043, 0.1367)    # on the support grip
	aug.ejection_port = Vector3(-0.026, 0.0387, -0.1694)  # out of the butt's right, behind the grip
	aug.charging_handle = Vector3(0.026, 0.0426, 0.1076)  # the olive hook on the left (the model's "Handle")
	aug.bolt_travel = 0.08
	aug.sound_shot = "shot"
	aug.hip_offset = Vector3(0.16, -0.14, -0.3)  # a bullpup, as the P90
	_defs.append(aug)

	var m16 := WeaponDef.new()
	m16.id = "m16"
	m16.display_name = "M16A1"
	m16.scene_path = "res://prefabs/weapons/m16_blockout.tscn"  # tools/make_m16_blockout.py
	m16.model_variants = {"Barrel": "B508", "Barrel/B508/Muzzle": "Hider", "Barrel/B368/Muzzle": "Hider",
			"Stock": "A1", "Stock/CAR/Slide": "Out", "Mags": "M16_Mag_30"}
	m16.muzzle = Vector3(0.0, 0.0548, 0.6814)
	m16.rear_sight = Vector3(0.0, 0.1183, -0.0286)  # the A1 aperture's middle, on the handle's back (2.5" over the bore)
	m16.front_sight = Vector3(0.0, 0.1183, 0.4926)  # the post's tip
	m16.eye_relief = 0.09  # the cheek on the comb
	m16.right_hand = Vector3(0.0, -0.0405, -0.0655)  # the middle of the grip
	m16.left_hand = Vector3(0.0, 0.0286, 0.2859)    # under the handguard
	m16.ejection_port = Vector3(-0.016, 0.0596, 0.0655)
	m16.charging_handle = Vector3(0.0, 0.0762, -0.0643)  # the T handle at the upper's back (the model's "Handle")
	m16.handle_reciprocates = false
	m16.bolt_travel = 0.08
	m16.sound_shot = "shot"
	m16.hip_offset = Vector3(0.17, -0.165, -0.24)
	_defs.append(m16)

	var groza := WeaponDef.new()
	groza.id = "groza"
	groza.display_name = "Гроза"
	groza.scene_path = "res://prefabs/weapons/groza_blockout.tscn"  # tools/make_groza_blockout.py
	groza.model_variants = {"Muzzle": "Comp", "Mags": "Groza_Mag_30"}
	groza.muzzle = Vector3(0.0, 0.0295, 0.1159)
	groza.rear_sight = Vector3(0.0, 0.1226, -0.1211)  # the rear leaf's ears' tops in the frame's rear post
	groza.front_sight = Vector3(0.0, 0.1226, 0.0461)  # the post's tip in the front post
	groza.eye_relief = 0.12  # the cheek forward on the receiver
	groza.right_hand = Vector3(0.0, -0.0541, -0.0522)  # the middle of the grip
	groza.left_hand = Vector3(0.0, -0.01, 0.045)      # under the front body, by the frame's front post
	groza.ejection_port = Vector3(-0.017, 0.0437, -0.2612)  # the AK's port by the cheek
	groza.charging_handle = Vector3(-0.012, 0.0693, -0.1349)  # forward on the right over the well (the model's "Handle")
	groza.bolt_travel = 0.08
	groza.sound_shot = "shot"
	groza.hip_offset = Vector3(0.16, -0.14, -0.3)  # a bullpup, as the AUG
	_defs.append(groza)

	var val := WeaponDef.new()
	val.id = "val"
	val.display_name = "АС ВАЛ"
	val.scene_path = "res://prefabs/weapons/val_blockout.tscn"  # tools/make_val_blockout.py
	val.model_variants = {"Barrel": "Can", "Stock": "Wire", "Mags": "Val_Mag_20"}
	val.muzzle = Vector3(0.0, 0.0174, 0.5237)
	val.rear_sight = Vector3(0.0, 0.0498, 0.2101)  # the notch's top, on the can's back
	val.front_sight = Vector3(0.0, 0.0498, 0.4996)  # the post's tip on the can's nose
	val.eye_relief = 0.3701  # the eye over the stock, behind the receiver
	val.right_hand = Vector3(0.0, -0.0541, -0.0541)  # the middle of the grip
	val.left_hand = Vector3(0.0, -0.0127, 0.1575)    # under the handguard
	val.ejection_port = Vector3(-0.017, 0.0268, 0.0658)
	val.charging_handle = Vector3(-0.016, 0.0211, 0.1011)  # in the port on the right (the model's "Handle")
	val.bolt_travel = 0.08
	val.sound_shot = "shot_suppressed"
	val.hip_offset = Vector3(0.17, -0.165, -0.24)
	_defs.append(val)

	var striker := WeaponDef.new()
	striker.id = "striker"
	striker.display_name = "Striker"
	striker.scene_path = "res://prefabs/weapons/striker_blockout.tscn"  # tools/make_striker_blockout.py
	striker.model_variants = {"Body": "Striker", "Body/Striker/Stock": "Extended"}
	striker.muzzle = Vector3(0.0, 0.0458, 0.4205)
	striker.rear_sight = Vector3(0.0, 0.0826, 0.0454)   # the notch's ears on the strap's back, over the drum
	striker.front_sight = Vector3(0.0, 0.0826, 0.3649)  # the blade's tip
	striker.eye_relief = 0.25  # the cheek on the stock's arm, behind the receiver
	striker.right_hand = Vector3(0.0, -0.0583, -0.07)  # the middle of the grip
	striker.left_hand = Vector3(0.0, -0.0174, 0.2478)  # on the foregrip
	# The loading gate: the chamber at 3 o'clock seen from behind, on the drum's back right; the left hand pushes the
	# shell in forward from behind it (the gun canted, its right side up), the hull flies out of it after a shot.
	striker.shell_port = Vector3(-0.054, -0.0082, 0.004)
	striker.shell_grip = Vector3(-0.042, 0.0, 0.0)
	striker.shell_from = Vector3(-0.03, 0.0, -0.06)
	striker.ejection_port = Vector3(-0.054, -0.0082, 0.02)
	striker.eject_hull = true
	striker.loads_right_hand = true  # the left holds it by the foregrip (owner, 2026-11-07)
	striker.sound_shot = "shot_shotgun"
	striker.hip_offset = Vector3(0.17, -0.165, -0.24)
	_defs.append(striker)

	for def in _defs:
		for prop in SCALED_POINTS:
			def.set(prop, def.get(prop) * def.model_scale)
