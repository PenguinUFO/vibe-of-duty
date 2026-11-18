"""One-off diff of the hand-edited gigachurch_shell.tscn against the generator's baseline (_drift_check_shell.tscn).
Parses both into node dicts, matches by name then by geometry key, prints added / deleted / changed."""
import re
import sys

HEADER = re.compile(r'\[node name="([^"]+)"([^\]]*)\]$')
NUM = re.compile(r"[-0-9.e]+")


def norm_num(s):
    """'−0.4763' -> -0.476; numbers rounded to 3 decimals, -0 -> 0."""
    try:
        v = round(float(s), 3)
    except ValueError:
        return s
    return 0.0 if v == 0 else v


def norm_vec(s):
    return tuple(norm_num(x) for x in NUM.findall(s))


def parse(path):
    nodes, name, props = {}, None, None
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            m = HEADER.match(line)
            if m:
                if name:
                    nodes[name] = props
                name = m.group(1)
                rest = m.group(2)
                pm = re.search(r'parent="([^"]+)"', rest)
                props = {"parent": pm.group(1) if pm else None}
                if 'type="OmniLight3D"' in rest:
                    props["light"] = True
                continue
            if name and "=" in line:
                k, v = line.split("=", 1)
                props[k.strip()] = v.strip()
    if name:
        nodes[name] = props
    return nodes


def pos_of(p):
    if "transform" not in p:
        return None
    v = norm_vec(p["transform"])
    return tuple(v[9:12]) if len(v) >= 12 else None


def size_of(p):
    return norm_vec(p.get("size", "")) or None


def geom_key(p):
    return (pos_of(p), size_of(p))


def main():
    base, his = parse(sys.argv[1]), parse(sys.argv[2])
    bg = {n: p for n, p in base.items() if "light" not in p}
    hg = {n: p for n, p in his.items() if "light" not in p}
    bl = {n: p for n, p in base.items() if "light" in p}
    hl = {n: p for n, p in his.items() if "light" in p}

    matched, added, deleted = {}, {}, dict(bg)
    for n, p in hg.items():
        if n in bg:
            matched[n] = p
            del deleted[n]
        else:
            added[n] = p
    # renamed-but-same-geometry: match added against deleted by (pos, size)
    del_by_key = {}
    for n, p in deleted.items():
        del_by_key.setdefault(geom_key(p), []).append(n)
    still_added = {}
    for n, p in added.items():
        hit = del_by_key.get(geom_key(p))
        if hit:
            matched[hit.pop(0)] = p
            if not hit:
                del del_by_key[geom_key(p)]
        else:
            still_added[n] = p
    still_deleted = {n: deleted[n] for lst in del_by_key.values() for n in lst}

    def show(p):
        return "pos=%s size=%s color=%s layers=%s" % (pos_of(p), size_of(p), p.get("color"), p.get("mesh_layers"))

    print("=== ADDED (%d) ===" % len(still_added))
    for n, p in still_added.items():
        print("  %-26s %s" % (n, show(p)))
    print("=== DELETED (%d) ===" % len(still_deleted))
    for n, p in still_deleted.items():
        print("  %-26s %s" % (n, show(p)))
    print("=== CHANGED ===")
    for n, p in sorted(matched.items()):
        b = bg.get(n, deleted.get(n))
        if b is None:
            continue
        diffs = []
        if pos_of(b) != pos_of(p):
            diffs.append("pos %s -> %s" % (pos_of(b), pos_of(p)))
        if norm_vec(b.get("size", "")) != norm_vec(p.get("size", "")):
            diffs.append("size %s -> %s" % (b.get("size"), p.get("size")))
        if b.get("color") != p.get("color"):
            diffs.append("color %s -> %s" % (b.get("color"), p.get("color")))
        if b.get("mesh_layers") != p.get("mesh_layers"):
            diffs.append("layers %s -> %s" % (b.get("mesh_layers"), p.get("mesh_layers")))
        if diffs:
            print("  %-26s %s" % (n, "; ".join(diffs)))
    print("=== LAMPS (his %d, base %d) ===" % (len(hl), len(bl)))
    for n, p in hl.items():
        b = bl.get(n)
        if b is None:
            print("  ADDED   %s pos=%s e=%s rng=%s col=%s shade=%s" %
                  (n, pos_of(p), p.get("light_energy"), p.get("omni_range"),
                   p.get("light_color"), p.get("metadata/shade")))
        else:
            diffs = []
            if pos_of(b) != pos_of(p):
                diffs.append("pos %s -> %s" % (pos_of(b), pos_of(p)))
            for k in ("light_energy", "omni_range", "light_color", "metadata/shade"):
                if b.get(k) != p.get(k):
                    diffs.append("%s %s -> %s" % (k, b.get(k), p.get(k)))
            if diffs:
                print("  CHANGED %-24s %s" % (n, "; ".join(diffs)))
    for n in bl:
        if n not in hl:
            print("  DELETED %s pos=%s" % (n, pos_of(bl[n])))
    print("counts: matched %d, added %d, deleted %d, lamps his %d base %d" %
          (len(matched), len(still_added), len(still_deleted), len(hl), len(bl)))


main()
