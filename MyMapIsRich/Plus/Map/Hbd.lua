-- Les icônes des autres addons sur la carte : celles de Questie, TomTom, des
-- addons de récolte... En code de My Map Is Rich depuis la 0.12.0 (elles
-- venaient de Map/PadView.lua et Map/Extras.lua).
-- Chaque addon pose ses icônes sur la carte du jeu par sa copie de la
-- bibliothèque HereBeDragons ; la carte du jeu est sous notre vue, invisible.
-- Tant que la vue est là, ces bibliothèques n'y posent plus rien (la fonction
-- HandlePin de chacune, enveloppée : leur table, pas celle de Blizzard), et
-- leurs icônes viennent sur notre vue, là où elles sont dans le monde : par le
-- point de carte que l'addon a donné, sinon par la place que la bibliothèque
-- garde. Celles de Questie gardent leur info-bulle (avec les quêtes des icônes
-- voisines), et ses chemins de monstres se tracent sur la carte, dans ses
-- couleurs.
local _, root = ...
local ns = root.Plus

local H = {}
ns.Map.Hbd = H
local K = ns.Map.Coords

local QUESTIE_LIB = "HereBeDragonsQuestie-Pins-2.0"
local QUESTIE_MODULE = "Questie's HBDPins"   -- (Questie 12.8 et après : un de ses modules, pas dans LibStub)
local QUESTIE_FROM = 2.5         -- le zoom d'où viennent les icônes de Questie (un continent de quêtes, c'est trop)
local SHOW_CONTINENT = 2         -- HBD_PINS_WORLDMAP_SHOW_CONTINENT : une icône que son addon montre dès la carte d'un continent
local CLUSTER = 20               -- px autour d'une icône de Questie survolée dont l'info-bulle dit les quêtes aussi
local REACH = 12                 -- px du curseur où une icône compte comme dessous

local layer                      -- leurs icônes, sur la vue
local on = false                 -- la vue a servi : les bibliothèques ne posent plus rien sur la carte du jeu
local at = setmetatable({}, { __mode = "k" })   -- icône -> { u, v, questie, son drapeau d'affichage }
local shown = {}                 -- icône -> true : posée sur la vue

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- La copie de Questie 12.8 et après (son module HBDPins), lue dans sa liste
-- de modules : un Questie plus ancien ne reçoit pas de module vide
local function QuestieModule()
    local loader = _G.QuestieLoader
    local modules = type(loader) == "table" and rawget(loader, "_modules")
    local pins = type(modules) == "table" and rawget(modules, "HBDPins")
    if type(pins) == "table" and type(pins.worldmapProvider) == "table" then return pins end
end

-- Chaque copie de la bibliothèque chargée : nom -> bibliothèque
local function Libs()
    local out = {}
    local q = QuestieModule()
    if q then out[QUESTIE_MODULE] = q end
    if not LibStub then return out end
    if LibStub.IterateLibraries then
        for name, lib in LibStub:IterateLibraries() do
            if type(name) == "string" and type(lib) == "table"
                and (name:match("^HereBeDragons.*%-Pins%-2%.0$") or name == "HereBeDragons-Pins-ZGV") then
                out[name] = lib
            end
        end
    else
        out[QUESTIE_LIB] = LibStub(QUESTIE_LIB, true)
    end
    return out
end

-- (chaque bibliothèque enveloppée une fois : rien sur la carte du jeu tant que la vue est là)
local function Hold()
    for _, lib in pairs(Libs()) do
        local provider = lib.worldmapProvider
        if type(provider) == "table" and type(provider.HandlePin) == "function" and not provider.mmirView then
            provider.mmirView = true
            local HandlePin = provider.HandlePin
            provider.HandlePin = function(self, ...)
                if on then return end
                return HandlePin(self, ...)
            end
            -- (celles déjà sur la carte du jeu : retirées, comme la bibliothèque le fait à un changement de carte)
            local map = _G.WorldMapFrame
            if map and map:IsShown() and type(provider.RemoveAllData) == "function" then pcall(provider.RemoveAllData, provider) end
        end
    end
end

-- La place d'une icône dans le monde
local function IconWorld(icon, data)
    local uiMapID = data.uiMapID
    if uiMapID and icon.UiMapID == uiMapID and type(icon.x) == "number" and type(icon.y) == "number" then
        local u, v = K.ToWorld(uiMapID, icon.x / 100, icon.y / 100)
        if u then return u, v end
    end
    -- (les x, y de la bibliothèque sont les Y, X du jeu)
    if type(data.instanceID) == "number" and type(data.x) == "number" and type(data.y) == "number" then
        return K.FromYards(data.instanceID, data.y, data.x)
    end
end

-- Quelles icônes les addons ont sur la carte maintenant, et où
function H.Scan()
    wipe(at)
    for name, lib in pairs(Libs()) do
        local pins = lib.worldmapPins
        local questie = name == QUESTIE_LIB or name == QUESTIE_MODULE
        if type(pins) == "table" then
            for icon, data in pairs(pins) do
                if type(icon) == "table" and type(data) == "table" and icon.SetPoint and not (questie and icon.type == "line") then
                    local ok, wu, wv = pcall(IconWorld, icon, data)
                    if ok and wu and wv then at[icon] = { wu, wv, questie, tonumber(data.worldMapShowFlag) or 0 } end
                end
            end
        end
    end
end

-- Une icône de Questie (sur la vue) : son info-bulle, celle de Questie, avec
-- les quêtes des icônes voisines sur la vue (là où il n'y en a plus sur la
-- carte du jeu). tooltip : celle de la manette (Questie l'utilise pour elle)
function H.Tip(icon, tooltip)
    local loader = _G.QuestieLoader
    local ok, tips = pcall(function() return loader:ImportModule("MapIconTooltip") end)
    if not ok or type(tips) ~= "table" or type(tips.ShowOnTooltip) ~= "function" or not tooltip then return end
    local near = {}
    local cx, cy = icon:GetCenter()
    if cx then
        for other in pairs(shown) do
            local ox, oy
            if at[other] and at[other][3] then ox, oy = other:GetCenter() end
            if ox and (ox - cx) ^ 2 + (oy - cy) ^ 2 <= CLUSTER ^ 2 then near[#near + 1] = other end
        end
    end
    tooltip:Hide()                -- (une vide déjà là la retiendrait : sa garde de 0,05 s)
    pcall(tips.ShowOnTooltip, icon, tooltip, nil, near)
    if tooltip ~= GameTooltip and tooltip:IsShown() and tooltip.SetAnchorType then
        pcall(tooltip.SetAnchorType, tooltip, "ANCHOR_RIGHT")
    end
end

-- Les icônes en vue posées dessus (à leur taille : la vue n'est pas mise à
-- l'échelle), les autres cachées. Celles de Questie dès QUESTIE_FROM ; celles
-- d'un autre addon aussi, ou de plus loin s'il le demande (le point de TomTom).
-- u, v, zoom : la vue ; px : px de la vue par unité de l'art ; hw, hh : sa moitié (px)
function H.Place(u, v, zoom, W, Hh, px, hw, hh)
    if not layer then return end
    local seen = {}
    local profile = _G.Questie and Questie.db and Questie.db.profile
    local questieOn = zoom >= QUESTIE_FROM and not (profile and profile.enabled == false)
    hw, hh = hw + 16, hh + 16
    for icon, p in pairs(at) do
        local x, y = (p[1] - u) * W * px, (p[2] - v) * Hh * px
        local show
        if p[3] then show = questieOn else show = zoom >= QUESTIE_FROM or p[4] >= SHOW_CONTINENT end
        if show and x > -hw and x < hw and y > -hh and y < hh then
            if icon:GetParent() ~= layer then icon:SetParent(layer) end
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", layer, "CENTER", x, -y)
            icon:Show()
            seen[icon] = true
            if p[3] and not icon.mmirTip then   -- (la souris sur une de Questie : son info-bulle, d'ici)
                icon.mmirTip = true
                icon:HookScript("OnEnter", function(self) if shown[self] then H.Tip(self, GameTooltip) end end)
            end
        end
    end
    for icon in pairs(shown) do
        if not seen[icon] and icon:GetParent() == layer then icon:Hide() end
    end
    shown = seen
end

-- L'icône d'un addon la plus proche du curseur (px de l'écran), à portée
function H.At(x, y)
    local best, bestD = nil, REACH * REACH
    for icon in pairs(shown) do
        if icon:IsVisible() then
            local cx, cy = icon:GetCenter()
            if cx then
                local es = icon:GetEffectiveScale()
                local dx, dy = cx * es - x, cy * es - y
                local d = dx * dx + dy * dy
                if d < bestD then best, bestD = icon, d end
            end
        end
    end
    return best
end

-- Une icône de Questie posée sur la vue
function H.IsQuestie(icon) return shown[icon] and at[icon] and at[icon][3] or false end
function H.Shown(icon) return shown[icon] and true or false end

---------------------------------------------------------------------------
-- Les chemins des monstres de Questie (son WaypointMap, depuis Questie 12.2) :
-- Questie les trace lui-même sur la carte du jeu de leur zone ; ici, chacun
-- par le rectangle de sa zone, au-dessus de l'art, dans ses couleurs, comme
-- Questie les choisit (une route une fois : sa copie en valeur, sinon la plus
-- visible), redessinés quand Questie redessine les siens
---------------------------------------------------------------------------
local QP = { width = 2.5, zones = {}, spare = {}, view = {}, movedAt = -10, dirty = true, at = 0 }
local MOST_ZONES = 4             -- tracés seulement assez près : pas plus de zones que ça en vue
local EVERY = 0.5                -- secondes entre deux tracés, au plus
local SETTLE = 0.2               -- secondes de vue immobile avant de revoir les zones proches
local REFRESH = 5                -- ... et tout retracé, la vue immobile

local function Waypoints()
    local Q = _G.QuestieLoader
    if type(Q) ~= "table" or type(Q.ImportModule) ~= "function" then return end
    local ok, W = pcall(Q.ImportModule, Q, "QuestieWaypoints")
    if not ok or type(W) ~= "table" or type(W.paths) ~= "table" or type(W.WorldMapAlpha) ~= "function" then return end
    return W
end

local function SeenZone(uiMapID)
    QP.seenZones = QP.seenZones or {}
    if uiMapID and not QP.seenZones[uiMapID] then
        QP.seenZones[uiMapID] = true
        QP.moved = true
    end
end

-- (les zones près de la vue : un chemin n'est tracé que dans l'une d'elles)
local function ZonesNear(u, v, hu, hv)
    local zones, n = QP.zones, 0
    wipe(zones)
    local l0, r0, t0, b0 = u - hu * 1.2, u + hu * 1.2, v - hv * 1.2, v + hv * 1.2
    for uiMapID in pairs(QP.seenZones or {}) do
        local l, r, t, b = K.Rect(uiMapID)
        if l and r > l0 and l < r0 and b > t0 and t < b0 then
            zones[uiMapID] = true
            n = n + 1
        end
    end
    return n
end

local function DrawPaths()
    local W = Waypoints()
    local P = ns.Map.Pins
    if not (W or QP.lines) or not P.Ready() then return end
    QP.set = QP.set or P.Set("questiepaths", 0, 1)
    P.Clear(QP.set)
    QP.dirty, QP.at = false, GetTime()
    if not (on and QP.near) then return end
    local zones = QP.zones
    if W then
        local routes = {}
        for path in pairs(W.paths) do
            if path.uiMapId and zones[path.uiMapId] and type(path.points) == "table" then
                local okA, alpha = pcall(W.WorldMapAlpha, path)
                if okA and alpha then
                    local rank = alpha + ((W.IsHighlighted and W.IsHighlighted(path)) and 2 or 0)
                    local key = path.route or path
                    if not routes[key] or rank > routes[key].rank then routes[key] = { path = path, alpha = alpha, rank = rank } end
                end
            end
        end
        for _, r in pairs(routes) do
            local path = r.path
            local okC, c = pcall(W.Color, path)
            c = okC and type(c) == "table" and c or { 1, 0.8, 0, 1 }
            local pts = {}
            for _, p in ipairs(path.points) do
                if type(p.x) == "number" and type(p.y) == "number" then
                    local pu, pv = K.ToWorld(path.uiMapId, p.x / 100, p.y / 100)
                    if pu then pts[#pts + 1], pts[#pts + 2] = pu, pv end
                end
            end
            if #pts >= 4 then P.Path(QP.set, pts, QP.width, c[1], c[2], c[3], (c[4] or 1) * r.alpha) end
        end
        return
    end
    for f, d in pairs(QP.lines) do
        local icon = f.iconFrame
        if d.map and zones[d.map] and icon and not f.hidden and not icon.hidden then
            local c = type(d[5]) == "table" and d[5] or { 1, 0.8, 0, 1 }
            local u1, v1 = K.ToWorld(d.map, d[1] / 100, d[2] / 100)
            local u2, v2 = K.ToWorld(d.map, d[3] / 100, d[4] / 100)
            if u1 and u2 then P.Line(QP.set, u1, v1, u2, v2, QP.width, c[1], c[2], c[3], c[4] or 1) end
        end
    end
end

-- Questie d'avant 12.2 trace chaque bout de chemin comme un cadre à lui
-- (QuestieFramePool:CreateLine) : ses bouts sont gardés ici à sa création
local function HookOldLines(Q)
    local ok, FP = pcall(Q.ImportModule, Q, "QuestieFramePool")
    if not ok or type(FP) ~= "table" or type(FP.CreateLine) ~= "function" then return end
    local okZ, zdb = pcall(Q.ImportModule, Q, "ZoneDB")
    zdb = okZ and type(zdb) == "table" and type(zdb.GetUiMapIdByAreaId) == "function" and zdb or nil
    if not zdb then return end
    QP.lines = setmetatable({}, { __mode = "k" })
    -- (la fonction de Questie enveloppée, dans sa propre table : rien du jeu)
    local create = FP.CreateLine
    FP.CreateLine = function(self, iconFrame, sx, sy, ex, ey, width, color, areaId, ...)
        local f = create(self, iconFrame, sx, sy, ex, ey, width, color, areaId, ...)
        if type(f) == "table" and type(sx) == "number" and type(ey) == "number" then
            local area = areaId or (iconFrame and iconFrame.AreaID)
            local okM, uiMapID = pcall(zdb.GetUiMapIdByAreaId, zdb, area)
            local d = { sx, sy, ex, ey, color, map = okM and K.Rect(uiMapID or 0) and uiMapID or nil }
            QP.lines[f] = d
            SeenZone(d.map)
            if d.map and QP.zones[d.map] then QP.dirty = true end
        end
        return f
    end
    return true
end

local function HookPaths()
    if QP.hooked then return end
    local Q = _G.QuestieLoader
    if type(Q) ~= "table" or type(Q.ImportModule) ~= "function" then return end
    if Waypoints() then
        local ok, Mp = pcall(Q.ImportModule, Q, "WaypointMap")
        if not ok or type(Mp) ~= "table" or type(Mp.Invalidate) ~= "function" then return end
        QP.hooked = true
        hooksecurefunc(Mp, "Invalidate", function() QP.dirty = true end)
    elseif HookOldLines(Q) then
        QP.hooked = true
    end
end

-- (les zones près de la vue maintenant : un autre ensemble, ou près / loin, retrace)
local function NearNow()
    local w = QP.view
    if not w[1] then return end
    local W = Waypoints()
    if W then
        for path in pairs(W.paths) do SeenZone(path.uiMapId) end
    end
    QP.moved = false
    local was = QP.zones
    QP.zones, QP.spare = QP.spare, was
    local n = ZonesNear(w[1], w[2], w[3], w[4])
    local near = n > 0 and n <= MOST_ZONES
    local same = near == QP.near and n == (QP.count or -1)
    if same and near then
        for id in pairs(QP.zones) do
            if not was[id] then same = false break end
        end
    end
    QP.count = n
    if not same then QP.near, QP.dirty = near, true end
end

-- (chaque déplacement ou zoom note seulement la vue : les zones proches se
-- revoient une fois la carte arrêtée)
ns.Map.Pins.OnView(function(u, v, hu, hv)
    if not QP.hooked then return end
    local w = QP.view
    w[1], w[2], w[3], w[4] = u, v, hu, hv
    QP.moved, QP.movedAt = true, GetTime()
end)

local tick = CreateFrame("Frame")
tick:Hide()
tick:SetScript("OnUpdate", function()
    local now = GetTime()
    if now - QP.movedAt < SETTLE or ns.Map.View.Zooming() then return end
    if QP.moved then pcall(NearNow) end
    if now - QP.at < EVERY then return end
    if QP.dirty or now - QP.at > REFRESH then
        local ok, err = pcall(DrawPaths)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end)

---------------------------------------------------------------------------
-- Pour la vue (Map/View.lua)
---------------------------------------------------------------------------
-- Le calque de leurs icônes, sur la vue, à ce niveau
function H.Setup(view, level)
    if layer then return end
    layer = CreateFrame("Frame", nil, view)
    layer:SetAllPoints(view)
    layer:SetFrameLevel(level)
end

-- La vue montrée : les bibliothèques tenues, leurs icônes lues, les chemins tracés
function H.Show()
    on = true
    Hold()
    H.Scan()
    HookPaths()
    if QP.hooked then
        QP.dirty = true
        tick:Show()
    end
end

-- La vue cachée : leurs icônes cachées avec elle. (Les bibliothèques restent
-- tenues : la carte du jeu, sous la vue, n'en aura jamais besoin.)
function H.Hide()
    tick:Hide()
    for icon in pairs(shown) do
        if icon:GetParent() == layer then icon:Hide() end
    end
    wipe(shown)
end
