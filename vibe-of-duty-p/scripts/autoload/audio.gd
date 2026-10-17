extends Node
## Single entry point for sound: Audio.play("shot"), Audio.play("hit", world_position).
##
## Lookup order for an id:
##   1. a file named <id>.ogg / .wav / .mp3 anywhere under res://audioSFX/ (drop-in replacement)
##   2. a procedurally generated placeholder (see PLACEHOLDERS)
## Ids starting with "ui_" are routed to the UI bus, everything else to SFX.

const SFX_DIR := "res://audioSFX"
const AUDIO_EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]
const MIX_RATE := 22050
const POOL_SIZE := 16
const MUSIC_DIR := "res://music"
const HEARING_RANGE := 70.0  # positional sounds fade out completely beyond this (m)

# kind: "noise" (decaying noise burst), "tone" (sine, freq -> freq_end sweep), "thump" (low sweep + noise)
const PLACEHOLDERS := {
	"shot": {"kind": "noise", "dur": 0.18, "decay": 22.0, "vol": 0.9},
	"shot_pistol": {"kind": "noise", "dur": 0.14, "decay": 28.0, "vol": 0.8},
	"shot_shotgun": {"kind": "thump", "dur": 0.3, "freq": 140.0, "freq_end": 50.0, "decay": 12.0, "vol": 1.0},
	"empty": {"kind": "tone", "dur": 0.05, "freq": 1800.0, "freq_end": 1800.0, "decay": 40.0, "vol": 0.4},
	"reload": {"kind": "tone", "dur": 0.12, "freq": 500.0, "freq_end": 900.0, "decay": 14.0, "vol": 0.5},
	"hit": {"kind": "tone", "dur": 0.07, "freq": 1400.0, "freq_end": 900.0, "decay": 30.0, "vol": 0.6},
	"hurt": {"kind": "thump", "dur": 0.2, "freq": 220.0, "freq_end": 90.0, "decay": 16.0, "vol": 0.7},
	"death": {"kind": "thump", "dur": 0.5, "freq": 180.0, "freq_end": 40.0, "decay": 6.0, "vol": 0.9},
	"kill": {"kind": "tone", "dur": 0.18, "freq": 700.0, "freq_end": 1400.0, "decay": 10.0, "vol": 0.6},
	"jump": {"kind": "tone", "dur": 0.1, "freq": 200.0, "freq_end": 320.0, "decay": 18.0, "vol": 0.3},
	"land": {"kind": "thump", "dur": 0.12, "freq": 110.0, "freq_end": 60.0, "decay": 25.0, "vol": 0.5},
	"step": {"kind": "noise", "dur": 0.06, "decay": 50.0, "vol": 0.25},
	"slide": {"kind": "noise", "dur": 0.35, "decay": 6.0, "vol": 0.3},
	"impact": {"kind": "noise", "dur": 0.05, "decay": 60.0, "vol": 0.35},
	"match_start": {"kind": "tone", "dur": 0.4, "freq": 440.0, "freq_end": 880.0, "decay": 5.0, "vol": 0.5},
	"match_end": {"kind": "tone", "dur": 0.6, "freq": 880.0, "freq_end": 330.0, "decay": 4.0, "vol": 0.5},
	"equip": {"kind": "tone", "dur": 0.1, "freq": 300.0, "freq_end": 600.0, "decay": 20.0, "vol": 0.4},
	"spawn": {"kind": "tone", "dur": 0.25, "freq": 400.0, "freq_end": 800.0, "decay": 8.0, "vol": 0.4},
	"ui_click": {"kind": "tone", "dur": 0.04, "freq": 1200.0, "freq_end": 1200.0, "decay": 50.0, "vol": 0.4},
}

var _streams: Dictionary = {}  # id -> AudioStream
var _file_index: Dictionary = {}  # id -> resource path
var _music_index: Dictionary = {}  # id -> resource path
var _music_id := ""
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _music_player: AudioStreamPlayer
var _silent := DisplayServer.get_name() == "headless"  # dedicated server: nothing to play


func _ready() -> void:
	_scan_dir(SFX_DIR)
	_scan_music(MUSIC_DIR)
	for i in POOL_SIZE:
		var p2 := AudioStreamPlayer.new()
		add_child(p2)
		_pool_2d.append(p2)
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = &"SFX"
		p3.unit_size = 8.0
		p3.max_distance = HEARING_RANGE
		add_child(p3)
		_pool_3d.append(p3)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	add_child(_music_player)


## Plays sound [param id]. If [param world_position] is a Vector3 the sound is positional.
func play(id: String, world_position: Variant = null, volume_db: float = 0.0) -> void:
	if _silent:
		return
	var stream := _get_stream(id)
	if stream == null:
		push_warning("Audio: unknown sound id '%s'" % id)
		return
	if world_position is Vector3:
		var p3 := _free_player(_pool_3d) as AudioStreamPlayer3D
		p3.global_position = world_position
		p3.stream = stream
		p3.volume_db = volume_db
		p3.play()
	else:
		var p2 := _free_player(_pool_2d) as AudioStreamPlayer
		p2.bus = &"UI" if id.begins_with("ui_") else &"SFX"
		p2.stream = stream
		p2.volume_db = volume_db
		p2.play()


func play_music(stream: AudioStream) -> void:
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
	_music_id = ""


## Plays the looping track `res://music/<id>.ogg|mp3|wav` (ids used: "menu", "game"). Silence if the file
## does not exist, so music can simply be dropped into the folder later.
func play_music_id(id: String) -> void:
	if _silent or _music_id == id:
		return
	if not _music_index.has(id):
		stop_music()
		return
	var stream: AudioStream = load(_music_index[id])
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music_id = id
	play_music(stream)


func _get_stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var stream: AudioStream = null
	if _file_index.has(id):
		stream = load(_file_index[id])
	elif PLACEHOLDERS.has(id):
		stream = _synthesize(PLACEHOLDERS[id])
	if stream != null:
		_streams[id] = stream
	return stream


func _free_player(pool: Array) -> Node:
	for p in pool:
		if not p.playing:
			return p
	return pool[0]  # all busy: steal the oldest


func _scan_dir(dir_path: String) -> void:
	for file in DirAccess.get_files_at(dir_path):
		# Exported builds list files as "<name>.ext.import"/".remap".
		var clean := file.trim_suffix(".import").trim_suffix(".remap")
		if clean.get_extension() in AUDIO_EXTENSIONS:
			_file_index[clean.get_basename()] = dir_path.path_join(clean)
	for sub in DirAccess.get_directories_at(dir_path):
		_scan_dir(dir_path.path_join(sub))


func _scan_music(dir_path: String) -> void:
	for file in DirAccess.get_files_at(dir_path):
		var clean := file.trim_suffix(".import").trim_suffix(".remap")
		if clean.get_extension() in AUDIO_EXTENSIONS:
			_music_index[clean.get_basename()] = dir_path.path_join(clean)
	for sub in DirAccess.get_directories_at(dir_path):
		_scan_music(dir_path.path_join(sub))


func _synthesize(def: Dictionary) -> AudioStreamWAV:
	var count := int(MIX_RATE * float(def["dur"]))
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def)  # deterministic placeholders
	var kind: String = def["kind"]
	var decay: float = def["decay"]
	var vol: float = def["vol"]
	var freq: float = def.get("freq", 0.0)
	var freq_end: float = def.get("freq_end", freq)
	var phase := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var env := exp(-decay * t)
		var sample := 0.0
		if kind != "noise":
			var f := lerpf(freq, freq_end, float(i) / count)
			phase += TAU * f / MIX_RATE
			sample = sin(phase)
		if kind != "tone":
			sample += rng.randf_range(-1.0, 1.0) * (0.5 if kind == "thump" else 1.0)
		data.encode_s16(i * 2, int(clampf(sample * env * vol, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
