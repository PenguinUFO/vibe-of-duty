class_name HudAugs
extends Control
## Bottom-left, over the health plate: what the build carries - a small plate per augmentation, in the body's order
## (hands, head, chest, legs), none for an empty slot. Drawn from primitives. Those with a state show it:
## the "ЧМП" lights up in the hands, the "Гренадир" dims when the grenade is gone, the "Хрях-бабах" counts down on its
## timer, the "Прыг-Прыг" puts out its upper chevron until the floor, the "Прыг-скок" fills with speed past a sprint.

const PLATE := 40.0
const GAP := 6.0
const ORDER: Array[String] = [PartDB.PIG_ARMS, PartDB.ENGINEER, PartDB.SKULL_PISTOL, PartDB.GRENADIER, PartDB.BOMB,
		PartDB.BUNNY, PartDB.JET_HOOVES]
const MAX_PLATES := 4       # one per body slot that has parts
const SIZE := Vector2(PLATE * MAX_PLATES + GAP * (MAX_PLATES - 1), PLATE)
const INK := UiTheme.TEXT
const SPENT := Color(UiTheme.TEXT_DIM, 0.6)
const FILL := Color(UiTheme.ACCENT, 0.4)
## The left half of a hoof's print, the toe up; the right one mirrors it.
const HOOF: Array[Vector2] = [Vector2(-1.5, -11), Vector2(-5, -8), Vector2(-8, -2), Vector2(-8.5, 5), Vector2(-6, 10),
		Vector2(-1.5, 10)]
const GEAR_TEETH := 8

var _parts: Array[String] = []
var _build: Array = []
var _cmp := false
var _grenade := false
var _armed := false
var _air_jump := false
var _hop := 0.0
var _bomb_left := 0.0
var _plate := UiTheme.box(UiTheme.HUD_PLATE, UiTheme.CHAMFER)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE


## The plates of a (sanitized) build.
func set_build(build: Array) -> void:
	if build == _build:
		return
	_build = build.duplicate()
	_parts.clear()
	for id in ORDER:
		if build.has(id):
			_parts.append(id)
	queue_redraw()


## `cmp`: the "ЧМП" is in the hands; `grenade`: the "Гренадир"'s is still in; `armed`: the bomb is counting;
## `air_jump`: the jump in the air is still there; `hop`: 0..1, speed past a sprint.
func set_state(cmp: bool, grenade: bool, armed: bool, air_jump: bool, hop: float) -> void:
	if cmp == _cmp and grenade == _grenade and armed == _armed and air_jump == _air_jump and hop == _hop:
		return
	if armed and not _armed:
		_bomb_left = WeaponDB.grenade("bomb_fuse", 1.5)
	_cmp = cmp
	_grenade = grenade
	_armed = armed
	_air_jump = air_jump
	_hop = hop
	queue_redraw()


func _process(delta: float) -> void:
	if _armed:
		_bomb_left = maxf(_bomb_left - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var half := Vector2.ONE * PLATE * 0.5
	for i in _parts.size():
		draw_set_transform(half + Vector2((PLATE + GAP) * i, 0.0))
		draw_style_box(_plate, Rect2(-half, half * 2.0))
		match _parts[i]:
			PartDB.PIG_ARMS:
				_draw_arms()
			PartDB.ENGINEER:
				_draw_engineer()
			PartDB.SKULL_PISTOL:
				_draw_skull()
			PartDB.GRENADIER:
				_draw_grenade()
			PartDB.BOMB:
				_draw_bomb()
			PartDB.BUNNY:
				_draw_bunny()
			PartDB.JET_HOOVES:
				_draw_jet_hooves()
	draw_set_transform(Vector2.ZERO)


## A hoof's print at `at`, its toe up before `angle` turns it.
func _hoof(at: Vector2, angle: float, scale_by: float, color: Color) -> void:
	for side in [1.0, -1.0]:
		var points := PackedVector2Array()
		for point in HOOF:
			points.append(at + (point * Vector2(side, 1.0) * scale_by).rotated(angle))
		draw_colored_polygon(points, color)


func _draw_arms() -> void:
	_hoof(Vector2(5, 0), PI * 0.5, 1.0, INK)  # the punch, to the right
	for y in [-5.0, 5.0]:  # what it leaves behind: the longer reach
		draw_rect(Rect2(-14, y - 1.0, 9, 2), UiTheme.TEXT_DIM)


func _draw_engineer() -> void:
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 32, INK, 3.0)
	for i in GEAR_TEETH:
		var way := Vector2.RIGHT.rotated(TAU * i / GEAR_TEETH)
		draw_line(way * 11.0, way * 15.5, INK, 5.0)
	draw_circle(Vector2.ZERO, 6.5, INK)  # the snout
	for x in [-2.5, 2.5]:
		draw_circle(Vector2(x, 0), 1.5, Color.BLACK)


func _draw_skull() -> void:
	var ink := UiTheme.ACCENT if _cmp else INK
	draw_circle(Vector2(-4, -3), 11.0, ink)
	draw_rect(Rect2(-9, 5, 11, 8), ink)  # the jaw
	for x in [-6.0, -2.0]:  # its teeth
		draw_rect(Rect2(x, 9, 1, 4), Color.BLACK)
	draw_circle(Vector2(2, -3), 4.0, Color.BLACK)  # the eye socket, the gun in it
	draw_rect(Rect2(2, -5, 14, 4), ink)


func _draw_grenade() -> void:
	draw_circle(Vector2(0, 2), 10.0, INK if _grenade else SPENT)
	draw_circle(Vector2(0, -8), 3.0, UiTheme.DANGER if _grenade else SPENT)  # its lamp (Grenade.LAMP)


func _draw_bomb() -> void:
	for y in [-4.0, 4.0]:  # the straps, out from behind the ball
		draw_rect(Rect2(-17, y - 1.0, 34, 2), UiTheme.TEXT_DIM)
	draw_circle(Vector2.ZERO, 12.0, UiTheme.DANGER)
	if _armed:
		var text := "%.1f" % _bomb_left
		var font := UiTheme.bold_font()
		draw_rect(Rect2(-14, -8, 28, 16), Color.BLACK)
		draw_string(font, Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, 5), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.DANGER)
		return
	draw_rect(Rect2(-9, -4, 18, 10), Color.BLACK)  # the timer...
	for x in [-7.0, 1.0]:  # ...with its idle "--" (ChestBomb.IDLE_TEXT)
		draw_rect(Rect2(x, 0, 6, 2), UiTheme.DANGER)


func _draw_bunny() -> void:
	var top := PLATE * 0.5 * (1.0 - 2.0 * _hop)
	var level := PackedVector2Array([Vector2(-PLATE, top), Vector2(PLATE, top), Vector2(PLATE, PLATE), Vector2(-PLATE, PLATE)])
	for part in Geometry2D.intersect_polygons(_outline(), level):
		draw_colored_polygon(part, FILL)
	for x in [-11.0, 1.0]:  # two hops...
		draw_arc(Vector2(x, 4), 6.0, PI, TAU, 12, INK, 2.5)
	_hoof(Vector2(12, 3), 0.0, 0.6, INK)  # ...and down for the third


## The plate's shape round its middle: UiTheme.box cuts two corners.
func _outline() -> PackedVector2Array:
	var h := PLATE * 0.5
	var cut := float(UiTheme.CHAMFER)
	return PackedVector2Array([Vector2(-h + cut, -h), Vector2(h, -h), Vector2(h, h - cut), Vector2(h - cut, h), Vector2(-h, h),
			Vector2(-h, -h + cut)])


func _draw_jet_hooves() -> void:
	_hoof(Vector2(0, 9), 0.0, 0.7, INK)
	draw_polyline(PackedVector2Array([Vector2(-8, 0), Vector2(0, -6), Vector2(8, 0)]), INK, 3.0)
	draw_polyline(PackedVector2Array([Vector2(-8, -8), Vector2(0, -14), Vector2(8, -8)]), INK if _air_jump else SPENT, 3.0)
