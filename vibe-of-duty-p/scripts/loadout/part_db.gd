class_name PartDB
extends RefCounted
## The parts a build is made of (Docs/LOADOUT.md) and the rules: one part per slot - the weapon, its modules
## (from weapons.cfg, WeaponDB), the body and the kit - and BUDGET tokens per build. Players pick a kit (weapons.cfg
## [kit.<id>]: a weapon with its modules, owner 2026-10-31); the weapons stay under the hood. The kit's modules can be
## changed only with the "Инженер" in the head. A build travels as an Array of part ids in SLOTS order; anything
## invalid (unknown id, wrong slot, a module whose "requires" is missing, over budget) turns into the native parts
## (sanitize), so the server never applies a build it did not check.

const WEAPON_SLOTS: Array[String] = ["weapon", "suppressor", "conversion", "stock", "mag", "grip", "muzzle", "sight",
		"ammo"]
## Slots hidden for now (owner, 2026-10-23): the editor does not show them and every build has their defaults. The
## parts stay (weapons.cfg); dropping a slot from here brings it back.
const HIDDEN_SLOTS: Array[String] = ["grip", "muzzle", "ammo"]
## Slots the editor shows and the saved builds keep, but no match plays yet (owner, 2026-10-31: the organs, buttons
## only): sanitize puts the native part in unless asked to keep them. Their price counts in the editor's tokens.
const INERT_SLOTS: Array[String] = ["hands", "head", "chest", "belly", "legs"]
## Parts of the INERT_SLOTS a match does play (owner, 2026-10-31).
const ENGINEER := "engineer"  # the head's chip: with it the kit's modules can be changed (free)
const ACTIVE_PARTS: Array[String] = [ENGINEER]
const BODY_SLOTS: Array[String] = ["hands", "head", "chest", "belly", "legs"]
const SLOTS: Array[String] = ["weapon", "suppressor", "conversion", "stock", "mag", "grip", "muzzle", "sight", "ammo", "hands",
		"head", "chest", "belly", "legs", "kit"]
const SLOT_NAMES := {"weapon": "Оружие", "suppressor": "Глушитель", "conversion": "Переделка", "mag": "Магазин", "stock": "Приклад", "grip": "Рукоятка",
		"muzzle": "Дульное", "sight": "Прицел", "ammo": "Патрон", "hands": "Руки",
		"head": "Голова", "chest": "Грудь", "belly": "Брюхо", "legs": "Ноги", "kit": "Комплектация"}
const BUDGET := 10
## Owner, 2026-10-23: everything costs 0 for now (balance testing). The prices stay in the data (PartDef.cost,
## weapons.cfg): false brings them back.
const FREE := true
## Every number a part can change, at "no change". "_mult" multiply, the rest add up.
const DEFAULT_MODS := {
	"health_add": 0.0,          # max health (on top of kid mode's)
	"regen_delay_add": 0.0,     # s before health comes back
	"damage_taken_mult": 1.0,   # all damage taken (server)
	"head_taken_mult": 1.0,     # damage taken from head hits (server)
	"speed_mult": 1.0,          # walk, sprint and crouch speed
	"sprint_mult": 1.0,         # sprint speed only
	"jump_mult": 1.0,           # jump velocity
	"land_db": 0.0,             # landing sound volume, as heard by everybody
	"reload_mult": 1.0,         # reload time
	"ads_time_mult": 1.0,       # time to raise the sights
	"spread_hip_mult": 1.0,
	"spread_ads_mult": 1.0,
	"melee_damage_mult": 1.0,   # hoof punch damage
	"bag_heal": 0.0,            # HP an ammo bag heals; > 0 also means it gives no ammo (server)
}

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


## The parts `slot` offers in a build with this weapon (an id): its modules, or the body parts / weapons.
static func options(slot: String, weapon: String) -> Array[PartDef]:
	return for_slot(slot, weapon if WEAPON_SLOTS.has(slot) and slot != "weapon" else "")


## The native build: no organs, no implants, the kit `kit` (an id; the first kit if it is not one) - its weapon with
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


## True if the build's modules are not its kit's (changed with the "Инженер").
static func is_custom(parts: Array) -> bool:
	var kit := default_build(kit_of(parts).id)
	for i in range(1, WEAPON_SLOTS.size()):
		if str(parts[i]) != str(kit[i]):
			return true
	return false


## The kit's name as players see it: "AK Кобра", "AK Кобра кастом" when its modules were changed.
static func kit_name(parts: Array) -> String:
	return kit_of(parts).display_name + (" кастом" if is_custom(parts) else "")


static func cost(parts: Array) -> int:
	var total := 0
	for id in parts:
		var part := get_part(str(id))
		if part != null:
			total += price(part)
	return total


## What a part costs in a build now: its price, or 0 while FREE. Kits and modules are free (owner, 2026-10-31).
static func price(part: PartDef) -> int:
	return 0 if FREE or part.slot == "kit" or WEAPON_SLOTS.has(part.slot) else part.cost


## A valid build from anything: the kit's weapon with the kit's modules - other modules only with the ENGINEER in
## (of that weapon, not hidden) - and the body; wrong or missing parts become native, so do the HIDDEN_SLOTS and the
## INERT_SLOTS (but the ACTIVE_PARTS) unless `keep_inert` (a saved build keeps them, a played one does not), modules
## whose "requires" is not in the build and the slot another part "excludes" (the AK's suppressor: the muzzle); over
## budget, the whole build is the kit's native one. A build without a kit (saved before them) gets kit_for_weapon.
## Each id goes to its part's slot, so the order and missing slots do not matter (--build=kit.ak_kobra,engineer).
static func sanitize(parts: Variant, keep_inert := false) -> Array:
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
		if part != null and BODY_SLOTS.has(part.slot) and not part.slot in HIDDEN_SLOTS \
				and (keep_inert or not part.slot in INERT_SLOTS or part.id in ACTIVE_PARTS):
			clean[SLOTS.find(part.slot)] = part.id
	if clean.has(ENGINEER):
		for id in parts:
			var part := get_part(str(id))
			if part != null and part.slot != "weapon" and WEAPON_SLOTS.has(part.slot) and part.weapon == clean[0] \
					and not part.slot in HIDDEN_SLOTS:
				clean[SLOTS.find(part.slot)] = part.id
	for i in SLOTS.size():
		var part := get_part(clean[i])
		if part != null and part.excludes != "":
			for slot in part.excludes.split(","):
				var kept := options(slot, clean[0])
				clean[SLOTS.find(slot)] = kept[0].id if not kept.is_empty() else ""
	for i in SLOTS.size():
		var part := get_part(clean[i])
		if part != null and part.requires != "" and not clean.has(part.requires):
			clean[i] = options(SLOTS[i], clean[0])[0].id
	return clean if cost(clean) <= BUDGET else default_build(kit)


## The weapon as a (sanitized) build plays it, for statistics (MatchStats): its kit and the modules that are not the
## kit's (the "Инженер"), without the weapon prefix - "ak_kobra", "ak_kobra+suppressor.on".
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


## The combined numbers of a (sanitized) build.
static func mods(parts: Array) -> Dictionary:
	var total := DEFAULT_MODS.duplicate()
	for id in parts:
		var part := get_part(str(id))
		if part == null:
			continue
		for key in part.mods:
			if (key as String).ends_with("_mult"):
				total[key] *= part.mods[key]
			else:
				total[key] += part.mods[key]
	return total


static func _build() -> void:
	if not _parts.is_empty() and _weapons_version == WeaponDB.version:
		return
	WeaponDB.count()  # loads the config
	_weapons_version = WeaponDB.version
	_parts.assign([
		PartDef.make("hoof", "hands", 0, "Копыто", "Родное. Удар — 75 урона."),
		PartDef.make("sledge_hoof", "hands", 2, "Копыто-кувалда",
				"Удар убивает сразу. Ходишь на 10% медленнее.", {"melee_damage_mult": 2.0, "speed_mult": 0.9}),
		PartDef.make("head", "head", 0, "Своя голова", "Родная."),
		PartDef.make(ENGINEER, "head", 0, "Инженер", "Чип у правого уха: модули комплектации можно менять."),
		PartDef.make("lead_brow", "head", 1, "Свинцовый лоб",
				"В голову бьют как в тело. Прицеливаешься на 40% дольше.",
				{"head_taken_mult": 1.0 / 1.15, "ads_time_mult": 1.4}),  # 1.15: NetWorld.HEAD_DAMAGE_MULT
		PartDef.make("chest", "chest", 0, "Своё сердце", "Родное."),
		PartDef.make("lead_heart", "chest", 2, "Свинцовое сердце",
				"+50 здоровья. Лечение начинается на 2 с позже.", {"health_add": 50.0, "regen_delay_add": 2.0}),
		PartDef.make("adrenal", "chest", 2, "Адреналиновая железа",
				"Лечение начинается на 1.5 с раньше. −30 здоровья.", {"regen_delay_add": -1.5, "health_add": -30.0}),
		PartDef.make("belly", "belly", 0, "Своё брюхо", "Родное."),
		PartDef.make("second_stomach", "belly", 1, "Второй желудок",
				"Сумка с патронами лечит 75. Патронов из неё не получаешь.", {"bag_heal": 75.0}),
		PartDef.make("lard", "belly", 2, "Сало", "Урон по тебе −15%. Ходишь на 10% медленнее.",
				{"damage_taken_mult": 0.85, "speed_mult": 0.9}),
		PartDef.make("legs", "legs", 0, "Свои окорока", "Родные."),
		PartDef.make("spring_hooves", "legs", 1, "Пружинные копыта",
				"Прыжок выше на 30%. Приземление слышно всем.", {"jump_mult": 1.3, "land_db": 12.0}),
		PartDef.make("runner_hams", "legs", 2, "Беговые окорока",
				"Спринт быстрее на 15%. Перезарядка на 30% дольше.", {"sprint_mult": 1.15, "reload_mult": 1.3}),
	])
	# The weapons (WeaponDB order: the first is the native one) and their modules, as weapons.cfg lists them (the
	# first of a slot is its default).
	for i in WeaponDB.count():
		var def := WeaponDB.get_def(i)
		_parts.append(PartDef.make(def.id, "weapon", 0, def.display_name, def.info))
		for slot in WEAPON_SLOTS.slice(1):
			for module: Dictionary in WeaponDB.modules_for(def.id, slot):
				if module["hidden"]:
					continue  # weapons.cfg "hidden": kept for later, not offered (a build with it goes native)
				var part := PartDef.make(module["id"], slot, module["cost"], module["name"], module["info"])
				part.requires = module["requires"]
				part.excludes = module["excludes"]
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
		var part := PartDef.make(kit["id"], "kit", 0, kit["name"], "")
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
