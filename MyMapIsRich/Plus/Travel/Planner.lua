-- Le calcul d'un itinéraire : le trajet le plus rapide d'un point à un
-- autre, en marchant, en vol (les vols appris), en bateau, en zeppelin, par
-- le portail de Darnassus et le tram des profondeurs.
--   Planner.Find(from, to)  from, to : { cont, x, y } (yards du monde)
--                           -> { legs = { étape, ... }, secs } ou nil
--   Une étape : { kind = "walk" | "flight" | "boat" | "zeppelin" | "portal" | "tram", from, to
--   (des nœuds : { cont, x, y, name }), secs, paths (les sauts d'un vol),
--   route (le nom d'une ligne de bateau), points (le tracé d'une marche :
--   { {x, y}, ... }) }
-- La marche peut suivre les routes du jeu (Travel/Roads.lua) et va en ligne
-- droite, avec un détour, entre une route et un point qui n'est pas dessus.
-- Le réglage « Chemin à pied » (Pl.PathProfile) dit combien un yard hors
-- route compte : à travers champs, autant qu'un yard de route.
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

local DETOUR = 1.3           -- la marche réelle par rapport à la ligne droite
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
-- Le réglage « Chemin à pied » (travelPath) : ce que compte un yard hors
-- route pour choisir le chemin (un yard de route compte 1), et ce que coûte
-- le fait de monter sur une route (yd), pour qu'un chemin ne fasse pas un
-- crochet vers un petit bout de route. Lu aussi par la grille (Travel/Nav.lua).
-- Le temps annoncé reste le temps réel.
---------------------------------------------------------------------------
local PROFILES = {
    roads = { off = 2.0, join = 24 },    -- routes au maximum
    mixed = { off = 1.3, join = 16 },    -- routes si possible
    fields = { off = 1.0, join = 0 },    -- à travers champs : au plus court
}

function Pl.PathProfile()
    local mode = ns.db and ns.db.options.travelPath
    return PROFILES[mode] or PROFILES.mixed, PROFILES[mode] and mode or "mixed"
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

local Heap = G.Heap          -- (un tas binaire : Travel/Graph.lua)

-- opts : { walkOnly (la marche seule, sans vols ni bateaux), blind (pas de
-- grille de marche pour préciser le chemin ensuite), speed (yd/s : la vitesse
-- de marche, celle d'un fantôme par exemple) } ; rien : un itinéraire complet
function Pl.Find(from, to, opts)
    local g = opts and opts.walkOnly and { nodes = {}, edges = {}, known = 0 } or G.Build()
    local nodes, edges = g.nodes, g.edges
    -- (le départ et l'arrivée sont les points donnés, qui gardent leur carte
    -- et leur place sur la carte)
    from.id, from.kind = "start", "start"
    to.id, to.kind = "goal", "goal"
    nodes.start, nodes.goal = from, to
    local speed = opts and opts.speed or Pl.Speed()
    local Roads = ns.TravelRoads
    local profile = Pl.PathProfile()
    -- (à travers champs : les routes ne servent à rien, tout va en ligne droite)
    local useRoads = Roads and profile.off > 1
    -- (le coût d'une marche hors route de d yards, pour choisir le chemin)
    local Nav = ns.TravelNav
    local blind = opts and opts.blind
        or not (ns.db and ns.db.options.travelTerrain ~= false and Nav and Nav.Available() and Nav.Has(from.cont))
    local far = blind and math.max(profile.off, OFFROAD_BLIND) or profile.off
    local function Offroad(d)
        if not useRoads then return d * DETOUR end
        if d <= OFFROAD_NEAR then return d * profile.off end
        return OFFROAD_NEAR * profile.off + (d - OFFROAD_NEAR) * far
    end

    -- (les accès aux routes de chaque point clé)
    local nets, access, accessOf, onEdge = {}, {}, {}, {}
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

    local dist, prev, via, done = { start = 0 }, {}, {}, {}
    local heap = Heap()
    heap.Push(0, "start")
    local best, bd

    local function Relax(id, cost, edge)
        if done[id] then return end
        local nd = bd + cost
        if not dist[id] or nd < dist[id] then
            dist[id], prev[id], via[id] = nd, best, edge
            heap.Push(nd, id)
        end
    end

    -- Une marche : son coût (la préférence) et son temps réel
    local function Line(id, ax, ay, bx, by)
        local dx, dy = bx - ax, by - ay
        local d = math.sqrt(dx * dx + dy * dy)
        Relax(id, Offroad(d) / speed, { kind = "walk", secs = d * DETOUR / speed, line = { ax, ay, bx, by } })
    end
    local function Road(id, cont, e, p0, p1)
        local d = math.abs(p1 - p0)
        Relax(id, d / speed, { kind = "walk", secs = d / speed, road = { cont, e, p0, p1 } })
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
                -- (les vols, les bateaux, les zeppelins ; un vol qui en suit un
                -- autre continue le même voyage : pas de nouveau décollage)
                for _, e in ipairs(edges[best] or {}) do
                    local cost = e.secs
                    if e.kind == "flight" and not (via[best] and via[best].kind == "flight") then cost = cost + G.TAKEOFF end
                    Relax(e.to, cost, e)
                end
                -- (en ligne droite vers les autres points clés du continent)
                for id, n in pairs(nodes) do
                    if id ~= best and id ~= "start" and n.cont == key.cont then
                        Line(id, key.x, key.y, n.x, n.y)
                    end
                end
                -- (jusqu'aux routes voisines)
                for _, aid in ipairs(accessOf[best] or {}) do
                    local a = access[aid]
                    Line(aid, key.x, key.y, a.x, a.y)
                end
            elseif acc then
                -- (quitter la route vers son point clé, ou la suivre)
                local k = nodes[acc.key]
                Line(acc.key, acc.x, acc.y, k.x, k.y)
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
        else
            local leg = { kind = e.kind, from = nodes[link.from], to = nodes[link.to], secs = e.secs, route = e.route }
            if e.kind == "flight" then
                leg.secs = leg.secs + G.TAKEOFF
                leg.paths, leg.measured = { e.path }, e.measured
            end
            legs[#legs + 1] = leg
        end
    end
    for _, leg in ipairs(legs) do total = total + leg.secs end
    return { legs = legs, secs = total, speed = speed, known = g.known, roads = useRoads and true or false }, g
end

-- La marche seule d'un point à un autre, selon le réglage, sans la grille
-- (une longue ligne droite y compte au moins OFFROAD_BLIND) : le secours
-- d'une marche que la grille n'a pas pu préciser. Rend son étape de marche,
-- ou nil.
function Pl.WalkEstimate(from, to)
    local plan = Pl.Find({ cont = from.cont, x = from.x, y = from.y }, { cont = to.cont, x = to.x, y = to.y },
        { walkOnly = true, blind = true })
    local leg = plan and plan.legs[1]
    if leg and leg.kind == "walk" and #plan.legs == 1 then return leg end
end
