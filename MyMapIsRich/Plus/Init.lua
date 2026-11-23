-- Le début de My Map Is Rich : chargé le premier (le .toc).
--
-- L'espace de noms de l'addon (root, le « ... » de chaque fichier) ne porte
-- plus que les données de la carte (root.MapPlaces, root.MapFlights... :
-- Data/Map/) et Plus, tout le code de l'addon (root.Plus). Chaque fichier de
-- Plus commence par « local _, root = ... ; local ns = root.Plus ». Plus lit
-- les données par ns.Map.Data seulement (Map/Data.lua).
-- (Le nom « Plus » vient de la moitié reprise d'OpenMap On Gamepad ; depuis la
-- 1.0.0, il n'y a plus de code d'OpenMap à côté.)
local ADDON, root = ...
root.Plus = root.Plus or {}

-- Le chemin des textures de la carte (Media/Map/), dont les données ont
-- besoin dès leur chargement (Data/Map/CaveMinimap.lua, DungeonMinimap.lua)
root.Media = { path = "Interface\\AddOns\\" .. ADDON .. "\\Media\\" }
root.Media.tex = root.Media.path .. "Map\\"

-- (accès global : _G.MyMapIsRich.Plus, lu par My Gamepad Is Rich, débogage)
_G.MyMapIsRich = root
