class_name KillCam
extends Node3D
## Kill cam: after the local player is killed by somebody, replays the last seconds before the kill through the
## killer's eyes. Purely local and cosmetic: it replays what this machine drew (the poses of everyone as they were
## shown here, and the shots relayed to us), so it costs no network traffic. Lives under NetWorld; not created on a
## dedicated server.
##
## The replay starts right at the kill: REPLAY_BEFORE s before it and REPLAY_AFTER s after it, played in real time
## (so it runs that far behind the live recording, which keeps going). Together they fit into
## NetWorld.RESPAWN_DELAY (3 s). The kill cam is this death's screen: its last frame stays up until the player
## respawns (Player.respawn -> stop), so the plain "ВЫ ПОГИБЛИ" screen never shows after it.

const RECORD_INTERVAL := 1.0 / 60.0
const KEEP := 6.0            # s of history kept
const REPLAY_BEFORE := 2.4   # s replayed before the kill...
const REPLAY_AFTER := 0.5    # ...and after it
const BAR_HEIGHT := 0.08     # letterbox bars, share of the screen height

var world: NetWorld

var _frames: Array = []        # {t, poses: {peer_id: Array (Player.drawn_pose)}}
var _shots: Array = []         # {t, id, weapon, origin, ends}
var _names := {}               # peer_id -> name, kept for players who leave during the replay
var _record_timer := 0.0

var _playing := false
var _killer_id := -1
var _killer_name := ""
var _death_t := 0.0
var _replay_t := 0.0           # current time on the recording's clock
var _shot_t := 0.0             # shots up to this time have been replayed
# Stand-in bodies and first-person arms are built ahead of time, one per frame as players appear (_prewarm), and
# reused: building them at the moment of death took ~70 ms - a hitch right when the player dies.
var _ghosts := {}              # peer_id -> PlayerVisual
var _arms_by_id := {}          # peer_id -> FirstPersonArms in that player's colours
var _eye := Player.STAND_EYE
var _ads := 0.0
var _prev_look := Vector2.ZERO
var _prev_pos := Vector3.ZERO

var _camera := Camera3D.new()
var _view: WeaponView
var _arms: FirstPersonArms
var _ui := CanvasLayer.new()
var _title: Label
var _caption: Label


func _ready() -> void:
	_camera.far = 300.0
	add_child(_camera)
	_view = WeaponView.new()
	_view.is_viewmodel = true
	_view.visible = false
	_camera.add_child(_view)
	_ui.layer = 6
	_ui.visible = false
	add_child(_ui)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0 - BAR_HEIGHT
		bar.anchor_bottom = BAR_HEIGHT if top else 1.0
		_ui.add_child(bar)
	_title = _make_label(30)
	_title.text = "ВЫ ПОГИБЛИ"
	_title.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2))
	_title.anchor_right = 1.0
	_title.anchor_bottom = BAR_HEIGHT
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui.add_child(_title)
	_caption = _make_label(22)
	_caption.anchor_top = 1.0 - BAR_HEIGHT
	_caption.anchor_right = 1.0
	_caption.anchor_bottom = 1.0
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui.add_child(_caption)


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec() / 1e6
	_record(now, delta)
	if not _playing:
		_prewarm()
	if _playing:
		if Game.state != Game.State.PLAYING:
			stop()
			return
		_replay_t = minf(_replay_t + delta, _death_t + REPLAY_AFTER)  # then holds the last frame until the respawn
		_play(delta)


## The local player was just killed by `killer_id` (not by themselves or the map).
func start(killer_id: int) -> void:
	stop()
	if not world.players.has(killer_id):
		return
	_killer_id = killer_id
	_killer_name = (world.players[killer_id] as Player).player_name
	_death_t = Time.get_ticks_usec() / 1e6
	_begin()


## Ends the replay and gives the view back to the local player.
func stop() -> void:
	if not _playing:
		return
	_playing = false
	_ui.visible = false
	if world.hud:
		world.hud.visible = true
	if Game.net_log:
		print("[KILLCAM %d] end %.2f s after the kill (replay reached %+.2f s)" % [multiplayer.get_unique_id(),
				Time.get_ticks_usec() / 1e6 - _death_t, _replay_t - _death_t])
	for id in _ghosts:
		_show_ghost(_ghosts[id], false)
	_view.visible = false
	if _arms:
		_arms.visible = false
		_arms = null
	for id in world.players:
		(world.players[id] as Player).set_kill_cam(false)


func is_playing() -> bool:
	return _playing


## A shot as this machine showed it (remote shots and our own). Replayed from the shooter's recorded pose.
func record_shot(shooter_id: int, weapon: int, origin: Vector3, ends: PackedVector3Array) -> void:
	_shots.append({"t": Time.get_ticks_usec() / 1e6, "id": shooter_id, "weapon": weapon, "origin": origin, "ends": ends})


func _record(now: float, delta: float) -> void:
	_record_timer -= delta
	if _record_timer > 0.0:
		return
	_record_timer += RECORD_INTERVAL
	_record_timer = maxf(_record_timer, 0.0)
	var poses := {}
	for id in world.players:
		var player: Player = world.players[id]
		poses[id] = player.drawn_pose()
		_names[id] = player.player_name
	_frames.append({"t": now, "poses": poses})
	while not _frames.is_empty() and _frames[0]["t"] < now - KEEP:
		_frames.pop_front()
	while not _shots.is_empty() and _shots[0]["t"] < now - KEEP:
		_shots.pop_front()


func _begin() -> void:
	var from := _death_t - REPLAY_BEFORE
	if _frames.size() < 2:
		return
	_replay_t = maxf(from, _frames[0]["t"])
	if _pose_at(_killer_id, _replay_t).is_empty():
		return  # the killer only just appeared: nothing worth showing
	_shot_t = _replay_t
	_playing = true
	for id in world.players:
		(world.players[id] as Player).set_kill_cam(true)
	_arms = _arms_for(_killer_id)
	_camera.fov = Settings.fov
	_camera.make_current()
	_ui.visible = true
	if world.hud:
		world.hud.visible = false  # the match clock and kill feed would sit on the letterbox bars
	if Game.net_log:
		print("[KILLCAM %d] replay of %s from %.2f s before the kill" % [multiplayer.get_unique_id(), _killer_name,
				_death_t - _replay_t])
	var first := _pose_at(_killer_id, _replay_t)
	_eye = Player.CROUCH_EYE if first[3] else Player.STAND_EYE
	_ads = 1.0 if first[4] else 0.0
	_prev_look = Vector2(first[1], first[2])
	_prev_pos = first[0]
	_play(0.0)


func _play(delta: float) -> void:
	var me: Player = world.players.get(multiplayer.get_unique_id())
	var left := me.death_time_left if me != null else 0.0
	_caption.text = "Вас убил %s        Возрождение через %.1f" % [_killer_name, left]
	# Everybody but the killer is drawn by a stand-in body; the killer is the camera, with their gun and hooves.
	for frame in _frames:
		if frame["t"] > _replay_t:
			break
		for id in frame["poses"]:
			if id != _killer_id and not _ghosts.has(id):
				_ghost_for(id)  # not prewarmed yet (joined a moment ago)
	for id in _ghosts:
		var ghost: PlayerVisual = _ghosts[id]
		var pose := _pose_at(id, _replay_t) if id != _killer_id else []
		_show_ghost(ghost, not pose.is_empty())
		if pose.is_empty():
			continue
		ghost.global_position = pose[0]
		ghost.global_rotation = Vector3(0.0, pose[1], 0.0)
		ghost.set_aim_pitch(pose[2])
		ghost.set_crouched(pose[3])
		ghost.set_ads(pose[4])
		ghost.set_weapon(pose[6])
		if ghost._dead == pose[5]:
			ghost.set_dead(not pose[5])
		ghost.update_motion(delta, Vector3.ZERO)

	var killer := _pose_at(_killer_id, _replay_t)
	if not killer.is_empty():
		var dt := maxf(delta, 0.0001)
		_eye = lerpf(_eye, Player.CROUCH_EYE if killer[3] else Player.STAND_EYE, 1.0 - exp(-14.0 * delta))
		_ads = move_toward(_ads, 1.0 if killer[4] else 0.0, delta / PlayerVisual.ADS_BLEND_TIME)
		_camera.global_transform = Transform3D(Basis.from_euler(Vector3(killer[2], killer[1], 0.0)),
				killer[0] + Vector3.UP * _eye)
		var def := WeaponDB.get_def(killer[6])
		_camera.fov = lerpf(Settings.fov, Settings.fov * def.ads_fov_mult, _ads)
		var look := Vector2(killer[1], killer[2])
		var look_delta := look - _prev_look
		look_delta.x = wrapf(look_delta.x, -PI, PI)
		_prev_look = look
		var moved: Vector3 = killer[0] - _prev_pos
		_prev_pos = killer[0]
		var speed := Vector2(moved.x, moved.z).length() / dt
		_view.set_weapon(killer[6])
		_view.visible = killer[5]
		_arms.visible = killer[5]
		_view.update_pose(delta, _ads, -1.0, -1.0, 0.0, speed if speed < 15.0 else 0.0, true, look_delta, 0.0)
		_arms.pose()

	for shot in _shots:
		if shot["t"] > _shot_t and shot["t"] <= _replay_t:
			_replay_shot(shot)
	_shot_t = _replay_t


## Builds what a replay may need ahead of time: a stand-in body for every player and first-person arms for every
## possible killer. At most one per frame; the cached ones of players who left are freed.
func _prewarm() -> void:
	var me := multiplayer.get_unique_id()
	for id in world.players:
		if not _ghosts.has(id):
			_ghost_for(id)
			return
		if id != me and not _arms_by_id.has(id):
			_arms_for(id)
			return
	for cache in [_ghosts, _arms_by_id]:
		for id in cache.keys():
			if not world.players.has(id):
				(cache[id] as Node).queue_free()
				cache.erase(id)


func _ghost_for(id: int) -> PlayerVisual:
	if not _ghosts.has(id):
		var ghost := PlayerVisual.new()
		add_child(ghost)
		ghost.setup(id, (world.players[id] as Player).player_name if world.players.has(id) else _names.get(id, "Игрок"))
		_show_ghost(ghost, false)
		_ghosts[id] = ghost
	return _ghosts[id]


func _show_ghost(ghost: PlayerVisual, shown: bool) -> void:
	ghost.visible = shown
	ghost.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED


func _arms_for(id: int) -> FirstPersonArms:
	if not _arms_by_id.has(id):
		var arms := FirstPersonArms.new()
		arms.visible = false
		_camera.add_child(arms)
		arms.setup(id, _view)
		_arms_by_id[id] = arms
	return _arms_by_id[id]


func _replay_shot(shot: Dictionary) -> void:
	var def := WeaponDB.get_def(shot["weapon"])
	var muzzle: Vector3 = shot["origin"]
	if shot["id"] == _killer_id:
		_view.flash()
		_view.kick(1.0 if def.pellets == 1 else 2.0)
		Audio.play(def.sound_shot)
		muzzle = _view.muzzle_global_position()
	elif _ghosts.has(shot["id"]):
		var ghost: PlayerVisual = _ghosts[shot["id"]]
		ghost.set_weapon(shot["weapon"])
		ghost.show_shot()
		muzzle = ghost.muzzle_global_position()
		Audio.play(def.sound_shot, muzzle)
	var scene_root := get_tree().current_scene
	var ends: PackedVector3Array = shot["ends"]
	for i in ends.size():
		ShotEffects.spawn_tracer(scene_root, muzzle, ends[i])
		ShotEffects.spawn_impact(scene_root, ends[i], Vector3.UP)


## A player's recorded pose at time `t` (Player.drawn_pose, positions and angles interpolated), or [] when they
## were not there.
func _pose_at(id: int, t: float) -> Array:
	var i := 0
	while i < _frames.size() - 1 and _frames[i + 1]["t"] <= t:
		i += 1
	var a: Dictionary = _frames[i]
	var b: Dictionary = _frames[mini(i + 1, _frames.size() - 1)]
	var pa: Array = a["poses"].get(id, [])
	var pb: Array = b["poses"].get(id, pa)
	if pa.is_empty():
		return pb
	if pb.is_empty() or b["t"] <= a["t"]:
		return pa
	var f := clampf((t - a["t"]) / (b["t"] - a["t"]), 0.0, 1.0)
	if (pa[0] as Vector3).distance_to(pb[0]) > 2.0:
		f = 0.0  # a teleport (respawn): no sliding across the map
	var pose := pa.duplicate()
	pose[0] = (pa[0] as Vector3).lerp(pb[0], f)
	pose[1] = lerp_angle(pa[1], pb[1], f)
	pose[2] = lerpf(pa[2], pb[2], f)
	return pose


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
