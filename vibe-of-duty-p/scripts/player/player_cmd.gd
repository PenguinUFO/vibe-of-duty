class_name PlayerCmd
extends RefCounted
## One tick of player input. This is what the client sends to the server and replays during
## reconciliation, so simulation must depend on nothing but the previous state and this.

var move := Vector2.ZERO  # x: right, y: back (Input.get_vector convention, forward is -y)
var yaw := 0.0
var pitch := 0.0
var jump := false       # one-press event (buffered for a few ticks)
var jump_held := false  # key is down (lets a jump grab a ledge in mid-air)
var sprint := false
var crouch := false
var fire := false    # held
var aim := false     # held
var reload := false  # one-tick event
var melee := false   # one-tick event: hoof punch (the hands slot)
var select := -1     # one-tick event: weapon index to switch to, -1 = none
var view_tick := 0.0  # server tick the shooter was looking at (lag compensation); 0 = unknown
