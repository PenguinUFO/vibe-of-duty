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
## Must come before Players in the scene: the load moves before anybody steps.

const CRUSH_SLACK := 0.03          # m: a push blocked by more than this crushes
const ON_TOP := 0.25               # m: feet this close below a block's top stand on it (not pushed)

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


func _ready() -> void:
	_world = get_node_or_null("../World") as NetWorld
	_load = get_node_or_null(load_path) as Node3D
	if _load:
		for child in _load.find_children("*", "Block", true, false):
			_blocks.append(child as Block)


func _physics_process(delta: float) -> void:
	if _load == null:
		return
	var offset := offset_at(_time())
	if not _placed:  # a late joiner's load is placed, no pushes
		_placed = true
		_offset = offset
		_load.position.z = offset
		return
	var moved := offset - _offset
	_offset = offset
	var server := multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	# Riders: a client's own player rides on the blocks' velocity (its prediction and replays step with it). The
	# server carries them itself, once a tick: it steps a client 0-2 commands a tick (Player.CMD_BUDGET_PER_TICK), and
	# a carry per step drifted - a rider ended 1.4 m past the dock after one trip.
	var velocity := Vector3.ZERO if server else Vector3(0.0, 0.0, moved / delta)
	for block in _blocks:
		block.constant_linear_velocity = velocity
	if moved == 0.0:
		return
	_load.position.z = offset
	if _world:
		for player: Player in _world.players.values():
			if not player.alive or not (server or player.control == Player.Mode.LOCAL):
				continue
			if _rides(player):  # the server carries a rider; a client's own rider goes with the floor (no push on top)
				if server:
					_shove(player, Vector3(0.0, 0.0, moved), server)
			else:
				_push(player, signf(moved), server)


func _time() -> float:
	if time_override >= 0.0:
		return time_override
	return _world.shared_time() if _world else Time.get_ticks_usec() / 1e6


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


## Stands on the load: on the floor, and the floor is one of its blocks (the last move's collisions).
func _rides(player: Player) -> bool:
	if not player.is_on_floor():
		return false
	for i in player.get_slide_collision_count():
		var hit := player.get_slide_collision(i)
		if hit.get_normal().y > 0.7 and _blocks.has(hit.get_collider()):
			return true
	return false


## Moves a player through the load's blocks (not through the level); blocked - crushed.
func _shove(player: Player, motion: Vector3, server: bool) -> void:
	for block in _blocks:
		player.add_collision_exception_with(block)
	var hit := player.move_and_collide(motion)
	for block in _blocks:
		player.remove_collision_exception_with(block)
	if server and hit != null and hit.get_remainder().length() > CRUSH_SLACK:
		var game := get_node_or_null(^"/root/Game")  # not Game: tools load this without the autoloads
		if game:
			game.count("crushed")
		_world._server_suicide(player)
