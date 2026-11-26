-- Le réseau des trajets, construit à chaque calcul (une centaine de nœuds :
-- c'est instantané, et ce qu'on sait des vols reste à jour) d'après les
-- données d'OpenMap, sans rien y écrire :
--   OpenMap.MapFlights : les maîtres de vol et les vols entre eux (leur
--     tracé, leur longueur), mod.db.flightTimes (les temps mesurés sur tes
--     vols), mod.char.flightsKnown (les vols appris, par nom)
--   OpenMap.MapPlaces.transports : les quais des bateaux et des zeppelins
--   ns.Passages (Data/Passages.lua) : le portail de Darnassus, le tram des
--     profondeurs
-- Les positions sont en yards du monde, par continent (0 les Royaumes de
-- l'Est, 1 Kalimdor), comme C_Map.GetWorldPosFromMapPos les donne.
-- Les dirigeables de Zephras (continent 2991) ne sont pas sur la carte
-- assemblée : laissés de côté.
local _, root = ...
local ns = root.Plus

local G = {}
ns.TravelGraph = G

local FLY_SPEED = 30         -- yd/s en vol (l'estimation d'OpenMap, Flights.lua)
local HOP = 2                -- s de plus par saut d'un vol estimé (comme Polestar)
local TAKEOFF = 4            -- s : parler au maître de vol et décoller ; compté pour choisir le
                             -- chemin (un vol de plus doit valoir le détour), pas dans le temps annoncé
local SHIP_SPEED = 20        -- yd/s en bateau ou en zeppelin (environ)
local SEA_CROSSING = 180     -- s : une traversée d'un continent à l'autre
local SHIP_WAIT = 120        -- s : l'attente moyenne au quai
local DOCK_MERGE = 40        -- yd : deux quais si proches n'en font qu'un

G.FLY_SPEED, G.TAKEOFF = FLY_SPEED, TAKEOFF

-- Ports gobelins : les deux factions (comme Routes.lua d'OpenMap)
local NEUTRAL = { ["Booty Bay - Ratchet"] = true, ["Steamwheedle Port - Powderfuse Port"] = true }
local KINDS = { boat = true, zeppelin = true }
local CONTINENTS = { [0] = true, [1] = true }

local function Data()
    local F, P = ns.Map.Data.Flights(), ns.Map.Data.Places()
    if type(F) ~= "table" or type(F.nodes) ~= "table" or type(F.paths) ~= "table" then F = nil end
    if type(P) ~= "table" or type(P.transports) ~= "table" then P = nil end
    return F, P
end

local function FactionBit()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if faction == "Horde" then return 2, "Horde" end
    return 1, "Alliance"
end

-- Un maître de vol de ta faction (et ceux d'une classe pour elle seule),
-- comme Usable() dans Flights.lua
local function Usable(n, factionBit)
    if type(n) ~= "table" or type(n[5]) ~= "number" or not bit or not bit.band then return false end
    if bit.band(n[5], factionBit) == 0 then return false end
    if n[6] then
        local _, class = UnitClass("player")
        return n[6] == class
    end
    return true
end

-- Ce que le jeu dit des maîtres de vol (C_TaxiMap) : leur nom dans la langue
-- du client, ceux trouvés, et combien ne le sont pas
local function GameNodes()
    local names, seen, hidden = {}, {}, 0
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return names, seen, hidden end
    local world = ns.Map.Data.World()
    local continents = world and world.continents or { 1414, 1415 }
    for _, mapID in ipairs(continents) do
        local ok, list = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
        if ok and type(list) == "table" then
            for _, info in ipairs(list) do
                if type(info) == "table" and info.nodeID then
                    if type(info.name) == "string" and info.name ~= "" then names[info.nodeID] = info.name end
                    if info.isUndiscovered == false then
                        seen[info.nodeID] = true
                    elseif info.isUndiscovered == true then
                        hidden = hidden + 1
                    end
                end
            end
        end
    end
    return names, seen, hidden
end

-- Les vols appris, comme Known() dans Flights.lua : la liste vue chez un
-- maître de vol (par personnage) ; sinon ce que le jeu dit (seulement s'il
-- distingue les vols trouvés des autres : Forever les dit tous trouvés).
-- La liste apprise est en noms du jeu (en français sur un client français),
-- alors que les données d'OpenMap restent en anglais tant que sa carte n'a
-- pas été ouverte (ReadFound les renomme) : on compare aux deux.
local function KnownSet(F)
    local known = {}
    local learned = ns.Map.Flights.Known()
    local names, seen, hidden = GameNodes()
    if type(learned) == "table" and next(learned) then
        for id, n in pairs(F.nodes) do
            if learned[n[1]] or (names[id] and learned[names[id]]) then known[id] = true end
        end
        return known
    end
    if hidden > 0 then
        for id in pairs(seen) do known[id] = true end
    end
    return known
end
G.KnownSet = function()
    local F = Data()
    return F and KnownSet(F) or {}
end

-- Le nom court d'un maître de vol : « Stormwind, Elwynn » -> « Stormwind »
-- (la virgule pleine chasse cherchée en texte simple, comme Flights.lua)
function G.Short(name)
    if type(name) ~= "string" then return "?" end
    local s = name:match("^[^,]+") or name
    local i = s:find("，", 1, true)
    return i and s:sub(1, i - 1) or s
end

local function Dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
G.Dist = Dist

-- Le temps d'un vol (un saut) : mesuré, sinon estimé d'après sa longueur
local function FlightSecs(F, path)
    local a, b = F.nodes[path[1]], F.nodes[path[2]]
    local times = ns.Map.Flights.Times()
    local t = type(times) == "table" and a and b and times[a[1] .. "|" .. b[1]]
    if type(t) == "number" and t > 0 then return t, true end
    return (path[3] or 0) / FLY_SPEED + HOP, false
end

-- Le réseau : { nodes = { id -> nœud }, edges = { id -> { arête, ... } },
-- known = nombre de vols appris }. Un nœud : { id, cont, x, y, kind
-- ("flight" | "dock" | "passage"), name, node (l'id du maître de vol), known
-- (un vol appris), layer et passage (un bout de passage : sa couche dans la
-- grille de marche, "portal" | "tram") }. Une arête : { to, secs, kind
-- ("flight" | "boat" | "zeppelin" | "portal" | "tram"), path, measured, route, key }.
-- Tous les maîtres de vol de ta faction sont des nœuds : un vol peut partir
-- d'un maître de vol pas encore appris (on y va, on lui parle, il est appris
-- et on s'envole), mais n'atterrit que chez un maître de vol appris, comme
-- dans le jeu : un saut n'arrive qu'à un nœud appris.
-- assumeKnown : comme si tous les vols de ta faction étaient appris (« plus
-- rapide si tu avais le vol de… » : Planner.lua) ; chaque nœud garde son vrai known.
function G.Build(assumeKnown)
    local F, P = Data()
    local g = { nodes = {}, edges = {}, known = 0 }
    local factionBit, faction = FactionBit()

    -- (une arête a sa clé, « genre:départ>arrivée » : un plan dit ainsi par où il
    -- passe, pour exclure une étape ou garder le même chemin, Planner.lua)
    local function AddEdge(from, edge)
        edge.key = edge.kind .. ":" .. from .. ">" .. edge.to
        g.edges[from] = g.edges[from] or {}
        local list = g.edges[from]
        list[#list + 1] = edge
    end

    -- (les passages : le portail de Darnassus, le tram des profondeurs ; un
    -- bout garde la couche de la grille de marche où il est)
    for i, p in ipairs(type(ns.Passages) == "table" and ns.Passages or {}) do
        if (not p.faction or p.faction == faction) and CONTINENTS[p.a[1]] and CONTINENTS[p.b[1]] then
            local ends = {}
            for side, e in pairs({ a = p.a, b = p.b }) do
                local n = { id = "p" .. i .. side, cont = e[1], x = e[2], y = e[3], layer = e[4], kind = "passage",
                    passage = p.kind }
                g.nodes[n.id] = n
                ends[side] = n
            end
            AddEdge(ends.a.id, { to = ends.b.id, secs = p.secs, kind = p.kind })
            AddEdge(ends.b.id, { to = ends.a.id, secs = p.secs, kind = p.kind })
        end
    end

    if F then
        local known = KnownSet(F)
        for id, n in pairs(F.nodes) do
            if Usable(n, factionBit) and CONTINENTS[n[2]] then
                g.nodes["f" .. id] = { id = "f" .. id, cont = n[2], x = n[3], y = n[4], kind = "flight",
                    name = G.Short(n[1]), node = id, known = known[id] and true or false }
                if known[id] then g.known = g.known + 1 end
            end
        end
        for _, path in ipairs(F.paths) do
            local a, b = g.nodes["f" .. tostring(path[1])], g.nodes["f" .. tostring(path[2])]
            if a and b and (b.known or assumeKnown) then
                local secs, measured = FlightSecs(F, path)
                AddEdge(a.id, { to = b.id, secs = secs, kind = "flight", path = path, measured = measured })
            end
        end
    end

    if P then
        local docks = {}
        local function Dock(cont, x, y, route)
            for _, d in ipairs(docks) do
                if d.cont == cont and math.abs(d.x - x) < DOCK_MERGE and math.abs(d.y - y) < DOCK_MERGE then return d end
            end
            local d = { id = "d" .. (#docks + 1), cont = cont, x = x, y = y, kind = "dock", route = route }
            docks[#docks + 1] = d
            g.nodes[d.id] = d
            return d
        end
        for _, t in ipairs(P.transports) do
            local kind, route = t[1], t[2]
            local side = kind == "zeppelin" and "Horde" or NEUTRAL[route] and "Neutral" or "Alliance"
            if KINDS[kind] and (side == "Neutral" or side == faction)
                and CONTINENTS[t[3]] and CONTINENTS[t[6]]
                and type(t[4]) == "number" and type(t[7]) == "number" then
                local a = Dock(t[3], t[4], t[5], route)
                local b = Dock(t[6], t[7], t[8], route)
                local ride = a.cont == b.cont and Dist(a, b) / SHIP_SPEED or SEA_CROSSING
                AddEdge(a.id, { to = b.id, secs = SHIP_WAIT + ride, kind = kind, route = route })
            end
        end
    end
    return g
end

-- Un tas binaire, le plus petit coût d'abord (Planner.lua, Nav.lua) :
-- h.Push(coût, id), h.Pop() -> coût, id (rien quand il est vide)
function G.Heap()
    local costs, ids, size = {}, {}, 0
    local h = {}
    function h.Push(cost, id)
        size = size + 1
        local i = size
        while i > 1 do
            local parent = math.floor(i / 2)
            if costs[parent] <= cost then break end
            costs[i], ids[i] = costs[parent], ids[parent]
            i = parent
        end
        costs[i], ids[i] = cost, id
    end
    function h.Pop()
        if size == 0 then return end
        local cost, id = costs[1], ids[1]
        local lastCost, lastId = costs[size], ids[size]
        costs[size], ids[size] = nil, nil
        size = size - 1
        if size > 0 then
            local i = 1
            while true do
                local child = i * 2
                if child > size then break end
                if child < size and costs[child + 1] < costs[child] then child = child + 1 end
                if costs[child] >= lastCost then break end
                costs[i], ids[i] = costs[child], ids[child]
                i = child
            end
            costs[i], ids[i] = lastCost, lastId
        end
        return cost, id
    end
    function h.Size() return size end
    return h
end
