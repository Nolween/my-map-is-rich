-- Les quêtes sur la carte plein écran (maquette « Les quêtes sur la carte
-- plein écran ») : un panneau à droite, sous les boutons du haut, sur toute
-- la hauteur.
--
-- Toujours affiché avec la carte, plein écran ou réduite : rien ne le cache,
-- que la carte qui se ferme. Plein écran, il est sur la carte, à droite ; la
-- carte réduite le pose dehors, collé à son bord droit.
-- À la manette, sur la carte plein écran, la manette y entre à l'ouverture
-- si la carte n'a pas son curseur, et le stick gauche y va de quête en quête
-- au lieu de faire marcher le personnage (en bas du fichier). Sinon, il reste
-- au repos (padPassive). RT y entre (Pad/MapNav.lua), comme A sur une quête au
-- curseur et la croix droite du jeu (son journal) : plus de curseur sur la carte, la
-- croix va de quête en quête (la carte y glisse), Y, X, LT le tri. RT, B ou la
-- croix gauche en ressortent (la croix gauche du jeu redonne ensuite le
-- curseur à la carte). Rien n'est écrit dans les cadres du jeu : ses gestes
-- sont seulement observés (hooksecurefunc, HookScript).
--
-- Le panneau : les quêtes du journal, par zone ou les plus proches (LT / RT),
-- une recherche. A ou un clic ouvre la fiche d'une quête à la place de la
-- liste, comme le journal de la carte du jeu : ses objectifs, son histoire,
-- ses récompenses (les objets, l'argent, l'expérience), le temps depuis toi ;
-- Itinéraire (Y : part tout de suite), Ajouter à la file (X), Suivre (A), Partager
-- (LT), Abandonner (View, deux appuis). B revient à la liste. La carte glisse
-- jusqu'à la quête.
-- Le menu d'une quête : Y dans la liste, ou un clic droit, ouvre toutes ses
-- actions sans passer par la fiche (voir la quête, itinéraire, file, suivre,
-- partager, lien dans la discussion, abandonner après confirmation).
-- À la souris : clic la fiche, Maj+clic l'itinéraire tout de suite, clic
-- droit le menu.
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
local PAGE_W = WIDTH - 12 - 22 - 6   -- px : le texte de la fiche (la barre de défilement à droite)
local ITEM_H = 40                    -- px : la case d'une récompense
local OPEN_QUIET = 0.35      -- s : le journal du jeu rouvert avec la carte (son état gardé) n'ouvre pas le nôtre
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t "   -- (la coche : la police du jeu n'a pas « ✓ »)

local panel, list, page, search
local entries = {}           -- les quêtes du journal : { index, questID, title, level, complete, zone, point, dist }
local items = {}             -- ce que la liste montre : { head = zone, count } ou { quest = q }
local sortBy = "zone"        -- "zone" ou "dist"
local selected               -- le questID choisi
local view = "list"          -- "list" ou "quest" (la fiche de la quête choisie)
local readCache = {}         -- questID → ce que le journal dit de la quête (Details)
local openedAt, userAt = -10, -10
local focused = false        -- la manette dans le panneau (QP.Focus)
local armed                  -- le questID dont l'abandon attend sa confirmation (AbandonPress)
local menuFrame              -- le cadre du menu d'une quête (UI.ShowMenu)
local menuQuest              -- le questID du menu ouvert (nil : pas de menu à nous)
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

-- La quête choisie dans le journal du jeu le temps de fn, puis celle d'avant
-- rendue (l'API moderne, celle de la carte de Forever, sinon celle de Classic)
local function WithSelected(q, fn)
    local CQ = C_QuestLog
    local index = q.index
    if CQ and CQ.GetLogIndexForQuestID and q.questID then
        local i = Plain(Call(CQ.GetLogIndexForQuestID, q.questID))
        if type(i) == "number" and i > 0 then index = i end
    end
    local ok, result
    -- (choisir une quête dans le journal du jeu coupé par la garde, Plus/Core.lua :
    -- lu sans la choisir ; l'API moderne lit par l'index et le questID)
    if not ns.Risky("SelectQuest") then
        ok, result = pcall(fn, index)
    elseif CQ and CQ.SetSelectedQuest and q.questID then
        local before = Plain(Call(CQ.GetSelectedQuest))
        Call(CQ.SetSelectedQuest, q.questID)
        ok, result = pcall(fn, index)
        if type(before) == "number" and before > 0 and before ~= q.questID then Call(CQ.SetSelectedQuest, before) end
    else
        local before = Plain(Call(_G.GetQuestLogSelection))
        Call(_G.SelectQuestLogEntry, index)
        ok, result = pcall(fn, index)
        if type(before) == "number" and before > 0 and before ~= index then Call(_G.SelectQuestLogEntry, before) end
    end
    if ok then return result end
end

local function Share(q)
    if not (IsInGroup and IsInGroup()) then
        ns.Print(L.SHARE_NO_GROUP)
        return
    end
    WithSelected(q, function() Call(_G.QuestLogPushQuest) end)
end

-- Abandonner une quête, comme le bouton du journal du jeu : la quête choisie
-- dans son journal, désignée comme celle à abandonner, puis abandonnée. Rien
-- n'est abandonné si le jeu ne confirme pas que c'est bien elle (la garde de
-- Plus/Core.lua qui couperait le choix laisserait une autre quête choisie).
-- (vrai : abandonnée)
local function Abandon(q)
    local CQ = C_QuestLog
    local set = (CQ and CQ.SetAbandonQuest) or _G.SetAbandonQuest
    local go = (CQ and CQ.AbandonQuest) or _G.AbandonQuest
    if type(set) ~= "function" or type(go) ~= "function" or not q.questID then return false end
    if not ns.Risky("SelectQuest") then return false end
    local index = q.index
    if CQ and CQ.GetLogIndexForQuestID then
        local i = Plain(Call(CQ.GetLogIndexForQuestID, q.questID))
        if type(i) == "number" and i > 0 then index = i end
    end
    -- (les deux journaux, le moderne et celui de Classic : Forever peut mêler
    -- leurs fonctions)
    if CQ and CQ.SetSelectedQuest then Call(CQ.SetSelectedQuest, q.questID) end
    if _G.SelectQuestLogEntry then Call(_G.SelectQuestLogEntry, index) end
    Call(set)
    local sure
    if CQ and CQ.GetAbandonQuest then
        sure = Plain(Call(CQ.GetAbandonQuest)) == q.questID
    elseif _G.GetAbandonQuestName then
        sure = Plain(Call(_G.GetAbandonQuestName)) == q.title
    elseif _G.GetQuestLogSelection then
        sure = Plain(Call(_G.GetQuestLogSelection)) == index
    elseif CQ and CQ.GetSelectedQuest then
        sure = Plain(Call(CQ.GetSelectedQuest)) == q.questID
    end
    if not sure then return false end
    local ok = pcall(go)
    return ok
end

local function Num(v)
    v = Plain(v)
    return type(v) == "number" and v or 0
end

local function Str(v)
    v = Plain(v)
    return type(v) == "string" and v or ""
end

-- Ce que le journal dit d'une quête, comme sa fiche dans le jeu : son
-- histoire, le résumé de ses objectifs, les objets au choix, les objets
-- donnés, l'argent, l'expérience, les sorts appris
local function Details(q)
    return WithSelected(q, function(index)
        local d = { choices = {}, rewards = {}, spells = {} }
        d.story, d.summary = Call(_G.GetQuestLogQuestText, index)
        d.story, d.summary = Str(d.story), Str(d.summary)
        local id = q.questID
        local function Items(kind, n, info, out)
            for i = 1, n do
                local name, texture, count, quality = info(i)
                name = Str(name)
                if name ~= "" then
                    out[#out + 1] = { kind = kind, i = i, name = name, texture = Plain(texture), count = Num(count),
                        quality = Plain(quality), link = Plain(Call(_G.GetQuestLogItemLink, kind, i, id)) }
                end
            end
        end
        Items("choice", Num(Call(_G.GetNumQuestLogChoices, id, true)),
            function(i) return Call(_G.GetQuestLogChoiceInfo, i, id) end, d.choices)
        Items("reward", Num(Call(_G.GetNumQuestLogRewards, id)),
            function(i) return Call(_G.GetQuestLogRewardInfo, i, id) end, d.rewards)
        d.money = Num(Call(_G.GetQuestLogRewardMoney, id))
        d.xp = Num(Call(_G.GetQuestLogRewardXP, id))
        local QI = C_QuestInfoSystem
        if QI and QI.GetQuestRewardSpells then
            local ids = Call(QI.GetQuestRewardSpells, id)
            for _, spellID in ipairs(type(ids) == "table" and ids or {}) do
                local info = QI.GetQuestRewardSpellInfo and Call(QI.GetQuestRewardSpellInfo, id, spellID)
                if type(info) == "table" and Str(info.name) ~= "" then
                    d.spells[#d.spells + 1] = { kind = "spell", name = Str(info.name), texture = Plain(info.texture), spellID = spellID }
                end
            end
        elseif _G.GetQuestLogRewardSpell then
            local texture, name = Call(_G.GetQuestLogRewardSpell)
            if Str(name) ~= "" then d.spells[1] = { kind = "spell", name = Str(name), texture = Plain(texture) } end
        end
        return d
    end)
end

-- (ce que la fiche montre, lu une fois par ouverture : relu à chaque
-- changement du journal, choisir une quête pourrait en annoncer un)
local function Read1(q, fresh)
    if fresh or not readCache[q.questID] then readCache[q.questID] = Details(q) or { choices = {}, rewards = {}, spells = {} } end
    return readCache[q.questID]
end

-- (/mmir focus : ce que la lecture trouve sur ce client)
function QP.Probe()
    local CQ = C_QuestLog or {}
    local function Has(f) return type(f) == "function" and L.YES or "-" end
    local line = ("SetSelectedQuest %s · SelectQuestLogEntry %s · GetQuestLogQuestText %s · GetNumQuestLogChoices %s · GetQuestLogRewardXP %s · GetQuestLogItemLink %s")
        :format(Has(CQ.SetSelectedQuest), Has(_G.SelectQuestLogEntry), Has(_G.GetQuestLogQuestText),
            Has(_G.GetNumQuestLogChoices), Has(_G.GetQuestLogRewardXP), Has(_G.GetQuestLogItemLink))
    local q
    for _, e in ipairs(entries) do
        if e.questID == selected then q = e break end
    end
    if q then
        local d = Details(q) or {}
        line = line .. ("\n  %s : histoire %d car. · résumé %d car. · au choix %d · donnés %d · argent %d · xp %d · sorts %d")
            :format(q.title, #(d.story or ""), #(d.summary or ""), #(d.choices or {}), #(d.rewards or {}),
                d.money or 0, d.xp or 0, #(d.spells or {}))
    end
    return line
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
-- (le point d'une quête sur la carte : plusieurs appels au jeu par quête, et
-- le journal change souvent à l'ouverture de la carte ; gardé 3 s)
local POINT_TTL = 3
local pointCache = {}           -- questID → { at, point }

local function QuestPoint(questID)
    local now = GetTime()
    local c = pointCache[questID]
    if c and now - c.at < POINT_TTL then return c.point end
    local okP, point = pcall(ns.TravelQuests.Point, questID)
    point = okP and point or nil
    pointCache[questID] = { at = now, point = point }
    return point
end

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
                local point = QuestPoint(q.questID)
                if point then
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

-- (une quête du journal par son questID, telle que relue en dernier)
local function Fresh(questID)
    for _, q in ipairs(entries) do
        if q.questID == questID then return q end
    end
end

-- (le menu d'une quête fermé, s'il est ouvert)
local function CloseQuestMenu()
    if menuQuest and UI.MenuShown() then UI.HideMenu() end
    menuQuest = nil
end

local FillPage           -- (plus bas)
local function FillRow(row, it)
    row.item = it
    if it.head then
        -- (le nom d'une zone : en grand, sur son bandeau, avec son nombre de quêtes)
        row:EnableMouse(false)
        row.selected:Hide()
        row.level:SetText("")
        row.title:SetText("")
        row.prog:SetText("")
        row.dist:SetText("")
        row.head:SetText(it.head)
        row.count:SetText(tostring(it.count))
        row.band:Show()
        row.bar:Show()
        row.line:Show()
        row.head:Show()
        row.count:Show()
        row:Show()
    else
        local q = it.quest
        row:EnableMouse(true)
        row.band:Hide()
        row.bar:Hide()
        row.line:Hide()
        row.head:Hide()
        row.count:Hide()
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

-- Les lignes réutilisées, remplies depuis le décalage
local function FillList()
    if not list then return end
    local rows = list.rows
    list.offset = math.max(0, math.min(list.offset or 0, math.max(0, #items - #rows)))
    for i, row in ipairs(rows) do
        local it = items[list.offset + i]
        if it then
            FillRow(row, it)
        else
            row.item = nil
            row:Hide()
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
    panel.lt:SetShown(pad and view == "list")
    panel.rt:SetShown(pad)
    for _, b in ipairs(page.actions) do if b.glyph then b.glyph:SetShown(pad) end end
    page.back.glyph:SetShown(pad)
end

local ShowView               -- (plus bas)

function QP.Refresh()
    if not (panel and panel:IsShown()) then return end
    Read()
    -- (la quête du menu rendue ou abandonnée : le menu se ferme)
    if menuQuest and not Fresh(menuQuest) then CloseQuestMenu() end
    if selected and not Selected() then
        selected = nil
        -- (la quête de la fiche rendue ou abandonnée : retour à la liste)
        if view == "quest" then ShowView("list") end
    end
    if not selected and entries[1] then selected = entries[1].questID end
    BuildItems()
    FillHead()
    FillList()
    if view == "quest" then FillPage(false) end
end

---------------------------------------------------------------------------
-- La quête choisie : le détail, et la carte qui y glisse
---------------------------------------------------------------------------
local function ShowOnMap(q)
    local mv = ns.Map.View
    if not (q and q.point) then
        mv.QuestArea(nil)
        return
    end
    local u, v = Pl().UV(q.point)
    if not u then return end
    if ns.MapNav then ns.MapNav.SetFollow(false) end
    local _, _, zoom = mv.Now()
    if q.point.map then
        local fit = mv.FitZoom(q.point.map)
        if fit then zoom = math.max(zoom or 1, fit) end
    end
    mv.Glide(u, v, zoom)
    mv.QuestArea(q.questID, q.point.map)
end

local function Select(q, glide)
    if not q then return end
    selected = q.questID
    FillList()
    if glide then ShowOnMap(q) end
end

---------------------------------------------------------------------------
-- La fiche d'une quête, comme dans le journal du jeu : ses objectifs, son
-- histoire, ses récompenses
---------------------------------------------------------------------------
-- (un texte du jeu, déjà traduit, sinon le nôtre)
local function GameText(name, key)
    local s = _G[name]
    if type(s) == "string" and s ~= "" then return s end
    return L[key]
end

-- (depuis toi : le trajet calculé, pas lancé)
local function FromText(q)
    if q.point and T() then
        local p = T().Preview(q.point)
        if not p then return L.TRAVEL_ALREADY end
        local kinds = {}
        local K = { walk = "KIND_WALK", flight = "KIND_FLIGHT", boat = "KIND_BOAT", zeppelin = "KIND_ZEPPELIN", portal = "KIND_PORTAL", tram = "KIND_TRAM" }
        for i, leg in ipairs(p.legs) do kinds[i] = L[K[leg.kind] or "KIND_WALK"] end
        return L.FICHE_ABOUT:format(Duration(p.secs)) .. " · " .. table.concat(kinds, ", ")
    end
    if not q.point then return L.TRAVEL_NO_QUEST:format(q.title) end
    return ""
end

local function QualityColor(quality)
    local c = type(quality) == "number" and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if type(c) == "table" and c.r then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function Coins(money)
    if GetCoinTextureString then
        local s = Call(GetCoinTextureString, money)
        if type(s) == "string" then return s end
    end
    if GetMoneyString then
        local s = Call(GetMoneyString, money)
        if type(s) == "string" then return s end
    end
    return tostring(money)
end

local function Big(n)
    if BreakUpLargeNumbers then
        local s = Call(BreakUpLargeNumbers, n)
        if type(s) == "string" then return s end
    end
    return tostring(n)
end

-- L'info-bulle du jeu d'une récompense : par son lien, sinon par le journal
local function RewardTip(self)
    local it = self.data
    if not it then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local ok = false
    if it.link then ok = pcall(GameTooltip.SetHyperlink, GameTooltip, it.link) end
    if not ok and it.spellID and GameTooltip.SetSpellByID then ok = pcall(GameTooltip.SetSpellByID, GameTooltip, it.spellID) end
    if not ok and it.kind ~= "spell" and GameTooltip.SetQuestLogItem then
        local q = Selected()
        if q then
            ok = WithSelected(q, function()
                GameTooltip:SetQuestLogItem(it.kind, it.i, q.questID)
                return true
            end) and true or false
        end
    end
    if not ok then GameTooltip:SetText(it.name, QualityColor(it.quality)) end
    GameTooltip:Show()
end

-- (une case de récompense : l'icône et son nombre, le nom dans la couleur de
-- sa qualité ; réutilisée d'une fiche à l'autre)
local function RewardButton(i)
    local b = page.items[i]
    if b then return b end
    b = CreateFrame("Button", nil, page.child)
    b:SetSize(page.colW, ITEM_H)
    b.isReward = true
    b.noGamepad = true      -- (la croix gauche / droite y va : PageReward)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    UI.Fill(b.bg, "inputBg", 1)
    UI.Border(b, "edgeLight", 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(ITEM_H - 6, ITEM_H - 6)
    b.icon:SetPoint("LEFT", 3, 0)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", -1, 1)
    b.name = UI.Text(b, "GameFontHighlightSmall")
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.name:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.name:SetJustifyH("LEFT")
    b:SetScript("OnEnter", RewardTip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    page.items[i] = b
    return b
end

local function LabelText(i)
    local fs = page.labels[i]
    if fs then return fs end
    fs = UI.Text(page.child, "GameFontNormalSmall")
    fs:SetWidth(PAGE_W)
    fs:SetJustifyH("LEFT")
    page.labels[i] = fs
    return fs
end

-- (un titre de section, comme UI.Section : doré, un trait jusqu'au bord)
local function Head(i, text, y)
    local h = page.heads[i]
    h.fs:SetText(text)
    h.fs:ClearAllPoints()
    h.fs:SetPoint("TOPLEFT", page.child, "TOPLEFT", 0, -y)
    h.line:SetWidth(math.max(1, PAGE_W - h.fs:GetStringWidth() - 8))
    h.fs:Show()
    h.line:Show()
    return y + h.fs:GetStringHeight() + 8
end

-- (un paragraphe : posé à y, sa hauteur mesurée)
local function Para(fs, text, y, gap)
    if not text or text == "" then
        fs:Hide()
        return y
    end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", page.child, "TOPLEFT", 0, -y)
    fs:SetText(text)
    fs:Show()
    return y + fs:GetStringHeight() + (gap or 10)
end

function FillPage(fresh)
    local q = Selected()
    if not (page and q) then return end
    local d = Read1(q, fresh)
    page.title:SetText(q.title)
    page.level:SetText(q.level and L.QUESTS_LEVEL:format(q.level) or "")
    page.level:SetTextColor(LevelColor(q.level))
    page.zone:SetText(q.zone)
    page.from:SetText(FromText(q))
    local canGo = q.point ~= nil and ns.db.options.travel and true or false
    page.route:SetEnabled(canGo)
    page.queue:SetEnabled(canGo)
    page.track:SetText(Watched(q) and L.QUESTS_UNTRACK or L.QUESTS_TRACK)
    -- (une autre quête : l'abandon demandé pour la précédente est oublié)
    if armed ~= q.questID then armed = nil end
    page.abandon:SetText(armed and (UI.Hex("bad") .. L.QUESTS_ABANDON_SURE .. "|r") or L.QUESTS_ABANDON)
    for _, h in ipairs(page.heads) do
        h.fs:Hide()
        h.line:Hide()
    end
    for _, fs in ipairs(page.labels) do fs:Hide() end
    for _, b in ipairs(page.items) do
        b.data = nil
        b:Hide()
    end
    -- (les objectifs : le résumé du jeu, puis chacun, fait ou non)
    local y = Head(1, GameText("QUEST_OBJECTIVES", "QUESTS_OBJECTIVES_HEAD"), 0)
    y = Para(page.summary, d.summary, y, 8)
    local lines = {}
    for _, o in ipairs(Objectives(q)) do
        lines[#lines + 1] = (o[2] and ("|cff40ff40" .. CHECK) or "|cffffffff• ") .. o[1] .. "|r"
    end
    if q.complete and #lines == 0 then lines[1] = "|cff40ff40" .. CHECK .. L.QUESTS_DONE .. "|r" end
    y = Para(page.objs, table.concat(lines, "\n"), y, 14)
    -- (l'histoire)
    if d.story ~= "" then
        y = Head(2, GameText("QUEST_DESCRIPTION", "QUESTS_STORY"), y)
        y = Para(page.story, d.story, y, 14)
    else
        page.story:Hide()
    end
    -- (les récompenses : au choix, données, puis l'argent et l'expérience)
    page.money:Hide()
    local given = {}
    for _, it in ipairs(d.rewards) do given[#given + 1] = it end
    for _, it in ipairs(d.spells) do given[#given + 1] = it end
    if #d.choices + #given > 0 or d.money > 0 or d.xp > 0 then
        y = Head(3, GameText("QUEST_REWARDS", "QUESTS_REWARDS"), y)
        local nLabel, nItem, before = 0, 0, false
        local function Label(text)
            nLabel = nLabel + 1
            y = Para(LabelText(nLabel), text, y, 6)
        end
        local function Grid(set)
            for k, it in ipairs(set) do
                nItem = nItem + 1
                local b = RewardButton(nItem)
                b.data = it
                b.icon:SetTexture(it.texture or 134400)
                b.count:SetText((it.count or 0) > 1 and tostring(it.count) or "")
                b.name:SetText(it.name)
                b.name:SetTextColor(QualityColor(it.quality))
                local col, row = (k - 1) % 2, math.floor((k - 1) / 2)
                b.top = y + row * (ITEM_H + 4)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", page.child, "TOPLEFT", col * (page.colW + 6), -b.top)
                b:Show()
            end
            y = y + math.ceil(#set / 2) * (ITEM_H + 4) + 6
        end
        if #d.choices > 0 then
            Label(GameText("REWARD_CHOICES", "QUESTS_CHOOSE"))
            Grid(d.choices)
            before = true
        end
        if #given > 0 then
            Label(before and GameText("REWARD_ITEMS", "QUESTS_ALSO") or GameText("REWARD_ITEMS_ONLY", "QUESTS_RECEIVE"))
            Grid(given)
            before = true
        end
        if d.money > 0 or d.xp > 0 then
            Label(before and GameText("REWARD_ITEMS", "QUESTS_ALSO") or GameText("REWARD_ITEMS_ONLY", "QUESTS_RECEIVE"))
            local parts = {}
            if d.money > 0 then parts[#parts + 1] = Coins(d.money) end
            if d.xp > 0 then parts[#parts + 1] = L.QUESTS_XP:format(Big(d.xp)) end
            y = Para(page.money, table.concat(parts, "\n"), y, 10)
        end
    end
    page.child:SetHeight(math.max(1, y + 8))
    if fresh then page.scroll:ToTop() end
end

-- La liste ou la fiche, à la même place
function ShowView(v)
    view = v
    CloseQuestMenu()
    local isList = v == "list"
    panel.title:SetShown(isList)
    panel.count:SetShown(isList)
    for _, tab in pairs(panel.tabs) do tab:SetShown(isList) end
    if not isList and search:HasFocus() then search:ClearFocus() end
    search:SetShown(isList)
    list:SetShown(isList)
    page:SetShown(not isList)
    if isList then
        GameTooltip:Hide()
        armed = nil
    end
    FillHead()
    P.Dirty()
end

function QP.View() return QP.Shown() and view or nil end

-- A ou un clic sur une quête : sa fiche, et la carte qui y glisse
local function OpenQuest(q)
    if not (q and page) then return end
    selected = q.questID
    ShowView("quest")
    FillList()
    FillPage(true)
    ShowOnMap(q)
end

-- B ou Retour : la liste, sur la même quête (et la manette avec)
local function BackToList()
    local cur = F.Current and F.Current()
    if cur and cur.isReward then F.SetCurrent(nil) end
    ShowView("list")
    for k, it in ipairs(items) do
        if it.quest and it.quest.questID == selected then
            if k <= list.offset or k > list.offset + #list.rows then
                list.offset = math.max(0, k - math.floor(#list.rows / 2))
            end
            break
        end
    end
    FillList()
    if focused and F.SetCurrent then
        for _, row in ipairs(list.rows) do
            if row:IsShown() and row.item and row.item.quest and row.item.quest.questID == selected then
                F.SetCurrent(row)
                break
            end
        end
    end
end

-- (la manette dans la fiche : la croix haut / bas fait défiler, gauche /
-- droite va de récompense en récompense, avec son info-bulle)
local function PageScroll(dir)
    local s = page.scroll
    local max = math.max(0, s:GetVerticalScrollRange() or 0)
    s:SetVerticalScroll(math.max(0, math.min(max, s:GetVerticalScroll() + dir * 48)))
    local cur = F.Current and F.Current()
    if cur and cur.isReward then F.SetCurrent(nil) end
end

local function ShownRewards()
    local out = {}
    for _, b in ipairs(page.items) do
        if b.data and b:IsShown() then out[#out + 1] = b end
    end
    return out
end

local function PageReward(dir)
    local shown = ShownRewards()
    if #shown == 0 then return end
    local cur = F.Current and F.Current()
    local k = 0
    for i, b in ipairs(shown) do
        if b == cur then k = i break end
    end
    if k == 0 then
        k = dir > 0 and 1 or #shown
    else
        k = k + dir
        if k < 1 then k = #shown elseif k > #shown then k = 1 end
    end
    local b = shown[k]
    local s = page.scroll
    local viewH, at = s:GetHeight() or 0, s:GetVerticalScroll()
    local max = math.max(0, s:GetVerticalScrollRange() or 0)
    if b.top < at then
        s:SetVerticalScroll(math.max(0, b.top - 6))
    elseif b.top + ITEM_H > at + viewH then
        s:SetVerticalScroll(math.min(max, b.top + ITEM_H - viewH + 6))
    end
    if F.SetCurrent then F.SetCurrent(b) end
end

-- Itinéraire : part tout de suite, depuis où tu es (pas d'aperçu à confirmer)
local function Route()
    local q = Selected()
    if q and q.point and T() then T().Go(q.point) end
end

local function Queue()
    local q = Selected()
    if q and q.point and T() then T().Enqueue(q.point) end
end

-- Abandonner (View à la manette, ou le bouton) : un premier appui demande de
-- confirmer (le bouton dit « Vraiment abandonner ? », en rouge, 4 s), le
-- second abandonne et revient à la liste
local ABANDON_WAIT = 4       -- s : le temps de confirmer

local function PaintAbandon()
    if not page then return end
    local q = Selected()
    if q and armed == q.questID then
        page.abandon:SetText(UI.Hex("bad") .. L.QUESTS_ABANDON_SURE .. "|r")
    else
        page.abandon:SetText(L.QUESTS_ABANDON)
    end
    P.Dirty()
end

local function Disarm()
    if not armed then return end
    armed = nil
    PaintAbandon()
end

local function AbandonPress()
    local q = Selected()
    if not q then return end
    if armed ~= q.questID then
        armed = q.questID
        PaintAbandon()
        local id = q.questID
        C_Timer.After(ABANDON_WAIT, function()
            if armed == id then Disarm() end
        end)
        return
    end
    armed = nil
    PaintAbandon()
    if Abandon(q) then
        readCache[q.questID] = nil
        BackToList()
    else
        ns.Print(L.QUESTS_ABANDON_FAILED)
    end
end

local function Sort(key)
    sortBy = key
    if list then list.offset = 0 end
    BuildItems()
    FillHead()
    FillList()
end

---------------------------------------------------------------------------
-- Le menu d'une quête (Y à la manette, ou un clic droit, dans la liste) :
-- toutes ses actions sans ouvrir sa fiche. C'est le menu de l'addon
-- (UI.ShowMenu, celui d'Alt+clic sur la carte), posé à gauche de la ligne de
-- la quête, sur la carte. À la manette, c'est la fenêtre du dessus
-- (Pad/Focus.lua) : la croix va de ligne en ligne, A choisit, B ou Y le
-- ferment (le contexte « questmenu », plus bas).
---------------------------------------------------------------------------
local ShowQuestMenu          -- (plus bas)

-- (la ligne d'une quête, si la liste la montre)
local function RowOf(questID)
    if not list then return end
    for _, row in ipairs(list.rows) do
        if row:IsShown() and row.item and row.item.quest and row.item.quest.questID == questID then return row end
    end
end

-- Le lien d'une quête, celui que le jeu met dans la discussion : par son
-- questID (l'API de Forever), sinon par sa place dans le journal (celle de
-- Classic) ; gardé seulement s'il désigne bien cette quête
local function QuestLink(q)
    if type(_G.GetQuestLink) ~= "function" or not q.questID then return nil end
    local mark = "quest:" .. q.questID .. "[:|]"
    local function Try(arg)
        local link = Plain(Call(_G.GetQuestLink, arg))
        if type(link) == "string" and link:find(mark) then return link end
    end
    local index = q.index
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local i = Plain(Call(C_QuestLog.GetLogIndexForQuestID, q.questID))
        if type(i) == "number" and i > 0 then index = i end
    end
    return Try(q.questID) or (index and Try(index)) or nil
end

-- Le lien dans la saisie de la discussion déjà ouverte, sinon la discussion
-- ouverte avec lui
local function LinkInChat(q)
    local link = QuestLink(q)
    if not link then return end
    local done = type(_G.ChatEdit_InsertLink) == "function" and Call(_G.ChatEdit_InsertLink, link)
    if not done and type(_G.ChatFrame_OpenChat) == "function" then Call(_G.ChatFrame_OpenChat, link) end
end

-- (une action du menu : sur la quête telle que relue au moment du choix)
local function OnQuest(questID, fn)
    return function()
        local q = Fresh(questID)
        if q then fn(q) end
    end
end

-- Le menu ouvert : à gauche de la ligne de la quête (la liste est au bord
-- droit), sinon au curseur ; à la manette, sa première ligne choisie
local function OpenMenu(items, q, row)
    local x, y = GetCursorPosition()
    menuFrame = UI.ShowMenu(items, x, y, q.title)
    if not menuFrame then return end
    if not menuFrame.questHooked then
        menuFrame.questHooked = true
        -- (notre propre cadre : fermé par un choix, un clic ailleurs, B)
        menuFrame:HookScript("OnHide", function()
            menuQuest = nil
            P.Dirty()
        end)
    end
    menuQuest = q.questID
    row = row or RowOf(q.questID)
    if row then
        menuFrame:ClearAllPoints()
        menuFrame:SetPoint("TOPRIGHT", row, "TOPLEFT", -6, 0)
    end
    if ns.PadUI() and F.SetCurrent and menuFrame.rows and menuFrame.rows[1] then F.SetCurrent(menuFrame.rows[1]) end
    P.Dirty()
end

-- Abandonner, confirmé dans le même menu : Annuler d'abord (A deux fois de
-- suite n'abandonne rien), puis « Vraiment abandonner ? » en rouge. (Le trait
-- entre les deux donne au menu les 90 px qui en font une fenêtre pour la
-- manette : Pad/Focus.lua, IsWindow.)
local function ShowAbandonMenu(q, row)
    local id = q.questID
    OpenMenu({
        { GameText("CANCEL", "HINT_BACK"), OnQuest(id, function(cur) ShowQuestMenu(cur, RowOf(id)) end) },
        { UI.Hex("bad") .. L.QUESTS_ABANDON_SURE .. "|r", OnQuest(id, function(cur)
            if Abandon(cur) then
                readCache[id] = nil
            else
                ns.Print(L.QUESTS_ABANDON_FAILED)
            end
        end), sep = true },
    }, q, row)
end

function ShowQuestMenu(q, row)
    if not q then return end
    local id = q.questID
    local pad = ns.PadUI()
    local shift = ns.MapChrome and ns.MapChrome.KeyName and ns.MapChrome.KeyName("SHIFT_KEY_TEXT", "Shift") or "Shift"
    local travel = ns.db and ns.db.options.travel
    local goal = T() and T().Goal()
    local going = goal and goal.questID == id
    local items = {}
    items[#items + 1] = { L.HINT_QUESTS_OPEN, OnQuest(id, function(cur)
        OpenQuest(cur)
        if ns.PadUI() and not focused then QP.Focus() end
    end), key = pad and "A" or nil }
    -- (l'itinéraire tout de suite, comme R3 et Maj+clic : sur la quête du
    -- trajet en cours, il l'annule)
    if travel and (q.point or going) then
        items[#items + 1] = { going and L.HINT_TRAVEL_CANCEL or L.FICHE_ROUTE, OnQuest(id, function(cur)
            Select(cur, false)
            if T() then T().AtQuest(cur.questID) end
        end), key = pad and "R3" or L.MENU_CLICK:format(shift) }
    end
    if travel and q.point then
        items[#items + 1] = { L.ACT_QUEUE, OnQuest(id, function(cur)
            Select(cur, false)
            Queue()
        end), key = pad and "X" or nil }
    end
    items[#items + 1] = { Watched(q) and L.QUESTS_UNTRACK or L.QUESTS_TRACK, OnQuest(id, function(cur)
        ToggleWatch(cur)
        FillList()
        if view == "quest" then FillPage(false) end
    end), sep = true }
    items[#items + 1] = { L.QUESTS_SHARE, OnQuest(id, Share) }
    if QuestLink(q) then items[#items + 1] = { L.QUESTS_LINK, OnQuest(id, LinkInChat) } end
    items[#items + 1] = { L.QUESTS_ABANDON .. "…", OnQuest(id, function(cur) ShowAbandonMenu(cur, RowOf(id)) end), sep = true }
    OpenMenu(items, q, row)
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
    -- (l'en-tête d'une zone : un bandeau plus clair que la liste, un trait d'or
    -- à gauche, un liseré d'or dessous ; 3 px de vide au-dessus, qui le
    -- détachent de la quête d'avant)
    row.band = row:CreateTexture(nil, "BACKGROUND")
    row.band:SetPoint("TOPLEFT", 0, -3)
    row.band:SetPoint("BOTTOMRIGHT", 0, 0)
    UI.Fade(row.band, "HORIZONTAL", "goldDim", 0.55, "headerTop", 0.9)
    row.band:Hide()
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("TOPLEFT", row.band, "TOPLEFT", 0, 0)
    row.bar:SetPoint("BOTTOMLEFT", row.band, "BOTTOMLEFT", 0, 0)
    row.bar:SetWidth(3)
    row.bar:SetColorTexture(1, 0.82, 0, 1)
    row.bar:Hide()
    row.line = row:CreateTexture(nil, "ARTWORK")
    row.line:SetPoint("BOTTOMLEFT", 0, 0)
    row.line:SetPoint("BOTTOMRIGHT", 0, 0)
    row.line:SetHeight(1)
    row.line:SetColorTexture(1, 0.82, 0, 0.6)
    row.head = UI.Text(row, "GameFontNormalLarge")
    row.head:SetPoint("LEFT", 10, -1)
    row.head:SetTextColor(1, 0.82, 0)
    row.head:SetJustifyH("LEFT")
    row.head:SetWordWrap(false)
    row.head:SetShadowOffset(1, -1)
    row.head:Hide()
    row.count = UI.Text(row, "GameFontHighlight")
    row.count:SetPoint("RIGHT", -8, -1)
    row.count:SetJustifyH("RIGHT")
    row.count:Hide()
    row.head:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
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
            ShowQuestMenu(q, self)
        elseif IsShiftKeyDown() then
            if T() then T().AtQuest(q.questID) end
        else
            OpenQuest(q)
            -- (à la manette, A au curseur sur une quête : la manette entre dans la fiche)
            if ns.PadUI() and not focused then QP.Focus() end
        end
    end)
    -- (la manette dans la liste : la croix qui arrive sur une quête la choisit,
    -- et la carte y glisse ; Pad/Focus.lua appelle OnEnter de l'élément choisi)
    row:SetScript("OnEnter", function(self)
        local it = self.item
        if not (focused and ns.PadUI() and F.Current() == self and it and it.quest) then return end
        if it.quest.questID ~= selected then Select(it.quest, true) end
    end)
    return row
end

-- Sa place : en plein écran, sous les boutons du haut, et sous la bande des
-- boutons de la manette quand elle est là (UI/MapChrome.lua : ButtonsBottom) ;
-- la carte réduite (ns.MapSmall), hors de la carte, contre son bord droit, de
-- toute sa hauteur
function QP.Place()
    if not (panel and panel.chrome) then return end
    panel:ClearAllPoints()
    if ns.MapSmall() then
        panel:SetPoint("TOPLEFT", panel.chrome, "TOPRIGHT", 4, 0)
        panel:SetPoint("BOTTOMLEFT", panel.chrome, "BOTTOMRIGHT", 4, 0)
        return
    end
    local top = TOP
    if ns.MapChrome and ns.MapChrome.ButtonsBottom then top = math.max(TOP, ns.MapChrome.ButtonsBottom() + 6) end
    panel:SetPoint("TOPRIGHT", panel.chrome, "TOPRIGHT", -EDGE, -top)
    panel:SetPoint("BOTTOMRIGHT", panel.chrome, "BOTTOMRIGHT", -EDGE, BOTTOM)
end

local function Build(chrome)
    if panel then return end
    panel = UI.Overlay(chrome)
    -- (sur la carte du jeu, pas sur la vue : la vue coupe ce qui dépasse, et la
    -- carte réduite pose la liste dehors ; la strate et le niveau de l'habillage)
    local host = _G.WorldMapFrame
    if host then panel:SetParent(host) end
    local strata = ns.Map.View.Strata()
    if strata then panel:SetFrameStrata(strata) end
    panel:SetWidth(WIDTH)
    panel.chrome = chrome
    panel:EnableMouse(true)
    panel:SetFrameLevel(chrome:GetFrameLevel() + 20)
    -- (l'en-tête : le titre, le nombre, le tri ; RT, la manette y entre)
    local title = UI.Text(panel, "GameFontNormalLarge", L.QUESTS_TITLE)
    panel.title = title
    title:SetPoint("TOPLEFT", 12, -12)
    panel.count = UI.DimText(panel, nil, "GameFontHighlightSmall")
    panel.count:SetPoint("LEFT", title, "RIGHT", 8, -1)
    panel.rt = UI.CreateGlyph(panel, 16)
    panel.rt:SetPoint("TOPRIGHT", -12, -13)
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
    list:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    list:EnableMouseWheel(true)
    list.rows, list.offset = {}, 0
    function list:SetOffset(o)
        self.offset = math.max(0, o)
        FillList()     -- (qui le ramène dans les bornes)
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
    -- (la fiche d'une quête, à la place de la liste : Retour, le titre, la
    -- zone et le temps depuis toi ; ce qui défile ; les boutons du bas)
    page = CreateFrame("Frame", nil, panel)
    page:SetAllPoints(panel)
    page:Hide()
    page.back = Button(page, L.HINT_BACK, 110, 22, "grey", "PAD2")
    page.back:SetPoint("TOPLEFT", 10, -10)
    page.back:SetScript("OnClick", function() BackToList() end)
    -- (Abandonner, en haut à droite, loin des autres boutons : deux appuis)
    page.abandon = Button(page, L.QUESTS_ABANDON, 160, 22, "grey", "PADBACK")
    page.abandon:SetPoint("TOPRIGHT", -12, -10)
    page.abandon:SetScript("OnClick", function() AbandonPress() end)
    page.level = UI.Text(page, "GameFontHighlightSmall")
    page.level:SetPoint("TOPRIGHT", -12, -44)
    page.title = UI.Text(page, "GameFontNormalLarge")
    page.title:SetPoint("TOPLEFT", 12, -40)
    page.title:SetPoint("RIGHT", page.level, "LEFT", -8, 0)
    page.title:SetJustifyH("LEFT")
    page.title:SetWordWrap(false)
    page.zone = UI.DimText(page, nil, "GameFontHighlightSmall")
    page.zone:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -4)
    page.from = UI.Text(page, "GameFontHighlightSmall")
    page.from:SetPoint("TOPLEFT", page.zone, "BOTTOMLEFT", 0, -3)
    page.from:SetPoint("RIGHT", page, "RIGHT", -12, 0)
    page.from:SetJustifyH("LEFT")
    page.from:SetWordWrap(false)
    page.scroll = UI.Scroll(page, nil, 40)
    page.scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
    page.scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -22, 78)
    page.child = page.scroll.child
    page.child:SetWidth(PAGE_W)
    page.colW = math.floor((PAGE_W - 6) / 2)
    page.heads, page.labels, page.items = {}, {}, {}
    for i = 1, 3 do
        local fs = UI.Text(page.child, "GameFontNormalLarge")
        local line = page.child:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 0.82, 0, 0.25)
        line:SetHeight(1)
        line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
        page.heads[i] = { fs = fs, line = line }
    end
    local function Paragraph(font)
        local fs = UI.Text(page.child, font)
        fs:SetWidth(PAGE_W)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(true)
        if fs.SetSpacing then fs:SetSpacing(2) end
        return fs
    end
    page.summary = Paragraph("GameFontHighlight")
    page.objs = Paragraph("GameFontHighlightSmall")
    page.story = Paragraph("GameFontHighlight")
    page.money = Paragraph("GameFontHighlight")
    local half = math.floor((WIDTH - 24 - 6) / 2)
    page.route = Button(page, L.FICHE_ROUTE, half, 28, nil, "PAD4")
    page.route:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 12, 42)
    page.route:SetScript("OnClick", Route)
    -- (à la manette, la file depuis la liste : View ; X ne fait que la taille de la carte)
    page.queue = Button(page, L.ACT_QUEUE, half, 28, "grey")
    page.queue:SetPoint("LEFT", page.route, "RIGHT", 6, 0)
    page.queue:SetScript("OnClick", Queue)
    page.track = Button(page, L.QUESTS_TRACK, half, 24, "grey", "PAD1")
    page.track:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 12, 12)
    page.track:SetScript("OnClick", function()
        local q = Selected()
        if q then
            ToggleWatch(q)
            FillPage(false)
        end
    end)
    page.share = Button(page, L.QUESTS_SHARE, half, 24, "grey", "PADLTRIGGER")
    page.share:SetPoint("LEFT", page.track, "RIGHT", 6, 0)
    page.share:SetScript("OnClick", function()
        local q = Selected()
        if q then Share(q) end
    end)
    -- (à la manette, ses boutons se pressent par leurs pastilles : la croix
    -- fait défiler la fiche et va de récompense en récompense)
    page.actions = { page.route, page.queue, page.track, page.share, page.abandon }
    page.back.noGamepad = true
    page.scroll.bar.noGamepad = true
    for _, b in ipairs(page.actions) do b.noGamepad = true end
    QP.Place()
    panel:Hide()
    panel.padPassive = true    -- (au repos tant que Menu n'y entre pas)
    ns.Map.Cursor.AddRoot(panel)
    F.RegisterWindow(panel, {
        onBack = function() QP.Blur() end,
        first = function()
            -- (dans la fiche, rien n'est choisi d'avance : la croix fait défiler)
            if view ~= "list" then return nil end
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

-- La liste est toujours là, carte plein écran ou réduite : elle s'affiche
-- avec la carte, et seule la carte qui se ferme la cache
function QP.Show()
    if not (panel and ns.FullMap() and ns.MapShown()) or panel:IsShown() then return end
    QP.Place()
    panel:Show()
    QP.Refresh()
    local q = Selected()
    if q then ShowOnMap(q) end
    P.Dirty()
end

function QP.Hide()
    if not panel then return end
    CloseQuestMenu()
    SetFocused(false)
    if not panel:IsShown() then return end
    -- (rouvert, le panneau montre la liste)
    if view ~= "list" then ShowView("list") end
    panel:Hide()
    ns.Map.View.QuestArea(nil)
    P.Dirty()
end

function QP.Shown() return panel and panel:IsShown() or false end
function QP.MouseOver() return panel and panel:IsVisible() and panel:IsMouseOver() or false end

-- La manette dans le panneau, ou pas : affiché avec la carte, il reste au
-- repos (la carte garde la manette et son curseur ; Pad/Focus.lua :
-- padPassive) ; RT y entre, B en ressort
-- (la manette sort de la liste : nos raccourcis ôtés, la manette revient au
-- jeu ; sa croix gauche, « Carte », redonne le curseur à la carte. L'addon ne
-- le fait pas lui-même : voir plus bas, la manette n'est jamais donnée à la
-- carte par l'addon)
function SetFocused(on)
    focused = on and true or false
    if panel then panel.padPassive = not focused end
    P.Dirty()
end

function QP.Focus() if QP.Shown() then SetFocused(true) end end
function QP.Blur() SetFocused(false) end
function QP.Focused() return QP.Shown() and focused end

-- RT à la manette (Pad/MapNav.lua) : la manette entre dans la liste (plus de
-- curseur : la croix va de quête en quête) ; dedans, elle revient à la carte.
-- La liste reste affichée.
function QP.PadMenu()
    QP.Show()
    if focused then QP.Blur() else QP.Focus() end
end

-- Le journal du jeu ouvert par un geste du joueur (sa croix droite, son
-- bouton, L) : la manette va dans notre liste, comme le jeu la donne à son
-- journal
local function ShowFromGame()
    QP.Show()
    if ns.PadUI() then QP.Focus() end
end

local function AfterSidePanel()
    if ns.FullMap() and ns.MapShown() and SidePanelShown() then ShowFromGame() end
end

local function OnLogShow()
    if not (ns.FullMap() and ns.MapShown()) then return end
    -- (rouvert avec la carte, d'après l'état gardé du jeu, sans geste du joueur : rien)
    if GetTime() - openedAt < OPEN_QUIET and GetTime() - userAt > OPEN_QUIET then return end
    ShowFromGame()
end

local function Hook()
    local map = Map()
    if not map or QP.hooked then return end
    QP.hooked = true
    map:HookScript("OnShow", function() openedAt = GetTime() end)
    if type(_G.ToggleQuestLog) == "function" then
        hooksecurefunc("ToggleQuestLog", function() userAt = GetTime() end)
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
    end
end

-- La carte plein écran s'ouvre sans le journal du jeu. Le jeu ouvre sa carte
-- comme le dit son réglage questLogOpen (Map/Window.lua) ; journal ouvert, il
-- y met la manette, cachée sous la carte plein écran, et la carte n'a pas son
-- curseur avant un appui sur la croix. Nos quêtes le remplacent : le réglage
-- est remis à « fermé » (seulement lui : rien d'écrit dans les cadres du jeu),
-- carte fermée et hors combat.
local function KeepGameLogClosed()
    if not ns.FullMap() or InCombatLockdown() or ns.MapShown() then return end
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if not (get and set) then return end
    local ok, now = pcall(get, "questLogOpen")
    if ok and now ~= nil and now ~= "0" then pcall(set, "questLogOpen", "0") end
end

ns.On("READY", function()
    if _G.WorldMapFrame then
        Hook()
    elseif EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Hook)
    end
    C_Timer.After(1, KeepGameLogClosed)
    -- (les anciennes mémoires des quêtes affichées ou non : la liste est
    -- désormais toujours là)
    if ns.db and ns.db.options then
        ns.db.options.questsOpen = nil
        ns.db.options.questsShown = nil
    end
end)
-- La manette n'est jamais donnée à la carte par l'addon. Appeler la fonction
-- FocusMap de la carte du jeu (à son ouverture, à la sortie de notre liste)
-- faisait écrire à l'interface manette son état de focus depuis le code de
-- l'addon : ensuite, le jeu se croyait contaminé chaque fois qu'il le
-- relisait (l'ouverture de la carte, un changement de focus) et bloquait
-- SetPreferredGamepadInteractTarget, jusqu'au /reload (taint.log). Le curseur
-- vient de la croix gauche du jeu (« Carte »), comme dans le jeu.

ns.On("MAP_CHROME", Build)
ns.On("MAP_HIDE", function()
    QP.Hide()
    C_Timer.After(0, KeepGameLogClosed)
end)
ns.On("MAP_SHOW", function() C_Timer.After(0.1, QP.Show) end)
-- (plein écran ou réduite : la liste change de place)
ns.On("MAP_SIZE", function()
    if not (panel and ns.MapShown()) then return end
    QP.Place()
    QP.Show()
end)

-- (le journal change : la liste suit, un peu plus tard)
local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
local pending = false
events:SetScript("OnEvent", function(_, event)
    -- (la carte fermée pendant un combat : le journal du jeu remis à « fermé » après)
    if event == "PLAYER_REGEN_ENABLED" then
        KeepGameLogClosed()
        return
    end
    if pending or not QP.Shown() then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        QP.Refresh()
    end)
end)

---------------------------------------------------------------------------
-- La manette dans la liste : la croix (la carte glisse jusqu'à la quête), A
-- sa fiche, Y le menu de la quête, R3 l'itinéraire tout de suite, X la
-- file, LT le tri ; B, RT ou la croix gauche reviennent à la carte
---------------------------------------------------------------------------
local function Current()
    local f = F.Current and F.Current()
    if f and f.item and f.item.quest then return f.item.quest end
end

-- La croix (ou le stick) haut / bas dans la liste : de quête en quête, en
-- sautant les en-têtes de zone. La quête voisine hors de vue, la liste défile
-- jusqu'à elle, au lieu que la croix saute à la recherche ou aux boutons du
-- dessus (les plus proches à l'écran). Seulement depuis la toute première
-- quête, elle sort de la liste vers le haut.
local function ListStep(dy)
    local cur = F.Current and F.Current()
    local at
    if cur and cur.item and list and cur:GetParent() == list then
        for i, row in ipairs(list.rows) do
            if row == cur then at = list.offset + i end
        end
    end
    if not at then return F.Move(0, dy) end
    local k = at - dy
    while items[k] and not items[k].quest do k = k - dy end
    if not items[k] then
        -- (au bout de la liste : vers le haut, la recherche ; vers le bas, rien)
        if dy > 0 then F.Move(0, dy) end
        return
    end
    local i = k - list.offset
    if i < 1 then list:SetOffset(k - 1) elseif i > #list.rows then list:SetOffset(k - #list.rows) end
    local row = list.rows[k - list.offset]
    if not (row and row:IsShown()) then return end
    if row == cur then
        -- (la même ligne, une autre quête dedans : elle se choisit de nouveau)
        local onEnter = row:GetScript("OnEnter")
        if onEnter then pcall(onEnter, row) end
    else
        F.SetCurrent(row)
    end
end

-- (pas le contexte des fenêtres comme base : B y a son propre sens, revenir à la carte)
P.DefineContext("quests", 52.5, function() return QP.Focused() and F.Top() == panel and view == "list" end)
P.SetAction("quests", "PADDUP", function() ListStep(1) end)
P.SetAction("quests", "PADDDOWN", function() ListStep(-1) end)
-- (la liste est à droite de la carte, plein écran ou réduite : la croix gauche
-- n'est pas prise, elle reste au jeu, qui donne d'un seul appui son curseur à
-- la carte ; la liste le voit et rend la manette, plus bas : logWatch)
P.SetAction("quests", "PADDRIGHT", function() F.Move(1, 0) end, "HINT_MOVE")
P.SetAction("quests", "PAD1", function()
    local q = Current()
    if q then OpenQuest(q) else F.Activate("LeftButton") end
end, "HINT_QUESTS_OPEN")
-- (Y : le menu de la quête, à gauche de sa ligne)
P.SetAction("quests", "PAD4", function()
    local q = Current()
    if not q then return end
    Select(q, false)
    ShowQuestMenu(q, F.Current())
end, "HINT_QUESTS_MENU")
-- (R3 : l'itinéraire tout de suite, sans aperçu, comme R3 sur la carte et
-- Maj+clic ; R3 sur la quête du trajet en cours l'annule)
P.SetAction("quests", "PADRSTICK", function()
    local q = Current()
    if not q then return end
    Select(q, false)
    if T() then T().AtQuest(q.questID) end
end, function()
    if not (ns.db and ns.db.options.travel) then return nil end
    local q = Current()
    if not q then return nil end
    local goal = T() and T().Goal()
    if goal and goal.questID == q.questID then return "HINT_TRAVEL_CANCEL" end
    return "HINT_TRAVEL_QUEST"
end)
-- (View : la quête dans la file ; X : la taille de la carte, rien d'autre)
P.SetAction("quests", "PADBACK", function()
    local q = Current()
    if q then Select(q, false) end
    Queue()
end, "ACT_QUEUE")
P.SetAction("quests", "PAD3", ns.PadMapSize, ns.PadMapSizeHint)
-- (LT : le tri, par zone ou les plus proches ; RT : revenir à la carte, comme
-- B ; la liste reste)
P.SetAction("quests", "PADLTRIGGER", function() Sort(sortBy == "zone" and "dist" or "zone") end, "HINT_QUESTS_SORT")
P.SetAction("quests", "PADRTRIGGER", function() QP.PadMenu() end, "HINT_BACK_MAP")
P.SetAction("quests", "PAD2", function() QP.Blur() end, "HINT_BACK_MAP")
F.WINDOW_CONTEXTS.quests = true

-- Le menu d'une quête ouvert : la croix et A, ceux des fenêtres ; B ou Y le
-- ferment (la manette revient sur la quête, Pad/Focus.lua s'en souvient)
P.DefineContext("questmenu", 52.7, function()
    return menuQuest ~= nil and menuFrame ~= nil and UI.MenuShown() and F.Top() == menuFrame
end, "window")
P.SetAction("questmenu", "PAD2", function() CloseQuestMenu() end, "HINT_MENU_CLOSE")
P.SetAction("questmenu", "PAD4", function() CloseQuestMenu() end)
-- (pas de clic droit dans un menu ; X : le menu fermé, la taille de la carte)
P.SetAction("questmenu", "PAD3", function()
    CloseQuestMenu()
    ns.PadMapSize()
end, ns.PadMapSizeHint)
F.WINDOW_CONTEXTS.questmenu = true

---------------------------------------------------------------------------
-- La manette dans la fiche : la croix haut / bas fait défiler, gauche /
-- droite va de récompense en récompense ; A suivre, Y l'itinéraire, X la
-- file, LT partager, View abandonner (deux fois), RT revient à la carte ; B
-- revient à la liste
---------------------------------------------------------------------------
local function Act(fn)
    return function()
        local q = Selected()
        if q then fn(q) end
    end
end

P.DefineContext("questpage", 52.6, function() return QP.Focused() and F.Top() == panel and view == "quest" end)
P.SetAction("questpage", "PADDUP", function() PageScroll(-1) end)
P.SetAction("questpage", "PADDDOWN", function() PageScroll(1) end, "HINT_SCROLL")
P.SetAction("questpage", "PADDLEFT", function() PageReward(-1) end)
P.SetAction("questpage", "PADDRIGHT", function() PageReward(1) end, function()
    return (page and #ShownRewards() > 0) and "HINT_REWARDS" or nil
end)
P.SetAction("questpage", "PAD1", Act(function(q)
    ToggleWatch(q)
    FillPage(false)
end), function()
    local q = Selected()
    return (q and Watched(q)) and "QUESTS_UNTRACK" or "QUESTS_TRACK"
end)
P.SetAction("questpage", "PAD4", function() Route() end, "FICHE_ROUTE")
P.SetAction("questpage", "PAD3", ns.PadMapSize, ns.PadMapSizeHint)
P.SetAction("questpage", "PADLTRIGGER", Act(Share), "QUESTS_SHARE")
P.SetAction("questpage", "PADBACK", function() AbandonPress() end, function()
    local q = Selected()
    return (q and armed == q.questID) and "QUESTS_ABANDON_SURE" or "QUESTS_ABANDON"
end)
P.SetAction("questpage", "PADRTRIGGER", function() QP.PadMenu() end, "HINT_BACK_MAP")
P.SetAction("questpage", "PAD2", function() BackToList() end, "HINT_QUESTS_LIST")
F.WINDOW_CONTEXTS.questpage = true

---------------------------------------------------------------------------
-- La carte plein écran sans son curseur : le personnage ne bouge pas
--
-- Depuis que l'addon ne donne plus la manette à la carte du jeu (plus haut),
-- la carte plein écran s'ouvre sans curseur : le jeu met la manette dans son
-- journal, caché sous la nôtre, et le stick gauche faisait marcher le
-- personnage derrière la carte. Sur la carte plein écran, le joueur a donc
-- toujours l'un des deux :
-- - le curseur de la carte (la croix gauche du jeu, « Carte ») ;
-- - sinon, notre liste des quêtes : la manette y entre à l'ouverture, et le
--   stick gauche y va de quête en quête comme la croix (dans la fiche, il la
--   fait défiler).
-- Sorti de la liste (B, RT, la croix gauche) sans le curseur, le stick y
-- ramène, RT aussi, et la croix gauche du jeu donne le curseur.
-- Le stick est gardé par un cadre de l'addon (EnableGamePadStick, comme la
-- roue des actions : UI/ActionBar.lua) : il ne va plus au jeu, et il est lu
-- sur la manette (ns.Map.Cursor.Stick). Jamais les boutons. Seulement hors
-- combat : en combat, le stick revient au personnage. La carte réduite le
-- laisse au personnage, comme la carte en fenêtre du jeu.
---------------------------------------------------------------------------
local STICK_ON = 0.5         -- l'inclinaison du stick qui compte comme un appui
local STICK_OFF = 0.3        -- ... et sous laquelle il est relâché
local STICK_DELAY = 0.35     -- s : le stick tenu se répète après...
local STICK_EVERY = 0.12     -- s : ... puis à ce rythme (plus vite tout incliné)
local FOCUS_AT = { 0.15, 0.45 }  -- s après l'ouverture : la manette dans la liste, si la carte n'a pas son curseur

local function FullScreen()
    return ns.FullMap() and ns.MapShown() and not ns.MapSmall()
end

-- La carte du jeu a-t-elle la manette (son curseur) ? Ce que le jeu en dit
-- (IsCanvasGamepadFocus), sans attendre que le curseur s'affiche : le stick
-- doit lui revenir aussitôt, c'est lui qui fait paraître le curseur
local function CanvasHasPad()
    local map = Map()
    if map and map.IsCanvasGamepadFocus then
        local ok, on = pcall(map.IsCanvasGamepadFocus, map)
        return ok and on and true or false
    end
    return ns.MapNav and ns.MapNav.CursorOnMap() or false
end

-- La liste peut-elle prendre la manette : aucune autre fenêtre de l'addon ne
-- l'a (seulement la carte seule, le journal du jeu caché, ou rien)
local function Free()
    local current = P.current
    if current and current ~= "map" and current ~= "questlog" and current ~= "mapidle" then return false end
    return F.Top() == nil
end

local keeper = CreateFrame("Frame", nil, UIParent)
keeper:SetSize(1, 1)
keeper:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
keeper:SetFrameStrata("FULLSCREEN_DIALOG")
-- (les sticks reçus : rien à en faire, ils ne vont simplement pas au jeu)
pcall(keeper.SetScript, keeper, "OnGamePadStick", function() end)
keeper:Hide()
local keeping = false

local function Keep(on)
    on = on and true or false
    if on == keeping or not keeper.EnableGamePadStick then return end
    if on and InCombatLockdown() then return end
    keeping = on
    if on then keeper:Show() end
    pcall(keeper.EnableGamePadStick, keeper, on)
    if not on then keeper:Hide() end
end

local function WantKeep()
    if not (ns.db and ns.db.options.enabled) or InCombatLockdown() then return false end
    if not (FullScreen() and ns.PadUI()) then return false end
    return not CanvasHasPad()
end

-- Le stick gauche lu : -1 (bas), 0, 1 (haut), et son inclinaison
local stickDir, stickWait = 0, 0
local function StickY()
    local _, y = ns.Map.Cursor.Stick()
    if type(y) ~= "number" then return 0, 0 end
    local a = math.abs(y)
    local limit = stickDir ~= 0 and STICK_OFF or STICK_ON
    if a < limit then return 0, a end
    return y > 0 and 1 or -1, a
end

-- Un « appui » du stick : dans la liste, la quête d'au-dessus ou d'en
-- dessous ; dans le menu d'une quête, la ligne d'au-dessus ou d'en dessous ;
-- dans la fiche, elle défile ; hors de la liste, il y ramène
local function StickStep(dir)
    if QP.Focused() then
        if menuQuest and menuFrame and F.Top() == menuFrame then
            F.Move(0, dir)
            P.Dirty()
            return
        end
        if F.Top() ~= panel then return end
        if view == "list" then ListStep(dir) else PageScroll(-dir) end
        P.Dirty()
    elseif QP.Shown() and Free() then
        QP.Focus()
    end
end

local stickDriver = CreateFrame("Frame")
stickDriver:Hide()
stickDriver:SetScript("OnUpdate", function(_, elapsed)
    local want = WantKeep()
    Keep(want)
    if not want then
        stickDir = 0
        return
    end
    local dir, tilt = StickY()
    if dir == 0 then
        stickDir = 0
        return
    end
    if dir ~= stickDir then
        stickDir, stickWait = dir, STICK_DELAY
        StickStep(dir)
        return
    end
    stickWait = stickWait - elapsed
    if stickWait <= 0 then
        -- (tout incliné, deux fois plus vite)
        stickWait = STICK_EVERY * (1.5 - math.min(1, tilt) * 0.75)
        StickStep(dir)
    end
end)

-- La manette dans la liste à l'ouverture de la carte plein écran, si le jeu
-- n'a pas donné le curseur à la carte (deux essais : le jeu place sa manette
-- pendant l'ouverture, parfois un peu après)
local function FocusAtOpen()
    if focused or not (FullScreen() and ns.PadUI()) or InCombatLockdown() then return end
    if not QP.Shown() then QP.Show() end
    if not QP.Shown() or CanvasHasPad() or not Free() then return end
    QP.Focus()
end

-- La navigation de l'interface manette du jeu (SmartNavigation) peut entrer
-- dans nos lignes (elles sont sur la carte du jeu) ou dans son journal, caché
-- sous notre liste : surtout sur la carte réduite, qui laisse la manette au
-- jeu. Elle ne sait pas faire défiler notre liste et s'arrête à sa dernière
-- ligne visible. Dès que son focus y arrive, la manette passe dans notre
-- liste, qui défile. Sortie de la liste (B, la croix gauche), elle n'y est
-- reprise que si le jeu y déplace de nouveau son focus.
local function Within(f, frame)
    for _ = 1, 15 do
        if not f then return false end
        if f == frame then return true end
        f = f.GetParent and f:GetParent()
    end
    return false
end
local gameButton, watchWait = nil, 0
local logWatch = CreateFrame("Frame")
logWatch:Hide()
logWatch:SetScript("OnUpdate", function(_, elapsed)
    watchWait = watchWait - elapsed
    if watchWait > 0 then return end
    watchWait = 0.2
    -- (le curseur donné à la carte, la croix gauche du jeu : la liste rend la manette)
    if focused and view == "list" and CanvasHasPad() then
        QP.Blur()
        return
    end
    local nav = _G.SmartNavigation
    if not (nav and type(nav.GetCurrentButton) == "function") then return end
    local ok, button = pcall(nav.GetCurrentButton, nav)
    if not ok or type(button) ~= "table" or type(button.GetParent) ~= "function" then button = nil end
    if button == gameButton then return end
    gameButton = button
    if not button or focused or InCombatLockdown() or not ns.PadUI() then return end
    if not (panel and QP.Shown() and view == "list" and Free()) then return end
    local inPanel = Within(button, panel)
    if not (inPanel or Within(button, _G.QuestMapFrame)) then return end
    QP.Focus()
    -- (sur l'une de nos lignes : la manette reste sur celle-là)
    if inPanel and button.item and F.SetCurrent then F.SetCurrent(button) end
end)

ns.On("MAP_SHOW", function()
    stickDir = 0
    stickDriver:Show()
    gameButton, watchWait = nil, 0
    logWatch:Show()
    for _, t in ipairs(FOCUS_AT) do C_Timer.After(t, FocusAtOpen) end
end)
ns.On("MAP_HIDE", function()
    stickDriver:Hide()
    logWatch:Hide()
    Keep(false)
end)
-- (passée en plein écran : comme à l'ouverture)
ns.On("MAP_SIZE", function()
    if ns.MapShown() and not ns.MapSmall() then C_Timer.After(0.15, FocusAtOpen) end
end)

local keepEvents = CreateFrame("Frame")
keepEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
keepEvents:SetScript("OnEvent", function()
    -- (le combat commence : le stick rendu au personnage tant qu'on le peut encore)
    Keep(false)
end)

-- Sorti de la liste, sans le curseur de la carte : la barre d'aide dit
-- comment revenir à l'une ou à l'autre. Aucun raccourci posé (la croix
-- gauche et B restent au jeu) ; RT est lu sur la manette, comme sur la carte
-- seule (Pad/MapNav.lua)
P.DefineContext("mapidle", 15, function()
    if not (FullScreen() and QP.Shown()) or focused then return false end
    return not (ns.MapNav and ns.MapNav.CanvasFocus())
end, nil, "read")
P.SetPassive("mapidle", "PADDLEFT", "HINT_BACK_MAP")
P.SetAction("mapidle", "PADRTRIGGER", function() QP.Focus() end, "HINT_QUESTS")
P.SetPassive("mapidle", "PAD2", "HINT_CLOSE_MAP")
P.SetAction("mapidle", "PAD3", ns.PadMapSize, ns.PadMapSizeHint)
