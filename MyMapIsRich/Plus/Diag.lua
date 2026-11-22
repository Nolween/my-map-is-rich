-- Diagnostic : /mmir etat (où en est l'addon) et /mmir sonde (à lancer carte
-- ouverte : ce que chaque bouton de la manette fait sur la carte du jeu, sans
-- les raccourcis de l'addon, et les fenêtres d'OpenMap ouvertes).
local _, root = ...
local ns = root.Plus
local L = ns.L
local P = ns.Pad
local F = ns.Focus

local Diag = {}
ns.Diag = Diag

local function YesNo(v) return v and ("|cff40ff40" .. L.YES .. "|r") or ("|cffff7060" .. L.NO .. "|r") end

local function Meta(addon, field)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if not get then return nil end
    local ok, v = pcall(get, addon, field)
    return ok and v or nil
end

function Diag.Status()
    local mod = ns.mod
    ns.Print(L.STATUS_HEAD, ns.VERSION, "0.8.11")
    ns.Print(L.STATUS_OPENMAP, YesNo(ns.Ready()), ns.Why() or "")
    ns.Print(L.STATUS_PADUI, YesNo(ns.PadUI()))
    ns.Print(L.STATUS_PADVIEW, YesNo(mod and mod.db and mod.db.padView), YesNo(ns.ViewReady()),
        YesNo(ns.MapShown() and ns.ViewOn()))
    ns.Print(L.STATUS_CONTEXT, P.current or L.NONE)
    if not P.current then
        local why = P.WhyNone()
        if why then ns.Print("  -> %s", L[why]) end
    end
    if P.current then
        local lost = P.Lost()
        if #lost > 0 then ns.Print(L.PROBE_LOSES, table.concat(lost, ", ")) end
    end
    if P.gaveUp then ns.Print(L.STATUS_GAVE_UP) end
    local mgir = _G.MyGamepadIsRich
    if type(mgir) == "table" then
        local steps = type(mgir.Focus) == "table" and type(mgir.Focus.InGame) == "function"
        ns.Print(L.STATUS_MGIR, YesNo(true), YesNo(steps))
    end
    if mod and mod.padWaits and not ns.ViewReady() then ns.Print(L.STATUS_RELOAD) end
    -- (les maîtres de vol qu'OpenMap retient pour ce personnage, et s'il les écoute : Core.lua, EnsureFlights)
    local learned, count = mod and mod.char and mod.char.flightsKnown, 0
    if type(learned) == "table" then
        for _ in pairs(learned) do count = count + 1 end
    end
    ns.Print(L.STATUS_FLIGHTS, count, YesNo(ns.FlightsTracked()))
    -- (les vibrations d'un itinéraire : le jeu les permet-il ? Pad/Rumble.lua)
    local RB = ns.Rumble
    ns.Print(L.STATUS_RUMBLE, YesNo(RB and RB.Available()), YesNo(ns.db.options.travelRumble ~= false))
end

-- (les noms longs raccourcis : « forever: », « addon: », « mgir: »)
local function Short(action)
    return (action:gsub("^CLICK InputFunctionBindingButton_", "forever:")
        :gsub("^CLICK MyMapIsRichPlusPad", "addon:")
        :gsub("^CLICK MyGamepadIsRich", "mgir:")
        :gsub(":LeftButton$", ""))
end

-- /mmir focus : à qui la manette appartient sur la carte (le curseur du jeu,
-- le focus de la carte, l'état de l'interface manette), et les fonctions que
-- le jeu donne pour ça (pour comprendre ce que fait l'interface manette)
local function Try(obj, method, ...)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then return "-" end
    local ok, a = pcall(obj[method], obj, ...)
    if not ok then return "err" end
    return tostring(a)
end

local function Names(t, pattern)
    local out = {}
    if type(t) ~= "table" then return "-" end
    local seen = {}
    local function Add(k)
        if type(k) == "string" and not seen[k] and (not pattern or k:find(pattern)) then
            seen[k] = true
            out[#out + 1] = k
        end
    end
    for k, v in pairs(t) do if type(v) == "function" then Add(k) end end
    local mt = getmetatable(t)
    if type(mt) == "table" and type(mt.__index) == "table" then
        for k, v in pairs(mt.__index) do if type(v) == "function" then Add(k) end end
    end
    table.sort(out)
    return #out > 0 and table.concat(out, ", ") or "-"
end

function Diag.Focus(withApi)
    local map = _G.WorldMapFrame
    local soft = _G.SoftCursor
    local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    ns.Print(L.FOCUS_HEAD)
    ns.Print("  carte ouverte : %s · vue manette My Map Is Rich : %s · contexte : %s%s", tostring(ns.MapShown()),
        tostring(ns.ViewOn()), P.current or L.NONE, P.gaveUp and " (abandon)" or "")
    ns.Print("  SoftCursor : %s · affiché : %s", tostring(soft ~= nil), tostring(soft and soft:IsShown() or false))
    ns.Print("  carte IsCanvasGamepadFocus : %s", Try(map, "IsCanvasGamepadFocus"))
    -- (où la carte du jeu met la manette : la carte ou son journal ; le journal ouvert ou non)
    ns.Print("  carte IsMapFocused : %s · IsQuestFocused : %s · IsSidePanelShown : %s", Try(map, "IsMapFocused"),
        Try(map, "IsQuestFocused"), Try(map, "IsSidePanelShown"))
    -- (la fiche d'une quête : les fonctions de lecture du journal trouvées, et
    -- ce qu'elles disent de la quête choisie, UI/QuestPanel.lua)
    if ns.QuestPanel and ns.QuestPanel.Probe then
        local ok, line = pcall(ns.QuestPanel.Probe)
        ns.Print("  journal : %s", ok and line or tostring(line))
    end
    ns.Print("  InputBindingManager : %s · IsOnlyCoreBindingSetActive : %s", tostring(manager ~= nil),
        Try(manager, "IsOnlyCoreBindingSetActive"))
    local mod = ns.mod
    local x, y
    if mod and mod.PadCursorXY then
        local ok, a, b = pcall(mod.PadCursorXY)
        if ok then x, y = a, b end
    end
    ns.Print("  curseur My Map Is Rich : %s", x and ("%.0f, %.0f"):format(x, y) or L.NONE)
    for _, key in ipairs({ "PAD1", "PAD2", "PADDRIGHT", "PADLSHOULDER" }) do
        local ok, action = pcall(GetBindingAction, key, true)
        ns.Print("  %s : %s", key, (ok and action and action ~= "") and Short(action) or L.NONE)
    end
    ns.Print("  pile de l'interface manette (PeekName) : %s", Try(manager, "PeekName"))
    -- (le bouton qui a le focus de la manette, et la quête qu'il porte :
    -- R3 sur une quête de la liste, Travel/Quests.lua)
    local nav = _G.SmartNavigation
    local okB, button = false, nil
    if nav and type(nav.GetCurrentButton) == "function" then okB, button = pcall(nav.GetCurrentButton, nav) end
    local bName = L.NONE
    if okB and type(button) == "table" then
        bName = (button.GetName and button:GetName()) or (button.GetDebugName and button:GetDebugName()) or tostring(button)
    end
    local quest = ns.TravelQuests and ns.TravelQuests.Focused()
    ns.Print("  SmartNavigation : %s · quête : %s · curseur sur la carte : %s", tostring(bName),
        quest and tostring(quest) or L.NONE, tostring(ns.MapNav and ns.MapNav.CursorOnMap() or false))
    if withApi then
        ns.Print("  carte, Gamepad : %s", Names(map, "[Gg]amepad"))
        ns.Print("  carte, Focus : %s", Names(map, "Focus"))
        ns.Print("  carte, Canvas : %s", Names(map, "Canvas"))
        ns.Print("  GamepadSharedUtility : %s", Names(GamepadSharedUtility))
        local footer = map and map.worldMapFooter
        ns.Print("  pied de la carte : %s", Names(footer))
    end
end

-- /mmir focus ouverture : le même relevé, pris tout seul à la prochaine
-- ouverture de la carte (une demi-seconde, puis deux secondes après), sans
-- rien taper : taper la commande met la manette dans la discussion
local armed = false

function Diag.ArmOpenFocus()
    armed = true
    ns.Print(L.FOCUS_ARMED)
end

ns.On("MAP_SHOW", function()
    if not armed then return end
    armed = false
    C_Timer.After(0.5, function() Diag.Focus(true) end)
    C_Timer.After(2, function() Diag.Focus(false) end)
end)

-- Les boutons de la manette sur la carte : l'action du jeu (ou d'un addon)
local PROBE_KEYS = {
    "PAD1", "PAD2", "PAD3", "PAD4", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
    "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER",
    "PADLSTICK", "PADRSTICK", "PADBACK", "PADFORWARD", "PADSOCIAL",
}

function Diag.Probe()
    if not ns.MapShown() then
        ns.Print(L.PROBE_OPEN_MAP)
        return
    end
    if InCombatLockdown() then
        ns.Print(L.PROBE_COMBAT)
        return
    end
    -- (sans nos raccourcis le temps de lire : ceux du jeu ; reposés juste après)
    local had = P.current
    if P.Release then P.Release() end
    ns.Print(L.PROBE_HEAD)
    for _, key in ipairs(PROBE_KEYS) do
        local ok, action = pcall(GetBindingAction, key, true)
        ns.Print("  %s : %s", key, (ok and action and action ~= "") and Short(action) or ("|cff8a8070" .. L.NONE .. "|r"))
    end
    for _, cvar in ipairs({ "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt", "GamePadCursorLeftClick", "GamePadCursorRightClick" }) do
        local get = (C_CVar and C_CVar.GetCVar) or GetCVar
        local okV, value = pcall(get, cvar)
        ns.Print("  %s = %s", cvar, okV and tostring(value) or "?")
    end
    local top = F and F.Top()
    ns.Print(L.PROBE_WINDOW, top and (top:GetName() or tostring(top)) or L.NONE)
    if had then ns.Print(L.PROBE_HAD, had) end
    P.Dirty()
    -- (une demi-seconde après : nos raccourcis sont-ils repassés devant ceux
    -- de l'interface manette ?)
    C_Timer.After(0.5, function()
        if not P.current then
            ns.Print(L.PROBE_NOT_BOUND)
            return
        end
        local lost = P.Lost()
        if #lost == 0 then
            ns.Print(L.PROBE_WINS, P.current)
        else
            ns.Print(L.PROBE_LOSES, table.concat(lost, ", "))
        end
    end)
end

---------------------------------------------------------------------------
-- /mmir test : carte ouverte, quels boutons de la manette font perdre son
-- curseur à la carte quand un addon y pose un raccourci. Pour chaque groupe,
-- un raccourci factice (vers un bouton qui ne fait rien) est posé, le focus
-- de la carte lu 0,6 s après, le raccourci retiré, et le focus relu 0,6 s
-- après. L'addon ne prend rien pendant le test (P.suspended). Ne touche pas
-- la manette pendant les quelques secondes du test.
---------------------------------------------------------------------------
local TEST_GROUPS = {
    { "A B X", { "PAD1", "PAD2", "PAD3" } },
    { "+", { "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" } },
    { "Y", { "PAD4" } },
    { "LB RB", { "PADLSHOULDER", "PADRSHOULDER" } },
    { "LT RT", { "PADLTRIGGER", "PADRTRIGGER" } },
    { "View", { "PADBACK" } },
}
local TEST_WAIT = 0.6

local testOwner = CreateFrame("Frame")
local testButton = CreateFrame("Button", "MyMapIsRichPlusTestButton", UIParent)
testButton:SetSize(1, 1)
testButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
local testing = false

local function HasCursor()
    local soft = _G.SoftCursor
    if soft and soft:IsShown() then return true end
    local map = _G.WorldMapFrame
    if map and map.IsCanvasGamepadFocus then
        local ok, on = pcall(map.IsCanvasGamepadFocus, map)
        return ok and on and true or false
    end
    return false
end

local function EndTest(msg)
    testing = false
    if not InCombatLockdown() then ClearOverrideBindings(testOwner) end
    P.suspended = false
    P.Dirty()
    if msg then ns.Print(msg) end
end

function Diag.Test()
    if testing then return end
    if not ns.MapShown() then
        ns.Print(L.PROBE_OPEN_MAP)
        return
    end
    if InCombatLockdown() then
        ns.Print(L.PROBE_COMBAT)
        return
    end
    testing = true
    P.suspended = true
    if P.Release then P.Release() end
    ns.Print(L.TEST_RUNNING)
    local results, i = {}, 0
    local function Next()
        i = i + 1
        local g = TEST_GROUPS[i]
        if not g then
            ns.Print(L.TEST_HEAD)
            for _, r in ipairs(results) do
                ns.Print("  %s : %s, %s", r[1], r[2] and L.TEST_KEPT or L.TEST_LOST,
                    r[3] and L.TEST_BACK or L.TEST_STILL_LOST)
            end
            EndTest(L.TEST_DONE)
            return
        end
        if InCombatLockdown() or not ns.MapShown() then return EndTest(L.TEST_ABORT) end
        for _, key in ipairs(g[2]) do
            SetOverrideBindingClick(testOwner, true, key, testButton:GetName(), "LeftButton")
        end
        C_Timer.After(TEST_WAIT, function()
            local during = HasCursor()
            if InCombatLockdown() or not ns.MapShown() then return EndTest(L.TEST_ABORT) end
            ClearOverrideBindings(testOwner)
            C_Timer.After(TEST_WAIT, function()
                results[#results + 1] = { g[1], during, HasCursor() }
                Next()
            end)
        end)
    end
    -- (d'abord : la carte a-t-elle son curseur sans rien de l'addon ?)
    C_Timer.After(TEST_WAIT, function()
        if not HasCursor() then return EndTest(L.TEST_NO_FOCUS) end
        Next()
    end)
end
