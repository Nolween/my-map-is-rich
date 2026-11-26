-- Les raccourcis du jeu (Raccourcis > My Map Is Rich, Bindings.xml) : me
-- localiser, poser une épingle, la liste des épingles, la plume, les
-- réglages de la carte. La carte s'ouvre d'abord si elle est fermée (pas en
-- combat : c'est le jeu qui ouvre sa carte). Depuis la 0.6.0, ils remplacent
-- ceux du menu d'OpenMap (Map/Panel.lua), qui ne répondaient plus sur la
-- carte plein écran.
local _, root = ...
local ns = root.Plus
local L = ns.L

-- (leurs noms dans la liste des raccourcis du jeu ; les globaux que le jeu cherche)
_G.BINDING_NAME_MYMAPISRICH_FIND = L.BINDING_FIND
_G.BINDING_NAME_MYMAPISRICH_PIN = L.BINDING_PIN
_G.BINDING_NAME_MYMAPISRICH_PINS = L.BINDING_PINS
_G.BINDING_NAME_MYMAPISRICH_QUILL = L.BINDING_QUILL
_G.BINDING_NAME_MYMAPISRICH_MENU = L.BINDING_MENU

local ACTIONS = {
    find = function() ns.Map.View.FindMe() end,
    pin = function() ns.Map.MyPins.SetMode(true) end,
    pins = function() ns.Map.MyPins.Toggle(true) end,
    quill = function() ns.Map.Sketch.Toggle(true) end,
}

-- (le temps que la carte s'ouvre et se recentre : Pad/MapNav.lua)
local OPEN_WAIT = 0.3

function _G.MyMapIsRich_Binding(id)
    if not (ns.db and ns.Ready()) or ns.Conflict() then return end
    if id == "menu" then
        ns.Map.Menu.Toggle()
        return
    end
    local run = ACTIONS[id]
    if not run then return end
    if ns.MapShown() then
        run()
        return
    end
    if InCombatLockdown() or not ToggleWorldMap or not ns.Risky("OpenMap") then return end
    pcall(ToggleWorldMap)
    C_Timer.After(OPEN_WAIT, function() if ns.MapShown() then run() end end)
end
