-- Le tracé d'un itinéraire sur la carte : un jeu d'icônes à nous
-- (ns.Map.Pins ; jamais la carte de Blizzard), avec une ligne par étape (un bord sombre et un cœur coloré,
-- comme les vols de Flights.lua), un point à chaque étape et la destination
-- avec sa légende (le temps, le nombre d'étapes).
--   marche : blanc, le long des routes suivies · vol : doré, le long des vrais trajets des vols ·
--   bateau : bleu · zeppelin : rouge (en ligne droite de quai à quai) ·
--   portail : violet · tram : gris acier (en ligne droite d'un bout à l'autre)
-- Le tracé attend que la carte assemblée existe (ns.Map.Pins.Ready) : sinon il est
-- fait à la prochaine ouverture de la carte.
local _, root = ...
local ns = root.Plus
local L = ns.L
local Pl = ns.TravelPlanner

local R = {}
ns.TravelRoute = R

local COLORS = {
    walk = { 0.95, 0.95, 0.95 },
    flight = { 0.95, 0.78, 0.35 },
    boat = { 0.30, 0.55, 0.95 },
    zeppelin = { 0.90, 0.25, 0.20 },
    portal = { 0.70, 0.40, 0.95 },
    tram = { 0.60, 0.68, 0.78 },
    teleport = { 0.45, 0.85, 1 },
}
R.COLORS = COLORS            -- (le panneau de trajet : UI/RouteHud.lua)
local DONE_ALPHA = 0.35      -- une étape déjà faite
local STOP = { atlas = "WhiteCircle-RaidBlips", texture = "Interface\\Buttons\\WHITE8X8", size = 9 }
local GOAL = { atlas = "Waypoint-MapPin-Untracked", texture = "Interface\\Minimap\\Ping\\ping5", size = 26 }

local set
local wanted                 -- { plan, index } : à dessiner
local drawn = false

-- Une durée : « 3:20 », « 1 h 05 »
function R.Clock(secs)
    secs = math.max(0, math.floor((secs or 0) + 0.5))
    if secs >= 3600 then
        return ("%d h %02d"):format(math.floor(secs / 3600), math.floor(secs % 3600 / 60))
    end
    return ("%d:%02d"):format(math.floor(secs / 60), secs % 60)
end

local function Set()
    if set or not ns.Map.Pins.Ready() then return set end
    -- (au niveau des vols tracés sur la carte, sous ses icônes)
    set = ns.Map.Pins.Set("omgp_journey", 1, 1)
    return set
end

local function Line(u1, v1, u2, v2, color, alpha)
    local r, g, b = color[1], color[2], color[3]
    local edge = ns.Map.Pins.Line(set, u1, v1, u2, v2, 3.4, 0.12, 0.08, 0.03, alpha * 0.8)
    local core = ns.Map.Pins.Line(set, u1, v1, u2, v2, 1.8, r, g, b, alpha)
    if edge then edge:SetDrawLayer("ARTWORK", 0) end
    if core then core:SetDrawLayer("ARTWORK", 1) end
end

-- Le tracé d'une étape en yards de son continent : { {x, y}, ... } (une
-- marche : celui des routes suivies ; un vol : ses vrais trajets ; un bateau
-- d'un quai à l'autre du même continent), ou nil (une traversée de la mer)
function R.Geometry(leg)
    if leg.geom ~= nil then return leg.geom or nil end
    local geom = false
    if leg.kind == "walk" and leg.points and #leg.points >= 2 then
        geom = leg.points
    elseif leg.kind == "flight" and leg.paths then
        geom = {}
        for _, path in ipairs(leg.paths) do
            local p = path[5]
            if type(p) == "table" then
                for k = 1, #p - 1, 2 do
                    local last = geom[#geom]
                    if not (last and last.x == p[k] and last.y == p[k + 1]) then
                        geom[#geom + 1] = { x = p[k], y = p[k + 1] }
                    end
                end
            end
        end
        if #geom < 2 then geom = false end
    end
    if not geom and leg.from.cont == leg.to.cont then
        geom = { { x = leg.from.x, y = leg.from.y }, { x = leg.to.x, y = leg.to.y } }
    end
    leg.geom = geom
    return geom or nil
end

local function Polyline(cont, pts, color, alpha)
    local FromYards = ns.Map.Coords.FromYards
    local pu, pv = FromYards(cont, pts[1].x, pts[1].y)
    for i = 2, #pts do
        local u, v = FromYards(cont, pts[i].x, pts[i].y)
        if pu and u then Line(pu, pv, u, v, color, alpha) end
        pu, pv = u, v
    end
end

-- Une étape : ses lignes. `live` (l'étape en cours, une marche) : { j, x, y,
-- px, py } : le tracé part du joueur (px, py), rejoint le point du tracé le
-- plus proche de lui (x, y, sur le segment j), et la partie faite n'est plus
-- dessinée
local function DrawLeg(leg, alpha, live)
    -- (une téléportation : pas de chemin, on y est en un instant)
    if leg.kind == "teleport" then return end
    local color = COLORS[leg.kind] or COLORS.walk
    local geom = R.Geometry(leg)
    if not geom then
        -- (une traversée de la mer, sur la carte assemblée)
        local u1, v1 = Pl.UV(leg.from)
        local u2, v2 = Pl.UV(leg.to)
        if u1 and u2 then Line(u1, v1, u2, v2, color, alpha) end
        return
    end
    if live and live.j and live.j < #geom then
        local pts = { { x = live.px, y = live.py }, { x = live.x, y = live.y } }
        for i = live.j + 1, #geom do pts[#pts + 1] = geom[i] end
        geom = pts
    end
    Polyline(leg.from.cont, geom, color, alpha)
end

local function GoalTooltip(pin)
    local plan = pin.plan
    if not plan then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.TRAVEL_TOOLTIP_TITLE, 1, 0.82, 0)
    for i, leg in ipairs(plan.legs) do
        local r, g, b = 1, 1, 1
        if i < (pin.index or 1) then r, g, b = 0.5, 0.5, 0.5 end
        GameTooltip:AddDoubleLine(("%d. %s"):format(i, ns.Travel.LegText(leg)), R.Clock(leg.secs), r, g, b, r, g, b)
    end
    GameTooltip:AddDoubleLine(L.TRAVEL_TOTAL, R.Clock(plan.secs), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddLine(L.TRAVEL_TOOLTIP_CANCEL, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function Draw()
    if not wanted or not Set() then return end
    local Pins = ns.Map.Pins
    Pins.Clear(set)
    local plan, index = wanted.plan, wanted.index or 1
    for i, leg in ipairs(plan.legs) do
        DrawLeg(leg, i < index and DONE_ALPHA or 0.95, i == index and wanted.live or nil)
    end
    -- (un point à chaque changement d'étape)
    for i = 1, #plan.legs - 1 do
        local u, v = Pl.UV(plan.legs[i].to)
        local pin = u and Pins.Add(set, u, v, STOP)
        if pin then
            local c = COLORS[plan.legs[i + 1].kind] or COLORS.walk
            pin.Icon:SetVertexColor(c[1], c[2], c[3], i < index and DONE_ALPHA or 1)
            pin:EnableMouse(false)
            -- (les icônes sont réutilisées : la légende de la destination d'avant)
            if pin.caption then pin.caption:Hide() end
            pin.plan = nil
        end
    end
    local goal = plan.legs[#plan.legs].to
    local gu, gv = Pl.UV(goal)
    local pin = gu and Pins.Add(set, gu, gv, GOAL)
    if pin then
        pin.Icon:SetVertexColor(1, 0.85, 0.3)
        pin.plan, pin.index = plan, index
        pin:SetScript("OnEnter", GoalTooltip)
        pin:SetScript("OnLeave", GameTooltip_Hide)
        if not pin.caption then
            pin.caption = pin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            pin.caption:SetPoint("LEFT", pin, "CENTER", 16, 0)
            pin.caption:SetShadowOffset(1, -1)
        end
        local stops = #plan.legs
        pin.caption:SetText(("|cffffffff%s|r  |cffaaaaaa(%s)|r"):format(R.Clock(wanted.remaining or plan.secs),
            stops == 1 and L.TRAVEL_ONE_STEP or L.TRAVEL_STEPS:format(stops)))
        pin.caption:Show()
    end
    drawn = true
end

-- Le tracé d'un itinéraire, l'étape `index` en cours (celles d'avant
-- pâlies) ; `live` : où en est le joueur sur une marche (DrawLeg) ;
-- `remaining` : le temps qu'il reste (sinon celui de tout l'itinéraire)
function R.Show(plan, index, live, remaining)
    wanted = { plan = plan, index = index, live = live, remaining = remaining }
    Draw()
end

-- Le tracé est-il dessiné (sinon, il le sera à l'ouverture de la carte) ?
function R.Drawn() return drawn end

function R.Clear()
    wanted = nil
    if set and drawn then
        ns.Map.Pins.Clear(set)
    end
    drawn = false
end

-- (un trajet repris après un /reload : la carte assemblée d'OpenMap n'existe
-- qu'à sa première ouverture, peut-être juste après nous)
local function DrawLater()
    if wanted and not drawn then Draw() end
end
ns.On("MAP_SHOW", function()
    DrawLater()
    C_Timer.After(0.3, DrawLater)
end)
ns.On("CONTEXT", DrawLater)
