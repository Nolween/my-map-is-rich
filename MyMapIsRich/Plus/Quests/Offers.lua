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
--   Offers.List()  -> { { id, trivial = vrai : grise }, ... }, gardée jusqu'au
--                     prochain changement du journal (QUESTS_CHANGED)
local _, root = ...
local ns = root.Plus

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
local function GroupDone(id)
    if id < 0 then return Log.Done(-id) end
    if Log.Done(id) then return true end
    local q = Db.Quest(id)
    for _, other in ipairs(q and q.exclusive or {}) do
        if Log.Done(other) then return true end
    end
    return false
end

local function Open(q, inLog)
    if #q.preAny > 0 then
        local any = false
        for _, id in ipairs(q.preAny) do
            if Log.Done(id) then
                any = true
                break
            end
        end
        if not any then return false end
    else
        -- (le groupe ne compte que sans « une parmi » : comme Questie)
        for _, id in ipairs(q.preAll) do
            if not GroupDone(id) then return false end
        end
    end
    if q.parent and not inLog[q.parent] then return false end
    if q.nextInChain and (inLog[q.nextInChain] or Log.Done(q.nextInChain)) then return false end
    for _, id in ipairs(q.exclusive) do
        if inLog[id] or Log.Done(id) then return false end
    end
    if q.breadcrumb and (inLog[q.breadcrumb] or Log.Done(q.breadcrumb)) then return false end
    for _, id in ipairs(q.breadcrumbs) do
        if inLog[id] then return false end
    end
    if q.disabledBy and inLog[q.disabledBy] then return false end
    if q.untilDone and Log.Done(q.untilDone) then return false end
    if q.startWith and not (inLog[q.startWith] or Log.Done(q.startWith)) then return false end
    return true
end

function Offers.List()
    if list then return list end
    list = {}
    if not Db.Has() then return list end
    local mine = UnitLevel("player") or 1
    local _, _, raceID = UnitRace("player")
    local _, _, classID = UnitClass("player")
    local race, class = Bit(raceID), Bit(classID)
    local side = UnitFactionGroup("player") == "Horde" and 2 or 1
    local inLog = Log.Quests()
    Db.EachQuest(function(id)
        local q = Db.Quest(id)
        if not q or inLog[id] or q.hidden or q.skill or #q.starts == 0 then return end
        -- (une quête sans niveau requis dans la base : son propre niveau, comme Questie)
        local need = q.minLevel > 0 and q.minLevel or q.level
        if need > mine or (q.maxLevel > 0 and mine > q.maxLevel) then return end
        if not Has(q.races, race) or not Has(q.classes, class) then return end
        -- (au moins un donneur qui t'est amical)
        local friendly = false
        for _, ref in ipairs(q.starts) do
            if band and band(Db.React(ref), side) ~= 0 then
                friendly = true
                break
            end
        end
        if not friendly or Log.Done(id) or not Open(q, inLog) or not SpellOK(q.spell)
            or not RepOK(q.rep, q.maxRep) then return end
        list[#list + 1] = { id = id, trivial = Trivial(q.level, mine) }
    end)
    return list
end

ns.On("QUESTS_CHANGED", function() list = nil end)
