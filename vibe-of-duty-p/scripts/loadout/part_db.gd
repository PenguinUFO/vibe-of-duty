class_name PartDB
extends RefCounted
## The parts a build is made of (Docs/LOADOUT.md) and the rules: one part per slot - the weapon, its modules
## (from weapons.cfg, WeaponDB) and the kit. Players pick a kit (weapons.cfg [kit.<id>]: a weapon with its modules,
## owner 2026-10-31); the weapons stay under the hood. Everybody can change the kit's modules (owner, 2026-11-09: no
## augmentations, no tokens). A build travels as an Array of part ids in SLOTS order; anything invalid (unknown id,
## wrong slot, a module whose "requires" is missing) turns into the native parts (sanitize), so the server never
## applies a build it did not check.

const WEAPON_SLOTS: Array[String] = ["weapon", "barrel", "suppressor", "conversion", "stock", "mag", "grip", "muzzle",
		"sight", "ammo", "akimbo"]
## Slots hidden for now (owner, 2026-10-23): the editor does not show them and every build has their defaults. The
## parts stay (weapons.cfg); dropping a slot from here brings it back. The grip is back for the AUG (2026-11-02); the
## MP7's folded grip stays hidden by its module ("hidden" in weapons.cfg).
const HIDDEN_SLOTS: Array[String] = ["muzzle", "ammo"]
const SLOTS: Array[String] = ["weapon", "barrel", "suppressor", "conversion", "stock", "mag", "grip", "muzzle", "sight", "ammo",
		"akimbo", "kit"]
const SLOT_NAMES := {"weapon": "Оружие", "barrel": "Ствол", "suppressor": "Глушитель", "conversion": "Переделка", "mag": "Магазин", "stock": "Приклад", "grip": "Рукоятка",
		"muzzle": "Дульное", "sight": "Прицел", "ammo": "Патрон", "akimbo": "Акимбо", "kit": "Комплектация"}

static var _parts: Array[PartDef] = []
static var _by_id := {}
static var _weapons_version := -1  # WeaponDB.version the module parts were made from


static func all() -> Array[PartDef]:
	_build()
	return _parts


static func get_part(id: String) -> PartDef:
	_build()
	return _by_id.get(id)


## The parts that fit `slot`, the native one first; a module slot: those of `weapon` (an id).
static func for_slot(slot: String, weapon := "") -> Array[PartDef]:
	var list: Array[PartDef] = []
	for part in all():
		if part.slot == slot and part.weapon == weapon:
			list.append(part)
	return list


## The parts `slot` offers in a build with this weapon (an id): its modules, or the weapons / kits. The kits go
## in weapons.cfg's order: by the kind of weapon (owner, 2026-11-05).
static func options(slot: String, weapon: String) -> Array[PartDef]:
	return for_slot(slot, weapon if WEAPON_SLOTS.has(slot) and slot != "weapon" else "")


## The native build: the kit `kit` (an id; the first kit if it is not one) - its weapon with
## its modules, the other slots at their defaults ("" for a slot weapons.cfg has no modules for).
static func default_build(kit := "") -> Array:
	var kit_part := get_part(kit)
	if kit_part == null or kit_part.slot != "kit":
		kit_part = for_slot("kit")[0]
	var weapon := kit_part.kit_weapon
	var parts := []
	for slot in SLOTS:
		var list := options(slot, weapon)
		parts.append(weapon if slot == "weapon" else kit_part.id if slot == "kit" else list[0].id if not list.is_empty() else "")
	for id: String in kit_part.kit_modules:
		parts[SLOTS.find(get_part(id).slot)] = id
	return parts


## The kit a build saved before the kits gets: the weapon's kit without modules, else its first one, else the first.
static func kit_for_weapon(weapon: String) -> PartDef:
	var first: PartDef = null
	for kit in for_slot("kit"):
		if kit.kit_weapon == weapon:
			if kit.kit_modules.is_empty():
				return kit
			if first == null:
				first = kit
	return first if first != null else for_slot("kit")[0]


## The build's kit part.
static func kit_of(parts: Array) -> PartDef:
	var kit := get_part(str(parts[SLOTS.find("kit")])) if parts.size() == SLOTS.size() else null
	return kit if kit != null and kit.slot == "kit" else for_slot("kit")[0]


## True if the build's modules are not its kit's.
static func is_custom(parts: Array) -> bool:
	var kit := default_build(kit_of(parts).id)
	for i in range(1, WEAPON_SLOTS.size()):
		if str(parts[i]) != str(kit[i]):
			return true
	return false


## The kit's name as players see it: "Хрюгер", "Хрюгер кастом" when its modules were changed.
static func kit_name(parts: Array) -> String:
	return kit_of(parts).display_name + (" кастом" if is_custom(parts) else "")


## A valid build from anything: the kit's weapon with the kit's modules, changed by the other modules of that weapon
## (not hidden); wrong or missing parts become native, so do the HIDDEN_SLOTS, modules whose "requires" is not in the
## build, the slot another part "excludes" (the AK's suppressor: the muzzle) and the part another one "forces" (the
## akimbo's folded stock). A build without a kit (saved before them) gets kit_for_weapon. Each id goes to its part's
## slot, so the order and missing slots do not matter (--build=kit.ak,ak.suppressor.on); ids that are no part (the
## augmentations of old saved builds) are dropped.
static func sanitize(parts: Variant) -> Array:
	if not parts is Array:
		return default_build()
	var kit := ""
	var weapon := ""
	for id in parts:
		var part := get_part(str(id))
		if part != null and part.slot == "kit":
			kit = part.id
		elif part != null and part.slot == "weapon":
			weapon = part.id
	if kit == "":
		kit = kit_for_weapon(weapon).id
	var clean := default_build(kit)
	for id in parts:
		var part := get_part(str(id))
		if part != null and part.slot != "weapon" and WEAPON_SLOTS.has(part.slot) and part.weapon == clean[0] \
				and not part.slot in HIDDEN_SLOTS:
			clean[SLOTS.find(part.slot)] = part.id
	_drop_unmet(clean)  # first: a module that goes must not leave its "excludes" and "forces" behind
	for i in SLOTS.size():
		var part := get_part(clean[i])
		if part != null and part.excludes != "":
			for slot in part.excludes.split(","):
				var kept := options(slot, clean[0])
				clean[SLOTS.find(slot)] = kept[0].id if not kept.is_empty() else ""
		if part != null and part.forces != "":
			clean[SLOTS.find(get_part(part.forces).slot)] = part.forces
	_drop_unmet(clean)
	return clean


## Modules whose "requires" is not in the build go back to their slot's default.
static func _drop_unmet(clean: Array) -> void:
	for i in SLOTS.size():
		var part := get_part(clean[i])
		if part != null and part.requires != "" and not clean.has(part.requires):
			clean[i] = options(SLOTS[i], clean[0])[0].id


## The weapon as a (sanitized) build plays it, for statistics (MatchStats): its kit and the modules that are not the
## kit's, without the weapon prefix - "ak", "ak+suppressor.on".
static func variant_name(parts: Array) -> String:
	var kit := kit_of(parts)
	var native := default_build(kit.id)
	var variant := kit.id.trim_prefix("kit.")
	for i in range(1, WEAPON_SLOTS.size()):
		var id := str(parts[i])
		if id != "" and id != str(native[i]):
			variant += "+" + id.trim_prefix(str(parts[0]) + ".")
	return variant


## The part ids of the build's weapon modules (for WeaponDB.make_def).
static func weapon_modules(parts: Array) -> Array:
	return parts.slice(1, WEAPON_SLOTS.size())


static func _build() -> void:
	if not _parts.is_empty() and _weapons_version == WeaponDB.version:
		return
	WeaponDB.count()  # loads the config
	_weapons_version = WeaponDB.version
	_parts.clear()
	# The weapons (WeaponDB order: the first is the native one) and their modules, as weapons.cfg lists them (the
	# first of a slot is its default).
	for i in WeaponDB.count():
		var def := WeaponDB.get_def(i)
		_parts.append(PartDef.make(def.id, "weapon", def.display_name, def.info))
		for slot in WEAPON_SLOTS.slice(1):
			for module: Dictionary in WeaponDB.modules_for(def.id, slot):
				if module["hidden"]:
					continue  # weapons.cfg "hidden": kept for later, not offered (a build with it goes native)
				var part := PartDef.make(module["id"], slot, module["name"], module["info"])
				part.requires = module["requires"]
				part.excludes = module["excludes"]
				part.forces = module["forces"]
				part.weapon = def.id
				_parts.append(part)
	_by_id.clear()
	for part in _parts:
		_by_id[part.id] = part
	# The kits (weapons.cfg [kit.<id>], in its order); a config without them: one bare kit per weapon.
	var kits: Array = WeaponDB.kits().duplicate()
	if kits.is_empty():
		for i in WeaponDB.count():
			var def := WeaponDB.get_def(i)
			kits.append({"id": "kit." + def.id, "name": def.display_name, "weapon": def.id, "modules": []})
	for kit: Dictionary in kits:
		var part := PartDef.make(kit["id"], "kit", kit["name"], "")
		part.kit_weapon = kit["weapon"]
		var known: PartDef = _by_id.get(part.kit_weapon)
		if known == null or known.slot != "weapon":
			push_error("weapons.cfg: [%s] has no weapon '%s'" % [part.id, part.kit_weapon])
			continue
		for id: String in kit["modules"]:
			var module: PartDef = _by_id.get(id)
			if module == null or module.weapon != part.kit_weapon:
				push_error("weapons.cfg: [%s] - no module '%s' (hidden or not there)" % [part.id, id])
				continue
			part.kit_modules.append(id)
		_parts.append(part)
		_by_id[part.id] = part
