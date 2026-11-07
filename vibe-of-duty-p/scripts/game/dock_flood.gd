class_name DockFlood
extends Node3D
## Read Docs/LEVEL_DRYDOCK.md first; update it with any change here.
## The dry dock's lock: the dock fills and drains on one schedule from the server's clock (NetWorld.shared_time), as
## CraneBridge's, so every machine sees the same water with nothing sent, a late joiner too. Beacons flash before and
## while it fills. The server drowns whoever stands in the water with their head under it, and whoever goes through
## the thin ice of the sea. The water has no body: bullets and grenades go through it.
## Must come before Players in the scene.

const DOCK_MIN := Vector2(-52.0, -8.75)   # x, z: the dock and the tunnel to the pump house
const DOCK_MAX := Vector2(42.5, 8.75)
const FLOOR_Y := -6.0
const FULL_Y := -3.7                      # just under the submarine's lower deck
const HEAD := 1.5                         # m over the feet: water higher than this drowns
const SEA_X := 45.0                       # east of here
const SEA_Y := -2.2
const SEA_SIZE := Vector2(60.0, 130.0)
const BEACONS: Array[Vector3] = [Vector3(-36.5, 2.4, -9.6), Vector3(-36.5, 2.4, 9.6), Vector3(41.5, 2.4, -9.6),
		Vector3(41.5, 2.4, 9.6)]
const FLASH := 1.2                        # per second
const WATER_COLOR := Color(0.05, 0.09, 0.11, 0.92)

@export var dry := 40.0                   # s
@export var warn := 6.0                   # s of the dry time, at its end: the beacons flash
@export var fill := 14.0                  # s
@export var full := 30.0                  # s
@export var drain := 10.0                 # s
@export var phase := 0.0                  # s added to the clock

## Tools (screenshots): the time the schedule is read at instead of the server's clock (negative: off).
var time_override := -1.0

var _world: NetWorld
var _water: MeshInstance3D
var _beacons: Array[OmniLight3D] = []
var _beacon_bulbs: Array[MeshInstance3D] = []


func _ready() -> void:
	_world = get_node_or_null("../World") as NetWorld
	if DisplayServer.get_name() != "headless":
		_build()


func _physics_process(_delta: float) -> void:
	var time := _time()
	var level := level_at(time)
	if _water:
		_water.position.y = level
		_water.visible = level > FLOOR_Y + 0.02
		var on := warning_at(time) and fposmod(time * FLASH, 1.0) < 0.5
		for light in _beacons:
			light.visible = on
		for bulb in _beacon_bulbs:
			bulb.visible = on
	if _world == null or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	for player: Player in _world.players.values():
		if player.alive and _under(player.global_position, level):
			var game := get_node_or_null(^"/root/Game")  # not Game: tools load this without the autoloads
			if game:
				game.count("drowned")
			_world._server_suicide(player, "drowned")


## The water's height at time t.
func level_at(t: float) -> float:
	var tau := fposmod(t + phase, dry + fill + full + drain)
	if tau < dry:
		return FLOOR_Y
	tau -= dry
	if tau < fill:
		return lerpf(FLOOR_Y, FULL_Y, tau / fill)
	tau -= fill
	if tau < full:
		return FULL_Y
	return lerpf(FULL_Y, FLOOR_Y, (tau - full) / drain)


## The beacons flash: the last seconds of the dry time and while the water rises.
func warning_at(t: float) -> bool:
	var tau := fposmod(t + phase, dry + fill + full + drain)
	return tau >= dry - warn and tau < dry + fill


func _under(feet: Vector3, level: float) -> bool:
	if feet.x > SEA_X:
		return feet.y < SEA_Y
	return feet.x > DOCK_MIN.x and feet.x < DOCK_MAX.x and feet.z > DOCK_MIN.y and feet.z < DOCK_MAX.y \
			and feet.y + HEAD < level


func _time() -> float:
	if time_override >= 0.0:
		return time_override
	return _world.shared_time() if _world else Time.get_ticks_usec() / 1e6


func _build() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = WATER_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.25
	var plane := PlaneMesh.new()
	plane.size = DOCK_MAX - DOCK_MIN
	plane.material = material
	_water = MeshInstance3D.new()
	_water.mesh = plane
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.position = Vector3((DOCK_MIN.x + DOCK_MAX.x) * 0.5, FLOOR_Y, (DOCK_MIN.y + DOCK_MAX.y) * 0.5)
	add_child(_water)
	var sea_plane := PlaneMesh.new()
	sea_plane.size = SEA_SIZE
	sea_plane.material = material
	var sea := MeshInstance3D.new()
	sea.mesh = sea_plane
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position = Vector3(SEA_X + SEA_SIZE.x * 0.5, SEA_Y, 0.0)
	add_child(sea)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Palette.EMBER * Mood.GLOW_EMISSION
	glow.disable_fog = true
	var bulb_mesh := BoxMesh.new()
	bulb_mesh.size = Vector3(0.3, 0.3, 0.3)
	bulb_mesh.material = glow
	for pos in BEACONS:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.12, pos.y, 0.12)
		post.mesh = post_mesh
		post.material_override = Mood._flat(Palette.GREY_1)
		post.position = Vector3(pos.x, pos.y * 0.5, pos.z)
		add_child(post)
		var bulb := MeshInstance3D.new()
		bulb.mesh = bulb_mesh
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bulb.position = pos + Vector3.UP * 0.15
		bulb.visible = false
		add_child(bulb)
		_beacon_bulbs.append(bulb)
		var light := OmniLight3D.new()
		light.light_color = Mood.LAMP_COLOR
		light.light_energy = 3.0
		light.omni_range = 11.0
		light.light_specular = 0.0
		light.position = pos
		light.visible = false
		add_child(light)
		_beacons.append(light)
