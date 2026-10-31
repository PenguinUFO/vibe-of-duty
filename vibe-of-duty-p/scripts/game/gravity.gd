class_name Gravity
extends RefCounted
## Which way is up for players and for things that fall. On ordinary maps up is +Y everywhere. On a spinning ring
## station (a RingGravity node in the level) up points at the ring's axis, a line along world Z: the floor is the
## inside of the rim, and a player across the ring stands upside down over your head.
##
## Everything here depends on the position only, so all machines agree on it without sending anything: a player's
## facing (yaw, pitch) stays an angle in the local frame at their feet (frame()), as on a flat map.

static var ring_radius := 0.0  # 0: an ordinary map; else the rim floor's distance from the axis (m)
static var ring_axis_y := 0.0  # the axis runs along Z through (0, ring_axis_y, 0)


static func is_ring() -> bool:
	return ring_radius > 0.0


## Unit up at `pos`.
static func up(pos: Vector3) -> Vector3:
	if ring_radius <= 0.0:
		return Vector3.UP
	var to_axis := Vector2(-pos.x, ring_axis_y - pos.y)
	if to_axis.length_squared() < 1e-6:
		return Vector3.UP
	to_axis = to_axis.normalized()
	return Vector3(to_axis.x, to_axis.y, 0.0)


## The local frame at `pos`: a rotation taking +Y to up(pos). On the ring it turns about Z only, so walking around
## it keeps the facing in the frame (what a player's yaw means there).
static func frame(pos: Vector3) -> Basis:
	if ring_radius <= 0.0:
		return Basis.IDENTITY
	var u := up(pos)
	return Basis(Vector3.BACK, atan2(-u.x, u.y))


## Height of `pos` over the floor level: y, or on the ring how far in from the rim.
static func height(pos: Vector3) -> float:
	if ring_radius <= 0.0:
		return pos.y
	return ring_radius - Vector2(pos.x, pos.y - ring_axis_y).length()


## `v` without its up component at `pos`.
static func flat(v: Vector3, pos: Vector3) -> Vector3:
	if ring_radius <= 0.0:
		return Vector3(v.x, 0.0, v.z)
	return v.slide(up(pos))
