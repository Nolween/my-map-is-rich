"""Les quêtes que Questie ne propose jamais sur WoW Forever : sa liste noire
(Database/Corrections/QuestieQuestBlacklist.lua : doublons, quêtes retirées ou
absentes du jeu, effort de guerre d'Ahn'Qiraj, invasion) et ses quêtes de fêtes
(Database/Corrections/Holidays/quests/*.lua). Ces fichiers sont dans l'addon Questie
(https://github.com/Questie/Questie, même licence que QuestieDB : copie permise sous
GPLv3), pas dans QuestieDB.
S'y ajoutent les étiquettes que Questie corrige (Database/Corrections/
questTagInfoCorrections.lua : élite, donjon, raid, JcJ... là où le jeu se trompe ;
ailleurs, l'addon demande au jeu).

Rien n'est exécuté : chaque ligne « [id] = valeur, » est lue comme une donnée, et sa
valeur évaluée par une petite grammaire fermée (true, false, not, and, or, parenthèses,
comparaisons, Expansions.*, Questie.Is*, ContentPhases.activePhases.*), comme Questie
la verrait sur Forever (contenu Era, Questie.IsForever). Une valeur hors de cette
grammaire est laissée de côté et comptée.

    hidden, skipped = questie_hidden(dossier)   # { id de quête : raison }, nombre ignoré
    tags, skipped = questie_tags(dossier)       # { id de quête : étiquette (1 élite, 81 donjon...) }
"""

import json
import os
import re
import urllib.parse
import urllib.request

RELEASES = "https://api.github.com/repos/Questie/Questie/releases/latest"
RAW = "https://raw.githubusercontent.com/Questie/Questie/%s/%s"
CONTENTS = "https://api.github.com/repos/Questie/Questie/contents/%s?ref=%s"
BLACKLIST = "Database/Corrections/QuestieQuestBlacklist.lua"
HOLIDAYS = "Database/Corrections/Holidays/quests"
TAGS = "Database/Corrections/questTagInfoCorrections.lua"
HEADERS = {"User-Agent": "build-quests"}


def _get(url, as_json=False):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS)) as r:
        data = r.read()
    return json.loads(data) if as_json else data


def fetch(source):
    """La liste noire, les fêtes et les étiquettes de la dernière version de Questie, dans
    source/Questie-<version>/."""
    tag = _get(RELEASES, True)["tag_name"]           # (ex. « bundle/v12.14.0+v1.1.6 »)
    version = re.search(r"(\d+\.\d+\.\d+)", tag).group(1)
    ref = urllib.parse.quote(tag, safe="")
    dest = os.path.join(source, "Questie-%s" % version)
    if os.path.exists(os.path.join(dest, *BLACKLIST.split("/"))):
        files = [p for p in (TAGS,) if not os.path.exists(os.path.join(dest, *p.split("/")))]
        if not files:
            print("déjà là : %s" % dest)
            return dest
    else:
        print("téléchargement de la liste noire de Questie %s" % tag)
        files = [BLACKLIST, TAGS, "LICENSE.md"] + [
            f["path"] for f in _get(CONTENTS % (HOLIDAYS, ref), True) if f["name"].endswith(".lua")]
    for path in files:
        out = os.path.join(dest, *path.split("/"))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "wb") as f:
            f.write(_get(RAW % (ref, path)))
    return dest


def newest(source):
    best = None
    if os.path.isdir(source):
        for d in os.listdir(source):
            m = re.match(r"Questie-(\d+)\.(\d+)\.(\d+)", d)
            if m and os.path.exists(os.path.join(source, d, *BLACKLIST.split("/"))):
                key = tuple(int(x) for x in m.groups())
                if not best or key > best[0]:
                    best = (key, os.path.join(source, d))
    return best and best[1]


# ---------------------------------------------------------------------------
# La grammaire : Questie sur Forever (WOW_PROJECT_CAMELOT : contenu Era)
# ---------------------------------------------------------------------------
NAMES = {
    "true": True, "false": False, "nil": False, "HIDE_ON_MAP": True,
    "Expansions.Era": 1, "Expansions.Tbc": 2, "Expansions.Wotlk": 3, "Expansions.Cata": 4,
    "Expansions.MoP": 5, "Expansions.Current": 1,
    "Questie.IsForever": True, "Questie.IsEra": True, "Questie.IsClassic": True,
}
TOKEN = re.compile(r"\s*(>=|<=|~=|==|[<>()]|\d+|[A-Za-z_][A-Za-z_0-9.]*)")


class _Unknown(Exception):
    pass


def _tokens(expr):
    pos, out = 0, []
    expr = expr.strip()
    while pos < len(expr):
        m = TOKEN.match(expr, pos)
        if not m:
            raise _Unknown(expr)
        out.append(m.group(1))
        pos = m.end()
    return out


def evaluate(expr):
    """La valeur d'une expression Lua de la liste noire (grammaire fermée), ou _Unknown."""
    toks = _tokens(expr)
    i = 0

    def atom():
        nonlocal i
        t = toks[i]
        i += 1
        if t == "(":
            v = disj()
            if i >= len(toks) or toks[i] != ")":
                raise _Unknown(expr)
            i += 1
            return v
        if t == "not":
            return not cmp()
        if t.isdigit():
            return int(t)
        if t in NAMES:
            return NAMES[t]
        if re.match(r"^Questie\.Is\w+$", t):
            return False                                    # (les autres variantes du jeu)
        if re.match(r"^ContentPhases\.activePhases\.\w+$", t):
            return 0
        raise _Unknown(t)

    def cmp():
        nonlocal i
        v = atom()
        if i < len(toks) and toks[i] in (">=", "<=", "~=", "==", "<", ">"):
            op = toks[i]
            i += 1
            w = atom()
            v = {">=": v >= w, "<=": v <= w, "~=": v != w, "==": v == w, "<": v < w, ">": v > w}[op]
        return v

    def conj():
        nonlocal i
        v = cmp()
        while i < len(toks) and toks[i] == "and":
            i += 1
            w = cmp()
            v = v and w
        return v

    def disj():
        nonlocal i
        v = conj()
        while i < len(toks) and toks[i] == "or":
            i += 1
            w = conj()
            v = v or w
        return v

    v = disj()
    if i != len(toks):
        raise _Unknown(expr)
    return v


ENTRY = re.compile(r"^\s*\[(\d+)\]\s*=\s*(.+?)\s*,\s*(?:--.*)?$")


def _entries(lines):
    """{ id : valeur } d'un morceau de la liste, et le nombre de valeurs ignorées."""
    out, skipped = {}, 0
    for line in lines:
        m = ENTRY.match(line)
        if not m:
            continue
        try:
            out[int(m.group(1))] = evaluate(m.group(2))
        except (_Unknown, IndexError, TypeError):
            skipped += 1
    return out, skipped


def questie_hidden(folder):
    with open(os.path.join(folder, *BLACKLIST.split("/")), encoding="utf-8") as f:
        lines = f.read().split("\n")
    # les morceaux : la table de Load(), puis QuestieQuestBlacklist.AQWarEffortQuests, .InvasionQuests...
    parts, name = {"main": []}, "main"
    for line in lines:
        m = re.match(r"^QuestieQuestBlacklist\.(\w+)\s*=\s*\{", line)
        if m:
            name = m.group(1)
            parts[name] = []
        elif re.match(r"^\s*(if|elseif|else)\b", line) and name == "main":
            name = "guarded"                            # (les ajouts sous condition, après la table : ignorés)
            parts.setdefault(name, [])
        parts[name].append(line)
    hidden, skipped = {}, 0
    main, n = _entries(parts["main"])
    skipped += n
    for qid, v in main.items():
        if v:
            hidden[qid] = "liste noire"
    for key, why in (("AQWarEffortQuests", "effort de guerre d'AQ"), ("InvasionQuests", "invasion")):
        t, n = _entries(parts.get(key, []))
        skipped += n
        for qid, v in t.items():
            if v:
                hidden.setdefault(qid, why)
    holidays = os.path.join(folder, *HOLIDAYS.split("/"))
    for name in sorted(os.listdir(holidays)) if os.path.isdir(holidays) else []:
        with open(os.path.join(holidays, name), encoding="utf-8") as f:
            for qid in re.findall(r"tinsert\(\s*eventQuests\s*,\s*\{\s*\"[^\"]*\"\s*,\s*(\d+)", f.read()):
                hidden.setdefault(int(qid), "fête")
    return hidden, skipped


# ---------------------------------------------------------------------------
# Les étiquettes : { id, l10n("Elite") } lu comme son id, la condition par la grammaire
# ---------------------------------------------------------------------------
TAG_VALUE = re.compile(r"\{\s*(\d+)\s*,\s*l10n\(\s*\"[^\"]*\"\s*\)\s*\}")


def questie_tags(folder):
    """{ id de quête : étiquette } telle que Questie la corrige sur Forever (1 élite, 41 JcJ,
    62 raid, 81 donjon...), et le nombre de valeurs ignorées ; {} sans le fichier."""
    path = os.path.join(folder, *TAGS.split("/"))
    if not os.path.exists(path):
        return {}, 0
    with open(path, encoding="utf-8") as f:
        lines = [TAG_VALUE.sub(r"\1", line) for line in f.read().split("\n")]
    values, skipped = _entries(lines)
    tags = {qid: v for qid, v in values.items() if isinstance(v, int) and not isinstance(v, bool) and v > 0}
    return tags, skipped
