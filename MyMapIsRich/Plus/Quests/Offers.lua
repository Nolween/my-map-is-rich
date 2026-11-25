-- Les quêtes que tu peux prendre (les « ! » de Layers/QuestMarks.lua), d'après
-- la base des quêtes (Quests/Db.lua) et ton personnage, avec les règles que
-- Questie applique sur Forever :
--   - pas une quête que Questie ne propose jamais (sa liste noire : doublons,
--     quêtes retirées ou absentes de Forever ; ses fêtes ; l'effort de guerre
--     d'Ahn'Qiraj), ni une quête dont aucun donneur n'apparaît dans le monde ;
--   - ta race et ta classe (les masques de la quête), ta faction (le donneur
--     doit t'être amical) ;
--   - ton niveau : au moins le niveau requis (sans niveau requis dans la base :
--     celui de la quête), au plus le niveau maxi ;
--   - pas déjà faite, pas dans ton journal, ni sa quête suivante ;
--   - ses prérequis : une parmi plusieurs, sinon toutes celles du groupe (une
--     quête du groupe compte aussi si l'une de ses exclusives est faite) ;
--   - aucune de ses quêtes exclusives faite ou en cours ; pas une quête qui ne
--     fait que mener à une autre déjà prise, ni une quête dont une quête qui y
--     mène est en cours, ni une quête bloquée par une quête en cours ;
--   - la quête qu'elle demande d'avoir en cours (ou prise, ou faite), le sort
--     qu'elle demande de connaître (ou d'ignorer), la réputation qu'elle
--     demande ; pas une quête de métier.
--   Offers.List()      -> { { id, trivial = vrai : grise }, ... }, gardée jusqu'au
--                         prochain changement du journal (QUESTS_CHANGED) ; dans
--                         un long travail (ns.Job), elle se fait par tranches
--   Offers.Check(id)   -> nil si tu peux la prendre, sinon la règle qui s'y
--                         oppose (une clé WHY_Q_ des Locales) et ce qu'elle vise
--   Offers.Why(id)     -> la même raison, en toutes lettres (/mmir pourquoi)
-- Les quêtes que le joueur a cachées de la carte (la fiche d'un marqueur),
-- par personnage, dans ns.char.hiddenQuests : Offers.Hidden(id),
-- Offers.Hide({ id, ... }), Offers.Unhide(), Offers.NumHidden().
local _, root = ...
local ns = root.Plus
local L = ns.L

ns.Quests = ns.Quests or {}
local Offers = {}
ns.Quests.Offers = Offers

local Db = ns.Quests.Db
local Log = ns.Quests.Log
local band = bit and bit.band

local list

local function Bit(n) return n and n > 0 and 2 ^ (n - 1) or 0 end

local function Has(mask, b)
    if not mask or mask == 0 or b == 0 or not band then return true end
    return band(mask, b) ~= 0
end

-- Une quête grise (trop facile) pour ton niveau
local function Trivial(level, mine)
    if not level or level <= 0 then return false end
    local range = (GetQuestGreenRange and GetQuestGreenRange("player")) or 8
    return mine - level > range
end

-- Ta réputation auprès d'une faction (nil : inconnue)
local function Standing(faction)
    local get = _G.GetFactionInfoByID
    if not get then return end
    local ok, _, _, _, _, _, value = pcall(get, faction)
    return ok and type(value) == "number" and value or nil
end

local function RepOK(minRep, maxRep)
    if minRep then
        local v = Standing(minRep[1])
        if not v or v < (minRep[2] or 0) then return false end
    end
    if maxRep then
        local v = Standing(maxRep[1])
        if v and v >= (maxRep[2] or 0) then return false end
    end
    return true
end

-- requiredSpell : > 0, à connaître ; < 0, à ne pas connaître
local function SpellOK(spell)
    if not spell or spell == 0 then return true end
    local known = _G.IsSpellKnown or (C_SpellBook and C_SpellBook.IsSpellKnown)
    if not known then return true end
    local ok, yes = pcall(known, math.abs(spell))
    if not ok then return true end
    if spell > 0 then return yes and true or false end
    return not yes
end

-- Une quête du groupe de prérequis : faite, ou l'une de ses exclusives faite
-- (id < 0 : faite, sans regarder ses exclusives)
-- (faite ; pour « bientôt prête », une quête de ton journal compte comme faite : assume)
local assume
local function Done(id) return Log.Done(id) or (assume ~= nil and assume[id] ~= nil) end

local function GroupDone(id)
    if id < 0 then return Done(-id) end
    if Done(id) then return true end
    local q = Db.Quest(id)
    for _, other in ipairs(q and q.exclusive or {}) do
        if Done(other) then return true end
    end
    return false
end

-- Ce qui ferme la quête (ses prérequis, ses voisines), sinon nil : la clé de
-- la règle, et la quête qu'elle vise (l'id ; nil : à retrouver dans Why)
local function Closed(q, inLog)
    if #q.preAny > 0 then
        local any = false
        for _, id in ipairs(q.preAny) do
            if Done(id) then
                any = true
                break
            end
        end
        if not any then return "WHY_Q_PRE_ANY" end
    else
        -- (le groupe ne compte que sans « une parmi » : comme Questie)
        for _, id in ipairs(q.preAll) do
            if not GroupDone(id) then return "WHY_Q_PRE" end
        end
    end
    if q.parent and not inLog[q.parent] then return "WHY_Q_PARENT", q.parent end
    if q.nextInChain and (inLog[q.nextInChain] or Log.Done(q.nextInChain)) then return "WHY_Q_LATER", q.nextInChain end
    for _, id in ipairs(q.exclusive) do
        if inLog[id] or Log.Done(id) then return "WHY_Q_EXCLUSIVE", id end
    end
    if q.breadcrumb and (inLog[q.breadcrumb] or Log.Done(q.breadcrumb)) then return "WHY_Q_BREADCRUMB", q.breadcrumb end
    for _, id in ipairs(q.breadcrumbs) do
        if inLog[id] then return "WHY_Q_LEADS", id end
    end
    if q.disabledBy and inLog[q.disabledBy] then return "WHY_Q_BLOCKED", q.disabledBy end
    if q.untilDone and Log.Done(q.untilDone) then return "WHY_Q_UNTIL", q.untilDone end
    if q.startWith and not (inLog[q.startWith] or Log.Done(q.startWith)) then return "WHY_Q_START_WITH", q.startWith end
end

-- Ton personnage, une fois pour toute la liste
local function Me()
    local _, _, raceID = UnitRace("player")
    local _, _, classID = UnitClass("player")
    return { level = UnitLevel("player") or 1, race = Bit(raceID), class = Bit(classID),
        side = UnitFactionGroup("player") == "Horde" and 2 or 1, inLog = Log.Quests() }
end

-- La règle qui t'empêche de prendre la quête (une clé WHY_Q_, et ce qu'elle
-- vise : un niveau, une quête), ou nil : tu peux la prendre
local function Check(id, me)
    local q = Db.Quest(id)
    if not q then return "WHY_Q_UNKNOWN" end
    if me.inLog[id] then return "WHY_Q_IN_LOG" end
    if q.hidden then return "WHY_Q_HIDDEN" end
    if q.skill then return "WHY_Q_SKILL" end
    if #q.starts == 0 then return "WHY_Q_NO_GIVER" end
    -- (une quête sans niveau requis dans la base : son propre niveau, comme Questie)
    local need = q.minLevel > 0 and q.minLevel or q.level
    if need > me.level then return "WHY_Q_LEVEL_LOW", need end
    if q.maxLevel > 0 and me.level > q.maxLevel then return "WHY_Q_LEVEL_HIGH", q.maxLevel end
    if not Has(q.races, me.race) then return "WHY_Q_RACE" end
    if not Has(q.classes, me.class) then return "WHY_Q_CLASS" end
    -- (au moins un donneur qui t'est amical)
    local friendly = false
    for _, ref in ipairs(q.starts) do
        if band and band(Db.React(ref), me.side) ~= 0 then
            friendly = true
            break
        end
    end
    if not friendly then return "WHY_Q_FACTION" end
    -- (une quête répétable se reprend : faite ou non, elle reste proposée)
    if not q.repeatable and Log.Done(id) then return "WHY_Q_DONE" end
    local key, arg = Closed(q, me.inLog)
    if key then return key, arg end
    if not SpellOK(q.spell) then return "WHY_Q_SPELL" end
    if not RepOK(q.rep, q.maxRep) then return "WHY_Q_REP" end
end

-- (les listes se font à part et ne sont gardées qu'entières : faites par un
-- long travail, ns.Job, elles peuvent s'arrêter en route, ns.Slice ; refaites
-- d'ici là, gen a changé, elles ne sont pas gardées)
local gen = 0
local SLICE_EVERY = 25          -- quêtes passées en revue entre deux ns.Slice

function Offers.List()
    if list then return list end
    local out, mine, n = {}, gen, 0
    if not Db.Has() then return out end
    local me = Me()
    Db.EachQuest(function(id)
        if not Check(id, me) then
            local q = Db.Quest(id)
            out[#out + 1] = { id = id, trivial = Trivial(q.level, me.level) }
        end
        n = n + 1
        if n % SLICE_EVERY == 0 then ns.Slice() end
    end)
    if mine == gen then list = out end
    return out
end

function Offers.Check(id)
    if not Db.Has() then return "WHY_Q_UNKNOWN" end
    return Check(id, Me())
end

-- Les quêtes bientôt prêtes : à SOON niveaux au plus de toi (tout le reste
-- y est), ou dont il ne manque que des prérequis déjà dans ton journal.
-- { { id, why = la raison en toutes lettres }, ... }, gardée comme la liste
local SOON = 2
local soon
function Offers.Soon()
    if soon then return soon end
    local out, mine, n = {}, gen, 0
    if not Db.Has() then return out end
    local me = Me()
    local later = Me()
    Db.EachQuest(function(id)
        n = n + 1
        if n % SLICE_EVERY == 0 then ns.Slice() end
        local key, arg = Check(id, me)
        local ok = false
        if key == "WHY_Q_LEVEL_LOW" and arg <= me.level + SOON then
            later.level = arg
            ok = Check(id, later) == nil
        elseif key == "WHY_Q_PRE" or key == "WHY_Q_PRE_ANY" then
            -- (les prérequis de ton journal comptés comme faits : toutes les autres règles y passent encore)
            assume = me.inLog
            ok = Check(id, me) == nil
            assume = nil
        end
        if ok then out[#out + 1] = { id = id } end
    end)
    if mine == gen then soon = out end
    return out
end

-- (soon est refaite avec la liste : plus bas)

-- Une quête grise pour toi
function Offers.Trivial(id)
    local q = Db.Quest(id)
    return q and Trivial(q.level, UnitLevel("player") or 1) or false
end

-- Les listes ne dépendent que des quêtes du journal, des quêtes faites et de
-- ton niveau, pas des compteurs d'un objectif : refaites seulement quand
-- l'un d'eux change (un monstre tué ne relit pas les 6 000 quêtes)
local signature
ns.On("QUESTS_CHANGED", function()
    local ids = {}
    for id in pairs(Log.Quests()) do ids[#ids + 1] = id end
    table.sort(ids)
    -- (une quête rendue, prise, abandonnée change le journal : les quêtes faites suivent)
    local sig = (UnitLevel("player") or 0) .. ":" .. table.concat(ids, ",")

    if sig == signature then return end
    signature = sig
    list, soon, gen = nil, nil, gen + 1
end)
-- (une réputation, un sort appris changent aussi ce qui est proposé)
local refresh = CreateFrame("Frame")
refresh:SetScript("OnEvent", function() signature = nil end)
for _, e in ipairs({ "UPDATE_FACTION", "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED" }) do pcall(refresh.RegisterEvent, refresh, e) end


---------------------------------------------------------------------------
-- Les quêtes cachées par le joueur (par personnage)
---------------------------------------------------------------------------
local function HiddenTable()
    local char = ns.char
    if not char then return end
    char.hiddenQuests = char.hiddenQuests or {}
    return char.hiddenQuests
end

function Offers.Hidden(id)
    local t = ns.char and ns.char.hiddenQuests
    return t and t[id] and true or false
end

function Offers.Hide(ids)
    local t = HiddenTable()
    if not t then return end
    for _, id in ipairs(ids) do t[id] = true end
    ns.Fire("QUESTS_HIDDEN")
end

function Offers.Unhide()
    local t = HiddenTable()
    if t then wipe(t) end
    ns.Fire("QUESTS_HIDDEN")
end

function Offers.NumHidden()
    local n = 0
    for _ in pairs(ns.char and ns.char.hiddenQuests or {}) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Pourquoi une quête n'a pas de « ! » (/mmir pourquoi)
---------------------------------------------------------------------------
-- (des titres de quêtes, trois au plus)
local function Titles(ids)
    local out = {}
    for i, id in ipairs(ids) do
        if i > 3 then
            out[#out + 1] = "..."
            break
        end
        out[#out + 1] = Db.Title(math.abs(id))
    end
    return table.concat(out, ", ")
end

function Offers.Why(id)
    local key, arg = Offers.Check(id)
    if not key then
        if Offers.Hidden(id) then return L.WHY_Q_YOURS end
        if Offers.Trivial(id) and ns.Map.Settings.Get("questOffersGrey") ~= true then return L.WHY_Q_GREY end
        return L.WHY_Q_OFFERED
    end
    local q = Db.Quest(id)
    if key == "WHY_Q_PRE" then
        local missing = {}
        for _, pre in ipairs(q.preAll) do
            if not GroupDone(pre) then missing[#missing + 1] = pre end
        end
        arg = Titles(missing)
    elseif key == "WHY_Q_PRE_ANY" then
        arg = Titles(q.preAny)
    elseif key ~= "WHY_Q_LEVEL_LOW" and key ~= "WHY_Q_LEVEL_HIGH" and arg then
        arg = Db.Title(arg)
    end
    return L[key]:format(arg)
end

-- /mmir pourquoi <numéro ou nom> : la quête retrouvée (dans ton journal, puis
-- dans la base, par son titre anglais ou celui que le jeu sait), et sa raison
function Offers.Explain(text)
    text = strtrim(text or "")
    if not Db.Has() then
        ns.Print(L.PROBE_QUESTS_NO_BASE)
        return
    end
    if text == "" then
        ns.Print(L.WHY_Q_USAGE)
        return
    end
    local found = {}
    local id = tonumber(text:match("^#?(%d+)$"))
    if id then
        found[1] = id
    else
        local want = text:lower()
        local exact
        local function Look(qid, title)
            if type(title) ~= "string" or exact then return end
            local t = title:lower()
            if t == want then
                exact = qid
            elseif t:find(want, 1, true) and #found < 6 then
                for _, other in ipairs(found) do
                    if other == qid then return end
                end
                found[#found + 1] = qid
            end
        end
        for qid, q in pairs(Log.Quests()) do Look(qid, q.title) end
        if not exact then
            Db.EachQuest(function(qid)
                local q = Db.Quest(qid)
                Look(qid, q and q.title)
            end)
        end
        if not exact and #found == 0 then
            Db.EachQuest(function(qid) Look(qid, Db.Title(qid)) end)
        end
        if exact then found = { exact } end
    end
    if #found == 0 then
        ns.Print(L.WHY_Q_NOT_FOUND:format(text))
        return
    end
    if #found > 1 then
        ns.Print(L.WHY_Q_MANY)
        for i, qid in ipairs(found) do
            if i > 5 then break end
            ns.Print(("  [%d] %s"):format(qid, Db.Title(qid)))
        end
        return
    end
    ns.Print(L.WHY_Q_LINE:format(found[1], Db.Title(found[1]), Offers.Why(found[1])))
end
