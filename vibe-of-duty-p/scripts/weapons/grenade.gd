class_name Grenade
extends Node3D
## One grenade of the "Гренадир" (Docs/LOADOUT.md): a cast-iron ball out of the chest cannon that flies an arc (the
## map's gravity, Gravity), bounces off the level and goes off on its fuse. Every machine flies the same launch
## (Grenades), so they agree up to moving level pieces; the server's blast decides where it went off. A replay copy
## (`cosmetic`, the kill cam) goes off by itself on its fuse and hurts nobody.

const RADIUS := 0.1          # m: it touches the level this far from its centre (the model, MODEL_SCALE)
const MODEL_SCALE := 2.0     # the model is built at half size; owner, 2026-11-05: bigger, to be seen
const REST_SPEED := 0.6      # m/s: slower than this on a floor, it lies still
const ROLL_DRAG := 4.0       # 1/s: rolling on a floor slows it down
const FLOOR_UP := 0.6        # a surface whose normal is this close to up is a floor
const BOUNCE_SOUND := 2.0    # m/s into a surface for a clank
const ORPHAN := 1.0          # s past the fuse a client copy the server never set off disappears (a lost launch)
const IRON := Color(0.13, 0.13, 0.14)
const LAMP := Color(1.0, 0.2, 0.02)   # Palette's signal: danger
const BLAST_LIFE := 0.35     # s: the fireball and its light
const BLAST_SIZE := 2.2      # m: the fireball's radius at its biggest

var owner_id := 0
var velocity := Vector3.ZERO
var age := 0.0
var fuse := 2.5
var bounced := false         # it has hit something (a player too): no more direct hits
var resting := false
var cosmetic := false
var bounce := 0.45
var friction := 0.7
## Server: (grenade, from, to) -> true if the flight from `from` to `to` hit a player (it bounces off them).
var on_flight: Callable

var _lamp: MeshInstance3D
var _spin_axis := Vector3.RIGHT


## Starts the flight; `show`: build the model (not on a dedicated server).
func launch(pos: Vector3, vel: Vector3, show: bool) -> void:
	top_level = true
	global_position = pos
	velocity = vel
	fuse = WeaponDB.grenade("fuse", 2.5)
	bounce = WeaponDB.grenade("bounce", 0.45)
	friction = WeaponDB.grenade("friction", 0.7)
	if vel.length_squared() > 1e-4:
		_spin_axis = vel.cross(Gravity.up(pos)).normalized() if absf(vel.normalized().dot(Gravity.up(pos))) < 0.99 \
				else Vector3.RIGHT
	if show:
		_build_model()


func _physics_process(delta: float) -> void:
	age += delta
	if not resting:
		_fly(delta)
	if _lamp != null:
		var left := fuse - age  # blinks faster as the fuse burns down
		_lamp.visible = fmod(age, clampf(left * 0.25, 0.06, 0.3)) < 0.05
	if cosmetic and age >= fuse:
		blast_fx(self, global_position)
		queue_free()
	elif not cosmetic and not multiplayer.is_server() and age >= fuse + ORPHAN:
		queue_free()


func _fly(delta: float) -> void:
	var up := Gravity.up(global_position)
	velocity -= up * Player.GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var speed := velocity.length()
	var reach := to + (velocity / speed * RADIUS if speed > 1e-4 else Vector3.ZERO)
	var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, reach, Layers.WORLD))
	if not bounced and on_flight.is_valid() and on_flight.call(self, from, to if hit.is_empty() else hit["position"]):
		return  # bounced off a player (on_flight turned it)
	if hit.is_empty():
		global_position = to
	else:
		var normal: Vector3 = hit["normal"]
		global_position = (hit["position"] as Vector3) + normal * RADIUS
		var into := velocity.dot(normal)
		if -into > BOUNCE_SOUND:
			Audio.play("grenade_bounce", global_position)
		velocity = (velocity - normal * into) * friction - normal * into * bounce
		bounced = true
		if velocity.length() < REST_SPEED and normal.dot(up) > FLOOR_UP:
			velocity = Vector3.ZERO
			resting = true
	var floor_hit := velocity.dot(up) < 0.5 and not get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(global_position, global_position - up * (RADIUS + 0.02), Layers.WORLD)).is_empty()
	if floor_hit:
		velocity -= Gravity.flat(velocity, global_position) * minf(ROLL_DRAG * delta, 1.0)
	if _lamp != null and speed > 0.1:
		rotate(_spin_axis, -speed * delta / RADIUS * 0.5)


## Turns it back off a player it hit at `pos` (server, and the clients told so: Grenades).
func knock_back(pos: Vector3, vel: Vector3) -> void:
	global_position = pos
	velocity = vel
	bounced = true


func _build_model() -> void:
	scale = Vector3.ONE * MODEL_SCALE
	var ball := SphereMesh.new()
	ball.radius = 0.045
	ball.height = 0.09
	ball.radial_segments = 10
	ball.rings = 5
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	iron.metallic = 0.7
	iron.roughness = 0.5
	var body := MeshInstance3D.new()
	body.mesh = ball
	body.material_override = iron
	add_child(body)
	var band := TorusMesh.new()  # a cast seam round the middle
	band.inner_radius = 0.043
	band.outer_radius = 0.05
	band.rings = 12
	band.ring_segments = 4
	var seam := MeshInstance3D.new()
	seam.mesh = band
	seam.material_override = iron
	add_child(seam)
	var dot := SphereMesh.new()
	dot.radius = 0.012
	dot.height = 0.024
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = LAMP
	_lamp = MeshInstance3D.new()
	_lamp.mesh = dot
	_lamp.material_override = glow
	_lamp.position = Vector3(0.0, 0.045, 0.0)
	_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lamp)


## The blast as everybody sees and hears it: a fireball with its light, smoke and a bang. Cosmetic.
static func blast_fx(context: Node, pos: Vector3) -> void:
	Audio.play("explosion", pos)
	if DisplayServer.get_name() == "headless" or context == null or not context.is_inside_tree():
		return
	var scene := context.get_tree().current_scene
	if scene == null:
		return
	var up := Gravity.up(pos)
	Dust.burst(context, pos, 3.0)
	for k in 6:
		Dust.puff(context, pos + up * 0.2, (up * randf_range(1.0, 3.0) + Vector3(randf_range(-1, 1), 0.0,
				randf_range(-1, 1)) * 2.0), randf_range(0.5, 0.8), randf_range(1.2, 1.8))
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = pos + up * 0.2
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire.albedo_color = Color(1.0, 0.72, 0.42)  # Palette's ember, lit up
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	sphere.material = fire
	var ball := MeshInstance3D.new()
	ball.mesh = sphere
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.scale = Vector3.ONE * 0.2
	root.add_child(ball)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.35)
	light.omni_range = 9.0
	light.light_energy = 6.0
	light.shadow_enabled = false
	root.add_child(light)
	var tween := root.create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * BLAST_SIZE, BLAST_LIFE * 0.4).set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fire, "albedo_color", Color(0.9, 0.35, 0.12, 0.0), BLAST_LIFE)
	tween.tween_property(light, "light_energy", 0.0, BLAST_LIFE)
	tween.chain().tween_callback(root.queue_free)
