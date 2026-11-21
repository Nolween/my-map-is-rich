-- Cœur de Plus (la couche reprise d'OpenMap On Gamepad) : données
-- sauvegardées, accès à la carte, passage en vue manette, petits outils
-- partagés (messages, événements internes), commande /mmir.
--
-- La carte est celle de My Map Is Rich (le code d'OpenMap, dans le même
-- addon) : son espace de noms est la racine (root : le module « worldmap »
-- et le moteur de la carte, MapStitch). Plus vit à part, dans root.Plus,
-- pour que ses textes et ses réglages ne touchent jamais ceux de la carte.
-- Il ne se sert de la carte que si tout ce qu'il appelle existe : sinon il
-- reste en veille (ns.Ready() faux) et le dit avec /mmir etat.
-- Rien n'est écrit dans les cadres de Blizzard (la carte du monde reste
-- celle du jeu, sécurisée : l'interface manette de Forever n'est jamais
-- bloquée par notre faute).
local ADDON, root = ...
local ns = root.Plus
local L = ns.L

-- (accès global : _G.MyMapIsRich.Plus, lu par My Gamepad Is Rich, débogage)

ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "?"

local PREFIX = "|cff" .. (root.ACCENT or "e6b85c") .. "My Map Is Rich|r : "

function ns.Print(msg, ...)
    if select("#", ...) > 0 then msg = msg:format(...) end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

---------------------------------------------------------------------------
-- Réglages par défaut (MyMapIsRichPlusDB.options)
---------------------------------------------------------------------------
local DEFAULTS = {
    enabled = true,        -- l'addon prend la manette carte ouverte
    padView = true,        -- forcer la vue manette d'OpenMap (son option « padView »)
    jump = true,           -- la croix saute d'icône en icône sur la carte
    magnet = true,         -- le curseur au repos près d'une icône : la vue s'y recale
    magnetRadius = 24,     -- px autour du curseur
    hints = true,          -- la barre d'aide en bas de la carte
    centerOnOpen = true,   -- la carte ouverte : recentrée sur le personnage
    whatsNew = true,       -- les nouveautés, une fois, après une mise à jour (UI/WhatsNew.lua)
    mapCamera = true,      -- carte réduite, curseur hors de la carte : le stick droit tourne la caméra (Pad/Camera.lua)
    mapCameraInvert = false, -- ... l'axe vertical inversé
    keyboard = "auto",     -- disposition du clavier : auto, azerty, qwerty
    glyphs = "auto",       -- icônes des boutons : auto, xbox, ps
    theme = "brown",
    travel = true,         -- R3 sur la carte : un itinéraire jusqu'au curseur
    travelSpeed = "auto",  -- la vitesse de marche : auto, walk, slow, fast
    travelRoads = true,    -- la marche suit les routes du jeu (sinon : en ligne droite)
    travelTerrain = true,  -- les chemins à pied contournent les obstacles (Travel/Nav.lua)
    travelMinimap = true,  -- l'itinéraire aussi sur la minimap
    travelHud = true,      -- le panneau de trajet (UI/RouteHud.lua)
    travelArrow = true,    -- la flèche GPS sous le panneau de trajet
    travelRumble = true,   -- la manette vibre à chaque étape (Pad/Rumble.lua)
    travelSound = true,    -- un son à chaque étape et à l'arrivée
    travelCorpse = true,   -- en fantôme : l'itinéraire jusqu'au corps
    travelShare = true,    -- les destinations envoyées par le groupe (Travel/Share.lua)
    travelShareChat = true, -- envoyer au groupe : aussi une ligne dans la discussion
}

local function Fill(into, from)
    for k, v in pairs(from) do
        if into[k] == nil then
            if type(v) == "table" then
                into[k] = {}
                Fill(into[k], v)
            else
                into[k] = v
            end
        end
    end
end

function ns.ResetOptions()
    wipe(ns.db.options)
    Fill(ns.db.options, DEFAULTS)
end

---------------------------------------------------------------------------
-- Petits événements internes : ns.On(nom, fn), ns.Fire(nom, ...)
-- (READY : OpenMap trouvé et compatible ; MAP_SHOW / MAP_HIDE ; OPTIONS ;
-- THEME ; CONTEXT : le contexte de la manette a changé ; TRAVEL : un
-- itinéraire lancé, avancé ou fini, la file changée ; TRAVEL_ARRIVED (goal) :
-- arrivé à une destination ; TRAVEL_END (goal) : un trajet arrêté ou
-- remplacé par un autre)
---------------------------------------------------------------------------
local listeners = {}

function ns.On(name, fn)
    listeners[name] = listeners[name] or {}
    table.insert(listeners[name], fn)
end

function ns.Fire(name, ...)
    for _, fn in ipairs(listeners[name] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end

---------------------------------------------------------------------------
-- OpenMap : ce dont l'addon a besoin, vérifié une fois
---------------------------------------------------------------------------
-- (les fonctions du module « worldmap » appelées ; une seule absente et
-- l'addon reste en veille plutôt que de lever des erreurs en jeu)
local NEEDED = {
    "PadUI", "PadViewOn", "SetPadView", "Glide", "ViewNow", "CursorWorld",
    "PadCursorXY", "PadControlAt", "MenuShown", "CloseMenu", "OpenMenu",
    "FindMe", "SetPinMode", "PinMode", "TogglePins",
}

local why = L.WHY_NOT_LOADED

function ns.Why() return why end

local function FindOpenMap()
    -- (la carte de My Map Is Rich : l'espace de noms racine de l'addon)
    local om = root
    if type(om) ~= "table" or type(om.GetModule) ~= "function" then
        why = L.WHY_NO_OPENMAP
        return false
    end
    local ok, mod = pcall(om.GetModule, om, "worldmap")
    if not ok or type(mod) ~= "table" then
        why = L.WHY_NO_MODULE
        return false
    end
    local S = om.MapStitch
    if type(S) ~= "table" or type(S.GetPinSet) ~= "function" then
        why = L.WHY_NO_STITCH
        return false
    end
    -- (certaines fonctions n'existent qu'une fois la vue manette lancée,
    -- PadView.lua : elles sont vérifiées au moment de s'en servir)
    local missing = {}
    for _, name in ipairs({ "PadUI", "SetPadView", "MenuShown", "CloseMenu", "OpenMenu", "FindMe", "SetPinMode", "PinMode", "TogglePins" }) do
        if type(mod[name]) ~= "function" then missing[#missing + 1] = name end
    end
    if #missing > 0 then
        why = L.WHY_MISSING:format(table.concat(missing, ", "))
        return false
    end
    ns.OM, ns.mod, ns.S = om, mod, S
    why = nil
    return true
end

-- OpenMap est là et compatible
function ns.Ready() return ns.mod ~= nil end

-- Les fonctions de la vue manette (PadView.lua) sont là : elle tourne
function ns.ViewReady()
    local mod = ns.mod
    if not mod then return false end
    for _, name in ipairs(NEEDED) do
        if type(mod[name]) ~= "function" then return false end
    end
    return true
end

-- La vue manette d'OpenMap est affichée (carte ouverte, interface manette)
function ns.ViewOn()
    local mod = ns.mod
    if not (mod and mod.PadViewOn) then return false end
    local ok, on = pcall(mod.PadViewOn)
    return ok and on or false
end

-- L'interface manette de Forever est active
function ns.PadUI()
    local mod = ns.mod
    if mod and mod.PadUI then
        local ok, on = pcall(mod.PadUI)
        if ok then return on end
    end
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() or false
end

-- Un appel à OpenMap protégé : rend ok, résultats
function ns.Call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

-- La carte du monde (celle du jeu ; jamais modifiée ici)
function ns.Map() return _G.WorldMapFrame end

function ns.MapShown()
    local map = _G.WorldMapFrame
    return map and map:IsShown() or false
end

---------------------------------------------------------------------------
-- La vue manette d'OpenMap : son option « padView » est une option de test,
-- éteinte par défaut ; sans elle, OpenMap laisse la carte à Blizzard dès que
-- l'interface manette est active. On l'allume (option padView de l'addon),
-- avant le lancement d'OpenMap à la connexion (son OnEnable la lit), et
-- après coup si OpenMap attend déjà (mod.padWaits).
---------------------------------------------------------------------------
local function WantPadView()
    local mod = ns.mod
    if not (mod and mod.db and ns.db.options.enabled and ns.db.options.padView) then return end
    if not mod.db.padView then mod.db.padView = true end
end

---------------------------------------------------------------------------
-- Les maîtres de vol appris : OpenMap les retient (mod.char.flightsKnown)
-- quand on ouvre la carte d'un maître de vol, et mesure les temps de vol ;
-- c'est mod:SetupFlights() qui met cela en place. Mais seule sa carte
-- habituelle l'appelle (WorldMap.lua) : sa vue manette (PadView.lua) ne le
-- fait pas, et avec elle rien n'était jamais appris (tous les maîtres de vol
-- gris, aucun vol dans les itinéraires). On l'appelle donc nous-mêmes, une
-- fois, quand OpenMap a pris le chemin de sa vue manette (mod.padWaits).
---------------------------------------------------------------------------
local function EnsureFlights()
    local mod = ns.mod
    if ns.flightsHooked or not (mod and mod.padWaits and mod.SetupFlights) then return end
    ns.flightsHooked = ns.Call(mod.SetupFlights, mod) and true or false
end
ns.EnsureFlights = EnsureFlights

-- Le suivi des vols d'OpenMap est-il en place (par nous, ou par sa carte habituelle) ?
function ns.FlightsTracked()
    local mod = ns.mod
    return ns.flightsHooked or (mod and mod.enabled and true) or false
end

local function StartPadView()
    local mod = ns.mod
    if not (mod and ns.db.options.enabled and ns.db.options.padView) then return end
    WantPadView()
    if mod.padWaits and not (mod.PadViewBuilt and mod.PadViewBuilt()) and not InCombatLockdown() then
        ns.Call(mod.SetPadView, true)
    end
    EnsureFlights()
end
ns.StartPadView = StartPadView

---------------------------------------------------------------------------
-- Chargement
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON then
        -- (rien de sauvegardé : l'addon vient d'être installé, pas mis à jour
        -- ; UI/WhatsNew.lua ne montre alors rien)
        ns.freshInstall = MyMapIsRichPlusDB == nil
        MyMapIsRichPlusDB = MyMapIsRichPlusDB or {}
        ns.db = MyMapIsRichPlusDB
        ns.db.options = ns.db.options or {}
        Fill(ns.db.options, DEFAULTS)
        ns.db.recent = ns.db.recent or {}
        if ns.UI and ns.UI.SetTheme then ns.UI.SetTheme(ns.db.options.theme, true) end
        -- (OpenMap est chargé avant nous, ses réglages aussi : la vue manette
        -- est demandée avant qu'il ne se lance, à la connexion)
        if FindOpenMap() then WantPadView() end
    elseif event == "PLAYER_LOGIN" then
        -- (OpenMap ou OpenMap On Gamepad chargé aussi : en veille, Init.lua le dit)
        if root.dormant or (root.Conflict and root.Conflict()) then return end
        -- (après une mise à jour : les nouveautés, l'écran de chargement
        -- passé ; UI/WhatsNew.lua)
        C_Timer.After(6, function() if ns.WhatsNew then ns.WhatsNew.MaybeShow() end end)
        if not ns.mod then FindOpenMap() end
        if not ns.mod then
            ns.Print(L.DISABLED_WHY, why or "?")
            return
        end
        -- (après le lancement d'OpenMap, qui a lu son réglage à la connexion)
        C_Timer.After(0, function()
            StartPadView()
            EnsureFlights()
            ns.Fire("READY")
        end)
    end
end)

---------------------------------------------------------------------------
-- /mmir (et /mymapisrich) ; /mmir carte <…> : les commandes de la carte
-- (celles d'OpenMap : status, pins, news, draw, reset... : Init.lua)
---------------------------------------------------------------------------
SLASH_MYMAPISRICH1 = "/mmir"
SLASH_MYMAPISRICH2 = "/mymapisrich"
SlashCmdList.MYMAPISRICH = function(msg)
    local raw = strtrim(msg or "")
    local cmd = raw:lower()
    if root.dormant then
        ns.Print(L.DORMANT, root.dormant)
        return
    end
    local first, rest = raw:match("^(%S+)%s*(.*)$")
    first = first and first:lower()
    if first == "carte" or first == "map" then
        if root.MapSlash then root.MapSlash(rest or "") end
    elseif cmd == "etat" or cmd == "état" or cmd == "status" then
        if ns.Diag then ns.Diag.Status() end
    elseif cmd == "sonde" or cmd == "probe" then
        if ns.Diag then ns.Diag.Probe() end
    elseif cmd == "test" then
        if ns.Diag then ns.Diag.Test() end
    elseif cmd == "focus" or cmd == "focus api" then
        if ns.Diag then ns.Diag.Focus(cmd == "focus api") end
    elseif cmd == "off" or cmd == "on" then
        -- (couper / remettre à chaud : les boutons rendus au jeu, ou repris)
        ns.db.options.enabled = cmd == "on"
        ns.Fire("OPTIONS")
        ns.Print(cmd == "on" and L.TURNED_ON or L.TURNED_OFF)
    elseif cmd == "reset" then
        ns.ResetOptions()
        if ns.UI and ns.UI.SetTheme then ns.UI.SetTheme(ns.db.options.theme, true) end
        ns.Fire("OPTIONS")
        ns.Print(L.RESET_DONE)
    elseif cmd == "minimap" then
        if ns.MinimapButton then ns.MinimapButton.Toggle() end
    elseif cmd == "lieux" or cmd == "places" then
        if ns.Places then ns.Places.Toggle() end
    elseif cmd == "file" or cmd == "queue" then
        -- (la file du trajet en plusieurs étapes : l'onglet File, carte ouverte)
        if ns.Places then ns.Places.Show("queue") end
    elseif cmd == "file vider" or cmd == "queue clear" then
        if ns.Travel then
            ns.Travel.ClearQueue()
            ns.Print(L.TRAVEL_QUEUE_CLEARED)
        end
    elseif cmd == "panneau" or cmd == "hud" then
        -- (le panneau de trajet remis à sa place : UI/RouteHud.lua)
        if ns.RouteHud then
            ns.RouteHud.ResetPosition()
            ns.Print(L.HUD_RESET)
        end
    elseif cmd == "camera" or cmd == "caméra" or cmd == "camera inverse" or cmd == "caméra inverse" or cmd == "camera invert"
        or cmd == "camera sonde" or cmd == "caméra sonde" or cmd == "camera probe"
        or cmd == "camera trace" or cmd == "caméra trace" then
        -- (la caméra au stick droit, carte réduite : Pad/Camera.lua)
        if ns.MapCamera then ns.MapCamera.Toggle(cmd:match("(%a+)$")) end
    elseif cmd == "news" or cmd == "nouveautes" or cmd == "nouveautés" then
        -- (les nouveautés des dernières versions : UI/WhatsNew.lua)
        if ns.WhatsNew then ns.WhatsNew.Open() end
    elseif cmd == "trajet" or cmd == "route" then
        if ns.Travel then ns.Travel.Report() end
    elseif cmd == "trajet stop" or cmd == "route stop" then
        if ns.Travel then
            if ns.Travel.Active() then ns.Travel.Cancel(true) else ns.Print(L.TRAVEL_NONE) end
        end
    elseif cmd == "aide" or cmd == "help" or cmd == "?" then
        ns.Print(L.HELP)
    else
        if ns.Options and ns.Options.Open then ns.Options.Open() else ns.Print(L.HELP) end
    end
end
