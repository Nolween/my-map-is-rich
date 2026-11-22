-- La carte d'un donjon (Layers/DungeonView.lua) à la manette :
--   curseur au bord : déplacer la carte
--   stick droit     : zoomer autour du curseur de la manette
--   LB / RB         : étage précédent / suivant
--   LT / RT         : onglet précédent / suivant du panneau (étages, boss,
--                     quêtes, butin)
--   View            : passer dans le panneau (la croix y choisit, B en ressort)
-- A (les boss, les boutons sous le curseur) et X (revenir au monde) restent
-- à la vue de la carte ; la croix, Y et B à l'interface manette.
-- Tout passe par ns.Map.Dungeons : rien de la fenêtre n'est touché d'ici.
local _, root = ...
local ns = root.Plus
local P = ns.Pad
local F = ns.Focus

-- (chargé après Layers/DungeonView.lua, qui donne ces fonctions : le .toc)
local DG = ns.Map.Dungeons

local function Shown() return DG.Shown() end

-- (la molette de la carte, que le stick droit fait tourner : autour du
-- curseur de la manette quand elle mène, autour de la souris sinon)
DG.SetWheelPoint(function()
    if P.current == "dungeon" then
        return true, ns.Map.Cursor.XY()
    end
    return false
end)

local function Side()
    local side = DG.Side()
    if side and side:IsVisible() then F.SetForced(side) end
end

-- (comme la carte seule : aucun raccourci posé, les boutons dont
-- l'interface manette ne se sert pas sont lus ; la croix, Y et B restent les
-- siens, X revient au monde par la vue de la carte)
P.DefineContext("dungeon", 40, Shown, nil, "read")
P.SetAction("dungeon", "PADLSHOULDER", function() DG.Floor(-1) end)
P.SetAction("dungeon", "PADRSHOULDER", function() DG.Floor(1) end, function()
    return DG.HasFloors() and "HINT_FLOORS" or nil
end)
P.SetAction("dungeon", "PADLTRIGGER", function() DG.SideTab(-1) end)
P.SetAction("dungeon", "PADRTRIGGER", function() DG.SideTab(1) end, function()
    return DG.Side() and "HINT_TABS" or nil
end)
P.SetAction("dungeon", "PADBACK", Side, function()
    return DG.Side() and "HINT_SIDE" or nil
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
    local port = DG.Port()
    if not port then return end
    local x, y = ns.Map.Cursor.XY()
    if not x then return end
    local l, b, w, h = port:GetRect()
    if not l then return end
    local es = port:GetEffectiveScale()
    x, y = x / es - l, y / es - b
    if x < 0 or y < 0 or x > w or y > h then return end
    local function Push(d) return d < EDGE and (EDGE - d) / EDGE or 0 end
    local dx = Push(w - x) - Push(x)
    local dy = Push(h - y) - Push(y)
    if dx == 0 and dy == 0 then return end
    DG.Pan(dx * EDGE_SPEED * elapsed, dy * EDGE_SPEED * elapsed)
end)

ns.On("CONTEXT", function(name)
    edge:SetShown(name == "dungeon")
end)
