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
    mapSmall = false,      -- la carte de l'addon réduite, en fenêtre (sinon en plein écran ; X à la manette, le bouton Taille)
    layerMemory = {},      -- les clés d'un calque à plusieurs clés, allumées quand on l'a éteint (UI/Layers.lua)
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
    travelPath = "mixed",  -- le chemin à pied : roads (routes au maximum), mixed (routes si possible), fields (à travers champs)
    travelTerrain = true,  -- les chemins à pied contournent les obstacles (Travel/Nav.lua)
    travelMinimap = true,  -- l'itinéraire aussi sur la minimap
    travelHud = true,      -- le panneau de trajet (UI/RouteHud.lua)
    hudFolded = false,     -- ... replié : l'en-tête et le temps qu'il reste seulement
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
-- La carte : tout passe par ns.Map (Map/Api.lua). Ces petits raccourcis
-- restent ceux du reste de Plus.
---------------------------------------------------------------------------
function ns.Why() return ns.Map.Why() end

-- La carte est trouvée et compatible
function ns.Ready() return ns.Map.Ready() end

-- Les fonctions de la vue sont là : elle tourne
function ns.ViewReady() return ns.Map.ViewReady() end

-- La vue de la carte est là et montrée
function ns.ViewOn() return ns.Map.On() end

-- L'interface manette de Forever est active
function ns.PadUI() return ns.Map.PadUI() end

-- Un appel protégé : rend ok, résultats
function ns.Call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

function ns.MapShown()
    local map = _G.WorldMapFrame
    return map and map:IsShown() or false
end

-- La carte plein écran (ou réduite) de l'addon est-elle là ?
function ns.FullMap() return ns.Map.Full() end

-- La carte de l'addon réduite : une fenêtre, le jeu visible autour, le
-- personnage libre de bouger (ns.db.options.mapSmall ; sinon, le plein
-- écran). Le bouton Taille de l'habillage ou X à la manette passent de l'une
-- à l'autre (UI/MapChrome.lua) ; pas en combat (la croix sécurisée de la
-- carte se déplace avec elle). La carte se pose en conséquence, puis
-- « MAP_SIZE » prévient l'habillage.
function ns.MapSmall()
    return ns.FullMap() and ns.db and ns.db.options.mapSmall and true or false
end

function ns.SetMapSmall(on)
    if not (ns.db and ns.FullMap()) then return end
    on = on and true or false
    if InCombatLockdown() then
        ns.Print(L.MAP_SIZE_COMBAT)
        return
    end
    ns.db.options.mapSmall = on
    ns.Map.SetSmall(on)
    ns.Fire("MAP_SIZE", on)
end

function ns.ToggleMapSize() ns.SetMapSmall(not ns.MapSmall()) end

-- X à la manette : la taille de la carte. L'appui arrive par deux chemins,
-- le X du jeu sur sa carte (le gestionnaire de sortie de la vue) et la
-- lecture de la manette (Pad/MapNav.lua) ; le jeu ne l'envoie pas toujours
-- (sa carte en fenêtre), et les deux à la fois annuleraient le changement :
-- un seul compte
local SIZE_PRESS_GAP = 0.4   -- s : un second appui plus proche est le même
local sizePressAt = -10
function ns.PadToggleMapSize()
    local now = GetTime()
    if now - sizePressAt < SIZE_PRESS_GAP then return end
    sizePressAt = now
    ns.ToggleMapSize()
end

---------------------------------------------------------------------------
-- Les gestes de l'addon qui touchent à l'interface du jeu (rendre la manette
-- à sa carte, choisir une quête dans son journal, reposer nos raccourcis
-- après les siens) : chacun est noté juste avant (ns.Risky). Si le jeu bloque
-- l'addon (« bloqué à cause d'une action qui n'est utilisable que par l'IU de
-- Blizzard ») dans la seconde qui suit, ce geste est coupé jusqu'au /reload,
-- et la discussion dit lequel : la fenêtre du jeu ne revient plus pour lui.
---------------------------------------------------------------------------
local RISKY_WINDOW = 1.0
local riskyAt, riskyOff = {}, {}

-- (vrai : le geste peut se faire, et il est noté ; faux : il a été coupé)
function ns.Risky(name)
    if riskyOff[name] then return false end
    riskyAt[name] = GetTime()
    return true
end

local blockedEvents = CreateFrame("Frame")
blockedEvents:RegisterEvent("ADDON_ACTION_BLOCKED")
blockedEvents:RegisterEvent("ADDON_ACTION_FORBIDDEN")
blockedEvents:SetScript("OnEvent", function(_, _, addon, fn)
    if addon ~= ADDON then return end
    local now, culprit, at = GetTime(), nil, -1
    for name, t in pairs(riskyAt) do
        if now - t <= RISKY_WINDOW and t > at and not riskyOff[name] then culprit, at = name, t end
    end
    if culprit then
        riskyOff[culprit] = true
        ns.Print(L.BLOCKED_CUT, tostring(fn or "?"), culprit)
    else
        ns.Print(L.BLOCKED_SEEN, tostring(fn or "?"))
    end
end)

---------------------------------------------------------------------------
-- Les maîtres de vol appris (apprendre un maître de vol, mesurer un vol) :
-- seule la carte classique d'OpenMap mettait ce suivi en place ; on le fait
-- nous-mêmes, une fois la carte lancée (ns.Map.Flights.Setup)
---------------------------------------------------------------------------
function ns.EnsureFlights() return ns.Map.Flights.Setup() end
function ns.FlightsTracked() return ns.Map.Flights.Tracked() end

-- La vue de la carte, lancée si elle attend (l'addon allumé, hors combat)
local function StartPadView()
    if not (ns.Ready() and ns.db.options.enabled) then return end
    ns.Map.Start()
    ns.EnsureFlights()
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
        -- (l'ancienne case « Suivre les routes » décochée : à travers champs)
        if ns.db.options.travelRoads ~= nil then
            if ns.db.options.travelRoads == false and ns.db.options.travelPath == nil then ns.db.options.travelPath = "fields" end
            ns.db.options.travelRoads = nil
        end
        -- (0.5.0 : plus de carte classique, la carte plein écran est la seule)
        ns.db.options.classicMap, ns.db.options.padView = nil, nil
        Fill(ns.db.options, DEFAULTS)
        ns.db.recent = ns.db.recent or {}
        -- (ce qui est propre au personnage : ses vols appris, son point de destination...)
        MyMapIsRichPlusCharDB = MyMapIsRichPlusCharDB or {}
        ns.char = MyMapIsRichPlusCharDB
        ns.Map.InitDB()
        if ns.UI and ns.UI.SetTheme then ns.UI.SetTheme(ns.db.options.theme, true) end
        ns.Map.Attach()
    elseif event == "PLAYER_LOGIN" then
        -- (OpenMap ou OpenMap On Gamepad chargé aussi : en veille, Init.lua le dit)
        if root.dormant or (root.Conflict and root.Conflict()) then return end
        -- (après une mise à jour : les nouveautés, l'écran de chargement
        -- passé ; UI/WhatsNew.lua)
        C_Timer.After(6, function() if ns.WhatsNew then ns.WhatsNew.MaybeShow() end end)
        local ok, why = ns.Map.Attach()
        if not ok then
            ns.Print(L.DISABLED_WHY, why or "?")
            return
        end
        -- (après le lancement de la carte, à la connexion)
        C_Timer.After(0, function()
            StartPadView()
            ns.Fire("READY")
        end)
    end
end)

---------------------------------------------------------------------------
-- /mmir (et /mymapisrich) ; /mmir carte : les réglages de la carte ;
-- /mmir carte <…> : les commandes de la carte (status, pins, draw... : Init.lua)
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
        -- (seul, ou une commande inconnue : les réglages de la carte, l'onglet Carte)
        local sub = rest and rest:lower() or ""
        local handled = false
        if sub == "forgetflights" then
            -- (les maîtres de vol appris par ce personnage, oubliés : Layers/Flights.lua)
            ns.Map.Flights.Forget()
            handled = true
        elseif sub ~= "" and root.MapSlash then
            handled = root.MapSlash(rest)
        end
        if not handled then ns.Map.Menu.Open() end
    elseif cmd == "etat" or cmd == "état" or cmd == "status" then
        if ns.Diag then ns.Diag.Status() end
    elseif cmd == "sonde carte" or cmd == "probe map" then
        if ns.Diag then ns.Diag.ProbeCoords() end
    elseif cmd == "sonde" or cmd == "probe" then
        if ns.Diag then ns.Diag.Probe() end
    elseif cmd == "test" then
        if ns.Diag then ns.Diag.Test() end
    elseif cmd == "focus ouverture" or cmd == "focus open" then
        if ns.Diag then ns.Diag.ArmOpenFocus() end
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
    elseif cmd == "panneau replier" or cmd == "hud fold" then
        -- (le panneau de trajet replié ou déplié : UI/RouteHud.lua)
        if ns.RouteHud then
            ns.Print(ns.RouteHud.ToggleFold() and L.HUD_FOLDED or L.HUD_UNFOLDED)
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
