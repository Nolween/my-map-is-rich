"""Lire la base Forever de QuestieDB (https://github.com/Questie/QuestieDB, données sous
GPLv3 : voir son LICENSE.md) telle que ses versions la livrent : un QuestieDB_Forever.toc
« cuit », où chaque valeur est une métadonnée « ## X-<Entité>-<id>-<champ>: <base64> »
(du CBOR, compressé en zlib pour les listes d'ids et les blocs de traductions), plus ses
tables de zones en Lua (support/Forever/Zones/).

Ce module ne fait que décoder : build_quests.py choisit ce qu'il garde.

    db = QuestieDB(dossier)            # le dossier QuestieDB (celui de l'addon, ou de l'archive)
    db.ids("Quest")                    # les ids, croissants
    db.row("Npc", 299)                 # { index de champ : valeur } (les champs tableau compris)
    db.names("frFR", "Npc")            # { id : nom traduit }
    db.area_to_uimap, db.instance_to_area, db.dungeons
"""

import base64
import os
import re
import struct
import zlib


# ---------------------------------------------------------------------------
# CBOR (RFC 8949) : ce dont les données ont besoin
# ---------------------------------------------------------------------------
class _Cbor:
    def __init__(self, data):
        self.d = data
        self.i = 0

    def _arg(self, info):
        if info < 24:
            return info
        size = {24: 1, 25: 2, 26: 4, 27: 8}.get(info)
        if size is None:
            raise ValueError("CBOR : longueur indéfinie non prise en charge")
        v = int.from_bytes(self.d[self.i:self.i + size], "big")
        self.i += size
        return v

    def item(self):
        b = self.d[self.i]
        self.i += 1
        major, info = b >> 5, b & 31
        if major == 0:
            return self._arg(info)
        if major == 1:
            return -1 - self._arg(info)
        if major in (2, 3):
            n = self._arg(info)
            raw = self.d[self.i:self.i + n]
            self.i += n
            # (les textes de QuestieDB sont des chaînes d'octets : en UTF-8)
            return raw.decode("utf-8", "replace")
        if major == 4:
            return [self.item() for _ in range(self._arg(info))]
        if major == 5:
            out = {}
            for _ in range(self._arg(info)):
                k = self.item()
                out[k] = self.item()
            return out
        if major == 6:
            self._arg(info)
            return self.item()          # (une étiquette : la valeur seule)
        # major 7
        if info == 20:
            return False
        if info == 21:
            return True
        if info in (22, 23):
            return None
        if info == 25:
            h = int.from_bytes(self.d[self.i:self.i + 2], "big")
            self.i += 2
            return struct.unpack(">e", h.to_bytes(2, "big"))[0]
        if info == 26:
            v = struct.unpack(">f", self.d[self.i:self.i + 4])[0]
            self.i += 4
            return v
        if info == 27:
            v = struct.unpack(">d", self.d[self.i:self.i + 8])[0]
            self.i += 8
            return v
        return self._arg(info)


def cbor(data):
    return _Cbor(data).item()


def lua_list(v):
    """Une table Lua en CBOR : une liste (1, 2, ...), ou un dictionnaire aux clés entières
    (une table à trous) ; rendue en liste Python, avec None aux trous."""
    if isinstance(v, list):
        return v
    if isinstance(v, dict):
        keys = [k for k in v if isinstance(k, int)]
        if not keys:
            return []
        return [v.get(k) for k in range(1, max(keys) + 1)]
    return []


def at(v, i):
    """Le i-ème élément (à partir de 1) d'une table Lua décodée."""
    if isinstance(v, list):
        return v[i - 1] if 0 < i <= len(v) else None
    if isinstance(v, dict):
        return v.get(i)
    return None


# ---------------------------------------------------------------------------
# Les tables Lua simples des fichiers support/ : { [n] = n, ... }
# ---------------------------------------------------------------------------
def lua_number_map(text):
    return {int(k): int(v) for k, v in re.findall(r"\[(-?\d+)\]\s*=\s*(-?\d+)", text)}


class QuestieDB:
    FIELDS = {"Quest": 36, "Npc": 15, "Object": 7, "Item": 16}
    TABLES = {
        "Quest": {2, 3, 8, 9, 10, 12, 13, 14, 15, 16, 18, 19, 20, 21, 26, 28, 29, 35},
        "Npc": {7, 8, 10, 11},
        "Object": {2, 3, 4, 7},
        "Item": {2, 3, 4, 6, 14, 15},
    }

    def __init__(self, folder):
        self.folder = folder
        toc = os.path.join(folder, "QuestieDB_Forever.toc")
        if not os.path.exists(toc):
            raise SystemExit("pas de QuestieDB_Forever.toc dans %s" % folder)
        self.meta = {}
        with open(toc, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("## X-"):
                    k, _, v = line[3:].partition(":")
                    self.meta[k.strip()] = v.strip()
        self.version = self._plain("Version", toc)
        self.commit = self.meta.get("X-BUILD-COMMIT", "")
        self._ids = {}
        zones = os.path.join(folder, "support", "Forever", "Zones")
        self.area_to_uimap = self._area_to_uimap(os.path.join(zones, "areaIdToUiMapId.lua"))
        # (instanceIdToAreaId nomme ses zones par les constantes de src/corrections/enum/zones.lua)
        consts = {}
        with open(os.path.join(folder, "src", "corrections", "enum", "zones.lua"), encoding="utf-8") as f:
            consts = {k: int(v) for k, v in re.findall(r"([A-Z][A-Z0-9_]+)\s*=\s*(-?\d+)", f.read())}
        self.instance_to_area = {}
        with open(os.path.join(zones, "instanceIdToAreaId.lua"), encoding="utf-8") as f:
            for inst, val in re.findall(r"\[(\d+)\]\s*=\s*([\w.]+)", f.read()):
                area = int(val) if val.isdigit() else consts.get(val.split(".")[-1])
                if area:
                    self.instance_to_area[int(inst)] = area
        self.faction_enemy = {}
        ft = os.path.join(folder, "support", "Forever", "FactionTemplates", "factionTemplateClassic.lua")
        if os.path.exists(ft):
            with open(ft, encoding="utf-8") as f:
                self.faction_enemy = lua_number_map(f.read())

    @staticmethod
    def _plain(key, toc):
        with open(toc, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("## %s:" % key):
                    return line.split(":", 1)[1].strip()
        return ""

    @staticmethod
    def _area_to_uimap(path):
        """La table principale, puis ses remplacements (areaIdToUiMapIdOverride)."""
        with open(path, encoding="utf-8") as f:
            text = f.read()
        blocks = re.findall(r"(\w+)\s*=\s*\[\[return\s*\{(.*?)\}\]\]", text, re.S)
        main, over = {}, {}
        for name, body in blocks:
            (over if "Override" in name else main).update(lua_number_map(body))
        main.update(over)
        return main

    # --- les valeurs ---------------------------------------------------------
    def stored(self, key):
        v = self.meta.get(key)
        if v is None:
            return None
        m = re.match(r"^~(\d+)~$", v)
        if m:
            return "".join(self.meta[key + "-%d" % i] for i in range(1, int(m.group(1)) + 1))
        return v

    def ids(self, entity):
        if entity not in self._ids:
            raw = base64.b64decode(self.stored("X-%s-IDS" % entity))
            self._ids[entity] = sorted(cbor(zlib.decompress(raw)))
        return self._ids[entity]

    def row(self, entity, eid):
        s = self.stored("X-%s-%d-S" % (entity, eid))
        if s is None:
            return None
        scalar = cbor(base64.b64decode(s))
        out = {}
        if isinstance(scalar, dict):
            present = scalar.get("p", 0) or 0
            for k, v in scalar.items():
                if isinstance(k, int):
                    out[k] = v
        else:
            present = 0
            for i, v in enumerate(scalar, 1):
                out[i] = v
        for field in self.TABLES[entity]:
            if (present >> (field - 1)) & 1:
                t = self.stored("X-%s-%d-%d" % (entity, eid, field))
                if t is not None:
                    out[field] = cbor(base64.b64decode(t))
        return out

    def names(self, locale, entity, column=1):
        """{ id : nom } dans une langue (une colonne du bloc, alignée sur les ids : 1 le nom,
        2 le sous-titre d'un PNJ)."""
        s = self.stored("X-l10n-%s-%s" % (locale, entity))
        if s is None:
            return {}
        block = cbor(zlib.decompress(base64.b64decode(s)))
        col = lua_list(at(block, column))
        ids = self.ids(entity)
        return {ids[i]: n for i, n in enumerate(col) if isinstance(n, str) and n and i < len(ids)}
