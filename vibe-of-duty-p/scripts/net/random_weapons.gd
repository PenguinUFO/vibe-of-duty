class_name RandomWeapons
extends RefCounted
## Test mode "FFA random weapon" (Game.random_weapons, host panel -> Тестирование): every life (the first spawn, each
## respawn, a new match) the server gives the player a random kit (owner, 2026-10-31) instead of their build. A kit
## that came up sits out the player's next REST lives, then is back in the pool: never the same kit twice in a row,
## nor every other life.
## Owned by NetWorld (server).

const REST := 2

var _recent := {}  # peer_id -> Array[String]: the kit ids of their last REST lives, newest last


## The build of `id`'s next life (sanitized).
func next_build(id: int) -> Array:
	var recent: Array = _recent.get_or_add(id, [])
	var pool: Array[String] = []
	for part in PartDB.for_slot("kit"):
		if not recent.has(part.id):
			pool.append(part.id)
	if pool.is_empty():  # fewer kits than REST + 1: only no repeat in a row
		for part in PartDB.for_slot("kit"):
			if recent.is_empty() or part.id != recent.back():
				pool.append(part.id)
	var kit: String = pool.pick_random()
	recent.append(kit)
	while recent.size() > REST:
		recent.pop_front()
	return PartDB.sanitize(PartDB.default_build(kit))


func forget(id: int) -> void:
	_recent.erase(id)
