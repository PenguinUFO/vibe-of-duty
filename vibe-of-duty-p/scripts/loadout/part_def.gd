class_name PartDef
extends RefCounted
## One part of a build (Docs/LOADOUT.md): an organ, an implant or the weapon, for one body slot. `mods` change the
## player's numbers (PartDB.DEFAULT_MODS lists them all); every part except the native ones pays for its plus with a
## minus.

var id := ""
var slot := ""            # PartDB.SLOTS
var cost := 0             # tokens (PartDB.BUDGET per build)
var display_name := ""
var info := ""            # what it does, plus and minus
var mods := {}            # PartDB.DEFAULT_MODS key -> value ("_mult" keys multiply, the others add up)
var requires := ""        # a weapon module: another part id the build must have (weapons.cfg "requires")
var weapon := ""          # a weapon module: the weapon's id (it fits only that weapon); "" for every other part


static func make(p_id: String, p_slot: String, p_cost: int, p_name: String, p_info: String, p_mods := {}) -> PartDef:
	var part := PartDef.new()
	part.id = p_id
	part.slot = p_slot
	part.cost = p_cost
	part.display_name = p_name
	part.info = p_info
	part.mods = p_mods
	return part
