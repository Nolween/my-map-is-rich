-- Le panneau de trajet : pendant un itinéraire, un petit cadre à la charte
-- qui dit où on en est, sans ouvrir la carte.
--   l'en-tête   « Itinéraire » (ou « En vol », « Retour au corps ») et la destination
--   l'étape     sa couleur (celle du tracé), « Étape 1 / 3 · à pied », ce qu'il
--               faut faire, et ce qu'il reste d'une marche (yd)
--   le temps    le temps qu'il reste, et l'heure d'arrivée
--   la barre    découpée par étape, aux couleurs du tracé (Travel/Route.lua) :
--               les étapes faites pleines, celle en cours à moitié
--   le bas      « +2 destinations dans la file », ou l'étape d'après un vol
--   la flèche   sous le panneau, une flèche GPS vers le point de l'étape, par
--               rapport à là où tu regardes ; verte dans l'axe (réglage
--               « Flèche GPS »)
-- En vol, la barre est celle du vol (le temps mesuré par OpenMap quand il le
-- connaît), et une alerte s'affiche avant l'atterrissage. En fantôme, le
-- panneau mène au corps. Pendant un ralliement (Travel/Share.lua), le temps
-- de chaque membre du groupe s'ajoute en dessous.
-- En jeu, à la place choisie (on le glisse à la souris) : la carte plein
-- écran le cache (le tracé et la fiche y disent déjà le trajet) ; la carte
-- réduite le laisse, puisqu'on marche avec elle ouverte. Masqué en
-- combat ; réglage « Panneau de trajet » (onglet Trajets).
-- Repliable : la flèche de son coin (ou le bouton de l'onglet Trajets, à la
-- manette, ou /mmir panneau replier) ne laisse que l'en-tête et le temps qu'il
-- reste (ns.db.options.hudFolded) ; la flèche GPS reste.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local H = {}
ns.RouteHud = H

local WIDTH = 300
local PAD = 12
local BAR_H, BAR_GAP = 8, 3
local WELL_H = 66
local ARROW = 72             -- la flèche GPS, sous le panneau
local DEFAULT_POS = { "TOPLEFT", 20, -170 }

local frame
local segs, members = {}, {}

local function T() return ns.Travel end
local function R() return ns.TravelRoute end

---------------------------------------------------------------------------
-- Les textes
---------------------------------------------------------------------------
-- Une durée lisible : « 4 min 40 », « 1 h 05 », « 38 s »
function H.Duration(secs)
    secs = math.max(0, math.floor((secs or 0) + 0.5))
    if secs >= 3600 then return L.TIME_H_MIN:format(math.floor(secs / 3600), math.floor(secs % 3600 / 60)) end
    if secs >= 60 then return L.TIME_MIN_SEC:format(math.floor(secs / 60), secs % 60) end
    return L.TIME_SEC:format(secs)
end

-- L'heure d'arrivée (l'heure de l'ordinateur)
local function Arrival(secs)
    if not (date and time) then return "" end
    return L.HUD_ARRIVAL:format(date("%H:%M", time() + math.floor(secs or 0)))
end

-- Une distance : « 380 yd », « 1 240 yd »
function H.Yards(d)
    d = math.floor((d or 0) + 0.5)
    local s = tostring(d)
    if d >= 1000 then s = ("%d %03d"):format(math.floor(d / 1000), d % 1000) end
    return L.HUD_YARDS:format(s)
end

local KINDS = {
    walk = "KIND_WALK", flight = "KIND_FLIGHT", boat = "KIND_BOAT",
    zeppelin = "KIND_ZEPPELIN", portal = "KIND_PORTAL", tram = "KIND_TRAM",
}

local function KindColor(kind)
    local c = R().COLORS[kind] or R().COLORS.walk
    return c[1], c[2], c[3]
end

---------------------------------------------------------------------------
-- Le cadre
---------------------------------------------------------------------------
-- La carte ouverte cache-t-elle le jeu (plein écran, ou la carte classique) ?
-- La carte réduite le laisse visible : le panneau y reste, à sa place, comme
-- en jeu (on y marche carte ouverte)
local function MapCovers()
    return ns.MapShown() and not ns.MapSmall()
end

local function SavePos()
    if not (frame and ns.db) or MapCovers() then return end
    local point, _, _, x, y = frame:GetPoint(1)
    ns.db.options.hudPos = { point or "TOPLEFT", math.floor(x or 0), math.floor(y or 0) }
end

local function Place()
    if not frame then return end
    frame:ClearAllPoints()
    local pos = ns.db and ns.db.options.hudPos
    if type(pos) ~= "table" then pos = DEFAULT_POS end
    frame:SetPoint(pos[1] or "TOPLEFT", UIParent, pos[1] or "TOPLEFT", pos[2] or 20, pos[3] or -170)
end

function H.ResetPosition()
    if ns.db then ns.db.options.hudPos = nil end
    Place()
end

local function Build()
    if frame then return end
    local f = CreateFrame("Frame", "MyMapIsRichPlusRouteHud", UIParent)
    frame = f
    f:SetWidth(WIDTH)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(6000)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not MapCovers() then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePos()
    end)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    UI.Fade(f.bg, "VERTICAL", "panelBottom", 0.95, "panelTop", 0.95)
    UI.Border(f, "panelEdge", 1)
    UI.Border(f, 0, 0, 0, 0.7, 1)

    -- (replier / déplier : une flèche dans le coin)
    f.fold = UI.Button(f, "", 20, 20, "grey")
    f.fold:SetPoint("TOPRIGHT", -8, -8)
    f.fold.arrow = f.fold:CreateTexture(nil, "ARTWORK")
    f.fold.arrow:SetSize(10, 9)
    f.fold.arrow:SetPoint("CENTER")
    f.fold.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    f.fold:SetScript("OnClick", function() H.ToggleFold() end)
    UI.Tip(f.fold, function() return ns.db.options.hudFolded and L.HUD_UNFOLD or L.HUD_FOLD end)

    f.title = UI.Text(f, "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", PAD, -PAD)
    f.dest = UI.DimText(f, "")
    f.dest:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
    f.dest:SetPoint("RIGHT", f.fold, "LEFT", -6, 0)
    f.dest:SetJustifyH("RIGHT")
    f.dest:SetWordWrap(false)

    -- (l'étape en cours, en retrait)
    local well = UI.Well(f)
    well:SetPoint("TOPLEFT", PAD, -40)
    well:SetPoint("TOPRIGHT", -PAD, -40)
    well:SetHeight(WELL_H)
    f.well = well
    f.dot = well:CreateTexture(nil, "ARTWORK")
    f.dot:SetSize(14, 14)
    f.dot:SetPoint("TOPLEFT", 10, -10)
    f.dot:SetTexture("Interface\\COMMON\\Indicator-Gray")
    f.stepNo = UI.Text(well, "GameFontDisableSmall")
    f.stepNo:SetPoint("TOPLEFT", 32, -9)
    f.stepNo:SetPoint("RIGHT", -10, 0)
    f.stepNo:SetJustifyH("LEFT")
    f.step = UI.Text(well, "GameFontHighlight")
    f.step:SetPoint("TOPLEFT", f.stepNo, "BOTTOMLEFT", 0, -3)
    f.step:SetPoint("RIGHT", -10, 0)
    f.step:SetJustifyH("LEFT")
    f.step:SetJustifyV("TOP")
    if f.step.SetMaxLines then f.step:SetMaxLines(2) end
    f.dist = UI.Text(well, "GameFontNormalSmall")
    f.dist:SetPoint("BOTTOMLEFT", 32, 8)

    -- (le temps qu'il reste, l'heure d'arrivée)
    f.time = UI.Text(f, "GameFontNormalHuge")
    f.time:SetPoint("TOPLEFT", well, "BOTTOMLEFT", 0, -10)
    f.timeSub = UI.DimText(f, "")
    f.timeSub:SetPoint("BOTTOMLEFT", f.time, "BOTTOMRIGHT", 6, 2)
    f.arrival = UI.DimText(f, "", "GameFontHighlight")
    f.arrival:SetPoint("BOTTOMRIGHT", f.time, "BOTTOMRIGHT", 0, 0)
    f.arrival:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    f.arrival:SetJustifyH("RIGHT")

    -- (la barre découpée par étape)
    f.bar = CreateFrame("Frame", nil, f)
    f.bar:SetHeight(BAR_H)
    f.bar:SetPoint("TOPLEFT", f.time, "BOTTOMLEFT", 0, -10)
    f.bar:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)

    -- (l'alerte d'atterrissage)
    f.alert = UI.Text(f, "GameFontNormal")
    f.alert:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 0, -8)
    f.alert:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    f.alert:SetJustifyH("LEFT")

    -- (le bas : la file, l'étape d'après, la résurrection)
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetHeight(1)
    UI.Fill(f.rule, "edgeDim", 1)
    f.foot = UI.DimText(f, "")
    f.foot:SetJustifyH("LEFT")
    if f.foot.SetMaxLines then f.foot:SetMaxLines(2) end

    -- (le ralliement)
    f.rallyHead = UI.Text(f, "GameFontNormal")

    -- (la flèche GPS, sous le panneau : un disque sombre au liseré du panneau,
    -- un cran doré en haut pour « devant toi », et la flèche de l'addon
    -- (Media/Arrow.tga, tools/media/Arrow.ps1) qui tourne dedans ; dorée,
    -- verte quand on va dans la bonne direction)
    local a = CreateFrame("Frame", nil, f)
    a:SetSize(ARROW, ARROW)
    a:SetPoint("TOP", f, "BOTTOM", 0, -UI.PAGE_GAP)
    UI.Fill(UI.Disc(a, ARROW, "BACKGROUND", 0), "panelEdge", 1)
    UI.Fade(UI.Disc(a, ARROW - 2, "BACKGROUND", 1), "VERTICAL", "panelBottom", 0.95, "panelTop", 0.95)
    a.notch = a:CreateTexture(nil, "BORDER")
    a.notch:SetSize(2, 6)
    a.notch:SetPoint("TOP", 0, -3)
    UI.Fill(a.notch, "goldDim", 1)
    a.tex = a:CreateTexture(nil, "ARTWORK")
    a.tex:SetSize(ARROW - 14, ARROW - 14)
    a.tex:SetPoint("CENTER")
    a.tex:SetTexture("Interface\\AddOns\\MyMapIsRich\\Media\\Arrow")
    a:Hide()
    a:SetScript("OnUpdate", function(self, elapsed) H.UpdateArrow(self, elapsed) end)
    f.arrow = a
    f:Hide()
    Place()
end

---------------------------------------------------------------------------
-- La flèche GPS : la direction du point que vise l'étape (Travel/Guide.lua,
-- T.Target), par rapport à là où regarde le personnage. Les points du monde
-- (Pl.WorldOf) : x vers le nord, y vers l'ouest ; l'angle depuis le nord,
-- dans le sens inverse des aiguilles d'une montre, comme GetPlayerFacing
-- (et comme HereBeDragons)
---------------------------------------------------------------------------
local ARROW_EVERY = 0.03
local ON_COURSE = math.rad(15)   -- d'aussi près dans l'axe : verte
local arrowWait = 0

local function Facing()
    if not GetPlayerFacing then return end
    local ok, f = pcall(GetPlayerFacing)
    if not ok or type(f) ~= "number" or (issecretvalue and issecretvalue(f)) then return end
    return f
end

function H.UpdateArrow(a, elapsed)
    arrowWait = arrowWait - (elapsed or 0)
    if arrowWait > 0 then return end
    arrowWait = ARROW_EVERY
    local target = T() and T().Target()
    local here = target and ns.TravelPlanner.PlayerPoint()
    local facing = here and Facing()
    if not (facing and here.cont == target.cont) then
        a.tex:SetAlpha(0.25)
        return
    end
    local north, west = target.x - here.x, target.y - here.y
    if north * north + west * west < 1 then return end
    local turn = math.atan2(west, north) - facing
    a.tex:SetRotation(turn)
    -- (dans l'axe : verte ; sinon dorée)
    local off = math.abs((turn + math.pi) % (2 * math.pi) - math.pi)
    if off <= ON_COURSE then a.tex:SetVertexColor(0.35, 1, 0.35) else a.tex:SetVertexColor(1, 0.82, 0) end
    a.tex:SetAlpha(1)
end

-- Un morceau de la barre
local function Seg(i)
    local s = segs[i]
    if s then return s end
    s = CreateFrame("Frame", nil, frame.bar)
    s:SetHeight(BAR_H)
    s.bg = s:CreateTexture(nil, "BACKGROUND")
    s.bg:SetAllPoints()
    s.fill = s:CreateTexture(nil, "ARTWORK")
    s.fill:SetPoint("TOPLEFT")
    s.fill:SetPoint("BOTTOMLEFT")
    s.edge = UI.Border(s, 1, 1, 1, 0.5)
    segs[i] = s
    return s
end

-- La barre : des parts (secs, kind, done 0..1)
local function DrawBar(parts)
    local width = frame.bar:GetWidth()
    if not width or width <= 0 then width = WIDTH - 2 * PAD end
    local total = 0
    for _, p in ipairs(parts) do total = total + math.max(p.secs, 1) end
    local free = width - BAR_GAP * (#parts - 1)
    local x = 0
    for i, p in ipairs(parts) do
        local s = Seg(i)
        local w = math.max(4, free * math.max(p.secs, 1) / total)
        if i == #parts then w = math.max(4, width - x) end
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", frame.bar, "TOPLEFT", x, 0)
        s:SetWidth(w)
        local r, g, b = KindColor(p.kind)
        s.bg:SetColorTexture(r, g, b, 0.18)
        s.edge:SetColor(r, g, b, 0.6)
        local done = math.max(0, math.min(1, p.done or 0))
        s.fill:SetColorTexture(r, g, b, 0.95)
        s.fill:SetWidth(math.max(0.01, w * done))
        s.fill:SetShown(done > 0)
        s:Show()
        x = x + w + BAR_GAP
    end
    for i = #parts + 1, #segs do segs[i]:Hide() end
end

-- Une ligne du ralliement
local function Member(i)
    local m = members[i]
    if m then return m end
    m = CreateFrame("Frame", nil, frame)
    m:SetHeight(16)
    m.name = UI.Text(m, "GameFontHighlightSmall")
    m.name:SetPoint("LEFT", 0, 0)
    m.name:SetWidth(78)
    m.name:SetJustifyH("LEFT")
    m.name:SetWordWrap(false)
    m.eta = UI.Text(m, "GameFontHighlightSmall")
    m.eta:SetPoint("RIGHT", 0, 0)
    m.eta:SetWidth(80)
    m.eta:SetJustifyH("RIGHT")
    m.track = m:CreateTexture(nil, "BACKGROUND")
    m.track:SetPoint("LEFT", m.name, "RIGHT", 6, 0)
    m.track:SetPoint("RIGHT", m.eta, "LEFT", -6, 0)
    m.track:SetHeight(6)
    UI.Fill(m.track, "well", 1)
    m.fill = m:CreateTexture(nil, "ARTWORK")
    m.fill:SetPoint("LEFT", m.track, "LEFT", 0, 0)
    m.fill:SetHeight(6)
    members[i] = m
    return m
end

---------------------------------------------------------------------------
-- Ce qu'il montre
---------------------------------------------------------------------------
local function Wanted()
    if not (ns.db and ns.db.options.travelHud ~= false and ns.Ready()) then return false end
    if InCombatLockdown() then return false end
    -- (carte plein écran ouverte : caché ; le tracé et la fiche disent le trajet)
    if MapCovers() then return false end
    local share = ns.TravelShare
    return (T() and T().Active()) or (share and share.Rally() ~= nil) or false
end

function H.Refresh()
    if not Wanted() then
        if frame then frame:Hide() end
        return
    end
    Build()
    local f = frame
    local st = T().Status()
    local y = -40 - WELL_H
    if st then
        local leg, legs = st.leg, st.plan.legs
        local flying = st.flight ~= nil
        f.title:SetText(st.corpse and L.HUD_CORPSE or flying and L.HUD_FLIGHT or L.HUD_TITLE)
        f.dest:SetText(st.corpse and "" or L.HUD_TO:format(T().GoalName(st.goal)))
        f.well:Show()
        f.dot:SetVertexColor(KindColor(leg and leg.kind or "walk"))
        local kind = L[KINDS[leg and leg.kind or "walk"]] or ""
        if st.corpse then kind = L.HUD_GHOST end
        f.stepNo:SetText(L.HUD_STEP:format(st.index, #legs, kind))
        f.step:SetText(leg and T().LegText(leg) or "")
        f.dist:SetText(st.legLeft and H.Yards(st.legLeft) or "")
        f.time:Show()
        f.bar:Show()
        if flying then
            f.time:SetText(H.Duration(st.flight.left))
            f.timeSub:SetText(L.HUD_FLIGHT_LEFT)
            DrawBar({ { secs = 1, kind = "flight", done = 1 - st.flight.left / st.flight.total } })
        else
            f.time:SetText(H.Duration(st.remaining))
            f.timeSub:SetText(L.HUD_LEFT)
            local parts = {}
            for i, l in ipairs(legs) do
                local done = 0
                if i < st.index then
                    done = 1
                elseif i == st.index and l.kind == "walk" and st.legLeft and l.points then
                    local len = 0
                    for k = 2, #l.points do
                        len = len + math.sqrt((l.points[k].x - l.points[k - 1].x) ^ 2 + (l.points[k].y - l.points[k - 1].y) ^ 2)
                    end
                    if len > 0 then done = 1 - math.min(1, st.legLeft / len) end
                end
                parts[i] = { secs = l.secs, kind = l.kind, done = done }
            end
            DrawBar(parts)
        end
        f.arrival:SetText(Arrival(st.remaining))
        -- (la flèche GPS : pas en vol, le trajet se fait tout seul)
        f.arrow:SetShown(ns.db.options.travelArrow ~= false and not flying)
        y = y - 10 - (f.time:GetStringHeight() or 24) - 10 - BAR_H
        -- (l'alerte d'atterrissage)
        if flying and st.flight.left <= 10 then
            f.alert:SetText(L.HUD_LANDING:format(math.ceil(st.flight.left)))
            f.alert:Show()
            y = y - 8 - 14
        else
            f.alert:Hide()
        end
        -- (le bas)
        local foot
        if st.corpse then
            local stash = T().Stashed()
            if stash then foot = L.HUD_RESUME:format(T().GoalName(stash)) end
        elseif flying and legs[st.index + 1] then
            foot = L.HUD_THEN:format(T().LegText(legs[st.index + 1]))
        elseif st.queued > 0 then
            foot = st.queued == 1 and L.HUD_QUEUE_ONE or L.HUD_QUEUE:format(st.queued)
        end
        if foot then
            f.rule:ClearAllPoints()
            f.rule:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y - 10)
            f.rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y - 10)
            f.rule:Show()
            f.foot:ClearAllPoints()
            f.foot:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y - 18)
            f.foot:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
            f.foot:SetText(foot)
            f.foot:Show()
            y = y - 18 - (f.foot:GetStringHeight() or 12)
        else
            f.rule:Hide()
            f.foot:Hide()
        end
    else
        -- (un ralliement sans trajet en cours : arrivé, on attend les autres)
        f.title:SetText(L.HUD_RALLY)
        f.dest:SetText("")
        f.well:Hide()
        f.time:Hide()
        f.timeSub:SetText("")
        f.arrival:SetText("")
        f.bar:Hide()
        f.alert:Hide()
        f.rule:Hide()
        f.foot:Hide()
        f.arrow:Hide()
        y = -34
    end

    -- (le ralliement : le temps de chacun)
    local rally = ns.TravelShare and ns.TravelShare.Rally()
    local n = 0
    if rally then
        f.rallyHead:ClearAllPoints()
        f.rallyHead:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y - 12)
        f.rallyHead:SetText(L.HUD_RALLY_AT:format(rally.name or ""))
        f.rallyHead:Show()
        y = y - 12 - 16
        for _, who in ipairs(rally.members) do
            n = n + 1
            local m = Member(n)
            m:ClearAllPoints()
            m:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y - 4)
            m:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
            m.name:SetText(who.colored or who.name)
            local trackW = WIDTH - 2 * PAD - 78 - 80 - 12
            if who.arrived then
                m.eta:SetText("|cff40ff40" .. L.HUD_RALLY_HERE .. "|r")
                m.fill:SetColorTexture(UI.RGBA("good", 1))
                m.fill:SetWidth(trackW)
                m.fill:Show()
            elseif who.secs then
                m.eta:SetText(H.Duration(who.secs))
                local r, g, b = who.r or 1, who.g or 0.82, who.b or 0
                m.fill:SetColorTexture(r, g, b, 0.9)
                m.fill:SetWidth(math.max(1, trackW * math.max(0, math.min(1, who.done or 0))))
                m.fill:SetShown((who.done or 0) > 0)
            else
                m.eta:SetText(UI.Hex("textFaint") .. L.HUD_RALLY_NOADDON .. "|r")
                m.fill:Hide()
            end
            m:Show()
            y = y - 4 - 16
        end
    else
        f.rallyHead:Hide()
    end
    for i = n + 1, #members do members[i]:Hide() end

    -- (replié : l'en-tête seul, le temps qu'il reste à la place de la destination)
    local folded = ns.db.options.hudFolded and true or false
    if folded then
        f.well:Hide()
        f.time:Hide()
        f.timeSub:SetText("")
        f.arrival:SetText("")
        f.bar:Hide()
        f.alert:Hide()
        f.rule:Hide()
        f.foot:Hide()
        f.rallyHead:Hide()
        for i = 1, #members do members[i]:Hide() end
        local left = st and (st.flight and st.flight.left or st.remaining)
        f.dest:SetText(left and H.Duration(left) or "")
        y = -(PAD + 22)
    end
    -- (la flèche : vers le bas pour déplier, vers le haut pour replier)
    if folded then f.fold.arrow:SetTexCoord(0, 0.5625, 0, 1) else f.fold.arrow:SetTexCoord(0, 0.5625, 1, 0) end

    f:SetHeight(-y + PAD)
    f:Show()
end

-- Replier ou déplier le panneau (la flèche, l'onglet Trajets, /mmir panneau replier)
function H.ToggleFold()
    if not ns.db then return end
    ns.db.options.hudFolded = not ns.db.options.hudFolded
    if frame and frame:IsShown() then H.Refresh() end
    return ns.db.options.hudFolded
end

local ticker = CreateFrame("Frame")
local wait = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = 0.5
    if Wanted() or (frame and frame:IsShown()) then H.Refresh() end
end)

ns.On("TRAVEL", H.Refresh)
ns.On("OPTIONS", H.Refresh)
ns.On("MAP_SHOW", function() Place() H.Refresh() end)
ns.On("MAP_HIDE", function() Place() H.Refresh() end)
ns.On("MAP_SIZE", function() Place() H.Refresh() end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if frame then frame:Hide() end
    else
        H.Refresh()
    end
end)
