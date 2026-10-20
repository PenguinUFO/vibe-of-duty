class_name MuzzleLights
extends Node3D
## Shots light up their surroundings: a warm flash of light at the muzzle for a few frames, so a firefight in the
## dark shows who is shooting and from where (and lights the shooter for a moment). A small pool of shadowless
## OmniLights reused round-robin - an automatic weapon keeps re-lighting the same one - so it costs at most POOL
## lights however many people shoot. One pool per scene, made on first use; cosmetic, not created without a screen.

const POOL := 3
const LIFE := 0.07          # s: from full brightness to dark
const ENERGY := 3.0
const RANGE := 7.0
const COLOR := Color(1.0, 0.72, 0.42)
const REUSE_DISTANCE := 1.5  # a new flash this close to a lit one re-lights it instead of taking another

static var _instance: MuzzleLights

var _lights: Array[OmniLight3D] = []
var _age := PackedFloat32Array()
var _next := 0


static func flash(context: Node, pos: Vector3) -> void:
	var pool := _pool(context)
	if pool:
		pool._flash(pos)


static func _pool(context: Node) -> MuzzleLights:
	if DisplayServer.get_name() == "headless" or context == null or not context.is_inside_tree():
		return null
	var scene := context.get_tree().current_scene
	if scene == null:
		return null
	if not is_instance_valid(_instance) or not _instance.is_inside_tree() or _instance.get_parent() != scene:
		_instance = MuzzleLights.new()
		scene.add_child(_instance)
	return _instance


func _init() -> void:
	top_level = true
	for i in POOL:
		var light := OmniLight3D.new()
		light.light_color = COLOR
		light.omni_range = RANGE
		light.omni_attenuation = 1.6
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)
	_age.resize(POOL)
	_age.fill(LIFE)


func _flash(pos: Vector3) -> void:
	var slot := -1
	for i in POOL:
		if _lights[i].visible and _lights[i].global_position.distance_to(pos) < REUSE_DISTANCE:
			slot = i
			break
	if slot < 0:
		slot = _next
		_next = (_next + 1) % POOL
	_lights[slot].global_position = pos
	_lights[slot].visible = true
	_age[slot] = 0.0
	_lights[slot].light_energy = ENERGY * randf_range(0.8, 1.2)


func _process(delta: float) -> void:
	for i in POOL:
		if not _lights[i].visible:
			continue
		_age[i] += delta
		if _age[i] >= LIFE:
			_lights[i].visible = false
		else:
			_lights[i].light_energy = ENERGY * (1.0 - _age[i] / LIFE)
