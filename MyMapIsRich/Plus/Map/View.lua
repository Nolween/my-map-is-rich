-- La vue de la carte : la carte plein écran (ou réduite en fenêtre), à la
-- souris et à la manette. En code de My Map Is Rich depuis la 0.12.0 (elle
-- venait de Map/PadView.lua et Map/WorldMap.lua d'OpenMap).
--
-- La carte du jeu s'ouvre et se ferme comme toujours (M, Échap, B) ; elle
-- reste ouverte dessous, invisible. Rien n'y est écrit ni remplacé : seul
-- l'enfant de son cadre de défilement est rendu transparent tant que la vue
-- le couvre, et ses fonctions de manette sont seulement accrochées
-- (hooksecurefunc). Le code de l'interface manette du jeu (son curseur, B, la
-- croix, le focus) reste ainsi le sien.
--
-- Sur la vue : le dessin de la carte (Map/Art.lua, et son zoom rapproché,
-- Map/Close.lua), ses icônes (Map/PinSets.lua) et celles des calques de Plus, celles des autres addons
-- (Map/Hbd.lua), ta flèche, la zone d'une quête.
--   la souris   la molette zoome autour du curseur, tirer déplace, un clic
--               gauche entre dans la zone (ou presse l'icône), un clic droit
--               en sort ; avec Maj, Ctrl ou Alt, ce que Plus en fait d'abord
--               (UI/MapChrome.lua), le bouton du milieu te localise ;
--   la manette  le curseur est celui du jeu, reporté à la même place sur la
--               vue (Project) ; le stick droit zoome autour de lui (ou fait
--               tourner la molette d'une fenêtre sous lui) ; le curseur au
--               bord fait glisser la carte ; A presse le bouton ou l'icône
--               dessous, sinon entre dans la zone ; X ferme ce qui est ouvert
--               (la carte d'un donjon, la plume), sinon Plus en décide ; le
--               stick gauche enfoncé pose le point de destination là.
local _, root = ...
local ns = root.Plus
local L = ns.L

local V = ns.Map.View
local C = ns.Map.Cursor
local K = ns.Map.Coords
local A = ns.Map.Art
local P = ns.Map.Pins
local LK = ns.Map.Look
local HB = ns.Map.Hbd        -- (pas « H » : c'est la hauteur du dessin, dans plusieurs fonctions)

local ART_RANGE = 80            -- les niveaux de cadre que prend le dessin
local GLIDE_TIME = 0.4          -- la glissade de A et X, comme celle d'un clic
local PAD_ZOOM_RATE = 1.8       -- le stick droit à fond, par seconde (en zoom logarithmique)
local CITY_ZOOM = 1.5           -- plus près au-dessus d'une ville
local PLAYER_EVERY = 0.1        -- secondes entre deux places de ta flèche
local REACH = 12                -- px du curseur où une icône compte comme dessous
local HOVER_EVERY = 0.05        -- secondes entre deux regards sous le curseur
local EDGE_NEAR = 2             -- le curseur aussi près du bord de ses bornes y est
local EDGE_PUSH = 0.3           -- le stick gauche poussé vers ce bord : la carte glisse
local EDGE_PAN = 700            -- px de vue par seconde à fond, tant que la vitesse du jeu n'est pas vue
local WHEEL_EVERY = 0.12        -- secondes entre deux crans de molette du stick droit à fond
local ARROW_ABOVE = 8500        -- ta flèche : tant de niveaux au-dessus de la vue (au-dessus des icônes de Questie)
local POINTER_LEVEL = 9990      -- le curseur de la manette, au-dessus de tout
local SMALL_W, SMALL_H = 0.66, 0.72   -- la carte réduite, la carte du jeu en plein écran quand même

local map, sc, view, canvas
local pointer                   -- le curseur de la manette, redessiné sur l'art (celui du jeu est dessous)
local built, failed = false, false
local u, v, zoom                -- la vue : son centre (le monde, 0..1) et son zoom (1 : le monde entier)
local glide                     -- la glissade de A ou X en cours
local lastX, lastY              -- le curseur de la manette à l'image d'avant (px de l'écran)
local dirty = false
local drag                      -- la souris qui tire la vue : { x, y, u, v, moved }
local playerWait, hoverWait = 0, 0
local hbdWait = 0
local hovered                   -- l'icône sous le curseur de la manette, survolée comme à la souris
local overWindow, wheelFrame    -- le curseur sur une fenêtre de l'addon, et ce qui y défile
local edgePan = EDGE_PAN
local wheelWait = 0
local stickZoomAt = -10         -- quand le stick droit a zoomé pour la dernière fois (GetTime)
local small = false
local area = {}                 -- la zone d'une quête : { frame, quest, map, hoverQ/M, focusQ/M, failed }
local place = {}                -- le lieu sous le curseur (ou au centre) : { key, fishKey, zone, continent }
local onClick, onOut, onPress   -- ce que Plus fait d'un clic, du X de la manette, d'une icône choisie
local ownPress = false          -- (V.PinAction : l'action de l'icône elle-même, sans la fiche de Plus)
local diag = { started = 0, setup = "VIEW_SETUP_NOT_YET", shows = 0, why = "VIEW_WHY_NOT_YET" }
local Press, DrawArea

local function Clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end

local function Plain(val)
    if issecretvalue and issecretvalue(val) then return nil end
    return val
end

---------------------------------------------------------------------------
-- La géométrie
---------------------------------------------------------------------------
local function FitPx()
    local W, H = A.Size()
    return math.min(view:GetWidth() / W, view:GetHeight() / H)
end

-- (le détail de l'art suit la surface de la vue, pas seulement sa largeur)
local function DetailK()
    local W, H = A.Size()
    local w, h = view:GetWidth(), view:GetHeight()
    local k = ns.Map.Data.ClientZoom()
    if not W or w <= 0 or h <= 0 then return 1 / k end
    return math.min(w / W, h / H) / math.sqrt(w * h / (W * H)) / k
end

local function Stitchable(mapID)
    if not mapID or mapID == K.World() then return mapID == K.World() end
    local info = C_Map.GetMapInfo(mapID)
    if not info or (info.mapType ~= Enum.UIMapType.Continent and info.mapType ~= Enum.UIMapType.Zone) then return false end
    return A.Rect(mapID) ~= nil and A.ArtSize(mapID) ~= nil and A.Stitched(mapID, true)
end

local function FitZoom(mapID)
    local W, H = A.Size()
    local l, r, t, b = A.Rect(mapID)
    if not l then return 1 end
    return math.min(view:GetWidth() / ((r - l) * W), view:GetHeight() / ((b - t) * H)) / FitPx()
end

local function MostAt(cu, cv)
    return (LK.MaxZoom() or 64) * ((cu and A.InCity and A.InCity(cu, cv)) and CITY_ZOOM or 1)
end

-- Un point de l'écran (px, comme GetCursorPosition) -> son écart au centre de la vue (px de vue, y vers le bas)
local function Offset(x, y)
    local l, b, w, h = view:GetRect()
    if not l then return 0, 0 end
    local es = view:GetEffectiveScale()
    return x / es - (l + w / 2), (b + h / 2) - y / es
end

-- Le point du monde à un écart de la vue
local function WorldAt(sx, sy)
    local W, H = A.Size()
    local px = FitPx() * zoom
    return u + sx / (W * px), v + sy / (H * px)
end

-- Les bornes du curseur du jeu (ses unités) : là où il peut aller sur sa carte.
-- Pas toujours tout son cadre de défilement : le pied de l'interface manette,
-- ou une carte plus petite que le cadre, le tiennent loin d'un bord. Lues comme
-- le jeu le borne : un point très loin de chaque côté, ramené, est un coin
local function Bounds(soft)
    local bd = soft.bounds
    if not (bd and bd.ClampPointInBounds) then return end
    local ok1, l, b = pcall(bd.ClampPointInBounds, bd, -1e6, -1e6)
    local ok2, r, t = pcall(bd.ClampPointInBounds, bd, 1e6, 1e6)
    if not (ok1 and ok2) or type(l) ~= "number" or type(b) ~= "number" or type(r) ~= "number" or type(t) ~= "number" then return end
    local sl, sb, sw, sh = sc:GetRect()
    if sl then
        local k = sc:GetEffectiveScale() / soft:GetEffectiveScale()
        l, b = math.max(l, sl * k), math.max(b, sb * k)
        r, t = math.min(r, (sl + sw) * k), math.min(t, (sb + sh) * k)
    end
    if r - l < 20 or t - b < 20 then return end
    return l, b, r, t
end

-- Le curseur du jeu reste sur le cadre de défilement de sa carte, plus petit
-- que la vue : sa place dans ses bornes est reportée à la même place sur la
-- vue (px de l'écran), pour qu'il atteigne ses quatre bords
local function Project(soft, cx, cy)
    local es = soft:GetEffectiveScale()
    local vl, vb, vw, vh = view:GetRect()
    if not vl then return cx * es, cy * es end
    local fx, fy
    local l, b, r, t = Bounds(soft)
    if l then
        fx, fy = (cx - l) / (r - l), (cy - b) / (t - b)
    else
        local sl, sb, sw, sh = sc:GetRect()
        if not sl or sw <= 0 or sh <= 0 then return cx * es, cy * es end
        local ses = sc:GetEffectiveScale()
        fx, fy = (cx * es / ses - sl) / sw, (cy * es / ses - sb) / sh
    end
    fx, fy = Clamp(fx, 0, 1), Clamp(fy, 0, 1)
    local ves = view:GetEffectiveScale()
    return (vl + fx * vw) * ves, (vb + fy * vh) * ves
end

-- Le curseur de la manette (px de l'écran), tant que la carte a la manette
local function Cursor()
    local soft = _G.SoftCursor
    if not (soft and soft:IsShown()) then return end
    if map.IsCanvasGamepadFocus and not map:IsCanvasGamepadFocus() then return end
    local cx, cy = soft:GetCenter()
    if not cx then return end
    return Project(soft, cx, cy)
end

-- Le stick gauche qui pousse le curseur contre le bord de ses bornes : la
-- carte glisse de ce côté, là où le jeu ne la fait pas glisser lui-même
local function EdgePush()
    local soft = _G.SoftCursor
    if not soft then return 0, 0 end
    local cx, cy = soft:GetCenter()
    local l, b, r, t = Bounds(soft)
    if not (cx and l) then return 0, 0 end
    local sx, sy = C.Stick()
    if not sx then return 0, 0 end
    local px, py = 0, 0
    if (sx <= -EDGE_PUSH and cx <= l + EDGE_NEAR) or (sx >= EDGE_PUSH and cx >= r - EDGE_NEAR) then px = Clamp(sx, -1, 1) end
    if (sy <= -EDGE_PUSH and cy <= b + EDGE_NEAR) or (sy >= EDGE_PUSH and cy >= t - EDGE_NEAR) then py = Clamp(sy, -1, 1) end
    return px, py
end

-- La souris (px de l'écran), sur la vue
local function MouseXY()
    if not (view and view:IsVisible() and view:IsMouseOver()) then return end
    return GetCursorPosition()
end

---------------------------------------------------------------------------
-- La vue posée
---------------------------------------------------------------------------
local function Apply()
    dirty = false
    local W, H = A.Size()
    local px = FitPx() * zoom
    if not W or px <= 0 then return end
    zoom = Clamp(zoom, 1, math.max(1, MostAt(u, v), zoom))
    u, v = Clamp(u, 0, 1), Clamp(v, 0, 1)
    canvas:SetScale(px)
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", view, "CENTER", -u * W, v * H)     -- (en unités du canevas)
    local dk = DetailK()
    A.SetZoom(zoom * dk, px)
    local hw, hh = view:GetWidth() / 2, view:GetHeight() / 2
    A.SetView(u, v, hw / (W * px), hh / (H * px), zoom * dk, zoom / ns.Map.Data.ClientZoom())
    P.PlacePlayer()
    HB.Place(u, v, zoom, W, H, px, hw, hh)
    -- (la zone de la quête redessinée à la nouvelle échelle)
    if area.quest and area.frame then DrawArea(area.frame, area.quest) end
end

-- Zoomer jusqu'à `to`, le point du monde sous l'écart (sx, sy) gardé là
local function ZoomAbout(sx, sy, to)
    local W, H = A.Size()
    local cu, cv = WorldAt(sx, sy)
    local most = MostAt(cu, cv)
    if to > zoom then most = math.max(most, zoom) end
    to = Clamp(to, 1, most)
    local px = FitPx() * to
    u, v, zoom = cu - sx / (W * px), cv - sy / (H * px), to
    dirty = true
end

local function GlideTo(tu, tv, tz)
    glide = { u0 = u, v0 = v, z0 = zoom, u1 = tu, v1 = tv, z1 = Clamp(tz, 1, MostAt(tu, tv)), t = 0 }
end

local function Glide(elapsed)
    local a = glide
    a.t = math.min(1, a.t + elapsed / GLIDE_TIME)
    local e = a.t * a.t * (3 - 2 * a.t)
    zoom = math.exp(math.log(a.z0) + (math.log(a.z1) - math.log(a.z0)) * e)
    -- (le centre suit 1/zoom : un seul zoom autour d'un point fixe)
    local w = math.abs(a.z1 - a.z0) < 1e-6 and e or (1 / a.z0 - 1 / zoom) / (1 / a.z0 - 1 / a.z1)
    u, v = a.u0 + (a.u1 - a.u0) * w, a.v0 + (a.v1 - a.v0) * w
    if a.t >= 1 then glide = nil end
    dirty = true
end

-- A : dans la zone (ou le continent) sous le curseur, ou l'icône dessous
-- pressée ; X : un niveau plus loin (comme un clic, un clic droit)
local function Step(inward, pad)
    -- (les fenêtres de l'addon sur la carte d'abord, les boutons de la carte d'un donjon)
    if inward and lastX and C.Press(lastX, lastY) then return end
    if ns.Map.Dungeons.Shown() then
        if not inward then ns.Map.Dungeons.Close() end      -- (X : en sortir)
        return
    end
    -- la plume sortie : A pose la plume ou la lève, X la range
    if ns.Map.Sketch.Drawing() and ns.Sketch then
        if inward then ns.Sketch.PadPress() else ns.Sketch.Toggle(false) end
        return
    end
    -- le mode épingle : A en pose une là où est le curseur
    local E = ns.Map.MyPins
    if inward and E.Mode and E.Mode() and lastX and E.DropAt then
        local cu, cv = WorldAt(Offset(lastX, lastY))
        E.SetMode(false)
        E.DropAt(cu, cv)
        return
    end
    -- (le X de la manette, rien d'ouvert : Plus d'abord, la taille de la carte)
    if not inward and pad and onOut then
        local ok, taken = pcall(onOut)
        if ok and taken then return end
    end
    -- (l'icône sous le curseur pressée ; une qui n'a rien à presser laisse passer A)
    if inward and hovered and hovered:IsVisible() and not (hovered.openmapNoPress and not hovered.OnClick) then return Press(hovered) end
    local cu, cv
    if lastX then cu, cv = WorldAt(Offset(lastX, lastY)) else cu, cv = u, v end
    local chain = K.ChainAt(cu, cv)
    local world = K.World()
    if inward then
        for _, id in ipairs(chain) do
            if id ~= world and Stitchable(id) and FitZoom(id) > zoom * 1.05 then
                local l, r, t, b = A.Rect(id)
                GlideTo((l + r) / 2, (t + b) / 2, FitZoom(id))
                return
            end
        end
    else
        local target = world
        for _, id in ipairs(chain) do
            if id ~= world and Stitchable(id) and FitZoom(id) < zoom * 0.95 then target = id end
        end
        local l, r, t, b = A.Rect(target)
        if l then GlideTo((l + r) / 2, (t + b) / 2, FitZoom(target)) end
    end
end

local function UpdatePlayer()
    if not K.UnitWorld then return end                -- (Layers/Locate.lua)
    local pu, pv = K.UnitWorld("player")
    if not pu then P.SetPlayer(nil) return end
    P.SetPlayer(pu, pv, Plain(GetPlayerFacing and GetPlayerFacing()))
end

---------------------------------------------------------------------------
-- Le curseur de la manette, redessiné sur l'art comme le jeu le dessine (son
-- losange, et des traits jusqu'aux bords de la vue) : celui du jeu est sous la vue
---------------------------------------------------------------------------
local function Pointer(x, y)
    if not pointer then return end
    if not x then pointer:Hide() return end
    local sx, sy = Offset(x, y)
    local w, h = view:GetWidth(), view:GetHeight()
    local d, gap = pointer.diamond, 16
    d:ClearAllPoints()
    d:SetPoint("CENTER", view, "CENTER", sx, -sy)
    local lines = pointer.lines
    local lens = { w / 2 + sx - gap, w / 2 - sx - gap, h / 2 + sy - gap, h / 2 - sy - gap }
    lines[1]:ClearAllPoints() lines[1]:SetPoint("RIGHT", view, "CENTER", sx - gap, -sy)
    lines[2]:ClearAllPoints() lines[2]:SetPoint("LEFT", view, "CENTER", sx + gap, -sy)
    lines[3]:ClearAllPoints() lines[3]:SetPoint("BOTTOM", view, "CENTER", sx, -sy + gap)
    lines[4]:ClearAllPoints() lines[4]:SetPoint("TOP", view, "CENTER", sx, -sy - gap)
    for i = 1, 4 do
        local len = lens[i]
        if len >= 1 then
            if i <= 2 then lines[i]:SetSize(len, 2) else lines[i]:SetSize(2, len) end
            lines[i]:Show()
        else
            lines[i]:Hide()
        end
    end
    pointer:Show()
end

local function MakePointer(strata)
    -- (sur la carte du jeu, pas dans la vue : la vue découpe ses enfants, et
    -- le curseur se dessine d'un bloc, à son propre niveau)
    pointer = CreateFrame("Frame", nil, map)
    if strata then pointer:SetFrameStrata(strata) end
    pointer:SetAllPoints(view)
    pointer:SetFrameLevel(POINTER_LEVEL)
    pointer:Hide()
    local shade = pointer:CreateTexture(nil, "OVERLAY", nil, 6)
    local d = pointer:CreateTexture(nil, "OVERLAY", nil, 7)
    for i, t in ipairs({ shade, d }) do
        if not pcall(t.SetAtlas, t, "gamepad-mapquestlog-cursor-diamond-gold") then
            t:SetTexture("Interface\\Minimap\\Ping\\ping5")
        end
        t:SetSize(i == 1 and 38 or 35, i == 1 and 38 or 35)
    end
    shade:SetVertexColor(0, 0, 0)
    shade:SetPoint("CENTER", d, "CENTER")
    pointer.diamond = d
    pointer.lines = {}
    for i = 1, 4 do
        local line = pointer:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 0.82, 0, 0.6)
        pointer.lines[i] = line
    end
end

---------------------------------------------------------------------------
-- Le lieu sous le curseur (sinon au centre de la vue) : son nom avec les
-- niveaux de la zone, la pêche, sa carte et son continent, pour l'habillage
-- de la carte (UI/MapChrome.lua, par V.Place)
---------------------------------------------------------------------------
local function ContinentOf(chain)
    for _, id in ipairs(chain) do
        local info = id ~= K.World() and C_Map.GetMapInfo(id)
        if info and info.mapType == Enum.UIMapType.Continent then return info.name end
    end
end

-- (l'étiquette de zone de la carte du jeu, par-dessus la vue : cachée tant qu'elle est là)
local function GameLabel(alpha)
    for provider in pairs(map.dataProviders or {}) do
        if type(provider) == "table" and provider.Label and provider.Label.SetLabel then provider.Label:SetAlpha(alpha) end
    end
end

local function PlaceAt(x, y)
    local text, fishText, zone, continent
    local cu, cv
    if x then cu, cv = WorldAt(Offset(x, y)) else cu, cv = u, v end
    local chain = K.ChainAt(cu, cv)
    local id = chain[#chain]
    if id and id ~= K.World() and ns.ZoneInfo then
        local l, r, t, b = A.Rect(id)
        if l and r > l and b > t then
            -- (vue de plus loin que la zone : son nom et ses niveaux ; dessus : le lieu là)
            local whole = Stitchable(id) and FitZoom(id) > zoom * 1.05
            local ok, a, c = pcall(ns.ZoneInfo.PlaceLabel, id, (cu - l) / (r - l), (cv - t) / (b - t), whole)
            if ok then text, fishText, zone = a, c, id end
        end
    end
    if text then
        local ok, name = pcall(ContinentOf, chain)
        continent = ok and name or nil
    end
    place.key, place.fishKey, place.zone, place.continent = text, text and (fishText or "") or nil, zone, continent
end

---------------------------------------------------------------------------
-- La zone d'une quête, ombrée comme la carte du jeu ombre les siennes (son
-- QuestPOIFrame), sur le canevas de la vue au-dessus de l'art, sous les
-- icônes : celle de la quête survolée, sinon celle de la quête suivie
---------------------------------------------------------------------------
-- (dessinée pour la place du cadre à l'écran maintenant : le jeu ne la
-- calcule qu'à la mise en page suivante)
function DrawArea(f, questID)
    canvas:GetRect()
    f:GetRect()
    pcall(f.DrawNone, f)
    return pcall(f.DrawBlob, f, questID, true)
end

local function ShowArea()
    local f = area.frame
    local questID, mapID = area.hoverQ, area.hoverM
    if not questID then questID, mapID = area.focusQ, area.focusM end
    if not (questID and mapID and built and view:IsShown() and A.Rect(mapID)) then
        if f then
            pcall(f.DrawNone, f)
            f:Hide()
        end
        area.quest, area.map = nil, nil
        return
    end
    if not f then
        if area.failed then return end
        local ok, made = pcall(CreateFrame, "QuestPOIFrame", nil, canvas)
        if not ok or not made or not made.DrawBlob then area.failed = true return end
        f = made
        pcall(f.SetFillTexture, f, "Interface\\WorldMap\\UI-QuestBlob-Inside")
        pcall(f.SetBorderTexture, f, "Interface\\WorldMap\\UI-QuestBlob-Outside")
        pcall(f.SetFillAlpha, f, 128)
        pcall(f.SetBorderAlpha, f, 192)
        pcall(f.SetBorderScalar, f, 1.0)
        f:SetFrameLevel((A.artTop or canvas:GetFrameLevel() + ART_RANGE) + 1)
        area.frame = f
    end
    if area.quest == questID and area.map == mapID and f:IsShown() then return end
    local W, H = A.Size()
    local l, r, t, b = A.Rect(mapID)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", canvas, "TOPLEFT", l * W, -t * H)   -- (en unités du canevas, comme l'art)
    f:SetSize((r - l) * W, (b - t) * H)
    if f.SetMapID then pcall(f.SetMapID, f, mapID) end
    f:Show()
    if not DrawArea(f, questID) then f:Hide() return end
    area.quest, area.map = questID, mapID
end

---------------------------------------------------------------------------
-- L'icône sous le curseur : survolée comme à la souris (son info-bulle, sa
-- surbrillance), pressée par A ou un clic
---------------------------------------------------------------------------
local function Enter(pin)
    if pin == hovered then return end
    local was = hovered
    hovered = pin
    if was then
        if was.UnlockHighlight then was:UnlockHighlight() end
        local leave = was:GetScript("OnLeave")
        if leave then pcall(leave, was, false) end
        local own = _G.QuestieGamepadMapTooltip
        if HB.Shown(was) and own and own ~= GameTooltip then own:Hide() end
    end
    if pin then
        if pin.LockHighlight then pin:LockHighlight() end
        if HB.IsQuestie(pin) then                -- (celle de Questie : son info-bulle, d'ici)
            HB.Tip(pin, _G.QuestieGamepadMapTooltip or GameTooltip)
        else
            local enter = pin:GetScript("OnEnter")
            if enter then pcall(enter, pin, false) end
        end
    end
end

function Press(pin)
    -- (la fiche de Plus d'abord, ou ce que Maj, Ctrl, Alt demandent ; une
    -- icône sans place dans le monde, celle d'un autre addon, suit son cours)
    if not ownPress and onPress and pin.u and pin.v and not pin.away then
        local ok, taken = pcall(onPress, pin)
        if ok and taken then return end
    end
    -- ton épingle : sa fiche
    local p = pin.data
    if type(p) == "table" and p.id and p.map and p.x and pin.OnClick then
        pcall(pin.OnClick, pin)
        return
    end
    -- une entrée de donjon : sa carte (ou, les cartes éteintes, la vue s'en approche)
    if pin.instances then
        if pin.OnClick and ns.Map.Dungeons.MapsOn() then
            pcall(pin.OnClick, pin)
        elseif pin.u then
            GlideTo(pin.u, pin.v, math.max(zoom, 12))
        end
        return
    end
    -- un quai vers une île hors du monde dessiné : l'autre bout
    if pin.away then
        if pin.to then GlideTo(pin.to[1], pin.to[2], math.max(zoom, 6)) end
        return
    end
    if pin.OnClick then pcall(pin.OnClick, pin) end
    -- (son info-bulle de nouveau : le clic change ce qu'elle dit, le trajet d'un maître de vol)
    if hovered == pin then
        local enter = pin:GetScript("OnEnter")
        if enter then pcall(enter, pin, false) end
    end
end

---------------------------------------------------------------------------
-- Chaque image
---------------------------------------------------------------------------
local function OnUpdate(_, elapsed)
    -- (la souris qui tire la vue : elle suit le curseur, passé quelques px)
    if drag then
        local mx, my = GetCursorPosition()
        local es = view:GetEffectiveScale()
        local dx, dy = (mx - drag.x) / es, (my - drag.y) / es
        if drag.moved or dx * dx + dy * dy > 16 then
            drag.moved = true
            local W, H = A.Size()
            local px = FitPx() * zoom
            u, v, dirty = drag.u - dx / (W * px), drag.v + dy / (H * px), true
        end
    end
    local x, y = Cursor()
    local dungeon = ns.Map.Dungeons.Shown()
    local stick = x and C.ZoomTilt() or 0
    -- (sur une fenêtre de l'addon : le stick droit est sa molette)
    if overWindow and x then
        wheelWait = wheelWait - elapsed
        if stick ~= 0 and wheelFrame and wheelWait <= 0 then
            wheelWait = WHEEL_EVERY / math.max(0.3, math.abs(stick))
            local fn = wheelFrame:GetScript("OnMouseWheel")
            if fn then pcall(fn, wheelFrame, stick > 0 and 1 or -1) end
        elseif stick == 0 then
            wheelWait = 0
        end
    end
    local tilt = (dungeon or overWindow) and 0 or (stick or 0)
    if tilt ~= 0 then
        stickZoomAt = GetTime()
        glide = nil
        local sx, sy = Offset(x, y)
        ZoomAbout(sx, sy, zoom * math.exp(tilt * PAD_ZOOM_RATE * elapsed))
    end
    -- le curseur au bord de la vue : la vitesse du jeu pour sa carte (px de vue par seconde), la nôtre aussi
    local speed = x and not dungeon and not overWindow and sc.gamepadScrollSpeed
    local sxs, sys = speed and tonumber(speed.X) or 0, speed and tonumber(speed.Y) or 0
    edgePan = math.max(edgePan, math.abs(sxs), math.abs(sys))
    if x and not dungeon and not overWindow and (sxs == 0 or sys == 0) then
        local px, py = EdgePush()
        if sxs == 0 then sxs = px * edgePan end
        if sys == 0 then sys = py * edgePan end
    end
    if sxs ~= 0 or sys ~= 0 then
        glide = nil
        local W, H = A.Size()
        local px = FitPx() * zoom
        u, v = u + sxs * elapsed / (W * px), v - sys * elapsed / (H * px)
        dirty = true
    end
    if glide then Glide(elapsed) end
    if x then lastX, lastY = x, y end
    playerWait = playerWait - elapsed
    if playerWait <= 0 then
        playerWait = PLAYER_EVERY
        UpdatePlayer()
    end
    if dirty then Apply() end
    Pointer(x, y)
    hbdWait = hbdWait - elapsed
    if hbdWait <= 0 then
        hbdWait = 0.5
        HB.Scan()
        -- (les icônes des autres addons posées sur la vue, sans redessiner toute la carte)
        local W, Ht = A.Size()
        local px = FitPx() * zoom
        if W and px > 0 then HB.Place(u, v, zoom, W, Ht, px, view:GetWidth() / 2, view:GetHeight() / 2) end
    end
    hoverWait = hoverWait - elapsed
    if hoverWait <= 0 then
        hoverWait = HOVER_EVERY
        local ctl, blocked
        if x then ctl, blocked = C.ControlAt(x, y) end
        overWindow = (ctl or blocked) and true or false
        wheelFrame = overWindow and C.WheelAt(x, y) or nil
        if ctl or blocked or dungeon then Enter(ctl)
        else Enter(x and (P.At(x, y, REACH) or HB.At(x, y)) or nil) end
        -- (le lieu : pas sur une fenêtre ni la carte d'un donjon ; la souris sinon)
        local px, py = x, y
        if not px then px, py = MouseXY() end
        if ctl or blocked or dungeon then px, py = nil, nil end
        PlaceAt(px, py)
    end
end

---------------------------------------------------------------------------
-- Bâtir la vue, la montrer
---------------------------------------------------------------------------
-- La vue au-dessus de toute la carte du jeu : sa barre, ses boutons, son
-- journal de quêtes (que le jeu met en strate HIGH), le pied de l'interface
-- manette. Elle va dans la plus haute strate parmi eux, jusqu'à HIGH, à un
-- niveau au-dessus des leurs ; les fenêtres de l'addon (MyMapIsRich…, celles
-- du curseur) n'en sont pas et restent au-dessus
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local STRATA_NAME = {}
for name, rank in pairs(STRATA) do STRATA_NAME[rank] = name end
local strataUsed

local function Cover()
    local own = {}
    for _, f in ipairs(C.Roots()) do own[f] = true end
    local limit = sc:GetFrameLevel() + 8000
    local topRank, topLevel = STRATA[map:GetFrameStrata()] or 3, sc.Child:GetFrameLevel()
    local seen = {}
    local function Walk(f, depth)
        if not f or seen[f] or f == view or f == sc or own[f] or not f.GetFrameLevel then return end
        seen[f] = true
        local name = f.GetName and f:GetName()
        if type(name) == "string" and name:find("^MyMapIsRich") then return end
        local rank = STRATA[f:GetFrameStrata()] or 3
        local level = f:GetFrameLevel()
        if rank <= STRATA.HIGH and level < limit then
            if rank > topRank then topRank, topLevel = rank, level
            elseif rank == topRank and level > topLevel then topLevel = level end
        end
        if depth > 0 then
            for _, child in ipairs({ f:GetChildren() }) do Walk(child, depth - 1) end
        end
    end
    for _, child in ipairs({ map:GetChildren() }) do Walk(child, 4) end
    Walk(map.worldMapFooter, 4)
    Walk(_G.QuestMapFrame, 4)
    return STRATA_NAME[topRank] or map:GetFrameStrata(), topLevel
end

local function Fail(why, detail)
    failed, diag.why, diag.detail = true, why, detail and tostring(detail) or nil
    return false
end

local function Build()
    if built or failed then return built end
    if A.IsBuilt() then return Fail("VIEW_WHY_TWICE") end
    local base = sc.Child:GetFrameLevel() + 2
    local ok, strata, top = pcall(Cover)
    if ok and strata then
        view:SetFrameStrata(strata)
        strataUsed = strata
        base = (strata == map:GetFrameStrata()) and math.max(base, top + 2) or (top + 2)
        diag.cover = strata .. " " .. tostring(top)
    end
    view:SetFrameLevel(base)
    canvas:SetFrameLevel(base)
    local okB, err = pcall(A.Build, canvas, base + 1, ART_RANGE, base + ART_RANGE + 4)
    if not okB then return Fail("VIEW_WHY_ART", err) end
    local W, H = A.Size()
    if not A.IsBuilt() then return Fail("VIEW_WHY_ART", W) end
    local okL, laid = pcall(A.Layout, K.World())
    if not okL or not laid then return Fail("VIEW_WHY_LAYOUT", laid) end
    canvas:SetSize(W, H)
    -- (les icônes de la carte et ta flèche, au-dessus du dessin : Map/PinSets.lua)
    P.Setup(view, base + ART_RANGE + 4)
    P.RaiseArrow(math.min(9900, base + ARROW_ABOVE))
    MakePointer(strataUsed)
    HB.Setup(view, base + ART_RANGE + 10)
    A.SetShown(true)
    built = true
    diag.why = "VIEW_WHY_BUILT"
    -- (les calques de Plus posent leurs jeux d'icônes, puis l'aspect les allume ou les éteint)
    ns.Fire("MAP_BUILT")
    LK.Apply()
    return true
end

-- La vue où ouvrir, rien d'autre ne le disant : autour de toi, ta zone pleine vue
local function FirstView()
    local pu, pv, best
    if K.UnitWorld then pu, pv, best = K.UnitWorld("player") end
    if pu then
        u, v = pu, pv
        local zone = best
        while zone and not Stitchable(zone) do
            local info = C_Map.GetMapInfo(zone)
            zone = info and info.parentMapID and info.parentMapID > 0 and info.parentMapID or nil
        end
        zoom = zone and FitZoom(zone) or 4
    else
        u, v, zoom = 0.5, 0.5, 1
    end
end

local function Show()
    diag.shows = diag.shows + 1
    if not Build() then
        view:Hide()
        if built then sc.Child:SetAlpha(1) end
        return
    end
    -- (la vue où rouvrir : Layers/Locate.lua ; rien à suivre (dans une
    -- instance, rien de gardé) : là où elle était, sinon autour de toi)
    local su, sv, sz
    if V.SavedView then
        local ok, a, b, c = pcall(V.SavedView)
        if ok then su, sv, sz = a, b, c end
    end
    if su and sv and sz and sz > 0 and K.Finite(su, sv, sz) then
        u, v, zoom = su, sv, Clamp(sz, 1, MostAt(su, sv))
    elseif not u then
        FirstView()
    end
    HB.Show()
    glide = nil
    sc.Child:SetAlpha(0)      -- (la carte du jeu dessous : là, invisible ; rien d'elle n'est écrit)
    pcall(GameLabel, 0)
    view:Show()
    dirty = true
end

local function Hide()
    -- (la vue à la fermeture, pour la réouverture : Layers/Locate.lua)
    if built and view:IsShown() and V.Remember then pcall(V.Remember) end
    Enter(nil)
    HB.Hide()
    if ns.Map.Dungeons.Shown() then pcall(ns.Map.Dungeons.Close, true) end
    view:Hide()
    if pointer then pointer:Hide() end
    place.key, place.fishKey, place.zone, place.continent = nil, nil, nil, nil
    area.hoverQ, area.hoverM = nil, nil
    ShowArea()
    if built then pcall(GameLabel, 1) end
    glide, lastX, lastY, drag = nil, nil, nil, nil
    if sc and sc.Child then sc.Child:SetAlpha(1) end
end

-- La carte réduite (une fenêtre, le jeu visible autour) : la vue sur la
-- fenêtre de la carte du jeu, qu'elle couvre comme elle couvrait l'écran (Plus
-- garde cette carte en fenêtre : son réglage miniWorldMap, posé quand elle est
-- fermée). La carte du jeu en plein écran quand même : une fenêtre au milieu
local function PlaceView()
    if not view then return end
    view:ClearAllPoints()
    if not small then
        view:SetAllPoints(UIParent)
    elseif not (map.IsMaximized and map:IsMaximized()) then
        -- (la fenêtre du jeu, sans son journal de quêtes : la vue s'en tient à la
        -- carte, du coin haut gauche de la fenêtre au bord droit du canevas,
        -- jusqu'en bas de la fenêtre)
        view:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
        local mb, sb = map:GetBottom(), sc:GetBottom()
        local gap = (mb and sb) and math.max(0, sb - mb) or 0
        view:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", 0, -gap)
    else
        view:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        view:SetSize(math.floor(UIParent:GetWidth() * SMALL_W), math.floor(UIParent:GetHeight() * SMALL_H))
    end
    dirty = true
end

---------------------------------------------------------------------------
-- Le point de destination du stick gauche enfoncé : celui du jeu se pose là
-- où est son curseur sur sa carte dessous, pas sur cette vue ; il est reposé
-- là où est le curseur ici, sur la zone qui y est. Seul celui que le stick
-- vient de poser (lu à la fin de l'appel du jeu) ; celui d'un autre addon
-- reste où cet addon l'a mis
---------------------------------------------------------------------------
local STICK_NEAR = 0.005        -- un point si près du curseur du jeu sur sa carte (0..1) est celui qu'il vient de poser

local function WaypointAt(mapID, x, y)
    if not (C_Map.HasUserWaypoint and C_Map.GetUserWaypoint and C_Map.HasUserWaypoint()) then return false end
    local point = C_Map.GetUserWaypoint()
    local pos = point and point.uiMapID == mapID and point.position
    if not pos then return false end
    local wx, wy
    if pos.GetXY then wx, wy = pos:GetXY() else wx, wy = pos.x, pos.y end
    wx, wy = Plain(wx), Plain(wy)
    if type(wx) ~= "number" or type(wy) ~= "number" then return false end
    return math.abs(wx - x) <= STICK_NEAR and math.abs(wy - y) <= STICK_NEAR
end

local function PutAgain()
    if not (view:IsShown() and lastX) then return end
    local cu, cv = WorldAt(Offset(lastX, lastY))
    local zone, x, y = K.ZoneAt(cu, cv)
    if zone and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(zone)) then
        pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(zone, x, y))
    end
end

-- (une règle du jeu qui éteint les points de la carte : celui du jeu ne fait rien alors)
local function PinsOff()
    local rule = Enum and Enum.GameRule and Enum.GameRule.WorldMapTrackingPinDisabled
    return rule ~= nil and C_GameRules ~= nil and C_GameRules.IsGameRuleActive ~= nil and C_GameRules.IsGameRuleActive(rule) and true or false
end

local function PadPressed()
    if not (built and view:IsShown() and map.GetNormalizedGamepadCursorPosition) then return end
    local ok, mapID, x, y = pcall(function()
        if PinsOff() then return end
        return map:GetMapID(), map:GetNormalizedGamepadCursorPosition()
    end)
    if not ok or type(mapID) ~= "number" or type(Plain(x)) ~= "number" or type(Plain(y)) ~= "number" then return end
    local ok2, stick = pcall(WaypointAt, mapID, x, y)
    if ok2 and stick then
        PutAgain()
        if ns.Map.Waypoint.Refresh then pcall(ns.Map.Waypoint.Refresh) end
    end
end

---------------------------------------------------------------------------
-- La mise en place, une fois (à la connexion)
---------------------------------------------------------------------------
local function Setup()
    map = _G.WorldMapFrame
    sc = map and map.ScrollContainer
    if view then return end
    if not (sc and sc.Child and map.GetCanvas) then
        diag.setup = "VIEW_SETUP_ODD"
        return
    end
    diag.setup = "VIEW_SETUP_DONE"
    -- (enfant de la carte du jeu : elle s'ouvre et se ferme avec elle)
    view = CreateFrame("Frame", nil, map)
    PlaceView()
    view:SetClipsChildren(true)
    view:Hide()
    canvas = CreateFrame("Frame", nil, view)
    canvas:SetSize(1, 1)
    view:SetScript("OnUpdate", OnUpdate)
    view:SetScript("OnSizeChanged", function() dirty = true end)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", function(_, delta)
        local sx, sy = Offset(GetCursorPosition())
        glide, stickZoomAt = nil, GetTime()
        ZoomAbout(sx, sy, zoom * (delta > 0 and 1.25 or 0.8))
    end)
    view:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local mx, my = GetCursorPosition()
        drag, glide = { x = mx, y = my, u = u, v = v }, nil
    end)
    view:SetScript("OnMouseUp", function(_, button)
        local d = drag
        drag = nil
        if d and d.moved then return end
        lastX, lastY = GetCursorPosition()
        -- (ce que Plus fait d'un clic d'abord, avec Maj, Ctrl ou Alt : un
        -- itinéraire, une épingle, les actions ; le bouton du milieu te localise)
        if onClick then
            local ok, taken = pcall(onClick, button)
            if ok and taken then return end
        end
        if button == "MiddleButton" then
            if V.FindMe then pcall(V.FindMe, true) end
            return
        end
        if button ~= "LeftButton" and button ~= "RightButton" then return end
        local h = hovered
        hovered = nil          -- (l'icône de la manette n'est pas celle de la souris)
        Step(button == "LeftButton")
        hovered = h
    end)
    map:HookScript("OnShow", function()
        PlaceView()
        if small then C_Timer.After(0, PlaceView) end   -- (la fenêtre mise en page d'ici là)
    end)
    map:HookScript("OnShow", Show)
    map:HookScript("OnHide", Hide)
    for _, method in ipairs({ "Maximize", "Minimize" }) do
        if type(map[method]) == "function" then hooksecurefunc(map, method, PlaceView) end
    end
    -- A et X : après ceux du jeu (GamepadMapClick, GamepadMapUp) sur sa carte dessous
    if map.NavigateToGamepadCursor then
        hooksecurefunc(map, "NavigateToGamepadCursor", function() if view:IsShown() then Step(true) end end)
    end
    if map.NavigateToParentMap then
        hooksecurefunc(map, "NavigateToParentMap", function() if view:IsShown() then Step(false, true) end end)
    end
    if map.GamepadTryPlaceWaypoint then hooksecurefunc(map, "GamepadTryPlaceWaypoint", PadPressed) end
    if map:IsShown() then Show() end
end

---------------------------------------------------------------------------
-- Pour le reste de Plus (ns.Map.View, ns.Map.Cursor)
---------------------------------------------------------------------------
-- Mettre la vue en place (Plus/Core.lua, à la connexion)
function V.Start()
    diag.started = diag.started + 1
    if _G.WorldMapFrame then
        Setup()
    elseif EventUtil and EventUtil.ContinueOnAddOnLoaded then
        diag.setup = "VIEW_SETUP_WAITING"
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Setup)
    end
end
function V.Built() return built end
function V.On() return built end
function V.Frame() if built then return view end end
-- La strate des cadres posés sur la vue
function V.Strata() return strataUsed end
-- Où elle regarde : u, v (le monde, 0..1) et le zoom (1 : le monde entier)
function V.Now() if built and u then return u, v, zoom end end
-- Glisser jusqu'à u, v (et un zoom), ou s'y poser tout de suite
function V.Glide(tu, tv, tz) if built then GlideTo(tu, tv, tz or zoom) end end
function V.Show(tu, tv, tz)
    if not built then return end
    glide = nil
    u, v, zoom = tu, tv, Clamp(tz or zoom, 1, MostAt(tu, tv))
    dirty = true
end
-- Glisser jusqu'à montrer tout un rectangle du monde (fill : la part de la vue)
function V.GlideToRect(u0, v0, u1, v1, fill)
    if not built then return end
    local W, H = A.Size()
    local z = math.min(view:GetWidth() / ((u1 - u0) * W), view:GetHeight() / ((v1 - v0) * H)) / FitPx() / (fill or 1)
    GlideTo((u0 + u1) / 2, (v0 + v1) / 2, z)
end
-- Le zoom qui montre toute une carte du jeu
function V.FitZoom(mapID) if built and mapID then return FitZoom(mapID) end end
-- La moitié de la vue, en unités du monde, à ce zoom
function V.HalfExtents(z)
    if not built then return end
    local W, H = A.Size()
    local px = FitPx() * (z or zoom)
    return view:GetWidth() / 2 / (W * px), view:GetHeight() / 2 / (H * px)
end
-- Où est un point du monde sur la vue : son écart au centre (px de vue, y vers le bas)
function V.Offset(pu, pv)
    if not (built and u and pu and pv) then return end
    local W, H = A.Size()
    local px = FitPx() * zoom
    return (pu - u) * W * px, (pv - v) * H * px
end
-- Le lieu sous le curseur, sinon au centre : son nom (et les niveaux), la pêche, sa carte, son continent
function V.Place()
    if not (built and view:IsShown()) then return end
    if not place.key then PlaceAt(nil) end
    return place.key, place.fishKey, place.zone, place.continent
end
-- Un cran de molette sur la vue, autour de la souris
function V.Wheel(delta)
    if not built then return end
    local sx, sy = Offset(GetCursorPosition())
    glide, stickZoomAt = nil, GetTime()
    ZoomAbout(sx, sy, zoom * (delta > 0 and 1.25 or 0.8))
end
function V.Animating() return glide ~= nil end
-- Un zoom du joueur en cours (la molette, une glissade, le stick)
function V.Zooming() return glide ~= nil or GetTime() - stickZoomAt < 0.2 end
-- La vue redessinée (un réglage changé : Map/Look.lua)
function V.Redraw() dirty = true end
-- La zone d'une quête mise en valeur (nil : plus aucune) ; et la quête suivie
function V.QuestArea(questID, mapID)
    area.hoverQ, area.hoverM = questID, questID and mapID or nil
    ShowArea()
end
function V.QuestFocus(questID, mapID)
    area.focusQ, area.focusM = questID, questID and mapID or nil
    ShowArea()
end
-- Ce que Plus fait d'un clic sur la carte, du X de la manette, d'une icône choisie
function V.SetClickHandler(fn) onClick = fn end
function V.SetOutHandler(fn) onOut = fn end
function V.SetPressHandler(fn) onPress = fn end
-- (l'habillage de Plus nomme la zone : la vue n'a pas d'étiquette à elle)
function V.SetChrome() end
-- La carte réduite ou en plein écran
function V.SetSmall(on)
    small = on and true or false
    PlaceView()
end
function V.Small() return small end
-- L'action d'une icône elle-même (sa carte de donjon, le trajet d'un maître de vol, la fiche d'une épingle)
-- Une icône cliquée à la souris (Map/PinSets.lua) : la fiche de Plus d'abord, puis son action
function V.Press(pin) if pin then Press(pin) end end
function V.PinAction(pin)
    if not pin then return end
    ownPress = true
    local ok, err = pcall(Press, pin)
    ownPress = false
    if not ok and geterrorhandler then geterrorhandler()(err) end
end

-- Le curseur de la manette sur l'écran (x, y), s'il est sur la carte
function C.XY() if built then return Cursor() end end
-- Le point du monde sous le curseur (la manette, sinon la souris, sinon le
-- dernier) : u, v, et les unités du monde par px de vue
function C.World()
    if not built then return end
    local x, y = Cursor()
    if not x then x, y = MouseXY() end
    if not x then x, y = lastX, lastY end
    if not x then return end
    local W, H = A.Size()
    local px = FitPx() * zoom
    local cu, cv = WorldAt(Offset(x, y))
    return cu, cv, 1 / (W * px), 1 / (H * px)
end

-- /mmir carte status : où en est la vue
function V.Diag()
    local size = view and ("%.0f x %.0f"):format(view:GetWidth(), view:GetHeight()) or "-"
    local why = L[diag.why] or diag.why
    if diag.detail then why = why .. " (" .. diag.detail .. ")" end
    ns.Print(L.VIEW_DIAG, L[diag.setup] or diag.setup, diag.shows, why,
        tostring(view and view:IsShown() or false), size, diag.cover or "-", tostring(small))
end
