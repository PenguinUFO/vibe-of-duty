class_name Grenades
extends Node3D
## The grenades in flight (Docs/LOADOUT.md, "Граната") - the first projectile in the game. Created by NetWorld as
## its child "Grenades" (the same node path everywhere, for the RPCs).
##
## The server owns them: it launches each from the shooter's simulation (PlayerWeapons._on_grenade), checks the flight
## for a direct hit before the first bounce, sets it off on its fuse and applies the blast. The clients fly the same
## launch themselves (the same arc and bounces off the same level) and only draw it; the blast comes from the server
## with its position. The shooter's own client launches at once (prediction); the server's launch is not sent to it.
## A player has at most one grenade a life and the fuse is shorter than the respawn delay, so a grenade is known by its
## shooter's peer id.
##
## No lag compensation: a direct hit is judged against the players where the server has them, the blast where they
## are when it goes off.

const DIRECT_HEAD := false   # a direct hit counts as a body hit (no head bonus for a ball)
const KNOCK_BACK := 0.08     # share of its speed a grenade keeps bouncing back off a player: it drops at their feet
const SIGHT_LIFT := 0.1      # m above the grenade the blast "looks" from (it lies on the floor)

var world: NetWorld
var _flying := {}            # shooter peer id -> Grenade


# --- Server ------------------------------------------------------------------------------------------

## Launches `shooter`'s grenade (their simulation's launch event) and tells everybody but the shooter, whose client
## launched its own.
func server_launch(shooter: Player, origin: Vector3, vel: Vector3) -> void:
	_remove(shooter.peer_id)
	var grenade := _spawn(shooter.peer_id, origin, vel)
	grenade.on_flight = _server_flight
	Game.count("grenades")
	if world._stats != null:
		world._stats.grenade_thrown(shooter)
	for peer in world._ready_peers:
		if peer != shooter.peer_id:
			_launched.rpc_id(peer, shooter.peer_id, origin, vel)
	if not Game.dedicated and shooter.control != Player.Mode.LOCAL:
		shooter.show_remote_grenade(origin, vel)


func _physics_process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	for id in _flying.keys():
		var grenade = _flying[id]  # untyped: it may have been freed
		if not is_instance_valid(grenade):
			_flying.erase(id)
		elif (grenade as Grenade).age >= (grenade as Grenade).fuse:
			_server_blast(id, grenade.global_position)


## The flight of this tick (from -> to): the first player or target on it, before the first bounce, takes the direct
## hit and the grenade bounces back off them.
func _server_flight(grenade: Grenade, from: Vector3, to: Vector3) -> bool:
	var length := from.distance_to(to)
	if length < 1e-5:
		return false
	var dir := (to - from) / length
	var best := length
	var victim: Object = null
	var victim_head := false
	var thrower: Player = world.players.get(grenade.owner_id)
	for id in world.players:
		var other: Player = world.players[id]
		if other.peer_id == grenade.owner_id or not other.alive:
			continue
		if thrower != null and thrower.is_teammate(other) and not Game.friendly_fire():
			continue  # flies through a teammate it cannot hurt
		var hit := _ray_hitbox(from, dir, other.hitbox_state())
		if hit.x >= 0.0 and hit.x < best:
			best = hit.x
			victim = other
			victim_head = hit.y > 0.0
	for node in get_tree().get_nodes_in_group(Target.GROUP):
		var target := node as Target
		if not target.alive:
			continue
		var t_hit := _ray_hitbox(from, dir, target.hitbox_state())
		if t_hit.x >= 0.0 and t_hit.x < best:
			best = t_hit.x
			victim = target
			victim_head = t_hit.y > 0.0
	if victim == null:
		return false
	var pos := from + dir * best
	var damage := WeaponDB.grenade("direct_damage", 25.0)
	var shooter: Player = world.players.get(grenade.owner_id)
	if victim is Player:
		if shooter != null:
			world.server_apply_damage(shooter, victim as Player, damage, DIRECT_HEAD and victim_head, WeaponSim.GRENADE, pos)
	else:
		var target := victim as Target
		target.add_mark(pos, false)
		var knocked := target.take_damage(damage, false)
		if shooter != null and shooter.is_local:
			shooter.on_hit_confirmed(knocked, false)
	Game.count("grenade_direct")
	var vel := -grenade.velocity * KNOCK_BACK
	grenade.knock_back(pos - dir * Grenade.RADIUS, vel)
	for peer in world._ready_peers:
		_knocked.rpc_id(peer, grenade.owner_id, grenade.global_position, vel)
	return true


## [distance along the ray to the hitbox (-1: miss), 1 if the head was hit first else 0] (as PlayerWeapons._trace).
static func _ray_hitbox(origin: Vector3, dir: Vector3, state: Dictionary) -> Vector2:
	var t_head := LagComp.ray_sphere(origin, dir, LagComp.head_center(state), LagComp.HEAD_RADIUS)
	var seg := LagComp.body_segment(state)
	var t_body := LagComp.ray_capsule(origin, dir, seg[0], seg[1], LagComp.BODY_RADIUS)
	if t_head >= 0.0 and (t_body < 0.0 or t_head <= t_body + 0.0001):
		return Vector2(t_head, 1.0)
	return Vector2(t_body, 0.0)


## The blast: every player (the shooter too, owner 2026-11-02: full damage) and target it sees takes damage by how
## near their hitbox is - blast_damage up to blast_full m, then down to 0 at blast_radius. Cover stops it (owner: only
## in line of sight, like bullets).
func _server_blast(shooter_id: int, pos: Vector3) -> void:
	_remove(shooter_id)
	Game.count("grenade_blasts")
	var shooter: Player = world.players.get(shooter_id)
	_hurt_around(shooter, pos + Gravity.up(pos) * Grenade.RADIUS * 0.5, WeaponDB.grenade("blast_damage", 120.0))
	for peer in world._ready_peers:
		_exploded.rpc_id(peer, shooter_id, pos)
	if not Game.dedicated:
		Grenade.blast_fx(self, pos)


## Hurts what a blast at `eye` reaches.
func _hurt_around(shooter: Player, eye: Vector3, most: float) -> void:
	var full := WeaponDB.grenade("blast_full", 2.0)
	var radius := WeaponDB.grenade("blast_radius", 8.0)
	var space := get_world_3d().direct_space_state
	for id in world.players:
		var victim: Player = world.players[id]
		if not victim.alive:
			continue
		var amount := _blast_damage(space, eye, victim.hitbox_state(), full, radius, most)
		if amount > 0.0 and shooter != null:
			Game.count("grenade_self" if victim == shooter else "grenade_hurt")
			world.server_apply_blast(shooter, victim, amount, eye)
	for node in get_tree().get_nodes_in_group(Target.GROUP):
		var target := node as Target
		if not target.alive:
			continue
		var t_amount := _blast_damage(space, eye, target.hitbox_state(), full, radius, most)
		if t_amount > 0.0:
			var knocked := target.take_damage(t_amount, false)
			if shooter != null and shooter.is_local:
				shooter.on_hit_confirmed(knocked, false)


## Damage the blast at `eye` does to a hitbox: by the distance to its nearest part (body capsule or head), 0 if no
## line from the blast reaches the body's middle, its nearest point or the head.
static func _blast_damage(space: PhysicsDirectSpaceState3D, eye: Vector3, state: Dictionary, full: float,
		radius: float, most: float) -> float:
	var seg := LagComp.body_segment(state)
	var nearest := Geometry3D.get_closest_point_to_segment(eye, seg[0], seg[1])
	var head := LagComp.head_center(state)
	var distance := maxf(minf(eye.distance_to(nearest) - LagComp.BODY_RADIUS,
			eye.distance_to(head) - LagComp.HEAD_RADIUS), 0.0)
	if distance >= radius:
		return 0.0
	var seen := false
	for point in [nearest, (seg[0] + seg[1]) * 0.5, head]:
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, point, Layers.WORLD)).is_empty():
			seen = true
			break
	if not seen:
		return 0.0
	return most * clampf(1.0 - (distance - full) / maxf(radius - full, 0.01), 0.0, 1.0)


# --- Everybody -------------------------------------------------------------------------------------

## The shooter's own client: launches at once, before the server does (prediction).
func predict(shooter: Player, origin: Vector3, vel: Vector3) -> void:
	_remove(shooter.peer_id)
	_spawn(shooter.peer_id, origin, vel)


@rpc("authority", "reliable")
func _launched(shooter_id: int, origin: Vector3, vel: Vector3) -> void:
	if shooter_id == multiplayer.get_unique_id():
		return
	_remove(shooter_id)
	_spawn(shooter_id, origin, vel)
	if world.players.has(shooter_id):
		(world.players[shooter_id] as Player).show_remote_grenade(origin, vel)


@rpc("authority", "reliable")
func _knocked(shooter_id: int, pos: Vector3, vel: Vector3) -> void:
	var grenade = _flying.get(shooter_id)  # untyped: it may have been freed
	if is_instance_valid(grenade):
		(grenade as Grenade).knock_back(pos, vel)


@rpc("authority", "reliable")
func _exploded(shooter_id: int, pos: Vector3) -> void:
	_remove(shooter_id)
	Grenade.blast_fx(self, pos)


func _spawn(shooter_id: int, origin: Vector3, vel: Vector3) -> Grenade:
	var grenade := Grenade.new()
	grenade.owner_id = shooter_id
	add_child(grenade)
	grenade.launch(origin, vel, not Game.dedicated)
	_flying[shooter_id] = grenade
	return grenade


func _remove(shooter_id: int) -> void:
	var grenade = _flying.get(shooter_id)  # untyped: it may have been freed
	if is_instance_valid(grenade):
		(grenade as Grenade).queue_free()
	_flying.erase(shooter_id)
