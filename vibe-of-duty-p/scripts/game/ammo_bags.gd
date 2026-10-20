class_name AmmoBags
extends Node3D
## Ammo bags: a killed player drops a small pouch of rounds where they fell; walking over it gives one magazine more
## for every weapon (Player.server_take_ammo, up to the weapon's reserve_max). A player whose reserves are all full
## leaves it lying. A bag disappears when taken, after LIFETIME s, or when a new match starts.
##
## The server owns the bags (drops, pickups, expiry) and tells the clients with reliable RPCs; a joining client gets
## the bags already lying about. Clients only draw them: the pouch is tossed out of the body and drops to the
## ground. Created by NetWorld as its child "AmmoBags" (the same node path everywhere, for the RPCs).

const LIFETIME := 30.0
const MAX_BAGS := 24              # the oldest goes first when there are more
const PICKUP_RADIUS := 1.0        # horizontal distance from the player's feet (m)
const PICKUP_BELOW := 0.6         # the bag may be this far below the feet...
const PICKUP_ABOVE := 1.2         # ...or this far above them (on a step, a crate's edge)
const DROP_HEIGHT := 0.9          # tossed out from about the waist
const FIND_GROUND := 4.0          # how far below the body the ground is looked for
const GRAVITY := 9.8
const TOSS_SPEED := 1.2           # sideways speed of the toss (m/s)
const BLINK_TIME := 5.0           # the last seconds of a bag's life it blinks

var world: NetWorld

var _bags := {}                   # server: id -> {"pos": Vector3 (on the ground), "life": float}
var _next_id := 1
var _shown := {}                  # id -> {"node": Node3D, "from": Vector3, "to": Vector3, "t": float, "fall": float, "age": float}

static var _meshes: Array = []    # [pouch, flap, strap, round] meshes, built once
static var _materials: Array = [] # [cloth, cloth_dark, brass]


func _init() -> void:
	top_level = true


# --- Server ------------------------------------------------------------------------------------------

## Drops a bag under `body_pos` (the killed player's feet). Nothing when there is no ground below (fell off).
func server_drop(body_pos: Vector3) -> void:
	var from := body_pos + Vector3.UP * DROP_HEIGHT
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, body_pos + Vector3.DOWN * FIND_GROUND,
			Layers.WORLD))
	if hit.is_empty() or (hit["position"] as Vector3).y < world.kill_height:
		return  # no ground, or the deadly one (beside the train: it rushes past, the bag would stand still on it)
	var side := Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	var fall := sqrt(2.0 * maxf(from.y - (hit["position"] as Vector3).y, 0.05) / GRAVITY)
	var to: Vector3 = hit["position"] + side * TOSS_SPEED * fall
	# Keep it out of walls: the tossed spot must be reachable from the body and have ground under it.
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to + Vector3.UP * 0.1, Layers.WORLD)).is_empty():
		to = hit["position"]
	else:
		var under := space.intersect_ray(PhysicsRayQueryParameters3D.create(to + Vector3.UP * 0.5, to + Vector3.DOWN * 1.0,
				Layers.WORLD))
		to = under["position"] if not under.is_empty() else hit["position"]
	if _bags.size() >= MAX_BAGS:
		var oldest: int = _bags.keys().min()
		_server_remove(oldest, 0)
	var id := _next_id
	_next_id += 1
	_bags[id] = {"pos": to, "life": LIFETIME}
	if Game.net_log:
		print("[BAG] %d dropped at (%.1f, %.1f, %.1f)" % [id, to.x, to.y, to.z])
	_dropped(id, from, to, 0.0)
	for peer in world._ready_peers:
		_dropped.rpc_id(peer, id, from, to, 0.0)


## Every server tick (NetWorld._physics_process): expiry and pickups.
func server_tick(delta: float) -> void:
	for id in _bags.keys():
		var bag: Dictionary = _bags[id]
		bag["life"] -= delta
		if bag["life"] <= 0.0:
			_server_remove(id, 0)
			continue
		var pos: Vector3 = bag["pos"]
		for peer_id in world.players:
			var player: Player = world.players[peer_id]
			if not player.alive:
				continue
			var feet := player.global_position
			var dy := pos.y - feet.y
			if dy < -PICKUP_BELOW or dy > PICKUP_ABOVE or Vector2(pos.x - feet.x, pos.z - feet.z).length() > PICKUP_RADIUS:
				continue
			if player.server_take_ammo():
				_server_remove(id, peer_id)
				break


## A newly joined client: every bag lying about now (already on the ground).
func server_send_all(peer: int) -> void:
	for id in _bags:
		var bag: Dictionary = _bags[id]
		_dropped.rpc_id(peer, id, bag["pos"], bag["pos"], LIFETIME - float(bag["life"]))


## A new match: the ground is cleared.
func server_clear() -> void:
	for id in _bags.keys():
		_server_remove(id, 0)


## `taker`: the peer that picked it up (0: expired / cleared).
func _server_remove(id: int, taker: int) -> void:
	_bags.erase(id)
	if Game.net_log:
		print("[BAG] %d %s" % [id, "taken by %d" % taker if taker != 0 else "gone"])
	_gone(id, taker)
	for peer in world._ready_peers:
		_gone.rpc_id(peer, id, taker)


# --- Everyone (the server calls these locally too) -------------------------------------------------

@rpc("authority", "reliable")
func _dropped(id: int, from: Vector3, to: Vector3, age: float) -> void:
	if Game.dedicated or _shown.has(id):
		return
	var node := _make_bag()
	add_child(node)
	node.rotation.y = randf() * TAU
	node.global_position = from
	var fall := sqrt(2.0 * maxf(from.y - to.y, 0.0) / GRAVITY)
	_shown[id] = {"node": node, "from": from, "to": to, "t": 0.0 if fall > 0.0 else 1.0, "fall": maxf(fall, 0.001),
			"age": age, "spin": randf_range(-6.0, 6.0)}
	if fall <= 0.0:
		node.global_position = to


@rpc("authority", "reliable")
func _gone(id: int, taker: int) -> void:
	if taker != 0 and taker == multiplayer.get_unique_id():
		Audio.play("pickup")
		if Game.net_log and not multiplayer.is_server():
			print("[BAG] %d picked up by me" % id)
	if not _shown.has(id):
		return
	(_shown[id]["node"] as Node3D).queue_free()
	_shown.erase(id)


func _process(delta: float) -> void:
	for id in _shown:
		var bag: Dictionary = _shown[id]
		var node: Node3D = bag["node"]
		bag["age"] += delta
		if bag["t"] < 1.0:
			# Tossed out of the body: straight across, falling under gravity, turning over; lands flat.
			var t: float = minf(bag["t"] + delta / bag["fall"], 1.0)
			bag["t"] = t
			var from: Vector3 = bag["from"]
			var to: Vector3 = bag["to"]
			var p := from.lerp(to, t)
			p.y = from.y - 0.5 * GRAVITY * pow(t * bag["fall"], 2.0)
			node.global_position = Vector3(p.x, maxf(p.y, to.y), p.z)
			node.rotation.x = (1.0 - t) * bag["spin"] * 0.3
			if t >= 1.0:
				node.rotation.x = 0.0
				node.global_position = to
				Dust.burst(self, to, 0.3)
		var left: float = LIFETIME - bag["age"]
		node.visible = left > BLINK_TIME or fmod(left, 0.4) > 0.15  # about to go: blinks


## The pouch: an olive canvas bag with a darker flap and strap, brass rounds peeking out under the flap. About
## 26 x 12 x 16 cm, lying on its back, origin at the bottom (on the ground).
func _make_bag() -> Node3D:
	if _meshes.is_empty():
		var pouch := BoxMesh.new()
		pouch.size = Vector3(0.26, 0.12, 0.16)
		var flap := BoxMesh.new()
		flap.size = Vector3(0.27, 0.025, 0.11)
		var strap := BoxMesh.new()
		strap.size = Vector3(0.035, 0.13, 0.17)
		var bullet := CylinderMesh.new()
		bullet.top_radius = 0.009
		bullet.bottom_radius = 0.012
		bullet.height = 0.06
		bullet.radial_segments = 6
		bullet.rings = 1
		_meshes = [pouch, flap, strap, bullet]
		_materials = [_material(Color(0.36, 0.39, 0.22)), _material(Color(0.24, 0.26, 0.15)),
				_material(Color(0.86, 0.64, 0.26), 0.35)]
	var root := Node3D.new()
	root.name = "AmmoBag"
	_part(root, 0, 0, Vector3(0.0, 0.06, 0.0))
	_part(root, 1, 1, Vector3(0.0, 0.13, -0.025))
	_part(root, 2, 1, Vector3(0.065, 0.06, 0.0))
	_part(root, 2, 1, Vector3(-0.065, 0.06, 0.0))
	for k in 4:
		var r := _part(root, 3, 2, Vector3(-0.06 + k * 0.04, 0.13, 0.05))
		r.rotation.x = deg_to_rad(70.0)  # lying forward out of the open front
	return root


func _part(root: Node3D, mesh: int, material: int, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _meshes[mesh]
	m.material_override = _materials[material]
	m.position = pos
	root.add_child(m)
	return m


static func _material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85 if metallic == 0.0 else 0.4
	m.metallic = metallic
	return m
