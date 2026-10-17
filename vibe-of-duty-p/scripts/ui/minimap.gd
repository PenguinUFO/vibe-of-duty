class_name Minimap
extends Control
## Square radar in the top-right corner, north up: level blocks as a floor plan, the local player as an arrow
## turned to where they look (centre of the view). Shots fired by others stay as fixed marks at the spot they were
## fired from and fade out; they do not follow the shooter.

const SIDE := 200.0         # screen size (px)
const HALF_RANGE := 40.0    # world half-width shown (m)
const SHOT_SHOW_TIME := 3.0 # seconds a shot mark stays on the map
const WALL_MIN_TOP := 0.4   # blocks lower than this (the floor) are not drawn as structure

var world: NetWorld

var _blocks: Array[Block] = []
var _shots: Array = []  # [Vector2 world xz, float time]


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * SIDE
	size = custom_minimum_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The level is static: collect its blocks once.
	for node in get_tree().current_scene.find_children("*", "Block", true, false):
		var block := node as Block
		if block.global_position.y + block.size.y * 0.5 > WALL_MIN_TOP:
			_blocks.append(block)


func add_shot(origin: Vector3) -> void:
	_shots.append([Vector2(origin.x, origin.z), Time.get_ticks_msec() / 1000.0])


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.08, 0.6))
	var me: Player = null
	if world != null:
		for id in world.players:
			if (world.players[id] as Player).is_local:
				me = world.players[id]
	var centre_world := Vector2.ZERO
	if me != null:
		centre_world = Vector2(me.global_position.x, me.global_position.z)
	var scale := SIDE * 0.5 / HALF_RANGE
	var origin := Vector2.ONE * SIDE * 0.5 - centre_world * scale  # world xz -> screen

	for block in _blocks:
		var half := block.size * 0.5
		var corners := PackedVector2Array()
		for c in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z), Vector3(half.x, 0, half.z), Vector3(-half.x, 0, half.z)]:
			var w: Vector3 = block.global_transform * c
			corners.append(origin + Vector2(w.x, w.z) * scale)
		draw_colored_polygon(corners, Color(0.55, 0.6, 0.65, 0.85))

	var now := Time.get_ticks_msec() / 1000.0
	_shots = _shots.filter(func(s): return now - s[1] <= SHOT_SHOW_TIME)
	for s in _shots:
		var age: float = now - s[1]
		var alpha := 1.0 - age / SHOT_SHOW_TIME
		var p: Vector2 = origin + (s[0] as Vector2) * scale
		draw_circle(p, 4.0, Color(1.0, 0.25, 0.2, alpha))
		draw_arc(p, 6.0 + age * 5.0, 0.0, TAU, 24, Color(1.0, 0.25, 0.2, alpha * 0.6), 1.5, true)

	# Own arrow: the player looks along -Z of their rotation; on the map +Y is south.
	if me != null:
		var dir := Vector2(-sin(me.rotation.y), -cos(me.rotation.y))
		var side := Vector2(-dir.y, dir.x)
		var c := Vector2.ONE * SIDE * 0.5
		draw_colored_polygon(PackedVector2Array([c + dir * 10.0, c - dir * 7.0 + side * 6.0, c - dir * 3.0, c - dir * 7.0 - side * 6.0]),
				Color(0.4, 0.9, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)
