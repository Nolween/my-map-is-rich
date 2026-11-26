"""La grille de marche des itinéraires (MyMapIsRich/Plus/Data/Nav0.lua, Nav1.lua)
et les passages (MyMapIsRich/Plus/Data/Passages.lua).

Les cases (environ 8 yards) viennent du maillage de marche de Shortest Path
Forever (cjber, GPL-3.0-or-later ; Nav/NavN*.lua, extrait du terrain du client
avec les outils de TrinityCore), dans son format 4. Une case a une surface de
base (le sol, en général) et parfois des étages au-dessus ou au-dessous : un
pont, la rue d'une ville bâtie sur ses caves, les étages d'un bâtiment, les
anneaux de Fossoyeuse.
Les pas permis sont ceux de SPF : son maillage de marche a décidé, case par
case, où le joueur passe (les falaises, les murs, les pentes trop raides, les
rebords qu'on ne prend qu'en descendant), dans les huit directions et d'une
tuile à l'autre. Les étages : chaque pas d'un étage nomme la couche où il
arrive ; s'y ajoutent les chutes. Les hauteurs ne sont pas livrées : le jeu ne
lit que les pas permis et le terrain de chaque surface.
Le terrain d'une surface (pour le prix d'un pas, Travel/Nav.lua, d'après les
styles de marche de Polestar) :
  - pente douce ou raide : la pente du sol autour de la case, les hauteurs
    lissées sur trois cases (elles sont arrondies à zstep yards) ;
  - intérieur : sous un plafond (un toit, une voûte de grotte) à moins de
    INDOOR_GAP yards, sur un morceau d'au moins INDOOR_MIN cases (un pont ou une
    arche au-dessus d'une route ne compte pas) ;
  - intérieur de cité : le même, dans une capitale (Data/Hazards.lua).
S'y ajoutent :
  - la couverture des routes (Data/RoadCells.lua de SPF), pour que les
    chemins les préfèrent ;
  - la couche du sol de chaque case à étages (le terrain de SPF) et sa couche
    la plus basse ;
  - les ascenseurs (Data/Transports.lua de SPF) : un saut entre le haut et le
    bas, au même endroit de la carte.
Les passages (le portail de Darnassus, le tram des profondeurs) vont dans
Data/Passages.lua : ce sont des étapes de l'itinéraire, pas des pas.

La surface de base : un octet par case, 48 + type (0 bloquée, 1 sol, 2 eau)
+ 4 * pas permis vers une autre surface de base (1 +x, 2 -x, 4 +y, 8 -y)
+ 64 * route. Chaque tuile (67 x 67 cases, x d'abord) est compressée (zlib)
puis codée en base64 : le jeu la décode à la demande (C_EncodingUtil).

Le terrain et les diagonales de la base (terrain), un octet par case de même :
terrain (0 normal, 2 pente douce, 3 pente raide, 4 intérieur, 5 intérieur de
cité ; 1, la route, est dit par l'octet de base) + 8 * diagonales à inverser
(1 +x+y, 2 +x-y, 4 -x+y, 8 -x-y) : un pas en diagonale de base à base passe
si l'un des deux chemins en L passe, sauf si son bit le dit à l'inverse.

Les étages d'une tuile (floors), compressés de même : des groupes par case,
dans l'ordre des cases. Un groupe : l'écart à la case du groupe d'avant
(un octet, ou 255 puis deux octets), la couche du sol (255 : inconnue), la
couche la plus basse, le nombre de nœuds, puis chaque nœud : sa couche (0 la
base, i le i-ème étage depuis le bas), son type (1 sol, 2 eau, + 4 * route),
le masque de ses pas d'une case (1 +x, 2 -x, 4 +y, 8 -y, 16 +x+y, 32 +x-y,
64 -x+y, 128 -x-y), la couche d'arrivée de chacun dans l'ordre des bits,
son terrain (comme cls, sans diagonales), puis ses autres pas : leur nombre
et, pour chacun, dx + 64, dy + 64, couche.
Un nœud de couche 0 n'y a que les pas que l'octet de base ne dit pas (vers un
étage, une chute).

    python build_nav.py [dossier de ShortestPathForever]
"""

import base64
import glob
import math
import os
import re
import sys
import zlib

import numpy as np
from scipy import ndimage
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(HERE, "..", "roads"))
import build_roads  # noqa: E402  (la lecture des routes et de l'en-tête des cartes)
import portals  # noqa: E402  (le graphe des passages entre tuiles)

DEFAULT_SPF = build_roads.DEFAULT_SPF
OUT = os.path.join(REPO, "MyMapIsRich", "Plus", "Data", "Nav%d.lua")
OUT_PASSAGES = os.path.join(REPO, "MyMapIsRich", "Plus", "Data", "Passages.lua")
HAZARDS = os.path.join(REPO, "MyMapIsRich", "Plus", "Data", "Hazards.lua")
CONTINENTS = {0: "Royaumes de l'Est", 1: "Kalimdor"}
TILE = 1600 / 3
ROAD_MIN = 1                 # couverture minimale d'une case de route (sur 63)
LIFT_SECS = 22               # s : l'attente moyenne et la montée d'un ascenseur
LIFT_REACH = 3               # cases : la plateforme d'un ascenseur est cherchée jusque-là
PASSAGE_REACH = 4            # cases : de même pour le bout d'un passage
ISLAND = 30                  # étages : un îlot plus petit, au-dessus d'un sol sec, est élagué
# Le terrain (à régler en jeu : /mmir sonde terrain)
GENTLE_DEG = 22              # degrés : une pente douce à partir de là...
STEEP_DEG = 35               # ... raide à partir de là
SMOOTH = 5                   # cases : le côté du carré où les hauteurs sont lissées
INDOOR_GAP = 15              # yd : un plafond plus bas que ça au-dessus de la surface, c'est l'intérieur...
INDOOR_MIN = 12              # cases : ... sur un morceau d'au moins autant de cases (la base)
CAP_CELL = 64                # yd : les carrés des capitales (Data/Hazards.lua)
NORMAL, GENTLE, STEEP, INDOOR, CITY = 0, 2, 3, 4, 5

DX = [1, -1, 0, 0, 1, 1, -1, -1]
DY = [0, 0, 1, -1, 1, -1, 1, -1]
DIRECTION = {(DX[d], DY[d]): d for d in range(8)}

B64 = {c: i for i, c in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")}

# Les passages (Data/Portals.lua et Data/Transports.lua de SPF) : deux bouts
# (continent, x, y, z), le temps (chargements, attente, trajet), la faction
PASSAGES = [
    {
        "kind": "portal", "name": "Darnassus", "faction": "Alliance", "secs": 10,
        "a": (1, 8799.41, 969.787, 30.241),          # Rut'theran : le portail vers Darnassus
        "b": (1, 9947.48, 2630.04, 1318.6),          # Darnassus : le portail vers Rut'theran
    },
    {
        # deux chargements (5 s), la gare de chaque côté, l'attente (deux rames,
        # 143 s par tour) et le trajet (une minute)
        "kind": "tram", "name": "Deeprun Tram", "faction": "Alliance", "secs": 130,
        "a": (0, -8346.46, 514.031, 96.599),         # Hurlevent : le passage vers le tram
        "b": (0, -4840.26, -1330.46, 508.172),       # Forgefer : le passage vers le tram
    },
]


def num(s, i, width):
    """un entier en base 64 (grand-boutiste) de `width` symboles à partir de i (0 d'abord)"""
    v = 0
    for c in s[i:i + width]:
        v = v * 64 + B64[c]
    return v


def packed(files, name):
    """{ k: chaîne décompressée } d'un champ des fichiers NavN_*.lua (latin-1 : les étages finissent
    par des octets bruts, les plans de dégagement de SPF, qu'on ne lit pas)"""
    out = {}
    for f in files:
        text = open(f, encoding="utf-8").read()
        for m in re.finditer(r"data\.packed\.%s\[(\d+)\] = \{([^}]*)\}" % name, text):
            blocks = re.findall(r'"([^"]*)"', m.group(2))
            out[int(m.group(1)) - 1] = b"".join(zlib.decompress(base64.b64decode(b)) for b in blocks).decode("latin-1")
    return out


def decode_grid(s, C):
    """La grille du format 4 (PathGrid.lua : decodeDirectedGrid) : type (0 bloquée, 1 sol, 2 eau) et
    masque des pas de base à base (bit d : vers DX[d], DY[d], d'une tuile à l'autre compris)"""
    count = B64[s[0]]
    palette = [num(s, 1 + e * 2, 2) for e in range(count)]
    val = np.zeros(C * C, dtype=np.int8)
    mask = np.zeros(C * C, dtype=np.uint8)
    n, i, v, m = 0, 1 + count * 2, 0, 0
    while i < len(s):
        sym = B64[s[i]]
        i += 1
        if sym >= 48:
            reps = sym - 47
        else:
            if sym == 47:
                code = num(s, i, 2)
                i += 2
            else:
                code = palette[sym]
            v, m = code // 256, code % 256
            reps = 1
        val[n:n + reps] = v
        mask[n:n + reps] = m
        n += reps
    if n != C * C:
        raise SystemExit("grille : %d cases au lieu de %d" % (n, C * C))
    return val, mask


def decode_heights(s, val, C, zstep):
    """Les hauteurs (yd) des cases franchissables (PathGrid.lua : decodeHeights)"""
    z = np.full(C * C, np.nan, dtype=np.float32)
    zu = [None] * (C * C)
    pos, rep, delta, last = 0, 0, 0, 0
    for i in range(C * C):
        if val[i] == 0:
            continue
        if i % C > 0 and zu[i - 1] is not None:
            pred = zu[i - 1]
        elif i >= C and zu[i - C] is not None:
            pred = zu[i - C]
        else:
            pred = last
        if rep > 0:
            rep -= 1
            v = pred + delta
        else:
            sym = B64[s[pos]]
            if sym == 47:
                v = B64[s[pos + 1]] * 64 + B64[s[pos + 2]] - 2048
                pos += 3
            else:
                delta = sym - 23
                pos += 1
                while pos < len(s) and B64[s[pos]] >= 48:
                    rep += B64[s[pos]] - 47
                    pos += 1
                v = pred + delta
        last = v
        zu[i] = v
        z[i] = v * zstep
    return z


def decode_floors(s, C, val, implicit):
    """Les étages d'une tuile (format 4, PathGrid.lua : decodeFloors, decodeLinks) : leurs cases, types,
    hauteurs (yd), couches, et les pas (nœud, dx, dy, couche d'arrivée), tous à sens unique ; un nœud
    < C * C est la surface de base de cette case, sinon le (nœud - C * C)-ième étage. implicit : le
    floorFormat 1 de SPF (la couche d'arrivée d'un pas qui n'a qu'un choix n'est pas écrite)."""
    N = C * C
    n = num(s, 0, 3)
    pos = 3
    cells, vals, zs = [], [], []
    at, first, masks = {}, {}, {}
    lc, node = 0, N
    for _ in range(n):
        sym = B64[s[pos]]
        pos += 1
        if sym < 63:
            lc += sym
        else:
            lc += 63 + num(s, pos, 3)
            pos += 3
        cells.append(lc)
        vals.append(B64[s[pos]])
        zs.append(num(s, pos + 1, 2) - 2048)
        masks[node] = num(s, pos + 3, 2)
        at[node] = lc
        first.setdefault(lc, node)
        pos += 5
        node += 1
    last = node
    layers = [node - first[at[node]] + 1 for node in range(N, last)]
    links = []

    # (les nœuds de la base qui ont des pas vers un étage, ou d'une couche à préciser)
    count = num(s, pos, 3)
    pos += 3
    base, bnode = [], 0
    for _ in range(count):
        delta = B64[s[pos]]
        pos += 1
        if delta == 63:
            delta = 63 + num(s, pos, 3)
            pos += 3
        bnode += delta
        base.append(bnode)
        masks[bnode] = num(s, pos, 2)
        pos += 2

    # (les couches d'arrivée : implicites quand il n'y a qu'un choix, sauf dérogation)
    state = {"override": pos + 3, "end": pos, "ordinal": 0, "next": 0, "pos": pos}
    if implicit:
        state["end"] = state["override"] + num(s, pos, 3)
        state["pos"] = state["end"]

    def advance():
        if state["override"] >= state["end"]:
            state["next"] = math.inf
            return
        delta = B64[s[state["override"]]]
        state["override"] += 1
        if delta == 63:
            delta = 63 + num(s, state["override"], 3)
            state["override"] += 3
        state["next"] += delta

    if implicit:
        advance()

    def landing(frm, dx, dy, p):
        layers_set = B64[s[p]]
        p += 1
        if layers_set == 0:
            k = num(s, p, 2)
            p += 2
            for _ in range(k):
                links.append((frm, dx, dy, B64[s[p]]))
                p += 1
        else:
            layer = 0
            while layers_set > 0:
                if layers_set & 1:
                    links.append((frm, dx, dy, layer))
                layer += 1
                layers_set >>= 1
        return p

    def directed(frm):
        bits = masks.get(frm, 0)
        if not bits:
            return
        cell = frm if frm < N else at[frm]
        x, y = cell // C, cell % C
        for d in range(8):
            if not bits >> d & 1:
                continue
            dx, dy = DX[d], DY[d]
            layer = None
            if implicit:
                tx, ty = x + dx, y + dy
                if 0 <= tx < C and 0 <= ty < C:
                    target = tx * C + ty
                    f = first.get(target)
                    if frm < N:
                        if f is not None and at.get(f + 1) != target:
                            layer = 1
                    elif f is None:
                        layer = 0
            if layer is None:
                state["pos"] = landing(frm, dx, dy, state["pos"])
            else:
                state["ordinal"] += 1
                if state["ordinal"] == state["next"]:
                    state["override"] = landing(frm, dx, dy, state["override"])
                    advance()
                else:
                    links.append((frm, dx, dy, layer))

    for frm in range(N, last):
        directed(frm)
    for frm in base:
        directed(frm)
    pos = state["pos"]

    # (les chutes : d'un nœud, sur dx, dy cases, vers une couche)
    drops = num(s, pos, 3)
    pos += 3
    for _ in range(drops):
        frm = num(s, pos, 3)
        links.append((frm, B64[s[pos + 3]] - 8, B64[s[pos + 4]] - 8, B64[s[pos + 5]]))
        pos += 8
    return cells, vals, zs, layers, links


def decode_terrain(s):
    """{ case : couche du sol (None : pas de sol) } : les cases dont le sol n'est pas la base"""
    out, cell, pos = {}, -1, 0
    while pos < len(s):
        sym = B64[s[pos]]
        pos += 1
        if sym < 63:
            cell += sym + 1
        else:
            cell += 64 + num(s, pos, 3)
            pos += 3
        sym = B64[s[pos]]
        pos += 1
        out[cell] = None if sym == 63 else sym + 1
    return out


def decode_ceiling(s):
    """{ case * 64 + couche : hauteur (yd) du plus bas plafond } (PathCeiling.lua : relief ou structure)"""
    out, key, pos = {}, -1, 0

    def unsigned(p):
        value, place = 0, 1
        while True:
            digit = B64[s[p]]
            p += 1
            value += (digit % 32) * place
            if digit < 32:
                return value, p
            place *= 32

    while pos < len(s):
        delta, pos = unsigned(pos)
        value, pos = unsigned(pos)
        key += delta
        h = value // 2
        yd = (h / 2 if h % 2 == 0 else -(h + 1) / 2) / 8
        out[key] = min(out.get(key, yd), yd)
    return out


def capitals(cont):
    """Les carrés de 64 yards des capitales d'un continent (Data/Hazards.lua), les deux factions"""
    text = open(HAZARDS, encoding="utf-8").read()
    squares = set()
    for m in re.finditer(r'\[\d+\] = \{ "\w+", (\d+), "([-\d ]+)" \}', text):
        if int(m.group(1)) != cont:
            continue
        values = [int(v) for v in m.group(2).split()]
        for i, j, n in zip(values[0::3], values[1::3], values[2::3]):
            for q in range(n):
                squares.add((i, j + q))
    return squares


def lift_pairs(spf, cont):
    """Les ascenseurs d'un continent : [(x, y, z du haut, z du bas, nom), ...] (Data/Transports.lua)"""
    text = open(os.path.join(spf, "Data", "Transports.lua"), encoding="utf-8").read()
    docks = {}
    for m in re.finditer(r"ns\.Docks\[(\d+)\] = (\{.*?\})\n", text, re.S):
        body = m.group(2)
        fields = {}
        for key in ("map", "x", "y", "z"):
            f = re.search(r"\b%s = (-?[\d.]+)" % key, body)
            fields[key] = float(f.group(1)) if f else None
        site = re.search(r'site = "([^"]*)"', body)
        name = re.search(r'name = "([^"]*)"', body)
        fields["site"] = site.group(1) if site else "?"
        fields["name"] = name.group(1) if name else "?"
        docks[int(m.group(1))] = fields
    pairs = []
    for i, d in sorted(docks.items()):
        if 1001 <= i < 1100 and d["name"] == "Top" and d["map"] == cont:
            low = docks.get(i + 1)
            if low and low["name"] == "Bottom" and low["site"] == d["site"]:
                pairs.append((d["x"], d["y"], d["z"], low["z"], d["site"]))
    return pairs


def build(spf, cont, roads):
    files = sorted(glob.glob(os.path.join(spf, "Nav", "Nav%d_*.lua" % cont)))
    main = open(os.path.join(spf, "Nav", "Nav%d.lua" % cont), encoding="utf-8").read()
    main = main[main.find("ShortestPathForeverPathData[%d] = {" % cont):]
    head = build_roads.nav_header(spf, cont)
    C, nx, ny = head["cells"], head["nx"], head["ny"]
    if not re.search(r"\bformat = 4,", main):
        raise SystemExit("Nav%d.lua : le format 4 de SPF est attendu" % cont)
    zstep = float(re.search(r"\bzstep = ([\d.]+),", main).group(1))
    implicit = re.search(r"\bfloorFormat = 1,", main) is not None
    cs = TILE / C
    N = C * C
    grids, heights = packed(files, "grid"), packed(files, "height")
    floor_data, terrain_data = packed(files, "floor"), packed(files, "terrain")
    ceiling_data = packed(files, "ceiling")
    GX, GY = nx * C, ny * C
    V = np.zeros((GX, GY), dtype=np.int8)
    M = np.zeros((GX, GY), dtype=np.uint8)
    Z = np.full((GX, GY), np.nan, dtype=np.float32)
    for k, s in grids.items():
        val, mask = decode_grid(s, C)
        z = decode_heights(heights[k], val, C, zstep) if k in heights else np.full(N, np.nan, np.float32)
        kx, ky = k // ny, k % ny
        sl = (slice(kx * C, (kx + 1) * C), slice(ky * C, (ky + 1) * C))
        V[sl] = val.reshape(C, C)
        M[sl] = mask.reshape(C, C)
        Z[sl] = z.reshape(C, C)
    # (un cas sans hauteur : on ne sait rien, on n'y passe pas)
    walk = (V != 0) & ~np.isnan(Z)

    def target_walk(d):
        """la case voisine dans la direction d est-elle praticable ? (grille booléenne)"""
        t = np.zeros((GX, GY), dtype=bool)
        dx, dy = DX[d], DY[d]
        sx = slice(max(0, -dx), GX - max(0, dx))
        sy = slice(max(0, -dy), GY - max(0, dy))
        tx = slice(max(0, dx), GX - max(0, -dx))
        ty = slice(max(0, dy), GY - max(0, -dy))
        t[sx, sy] = walk[tx, ty]
        return t

    # --- Les étages : leurs nœuds, puis leurs pas ----------------------------
    # un nœud : (gx * GY + gy) * 64 + couche ; fz, fval : hauteur et type d'un étage
    fz, fval = {}, {}
    raw = []                                              # (k, cells, layers, links)
    for k, s in floor_data.items():
        val = V[(k // ny) * C:(k // ny + 1) * C, (k % ny) * C:(k % ny + 1) * C].reshape(-1)
        cells, vals, zs, layers, links = decode_floors(s, C, val, implicit)
        kx, ky = k // ny, k % ny
        for c, v, z, layer in zip(cells, vals, zs, layers):
            gx, gy = kx * C + c // C, ky * C + c % C
            nid = (gx * GY + gy) * 64 + layer
            fz[nid], fval[nid] = z, v
        raw.append((k, cells, layers, links))

    def exists(gx, gy, layer):
        if gx < 0 or gy < 0 or gx >= GX or gy >= GY:
            return False
        if layer == 0:
            return bool(walk[gx, gy])
        return ((gx * GY + gy) * 64 + layer) in fz

    def height(nid):
        layer = nid % 64
        if layer:
            return fz[nid]
        cell = nid // 64
        return float(Z[cell // GY, cell % GY])

    def value(nid):
        layer = nid % 64
        if layer:
            return fval[nid]
        cell = nid // 64
        return int(V[cell // GY, cell % GY])

    out = {}                                              # nœud -> { (dx, dy, couche) }
    linked = set()                                        # les nœuds touchés par un pas
    rejected, folded = 0, 0
    for k, cells, layers, links in raw:
        kx, ky = k // ny, k % ny
        for node, dx, dy, layer in links:
            if node < N:
                c, own = node, 0
            else:
                c, own = cells[node - N], layers[node - N]
            gx, gy = kx * C + c // C, ky * C + c % C
            if not exists(gx, gy, own) or not exists(gx + dx, gy + dy, layer) or (dx == 0 and dy == 0 and layer == own):
                rejected += 1
                continue
            if own == 0 and layer == 0 and (dx, dy) in DIRECTION:
                # (un pas de base à base d'une case : dans le masque de la base)
                M[gx, gy] |= 1 << DIRECTION[(dx, dy)]
                folded += 1
                continue
            a = (gx * GY + gy) * 64 + own
            b = ((gx + dx) * GY + gy + dy) * 64 + layer
            out.setdefault(a, set()).add((dx, dy, layer))
            linked.add(a)
            linked.add(b)

    # --- Les pas de la base : le masque de SPF, vers une case praticable ------
    step = [((M >> d) & 1).astype(bool) & walk & target_walk(d) for d in range(8)]
    px, mx, py, my = step[0], step[1], step[2], step[3]
    stepbits = (px.astype(np.uint8) + 2 * mx + 4 * py + 8 * my).astype(np.uint8)
    # (les diagonales : là où le maillage de SPF dit autre chose que la règle du jeu, un des deux
    # chemins en L de base à base, Travel/Nav.lua : Step ; ailleurs rien, la compression y gagne)
    def shifted(a, dx, dy):
        t = np.zeros_like(a)
        t[max(0, -dx):GX - max(0, dx), max(0, -dy):GY - max(0, dy)] = a[max(0, dx):GX - max(0, -dx), max(0, dy):GY - max(0, -dy)]
        return t

    diagbits = np.zeros((GX, GY), dtype=np.uint8)
    lonly = 0
    for bit, d in enumerate(range(4, 8)):
        dx, dy = DX[d], DY[d]
        bx = px if dx == 1 else mx
        by = py if dy == 1 else my
        lshape = (bx & shifted(by, dx, 0)) | (by & shifted(bx, 0, dy))
        diagbits |= ((step[d] ^ lshape).astype(np.uint8) << bit)
        lonly += int((step[d] & ~lshape).sum())
    anydiag = step[4] | step[5] | step[6] | step[7]
    kind = np.where(walk, np.where(V == 2, 2, 1), 0).astype(np.uint8)
    roadcov = build_roads.coverage_grid(head, roads) >= ROAD_MIN
    road = roadcov & walk
    code = (48 + kind + 4 * stepbits + 64 * road).astype(np.uint8)

    # --- Le terrain ----------------------------------------------------------
    # (la pente : les hauteurs du sol sec lissées sur SMOOTH x SMOOTH cases, puis leur pente)
    dry = walk & (V == 1)
    zf = np.where(dry, Z, 0).astype(np.float64)
    wsum = ndimage.uniform_filter(dry.astype(np.float64), size=SMOOTH, mode="constant")
    zsum = ndimage.uniform_filter(zf, size=SMOOTH, mode="constant")
    zs_ = np.where(wsum > 0, zsum / np.maximum(wsum, 1e-9), np.nan)
    gx_, gy_ = np.gradient(zs_, cs)
    slope = np.degrees(np.arctan(np.hypot(gx_, gy_)))
    slope = np.where(np.isnan(slope), 0, slope)
    cls = np.zeros((GX, GY), dtype=np.uint8)
    cls[dry & (slope >= GENTLE_DEG)] = GENTLE
    cls[dry & (slope >= STEEP_DEG)] = STEEP
    # (l'intérieur : un plafond bas au-dessus de la surface ; la base sur un morceau assez grand)
    ceilings = {}                                          # nœud -> hauteur du plafond
    for k, s in ceiling_data.items():
        kx, ky = k // ny, k % ny
        for key, h in decode_ceiling(s).items():
            c, layer = key // 64, key % 64
            gx, gy = kx * C + c // C, ky * C + c % C
            ceilings[(gx * GY + gy) * 64 + layer] = h
    under = np.zeros((GX, GY), dtype=bool)
    floor_inside = set()
    for nid, h in ceilings.items():
        layer = nid % 64
        cell = nid // 64
        gx, gy = cell // GY, cell % GY
        if layer == 0:
            if walk[gx, gy] and 0 < h - Z[gx, gy] <= INDOOR_GAP:
                under[gx, gy] = True
        elif nid in fz and 0 < h - fz[nid] <= INDOOR_GAP:
            floor_inside.add(nid)
    labels, count = ndimage.label(under, structure=np.ones((3, 3)))
    sizes = ndimage.sum(under, labels, index=np.arange(1, count + 1))
    big = np.zeros(count + 1, dtype=bool)
    big[1:] = sizes >= INDOOR_MIN
    indoor = big[labels] & under
    city = np.zeros((GX, GY), dtype=bool)
    caps = capitals(cont)
    if caps:
        xs = head["cx0"] * TILE + (np.arange(GX) + 0.5) * cs
        ys = head["cy0"] * TILE + (np.arange(GY) + 0.5) * cs
        ci, cj = np.floor(xs / CAP_CELL).astype(int), np.floor(ys / CAP_CELL).astype(int)
        for i, j in caps:
            xi = np.nonzero(ci == i)[0]
            yj = np.nonzero(cj == j)[0]
            if len(xi) and len(yj):
                city[xi[0]:xi[-1] + 1, yj[0]:yj[-1] + 1] = True
    cls[indoor] = INDOOR
    cls[indoor & city] = CITY

    def in_city(nid):
        cell = nid // 64
        return bool(city[cell // GY, cell % GY])

    def node_class(nid):
        if nid % 64 == 0:
            cell = nid // 64
            return int(cls[cell // GY, cell % GY])
        if nid in floor_inside:
            return CITY if in_city(nid) else INDOOR
        return NORMAL

    # --- La couche du sol et la plus basse, par case à étages ---------------
    ground = {}                                           # (gx, gy) -> couche
    for k, s in terrain_data.items():
        kx, ky = k // ny, k % ny
        for c, layer in decode_terrain(s).items():
            ground[(kx * C + c // C, ky * C + c % C)] = layer

    # --- Les ascenseurs ------------------------------------------------------
    def nearest_node(x, y, z, reach):
        """le nœud (relié) le plus proche d'un point du monde et d'une hauteur"""
        gx0 = int((x - head["cx0"] * TILE) // cs)
        gy0 = int((y - head["cy0"] * TILE) // cs)
        best, best_cost = None, None
        for gx in range(gx0 - reach, gx0 + reach + 1):
            for gy in range(gy0 - reach, gy0 + reach + 1):
                if not (0 <= gx < GX and 0 <= gy < GY):
                    continue
                cx = head["cx0"] * TILE + (gx + 0.5) * cs
                cy = head["cy0"] * TILE + (gy + 0.5) * cs
                flat = math.hypot(cx - x, cy - y)
                for layer in range(64):
                    nid = (gx * GY + gy) * 64 + layer
                    if layer == 0:
                        if not (walk[gx, gy] and (stepbits[gx, gy] or anydiag[gx, gy] or nid in linked)):
                            continue
                    elif nid not in fz:
                        break                             # (les étages d'une case se suivent)
                    elif nid not in linked:
                        continue
                    cost = flat + 2 * abs(height(nid) - z)
                    if best_cost is None or cost < best_cost:
                        best, best_cost = nid, cost
        return best, best_cost

    lifts = []
    for x, y, ztop, zbot, site in lift_pairs(spf, cont):
        top, ct = nearest_node(x, y, ztop, LIFT_REACH)
        bot, cb = nearest_node(x, y, zbot, LIFT_REACH)
        if top is None or bot is None or top == bot:
            print("  ascenseur ignoré : %s" % site)
            continue
        print("  ascenseur %s : haut couche %d (%.0f yd pour %.0f), bas couche %d (%.0f yd pour %.0f)" % (
            site, top % 64, height(top), ztop, bot % 64, height(bot), zbot))
        lifts.append((top, bot, LIFT_SECS))
        linked.add(top)
        linked.add(bot)

    # --- Les tuiles d'étages -------------------------------------------------
    # Seuls les étages sont listés. Les pas d'une base vers un étage voisin sont
    # écrits sur l'étage, comme pas entrants (le jeu les retrouve en regardant
    # les étages des huit cases voisines). Les pas de la base de plus d'une case
    # (des chutes) sont laissés de côté, comme avant.
    inward = {}                                           # étage -> { (dx, dy) : depuis la base de la case à (dx, dy) }
    dropped = 0
    for nid, es in out.items():
        if nid % 64:
            continue
        cell = nid // 64
        gx, gy = cell // GY, cell % GY
        for dx, dy, to in es:
            if to == 0:
                dropped += 1
                continue
            if (dx, dy) not in DIRECTION:
                dropped += 1
                continue
            target = ((gx + dx) * GY + gy + dy) * 64 + to
            inward.setdefault(target, set()).add((-dx, -dy))
    # (les petits îlots d'étages posés au-dessus d'un sol sec et praticable : des
    # rochers, des tables, des toits, des mezzanines ; le chemin passe dessous
    # ou à côté. Un îlot au-dessus de l'eau ou du vide, un pont, est gardé, comme
    # ceux d'un ascenseur ou d'un passage)
    keep = set()
    for top, bot, _ in lifts:
        keep.add(top)
        keep.add(bot)
    for p in PASSAGES:
        for side in ("a", "b"):
            c, x, y, z = p[side]
            if c == cont:
                nid, _ = nearest_node(x, y, z, PASSAGE_REACH)
                if nid is not None:
                    keep.add(nid)
    # (un îlot qui relie deux morceaux de la surface de base que rien d'autre ne
    # relie, une rampe vers un ascenseur, un escalier, est gardé aussi : les
    # morceaux de la base, d'après ses pas dans un sens ou dans l'autre)
    flat = np.arange(GX * GY).reshape(GX, GY)
    ia = np.concatenate([flat[:-1, :][(px[:-1, :] | mx[1:, :])], flat[:, :-1][(py[:, :-1] | my[:, 1:])]])
    ib = np.concatenate([flat[1:, :][(px[:-1, :] | mx[1:, :])], flat[:, 1:][(py[:, :-1] | my[:, 1:])]])
    graph = coo_matrix((np.ones(len(ia), dtype=np.int8), (ia, ib)), shape=(GX * GY, GX * GY))
    _, piece = connected_components(graph, directed=False)
    neighbours, bases = {}, {}
    for nid, es in out.items():
        cell = nid // 64
        for dx, dy, to in es:
            b = ((cell // GY + dx) * GY + cell % GY + dy) * 64 + to
            if nid % 64 and to:
                neighbours.setdefault(nid, []).append(b)
                neighbours.setdefault(b, []).append(nid)
            elif nid % 64:
                bases.setdefault(nid, set()).add(piece[b // 64])
            elif to:
                bases.setdefault(b, set()).add(piece[cell])
    pruned, seen = set(), set()
    for start in fz:
        if start in seen or start not in linked:
            continue
        comp, stack, solid, touched = [], [start], True, set()
        seen.add(start)
        while stack:
            nid = stack.pop()
            comp.append(nid)
            cell = nid // 64
            gx, gy = cell // GY, cell % GY
            if not walk[gx, gy] or V[gx, gy] == 2 or nid in keep:
                solid = False
            touched |= bases.get(nid, set())
            for b in neighbours.get(nid, ()):
                if b not in seen and b in fz:
                    seen.add(b)
                    stack.append(b)
        if solid and len(touched) <= 1 and len(comp) <= ISLAND:
            pruned.update(comp)

    by_tile = {}                                          # k -> { case locale : [étage, ...] }
    for nid in fz:
        if nid not in linked or nid in pruned:
            continue                                      # (un étage sans aucun pas, un îlot élagué)
        cell = nid // 64
        gx, gy = cell // GY, cell % GY
        k = (gx // C) * ny + gy // C
        lc = (gx % C) * C + gy % C
        by_tile.setdefault(k, {}).setdefault(lc, []).append(nid)
    tiles = {}
    kept_floors = 0
    floor_classes = {}
    columns = ("delta", "ground", "low", "count", "layer", "base", "same", "inmask", "nextra", "cls", "extra")
    for k in sorted(by_tile):
        kx, ky = k // ny, k % ny
        # (en colonnes : la compression y gagne beaucoup)
        cols = {name: bytearray() for name in columns}
        prev = -1
        cells = sorted(by_tile[k])
        for lc in cells:
            nodes = sorted(by_tile[k][lc], key=lambda n: n % 64)
            gx, gy = kx * C + lc // C, ky * C + lc % C
            cellbase = (gx * GY + gy) * 64
            delta = lc - prev
            prev = lc
            if delta < 255:
                cols["delta"].append(delta)
            else:
                cols["delta"] += bytes((255, delta >> 8, delta & 255))
            g = ground.get((gx, gy), 0)
            cols["ground"].append(255 if g is None else g)
            # (la plus basse des surfaces de la case, la base comprise)
            cands = list(nodes)
            if walk[gx, gy]:
                cands.append(cellbase)
            cols["low"].append(min(cands, key=height) % 64)
            cols["count"].append(len(nodes))
            for nid in nodes:
                layer = nid % 64
                cols["layer"].append(layer + 64 * (value(nid) == 2) + 128 * int(roadcov[gx, gy]))
                base, same, extra = 0, 0, []
                for dx, dy, to in sorted(out.get(nid, ())):
                    d = DIRECTION.get((dx, dy))
                    if d is not None and to == 0 and not base >> d & 1:
                        base |= 1 << d
                    elif d is not None and to == layer and not same >> d & 1:
                        same |= 1 << d
                    else:
                        extra.append((dx, dy, to))
                # (les pas entrants depuis la base : un bit par direction, vers la base voisine)
                inmask = 0
                for dx, dy in inward.get(nid, ()):
                    inmask |= 1 << DIRECTION[(dx, dy)]
                c = node_class(nid)
                floor_classes[c] = floor_classes.get(c, 0) + 1
                cols["base"].append(base)
                cols["same"].append(same)
                cols["inmask"].append(inmask)
                cols["nextra"].append(len(extra))
                cols["cls"].append(c)
                for dx, dy, to in extra:
                    cols["extra"] += bytes((dx + 64, dy + 64, to))
                kept_floors += 1
        n = len(cells)
        buf = bytes((n >> 8, n & 255)) + b"".join(bytes(cols[name]) for name in columns)
        tiles[k] = base64.b64encode(zlib.compress(buf, 9)).decode("ascii")

    # --- Le graphe des passages entre tuiles (les longues marches) -----------
    kept = {nid for k in by_tile for lst in by_tile[k].values() for nid in lst}
    portal_tiles, portal_stats, _ = portals.build({
        "GX": GX, "GY": GY, "C": C, "ny": ny, "cs": cs, "walk": walk, "V": V, "step": step, "road": road,
        "roadcov": roadcov, "cls": cls, "out": out, "kept": kept, "fval": fval, "node_class": node_class,
        "lifts": lifts,
    })

    clusters, terrain = {}, {}
    clsbyte = (cls + 8 * diagbits).astype(np.uint8)
    for k in grids:
        kx, ky = k // ny, k % ny
        sl = (slice(kx * C, (kx + 1) * C), slice(ky * C, (ky + 1) * C))
        if not kind[sl].any():
            continue
        clusters[k] = base64.b64encode(zlib.compress(code[sl].reshape(-1).tobytes(), 9)).decode("ascii")
        terrain[k] = base64.b64encode(zlib.compress(clsbyte[sl].reshape(-1).tobytes(), 9)).decode("ascii")

    def endpoint(x, y, z):
        nid, cost = nearest_node(x, y, z, PASSAGE_REACH)
        return None if nid is None else nid % 64

    dry_n = int(dry.sum())
    stats = {
        "tuiles": len(clusters),
        "cases franchissables": int(walk.sum()),
        "routes": int(road.sum()),
        "pentes douces": int((cls == GENTLE).sum()),
        "pentes raides": int((cls == STEEP).sum()),
        "intérieur": int((cls == INDOOR).sum()),
        "intérieur de cité": int((cls == CITY).sum()),
        "étages": len(fz),
        "étages gardés": kept_floors,
        "étages à l'intérieur": floor_classes.get(INDOOR, 0) + floor_classes.get(CITY, 0),
        "pas refusés": rejected,
        "pas de base repliés dans le masque": folded,
        "pas de la base laissés de côté": dropped,
        "diagonales sans chemin en L": lonly,
        "diagonales différentes de la règle": int(np.unpackbits(diagbits[..., None], axis=-1).sum()),
        "ascenseurs": len(lifts),
    }
    stats.update(portal_stats)
    print("  sol sec %d cases : %.1f %% en pente douce, %.1f %% raide" % (
        dry_n, 100 * stats["pentes douces"] / max(1, dry_n), 100 * stats["pentes raides"] / max(1, dry_n)))
    lift_rows = []
    for top, bot, secs in lifts:
        a, b = top // 64, bot // 64
        lift_rows.append((a // GY, a % GY, top % 64, b // GY, b % GY, bot % 64, secs))
    return head, clusters, terrain, tiles, lift_rows, endpoint, stats, portal_tiles


def main():
    spf = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SPF
    version = build_roads.spf_version(spf)
    roads = build_roads.road_cells(spf)
    endpoints = {}
    for cont, name in CONTINENTS.items():
        print(name)
        head, clusters, terrain, tiles, lifts, endpoint, stats, portal_tiles = build(spf, cont, roads.get(cont, {}))
        for p in PASSAGES:
            for side in ("a", "b"):
                c, x, y, z = p[side]
                if c == cont:
                    endpoints[(p["name"], side)] = endpoint(x, y, z)
        lines = [
            "-- Généré par tools/nav/build_nav.py : ne pas modifier à la main.",
            "-- La grille de marche des itinéraires (Travel/Nav.lua) : %s." % name,
            "-- Source : Shortest Path Forever %s de cjber (https://github.com/cjber/shortest-path-forever)," % version,
            "-- son maillage de marche (Nav/Nav%d*.lua, format 4, extrait du terrain du client avec les outils de" % cont,
            "-- TrinityCore), ses ascenseurs (Data/Transports.lua) et la couverture de ses routes (Data/RoadCells.lua).",
            "-- Données dérivées, sous licence GPL-3.0-or-later (voir LICENSE).",
            "-- Une tuile k (0 d'abord) couvre x dans [(cx0 + k // ny) T, +T), y dans [(cy0 + k %% ny) T, +T),",
            "-- T = 1600 / 3 yards, en cells x cells cases, x d'abord. tiles : la surface de base, un octet par case,",
            "-- 48 + type (0 bloquée, 1 sol, 2 eau) + 4 * pas permis (1 +x, 2 -x, 4 +y, 8 -y) + 64 * route.",
            "-- terrain : un octet par case, terrain (0 normal, 2 pente douce, 3 pente raide, 4 intérieur,",
            "-- 5 intérieur de cité) + 8 * diagonales à inverser (1 +x+y, 2 +x-y, 4 -x+y, 8 -x-y) : un pas en",
            "-- diagonale de base à base passe si l'un des deux chemins en L passe, sauf si son bit dit l'inverse.",
            "-- floors : les étages et les pas de plus (le format est décrit dans tools/nav/build_nav.py).",
            "-- portals : le graphe des passages entre tuiles, pour les longues marches (tools/nav/portals.py).",
            "-- lifts : { gx, gy, couche du haut, gx, gy, couche du bas, secondes } (cases de la grille).",
            "-- Chaque tuile est compressée (zlib) puis en base64. x vers le nord, y vers l'ouest (UnitPosition).",
            "local _, root = ...",
            "local ns = root.Plus                 -- (le code de l'addon lit ns.Nav, ns.Passages : root.Plus)",
            "",
            "ns.Nav = ns.Nav or {}",
            "ns.Nav[%d] = {" % cont,
            "\tcx0 = %d, cy0 = %d, nx = %d, ny = %d, cells = %d, diag = true," % (
                head["cx0"], head["cy0"], head["nx"], head["ny"], head["cells"]),
            "\tlifts = {",
        ]
        for row in lifts:
            lines.append("\t\t{ %d, %d, %d, %d, %d, %d, %d }," % row)
        lines += ["\t},", "\ttiles = {"]
        for k in sorted(clusters):
            lines.append('\t\t[%d] = "%s",' % (k + 1, clusters[k]))
        lines += ["\t},", "\tterrain = {"]
        for k in sorted(terrain):
            lines.append('\t\t[%d] = "%s",' % (k + 1, terrain[k]))
        lines += ["\t},", "\tfloors = {"]
        for k in sorted(tiles):
            lines.append('\t\t[%d] = "%s",' % (k + 1, tiles[k]))
        lines += ["\t},", "\tportals = {"]
        for k in sorted(portal_tiles):
            lines.append('\t\t[%d] = "%s",' % (k + 1, portal_tiles[k]))
        lines += ["\t},", "}", ""]
        path = OUT % cont
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines))
        floors_kb = sum(len(s) for s in tiles.values()) / 1024
        terrain_kb = sum(len(s) for s in terrain.values()) / 1024
        portals_kb = sum(len(s) for s in portal_tiles.values()) / 1024
        print("  %s ; étages : %.0f Ko ; terrain : %.0f Ko ; passages : %.0f Ko ; %s : %.0f Ko" % (
            ", ".join("%s %s" % (v, k) for k, v in stats.items()), floors_kb, terrain_kb, portals_kb, path,
            os.path.getsize(path) / 1024))

    lines = [
        "-- Généré par tools/nav/build_nav.py : ne pas modifier à la main.",
        "-- Les passages des itinéraires (Travel/Graph.lua) : un portail ou un tram entre deux points d'un",
        "-- continent. Source : Shortest Path Forever %s de cjber (Data/Portals.lua, Data/Transports.lua)," % version,
        "-- sous licence GPL-3.0-or-later (voir LICENSE).",
        "-- { kind, name, faction, secs, a = { cont, x, y, couche }, b = { ... } } : on va dans les deux sens.",
        "local _, root = ...",
            "local ns = root.Plus                 -- (le code de l'addon lit ns.Nav, ns.Passages : root.Plus)",
        "",
        "ns.Passages = {",
    ]
    for p in PASSAGES:
        def side(s):
            c, x, y, _ = p[s]
            layer = endpoints.get((p["name"], s))
            return "{ %d, %.1f, %.1f, %s }" % (c, x, y, "nil" if layer is None else layer)
        lines.append('\t{ kind = "%s", name = "%s", faction = "%s", secs = %d, a = %s, b = %s },' % (
            p["kind"], p["name"], p["faction"], p["secs"], side("a"), side("b")))
    lines += ["}", ""]
    with open(OUT_PASSAGES, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("Passages : %s" % ", ".join("%s %s" % (k, v) for k, v in sorted(endpoints.items())))


if __name__ == "__main__":
    main()
