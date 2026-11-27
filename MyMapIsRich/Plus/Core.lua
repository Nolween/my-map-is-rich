-- Cœur de My Map Is Rich : données sauvegardées, accès à la carte, passage
-- en vue manette, petits outils partagés (messages, événements internes),
-- la veille, commande /mmir.
--
-- Tout le code de l'addon vit dans root.Plus (Plus/Init.lua) ; il atteint la
-- carte par ns.Map (Map/Api.lua). Il ne s'en sert que si son dessin est là :
-- sinon il reste en veille (ns.Ready() faux) et le dit avec /mmir etat.
-- Rien n'est écrit dans les cadres de Blizzard (la carte du monde reste
-- celle du jeu, sécurisée : l'interface manette de Forever n'est jamais
-- bloquée par notre faute).
local ADDON, root = ...
local ns = root.Plus
local L = ns.L

ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "?"

local PREFIX = "|cffe6b85cMy Map Is Rich|r : "

function ns.Print(msg, ...)
    if select("#", ...) > 0 then msg = msg:format(...) end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

---------------------------------------------------------------------------
-- La veille : My Map Is Rich vient d'OpenMap et d'OpenMap On Gamepad. L'un
-- d'eux chargé aussi, il n'accroche rien (la carte leur reste) et le dit.
-- Rend le nom de celui qui est là, sinon false. (Tous les addons ne sont
-- chargés qu'à la connexion : avant, la réponse n'est pas retenue.)
---------------------------------------------------------------------------
local RIVALS = { "OpenMap", "OpenMapOnGamepad" }
local dormant
function ns.Conflict()
    if dormant ~= nil then return dormant end
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    local found = false
    if loaded then
        for _, name in ipairs(RIVALS) do
            local ok, on = pcall(loaded, name)
            if ok and on then found = name break end
        end
    end
    if not IsLoggedIn or IsLoggedIn() then dormant = found end
    return found
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
    travelPath = "balanced",  -- le style de marche (Travel/Nav.lua : Nav.STYLES) : fastest (le plus rapide),
                              -- balanced (équilibré, recommandé), roads (les routes)
    travelAlerts = true,   -- les alertes des bateaux et des zeppelins (Travel/Transit.lua)
    travelButton = true,   -- le bouton de voyage : la téléportation ou le vol de l'étape (UI/TravelButton.lua)
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
    tracker = true,        -- le suivi des quêtes à droite de l'écran, à la place de celui du jeu (UI/Tracker.lua)
    trackerSort = "dist",  -- ... rangé par distance (dist) ou par zone (zone)
    trackerFilter = "all", -- ... ce qu'il montre : all, watched (suivies), zone, near (proches)
    trackerAlpha = 0.7,    -- ... l'opacité de son fond
    trackerParty = true,   -- ... l'avancée du groupe sous les quêtes communes (Quests/Party.lua)
    trackerItems = true,   -- ... les objets de quête en face de leur quête (UI/TrackerItems.lua)
    trackerItemsSide = "center", -- ... de quel côté : center (vers le centre de l'écran), left, right
    trackerCombat = false, -- ... caché en combat
    trackerLock = false,   -- ... verrouillé à sa place
    trackerFolded = false, -- ... replié : l'en-tête seul
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
-- (READY : la carte trouvée et lancée ; MAP_SHOW / MAP_HIDE ; OPTIONS ;
-- THEME ; CONTEXT : le contexte de la manette a changé ; TRAVEL : un
-- itinéraire lancé, avancé ou fini, la file changée ; TRAVEL_ARRIVED (goal) :
-- arrivé à une destination ; TRAVEL_END (goal) : un trajet arrêté ou
-- remplacé par un autre)
---------------------------------------------------------------------------
local listeners = {}
local Clock = debugprofilestop   -- (ms ; peut manquer : rien n'est alors mesuré)

-- Le temps pris par chaque événement : le dernier, le pire, combien de fois,
-- et en combien d'images (ns.FireSpread) ; /mmir carte status les montre
ns.fireTimes = {}
local function Took(name, ms, frames)
    local t = ns.fireTimes[name] or { worst = 0, n = 0 }
    t.last, t.worst, t.n, t.frames = ms, math.max(t.worst, ms), t.n + 1, frames
    ns.fireTimes[name] = t
end

function ns.On(name, fn)
    listeners[name] = listeners[name] or {}
    table.insert(listeners[name], fn)
end

function ns.Fire(name, ...)
    local t0 = Clock and Clock()
    for _, fn in ipairs(listeners[name] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
    if t0 then Took(name, Clock() - t0) end
end

-- Le même, un écouteur par image, pour ne pas tout faire d'un coup (la carte
-- dessinée en arrière-plan : MAP_BUILT). Rien pendant un combat : on attend
-- qu'il finisse. done() une fois tous passés. Rend une fonction qui fait
-- tout le reste maintenant (la carte ouverte avant la fin)
function ns.FireSpread(name, done)
    local list = listeners[name] or {}
    local at, finished, ms, frames = 0, false, 0, 0
    local function One()
        at = at + 1
        local fn = list[at]
        if not fn then return end
        local t0 = Clock and Clock()
        local ok, err = pcall(fn)
        if not ok and geterrorhandler then geterrorhandler()(err) end
        if t0 then ms = ms + Clock() - t0 end
    end
    local function Finish()
        if finished then return end
        finished = true
        if done then
            local ok, err = pcall(done)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        end
        if Clock then Took(name, ms, frames) end
    end
    local function Step()
        if finished then return end
        if InCombatLockdown() then
            C_Timer.After(1, Step)
            return
        end
        frames = frames + 1
        One()
        if at >= #list then Finish() else C_Timer.After(0, Step) end
    end
    C_Timer.After(0, Step)
    return function()
        if finished then return end
        frames = frames + 1
        while at < #list do One() end
        Finish()
    end
end

---------------------------------------------------------------------------
-- Les longs travaux, quelques ms par image (les marqueurs de quêtes : les
-- 6 000 quêtes de la base passées en revue). ns.Job(fn, done) lance fn dans
-- une coroutine, done(son résultat) une fois finie ; fn appelle ns.Slice()
-- là où elle peut s'arrêter, jamais sous un pcall (Lua 5.1 ne cède pas à
-- travers). job.Rush() finit tout maintenant (quelqu'un attend la réponse),
-- job.Cancel() l'abandonne (ce qu'il calculait a changé). Un à la fois, dans
-- l'ordre où ils sont lancés ; ns.Slice() hors d'un travail ne fait rien.
---------------------------------------------------------------------------
local JOB_MS = 3
local jobs, jobOf = {}, {}      -- les travaux en attente ; coroutine -> travail
local runner = CreateFrame("Frame")
runner:Hide()

local function Resume(job)
    job.t0 = Clock and Clock() or 0
    local ok, result = coroutine.resume(job.co)
    if not ok then
        job.dead = true
        if geterrorhandler then geterrorhandler()(result) end
    elseif coroutine.status(job.co) == "dead" then
        job.dead = true
        if job.done and not job.cancelled then
            local okD, err = pcall(job.done, result)
            if not okD and geterrorhandler then geterrorhandler()(err) end
        end
    end
    if job.dead then jobOf[job.co] = nil end
end

runner:SetScript("OnUpdate", function(self)
    while jobs[1] and jobs[1].dead do table.remove(jobs, 1) end
    local job = jobs[1]
    if not job then
        self:Hide()
        return
    end
    Resume(job)
end)

function ns.Slice()
    local job = jobOf[coroutine.running() or 0]
    if job and not job.rush and Clock and Clock() - job.t0 > JOB_MS then coroutine.yield() end
end

function ns.Job(fn, done)
    local job = { co = coroutine.create(fn), done = done }
    jobOf[job.co] = job
    jobs[#jobs + 1] = job
    runner:Show()
    function job.Rush()
        -- (pas depuis lui-même, ni depuis ce qu'il a lancé : il attend déjà)
        if job.dead or coroutine.status(job.co) ~= "suspended" then return end
        job.rush = true
        while not job.dead do Resume(job) end
    end
    function job.Cancel()
        job.cancelled, job.dead = true, true
        jobOf[job.co] = nil
    end
    return job
end

---------------------------------------------------------------------------
-- La carte : tout passe par ns.Map (Map/Api.lua). Ces petits raccourcis
-- restent ceux du reste de Plus.
---------------------------------------------------------------------------
function ns.Why() return ns.Map.Why() end

-- La carte est trouvée et compatible
-- (en veille, OpenMap ou OpenMap On Gamepad chargé aussi : jamais prêt)
function ns.Ready() return ns.Map.Ready() and not ns.Conflict() end

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

-- X à la manette, carte ouverte : la taille de la carte, et rien d'autre,
-- quel que soit l'écran posé sur la carte (la liste des quêtes, la fiche d'un
-- point, les lieux, le rail des calques, la plume, un donjon...). Seuls le
-- clavier à l'écran et l'invitation du groupe gardent leur X. L'action et
-- son libellé, pour chaque contexte de la manette
function ns.PadMapSize()
    if ns.FullMap() and ns.MapShown() then ns.PadToggleMapSize() end
end
function ns.PadMapSizeHint()
    if not (ns.FullMap() and ns.MapShown()) then return nil end
    return ns.MapSmall() and "HINT_MAP_FULL" or "HINT_MAP_SMALL"
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
local blockedSaid = {}       -- les fonctions bloquées déjà dites (le blocage dure jusqu'au /reload : une fois suffit)

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
    elseif not blockedSaid[tostring(fn or "?")] then
        blockedSaid[tostring(fn or "?")] = true
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
-- (l'addon remis en marche, /mmir on ou le bouton de la minimap : la vue mise en place sans /reload)
ns.On("OPTIONS", function()
    if ns.db and ns.db.options.enabled and not InCombatLockdown() then StartPadView() end
end)

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
        -- (1.4.0 : les styles de marche de Polestar ; à travers champs devient le
        -- plus rapide, routes si possible l'équilibré, routes au maximum les routes)
        local PATHS = { fields = "fastest", mixed = "balanced" }
        if PATHS[ns.db.options.travelPath] then ns.db.options.travelPath = PATHS[ns.db.options.travelPath] end
        -- (1.4.0 : la pierre de foyer n'est plus dans les itinéraires, son réglage s'en va)
        ns.db.options.travelHearth = nil
        -- (0.5.0 : plus de carte classique, la carte plein écran est la seule)
        ns.db.options.classicMap, ns.db.options.padView = nil, nil
        Fill(ns.db.options, DEFAULTS)
        ns.db.recent = ns.db.recent or {}
        -- (ce qui est propre au personnage : ses vols appris, son point de destination...)
        MyMapIsRichPlusCharDB = MyMapIsRichPlusCharDB or {}
        ns.char = MyMapIsRichPlusCharDB
        -- (1.4.0 : l'auberge de la pierre de foyer ne sert plus aux itinéraires)
        ns.char.hearth = nil
        ns.Map.InitDB()
        if ns.UI and ns.UI.SetTheme then ns.UI.SetTheme(ns.db.options.theme, true) end
        ns.Map.Attach()
    elseif event == "PLAYER_LOGIN" then
        -- (OpenMap ou OpenMap On Gamepad chargé aussi : en veille, on le dit)
        local rival = ns.Conflict()
        if rival then
            ns.Print(L.DORMANT, rival)
            -- (le tutoriel, lui, s'ouvre quand même : c'est lui qui propose
            -- de couper l'autre ; il n'accroche rien du jeu)
            C_Timer.After(6, function() if ns.Tutorial then ns.Tutorial.MaybeShow() end end)
            return
        end
        -- (l'écran de chargement passé : le tutoriel au premier lancement,
        -- UI/Tutorial.lua ; sinon, après une mise à jour, les nouveautés,
        -- UI/WhatsNew.lua. Le tutoriel fermé, les nouveautés suivent.)
        C_Timer.After(6, function()
            if ns.Tutorial and ns.Tutorial.Pending() then
                ns.Tutorial.MaybeShow()
            elseif ns.WhatsNew then
                ns.WhatsNew.MaybeShow()
            end
        end)
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
-- /mmir carte <…> : les commandes de la carte (MAP_COMMANDS)
---------------------------------------------------------------------------
-- (status : ce que fait la vue ; pins : tes épingles montrées ou cachées ;
-- draw : la plume ; forgetflights : les maîtres de vol appris par ce
-- personnage, oubliés. padview : l'ancien nom de status ; replacer : la
-- carte réduite rendue à la place que le jeu lui donne, Map/View.lua)
local function PlaceAgain()
    ns.Map.ResetPlace()
    ns.Print(L.MAP_PLACE_RESET)
end
local MAP_COMMANDS = {
    status = function() ns.Map.View.Diag() end,
    padview = function() ns.Map.View.Diag() end,
    pins = function() ns.Map.MyPins.Toggle() end,
    draw = function() ns.Map.Sketch.Toggle() end,
    replacer = PlaceAgain,
    reset = PlaceAgain,
}
SLASH_MYMAPISRICH1 = "/mmir"
SLASH_MYMAPISRICH2 = "/mymapisrich"
SlashCmdList.MYMAPISRICH = function(msg)
    local raw = strtrim(msg or "")
    local cmd = raw:lower()
    -- (le tutoriel : UI/Tutorial.lua ; aussi en veille)
    if cmd == "tuto" or cmd == "tutoriel" or cmd == "tutorial" then
        if ns.Tutorial then ns.Tutorial.Open(1) end
        return
    end
    local rival = ns.Conflict()
    if rival then
        ns.Print(L.DORMANT, rival)
        return
    end
    local first, rest = raw:match("^(%S+)%s*(.*)$")
    first = first and first:lower()
    if first == "carte" or first == "map" then
        -- (seul, ou une commande inconnue : les réglages de la carte, l'onglet Carte)
        local sub = rest and rest:lower() or ""
        local run = MAP_COMMANDS[sub]
        if sub == "forgetflights" then
            -- (les maîtres de vol appris par ce personnage : seulement ses sauvegardes, la carte n'a pas à être prête)
            ns.Map.Flights.Forget()
        elseif run and ns.Ready() then
            local ok, err = pcall(run)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        else
            ns.Map.Menu.Open()
        end
    elseif cmd == "etat" or cmd == "état" or cmd == "status" then
        if ns.Diag then ns.Diag.Status() end
    elseif cmd == "sonde carte" or cmd == "probe map" then
        if ns.Diag then ns.Diag.ProbeCoords() end
    elseif cmd == "sonde terrain" or cmd == "probe ground" then
        -- (le terrain de la grille de marche là où tu es : Travel/Nav.lua)
        if ns.Diag then ns.Diag.ProbeTerrain() end
    elseif cmd == "sonde quetes" or cmd == "sonde quêtes" or cmd == "probe quests" then
        -- (tes quêtes du journal dans la base des quêtes : Layers/QuestMarks.lua)
        if ns.Quests and ns.Quests.Marks then ns.Quests.Marks.Probe() end
    elseif cmd == "quetes export" or cmd == "quêtes export" or cmd == "quests export" then
        -- (ce que la base ne savait pas, appris en jouant : Quests/Learn.lua)
        if ns.Quests and ns.Quests.Learn then ns.Quests.Learn.ShowExport() end
    elseif first == "pourquoi" or first == "why" then
        -- (pourquoi une quête n'a pas de « ! » sur la carte : Quests/Offers.lua)
        if ns.Quests and ns.Quests.Offers then ns.Quests.Offers.Explain(rest) end
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
    elseif cmd == "suivi replacer" or cmd == "tracker reset" then
        -- (le suivi des quêtes remis à sa place : UI/Tracker.lua)
        if ns.Tracker then
            ns.Tracker.ResetPosition()
            ns.Print(L.TRACKER_RESET)
        end
    elseif cmd == "suivi replier" or cmd == "tracker fold" then
        if ns.Tracker then
            ns.Print(ns.Tracker.ToggleFold() and L.TRACKER_FOLDED or L.TRACKER_UNFOLDED)
        end
    elseif cmd == "suivi" or cmd == "tracker" then
        -- (le suivi des quêtes montré ou coupé ; coupé, celui du jeu revient)
        if ns.Tracker then
            ns.Print(ns.Tracker.Toggle() and L.TRACKER_ON or L.TRACKER_OFF)
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
    elseif cmd == "trajet passer" or cmd == "route skip" then
        -- (passer l'étape en cours : le vol, le bateau, la téléportation ; Travel/Guide.lua)
        if ns.Travel then
            if ns.Travel.Active() then ns.Travel.SkipLeg() else ns.Print(L.TRAVEL_NONE) end
        end
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
