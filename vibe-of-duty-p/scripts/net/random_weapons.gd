class_name RandomWeapons
extends RefCounted
## Test mode "FFA random weapon" (Game.random_weapons, host panel -> Тестирование): every life (the first spawn, each
## respawn, a new match) the server gives the player a random weapon with its cards (PartDB.CARD_SLOTS) each on or
## off at random, instead of their build. A weapon that came up sits out the player's next REST lives, then is back in
## the pool: never the same weapon twice in a row, nor every other life.
## Owned by NetWorld (server).

const REST := 2

var _recent := {}  # peer_id -> Array[String]: the weapon ids of their last REST lives, newest last


## The build of `id`'s next life (sanitized: the cards' "excludes" / "requires" hold).
func next_build(id: int) -> Array:
	var recent: Array = _recent.get_or_add(id, [])
	var pool: Array[String] = []
	for part in PartDB.for_slot("weapon"):
		if not recent.has(part.id):
			pool.append(part.id)
	if pool.is_empty():  # fewer weapons than REST + 1: only no repeat in a row
		for part in PartDB.for_slot("weapon"):
			if recent.is_empty() or part.id != recent.back():
				pool.append(part.id)
	var weapon: String = pool.pick_random()
	recent.append(weapon)
	while recent.size() > REST:
		recent.pop_front()
	var build := PartDB.default_build(weapon)
	for slot in PartDB.CARD_SLOTS:
		var list := PartDB.options(slot, weapon)
		if list.size() >= 2 and randi() % 2 == 1:
			build[PartDB.SLOTS.find(slot)] = list[1].id
	return PartDB.sanitize(build)


func forget(id: int) -> void:
	_recent.erase(id)
