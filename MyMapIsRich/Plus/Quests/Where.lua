-- Où aller pour une quête du journal, et à quelle distance : le point utile
-- le plus proche de toi, d'après la base des quêtes (Quests/Db.lua).
--   une quête finie   le PNJ qui la reprend (la base, sinon ce qui a été
--                     appris en jouant : Quests/Learn.lua)
--   sinon             le plus proche de ses objectifs pas finis : les monstres
--                     et les objets reliés par Log.Goals, les sources d'un objet
--                     à trouver, les lieux à explorer
--   à défaut          le point que le jeu donne à la quête (Travel/Quests.lua)
-- Un point dans un donjon : son entrée. La distance est à vol d'oiseau, en
-- yards, sur ton continent ; un point d'un autre continent n'en a pas (far).
--   Where.Of(questID [, here])   { u, v, cont, dist, far, kind = "turnin" | "goal" | "poi", name, spot }, ou nil
--   Where.Zone(w)                le nom de la zone où est ce point
--   Where.Point(questID)         le point du monde (Travel/Planner.lua) d'un itinéraire
--   Where.Route(questID)         l'itinéraire jusqu'à lui (sur la quête du trajet en cours : l'annule)
--   Where.Enqueue(questID)       l'ajouter à la file
--   Where.Routed(questID)        est-ce la destination du trajet en cours ?
-- Les endroits d'une quête sont gardés jusqu'au prochain changement du
-- journal (« QUESTS_CHANGED ») : seule la distance se recalcule quand on bouge.
-- Le suivi des quêtes (UI/Tracker.lua) et la liste des quêtes de la carte
-- (UI/QuestPanel.lua) disent ainsi la même distance.
local _, root = ...
local ns = root.Plus
local L = ns.L

ns.Quests = ns.Quests or {}
local Where = {}
ns.Quests.Where = Where

local Db = ns.Quests.Db
local Log = ns.Quests.Log
local K = ns.Map.Coords

local NONE = {}
local MAX_SOURCES = 40          -- les sources d'un objet regardées (un objet lâché par cent monstres : assez pour trouver le plus proche)
local CONTINENT_MAP = { [0] = 1415, [1] = 1414 }   -- continent du jeu -> sa carte (comme Map/Coords.lua)

local function Pl() return ns.TravelPlanner end

---------------------------------------------------------------------------
-- Les yards d'un point du monde
---------------------------------------------------------------------------
-- Le continent d'un point du monde (u, v) : celui dont la carte le contient
local function ContAt(u, v)
    for cont, mapID in pairs(CONTINENT_MAP) do
        local l, r, t, b = K.Rect(mapID)
        if l and u >= l and u <= r and v >= t and v <= b then return cont end
    end
end

-- (la projection des yards d'un continent sur le monde est linéaire : son
-- inverse, une fois par continent)
local basis = {}
local function Basis(cont)
    local b = basis[cont]
    if b then return b end
    local x0, y0 = K.FromYards(cont, 0, 0)
    local x1, y1 = K.FromYards(cont, 1000, 0)
    local x2, y2 = K.FromYards(cont, 0, 1000)
    if not (x0 and x1 and x2) then return end
    local ax, ay, bx, by = (x1 - x0) / 1000, (y1 - y0) / 1000, (x2 - x0) / 1000, (y2 - y0) / 1000
    local det = ax * by - bx * ay
    if det == 0 then return end
    b = { x0, y0, ax, ay, bx, by, det }
    basis[cont] = b
    return b
end

local function Yards(cont, u, v)
    local b = Basis(cont)
    if not b then return end
    local du, dv = u - b[1], v - b[2]
    return (du * b[6] - b[5] * dv) / b[7], (b[3] * dv - du * b[4]) / b[7]
end

---------------------------------------------------------------------------
-- Les endroits d'une quête
---------------------------------------------------------------------------
local spotsOf = {}              -- questID -> { kind, poi, list = { { u, v, cont, x, y, ref, name, inside, point } } }

local function Add(list, u, v, ref, inside, name)
    local cont = ContAt(u, v)
    if not cont then return end
    local x, y = Yards(cont, u, v)
    if not x then return end
    list[#list + 1] = { u = u, v = v, cont = cont, x = x, y = y, ref = ref, inside = inside, name = name }
end

local function AddRef(list, ref)
    for _, p in ipairs(Db.Places(ref)) do Add(list, p[1], p[2], ref, p.inside) end
end

-- Qui la reprend : la base, sinon le PNJ appris à un rendu d'avant
local function TurnIn(questID, list)
    local q = Db.Quest(questID)
    for _, ref in ipairs(q and q.ends or NONE) do AddRef(list, ref) end
    if #list > 0 then return end
    local e = ns.db and ns.db.learnedQuests and ns.db.learnedQuests[questID]
    for ref, s in pairs(e and e.ends or NONE) do
        local u, v = s.map and K.ToWorld(s.map, s.x / 100, s.y / 100)
        if u then Add(list, u, v, ref, nil, s.name) end
    end
end

-- Ses objectifs pas finis
local function Goals(questID, list)
    for _, o in ipairs(Log.Goals(questID)) do
        if not o.finished then
            if o.refs then
                for _, ref in ipairs(o.refs) do AddRef(list, ref) end
            elseif o.item then
                for i, src in ipairs(Db.Sources(o.item)) do
                    if i > MAX_SOURCES then break end
                    AddRef(list, src[1])
                end
            elseif o.explore then
                for _, p in ipairs(Db.Explore(questID)) do Add(list, p[1], p[2]) end
            end
        end
    end
end

-- Le point que le jeu donne à la quête
local function Poi(questID, list)
    local TQ = ns.TravelQuests
    if not (TQ and TQ.Point) then return end
    local ok, point = pcall(TQ.Point, questID)
    if not (ok and point) then return end
    local u, v = Pl().UV(point)
    if not u then return end
    list[#list + 1] = { u = u, v = v, cont = point.cont, x = point.x, y = point.y, point = point }
end

local function Spots(questID)
    local s = spotsOf[questID]
    if s then return s end
    s = { list = {} }
    local q = Log.Quests()[questID]
    if q and q.complete then
        s.kind = "turnin"
        TurnIn(questID, s.list)
    else
        s.kind = "goal"
        Goals(questID, s.list)
    end
    if #s.list == 0 then
        s.poi = true
        Poi(questID, s.list)
    end
    spotsOf[questID] = s
    return s
end

---------------------------------------------------------------------------
-- Le plus proche
---------------------------------------------------------------------------
-- here : où est le joueur (Pl.PlayerPoint), donné pour ne le lire qu'une
-- fois quand on regarde toutes les quêtes ; nil dans une instance
function Where.Of(questID, here)
    if not questID then return end
    local s = Spots(questID)
    if #s.list == 0 then return end
    if here == nil and Pl() then here = Pl().PlayerPoint() end
    local best, bestD
    if here then
        for _, p in ipairs(s.list) do
            if p.cont == here.cont then
                local d = (p.x - here.x) ^ 2 + (p.y - here.y) ^ 2
                if not bestD or d < bestD then best, bestD = p, d end
            end
        end
    end
    local far = best == nil
    best = best or s.list[1]
    return {
        u = best.u, v = best.v, cont = best.cont,
        dist = bestD and math.sqrt(bestD) or nil, far = far,
        kind = s.poi and "poi" or s.kind,
        name = best.name or (best.ref and Db.Name(best.ref)) or nil,
        inside = best.inside, spot = best,
    }
end

-- Le nom de la zone où est ce point (gardé avec le point)
function Where.Zone(w)
    local spot = w and w.spot
    if not spot then return end
    if spot.zone == nil then
        spot.zone = false
        local mapID = K.ZoneAt(spot.u, spot.v)
        if mapID and C_Map and C_Map.GetMapInfo then
            local ok, info = pcall(C_Map.GetMapInfo, mapID)
            if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then spot.zone = info.name end
        end
    end
    return spot.zone or nil
end

-- Le point du monde du plus proche, pour un itinéraire : il porte la quête
-- (Travel/Guide.lua le nomme par son titre, et reconnaît la quête du trajet)
function Where.Point(questID)
    local w = Where.Of(questID)
    if not w then return end
    local point = w.spot.point or Pl().PointAtUV(w.u, w.v)
    if not point then return end
    local goal = {}
    for k, v in pairs(point) do goal[k] = v end
    local q = Log.Quests()[questID]
    goal.questID = questID
    goal.title = (q and q.title) or Db.Title(questID)
    goal.name = nil
    return goal
end

function Where.Routed(questID)
    local T = ns.Travel
    local goal = T and T.Goal()
    return goal ~= nil and goal.questID == questID
end

function Where.Route(questID)
    local T = ns.Travel
    if not (T and ns.db and ns.db.options.travel) then return end
    if Where.Routed(questID) then
        T.Cancel(true)
        return
    end
    local point = Where.Point(questID)
    if not point then
        -- (rien de connu : le jeu dit pourquoi, Travel/Guide.lua)
        T.AtQuest(questID)
        return
    end
    T.Go(point)
end

function Where.Enqueue(questID)
    local T = ns.Travel
    if not (T and ns.db and ns.db.options.travel) then return end
    local point = Where.Point(questID)
    if not point then
        ns.Print(L.TRAVEL_NO_QUEST:format(Db.Title(questID)))
        return
    end
    T.Enqueue(point)
end

-- (le journal changé, une quête apprise : les endroits relus à la demande)
ns.On("QUESTS_CHANGED", function() wipe(spotsOf) end)
ns.On("QUESTS_LEARNED", function() wipe(spotsOf) end)
