-- Les données de la carte : ns.Map.Data, le seul accès de Plus aux tables
-- de Data/Map/ (depuis la 1.0.0 ; elles venaient de Core.lua, de
-- Data/Forever/Client.lua et de Data/Forever/Tiles.lua d'OpenMap).
--
-- Les tables elles-mêmes (root.MapPlaces, root.MapFlights...) sont tirées
-- des images et des fichiers du jeu par les outils d'OpenMap (licence MIT,
-- LICENSES/OpenMap.txt) : on les régénère, on ne les édite pas. Elles se
-- chargent avant Plus/ (le .toc) ; le chemin de leurs textures, Media/Map/,
-- est posé par Plus/Init.lua, avant elles.
local _, root = ...
local ns = root.Plus

local D = ns.Map.Data

---------------------------------------------------------------------------
-- Des lectures sûres : ce client a des valeurs secrètes (issecretvalue)
---------------------------------------------------------------------------
local Safe = {}

function Safe.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

function Safe.Value(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Le x, y d'une position : les vecteurs de Blizzard ont GetXY, mais certaines
-- fonctions de ce client rendent une simple table { x, y }
function Safe.XY(vec)
    if type(vec) ~= "table" then return end
    if vec.GetXY then return vec:GetXY() end
    return vec.x, vec.y
end

-- Des nombres simples, ni NaN ni infinis (une vue calculée pendant que la
-- carte fait 0 px de large divise par zéro : posée sur la carte, elle la
-- laissait vide jusqu'à un /reload)
function Safe.Finite(...)
    for i = 1, select("#", ...) do
        local n = select(i, ...)
        if type(n) ~= "number" or Safe.IsSecret(n) or n ~= n or n == math.huge or n == -math.huge then return false end
    end
    return true
end

-- fn(...) appelée : son premier résultat s'il est simple, sinon nil
function Safe.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    return Safe.Value(v)
end

D.Safe = Safe

---------------------------------------------------------------------------
-- Les tuiles des grottes et des cartes de donjon : celles de l'addon
-- (Media/Map/MapTile), pas celles du jeu. WoW Forever ne les donne pas dans
-- toutes les langues : certains clients (esMX, ruRU, itIT) les dessinaient en
-- carrés verts. Chaque numéro de fichier des listes de tuiles de
-- Data/Map/Caves.lua et DungeonMaps.lua est remplacé par sa copie (trouvé
-- par TextureFix d'OpenMap, de RADD95). De même pour les cartes de Gaps.lua
-- (la terre qu'aucune zone ne couvre) nommées dans GAP_ART : Gilneas.
---------------------------------------------------------------------------
local TILES = root.Media.tex .. "MapTile\\"
local GAP_ART = { Gilneas = true }

local function Swap(tiles)
    for k, fid in ipairs(tiles) do
        if type(fid) == "number" and fid ~= 0 then tiles[k] = TILES .. fid end   -- (0 : une tuile qui ne se dessine pas)
    end
end

for _, cave in pairs(root.MapCaves or {}) do
    if cave[11] then Swap(cave[11]) end
end
for _, floors in pairs(root.MapDungeonMaps or {}) do
    for _, floor in ipairs(floors) do
        if floor.tiles then Swap(floor.tiles) end
    end
end
for _, art in ipairs(root.MapGaps and root.MapGaps.art or {}) do
    if GAP_ART[art[1]] then Swap(art[4]) end
end

---------------------------------------------------------------------------
-- Les tables, une par une
---------------------------------------------------------------------------
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
-- Combien plus loin zoomer dans ce client (ses zones plus petites) ; 1 d'habitude
function D.ClientZoom() return root.ClientMaps and root.ClientMaps.zoom or 1 end
-- Les couleurs harmonisées existent pour ce client (Data/Map/Grade.lua)
function D.HasGrade() return root.MapGrade ~= nil end

-- Toutes les tables d'un coup (root.Map…), avec Safe et Media : pour le
-- dessin (Map/Art.lua) et le zoom rapproché (Map/Close.lua), qui les lisent
-- sous leurs noms d'origine (D.MapGaps, D.Media.tex...)
local all = setmetatable({ Safe = Safe, Media = root.Media }, { __index = root })
function D.All() return all end
