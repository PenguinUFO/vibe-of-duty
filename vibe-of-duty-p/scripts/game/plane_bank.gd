class_name PlaneBank
extends Node3D
## Read Docs/LEVEL_PLANE.md first; update it with any change here.
## The plane banks now and then: a few degrees to one side for several seconds, then level again. Everything not
## bolted down (LooseCargo nodes) slides to the low side and stays there till a bank the other way; a player caught
## between moving cargo and anything solid is crushed (the server kills them, as a fall).
## - One schedule from the server's clock (NetWorld.shared_time): every machine sees the same banks and the same
##   cargo positions with nothing sent, a late joiner too. The cargo's motion is worked out from the schedule (each
##   bank in turn, from the scene's positions), not simulated.
## - The plane is the frame of reference: outside, the world tilts instead (the sky with its sea of clouds, the near
##   clouds, the sun - its light patches sweep across the hold), and the local camera leans part of the bank
##   (view_roll, read by PlayerView).
## - The cargo pushes players out of its way (the server, and each client its own player, before the players step);
##   blocked - the player is crushed. Standing on cargo is safe: it carries you (its blocks' constant velocity).
## Must come before Players in the scene: the cargo moves before anybody steps.

const SLOT := 45.0                 # s: at most one bank in each slot of this long
const START := Vector2(8.0, 28.0)  # s into its slot a bank starts
const AMPLITUDE := Vector2(5.0, 12.0)  # degrees
const HOLD := Vector2(4.0, 7.0)    # s at full bank
const RISE := 4.0                  # s to roll in, the same to roll out
const SLIDE_ACCEL := 2.5           # m/s^2 of cargo well over its grip (3 degrees or more)...
const SLIDE_SPEED := 3.0           # ...and its top speed
const TURBULENCE := 0.6            # degrees of slow wobble on top (cosmetic: moves no cargo)
const VIEW_LEAN := 0.5             # part of the bank the local camera leans
const CRUSH_SLACK := 0.03          # m: a push blocked by more than this crushes
const ON_TOP := 0.25               # m: feet this close below cargo's top stand on it (not pushed)

## Radians the local camera leans now (0 off this map).
static var view_roll := 0.0

## Tools (screenshots): the time the schedule is read at instead of the server's clock (negative: off).
var time_override := -1.0

var _world: NetWorld
var _cargo: Array[Dictionary] = []  # {node, grip, box (AABB at offset 0), blocks, lo, hi}
var _offsets := PackedFloat32Array()  # each cargo's x offset now
var _cache_slot := 0                  # banks before this slot are folded into _cache_offsets
var _cache_offsets := PackedFloat32Array()
var _limits_ready := false
var _sun: DirectionalLight3D
var _sun_base := Basis.IDENTITY
var _sun_set := Basis.IDENTITY        # what this node last gave the sun (anything else: Mood re-applied it)
var _environment: Environment
var _scenery: Node3D
var _visuals := true


func _ready() -> void:
	_world = get_node_or_null("../World") as NetWorld
	_visuals = DisplayServer.get_name() != "headless"
	for node in get_parent().find_children("*", "LooseCargo", true, false):
		var cargo := node as LooseCargo
		var blocks: Array[Block] = []
		var box := AABB()
		for child in cargo.find_children("*", "Block", true, false):
			var block := child as Block
			var own := AABB(block.position - block.size * 0.5, block.size)  # in the cargo node's space = the level's
			box = own if blocks.is_empty() else box.merge(own)
			blocks.append(block)
		if not blocks.is_empty():
			_cargo.append({"node": cargo, "grip": cargo.grip, "box": box, "blocks": blocks, "lo": 0.0, "hi": 0.0})
	_offsets.resize(_cargo.size())
	_cache_offsets.resize(_cargo.size())
	_sun = get_node_or_null("../Sun") as DirectionalLight3D
	var world_env := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	_environment = world_env.environment if world_env else null
	_scenery = get_node_or_null("../Scenery") as Node3D


func _exit_tree() -> void:
	view_roll = 0.0
	if _environment:  # the environment is shared with the next load of the scene
		_environment.sky_rotation = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not _limits_ready:  # the physics space is queried only from here; a late joiner's cargo is placed, no pushes
		_find_limits()
		_limits_ready = true
		_offsets = offsets_at(_time())
		for i in _cargo.size():
			(_cargo[i]["node"] as Node3D).position.x = _offsets[i]
		return
	var offsets := offsets_at(_time())
	var server := multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	for i in _cargo.size():
		var moved := offsets[i] - _offsets[i]
		if moved == 0.0:
			for block: Block in _cargo[i]["blocks"]:
				block.constant_linear_velocity = Vector3.ZERO
			continue
		var cargo: LooseCargo = _cargo[i]["node"]
		cargo.position.x = offsets[i]
		for block: Block in _cargo[i]["blocks"]:
			block.constant_linear_velocity = Vector3(moved / delta, 0.0, 0.0)
		if _world:
			for player: Player in _world.players.values():
				if player.alive and (server or player.control == Player.Mode.LOCAL):
					_push(player, _cargo[i], signf(moved), server)
	_offsets = offsets


func _process(_delta: float) -> void:
	if not _visuals:
		return
	var t := _time()
	var roll := deg_to_rad(roll_at(t) + TURBULENCE * sin(t * 0.31) * sin(t * 0.17 + 1.0))
	view_roll = roll * VIEW_LEAN
	if _environment:
		_environment.sky_rotation = Vector3(0.0, 0.0, roll)
	if _scenery:
		_scenery.rotation.z = roll
	if _sun:
		if not _sun.basis.is_equal_approx(_sun_set):
			_sun_base = _sun.basis
		_sun.basis = Basis(Vector3.BACK, roll) * _sun_base
		_sun_set = _sun.basis


## view_roll, for tools that hold the node untyped.
func lean() -> float:
	return view_roll


func _time() -> float:
	if time_override >= 0.0:
		return time_override
	return _world.shared_time() if _world else Time.get_ticks_usec() / 1e6


## The bank in slot k: [start (s), degrees (signed: + the +x side goes down), hold (s)].
func _bank(k: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + k
	var start := k * SLOT + rng.randf_range(START.x, START.y)
	var degrees := rng.randf_range(AMPLITUDE.x, AMPLITUDE.y) * (1.0 if rng.randf() < 0.5 else -1.0)
	return [start, degrees, rng.randf_range(HOLD.x, HOLD.y)]


## Degrees of bank at time t (+: the +x side down).
func roll_at(t: float) -> float:
	var bank := _bank(floori(t / SLOT))
	var tau: float = t - bank[0]
	var hold: float = bank[2]
	if tau <= 0.0 or tau >= RISE * 2.0 + hold:
		return 0.0
	var up := smoothstep(0.0, RISE, tau) if tau < RISE + hold else smoothstep(RISE * 2.0 + hold, RISE + hold, tau)
	return bank[1] * up


## Every cargo's x offset at time t: the banks before t's slot folded in turn (cached), then the current one.
func offsets_at(t: float) -> PackedFloat32Array:
	var slot := maxi(floori(t / SLOT), 0)
	if slot < _cache_slot:  # the clock went back (a tool): fold again from the scene's positions
		_cache_slot = 0
		_cache_offsets.fill(0.0)
	while _cache_slot < slot:
		var bank := _bank(_cache_slot)
		_cache_offsets = _slide(bank, _cache_offsets, (_cache_slot + 1) * SLOT - bank[0])
		_cache_slot += 1
	var current := _bank(slot)
	if t <= current[0]:
		return _cache_offsets
	return _slide(current, _cache_offsets, t - current[0])


## Offsets tau s after a bank started, from the offsets before it. The cargo nearest the low side goes first; the
## rest stop against it (or against cargo that does not slide). Cargo set moving keeps going to the wall even after
## the plane levels out.
func _slide(bank: Array, from: PackedFloat32Array, tau: float) -> PackedFloat32Array:
	var degrees: float = absf(bank[1])
	var side := signf(bank[1])
	var order := range(_cargo.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return (_cargo[a]["box"].get_center().x + from[a]) * side > (_cargo[b]["box"].get_center().x + from[b]) * side)
	var out := from.duplicate()
	var done: Array[int] = []
	for i: int in order:
		var cargo := _cargo[i]
		var grip: float = cargo["grip"]
		var x := from[i]
		if degrees > grip:
			# Slides once the bank passes its grip (on the smoothstep roll-in: its inverse).
			var since := tau - RISE * (0.5 - sin(asin(1.0 - 2.0 * grip / degrees) / 3.0))
			if since > 0.0:
				var accel := SLIDE_ACCEL * clampf((degrees - grip) / 3.0, 0.3, 1.0)
				var full := SLIDE_SPEED / accel  # s to top speed
				var dist := 0.5 * accel * since * since if since < full \
						else 0.5 * SLIDE_SPEED * full + SLIDE_SPEED * (since - full)
				x += side * dist
		x = clampf(x, cargo["lo"], cargo["hi"])
		var box: AABB = cargo["box"]
		for j in done:
			var other: AABB = _cargo[j]["box"]
			if not _overlap_yz(box, other):
				continue
			if side > 0.0:
				x = minf(x, other.position.x + out[j] - box.end.x)
			else:
				x = maxf(x, other.end.x + out[j] - box.position.x)
		out[i] = x
		done.append(i)
	return out


static func _overlap_yz(a: AABB, b: AABB) -> bool:
	return a.position.y < b.end.y and b.position.y < a.end.y and a.position.z < b.end.z and b.position.z < a.end.z


## How far each cargo can go each way: its box swept along x against the level (not the other cargo), a little
## above the floor and slimmer, so the floor and the walls it stands beside do not count.
func _find_limits() -> void:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for cargo in _cargo:
		for block: Block in cargo["blocks"]:
			exclude.append(block.get_rid())
	for cargo in _cargo:
		var box: AABB = cargo["box"]
		var shape := BoxShape3D.new()
		shape.size = box.size - Vector3(0.0, 0.06, 0.06)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = Layers.WORLD
		query.exclude = exclude
		query.transform = Transform3D(Basis.IDENTITY, box.get_center() + Vector3(0.0, 0.03, 0.0))
		for side in [-1.0, 1.0]:
			query.motion = Vector3(side * 12.0, 0.0, 0.0)
			var safe: float = space.cast_motion(query)[0]
			cargo["hi" if side > 0.0 else "lo"] = side * 12.0 * safe


## Pushes a player out of the way of cargo moving along x (side); a push the level blocks crushes them.
func _push(player: Player, cargo: Dictionary, side: float, server: bool) -> void:
	var feet := player.global_position
	var height := Player.CROUCH_HEIGHT if player.is_crouched else Player.STAND_HEIGHT
	var r := Player.RADIUS
	var offset := Vector3((cargo["node"] as Node3D).position.x, 0.0, 0.0)
	var need := 0.0
	for block: Block in cargo["blocks"]:
		var lo := block.position + offset - block.size * 0.5
		var hi := block.position + offset + block.size * 0.5
		if feet.x + r <= lo.x or feet.x - r >= hi.x or feet.z + r <= lo.z or feet.z - r >= hi.z \
				or feet.y + height <= lo.y or feet.y >= hi.y - ON_TOP:
			continue
		need = maxf(need, (hi.x + r + 0.01 - feet.x) if side > 0.0 else (feet.x - (lo.x - r - 0.01)))
	if need <= 0.0:
		return
	for block: Block in cargo["blocks"]:
		player.add_collision_exception_with(block)
	var hit := player.move_and_collide(Vector3(side * need, 0.0, 0.0))
	for block: Block in cargo["blocks"]:
		player.remove_collision_exception_with(block)
	if server and hit != null and hit.get_remainder().length() > CRUSH_SLACK:
		var game := get_node_or_null(^"/root/Game")  # not Game: tools load this without the autoloads
		if game:
			game.count("crushed")
		_world._server_suicide(player)
