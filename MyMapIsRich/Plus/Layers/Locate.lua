-- Me localiser, la vue à la réouverture de la carte, et le mode « poser une
-- épingle » : en code de My Map Is Rich depuis la 0.9.0 (ils venaient de
-- Map/Nav.lua, d'OpenMap).
--   me localiser   la carte glisse jusqu'à toi (le bouton de l'habillage, la
--                  croix, Places, le raccourci du jeu) ;
--   la réouverture la carte rouvre sur toi, à la taille de ta zone, avec le
--                  réglage « La carte ouverte : recentrée sur toi » (onglet
--                  Réglages) ; sans lui, là où tu l'avais laissée. Dans un
--                  donjon, où rien ne te place, là où tu l'avais laissée ;
--   le mode épingle le prochain appui sur la carte (A à la manette) y pose une
--                  épingle (la roue, la fiche d'un point).
-- Les anciens choix d'OpenMap (« garder le zoom », « toute ta zone »,
-- « garder la vue si tu y es encore ») se résument à ces deux-là.
local _, root = ...
local ns = root.Plus
local L = ns.L

local K = ns.Map.Coords
local V = ns.Map.View
local E = ns.Map.MyPins

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- La place d'une unité sur le monde : u, v et sa carte ; rien si le jeu la
-- tait (secrète, dans une instance, inconnue)
function K.UnitWorld(unit)
    local ok, best = pcall(C_Map.GetBestMapForUnit, unit)
    best = ok and Plain(best) or nil
    if not best or not K.Rect(best) then return end
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, best, unit)
    if not okP or not pos then return end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    x, y = Plain(x), Plain(y)
    if not (x and y) or (x == 0 and y == 0) then return end
    local u, v = K.ToWorld(best, x, y)
    if u then return u, v, best end
end

---------------------------------------------------------------------------
-- Me localiser
---------------------------------------------------------------------------
function V.FindMe(keepZoom)
    local u, v, best = K.UnitWorld("player")
    if not u then
        ns.Print(L.FINDME_NONE)
        return false
    end
    local _, _, zoom = V.Now()
    zoom = zoom or 1
    local fit = V.FitZoom(best) or zoom
    V.Glide(u, v, keepZoom and zoom or math.max(zoom, fit))
    return true
end

---------------------------------------------------------------------------
-- La vue à la réouverture
---------------------------------------------------------------------------
local saved                     -- { u, v, zoom } : la vue quand la carte s'est fermée

local function MaxZoom()
    return ns.Map.Settings.Get("maxZoom") or math.huge
end

-- (la vue de la carte du jeu pour un donjon : là où tu étais dehors)
local function RememberOutside()
    local u, v, best = K.UnitWorld("player")
    local mod = ns.Map.Legacy()
    if u and mod then mod.outsideInstanceView = { u, v, best } end
end

local function OnMapHidden()
    local u, v, zoom = V.Now()
    -- (jamais une vue qui n'en est pas une, NaN : la carte rouvrait vide)
    if u and K.Finite(u, v, zoom) and zoom > 0 then saved = { u, v, zoom } end
end

-- La vue où rouvrir : u, v, zoom ; onlySaved : seulement une vue gardée
local function SavedView(_, onlySaved)
    local center = ns.db and ns.db.options.centerOnOpen
    local u, v, best = K.UnitWorld("player")
    if saved and (not center or not u) then return saved[1], saved[2], saved[3] end
    if onlySaved then return end
    if u then
        local fit = V.FitZoom(best) or 1
        return u, v, math.min(fit, MaxZoom())
    end
end

---------------------------------------------------------------------------
-- Le mode « poser une épingle » : le prochain appui sur la carte la pose
---------------------------------------------------------------------------
local armed = false

function E.Mode() return armed end

function E.SetMode(on)
    armed = on and true or false
    ns.Fire("MAP_PIN_MODE", armed)
end

-- Une épingle là où l'on a appuyé, dans le mode épingle (Map/PadView.lua)
local function DropAt(u, v)
    local id, x, y = K.ZoneAt(u, v)
    if id then E.Add(id, x, y) end
end

---------------------------------------------------------------------------
-- Les ponts vers le code d'OpenMap qui reste (la vue : Map/PadView.lua,
-- Map/WorldMap.lua)
---------------------------------------------------------------------------
ns.On("MAP_ATTACHED", function()
    local mod = ns.Map.Legacy()
    if not mod then return end
    mod.FindMe = function(_, keepZoom) return V.FindMe(keepZoom) end
    mod.SavedView = SavedView
    mod.OnMapHidden = function() OnMapHidden() end
    mod.RememberOutsideInstance = RememberOutside
    mod.PinMode = function() return armed end
    mod.SetPinMode = function(on) E.SetMode(on) end
    mod.DropWaypoint = DropAt
end)

-- (la carte fermée : le mode épingle aussi)
ns.On("MAP_HIDE", function() if armed then E.SetMode(false) end end)
