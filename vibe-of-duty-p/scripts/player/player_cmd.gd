class_name PlayerCmd
extends RefCounted
## One tick of player input. This is what the client will send to the server and replay
## during reconciliation, so movement must depend on nothing but the previous state and this.

var move := Vector2.ZERO  # x: right, y: back (Input.get_vector convention, forward is -y)
var yaw := 0.0
var pitch := 0.0
var jump := false
var sprint := false
var crouch := false
