class_name PartDB
extends RefCounted
## The parts a build is made of (Docs/LOADOUT.md) and the rules: one part per slot - the weapon, its modules
## (from weapons.cfg, WeaponDB) and the body - and BUDGET tokens per build. A build travels as an Array of part ids in
## SLOTS order; anything invalid (unknown id, wrong slot, a module whose "requires" is missing, over budget) turns into
## the native parts (sanitize), so the server never applies a build it did not check.

const WEAPON_SLOTS: Array[String] = ["weapon", "suppressor", "conversion", "stock", "mag", "grip", "muzzle", "sight",
		"ammo"]
## Slots the build editor shows as cards (on / off: the slot's second module or its first), right after the weapon
## (owner, 2026-10-23, as Black Ops 2's attachments): the suppressor, a conversion (the Luger's "Хрюгер"), the stock
## (fold it; the Luger's: put it on), the next magazine size up, the optic (owner, 2026-10-26: the AK's Kobra).
const CARD_SLOTS: Array[String] = ["suppressor", "conversion", "stock", "mag", "sight"]
## Slots hidden for now (owner, 2026-10-23): the editor does not show them and every build has their defaults - the
## weapon's lists, and the whole body (the native one). The parts stay (weapons.cfg, _build); dropping a slot from here
## brings it back.
const HIDDEN_SLOTS: Array[String] = ["grip", "muzzle", "ammo", "hands", "head", "chest", "belly", "legs"]
const BODY_SLOTS: Array[String] = ["hands", "head", "chest", "belly", "legs"]
const SLOTS: Array[String] = ["weapon", "suppressor", "conversion", "stock", "mag", "grip", "muzzle", "sight", "ammo", "hands",
		"head", "chest", "belly", "legs"]
const SLOT_NAMES := {"weapon": "Оружие", "suppressor": "Глушитель", "conversion": "Переделка", "mag": "Магазин", "stock": "Приклад", "grip": "Рукоятка",
		"muzzle": "Дульное", "sight": "Прицел", "ammo": "Патрон", "hands": "Руки",
		"head": "Голова", "chest": "Грудь", "belly": "Брюхо", "legs": "Ноги"}
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


## The native build: no organs, no implants, the first weapon with its base modules (0 tokens), or with `weapon`
## (an id). "" for a slot weapons.cfg has no modules for.
static func default_build(weapon := "") -> Array:
	if weapon == "":
		weapon = for_slot("weapon")[0].id
	var parts := []
	for slot in SLOTS:
		var list := options(slot, weapon)
		parts.append(weapon if slot == "weapon" else list[0].id if not list.is_empty() else "")
	return parts


static func cost(parts: Array) -> int:
	var total := 0
	for id in parts:
		var part := get_part(str(id))
		if part != null:
			total += price(part)
	return total


## What a part costs in a build now: its price, or 0 while FREE.
static func price(part: PartDef) -> int:
	return 0 if FREE else part.cost


## A valid build from anything: wrong or missing parts become native, so do the HIDDEN_SLOTS, modules of another
## weapon or whose "requires" is not in the build, and the slot another part "excludes" (the AK's suppressor card: the
## muzzle); over budget, the whole build is native (with its weapon). Each id goes to its part's slot, so the order and
## missing slots do not matter (--build=ak.suppressor.on,lead_heart).
static func sanitize(parts: Variant) -> Array:
	if not parts is Array:
		return default_build()
	var weapon := ""
	for id in parts:
		var part := get_part(str(id))
		if part != null and part.slot == "weapon":
			weapon = part.id
	var clean := default_build(weapon)
	for id in parts:
		var part := get_part(str(id))
		if part != null and options(part.slot, clean[0]).has(part) and not part.slot in HIDDEN_SLOTS:
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
	return clean if cost(clean) <= BUDGET else default_build(clean[0])


## The weapon as a (sanitized) build plays it, for statistics (MatchStats): its id and the modules that are not its
## default, without the weapon prefix - "ak", "acr+suppressor.on+mag.40".
static func variant_name(parts: Array) -> String:
	var weapon := str(parts[0])
	var variant := weapon
	for i in range(1, WEAPON_SLOTS.size()):
		var id := str(parts[i])
		var list := options(SLOTS[i], weapon)
		if id != "" and not list.is_empty() and list[0].id != id:
			variant += "+" + id.trim_prefix(weapon + ".")
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
