-- L'accès de Plus à la carte : ns.Map.
--
-- Tout ce que Plus demande à la carte passe par ici, et seulement par ici :
-- la vue (où elle regarde, glisser, zoomer), le curseur, les coordonnées,
-- les icônes, les épingles, le point de destination, les vols, les citadins,
-- la plume, les donjons, les réglages de la carte.
--
-- Depuis la 0.5.0, ces fonctions appellent encore le code venu d'OpenMap
-- (le module « worldmap » et MapStitch, dans Map/) ; chaque version suivante
-- en remplace un bloc par notre propre code, sans que le reste de Plus ait à
-- changer. Chaque fonction cherche la fonction d'OpenMap au moment de
-- l'appel : celles de la vue (Map/PadView.lua) ne naissent qu'une fois la
-- carte bâtie, on n'en garde donc jamais de copie. Une fonction absente ou
-- une erreur rendent nil : Plus ne lève pas d'erreur en jeu pour la carte.
local _, root = ...
local ns = root.Plus
local L = ns.L

local M = {}
ns.Map = M

local mod, S        -- le module « worldmap » et MapStitch, une fois trouvés (M.Attach)

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
local function F(name) return mod and mod[name] end
local function SF(name) return S and S[name] end

---------------------------------------------------------------------------
-- Cycle de vie
---------------------------------------------------------------------------
-- (ce dont Plus a besoin dès le chargement ; une seule absente et l'addon
-- reste en veille plutôt que de lever des erreurs en jeu)
local NEEDED = { "PadUI", "SetPadView" }
-- (celles de la vue, qui n'existent qu'une fois la carte bâtie : M.ViewReady)
local VIEW_NEEDED = { "PadViewOn", "Glide", "ViewNow", "CursorWorld", "PadCursorXY", "PadControlAt" }

local why = L.WHY_NOT_LOADED

-- Trouver la carte : rend vrai, ou faux et pourquoi (le texte de /mmir etat)
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
    if type(s) ~= "table" or type(s.GetPinSet) ~= "function" then
        why = L.WHY_NO_STITCH
        return false, why
    end
    local missing = {}
    for _, name in ipairs(NEEDED) do
        if type(m[name]) ~= "function" then missing[#missing + 1] = name end
    end
    if #missing > 0 then
        why = L.WHY_MISSING:format(table.concat(missing, ", "))
        return false, why
    end
    mod, S = m, s
    why = nil
    -- (la carte se redessine, le mode épingle change : prévenir Plus)
    if type(mod.Refresh) == "function" then
        hooksecurefunc(mod, "Refresh", function() ns.Fire("MAP_REFRESH") end)
    end
    -- (les modules de Plus qui remplacent ceux d'OpenMap posent leurs ponts : Layers/MyPins.lua)
    ns.Fire("MAP_ATTACHED")
    return true
end

-- Le module « worldmap » d'OpenMap et MapStitch, pour les modules de Plus qui
-- en remplacent un morceau et doivent répondre à l'ancien code qui reste
-- (les ponts : mod.RefreshPins, mod.PinAt...) ; et pour /mmir sonde carte.
-- Rien d'autre ne s'en sert : tout le reste passe par ns.Map. Partira en 1.0.0.
function M.Legacy() return mod, S end

function M.Why() return why end

-- La carte est trouvée et compatible
function M.Ready() return mod ~= nil end

-- Les fonctions de la vue sont là : la carte est bâtie et tourne
function M.ViewReady()
    if not mod then return false end
    for _, name in ipairs(VIEW_NEEDED) do
        if type(mod[name]) ~= "function" then return false end
    end
    return true
end

-- La carte est bâtie (une fois pour toutes)
function M.Built() return Get(F("PadViewBuilt")) and true or false end

-- La vue de la carte est là et montrée
function M.On() return Get(F("PadViewOn")) and true or false end

-- La carte plein écran (ou réduite) de l'addon est là
function M.Full() return Get(F("ViewFull")) and true or false end

-- La carte posée réduite (une fenêtre) ou en plein écran
function M.SetSmall(on) return Run(F("ViewSetSmall"), on and true or false) end

-- L'interface manette de Forever est active
function M.PadUI()
    if mod and mod.PadUI then
        local ok, on = pcall(mod.PadUI)
        if ok then return on end
    end
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() or false
end

-- Lancer la vue de la carte si elle attend (hors combat)
function M.Start()
    if not mod or InCombatLockdown() then return false end
    if mod.padWaits and not M.Built() then return Run(mod.SetPadView, true) end
    return false
end

-- La carte attend sa vue (le chemin plein écran a été pris)
function M.Waits() return mod and mod.padWaits and true or false end

-- (pour /mmir etat : l'état brut de la carte)
function M.Diag()
    if not mod then return end
    return {
        enabled = mod.enabled, padWaits = mod.padWaits, built = M.Built(), on = M.On(), full = M.Full(),
        db = mod.db,
    }
end

---------------------------------------------------------------------------
-- La vue : où elle regarde, glisser, zoomer
---------------------------------------------------------------------------
local V = {}
M.View = V

-- Le cadre de la vue (l'habillage, la barre d'aide, les lieux s'y posent)
function V.Frame() return Get(F("ViewFrame")) end

-- La strate des cadres posés sur la vue
function V.Strata() return mod and mod.viewStrata end

-- Où elle regarde : u, v (le monde, 0..1) et le zoom (1 : le monde entier)
function V.Now() return Get(F("ViewNow")) end

-- Glisser jusqu'à u, v (et un zoom), ou s'y poser tout de suite
function V.Glide(u, v, zoom) return Run(F("Glide"), u, v, zoom) end
function V.Show(u, v, zoom) return Run(F("ShowNow"), u, v, zoom) end

-- Glisser jusqu'à montrer tout un rectangle du monde (fill : la part de la vue)
function V.GlideToRect(u0, v0, u1, v1, fill) return Run(SF("GlideToRect"), u0, v0, u1, v1, fill) end

-- Le zoom qui montre toute une carte du jeu
function V.FitZoom(mapID) return Get(F("FitZoom"), mapID) end

-- La moitié de la vue, en unités du monde, à ce zoom
function V.HalfExtents(zoom) return Get(F("ViewHalfExtents"), zoom) end

-- Garder un point du monde sous l'anneau doré (la fiche d'une icône)
function V.Offset(u, v) return Get(F("ViewOffset"), u, v) end

-- Le lieu au centre : son nom, la pêche, le continent
function V.Place() return Get(F("ViewPlace")) end

function V.Animating() return Get(F("Animating")) and true or false end
function V.Zooming() return Get(F("Zooming")) and true or false end

-- (me localiser : Layers/Locate.lua, depuis la 0.9.0)

-- La zone d'une quête mise en valeur (nil : plus aucune)
function V.QuestArea(questID, mapID) return Run(F("PadQuestArea"), questID, mapID) end
-- La quête suivie (celle du jeu) : son icône dorée et sa zone quand rien d'autre n'est survolé
function V.QuestFocus(questID, mapID) return Run(F("PadQuestFocus"), questID, mapID) end
-- La carte du jeu sous la vue (celle sur laquelle le jeu est ouvert)
function V.GameMapID()
    local map = _G.WorldMapFrame
    return map and map.GetMapID and Get(map.GetMapID, map)
end

-- Ce que Plus fait d'un clic sur la carte, du X de la manette, d'une icône
-- choisie ; et l'habillage de Plus à la place du nom de zone de la carte
function V.SetClickHandler(fn) if mod then mod.OnViewClick = fn end end
function V.SetOutHandler(fn) if mod then mod.OnViewOut = fn end end
function V.SetPressHandler(fn) if mod then mod.OnPinPress = fn end end
function V.SetChrome(on) if mod then mod.viewChrome = on and true or nil end end

---------------------------------------------------------------------------
-- Le curseur
---------------------------------------------------------------------------
local C = {}
M.Cursor = C

-- Le curseur de la manette sur l'écran (x, y), s'il est sur la carte
function C.XY() return Get(F("PadCursorXY")) end

-- Le point du monde sous le curseur : u, v
function C.World() return Get(F("CursorWorld")) end

-- Le stick du curseur
function C.Stick() return Get(F("PadCursorStick")) end

-- Le cadre sous un point de l'écran, celui que A presserait
function C.ControlAt(x, y) return Get(F("PadControlAt"), x, y) end

-- Donner un cadre au curseur de la manette (A le presse)
function C.AddRoot(f)
    local roots = mod and mod.padRoots
    if type(roots) == "table" and f then table.insert(roots, f) end
end

-- Les cadres donnés au curseur
function C.Roots()
    local roots = mod and mod.padRoots
    return type(roots) == "table" and roots or nil
end

---------------------------------------------------------------------------
-- Les coordonnées
---------------------------------------------------------------------------
local K = {}
M.Coords = K
-- (depuis la 0.7.0, le monde, les rectangles, les yards : Map/Coords.lua)

-- (depuis la 0.10.0, l'entrée et le nom d'un donjon : Layers/Dungeons.lua)

-- Une zone est dessinée sur la carte (Map/Stitch.lua, jusqu'en 0.13.0)
function K.Stitched(mapID) return Get(SF("Stitched"), mapID) and true or false end

---------------------------------------------------------------------------
-- Les icônes (les jeux d'icônes de la carte)
---------------------------------------------------------------------------
local P = {}
M.Pins = P

-- La carte est dessinée : on peut y poser des icônes
function P.Ready() return Get(SF("IsBuilt")) and true or false end

-- Un jeu d'icônes à soi (créé une fois), ou celui d'un calque
function P.Set(key, minZoom, level) return Get(SF("PinSet"), key, minZoom, level) end
function P.Get(key) return Get(SF("GetPinSet"), key) end
function P.Clear(set) return Run(SF("ClearPinSet"), set) end
-- Une icône déplacée, ou retirée de son jeu
function P.Move(set, pin, u, v) return Run(SF("MovePin"), set, pin, u, v) end
function P.Remove(set, pin) return Run(SF("RemovePin"), set, pin) end
-- Un jeu d'icônes montré ou caché
function P.SetOn(set, on) return Run(SF("SetPinSetOn"), set, on and true or false) end
-- Un point simple (une texture, pas un bouton : les routes en ont des centaines)
function P.Dot(set, u, v, size, look, r, g, b, a, parent) return Get(SF("AddDot"), set, u, v, size, look, r, g, b, a, parent) end
-- Ce que le jeu d'icônes construit la première fois qu'il se montre
function P.SetBuild(set, fn) if type(set) == "table" then set.build = fn end end
-- fn(u, v, hu, hv, zoom) à chaque déplacement ou zoom de la vue
function P.OnView(fn)
    if S and type(S.viewHooks) == "table" then table.insert(S.viewHooks, fn) end
end

-- Les icônes des jeux nommés dont le calque est montré (une liste de cadres ;
-- à chacun de voir lesquelles sont visibles à l'écran)
function P.Shown(keys)
    local out = {}
    for _, key in ipairs(keys or {}) do
        local set = P.Get(key)
        if type(set) == "table" and set.frame and set.frame:IsVisible() and type(set.pins) == "table" then
            for _, pin in ipairs(set.pins) do out[#out + 1] = pin end
        end
    end
    return out
end

-- Une icône, un trait
function P.Add(set, u, v, look, data) return Get(SF("AddPin"), set, u, v, look, data) end
function P.Line(set, u1, v1, u2, v2, thickness, r, g, b, a, texture)
    return Get(SF("AddLine"), set, u1, v1, u2, v2, thickness, r, g, b, a, texture)
end

-- Ce que fait une icône quand on la choisit (celle de la carte)
function P.Action(pin) return Run(F("PinAction"), pin) end

-- « Seulement les lieux trouvés » : ce qui est trouvé, revu (un donjon où
-- l'on vient d'entrer)
function P.RefreshFound() return Run(SF("RefreshFound")) end

-- La sorte d'une icône : "dungeon" (une entrée), "flight" (un maître de
-- vol), "action" (une icône qui fait quelque chose quand on la choisit), ou
-- nil. Remplacera les devinettes sur les champs des icônes d'OpenMap.
function P.Kind(pin)
    if type(pin) ~= "table" then return end
    -- (pas pin.kind : les quais de Map/Stitch.lua y mettent « boat » ou « zeppelin »)
    if pin.instances then return "dungeon" end
    if pin.node then return "flight" end
    if pin.OnClick then return "action" end
end

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
function SK.Toggle(on) return Run(F("ToggleSketch"), mod, on) end
function SK.Drawing() return Get(F("IsSketching"), mod) and true or false end
function SK.Available() return F("ToggleSketch") ~= nil end
-- Les dessins attachés à une épingle (Map/Sketch.lua, jusqu'en 0.11.0) : combien,
-- dessiner sur elle (la barre de la plume sous dock), l'épingle en cours, effacer les siens
function SK.Count(pinId) return Get(F("SketchCount"), pinId) or 0 end
function SK.ForPin(pin, dock) return Run(F("ToggleSketch"), mod, true, pin, dock) end
function SK.Pin() return Get(F("SketchPin")) end
function SK.Drop(pinId) return Run(F("DropSketches"), pinId) end
function SK.Redraw() return Run(F("RefreshSketch")) end
-- Les traits de la plume sur la carte d'un donjon (mod.db.sketch.dungeons,
-- par mapID de l'instance ; make : la table créée s'il n'y en a pas), sa
-- couleur d'encre, « Tes dessins » montrés, et la plume prévenue d'un trait
function SK.DungeonStrokes(key, make)
    local sk = mod and mod.db and mod.db.sketch
    if not (sk and key) then return end
    if make then
        sk.dungeons = sk.dungeons or {}
        sk.dungeons[key] = sk.dungeons[key] or {}
    end
    return sk.dungeons and sk.dungeons[key]
end
function SK.Ink() return Get(F("SketchInk")) end
function SK.Shown() return not (mod and mod.db and mod.db.sketchShown == false) end
function SK.Changed() return Run(F("OnSketchChanged")) end

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
-- Les zones inexplorées : "show", "dim" (assombries) ou "hide"
function LK.Unexplored() return Get(F("Unexplored")) or "show" end
function LK.SetUnexplored(v) return Run(F("SetUnexplored"), v) end
-- ... réglées pour ce personnage seulement
function LK.UnexploredOwn() return mod and mod.char and mod.char.unexploredOwn and true or false end
function LK.SetUnexploredOwn(on) return Run(F("SetUnexploredOwn"), on and true or false) end
-- Le zoom le plus profond (les niveaux de zoom suivent)
function LK.SetMaxZoom(v) return Run(F("SetMaxZoom"), v) end
-- Les bornes d'un curseur de la carte : le plus petit, le plus grand, le pas
local RANGES = { maxZoom = "MAX_ZOOM", iconsFrom = "ICONS_FROM", iconScale = "ICON_SCALE", minimapFrom = "MINI_FROM" }
function LK.Range(key)
    local t = mod and RANGES[key] and mod[RANGES[key]]
    if type(t) == "table" then return t[1], t[2], t[3] end
end
-- La valeur d'origine d'un réglage de la carte
function LK.Default(key) return mod and mod.defaults and mod.defaults[key] end
-- Les couleurs harmonisées existent pour ce client (Data/Forever/Grade.lua)
function LK.HasGrade() return root.MapGrade ~= nil end

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

---------------------------------------------------------------------------
-- « MAP_BUILT » : la carte est dessinée (à sa première ouverture), une fois ;
-- les modules de Plus y posent leurs jeux d'icônes
---------------------------------------------------------------------------
local builtFired = false
local function WatchBuilt(tries)
    if builtFired or not mod then return end
    if P.Ready() then
        builtFired = true
        ns.Fire("MAP_BUILT")
    elseif tries < 60 then
        C_Timer.After(0.25, function() WatchBuilt(tries + 1) end)
    end
end
ns.On("MAP_SHOW", function() WatchBuilt(0) end)
function M.IsBuilt() return builtFired end
