"""La grille de marche des itinéraires (MyMapIsRich/Plus/Data/Nav0.lua, Nav1.lua)
et les passages (MyMapIsRich/Plus/Data/Passages.lua).

Les cases (environ 8 yards) viennent du maillage de marche de Shortest Path
Forever (cjber, GPL-3.0-or-later ; Nav/NavN*.lua, extrait du terrain du client
avec les outils de TrinityCore). Une case a une surface de base (le sol, en
général) et parfois des étages au-dessus ou au-dessous : un pont, la rue d'une
ville bâtie sur ses caves, les étages d'un bâtiment, les anneaux de Fossoyeuse.
Ce script calcule hors du jeu les pas permis, avec les règles de SPF
(Routing/PathGrid.lua) :
  - un pas fermé par les données (une falaise, un mur) ne passe pas ;
  - une montée de plus de 50 degrés ne passe pas ;
  - une pente raide (entre 50 et 61,6 degrés) ne se prend qu'en descendant ;
  - d'une tuile à l'autre (les données n'y ferment rien), une chute de plus
    de 14,57 yards ne passe pas non plus (entre deux surfaces de base).
Les étages (format 3 de SPF) : chaque pas d'un étage nomme la couche où il
arrive ; s'y ajoutent les pas à sens unique et les chutes. Les hauteurs ne
sont pas livrées : le jeu ne lit que les pas permis.
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

Les étages d'une tuile (floors), compressés de même : des groupes par case,
dans l'ordre des cases. Un groupe : l'écart à la case du groupe d'avant
(un octet, ou 255 puis deux octets), la couche du sol (255 : inconnue), la
couche la plus basse, le nombre de nœuds, puis chaque nœud : sa couche (0 la
base, i le i-ème étage depuis le bas), son type (1 sol, 2 eau, + 4 * route),
le masque de ses pas d'une case (1 +x, 2 -x, 4 +y, 8 -y, 16 +x+y, 32 +x-y,
64 -x+y, 128 -x-y), la couche d'arrivée de chacun dans l'ordre des bits,
puis ses autres pas : leur nombre et, pour chacun, dx + 64, dy + 64, couche.
Un nœud de couche 0 n'y a que les pas que l'octet de base ne dit pas (vers un
étage, une chute, un sens unique).

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
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(HERE, "..", "roads"))
import build_roads  # noqa: E402  (la lecture des routes et de l'en-tête des cartes)

DEFAULT_SPF = build_roads.DEFAULT_SPF
OUT = os.path.join(REPO, "MyMapIsRich", "Plus", "Data", "Nav%d.lua")
OUT_PASSAGES = os.path.join(REPO, "MyMapIsRich", "Plus", "Data", "Passages.lua")
CONTINENTS = {0: "Royaumes de l'Est", 1: "Kalimdor"}
TILE = 1600 / 3
TAN50 = math.tan(math.radians(50))
FALL = 14.57                 # yd : la plus haute chute permise (Player::HandleFall)
ROAD_MIN = 1                 # couverture minimale d'une case de route (sur 63)
LIFT_SECS = 22               # s : l'attente moyenne et la montée d'un ascenseur
LIFT_REACH = 3               # cases : la plateforme d'un ascenseur est cherchée jusque-là
PASSAGE_REACH = 4            # cases : de même pour le bout d'un passage
ISLAND = 30                  # étages : un îlot plus petit, au-dessus d'un sol sec, est élagué

DX = [1, -1, 0, 0, 1, 1, -1, -1]
DY = [0, 0, 1, -1, 1, -1, 1, -1]
DIRECTION = {(DX[d], DY[d]): d for d in range(8)}
BIT = {1: 1, -1: 2}          # (le pas +x / -x de l'octet de base ; y : * 4)

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
    """{ k: chaîne décompressée } d'un champ des fichiers NavN_*.lua"""
    out = {}
    for f in files:
        text = open(f, encoding="utf-8").read()
        for m in re.finditer(r"data\.packed\.%s\[(\d+)\] = \{([^}]*)\}" % name, text):
            blocks = re.findall(r'"([^"]*)"', m.group(2))
            out[int(m.group(1)) - 1] = b"".join(zlib.decompress(base64.b64decode(b)) for b in blocks).decode("ascii")
    return out


def decode_grid(s, C, steep_map):
    """type (0 bloquée, 1 sol, 2 eau, 3 pente raide) et drapeaux (1 : pas +x fermé, 2 : pas +y fermé)"""
    val = np.zeros(C * C, dtype=np.int8)
    flags = np.zeros(C * C, dtype=np.uint8)
    n, v, f = 0, 0, 0
    for ch in s:
        sym = B64[ch]
        if sym < 48:
            v, f = sym // 16, sym % 16
            if steep_map and v == 1 and f >= 8:
                v, f = 3, f - 8
            reps = 1
        else:
            reps = sym - 47
        val[n:n + reps] = v
        flags[n:n + reps] = f
        n += reps
    return val, flags


def decode_heights(s, val, C, zstep):
    """Les hauteurs (yd) des cases franchissables (PathGrid.lua : decodeHeights)"""
    z = np.full(C * C, np.nan, dtype=np.float32)
    zu = [None] * (C * C)
    pos, rep, delta, last = 0, 0, 0, 0
    for i in range(C * C):
        if val[i] == 0:
            continue
        pred = None
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


def decode_floors(s, C):
    """Les étages d'une tuile (format 3, PathGrid.lua : decodeFloors, decodeLinks) :
    leurs cases, types, hauteurs (yd), couches, et les pas bruts
    (nœud, dx, dy, couche d'arrivée, dans les deux sens ?) ; un nœud < C * C est
    la surface de base de cette case, sinon le (nœud - C * C)-ième étage."""
    N = C * C
    n = num(s, 0, 3)
    pos = 3
    cells, vals, zs, masks, lpos = [], [], [], [], []
    lc = 0
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
        mask = num(s, pos + 3, 2)
        masks.append(mask)
        lpos.append(pos + 5)
        pos += 5 + bin(mask).count("1")
    first = {}
    for i, c in enumerate(cells):
        first.setdefault(c, i)
    layers = [i - first[c] + 1 for i, c in enumerate(cells)]
    links = []
    for i in range(n):
        p, bits = lpos[i], masks[i]
        for d in range(8):
            if bits >> d & 1:
                links.append((N + i, DX[d], DY[d], B64[s[p]], True))
                p += 1
    steps = num(s, pos, 3)
    at = pos + 3
    record = 0
    for _ in range(steps):
        sym = B64[s[at]]
        at += 1
        if sym < 63:
            record += sym
        else:
            record += 63 + num(s, at, 3)
            at += 3
        kind = B64[s[at]]
        links.append((record, DX[kind % 8], DY[kind % 8], B64[s[at + 1]], kind < 8))
        at += 2
    drops = num(s, at, 3)
    at += 3
    for _ in range(drops):
        node = num(s, at, 3)
        links.append((node, B64[s[at + 3]] - 8, B64[s[at + 4]] - 8, B64[s[at + 5]], False))
        at += 8
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
    main = open(os.path.join(spf, "Nav", "Nav%d.lua" % cont), encoding="utf-8").read()[:20000]
    head = build_roads.nav_header(spf, cont)
    C, nx, ny = head["cells"], head["nx"], head["ny"]
    if not re.search(r"\bformat = 3,", main):
        raise SystemExit("Nav%d.lua : le format 3 de SPF est attendu" % cont)
    zstep = float(re.search(r"\bzstep = ([\d.]+),", main).group(1))
    steep_map = re.search(r"\bsteep = true,", main) is not None
    cs = TILE / C
    N = C * C
    grids, heights = packed(files, "grid"), packed(files, "height")
    floor_data, terrain_data = packed(files, "floor"), packed(files, "terrain")
    GX, GY = nx * C, ny * C
    V = np.zeros((GX, GY), dtype=np.int8)
    CLX = np.zeros((GX, GY), dtype=bool)
    CLY = np.zeros((GX, GY), dtype=bool)
    Z = np.full((GX, GY), np.nan, dtype=np.float32)
    for k, s in grids.items():
        val, flags = decode_grid(s, C, steep_map)
        z = decode_heights(heights.get(k, ""), val, C, zstep) if k in heights else np.full(C * C, np.nan, np.float32)
        kx, ky = k // ny, k % ny
        sl = (slice(kx * C, (kx + 1) * C), slice(ky * C, (ky + 1) * C))
        V[sl] = val.reshape(C, C)
        CLX[sl] = (flags & 1).astype(bool).reshape(C, C)
        CLY[sl] = (flags & 2).astype(bool).reshape(C, C)
        Z[sl] = z.reshape(C, C)
    walk = V != 0
    steep = V == 3
    # (un cas sans hauteur : on ne sait rien, on n'y passe pas)
    walk &= ~np.isnan(Z)

    def moves(axis):
        """pas permis vers +axe et vers -axe (deux grilles booléennes)"""
        a = [slice(None), slice(None)]
        b = [slice(None), slice(None)]
        a[axis] = slice(0, -1)
        b[axis] = slice(1, None)
        a, b = tuple(a), tuple(b)
        both = walk[a] & walk[b]
        rise = Z[b] - Z[a]
        idx = np.arange(V.shape[axis] - 1)
        border = (idx % C) == C - 1                      # (le pas passe d'une tuile à l'autre)
        border = border[:, None] if axis == 0 else border[None, :]
        closed = (CLX if axis == 0 else CLY)[a] & ~border
        anysteep = steep[a] | steep[b]
        ok = both & ~closed
        up = ok & (rise <= TAN50 * cs) & (~anysteep | (rise <= 0)) & ~(border & (rise < -FALL))
        down = ok & (-rise <= TAN50 * cs) & (~anysteep | (-rise <= 0)) & ~(border & (-rise < -FALL))
        plus = np.zeros(V.shape, dtype=bool)
        minus = np.zeros(V.shape, dtype=bool)
        plus[a] = up                                      # de a vers b (+axe)
        minus[b] = down                                   # de b vers a (-axe)
        return plus, minus

    px, mx = moves(0)
    py, my = moves(1)
    kind = np.where(walk, np.where(V == 2, 2, 1), 0).astype(np.uint8)
    roadcov = build_roads.coverage_grid(head, roads) >= ROAD_MIN
    road = roadcov & walk
    stepbits = (px.astype(np.uint8) + 2 * mx + 4 * py + 8 * my).astype(np.uint8)
    code = (48 + kind + 4 * stepbits + 64 * road).astype(np.uint8)

    # --- Les étages : leurs nœuds, puis leurs pas résolus -------------------
    # un nœud : (gx * GY + gy) * 64 + couche ; fz, fval : hauteur et type d'un étage
    fz, fval = {}, {}
    raw = []                                              # (k, cells, layers, links)
    for k, s in floor_data.items():
        cells, vals, zs, layers, links = decode_floors(s, C)
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

    def allowed(a, b, dx, dy):
        """la règle de pente de SPF (neighbour) : montée de 50° au plus, pente raide en descente seulement"""
        rise = height(b) - height(a)
        if rise > TAN50 * math.hypot(dx, dy) * cs:
            return False
        if value(a) == 3 or value(b) == 3:
            return rise <= 0
        return True

    out = {}                                              # nœud -> { (dx, dy, couche) }
    linked = set()                                        # les nœuds touchés par un pas

    def add(a, dx, dy, layer):
        cell = a // 64
        gx, gy = cell // GY + dx, cell % GY + dy
        if not exists(gx, gy, layer):
            return False
        b = (gx * GY + gy) * 64 + layer
        if a == b or not allowed(a, b, dx, dy):
            return False
        out.setdefault(a, set()).add((dx, dy, layer))
        linked.add(a)
        linked.add(b)
        return True

    rejected = 0
    for k, cells, layers, links in raw:
        kx, ky = k // ny, k % ny
        for node, dx, dy, layer, both in links:
            if node < N:
                c, own = node, 0
            else:
                c, own = cells[node - N], layers[node - N]
            gx, gy = kx * C + c // C, ky * C + c % C
            if not exists(gx, gy, own):
                rejected += 1
                continue
            a = (gx * GY + gy) * 64 + own
            ok = add(a, dx, dy, layer)
            if both and exists(gx + dx, gy + dy, layer):
                b = ((gx + dx) * GY + gy + dy) * 64 + layer
                ok = add(b, -dx, -dy, own) or ok
            if not ok:
                rejected += 1

    # (les pas de base à base que l'octet de base dit déjà ne sont pas répétés)
    def base_can(gx, gy, bit):
        if gx < 0 or gy < 0 or gx >= GX or gy >= GY:
            return False
        return bool(stepbits[gx, gy] & bit)

    def covered(gx, gy, dx, dy):
        if dx == 0 or dy == 0:
            return base_can(gx, gy, BIT[dx] if dx else 4 * BIT[dy])
        bx, by = BIT[dx], 4 * BIT[dy]
        return (base_can(gx, gy, bx) and base_can(gx + dx, gy, by)) or (base_can(gx, gy, by) and base_can(gx, gy + dy, bx))

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
                        if not (walk[gx, gy] and (stepbits[gx, gy] or nid in linked)):
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
    # les étages des huit cases voisines). Les pas de base à base que l'octet de
    # base ne dit pas (sens uniques, chutes) sont laissés de côté, comme avant.
    inward = {}                                           # étage -> { (dx, dy) : depuis la base de la case à (dx, dy) }
    dropped = 0
    for nid, es in out.items():
        if nid % 64:
            continue
        cell = nid // 64
        gx, gy = cell // GY, cell % GY
        for dx, dy, to in es:
            if to == 0:
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
    for k in sorted(by_tile):
        kx, ky = k // ny, k % ny
        # (en colonnes : la compression y gagne beaucoup)
        cols = {name: bytearray() for name in ("delta", "ground", "low", "count", "layer", "base", "same", "inmask", "nextra", "extra")}
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
                cols["base"].append(base)
                cols["same"].append(same)
                cols["inmask"].append(inmask)
                cols["nextra"].append(len(extra))
                for dx, dy, to in extra:
                    cols["extra"] += bytes((dx + 64, dy + 64, to))
                kept_floors += 1
        n = len(cells)
        buf = bytes((n >> 8, n & 255)) + b"".join(bytes(cols[name]) for name in
                                                  ("delta", "ground", "low", "count", "layer", "base", "same", "inmask", "nextra", "extra"))
        tiles[k] = base64.b64encode(zlib.compress(buf, 9)).decode("ascii")

    clusters, raw_total = {}, 0
    for k in grids:
        kx, ky = k // ny, k % ny
        tile = code[kx * C:(kx + 1) * C, ky * C:(ky + 1) * C].reshape(-1).tobytes()
        if not (kind[kx * C:(kx + 1) * C, ky * C:(ky + 1) * C].any()):
            continue
        raw_total += len(tile)
        clusters[k] = base64.b64encode(zlib.compress(tile, 9)).decode("ascii")

    def endpoint(x, y, z):
        nid, cost = nearest_node(x, y, z, PASSAGE_REACH)
        return None if nid is None else nid % 64

    stats = {
        "tuiles": len(clusters),
        "cases franchissables": int(walk.sum()),
        "routes": int(road.sum()),
        "étages": len(fz),
        "étages gardés": kept_floors,
        "pas refusés": rejected,
        "sauts de la base vers un étage ignorés": dropped,
        "ascenseurs": len(lifts),
    }
    lift_rows = []
    for top, bot, secs in lifts:
        a, b = top // 64, bot // 64
        lift_rows.append((a // GY, a % GY, top % 64, b // GY, b % GY, bot % 64, secs))
    return head, clusters, tiles, lift_rows, endpoint, stats


def main():
    spf = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SPF
    version = build_roads.spf_version(spf)
    roads = build_roads.road_cells(spf)
    endpoints = {}
    for cont, name in CONTINENTS.items():
        print(name)
        head, clusters, tiles, lifts, endpoint, stats = build(spf, cont, roads.get(cont, {}))
        for p in PASSAGES:
            for side in ("a", "b"):
                c, x, y, z = p[side]
                if c == cont:
                    endpoints[(p["name"], side)] = endpoint(x, y, z)
        lines = [
            "-- Généré par tools/nav/build_nav.py : ne pas modifier à la main.",
            "-- La grille de marche des itinéraires (Travel/Nav.lua) : %s." % name,
            "-- Source : Shortest Path Forever %s de cjber (https://github.com/cjber/shortest-path-forever)," % version,
            "-- son maillage de marche (Nav/Nav%d*.lua, extrait du terrain du client avec les outils de TrinityCore)," % cont,
            "-- ses ascenseurs (Data/Transports.lua) et la couverture de ses routes (Data/RoadCells.lua). Données",
            "-- dérivées, sous licence GPL-3.0-or-later (voir LICENSE).",
            "-- Une tuile k (0 d'abord) couvre x dans [(cx0 + k // ny) T, +T), y dans [(cy0 + k %% ny) T, +T),",
            "-- T = 1600 / 3 yards, en cells x cells cases, x d'abord. tiles : la surface de base, un octet par case,",
            "-- 48 + type (0 bloquée, 1 sol, 2 eau) + 4 * pas permis (1 +x, 2 -x, 4 +y, 8 -y) + 64 * route.",
            "-- floors : les étages et les pas de plus (le format est décrit dans tools/nav/build_nav.py).",
            "-- lifts : { gx, gy, couche du haut, gx, gy, couche du bas, secondes } (cases de la grille).",
            "-- Chaque tuile est compressée (zlib) puis en base64. x vers le nord, y vers l'ouest (UnitPosition).",
            "local _, ns = ...",
            "",
            "ns.Nav = ns.Nav or {}",
            "ns.Nav[%d] = {" % cont,
            "\tcx0 = %d, cy0 = %d, nx = %d, ny = %d, cells = %d," % (head["cx0"], head["cy0"], head["nx"], head["ny"], head["cells"]),
            "\tlifts = {",
        ]
        for row in lifts:
            lines.append("\t\t{ %d, %d, %d, %d, %d, %d, %d }," % row)
        lines += ["\t},", "\ttiles = {"]
        for k in sorted(clusters):
            lines.append('\t\t[%d] = "%s",' % (k + 1, clusters[k]))
        lines += ["\t},", "\tfloors = {"]
        for k in sorted(tiles):
            lines.append('\t\t[%d] = "%s",' % (k + 1, tiles[k]))
        lines += ["\t},", "}", ""]
        path = OUT % cont
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines))
        floors_kb = sum(len(s) for s in tiles.values()) / 1024
        print("  %s ; étages : %.0f Ko ; %s : %.0f Ko" % (", ".join("%s %s" % (v, k) for k, v in stats.items()),
                                                         floors_kb, path, os.path.getsize(path) / 1024))

    lines = [
        "-- Généré par tools/nav/build_nav.py : ne pas modifier à la main.",
        "-- Les passages des itinéraires (Travel/Graph.lua) : un portail ou un tram entre deux points d'un",
        "-- continent. Source : Shortest Path Forever %s de cjber (Data/Portals.lua, Data/Transports.lua)," % version,
        "-- sous licence GPL-3.0-or-later (voir LICENSE).",
        "-- { kind, name, faction, secs, a = { cont, x, y, couche }, b = { ... } } : on va dans les deux sens.",
        "local _, ns = ...",
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
