-- Le suivi des quêtes : à droite de l'écran, à la place de celui du jeu, un
-- panneau à la charte qui dit, pour chaque quête du journal, ce qu'il reste à
-- faire et où aller.
--   l'en-tête    « Quêtes 38/40 », le tri (Distance ou Zone), la flèche qui
--                le replie ; on le glisse par là (sauf « Verrouiller »)
--   les filtres  Toutes · Suivies (la liste de suivi du jeu) · Zone (celle où
--                tu es) · Proches (moins de 800 yd) ; dans un donjon, Donjon
--                s'ajoute et se choisit tout seul
--   À rendre     en tête : les quêtes finies, à qui les rendre et où
--   la liste     par distance, la plus proche d'abord (Quests/Where.lua : le
--                plus proche de ce qu'il reste à faire) ; ou par zone, celle
--                où tu es d'abord, chaque zone repliable
--   une quête    [niveau] dans la couleur de sa difficulté, son titre, Élite
--                (en rose vif), Donjon..., la distance (un autre continent : sa zone) ; ses
--                objectifs (un objectif qui avance s'allume d'or), le temps
--                qu'il reste à une quête minutée, et l'avancée de ceux du
--                groupe qui l'ont aussi (Quests/Party.lua). La barre d'or :
--                la quête de l'itinéraire en cours ; le fond doré : celle que
--                le jeu suit en priorité
--   en bas       « 3 quêtes masquées » : un clic les montre (pâles)
-- À la souris : un clic, l'itinéraire jusqu'au plus proche (encore : annulé) ;
-- Maj+clic, le lien dans la discussion ; un clic droit, le menu de la quête.
-- La liste ne se réordonne pas sous la souris, et un écart de moins de 30 yd
-- ne change pas l'ordre.
-- En jeu et avec la carte réduite ; caché sous la carte plein écran (sa liste
-- des quêtes, UI/QuestPanel.lua, fait le même travail, et à la manette).
-- Hors de la carte, il ne prend aucun bouton de la manette. Il ne crée aucun
-- cadre protégé : il reste là en combat (réglage « Masquer en combat »).
-- Les objets de quête en face des quêtes sont des boutons protégés posés à
-- côté de lui, sans ancre vers lui (UI/TrackerItems.lua) : il leur dit où sont
-- les quêtes (TR.Shown, le message TRACKER_LAYOUT) et, en combat, tant qu'il y
-- en a, il garde l'ordre de sa liste (ils ne peuvent pas la suivre).
--
-- LE SUIVI DU JEU (une exception à « rien n'est écrit dans les cadres de
-- Blizzard », voulue, comme celle de Map/View.lua) : tant que le nôtre est
-- actif, ObjectiveTrackerFrame est mis à l'alpha 0 (un SetAlpha du jeu est
-- repris par hooksecurefunc), et rien d'autre. Le réglage coupé, il est rendu
-- (alpha 1). Jamais de Hide() ni de Show() depuis l'addon : ses scripts
-- OnHide / OnShow tournaient alors au nom de l'addon, l'interface manette du
-- jeu en prenait son état, et le jeu bloquait ensuite
-- SetPreferredGamepadInteractTarget jusqu'au /reload (1.3.0 : après chaque
-- combat, à chaque quête acceptée). Le revers : invisible, le suivi du jeu
-- garde ses boutons cliquables à la souris, à son emplacement. L'alpha
-- n'appelle aucun script et n'est pas protégé : il se change en combat. Rien
-- n'est touché en veille (ns.Conflict), ni quand un autre suivi est là.
-- Les autres suivis (TR.Rival) : celui d'EllesmereUI (EllesmereUIQuestTracker
-- chargé) ou celui de Questie (son réglage « Activer le suivi ») : le nôtre
-- s'efface, ne cache rien, et l'onglet Quêtes de /mmir le dit.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local TR = {}
ns.Tracker = TR

local Log = ns.Quests.Log
local Db = ns.Quests.Db
local Where = ns.Quests.Where
local Party = ns.Quests.Party

local WIDTH = 300
local PAD = 8                -- px : la marge gauche de la liste
local BAR_W = 14             -- px : à droite, la place de la barre de défilement
local HEAD_H = 28
local FILTER_H = 20
local GAP = UI.PAGE_GAP
local LINE_GAP = 2
local BLOCK_GAP = 3
local INDENT = 14            -- px : les objectifs, sous le titre
local NEAR = 800             -- yd : « Proches »
local STEP = 30              -- yd : un écart plus petit ne change pas l'ordre
local FLASH = 1.5            -- s : un objectif qui avance, en or
local TICK = 1               -- s : les distances relues
local MAX_SHARE = 0.6        -- la hauteur au plus, en part de l'écran
local DEFAULT_POS = { "TOPRIGHT", -70, -230 }
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t "   -- (la coche : la police du jeu n'a pas « ✓ »)
local FILTERS = { "all", "watched", "zone", "near" }
local FILTER_KEYS = {
    all = "TRACKER_FILTER_ALL", watched = "TRACKER_FILTER_WATCHED", zone = "TRACKER_FILTER_ZONE",
    near = "TRACKER_FILTER_NEAR", dungeon = "TRACKER_FILTER_DUNGEON",
}

local frame, scroll, child, emptyText
local heads, blocks, filterButtons = {}, {}, {}
local shownQuests = {}       -- les quêtes affichées : { q, block }
local rank = {}              -- questID -> sa place dans la dernière liste (l'ordre gardé)
local lastObj, flashUntil = {}, {}
local timerEnd = {}          -- questID -> GetTime() de sa fin
local showHidden = false
local instance               -- le mapID du donjon où tu es, ou nil
local dungeonPick = false    -- le filtre Donjon choisi (tout seul en entrant)
local pending = false        -- une liste à remettre dans l'ordre quand la souris part

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

local function QP() return ns.QuestPanel end
local function Opt() return ns.db and ns.db.options or {} end

local function Hidden()
    if not ns.char then return {} end
    ns.char.trackerHidden = ns.char.trackerHidden or {}
    return ns.char.trackerHidden
end

local function FoldedZones()
    if not ns.char then return {} end
    ns.char.trackerZones = ns.char.trackerZones or {}
    return ns.char.trackerZones
end

---------------------------------------------------------------------------
-- Les autres suivis, et celui du jeu
---------------------------------------------------------------------------
local function Loaded(name)
    local fn = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
    if not fn then return false end
    local ok, on = pcall(fn, name)
    return ok and on and true or false
end

-- Un autre suivi des quêtes à l'écran : "ellesmere", "questie", ou nil
function TR.Rival()
    if Loaded("EllesmereUIQuestTracker") then return "ellesmere" end
    if Loaded("Questie") then
        local ok, on = pcall(function() return _G.Questie.db.profile.trackerEnabled end)
        if ok and on then return "questie" end
    end
end

local muted, hooked = false, false

local function GameTracker() return _G.ObjectiveTrackerFrame end

local function HideGame()
    local otf = GameTracker()
    if not otf then return end
    if not hooked then
        hooked = true
        -- (le jeu remet son alpha, son cadre réaffiché : repris tant qu'on le cache)
        hooksecurefunc(otf, "SetAlpha", function(self, a)
            if muted and a ~= 0 then self:SetAlpha(0) end
        end)
        otf:HookScript("OnShow", function(self)
            if muted then self:SetAlpha(0) end
        end)
    end
    -- (déjà invisible : rien à refaire à chaque relecture du suivi)
    if muted and otf:GetAlpha() == 0 then return end
    muted = true
    otf:SetAlpha(0)
end

local function ShowGame()
    if not muted then return end
    muted = false
    local otf = GameTracker()
    if not otf then return end
    otf:SetAlpha(1)
end

-- Le nôtre actif (le réglage, ni veille ni autre suivi) : celui du jeu caché
local function Active()
    return ns.db ~= nil and Opt().tracker ~= false and not ns.Conflict() and TR.Rival() == nil
end
TR.Active = Active

local function Mute()
    if ns.Conflict() then return end
    if Active() then HideGame() else ShowGame() end
end

---------------------------------------------------------------------------
-- Les quêtes
---------------------------------------------------------------------------
local function LevelColor(level)
    if type(level) == "number" and GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(level)
        if type(c) == "table" and c.r then return c.r, c.g, c.b end
    end
    return 1, 0.82, 0
end

-- « [42+] » : comme le suivi de Forever l'écrit (QuestUtilsOverrides), sinon le niveau
local function Prefix(q)
    local QUO = _G.QuestUtilsOverrides
    local text
    if QUO and QUO.GetQuestTitlePrefix then
        local diff = C_QuestLog and C_QuestLog.GetQuestDifficultyLevel and Plain(Call(C_QuestLog.GetQuestDifficultyLevel, q.id))
        text = Plain(Call(QUO.GetQuestTitlePrefix, { questID = q.id, difficultyLevel = diff or q.level }))
    end
    if type(text) ~= "string" or text == "" then
        if not (type(q.level) == "number" and q.level > 0) then return "" end
        text = "[" .. q.level .. "]"
    end
    text = strtrim(text)
    local r, g, b = LevelColor(q.level)
    return ("|cff%02x%02x%02x%s|r "):format(r * 255, g * 255, b * 255, text)
end

-- « (Donjon) », « (JcJ) » : le texte du jeu (une quête élite a le sien : Db.EliteTag)
local function Tag(q)
    local QUO = _G.QuestUtilsOverrides
    if QUO and QUO.GetQuestTagText then
        local t = Plain(Call(QUO.GetQuestTagText, q.id))
        if type(t) == "string" and t ~= "" then return t end
    end
    if C_QuestLog and C_QuestLog.GetQuestTagInfo then
        local info = Call(C_QuestLog.GetQuestTagInfo, q.id)
        local name = type(info) == "table" and Plain(info.tagName)
        if type(name) == "string" and name ~= "" then return "(" .. name .. ")" end
    end
end

local function ReadTimers()
    wipe(timerEnd)
    if not (C_QuestLog and C_QuestLog.GetQuestTimers) then return end
    local list = Call(C_QuestLog.GetQuestTimers)
    if type(list) ~= "table" then return end
    local now = GetTime()
    for _, t in ipairs(list) do
        if type(t) == "table" then
            local id, secs = Plain(t.questID), Plain(t.questTimer)
            if type(id) == "number" and type(secs) == "number" then timerEnd[id] = now + secs end
        end
    end
end

-- Le donjon où tu es : le mapID de son instance et son nom, sinon nil
local function Instance()
    if not (IsInInstance and GetInstanceInfo) then return end
    local inside, kind = IsInInstance()
    if not inside or (kind ~= "party" and kind ~= "raid") then return end
    local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    return Plain(instanceID), Plain(name)
end

local function Filter()
    if instance and dungeonPick then return "dungeon" end
    local f = Opt().trackerFilter
    if f == "watched" or f == "zone" or f == "near" then return f end
    return "all"
end

-- Les quêtes du journal, avec la zone de leur rubrique et leur distance
local function Collect(here)
    local list = {}
    local log = Log.Quests()
    local zone
    for i = 1, Log.NumEntries() do
        local info = Log.InfoAt(i)
        if info and info.title then
            if info.isHeader then
                zone = info.title
            elseif info.questID and log[info.questID] then
                local lq = log[info.questID]
                local q = { id = info.questID, index = i, title = lq.title or info.title, level = lq.level,
                    complete = lq.complete, zone = zone or "" }
                q.where = Where.Of(q.id, here or false)
                q.dist = q.where and q.where.dist or nil
                list[#list + 1] = q
            end
        end
    end
    return list
end

local function Keep(q, filter, zoneA, zoneB, dungeonSet, dungeonName)
    if filter == "watched" then return QP() and QP().IsWatched(q.id) or false end
    if filter == "zone" then
        if q.zone ~= "" and (q.zone == zoneA or q.zone == zoneB) then return true end
        local z = q.where and Where.Zone(q.where)
        return z ~= nil and (z == zoneA or z == zoneB)
    end
    if filter == "near" then return q.dist ~= nil and q.dist <= NEAR end
    if filter == "dungeon" then
        return (dungeonSet and dungeonSet[q.id]) or (dungeonName ~= nil and q.zone == dungeonName) or false
    end
    return true
end

-- L'ordre : par distance, en pas de 30 yd (dans un même pas, l'ordre d'avant),
-- puis l'ordre du journal ; la souris sur le panneau, l'ordre d'avant
local function Sorter(byDist, frozen)
    local function Rank(q) return rank[q.id] or (10000 + q.index) end
    return function(a, b)
        if frozen then
            local ra, rb = Rank(a), Rank(b)
            if ra ~= rb then return ra < rb end
            return a.index < b.index
        end
        if byDist then
            local da = a.dist and math.floor(a.dist / STEP) or math.huge
            local db = b.dist and math.floor(b.dist / STEP) or math.huge
            if da ~= db then return da < db end
            local ra, rb = Rank(a), Rank(b)
            if ra ~= rb then return ra < rb end
        end
        return a.index < b.index
    end
end

-- Ce que la liste montre : { head = texte, count, zone } ou { quest = q } ;
-- et le nombre de quêtes masquées
local function Rows(list, frozen)
    local filter = Filter()
    local zoneA = GetRealZoneText and GetRealZoneText() or ""
    local zoneB = GetZoneText and GetZoneText() or ""
    local dungeonSet, dungeonName
    if filter == "dungeon" then
        local id, name = Instance()
        dungeonName = name
        dungeonSet = {}
        for _, qid in ipairs(Db.DungeonQuests(id)) do dungeonSet[qid] = true end
    end
    local hidden = Hidden()
    local turnin, active, nHidden = {}, {}, 0
    for _, q in ipairs(list) do
        if hidden[q.id] then nHidden = nHidden + 1 end
        if (not hidden[q.id] or showHidden) and Keep(q, filter, zoneA, zoneB, dungeonSet, dungeonName) then
            q.hidden = hidden[q.id] and true or false
            table.insert(q.complete and turnin or active, q)
        end
    end
    local byDist = Opt().trackerSort ~= "zone"
    table.sort(turnin, Sorter(true, frozen))
    local rows = {}
    if #turnin > 0 then
        rows[#rows + 1] = { head = L.TRACKER_TURNIN_HEAD, count = #turnin }
        for _, q in ipairs(turnin) do rows[#rows + 1] = { quest = q } end
    end
    if byDist then
        table.sort(active, Sorter(true, frozen))
        if #turnin > 0 and #active > 0 then rows[#rows + 1] = { head = L.TRACKER_ACTIVE_HEAD, count = #active } end
        for _, q in ipairs(active) do rows[#rows + 1] = { quest = q } end
    else
        -- (par zone : celle où tu es d'abord, puis la plus proche)
        local zones, byZone = {}, {}
        for _, q in ipairs(active) do
            local z = q.zone
            if not byZone[z] then
                byZone[z] = { name = z, quests = {}, first = q.index }
                zones[#zones + 1] = byZone[z]
            end
            local g = byZone[z]
            table.insert(g.quests, q)
            if q.dist and (not g.dist or q.dist < g.dist) then g.dist = q.dist end
        end
        table.sort(zones, function(a, b)
            local ha, hb = a.name == zoneA or a.name == zoneB, b.name == zoneA or b.name == zoneB
            if ha ~= hb then return ha end
            if not frozen and (a.dist or b.dist) and a.dist ~= b.dist then
                if not a.dist then return false end
                if not b.dist then return true end
                return a.dist < b.dist
            end
            return a.first < b.first
        end)
        local folded = FoldedZones()
        for _, g in ipairs(zones) do
            local name = g.name ~= "" and g.name or L.TRACKER_OTHER
            rows[#rows + 1] = { head = name, count = #g.quests, zone = g.name, folded = folded[g.name] and true or false }
            if not folded[g.name] then
                table.sort(g.quests, Sorter(false, frozen))
                for _, q in ipairs(g.quests) do rows[#rows + 1] = { quest = q } end
            end
        end
    end
    return rows, nHidden, filter, #turnin + #active
end

---------------------------------------------------------------------------
-- Les lignes d'une quête
---------------------------------------------------------------------------
local function Yards(d) return ns.RouteHud.Yards(d) end
local function Duration(s) return ns.RouteHud.Duration(s) end

-- La distance, à droite du titre (un autre continent : la zone)
local function DistText(q)
    local w = q.where
    if not w then return "" end
    if q.dist then return Yards(q.dist) end
    if w.far then return Where.Zone(w) or "" end
    return ""
end

-- Les lignes sous le titre : { texte, police }
local function Lines(q, now)
    local out = {}
    if q.complete then
        local w = q.where
        local name = w and w.kind == "turnin" and w.name
        local zone = w and Where.Zone(w)
        local text
        if name and zone then
            text = L.TRACKER_TURNIN_AT:format(name, zone)
        elseif name then
            text = L.TRACKER_TURNIN:format(name)
        else
            text = L.TRACKER_TURNIN_ANY
        end
        out[#out + 1] = CHECK .. UI.Hex("good") .. text .. "|r"
    else
        for j, o in ipairs(Log.Objectives(q.id, q.index)) do
            local key = q.id .. ":" .. j
            local have = tonumber(o.have) or (o.finished and 1 or 0)
            if lastObj[key] and have > lastObj[key] then
                flashUntil[key] = now + FLASH
                -- (l'or éteint, le délai passé)
                C_Timer.After(FLASH + 0.1, function() TR.Dirty() end)
            end
            lastObj[key] = have
            if o.finished then
                out[#out + 1] = CHECK .. UI.Hex("textDim") .. o.text .. "|r"
            elseif (flashUntil[key] or 0) > now then
                out[#out + 1] = "|cffffd100- " .. o.text .. "|r"
            else
                out[#out + 1] = "- " .. o.text
            end
        end
    end
    local ends = timerEnd[q.id]
    if ends then out[#out + 1] = { timer = true, text = "|cffffd100" .. L.TRACKER_TIME_LEFT:format(Duration(ends - now)) .. "|r" } end
    if Opt().trackerParty ~= false and Party then
        for _, m in ipairs(Party.Of(q.id)) do
            local what
            if m.done then
                what = UI.Hex("good") .. L.TRACKER_PARTY_DONE .. "|r"
            else
                local parts = {}
                for _, p in ipairs(m.parts) do parts[#parts + 1] = p[1] .. "/" .. p[2] end
                what = table.concat(parts, " · ")
            end
            out[#out + 1] = { party = true, text = L.TRACKER_PARTY_LINE:format(m.colored, what) }
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Le cadre
---------------------------------------------------------------------------
local function ContentWidth() return WIDTH - PAD - BAR_W end

local function MapCovers() return ns.MapShown() and not ns.MapSmall() end

local function SavePos()
    if not (frame and ns.db) then return end
    local right, top = frame:GetRight(), frame:GetTop()
    if not (right and top) then return end
    Opt().trackerPos = { "TOPRIGHT", math.floor(right - UIParent:GetRight() + 0.5), math.floor(top - UIParent:GetTop() + 0.5) }
    frame:ClearAllPoints()
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", Opt().trackerPos[2], Opt().trackerPos[3])
    ns.Fire("TRACKER_LAYOUT")
end

local function Place()
    if not frame then return end
    frame:ClearAllPoints()
    local pos = Opt().trackerPos
    if type(pos) ~= "table" then pos = DEFAULT_POS end
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", pos[2] or DEFAULT_POS[2], pos[3] or DEFAULT_POS[3])
    ns.Fire("TRACKER_LAYOUT")
end

function TR.ResetPosition()
    if ns.db then Opt().trackerPos = nil end
    Place()
end

local function PaintBackground()
    if not frame then return end
    local a = math.max(0, math.min(1, tonumber(Opt().trackerAlpha) or 0.7))
    UI.Fade(frame.bg, "VERTICAL", "panelBottom", a, "panelTop", a)
    frame.edge:SetColor("panelEdge", math.max(0.35, a))
    frame.inner:SetColor(0, 0, 0, 0.7 * a)
end
TR.Repaint = PaintBackground

local Dirty                  -- (plus bas)

local function OnRight()
    local x = frame and frame:GetCenter()
    return x and x > UIParent:GetWidth() / 2
end
TR.OnRight = OnRight

-- Le menu d'une quête (un clic droit)
local function Menu(b, q)
    local id = q.id
    local qp = QP()
    local items = {}
    -- (sa fiche dans la liste des quêtes de la carte : le texte, les
    -- objectifs, les récompenses ; la carte s'ouvre, hors combat)
    if qp then
        items[#items + 1] = { L.TRACKER_SHOW_LOG, function() qp.OpenID(id) end }
    end
    if Opt().travel then
        items[#items + 1] = { Where.Routed(id) and L.HINT_TRAVEL_CANCEL or L.FICHE_ROUTE, function() Where.Route(id) end, sep = true }
        items[#items + 1] = { L.ACT_QUEUE, function() Where.Enqueue(id) end }
    end
    if qp then
        items[#items + 1] = { qp.IsWatched(id) and L.QUESTS_UNTRACK or L.QUESTS_TRACK, function()
            qp.ToggleWatch(id)
            Dirty()
        end, sep = true }
    end
    items[#items + 1] = { TR.IsHidden(id) and L.TRACKER_UNHIDE or L.TRACKER_HIDE, function() TR.ToggleHidden(id) end, sep = qp == nil }
    if qp then
        items[#items + 1] = { L.QUESTS_SHARE, function() qp.Share(id) end }
        if qp.HasLink(id) then items[#items + 1] = { L.QUESTS_LINK, function() qp.Link(id) end } end
    end
    local x, y = GetCursorPosition()
    local m = UI.ShowMenu(items, x, y, q.title)
    if not m then return end
    m:ClearAllPoints()
    if OnRight() then m:SetPoint("TOPRIGHT", b, "TOPLEFT", -6, 0) else m:SetPoint("TOPLEFT", b, "TOPRIGHT", 6, 0) end
end

local function QuestTip(self)
    local q = self.q
    if not q then return end
    GameTooltip:SetOwner(self, OnRight() and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    GameTooltip:SetText(q.title or "", 1, 0.82, 0, 1, true)
    if Db.IsElite(q.id) then GameTooltip:AddLine(L.QUESTS_ELITE_TIP, 1, 0.35, 0.78, true) end
    local w = q.where
    if w and w.name and w.kind == "goal" then GameTooltip:AddLine(L.TRACKER_NEAREST:format(w.name), 1, 1, 1, true) end
    local zone = w and Where.Zone(w)
    if zone then GameTooltip:AddLine(zone, UI.RGB("textDim")) end
    GameTooltip:AddLine(" ")
    if Opt().travel then GameTooltip:AddLine(L.TRACKER_TIP_CLICK, 0.75, 0.75, 0.75, true) end
    GameTooltip:AddLine(L.TRACKER_TIP_SHIFT, 0.75, 0.75, 0.75, true)
    GameTooltip:AddLine(L.TRACKER_TIP_RIGHT, 0.75, 0.75, 0.75, true)
    GameTooltip:Show()
end

local function QuestBlock(i)
    local b = blocks[i]
    if b then return b end
    b = CreateFrame("Button", nil, child)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    UI.RowBackground(b)
    b.mark = UI.MarkBar(b)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.07)
    b.title = UI.Text(b, "GameFontNormal")
    b.title:SetJustifyH("LEFT")
    b.title:SetPoint("TOPLEFT", 8, -3)
    b.dist = UI.DimText(b, "")
    b.dist:SetJustifyH("RIGHT")
    b.dist:SetWordWrap(false)
    b.dist:SetPoint("TOPRIGHT", -4, -4)
    b.lines = {}
    b:SetScript("OnClick", function(self, button)
        local q = self.q
        if not q then return end
        if button == "RightButton" then
            Menu(self, q)
        elseif IsShiftKeyDown() then
            if QP() then QP().Link(q.id) end
        elseif Opt().travel then
            Where.Route(q.id)
        end
    end)
    b:SetScript("OnEnter", QuestTip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    blocks[i] = b
    return b
end

local function Line(b, k)
    local fs = b.lines[k]
    if fs then return fs end
    fs = UI.Text(b, "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    b.lines[k] = fs
    return fs
end

-- Une quête dans son bloc ; rend sa hauteur
local function FillQuest(b, q, now, stripe)
    local cw = ContentWidth()
    b.q = q
    b:SetWidth(cw)
    b.stripe:SetShown(stripe)
    b.selected:SetShown(q.superTracked)
    b.mark:SetShown(Where.Routed(q.id))
    b:SetAlpha(q.hidden and 0.5 or 1)
    b.dist:SetText(DistText(q))
    local dw = math.min(120, math.max(0, math.ceil(b.dist:GetStringWidth())))
    b.dist:SetWidth(dw + 2)
    -- (élite : le mot en rose vif, à la place de « (Élite) » en gris du jeu)
    local elite = Db.EliteTag(q.id)
    local tag = not elite and Tag(q)
    tag = elite or (tag and (UI.Hex("textDim") .. tag .. "|r"))
    b.title:SetWidth(cw - 12 - dw - (dw > 0 and 8 or 0))
    b.title:SetText(Prefix(q) .. (q.title or "") .. (tag and (" " .. tag) or ""))
    local h = 3 + math.max(12, b.title:GetStringHeight() or 12)
    local k = 0
    b.timer = nil
    for _, line in ipairs(Lines(q, now)) do
        k = k + 1
        local fs = Line(b, k)
        local text, indent = line, INDENT
        if type(line) == "table" then
            text = line.text
            if line.party then indent = INDENT + 10 end
            if line.timer then b.timer = fs end
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", indent, -(h + LINE_GAP))
        fs:SetWidth(cw - indent - 6)
        fs:SetText(text)
        fs:Show()
        h = h + LINE_GAP + (fs:GetStringHeight() or 12)
    end
    for j = k + 1, #b.lines do b.lines[j]:Hide() end
    h = h + 4
    b:SetHeight(h)
    return h
end

local function HeadBlock(i)
    local h = heads[i]
    if h then return h end
    h = CreateFrame("Button", nil, child)
    h:SetHeight(18)
    h.text = UI.Text(h, "GameFontNormalSmall")
    h.text:SetPoint("LEFT", 6, 0)
    h.text:SetJustifyH("LEFT")
    h.text:SetWordWrap(false)
    h.count = UI.Text(h, "GameFontDisableSmall")
    h.count:SetPoint("RIGHT", -6, 0)
    h.arrow = h:CreateTexture(nil, "ARTWORK")
    h.arrow:SetSize(9, 8)
    h.arrow:SetPoint("RIGHT", h.count, "LEFT", -4, 0)
    h.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    h.line = h:CreateTexture(nil, "ARTWORK")
    h.line:SetHeight(1)
    h.line:SetPoint("BOTTOMLEFT", 6, 0)
    h.line:SetPoint("BOTTOMRIGHT", -6, 0)
    h.line:SetColorTexture(1, 0.82, 0, 0.22)
    h.hl = h:CreateTexture(nil, "HIGHLIGHT")
    h.hl:SetAllPoints()
    h.hl:SetColorTexture(1, 0.82, 0, 0.07)
    h:SetScript("OnClick", function(self)
        if self.zone == nil then return end
        local folded = FoldedZones()
        folded[self.zone] = not folded[self.zone] or nil
        Dirty()
    end)
    h:SetScript("OnEnter", function(self)
        if self.zone == nil then return end
        GameTooltip:SetOwner(self, OnRight() and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
        GameTooltip:SetText(self.text:GetText() or "", 1, 0.82, 0)
        GameTooltip:AddLine(L.TRACKER_ZONE_TIP, 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    heads[i] = h
    return h
end

local function FillHead(h, row)
    h:SetWidth(ContentWidth())
    h.zone = row.zone
    h.count:SetText(tostring(row.count or ""))
    if row.zone ~= nil then
        -- (une zone : son nom en or, repliable)
        h.text:SetFontObject("GameFontNormalSmall")
        h.text:SetText(row.head)
        h:EnableMouse(true)
        h.arrow:Show()
        if row.folded then h.arrow:SetTexCoord(0, 0.5625, 0, 1) else h.arrow:SetTexCoord(0, 0.5625, 1, 0) end
        h.text:SetPoint("RIGHT", h.arrow, "LEFT", -4, 0)
    else
        -- (une rubrique : « À RENDRE », en petites capitales grises)
        h.text:SetFontObject("GameFontDisableSmall")
        h.text:SetText(row.head:upper())
        h:EnableMouse(false)
        h.arrow:Hide()
        h.text:SetPoint("RIGHT", h.count, "LEFT", -4, 0)
    end
end

local function LayoutFilters()
    local list = {}
    for _, key in ipairs(FILTERS) do list[#list + 1] = key end
    if instance then list[#list + 1] = "dungeon" end
    local n = #list
    local inner = WIDTH - 2 * PAD
    local w = math.floor((inner - (n - 1) * 3) / n)
    local current = Filter()
    for i, key in ipairs(list) do
        local b = filterButtons[key]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (i - 1) * (w + 3), -(HEAD_H + GAP))
        b:SetWidth(w)
        b:SetSelected(key == current)
        b:Show()
    end
    if not instance then filterButtons.dungeon:Hide() end
end

local function ChooseFilter(key)
    if key == "dungeon" then
        dungeonPick = true
    else
        dungeonPick = false
        Opt().trackerFilter = key
    end
    if scroll then scroll:ToTop() end
    Dirty()
end

local function FilterTip(self)
    local key = self.key
    GameTooltip:SetOwner(self, OnRight() and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    GameTooltip:SetText(L[FILTER_KEYS[key]], 1, 0.82, 0)
    local tip = L[FILTER_KEYS[key] .. "_TIP"]
    if key == "near" then tip = tip:format(Yards(NEAR)) end
    GameTooltip:AddLine(tip, 1, 1, 1, true)
    GameTooltip:Show()
end

local function Build()
    if frame then return end
    local f = CreateFrame("Frame", "MyMapIsRichPlusTracker", UIParent)
    frame = f
    f:SetWidth(WIDTH)
    f:SetHeight(HEAD_H + 2)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(20)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(false)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.edge = UI.Border(f, "panelEdge", 1)
    f.inner = UI.Border(f, 0, 0, 0, 0.7, 1)

    -- (l'en-tête : on le glisse, il porte le tri et le repli)
    local head = CreateFrame("Button", nil, f)
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(HEAD_H)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head.bg = head:CreateTexture(nil, "BACKGROUND")
    head.bg:SetAllPoints()
    UI.Fade(head.bg, "VERTICAL", "headerBottom", 0.95, "headerTop", 0.95)
    head:SetScript("OnDragStart", function()
        if not Opt().trackerLock then f:StartMoving() end
    end)
    head:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        SavePos()
    end)
    UI.Tip(head, L.TRACKER_TITLE, function() return Opt().trackerLock and L.TRACKER_TIP_LOCKED or L.TRACKER_TIP_DRAG end)
    f.head = head
    f.title = UI.Text(head, "GameFontNormal", L.TRACKER_TITLE)
    f.title:SetPoint("LEFT", 10, 0)
    f.count = UI.Text(head, "GameFontHighlightSmall")
    f.count:SetPoint("LEFT", f.title, "RIGHT", 8, 0)

    f.fold = UI.Button(head, "", 18, 18, "grey")
    f.fold:SetPoint("RIGHT", -6, 0)
    f.fold.arrow = f.fold:CreateTexture(nil, "ARTWORK")
    f.fold.arrow:SetSize(10, 9)
    f.fold.arrow:SetPoint("CENTER")
    f.fold.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    f.fold:SetScript("OnClick", function() TR.ToggleFold() end)
    UI.Tip(f.fold, function() return Opt().trackerFolded and L.HUD_UNFOLD or L.HUD_FOLD end)

    f.sort = UI.Button(head, "", 76, 18, "grey")
    f.sort:SetPoint("RIGHT", f.fold, "LEFT", -4, 0)
    f.sort:SetScript("OnClick", function()
        Opt().trackerSort = Opt().trackerSort == "zone" and "dist" or "zone"
        if scroll then scroll:ToTop() end
        ns.Fire("TRACKER")
        Dirty()
    end)
    UI.Tip(f.sort, L.OPT_TRACKER_SORT, L.TRACKER_SORT_TIP)

    -- (les filtres)
    for _, key in ipairs({ "all", "watched", "zone", "near", "dungeon" }) do
        local b = UI.NavButton(f, FILTER_H)
        b:SetLevel(2)
        b.key = key
        b.text:SetText(L[FILTER_KEYS[key]])
        b.text:SetJustifyH("CENTER")
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", 3, 0)
        b.text:SetPoint("RIGHT", -3, 0)
        b:SetScript("OnClick", function() ChooseFilter(key) end)
        b:SetScript("OnEnter", FilterTip)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        filterButtons[key] = b
    end

    -- (la liste)
    scroll = UI.Scroll(f, nil, 36)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(HEAD_H + GAP + FILTER_H + GAP))
    scroll:SetWidth(ContentWidth())
    scroll:SetHeight(40)
    child = scroll.child
    child:SetWidth(ContentWidth())
    emptyText = UI.Text(child, "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", 6, -6)
    emptyText:SetWidth(ContentWidth() - 12)
    emptyText:SetJustifyH("LEFT")
    f.more = CreateFrame("Button", nil, child)
    f.more:SetHeight(18)
    f.more.text = UI.Text(f.more, "GameFontDisableSmall")
    f.more.text:SetPoint("LEFT", 6, 0)
    f.more.text:SetPoint("RIGHT", -6, 0)
    f.more.text:SetJustifyH("LEFT")
    local hl = f.more:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.07)
    f.more:SetScript("OnClick", function()
        showHidden = not showHidden
        Dirty()
    end)

    PaintBackground()
    f:Hide()
    Place()
end

---------------------------------------------------------------------------
-- Ce qu'il montre
---------------------------------------------------------------------------
local function Wanted()
    if not Active() then return false end
    if MapCovers() then return false end
    if Opt().trackerCombat and InCombatLockdown() then return false end
    return next(Log.Quests()) ~= nil
end

local EMPTY = {
    all = "TRACKER_EMPTY_HIDDEN", watched = "TRACKER_EMPTY_WATCHED", zone = "TRACKER_EMPTY_ZONE",
    near = "TRACKER_EMPTY_NEAR", dungeon = "TRACKER_EMPTY_DUNGEON",
}

-- (l'ordre gardé : la souris sur le panneau ; en combat, tant que des objets
-- de quête sont en face de leurs quêtes, UI/TrackerItems.lua)
local function Held()
    if frame:IsMouseOver() then return true end
    return InCombatLockdown() and ns.TrackerItems ~= nil and ns.TrackerItems.Any()
end

-- Ce que montre le suivi, pour les objets de quête (UI/TrackerItems.lua) : le
-- cadre (s'il est là), sa liste, et les quêtes montrées { q, block }
function TR.Shown()
    return frame and frame:IsShown() and frame or nil, scroll, shownQuests
end

local Draw                   -- (juste dessous)

function TR.Refresh()
    Draw()
    ns.Fire("TRACKER_LAYOUT")
end

Draw = function()
    Mute()
    if not Wanted() then
        if frame then frame:Hide() end
        return
    end
    Build()
    local f = frame
    local now = GetTime()
    local folded = Opt().trackerFolded and true or false
    local here = ns.TravelPlanner and ns.TravelPlanner.PlayerPoint()
    local list = Collect(here)
    local max = C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept and Plain(Call(C_QuestLog.GetMaxNumQuestsCanAccept))
    f.count:SetText(type(max) == "number" and max > 0 and L.QUESTS_COUNT:format(#list, max) or tostring(#list))
    f.sort:SetText(Opt().trackerSort == "zone" and L.TRACKER_SORT_ZONE or L.TRACKER_SORT_DIST)
    if folded then f.fold.arrow:SetTexCoord(0, 0.5625, 0, 1) else f.fold.arrow:SetTexCoord(0, 0.5625, 1, 0) end
    f:Show()
    if folded then
        for _, b in pairs(filterButtons) do b:Hide() end
        scroll:Hide()
        f:SetHeight(HEAD_H + 2)
        wipe(shownQuests)
        return
    end
    LayoutFilters()
    scroll:Show()

    local frozen = Held() and next(rank) ~= nil
    pending = false
    ReadTimers()
    local super = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and Plain(Call(C_SuperTrack.GetSuperTrackedQuestID))
    local rows, nHidden, filter, nShown = Rows(list, frozen)
    local y, nHead, nQuest = 0, 0, 0
    wipe(shownQuests)
    local newRank = {}
    for _, row in ipairs(rows) do
        if row.head then
            nHead = nHead + 1
            local h = HeadBlock(nHead)
            FillHead(h, row)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(y + (y > 0 and 4 or 0)))
            h:Show()
            y = y + (y > 0 and 4 or 0) + 18 + 2
        else
            nQuest = nQuest + 1
            local q = row.quest
            q.superTracked = super ~= nil and super == q.id
            local b = QuestBlock(nQuest)
            local bh = FillQuest(b, q, now, nQuest % 2 == 0)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            b:Show()
            y = y + bh + BLOCK_GAP
            shownQuests[#shownQuests + 1] = { q = q, block = b }
            newRank[q.id] = #shownQuests
        end
    end
    for i = nHead + 1, #heads do heads[i]:Hide() end
    for i = nQuest + 1, #blocks do
        blocks[i].q = nil
        blocks[i]:Hide()
    end
    -- (l'ordre gardé : la souris dessus, les quêtes nouvelles se mettent au bout)
    if frozen then
        local n = 0
        for _, r in pairs(rank) do n = math.max(n, r) end
        for id, r in pairs(newRank) do if not rank[id] then n = n + 1 rank[id] = n end end
    else
        rank = newRank
    end

    -- (une liste vide dit pourquoi)
    if nShown == 0 then
        local key = EMPTY[filter] or "TRACKER_EMPTY_HIDDEN"
        local text = L[key]
        if filter == "near" then text = text:format(Yards(NEAR)) end
        emptyText:SetText(text)
        emptyText:Show()
        y = y + 6 + (emptyText:GetStringHeight() or 12) + 6
    else
        emptyText:Hide()
    end
    -- (en bas : les quêtes masquées)
    if nHidden > 0 then
        f.more:ClearAllPoints()
        f.more:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(y + 2))
        f.more:SetWidth(ContentWidth())
        local text = nHidden == 1 and L.TRACKER_HIDDEN_ONE or L.TRACKER_HIDDEN_N:format(nHidden)
        if showHidden then text = L.TRACKER_HIDDEN_HIDE end
        f.more.text:SetText(text)
        f.more:Show()
        y = y + 2 + 18
    else
        f.more:Hide()
        showHidden = false
    end

    -- (la hauteur : le contenu, jusqu'à la part de l'écran permise et au bas de l'écran)
    child:SetHeight(math.max(1, y))
    local top = f:GetTop() or UIParent:GetTop()
    local listTop = HEAD_H + GAP + FILTER_H + GAP
    local room = math.min(UIParent:GetHeight() * MAX_SHARE, top - (UIParent:GetBottom() or 0) - 20) - listTop - PAD
    local view = math.max(30, math.min(y, room))
    scroll:SetHeight(view)
    f:SetHeight(listTop + view + PAD)
end

-- (plusieurs changements de suite : une seule relecture)
local dirtyWait = false
function Dirty()
    if dirtyWait then return end
    dirtyWait = true
    C_Timer.After(0.1, function()
        dirtyWait = false
        TR.Refresh()
    end)
end
TR.Dirty = Dirty

-- Les distances relues chaque seconde : le texte change sur place ; l'ordre
-- changé (de plus d'un pas), la liste refaite, pas sous la souris
local function Tick()
    if not (frame and frame:IsShown()) or #shownQuests == 0 then return end
    local here = ns.TravelPlanner and ns.TravelPlanner.PlayerPoint()
    local now = GetTime()
    local byDist = Opt().trackerSort ~= "zone"
    local moved = false
    for _, s in ipairs(shownQuests) do
        local q = s.q
        q.where = Where.Of(q.id, here or false)
        q.dist = q.where and q.where.dist or nil
        if s.block.q == q then
            local text = DistText(q)
            if text ~= s.block.dist:GetText() then
                s.block.dist:SetText(text)
                moved = moved or byDist
            end
            local ends = timerEnd[q.id]
            if ends and s.block.timer then
                s.block.timer:SetText("|cffffd100" .. L.TRACKER_TIME_LEFT:format(Duration(ends - now)) .. "|r")
            end
        end
    end
    if not moved and not pending then return end
    -- (l'ordre a-t-il changé, d'un pas entier ?)
    local changed = pending
    if byDist and not changed then
        local prev
        for _, s in ipairs(shownQuests) do
            local q = s.q
            local step = q.dist and math.floor(q.dist / STEP) or math.huge
            if prev and not prev.complete == not q.complete and step < prev.step then changed = true break end
            prev = { step = step, complete = q.complete }
        end
    end
    if not changed then return end
    if Held() then
        pending = true
        return
    end
    TR.Refresh()
end

local ticker = CreateFrame("Frame")
local tickWait = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    tickWait = tickWait - elapsed
    if tickWait > 0 then return end
    tickWait = TICK
    local ok, err = pcall(Tick)
    if not ok and geterrorhandler then geterrorhandler()(err) end
end)

---------------------------------------------------------------------------
-- Les gestes (le menu de la carte, l'onglet Quêtes, /mmir suivi)
---------------------------------------------------------------------------
function TR.IsHidden(questID) return Hidden()[questID] and true or false end

function TR.ToggleHidden(questID)
    local hidden = Hidden()
    hidden[questID] = not hidden[questID] or nil
    ns.Fire("TRACKER")
    Dirty()
end

-- Les quêtes masquées encore dans le journal (les autres sont oubliées)
function TR.NumHidden()
    local hidden, log, n = Hidden(), Log.Quests(), 0
    for id in pairs(hidden) do
        if log[id] then n = n + 1 end
    end
    return n
end

function TR.UnhideAll()
    wipe(Hidden())
    ns.Fire("TRACKER")
    Dirty()
end

function TR.ToggleFold()
    if not ns.db then return end
    Opt().trackerFolded = not Opt().trackerFolded
    TR.Refresh()
    return Opt().trackerFolded
end

-- /mmir suivi : le montrer ou le couper
function TR.Toggle()
    if not ns.db then return end
    Opt().tracker = Opt().tracker == false
    ns.Fire("OPTIONS")
    TR.Refresh()
    return Opt().tracker
end

-- « Utiliser celui de My Map Is Rich » (l'onglet Quêtes) : EllesmereUI coupé
-- pour ce personnage (rend "reload" : il reste chargé jusqu'au rechargement) ;
-- Questie, son suivi coupé par son propre réglage (il recharge l'interface)
function TR.UseOurs()
    local rival = TR.Rival()
    if rival == "ellesmere" then
        -- (sans nom de personnage : celui-ci. Sur Forever, le jeu range les
        -- addons sous le nom complet, « Prénom Nom », que UnitName ne donne
        -- pas : un nom passé désignait un personnage qui n'existe pas, et le
        -- jeu l'ignorait sans rien dire)
        local addon = "EllesmereUIQuestTracker"
        local disable = C_AddOns and C_AddOns.DisableAddOn or _G.DisableAddOn
        local ok = disable and pcall(disable, addon)
        -- (le jeu l'a-t-il vraiment coupé ? 0 : coupé pour ce personnage)
        local state = C_AddOns and C_AddOns.GetAddOnEnableState and Plain(Call(C_AddOns.GetAddOnEnableState, addon))
        if ok and (type(state) ~= "number" or state == 0) then
            TR.reload = true
            ns.Print(L.TRACKER_RIVAL_DISABLED)
            return "reload"
        end
        ns.Print(L.TRACKER_RIVAL_FAILED)
    elseif rival == "questie" then
        local ok = pcall(function()
            local tracker = _G.QuestieLoader:ImportModule("QuestieTracker")
            tracker:Disable()
        end)
        if not ok then ns.Print(L.TRACKER_RIVAL_QUESTIE_HOW) end
    end
end

---------------------------------------------------------------------------
-- Les événements
---------------------------------------------------------------------------
local function EnterZone()
    local id = Instance()
    if id ~= instance then
        instance = id
        -- (entré dans un donjon : le filtre Donjon, s'il y a de ses quêtes ; sorti : celui d'avant)
        dungeonPick = id ~= nil
        if scroll then scroll:ToTop() end
    end
    Dirty()
end

ns.On("QUESTS_CHANGED", Dirty)
ns.On("QUESTS_PARTY", Dirty)
ns.On("TRAVEL", Dirty)
ns.On("OPTIONS", function()
    PaintBackground()
    Dirty()
end)
ns.On("THEME", Dirty)
ns.On("MAP_SHOW", Dirty)
ns.On("MAP_HIDE", Dirty)
ns.On("MAP_SIZE", Dirty)

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED",
    "SUPER_TRACKING_CHANGED", "QUEST_WATCH_LIST_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, arg)
    if ns.Conflict() then return end
    if event == "PLAYER_LOGIN" then
        -- (les autres addons et leurs réglages lus : Questie, EllesmereUI)
        C_Timer.After(2, TR.Refresh)
    elseif event == "ADDON_LOADED" then
        if arg == "Blizzard_ObjectiveTracker" and ns.db then C_Timer.After(0, Mute) end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        EnterZone()
    else
        Dirty()
    end
end)
