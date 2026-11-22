-- R3 sur une quête de la liste de droite (le journal de quêtes de la carte
-- réduite) : un itinéraire jusqu'à cette quête. R3 de nouveau sur la quête
-- du trajet en cours l'annule.
--
-- La quête : le bouton qui a le focus de l'interface manette
-- (SmartNavigation:GetCurrentButton, comme le lit Baganator), une ligne du
-- journal (titre ou objectif) qui porte son questID. Quand le détail d'une
-- quête est ouvert, c'est la quête affichée.
--
-- Son emplacement, d'après le jeu, comme le fait Shortest Path Forever
-- (Journey/JourneyInput.lua et Routing/QuestDestination.lua, de cjber,
-- GPL-3.0-or-later) :
--   - ses points sur la carte (C_QuestLog.GetQuestsOnMap) : la zone de
--     l'objectif, ou le donneur à qui la rendre quand elle est terminée ;
--   - à défaut, son prochain point de passage (C_QuestLog.GetNextWaypoint),
--     quand l'objectif est dans une autre zone ;
--   - en dernier, son point de départ, seul connu de certaines quêtes.
--
-- Le contexte « questlog » prend R3 par un raccourci (Pad/Bindings.lua),
-- tant que le focus est dans le journal de quêtes et que le curseur n'est
-- pas sur la carte : là, le jeu fait de R3 un ping (« Impossible d'envoyer
-- un ping pour ça »), qu'un bouton seulement lu laissait passer. Sur un
-- en-tête, R3 ne fait donc rien.
local _, root = ...
local ns = root.Plus
local L = ns.L
local P = ns.Pad
local Pl = ns.TravelPlanner

local Q = {}
ns.TravelQuests = Q

local NONE = {}
local DEPTH = 3              -- parents regardés au-dessus du bouton qui a le focus
local UNDER = 15             -- parents regardés pour savoir s'il est dans la carte

-- (une valeur secrète du jeu ne sert à rien : nil)
local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local results = { pcall(fn, ...) }
    if not results[1] then return end
    return unpack(results, 2)
end

---------------------------------------------------------------------------
-- La quête qui a le focus de la manette
---------------------------------------------------------------------------
local function QuestIDOf(f)
    local id = Plain(f.questID)
    if type(id) == "number" and id > 0 then return id end
    if type(f.GetQuestID) == "function" then
        id = Plain(Call(f.GetQuestID, f))
        if type(id) == "number" and id > 0 then return id end
    end
end

local function Inside(f, root)
    for _ = 1, UNDER do
        if not f then return false end
        if f == root then return true end
        f = f.GetParent and f:GetParent()
    end
    return false
end

-- Le bouton qui a le focus de l'interface manette, s'il est dans `root`
local function Current(root)
    local nav = _G.SmartNavigation
    if not (nav and root and type(nav.GetCurrentButton) == "function") then return end
    local button = Call(nav.GetCurrentButton, nav)
    if type(button) ~= "table" or type(button.GetParent) ~= "function" then return end
    if Inside(button, root) then return button end
end

-- Le focus est-il dans le journal de quêtes de la carte ?
function Q.InLog()
    return Current(_G.QuestMapFrame) ~= nil
end

-- La quête sous le focus de la manette, dans le journal de la carte (nil :
-- le focus est ailleurs, sur un en-tête, ou le jeu ne le dit pas)
function Q.Focused()
    local map = _G.WorldMapFrame
    local button = Current(map)
    if not button then return end
    -- (la ligne d'une quête : son titre, ou un de ses objectifs)
    local f = button
    for _ = 1, DEPTH do
        local id = QuestIDOf(f)
        if id then return id end
        f = f:GetParent()
        if not f or f == map or f == _G.QuestMapFrame then break end
    end
    -- (le détail d'une quête ouvert : la quête affichée)
    local qmf = _G.QuestMapFrame
    local details = qmf and qmf.DetailsFrame
    if details and details:IsShown() and Inside(button, qmf) then
        local id = Plain(Call(_G.QuestMapFrame_GetDetailQuestID))
        if type(id) == "number" and id > 0 then return id end
    end
end

---------------------------------------------------------------------------
-- Où aller pour une quête
---------------------------------------------------------------------------
local function Valid(mapID, x, y)
    return type(mapID) == "number" and mapID > 0 and type(x) == "number" and type(y) == "number"
        and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

-- Les points d'une quête sur une carte (ceux de GetQuestsOnMap : x, y sont
-- ceux de la carte demandée)
local function POIs(questID, mapID)
    if type(mapID) ~= "number" or mapID <= 0 or not C_QuestLog.GetQuestsOnMap then return end
    local list = Call(C_QuestLog.GetQuestsOnMap, mapID)
    for _, poi in ipairs(type(list) == "table" and list or NONE) do
        if Plain(poi.questID) == questID then return list end
    end
end

-- Le point d'une quête : { cont, x, y, map, mx, my, title, questID }, ou
-- nil ; et son titre
function Q.Point(questID)
    if not C_QuestLog then return end
    local title = Plain(Call(C_QuestLog.GetTitleForQuestID, questID))
    local complete = Plain(Call(C_QuestLog.IsComplete, questID)) and true or false
    -- (la carte de la quête : celle de ses points, sinon celle de son point de passage)
    local mapID = Plain(Call(_G.GetQuestUiMapID, questID, true))
    if type(mapID) ~= "number" or mapID <= 0 then mapID = Plain(Call(_G.GetQuestUiMapID, questID, false)) end
    -- (une quête dont seul le départ a un point peut n'avoir aucune carte : celle du joueur)
    local pois = POIs(questID, mapID)
    if not pois then
        local here = C_Map and Plain(Call(C_Map.GetBestMapForUnit, "player"))
        pois = POIs(questID, here)
        if pois then mapID = here end
    end
    local dest, start
    for _, poi in ipairs(pois or NONE) do
        if Plain(poi.questID) == questID then
            local x, y = Plain(poi.x), Plain(poi.y)
            if Valid(mapID, x, y) then
                if not Plain(poi.isQuestStart) then
                    dest = { mapID, x, y }
                    break
                end
                start = start or { mapID, x, y }
            end
        end
    end
    -- (le point de passage : l'objectif est dans une autre zone ; une quête
    -- terminée garde plutôt son point, le donneur)
    if not complete or not dest then
        local wMap, wx, wy = Call(C_QuestLog.GetNextWaypoint, questID)
        wMap, wx, wy = Plain(wMap), Plain(wx), Plain(wy)
        if Valid(wMap, wx, wy) then dest = { wMap, wx, wy } end
    end
    dest = dest or start
    if not dest then return nil, title end
    local point = Pl.WorldOf(dest[1], dest[2], dest[3])
    if not point then return nil, title end
    point.title = (title and title ~= "") and title or nil
    point.questID = questID
    return point, title
end

---------------------------------------------------------------------------
-- R3 sur la liste
---------------------------------------------------------------------------
local function Detect()
    if not (ns.db and ns.db.options.travel) then return false end
    if ns.MapNav.CursorOnMap() then return false end
    return Q.InLog()
end

P.DefineContext("questlog", 20, Detect)
-- (RT : les quêtes de la carte plein écran, comme sur la carte seule — le
-- jeu met souvent la manette dans son journal, caché sous la carte plein
-- écran, en l'ouvrant : UI/QuestPanel.lua)
P.SetAction("questlog", "PADRTRIGGER", function()
    if ns.FullMap() and ns.QuestPanel then ns.QuestPanel.PadMenu() end
end, function()
    if not ns.FullMap() then return nil end
    return "HINT_QUESTS"
end)
P.SetAction("questlog", "PADRSTICK", function()
    local questID = Q.Focused()
    if questID and ns.Travel then ns.Travel.AtQuest(questID) end
end, function()
    local focused = Q.Focused()
    if not focused then return nil end
    local goal = ns.Travel and ns.Travel.Goal()
    if goal and goal.questID == focused then return "HINT_TRAVEL_CANCEL" end
    return "HINT_TRAVEL_QUEST"
end)
