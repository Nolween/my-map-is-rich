-- Les quêtes sur la carte plein écran (maquette « Les quêtes sur la carte
-- plein écran ») : un panneau à droite, sous les boutons du haut, sur toute
-- la hauteur.
--
-- Ouvert de base avec la carte ; fermé par un geste du joueur, il le reste
-- aux ouvertures suivantes (ns.db.options.questsOpen). Les gestes : L
-- (ToggleQuestLog, le journal du jeu), le bouton du journal de la carte du
-- jeu et sa croix droite (son panneau de côté), le bouton Quêtes de
-- l'habillage, et Menu à la manette (Pad/MapNav.lua). Rien n'est écrit dans
-- les cadres du jeu : ses gestes sont seulement observés (hooksecurefunc,
-- HookScript). À la souris, nos boutons basculent aussi le journal du jeu,
-- pour que les deux restent d'accord ; à la manette, jamais (le basculer
-- depuis le code de l'addon bloquerait l'interface manette).
-- À la manette, le panneau ouvert reste au repos (padPassive : la carte garde
-- la manette et son curseur, qui peut y presser une ligne) ; Menu y entre, B
-- en ressort, Menu de nouveau le ferme.
--
-- Le panneau : les quêtes du journal, par zone ou les plus proches (LT / RT),
-- une recherche ; la quête choisie (ses objectifs, le temps depuis toi), la
-- carte y glisse et montre sa zone ; Itinéraire (Y : l'aperçu), Ajouter à la
-- file (X), Suivre, Partager au groupe, le texte de la quête.
-- À la souris : clic choisir, Maj+clic l'itinéraire tout de suite, clic droit
-- ajouter à la file.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI
local P = ns.Pad
local F = ns.Focus

local QP = {}
ns.QuestPanel = QP

local WIDTH = 400
local TOP = 64               -- px : sous les boutons du haut
local BOTTOM = 76            -- px : au-dessus des coordonnées et de la barre d'aide
local EDGE = 12
local ROW_H = 26
local DETAIL_H = 236
local OPEN_QUIET = 0.35      -- s : le journal du jeu rouvert avec la carte (son état gardé) n'ouvre pas le nôtre

local panel, list, detail, search
local entries = {}           -- les quêtes du journal : { index, questID, title, level, complete, zone, point, dist }
local items = {}             -- ce que la liste montre : { head = zone, count } ou { quest = q }
local sortBy = "zone"        -- "zone" ou "dist"
local selected               -- le questID choisi
local showText = false       -- le texte de la quête au lieu de ses objectifs
local openedAt, userAt = -10, -10
local closing = false
local focused = false        -- la manette dans le panneau (QP.Focus)
local SetFocused             -- (plus bas)

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

local function Map() return _G.WorldMapFrame end
local function T() return ns.Travel end
local function Pl() return ns.TravelPlanner end

local function Duration(secs)
    if ns.RouteHud and ns.RouteHud.Duration then return ns.RouteHud.Duration(secs) end
    return tostring(math.floor(secs or 0))
end

local function Yards(d)
    if ns.RouteHud and ns.RouteHud.Yards then return ns.RouteHud.Yards(d) end
    return tostring(math.floor(d or 0))
end

---------------------------------------------------------------------------
-- Le journal du jeu (l'API moderne, sinon celle de Classic)
---------------------------------------------------------------------------
local function NumEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        return Plain(Call(C_QuestLog.GetNumQuestLogEntries)) or 0
    end
    return Plain(Call(_G.GetNumQuestLogEntries)) or 0
end

local function InfoAt(i)
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = Call(C_QuestLog.GetInfo, i)
        if type(info) == "table" then
            return { title = Plain(info.title), level = Plain(info.level), isHeader = Plain(info.isHeader),
                questID = Plain(info.questID), complete = Plain(info.isComplete) }
        end
    end
    local title, level, _, isHeader, _, complete, _, questID = Call(_G.GetQuestLogTitle, i)
    if title then
        return { title = Plain(title), level = Plain(level), isHeader = Plain(isHeader), questID = Plain(questID),
            complete = Plain(complete) }
    end
end

local function MaxQuests()
    if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
        local n = Plain(Call(C_QuestLog.GetMaxNumQuestsCanAccept))
        if type(n) == "number" and n > 0 then return n end
    end
    return tonumber(_G.MAX_QUESTLOG_QUESTS) or nil
end

local function Objectives(q)
    local out = {}
    if C_QuestLog and C_QuestLog.GetQuestObjectives and q.questID then
        local objs = Call(C_QuestLog.GetQuestObjectives, q.questID)
        for _, o in ipairs(type(objs) == "table" and objs or {}) do
            local text = Plain(o.text)
            if type(text) == "string" and text ~= "" then out[#out + 1] = { text, Plain(o.finished) and true or false } end
        end
    end
    if #out == 0 and _G.GetNumQuestLeaderBoards then
        local n = Plain(Call(_G.GetNumQuestLeaderBoards, q.index)) or 0
        for j = 1, n do
            local text, _, done = Call(_G.GetQuestLogLeaderBoard, j, q.index)
            text = Plain(text)
            if type(text) == "string" and text ~= "" then out[#out + 1] = { text, Plain(done) and true or false } end
        end
    end
    return out
end

-- La progression d'une quête, en une colonne : « 13/15 », « Terminée »
local function Progress(q)
    if q.complete then return L.QUESTS_DONE, true end
    local have, need = 0, 0
    for _, o in ipairs(Objectives(q)) do
        local a, b = o[1]:match("(%d+)%s*/%s*(%d+)")
        if a then have, need = have + tonumber(a), need + tonumber(b) end
    end
    if need > 0 then return ("%d/%d"):format(have, need), false end
    return "", false
end

local function Watched(q)
    if C_QuestLog and C_QuestLog.IsQuestWatched and q.questID then return Call(C_QuestLog.IsQuestWatched, q.questID) and true or false end
    return Call(_G.IsQuestWatched, q.index) and true or false
end

local function ToggleWatch(q)
    local on = Watched(q)
    if C_QuestLog and C_QuestLog.AddQuestWatch and q.questID then
        if on then Call(C_QuestLog.RemoveQuestWatch, q.questID) else Call(C_QuestLog.AddQuestWatch, q.questID) end
    elseif on then
        Call(_G.RemoveQuestWatch, q.index)
    else
        Call(_G.AddQuestWatch, q.index)
    end
end

local function Share(q)
    if not (IsInGroup and IsInGroup()) then
        ns.Print(L.SHARE_NO_GROUP)
        return
    end
    Call(_G.SelectQuestLogEntry, q.index)
    Call(_G.QuestLogPushQuest)
end

local function QuestText(q)
    Call(_G.SelectQuestLogEntry, q.index)
    local desc, objectives = Call(_G.GetQuestLogQuestText)
    desc, objectives = Plain(desc), Plain(objectives)
    if type(desc) == "string" and desc ~= "" then return desc end
    return type(objectives) == "string" and objectives or ""
end

local function LevelColor(level)
    if type(level) == "number" and GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(level)
        if type(c) == "table" and c.r then return c.r, c.g, c.b end
    end
    return 1, 0.82, 0
end

---------------------------------------------------------------------------
-- Les quêtes et la liste
---------------------------------------------------------------------------
local function Read()
    wipe(entries)
    local here = Pl().PlayerPoint()
    local zone
    for i = 1, NumEntries() do
        local info = InfoAt(i)
        if info and info.title then
            if info.isHeader then
                zone = info.title
            elseif info.questID then
                local q = { index = i, questID = info.questID, title = info.title, level = info.level,
                    complete = info.complete == true or info.complete == 1, zone = zone or "" }
                local okP, point = pcall(ns.TravelQuests.Point, q.questID)
                if okP and point then
                    q.point = point
                    if here and here.cont == point.cont then q.dist = ns.TravelGraph.Dist(here, point) end
                end
                entries[#entries + 1] = q
            end
        end
    end
end

local function Filtered()
    local text = search and strtrim(search:GetText() or ""):lower() or ""
    local out = {}
    for _, q in ipairs(entries) do
        if text == "" or q.title:lower():find(text, 1, true) or q.zone:lower():find(text, 1, true) then out[#out + 1] = q end
    end
    return out
end

local function BuildItems()
    wipe(items)
    local quests = Filtered()
    if sortBy == "dist" then
        table.sort(quests, function(a, b)
            if a.dist and b.dist then return a.dist < b.dist end
            if a.dist then return true end
            if b.dist then return false end
            return a.index < b.index
        end)
        for _, q in ipairs(quests) do items[#items + 1] = { quest = q } end
        return
    end
    local zones, byZone = {}, {}
    for _, q in ipairs(quests) do
        if not byZone[q.zone] then
            byZone[q.zone] = {}
            zones[#zones + 1] = q.zone
        end
        table.insert(byZone[q.zone], q)
    end
    for _, z in ipairs(zones) do
        items[#items + 1] = { head = z, count = #byZone[z] }
        for _, q in ipairs(byZone[z]) do items[#items + 1] = { quest = q } end
    end
end

local function Selected()
    for _, q in ipairs(entries) do
        if q.questID == selected then return q end
    end
end

local FillDetail

local function FillList()
    if not list then return end
    local rows = list.rows
    local maxOffset = math.max(0, #items - #rows)
    list.offset = math.max(0, math.min(list.offset or 0, maxOffset))
    for i, row in ipairs(rows) do
        local it = items[list.offset + i]
        row.item = it
        if not it then
            row:Hide()
        elseif it.head then
            row:EnableMouse(false)
            row.selected:Hide()
            row.level:SetText("")
            row.title:SetText(it.head)
            row.title:SetFontObject("GameFontNormalSmall")
            row.title:SetTextColor(1, 0.82, 0)
            row.prog:SetText("")
            row.dist:SetText(tostring(it.count))
            row.line:Show()
            row:Show()
        else
            local q = it.quest
            row:EnableMouse(true)
            row.line:Hide()
            row.selected:SetShown(q.questID == selected)
            row.level:SetText(q.level and ("[" .. q.level .. "]") or "")
            row.level:SetTextColor(LevelColor(q.level))
            row.title:SetFontObject("GameFontHighlightSmall")
            row.title:SetText(q.title)
            if q.questID == selected then row.title:SetTextColor(1, 1, 1) else row.title:SetTextColor(1, 0.82, 0) end
            local prog, done = Progress(q)
            row.prog:SetText(prog)
            if done then row.prog:SetTextColor(UI.RGB("good")) else row.prog:SetTextColor(1, 1, 1) end
            row.dist:SetText(q.dist and Yards(q.dist) or "")
            row:Show()
        end
    end
    list.empty:SetShown(#items == 0)
    list.empty:SetText(#entries == 0 and L.QUESTS_NONE or L.QUESTS_NONE_FOUND)
end

local function FillHead()
    local n = #entries
    local max = MaxQuests()
    panel.count:SetText(max and L.QUESTS_COUNT:format(n, max) or tostring(n))
    for key, tab in pairs(panel.tabs) do tab:SetSelected(key == sortBy) end
    local pad = ns.PadUI()
    panel.lt:SetShown(pad)
    panel.rt:SetShown(pad)
    detail.route.glyph:SetShown(pad)
    detail.queue.glyph:SetShown(pad)
end

function QP.Refresh()
    if not (panel and panel:IsShown()) then return end
    Read()
    if selected and not Selected() then selected = nil end
    if not selected and entries[1] then selected = entries[1].questID end
    BuildItems()
    FillHead()
    FillList()
    FillDetail()
end

---------------------------------------------------------------------------
-- La quête choisie : le détail, et la carte qui y glisse
---------------------------------------------------------------------------
local function ShowOnMap(q)
    local mod = ns.mod
    if not (q and q.point) then
        if mod.PadQuestArea then ns.Call(mod.PadQuestArea, nil) end
        return
    end
    local u, v = Pl().UV(q.point)
    if not u then return end
    if ns.MapNav then ns.MapNav.SetFollow(false) end
    local zoom
    local okV, _, _, z = pcall(mod.ViewNow)
    if okV then zoom = z end
    if mod.FitZoom and q.point.map then
        local okF, fit = pcall(mod.FitZoom, q.point.map)
        if okF and fit then zoom = math.max(zoom or 1, fit) end
    end
    ns.Call(mod.Glide, u, v, zoom)
    if mod.PadQuestArea then ns.Call(mod.PadQuestArea, q.questID, q.point.map) end
end

local function Select(q, glide)
    if not q then return end
    selected = q.questID
    showText = false
    FillList()
    FillDetail()
    if glide then ShowOnMap(q) end
end

function FillDetail()
    local q = Selected()
    detail:SetShown(q ~= nil)
    if not q then return end
    detail.title:SetText(q.title)
    detail.level:SetText(q.level and L.QUESTS_LEVEL:format(q.level) or "")
    detail.level:SetTextColor(LevelColor(q.level))
    detail.zone:SetText(q.zone)
    local lines = {}
    if showText then
        lines[1] = QuestText(q)
    else
        for _, o in ipairs(Objectives(q)) do
            lines[#lines + 1] = (o[2] and "|cff40ff40✓ " or "|cffffffff• ") .. o[1] .. "|r"
        end
        if q.complete and #lines == 0 then lines[1] = "|cff40ff40" .. L.QUESTS_DONE .. "|r" end
    end
    detail.body:SetText(table.concat(lines, "\n"))
    -- (depuis toi : le trajet calculé, pas lancé)
    local from = ""
    if q.point and T() then
        local p = T().Preview(q.point)
        if p then
            local kinds = {}
            local K = { walk = "KIND_WALK", flight = "KIND_FLIGHT", boat = "KIND_BOAT", zeppelin = "KIND_ZEPPELIN", portal = "KIND_PORTAL", tram = "KIND_TRAM" }
            for i, leg in ipairs(p.legs) do kinds[i] = L[K[leg.kind] or "KIND_WALK"] end
            from = L.FICHE_ABOUT:format(Duration(p.secs)) .. " · " .. table.concat(kinds, ", ")
        else
            from = L.TRAVEL_ALREADY
        end
    elseif not q.point then
        from = L.TRAVEL_NO_QUEST:format(q.title)
    end
    detail.from:SetText(from)
    detail.route:SetEnabled(q.point ~= nil and ns.db.options.travel and true or false)
    detail.queue:SetEnabled(q.point ~= nil and ns.db.options.travel and true or false)
    detail.track:SetText(Watched(q) and L.QUESTS_UNTRACK or L.QUESTS_TRACK)
    detail.text:SetText(showText and L.QUESTS_OBJECTIVES or L.QUESTS_TEXT)
end

local function Route()
    local q = Selected()
    if not (q and q.point and ns.PointCard) then return end
    ns.PointCard.PreviewPoint(q.point)
end

local function Queue()
    local q = Selected()
    if q and q.point and T() then T().Enqueue(q.point) end
end

local function Sort(key)
    sortBy = key
    if list then list.offset = 0 end
    BuildItems()
    FillHead()
    FillList()
end

---------------------------------------------------------------------------
-- La construction
---------------------------------------------------------------------------
local function Button(parent, text, w, h, style, key)
    local b = UI.Button(parent, text, w, h, style)
    if key then
        b.glyph = UI.CreateGlyph(b, 18)
        b.glyph:SetPoint("LEFT", 6, 0)
        b.glyph:SetKey(key)
    end
    return b
end

local function Tab(parent, text, key)
    local b = UI.NavButton(parent, 22)
    b:SetLevel(2)
    b.text:SetText(text)
    b:SetWidth(b.text:GetStringWidth() + 22)
    b:SetScript("OnClick", function() Sort(key) end)
    return b
end

local function Row(i)
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("RIGHT", list, "RIGHT", 0, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints()
    UI.Gradient(row.selected, "HORIZONTAL", 1, 0.82, 0, 0.2, 1, 0.82, 0, 0.05)
    row.selected:Hide()
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.07)
    row.line = row:CreateTexture(nil, "ARTWORK")
    row.line:SetPoint("BOTTOMLEFT", 2, 0)
    row.line:SetPoint("BOTTOMRIGHT", -2, 0)
    row.line:SetHeight(1)
    row.line:SetColorTexture(1, 0.82, 0, 0.22)
    row.level = UI.Text(row, "GameFontHighlightSmall")
    row.level:SetPoint("LEFT", 4, 0)
    row.level:SetWidth(30)
    row.dist = UI.DimText(row, nil, "GameFontHighlightSmall")
    row.dist:SetPoint("RIGHT", -4, 0)
    row.dist:SetWidth(64)
    row.dist:SetJustifyH("RIGHT")
    row.prog = UI.Text(row, "GameFontHighlightSmall")
    row.prog:SetPoint("RIGHT", row.dist, "LEFT", -6, 0)
    row.title = UI.Text(row, "GameFontHighlightSmall")
    row.title:SetPoint("LEFT", row.level, "RIGHT", 4, 0)
    row.title:SetPoint("RIGHT", row.prog, "LEFT", -6, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row:SetScript("OnClick", function(self, button)
        local it = self.item
        if not (it and it.quest) then return end
        local q = it.quest
        if button == "RightButton" then
            Select(q, false)
            Queue()
        elseif IsShiftKeyDown() then
            if T() then T().AtQuest(q.questID) end
        else
            Select(q, true)
        end
    end)
    return row
end

local function Build(chrome)
    if panel then return end
    panel = UI.Overlay(chrome)
    panel:SetWidth(WIDTH)
    panel:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -EDGE, -TOP)
    panel:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -EDGE, BOTTOM)
    panel:EnableMouse(true)
    panel:SetFrameLevel(chrome:GetFrameLevel() + 20)
    -- (l'en-tête : le titre, le nombre, le tri, la croix)
    local title = UI.Text(panel, "GameFontNormalLarge", L.QUESTS_TITLE)
    title:SetPoint("TOPLEFT", 12, -12)
    panel.count = UI.DimText(panel, nil, "GameFontHighlightSmall")
    panel.count:SetPoint("LEFT", title, "RIGHT", 8, -1)
    panel.close = UI.CloseButton(panel, 20, function() QP.Hide(true) end)
    panel.close:SetPoint("TOPRIGHT", -8, -10)
    panel.close.noGamepad = true
    panel.rt = UI.CreateGlyph(panel, 16)
    panel.rt:SetPoint("RIGHT", panel.close, "LEFT", -8, 0)
    panel.rt:SetKey("PADRTRIGGER")
    panel.tabs = { dist = Tab(panel, L.QUESTS_NEAREST, "dist"), zone = Tab(panel, L.QUESTS_BY_ZONE, "zone") }
    panel.tabs.dist:SetPoint("RIGHT", panel.rt, "LEFT", -4, 0)
    panel.tabs.zone:SetPoint("RIGHT", panel.tabs.dist, "LEFT", -4, 0)
    panel.lt = UI.CreateGlyph(panel, 16)
    panel.lt:SetPoint("RIGHT", panel.tabs.zone, "LEFT", -4, 0)
    panel.lt:SetKey("PADLTRIGGER")
    -- (la recherche)
    search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetAutoFocus(false)
    search:SetHeight(22)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -42)
    search:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
    UI.SkinInput(search)
    search.hint = UI.DimText(search, L.QUESTS_SEARCH, "GameFontDisableSmall")
    search.hint:SetPoint("LEFT", 2, 0)
    search:SetScript("OnTextChanged", function(self)
        self.hint:SetShown(self:GetText() == "")
        if list then list.offset = 0 end
        BuildItems()
        FillList()
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    -- (la liste : des lignes réutilisées, qui défilent à la molette et à la croix)
    list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -72)
    list:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, DETAIL_H + 14)
    list:EnableMouseWheel(true)
    list.rows, list.offset = {}, 0
    function list:SetOffset(o)
        self.offset = math.max(0, math.min(o, math.max(0, #items - #self.rows)))
        FillList()
    end
    list:SetScript("OnMouseWheel", function(self, delta) self:SetOffset(self.offset - delta * 3) end)
    list:SetScript("OnSizeChanged", function(self)
        local n = math.max(1, math.floor((self:GetHeight() or 0) / ROW_H))
        for i = #self.rows + 1, n do self.rows[i] = Row(i) end
        for i = n + 1, #self.rows do self.rows[i]:Hide() end
        for i = n + 1, #self.rows do self.rows[i] = nil end
        FillList()
    end)
    list.empty = UI.DimText(list, nil, "GameFontHighlightSmall")
    list.empty:SetPoint("TOP", 0, -20)
    -- (la quête choisie)
    detail = UI.Well(panel)
    detail:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)
    detail:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    detail:SetHeight(DETAIL_H)
    detail.level = UI.Text(detail, "GameFontHighlightSmall")
    detail.level:SetPoint("TOPRIGHT", -12, -12)
    detail.title = UI.Text(detail, "GameFontNormalLarge")
    detail.title:SetPoint("TOPLEFT", 12, -10)
    detail.title:SetPoint("RIGHT", detail.level, "LEFT", -8, 0)
    detail.title:SetJustifyH("LEFT")
    detail.title:SetWordWrap(false)
    detail.zone = UI.DimText(detail, nil, "GameFontHighlightSmall")
    detail.zone:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -3)
    detail.body = UI.Text(detail, "GameFontHighlightSmall")
    detail.body:SetPoint("TOPLEFT", detail.zone, "BOTTOMLEFT", 0, -6)
    detail.body:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    detail.body:SetJustifyH("LEFT")
    detail.body:SetJustifyV("TOP")
    detail.body:SetHeight(82)
    detail.from = UI.Text(detail, "GameFontHighlightSmall")
    detail.from:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 12, 72)
    detail.from:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    detail.from:SetJustifyH("LEFT")
    detail.from:SetWordWrap(false)
    local half = math.floor((WIDTH - 16 - 24 - 6) / 2)
    detail.route = Button(detail, L.FICHE_ROUTE, half, 28, nil, "PAD4")
    detail.route:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 12, 38)
    detail.route:SetScript("OnClick", Route)
    detail.queue = Button(detail, L.ACT_QUEUE, half, 28, "grey", "PAD3")
    detail.queue:SetPoint("LEFT", detail.route, "RIGHT", 6, 0)
    detail.queue:SetScript("OnClick", Queue)
    local third = math.floor((WIDTH - 16 - 24 - 12) / 3)
    detail.track = Button(detail, L.QUESTS_TRACK, third, 22, "grey")
    detail.track:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 12, 10)
    detail.track:SetScript("OnClick", function()
        local q = Selected()
        if q then ToggleWatch(q) FillDetail() end
    end)
    detail.share = Button(detail, L.QUESTS_SHARE, third, 22, "grey")
    detail.share:SetPoint("LEFT", detail.track, "RIGHT", 6, 0)
    detail.share:SetScript("OnClick", function()
        local q = Selected()
        if q then Share(q) end
    end)
    detail.text = Button(detail, L.QUESTS_TEXT, third, 22, "grey")
    detail.text:SetPoint("LEFT", detail.share, "RIGHT", 6, 0)
    detail.text:SetScript("OnClick", function()
        showText = not showText
        FillDetail()
    end)
    panel:Hide()
    panel.padPassive = true    -- (au repos tant que Menu n'y entre pas)
    local roots = ns.mod and ns.mod.padRoots
    if type(roots) == "table" then table.insert(roots, panel) end
    F.RegisterWindow(panel, {
        onBack = function() QP.Hide(true) end,
        first = function()
            for _, row in ipairs(list.rows) do
                if row:IsShown() and row.item and row.item.quest and row.item.quest.questID == selected then return row end
            end
            return list.rows[1]
        end,
    })
end

---------------------------------------------------------------------------
-- Ouvrir, fermer ; le journal du jeu suivi
---------------------------------------------------------------------------
local function SidePanelShown()
    local map = Map()
    if not map then return false end
    if map.IsSidePanelShown then return Call(map.IsSidePanelShown, map) and true or false end
    local log = map.QuestLog or _G.QuestMapFrame
    return log and log:IsShown() or false
end

-- (à la souris, hors combat : le journal du jeu suit le nôtre ; jamais à la
-- manette : ce serait le code de l'addon dans la carte du jeu)
local function MatchGame(open)
    local map = Map()
    if ns.PadUI() or InCombatLockdown() or not (map and map.HandleUserActionToggleSidePanel) then return end
    if SidePanelShown() ~= open then Call(map.HandleUserActionToggleSidePanel, map) end
end

-- (ouvert ou fermé par un geste du joueur : retenu pour la prochaine ouverture de la carte)
local function Remember(open)
    if ns.db then ns.db.options.questsOpen = open and true or false end
end

function QP.Show(user)
    if not (panel and ns.FullMap() and ns.MapShown()) then return end
    if user ~= nil then Remember(true) end
    if not panel:IsShown() then
        panel:Show()
        QP.Refresh()
        local q = Selected()
        if q then ShowOnMap(q) end
        if ns.MapChrome and ns.MapChrome.SetQuestsLit then ns.MapChrome.SetQuestsLit(true) end
        P.Dirty()
    end
    if user then MatchGame(true) end
end

function QP.Hide(user)
    if not panel then return end
    if user ~= nil then Remember(false) end
    if panel:IsShown() then
        closing = true
        SetFocused(false)
        panel:Hide()
        local mod = ns.mod
        if mod and mod.PadQuestArea then ns.Call(mod.PadQuestArea, nil) end
        if ns.MapChrome and ns.MapChrome.SetQuestsLit then ns.MapChrome.SetQuestsLit(false) end
        P.Dirty()
        closing = false
    end
    if user then MatchGame(false) end
end

function QP.Shown() return panel and panel:IsShown() or false end

-- La manette dans le panneau, ou pas : ouvert de base, il reste au repos (la
-- carte garde la manette et son curseur ; Pad/Focus.lua : padPassive) ;
-- Menu y entre, B en ressort
function SetFocused(on)
    focused = on and true or false
    if panel then panel.padPassive = not focused end
    P.Dirty()
end

function QP.Focus() if QP.Shown() then SetFocused(true) end end
function QP.Blur() SetFocused(false) end
function QP.Focused() return QP.Shown() and focused end

-- Menu à la manette : fermé, ouvert et la manette dedans ; ouvert au repos,
-- la manette dedans ; la manette dedans, fermé
function QP.PadMenu()
    if not QP.Shown() then
        QP.Show(false)
        QP.Focus()
    elseif not focused then
        QP.Focus()
    else
        QP.Hide(false)
    end
end

function QP.Toggle()
    if QP.Shown() then QP.Hide(true) else QP.Show(true) end
end

-- L (ToggleQuestLog) : la carte ouverte par lui, nos quêtes avec ; déjà
-- ouverte, nos quêtes basculées
local function AfterToggleLog()
    if not ns.FullMap() then return end
    if not ns.MapShown() then
        QP.Hide(nil)
        return
    end
    if GetTime() - openedAt < OPEN_QUIET then QP.Show(false) return end
    if QP.Shown() then QP.Hide(false) else QP.Show(false) end
end

-- Le bouton du journal de la carte du jeu (ou ce que fait la croix droite)
-- (ouvert par un geste du journal à la manette : la manette y va, comme le
-- jeu la donne à son journal)
local function ShowFromGame()
    QP.Show(false)
    if ns.PadUI() then QP.Focus() end
end

local function AfterSidePanel()
    if not ns.FullMap() then return end
    if SidePanelShown() then ShowFromGame() else QP.Hide(false) end
end

local function OnLogShow()
    if not (ns.FullMap() and ns.MapShown()) then return end
    -- (rouvert avec la carte, d'après l'état gardé du jeu, sans geste du joueur : rien)
    if GetTime() - openedAt < OPEN_QUIET and GetTime() - userAt > OPEN_QUIET then return end
    ShowFromGame()
end

local function OnLogHide()
    -- (la carte qui se ferme ferme aussi le journal : ce n'est pas un geste pour les quêtes)
    if closing or not ns.FullMap() or not ns.MapShown() then return end
    QP.Hide(false)
end

local function Hook()
    local map = Map()
    if not map or QP.hooked then return end
    QP.hooked = true
    map:HookScript("OnShow", function() openedAt = GetTime() end)
    if type(_G.ToggleQuestLog) == "function" then
        hooksecurefunc("ToggleQuestLog", function()
            userAt = GetTime()
            C_Timer.After(0, AfterToggleLog)
        end)
    end
    if type(map.HandleUserActionToggleSidePanel) == "function" then
        hooksecurefunc(map, "HandleUserActionToggleSidePanel", function()
            userAt = GetTime()
            C_Timer.After(0, AfterSidePanel)
        end)
    end
    local log = map.QuestLog or _G.QuestMapFrame
    if log and log.HookScript then
        log:HookScript("OnShow", function() C_Timer.After(0, OnLogShow) end)
        log:HookScript("OnHide", function() C_Timer.After(0, OnLogHide) end)
    end
end

ns.On("READY", function()
    if _G.WorldMapFrame then
        Hook()
    elseif EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Hook)
    end
end)
ns.On("MAP_CHROME", Build)
ns.On("MAP_HIDE", function() QP.Hide(nil) end)
-- (de base, les quêtes s'ouvrent avec la carte plein écran ; fermées par un
-- geste du joueur, elles le restent aux ouvertures suivantes)
ns.On("MAP_SHOW", function()
    C_Timer.After(0.1, function()
        if ns.db and ns.db.options.questsOpen ~= false then QP.Show(nil) end
    end)
end)

-- (le journal change : la liste suit, un peu plus tard)
local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
local pending = false
events:SetScript("OnEvent", function()
    if pending or not QP.Shown() then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        QP.Refresh()
    end)
end)

---------------------------------------------------------------------------
-- La manette dans le panneau : la croix, A choisir (et la carte y glisse),
-- Y l'itinéraire, X la file, LT / RT le tri ; B reste au jeu, qui ferme son
-- journal (et le nôtre avec)
---------------------------------------------------------------------------
local function Current()
    local f = F.Current and F.Current()
    if f and f.item and f.item.quest then return f.item.quest end
end

-- (pas le contexte des fenêtres comme base : B y a son propre sens, revenir à la carte)
P.DefineContext("quests", 52.5, function() return QP.Focused() and F.Top() == panel end)
P.SetAction("quests", "PADDUP", function() F.Move(0, 1) end)
P.SetAction("quests", "PADDDOWN", function() F.Move(0, -1) end)
P.SetAction("quests", "PADDLEFT", function() F.Move(-1, 0) end)
P.SetAction("quests", "PADDRIGHT", function() F.Move(1, 0) end, "HINT_MOVE")
P.SetAction("quests", "PAD1", function()
    local q = Current()
    if q then Select(q, true) else F.Activate("LeftButton") end
end, "HINT_SELECT")
P.SetAction("quests", "PAD4", function()
    local q = Current()
    if q then Select(q, false) end
    Route()
end, "FICHE_ROUTE")
P.SetAction("quests", "PAD3", function()
    local q = Current()
    if q then Select(q, false) end
    Queue()
end, "ACT_QUEUE")
P.SetAction("quests", "PADLTRIGGER", function() Sort("zone") end)
P.SetAction("quests", "PADRTRIGGER", function() Sort("dist") end, "HINT_QUESTS_SORT")
P.SetAction("quests", "PAD2", function() QP.Blur() end, "HINT_BACK_MAP")
P.SetAction("quests", "PADFORWARD", function() QP.PadMenu() end, "HINT_QUESTS_CLOSE")
F.WINDOW_CONTEXTS.quests = true
