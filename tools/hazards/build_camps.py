"""Les camps de chaque faction (MyMapIsRich/Plus/Data/Camps.lua), que les chemins à pied d'un joueur de
l'autre faction ne traversent pas (Plus/Travel/Nav.lua).

Les villes connues jusque-là (Data/Hazards.lua) venaient toutes d'un maître de vol : un camp sans maître
de vol (Bourg-Hurlant, Sabot-de-Sang, Brill, Comté-de-l'Or, Kharanos, Dolanaar...) manquait. Ici, un camp
est un groupe de PNJ d'une seule faction (QuestieDB : « A » ou « H »), au moins MIN_NPCS distants de
moins de LINK yards de proche en proche, dont au moins un PNJ de ville (aubergiste, marchand,
réparateur, maître de vol, maître de classe, banquier, commissaire-priseur, maître des écuries, ou un
garde). Son terrain : les morceaux de 100/3 yards à moins de REACH yards d'un de ses PNJ.

Sources :
  - la base Forever de QuestieDB (GPLv3, relevée en jeu par la communauté de Questie), déjà copiée par
    tools/quests (tools/quests/source/QuestieDB-x.y.z) : les PNJ, leur faction, leurs apparitions en
    pourcentages de leur zone ;
  - les rectangles des zones en yards du monde (Data/Zones.lua de Shortest Path Forever, de cjber,
    GPL-3.0-or-later, déjà lu par tools/hazards/build_hazards.ps1).

    python build_camps.py [dossier de ShortestPathForever]
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, "tools", "quests"))
import build_quests  # noqa: E402  (newest, as_map)
from questiedb import QuestieDB  # noqa: E402

DEFAULT_SPF = r"K:\World of Warcraft\_forever_\Interface\AddOns\ShortestPathForever"
OUT = os.path.join(REPO, "MyMapIsRich", "Plus", "Data", "Camps.lua")
CONTINENTS = {0, 1}
CELL = 100 / 3               # yd : les morceaux de terrain (comme les villes de Hazards.lua)
LINK = 40                    # yd : deux PNJ plus proches sont du même camp
REACH = 35                   # yd : le terrain d'un camp, autour de ses PNJ
MIN_NPCS = 4                 # PNJ différents au moins
TOWN_FLAGS = 4 | 8 | 16 | 128 | 256 | 4096 | 8192 | 16384   # marchand, vol, maître, auberge, banque, enchères, écuries, réparation
GUARDS = re.compile(r"\b(Guard|Guardian|Grunt|Deathguard|Sentinel|Brave|Protector|Watcher|Watchman|Mountaineer|"
                    r"Defender|Peacekeeper|Warden|Footman|Marshal|Patroller)\b", re.I)
B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"


def zone_rects(spf):
    """{ carte : (continent, minX, minY, maxX, maxY) } (Data/Zones.lua de SPF)"""
    text = open(os.path.join(spf, "Data", "Zones.lua"), encoding="utf-8").read()
    out = {}
    for m in re.finditer(r"\[(\d+)\] = \{(.*?)\}", text, re.S):
        body = m.group(2)
        f = {k: re.search(r"\b%s = (-?[\d.]+)" % k, body) for k in ("map", "minX", "minY", "maxX", "maxY")}
        if all(f.values()):
            out[int(m.group(1))] = tuple(float(f[k].group(1)) for k in ("map", "minX", "minY", "maxX", "maxY"))
    return out


def world(rect, px, py):
    """un point d'une carte (pourcentages) en yards du monde : x vers le nord, y vers l'ouest"""
    cont, minX, minY, maxX, maxY = rect
    return int(cont), maxX - (py / 100) * (maxX - minX), maxY - (px / 100) * (maxY - minY)


def bits(cells, i0, j0, w, h):
    """w x h bits, x d'abord depuis (i0, j0), six par symbole base64, le plus fort d'abord"""
    flat = [((i0 + i, j0 + j) in cells) for i in range(w) for j in range(h)]
    out = []
    for k in range(0, len(flat), 6):
        v = 0
        for b, on in enumerate(flat[k:k + 6]):
            if on:
                v |= 1 << (5 - b)
        out.append(B64[v])
    return "".join(out)


def main():
    spf = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SPF
    folder = build_quests.newest()
    if not folder:
        raise SystemExit("pas de QuestieDB dans tools/quests/source : lancer d'abord /sync-quetes")
    db = QuestieDB(folder)
    rects = zone_rects(spf)
    print("QuestieDB %s, %d zones" % (db.version, len(rects)))

    # (les apparitions des PNJ d'une seule faction, en yards du monde)
    points = {}              # (faction, continent) -> [ (x, y, npc), ... ]
    info = {}                # npc -> (nom, de ville ?)
    for nid in db.ids("Npc"):
        r = db.row("Npc", nid)
        if not r:
            continue
        side = {"A": "Alliance", "H": "Horde"}.get(r.get(13))
        # (sans modèle de faction : les PNJ d'un événement de Forever, « Enraged ... Grunt »,
        # « Furious ... Sentinel », qui suivent les joueurs partout)
        if not side or not r.get(12):
            continue
        name = r.get(1) if isinstance(r.get(1), str) else "?"
        flags = r.get(15) if isinstance(r.get(15), int) else 0
        town = bool(flags & TOWN_FLAGS) or bool(GUARDS.search(name))
        for area, spots in build_quests.as_map(r.get(7)).items():
            rect = rects.get(db.area_to_uimap.get(area))
            if not rect or int(rect[0]) not in CONTINENTS:
                continue
            for spot in spots or []:
                if not isinstance(spot, (list, tuple)) or len(spot) < 2 or spot[0] is None or spot[0] < 0:
                    continue
                c, x, y = world(rect, spot[0], spot[1])
                points.setdefault((side, c), []).append((x, y, nid))
                info[nid] = (name, town)

    camps = []
    for (side, cont), pts in sorted(points.items()):
        # (les groupes : de proche en proche à moins de LINK, par un index en cases de LINK)
        index = {}
        for k, (x, y, _) in enumerate(pts):
            index.setdefault((int(x // LINK), int(y // LINK)), []).append(k)
        parent = list(range(len(pts)))

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a

        for k, (x, y, _) in enumerate(pts):
            gx, gy = int(x // LINK), int(y // LINK)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for o in index.get((gx + dx, gy + dy), ()):
                        if o > k and (pts[o][0] - x) ** 2 + (pts[o][1] - y) ** 2 <= LINK * LINK:
                            ra, rb = find(k), find(o)
                            if ra != rb:
                                parent[ra] = rb
        groups = {}
        for k in range(len(pts)):
            groups.setdefault(find(k), []).append(pts[k])
        for members in groups.values():
            npcs = {m[2] for m in members}
            towns = [n for n in npcs if info[n][1]]
            if len(npcs) < MIN_NPCS or not towns:
                continue
            cells = set()
            reach = REACH / CELL
            for x, y, _ in members:
                ci, cj = x / CELL, y / CELL
                for i in range(int(ci - reach) - 1, int(ci + reach) + 2):
                    for j in range(int(cj - reach) - 1, int(cj + reach) + 2):
                        if ((i + 0.5) * CELL - x) ** 2 + ((j + 0.5) * CELL - y) ** 2 <= REACH * REACH:
                            cells.add((i, j))
            i0, j0 = min(c[0] for c in cells), min(c[1] for c in cells)
            w, h = max(c[0] for c in cells) - i0 + 1, max(c[1] for c in cells) - j0 + 1
            label = sorted(info[n][0] for n in towns)[0]
            camps.append((side, cont, i0, j0, w, h, bits(cells, i0, j0, w, h), label, len(npcs)))

    lines = [
        "-- Généré par tools/hazards/build_camps.py : ne pas modifier à la main.",
        "-- Les camps de chaque faction, que les chemins à pied d'un joueur de l'autre faction ne traversent",
        "-- pas (Travel/Nav.lua) : un groupe de PNJ d'une seule faction, dont au moins un PNJ de ville.",
        "-- Sources : la base Forever de QuestieDB %s (GPLv3 ; les PNJ, leur faction, leurs apparitions) et" % db.version,
        "-- les rectangles des zones de Shortest Path Forever de cjber (GPL-3.0-or-later). Données dérivées,",
        "-- sous licence GPL-3.0-or-later (voir LICENSE).",
        "--   { faction, continent, i0, j0, w, h, cases } : le terrain du camp, en morceaux de 100/3 yards (le",
        "--     morceau (i, j) couvre x dans [i, i + 1), y dans [j, j + 1) fois 100/3) ; cases : w x h bits, x",
        "--     d'abord depuis (i0, j0), six bits par symbole base64 (A-Za-z0-9+/), le plus fort d'abord.",
        "-- x vers le nord, y vers l'ouest (UnitPosition), en yards du monde.",
        "local _, root = ...",
        "local ns = root.Plus",
        "",
        "ns.CampData = {",
    ]
    for side, cont, i0, j0, w, h, b, label, n in camps:
        lines.append('\t{ "%s", %d, %d, %d, %d, %d, "%s" }, -- %s (%d PNJ)' % (side, cont, i0, j0, w, h, b, label, n))
    lines += ["}", ""]
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    for side in ("Alliance", "Horde"):
        print("%s : %d camps" % (side, sum(1 for c in camps if c[0] == side)))
    print("-> %s (%d Ko)" % (OUT, os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
