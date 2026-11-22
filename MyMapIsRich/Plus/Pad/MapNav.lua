-- La carte seule, à la manette (vue manette d'OpenMap, aucune fenêtre
-- ouverte). L'interface manette lie tous les boutons principaux sur la carte,
-- et y poser nos raccourcis lui fait perdre le focus (plus de curseur) : le
-- jeu et OpenMap gardent donc le stick gauche (le curseur), A (appuyer sur
-- l'icône ou zoomer dans la zone), X (dézoomer), B (fermer la carte), Y
-- (Plus), la croix (Carte standard), L3 (marqueur), le stick droit (zoom).
-- L'addon lit sur la manette ceux dont elle ne se sert pas :
--   RB      : suivre le personnage (la carte le garde au centre quand il
--             marche) ; RB de nouveau : arrêter
--   LB      : le navigateur de lieux (UI/Places.lua)
--   LT / RT : l'icône précédente / suivante autour du curseur
--   View    : la roue des actions (UI/ActionBar.lua : la file, envoyer au
--             groupe, épingles, plume, menu d'OpenMap)
--   R3      : un itinéraire jusqu'au point sous le curseur, ou l'annuler sur
--             sa destination (Travel/Guide.lua)
-- Le curseur de la manette est celui du jeu : l'addon ne le déplace jamais
-- (ce serait du code d'addon dans la carte de Blizzard). Pour amener une
-- icône sous le curseur, c'est la vue d'OpenMap qui glisse.
-- L'aimant : le curseur au repos tout près d'une icône, la vue se recale
-- pour la mettre dessous (son info-bulle s'ouvre, A l'appuie).
--
-- La plume d'OpenMap sortie (contexte « sketch ») : A pose et lève la plume,
-- X la range (OpenMap) ; View passe dans ses outils.
local _, root = ...
local ns = root.Plus
local L = ns.L
local P = ns.Pad
local F = ns.Focus

local M = {}
ns.MapNav = M

-- Les jeux d'icônes d'OpenMap (Stitch.lua : S.PinSet) qu'on peut viser
local SETS = {
    "dungeons", "boats", "zeppelins", "flight", "route", "routes",
    "userpins", "waypoint", "group", "friends", "friendzones",
    "quests", "questoffers", "notes",
    "tf_vendor", "tf_repair", "tf_innkeeper", "tf_banker", "tf_mailbox",
    "tf_auctioneer", "tf_stable", "tf_classTrainer", "tf_profTrainer",
    "tf_spirit", "tf_rare",
    "omgp_journey",          -- (la destination d'un itinéraire : Travel/Route.lua)
}
local PAN_PART = 0.25        -- la part de la vue d'un déplacement sans icône
local UNDER = 6              -- px : une icône si près du curseur est déjà dessous
local REST = 0.3             -- s de repos du curseur avant l'aimant

local function Scroll()
    local map = _G.WorldMapFrame
    return map and map.ScrollContainer
end

-- Le rectangle de la vue à l'écran (px) : toute la carte plein écran, sinon
-- la vue de la carte du jeu
local function ViewRect()
    local mod = ns.mod
    local sc = ns.FullMap() and mod.ViewFrame and mod.ViewFrame() or Scroll()
    if not sc then return end
    local l, b, w, h = sc:GetRect()
    if not l then return end
    local es = sc:GetEffectiveScale()
    return l * es, b * es, (l + w) * es, (b + h) * es, es
end

-- Le curseur de la manette (px de l'écran), sinon le milieu de la vue
local function Cursor()
    local mod = ns.mod
    if mod and mod.PadCursorXY then
        local ok, x, y = pcall(mod.PadCursorXY)
        if ok and x then return x, y, true end
    end
    local l, b, r, t = ViewRect()
    if l then return (l + r) / 2, (b + t) / 2, false end
end

local function Visible(f)
    if not (f:IsVisible() and f:IsMouseEnabled()) then return false end
    if f.GetEffectiveAlpha and f:GetEffectiveAlpha() < 0.05 then return false end
    return true
end

-- Les icônes de HereBeDragons (Questie, TomTom, les récolteurs...) que la
-- vue manette d'OpenMap pose sur sa carte
local function LibIcons(out, seen)
    if not (LibStub and LibStub.IterateLibraries) then return end
    for name, lib in LibStub:IterateLibraries() do
        if type(name) == "string" and type(lib) == "table" and type(lib.worldmapPins) == "table"
            and (name:match("^HereBeDragons.*%-Pins%-2%.0$") or name == "HereBeDragons-Pins-ZGV") then
            for icon in pairs(lib.worldmapPins) do
                if type(icon) == "table" and icon.IsVisible and not seen[icon] and Visible(icon) then
                    seen[icon] = true
                    out[#out + 1] = icon
                end
            end
        end
    end
end

-- Les icônes visibles dans la vue : { { frame, x, y }, ... } en px de l'écran
local function Icons()
    local out, seen = {}, {}
    local S = ns.S
    if S and S.GetPinSet then
        for _, key in ipairs(SETS) do
            local set = S.GetPinSet(key)
            if set and set.frame and set.frame:IsVisible() and type(set.pins) == "table" then
                for _, pin in ipairs(set.pins) do
                    if not seen[pin] and Visible(pin) then
                        seen[pin] = true
                        out[#out + 1] = pin
                    end
                end
            end
        end
    end
    pcall(LibIcons, out, seen)
    local l, b, r, t = ViewRect()
    local list = {}
    for _, f in ipairs(out) do
        local cx, cy = f:GetCenter()
        if cx then
            local es = f:GetEffectiveScale()
            local x, y = cx * es, cy * es
            if not l or (x >= l and x <= r and y >= b and y <= t) then
                list[#list + 1] = { f, x, y }
            end
        end
    end
    return list
end

-- La vue glisse pour que le point (tx, ty) de l'écran vienne sous (x, y)
local function Bring(tx, ty, x, y)
    local mod = ns.mod
    if not (mod and mod.CursorWorld and mod.ViewNow and mod.Glide) then return false end
    local okW, _, _, du, dv = pcall(mod.CursorWorld)
    local okV, u, v, zoom = pcall(mod.ViewNow)
    if not (okW and okV and du and u) then return false end
    local _, _, _, _, es = ViewRect()
    es = es or 1
    local dx, dy = (tx - x) / es, (ty - y) / es
    -- (l'écran monte, le monde d'OpenMap descend : v croît vers le bas)
    ns.Call(mod.Glide, u + dx * du, v - dy * dv, zoom)
    return true
end

-- (un saut ou un recentrage vient d'avoir lieu : l'aimant ne s'en mêle pas
-- tant que le curseur ne bouge pas)
local magnetDone = false

-- Déplacer la vue d'un quart dans une direction (dx, dy : -1, 0 ou 1)
function M.Pan(dx, dy)
    local l, b, r, t = ViewRect()
    local x, y = Cursor()
    if not (l and x) then return end
    -- (le point à un quart de vue dans la direction vient sous le curseur)
    Bring(x + dx * (r - l) * PAN_PART, y + dy * (t - b) * PAN_PART, x, y)
end

---------------------------------------------------------------------------
-- L'aimant
---------------------------------------------------------------------------
local magnet = CreateFrame("Frame")
magnet:Hide()
local restX, restY, restSince = nil, nil, 0
local wait = 0
magnet:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = 0.1
    -- (la carte suit le personnage : l'aimant ne la déplace pas)
    if not ns.db.options.magnet or P.current ~= "map" or M.Following() then return end
    local x, y, real = Cursor()
    if not (x and real) then return end
    -- (le curseur bouge : l'aimant attend qu'il se repose)
    if not restX or math.abs(x - restX) + math.abs(y - restY) > 1.5 then
        restX, restY, restSince, magnetDone = x, y, GetTime(), false
        return
    end
    if magnetDone or GetTime() - restSince < REST then return end
    local mod = ns.mod
    if mod.Animating then
        local ok, busy = pcall(mod.Animating)
        if ok and busy then return end
    end
    if mod.Zooming then
        local ok, busy = pcall(mod.Zooming)
        if ok and busy then return end
    end
    -- (au-dessus d'une fenêtre d'OpenMap : rien)
    local okC, ctl, blocked = pcall(mod.PadControlAt, x, y)
    if okC and (ctl or blocked) then return end
    local radius = ns.db.options.magnetRadius or 24
    local best, bestD = nil, radius * radius
    for _, it in ipairs(Icons()) do
        local ax, ay = it[2] - x, it[3] - y
        local d = ax * ax + ay * ay
        if d < bestD then best, bestD = it, d end
    end
    magnetDone = true
    if best and bestD > 2 * 2 then Bring(best[2], best[3], x, y) end
end)

---------------------------------------------------------------------------
-- Les actions
---------------------------------------------------------------------------
local function FindMe()
    local mod = ns.mod
    ns.Call(mod.FindMe, mod)
end
M.FindMe = FindMe

---------------------------------------------------------------------------
-- RB : suivre le personnage. Un appui recentre la carte sur lui et l'y
-- garde : la vue le suit quand il marche, et revient sur lui après un zoom.
-- Un autre appui arrête. LT / RT et le choix d'un lieu, qui emmènent la vue
-- ailleurs, arrêtent aussi le suivi ; l'aimant se tait pendant ce temps.
-- Le suivi dure jusqu'à ce qu'on l'arrête (la carte fermée puis rouverte,
-- il reprend). La carte ouverte : recentrée sur le personnage (réglage
-- centerOnOpen).
---------------------------------------------------------------------------
local following = false
local FOLLOW_EVERY = 0.05    -- s
local OPEN_DELAYS = { 0.05, 0.25 }   -- s : après qu'OpenMap a remis sa vue à l'ouverture

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Où est le personnage sur le monde d'OpenMap (u, v), et la carte où il est
local function PlayerWorld()
    local mod = ns.mod
    if not (mod and mod.ToWorld and C_Map and C_Map.GetBestMapForUnit) then return end
    local ok, best = pcall(C_Map.GetBestMapForUnit, "player")
    best = ok and Plain(best) or nil
    if not best then return end
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, best, "player")
    if not okP or not pos then return end
    local okXY, x, y = pcall(pos.GetXY, pos)
    if not okXY then return end
    x, y = Plain(x), Plain(y)
    if not (x and y) or (x == 0 and y == 0) then return end
    local okW, u, v = pcall(mod.ToWorld, best, x, y)
    if okW and u then return u, v, best end
end

-- La vue tout de suite sur le personnage ; `fit` : au moins au zoom où sa zone tient
local function CenterNow(fit)
    local mod = ns.mod
    local u, v, best = PlayerWorld()
    if not u then return false end
    local ok, cu, cv, zoom = pcall(mod.ViewNow)
    if not (ok and cu) then return false end
    if fit and mod.FitZoom then
        local okZ, z = pcall(mod.FitZoom, best)
        if okZ and z then zoom = math.max(zoom, z) end
    end
    ns.Call(mod.ShowNow, u, v, zoom)
    return true
end

function M.Following() return following end

function M.SetFollow(on)
    on = on and true or false
    if on == following then return end
    following = on
    if on then FindMe() end
    P.Dirty()
end

local function ToggleFollow() M.SetFollow(not following) end

local follow = CreateFrame("Frame")
follow:Hide()
local followWait = 0
follow:SetScript("OnUpdate", function(_, elapsed)
    followWait = followWait - elapsed
    if followWait > 0 then return end
    followWait = FOLLOW_EVERY
    if not (following and ns.ViewOn()) then return end
    if P.current == "sketch" or P.current == "dungeon" then return end
    local mod = ns.mod
    -- (un recentrage qui glisse encore, ou un zoom en cours : on attend)
    if mod.Animating then
        local ok, busy = pcall(mod.Animating)
        if ok and busy then return end
    end
    if mod.Zooming then
        local ok, busy = pcall(mod.Zooming)
        if ok and busy then return end
    end
    local u, v = PlayerWorld()
    if not u then return end
    local ok, cu, cv = pcall(mod.ViewNow)
    if not (ok and cu) then return end
    -- (moins d'un demi-pixel d'écart : rien à faire)
    local okC, _, _, pu, pv = pcall(mod.CursorWorld)
    local tu = okC and pu and pu * 0.5 or 1e-6
    local tv = okC and pv and pv * 0.5 or 1e-6
    if math.abs(u - cu) <= tu and math.abs(v - cv) <= tv then return end
    CenterNow(false)
end)

ns.On("MAP_SHOW", function()
    follow:Show()
    if not (ns.db and ns.db.options.centerOnOpen) then return end
    -- (après qu'OpenMap a remis la vue qu'il avait gardée, à l'image suivante)
    for _, delay in ipairs(OPEN_DELAYS) do
        C_Timer.After(delay, function()
            if ns.MapShown() and ns.ViewOn() then CenterNow(true) end
        end)
    end
end)
ns.On("MAP_HIDE", function() follow:Hide() end)

local function Sketching()
    local mod = ns.mod
    if not (mod and mod.IsSketching) then return false end
    local ok, on = pcall(mod.IsSketching, mod)
    return ok and on or false
end

-- Le plateau de la plume (Sketch.lua : sa fenêtre, donnée au curseur)
local function Tray()
    local roots = ns.mod and ns.mod.padRoots
    if type(roots) ~= "table" then return end
    for _, f in ipairs(roots) do
        if type(f) == "table" and f.tools and f.head and f.IsVisible and f:IsVisible() then return f end
    end
end

-- La carte a le focus de la manette (le curseur du jeu, SoftCursor, est à
-- elle). Tant qu'elle ne l'a pas (le focus est sur le journal de quêtes ou
-- le pied de la carte), l'interface manette garde tous ses boutons : c'est
-- avec eux qu'elle donne le focus à la carte.
local function CanvasFocus()
    local map = _G.WorldMapFrame
    -- (le curseur de la carte affiché : la carte a la manette)
    local soft = _G.SoftCursor
    if soft and soft:IsShown() then return true end
    if not (map and map.IsCanvasGamepadFocus) then return true end
    local ok, on = pcall(map.IsCanvasGamepadFocus, map)
    return ok and on and true or false
end
M.CanvasFocus = CanvasFocus

-- Le curseur de la manette est-il vraiment sur la carte ? La règle du zoom
-- d'OpenMap (PadView.lua : Cursor) : le curseur du jeu affiché ET la carte
-- qui a le focus. Le curseur seul ne suffit pas : passé sur la carte puis
-- revenu sur la liste de droite, il reste affiché. (La caméra au stick et
-- R3 sur une quête de la liste s'en servent.)
function M.CursorOnMap()
    local map = _G.WorldMapFrame
    if not map then return false end
    local soft = _G.SoftCursor
    if not (soft and soft:IsShown()) then return false end
    if not map.IsCanvasGamepadFocus then return true end
    local ok, on = pcall(map.IsCanvasGamepadFocus, map)
    return ok and on and true or false
end

---------------------------------------------------------------------------
-- LT / RT : l'icône précédente / suivante autour du curseur. Au premier
-- appui, les icônes visibles sont rangées de la plus proche du curseur à la
-- plus lointaine (sans celle déjà dessous) ; chaque appui amène la suivante
-- (ou la précédente) sous le curseur. La liste est refaite si le curseur a
-- bougé depuis le dernier saut, ou après CYCLE_STALE s sans appui.
---------------------------------------------------------------------------
local CYCLE_MOVED = 8        -- px
local CYCLE_STALE = 3        -- s
local cycle                  -- { icons = { frame, ... }, at = index, x, y (le curseur), t }

function M.Cycle(dir)
    local x, y = Cursor()
    if not x then return end
    -- (la vue part vers une icône : elle ne suit plus le personnage)
    M.SetFollow(false)
    local now = GetTime()
    local stale = not cycle or now - cycle.t > CYCLE_STALE
        or math.abs(x - cycle.x) + math.abs(y - cycle.y) > CYCLE_MOVED
    if stale then
        local list = {}
        for _, it in ipairs(Icons()) do
            local ax, ay = it[2] - x, it[3] - y
            local d = ax * ax + ay * ay
            if d > UNDER * UNDER then list[#list + 1] = { it[1], d } end
        end
        table.sort(list, function(a, b) return a[2] < b[2] end)
        local icons = {}
        for i, it in ipairs(list) do icons[i] = it[1] end
        cycle = { icons = icons, at = 0 }
    end
    cycle.x, cycle.y, cycle.t = x, y, now
    local n = #cycle.icons
    if n == 0 then return end
    -- (de l'une à l'autre en boucle ; LT au premier appui : la plus lointaine)
    cycle.at = (cycle.at - 1 + dir) % n + 1
    local f = cycle.icons[cycle.at]
    if not (f and f:IsVisible()) then return end
    local cx, cy = f:GetCenter()
    if not cx then return end
    local es = f:GetEffectiveScale()
    magnetDone = true
    Bring(cx * es, cy * es, x, y)
end

local function Actions()
    if ns.ActionBar then ns.ActionBar.Toggle() end
end

-- La carte seule : aucun raccourci posé (l'interface manette perdrait le
-- focus de la carte) ; les boutons dont elle ne se sert pas y sont lus
-- (Pad/Bindings.lua, mode « read »). La croix, A, X, B et les sticks
-- restent les siens et ceux d'OpenMap.
-- La barre d'aide, comme la maquette de la carte plein écran : A Choisir,
-- R3, LB, RB, Y (les calques : UI/Layers.lua), View, LT (l'icône
-- suivante), RT (les quêtes : UI/QuestPanel.lua), puis X et B (du jeu, en gris).
P.DefineContext("map", 10, CanvasFocus, nil, "read")
P.SetPassive("map", "PAD1", function()
    local mod = ns.mod
    local ok, on = pcall(mod.PinMode)
    return (ok and on) and "HINT_PIN_DROP" or "HINT_SELECT"
end)
-- (R3 : le clic du stick droit ; Travel/ est chargé après ce fichier)
P.SetAction("map", "PADRSTICK", function()
    if ns.Travel then ns.Travel.AtCursor() end
end, function()
    return ns.Travel and ns.Travel.HintLabel() or nil
end)
P.SetAction("map", "PADRSHOULDER", ToggleFollow, function()
    return following and "HINT_FOLLOW_STOP" or "HINT_FOLLOW"
end)
P.SetAction("map", "PADLSHOULDER", function()
    -- (la carte plein écran : « Aller à… », la recherche ; sinon le navigateur de lieux)
    if not ns.Places then return end
    if ns.FullMap() then
        if ns.Places.Shown() then ns.Places.Hide() else ns.Places.Show("search") end
    else
        ns.Places.Toggle()
    end
end, function() return ns.FullMap() and "HINT_GOTO" or "HINT_PLACES" end)
-- (Y : le panneau des calques, sur la carte plein écran seulement)
P.SetAction("map", "PAD4", function()
    if ns.FullMap() and ns.Layers then ns.Layers.TogglePanel() end
end, function() return ns.FullMap() and "HINT_LAYERS" or nil end)
P.SetAction("map", "PADBACK", Actions, "HINT_ACTIONS")
-- (sur la carte plein écran, LT : l'icône suivante autour du curseur ; RT :
-- les quêtes, UI/QuestPanel.lua — Start est au menu en cercle. Sur la carte
-- classique, LT / RT : l'icône précédente / suivante, comme avant)
P.SetAction("map", "PADLTRIGGER", function()
    if ns.FullMap() then M.Cycle(1) else M.Cycle(-1) end
end, function()
    return ns.FullMap() and "HINT_JUMP" or nil
end)
P.SetAction("map", "PADRTRIGGER", function()
    if ns.FullMap() and ns.QuestPanel then ns.QuestPanel.PadMenu() else M.Cycle(1) end
end, function()
    -- (la manette sur la carte : RT affiche la liste ou y entre ; dedans, c'est
    -- le contexte « quests » de UI/QuestPanel.lua qui dit « Fermer les quêtes »)
    if not ns.FullMap() then return nil end
    return "HINT_QUESTS"
end)
P.SetPassive("map", "PAD3", function() return ns.FullMap() and "HINT_ZOOM_OUT" or nil end)
P.SetPassive("map", "PAD2", function() return ns.FullMap() and "HINT_CLOSE_MAP" or nil end)

-- La plume sortie : A pose et lève la plume, X la range (OpenMap) ; View
-- passe dans ses outils, RB recentre
P.DefineContext("sketch", 45, function() return Sketching() and CanvasFocus() end, nil, "read")
P.SetAction("sketch", "PADBACK", function()
    local tray = Tray()
    if tray and F.SetForced then F.SetForced(tray) end
end, "HINT_QUILL_TOOLS")
P.SetAction("sketch", "PADRSHOULDER", FindMe, "HINT_RECENTER")
P.SetPassive("sketch", "PAD1", "HINT_QUILL_PEN")
P.SetPassive("sketch", "PAD3", "HINT_QUILL_DONE")

ns.On("CONTEXT", function(name)
    magnet:SetShown(name == "map")
    restX, magnetDone = nil, false
end)

-- Poser une épingle depuis le menu d'OpenMap : le menu se ferme, pour que A
-- pose l'épingle sur la carte (la vue manette le fait quand aucune fenêtre
-- n'a la manette)
ns.On("READY", function()
    local mod = ns.mod
    if type(mod.SetPinMode) == "function" then
        hooksecurefunc(mod, "SetPinMode", function(on)
            if on and ns.ViewOn() and mod.MenuShown and mod.MenuShown() then
                ns.Call(mod.CloseMenu)
            end
            P.Dirty()
        end)
    end
end)
