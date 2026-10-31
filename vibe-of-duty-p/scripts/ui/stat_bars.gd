class_name StatBars
extends VBoxContainer
## The build editor's weapon stats (BuildPanel, Docs/LOADOUT.md "Экран сборки"): no numbers, solid bars on one scale for
## every weapon - damage (body hits to kill up close), range (how far it keeps that), accuracy (aimed spread and kick),
## fire rate, handling (aiming, drawing, running with it) - and on one line the magazine as a number and the reload as a
## ring (full: the fastest). The scale's ends are constants with room to spare, so a new weapon moves no one's bars.
## Range goes by the square root (12..60 m, where most guns are, would be a sliver otherwise); accuracy counts the kick
## by how fast the next shot comes (a single shot's kick hardly matters).
## show_def(current, other): `other` (the module or weapon under the pointer) draws the difference - what it adds in
## GAIN, what it takes in LOSS.

const NAMES: Array[String] = ["Урон", "Дальность", "Точность", "Скорострельность", "Маневренность"]
const GAIN := UiTheme.GOOD
const LOSS := UiTheme.DANGER
const BAR_HEIGHT := 10.0
const RING_SIZE := 26.0

const KILL_WORST := 12      # body hits to kill: this many or more - an empty bar
const RANGE_BEST := 300.0   # m it keeps its close-up hits to kill at
const ERROR_WORST := 1.5    # deg: aimed spread + the kick of a shot x rate / RATE_BEST
const RATE_BEST := 1200.0   # rounds a minute
const RELOAD_BEST := 0.5    # s for a full magazine: a full ring...
const RELOAD_WORST := 5.0   # ...an empty one

var _bars: Array[Control] = []
var _values := PackedFloat32Array([0, 0, 0, 0, 0])
var _others := PackedFloat32Array([-1, -1, -1, -1, -1])  # -1: nothing under the pointer
var _mag := Label.new()
var _ring := Control.new()
var _reload := 0.0
var _reload_other := -1.0


func _init() -> void:
	add_theme_constant_override("separation", 6)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	for i in NAMES.size():
		var label := Label.new()
		label.text = NAMES[i]
		label.theme_type_variation = "Hint"
		grid.add_child(label)
		var bar := Control.new()
		bar.custom_minimum_size.y = BAR_HEIGHT
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.draw.connect(_draw_bar.bind(bar, i))
		grid.add_child(bar)
		_bars.append(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var mag_title := Label.new()
	mag_title.text = "Магазин"
	mag_title.theme_type_variation = "Hint"
	row.add_child(mag_title)
	row.add_child(_mag)
	var reload_title := Label.new()
	reload_title.text = "Перезарядка"
	reload_title.theme_type_variation = "Hint"
	row.add_child(reload_title)
	_ring.custom_minimum_size = Vector2(RING_SIZE, RING_SIZE)
	_ring.draw.connect(_draw_ring)
	row.add_child(_ring)


## `current`: the build's weapon; `other`: the same build with the part under the pointer (null: none).
func show_def(current: WeaponDef, other: WeaponDef = null) -> void:
	_values = scores(current)
	_reload = reload_score(current)
	_others = scores(other) if other != null else PackedFloat32Array([-1, -1, -1, -1, -1])
	_reload_other = reload_score(other) if other != null else -1.0
	_mag.text = str(current.mag_size)
	_mag.remove_theme_color_override("font_color")
	if other != null and other.mag_size != current.mag_size:
		_mag.text = "%d → %d" % [current.mag_size, other.mag_size]
		_mag.add_theme_color_override("font_color", GAIN if other.mag_size > current.mag_size else LOSS)
	for bar in _bars:
		bar.queue_redraw()
	_ring.queue_redraw()


## The five bars of a weapon, 0..1 each.
static func scores(def: WeaponDef) -> PackedFloat32Array:
	var hits := hits_to_kill(def, 0.0)
	var keeps := def.max_range  # how far the close-up hits to kill hold
	for i in mini(def.falloff_ranges.size(), def.falloff_mults.size()):
		if hits_to_kill(def, def.falloff_ranges[i] + 0.01) > hits:
			keeps = minf(def.falloff_ranges[i], def.max_range)
			break
	var rate := 60.0 / def.fire_interval
	if def.fire_ramp_time > 0.0 and def.fire_interval_ramped > 0.0:
		rate = 60.0 / def.fire_interval_ramped
	var error := rad_to_deg(def.spread_ads + def.recoil_pitch * minf(rate / RATE_BEST, 1.0))
	var handling := (_fall(def.ads_time, 0.1, 0.5) + _fall(def.equip_time, 0.2, 1.2)
			+ clampf((def.move_speed_mult - 0.75) / 0.3, 0.0, 1.0)) / 3.0
	return PackedFloat32Array([
		clampf(float(KILL_WORST - hits) / float(KILL_WORST - 1), 0.0, 1.0),
		sqrt(clampf(keeps / RANGE_BEST, 0.0, 1.0)),
		_fall(error, 0.0, ERROR_WORST),
		clampf(rate / RATE_BEST, 0.0, 1.0),
		handling,
	])


## Body hits to kill a player of the base health at `distance` m (every pellet in).
static func hits_to_kill(def: WeaponDef, distance: float) -> int:
	return ceili(PlayerBase.MAX_HEALTH / maxf(def.damage_at(distance) * def.pellets, 0.01))


## The reload ring, 0..1: the time to fill an empty magazine (a round at a time: each of them).
static func reload_score(def: WeaponDef) -> float:
	var time := def.reload_time * (def.mag_size if def.reload_single else 1)
	return _fall(time, RELOAD_BEST, RELOAD_WORST)


## 1 at `best` and below, 0 at `worst` and above.
static func _fall(value: float, best: float, worst: float) -> float:
	return clampf((worst - value) / (worst - best), 0.0, 1.0)


func _draw_bar(bar: Control, i: int) -> void:
	var width := bar.size.x
	var rect := Rect2(Vector2.ZERO, bar.size)
	bar.draw_rect(rect, UiTheme.FIELD)
	var value := _values[i]
	var other := _others[i]
	var solid := value if other < 0.0 else minf(value, other)
	bar.draw_rect(Rect2(0.0, 0.0, width * solid, bar.size.y), UiTheme.TEXT)
	if other >= 0.0 and not is_equal_approx(other, value):
		var from := minf(value, other)
		bar.draw_rect(Rect2(width * from, 0.0, width * absf(other - value), bar.size.y), GAIN if other > value else LOSS)


func _draw_ring() -> void:
	var centre := _ring.size * 0.5
	var radius := minf(_ring.size.x, _ring.size.y) * 0.5 - 3.0
	var start := -PI * 0.5
	_ring.draw_arc(centre, radius, 0.0, TAU, 48, UiTheme.FIELD, 5.0, true)
	var solid := _reload if _reload_other < 0.0 else minf(_reload, _reload_other)
	if solid > 0.0:
		_ring.draw_arc(centre, radius, start, start + TAU * solid, 48, UiTheme.TEXT, 5.0, true)
	if _reload_other >= 0.0 and not is_equal_approx(_reload_other, _reload):
		var from := start + TAU * minf(_reload, _reload_other)
		_ring.draw_arc(centre, radius, from, from + TAU * absf(_reload_other - _reload), 48,
				GAIN if _reload_other > _reload else LOSS, 5.0, true)
