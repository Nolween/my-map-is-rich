-- L'accès de Plus à la carte : ns.Map.
--
-- Tout ce que Plus demande à la carte passe par ici, et seulement par ici :
-- la vue (où elle regarde, glisser, zoomer), le curseur, les coordonnées,
-- les icônes, les épingles, le point de destination, les vols, les citadins,
-- la plume, les donjons, les réglages de la carte.
--
-- Depuis la 0.5.0, chaque version remplace un bloc du code venu d'OpenMap
-- par le nôtre, sans que le reste de Plus ait à changer. Depuis la 0.12.0, la
-- vue (Map/View.lua), le curseur (Map/Cursor.lua), l'aspect (Map/Look.lua) et
-- les icônes des autres addons (Map/Hbd.lua) sont à nous ; restent d'OpenMap
-- le dessin de la carte et ses jeux d'icônes (MapStitch, Map/Stitch.lua, et
-- le zoom rapproché, Map/Close.lua) : ns.Map.Art et ns.Map.Pins y mènent.
-- Une fonction absente ou une erreur rendent nil : Plus ne lève pas
-- d'erreur en jeu pour la carte.
local _, root = ...
local ns = root.Plus
local L = ns.L

local M = {}
ns.Map = M

local mod, S        -- le module « worldmap » (ses sauvegardes) et MapStitch, une fois trouvés (M.Attach)

-- (les résultats d'un appel protégé, sans le « ok » ; rien sur une erreur)
local function Pass(ok, ...)
    if ok then return ... end
end
local function Get(fn, ...)
    if type(fn) ~= "function" then return end
    return Pass(pcall(fn, ...))
end
-- (vrai si l'appel a eu lieu sans erreur)
local function Run(fn, ...)
    if type(fn) ~= "function" then return false end
    return (pcall(fn, ...))
end
local function SF(name) return S and S[name] end

---------------------------------------------------------------------------
-- Cycle de vie
---------------------------------------------------------------------------
local why = L.WHY_NOT_LOADED

-- Trouver le dessin de la carte : rend vrai, ou faux et pourquoi (le texte de /mmir etat)
function M.Attach()
    if mod then return true end
    if type(root) ~= "table" or type(root.GetModule) ~= "function" then
        why = L.WHY_NO_OPENMAP
        return false, why
    end
    local ok, m = pcall(root.GetModule, root, "worldmap")
    if not ok or type(m) ~= "table" then
        why = L.WHY_NO_MODULE
        return false, why
    end
    local s = root.MapStitch
    if type(s) ~= "table" or type(s.GetPinSet) ~= "function" or type(s.Build) ~= "function" then
        why = L.WHY_NO_STITCH
        return false, why
    end
    mod, S = m, s
    why = nil
    -- (les modules de Plus posent leurs ponts vers le code d'OpenMap qui reste,
    -- et copient ce que le joueur avait : Layers/, Map/)
    ns.Fire("MAP_ATTACHED")
    return true
end

-- Le module « worldmap » d'OpenMap et MapStitch, pour les modules de Plus qui
-- répondent au code d'OpenMap qui reste (Map/Stitch.lua, Map/Close.lua,
-- Init.lua : les ponts) ; et pour /mmir sonde carte. Partira en 1.0.0.
function M.Legacy() return mod, S end

function M.Why() return why end

-- Le dessin de la carte est trouvé
function M.Ready() return mod ~= nil end

-- La vue est bâtie (à la première ouverture de la carte) et tourne
function M.ViewReady() return M.View.Built and M.View.Built() or false end
function M.Built() return M.ViewReady() end

-- La vue de la carte est là
function M.On() return M.View.On and M.View.On() or false end

-- La carte plein écran (ou réduite) de l'addon est là
function M.Full() return M.On() end

-- La carte posée réduite (une fenêtre) ou en plein écran
function M.SetSmall(on) return Run(M.View.SetSmall, on and true or false) end

-- L'interface manette de Forever est active
function M.PadUI()
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() and true or false
end

-- Mettre la vue en place (une fois : elle se bâtit à la première ouverture de la carte)
function M.Start()
    if not mod then return false end
    return Run(M.View.Start)
end

-- (depuis la 0.12.0, la vue n'attend plus rien : elle se met en place à la connexion)
function M.Waits() return false end

-- (pour /mmir etat : l'état brut de la carte)
function M.Diag()
    if not mod then return end
    return { built = M.Built(), on = M.On(), full = M.Full(), db = mod.db }
end

---------------------------------------------------------------------------
-- La vue : où elle regarde, glisser, zoomer (Map/View.lua)
---------------------------------------------------------------------------
local V = {}
M.View = V
-- La carte du jeu sous la vue (celle sur laquelle le jeu est ouvert)
function V.GameMapID()
    local map = _G.WorldMapFrame
    return map and map.GetMapID and Get(map.GetMapID, map)
end

---------------------------------------------------------------------------
-- Le curseur (Map/Cursor.lua ; sa place à l'écran : Map/View.lua)
---------------------------------------------------------------------------
local C = {}
M.Cursor = C

---------------------------------------------------------------------------
-- Le dessin de la carte d'OpenMap (MapStitch), pour le moteur de Plus
-- (Map/View.lua, Map/Look.lua, Map/Hbd.lua) jusqu'en 0.13.0 : ses fonctions
-- telles quelles (A.Build, A.Layout, A.SetView...), et ce que la vue lui donne
-- (A.GlideToWorld = ...). Le reste de Plus passe par ns.Map.Pins et Coords.
---------------------------------------------------------------------------
M.Art = setmetatable({}, {
    __index = function(_, key) return S and S[key] end,
    __newindex = function(_, key, value) if S then S[key] = value end end,
})

---------------------------------------------------------------------------
-- Les coordonnées
---------------------------------------------------------------------------
local K = {}
M.Coords = K
-- (depuis la 0.7.0, le monde, les rectangles, les yards : Map/Coords.lua)

-- (depuis la 0.10.0, l'entrée et le nom d'un donjon : Layers/Dungeons.lua)

-- Une zone est dessinée sur la carte (Map/Stitch.lua, jusqu'en 0.13.0)
function K.Stitched(mapID) return Get(SF("Stitched"), mapID) and true or false end
-- La taille du monde dessiné, en unités de l'art : largeur, hauteur (le rapport
-- des deux côtés, pour qu'un cercle de la plume soit rond à l'écran)
function K.Size() return Get(SF("Size")) end

---------------------------------------------------------------------------
-- Les icônes (les jeux d'icônes de la carte)
---------------------------------------------------------------------------
local P = {}
M.Pins = P
-- (depuis la 0.13.0, les jeux d'icônes, ta flèche, « seulement les lieux trouvés » : Map/PinSets.lua)

---------------------------------------------------------------------------
-- Les épingles du joueur
---------------------------------------------------------------------------
local E = {}
M.MyPins = E
-- (les épingles : Layers/MyPins.lua ; le mode « poser une épingle » : Layers/Locate.lua)

---------------------------------------------------------------------------
-- Le point de destination (celui du jeu, et TomTom)
---------------------------------------------------------------------------
local W = {}
M.Waypoint = W
-- (depuis la 0.9.0 : Layers/Waypoint.lua)

---------------------------------------------------------------------------
-- Les vols, les bateaux : les données de la carte
---------------------------------------------------------------------------
local D = {}
M.Data = D

-- Les maîtres de vol et leurs trajets (nodes, paths)
function D.Flights() return root.MapFlights end
-- Les lieux : entrées de donjon (instances), quais (transports), traversées
function D.Places() return root.MapPlaces end
-- Les continents (absent sur Forever)
function D.World() return root.MapWorld end
-- Les niveaux et la pêche de chaque zone ; la zone de chaque grande ville
function D.Levels() return root.MapLevels end
function D.Fishing() return root.MapFishing end
function D.CityZones() return root.MapCityZones end
-- Les cartes des donjons (celles de Blizzard, celles tirées de la minicarte)
-- et la place de leurs boss
function D.DungeonMaps() return root.MapDungeonMaps end
function D.DungeonMinimap() return root.MapDungeonMinimap end
function D.DungeonBosses() return root.MapDungeonBosses end
-- Combien plus loin zoomer dans ce client (ses zones plus petites :
-- Data/Forever/Client.lua) ; 1 d'habitude
function D.ClientZoom() return root.ClientMaps and root.ClientMaps.zoom or 1 end
-- Les couleurs harmonisées existent pour ce client (Data/Forever/Grade.lua)
function D.HasGrade() return root.MapGrade ~= nil end

local FL = {}
M.Flights = FL
-- (depuis la 0.8.0, les maîtres de vol : Layers/Flights.lua)

---------------------------------------------------------------------------
-- Les citadins (Questie), la plume, les donjons
---------------------------------------------------------------------------
local T = {}
M.Townsfolk = T
-- (depuis la 0.9.0 : Layers/Townsfolk.lua)

local SK = {}
M.Sketch = SK
-- (depuis la 0.11.0, la plume : Layers/Sketch.lua)

local DG = {}
M.Dungeons = DG
-- (depuis la 0.10.0, les entrées : Layers/Dungeons.lua ; la carte d'un
-- donjon et sa conduite à la manette : Layers/DungeonView.lua)

---------------------------------------------------------------------------
-- Les réglages de la carte : l'onglet Carte de la fenêtre /mmir (UI/MapPage.lua).
-- Depuis la 0.6.0, ils remplacent le menu et la fenêtre de réglages d'OpenMap.
---------------------------------------------------------------------------
local MN = {}
M.Menu = MN
function MN.Shown() return ns.UI and ns.UI.Shown and ns.UI.Shown("map") or false end
function MN.Open() if ns.UI and ns.UI.Show then ns.UI.Show("map") end end
function MN.Close() if MN.Shown() and ns.UI.Hide then ns.UI.Hide() end end
function MN.Toggle()
    if MN.Shown() then return MN.Close() end
    return MN.Open()
end

---------------------------------------------------------------------------
-- L'aspect de la carte : les zones inexplorées, le zoom, les curseurs
---------------------------------------------------------------------------
local LK = {}
M.Look = LK
-- (depuis la 0.12.0 : Map/Look.lua)

---------------------------------------------------------------------------
-- Les fenêtres de la carte qui ont un nom (B les ferme : Pad/Focus.lua)
---------------------------------------------------------------------------
local WINDOWS = {
    "MyMapIsRichPins", "MyMapIsRichPinEditor", "MyMapIsRichPinsCode",
}
function M.Windows()
    local out = {}
    for _, name in ipairs(WINDOWS) do
        local f = _G[name]
        if f then out[#out + 1] = f end
    end
    return out
end

-- « MAP_BUILT » : la carte est dessinée (à sa première ouverture), une fois ;
-- les modules de Plus y posent leurs jeux d'icônes (Map/View.lua le lance)
function M.IsBuilt() return M.ViewReady() end
