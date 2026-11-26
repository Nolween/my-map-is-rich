-- Le calcul d'un itinéraire : le trajet le plus rapide d'un point à un
-- autre, en marchant, en vol (les vols appris), en bateau, en zeppelin, par
-- le portail de Darnassus, le tram des profondeurs et les téléportations de
-- classe.
--   Planner.Find(from, to, opts)  from, to : { cont, x, y } (yards du monde)
--                                 -> { legs = { étape, ... }, secs } ou nil
--   Planner.Best(from, to, opts)  le même, avec les règles qui demandent un
--                                 second calcul (téléportations, indice d'un vol)
--   Une étape : { kind = "walk" | "flight" | "boat" | "zeppelin" | "portal" | "tram" | "teleport", from, to
--   (un bateau : transit, sa ligne ; timed, son horaire est appris ; wait, l'attente au quai)
--   (des nœuds : { cont, x, y, name }), secs, paths (les sauts d'un vol),
--   route (le nom d'une ligne de bateau), points (le tracé d'une marche :
--   { {x, y}, ... }) }
-- La marche peut suivre les routes du jeu (Travel/Roads.lua) et va en ligne
-- droite, avec un détour, entre une route et un point qui n'est pas dessus.
-- Le style de marche (Pl.Style, Travel/Nav.lua : Nav.STYLES) dit combien un
-- yard de route compte, à côté d'un yard de ligne droite (WALK_DETOUR).
-- Elle ne relie que deux points d'un même continent.
-- Dijkstra sur le temps, sur les nœuds du réseau (Travel/Graph.lua), le
-- départ, l'arrivée et les carrefours des routes.
--
-- Les positions : celle du joueur (sa carte et sa place dessus), celle du
-- curseur sur la carte, et le passage d'un point du monde à une
-- carte du jeu (pour le waypoint).
local _, root = ...
local ns = root.Plus
local G = ns.TravelGraph

local Pl = {}
ns.TravelPlanner = Pl

local DETOUR = 1.3           -- la marche réelle par rapport à la ligne droite (le temps annoncé)
local WALK_DETOUR = 1.25     -- ... et ce qu'elle compte pour choisir le chemin (comme Polestar)
local RUN = 7                -- yd/s à pied
local SPEEDS = { walk = RUN, slow = RUN * 1.6, fast = RUN * 2 }
Pl.GHOST_SPEED = RUN * 1.25  -- yd/s : un fantôme court plus vite, sans monture

---------------------------------------------------------------------------
-- Les positions
---------------------------------------------------------------------------
-- (une valeur secrète du jeu ne sert à rien : nil)
local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Un point d'une carte du jeu dans le monde : { cont, x, y, map, mx, my }
function Pl.WorldOf(mapID, mx, my)
    if not (mapID and mx and my and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(mx, my))
    if not ok or not pos then return end
    cont = Plain(cont)
    local okXY, x, y = pcall(pos.GetXY, pos)
    if not okXY then return end
    x, y = Plain(x), Plain(y)
    if type(cont) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return end
    return { cont = cont, x = x, y = y, map = mapID, mx = mx, my = my }
end

-- Où est le joueur (nil : dans une instance, ou le jeu ne le dit pas)
function Pl.PlayerPoint()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    mapID = ok and Plain(mapID) or nil
    if not mapID then return end
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not okP or not pos then return end
    local okXY, x, y = pcall(pos.GetXY, pos)
    if not okXY then return end
    x, y = Plain(x), Plain(y)
    if not (x and y) or (x == 0 and y == 0) then return end
    return Pl.WorldOf(mapID, x, y)
end

-- La carte (zone ou ville) sous un point du monde (u, v)
local function MapAt(u, v)
    local K = ns.Map.Coords
    local chain = K.ChainAt(u, v)
    local mapID = chain[#chain]
    if not mapID or mapID == K.World() then return end
    local mx, my = K.FromWorld(mapID, u, v)
    if not mx then return end
    return mapID, mx, my
end

-- Le point du monde sous le curseur (u, v), et les unités du
-- monde par pixel (pour comparer des distances à l'écran)
function Pl.CursorUV()
    local u, v, pu, pv = ns.Map.Cursor.World()
    if not u then return end
    return u, v, pu, pv
end

-- Le point sous le curseur, sur la carte ; et Pl.CursorUV()
function Pl.CursorPoint()
    local u, v, pu, pv = Pl.CursorUV()
    if not u then return end
    local mapID, mx, my = MapAt(u, v)
    if not mapID then return nil, u, v, pu, pv end
    local point = Pl.WorldOf(mapID, mx, my)
    if point then point.u, point.v = u, v end
    return point, u, v, pu, pv
end

-- Le point du monde (yards) d'un point de la carte d'OpenMap (u, v) : un
-- lieu du navigateur, un résultat de recherche
function Pl.PointAtUV(u, v)
    local mapID, mx, my = MapAt(u, v)
    if not mapID then return end
    local point = Pl.WorldOf(mapID, mx, my)
    if point then point.u, point.v = u, v end
    return point
end

-- Un point du monde (yards) sur la carte (u, v)
function Pl.UV(point)
    if point.u and point.v then return point.u, point.v end
    local u, v = ns.Map.Coords.FromYards(point.cont, point.x, point.y)
    if u then
        point.u, point.v = u, v
        return u, v
    end
end

-- Un point du monde sur une carte du jeu : mapID, x, y (pour le waypoint)
function Pl.MapPoint(point)
    if point.map and point.mx then return point.map, point.mx, point.my end
    local u, v = Pl.UV(point)
    if not u then return end
    local mapID, mx, my = MapAt(u, v)
    if mapID then point.map, point.mx, point.my = mapID, mx, my end
    return mapID, mx, my
end

-- Le nom de la zone où est un point (le nom que le jeu lui donne)
function Pl.ZoneName(point)
    local mapID = Pl.MapPoint(point)
    if not (mapID and C_Map and C_Map.GetMapInfo) then return end
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    return ok and type(info) == "table" and info.name or nil
end

---------------------------------------------------------------------------
-- La vitesse de marche (yd/s) : le réglage, sinon d'après le niveau (une
-- monture supposée dès qu'on peut l'avoir), ou la vitesse du moment si elle
-- est plus grande (déjà en monture, en forme de voyage...)
---------------------------------------------------------------------------
-- La vitesse de course du moment (yd/s), même à l'arrêt : à pied, en
-- monture, en forme de voyage, en fantôme... ; nil si le jeu ne la dit pas
function Pl.LiveSpeed()
    if not GetUnitSpeed then return end
    local ok, _, run = pcall(GetUnitSpeed, "player")
    run = ok and Plain(run) or nil
    if type(run) ~= "number" or run <= 0 then return end
    return run
end

-- Le réglage suit-il la vitesse du moment ? (« auto » ; sinon le joueur a
-- choisi sa vitesse)
function Pl.AutoSpeed()
    local mode = ns.db and ns.db.options.travelSpeed or "auto"
    return not SPEEDS[mode]
end

function Pl.Speed()
    local mode = ns.db and ns.db.options.travelSpeed or "auto"
    if SPEEDS[mode] then return SPEEDS[mode] end
    local level = UnitLevel and UnitLevel("player") or 1
    local guess = SPEEDS.walk
    if level >= 60 then guess = SPEEDS.fast
    elseif level >= 40 then guess = SPEEDS.slow end
    local live = Pl.LiveSpeed()
    if live and live > guess then return live end
    return guess
end

---------------------------------------------------------------------------
-- Le style de marche (réglage « Chemin à pied », travelPath) : fastest (le
-- plus rapide), balanced (équilibré, le défaut), roads (les routes) ; leurs
-- prix sont dans Travel/Nav.lua (Nav.STYLES). name : un style demandé (celui
-- d'un itinéraire, de l'aperçu) ; sinon celui du réglage. Le temps annoncé
-- reste le temps réel.
---------------------------------------------------------------------------
function Pl.Style(name)
    local Nav = ns.TravelNav
    local styles = Nav and Nav.STYLES or {}
    if name and styles[name] then return name end
    local mode = ns.db and ns.db.options.travelPath
    if styles[mode] then return mode end
    return "balanced"
end

---------------------------------------------------------------------------
-- Les téléportations de classe (Data/Teleports.lua : celles du mage vers les
-- capitales, avec une rune de téléportation ; Reflet-de-Lune du druide) : un
-- sort que tu connais, qui ne pose pas dans la zone où tu es. Son temps : ce
-- qu'il reste de sa recharge, puis l'incantation. Les règles de Polestar :
-- pour choisir le chemin, il compte TELEPORT_MARGIN de plus (l'écran de
-- chargement, une incantation coupée), et il n'est gardé que s'il fait gagner
-- TELEPORT_SHARE du trajet sans lui (Pl.Best).
---------------------------------------------------------------------------
local TELEPORT_MARGIN = 60   -- s
local TELEPORT_SHARE = 0.2

function Pl.SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)
        if ok and type(Plain(name)) == "string" then return name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, id)
        if ok and type(Plain(name)) == "string" then return name end
    end
end

local function Knows(id)
    for _, name in ipairs({ "IsPlayerSpell", "IsSpellKnown" }) do
        local fn = _G[name]
        if fn then
            local ok, known = pcall(fn, id)
            if ok and Plain(known) then return true end
        end
    end
    return false
end

local function Carries(item)
    local count = C_Item and C_Item.GetItemCount or _G.GetItemCount
    if not count then return false end
    local ok, n = pcall(count, item)
    n = ok and Plain(n) or nil
    return type(n) == "number" and n > 0
end

-- Ce qu'il reste de la recharge d'un sort (s ; celle de toutes les actions ne compte pas)
local function SpellWait(id)
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, id)
        if ok and type(info) == "table" then start, duration = Plain(info.startTime), Plain(info.duration) end
    elseif GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, id)
        if ok then start, duration = Plain(s), Plain(d) end
    end
    if type(start) ~= "number" or type(duration) ~= "number" or start <= 0 or duration <= 1.5 then return 0 end
    return math.max(0, start + duration - GetTime())
end

-- Les téléportations possibles depuis `from` : { { spell, name, cont, x, y, zone, secs }, ... }
function Pl.Teleports(from)
    local list = {}
    local Nav = ns.TravelNav
    local zoneAt = Nav and Nav.ZoneAt
    local here = zoneAt and zoneAt(from.cont, from.x, from.y)
    for _, t in ipairs(type(ns.TeleportData) == "table" and ns.TeleportData or {}) do
        if Knows(t.spell) and (not t.reagent or Carries(t.reagent)) then
            local zone = zoneAt and zoneAt(t.cont, t.x, t.y)
            -- (jamais une qui pose là où tu es déjà)
            if not (t.cont == from.cont and zone and zone == here) then
                list[#list + 1] = { spell = t.spell, name = Pl.SpellName(t.spell) or ("#" .. t.spell), cont = t.cont,
                    x = t.x, y = t.y, zone = zone, secs = SpellWait(t.spell) + (t.cast or 10) }
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Le calcul
---------------------------------------------------------------------------
-- La marche suit les routes (Travel/Roads.lua) : chaque point clé (départ,
-- arrivée, maître de vol, quai) rejoint ses routes les plus proches par un
-- « accès » (le point de la route le plus proche, sur chacun des tronçons
-- voisins), on suit les tronçons de carrefour en carrefour, et on en sort
-- par l'accès d'un autre point clé. La ligne droite reste possible entre
-- deux points clés, mais un yard hors route compte selon le réglage (le
-- temps annoncé, lui, reste le temps réel).
-- (sans la grille de marche pour préciser ensuite le chemin, une longue
-- ligne droite traverse montagnes et forêts : au-delà de OFFROAD_NEAR,
-- chaque yard hors route compte au moins OFFROAD_BLIND)
local OFFROAD_NEAR = 300     -- yd
local OFFROAD_BLIND = 1.5    -- au-delà, sans la grille de marche
local ACCESS_K = 4           -- les routes voisines d'un point clé
local ACCESS_NEAR = 600      -- yd : les routes cherchées autour d'un point clé
local ACCESS_FAR = 2000      -- yd : ... ou la plus proche, si aucune n'est si près
local ROAD_ID = 100000       -- un nœud de route : continent * ROAD_ID + numéro
local ZONE_STEP = 50         -- yd : une ligne droite compte les zones trop hautes et le terrain ennemi par
                             -- morceaux de cette longueur (un petit camp ne passe pas entre deux)

local Heap = G.Heap          -- (un tas binaire : Travel/Graph.lua)

-- opts : { walkOnly (la marche seule, sans vols ni bateaux), blind (pas de
-- grille de marche pour préciser le chemin ensuite), speed (yd/s : la vitesse
-- de marche, celle d'un fantôme par exemple), style (le style de marche,
-- Pl.Style), noTeleport (sans téléportation), assumeKnown (comme si tous les
-- vols étaient appris), exclude (des clés d'arêtes à ne pas prendre), only
-- (les seules clés permises, la marche toujours) } ; rien : un itinéraire
-- complet, au style du réglage. Chaque étape (hors marche) dit ses arêtes :
-- leg.keys.
function Pl.Find(from, to, opts)
    opts = opts or {}
    local g = opts.walkOnly and { nodes = {}, edges = {}, known = 0 } or G.Build(opts.assumeKnown)
    local nodes, edges = g.nodes, g.edges
    local exclude, only = opts.exclude, opts.only
    local function Allowed(key)
        if exclude and exclude[key] then return false end
        return not only or only[key] == true
    end
    -- (le départ et l'arrivée sont les points donnés, qui gardent leur carte
    -- et leur place sur la carte)
    from.id, from.kind = "start", "start"
    to.id, to.kind = "goal", "goal"
    nodes.start, nodes.goal = from, to
    -- (les téléportations : leur point d'arrivée, où l'on va depuis le départ)
    local teleports = {}
    if not (opts.walkOnly or opts.noTeleport) then
        for _, t in ipairs(Pl.Teleports(from)) do
            local key = "teleport:" .. t.spell
            if Allowed(key) then
                local id = "t" .. t.spell
                nodes[id] = { id = id, kind = "teleport", cont = t.cont, x = t.x, y = t.y, map = t.zone, name = t.name,
                    spell = t.spell }
                teleports[#teleports + 1] = { to = id, secs = t.secs, kind = "teleport", spell = t.spell, key = key }
            end
        end
    end
    local speed = opts.speed or Pl.Speed()
    local Roads = ns.TravelRoads
    local Nav = ns.TravelNav
    local style = Pl.Style(opts.style)
    local roadMult = Nav and Nav.STYLES[style] and Nav.STYLES[style].mult[1] or 0.8
    local useRoads = Roads and true or false
    -- (le coût d'une marche hors route de d yards, pour choisir le chemin)
    local nets, access, accessOf, onEdge = {}, nil, nil, nil
    local blind = opts.blind
        or not (ns.db and ns.db.options.travelTerrain ~= false and Nav and Nav.Available() and Nav.Has(from.cont))
    local far = blind and math.max(WALK_DETOUR, OFFROAD_BLIND) or WALK_DETOUR
    local function Offroad(d)
        if d <= OFFROAD_NEAR then return d * WALK_DETOUR end
        return OFFROAD_NEAR * WALK_DETOUR + (d - OFFROAD_NEAR) * far
    end
    -- (les zones trop hautes pour toi, comme la grille : Travel/Nav.lua ; celle
    -- du départ et celle de l'arrivée ne comptent pas)
    local level = UnitLevel and Plain(UnitLevel("player"))
    local zoneAt, zoneFactor = Nav and Nav.ZoneAt, Nav and Nav.ZoneFactor
    local zones = type(level) == "number" and zoneAt and zoneFactor and true or false
    local exempt = {}
    if zones then
        local a, b = zoneAt(from.cont, from.x, from.y), zoneAt(to.cont, to.x, to.y)
        if a then exempt[a] = true end
        if b then exempt[b] = true end
    end
    -- (gardés par carré de ZONE_STEP yards : une ligne de plus repasse souvent par les mêmes)
    local zoneMemo = {}
    local function ZoneAt(cont, x, y, onRoad)
        local key = ((cont * 8192 + math.floor(x / ZONE_STEP) + 4096) * 8192 + math.floor(y / ZONE_STEP) + 4096) * 2
            + (onRoad and 1 or 0)
        local f = zoneMemo[key]
        if f then return f end
        local zone = zoneAt(cont, x, y)
        f = (zone and not exempt[zone]) and zoneFactor(zone, level, onRoad) or 1
        zoneMemo[key] = f
        return f
    end
    -- (le terrain de l'autre faction, comme la grille : Travel/Nav.lua, Nav.Hostile ; par continent, celui
    -- du départ ou de l'arrivée ne comptant pas)
    local hostileOf, nowhere = {}, { x = 1e9, y = 1e9 }
    local function Hostile(cont)
        local h = hostileOf[cont]
        if h == nil then
            local raw = Nav and Nav.Hostile and Nav.Hostile(cont, from.cont == cont and from or nowhere,
                to.cont == cont and to or nowhere)
            h = false
            if raw then
                -- (gardé par carré de 10 yards)
                local memo = {}
                h = function(x, y)
                    local key = (math.floor(x / 10) + 65536) * 131072 + math.floor(y / 10) + 65536
                    local f = memo[key]
                    if not f then
                        f = raw(x, y)
                        memo[key] = f
                    end
                    return f
                end
            end
            hostileOf[cont] = h
        end
        return h or nil
    end
    -- (une ligne droite : la moyenne des zones sur ses morceaux de ZONE_STEP yards, fois le terrain
    -- ennemi le plus fort qu'elle croise)
    local function LineZone(cont, ax, ay, bx, by, d)
        local hostile = Hostile(cont)
        if not (zones or hostile) then return 1 end
        local n = math.max(1, math.ceil(d / ZONE_STEP))
        local sum, worst = 0, 1
        for k = 1, n do
            local f = (k - 0.5) / n
            local x, y = ax + (bx - ax) * f, ay + (by - ay) * f
            if zones then sum = sum + ZoneAt(cont, x, y, false) end
            if hostile then worst = math.max(worst, (hostile(x, y))) end
        end
        return (zones and sum / n or 1) * worst
    end
    -- (un tronçon de route : de même le long de son tracé, gardé)
    local roadZone = {}
    local function RoadZone(cont, e)
        local hostile = Hostile(cont)
        if not (zones or hostile) then return 1 end
        local k = cont * ROAD_ID + e
        local f = roadZone[k]
        if not f then
            local net = nets[cont]
            local px, py = net.PX[e], net.PY[e]
            local sum, n, worst = 0, 0, 1
            for j = 1, #px do
                local x0, y0 = px[j], py[j]
                local x1, y1 = px[j + 1] or x0, py[j + 1] or y0
                local steps = math.max(1, math.ceil(math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) / ZONE_STEP))
                for q = 0, (j < #px) and steps - 1 or 0 do
                    local x, y = x0 + (x1 - x0) * q / steps, y0 + (y1 - y0) * q / steps
                    if zones then sum, n = sum + ZoneAt(cont, x, y, true), n + 1 end
                    if hostile then worst = math.max(worst, (hostile(x, y))) end
                end
            end
            f = (zones and sum / math.max(1, n) or 1) * worst
            roadZone[k] = f
        end
        return f
    end

    -- (les accès aux routes de chaque point clé)
    access, accessOf, onEdge = {}, {}, {}
    if useRoads then
        for id, n in pairs(nodes) do
            local net = nets[n.cont]
            if net == nil then
                net = Roads.Get(n.cont) or false
                nets[n.cont] = net
                onEdge[n.cont] = {}
            end
            if net then
                local list = Roads.Access(net, n.x, n.y, ACCESS_K, ACCESS_NEAR)
                if #list == 0 then list = Roads.Access(net, n.x, n.y, 1, ACCESS_FAR) end
                for i, a in ipairs(list) do
                    local aid = id .. "#" .. i
                    a.key, a.cont = id, n.cont
                    access[aid] = a
                    accessOf[id] = accessOf[id] or {}
                    table.insert(accessOf[id], aid)
                    local here = onEdge[n.cont]
                    here[a.edge] = here[a.edge] or {}
                    table.insert(here[a.edge], aid)
                end
            end
        end
    end

    -- (dist : le coût pour choisir le chemin ; when : le temps réel depuis le
    -- départ, pour l'horaire d'un bateau au quai où l'on arrive)
    local dist, when, prev, via, done = { start = 0 }, { start = 0 }, {}, {}, {}
    local heap = Heap()
    heap.Push(0, "start")
    local best, bd

    local function Relax(id, cost, edge)
        if done[id] then return end
        local nd = bd + cost
        if not dist[id] or nd < dist[id] then
            dist[id], prev[id], via[id] = nd, best, edge
            when[id] = (when[best] or 0) + (edge.secs or 0)
            heap.Push(nd, id)
        end
    end
    -- (un bateau, un zeppelin : l'attente selon son horaire appris, ou l'attente
    -- moyenne de sa ligne, Travel/Transit.lua ; sans ligne connue, celle du réseau)
    local Transit = ns.Transit
    local function Ship(e)
        if not (Transit and (e.kind == "boat" or e.kind == "zeppelin")) then return e end
        local secs, wait, rid, timed = Transit.Leg(nodes[best], nodes[e.to], when[best] or 0)
        if not secs then return e end
        return { to = e.to, secs = secs, kind = e.kind, route = e.route, key = e.key, transit = rid, timed = timed, wait = wait }
    end

    -- Une marche : son coût (la préférence, les zones trop hautes) et son temps réel
    local function Line(id, cont, ax, ay, bx, by)
        local dx, dy = bx - ax, by - ay
        local d = math.sqrt(dx * dx + dy * dy)
        Relax(id, Offroad(d) * LineZone(cont, ax, ay, bx, by, d) / speed,
            { kind = "walk", secs = d * DETOUR / speed, line = { ax, ay, bx, by } })
    end
    local function Road(id, cont, e, p0, p1)
        local d = math.abs(p1 - p0)
        Relax(id, d * roadMult * RoadZone(cont, e) / speed, { kind = "walk", secs = d / speed, road = { cont, e, p0, p1 } })
    end
    -- (depuis la position `pos` du tronçon e : ses deux bouts et les accès posés dessus)
    local function AlongEdge(cont, e, pos, except)
        local net = nets[cont]
        local base = cont * ROAD_ID
        Road(base + net.EA[e], cont, e, pos, 0)
        Road(base + net.EB[e], cont, e, pos, net.EL[e])
        for _, aid in ipairs(onEdge[cont][e] or {}) do
            if aid ~= except then Road(aid, cont, e, pos, access[aid].pos) end
        end
    end

    while true do
        bd, best = heap.Pop()
        if not best then return nil, g end
        if not done[best] then
            done[best] = true
            if best == "goal" then break end
            local key, acc = nodes[best], access[best]
            if key then
                -- (depuis le départ : les téléportations, leur marge en plus)
                if best == "start" then
                    for _, t in ipairs(teleports) do Relax(t.to, t.secs + TELEPORT_MARGIN, t) end
                end
                -- (les vols, les bateaux, les zeppelins ; un vol qui en suit un
                -- autre continue le même voyage : pas de nouveau décollage)
                for _, e in ipairs(edges[best] or {}) do
                    if Allowed(e.key) then
                        e = Ship(e)
                        local cost = e.secs
                        if e.kind == "flight" and not (via[best] and via[best].kind == "flight") then cost = cost + G.TAKEOFF end
                        Relax(e.to, cost, e)
                    end
                end
                -- (en ligne droite vers les autres points clés du continent)
                for id, n in pairs(nodes) do
                    if id ~= best and id ~= "start" and n.cont == key.cont then
                        Line(id, key.cont, key.x, key.y, n.x, n.y)
                    end
                end
                -- (jusqu'aux routes voisines)
                for _, aid in ipairs(accessOf[best] or {}) do
                    local a = access[aid]
                    Line(aid, key.cont, key.x, key.y, a.x, a.y)
                end
            elseif acc then
                -- (quitter la route vers son point clé, ou la suivre)
                local k = nodes[acc.key]
                Line(acc.key, acc.cont, acc.x, acc.y, k.x, k.y)
                AlongEdge(acc.cont, acc.edge, acc.pos, best)
            else
                -- (un carrefour : ses tronçons)
                local cont = math.floor(best / ROAD_ID)
                local i = best % ROAD_ID
                local net = nets[cont]
                for _, e in ipairs(net.around[i]) do
                    local a, b = net.EA[e], net.EB[e]
                    if a ~= b then
                        AlongEdge(cont, e, a == i and 0 or net.EL[e], nil)
                    end
                end
            end
        end
    end

    -- (les arêtes, de la fin au départ, remises dans l'ordre)
    local chain = {}
    local id = "goal"
    while id ~= "start" do
        table.insert(chain, 1, { from = prev[id], to = id, edge = via[id] })
        id = prev[id]
    end
    -- (les étapes : les marches qui se suivent n'en font qu'une, avec tout
    -- leur tracé ; les sauts d'un même vol aussi)
    local legs, total = {}, 0
    local function Add(points, list)
        for i, p in ipairs(list) do
            local last = points[#points]
            if not (i == 1 and last and math.abs(last.x - p.x) < 0.5 and math.abs(last.y - p.y) < 0.5) then
                points[#points + 1] = p
            end
        end
    end
    for _, link in ipairs(chain) do
        local e = link.edge
        local last = legs[#legs]
        if e.kind == "walk" then
            if not (last and last.kind == "walk") then
                last = { kind = "walk", from = nodes[link.from], secs = 0, points = {} }
                legs[#legs + 1] = last
            end
            last.secs = last.secs + e.secs
            if e.line then
                local l = e.line
                Add(last.points, { { x = l[1], y = l[2] }, { x = l[3], y = l[4] } })
            else
                local r = e.road
                Add(last.points, Roads.Slice(nets[r[1]], r[2], r[3], r[4]))
            end
            -- (une marche finit toujours à un point clé : celui-ci, s'il est le dernier)
            if nodes[link.to] then last.to = nodes[link.to] end
        elseif e.kind == "flight" and last and last.kind == "flight" then
            last.to = nodes[link.to]
            last.secs = last.secs + e.secs
            last.paths[#last.paths + 1] = e.path
            last.measured = last.measured and e.measured
            last.keys[#last.keys + 1] = e.key
        else
            local leg = { kind = e.kind, from = nodes[link.from], to = nodes[link.to], secs = e.secs, route = e.route,
                spell = e.spell, keys = { e.key }, transit = e.transit, timed = e.timed, wait = e.wait }
            if e.kind == "flight" then
                leg.paths, leg.measured = { e.path }, e.measured
            end
            legs[#legs + 1] = leg
        end
    end
    for _, leg in ipairs(legs) do total = total + leg.secs end
    return { legs = legs, secs = total, speed = speed, known = g.known, roads = useRoads, style = style }, g
end

---------------------------------------------------------------------------
-- Le meilleur itinéraire, avec les règles de Polestar qui demandent un
-- second calcul :
--   - une téléportation n'est gardée que si elle fait gagner TELEPORT_SHARE
--     du trajet sans elle ;
--   - « Plus rapide si tu avais le vol de… » : un trajet sans vol de plus de
--     HINT_WALK, refait comme si tous les vols de ta faction étaient appris ;
--     s'il atterrit chez un maître de vol que tu n'as pas et gagne plus de
--     HINT_GAIN, plan.hint = { name (ce maître de vol), saves (s) }.
-- opts comme Pl.Find, et hint = false : sans chercher l'indice.
---------------------------------------------------------------------------
local HINT_WALK, HINT_GAIN = 120, 30   -- s

local function With(opts, key, value)
    local copy = {}
    for k, v in pairs(opts or {}) do copy[k] = v end
    copy[key] = value
    return copy
end

local function Uses(plan, kind)
    for _, leg in ipairs(plan.legs) do
        if leg.kind == kind then return true end
    end
    return false
end

-- (le premier saut d'un plan qui atterrit chez un maître de vol pas appris : son nom)
local function MissingFlight(plan, g)
    for _, leg in ipairs(plan.legs) do
        for _, path in ipairs(leg.kind == "flight" and leg.paths or {}) do
            local n = g and g.nodes["f" .. tostring(path[2])]
            if n and n.known == false then return n.name end
        end
    end
end

function Pl.Best(from, to, opts)
    opts = opts or {}
    local plan, g = Pl.Find(from, to, opts)
    if not plan then return plan, g end
    if not opts.walkOnly and Uses(plan, "teleport") then
        local without, g2 = Pl.Find(from, to, With(opts, "noTeleport", true))
        if without and without.secs - plan.secs < TELEPORT_SHARE * without.secs then plan, g = without, g2 end
    end
    if not opts.walkOnly and opts.hint ~= false and not Uses(plan, "flight") and plan.secs > HINT_WALK then
        local alt, ag = Pl.Find(from, to, With(opts, "assumeKnown", true))
        local name = alt and MissingFlight(alt, ag)
        if name and alt.secs < plan.secs - HINT_GAIN then plan.hint = { name = name, saves = plan.secs - alt.secs } end
    end
    return plan, g
end

-- La marche seule d'un point à un autre, au style donné (nil : le réglage),
-- sans la grille (une longue ligne droite y compte au moins OFFROAD_BLIND) :
-- le secours d'une marche que la grille n'a pas pu préciser. Rend son étape
-- de marche, ou nil.
function Pl.WalkEstimate(from, to, style)
    local plan = Pl.Find({ cont = from.cont, x = from.x, y = from.y }, { cont = to.cont, x = to.x, y = to.y },
        { walkOnly = true, blind = true, style = style })
    local leg = plan and plan.legs[1]
    if leg and leg.kind == "walk" and #plan.legs == 1 then return leg end
end
