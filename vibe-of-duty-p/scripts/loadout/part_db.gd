class_name PartDB
extends RefCounted
## The parts a build is made of (Docs/LOADOUT.md) and the rules: one part per body slot, BUDGET tokens per build. A
## build travels as an Array of part ids in SLOTS order; anything invalid (unknown id, wrong slot, over budget) turns
## into the native parts (sanitize), so the server never applies a build it did not check.

const SLOTS: Array[String] = ["weapon", "hands", "head", "chest", "belly", "legs"]
const SLOT_NAMES := {"weapon": "Оружие", "hands": "Руки", "head": "Голова", "chest": "Грудь", "belly": "Брюхо",
		"legs": "Ноги"}
const BUDGET := 5
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


static func all() -> Array[PartDef]:
	_build()
	return _parts


static func get_part(id: String) -> PartDef:
	_build()
	return _by_id.get(id)


## The parts that fit `slot`, the native one first.
static func for_slot(slot: String) -> Array[PartDef]:
	var list: Array[PartDef] = []
	for part in all():
		if part.slot == slot:
			list.append(part)
	return list


## The native build: no organs, no implants (0 tokens).
static func default_build() -> Array:
	var parts := []
	for slot in SLOTS:
		parts.append(for_slot(slot)[0].id)
	return parts


static func cost(parts: Array) -> int:
	var total := 0
	for id in parts:
		var part := get_part(str(id))
		if part != null:
			total += part.cost
	return total


## A valid build from anything: wrong or missing parts become native; over budget, the whole build is native.
static func sanitize(parts: Variant) -> Array:
	var clean := default_build()
	if not parts is Array:
		return clean
	for i in mini((parts as Array).size(), SLOTS.size()):
		var part := get_part(str(parts[i]))
		if part != null and part.slot == SLOTS[i]:
			clean[i] = part.id
	return clean if cost(clean) <= BUDGET else default_build()


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
	if not _parts.is_empty():
		return
	_parts.assign([
		PartDef.make("ak", "weapon", 0, "АК", "Единственный ствол."),
		PartDef.make("hoof", "hands", 0, "Копыто", "Родное. Удар — 75 урона."),
		PartDef.make("sledge_hoof", "hands", 2, "Копыто-кувалда",
				"Удар убивает сразу. Ходишь на 10% медленнее.", {"melee_damage_mult": 2.0, "speed_mult": 0.9}),
		PartDef.make("head", "head", 0, "Своя голова", "Родная."),
		PartDef.make("lead_brow", "head", 1, "Свинцовый лоб",
				"В голову бьют как в тело. Прицеливаешься на 40% дольше.",
				{"head_taken_mult": 1.0 / 1.15, "ads_time_mult": 1.4}),  # 1.15: NetWorld.HEAD_DAMAGE_MULT
		PartDef.make("scope_eye", "head", 2, "Глаз-прицел",
				"Разброс в прицеле ×0.4. От бедра ×1.6.", {"spread_ads_mult": 0.4, "spread_hip_mult": 1.6}),
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
	for part in _parts:
		_by_id[part.id] = part
