-- Ton journal de quêtes, lu une fois pour tout l'addon (la liste des quêtes,
-- UI/QuestPanel.lua, et les marqueurs, Layers/QuestMarks.lua), et relié à la
-- base des quêtes (Quests/Db.lua) :
--   Log.NumEntries(), Log.InfoAt(i)     les lignes du journal (l'API moderne, sinon celle de Classic)
--   Log.Objectives(questID, index)      ses objectifs : { text, finished, type, have, need }
--   Log.Quests()                        les quêtes du journal : questID -> { id, index, title, level, complete }
--   Log.Goals(questID)                  ses objectifs reliés à la base : chacun avec refs (les PNJ > 0
--                                       et objets < 0 à viser), item (l'objet à trouver) ou explore
--                                       (un lieu à explorer)
--   Log.Done(questID)                   la quête est-elle déjà faite (rendue) ?
-- Un objectif du jeu se relie d'abord par le nom (son texte, dans ta langue,
-- dit celui du monstre ou de l'objet), sinon dans l'ordre de la base, par sorte.
-- Le journal change par rafales : « QUESTS_CHANGED » (ns.Fire) une fois la
-- rafale passée.
local _, root = ...
local ns = root.Plus

ns.Quests = ns.Quests or {}
local Log = {}
ns.Quests.Log = Log

local Db = ns.Quests.Db

local EVERY = 0.5               -- s : une rafale de mises à jour, un seul changement

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

---------------------------------------------------------------------------
-- Le journal du jeu
---------------------------------------------------------------------------
function Log.NumEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        return Plain(Call(C_QuestLog.GetNumQuestLogEntries)) or 0
    end
    return Plain(Call(_G.GetNumQuestLogEntries)) or 0
end

function Log.InfoAt(i)
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = Call(C_QuestLog.GetInfo, i)
        if type(info) == "table" then
            return { title = Plain(info.title), level = Plain(info.level), isHeader = Plain(info.isHeader),
                questID = Plain(info.questID), complete = Plain(info.isComplete), isHidden = Plain(info.isHidden) }
        end
    end
    local title, level, _, isHeader, _, complete, _, questID = Call(_G.GetQuestLogTitle, i)
    if title then
        return { title = Plain(title), level = Plain(level), isHeader = Plain(isHeader), questID = Plain(questID),
            complete = Plain(complete) }
    end
end

-- Les objectifs d'une quête du journal (index : sa ligne, pour l'API de Classic)
function Log.Objectives(questID, index)
    local out = {}
    if C_QuestLog and C_QuestLog.GetQuestObjectives and questID then
        local objs = Call(C_QuestLog.GetQuestObjectives, questID)
        for _, o in ipairs(type(objs) == "table" and objs or {}) do
            local text = Plain(o.text)
            if type(text) == "string" and text ~= "" then
                out[#out + 1] = { text = text, finished = Plain(o.finished) and true or false, type = Plain(o.type),
                    have = Plain(o.numFulfilled), need = Plain(o.numRequired) }
            end
        end
    end
    if #out == 0 and index and _G.GetNumQuestLeaderBoards then
        local n = Plain(Call(_G.GetNumQuestLeaderBoards, index)) or 0
        for j = 1, n do
            local text, kind, done = Call(_G.GetQuestLogLeaderBoard, j, index)
            text = Plain(text)
            if type(text) == "string" and text ~= "" then
                out[#out + 1] = { text = text, finished = Plain(done) and true or false, type = Plain(kind) }
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Les quêtes du journal, gardées jusqu'au prochain changement
---------------------------------------------------------------------------
local cache, goals = nil, {}

-- (un nom dans le texte d'un objectif, sans tenir compte de la casse)
local function Says(text, name)
    return type(name) == "string" and name ~= "" and text:lower():find(name:lower(), 1, true) ~= nil
end

local function ItemName(itemID)
    local name = GetItemInfo and GetItemInfo(itemID)
    if not name and C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(itemID) end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
    return Plain(name)
end

-- Relier les objectifs du jeu à ceux de la base : d'abord par le nom (le texte du
-- jeu dit le nom du monstre, de l'objet), sinon dans l'ordre, par sorte
local function Link(g, base)
    local usedGoal, usedItem = {}, {}
    local function Take(list, used, match, want)
        for i, v in ipairs(list) do
            if not used[i] and match(v) then
                used[i] = true
                return v
            end
        end
        for i, v in ipairs(list) do
            if not used[i] and (not want or want(v)) then
                used[i] = true
                return v
            end
        end
    end
    -- (d'abord ceux qu'on reconnaît à leur nom, pour que l'ordre ne serve qu'aux autres)
    for pass = 1, 2 do
        for _, o in ipairs(g) do
            if o.type == "item" and not o.item then
                local it = pass == 1 and Take(base.items, usedItem, function(id) return Says(o.text, ItemName(id)) end, function() return false end)
                    or pass == 2 and Take(base.items, usedItem, function() return false end)
                if it then o.item = it end
            elseif (o.type == "monster" or o.type == "object") and not o.refs then
                local object = o.type == "object"
                local function Named(goal)
                    for _, ref in ipairs(goal) do
                        if Says(o.text, Db.Name(ref)) then return true end
                    end
                end
                local goal = pass == 1 and Take(base.goals, usedGoal, Named, function() return false end)
                    or pass == 2 and Take(base.goals, usedGoal, function(gl) return (gl[1] < 0) == object end)
                if goal then o.refs = goal end
            elseif o.type == "event" and pass == 1 then
                o.explore = true
            end
        end
    end
end

function Log.Quests()
    if cache then return cache end
    cache = {}
    for i = 1, Log.NumEntries() do
        local info = Log.InfoAt(i)
        -- (pas les quêtes cachées du journal : des marques que le jeu tient pour lui)
        if info and not info.isHeader and not info.isHidden and info.questID then
            local complete = info.complete == 1 or info.complete == true
            if info.complete == nil and C_QuestLog and C_QuestLog.IsComplete then
                complete = Plain(Call(C_QuestLog.IsComplete, info.questID)) and true or false
            end
            cache[info.questID] = { id = info.questID, index = i, title = info.title, level = info.level,
                complete = complete }
        end
    end
    return cache
end

-- Les objectifs d'une quête reliés à la base : { text, finished, type, have, need, refs | item }
function Log.Goals(questID)
    local g = goals[questID]
    if g then return g end
    local q = Log.Quests()[questID]
    g = Log.Objectives(questID, q and q.index)
    local base = Db.Quest(questID)
    if base then Link(g, base) end
    goals[questID] = g
    return g
end

---------------------------------------------------------------------------
-- Les quêtes faites
---------------------------------------------------------------------------
local done = nil
local turnedIn = {}             -- (les quêtes rendues pendant la partie, avant que le jeu les compte faites)

function Log.Done(questID)
    if not done then
        done = {}
        -- (une liste vide, juste après la connexion, n'est pas encore la liste : alors une quête à la fois)
        local all = C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs and Call(C_QuestLog.GetAllCompletedQuestIDs)
        if type(all) == "table" and #all > 0 then
            for _, id in ipairs(all) do done[id] = true end
            done.full = true
        else
            local legacy = Call(_G.GetQuestsCompleted)
            if type(legacy) == "table" and next(legacy) then
                for id, v in pairs(legacy) do if v then done[id] = true end end
                done.full = true
            end
        end
    end
    if done[questID] or turnedIn[questID] then return true end
    if done.full then return false end
    -- (sans la liste : une quête à la fois)
    local flagged = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    local yes = flagged and Plain(Call(flagged, questID)) and true or false
    done[questID] = yes
    return yes
end

---------------------------------------------------------------------------
-- Les changements
---------------------------------------------------------------------------
local waiting = false
local function Changed()
    cache = nil
    wipe(goals)
    if waiting then return end
    waiting = true
    C_Timer.After(EVERY, function()
        waiting = false
        cache = nil
        wipe(goals)
        done = nil              -- (sur Forever, QUEST_TURNED_IN arrive parfois tard, ou pas)
        ns.Fire("QUESTS_CHANGED")
    end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "UNIT_QUEST_LOG_CHANGED" and arg ~= "player" then return end
    if event == "QUEST_TURNED_IN" and type(arg) == "number" then
        turnedIn[arg] = true
    elseif event == "QUEST_REMOVED" and type(arg) == "number" then
        -- (sur Forever, QUEST_TURNED_IN arrive parfois tard ou pas : une quête qui
        -- quitte le journal est regardée un peu plus tard, rendue ou abandonnée)
        local id = arg
        C_Timer.After(2, function()
            local flagged = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
            if flagged and Plain(Call(flagged, id)) then turnedIn[id] = true end
            Changed()
        end)
    end
    if event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" or event == "QUEST_ACCEPTED" or event == "PLAYER_LEVEL_UP" then
        done = nil
    end
    Changed()
end)
for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
    "UNIT_QUEST_LOG_CHANGED", "PLAYER_LEVEL_UP" }) do
    pcall(events.RegisterEvent, events, e)
end
