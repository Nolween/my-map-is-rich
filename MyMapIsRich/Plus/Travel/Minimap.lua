-- L'itinéraire sur la minimap : des points le long du trajet qui reste, à
-- partir du joueur (la marche le long des routes, les vols, les bateaux), et
-- la destination, posée au bord quand elle est hors de vue.
-- Le placement est celui de HereBeDragons (Questie, GatherMate...) : le
-- rayon de vue de la minimap en yards (C_Minimap.GetViewRadius, sinon la
-- table de son zoom), la rotation quand la minimap tourne (rotateMinimap,
-- GetPlayerFacing) et sa forme (GetMinimapShape : ronde ou carrée).
-- Rien n'est écrit dans la minimap du jeu : nos points sont sur un cadre à
-- nous, posé par-dessus (même place, même strate, un peu plus haut).
local _, root = ...
local ns = root.Plus
local Pl = ns.TravelPlanner
local R = ns.TravelRoute

local MM = {}
ns.TravelMinimap = MM

local EVERY = 0.05           -- s entre deux mises à jour
local MAX_DOTS = 160
local DOT = 5                -- px
local GOAL_SIZE = 16         -- px
local EDGE = 0.92            -- (les points s'arrêtent un peu avant le bord)
local SPACING = 1 / 11       -- l'écart entre deux points, en part du rayon de vue
local COLORS = {
    walk = { 1, 0.82, 0.25 },
    flight = { 0.95, 0.78, 0.35 },
    boat = { 0.35, 0.62, 1 },
    zeppelin = { 1, 0.38, 0.32 },
    portal = { 0.75, 0.45, 1 },
    tram = { 0.65, 0.72, 0.8 },
    hearth = { 0.45, 0.85, 1 },
}
-- (le diamètre de la vue, en yards, à chaque zoom : HereBeDragons)
local VIEW = {
    outdoor = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
    indoor = { [0] = 300, 240, 180, 120, 80, 50 },
}

local frame, goal, goalShadow
local dots, shadows = {}, {}

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Look(tex, atlas, texture)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        tex:SetAtlas(atlas)
    else
        tex:SetTexture(texture)
    end
end

local function Build()
    local mm = _G.Minimap
    if frame or not mm then return frame end
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetAllPoints(mm)
    frame:EnableMouse(false)
    frame:Hide()
    goalShadow = frame:CreateTexture(nil, "OVERLAY", nil, 6)
    goal = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    Look(goalShadow, "Waypoint-MapPin-Untracked", "Interface\\Minimap\\Ping\\ping5")
    Look(goal, "Waypoint-MapPin-Untracked", "Interface\\Minimap\\Ping\\ping5")
    goalShadow:SetVertexColor(0, 0, 0, 0.7)
    goal:SetVertexColor(1, 0.85, 0.3)
    return frame
end

local function Dot(i)
    local d = dots[i]
    if not d then
        shadows[i] = frame:CreateTexture(nil, "OVERLAY", nil, 2)
        d = frame:CreateTexture(nil, "OVERLAY", nil, 3)
        Look(shadows[i], "WhiteCircle-RaidBlips", "Interface\\Buttons\\WHITE8X8")
        Look(d, "WhiteCircle-RaidBlips", "Interface\\Buttons\\WHITE8X8")
        shadows[i]:SetVertexColor(0, 0, 0, 0.75)
        shadows[i]:SetSize(DOT + 2, DOT + 2)
        d:SetSize(DOT, DOT)
        dots[i] = d
    end
    return d, shadows[i]
end

local function HideFrom(n)
    for i = n, #dots do
        dots[i]:Hide()
        shadows[i]:Hide()
    end
end

-- Le rayon de vue de la minimap, en yards
local function ViewRadius(mm)
    if C_Minimap and C_Minimap.GetViewRadius then
        local ok, r = pcall(C_Minimap.GetViewRadius)
        r = ok and Plain(r) or nil
        if type(r) == "number" and r > 0 then return r end
    end
    local zoom = mm:GetZoom() or 0
    local outdoor = tonumber(GetCVar("minimapZoom")) == zoom
    local list = outdoor and VIEW.outdoor or VIEW.indoor
    return (list[zoom] or VIEW.outdoor[0]) / 2
end

-- La vue de la minimap en ce moment (nil : cachée, ou ta place inconnue) :
-- here (ta place), radius (yards), scale (px par yard), limit (un peu avant
-- le bord), square, View(x, y) (un point du monde vu sur la minimap, en yards
-- vers l'est et le nord) et Inside(sx, sy). Aussi pour les quêtes sur la
-- minimap (Layers/QuestMinimap.lua). on : le cadre où l'on dessine (posé sur la
-- minimap : ses px à lui)
function MM.Viewer(on)
    local mm = _G.Minimap
    if not (mm and mm:IsVisible()) then return end
    local here = Pl.PlayerPoint()
    local rotate = GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing and Plain(GetPlayerFacing()) or nil
    if not here or (rotate and not facing) then return end
    local radius = ViewRadius(mm)
    local half = (on or mm):GetWidth() / 2
    if not (radius and radius > 0 and half > 0) then return end
    local limit = radius * EDGE
    local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
    local sin, cos = 0, 1
    if facing then sin, cos = math.sin(facing), math.cos(facing) end
    local px, py = here.x, here.y
    local v = { here = here, radius = radius, scale = half / radius, limit = limit, square = square }
    function v.View(x, y)
        local e, n = py - y, x - px
        if facing then return e * cos + n * sin, n * cos - e * sin end
        return e, n
    end
    function v.Inside(sx, sy)
        if square then return math.abs(sx) <= limit and math.abs(sy) <= limit end
        return sx * sx + sy * sy <= limit * limit
    end
    return v
end

local function Update()
    local mm = _G.Minimap
    local T = ns.Travel
    local plan, index, proj, target
    if T and ns.db and ns.db.options.travel and ns.db.options.travelMinimap then
        plan, index, proj, target = T.Live()
    end
    local viewer = plan and Build() and MM.Viewer(frame)
    if not viewer then
        if frame then frame:Hide() end
        return
    end
    frame:SetFrameStrata(mm:GetFrameStrata())
    frame:SetFrameLevel(mm:GetFrameLevel() + 8)
    frame:Show()
    local here, radius, scale, limit, square = viewer.here, viewer.radius, viewer.scale, viewer.limit, viewer.square
    local px, py, cont = here.x, here.y, here.cont
    local View, Inside = viewer.View, viewer.Inside

    local count = 0
    local step = radius * SPACING
    local far = radius * 1.5
    -- (des points tous les `step` yards le long d'un tracé)
    local function Trail(pts, first, color)
        local carry = 0
        for i = first, #pts - 1 do
            local a, b = pts[i], pts[i + 1]
            local dx, dy = b.x - a.x, b.y - a.y
            local len = math.sqrt(dx * dx + dy * dy)
            local ax, ay = a.x - px, a.y - py
            local bx, by = b.x - px, b.y - py
            -- (un segment loin de la vue : rien à poser)
            if math.min(ax * ax + ay * ay, bx * bx + by * by) > (far + len) * (far + len) then
                carry = 0
            else
                local at = carry
                while at <= len and count < MAX_DOTS do
                    local f = len > 0 and at / len or 0
                    local sx, sy = View(a.x + dx * f, a.y + dy * f)
                    if Inside(sx, sy) then
                        count = count + 1
                        local d, s = Dot(count)
                        d:ClearAllPoints()
                        d:SetPoint("CENTER", frame, "CENTER", sx * scale, sy * scale)
                        s:ClearAllPoints()
                        s:SetPoint("CENTER", d, "CENTER")
                        d:SetVertexColor(color[1], color[2], color[3], 1)
                        d:Show()
                        s:Show()
                    end
                    at = at + step
                end
                carry = at - len
            end
        end
    end

    for i = index, #plan.legs do
        local leg = plan.legs[i]
        local geom = R.Geometry(leg)
        -- (un portail, un tram : pas de chemin au sol entre ses deux bouts)
        if geom and leg.from.cont == cont and leg.kind ~= "portal" and leg.kind ~= "tram"
            and leg.kind ~= "hearth" then
            local color = COLORS[leg.kind] or COLORS.walk
            if i == index and proj and leg.kind == "walk" and proj.j < #geom then
                -- (l'étape en cours : du joueur au point du tracé le plus proche, puis la suite)
                local pts = { { x = px, y = py }, { x = proj.x, y = proj.y } }
                for k = proj.j + 1, #geom do pts[#pts + 1] = geom[k] end
                Trail(pts, 1, color)
            else
                Trail(geom, 1, color)
            end
        end
    end
    HideFrom(count + 1)

    -- (la destination : à sa place, ou au bord dans sa direction)
    if target and target.cont == cont then
        local sx, sy = View(target.x, target.y)
        local size = GOAL_SIZE
        if not Inside(sx, sy) then
            local k = square and limit / math.max(math.abs(sx), math.abs(sy))
                or limit / math.sqrt(sx * sx + sy * sy)
            sx, sy, size = sx * k, sy * k, GOAL_SIZE * 0.8
        end
        goal:ClearAllPoints()
        goal:SetPoint("CENTER", frame, "CENTER", sx * scale, sy * scale)
        goal:SetSize(size, size)
        goalShadow:ClearAllPoints()
        goalShadow:SetPoint("CENTER", goal, "CENTER", 0, -1)
        goalShadow:SetSize(size + 3, size + 3)
        goal:Show()
        goalShadow:Show()
    else
        goal:Hide()
        goalShadow:Hide()
    end
end

local driver = CreateFrame("Frame")
driver:Hide()
local wait = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = EVERY
    local ok, err = pcall(Update)
    if not ok then
        driver:Hide()
        if frame then frame:Hide() end
        if geterrorhandler then geterrorhandler()(err) end
    end
end)

-- (actif pendant un itinéraire seulement)
local function Refresh()
    local on = ns.Travel and ns.Travel.Active() and ns.db and ns.db.options.travelMinimap
    driver:SetShown(on and true or false)
    if not on and frame then frame:Hide() end
end
ns.On("TRAVEL", Refresh)
ns.On("OPTIONS", Refresh)
