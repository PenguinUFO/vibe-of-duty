class_name CraneBridge
extends Node
## Read Docs/LEVEL_TOWER.md first; update it with any change here.
## The tower crane's load: a two-storey corridor across the gap between the two towers (the shell's CraneLoad node -
## the corridor, its lamps, the cable and the trolley; tools/make_tower_map.py builds it at the first dock). The crane
## keeps it moving: a few seconds at one pair of doorways, along z to the other pair, a few seconds there, back.
## While it travels the towers are cut off from each other, and a doorway it has left opens onto the drop.
## - One schedule from the server's clock (NetWorld.shared_time), as PlaneBank's: every machine sees the corridor in
##   the same place with nothing sent, a late joiner too.
## - Standing in it is safe: it carries you (see Riders below). Whoever is in its way is pushed along
##   (the server, and each client its own player, before the players step); pushed against anything solid - crushed
##   (the server kills them, as a fall).
## - A jump keeps the load's speed (Block.ride_velocity, PlayerMovement.step): you come down where you left it.
## Must come before Players in the scene: the load moves before anybody steps.

const CRUSH_SLACK := 0.03          # m: a push blocked by more than this crushes
const ON_TOP := 0.25               # m: feet this close below a block's top stand on it (not pushed)
const LEAD_TRIM := 0.0             # s off the measured round trip (it counts the wait for this machine's tick too)
const JUMP := 0.5                  # m a tick: more is the clock being set (joining), not travel - placed, no pushes

@export var load_path := ^"../Shell/CraneLoad"
@export var travel := 11.0         # m along +z from the first dock to the second
@export var hold := 4.0            # s at each dock (the owner: on the move nearly all the time)
@export var move := 10.0           # s from one dock to the other (eased: top speed 1.5 x travel / move)
@export var phase := 0.0           # s added to the clock (where in its cycle the load is at time 0)

## Tools (screenshots): the time the schedule is read at instead of the server's clock (negative: off).
var time_override := -1.0

var _world: NetWorld
var _load: Node3D
var _blocks: Array[Block] = []
var _offset := 0.0
var _placed := false
var _lead := 0.0                   # s, client: how far ahead of the clock the load is shown (see _time)


func _ready() -> void:
	_world = get_node_or_null("../World") as NetWorld
	_load = get_node_or_null(load_path) as Node3D
	if _load:
		for child in _load.find_children("*", "Block", true, false):
			_blocks.append(child as Block)
			(child as Block).ride_offset_at = _server_offset
	Block.movers += 1


func _exit_tree() -> void:
	Block.movers -= 1


func _physics_process(delta: float) -> void:
	if _load == null:
		return
	var offset := offset_at(_time())
	if not _placed or absf(offset - _offset) > JUMP:  # a late joiner's load is placed, no pushes
		_placed = true
		_offset = offset
		_load.position.z = offset
		for block in _blocks:
			block.ride_offset = Vector3(0.0, 0.0, offset)
		return
	var moved := offset - _offset
	_offset = offset
	var server := multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	# Riders are carried here, once a tick - the server's, and a client's own player the same way. Not on the blocks'
	# velocity (CharacterBody3D's moving platform): the server steps a client 0-2 commands a tick
	# (Player.CMD_BUDGET_PER_TICK), and a carry per step drifted - a rider ended 1.4 m past the dock after one trip;
	# on a client it dropped the carry against a tower's wall. A client's replays are not carried: PlayerNet puts the
	# server's place onto the load where it is now (Block.ride_offset).
	for block in _blocks:
		block.ride_velocity = Vector3(0.0, 0.0, moved / delta)
		block.ride_offset = Vector3(0.0, 0.0, offset)
	if moved == 0.0:
		return
	_load.position.z = offset
	if _world:
		for player: Player in _world.players.values():
			if not player.alive or not (server or player.control == Player.Mode.LOCAL):
				continue
			if _rides(player):
				_shove(player, Vector3(0.0, 0.0, moved), server)
			else:
				_push(player, signf(moved), server)


## A client shows the load where the server will have it when the command stepped now gets there - its own player's
## round trip ahead of the clock (the clock itself is a snapshot's delay behind). Read at the clock, a rider's
## predicted place was the load's travel over the ping away from the server's: corrected on every snapshot.
func _time() -> float:
	if time_override >= 0.0:
		return time_override
	if _world == null:
		return Time.get_ticks_usec() / 1e6
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		return _world.server_tick / float(Engine.physics_ticks_per_second)  # to the tick: _server_offset repeats it
	if multiplayer.has_multiplayer_peer():
		for player: Player in _world.players.values():
			if player.control == Player.Mode.LOCAL and player.rtt_ms > 0.0:
				_lead = lerpf(_lead, player.rtt_ms / 1000.0 - LEAD_TRIM, 0.05 if _lead > 0.0 else 1.0)
	return _world.shared_time() + _lead


## Block.ride_offset_at: where the server had the load when it sent the snapshot of this tick (NetWorld counts the
## tick after this node and the players have run).
func _server_offset(tick: int) -> Vector3:
	return Vector3(0.0, 0.0, offset_at((tick - 1) / float(Engine.physics_ticks_per_second)))


## The load's z offset from the first dock at time t: hold, move over, hold, move back.
func offset_at(t: float) -> float:
	var tau := fposmod(t + phase, 2.0 * (hold + move))
	if tau < hold:
		return 0.0
	if tau < hold + move:
		return travel * smoothstep(0.0, 1.0, (tau - hold) / move)
	if tau < 2.0 * hold + move:
		return travel
	return travel * (1.0 - smoothstep(0.0, 1.0, (tau - 2.0 * hold - move) / move))


## Pushes a player out of the way of the load moving along z (side): out ahead of each block that came at them; a push
## the level blocks crushes them.
func _push(player: Player, side: float, server: bool) -> void:
	var feet := player.global_position
	var height := Player.CROUCH_HEIGHT if player.is_crouched else Player.STAND_HEIGHT
	var r := Player.RADIUS
	var need := 0.0
	for block in _blocks:
		var lo := block.global_position - block.size * 0.5
		var hi := block.global_position + block.size * 0.5
		if block.basis != Basis.IDENTITY:  # the stair: its bounding box (standing on it is not a push)
			var aabb := block.global_transform * AABB(-block.size * 0.5, block.size)
			lo = aabb.position
			hi = aabb.end
			if feet.x > lo.x and feet.x < hi.x and feet.z > lo.z and feet.z < hi.z:
				continue
		# Only a block coming at them: one moving away (a parapet they lean on as the load leaves) is not a push -
		# pushing them past its far face threw them through it and over the side.
		if (feet.z - (lo.z + hi.z) * 0.5) * side <= 0.0:
			continue
		if feet.x + r <= lo.x or feet.x - r >= hi.x or feet.z + r <= lo.z or feet.z - r >= hi.z \
				or feet.y + height <= lo.y or feet.y >= hi.y - ON_TOP:
			continue
		need = maxf(need, (hi.z + r + 0.01 - feet.z) if side > 0.0 else (feet.z - (lo.z - r - 0.01)))
	if need > 0.0:
		_shove(player, Vector3(0.0, 0.0, side * need), server)


## Stands on the load: on the floor, and the floor is one of its blocks. Not by the last move's collisions: walking,
## the move has none with the floor, and the server left whoever walked in the corridor behind.
func _rides(player: Player) -> bool:
	return player.is_on_floor() and _blocks.has(player.floor_block())


## Moves a player through the load's blocks (not through the level); blocked - crushed.
func _shove(player: Player, motion: Vector3, server: bool) -> void:
	for block in _blocks:
		player.add_collision_exception_with(block)
	var from := player.global_position
	var hit := player.move_and_collide(motion)
	if hit != null:  # along a wall they lean on: the rest of the way slides (stopped dead, a rider fell behind the load)
		player.move_and_collide(hit.get_remainder().slide(hit.get_normal()))
	for block in _blocks:
		player.remove_collision_exception_with(block)
	var lost := motion.length() - (player.global_position - from).dot(motion.normalized())
	if server and hit != null and lost > CRUSH_SLACK:
		var game := get_node_or_null(^"/root/Game")  # not Game: tools load this without the autoloads
		if game:
			game.count("crushed")
		_world._server_suicide(player, "crushed")
