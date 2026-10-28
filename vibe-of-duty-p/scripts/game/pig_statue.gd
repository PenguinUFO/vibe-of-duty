class_name PigStatue
extends Node3D
## The statue in the middle of the Chernobyl map (the owner, 2026-10-28): a pig with a Kalashnikov on a pedestal, in
## the pose of the reference's monument - the right arm up, the gun raised over the head by its pistol grip, the left arm
## down at the side, the head lifted. Read Docs/LEVEL_CHERNOBYL.md first.
## Built at load from the players' own body (Mannequin, posed once - the arms by hand: Mannequin poses them only round
## a held gun) and the game's AK (WeaponView), all in bronze. The node's origin is the pedestal's top, its -Z where the
## pig looks; `statue_scale` x life size. Collision: one box round the body (bullets stop on it, the raised gun lets
## them through).
##
## It shoots back. A bullet into the box (PlayerWeapons.SHOT_LISTENER, on the server) makes the shooter its attacker:
## - the head snaps round (HEAD_SPEED, an owl's turn: up to HEAD_YAW_MAX either way, on its own, the body stays) and
##   follows the attacker while it sees them, else stares at where they were last seen;
## - the body turns on the pedestal and the arm brings the AK down, slowly (AIM_SPEED), towards the attacker or their
##   last known place, and fires bursts there once on it (AK damage; a magazine, then a reload pause);
## - until the attacker dies (from anything); then it lifts the gun back into the monument pose. A new shooter takes over.
## Server-authoritative: the server thinks and deals the damage (a statue kill counts as a suicide: no killer); clients
## get the pose (_sync, SYNC_INTERVAL) and the shots (_shot) from it.

const GROUP := "pig_statues"
const BRONZE := Color(0.36, 0.29, 0.19)
const BODY_BOX := Vector3(0.7, 1.75, 0.55)   # life size, round the body from the feet up
const HEAD_SPEED := 9.0        # rad/s the head turns at its attacker: a jerk
const HEAD_REST_SPEED := 0.6   # rad/s back to looking up, once the attacker is dead
const HEAD_YAW_MAX := 2.6      # rad either way from the body's front
const HEAD_PITCH_MAX := 1.1
const AIM_SPEED := 0.5         # rad/s the gun swings: a sprint across its view at under ~12 m outruns it
const BODY_SPEED := 0.7        # rad/s the body turns on the pedestal
const REST_SPEED := 0.4        # rad/s back into the monument pose
const FIRE_CONE := 0.06        # rad: fires when the gun is this close to where it wants to shoot
const SPREAD := deg_to_rad(1.5)  # cone half angle of its shots
const BURST := Vector2i(3, 6)  # rounds per burst
const BURST_PAUSE := 0.35
const REACH := 0.5             # the gun hand from the shoulder (life size): the arm nearly straight
const SYNC_INTERVAL := 1.0 / 30.0
const SMOOTH := 18.0           # clients: how fast the shown pose follows the synced one (1/s)

@export var statue_scale := 3.0
@export var head_up := 0.3                  # rad the head and chest lift (Mannequin.pitch)
## The gun's barrel direction in the monument pose (the pig's frame: x right, y up, -z forward): up, a little out and
## forward. The hand is REACH along it from the shoulder.
@export var barrel := Vector3(0.18, 1.0, -0.12)

var _world: NetWorld
var _body := Node3D.new()
var _head_node: Node3D
var _head_origin := Vector3.ZERO  # the head centre (body frame, life size)
var _gun := WeaponView.new()
var _grip := Vector3.ZERO         # the pistol grip's palm point in the gun's frame
var _right_arm: Dictionary
var _shoulder_r := Vector3.ZERO   # body frame, life size
var _solid := StaticBody3D.new()

# The pose (server: simulated; clients: shown, following _net_*). Statue frame: the node's own, before the body turns.
var _body_yaw := 0.0
var _aim := Vector3.UP            # the gun's direction (statue frame, unit)
var _head := Vector2.ZERO         # head yaw, pitch (body frame)
var _net_yaw := 0.0
var _net_aim := Vector3.UP
var _net_head := Vector2.ZERO

# Server.
var _attacker := 0                # peer id; 0: none
var _last_seen := Vector3.INF     # the attacker's chest when last seen (world)
var _cooldown := 0.0
var _burst := 0
var _mag := 0
var _sync_left := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_world = get_node_or_null("../World") as NetWorld
	_body.name = "Body"
	_body.scale = Vector3.ONE * statue_scale
	add_child(_body)
	_build()
	var material := _bronze()
	for mesh in _body.find_children("*", "GeometryInstance3D", true, false):
		if mesh.get_parent() is Marker3D:
			continue  # the muzzle flash keeps its glow
		(mesh as GeometryInstance3D).material_override = material
	_solid.collision_layer = Layers.WORLD
	_solid.collision_mask = 0
	_solid.set_meta(PlayerWeapons.SHOT_LISTENER, _on_shot_by)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BODY_BOX * statue_scale
	shape.shape = box
	shape.position = Vector3(0.0, BODY_BOX.y * statue_scale / 2, 0.0)
	_solid.add_child(shape)
	add_child(_solid)
	_aim = _rest_aim()
	_net_aim = _aim
	_head = Vector2(0.0, head_up)
	_net_head = _head
	_mag = _gun.def.mag_size
	_pose()


func _build() -> void:
	var pig := Mannequin.new()
	_body.add_child(pig)
	pig.build(BRONZE)
	pig.pitch = head_up
	pig.pose()  # legs, torso, head (no gun: the arms are left alone)
	for side in ["L", "R"]:  # its arms are posed only round a held gun: ours instead
		for part in ["Shoulder", "UpperArm", "Elbow", "Forearm", "Hand"]:
			pig.get_node(part + side).free()
	_head_node = pig.get_node("Head")
	_head_origin = _head_node.position
	var chest := Mannequin.chest_frame(head_up, 0.0)
	_shoulder_r = chest * Vector3(Mannequin.SHOULDER_X, Mannequin.SHOULDER_UP, 0.0)
	var shoulder_l := chest * Vector3(-Mannequin.SHOULDER_X, Mannequin.SHOULDER_UP, 0.0)

	_body.add_child(_gun)
	_gun.set_weapon(WeaponDB.index_of("ak"))
	_grip = Mannequin._view_point(_gun.def.right_hand)
	_right_arm = Mannequin.make_arm(_body, "R", BRONZE)
	var left := Mannequin.make_arm(_body, "L", BRONZE)
	Mannequin.pose_arm(left, shoulder_l, shoulder_l + Vector3(-0.1, -0.5, -0.04), Vector3(0.0, -1.0, 0.1),
			Vector3.RIGHT, Vector3(0.0, 0.0, 1.0))


## The middle of the collision box (world): where a shot at its body goes.
func chest_point() -> Vector3:
	return global_transform * Vector3(0.0, BODY_BOX.y * statue_scale * 0.6, 0.0)


func _rest_aim() -> Vector3:
	return barrel.normalized()


func _is_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _physics_process(delta: float) -> void:
	if _world == null:
		return
	if _is_server():
		_think(delta)
	else:
		var w := 1.0 - exp(-SMOOTH * delta)
		_body_yaw = lerp_angle(_body_yaw, _net_yaw, w)
		_aim = _aim.slerp(_net_aim, w).normalized()
		_head = _head.lerp(_net_head, w)


func _process(_delta: float) -> void:
	_pose()


# --- server -------------------------------------------------------------------------------------------------------

## A bullet hit the statue (PlayerWeapons._tell_shot_level): its shooter is the attacker now, where they stand.
func _on_shot_by(shooter: Player) -> void:
	if not shooter.alive:
		return
	if _attacker != shooter.peer_id:
		_burst = 0  # a fresh aim: the first burst waits for the gun to get there
	_attacker = shooter.peer_id
	_last_seen = _chest(shooter)


func _think(delta: float) -> void:
	var attacker := _attacker_player()
	var inv := global_transform.affine_inverse().basis
	var want_aim := _rest_aim()
	var aim_speed := REST_SPEED
	var want_yaw := 0.0
	var want_head := Vector2(0.0, head_up)
	var head_speed := HEAD_REST_SPEED
	if attacker != null:
		var eye := attacker.global_position + Vector3.UP * (Player.CROUCH_EYE if attacker.is_crouched else Player.STAND_EYE)
		var head_world := global_transform * (_body.transform * _head_origin)
		var look := _last_seen
		if _sees(head_world, eye) or _sees(head_world, _chest(attacker)):
			_last_seen = _chest(attacker)
			look = eye
		var d := _body.transform.basis.inverse() * (inv * (look - head_world))
		want_head = Vector2(clampf(atan2(-d.x, -d.z), -HEAD_YAW_MAX, HEAD_YAW_MAX),
				clampf(atan2(d.y, Vector2(d.x, d.z).length()), -HEAD_PITCH_MAX, HEAD_PITCH_MAX))
		head_speed = HEAD_SPEED
		var to := inv * (_last_seen - global_transform * (_body.transform * _shoulder_r))
		want_aim = to.normalized()
		aim_speed = AIM_SPEED
		want_yaw = atan2(-to.x, -to.z)
	_body_yaw = rotate_toward(_body_yaw, want_yaw, BODY_SPEED * delta)
	_aim = _turn(_aim, want_aim, aim_speed * delta)
	# Yaw moves without wrapping: from far left to far right the head turns the long way, through the front.
	_head = Vector2(move_toward(_head.x, want_head.x, head_speed * delta),
			move_toward(_head.y, want_head.y, head_speed * delta))
	_cooldown -= delta
	if attacker != null and not Game.is_frozen() and _cooldown <= 0.0 and _aim.angle_to(want_aim) < FIRE_CONE:
		_fire()
	_sync_left -= delta
	if _sync_left <= 0.0:
		_sync_left = SYNC_INTERVAL
		for peer in _world._ready_peers:
			_sync.rpc_id(peer, _body_yaw, _aim, _head)


func _attacker_player() -> Player:
	if _attacker == 0:
		return null
	var player := _world.players.get(_attacker) as Player
	if player == null or not player.alive:
		_attacker = 0  # dead (or gone): the statue calms down
		return null
	return player


static func _chest(player: Player) -> Vector3:
	return player.global_position + Vector3.UP * (0.7 if player.is_crouched else 1.1)


func _sees(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD, [_solid.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func _turn(from: Vector3, to: Vector3, step: float) -> Vector3:
	var angle := from.angle_to(to)
	if angle <= step:
		return to
	return from.slerp(to, step / angle).normalized()


## One round at the attacker's last known place, from the muzzle, with SPREAD. Hits whoever is in the way.
func _fire() -> void:
	var def := _gun.def
	if _burst <= 0:
		_burst = randi_range(BURST.x, BURST.y)
	_burst -= 1
	_mag -= 1
	_cooldown = def.fire_interval
	if _mag <= 0:
		_mag = def.mag_size
		_cooldown = def.reload_time
	elif _burst <= 0:
		_cooldown = BURST_PAUSE
	var muzzle := _gun.muzzle_global_position()
	var shoulder := global_transform * (_body.transform * _shoulder_r)
	var point := shoulder + global_transform.basis * _aim * shoulder.distance_to(_last_seen)
	var dir := _scatter((point - muzzle).normalized())
	var r := _trace(muzzle, dir, def.max_range)
	var victim: Player = r["player"]
	Game.count("statue_shots")
	if victim != null:
		_hit(victim, r["head"], muzzle.distance_to(r["pos"]), muzzle)
	if not Game.dedicated:
		_show_shot(r["pos"])
	for peer in _world._ready_peers:
		_shot.rpc_id(peer, r["pos"])


static func _scatter(dir: Vector3) -> Vector3:
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var up := side.cross(dir)
	var angle := randf() * TAU
	return (dir + (side * cos(angle) + up * sin(angle)) * tan(SPREAD * sqrt(randf()))).normalized()


## The first thing a round hits: the level (not the statue itself) or a player's hitbox (live, no rewind: the server's
## own shot). No cover penetration.
func _trace(from: Vector3, dir: Vector3, max_range: float) -> Dictionary:
	var end := from + dir * max_range
	var query := PhysicsRayQueryParameters3D.create(from, end, Layers.WORLD, [_solid.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var best := max_range
	var result := {"pos": end, "player": null, "head": false}
	if not hit.is_empty():
		best = from.distance_to(hit["position"])
		result["pos"] = hit["position"]
	for id in _world.players:
		var player: Player = _world.players[id]
		if not player.alive:
			continue
		var state := player.hitbox_state()
		var t_head := LagComp.ray_sphere(from, dir, LagComp.head_center(state), LagComp.HEAD_RADIUS)
		var seg := LagComp.body_segment(state)
		var t_body := LagComp.ray_capsule(from, dir, seg[0], seg[1], LagComp.BODY_RADIUS)
		var head := t_head >= 0.0 and (t_body < 0.0 or t_head <= t_body + 0.0001)
		var t := t_head if head else t_body
		if t >= 0.0 and t < best:
			best = t
			result = {"pos": from + dir * t, "player": player, "head": head}
	return result


## Server: a round of AK damage into `victim` (its armour holds as against a player's AK). A kill is the victim's own
## death in the score (NetWorld._server_kill with the victim as the killer): the statue is not a player.
func _hit(victim: Player, head: bool, distance: float, from: Vector3) -> void:
	if not victim.alive or victim.spawn_protect > 0:
		return
	var def := _gun.def
	var amount := def.damage_at(distance) * (def.head_mult if head else 1.0) * victim.damage_taken_mult(head)
	var killed := victim.server_damage(amount, def.regen_block)
	Game.count("statue_hits")
	if victim.control == Player.Mode.LOCAL:
		victim.on_damaged_from(from)  # the host is the victim
	elif victim.peer_id in _world._ready_peers:
		_world._damaged_from.rpc_id(victim.peer_id, from)
	if killed:
		Game.count("statue_kills")
		_world._server_kill(victim, victim, -1, head)


# --- everyone -----------------------------------------------------------------------------------------------------

@rpc("authority", "unreliable_ordered")
func _sync(body_yaw: float, aim: Vector3, head: Vector2) -> void:
	_net_yaw = body_yaw
	_net_aim = aim.normalized()
	_net_head = head


@rpc("authority", "unreliable")
func _shot(end: Vector3) -> void:
	_show_shot(end)


func _show_shot(end: Vector3) -> void:
	var def := _gun.def
	var muzzle := _gun.muzzle_global_position()
	_gun.flash()
	MuzzleLights.flash(self, muzzle)
	Audio.play(def.sound_shot, muzzle, def.loudness)
	var level := get_parent()
	ShotEffects.spawn_tracer(level, muzzle, end)
	ShotEffects.spawn_impact(level, end, (muzzle - end).normalized())
	Audio.play("impact", end)
	for id in _world.players:
		(_world.players[id] as Player).react_to_shot(muzzle, end)


## Body yaw, head and arm with the gun from the current pose. The gun is held by its pistol grip, its barrel along
## _aim; raised, its top turns towards the head (the magazine out), levelled, up.
func _pose() -> void:
	_body.rotation.y = _body_yaw
	_head_node.transform = Transform3D(Basis(Vector3.UP, _head.x) * Basis(Vector3.RIGHT, _head.y), _head_origin)
	var aim := Basis(Vector3.UP, -_body_yaw) * _aim  # statue frame -> body frame
	var back := -aim  # the gun's +Z (its barrel is -Z)
	var raised := clampf(aim.y, 0.0, 1.0)
	var hint := Vector3.UP.lerp(Vector3.LEFT, raised)
	var top := hint - back * hint.dot(back)
	top = top.normalized() if top.length() > 0.01 else Vector3.FORWARD
	var gun_basis := Basis(top.cross(back), top, back)
	var palm := _shoulder_r + aim * REACH
	_gun.transform = Transform3D(gun_basis, palm - gun_basis * _grip)
	Mannequin.pose_arm(_right_arm, _shoulder_r, palm, gun_basis * Mannequin.RIGHT_FINGERS,
			gun_basis * Mannequin.RIGHT_PALM, Mannequin.RIGHT_POLE.lerp(Vector3(1.0, -0.2, 0.3), raised))


## Bronze with the blocks' coarse noise (Block): the statue reads as part of the scenery, not as a player.
func _bronze() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = BRONZE
	material.albedo_texture = Block._noise_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / Block.NOISE_METRES * 2.0
	material.metallic = 0.5
	material.roughness = 0.6
	return material
