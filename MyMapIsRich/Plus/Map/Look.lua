-- L'aspect de la carte : ses réglages et leur effet sur le dessin, en code de
-- My Map Is Rich depuis la 0.12.0 (ils venaient de Map/WorldMap.lua).
--   les calques      donjons, bateaux, zeppelins, maîtres de vol, routes ;
--   les icônes       leur taille, le zoom d'où elles viennent, « seulement
--                    les lieux trouvés », cachées dans les instances ;
--   le dessin        les zones inexplorées (montrées, assombries ou cachées,
--                    pour tout le compte ou ce personnage), l'assombrissement
--                    et sa teinte, l'harmonie des couleurs, la désaturation ;
--   le zoom          le plus profond ; ta flèche.
-- Un réglage changé (l'onglet Carte, le rail des calques) passe par
-- ns.Map.Settings.Refresh : le dessin suit, la vue se redessine, et
-- « MAP_REFRESH » prévient les calques de Plus.
local _, root = ...
local ns = root.Plus

local LK = ns.Map.Look
local Settings = ns.Map.Settings
local A = ns.Map.Art
local P = ns.Map.Pins
local Get = Settings.Get

-- Les bornes des curseurs : le plus petit, le plus grand, le pas
local RANGES = {
    iconsFrom = { 0, 20, 0.5 },     -- (0 : chaque icône dès son propre zoom, « Auto » ; 1 : le monde entier)
    iconScale = { 0.6, 2, 0.05 },
    maxZoom = { 16, 192, 8 },       -- (fois la vue du monde entier)
}

local KEYS = {
    icons = true,                   -- les entrées de donjon et de raid
    boats = true,                   -- les quais des bateaux
    zeppelins = true,               -- les tours des zeppelins
    flight = true,                  -- les maîtres de vol
    routes = false,                 -- les routes des bateaux et des zeppelins
    hideWorldPinsInInstances = false,
    playerArrow = true,             -- ta flèche sur la carte
    iconsFrom = 0,
    iconScale = 1,
    darkening = 1,                  -- l'ombre des zones assombries (0..1)
    darkenColor = false,            -- sa teinte, { r, g, b } (false : l'ombre du jeu)
    foundOnly = false,              -- donjons, quais et tours seulement une fois le lieu exploré
    colorMatch = 1,                 -- les bords des zones vers les couleurs partagées
    desaturate = 0.1,
    unexplored = "show",            -- "show", "dim" ou "hide"
}
for key, default in pairs(KEYS) do Settings.Own(key, default) end
-- (fois le zoom du client : un monde de petites zones va d'autant plus loin)
Settings.Own("maxZoom", 48 * ns.Map.Data.ClientZoom())
-- (ce personnage : ses zones inexplorées à lui, s'il en a)
Settings.Own("unexploredOwn", nil)
Settings.Own("unexploredChar", nil)

-- (les jeux d'icônes de la carte et la clé qui les allume)
local SET_KEYS = { dungeons = "icons", boats = "boats", zeppelins = "zeppelins", flight = "flight", routes = "routes" }

---------------------------------------------------------------------------
-- Pour l'onglet Carte (UI/MapPage.lua)
---------------------------------------------------------------------------
function LK.Range(key)
    local r = RANGES[key]
    if not r and key == "minimapFrom" then
        -- (le zoom rapproché, Map/Close.lua jusqu'en 0.14.0)
        local mod = ns.Map.Legacy()
        r = mod and mod.MINI_FROM
    end
    if type(r) == "table" then return r[1], r[2], r[3] end
end

function LK.Default(key) return Settings.Default(key) end

function LK.HasGrade() return ns.Map.Data.HasGrade() end

-- Le zoom le plus profond
function LK.MaxZoom() return Get("maxZoom") or LK.Default("maxZoom") end
function LK.SetMaxZoom(v)
    local r = RANGES.maxZoom
    Settings.Set("maxZoom", math.max(r[1], math.min(r[2], tonumber(v) or LK.Default("maxZoom"))))
end

-- Les zones inexplorées : celles du compte, ou celles de ce personnage s'il a les siennes
function LK.UnexploredOwn() return Settings.Char("unexploredOwn") and true or false end
function LK.Unexplored()
    if LK.UnexploredOwn() then return Settings.Char("unexploredChar") or Get("unexplored") or "show" end
    return Get("unexplored") or "show"
end
function LK.SetUnexplored(v)
    if LK.UnexploredOwn() then Settings.SetChar("unexploredChar", v) else Settings.Set("unexplored", v) end
    LK.Refresh()
end
function LK.SetUnexploredOwn(on)
    -- (il part de ce qui est montré maintenant)
    if on and not LK.UnexploredOwn() then Settings.SetChar("unexploredChar", Get("unexplored")) end
    Settings.SetChar("unexploredOwn", on and true or nil)
    LK.Refresh()
end

---------------------------------------------------------------------------
-- Le dessin d'après les réglages
---------------------------------------------------------------------------
-- Dans un donjon, un raid ou un champ de bataille, les icônes du monde
-- cachées (le réglage « cachées dans les instances »)
local function InstanceHidden()
    if not Get("hideWorldPinsInInstances") then return false end
    local inside, kind = IsInInstance()
    if issecretvalue and (issecretvalue(inside) or issecretvalue(kind)) then return false end
    return inside and (kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena") or false
end

local function Apply()
    if not A.IsBuilt or not A.IsBuilt() then return end
    P.SetPlayerHidden(Get("playerArrow") == false)
    P.SetPlacesFrom(Get("iconsFrom"))
    P.SetFoundOnly(Get("foundOnly"))
    P.SetIconScale(Get("iconScale") or 1)
    if A.SetGapFillsShown then A.SetGapFillsShown(false) end   -- (les dessins de Santiago Reyes sont partis)
    if A.SetDarkening then A.SetDarkening(Get("darkening") or 1, Get("darkenColor") or nil) end
    A.ApplyGrade(Get("colorMatch"), Get("desaturate"), LK.Unexplored())
    P.SetWorldPinsHidden(InstanceHidden())
    for key, opt in pairs(SET_KEYS) do
        local set = P.Get(key)
        if set then P.SetOn(set, Get(opt)) end
    end
    if A.RefreshRoutes then A.RefreshRoutes() end
end
LK.Apply = function()
    local ok, err = pcall(Apply)
    if not ok and geterrorhandler then geterrorhandler()(err) end
end

-- Un réglage changé : le dessin, la vue, puis les calques de Plus
function LK.Refresh()
    LK.Apply()
    if ns.Map.View.Redraw then ns.Map.View.Redraw() end
    ns.Fire("MAP_REFRESH")
end

---------------------------------------------------------------------------
-- La migration : les réglages de la carte d'OpenMap, copiés une fois
---------------------------------------------------------------------------
ns.On("MAP_ATTACHED", function()
    ns.Map.Migrate("look", function(old, new, copy)
        for key in pairs(KEYS) do
            if old[key] ~= nil then new.settings[key] = copy(old[key]) end
        end
        if old.maxZoom ~= nil then new.settings.maxZoom = old.maxZoom end
    end)
    ns.Map.Migrate("lookChar", function(old, new)
        if old.unexploredOwn then new.settings.unexploredOwn = true end
        if old.unexplored ~= nil then new.settings.unexploredChar = old.unexplored end
    end, true)
end)

-- (dans une instance ou dehors : les icônes du monde cachées ou remontrées)
local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function()
    if P.Ready() then pcall(P.SetWorldPinsHidden, InstanceHidden()) end
end)
