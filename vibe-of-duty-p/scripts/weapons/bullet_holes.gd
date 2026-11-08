class_name BulletHoles
extends RefCounted
## Bullet holes left on the level by hitscan shots: a fixed pool of Decal nodes reused round-robin (the oldest hole
## goes first). A hole is parented to the collider it hit, so it rides along with moving level pieces (the crane,
## cargo) and goes away with them. Cosmetic; nothing without a screen.

const POOL := 128
const SIZE := 0.085         # m across
const DEPTH := 0.06         # m the decal box reaches into and out of the surface
const PIXELS := 12          # texture side: chunky pixels, as the rest of the PSX look
const VARIANTS := 4
const PROBE := 0.06         # m around a remote shot's end searched for the surface it hit
const VIEWMODEL_LAYER := 1 << 1

static var _decals: Array[Decal] = []
static var _next := 0
static var _textures: Array[ImageTexture] = []


## A hole at `pos` (world) on a surface facing `normal`; `collider` (may be null) - what the ray hit.
static func spawn(context: Node, pos: Vector3, normal: Vector3, collider: Object) -> void:
	if DisplayServer.get_name() == "headless" or context == null or not context.is_inside_tree():
		return
	var scene := context.get_tree().current_scene
	if scene == null or normal.length_squared() < 0.5:
		return
	var parent: Node = scene
	if collider is Node3D and (collider as Node3D).is_inside_tree():
		parent = collider as Node3D
	var decal := _take()
	if decal.get_parent() != parent:
		if decal.get_parent() != null:
			decal.get_parent().remove_child(decal)
		parent.add_child(decal)
	decal.texture_albedo = _textures[randi() % _textures.size()]
	var s := SIZE * randf_range(0.8, 1.15)
	decal.size = Vector3(s, DEPTH, s)
	var y := normal.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized().rotated(y, randf() * TAU)
	decal.global_transform = Transform3D(Basis(x, y, x.cross(y)), pos)
	decal.visible = true


## A hole where a shot seen only by its end (somebody else's, a replay) met the level: the surface is found by a
## short ray around `end` along the shot. Nothing if the shot ended in the air or on a player.
static func spawn_at_end(context: Node, origin: Vector3, end: Vector3) -> void:
	if DisplayServer.get_name() == "headless" or context == null or not context.is_inside_tree():
		return
	var dir := end - origin
	if dir.length_squared() < 0.01:
		return
	dir = dir.normalized()
	var space := (context as Node3D).get_world_3d().direct_space_state if context is Node3D else null
	if space == null:
		return
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(end - dir * PROBE, end + dir * PROBE, Layers.WORLD))
	if not hit.is_empty():
		spawn(context, hit["position"], hit["normal"], hit["collider"])


static func _take() -> Decal:
	if _textures.is_empty():
		for i in VARIANTS:
			_textures.append(_make_texture(i))
	# Holes freed with their level (a map change) or with a destroyed collider drop out of the pool.
	for i in range(_decals.size() - 1, -1, -1):
		if not is_instance_valid(_decals[i]):
			_decals.remove_at(i)
	if _decals.size() < POOL:
		var decal := Decal.new()
		decal.cull_mask = 0xFFFFF & ~VIEWMODEL_LAYER  # not on the weapon in the hands
		decal.normal_fade = 0.4  # no smear along surfaces at a grazing angle to the hole
		decal.upper_fade = 0.2
		decal.lower_fade = 0.2
		_decals.append(decal)
		return decal
	_next = _next % _decals.size()
	var reused := _decals[_next]
	_next += 1
	return reused


## A ragged dark hole: black core, a dark scorched ring, a few pale chips of the surface knocked out around it.
static func _make_texture(variant: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (variant + 1)
	var image := Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var c := Vector2.ONE * ((PIXELS - 1) * 0.5) + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
	var core := rng.randf_range(1.3, 1.8)
	var ring := core + rng.randf_range(1.2, 1.8)
	var phase := rng.randf() * TAU
	var wobble := rng.randf_range(0.15, 0.35)
	var lobes := float(rng.randi_range(3, 5))
	for py in PIXELS:
		for px in PIXELS:
			var d := Vector2(px, py) - c
			var r := d.length() * (1.0 - wobble * 0.5 * sin(lobes * d.angle() + phase))  # ragged edge
			var color := Color(0, 0, 0, 0)
			if r < core:
				color = Color(0.02, 0.018, 0.016, 1.0)
			elif r < ring:
				color = Color(0.09, 0.08, 0.07, 0.85)
			elif r < ring + 2.5 and rng.randf() < 0.35 * (ring + 2.5 - r) / 2.5:
				color = Color(0.52, 0.48, 0.42, 0.55)  # chips: lighter than the dark levels, so the hole reads
			image.set_pixel(px, py, color)
	return ImageTexture.create_from_image(image)
