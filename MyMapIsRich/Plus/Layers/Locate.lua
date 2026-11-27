-- Me localiser, la vue à la réouverture de la carte, et le mode « poser une
-- épingle » : en code de My Map Is Rich depuis la 0.9.0 (ils venaient de
-- Map/Nav.lua, d'OpenMap).
--   me localiser   la carte glisse jusqu'à toi (le bouton de l'habillage, la
--                  croix, Places, le raccourci du jeu) ;
--   la réouverture la carte rouvre au zoom où tu l'avais laissée (gardé par
--                  personnage, même après un /reload) : sur toi, avec le
--                  réglage « La carte ouverte : recentrée sur toi » (onglet
--                  Réglages) ; sans lui, là où tu l'avais laissée. La toute
--                  première fois, ta zone entière. Dans un donjon, où rien
--                  ne te place, là où tu l'avais laissée ;
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

-- (jamais une vue qui n'en est pas une, NaN : la carte rouvrait vide)
local function Valid(t)
    return type(t) == "table" and K.Finite(t[1], t[2], t[3]) and t[3] > 0
end

-- La vue gardée : celle de la dernière fermeture, gardée par personnage
-- (ns.char.mapView) pour revenir après un /reload ou à la connexion
local function Saved()
    if not saved and ns.char and Valid(ns.char.mapView) then
        local t = ns.char.mapView
        saved = { t[1], t[2], t[3] }
    end
    return saved
end

local function OnMapHidden()
    local u, v, zoom = V.Now()
    if not (u and Valid({ u, v, zoom })) then return end
    saved = { u, v, zoom }
    if ns.char then ns.char.mapView = { u, v, zoom } end
end

-- La vue où rouvrir : u, v, zoom ; onlySaved : seulement une vue gardée.
-- Recentrée sur toi, elle garde le zoom que tu avais en la fermant ; la
-- toute première fois, ta zone entière
local function SavedView(_, onlySaved)
    local center = ns.db and ns.db.options.centerOnOpen
    local u, v, best = K.UnitWorld("player")
    local s = Saved()
    if s and (not center or not u) then return s[1], s[2], s[3] end
    if onlySaved then return end
    if u then
        if s then return u, v, s[3] end
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

-- Une épingle là où l'on a appuyé, dans le mode épingle (Map/View.lua)
function E.DropAt(u, v)
    local id, x, y = K.ZoneAt(u, v)
    if id then E.Add(id, x, y) end
end

---------------------------------------------------------------------------
-- Pour la vue (Map/View.lua) : la vue où rouvrir, et celle à garder quand
-- la carte se ferme
---------------------------------------------------------------------------
function V.SavedView() return SavedView() end
function V.Remember() OnMapHidden() end

-- (la carte fermée : le mode épingle aussi)
ns.On("MAP_HIDE", function() if armed then E.SetMode(false) end end)
