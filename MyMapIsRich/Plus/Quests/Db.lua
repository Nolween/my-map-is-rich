-- La base des quêtes de My Map Is Rich (Data/Quests.lua, générée par
-- tools/quests/build_quests.py depuis la base Forever de QuestieDB, copiée
-- dans l'addon : rien d'autre à installer) : ce que le jeu ne dit pas, où
-- sont les donneurs, les monstres et les objets d'une quête.
--   Db.Quest(id)              la quête (ses champs nommés), ou nil
--   Db.Npc(id), Db.Object(id) le PNJ, l'objet du monde, ou nil
--   Db.Places(ref)            ses points sur la carte (u, v du monde) : ref > 0
--                             un PNJ, < 0 un objet ; un donjon : son entrée
--   Db.Explore(questID)       les lieux à explorer d'une quête (mêmes points)
--   Db.Sources(itemID)        qui lâche, où se ramasse, qui vend un objet
--   Db.Name(ref)              son nom dans la langue du joueur, si on l'a
-- Les points ne se décodent qu'une fois, à la première demande. Les noms
-- traduits : ceux de ta langue seulement, décodés au chargement (les autres
-- sont oubliés) ; ceux que le jeu montre quand tu croises un PNJ passent
-- devant (gardés par compte, dans MyMapIsRichPlusDB.questNames).
local _, root = ...
local ns = root.Plus

ns.Quests = ns.Quests or {}
local Db = {}
ns.Quests.Db = Db

local K = ns.Map.Coords
local NONE = {}

local data = type(ns.QuestData) == "table" and ns.QuestData or nil
local quests, places, explore = {}, {}, {}   -- les quêtes nommées, les points décodés
local localNames = { n = {}, o = {} }         -- les noms de la base dans la langue du joueur

-- Les noms traduits de ta langue (« n<id>=nom » ou « o<id>=nom », en zlib puis base64)
if data and type(data.names) == "table" then
    local blob = data.names[GetLocale and GetLocale() or "enUS"]
    if type(blob) == "string" and C_EncodingUtil and C_EncodingUtil.DecodeBase64 and C_EncodingUtil.DecompressString
        and Enum and Enum.CompressionMethod and Enum.CompressionMethod.Zlib then
        local ok, text = pcall(function()
            return C_EncodingUtil.DecompressString(C_EncodingUtil.DecodeBase64(blob), Enum.CompressionMethod.Zlib)
        end)
        if ok and type(text) == "string" then
            for kind, id, name in text:gmatch("([no])(%d+)=([^\n]+)") do localNames[kind][tonumber(id)] = name end
        end
    end
    data.names = nil
end

function Db.Has() return data ~= nil end
function Db.Build() return data and data.build end

---------------------------------------------------------------------------
-- Les quêtes
---------------------------------------------------------------------------
function Db.Quest(id)
    local q = quests[id]
    if q ~= nil then return q or nil end
    local r = data and data.quests[id]
    if not r then
        quests[id] = false
        return
    end
    q = {
        id = id, title = r[1], level = r[2] or 0, minLevel = r[3] or 0, maxLevel = r[4] or 0,
        races = r[5] or 0, classes = r[6] or 0, zone = r[7] or 0,
        starts = r[8] or NONE, ends = r[9] or NONE, goals = r[10] or NONE, items = r[11] or NONE,
        preAll = r[12] or NONE, exclusive = r[13] or NONE, breadcrumb = r[14] or nil, skill = r[15] or nil,
        rep = r[16] or nil, hidden = r[17] and true or false, explore = r[18] or nil,
        parent = r[19] or nil, spell = r[20] or nil, untilDone = r[21] or nil, startWith = r[22] or nil,
        preAny = r[23] or NONE, nextInChain = r[24] or nil, breadcrumbs = r[25] or NONE,
        disabledBy = r[26] or nil, maxRep = r[27] or nil,
    }
    quests[id] = q
    return q
end

-- Toutes les quêtes de la base : fn(id) pour chacune
function Db.EachQuest(fn)
    if not data then return end
    for id in pairs(data.quests) do fn(id) end
end

---------------------------------------------------------------------------
-- Les PNJ, les objets, leurs points
---------------------------------------------------------------------------
function Db.Npc(id)
    local r = data and data.npcs[id]
    if not r then return end
    return { id = id, name = r[1], minLevel = r[2], maxLevel = r[3], rank = r[4], react = r[5] or 0, inst = r[7] }
end

function Db.Object(id)
    local r = data and data.objects[id]
    if not r then return end
    return { id = -id, name = r[1], react = r[2] or 3, inst = r[4] }
end

-- La réaction d'un donneur : 1 amical envers l'Alliance, 2 envers la Horde
function Db.React(ref)
    if not data then return 3 end
    if ref > 0 then
        local r = data.npcs[ref]
        return r and r[5] or 0
    end
    local r = data.objects[-ref]
    return r and r[2] or 3
end

-- trois caractères (six bits chacun, le plus fort d'abord) : x ou y en % * 100 + 32768
local B64 = {}
do
    local abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, #abc do B64[abc:byte(i)] = i - 1 end
end

-- { [carte] = points } -> les points du monde, dans out
local function Decode(maps, out)
    if type(maps) ~= "table" then return end
    local byte = string.byte
    for mapID, s in pairs(maps) do
        if type(s) == "string" and K.Rect(mapID) then
            for i = 1, #s - 5, 6 do
                local a, b, c, d, e, f = byte(s, i, i + 5)
                local x = (B64[a] * 4096 + B64[b] * 64 + B64[c] - 32768) / 10000
                local y = (B64[d] * 4096 + B64[e] * 64 + B64[f] - 32768) / 10000
                local u, v = K.ToWorld(mapID, x, y)
                if u then out[#out + 1] = { u, v } end
            end
        end
    end
end

-- L'entrée d'un donjon (son mapID d'instance) et son niveau mini, d'après les lieux de la carte
local entrances
local function Entrance(mapID)
    if not entrances then
        entrances = {}
        local P = ns.Map.Data.Places and ns.Map.Data.Places()
        for _, g in ipairs(P and P.instances or NONE) do
            for _, inst in ipairs(g[4] or NONE) do
                if inst[1] and not entrances[inst[1]] then
                    local u, v = K.EntranceAt(g)
                    if u then entrances[inst[1]] = { u, v, inst[4] } end
                end
            end
        end
    end
    return entrances[mapID]
end

-- Les points d'un PNJ (ref > 0) ou d'un objet (ref < 0) : { { u, v } } ; à
-- l'entrée d'un donjon : inside (son mapID d'instance) et minLevel (son niveau mini)
function Db.Places(ref)
    local p = places[ref]
    if p then return p end
    p = {}
    local r = data and (ref > 0 and data.npcs[ref] or data.objects[-ref])
    if r then
        local maps, inst
        if ref > 0 then maps, inst = r[6], r[7] else maps, inst = r[3], r[4] end
        Decode(maps, p)
        for _, mapID in ipairs(inst or NONE) do
            local e = Entrance(mapID)
            if e then p[#p + 1] = { e[1], e[2], inside = mapID, minLevel = e[3] } end
        end
    end
    -- (seulement une fois la carte connue : les rectangles des cartes viennent du jeu)
    if #p > 0 or not r then places[ref] = p end
    return p
end

-- Les lieux à explorer d'une quête (un objectif « event » du jeu)
function Db.Explore(questID)
    local p = explore[questID]
    if p then return p end
    p = {}
    local q = Db.Quest(questID)
    if q and q.explore then Decode(q.explore, p) end
    if #p > 0 or not (q and q.explore) then explore[questID] = p end
    return p
end

-- Les sources d'un objet : { { ref, vendor = vrai : un marchand }, ... }
function Db.Sources(itemID)
    local r = data and data.items[itemID]
    local out = {}
    if r then
        for _, ref in ipairs(r[1] or NONE) do out[#out + 1] = { ref } end
        for _, ref in ipairs(r[2] or NONE) do out[#out + 1] = { ref, vendor = true } end
    end
    return out
end

---------------------------------------------------------------------------
-- Les noms
---------------------------------------------------------------------------
local function Learned()
    local db = ns.db
    if not db then return end
    db.questNames = db.questNames or {}
    local loc = GetLocale and GetLocale() or "enUS"
    db.questNames[loc] = db.questNames[loc] or {}
    return db.questNames[loc]
end

function Db.Name(ref)
    if not data or not ref then return end
    if ref > 0 then
        local seen = Learned()
        if seen and seen[ref] then return seen[ref] end
        local n = localNames.n[ref]
        if n then return n end
        local r = data.npcs[ref]
        return r and r[1]
    end
    local n = localNames.o[-ref]
    if n then return n end
    local r = data.objects[-ref]
    return r and r[1]
end

-- Le nom d'un PNJ croisé (survolé, ciblé, sa barre de nom) : retenu s'il est dans la base
local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Learn(unit)
    if not data or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local guid = Plain(UnitGUID(unit))
    if type(guid) ~= "string" then return end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind ~= "Creature" or not id then return end
    id = tonumber(id)
    if not data.npcs[id] then return end
    local name = Plain(UnitName(unit))
    local seen = Learned()
    if seen and type(name) == "string" and name ~= "" and name ~= _G.UNKNOWNOBJECT then seen[id] = name end
end

local learner = CreateFrame("Frame")
learner:SetScript("OnEvent", function(_, event, unit)
    if ns.Conflict and ns.Conflict() then return end
    if event == "UPDATE_MOUSEOVER_UNIT" then Learn("mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then Learn("target")
    elseif unit then Learn(unit) end
end)
for _, e in ipairs({ "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED" }) do
    pcall(learner.RegisterEvent, learner, e)
end
