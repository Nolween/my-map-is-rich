"""Le graphe des passages entre tuiles (le champ portals de Plus/Data/NavN.lua), pour les longues marches :
Travel/Nav.lua cherche d'abord sur ce graphe, puis précise le chemin tuile par tuile.

Les pas sont ceux que le jeu lit dans la grille (Travel/Nav.lua : Expand) : de base à base (le masque du
maillage, diagonales comprises), de la base vers un étage voisin, d'un étage vers la base, vers le même
étage ou ailleurs (sauts, chutes), et les ascenseurs. Chacun coûte sa longueur fois le prix du terrain où
il entre, au style Équilibré (Travel/Nav.lua : Nav.STYLES.balanced ; l'eau au pas d'un marcheur).

Un passage : le long du bord de deux tuiles voisines (ou d'un coin), les pas qui le traversent d'une tuile
à l'autre, entre les mêmes couches, se groupent en suites de cases voisines, coupées tous les RUN ; la
case du milieu de chaque suite, de chaque côté, avec son pas. Dans chaque tuile, un Dijkstra (sur la tuile
seule) donne le coût de chacun de ses passages vers chacun des autres.

Par tuile k (portals[k + 1], compressé par zlib puis en base64), en octets, grand-boutiste :
  n (2), puis n nœuds : case locale (2, x d'abord), couche (1) ;
  m (2), puis m pas sortants : nœud (1), tuile voisine (1 : (dx + 1) * 3 + dy + 1), case locale (2),
    couche (1), coût (2) ;
  p (2), puis p liaisons dans la tuile : de (1), vers (1), coût (2).
Les coûts sont en yards au prix du terrain, arrondis.
"""

import base64
import math
import struct
import zlib

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import dijkstra

RUN = 48                     # cases : une suite plus longue est coupée en plusieurs passages...
RUN_WATER = 67               # ... sauf dans l'eau, où l'on ne nage presque jamais : un passage par bord
WATER = 3 * 7 / 4.72         # le prix d'un yard nagé pour un marcheur (Travel/Nav.lua : WATER_PREF, SWIM)
MULT = {0: 1.0, 1: 0.8, 2: 1.3, 3: 2.5, 4: 2.0, 5: 1.0}   # Équilibré : normal, route, pentes, intérieur, cité
DX = [1, -1, 0, 0, 1, 1, -1, -1]
DY = [0, 0, 1, -1, 1, -1, 1, -1]
MAX_COST = 65535
SLACK = 1.02                 # une liaison n'est gardée que si aucun autre passage ne la fait à 2 % près


def build(ctx):
    """ctx : GX, GY, C, ny, cs, walk, V, step (8 grilles), road, roadcov, cls, out, kept (les étages
    gardés), fval, node_class, lifts, lift_secs. Rend { k : chaîne base64 }, et des chiffres."""
    GX, GY, C, ny, cs = ctx["GX"], ctx["GY"], ctx["C"], ctx["ny"], ctx["cs"]
    walk, V, step, road, cls = ctx["walk"], ctx["V"], ctx["step"], ctx["road"], ctx["cls"]
    kept, out, fval, roadcov, node_class = ctx["kept"], ctx["out"], ctx["fval"], ctx["roadcov"], ctx["node_class"]

    # (le prix du terrain de la base : l'eau, l'intérieur, la route, la pente)
    price = np.ones((GX, GY), dtype=np.float64)
    for c, v in MULT.items():
        price[cls == c] = v
    price[road & (cls < 4)] = MULT[1]
    price[V == 2] = WATER

    def floor_price(nid):
        if fval.get(nid) == 2:
            return WATER
        c = node_class(nid)
        if c < 4:
            cell = nid // 64
            if roadcov[cell // GY, cell % GY]:
                return MULT[1]
        return MULT[c]

    def tile_of(gx, gy):
        return (gx // C) * ny + gy // C

    # --- tous les pas : (de, vers, coût), les nœuds en ids du jeu ------------
    src, dst, cost = [], [], []
    gxs, gys = np.meshgrid(np.arange(GX), np.arange(GY), indexing="ij")
    for d in range(8):
        dx, dy = DX[d], DY[d]
        m = step[d]
        a_x, a_y = gxs[m], gys[m]
        b_x, b_y = a_x + dx, a_y + dy
        length = cs * (math.sqrt(2) if dx and dy else 1)
        src.append(((a_x * GY + a_y) * 64).astype(np.int64))
        dst.append(((b_x * GY + b_y) * 64).astype(np.int64))
        cost.append(length * price[b_x, b_y])
    extra_s, extra_d, extra_c = [], [], []
    for nid, es in out.items():
        own = nid % 64
        if own and nid not in kept:
            continue
        cell = nid // 64
        gx, gy = cell // GY, cell % GY
        for dx, dy, to in es:
            if own == 0 and to == 0:
                continue                                  # (dans le masque de la base)
            tx, ty = gx + dx, gy + dy
            if not (0 <= tx < GX and 0 <= ty < GY):
                continue
            b = (tx * GY + ty) * 64 + to
            if to and b not in kept:
                continue
            if not to and not walk[tx, ty]:
                continue
            if own == 0 and (abs(dx) > 1 or abs(dy) > 1):
                continue                                  # (les chutes depuis la base ne sont pas livrées)
            near = abs(dx) <= 1 and abs(dy) <= 1 and (dx or dy)
            length = cs * (math.sqrt(2) if dx and dy else 1) if near else cs * max(0.5, math.hypot(dx, dy))
            p = floor_price(b) if to else price[tx, ty]
            extra_s.append(nid)
            extra_d.append(b)
            extra_c.append(length * p)
    for top, bot, secs in ctx["lifts"]:
        for a, b in ((top, bot), (bot, top)):
            extra_s.append(a)
            extra_d.append(b)
            extra_c.append(secs * 7.0)
    src = np.concatenate(src + [np.array(extra_s, dtype=np.int64)])
    dst = np.concatenate(dst + [np.array(extra_d, dtype=np.int64)])
    cost = np.concatenate(cost + [np.array(extra_c, dtype=np.float64)])

    # (la tuile de chaque bout)
    def tiles(ids):
        cell = ids // 64
        return (cell // GY // C) * ny + (cell % GY) // C

    ts, td = tiles(src), tiles(dst)
    inner = ts == td

    # --- les passages : les pas d'une tuile à l'autre, groupés en suites -----
    cross = np.nonzero(~inner)[0]

    def wet(n):
        if n % 64:
            return fval.get(n) == 2
        cell = n // 64
        return V[cell // GY, cell % GY] == 2

    # (chaque pas d'une tuile à l'autre, rangé par paire de cases, celle de la plus petite tuile
    # d'abord : l'aller et le retour par les mêmes cases font un seul passage ; pas par les coins)
    pairs = {}
    for e in cross:
        a, b = int(src[e]), int(dst[e])
        ka, kb = int(ts[e]), int(td[e])
        if kb // ny != ka // ny and kb % ny != ka % ny:
            continue
        pairs.setdefault((a, b) if ka < kb else (b, a), []).append(e)
    groups = {}
    for (lo, hi), es in pairs.items():
        cl, ch = lo // 64, hi // 64
        klo = (cl // GY // C) * ny + (cl % GY) // C
        khi = (ch // GY // C) * ny + (ch % GY) // C
        along = cl % GY if khi // ny != klo // ny else cl // GY     # (la coordonnée qui suit le bord)
        ways = {bool(ts[e] < td[e]) for e in es}
        groups.setdefault((klo, khi, lo % 64, hi % 64), []).append((along, ways, wet(lo) and wet(hi), es))
    chosen = []                                           # les pas retenus comme passages
    for items in groups.values():
        items.sort(key=lambda it: it[0])
        runs, run = [], [items[0]]
        for it in items[1:]:
            limit = RUN_WATER if (it[2] and run[0][2]) else RUN
            if it[0] <= run[-1][0] + 1 and it[0] - run[0][0] < limit:
                run.append(it)
            else:
                runs.append(run)
                run = [it]
        runs.append(run)
        for run in runs:
            # (la paire du milieu, de préférence une qui va dans les deux sens ; un sens qu'elle
            # n'a pas, s'il existe ailleurs dans la suite, prend la paire du milieu de ce sens)
            both = [it for it in run if len(it[1]) == 2]
            pick = (both or run)[len(both or run) // 2]
            chosen.extend(pick[3])
            for way in (True, False):
                if way not in pick[1]:
                    some = [it for it in run if way in it[1]]
                    if some:
                        chosen.extend(e for e in some[len(some) // 2][3] if bool(ts[e] < td[e]) == way)

    # (les nœuds de chaque tuile : les bouts des passages qui y sont)
    abstract = {}                                         # k -> [ nœud, ... ]
    for e in chosen:
        for node, k in ((int(src[e]), int(ts[e])), (int(dst[e]), int(td[e]))):
            lst = abstract.setdefault(k, [])
            if node not in lst:
                lst.append(node)

    # --- dans chaque tuile : un Dijkstra entre ses passages ------------------
    order = np.argsort(ts[inner], kind="stable")
    isrc, idst, icost, itile = src[inner][order], dst[inner][order], cost[inner][order], ts[inner][order]
    bounds = np.searchsorted(itile, np.arange(int(itile.max()) + 2) if len(itile) else [0])
    out_tiles, total_nodes, total_links = {}, 0, 0
    raw = {}                                              # (pour vérifier : la même chose, en ids du jeu)
    exits = {}
    for e in chosen:
        exits.setdefault(int(ts[e]), []).append(e)
    for k, nodes in abstract.items():
        if len(nodes) > 255:
            nodes = nodes[:255]
        idx = {n: i for i, n in enumerate(nodes)}
        lo, hi = (bounds[k], bounds[k + 1]) if k + 1 < len(bounds) else (0, 0)
        es, ed, ec = isrc[lo:hi], idst[lo:hi], icost[lo:hi]
        links = []
        if len(es) and len(nodes) > 1:
            ids, inv = np.unique(np.concatenate([es, ed, np.array(nodes, dtype=np.int64)]), return_inverse=True)
            n_e = len(es)
            g = coo_matrix((ec, (inv[:n_e], inv[n_e:2 * n_e])), shape=(len(ids), len(ids))).tocsr()
            local = inv[2 * n_e:]
            dist = dijkstra(g, directed=True, indices=local)[:, local]
            # (une liaison qu'un autre passage de la tuile fait aussi bien, à SLACK près, est retirée :
            # la recherche passe alors par lui)
            n = len(nodes)
            via = dist[:, :, None] + dist[None, :, :]       # via[i, k, j] = d(i, k) + d(k, j)
            for i in range(n):
                for j in range(n):
                    d = dist[i, j]
                    if i == j or not np.isfinite(d):
                        continue
                    others = np.delete(via[i, :, j], [i, j])
                    if len(others) and others.min() <= d * SLACK + 1:
                        continue
                    links.append((i, j, min(MAX_COST, int(round(d)))))
        crossing = []
        for e in exits.get(k, ()):
            a, b = int(src[e]), int(dst[e])
            if a not in idx:
                continue
            cb = b // 64
            bx, by = cb // GY, cb % GY
            kb = int(td[e])
            dkx, dky = kb // ny - k // ny, kb % ny - k % ny
            crossing.append((idx[a], (dkx + 1) * 3 + dky + 1, (bx % C) * C + by % C, b % 64,
                             min(MAX_COST, int(round(cost[e])))))
        buf = [struct.pack(">H", len(nodes))]
        for n in nodes:
            cell = n // 64
            gx, gy = cell // GY, cell % GY
            buf.append(struct.pack(">HB", (gx % C) * C + gy % C, n % 64))
        buf.append(struct.pack(">H", len(crossing)))
        for c in crossing:
            buf.append(struct.pack(">BBHBH", *c))
        buf.append(struct.pack(">H", len(links)))
        for l in links:
            buf.append(struct.pack(">BBH", *l))
        out_tiles[k] = base64.b64encode(zlib.compress(b"".join(buf), 9)).decode("ascii")
        raw[k] = (list(nodes), [(nodes[c[0]], int(dst[e]), c[4]) for c, e in zip(crossing, [e for e in exits.get(k, ()) if int(src[e]) in idx])],
                  [(nodes[i], nodes[j], c) for i, j, c in links])
        total_nodes += len(nodes)
        total_links += len(links)
    stats = {"passages": len(chosen), "nœuds de passage": total_nodes, "liaisons dans les tuiles": total_links}
    graph = {"src": src, "dst": dst, "cost": cost, "raw": raw}
    return out_tiles, stats, graph
