class_name PartDef
extends RefCounted
## One part of a build (Docs/LOADOUT.md): the weapon, one of its modules or a kit, for one slot.

var id := ""
var slot := ""            # PartDB.SLOTS
var display_name := ""
var info := ""            # what it does
var requires := ""        # a weapon module: another part id the build must have (weapons.cfg "requires")
var excludes := ""        # a weapon module: slots ("a,b") kept at their defaults while this part is in (weapons.cfg)
var forces := ""          # a weapon module: the part id its slot is held at while this part is in (weapons.cfg "forces")
var weapon := ""          # a weapon module: the weapon's id (it fits only that weapon); "" for every other part
var kit_weapon := ""      # a kit (slot "kit"): its weapon's id...
var kit_modules := []     # ...and its modules (full ids; the other slots have their defaults)


static func make(p_id: String, p_slot: String, p_name: String, p_info: String) -> PartDef:
	var part := PartDef.new()
	part.id = p_id
	part.slot = p_slot
	part.display_name = p_name
	part.info = p_info
	return part
