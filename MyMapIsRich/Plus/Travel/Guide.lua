-- Le suivi d'un itinéraire (ns.Travel) : R3 sur la carte le lance vers le
-- point sous le curseur (Pad/MapNav.lua), R3 sur sa destination l'annule.
-- L'étape en cours pose le waypoint du jeu (sa flèche) au bout de l'étape :
-- le maître de vol, le quai, puis la destination ; pendant une marche qui
-- suit les routes, un peu devant toi sur le tracé. Il passe par OpenMap
-- (mod.TrackPoint : le waypoint de Blizzard, ou le sien, et TomTom) ; rien
-- n'est écrit dans la carte de Blizzard.
-- Toutes les secondes, pendant un trajet : le joueur arrivé au bout d'une
-- étape (ou d'une étape plus loin), on passe à la suivante. En vol, on
-- attend l'atterrissage (le temps qu'il reste est suivi, et une alerte
-- sonne avant). À la destination : un message, et la destination suivante
-- de la file, s'il y en a une.
-- Chaque étape, l'arrivée et la sortie du chemin font vibrer la manette
-- (Pad/Rumble.lua) et sonnent (réglages Vibrations et Sons).
-- La file : d'autres destinations après celle-ci, rangées dans l'ordre le
-- plus court (le plus proche d'abord, puis 2-opt) ; l'onglet File du
-- navigateur de lieux les montre (UI/Places.lua).
-- En fantôme : un itinéraire à pied jusqu'au corps ; le trajet d'avant
-- reprend après la résurrection.
-- La destination et la file sont gardées par personnage
-- (OpenMapOnGamepadDB.travel, travelQueue) : après un /reload, le trajet est
-- recalculé depuis où tu es.
local _, root = ...
local ns = root.Plus
local L = ns.L
local G = ns.TravelGraph
local Pl = ns.TravelPlanner
local R = ns.TravelRoute

local T = {}
ns.Travel = T

local REACH = { walk = 30, flight = 90, boat = 70, zeppelin = 70, portal = 40, tram = 40 }   -- yd : arrivé au bout d'une étape
local GOAL_REACH = 25        -- yd : arrivé à la destination
local CORPSE_REACH = 20      -- yd : arrivé près du corps
local CURSOR_ON_GOAL = 24    -- px : le curseur sur la destination (R3 l'annule)
local TICK = 1               -- s
local RESUME_DELAY = 3       -- s après la connexion
local OFF_ROUTE = 150        -- yd : plus loin du chemin d'une marche, on en est sorti...
local OFF_TICKS = 3          -- ... pendant autant de secondes de suite : recalculé
local REPLAN_GAP = 10        -- s entre deux recalculs
local LAND_WARN = 10         -- s avant l'atterrissage d'un vol : l'alerte
local NEXT_DELAY = 1.5       -- s entre l'arrivée et la destination suivante de la file
local QUEUE_MAX = 20
local lastReplan = -REPLAN_GAP

local state                  -- { plan, index, goal, taxi }
local lastWaypoint           -- { mapID, x, y } : le waypoint posé par nous
local aimPending = false     -- à poser à la fin du combat
local lastPlan               -- le dernier calcul (pour /mmir trajet)
local queue = {}             -- les destinations suivantes
local stash                  -- la destination d'avant la mort (reprise à la résurrection)

---------------------------------------------------------------------------
-- Les textes
---------------------------------------------------------------------------
local function Zone(point)
    return Pl.ZoneName(point) or L.TRAVEL_DEST
end

local function NodeName(n)
    if n.kind == "flight" then
        -- (pas encore appris : on lui parle en arrivant, puis on s'envole)
        return (n.known == false and L.TRAVEL_FM_NEW or L.TRAVEL_FM):format(n.name or "?")
    end
    if n.kind == "dock" then return L.TRAVEL_DOCK:format(Zone(n)) end
    if n.kind == "passage" then
        return (n.passage == "tram" and L.TRAVEL_TRAM or L.TRAVEL_PORTAL):format(Zone(n))
    end
    if n.kind == "goal" then
        if n.corpse then return L.TRAVEL_CORPSE_DEST end
        -- (une quête : son titre ; un lieu, un PNJ : son nom)
        if n.title then return L.TRAVEL_QUEST_DEST:format(n.title) end
        if n.name then return n.name end
        return L.TRAVEL_DEST_IN:format(Zone(n))
    end
    return Zone(n)
end

-- Ce qu'il faut faire pendant une étape : « Va au maître de vol (Hurlevent) »
function T.LegText(leg)
    local to = leg.to
    if leg.kind == "flight" then return L.TRAVEL_LEG_FLIGHT:format(to.name or "?") end
    if leg.kind == "boat" then return L.TRAVEL_LEG_BOAT:format(Zone(to)) end
    if leg.kind == "zeppelin" then return L.TRAVEL_LEG_ZEPPELIN:format(Zone(to)) end
    if leg.kind == "portal" then return L.TRAVEL_LEG_PORTAL:format(Zone(to)) end
    if leg.kind == "tram" then return L.TRAVEL_LEG_TRAM:format(Zone(to)) end
    return L.TRAVEL_LEG_WALK:format(NodeName(to))
end

-- Le nom court d'une destination (le panneau de trajet, la file) : son nom,
-- le titre de sa quête, sinon sa zone
function T.GoalName(goal)
    if not goal then return "" end
    if goal.corpse then return L.TRAVEL_CORPSE_NAME end
    if goal.name then return goal.name end
    if goal.title then return L.TRAVEL_QUEST_SHORT:format(goal.title) end
    return Zone(goal)
end

function T.ZoneOf(point) return Pl.ZoneName(point) end

---------------------------------------------------------------------------
-- Les retours : la manette vibre, un son (réglages)
---------------------------------------------------------------------------
local SOUNDS = {
    step = { "MAP_PING", 3175 },
    arrive = { "READY_CHECK", 8960 },
    off = { "IG_MAINMENU_OPTION_CHECKBOX_OFF", 857 },
    land = { "MAP_PING", 3175 },
}

-- Un message de suivi (une étape, l'arrivée...) : seulement sans le panneau
-- de trajet, qui dit déjà tout (UI/RouteHud.lua) ; les erreurs, elles,
-- s'écrivent toujours (ns.Print)
function T.Say(msg, ...)
    if ns.db and ns.db.options.travelHud == false then ns.Print(msg, ...) end
end

function T.Feedback(kind)
    if ns.Rumble then ns.Rumble.Play(kind) end
    if not (ns.db and ns.db.options.travelSound ~= false and PlaySound) then return end
    local s = SOUNDS[kind]
    local id = s and (SOUNDKIT and SOUNDKIT[s[1]] or s[2])
    if id then pcall(PlaySound, id, "Master") end
end

---------------------------------------------------------------------------
-- La destination et la file, gardées par personnage
---------------------------------------------------------------------------
local function CharKey()
    local name = UnitName and UnitName("player") or "?"
    local realm = GetRealmName and GetRealmName() or "?"
    return name .. "-" .. realm
end

-- (une destination sans ses champs de calcul : ce qui se garde)
local function Copy(goal)
    return { cont = goal.cont, x = goal.x, y = goal.y, map = goal.map, mx = goal.mx, my = goal.my,
        title = goal.title, questID = goal.questID, name = goal.name, rally = goal.rally }
end
T.Copy = Copy

local function Valid(saved)
    return type(saved) == "table" and type(saved.cont) == "number" and type(saved.x) == "number" and type(saved.y) == "number"
end

local function Save(goal)
    if not ns.db then return end
    -- (le corps n'est pas gardé : la destination d'avant la mort l'est encore)
    if goal and goal.corpse then return end
    ns.db.travel = ns.db.travel or {}
    ns.db.travel[CharKey()] = goal and Copy(goal) or nil
end

local function SaveQueue()
    if not ns.db then return end
    ns.db.travelQueue = ns.db.travelQueue or {}
    local list = {}
    for i, g in ipairs(queue) do list[i] = Copy(g) end
    ns.db.travelQueue[CharKey()] = #list > 0 and list or nil
end

---------------------------------------------------------------------------
-- Le waypoint de l'étape en cours. Pendant une marche qui suit les routes,
-- il est posé sur le tracé, AHEAD yards devant le joueur (depuis le point du
-- tracé le plus proche de lui, sans jamais revenir en arrière) : la flèche
-- suit les virages de la route au lieu de pointer droit vers le bout.
---------------------------------------------------------------------------
local AHEAD = 200            -- yd : le waypoint d'une marche, devant le joueur sur le tracé
local MOVE = 60              -- yd : il n'est reposé que s'il a avancé d'autant
local WINDOW = 40            -- segments du tracé regardés après le dernier atteint

local function Project(ax, ay, bx, by, x, y)
    local dx, dy = bx - ax, by - ay
    local len2 = dx * dx + dy * dy
    local t = len2 > 0 and ((x - ax) * dx + (y - ay) * dy) / len2 or 0
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local px, py = ax + t * dx, ay + t * dy
    return t, (x - px) * (x - px) + (y - py) * (y - py)
end

-- Le point visé pendant une étape : AHEAD yd devant le joueur sur le tracé
-- d'une marche, sinon le bout de l'étape
local function Target(leg, here)
    local pts = leg.points
    if leg.kind ~= "walk" or not (pts and #pts >= 2 and here and here.cont == leg.from.cont) then
        state.proj = nil
        return leg.to
    end
    local from = state.progress or 1
    local bestJ, bestT, bestD = from, 0, math.huge
    local function Scan(j0, j1)
        for j = j0, j1 do
            local t, d2 = Project(pts[j].x, pts[j].y, pts[j + 1].x, pts[j + 1].y, here.x, here.y)
            if d2 < bestD then bestJ, bestT, bestD = j, t, d2 end
        end
    end
    Scan(from, math.min(#pts - 1, from + WINDOW))
    -- (loin du tracé : tout ce qui reste est regardé)
    if bestD > 150 * 150 then Scan(from, #pts - 1) end
    state.progress = bestJ
    local a, b = pts[bestJ], pts[bestJ + 1]
    local x, y = a.x + bestT * (b.x - a.x), a.y + bestT * (b.y - a.y)
    -- (où en est le joueur : pour le tracé, le temps restant, l'écart au chemin)
    state.proj = { j = bestJ, x = x, y = y, dist = math.sqrt(bestD), px = here.x, py = here.y }
    local left, j = AHEAD, bestJ
    while j < #pts do
        local nx, ny = pts[j + 1].x, pts[j + 1].y
        local seg = math.sqrt((nx - x) * (nx - x) + (ny - y) * (ny - y))
        if seg >= left then
            local f = seg > 0 and left / seg or 0
            return { cont = leg.from.cont, x = x + (nx - x) * f, y = y + (ny - y) * f }
        end
        left = left - seg
        x, y, j = nx, ny, j + 1
    end
    return leg.to
end

local function Aim(say)
    if not state then return end
    local leg = state.plan.legs[state.index]
    if not leg then return end
    if say then
        T.Say(L.TRAVEL_STEP, state.index, #state.plan.legs, T.LegText(leg), R.Clock(leg.secs))
    end
    if InCombatLockdown() then
        aimPending = true
        return
    end
    aimPending = false
    local target = Target(leg, Pl.PlayerPoint())
    state.target = target
    local mapID, mx, my = Pl.MapPoint(target)
    local mod = ns.mod
    if mapID and mod and mod.TrackPoint then
        local ok = ns.Call(mod.TrackPoint, mapID, mx, my, T.LegText(leg))
        if ok then lastWaypoint = { mapID, mx, my } end
    end
end

-- (pendant une marche : où en est le joueur, et le waypoint reposé plus loin
-- quand il avance)
local function FollowWalk(here)
    local leg = state.plan.legs[state.index]
    if not (leg and leg.kind == "walk" and leg.points) then
        state.proj = nil
        return
    end
    local target = Target(leg, here)
    if InCombatLockdown() then return end
    local last = state.target
    if last == target then return end
    if last and last.cont == target.cont and G.Dist(last, target) < MOVE then return end
    Aim(false)
end

---------------------------------------------------------------------------
-- Le tracé suit le joueur : il part de lui, la partie faite disparaît, et
-- le temps restant se met à jour (redessiné quand il a bougé, carte ouverte)
---------------------------------------------------------------------------
local REDRAW_MOVE = 8        -- yd

local function LegLength(leg)
    if not leg.length then
        local pts, total = leg.points, 0
        for i = 2, #pts do
            local dx, dy = pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y
            total = total + math.sqrt(dx * dx + dy * dy)
        end
        leg.length = total
    end
    return leg.length
end

-- Ce qu'il reste d'une marche en cours (yd), d'après où en est le joueur
local function WalkLeft(leg, p)
    local pts = leg.points
    local nx, ny = pts[p.j + 1].x, pts[p.j + 1].y
    local rest = math.sqrt((nx - p.x) * (nx - p.x) + (ny - p.y) * (ny - p.y))
    for i = p.j + 1, #pts - 1 do
        local dx, dy = pts[i + 1].x - pts[i].x, pts[i + 1].y - pts[i].y
        rest = rest + math.sqrt(dx * dx + dy * dy)
    end
    return rest
end

-- En vol : le temps de vol qu'il reste (s), et le temps de tout le vol
local function FlightLeft()
    local taxi = state and state.taxi
    local leg = state and state.plan.legs[state.index]
    if not (taxi and leg and leg.kind == "flight") then return end
    local total = math.max(1, leg.secs - G.TAKEOFF)
    return math.max(0, total - (GetTime() - taxi.start)), total
end

-- Le temps qu'il reste : l'étape en cours (une marche : la part qu'il en
-- reste ; un vol en l'air : le temps de vol qui reste), puis les suivantes
local function Remaining()
    local legs = state.plan.legs
    local total = 0
    for i = state.index, #legs do total = total + legs[i].secs end
    local leg, p = legs[state.index], state.proj
    if leg and leg.kind == "walk" and leg.points and p then
        local len = LegLength(leg)
        if len > 0 then total = total - leg.secs + leg.secs * math.min(1, WalkLeft(leg, p) / len) end
    elseif leg and leg.kind == "flight" and state.taxi then
        local left = FlightLeft()
        if left then total = total - leg.secs + left end
    end
    return total
end
T.Remaining = function() return state and Remaining() or nil end

local function Redraw(force)
    if not state then return end
    local p = state.proj
    if not (force or ns.MapShown()) then return end
    local live = p and { j = p.j, x = p.x, y = p.y, px = p.px, py = p.py } or nil
    R.Show(state.plan, state.index, live, Remaining())
    state.drawnX, state.drawnY = p and p.px, p and p.py
end

-- Pour la minimap (Travel/Minimap.lua) : le plan, l'étape en cours, et où en
-- est le joueur sur une marche
function T.Live()
    if not state then return end
    return state.plan, state.index, state.proj, state.goal
end

-- Pour le panneau de trajet (UI/RouteHud.lua) : tout ce qu'il montre
--   { plan, index, leg, goal, remaining, legLeft (yd d'une marche, sinon
--     nil), flight = { left, total } en l'air, queued, corpse }
function T.Status()
    if not state then return end
    local leg = state.plan.legs[state.index]
    local out = { plan = state.plan, index = state.index, leg = leg, goal = state.goal,
        remaining = Remaining(), queued = #queue, corpse = state.goal.corpse and true or false }
    if leg and leg.kind == "walk" then
        local p = state.proj
        if p and leg.points then
            out.legLeft = WalkLeft(leg, p)
        else
            local here = Pl.PlayerPoint()
            if here and here.cont == leg.to.cont then out.legLeft = G.Dist(here, leg.to) end
        end
    end
    if state.taxi then
        local left, total = FlightLeft()
        if left then out.flight = { left = left, total = total } end
    end
    return out
end

-- Le point que vise l'étape en cours (la flèche GPS : UI/RouteHud.lua) : celui
-- du waypoint, un peu devant sur la route pendant une marche, sinon le bout de
-- l'étape
function T.Target()
    if not state then return end
    local leg = state.plan.legs[state.index]
    return state.target or (leg and leg.to)
end

-- Le waypoint d'OpenMap est-il toujours le nôtre ? (sinon il n'est pas effacé)
local function OurWaypoint()
    local mod = ns.mod
    if not (lastWaypoint and mod and mod.WaypointPoint) then return false end
    local ok, mapID, x, y = pcall(mod.WaypointPoint)
    if not ok or mapID ~= lastWaypoint[1] or not x then return false end
    return math.abs(x - lastWaypoint[2]) < 0.002 and math.abs(y - lastWaypoint[3]) < 0.002
end

---------------------------------------------------------------------------
-- Lancer, annuler
---------------------------------------------------------------------------
local ticker = CreateFrame("Frame")
ticker:Hide()

function T.Active() return state ~= nil end
function T.Goal() return state and state.goal end

---------------------------------------------------------------------------
-- Les chemins précis (Travel/Nav.lua) : l'itinéraire part tout de suite sur
-- son estimation par les routes, puis chaque marche, l'une après l'autre
-- (celle en cours d'abord, depuis où est le joueur), est recherchée sur la
-- grille de marche en tâche de fond. Un chemin trouvé remplace le tracé de
-- l'étape, son temps et la flèche ; sinon l'estimation reste.
---------------------------------------------------------------------------
local cancelSearch

local function StopSearch()
    if cancelSearch then cancelSearch() end
    cancelSearch = nil
end

local INSET = 90             -- yd : une seconde recherche part et arrive aussi loin à l'intérieur du tracé
local MIN_INSET_LEG = 300    -- yd : ... pour une marche au moins aussi longue

-- Le point d'un tracé à `d` yards de son début (ou de sa fin, `fromEnd`), et
-- le numéro du point du tracé qui le suit (ou le précède)
local function Along(points, d, fromEnd)
    local n = #points
    local first, last, step = 1, n, 1
    if fromEnd then first, last, step = n, 1, -1 end
    local left = d
    for i = first, last - step, step do
        local a, b = points[i], points[i + step]
        local seg = math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y))
        if seg >= left then
            local f = seg > 0 and left / seg or 0
            return { x = a.x + (b.x - a.x) * f, y = a.y + (b.y - a.y) * f }, i + step
        end
        left = left - seg
    end
end

-- Une marche précisée (ou recalculée par les routes) : son nouveau tracé ;
-- `nav` : ce qu'en dit la grille (pour /mmir trajet)
local function Replace(leg, i, points, secs, nav)
    local plan = state.plan
    leg.points, leg.secs, leg.nav = points, secs, nav
    leg.geom, leg.length = nil, nil
    local total = 0
    for _, l in ipairs(plan.legs) do total = total + l.secs end
    plan.secs = total
    if i == state.index then
        state.progress, state.target, state.proj = nil, nil, nil
        Aim(false)
    end
    Redraw(true)
    ns.Fire("TRAVEL")
end

local Refine

-- La grille n'a pas trouvé de chemin : le départ ou l'arrivée est peut-être
-- sur un petit étage laissé de côté (un ponton, une plateforme), ou dans un
-- coin que la grille ne relie pas. Une seconde recherche part et arrive un
-- peu à l'intérieur du tracé estimé, et les deux bouts estimés y sont
-- raccordés. Sinon, la marche est recalculée par les routes, la ligne droite
-- bien plus chère (Planner.WalkEstimate).
local function Failed(leg, i, from, mine)
    local Nav = ns.TravelNav
    local pts = leg.points
    if leg.refined == "searching" and pts and #pts >= 2 then
        local total = 0
        for k = 2, #pts do
            total = total + math.sqrt((pts[k].x - pts[k - 1].x) ^ 2 + (pts[k].y - pts[k - 1].y) ^ 2)
        end
        if total >= MIN_INSET_LEG then
            local a, ai = Along(pts, INSET, false)
            local b, bi = Along(pts, INSET, true)
            if a and b then
                leg.refined = "retry"
                local cont = leg.from.cont
                cancelSearch = Nav.Find(cont, { cont = cont, x = a.x, y = a.y }, { cont = cont, x = b.x, y = b.y },
                    state.plan.speed, function(path)
                        cancelSearch = nil
                        if state ~= mine then return end
                        if path then
                            local out = {}
                            for k = 1, ai - 1 do out[#out + 1] = pts[k] end
                            for _, p in ipairs(path.points) do out[#out + 1] = p end
                            for k = bi + 1, #pts do out[#out + 1] = pts[k] end
                            local speed = state.plan.speed or 7
                            leg.refined = true
                            Replace(leg, i, out, path.secs + 2 * INSET * 1.3 / speed, path)
                        else
                            Failed(leg, i, from, mine)
                        end
                        Refine()
                    end)
                return
            end
        end
    end
    leg.refined = "failed"
    local est = Pl.WalkEstimate(from, leg.to)
    if est and est.points and #est.points > 2 then Replace(leg, i, est.points, est.secs) end
end

Refine = function()
    StopSearch()
    local Nav = ns.TravelNav
    if not (state and Nav and Nav.Available() and ns.db and ns.db.options.travelTerrain ~= false) then return end
    local legs = state.plan.legs
    for i = state.index, #legs do
        local leg = legs[i]
        if leg.kind == "walk" and not leg.refined and leg.from.cont == leg.to.cont and Nav.Has(leg.from.cont) then
            local from = leg.from
            local here = i == state.index and Pl.PlayerPoint()
            if here and here.cont == from.cont then from = here end
            local mine = state
            leg.refined = "searching"
            -- (le départ garde sa couche, un bout de passage, ou sa carte, une ville sous terre)
            cancelSearch = Nav.Find(from.cont, { cont = from.cont, x = from.x, y = from.y, layer = from.layer, map = from.map },
                leg.to, state.plan.speed,
                function(path)
                    cancelSearch = nil
                    if state ~= mine then return end
                    if path then
                        leg.refined = true
                        Replace(leg, i, path.points, path.secs, path)
                    else
                        Failed(leg, i, from, mine)
                        if leg.refined == "retry" then return end
                    end
                    Refine()
                end)
            return
        end
    end
end

function T.Cancel(say)
    StopSearch()
    local was = state and state.goal
    if state and OurWaypoint() and ns.mod and ns.mod.ClearPin then ns.Call(ns.mod.ClearPin) end
    state, lastWaypoint, aimPending = nil, nil, false
    R.Clear()
    -- (le trajet vers le corps annulé : la destination d'avant reste gardée)
    if not (was and was.corpse) then Save(nil) end
    ticker:Hide()
    if say then T.Say(L.TRAVEL_CANCELLED) end
    ns.Fire("TRAVEL")
    if was then ns.Fire("TRAVEL_END", was) end
end

-- mode : nil (un nouvel itinéraire), "resume" (après un /reload), "replan"
-- (recalculé : le joueur a quitté le chemin), "next" (la destination
-- suivante de la file), "corpse" (le retour au corps)
local MESSAGES = { resume = "TRAVEL_RESUMED", replan = "TRAVEL_REPLANNED", next = "TRAVEL_NEXT", corpse = "TRAVEL_CORPSE" }

function T.Start(plan, goal, mode)
    local was = state and state.goal
    state = { plan = plan, index = 1, goal = goal }
    Save(goal)
    R.Show(plan, 1)
    local steps = #plan.legs
    T.Say(L[MESSAGES[mode] or "TRAVEL_PLANNED"],
        steps == 1 and L.TRAVEL_ONE_STEP or L.TRAVEL_STEPS:format(steps), R.Clock(plan.secs))
    -- (recalculé en chemin : l'étape n'est redite que si elle a changé)
    Aim(mode ~= "replan")
    Redraw(true)
    ticker:Show()
    ns.Fire("TRAVEL")
    if was and was ~= goal then ns.Fire("TRAVEL_END", was) end
    Refine()
end

-- Calculer et lancer un trajet du joueur vers `goal` ; faux (et un message)
-- si ce n'est pas possible ; "here" : il y est déjà
local function Plan(goal, quiet, mode)
    local here = Pl.PlayerPoint()
    if not here then
        if not quiet then ns.Print(L.TRAVEL_NO_HERE) end
        return false
    end
    local reach = goal.corpse and CORPSE_REACH or GOAL_REACH
    if here.cont == goal.cont and G.Dist(here, goal) <= reach then
        if not quiet then ns.Print(L.TRAVEL_ALREADY) end
        return false, "here"
    end
    -- (un fantôme marche, et plus vite)
    local opts = goal.corpse and { walkOnly = true, speed = Pl.GHOST_SPEED } or nil
    local plan, g = Pl.Find(here, goal, opts)
    lastPlan = { here = here, goal = goal, plan = plan, known = g and g.known or 0 }
    if not plan or #plan.legs == 0 then
        if not quiet then
            ns.Print(L.TRAVEL_NO_ROUTE)
            if not goal.corpse and (g and g.known or 0) == 0 then ns.Print(L.TRAVEL_NO_FLIGHTS) end
        end
        return false
    end
    T.Start(plan, goal, mode)
    return true
end

-- Un trajet vers un point du monde (le navigateur de lieux, une
-- destination reçue du groupe...) ; vrai s'il est lancé
function T.Go(goal, quiet)
    if not (ns.db and ns.db.options.travel and goal) then return false end
    return Plan(goal, quiet) and true or false
end

---------------------------------------------------------------------------
-- La file : les destinations suivantes, dans l'ordre le plus court. La
-- distance est celle à vol d'oiseau (un autre continent : très loin), assez
-- pour ranger quelques lieux ; le vrai trajet est calculé à chaque départ.
---------------------------------------------------------------------------
local FAR = 1e7

local function Cost(a, b)
    if not (a and b) then return 0 end
    if a.cont ~= b.cont then return FAR end
    return G.Dist(a, b)
end

-- Le plus proche d'abord depuis `start`, puis 2-opt (un morceau du chemin
-- retourné tant que cela le raccourcit) ; le point de départ ne bouge pas
local function Order(start, list)
    local n = #list
    if n < 2 then return list end
    local left, path, at = {}, {}, start
    for i, g in ipairs(list) do left[i] = g end
    while #left > 0 do
        local best, bestD = 1, math.huge
        for i, g in ipairs(left) do
            local d = Cost(at, g)
            if d < bestD then best, bestD = i, d end
        end
        at = table.remove(left, best)
        path[#path + 1] = at
    end
    local p = { start }
    for i, g in ipairs(path) do p[i + 1] = g end
    local improved, rounds = true, 0
    while improved and rounds < 50 do
        improved, rounds = false, rounds + 1
        for i = 2, n do
            for j = i + 1, n + 1 do
                local before = Cost(p[i - 1], p[i]) + (p[j + 1] and Cost(p[j], p[j + 1]) or 0)
                local after = Cost(p[i - 1], p[j]) + (p[j + 1] and Cost(p[i], p[j + 1]) or 0)
                if after < before - 0.5 then
                    local a, b = i, j
                    while a < b do
                        p[a], p[b] = p[b], p[a]
                        a, b = a + 1, b - 1
                    end
                    improved = true
                end
            end
        end
    end
    local out = {}
    for i = 2, n + 1 do out[#out + 1] = p[i] end
    return out
end

function T.Queue() return queue end

-- Ranger la file dans l'ordre le plus court, après la destination en cours
function T.Optimize()
    local start = state and not state.goal.corpse and state.goal or Pl.PlayerPoint()
    if start and #queue >= 2 then
        -- (Order rend une nouvelle liste : la file est remplie de nouveau)
        local ordered = Order(start, queue)
        wipe(queue)
        for i, g in ipairs(ordered) do queue[i] = g end
    end
    SaveQueue()
    ns.Fire("TRAVEL")
end

-- Ajouter une destination : sans trajet en cours, elle est lancée tout de
-- suite ; sinon elle va dans la file (rangée)
function T.Enqueue(goal)
    if not (ns.db and ns.db.options.travel and goal) then return false end
    if not state then return T.Go(goal) end
    if #queue >= QUEUE_MAX then
        ns.Print(L.TRAVEL_QUEUE_FULL, QUEUE_MAX)
        return false
    end
    queue[#queue + 1] = goal
    T.Optimize()
    T.Say(L.TRAVEL_QUEUED, T.GoalName(goal), #queue)
    return true
end

function T.Unqueue(i)
    if not queue[i] then return end
    table.remove(queue, i)
    SaveQueue()
    ns.Fire("TRAVEL")
end

function T.ClearQueue()
    wipe(queue)
    SaveQueue()
    ns.Fire("TRAVEL")
end

-- Monter (dir -1) ou descendre (1) une destination ; rend sa nouvelle place
function T.MoveQueued(i, dir)
    local j = i + dir
    if not (queue[i] and queue[j]) then return i end
    queue[i], queue[j] = queue[j], queue[i]
    SaveQueue()
    ns.Fire("TRAVEL")
    return j
end

-- Y aller maintenant : elle passe devant ; la destination en cours revient
-- en tête de la file
function T.GoQueued(i)
    local goal = queue[i]
    if not goal then return end
    table.remove(queue, i)
    if state and not state.goal.corpse then table.insert(queue, 1, state.goal) end
    SaveQueue()
    if not Plan(goal, false) then
        -- (pas possible : elle reprend sa place)
        table.insert(queue, math.min(i, #queue + 1), goal)
        SaveQueue()
    end
    ns.Fire("TRAVEL")
end

-- La destination suivante de la file (après une arrivée)
local function NextInQueue()
    while #queue > 0 and not state do
        local goal = table.remove(queue, 1)
        SaveQueue()
        local ok = Plan(goal, false, "next")
        if ok then return end
    end
    ns.Fire("TRAVEL")
end

-- Passer la destination en cours : la suivante de la file, s'il y en a une
function T.Skip()
    if state and state.goal.corpse then return end
    T.Cancel(true)
    NextInQueue()
end

local function Arrived()
    local goal = state.goal
    T.Feedback("arrive")
    if goal.corpse then
        T.Say(L.TRAVEL_CORPSE_REACHED)
        T.Cancel(false)
        return
    end
    T.Say(L.TRAVEL_ARRIVED)
    ns.Fire("TRAVEL_ARRIVED", goal)
    T.Cancel(false)
    if #queue > 0 then
        C_Timer.After(NEXT_DELAY, function() if not state then NextInQueue() end end)
    end
end

-- Le curseur est-il sur la destination du trajet en cours ?
local function CursorOnGoal(u, v, pu, pv)
    if not (state and u and pu and pv and pu > 0 and pv > 0) then return false end
    local gu, gv = Pl.UV(state.goal)
    if not gu then return false end
    local dx, dy = (u - gu) / pu, (v - gv) / pv
    return dx * dx + dy * dy <= CURSOR_ON_GOAL * CURSOR_ON_GOAL
end

-- R3 sur la carte : un trajet vers le point sous le curseur, ou l'annuler
-- si le curseur est sur sa destination
function T.AtCursor()
    if not (ns.db and ns.db.options.travel) then return end
    local point, u, v, pu, pv = Pl.CursorPoint()
    if CursorOnGoal(u, v, pu, pv) then
        T.Cancel(true)
        return
    end
    if not point then
        ns.Print(L.TRAVEL_NO_THERE)
        return
    end
    Plan(point, false)
end

-- R3 sur une quête de la liste de droite (Travel/Quests.lua) : un trajet
-- jusqu'à elle, ou l'annuler si c'est déjà sa destination
function T.AtQuest(questID)
    if not (ns.db and ns.db.options.travel) then return end
    if state and state.goal.questID == questID then
        T.Cancel(true)
        return
    end
    local point, title = ns.TravelQuests.Point(questID)
    if not point then
        ns.Print(L.TRAVEL_NO_QUEST:format(title or ("#" .. questID)))
        return
    end
    Plan(point, false)
end

-- Le libellé de R3 dans la barre d'aide
function T.HintLabel()
    if not (ns.db and ns.db.options.travel) then return nil end
    if state and CursorOnGoal(Pl.CursorUV()) then return "HINT_TRAVEL_CANCEL" end
    return "HINT_TRAVEL"
end

---------------------------------------------------------------------------
-- En fantôme : le trajet jusqu'au corps
---------------------------------------------------------------------------
local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Où est le corps : sur la carte où est le joueur, sinon sur celles qui la
-- contiennent (la zone, le continent)
local function CorpsePoint()
    if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition and C_Map and C_Map.GetBestMapForUnit) then return end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    mapID = ok and Plain(mapID) or nil
    local guard = 0
    while mapID and guard < 6 do
        guard = guard + 1
        local okP, pos = pcall(C_DeathInfo.GetCorpseMapPosition, mapID)
        if okP and pos then
            local okXY, x, y = pcall(pos.GetXY, pos)
            x, y = okXY and Plain(x), okXY and Plain(y)
            if x and y and (x ~= 0 or y ~= 0) then return Pl.WorldOf(mapID, x, y) end
        end
        local okI, info = pcall(C_Map.GetMapInfo, mapID)
        mapID = okI and type(info) == "table" and info.parentMapID or nil
        if mapID == 0 then mapID = nil end
    end
end

local function IsGhost()
    return UnitIsGhost and UnitIsGhost("player") and true or false
end

-- La destination qui attend la résurrection (le panneau de trajet le dit)
function T.Stashed() return stash end

function T.CheckGhost()
    if not (ns.db and ns.db.options.travel) then return end
    if IsGhost() then
        if not ns.db.options.travelCorpse or (state and state.goal.corpse) then return end
        local point = CorpsePoint()
        if not point then return end
        point.corpse = true
        -- (la destination en cours attend la résurrection)
        if state then stash = state.goal end
        StopSearch()
        local ok = Plan(point, true, "corpse")
        if not ok and state and not state.goal.corpse then stash = nil end
    else
        if state and state.goal.corpse then T.Cancel(false) end
        if stash then
            local goal = stash
            stash = nil
            C_Timer.After(NEXT_DELAY, function()
                if not state and ns.db.options.travel then Plan(goal, false, "resume") end
            end)
        end
    end
end

---------------------------------------------------------------------------
-- Le suivi
---------------------------------------------------------------------------
local wait = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = TICK
    if not state then ticker:Hide() return end
    local legs = state.plan.legs
    -- (en vol : rien avant l'atterrissage, le trajet survole d'autres
    -- étapes ; le temps de vol est compté, l'alerte sonne avant la fin)
    if UnitOnTaxi and UnitOnTaxi("player") then
        if not state.taxi then
            -- (monté sur le vol depuis la marche qui y menait : l'étape du vol commence)
            local leg = legs[state.index]
            if leg and leg.kind ~= "flight" and legs[state.index + 1] and legs[state.index + 1].kind == "flight" then
                state.index = state.index + 1
                state.progress, state.target, state.proj = nil, nil, nil
                Redraw(true)
            end
            state.taxi = { start = GetTime() }
            ns.Fire("TRAVEL")
        end
        local left = FlightLeft()
        if left and left <= LAND_WARN and not state.taxi.warned then
            state.taxi.warned = true
            T.Feedback("land")
            T.Say(L.TRAVEL_LANDING)
        end
        return
    elseif state.taxi then
        state.taxi = nil
        ns.Fire("TRAVEL")
    end
    local here = Pl.PlayerPoint()
    if not here then return end
    for j = #legs, state.index, -1 do
        local leg = legs[j]
        -- (un vol atterrit, un bateau accoste, un peu à côté de leur point)
        local reach = REACH[leg.kind] or REACH.walk
        if j == #legs and leg.kind == "walk" then reach = state.goal.corpse and CORPSE_REACH or GOAL_REACH end
        if leg.to.cont == here.cont and G.Dist(here, leg.to) <= reach then
            if j == #legs then
                Arrived()
            else
                state.index = j + 1
                state.progress, state.target, state.proj, state.off = nil, nil, nil, 0
                T.Feedback("step")
                Aim(true)
                Redraw(true)
                ns.Fire("TRAVEL")
            end
            return
        end
    end
    FollowWalk(here)
    local p = state.proj
    -- (loin du chemin quelques secondes de suite : recalculé depuis où il est)
    if p and p.dist > OFF_ROUTE then
        state.off = (state.off or 0) + 1
        if state.off >= OFF_TICKS and GetTime() - lastReplan >= REPLAN_GAP then
            lastReplan = GetTime()
            T.Feedback("off")
            Plan(state.goal, true, "replan")
            return
        end
    else
        state.off = 0
    end
    if p and not (state.drawnX and math.abs(p.px - state.drawnX) + math.abs(p.py - state.drawnY) < REDRAW_MOVE) then
        Redraw(false)
    end
end)

-- (la carte ouverte : le tracé tel qu'il est maintenant)
ns.On("MAP_SHOW", function() Redraw(true) end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_UNGHOST")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if aimPending then Aim(false) end
    elseif ns.Ready() then
        -- (libéré : fantôme ; ressuscité : plus fantôme. Le corps est connu un instant après)
        C_Timer.After(0.5, T.CheckGhost)
    end
end)

-- Après un /reload : la destination gardée et la file, le trajet recalculé
-- (en fantôme : d'abord le corps)
ns.On("READY", function()
    local key = CharKey()
    local savedQueue = ns.db and ns.db.travelQueue and ns.db.travelQueue[key]
    if type(savedQueue) == "table" then
        wipe(queue)
        for _, g in ipairs(savedQueue) do
            if Valid(g) then queue[#queue + 1] = Copy(g) end
        end
    end
    local saved = ns.db and ns.db.travel and ns.db.travel[key]
    C_Timer.After(RESUME_DELAY, function()
        if state or not ns.db.options.travel then return end
        local goal = Valid(saved) and Copy(saved) or nil
        if IsGhost() and ns.db.options.travelCorpse then
            stash = goal
            T.CheckGhost()
            return
        end
        if goal then
            local ok, why = Plan(goal, true, "resume")
            if not ok then
                Save(nil)
                if why == "here" and #queue > 0 then NextInQueue() end
            end
        end
    end)
end)

ns.On("OPTIONS", function()
    if state and ns.db and not ns.db.options.travel then T.Cancel(false) end
end)

---------------------------------------------------------------------------
-- /mmir trajet : où tu es, ce qui est sous le curseur, le dernier calcul
---------------------------------------------------------------------------
local function Where(p)
    if not p then return L.NONE end
    return ("%s (%d : %.0f, %.0f)"):format(Zone(p), p.cont, p.x, p.y)
end

function T.Report()
    ns.Print(L.TRAVEL_REPORT_HERE, Where(Pl.PlayerPoint()))
    if ns.MapShown() then
        local point = Pl.CursorPoint()
        ns.Print(L.TRAVEL_REPORT_CURSOR, Where(point))
    end
    ns.Print(L.TRAVEL_REPORT_FLIGHTS, G.Build().known, ("%.1f"):format(Pl.Speed()))
    if state and state.goal.corpse then ns.Print(L.TRAVEL_REPORT_CORPSE) end
    if stash then ns.Print(L.TRAVEL_REPORT_STASH, T.GoalName(stash)) end
    local shown = state and state.plan or lastPlan and lastPlan.plan
    if not shown then
        ns.Print(L.TRAVEL_NONE)
    else
        for i, leg in ipairs(shown.legs) do
            local mark = state and i == state.index and "|cffffd100>|r " or "  "
            ns.Print("%s%d. %s  |cffaaaaaa%s|r", mark, i, T.LegText(leg), R.Clock(leg.secs))
            -- (une marche précisée par la grille : ses étages, ses ascenseurs, la surface de ses bouts)
            local nav = leg.nav
            if nav then
                ns.Print("     |cff888888%s|r", L.TRAVEL_REPORT_NAV:format(nav.floors or 0, nav.lifts or 0,
                    nav.startLayer or 0, nav.goalLayer or 0, nav.alt and L.YES or L.NO))
            elseif leg.kind == "walk" and leg.refined then
                ns.Print("     |cff888888%s|r", L.TRAVEL_REPORT_NAV_NONE:format(tostring(leg.refined)))
            end
        end
        ns.Print("  %s %s", L.TRAVEL_TOTAL, R.Clock(shown.secs))
    end
    if #queue > 0 then
        ns.Print(L.TRAVEL_REPORT_QUEUE, #queue)
        for i, g in ipairs(queue) do ns.Print("  %d. %s", i, T.GoalName(g)) end
    end
    if ns.TravelShare and ns.TravelShare.Report then ns.TravelShare.Report() end
end
