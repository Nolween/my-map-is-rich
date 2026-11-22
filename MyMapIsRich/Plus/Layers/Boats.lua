-- Les routes des bateaux et des zeppelins : des points le long du trajet que
-- chacun suit vraiment (MapPlaces.sailings, tiré des tables du jeu), comme
-- les routes des écrans de chargement. En code de My Map Is Rich depuis la
-- 0.8.0 (elles venaient de Map/Routes.lua, d'OpenMap).
--   l'écart  les points sont à pas réguliers sur tout le trajet (une
--            traversée entre les cartes des deux continents est un arc) ;
--            des pas plus fins viennent entre eux à mesure qu'on zoome, pour
--            rester réguliers à l'écran ;
--   survol   une route reste discrète jusqu'à ce que le curseur (la souris
--            ou celui de la manette) en approche : elle s'éclaire et dit
--            d'où à où elle va.
-- Bleu : l'Alliance ; rouge : la Horde ; neutre (les ports gobelins) : rouge.
-- Le calque « routes » et les réglages « boats » et « zeppelins » restent
-- ceux de la carte d'OpenMap tant que les quais s'en servent (Map/Stitch.lua).
local _, root = ...
local ns = root.Plus
local L = ns.L

local K = ns.Map.Coords
local Pins = ns.Map.Pins
local Settings = ns.Map.Settings

local DOT = { atlas = "WhiteCircle-RaidBlips", texture = "Interface\\Buttons\\WHITE8X8" }
local LEVELS = 4                -- densités : chacune divise le pas de la précédente par deux
local STEP = 0.016              -- le pas le plus large (unités du monde)
local SHOW_PX = { 10, 16 }      -- un niveau plus fin apparaît quand son pas passe de / à ces px
local SIZE, QUIET, LIT = 5, 0.45, 0.75   -- taille d'un point (px), transparence au repos, survolée
local LIT_FADE = { 3, 12 }      -- le zoom sur lequel l'éclat du survol s'efface (de près, il est à peine là)
local EASE = 8                  -- la vitesse à laquelle une route va vers sa transparence (par seconde)
local HOVER_PX = 8              -- à combien de px le curseur doit venir
local BLUE, RED = { 0.20, 0.42, 0.88 }, { 0.72, 0.13, 0.10 }
-- (les ports gobelins : Baie-du-Butin et Cabestan ont un maître de vol de
-- chaque faction ; tous les autres bateaux sont ceux de l'Alliance)
local NEUTRAL = { ["Booty Bay - Ratchet"] = true, ["Steamwheedle Port - Powderfuse Port"] = true }
local KINDS = { boat = true, zeppelin = true }
local KIND_OPTION = { boat = "boats", zeppelin = "zeppelins" }

local routes = {}               -- { frame, levels, way = { { u, v } }, kind, faction, ends }
local set, lit

local function KindOn(route)
    local key = KIND_OPTION[route.kind]
    return not key or Settings.Get(key) ~= false
end

local function Smooth(x, r)
    local t = math.max(0, math.min(1, (x - r[1]) / (r[2] - r[1])))
    return t * t * (3 - 2 * t)
end

local function Faction(sail)
    if sail[1] == "zeppelin" then return "Horde" end
    if NEUTRAL[sail[2]] then return "Neutral" end
    return "Alliance"
end

-- Tout le trajet en points du monde, une traversée entre deux morceaux en arc ;
-- rien si un morceau ne se place pas (une demi-route s'arrêterait en mer)
local function Way(sail)
    local way = {}
    for _, piece in ipairs(sail[3]) do
        local cont, pts = piece[1], piece[2]
        local first = #way + 1
        for k = 1, #pts - 1, 2 do
            local u, v = K.FromYards(cont, pts[k], pts[k + 1])
            if u then way[#way + 1] = { u, v } end
        end
        if #way < first then return {} end
        if first > 1 and way[first] then
            local p0, p2 = way[first - 1], way[first]
            local du, dv = p2[1] - p0[1], p2[2] - p0[2]
            local len = math.sqrt(du * du + (dv * 1.5) ^ 2)
            if len > 0 then
                local side = ((p0[2] + p2[2]) / 2 < 0.5) and -1 or 1
                local nu, nv = -dv * 1.5 / len, du / len / 1.5
                if nv * side < 0 then nu, nv = -nu, -nv end
                local cu, cv = (p0[1] + p2[1]) / 2 + nu * 0.12 * len, (p0[2] + p2[2]) / 2 + nv * 0.12 * len
                for k = 23, 1, -1 do
                    local t = k / 24
                    table.insert(way, first, { (1 - t) ^ 2 * p0[1] + 2 * (1 - t) * t * cu + t * t * p2[1],
                        (1 - t) ^ 2 * p0[2] + 2 * (1 - t) * t * cv + t * t * p2[2] })
                end
            end
        end
    end
    return way
end

-- Le niveau (1 : le plus large) d'un point à l'indice i du pas le plus fin
local function LevelOf(i)
    local level = LEVELS
    while level > 1 and i % 2 == 0 do
        i, level = i / 2, level - 1
    end
    return level
end

-- Tous les points de toutes les routes ; là où deux routes de même sorte
-- partagent l'eau (au large de Menethil, de Grom'gol), la seconde saute les
-- points que la première y a déjà mis, pour garder l'écart régulier
local function BuildDots(s)
    local P = ns.Map.Data.Places() or {}
    local fine = STEP / 2 ^ (LEVELS - 1)
    local takenBy, taken = {}, nil
    local function Taken(u, v, level)
        local cx, cy = math.floor(u / STEP), math.floor(v * 1.5 / STEP)
        local reach = (STEP / 2 ^ (level - 1)) * 0.6
        for x = cx - 1, cx + 1 do
            for y = cy - 1, cy + 1 do
                for _, d in ipairs(taken[x .. ":" .. y] or {}) do
                    if d[3] <= level and math.sqrt((d[1] - u) ^ 2 + ((d[2] - v) * 1.5) ^ 2) < reach then return true end
                end
            end
        end
        local key = cx .. ":" .. cy
        taken[key] = taken[key] or {}
        table.insert(taken[key], { u, v, level })
    end
    for _, sail in ipairs(P.sailings or {}) do
        local way = KINDS[sail[1]] and Way(sail) or {}
        if #way > 1 then
            takenBy[sail[1]] = takenBy[sail[1]] or {}
            taken = takenBy[sail[1]]
            local route = { way = way, kind = sail[1], faction = Faction(sail), levels = {} }
            route.frame = CreateFrame("Frame", nil, s.frame)
            route.frame:SetAllPoints(s.frame)
            route.frame:SetAlpha(QUIET)
            for level = 1, LEVELS do
                local f = CreateFrame("Frame", nil, route.frame)
                f:SetAllPoints(route.frame)
                route.levels[level] = f
            end
            local c = route.faction == "Alliance" and BLUE or RED
            local i, carry = 0, 0
            for k = 1, #way - 1 do
                local u0, v0, u1, v1 = way[k][1], way[k][2], way[k + 1][1], way[k + 1][2]
                local seg = math.sqrt((u1 - u0) ^ 2 + ((v1 - v0) * 1.5) ^ 2)
                local t = carry
                while t <= seg do
                    local f = seg > 0 and t / seg or 0
                    local u, v = u0 + (u1 - u0) * f, v0 + (v1 - v0) * f
                    local level = LevelOf(i)
                    if not Taken(u, v, level) then
                        Pins.Dot(s, u, v, SIZE, DOT, c[1], c[2], c[3], 1, route.levels[level])
                    end
                    i = i + 1
                    t = t + fine
                end
                carry = t - seg
            end
            -- (d'où à où : les zones de ses deux bouts)
            local ends = {}
            for _, p in ipairs({ way[1], way[#way] }) do
                local id = K.ZoneAt(p[1], p[2])
                local info = id and C_Map.GetMapInfo(id)
                ends[#ends + 1] = info and info.name or "?"
            end
            route.ends = ends
            route.frame:SetShown(KindOn(route))
            routes[#routes + 1] = route
        end
    end
end

-- Les niveaux plus fins selon le zoom (unités du monde par px de la vue)
local function ApplyLevels()
    if #routes == 0 then return end
    local _, _, pu = ns.Map.Cursor.World()
    if not pu or pu <= 0 then return end
    for _, route in ipairs(routes) do
        for level = 1, LEVELS do
            local px = STEP / 2 ^ (level - 1) / pu
            local a = level == 1 and 1 or Smooth(px, SHOW_PX)
            -- (un niveau effacé est aussi caché : à 0, ses points étaient quand
            -- même dessinés et replacés à chaque image d'un zoom)
            route.levels[level]:SetAlpha(a)
            route.levels[level]:SetShown(a > 0.003)
        end
    end
end

-- Chaque route va doucement vers sa transparence ; l'éclat de celle survolée
-- diminue en zoomant
local function Ease(elapsed)
    local _, _, zoom = ns.Map.View.Now()
    local t = math.max(0, math.min(1, ((zoom or 1) - LIT_FADE[1]) / (LIT_FADE[2] - LIT_FADE[1])))
    local up = QUIET + (LIT - QUIET) * (1 - t * t * (3 - 2 * t))
    local k = math.min(1, elapsed * EASE)
    for _, route in ipairs(routes) do
        local target = route == lit and up or QUIET
        local a = route.alpha or QUIET
        if math.abs(a - target) > 0.002 then
            a = a + (target - a) * k
            route.alpha = a
            route.frame:SetAlpha(a)
        end
    end
end

local function Light(route)
    if route == lit then return end
    lit = route
    local owner = set and set.frame
    if not owner then return end
    if route then
        local px, py = ns.Map.Cursor.XY()
        if px then
            -- (près du curseur de la manette : celui de la souris est caché, ailleurs)
            local es = UIParent:GetEffectiveScale()
            GameTooltip:SetOwner(owner, "ANCHOR_NONE")
            GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", px / es + 16, py / es + 16)
        else
            GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
        end
        GameTooltip:AddLine(route.kind == "zeppelin" and L.BOATS_ZEPPELIN or L.BOATS_BOAT, 1, 0.82, 0)
        GameTooltip:AddLine(route.ends[1] .. "  -  " .. route.ends[2], 1, 1, 1)
        if route.faction == "Alliance" then
            GameTooltip:AddLine(FACTION_ALLIANCE or "Alliance", BLUE[1] + 0.25, BLUE[2] + 0.25, BLUE[3] + 0.25)
        elseif route.faction == "Horde" then
            GameTooltip:AddLine(FACTION_HORDE or "Horde", RED[1] + 0.25, RED[2] + 0.25, RED[3] + 0.25)
        else
            GameTooltip:AddLine(L.BOATS_NEUTRAL, 1, 0.82, 0)
        end
        GameTooltip:Show()
    elseif GameTooltip:IsOwned(owner) then
        GameTooltip:Hide()
    end
end

-- La route la plus proche du curseur, à HOVER_PX au plus
local function Hover()
    local view = ns.Map.View.Frame()
    local pad = ns.Map.Cursor.XY()
    if not (pad or (view and view:IsMouseOver())) then return Light(nil) end
    local u, v, pu, pv = ns.Map.Cursor.World()
    if not (u and pu and pv) then return Light(nil) end
    local best, bestD = nil, HOVER_PX
    for _, route in ipairs(routes) do
        local way = route.way
        for k = 1, route.frame:IsShown() and #way - 1 or 0 do   -- (une sorte cachée n'est pas survolée)
            local ax, ay = (way[k][1] - u) / pu, (way[k][2] - v) / pv
            local bx, by = (way[k + 1][1] - u) / pu, (way[k + 1][2] - v) / pv
            local dx, dy = bx - ax, by - ay
            local len2 = dx * dx + dy * dy
            local t = len2 > 0 and math.max(0, math.min(1, -(ax * dx + ay * dy) / len2)) or 0
            local d = math.sqrt((ax + dx * t) ^ 2 + (ay + dy * t) ^ 2)
            if d < bestD then best, bestD = route, d end
        end
    end
    Light(best)
end

-- Les sortes allumées ou éteintes (le rail des calques, l'onglet Carte)
local function RefreshKinds()
    if set then Pins.SetOn(set, Settings.Get("routes") and true or false) end
    for _, route in ipairs(routes) do
        local on = KindOn(route)
        route.frame:SetShown(on)
        if not on and route == lit then Light(nil) end
    end
end

-- (le jeu d'icônes « routes » : caché dans les donjons comme les autres
-- icônes du monde ; ses points ne se font que la première fois qu'il se montre)
local function Build()
    if set or not Pins.Ready() then return end
    set = Pins.Set("routes", 0, 0)
    if not set then return end
    Pins.SetBuild(set, function(s)
        BuildDots(s)
        ApplyLevels()
        local wait = 0
        s.frame:SetScript("OnUpdate", function(_, elapsed)
            Ease(elapsed)
            wait = wait - elapsed
            if wait > 0 then return end
            wait = 0.05
            Hover()
        end)
        s.frame:SetScript("OnHide", function() Light(nil) end)
    end)
    Pins.OnView(function() ApplyLevels() end)
    RefreshKinds()
end

ns.On("MAP_BUILT", Build)
ns.On("MAP_REFRESH", RefreshKinds)
