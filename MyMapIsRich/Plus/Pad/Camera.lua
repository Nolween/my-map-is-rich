-- La caméra au stick droit, carte réduite ouverte : quand la carte (en
-- fenêtre, pas en plein écran) n'a pas le curseur de la manette, parce
-- qu'il est sur la liste de droite (le journal de quêtes), le stick droit
-- fait tourner la caméra comme en jeu.
-- L'interface manette garde le stick pour sa liste, et ne laisse pas la
-- caméra tourner tant qu'une fenêtre a le focus. Le stick est donc lu sur la
-- manette (C_GamePad.GetDeviceMappedState, son stick « Camera »), sans
-- aucun raccourci, comme OpenMap lit déjà son zoom (WorldMap.lua :
-- PadStickTilt), et la caméra est tournée par les fonctions du jeu
-- (MoveViewLeftStart...), plus ou moins vite selon l'inclinaison.
-- Si le jeu refuse un jour ces appels (ADDON_ACTION_BLOCKED), la caméra au
-- stick se coupe d'elle-même, avec un message, plutôt que de répéter
-- l'erreur. /mmir camera la coupe ou la remet ; /mmir camera inverse
-- inverse l'axe vertical.
local ADDON, root = ...
local ns = root.Plus
local L = ns.L

local C = {}
ns.MapCamera = C

local DEAD = 0.15            -- l'inclinaison du stick sous laquelle il est au repos
local CURVE = 1.6            -- (la réponse du stick : douce au centre, pleine au bord)
local RESEND = 0.08          -- un changement de vitesse plus petit n'est pas renvoyé au jeu

local blocked = false

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Le stick de la caméra (le droit) : x, y de -1 à 1 (y vers le haut), ou nil
local cameraIndex
local function Stick()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return end
    local ok, state = pcall(C_GamePad.GetDeviceMappedState)
    if not ok or type(state) ~= "table" then return end
    local sticks = Plain(state.sticks)
    if type(sticks) ~= "table" then return end
    if not cameraIndex then
        local count = Plain(state.stickCount) or #sticks
        for i = 1, count do
            local okName, name = pcall(C_GamePad.StickIndexToConfigName or error, i - 1)
            if okName and name == "Camera" then cameraIndex = i break end
        end
        cameraIndex = cameraIndex or (#sticks >= 2 and 2) or nil
        if not cameraIndex then return end
    end
    local s = sticks[cameraIndex]
    if type(s) ~= "table" then return end
    local x, y = Plain(s.x), Plain(s.y)
    if type(x) ~= "number" or type(y) ~= "number" then return end
    return x, y
end

-- (lu aussi par la roue des actions : UI/ActionBar.lua)
C.Stick = Stick

-- La caméra au stick peut-elle servir maintenant ?
local function Wanted()
    if blocked or not ns.db then return false end
    local o = ns.db.options
    if not (o.enabled and o.mapCamera) then return false end
    local map = _G.WorldMapFrame
    if not (map and map:IsShown()) then return false end
    -- (en plein écran, la carte couvre le jeu : le stick y reste au zoom)
    if map.IsMaximized and map:IsMaximized() then return false end
    if not ns.PadUI() then return false end
    -- (seulement sur la liste des quêtes, ou sans contexte : la roue, une
    -- fenêtre, la plume, un donjon gardent le stick droit pour eux. La roue
    -- surtout : posée sous le curseur, il n'est plus « sur la carte », et la
    -- caméra tournait pendant qu'on choisissait)
    local current = ns.Pad and ns.Pad.current
    if current and current ~= "questlog" then return false end
    if ns.ActionBar and ns.ActionBar.Shown() then return false end
    -- (le curseur sur la carte : le stick y zoome, OpenMap ; Pad/MapNav.lua)
    return not ns.MapNav.CursorOnMap()
end

-- Un axe de la caméra : sa direction en cours (« Left », « Right », « Up »,
-- « Down » ou nil) et la vitesse envoyée
local axes = {
    yaw = { dir = nil, speed = 0 },
    pitch = { dir = nil, speed = 0 },
}

local function Call(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function Stop(axis)
    if axis.dir then Call("MoveView" .. axis.dir .. "Stop") end
    axis.dir, axis.speed = nil, 0
end

local function StopAll()
    Stop(axes.yaw)
    Stop(axes.pitch)
end

-- Un axe vers `dir` à `speed` (dir nil : arrêté)
local function Drive(axis, dir, speed)
    if dir ~= axis.dir then
        Stop(axis)
        if not dir then return end
        if Call("MoveView" .. dir .. "Start", speed) then axis.dir, axis.speed = dir, speed end
    elseif dir and math.abs(speed - axis.speed) > RESEND then
        if Call("MoveView" .. dir .. "Start", speed) then axis.speed = speed end
    end
end

-- La vitesse d'un axe d'après l'inclinaison (0 au repos), et le réglage du
-- jeu pour la manette (GamePadCameraYawSpeed / PitchSpeed : leur grandeur)
local function Speed(v, cvar)
    local a = math.abs(v)
    if a < DEAD then return 0 end
    local t = ((math.min(a, 1) - DEAD) / (1 - DEAD)) ^ CURVE
    local scale = math.abs(tonumber(GetCVar and GetCVar(cvar) or nil) or 1)
    scale = math.max(0.3, math.min(scale, 3))
    return t * scale
end

-- /mmir camera trace : chaque changement, dans la discussion (le contexte de
-- la manette, le curseur sur la carte, la caméra tournée par l'addon)
local tracing, traceWait, lastTrace = false, 0, nil
local function Trace(elapsed, turning)
    if not tracing then return end
    traceWait = traceWait - (elapsed or 0)
    if traceWait > 0 then return end
    traceWait = 0.25
    local line = L.CAMERA_TRACE:format(tostring(ns.Pad and ns.Pad.current or L.NONE),
        tostring(ns.MapNav and ns.MapNav.CursorOnMap() or false),
        tostring(ns.ActionBar and ns.ActionBar.Shown() or false), turning and L.YES or L.NO,
        tostring(ns.ActionBar and ns.ActionBar.KeepsSticks and ns.ActionBar.KeepsSticks()))
    if line ~= lastTrace then
        lastTrace = line
        ns.Print(line)
    end
end

function C.ToggleTrace()
    tracing = not tracing
    lastTrace = nil
    ns.Print(tracing and L.CAMERA_TRACE_ON or L.CAMERA_TRACE_OFF)
end

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(_, elapsed)
    local x, y
    if Wanted() then x, y = Stick() end
    Trace(elapsed, x and (math.abs(x) >= DEAD or math.abs(y) >= DEAD))
    if not x then
        StopAll()
        return
    end
    -- (MoveViewLeft / Right déplacent la caméra autour du personnage : vers
    -- la gauche, la vue tourne vers la droite. Stick à droite : regarder à
    -- droite, donc la caméra part à gauche)
    local yaw = Speed(x, "GamePadCameraYawSpeed")
    Drive(axes.yaw, yaw > 0 and (x > 0 and "Left" or "Right") or nil, yaw)
    -- (stick vers le haut : regarder vers le haut, la caméra descend ; le
    -- réglage du jeu inversé, ou /mmir camera inverse, l'inverse)
    local pitch = Speed(y, "GamePadCameraPitchSpeed")
    local up = y > 0
    local invert = (tonumber(GetCVar and GetCVar("GamePadCameraPitchSpeed") or nil) or 1) < 0
    if ns.db.options.mapCameraInvert then invert = not invert end
    if invert then up = not up end
    Drive(axes.pitch, pitch > 0 and (up and "Down" or "Up") or nil, pitch)
end)

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:SetScript("OnEvent", function(_, _, addon, fn)
    -- (le jeu refuse la caméra à l'addon : on n'insiste pas)
    if addon == ADDON and type(fn) == "string" and fn:find("MoveView") then
        blocked = true
        StopAll()
        driver:Hide()
        ns.Print(L.CAMERA_BLOCKED)
    end
end)

-- (la carte plein écran couvre tout : le stick droit y est à la carte, jamais à la caméra)
ns.On("MAP_SHOW", function() if not blocked and not ns.FullMap() then driver:Show() end end)
ns.On("MAP_HIDE", function()
    StopAll()
    driver:Hide()
end)

-- (une fenêtre qui prend la manette arrête notre caméra au stick ; celle du
-- jeu ne s'arrête pas d'un addon : ses vitesses, GamePadCameraYawSpeed...,
-- ne s'écrivent pas, et SetGamePadCursorControl est défait aussitôt par
-- l'interface manette. La roue ne prend donc pas la manette : UI/ActionBar.lua)
ns.On("CONTEXT", function() StopAll() end)

-- /mmir camera sonde : le contexte de la manette, et si le curseur est sur la carte
function C.Probe()
    ns.Print(L.CAMERA_PROBE, tostring(ns.Pad and ns.Pad.current or L.NONE),
        tostring(ns.MapNav and ns.MapNav.CursorOnMap() or false))
end

-- /mmir camera : couper ou remettre ; /mmir camera inverse : l'axe vertical
function C.Toggle(what)
    local o = ns.db.options
    if what == "sonde" or what == "probe" then
        C.Probe()
    elseif what == "trace" then
        C.ToggleTrace()
    elseif what == "inverse" or what == "invert" then
        o.mapCameraInvert = not o.mapCameraInvert
        ns.Print(o.mapCameraInvert and L.CAMERA_INVERT_ON or L.CAMERA_INVERT_OFF)
    else
        o.mapCamera = not o.mapCamera
        if not o.mapCamera then StopAll() end
        ns.Print(o.mapCamera and L.CAMERA_ON or L.CAMERA_OFF)
    end
end
