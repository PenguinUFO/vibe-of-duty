extends Node
## Balance data from weapons.cfg, no bots: for every kit, hits to kill and the ideal time to kill at each distance, for
## the normal health (PlayerBase.MAX_HEALTH) and "Хардкор" (PlayerBase.HARDCORE_HEALTH); then the kits' handling numbers.
## Ideal: every shot (every pellet) hits, all in the body or all in the head, the trigger pulled at the gun's full rate
## from the first shot (a semi-automatic clicked as fast as it allows), an empty magazine reloaded on the way. The
## numbers come from the game's own code (WeaponDB.make_def of each kit's build) and the shots are timed tick by tick
## as WeaponSim fires them (a carried cooldown remainder, a ramping rate, the akimbo's left gun on its own cooldown).
## Writes Docs/balance/ttk_calc.md (and prints it):
##   Godot_v4.7.2.exe --headless --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=ttk_calc

const DISTANCES: Array[float] = [5.0, 10.0, 20.0, 30.0, 40.0, 60.0, 80.0]
const TICKS := 60.0           # physics ticks a second (WeaponSim counts in them)
const MAX_TICKS := 60 * 60    # give up on a kill after a minute of fire
const OUT := "../Docs/balance/ttk_calc.md"


func _ready() -> void:
	var rows := _rows()
	var lines: Array[String] = []
	lines.append("# TTK по конфигу (калькулятор)")
	lines.append("")
	lines.append("> Сгенерировано `tools/ttk_calc.gd` %s, `weapons.cfg` md5 `%s`. Не править руками — перезапустить:" % [
			Time.get_date_string_from_system(), WeaponDB.config_text.md5_text().left(8)])
	lines.append("> `Godot_v4.7.2.exe --headless --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=ttk_calc`")
	lines.append("")
	lines.append("**Допущения:** попадает каждый выстрел и каждая дробина; все в тело или все в голову; огонь с полным темпом с " +
			"первого выстрела (полуавтомат — кликает так быстро, как разрешает оружие); пустой магазин перезаряжается по " +
			"дороге. Время — от первого выстрела до убивающего: без реакции, прицеливания и промахов, это нижняя граница. " +
			"Комплектации как в редакторе, со штатными модулями. Акимбо — обе руки стреляют сразу, отдельной " +
			"строкой — одна правая.")
	lines.append("")
	for health: int in [PlayerBase.MAX_HEALTH, PlayerBase.HARDCORE_HEALTH]:
		var title := "Обычный режим" if health == PlayerBase.MAX_HEALTH else "Хардкор"
		lines.append("## %s — %d HP" % [title, health])
		lines.append("")
		lines.append("### Попаданий до смерти (тело / голова)")
		lines.append("")
		lines.append_array(_table(rows, health, false))
		lines.append("")
		lines.append("### Время убийства, с (тело / голова)")
		lines.append("")
		lines.append_array(_table(rows, health, true))
		lines.append("")
	lines.append("## Характеристики комплектаций")
	lines.append("")
	lines.append_array(_handling(rows))
	lines.append("")
	var text := "\n".join(lines)
	print(text)
	var path := ProjectSettings.globalize_path("res://").path_join(OUT).simplify_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ttk_calc: cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
	else:
		file.store_string(text)
		file.close()
		print("ttk_calc: %s" % path)
	get_tree().quit()


## [{name, def, akimbo}] - a row per kit, an akimbo kit also with the right gun alone.
func _rows() -> Array:
	var rows := []
	for kit: Dictionary in WeaponDB.kits():
		var build := PartDB.default_build(str(kit["id"]))
		var def := WeaponDB.make_def(WeaponDB.index_of(build[0]), PartDB.weapon_modules(build))
		rows.append({"name": str(kit["name"]), "def": def, "akimbo": def.akimbo})
		if def.akimbo:
			rows.append({"name": "%s (одна рука)" % kit["name"], "def": def, "akimbo": false})
	return rows


func _table(rows: Array, health: int, times: bool) -> Array[String]:
	var head := "| |"
	var line := "|---|"
	for d in DISTANCES:
		head += " %d м |" % d
		line += "---|"
	var out: Array[String] = [head, line]
	for row: Dictionary in rows:
		var s := "| %s |" % row["name"]
		for d in DISTANCES:
			var body := _kill(row["def"], row["akimbo"], health, d, false)
			var hd := _kill(row["def"], row["akimbo"], health, d, true)
			if times:
				s += " %s / %s |" % [_secs(body), _secs(hd)]
			else:
				s += " %s / %s |" % [_hits(body), _hits(hd)]
		out.append(s)
	return out


## {hits, ticks} of the fastest kill (hits -1: none within MAX_TICKS). Each shot's damage is rounded on its own, its
## pellets together (PlayerHealth.server_damage); a head hit is x head_mult (PlayerWeapons).
func _kill(def: WeaponDef, akimbo: bool, health: int, distance: float, head: bool) -> Dictionary:
	var shot := roundi(def.damage_at(distance) * def.pellets * (def.head_mult if head else 1.0))
	if shot <= 0:
		return {"hits": -1, "ticks": 0}
	var hp := health
	var hits := 0
	var mag := def.mag_size
	var left_mag := def.mag_size if akimbo else 0
	var cooldown := 0.0
	var left_cooldown := 0.0
	var burst := 0
	var left_burst := 0
	var reload := 0
	for tick in MAX_TICKS:
		if cooldown > 0.0:
			cooldown -= 1.0
		if left_cooldown > 0.0:
			left_cooldown -= 1.0
		if reload > 0:
			reload -= 1
			if reload == 0:
				mag = def.mag_size if not def.reload_single else mini(mag + 1, def.mag_size)
				if def.reload_single and mag < def.mag_size:
					reload = def.reload_ticks()  # a tube: the next round
		var fired := false
		burst = burst + 1 if reload == 0 else 0
		if reload == 0 and cooldown <= 0.0:
			if mag > 0:
				mag -= 1
				cooldown += def.fire_ticks(burst / TICKS)
				fired = true
				hits += 1
				hp -= shot
				if hp <= 0:
					return {"hits": hits, "ticks": tick}
			if mag == 0 and left_mag == 0:
				reload = def.reload_ticks()
		var left_fired := false
		if left_mag > 0:
			left_burst += 1
			if left_cooldown <= 0.0:
				left_mag -= 1
				left_cooldown += def.fire_ticks(left_burst / TICKS)
				left_fired = true
				hits += 1
				hp -= shot
				if hp <= 0:
					return {"hits": hits, "ticks": tick}
		if not fired:
			cooldown = maxf(cooldown, 0.0)
		if not left_fired:
			left_cooldown = maxf(left_cooldown, 0.0)
		if mag == 0 and left_mag == 0 and reload == 0:
			reload = def.reload_ticks()
	return {"hits": -1, "ticks": 0}


func _hits(k: Dictionary) -> String:
	return "—" if k["hits"] < 0 else str(k["hits"])


func _secs(k: Dictionary) -> String:
	return "—" if k["hits"] < 0 else "%.2f" % (k["ticks"] / TICKS)


func _handling(rows: Array) -> Array[String]:
	var out: Array[String] = [
		"| | урон | дробин | голова × | темп, выстр/мин | авто | магазин | перезарядка, с | прицеливание, с | смена, с | скорость | разброс бедро / прицел, ° | отдача вверх / вбок, ° | спад урона |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|",
	]
	for row: Dictionary in rows:
		if not row["akimbo"] and str(row["name"]).ends_with("(одна рука)"):
			continue
		var def: WeaponDef = row["def"]
		var rate := "%d" % roundi(60.0 / def.fire_interval)
		if def.fire_ramp_time > 0.0 and def.fire_interval_ramped > 0.0:
			rate += " → %d за %.1f с" % [roundi(60.0 / def.fire_interval_ramped), def.fire_ramp_time]
		var reload := "%.2f" % def.reload_time
		if def.reload_single:
			reload += " за патрон"
		var falloff: Array[String] = []
		for i in mini(def.falloff_ranges.size(), def.falloff_mults.size()):
			falloff.append("×%s после %d м" % [_num(def.falloff_mults[i]), roundi(def.falloff_ranges[i])])
		var mag := str(def.mag_size) + (" ×2 (акимбо)" if def.akimbo else "")
		out.append("| %s | %s | %d | %s | %s | %s | %s | %s | %s | %s | %s | %s / %s | %s / %s | %s |" % [
			row["name"], _num(def.damage), def.pellets, _num(def.head_mult), rate, "да" if def.automatic else "нет", mag,
			reload, _num(def.ads_time), _num(def.equip_time), _num(def.move_speed_mult),
			_num(rad_to_deg(def.spread_hip)), _num(rad_to_deg(def.spread_ads)),
			_num(rad_to_deg(def.recoil_pitch)), _num(rad_to_deg(def.recoil_yaw)),
			", ".join(falloff) if not falloff.is_empty() else "нет; дальность %d м" % roundi(def.max_range)])
	return out


func _num(v: float) -> String:
	return String.num(snappedf(v, 0.001))
