"""La base des quêtes (MyMapIsRich/Plus/Data/Quests.lua), pour les marqueurs de quêtes
sur la carte (Plus/Quests/, Plus/Layers/QuestMarks.lua).

Le jeu ne dit pas où sont les monstres et les objets d'une quête, et aucune API
officielle non plus. Ils viennent de la base Forever de QuestieDB
(https://github.com/Questie/QuestieDB : ses données sont sous GPLv3, voir son
LICENSE.md ; relevées en jeu par la communauté de Questie avec QuestieTrace, et
revues pour WoW Forever). Les joueurs n'ont rien à installer : la base est
copiée dans l'addon à chaque mise à jour (commande /sync-quetes de Claude Code).

Ce qui est gardé :
  - les quêtes : niveaux, races et classes, qui les donne et qui les reprend,
    leurs objectifs (monstres, objets du monde, objets à trouver, lieux à
    explorer), leurs prérequis ;
  - les PNJ et objets du monde qui servent à une quête, avec leurs apparitions
    (carte du jeu, x, y en % : les coordonnées de Forever), fusionnées quand
    elles sont proches ; une apparition en donjon garde le numéro du donjon
    (le jeu la pose à son entrée) ;
  - leurs noms dans les 9 autres langues du client (pas l'italien : QuestieDB
    ne l'a pas) ;
  - pour chaque objet de quête : qui le lâche, où il se ramasse, qui le vend
    (sans les chances de butin : celles de QuestieDB viennent de Wowhead).
S'y ajoute la liste des quêtes que Questie ne propose jamais sur Forever (sa liste
noire et ses fêtes, lues comme des données : questie_hidden.py).
Les corrections à nous sont dans forever_fixes.json (une entrée de l'outil,
éditée à la main) et s'appliquent à chaque génération.

    py tools/quests/build_quests.py [--fetch] [dossier QuestieDB]
      --fetch   télécharge la dernière version Forever de QuestieDB et la liste noire de
                Questie (GitHub) dans tools/quests/source/ ; sans, les plus récentes qui s'y trouvent
"""

import base64
import datetime
import io
import json
import os
import re
import sys
import urllib.request
import zipfile
import zlib
from collections import defaultdict

import questie_hidden
from questiedb import QuestieDB, at, lua_list

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SOURCE = os.path.join(HERE, "source")
OUT = os.path.join(ROOT, "MyMapIsRich", "Plus", "Data", "Quests.lua")
RELEASES = "https://api.github.com/repos/Questie/QuestieDB/releases/latest"

LOCALES = ("deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW")
MERGE = (0.3, 1.0, 2.0, 4.0)    # % de la carte : la fusion des points proches, plus large pour un PNJ très présent
MANY = (60, 120, 200)           # au-delà, on passe au rayon suivant
# les catégories de quêtes des fêtes du jeu (zoneOrSort < 0) : jamais proposées
HOLIDAYS = {-22, -364, -366, -369, -370, -374, -375, -376, -1001, -1002, -1003, -1004, -1005,
            -1006, -1007, -1008}
RACES = 0xFFFF                  # (les races du masque ; QuestieDB y ajoute un bit à lui)


# ---------------------------------------------------------------------------
# La source : une version de QuestieDB Forever
# ---------------------------------------------------------------------------
def fetch():
    """La dernière version Forever, extraite dans source/QuestieDB-<version>/."""
    req = urllib.request.Request(RELEASES, headers={"User-Agent": "build-quests", "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req) as r:
        rel = json.load(r)
    asset = next((a for a in rel.get("assets", []) if re.search(r"Forever\.zip$", a["name"])), None)
    if not asset:
        raise SystemExit("pas d'archive Forever dans la version %s de QuestieDB" % rel.get("tag_name"))
    dest = os.path.join(SOURCE, "QuestieDB-%s" % rel["tag_name"].lstrip("v"))
    if os.path.exists(os.path.join(dest, "QuestieDB", "QuestieDB_Forever.toc")):
        print("déjà là : %s" % dest)
        return os.path.join(dest, "QuestieDB")
    print("téléchargement de %s (%.1f Mo)" % (asset["name"], asset["size"] / 1e6))
    req = urllib.request.Request(asset["browser_download_url"], headers={"User-Agent": "build-quests"})
    with urllib.request.urlopen(req) as r:
        data = r.read()
    os.makedirs(dest, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for name in z.namelist():
            # (seulement ce que l'outil lit : le .toc, les zones, les factions, les constantes, la licence)
            if re.search(r"(QuestieDB_Forever\.toc|support/Forever/(Zones|FactionTemplates)/[^/]*\.lua"
                         r"|src/corrections/enum/zones\.lua|QuestieDB/LICENSE\.md|QuestieDB/gpl-3\.0\.md)$", name):
                z.extract(name, dest)
    return os.path.join(dest, "QuestieDB")


def newest():
    best = None
    if os.path.isdir(SOURCE):
        for d in os.listdir(SOURCE):
            m = re.match(r"QuestieDB-(\d+)\.(\d+)\.(\d+)", d)
            if m and os.path.exists(os.path.join(SOURCE, d, "QuestieDB", "QuestieDB_Forever.toc")):
                key = tuple(int(x) for x in m.groups())
                if not best or key > best[0]:
                    best = (key, os.path.join(SOURCE, d, "QuestieDB"))
    return best and best[1]


# ---------------------------------------------------------------------------
# Les points
# ---------------------------------------------------------------------------
def merge(points, radius):
    kept, cells = [], {}
    for x, y in points:
        cx, cy = int(x // radius), int(y // radius)
        near = any((kx - x) ** 2 + (ky - y) ** 2 < radius * radius
                   for i in (cx - 1, cx, cx + 1) for j in (cy - 1, cy, cy + 1)
                   for kx, ky in cells.get((i, j), ()))
        if not near:
            kept.append((x, y))
            cells.setdefault((cx, cy), []).append((x, y))
    return kept


def thin(points):
    pts = merge(points, MERGE[0])
    for i, limit in enumerate(MANY):
        if len(pts) <= limit:
            break
        pts = merge(pts, MERGE[i + 1])
    return pts


# six bits par caractère (A-Za-z0-9+/), trois caractères par valeur : x ou y (en %) * 100 + 32768
B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"


def encode(points):
    out = []
    for x, y in points:
        for v in (int(round(x * 100)) + 32768, int(round(y * 100)) + 32768):
            v = max(0, min(v, 262143))
            out.append(B64[v >> 12] + B64[(v >> 6) & 63] + B64[v & 63])
    return "".join(out)


def as_map(v):
    """Une table Lua { [clé] = ... } décodée : une liste si ses clés sont 1, 2, ..."""
    if isinstance(v, dict):
        return v
    if isinstance(v, list):
        return {i + 1: x for i, x in enumerate(v) if x is not None}
    return {}


def points(v):
    return [(at(p, 1), at(p, 2)) for p in lua_list(v)
            if isinstance(at(p, 1), (int, float)) and isinstance(at(p, 2), (int, float))]


# ---------------------------------------------------------------------------
# L'écriture en Lua
# ---------------------------------------------------------------------------
def lstr(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "")
    return '"' + s + '"'


def lua(v):
    if v is None or v is False:
        return "false"
    if v is True:
        return "true"
    if isinstance(v, str):
        return lstr(v)
    if isinstance(v, float):
        r = round(v, 2)
        return str(int(r)) if r == int(r) else repr(r)
    if isinstance(v, int):
        return str(v)
    if isinstance(v, dict):
        return "{" + ",".join("[%d]=%s" % (k, lua(v[k])) for k in sorted(v)) + "}"
    if isinstance(v, (list, tuple)):
        items = list(v)
        while items and (items[-1] is None or items[-1] is False):
            items.pop()
        return "{" + ",".join(lua(x) for x in items) + "}"
    raise TypeError(v)


def ids(v):
    return [x for x in lua_list(v) if isinstance(x, int) and x > 0]


def signed(v):
    """Des ids gardant leur signe (preQuestGroup : < 0, à avoir fait sans regarder ses exclusives)."""
    return [x for x in lua_list(v) if isinstance(x, int) and x != 0]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    folder = args[0] if args else (fetch() if "--fetch" in sys.argv else newest())
    if not folder:
        raise SystemExit("pas de QuestieDB : lancer avec --fetch, ou donner son dossier")
    db = QuestieDB(folder)
    print("QuestieDB %s (%s)" % (db.version, db.commit[:8]))
    with open(os.path.join(HERE, "forever_fixes.json"), "r", encoding="utf-8") as f:
        fixes = json.load(f)
    hidden = set(fixes.get("hideQuests", []))
    area_inst = {a: i for i, a in db.instance_to_area.items()}
    # la liste noire et les fêtes de Questie (lues comme des données : questie_hidden.py)
    qfolder = questie_hidden.fetch(SOURCE) if "--fetch" in sys.argv else questie_hidden.newest(SOURCE)
    if not qfolder:
        raise SystemExit("pas de liste noire de Questie : lancer avec --fetch")
    blacklist, skipped = questie_hidden.questie_hidden(qfolder)
    print("liste noire de Questie (%s) : %d quêtes, %d valeurs illisibles"
          % (os.path.basename(qfolder), len(blacklist), skipped))

    def react_object(fid):
        eg = db.faction_enemy.get(fid) if fid else None
        if eg is None:
            return 3
        if eg & 1:
            return 0
        return (0 if eg & 2 else 1) | (0 if eg & 4 else 2)

    # --- les quêtes
    quests, need_npc, need_obj, need_item = {}, set(), set(), set()

    def refs(v):
        """{ PNJ, objets } -> [ PNJ (> 0), objets (< 0) ]"""
        return ids(at(v, 1)) + [-o for o in ids(at(v, 2))]

    for qid in db.ids("Quest"):
        if qid in hidden:
            continue
        r = db.row("Quest", qid)
        if not r or not r.get(1):
            continue
        starts, ends = refs(r.get(2)), refs(r.get(3))
        obj = r.get(10)
        goals = []
        for c in lua_list(at(obj, 1)):          # les monstres : { id, texte?, icône }
            if isinstance(at(c, 1), int):
                goals.append([at(c, 1)])
        for kc in lua_list(at(obj, 5)):         # le crédit : { { ids }, id principal, texte? }
            root = at(kc, 2)
            if isinstance(root, int):
                goals.append([root] + [i for i in ids(at(kc, 1)) if i != root])
        for o in lua_list(at(obj, 2)):          # les objets du monde
            if isinstance(at(o, 1), int):
                goals.append([-at(o, 1)])
        items = [at(i, 1) for i in lua_list(at(obj, 3)) if isinstance(at(i, 1), int)]
        trigger = {}
        for area, pts in as_map(at(r.get(9), 2)).items():
            ui = db.area_to_uimap.get(area)
            pts = [p for p in points(pts) if p[0] >= 0]
            if ui and pts:
                trigger.setdefault(ui, []).extend(pts)
        skill = at(r.get(18), 1)
        sort = r.get(17) or 0
        # (une quête que Questie ne propose jamais sur Forever : sa liste noire, ses fêtes)
        never = sort in HOLIDAYS or qid in blacklist
        quests[qid] = {
            "rec": [r[1], r.get(5) or 0, r.get(4) or 0, r.get(32) or 0, (r.get(6) or 0) & RACES, r.get(7) or 0, sort,
                    starts or None, ends or None, goals or None, items or None, signed(r.get(12)) or None,
                    ids(r.get(16)) or None, r.get(27) or None, skill or None, lua_list(r.get(19)) or None,
                    never or None, None, r.get(25) or None, r.get(30) or None, r.get(33) or None, r.get(34) or None,
                    ids(r.get(13)) or None, r.get(22) or None, ids(r.get(28)) or None, r.get(36) or None,
                    lua_list(r.get(20)) or None],
            "trigger": trigger,
        }
        for ref in starts + ends + [g for goal in goals for g in goal]:
            (need_npc if ref > 0 else need_obj).add(abs(ref))
        need_item.update(items)
    for qid, over in fixes.get("quests", {}).items():
        if int(qid) in quests:
            for k, v in over.items():
                quests[int(qid)]["rec"][int(k) - 1] = v

    # --- les objets de quête : qui les lâche, où ils se ramassent, qui les vend
    items = {}
    for it in sorted(need_item):
        r = db.row("Item", it)
        if not r:
            continue
        drops = ids(r.get(2)) + [-o for o in ids(r.get(3))]
        vendors = ids(r.get(14))
        if drops or vendors:
            items[it] = [drops or None, vendors or None]
            need_npc.update(d for d in drops + vendors if d > 0)
            need_obj.update(-d for d in drops if d < 0)

    # --- les apparitions
    lost = [0]

    def spawns(v):
        out, inst = defaultdict(list), set()
        for area, pts in as_map(v).items():
            pts = points(pts)
            if any(x < 0 for x, _ in pts):          # (-1, -1) : dans un donjon
                if area in area_inst:
                    inst.add(area_inst[area])
                pts = [p for p in pts if p[0] >= 0]
            ui = db.area_to_uimap.get(area)
            if pts and ui:
                out[ui].extend(pts)
            elif pts:
                lost[0] += len(pts)
        return out, inst

    def placed(key, eid, sp):
        fix = fixes.get(key, {}).get(str(eid))
        if fix:
            if fix.get("replace"):
                sp = defaultdict(list)
            for ui, pts in fix.get("spawns", {}).items():
                sp[int(ui)].extend(tuple(p) for p in pts)
        return {ui: encode(thin(p)) for ui, p in sp.items() if p}

    npcs, objects, npoints = {}, {}, 0
    for e in sorted(need_npc):
        r = db.row("Npc", e)
        if not r:
            continue
        sp, inst = spawns(r.get(7))
        enc = placed("npcs", e, sp)
        npoints += sum(len(s) // 6 for s in enc.values())
        react = {"A": 1, "H": 2, "AH": 3}.get(r.get(13) or "", 0)
        npcs[e] = [r.get(1) or "", r.get(4) or 0, r.get(5) or 0, r.get(6) or 0, react, enc or None, sorted(inst) or None]
    for e in sorted(need_obj):
        r = db.row("Object", e)
        if not r:
            continue
        sp, inst = spawns(r.get(4))
        enc = placed("objects", e, sp)
        npoints += sum(len(s) // 6 for s in enc.values())
        objects[e] = [r.get(1) or "", react_object(r.get(6)), enc or None, sorted(inst) or None]

    def anywhere(ref):
        rec = npcs.get(ref) if ref > 0 else objects.get(-ref)
        if not rec:
            return False
        return bool(rec[5] or rec[6]) if ref > 0 else bool(rec[2] or rec[3])

    for q in quests.values():
        rec = q["rec"]
        # (une quête dont aucun donneur n'apparaît nulle part ne se propose pas)
        if rec[7] and not any(anywhere(s) for s in rec[7]):
            rec[16] = True
        rec[17] = {ui: encode(thin(p)) for ui, p in q["trigger"].items()} or None

    # --- l'écriture
    lines = []
    w = lines.append
    w("-- Généré par tools/quests/build_quests.py : ne pas modifier à la main (commande /sync-quetes).")
    w("-- Les quêtes, leurs donneurs, leurs objectifs et où les trouver (Plus/Quests/, Layers/QuestMarks.lua).")
    w("-- Source : la base Forever de QuestieDB %s (https://github.com/Questie/QuestieDB, commit %s)," % (db.version, db.commit[:8]))
    w("-- données sous GPLv3 (voir LICENSES/QuestieDB.txt) ; le contenu du jeu (noms, titres) appartient")
    w("-- à Blizzard Entertainment.")
    w("--   quests[id] = { 1 titre anglais, 2 niveau, 3 niveau requis, 4 niveau maxi, 5 races, 6 classes,")
    w("--     7 zone (zoneOrSort), 8 donneurs, 9 preneurs, 10 cibles, 11 objets, 12 prérequis (toutes), 13 exclusives,")
    w("--     14 prépare la quête, 15 métier, 16 réputation mini { faction, valeur }, 17 à ne pas proposer (liste")
    w("--     noire et fêtes de Questie, ou aucun donneur dans le monde), 18 lieux à explorer, 19 quête à avoir en")
    w("--     cours, 20 sort à connaître (< 0 : à ne pas connaître), 21 quête qui la retire une fois faite,")
    w("--     22 quête à avoir prise ou faite, 23 prérequis (une parmi), 24 quête suivante, 25 quêtes qui y mènent,")
    w("--     26 quête qui la bloque tant qu'elle est en cours, 27 réputation maxi }")
    w("--     donneurs, preneurs : PNJ (id > 0) et objets du monde (id < 0) ; cibles : { { id, id qui en donne")
    w("--     aussi le crédit, ... } } ; prérequis (toutes) : id < 0, à avoir faite sans regarder ses exclusives ;")
    w("--     lieux à explorer : { [carte] = points }.")
    w("--   npcs[id] = { nom, niveau mini, niveau maxi, rang, réaction, { [carte] = points }, { donjons } }")
    w("--   objects[id] = { nom, réaction, { [carte] = points }, { donjons } }")
    w("--     réaction : 1 amical envers l'Alliance, 2 envers la Horde (3 les deux, 0 aucun) ; carte : son uiMapID ;")
    w("--     points : x, y en % de la carte, trois caractères chacun (A-Za-z0-9+/, six bits, le plus fort")
    w("--     d'abord), valeur * 100 + 32768 ; donjons : leur mapID d'instance.")
    w("--   items[id] = { { qui le lâche : PNJ > 0, objet < 0 }, { qui le vend } }")
    w("--   names[langue] = les noms traduits (ceux qui diffèrent de l'anglais), une ligne chacun : « n<id>=nom »")
    w("--     pour un PNJ, « o<id>=nom » pour un objet ; en zlib puis base64 (seule ta langue est décodée).")
    w("local _, root = ...")
    w("local ns = root.Plus")
    w("")
    w("ns.QuestData = {")
    w("\tbuild = %s," % lstr("QuestieDB %s" % db.version))
    w("\tquests = {")
    for qid in sorted(quests):
        w("\t\t[%d] = %s," % (qid, lua(quests[qid]["rec"])))
    w("\t},")
    w("\tnpcs = {")
    for e in sorted(npcs):
        w("\t\t[%d] = %s," % (e, lua(npcs[e])))
    w("\t},")
    w("\tobjects = {")
    for e in sorted(objects):
        w("\t\t[%d] = %s," % (e, lua(objects[e])))
    w("\t},")
    w("\titems = {")
    for it in sorted(items):
        w("\t\t[%d] = %s," % (it, lua(items[it])))
    w("\t},")
    w("\tnames = {")
    for loc in LOCALES:
        # (une ligne par nom : « n<id>=nom » pour un PNJ, « o<id>=nom » pour un objet ; en zlib puis base64)
        text = []
        for tag, entity, keep in (("n", "Npc", npcs), ("o", "Object", objects)):
            names = db.names(loc, entity)
            for e in sorted(keep):
                n = names.get(e)
                if n and n != keep[e][0] and "\n" not in n:
                    text.append("%s%d=%s" % (tag, e, n))
        blob = base64.b64encode(zlib.compress("\n".join(text).encode("utf-8"), 9)).decode("ascii")
        w("\t\t%s = %s," % (loc, lstr(blob)))
    w("\t},")
    w("}")

    body = "\n".join(lines) + "\n"
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(body)
    print(OUT)
    print("  %d quêtes, %d PNJ, %d objets du monde, %d objets de quête, %d points (%d hors des cartes connues)"
          % (len(quests), len(npcs), len(objects), len(items), npoints, lost[0]))
    print("  %.0f Ko" % (len(body.encode("utf-8")) / 1024))
    maps = defaultdict(int)
    for n in npcs.values():
        for ui in (n[5] or {}):
            maps[ui] += 1
    print("  cartes : %d (Rives Claires, 2548 : %d PNJ)" % (len(maps), maps.get(2548, 0)))
    if 7 in quests:
        print("  contrôle : quête 7 %r, cibles %s" % (quests[7]["rec"][0], quests[7]["rec"][9]))
    # (la date de la dernière synchronisation avec GitHub : le crochet de fin de tâche de Claude Code
    # la regarde, .claude/settings.local.json)
    if "--fetch" in sys.argv:
        with open(os.path.join(SOURCE, "last_sync.txt"), "w", encoding="ascii") as f:
            f.write(datetime.date.today().isoformat())


if __name__ == "__main__":
    main()
