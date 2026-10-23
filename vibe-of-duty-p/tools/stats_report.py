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
    kills, lives = [], []
    for _, events in sessions:
        kills += [e for e in events if e["e"] == "kill" and e["gun"] != "self"]
        lives += [e for e in events if e["e"] == "life"]
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
            a["hit"] += life["hits"]
            a["dmg_out"] += life["dmg_out"]
            a["dur"] += life["dur"]
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


if __name__ == "__main__":
    main()
