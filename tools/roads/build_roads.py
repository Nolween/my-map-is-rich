"""Le réseau de routes des itinéraires (MyMapIsRich/Plus/Data/Roads.lua).

Les routes viennent de Shortest Path Forever (cjber, GPL-3.0-or-later) : son
Data/RoadCells.lua donne, case par case (environ 8 yards), la couverture des
textures de route peintes au sol, lues dans les tuiles de terrain du client.
Ce script en fait un graphe léger :
  1. la grille des cases de route (couverture >= SEUIL), nettoyée ;
  2. son squelette (une ligne d'une case au milieu de chaque route) ;
  3. un graphe : nœuds aux carrefours et aux bouts, tronçons entre eux ;
  4. simplifié : petites impasses coupées, nœuds voisins fusionnés, tracés
     allégés (Douglas-Peucker) ;
  5. écrit en Lua, en chaînes d'entiers (yards du monde).

    python build_roads.py [dossier de ShortestPathForever]

Il faut numpy, scipy, scikit-image et pillow (requirements.txt). Les images de
contrôle vont dans tools/roads/out/ (hors git).
"""

import math
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.spatial import cKDTree
from skimage.morphology import remove_small_objects, skeletonize

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
OUT_LUA = os.path.join(REPO, "MyMapIsRich", "Plus", "Data", "Roads.lua")
OUT_DIR = os.path.join(HERE, "out")
DEFAULT_SPF = r"K:\World of Warcraft\_forever_\Interface\AddOns\ShortestPathForever"

CONTINENTS = {0: "Royaumes de l'Est", 1: "Kalimdor"}
TILE = 1600 / 3
THRESHOLD = 1         # couverture minimale d'une case de route (sur 63) : toute peinture compte
MIN_BLOB = 25         # cases : un îlot de route plus petit est retiré
SPUR = 40             # yd : une impasse plus courte est coupée
MERGE = 12            # yd : deux nœuds plus proches n'en font qu'un
TOLERANCE = 6         # yd : écart permis en allégeant un tracé
MIN_PIECE = 150       # yd : un morceau de réseau isolé plus court est retiré
GAP = 120             # yd : un bout de route est relié au morceau voisin jusqu'à cette distance
NEAR = 30             # yd : ... ou à une autre route du même morceau jusqu'à celle-ci

B64 = {c: i for i, c in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")}


# ---------------------------------------------------------------------------
# Lecture des données de Shortest Path Forever
# ---------------------------------------------------------------------------
def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def nav_header(spf, cont):
    text = read(os.path.join(spf, "Nav", "Nav%d.lua" % cont))[:20000]
    head = {}
    for key in ("cx0", "cy0", "nx", "ny", "cells"):
        m = re.search(r"\b%s = (-?\d+)," % key, text)
        if not m:
            raise SystemExit("Nav%d.lua : %s introuvable" % (cont, key))
        head[key] = int(m.group(1))
    return head


def road_cells(spf):
    """{ continent: { k: chaîne } } (k à partir de 0)"""
    maps, current = {}, None
    for line in read(os.path.join(spf, "Data", "RoadCells.lua")).splitlines():
        m = re.match(r"^\t\[(\d+)\] = \{$", line)
        if m:
            current = maps.setdefault(int(m.group(1)), {})
            continue
        m = re.match(r'^\t\t\[(\d+)\] = "([^"]*)",?$', line)
        if m and current is not None:
            current[int(m.group(1)) - 1] = m.group(2)
    return maps


def spf_version(spf):
    m = re.search(r"^## Version: (.+)$", read(os.path.join(spf, "ShortestPathForever.toc")), re.M)
    return m.group(1).strip() if m else "?"


def coverage_grid(head, clusters):
    C, ny = head["cells"], head["ny"]
    grid = np.zeros((head["nx"] * C, ny * C), dtype=np.uint8)
    for k, s in clusters.items():
        runs, values = [], []
        for p in range(0, len(s) - 2, 3):
            runs.append(B64[s[p]] * 64 + B64[s[p + 1]])
            values.append(B64[s[p + 2]])
        cells = np.repeat(np.array(values, dtype=np.uint8), runs)[: C * C]
        tile = np.zeros(C * C, dtype=np.uint8)
        tile[: len(cells)] = cells
        kx, ky = k // ny, k % ny
        grid[kx * C:(kx + 1) * C, ky * C:(ky + 1) * C] = tile.reshape(C, C)   # x d'abord
    return grid


# ---------------------------------------------------------------------------
# Du squelette au graphe
# ---------------------------------------------------------------------------
OFFSETS = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]


def skeleton_graph(skel):
    """nodes : [ (gx, gy) moyens ], edges : [ (a, b, [ (gx, gy), ... ]) ] (le tracé de a à b)"""
    gx, gy = np.nonzero(skel)
    on = set(zip(gx.tolist(), gy.tolist()))

    def neighbours(p):
        x, y = p
        return [(x + dx, y + dy) for dx, dy in OFFSETS if (x + dx, y + dy) in on]

    degree = {p: len(neighbours(p)) for p in on}
    special = {p for p, d in degree.items() if d != 2}
    # (les cases de carrefour qui se touchent forment un seul nœud)
    node_of, nodes = {}, []
    for p in special:
        if p in node_of:
            continue
        stack, members = [p], []
        node_of[p] = len(nodes)
        while stack:
            q = stack.pop()
            members.append(q)
            for r in neighbours(q):
                if r in special and r not in node_of:
                    node_of[r] = len(nodes)
                    stack.append(r)
        nodes.append((sum(m[0] for m in members) / len(members), sum(m[1] for m in members) / len(members)))

    edges, used = [], set()

    def walk(start_node, first, path):
        prev = path[-1]
        cur = first
        while True:
            path.append(cur)
            if cur in node_of:
                return node_of[cur], path
            used.add(cur)
            nxt = [r for r in neighbours(cur) if r != prev and (r not in used or r in node_of)]
            # (deux voisins possibles en diagonale : le plus proche d'abord)
            nxt.sort(key=lambda r: abs(r[0] - cur[0]) + abs(r[1] - cur[1]))
            if not nxt:
                return None, path
            prev, cur = cur, nxt[0]

    for p, n in list(node_of.items()):
        for r in neighbours(p):
            if r in node_of or r in used:
                continue
            end, path = walk(n, r, [p])
            if end is not None:
                edges.append((n, end, path))
    # (les boucles sans carrefour : un nœud posé sur l'une de leurs cases)
    for p in on:
        if p in used or p in node_of:
            continue
        n = len(nodes)
        nodes.append(p)
        node_of[p] = n
        for r in neighbours(p):
            if r not in used and r not in node_of:
                end, path = walk(n, r, [p])
                if end is not None:
                    edges.append((n, end, path))
                break
    return nodes, edges


def length(points):
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(points, points[1:]))


def douglas_peucker(points, tol):
    if len(points) < 3:
        return list(points)
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        i, j = stack.pop()
        ax, ay = points[i]
        bx, by = points[j]
        dx, dy = bx - ax, by - ay
        norm = math.hypot(dx, dy) or 1e-9
        best, at = -1, -1
        for k in range(i + 1, j):
            px, py = points[k]
            d = abs(dy * (px - ax) - dx * (py - ay)) / norm
            if d > best:
                best, at = d, k
        if best > tol:
            keep[at] = True
            stack.append((i, at))
            stack.append((at, j))
    return [p for p, k in zip(points, keep) if k]


class Graph:
    """Le graphe en yards : nœuds { id: (x, y) }, tronçons { id: [a, b, tracé] }"""

    def __init__(self, nodes, edges):
        self.nodes = dict(enumerate(nodes))
        self.edges = {}
        for i, (a, b, pts) in enumerate(edges):
            if a != b or len(pts) > 2:
                self.edges[i] = [a, b, pts]
        self.next_edge = len(edges)

    def incident(self):
        inc = {n: [] for n in self.nodes}
        for e, (a, b, _) in self.edges.items():
            inc[a].append(e)
            inc[b].append(e)
        return inc

    def prune_spurs(self):
        for _ in range(3):
            inc = self.incident()
            removed = False
            for e, (a, b, pts) in list(self.edges.items()):
                if length(pts) >= SPUR:
                    continue
                if (len(inc[a]) == 1) != (len(inc[b]) == 1):   # une impasse, pas un tronçon isolé
                    del self.edges[e]
                    removed = True
            if not removed:
                break
        self.drop_lonely_nodes()

    def contract_short(self):
        parent = {n: n for n in self.nodes}

        def find(n):
            while parent[n] != n:
                parent[n] = parent[parent[n]]
                n = parent[n]
            return n

        for e, (a, b, pts) in list(self.edges.items()):
            if length(pts) < MERGE:
                ra, rb = find(a), find(b)
                if ra != rb:
                    parent[rb] = ra
                del self.edges[e]
        groups = {}
        for n in self.nodes:
            groups.setdefault(find(n), []).append(n)
        for root, members in groups.items():
            if len(members) > 1:
                xs = [self.nodes[m][0] for m in members]
                ys = [self.nodes[m][1] for m in members]
                self.nodes[root] = (sum(xs) / len(xs), sum(ys) / len(ys))
        for e, edge in self.edges.items():
            edge[0], edge[1] = find(edge[0]), find(edge[1])
            edge[2] = [self.nodes[edge[0]]] + edge[2][1:-1] + [self.nodes[edge[1]]]
        self.edges = {e: v for e, v in self.edges.items() if v[0] != v[1] or length(v[2]) > MERGE * 3}
        self.drop_lonely_nodes()

    def bridge_gaps(self):
        """La peinture s'interrompt (un pont, l'entrée d'une ville, un tunnel) : chaque bout de route est
        relié au morceau de réseau voisin le plus proche (à moins de GAP yd), ou à une autre route toute
        proche (à moins de NEAR yd) du même morceau, par un tronçon droit. Un bout qui tombe au milieu
        d'un tronçon le coupe en deux, à cet endroit."""
        parent = {n: n for n in self.nodes}

        def find(n):
            while parent[n] != n:
                parent[n] = parent[parent[n]]
                n = parent[n]
            return n

        for a, b, _ in self.edges.values():
            parent[find(b)] = find(a)
        inc = self.incident()
        # (les cibles : les nœuds, et les points intérieurs des tronçons)
        targets, coords = [], []
        for n, p in self.nodes.items():
            targets.append(("n", n))
            coords.append(p)
        for e, (a, b, pts) in self.edges.items():
            for i in range(1, len(pts) - 1):
                targets.append(("e", e, i))
                coords.append(pts[i])
        tree = cKDTree(np.array(coords))
        links, splits = [], {}
        for n, es in inc.items():
            if len(es) != 1:
                continue
            own = es[0]
            a, b, _ = self.edges[own]
            other_end = b if a == n else a
            p = self.nodes[n]
            dists, idx = tree.query(p, k=40, distance_upper_bound=GAP)
            for d, i in zip(np.atleast_1d(dists), np.atleast_1d(idx)):
                if not np.isfinite(d) or d < 1:
                    continue
                t = targets[i]
                if t[0] == "n" and t[1] in (n, other_end):
                    continue
                if t[0] == "e" and t[1] == own:
                    continue
                tnode = t[1] if t[0] == "n" else self.edges[t[1]][0]
                if find(tnode) == find(n) and d > NEAR:
                    continue
                links.append((n, t, d))
                parent[find(tnode)] = find(n)
                if t[0] == "e":
                    splits.setdefault(t[1], set()).add(t[2])
                break
        # (les tronçons coupés là où un bout les rejoint : un nœud à chaque coupure)
        cut_node = {}
        for e, at in splits.items():
            a, b, pts = self.edges.pop(e)
            prev, start = a, 0
            for i in sorted(at):
                m = max(self.nodes) + 1
                self.nodes[m] = pts[i]
                cut_node[(e, i)] = m
                self.edges[self.next_edge] = [prev, m, pts[start:i + 1]]
                self.next_edge += 1
                prev, start = m, i
            self.edges[self.next_edge] = [prev, b, pts[start:]]
            self.next_edge += 1
        for n, t, _ in links:
            m = t[1] if t[0] == "n" else cut_node[(t[1], t[2])]
            self.edges[self.next_edge] = [n, m, [self.nodes[n], self.nodes[m]]]
            self.next_edge += 1
        return len(links)

    def drop_small_pieces(self):
        parent = {n: n for n in self.nodes}

        def find(n):
            while parent[n] != n:
                parent[n] = parent[parent[n]]
                n = parent[n]
            return n

        for a, b, _ in self.edges.values():
            parent[find(b)] = find(a)
        total = {}
        for a, _, pts in self.edges.values():
            total[find(a)] = total.get(find(a), 0) + length(pts)
        self.edges = {e: v for e, v in self.edges.items() if total[find(v[0])] >= MIN_PIECE}
        self.drop_lonely_nodes()

    def drop_lonely_nodes(self):
        used = set()
        for a, b, _ in self.edges.values():
            used.add(a)
            used.add(b)
        self.nodes = {n: p for n, p in self.nodes.items() if n in used}

    def simplify(self):
        for edge in self.edges.values():
            edge[2] = douglas_peucker(edge[2], TOLERANCE)


def merge_chains_fast(g):
    """merge_chains, sans refaire toutes les listes à chaque fusion"""
    inc = g.incident()
    for n in list(g.nodes):
        es = [e for e in inc.get(n, []) if e in g.edges]
        if len(es) != 2 or es[0] == es[1]:
            continue
        e1, e2 = es
        a1, b1, p1 = g.edges[e1]
        a2, b2, p2 = g.edges[e2]
        if a1 == b1 or a2 == b2:
            continue
        p1 = p1 if b1 == n else p1[::-1]
        o1 = a1 if b1 == n else b1
        p2 = p2 if a2 == n else p2[::-1]
        o2 = b2 if a2 == n else a2
        if o1 == n or o2 == n:
            continue
        del g.edges[e1], g.edges[e2]
        del g.nodes[n]
        e = g.next_edge
        g.next_edge += 1
        g.edges[e] = [o1, o2, p1 + p2[1:]]
        for o, old in ((o1, e1), (o2, e2)):
            lst = inc[o]
            lst[lst.index(old)] = e


# ---------------------------------------------------------------------------
# Un continent
# ---------------------------------------------------------------------------
def build(spf, cont, clusters):
    head = nav_header(spf, cont)
    C = head["cells"]
    cs = TILE / C
    x0, y0 = head["cx0"] * TILE, head["cy0"] * TILE
    grid = coverage_grid(head, clusters)
    road = grid >= THRESHOLD
    road = ndimage.binary_closing(road, structure=np.ones((3, 3), bool), iterations=2)
    road = remove_small_objects(road, max_size=MIN_BLOB)
    skel = skeletonize(road)
    nodes_px, edges_px = skeleton_graph(skel)

    def yards(p):
        return (x0 + (p[0] + 0.5) * cs, y0 + (p[1] + 0.5) * cs)

    nodes = [yards(p) for p in nodes_px]
    edges = [(a, b, [nodes[a]] + [yards(p) for p in pts[1:-1]] + [nodes[b]]) for a, b, pts in edges_px]
    g = Graph(nodes, edges)
    g.prune_spurs()
    merge_chains_fast(g)
    g.contract_short()
    merge_chains_fast(g)
    g.prune_spurs()
    merge_chains_fast(g)
    bridged = g.bridge_gaps()
    merge_chains_fast(g)
    g.drop_small_pieces()
    g.simplify()
    print("  %d trous comblés, %d morceaux de réseau" % (bridged, pieces(g)))
    return head, grid, road, g


def pieces(g):
    parent = {n: n for n in g.nodes}

    def find(n):
        while parent[n] != n:
            parent[n] = parent[parent[n]]
            n = parent[n]
        return n

    for a, b, _ in g.edges.values():
        parent[find(b)] = find(a)
    return len({find(n) for n in g.nodes})


def draw(path, head, grid, road, g):
    C = head["cells"]
    cs = TILE / C
    x0, y0 = head["cx0"] * TILE, head["cy0"] * TILE
    w, h = grid.shape
    # (le nord en haut : x croît vers le nord, y vers l'ouest)
    img = np.full((w, h, 3), 250, dtype=np.uint8)
    img[grid > 0] = (215, 215, 215)
    img[road] = (170, 170, 170)
    picture = Image.fromarray(img[::-1, ::-1])
    pen = ImageDraw.Draw(picture)

    def px(p):
        gx, gy = (p[0] - x0) / cs - 0.5, (p[1] - y0) / cs - 0.5
        return (h - 1 - gy, w - 1 - gx)

    for a, b, pts in g.edges.values():
        pen.line([px(p) for p in pts], fill=(200, 30, 30), width=2)
    for p in g.nodes.values():
        x, y = px(p)
        pen.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(30, 60, 220))
    picture.save(path)


def lua_numbers(values, per_line=24):
    out, line = [], []
    for v in values:
        line.append(str(int(round(v))))
        if len(line) >= per_line:
            out.append(" ".join(line))
            line = []
    if line:
        out.append(" ".join(line))
    return " ".join(out)


def main():
    spf = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SPF
    os.makedirs(OUT_DIR, exist_ok=True)
    cells = road_cells(spf)
    version = spf_version(spf)
    parts = []
    for cont, name in CONTINENTS.items():
        head, grid, road, g = build(spf, cont, cells.get(cont, {}))
        ids = {n: i + 1 for i, n in enumerate(sorted(g.nodes))}
        node_vals, edge_vals, point_vals = [], [], []
        for n in sorted(g.nodes):
            node_vals += g.nodes[n]
        km = 0
        for a, b, pts in g.edges.values():
            inner = pts[1:-1]
            start = len(point_vals) // 2 + 1
            for p in inner:
                point_vals += p
            ln = length(pts)
            km += ln
            edge_vals += [ids[a], ids[b], ln, start, len(inner)]
        print("%s : %d nœuds, %d tronçons, %d points, %.0f km de routes"
              % (name, len(g.nodes), len(g.edges), len(point_vals) // 2, km * 0.9144 / 1000))
        draw(os.path.join(OUT_DIR, "roads_%d.png" % cont), head, grid, road, g)
        parts.append('\t[%d] = { -- %s\n\t\tnodes = "%s",\n\t\tedges = "%s",\n\t\tpoints = "%s",\n\t},'
                     % (cont, name, lua_numbers(node_vals), lua_numbers(edge_vals), lua_numbers(point_vals)))
    header = (
        "-- Généré par tools/roads/build_roads.py : ne pas modifier à la main.\n"
        "-- Le réseau de routes des itinéraires (Travel/Roads.lua), en yards du monde par continent (0 les\n"
        "-- Royaumes de l'Est, 1 Kalimdor ; x vers le nord, y vers l'ouest, comme C_Map.GetWorldPosFromMapPos).\n"
        "-- Source : Shortest Path Forever %s de cjber (https://github.com/cjber/shortest-path-forever),\n"
        "-- Data/RoadCells.lua : la couverture des textures de route peintes au sol, lue dans les tuiles de\n"
        "-- terrain du client. Données dérivées, sous licence GPL-3.0-or-later (voir LICENSE).\n"
        "--   nodes  : x y par nœud (le nœud i est le i-ème couple)\n"
        "--   edges  : a b longueur début nombre par tronçon : ses deux nœuds, sa longueur (yd), et ses points\n"
        "--            intermédiaires dans points (à partir du couple « début », « nombre » couples)\n"
        "--   points : x y des points intermédiaires des tronçons\n"
        "local _, ns = ...\n\n"
        "ns.Roads = {\n" % version
    )
    with open(OUT_LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write(header + "\n".join(parts) + "\n}\n")
    print("%s : %.0f Ko" % (OUT_LUA, os.path.getsize(OUT_LUA) / 1024))


if __name__ == "__main__":
    main()
