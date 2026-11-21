-- La carte d'un donjon (la vue de donjon d'OpenMap, Dungeons.lua) à la
-- manette. OpenMap la fait zoomer autour de la souris et se déplacer en la
-- tirant à la souris ; ici :
--   curseur au bord : déplacer la carte
--   stick droit     : zoomer autour du curseur de la manette
--   LB / RB         : étage précédent / suivant
--   LT / RT         : onglet précédent / suivant du panneau (étages, boss,
--                     quêtes, butin)
--   View            : passer dans le panneau (la croix y choisit, B en ressort)
-- A (les boss, les boutons sous le curseur) et X (revenir au monde) restent
-- à la vue manette d'OpenMap ; la croix, Y et B à l'interface manette.
-- La vue est le cadre d'OpenMap « OpenMapDungeonView » : son zoom et son
-- décalage (view.zoom, view.ox, view.oy) sont changés puis la vue remise en
-- page par son propre script (celui de view.port, OnSizeChanged). Rien de
-- Blizzard n'est touché.
local _, root = ...
local ns = root.Plus
local L = ns.L
local P = ns.Pad
local F = ns.Focus

local D = {}
ns.Dungeon = D

local PAN_STEP = 60          -- px par appui (ou répétition) de la croix
local ZOOM_MIN, ZOOM_MAX = 0.5, 4   -- (ceux d'OpenMap : Dungeons.lua, Wheel)

local function View()
    local view = _G.MyMapIsRichDungeonView
    if view and view:IsShown() and view.zoom and view.port then return view end
end

local function Layout(view)
    local fn = view.port:GetScript("OnSizeChanged")
    if fn then pcall(fn, view.port) end
end

function D.Pan(dx, dy)
    local view = View()
    if not view then return end
    -- (la croix vers la droite : on regarde plus à droite, la carte part à gauche)
    view.ox = (view.ox or 0) - dx * PAN_STEP
    view.oy = (view.oy or 0) - dy * PAN_STEP
    Layout(view)
end

-- Zoomer d'un cran autour d'un point de l'écran (px ; le curseur de la manette)
function D.Zoom(delta, x, y)
    local view = View()
    if not view then return end
    local z = math.max(ZOOM_MIN, math.min(ZOOM_MAX, view.zoom * (delta > 0 and 1.25 or 0.8)))
    if math.abs(z - view.zoom) < 1e-3 then return end
    local es = view:GetEffectiveScale()
    local cx, cy = view.port:GetCenter()
    local dx, dy = 0, 0
    if x and cx then dx, dy = x / es - cx - view.ox, y / es - cy - view.oy end
    view.ox, view.oy = view.ox - dx * (z / view.zoom - 1), view.oy - dy * (z / view.zoom - 1)
    view.zoom = z
    Layout(view)
end

-- La molette de la vue (le stick droit d'OpenMap y passe) : autour du
-- curseur de la manette quand l'addon a la manette, autour de la souris sinon
local wrapped = false
local function Wrap()
    local view = _G.MyMapIsRichDungeonView
    if wrapped or not view then return end
    local original = view:GetScript("OnMouseWheel")
    if not original then return end
    wrapped = true
    view:SetScript("OnMouseWheel", function(self, delta)
        if P.current == "dungeon" or (P.current == "window" and F.Forced() == self.side) then
            local mod = ns.mod
            local ok, x, y = pcall(mod.PadCursorXY)
            if ok and x then return D.Zoom(delta, x, y) end
            return D.Zoom(delta)
        end
        return original(self, delta)
    end)
end

local function Floor(dir)
    local view = View()
    if not view then return end
    local b = dir < 0 and view.prev or view.next
    if b and b:IsShown() then pcall(b.Click, b) end
end

local function SideTab(dir)
    local view = View()
    local side = view and view.side
    if not (side and side:IsVisible() and side.tabs) then return end
    F.CycleTabs(side.tabs, ns.mod.db and ns.mod.db.dungeonTab, dir)
end

local function Side()
    local view = View()
    local side = view and view.side
    if side and side:IsVisible() then F.SetForced(side) end
end

local function Shown()
    local mod = ns.mod
    if not (mod and mod.DungeonViewShown) then return false end
    local ok, on = pcall(mod.DungeonViewShown)
    return ok and on or false
end

-- (comme la carte seule : aucun raccourci posé, les boutons dont
-- l'interface manette ne se sert pas sont lus ; la croix, Y et B restent les
-- siens, X revient au monde par la vue manette d'OpenMap)
P.DefineContext("dungeon", 40, Shown, nil, "read")
P.SetAction("dungeon", "PADLSHOULDER", function() Floor(-1) end)
P.SetAction("dungeon", "PADRSHOULDER", function() Floor(1) end, function()
    local view = View()
    return view and view.next and view.next:IsShown() and "HINT_FLOORS" or nil
end)
P.SetAction("dungeon", "PADLTRIGGER", function() SideTab(-1) end)
P.SetAction("dungeon", "PADRTRIGGER", function() SideTab(1) end, function()
    local view = View()
    return view and view.side and view.side:IsVisible() and "HINT_TABS" or nil
end)
P.SetAction("dungeon", "PADBACK", Side, function()
    local view = View()
    return view and view.side and view.side:IsVisible() and "HINT_SIDE" or nil
end)
P.SetPassive("dungeon", "PAD3", "HINT_BACK_WORLD")
P.SetPassive("dungeon", "RSTICK", "HINT_ZOOM")
P.SetPassive("dungeon", "LSTICK", "HINT_EDGE_PAN")

-- Le curseur de la manette près du bord de la carte du donjon : elle glisse
-- de ce côté (EDGE px du bord, EDGE_SPEED px par seconde au bord)
local EDGE, EDGE_SPEED = 40, 420
local edge = CreateFrame("Frame")
edge:Hide()
edge:SetScript("OnUpdate", function(_, elapsed)
    local view = View()
    local mod = ns.mod
    if not (view and mod and mod.PadCursorXY) then return end
    local ok, x, y = pcall(mod.PadCursorXY)
    if not ok or not x then return end
    local l, b, w, h = view.port:GetRect()
    if not l then return end
    local es = view.port:GetEffectiveScale()
    x, y = x / es - l, y / es - b
    if x < 0 or y < 0 or x > w or y > h then return end
    local function Push(d) return d < EDGE and (EDGE - d) / EDGE or 0 end
    local dx = Push(w - x) - Push(x)
    local dy = Push(h - y) - Push(y)
    if dx == 0 and dy == 0 then return end
    view.ox = (view.ox or 0) - dx * EDGE_SPEED * elapsed
    view.oy = (view.oy or 0) - dy * EDGE_SPEED * elapsed
    Layout(view)
end)

ns.On("CONTEXT", function(name)
    if name == "dungeon" then Wrap() end
    edge:SetShown(name == "dungeon")
end)
