-- Les boutons de la quête choisie, à l'écran (réglage questButtons, les
-- détails du calque Quêtes) :
--   - l'objet de quête : celui que le journal donne à utiliser (une torche,
--     une fiole...) ; un clic, ou son raccourci, l'utilise ;
--   - la cible : un clic, ou son raccourci, cible le monstre (ou le PNJ) de son
--     objectif en cours (/targetexact, son nom dans ta langue d'après la base
--     des quêtes) ; il n'attaque pas.
-- La quête choisie : celle de l'itinéraire en cours, sinon celle que le jeu
-- suit en premier (SuperTrack), sinon la première suivie ; sans objet ou sans
-- cible, la première quête du journal qui en a.
-- Ce sont des boutons protégés (SecureActionButtonTemplate) : créés, changés,
-- montrés ou cachés hors combat seulement ; un changement pendant un combat
-- attend PLAYER_REGEN_ENABLED. Maj+glisser les déplace (hors combat).
-- Leurs raccourcis : Raccourcis > My Map Is Rich (Bindings.xml : CLICK), à la
-- manette aussi par la liste des raccourcis du jeu.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local QB = {}
ns.QuestButtons = QB

ns.Map.Settings.Own("questButtons", true)

local SIZE = 36
local GAP = 4
local TARGET_ICON = "Interface\\Icons\\Ability_Hunter_SniperShot"

local frame, item, target
local pending = false
local shown = { item = nil, target = nil }

_G["BINDING_NAME_CLICK MyMapIsRichQuestItem:LeftButton"] = L.BINDING_QUEST_ITEM
_G["BINDING_NAME_CLICK MyMapIsRichQuestTarget:LeftButton"] = L.BINDING_QUEST_TARGET

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

local function On()
    return ns.db and ns.Map.Settings.Get("questButtons") ~= false and not (ns.Conflict and ns.Conflict())
end

---------------------------------------------------------------------------
-- La quête choisie, son objet, sa cible
---------------------------------------------------------------------------
local function Watched(id, q)
    if C_QuestLog and C_QuestLog.IsQuestWatched then return Call(C_QuestLog.IsQuestWatched, id) and true or false end
    return q.index and Call(_G.IsQuestWatched, q.index) and true or false
end

-- Les quêtes du journal, la choisie d'abord
local function Ordered()
    local Log = ns.Quests.Log
    local quests = Log.Quests()
    local first
    local goal = ns.Travel and ns.Travel.Goal()
    if goal and goal.questID and quests[goal.questID] then first = goal.questID end
    if not first and C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local id = Plain(Call(C_SuperTrack.GetSuperTrackedQuestID))
        if id and quests[id] then first = id end
    end
    local list = {}
    if first then list[1] = first end
    local watched, others = {}, {}
    for id, q in pairs(quests) do
        if id ~= first then
            if Watched(id, q) then watched[#watched + 1] = id else others[#others + 1] = id end
        end
    end
    table.sort(watched)
    table.sort(others)
    for _, id in ipairs(watched) do list[#list + 1] = id end
    for _, id in ipairs(others) do list[#list + 1] = id end
    return list
end

-- L'objet de quête à utiliser : { link, icon, quest }
local function FindItem(list)
    local get = _G.GetQuestLogSpecialItemInfo
    if not get then return end
    for _, id in ipairs(list) do
        local index = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and Plain(Call(C_QuestLog.GetLogIndexForQuestID, id))
        index = index or (ns.Quests.Log.Quests()[id] or {}).index
        if index then
            local link, icon = Call(get, index)
            link, icon = Plain(link), Plain(icon)
            if type(link) == "string" then return { link = link, icon = icon, quest = id } end
        end
    end
end

-- Le monstre ou le PNJ à cibler : { name, quest, text } (un objectif pas fini, d'un PNJ que la base nomme)
local function FindTarget(list)
    local Log, Db = ns.Quests.Log, ns.Quests.Db
    for _, id in ipairs(list) do
        for _, o in ipairs(Log.Goals(id)) do
            if not o.finished then
                for _, ref in ipairs(o.refs or {}) do
                    local name = ref > 0 and Db.Name(ref)
                    if name then return { name = name, quest = id, text = o.text } end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Les boutons
---------------------------------------------------------------------------
local function SavePosition()
    local point, _, rel, x, y = frame:GetPoint(1)
    ns.db.options.questButtonsPos = { point, rel, x, y }
end

local function Drag(b)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function()
        if IsShiftKeyDown() and not InCombatLockdown() then frame:StartMoving() end
    end)
    b:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition()
    end)
end

-- (une case d'action protégée : UI/Widgets.lua)
local function Button(name, icon, cooldown)
    local b = UI.ActionSlot(frame, SIZE, name, true, cooldown)
    if icon then b.icon:SetTexture(icon) end
    Drag(b)
    return b
end

local function Build()
    if frame or InCombatLockdown() then return frame end
    frame = CreateFrame("Frame", "MyMapIsRichQuestButtons", UIParent)
    frame:SetSize(SIZE * 2 + GAP, SIZE)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    local pos = ns.db.options.questButtonsPos
    if type(pos) == "table" and pos[1] then
        frame:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -190)
    end
    item = Button("MyMapIsRichQuestItem", nil, true)
    item:SetPoint("LEFT", frame, "LEFT", 0, 0)
    item:SetAttribute("type", "item")

    item:SetScript("OnEnter", function(self)
        if not shown.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        pcall(GameTooltip.SetHyperlink, GameTooltip, shown.item.link)
        GameTooltip:AddLine(L.QUESTBTN_ITEM_TIP:format(ns.Quests.Db.Title(shown.item.quest)), 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine(L.QUESTBTN_MOVE, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    target = Button("MyMapIsRichQuestTarget", TARGET_ICON)
    target:SetPoint("LEFT", item, "RIGHT", GAP, 0)
    target:SetAttribute("type", "macro")
    target:SetScript("OnEnter", function(self)
        if not shown.target then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.QUESTBTN_TARGET:format(shown.target.name), 1, 0.82, 0)
        GameTooltip:AddLine(ns.Quests.Db.Title(shown.target.quest), 1, 1, 1)
        if shown.target.text then GameTooltip:AddLine(shown.target.text, 0.8, 0.8, 0.8, true) end
        GameTooltip:AddLine(L.QUESTBTN_MOVE, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    frame:Hide()
    return frame
end

local function Cooldown()
    if not (item and shown.item) then return end
    local id = tonumber(shown.item.link:match("item:(%d+)"))
    local get = C_Container and C_Container.GetItemCooldown or _G.GetItemCooldown
    if not (id and get) then return end
    local ok, start, duration, enable = pcall(get, id)
    start, duration = ok and Plain(start), ok and Plain(duration)
    if start and duration and duration > 0 and enable ~= 0 then
        item.cooldown:SetCooldown(start, duration)
    elseif item.cooldown.Clear then
        item.cooldown:Clear()
    else
        item.cooldown:SetCooldown(0, 0)
    end

end

-- Tout remis à jour (hors combat ; pendant un combat : à sa fin)
function QB.Refresh()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    if not On() or not ns.Quests.Db.Has() then
        if frame then frame:Hide() end
        return
    end
    if not Build() then return end
    local list = Ordered()
    local it, tg = FindItem(list), FindTarget(list)
    shown.item, shown.target = it, tg
    -- (« item:numéro » : ce que l'action « item » d'un bouton protégé lit sûrement)
    local itemID = it and tonumber(it.link:match("item:(%d+)"))
    item:SetAttribute("item", itemID and ("item:" .. itemID) or nil)
    item.icon:SetTexture(it and it.icon or nil)
    item:SetShown(it ~= nil)
    target:SetAttribute("macrotext", tg and ("/targetexact " .. tg.name) or nil)
    target:SetShown(tg ~= nil)
    target:ClearAllPoints()
    if it then target:SetPoint("LEFT", item, "RIGHT", GAP, 0) else target:SetPoint("LEFT", frame, "LEFT", 0, 0) end
    frame:SetShown(it ~= nil or tg ~= nil)
    Cooldown()
end

local wait = false
local function Soon()
    if wait then return end
    wait = true
    C_Timer.After(0.3, function()
        wait = false
        local ok, err = pcall(QB.Refresh)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end)
end

ns.On("QUESTS_CHANGED", Soon)
ns.On("TRAVEL", Soon)
ns.On("MAP_REFRESH", Soon)
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then Soon() end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        if not InCombatLockdown() or item then pcall(Cooldown) end
    else
        Soon()
    end
end)
for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "SUPER_TRACKING_CHANGED", "QUEST_WATCH_LIST_CHANGED", "BAG_UPDATE_COOLDOWN",
    "PLAYER_ENTERING_WORLD" }) do
    pcall(events.RegisterEvent, events, e)
end
