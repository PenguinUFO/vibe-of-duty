"""Balance report from the host's match statistics (MatchStats, Docs/STATS.md): Markdown tables to stdout.

    python tools/stats_report.py [files or folders...] [--all] [--min=N]

Without paths: every file in the game's user://stats on this computer. Only sessions with the weapons.cfg of the
newest session are counted (numbers from another balance mislead); --all counts every session. --min=N: variants with
fewer lives are left out of the variant table (default 3).
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
        kills += [e for e in events if e["e"] == "kill" and e["gun"] != "self" and e["k"] != e["v"]]  # own grenade: k = v
        lives += [e for e in events if e["e"] == "life"]
        # Shots that landed: one "hit" per shot and victim, all with the same time, so a (shooter, time) pair is one
        # shot. Older files count every pellet in life["hits"] (shotgun accuracy over 100%), so accuracy uses these.
        landed += list({(f, e["m"], e["a"], e["t"]): e["aw"] for e in events
                        if e["e"] == "hit" and e["gun"] not in ("melee", "self")}.values())
    print(f"# Статистика боёв\n\nСессий: {len(sessions)}, жизней: {len(lives)}, убийств: {len(kills)}"
          + ("" if use_all else f" (weapons.cfg {md5[:8]})") + "\n")

    for key, title in ((weapon_of, "Оружие"), (lambda v: v, "Оружие и модули")):
        agg = defaultdict(lambda: {"lives": 0, "kills": 0, "deaths": 0, "duel_w": 0, "duel_l": 0, "ttk": [],
                                   "ttk_fire": [], "hits": [], "dist": [], "shots": 0, "hit": 0, "dmg_out": 0,
                                   "dur": 0.0})
        for life in lives:
            a = agg[key(life["w"])]
            a["lives"] += 1
            a["shots"] += life["shots"]
            a["dmg_out"] += life["dmg_out"]
            a["dur"] += life["dur"]
        for variant in landed:
            agg[key(variant)]["hit"] += 1
        for k in kills:
            a, b = agg[key(k["kw"])], agg[key(k["vw"])]
            a["kills"] += 1
            b["deaths"] += 1
            if k["gun"] != "melee":
                a["ttk"].append(k["ttk"])
                a["ttk_fire"].append(k["ttk_fire"])
                a["hits"].append(k["hits"])
            a["dist"].append(k["dist"])
            if k["v_dmg_to_k"] > 0 and k["dmg_others"] == 0:  # a duel: both hit, nobody else
                a["duel_w"] += 1
                b["duel_l"] += 1
        rows = []
        for name, a in agg.items():
            if title != "Оружие" and a["lives"] < min_lives:
                continue
            duels = a["duel_w"] + a["duel_l"]
            rows.append([name, a["lives"], a["kills"], a["deaths"], a["kills"] / max(a["deaths"], 1),
                         f"{a['duel_w']}/{duels}" + (f" ({100 * a['duel_w'] / duels:.0f}%)" if duels else ""),
                         med(a["ttk"]), med(a["ttk_fire"]), med(a["hits"]),
                         100.0 * a["hit"] / a["shots"] if a["shots"] else None,
                         a["dmg_out"] / a["dur"] if a["dur"] else None, med(a["dist"])])
        rows.sort(key=lambda r: -r[4])
        print(f"## {title}\n")
        print(table(["", "жизней", "убийств", "смертей", "К/Д", "дуэли", "TTK, с", "TTK от огня, с", "попаданий",
                     "точность, %", "урон/с жизни", "дистанция, м"], rows) + "\n")

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
            elif e["e"] == "kill" and "cause" in e:
                m["causes"][e["cause"]] += 1
    maps = {k: m for k, m in maps.items() if m["lives"]}
    if not maps:
        return
    print("\n## Темп (по картам; бой — попадание, своё или по себе; спокойно — дальше 5 с от попаданий и спавна)\n")
    rows = [[name, m["lives"], med(m["contact"]), pct(m["none"], m["lives"]), pct(m["calm"], m["dur"]),
             ", ".join(f"{c} {n}" for c, n in sorted(m["causes"].items())) or "—"] for name, m in sorted(maps.items())]
    print(table(["карта", "жизней", "до первого боя, с", "жизней без боя", "спокойного времени", "убила карта"], rows))


def builds(sessions):
    """Build changes (files from 2026-11-02 on: "build"): what players leave for what, and how long after death."""
    moves, dead_for, alive = defaultdict(int), [], 0
    for f, events in sessions:
        for e in events:
            if e["e"] == "build" and weapon_of(e["was"]) != weapon_of(e["w"]):
                moves[(weapon_of(e["was"]), weapon_of(e["w"]))] += 1
            if e["e"] == "build":
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
