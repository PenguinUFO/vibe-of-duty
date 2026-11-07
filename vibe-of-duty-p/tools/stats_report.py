"""Balance report from the host's match statistics (MatchStats, Docs/STATS.md): Markdown tables to stdout.

    python tools/stats_report.py [files or folders...] [--all] [--min=N]

Without paths: every file in the game's user://stats on this computer. Only sessions with the weapons.cfg of the
newest session are counted (numbers from another balance mislead); --all counts every session. --min=N: variants and
builds with fewer lives are left out of their tables (default 3).
"""
import glob
import json
import os
import statistics
import sys
from collections import defaultdict

DEFAULT_DIR = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "vibe-of-duty-p", "stats")
BANDS = [(0, 10), (10, 25), (25, 50), (50, 1e9)]


def load(paths):
    files = []
    for p in paths or [DEFAULT_DIR]:
        files += sorted(glob.glob(os.path.join(p, "*.jsonl"))) if os.path.isdir(p) else [p]
    sessions = []
    for f in files:
        with open(f, encoding="utf-8") as fh:
            events = [json.loads(line) for line in fh if line.strip()]
        if events and events[0].get("e") == "session":
            sessions.append((f, events))
    return sessions


def med(values):
    return statistics.median(values) if values else None


def fmt(v, digits=2):
    return "—" if v is None else (f"{v:.{digits}f}" if isinstance(v, float) else str(v))


def table(head, rows):
    out = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    out += ["| " + " | ".join(fmt(c) for c in r) + " |" for r in rows]
    return "\n".join(out)


def weapon_of(variant):
    return variant.split("+")[0]


NATIVE_BODY = {"hoof", "head", "chest", "belly", "legs"}  # PartDB: a body slot without an augmentation
OINK_AFTER_KILL = 3.0  # s: an oink this soon after the player's own kill counts as one over the body
ENGINEER = "engineer"  # PartDB.ENGINEER: the kit's modules can be changed


def augments(build):
    """The augmentations of a build (an Array of part ids, weapon first): module and kit ids have dots."""
    return tuple(i for i in build[1:] if i and "." not in i and i != build[0] and i not in NATIVE_BODY)


def aug_name(aug):
    return "+".join(aug) or "без аугментаций"


def tag_builds(events):
    """Which augmentations every life, killer, victim and shooter had: the player's last "spawn" line."""
    now = {}
    for e in events:
        if e["e"] == "spawn":
            now[e["p"]] = augments(e.get("build") or [""])
        elif e["e"] == "life":
            e["aug"] = now.get(e["p"], ())
        elif e["e"] == "punch":
            e["aug"] = now.get(e["p"], ())
        elif e["e"] == "kill":
            e["k_aug"], e["v_aug"] = now.get(e["k"], ()), now.get(e["v"], ())
        elif e["e"] == "hit":
            e["a_aug"] = now.get(e["a"], ())


def fight_table(title, names, lives, kills, landed, min_lives=0, by_name=False):
    """One row per name; `names` (variant, augmentations) -> the rows a fighter counts in (none, or several)."""
    agg = defaultdict(lambda: {"lives": 0, "kills": 0, "deaths": 0, "duel_w": 0, "duel_l": 0, "ttk": [],
                               "ttk_fire": [], "hits": [], "dist": [], "shots": 0, "hit": 0, "dmg_out": 0,
                               "dur": 0.0})
    for life in lives:
        for name in names(life["w"], life["aug"]):
            a = agg[name]
            a["lives"] += 1
            a["shots"] += life["shots"]
            a["dmg_out"] += life["dmg_out"]
            a["dur"] += life["dur"]
    for variant, aug in landed:
        for name in names(variant, aug):
            agg[name]["hit"] += 1
    for k in kills:
        duel = k["v_dmg_to_k"] > 0 and k["dmg_others"] == 0  # both hit, nobody else
        for name in names(k["kw"], k["k_aug"]):
            a = agg[name]
            a["kills"] += 1
            if k["gun"] != "melee":
                a["ttk"].append(k["ttk"])
                a["ttk_fire"].append(k["ttk_fire"])
                a["hits"].append(k["hits"])
            a["dist"].append(k["dist"])
            a["duel_w"] += 1 if duel else 0
        for name in names(k["vw"], k["v_aug"]):
            agg[name]["deaths"] += 1
            agg[name]["duel_l"] += 1 if duel else 0
    rows = []
    for name, a in agg.items():
        if a["lives"] < min_lives:
            continue
        duels = a["duel_w"] + a["duel_l"]
        rows.append([name, a["lives"], a["kills"], a["deaths"], a["kills"] / max(a["deaths"], 1),
                     f"{a['duel_w']}/{duels}" + (f" ({100 * a['duel_w'] / duels:.0f}%)" if duels else ""),
                     med(a["ttk"]), med(a["ttk_fire"]), med(a["hits"]),
                     100.0 * a["hit"] / a["shots"] if a["shots"] else None,
                     a["dmg_out"] / a["dur"] if a["dur"] else None, med(a["dist"])])
    if not rows:
        return
    rows.sort(key=(lambda r: r[0]) if by_name else (lambda r: -r[4]))
    print(f"## {title}\n")
    print(table(["", "жизней", "убийств", "смертей", "К/Д", "дуэли", "TTK, с", "TTK от огня, с", "попаданий",
                 "точность, %", "урон/с жизни", "дистанция, м"], rows) + "\n")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    use_all = "--all" in sys.argv
    min_lives = next((int(a[6:]) for a in sys.argv if a.startswith("--min=")), 3)
    sessions = load(args)
    if not sessions:
        print("No stats files found")
        return
    md5 = sessions[-1][1][0].get("weapons_md5")
    if not use_all:
        sessions = [s for s in sessions if s[1][0].get("weapons_md5") == md5]
    kills, lives, landed = [], [], []
    for f, events in sessions:
        tag_builds(events)
        kills += [e for e in events if e["e"] == "kill" and e["gun"] != "self" and e["k"] != e["v"]]  # own grenade: k = v
        lives += [e for e in events if e["e"] == "life"]
        # Shots that landed: one "hit" per shot and victim, all with the same time, so a (shooter, time) pair is one
        # shot. Older files count every pellet in life["hits"] (shotgun accuracy over 100%), so accuracy uses these.
        landed += list({(f, e["m"], e["a"], e["t"]): (e["aw"], e["a_aug"]) for e in events
                        if e["e"] == "hit" and e["gun"] not in ("melee", "self", "grenade", "bomb")}.values())
    print(f"# Статистика боёв\n\nСессий: {len(sessions)}, жизней: {len(lives)}, убийств: {len(kills)}"
          + ("" if use_all else f" (weapons.cfg {md5[:8]})") + "\n")

    fight_table("Оружие", lambda w, aug: [weapon_of(w)], lives, kills, landed)
    fight_table("Оружие и модули", lambda w, aug: [w], lives, kills, landed, min_lives)
    fight_table("Сборки (комплектация, модули и аугментации)", lambda w, aug: [f"{w} · {aug_name(aug)}"], lives, kills,
                landed, min_lives)
    fight_table("Аугментации (жизнь с двумя считается в обеих строках)",
                lambda w, aug: list(aug) or [aug_name(aug)], lives, kills, landed)
    engineered = {weapon_of(life["w"]) for life in lives if ENGINEER in life["aug"]}
    fight_table("Комплектации со Свинжинером (рядом — те же без него)",
                lambda w, aug: [w if ENGINEER in aug else f"{w} (без Свинжинера)"] if weapon_of(w) in engineered else [],
                lives, kills, landed, min_lives, by_name=True)

    weapons = sorted({weapon_of(k["kw"]) for k in kills} | {weapon_of(k["vw"]) for k in kills})
    m = defaultdict(int)
    for k in kills:
        m[(weapon_of(k["kw"]), weapon_of(k["vw"]))] += 1
    print("## Кто кого (строка убила столбец; в скобках — доля строки в их встречах)\n")
    rows = []
    for a in weapons:
        row = [a]
        for b in weapons:
            n, back = m[(a, b)], m[(b, a)]
            row.append("—" if a == b else f"{n}" + (f" ({100 * n / (n + back):.0f}%)" if n + back else ""))
        rows.append(row)
    print(table([""] + weapons, rows) + "\n")

    print("## TTK по дистанции (медиана, с; в скобках — убийств)\n")
    rows = []
    for w in weapons:
        row = [w]
        for lo, hi in BANDS:
            v = [k["ttk"] for k in kills if weapon_of(k["kw"]) == w and lo <= k["dist"] < hi and k["gun"] != "melee"]
            row.append(f"{med(v):.2f} ({len(v)})" if v else "—")
        rows.append(row)
    print(table([""] + [f"{lo}–{hi:g} м" if hi < 1e9 else f"{lo}+ м" for lo, hi in BANDS], rows))
    deaths(kills, lives)
    movement(sessions, kills)
    augment_use(sessions)
    akimbo(sessions)
    oinks(sessions)
    pace(sessions)
    builds(sessions)
    leaves(sessions)
    network(sessions)
    spawn_points(sessions)


FAR_REWIND = 200  # ms: a kill judged this far back (local net: median ~100 ms, interpolation included)
SEEN_ANGLE = 60  # deg off the view: past it the shooter was off the victim's screen (vertical FOV 90 at 16:9)


def pct(n, total):
    return f"{100 * n / total:.0f}%" if total else "—"


def deaths(kills, lives):
    """How players die and how lives end, by weapon (files from 2026-11-02 on: kill.v_angle, life.healed)."""
    by = defaultdict(list)
    for k in kills:
        if "v_angle" in k:
            by[weapon_of(k["vw"])].append(k)
    if by:
        print("\n## Смерти (по оружию жертвы)\n")
        print(f"Засада — жертва не ответила, убийца был дальше {SEEN_ANGLE}° от её взгляда при первом попадании. "
              "Ответ — секунды от первого попадания жертвы по убийце до её смерти.\n")
        rows = []
        for w, ks in sorted(by.items()):
            n = len(ks)
            rows.append([w, n, pct(sum(1 for k in ks if k["v_angle"] <= SEEN_ANGLE), n),
                         pct(sum(1 for k in ks if k["v_reply"] is None and k["v_angle"] > SEEN_ANGLE), n),
                         pct(sum(1 for k in ks if k["v_reply"] is not None), n),
                         pct(sum(1 for k in ks if k["v_hit_first"]), n),
                         med([k["v_reply"] for k in ks if k["v_reply"] is not None]),
                         pct(sum(1 for k in ks if k["v_healed"] > 0), n),
                         pct(sum(1 for k in ks if k["v_mag"] == 0), n)])
        print(table(["", "смертей", "видел убийцу", "засада", "ответил", "попал первым и умер", "ответ, с",
                     "лечился в стычке", "пустой магазин"], rows))
    by = defaultdict(list)
    for life in lives:
        if "healed" in life:
            by[weapon_of(life["w"])].append(life)
    if by:
        print("\n## Патроны и лечение (по жизням)\n")
        rows = []
        for w, ls in sorted(by.items()):
            n, dead = len(ls), [life for life in ls if life["end"] == "death"]
            rows.append([w, n, sum(life["bags"] for life in ls) / n, pct(sum(1 for life in ls if life["dry"]), n),
                         pct(sum(1 for life in dead if life["mag"] + life["reserve"] == 0), len(dead)),
                         med([life["reserve"] for life in dead]), med([life["healed"] for life in ls]),
                         sum(life["healed"] for life in ls) / max(sum(life["dur"] for life in ls), 1e-9)])
        print(table(["", "жизней", "сумок за жизнь", "щёлкал пустым", "умер без патронов", "запас при смерти",
                     "вылечено за жизнь", "лечение HP/с"], rows))


WAYS = {"ground": "на земле", "air": "в воздухе", "slide": "в подкате", "vault": "перелезает"}
FAST_LEGS = ("bunny", "jet_hooves")  # the legs' augmentations: their own rows in "Успешность движения"


def way_of(state):
    return "vault" if state["vault"] else "slide" if state["slide"] else "air" if state["air"] else "ground"


def legs_of(aug):
    return next((leg for leg in FAST_LEGS if leg in aug), None)


def movement(sessions, kills):
    """What players do with their legs and how it pays (files from 2026-11-05 on: life.jumps, life.moves)."""
    lives = [e for f, events in sessions for e in events if e["e"] == "life" and "moves" in e and "jumps" in e]
    if not lives:
        return
    print("\n## Движение (в минуту жизни; быстрее спринта — без подката)\n")
    by = defaultdict(list)
    for life in lives:
        for name in list(life["aug"]) or [aug_name(life["aug"])]:
            by[name].append(life)
    rows = []
    for name, ls in sorted(by.items()):
        minutes = max(sum(life["dur"] for life in ls) / 60, 1e-9)
        secs = minutes * 60
        spent = lambda way: sum(life["moves"].get(way, {}).get("t", 0) for life in ls)
        rows.append([name, len(ls)] + [sum(life[key] for life in ls) / minutes
                                       for key in ("jumps", "air_jumps", "slides", "vaults")]
                    + [pct(spent("air"), secs), pct(spent("slide"), secs), med([life["top_speed"] for life in ls]),
                       pct(sum(life["fast"] for life in ls), secs)])
    print(table(["", "жизней", "прыжков", "прыжков в воздухе", "подкатов", "перелезаний", "в воздухе", "в подкате",
                 "макс. скорость, м/с", "быстрее спринта"], rows))
    print("\n## Успешность движения (только пули; уклонение — доля пуль рядом, прошедших мимо)\n")
    agg = defaultdict(lambda: defaultdict(float))
    for life in lives:
        for way, n in life["moves"].items():
            for name in (WAYS[way], f"{WAYS[way]} · {legs_of(life['aug'])}") if legs_of(life["aug"]) else (WAYS[way],):
                for key, value in n.items():
                    agg[name][key] += value
    for k in kills:
        if "vault" in k["k_state"]:  # older files have no time per way of moving
            for aug, state, field in ((k["k_aug"], k["k_state"], "kills"), (k["v_aug"], k["v_state"], "deaths")):
                way = WAYS[way_of(state)]
                for name in (way, f"{way} · {legs_of(aug)}") if legs_of(aug) else (way,):
                    agg[name][field] += 1
    rows = []
    for name, a in sorted(agg.items()):
        if a["t"] <= 0:
            continue
        near = a["near_in"] + a["hits_in"]
        rows.append([name, a["t"] / 60, pct(a["hits"], a["shots"]), a["dmg_out"] / a["t"], a["dmg_in"] / a["t"],
                     pct(a["near_in"], near), int(a["kills"]), int(a["deaths"]), a["kills"] / max(a["deaths"], 1)])
    print(table(["", "минут", "точность", "урон/с", "получено/с", "уклонение", "убийств", "смертей", "К/Д"], rows))


def life_records(events):
    """Every life of a file with what its augmentations did: a grenade can land after its thrower's death, so hits go
    to the thrower's life up to their next spawn."""
    now, records = {}, []
    blank = lambda: {"hits": defaultdict(int), "dmg": defaultdict(int), "kills": defaultdict(int), "self_dmg": 0,
                     "self_kills": 0, "bomb_out": 0, "life": None, "aug": ()}
    for e in events:
        kind = e["e"]
        if kind == "spawn":
            now[e["p"]] = blank()
            now[e["p"]]["aug"] = augments(e.get("build") or [""])
            records.append(now[e["p"]])
        elif kind == "life" and e["p"] in now:
            now[e["p"]]["life"] = e
        elif kind == "hit" and e["a"] in now:
            now[e["a"]]["hits"][e["gun"]] += 1
            now[e["a"]]["dmg"][e["gun"]] += e["dmg"]
        elif kind == "kill" and e["k"] in now and e.get("cause") != "bomb_credit":
            r = now[e["k"]]
            if e["k"] != e["v"]:
                r["kills"][e["gun"]] += 1
            elif e.get("cause") == "grenade":
                r["self_kills"] += 1
        elif kind == "self_hit" and e["p"] in now:
            now[e["p"]]["self_dmg"] += e["dmg"]
        elif kind == "aug" and e["use"] == "bomb_out" and e["p"] in now:
            now[e["p"]]["bomb_out"] += 1
    return [r for r in records if r["life"] is not None and "grenades" in r["life"]]


def augment_use(sessions):
    """How often each augmentation's own action is used and what it gets (files from 2026-11-05 on)."""
    records = [r for f, events in sessions for r in life_records(events)]
    if not records:
        return
    print("\n## Аугментации в деле (раз — действие; успех — по цели; у бомбы и гранаты урон и убийства — ими самими)\n")
    rows = []

    def row(name, part, uses, wins, gun, trouble=None):
        ls = [r for r in records if part is None or part in r["aug"]]
        if not ls:
            return
        n = sum(uses(r) for r in ls)
        rows.append([name, len(ls), pct(sum(1 for r in ls if uses(r)), len(ls)), n,
                     pct(sum(wins(r) for r in ls), n) if wins else "—",
                     sum(r["dmg"][gun] for r in ls) / n if gun and n else None,
                     sum(r["kills"][gun] for r in ls) if gun else "—",
                     trouble(ls) if trouble else "—"])

    def own_harm(ls):
        return f"себе {sum(r['self_dmg'] for r in ls)} HP, смертей {sum(r['self_kills'] for r in ls)}"

    row("grenadier", "grenadier", lambda r: r["life"]["grenades"], lambda r: 1 if r["hits"]["grenade"] else 0, "grenade",
        own_harm)
    row("bomb", "bomb", lambda r: r["life"]["bombs"], lambda r: 1 if r["hits"]["bomb"] else 0, "bomb",
        lambda ls: f"убит до взрыва {sum(r['bomb_out'] for r in ls)}")
    row("skull_pistol", "skull_pistol", lambda r: r["life"]["cmp_shots"], lambda r: r["life"]["cmp_hits"], "cmp")
    if any("punches" in r["life"] for r in records):
        row("pig_arms", "pig_arms", lambda r: r["life"]["punches"], lambda r: r["life"]["punch_hits"], "melee")
        plain = [r for r in records if "pig_arms" not in r["aug"]]
        n = sum(r["life"]["punches"] for r in plain)
        rows.append(["копыто без Рук-Хрюков", len(plain), pct(sum(1 for r in plain if r["life"]["punches"]), len(plain)),
                     n, pct(sum(r["life"]["punch_hits"] for r in plain), n),
                     sum(r["dmg"]["melee"] for r in plain) / n if n else None,
                     sum(r["kills"]["melee"] for r in plain), "—"])
    if any("jumps" in r["life"] for r in records):
        row("jet_hooves", "jet_hooves", lambda r: r["life"].get("air_jumps", 0), None, None)
        row("bunny", "bunny", lambda r: 1 if r["life"]["fast"] > 0 else 0, None, None)
    row("engineer", "engineer", lambda r: 1 if "+" in r["life"]["w"] else 0, None, None)
    print(table(["", "жизней с ней", "пользовались", "раз", "успех", "урон за раз", "убийств", "минусы"], rows))
    print("\nbunny: раз — жизни быстрее спринта. engineer: раз — жизни с изменёнными модулями. "
          "Сравнение К/Д — в таблице «Аугментации», уклонение и урон на ходу — в «Успешности движения».")


def akimbo(sessions):
    """When the akimbo's left gun goes (files from 2026-11-05 on): per variant, emptied or thrown away by R, or never."""
    agg = defaultdict(lambda: {"empty": 0, "reload": 0, "died": 0, "t": [], "thrown": [], "mag": [], "fight": 0})
    for f, events in sessions:
        for e in events:
            if e["e"] == "akimbo_drop":
                a = agg[e["w"]]
                a["reload" if e["rounds"] else "empty"] += 1
                a["t"] += [] if e["life_t"] is None else [e["life_t"]]
                a["thrown"] += [e["rounds"]] if e["rounds"] else []
                a["mag"].append(e["mag"])
                a["fight"] += 1 if e["fight"] else 0
            elif e["e"] == "life" and e["end"] == "death" and e.get("left_mag"):
                agg[e["w"]]["died"] += 1
    if not agg:
        return
    rows = []
    for name, a in sorted(agg.items(), key=lambda x: -(x[1]["empty"] + x[1]["reload"] + x[1]["died"])):
        n = a["empty"] + a["reload"]
        rows.append([name, a["empty"], a["reload"], a["died"], med(a["t"]), med(a["thrown"]), med(a["mag"]),
                     pct(a["fight"], n)])
    print("\n## Акимбо: когда уходит левое\n")
    print(table(["", "кончилось", "выброшено R", "умер с левым", "с начала жизни, с", "патронов выброшено R",
                 "в правом при выбросе", "в бою"], rows))


def oinks(sessions):
    """Who oinks (F) and when (files from 2026-11-05 on): per player, and all of them."""
    agg = defaultdict(lambda: {"oinks": 0, "farts": 0, "dur": 0.0, "near": [], "alone": 0, "after_kill": 0})
    for f, events in sessions:
        last_kill = {}
        for e in events:
            if e["e"] == "kill" and e["k"] != e["v"]:
                last_kill[e["k"]] = e["t"]
            elif e["e"] == "life":
                for a in (agg[e["p"]], agg["все"]):
                    a["dur"] += e["dur"]
            elif e["e"] == "oink":
                for a in (agg[e["p"]], agg["все"]):
                    a["farts" if e["fart"] else "oinks"] += 1
                    a["alone"] += 1 if e["near"] is None else 0
                    a["near"] += [] if e["near"] is None else [e["near"]]
                    a["after_kill"] += 1 if e["t"] - last_kill.get(e["p"], -1000) <= OINK_AFTER_KILL else 0
    if not agg["все"]["oinks"] + agg["все"]["farts"]:
        return
    rows = []
    for name, a in sorted(agg.items(), key=lambda x: -(x[1]["oinks"] + x[1]["farts"])):
        n = a["oinks"] + a["farts"]
        rows.append([name, a["oinks"], a["farts"], n * 60 / a["dur"] if a["dur"] else None, med(a["near"]), a["alone"],
                     pct(a["after_kill"], n)])
    print("\n## Хрюки (F)\n")
    print(table(["", "хрюков", "пуков", "в минуту жизни", "до ближнего, м", "никого в живых", "сразу после убийства"], rows))


def pace(sessions):
    """Per map: how soon a life gets into a fight, how much of it is calm, what the map itself kills with (files
    from 2026-11-02 on: life.calm, kill.cause)."""
    maps = defaultdict(lambda: {"lives": 0, "contact": [], "none": 0, "calm": 0.0, "dur": 0.0, "causes": defaultdict(int)})
    for f, events in sessions:
        m = maps[events[0]["map"]]
        for e in events:
            if e["e"] == "life" and "calm" in e:
                m["lives"] += 1
                m["calm"] += e["calm"]
                m["dur"] += e["dur"]
                if e["contact"] is None:
                    m["none"] += 1
                else:
                    m["contact"].append(e["contact"])
            elif e["e"] == "kill" and e.get("cause") not in (None, "grenade", "bomb", "bomb_credit"):
                m["causes"][e["cause"]] += 1
    maps = {k: m for k, m in maps.items() if m["lives"]}
    if not maps:
        return
    print("\n## Темп (по картам; бой — попадание, своё или по себе; спокойно — дальше 5 с от попаданий и спавна)\n")
    rows = [[name, m["lives"], med(m["contact"]), pct(m["none"], m["lives"]), pct(m["calm"], m["dur"]),
             ", ".join(f"{c} {n}" for c, n in sorted(m["causes"].items())) or "—"] for name, m in sorted(maps.items())]
    print(table(["карта", "жизней", "до первого боя, с", "жизней без боя", "спокойного времени", "убила карта"], rows))


def builds(sessions):
    """Build changes (files from 2026-11-02 on: "build"; augmentations from 2026-11-05 on: its "build", "was_build"):
    what players leave for what, and how long after death."""
    moves, aug_moves, dead_for, alive = defaultdict(int), defaultdict(int), [], 0
    for f, events in sessions:
        for e in events:
            if e["e"] == "build" and weapon_of(e["was"]) != weapon_of(e["w"]):
                moves[(weapon_of(e["was"]), weapon_of(e["w"]))] += 1
            if e["e"] == "build":
                if "was_build" in e and augments(e["was_build"]) != augments(e["build"]):
                    aug_moves[(aug_name(augments(e["was_build"])), aug_name(augments(e["build"])))] += 1
                if e["dead_for"] is None:
                    alive += 1
                else:
                    dead_for.append(e["dead_for"])
    if not dead_for and not alive:
        return
    print(f"\n## Смена сборки\n\nСмен после смерти: {len(dead_for)} (медиана через {fmt(med(dead_for))} с после смерти), "
          f"живым: {alive}.\n")
    if moves:
        rows = [[a, b, n] for (a, b), n in sorted(moves.items(), key=lambda x: -x[1])]
        print(table(["с оружия", "на оружие", "раз"], rows))
    if aug_moves:
        rows = [[a, b, n] for (a, b), n in sorted(aug_moves.items(), key=lambda x: -x[1])]
        print("\n" + table(["с аугментаций", "на аугментации", "раз"], rows))


def leaves(sessions):
    """Who left mid-match and how they were doing (files from 2026-11-02 on: "leave")."""
    rows = []
    for f, events in sessions:
        for e in events:
            if e["e"] == "leave":
                rows.append([e["p"], events[0]["map"], f"{e['place']}/{e['players']}", f"{e['kills']}/{e['deaths']}",
                             f"{e['time_left']:.0f}" if e["playing"] else "между матчами"])
    if rows:
        print("\n## Выходы\n")
        print(table(["игрок", "карта", "место", "убийств/смертей", "до конца матча, с"], rows))


def network(sessions):
    """Per player: ping (ENet round trip) and how far back the server judged their shots (lag compensation)."""
    by = defaultdict(lambda: {"ping": [], "rewind": [], "kills": 0, "far": 0})
    for f, events in sessions:
        for e in events:
            if e["e"] == "hit" and "rewind" in e:
                p = by[e["a"]]
                if e["ping"] is not None:
                    p["ping"].append(e["ping"])
                p["rewind"].append(e["rewind"])
            elif e["e"] == "kill" and "rewind" in e:
                by[e["k"]]["kills"] += 1
                by[e["k"]]["far"] += 1 if e["rewind"] > FAR_REWIND else 0
    if not by:
        return
    print("\n## Сеть (по стрелкам; откат — насколько назад сервер проверял попадание)\n")
    rows = [[name, med(p["ping"]), med(p["rewind"]), max(p["rewind"]), p["kills"], p["far"]]
            for name, p in sorted(by.items())]
    print(table(["", "пинг, мс", "откат, мс", "макс. откат, мс", "убийств", f"с откатом > {FAR_REWIND} мс"], rows))


def spawn_points(sessions):
    """Per map and spawn point (files from 2026-10-31 on: spawn.pt): how soon the spawned get into a fight."""
    points = defaultdict(lambda: {"n": 0, "seen": 0, "near": [], "contact": [], "fast": 0, "dead": 0})
    for f, events in sessions:
        level = events[0]["map"]
        for i, s in enumerate(events):
            if s["e"] != "spawn" or "pt" not in s or s["pt"] < 0:
                continue
            p = points[(level, s["pt"])]
            p["n"] += 1
            p["seen"] += 1 if s["seen"] else 0
            if s["near"] is not None:
                p["near"].append(s["near"])
            for e in events[i + 1:]:  # this life: up to the player's next spawn or death
                if e["e"] == "spawn" and e["p"] == s["p"] or e.get("m") != s["m"]:
                    break
                if e["e"] == "hit" and s["p"] in (e["a"], e["v"]):
                    p["contact"].append(e["t"] - s["t"])
                    p["fast"] += 1 if e["t"] - s["t"] < 5 else 0
                    break
            for e in events[i + 1:]:
                if e["e"] == "spawn" and e["p"] == s["p"] or e.get("m") != s["m"]:
                    break
                if e["e"] == "kill" and e["v"] == s["p"]:
                    p["dead"] += 1 if e["t"] - s["t"] < 10 else 0
                    break
    if not points:
        return
    print("\n## Точки спавна (номер — порядок в SpawnPoints; бой — первое попадание, своё или по себе)\n")
    rows = [[f"{level} {pt}", p["n"], p["seen"], med(p["near"]), med(p["contact"]), p["fast"], p["dead"]]
            for (level, pt), p in sorted(points.items())]
    print(table(["точка", "спавнов", "на виду", "до ближнего, м", "до боя, с", "бой < 5 с", "смерть < 10 с"], rows))


if __name__ == "__main__":
    main()
