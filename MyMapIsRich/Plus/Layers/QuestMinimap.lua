-- Les marqueurs de quêtes sur la minimap : les mêmes que sur la carte
-- (Layers/QuestMarks.lua : les objectifs, les « ? », les « ! », en camps,
-- les quêtes suivies seulement, la quête choisie), ceux qui sont dans sa vue.
-- Le survol d'une icône donne la même info-bulle que sur la carte ; un clic
-- passe à la minimap (son ping), quand le client le permet.
-- Le placement est celui du trajet sur la minimap (Travel/Minimap.lua :
-- TravelMinimap.Viewer). Rien n'est écrit dans la minimap du jeu : nos icônes
-- sont sur un cadre à nous, posé par-dessus.
-- Le réglage « questMinimap » (les détails du calque Quêtes) l'allume.
-- Les points sont relus quand les marqueurs changent (« QUEST_MARKS ») ou
-- quand tu changes de continent, en yards de ton continent.
local _, root = ...
local ns = root.Plus

local Settings = ns.Map.Settings
local K = ns.Map.Coords

local QMM = {}
ns.QuestMinimap = QMM

Settings.Own("questMinimap", true)

local EVERY = 0.1               -- s entre deux mises à jour
local MAX_ICONS = 40
local SIZE = 0.8                -- la taille d'une icône, en part de celle de la carte

local frame
local icons = {}
local points                    -- { { x, y, look, e, inside, camp }, ... } sur le continent cont
local pointsCont
local stale = true              -- les marqueurs ont changé depuis : à relire
local reading, readGen = nil, 0 -- la relecture en cours (ns.Job : quelques ms par image)

local function QM() return ns.Quests and ns.Quests.Marks end

local function On()
    return Settings.Get("questMinimap") ~= false and QM() ~= nil and ns.Quests.Db.Has()
        and not (ns.Conflict and ns.Conflict())
end

-- Un point du monde (u, v) vers les yards du continent : la projection est
-- linéaire (Map/Coords.lua : FromYards), inversée une fois par continent
local function Projector(cont)
    local x0, y0 = K.FromYards(cont, 0, 0)
    local x1, y1 = K.FromYards(cont, 1000, 0)
    local x2, y2 = K.FromYards(cont, 0, 1000)
    if not (x0 and x1 and x2) then return end
    local ax, ay, bx, by = (x1 - x0) / 1000, (y1 - y0) / 1000, (x2 - x0) / 1000, (y2 - y0) / 1000
    local det = ax * by - bx * ay
    if det == 0 then return end
    return function(u, v)
        local du, dv = u - x0, v - y0
        return (du * by - bx * dv) / det, (ax * dv - du * ay) / det
    end
end

-- (dans un long travail, ns.Job : les camps de chaque marqueur, par tranches)
local function Read(qm, all, cont)
    local out = {}
    local To = Projector(cont)
    if not To then return out end
    for _, what in ipairs({ "goal", "end", "offer" }) do
        if qm.Want(what) then
            for _, e in ipairs(all[what] or {}) do
                local spots, look = qm.Spots(e)
                for _, p in ipairs(spots) do
                    local x, y = To(p[1], p[2])
                    if x then
                        out[#out + 1] = { x, y, look, e, inside = p.inside, camp = p.camp }
                    end
                end
                ns.Slice()
            end
        end
    end
    return out
end

-- Les points relus sans figer le jeu : les marqueurs d'abord (QM.EntriesSoon),
-- puis leurs points ; ceux d'avant restent montrés d'ici là (sur le même continent)
local function StartRead(cont)
    if reading then
        if reading.cont == cont then return end
        reading.Cancel()            -- (un autre continent : celui d'avant ne sert plus)
        reading = nil
    end
    local qm = QM()
    local all = qm and qm.EntriesSoon()
    if not all then return end     -- (« QUEST_MARKS » une fois les marqueurs prêts : relus alors)
    stale = false
    local mine = readGen
    reading = ns.Job(function() return Read(qm, all, cont) end, function(out)
        reading = nil
        if mine ~= readGen then return end
        points, pointsCont = out, cont
    end)
    reading.cont = cont
end

local function Build()
    local mm = _G.Minimap
    if frame or not mm then return frame end
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetAllPoints(mm)
    frame:EnableMouse(false)
    frame:Hide()
    return frame
end

local function Icon(i)
    local b = icons[i]
    if b then return b end
    b = CreateFrame("Button", nil, frame)
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetAllPoints()
    b.noClick = true
    -- (le survol pour l'info-bulle, les clics à la minimap dessous)
    if b.SetMouseClickEnabled then
        b:SetMouseClickEnabled(false)
        b:SetMouseMotionEnabled(true)
    end
    b:SetScript("OnEnter", function(self) if QM() then QM().Enter(self) end end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    icons[i] = b
    return b
end

local function HideFrom(n)
    for i = n, #icons do icons[i]:Hide() end
end

local function Update()
    local mm = _G.Minimap
    if not (On() and mm and Build()) then
        if frame then frame:Hide() end
        return
    end
    local viewer = ns.TravelMinimap and ns.TravelMinimap.Viewer(frame)
    if not viewer then
        frame:Hide()
        return
    end
    local cont = viewer.here.cont
    if stale or not points or pointsCont ~= cont then StartRead(cont) end
    if not points or pointsCont ~= cont then
        frame:Hide()
        return
    end
    frame:SetFrameStrata(mm:GetFrameStrata())
    frame:SetFrameLevel(mm:GetFrameLevel() + 6)
    frame:Show()
    local reach = viewer.radius * 1.5
    local px, py = viewer.here.x, viewer.here.y
    -- (ceux dans la vue, les plus proches d'abord : MAX_ICONS au plus)
    local inView = {}
    for _, p in ipairs(points) do
        local dx, dy = p[1] - px, p[2] - py
        if math.abs(dx) < reach and math.abs(dy) < reach then
            local sx, sy = viewer.View(p[1], p[2])
            if viewer.Inside(sx, sy) then inView[#inView + 1] = { p, sx, sy, dx * dx + dy * dy } end
        end
    end
    table.sort(inView, function(a, b) return a[4] < b[4] end)
    local n = 0
    for _, it in ipairs(inView) do
        if n >= MAX_ICONS then break end
        local p, sx, sy = it[1], it[2], it[3]
        n = n + 1
        local b = Icon(n)
        local size = (p[3].size or 16) * SIZE
        b:SetSize(size, size)
        ns.Map.Pins.Look(b.Icon, p[3])
        b.Icon:SetDesaturated((p[4].trivial or p[4].soon) and true or false)
        b.Icon:SetAlpha(QM().Alpha(p[4]))
        b.data, b.inside, b.camp = p[4], p.inside, p.camp
        b:ClearAllPoints()
        b:SetPoint("CENTER", frame, "CENTER", sx * viewer.scale, sy * viewer.scale)
        b:Show()
    end
    HideFrom(n + 1)
end

local driver = CreateFrame("Frame")
local wait = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = EVERY
    local ok, err = pcall(Update)
    if not ok then
        driver:Hide()
        if frame then frame:Hide() end
        if geterrorhandler then geterrorhandler()(err) end
    end
end)

-- (les marqueurs ont changé : relus à la prochaine mise à jour ; seulement
-- l'alpha, la quête choisie : rien à relire)
-- (ceux d'avant restent montrés jusqu'à la relecture : StartRead)
ns.On("QUEST_MARKS", function(alphaOnly)
    if alphaOnly then return end
    stale, readGen = true, readGen + 1
    if reading then
        reading.Cancel()
        reading = nil
    end
end)
