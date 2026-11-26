"""Les lignes de bateaux et de zeppelins (MyMapIsRich/Plus/Data/Transit.lua), pour apprendre leurs horaires
en les regardant passer (Plus/Travel/Transit.lua).

Source : Shortest Path Forever de cjber (GPL-3.0-or-later), Data/Routes.lua : pour chaque ligne, sa période
(le temps d'un tour, en ms), ses arrêts (le quai, quand le bateau y arrive et en repart, en ms dans le tour)
et son trajet (des points datés dans le tour), d'après les chemins du client et le modèle des transports de
CMaNGOS. Seuls les deux continents de la carte sont gardés.

    python build_transit.py [dossier de ShortestPathForever]

Sans dépendance (la bibliothèque standard de Python).
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
DEFAULT_SPF = r"K:\World of Warcraft\_forever_\Interface\AddOns\ShortestPathForever"
OUT = os.path.join(REPO, "MyMapIsRich", "Plus", "Data", "Transit.lua")
CONTINENTS = {0, 1}
NUM = r"-?\d+(?:\.\d+)?"


def main():
    spf = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SPF
    toc = open(os.path.join(spf, "ShortestPathForever.toc"), encoding="utf-8").read()
    m = re.search(r"(?m)^## Version: (.+)$", toc)
    version = m.group(1).strip() if m else "?"
    text = open(os.path.join(spf, "Data", "Routes.lua"), encoding="utf-8").read()

    # (les quais : dans l'ordre, leur numéro est leur place dans la liste)
    block = re.search(r"ns\.Docks = \{(.*?)\n\}", text, re.S).group(1)
    docks = []
    for line in block.splitlines():
        d = re.match(r"\s*\{ map = (\d+), x = (%s), y = (%s)" % (NUM, NUM), line)
        if d:
            docks.append((int(d.group(1)), float(d.group(2)), float(d.group(3))))

    # (les lignes)
    block = re.search(r"ns\.Routes = \{(.*)\n\}", text, re.S).group(1)
    routes = []
    for r in re.finditer(r"\n\t\[(\d+)\] = \{(.*?)\n\t\},", block, re.S):
        rid, body = int(r.group(1)), r.group(2)
        kind = re.search(r'kind = "(\w+)"', body).group(1)
        faction = re.search(r'faction = "(\w+)"', body)
        period = int(re.search(r"period = (\d+)", body).group(1))
        stops = [tuple(int(v) for v in s) for s in
                 re.findall(r"\{ dock = (\d+), arrive = (\d+), depart = (\d+) \}", body)]
        frames = []
        for f in re.findall(r"\{ (\d+), (\d+), (\d+), (%s), (%s)(?:, (\d+))? \}" % (NUM, NUM), body):
            frames.append((int(f[0]), int(f[1]), int(f[2]), float(f[3]), float(f[4]), int(f[5] or 0)))
        conts = {docks[s[0] - 1][0] for s in stops}
        if not conts <= CONTINENTS or not stops or len(frames) < 2:
            continue
        routes.append((rid, kind, faction.group(1) if faction else None, period, stops, frames))

    lines = [
        "-- Généré par tools/transit/build_transit.py : ne pas modifier à la main.",
        "-- Les lignes de bateaux et de zeppelins, pour apprendre leurs horaires en les regardant passer",
        "-- (Travel/Transit.lua). Source : Shortest Path Forever %s de cjber" % version,
        "-- (https://github.com/cjber/shortest-path-forever), Data/Routes.lua (les chemins du client et le modèle",
        "-- des transports de CMaNGOS). Données dérivées, sous licence GPL-3.0-or-later (voir LICENSE).",
        "--   docks[n] = { continent, x, y } : un quai, en yards du monde.",
        "--   routes[ligne] = { kind, faction (nil : les deux), period (ms, un tour), stops = { { quai, arrivée,",
        "--     départ }, ... } (ms dans le tour ; un départ plus petit que l'arrivée passe le début du tour),",
        "--     frames = { arrivée, départ, continent, x, y, saut, ... } (six nombres par point du trajet, daté",
        "--     en ms dans le tour ; saut : 1 quand le point suivant est atteint par un écran de chargement) }.",
        "-- x vers le nord, y vers l'ouest (UnitPosition).",
        "local _, root = ...",
        "local ns = root.Plus",
        "",
        "ns.TransitData = {",
        "\tdocks = {",
    ]
    for i, (c, x, y) in enumerate(docks, 1):
        lines.append("\t\t[%d] = { %d, %.1f, %.1f }," % (i, c, x, y))
    lines += ["\t},", "\troutes = {"]
    for rid, kind, faction, period, stops, frames in routes:
        lines.append('\t\t[%d] = { kind = "%s", %speriod = %d,' % (rid, kind, ('faction = "%s", ' % faction) if faction else "", period))
        lines.append("\t\t\tstops = { %s }," % ", ".join("{ %d, %d, %d }" % s for s in stops))
        lines.append("\t\t\tframes = {")
        for f in frames:
            lines.append("\t\t\t\t%d, %d, %d, %.1f, %.1f, %d," % f)
        lines += ["\t\t\t},", "\t\t},"]
    lines += ["\t},", "}", ""]
    with open(OUT, "w", encoding="utf-8", newline="\n") as out:
        out.write("\n".join(lines))
    print("%d quais, %d lignes -> %s" % (len(docks), len(routes), OUT))


if __name__ == "__main__":
    main()
