-- Ce que la base des quêtes ne sait pas encore (Forever ajoute des quêtes
-- que QuestieDB n'a pas), appris en jouant :
--   - une quête prise qui n'est pas dans la base : qui la donne, où (là où tu
--     étais en lui parlant), son titre et son niveau ; puis qui la reprend, à
--     son rendu. Gardé pour le compte (MyMapIsRichPlusDB.learnedQuests) : tes
--     autres personnages de la même faction voient son « ! » (Layers/QuestMarks.lua) ;
--   - un « ! » démenti : un PNJ à qui tu parles ne propose pas une quête que
--     la carte lui prêtait (elle n'est pas grise) ; ce « ! » s'efface pour ce
--     personnage, jusqu'à son prochain niveau (MyMapIsRichPlusCharDB.notOffered).
-- /mmir quetes export : ce qui a été appris, dans une fenêtre à copier, au
-- format de tools/quests/forever_fixes.json (addQuests, addNpcs).
--   Learn.Offers()        -> { { id, ref, spots, level }, ... } : les « ! » appris
--   Learn.NotOffered(id, ref)  le PNJ ref a démenti la quête id
--   Learn.Title(id)       le titre d'une quête apprise
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local Db = ns.Quests.Db
local Log = ns.Quests.Log

local Learn = {}
ns.Quests.Learn = Learn

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

local function Learned()
    if not ns.db then return end
    ns.db.learnedQuests = ns.db.learnedQuests or {}
    return ns.db.learnedQuests
end

local function NotOfferedTable()
    if not ns.char then return end
    ns.char.notOffered = ns.char.notOffered or {}
    return ns.char.notOffered
end

-- Le PNJ à qui tu parles : son numéro et son nom (nil : un joueur, un objet, inconnu)
local function TalkingTo()
    local guid = Plain(UnitGUID("npc"))
    if type(guid) ~= "string" then return end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    id = tonumber(id)
    if not id or (kind ~= "Creature" and kind ~= "GameObject") then return end
    local name = Plain(UnitName("npc"))
    return kind == "GameObject" and -id or id, type(name) == "string" and name or nil
end

-- Où tu es : la carte du jeu et x, y en % (comme forever_fixes.json)
local function Here()
    local mapID = C_Map and Plain(Call(C_Map.GetBestMapForUnit, "player"))
    local pos = mapID and Call(C_Map.GetPlayerMapPosition, mapID, "player")
    if not pos then return end
    local x, y = Call(pos.GetXY, pos)
    x, y = Plain(x), Plain(y)
    if not (x and y) or (x == 0 and y == 0) then return end
    return mapID, math.floor(x * 10000 + 0.5) / 100, math.floor(y * 10000 + 0.5) / 100
end

---------------------------------------------------------------------------
-- Apprendre
---------------------------------------------------------------------------
local talking                   -- { ref, name, map, x, y, at } : le PNJ qui vient de te parler d'une quête
local TALK_FRESH = 15           -- s : plus vieux, ce n'est plus lui (une quête d'objet, partagée par le groupe)

local function Remember()
    local ref, name = TalkingTo()
    if not ref then
        -- (un joueur, un objet de tes sacs : pas de PNJ, et pas l'ancien non plus)
        talking = nil
        return
    end
    local map, x, y = Here()
    talking = { ref = ref, name = name, map = map, x = x, y = y, at = GetTime() }
end

local function Talking()
    if talking and GetTime() - talking.at <= TALK_FRESH then return talking end
end

local function Spot(t)
    return { name = t.name, map = t.map, x = t.x, y = t.y }
end

-- Une quête prise, absente de la base : son donneur (celui qui vient de t'en parler)
local function Accepted(questID)
    local all = Learned()
    local talking = Talking()
    if not (all and questID and talking) or Db.Quest(questID) then return end
    -- (vraiment dans ton journal : pas un index du journal pris pour une quête)
    local q = Log.Quests()[questID]
    if not q then return end
    local e = all[questID] or { starts = {}, ends = {} }
    e.title = (q and q.title) or Db.Title(questID)
    e.level = (q and q.level) or e.level
    e.minLevel = math.min(e.minLevel or 999, UnitLevel("player") or 1)
    e.faction = UnitFactionGroup("player")
    -- (qui l'a prise : une quête de classe ou de race se reconnaît à l'export)
    e.learnedBy = select(2, UnitClass("player"))
    if talking.ref and talking.map then e.starts[talking.ref] = Spot(talking) end
    all[questID] = e
    ns.Fire("QUESTS_LEARNED")
end

-- Une quête rendue : celui qui la reprend
local function TurnedIn(questID)
    local all = Learned()
    local e = all and all[questID]
    local talking = Talking()
    if not (e and talking and talking.ref and talking.map) then return end
    e.ends[talking.ref] = Spot(talking)
end

-- Un PNJ qui parle : les quêtes qu'il propose vraiment (C_GossipInfo), face
-- aux « ! » que la carte lui prête
local function Gossip()
    local ref = TalkingTo()
    local QM = ns.Quests.Marks
    if not (ref and QM and C_GossipInfo and C_GossipInfo.GetAvailableQuests) then return end
    local avail = Call(C_GossipInfo.GetAvailableQuests)
    if type(avail) ~= "table" then return end
    local offered = {}
    for _, info in ipairs(avail) do
        local id = Plain(info.questID)
        -- (une quête sans numéro : le client ne dit pas tout, rien n'est conclu)
        if type(id) ~= "number" or id <= 0 then return end
        offered[id] = true
    end
    local t = NotOfferedTable()
    if not t then return end
    local level, changed = UnitLevel("player") or 1, false
    for _, e in ipairs(QM.Entries().offer or {}) do
        if e.ref == ref and not e.trivial then
            for _, line in ipairs(e.lines) do
                local id = line.quest
                if not offered[id] and not ns.Quests.Offers.Trivial(id) then
                    t[id] = t[id] or {}
                    t[id][ref] = level
                    changed = true
                end
            end
        end
    end
    if changed then ns.Fire("QUESTS_LEARNED") end
end

function Learn.NotOffered(id, ref)
    local t = ns.char and ns.char.notOffered
    local level = t and t[id] and t[id][ref]
    return level ~= nil and level >= (UnitLevel("player") or 1)
end

function Learn.Title(id)
    local e = ns.db and ns.db.learnedQuests and ns.db.learnedQuests[id]
    return e and e.title
end

-- Les « ! » appris que tu peux voir : ta faction, pas faite, pas dans ton
-- journal, ton niveau au moins celui où elle a été prise
function Learn.Offers()
    local out = {}
    local all = ns.db and ns.db.learnedQuests
    if not all then return out end
    local K = ns.Map.Coords
    local faction, mine, inLog = UnitFactionGroup("player"), UnitLevel("player") or 1, Log.Quests()
    for id, e in pairs(all) do
        if not Db.Quest(id) and e.faction == faction and not inLog[id] and not Log.Done(id) and mine >= (e.minLevel or 1) then
            for ref, s in pairs(e.starts or {}) do
                local u, v = s.map and K.ToWorld(s.map, s.x / 100, s.y / 100)
                if u then out[#out + 1] = { id = id, ref = ref, spots = { { u, v } }, level = e.level, name = s.name } end

            end
        end
    end
    return out
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg, ...)
    if ns.Conflict and ns.Conflict() or not Db.Has() then return end
    if event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" or event == "QUEST_GREETING" then
        Remember()
    elseif event == "GOSSIP_SHOW" then
        Remember()
        pcall(Gossip)
    elseif event == "QUEST_ACCEPTED" then
        -- (QUEST_ACCEPTED donne questID ; sur les clients de Classic, après l'index du journal : le dernier nombre)
        local id = select("#", ...) > 0 and select(select("#", ...), ...) or arg
        id = type(id) == "number" and id or nil

        C_Timer.After(0.5, function() pcall(Accepted, id) end)
    elseif event == "QUEST_TURNED_IN" then
        pcall(TurnedIn, arg)
    end
end)
for _, e in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW",
    "QUEST_ACCEPTED", "QUEST_TURNED_IN" }) do
    pcall(events.RegisterEvent, events, e)
end

---------------------------------------------------------------------------
-- /mmir quetes export : ce qui a été appris, au format de forever_fixes.json
---------------------------------------------------------------------------
local function Json(s)
    return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

function Learn.Export()
    local all = ns.db and ns.db.learnedQuests or {}
    local quests, npcs, n = {}, {}, 0
    local ids = {}
    for id in pairs(all) do if not Db.Quest(id) then ids[#ids + 1] = id end end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local e = all[id]
        n = n + 1
        local starts, ends = {}, {}
        for ref, s in pairs(e.starts or {}) do
            starts[#starts + 1] = tostring(ref)
            if ref > 0 and not Db.Npc(ref) then npcs[ref] = npcs[ref] or { s = s, faction = e.faction } end
        end
        for ref, s in pairs(e.ends or {}) do
            ends[#ends + 1] = tostring(ref)
            if ref > 0 and not Db.Npc(ref) then npcs[ref] = npcs[ref] or { s = s, faction = e.faction } end
        end
        quests[#quests + 1] = ('    "%d": { "title": %s, "level": %d, "minLevel": %d, "starts": [%s], "ends": [%s], "faction": %s, "learnedBy": %s }')
            :format(id, Json(e.title or "?"), e.level or 0, e.minLevel or 0, table.concat(starts, ", "),
                table.concat(ends, ", "), Json(e.faction or ""), Json(e.learnedBy or ""))

    end
    local lines = { '"addQuests": {', table.concat(quests, ",\n"), '},', '"addNpcs": {' }
    local list = {}
    for ref, n in pairs(npcs) do
        local s = n.s
        list[#list + 1] = ('    "%d": { "name": %s, "react": %d, "spawns": { "%d": [[%.2f, %.2f]] } }'):format(ref,
            Json(s.name or "?"), n.faction == "Horde" and 2 or 1, s.map or 0, s.x or 0, s.y or 0)

    end
    table.sort(list)
    lines[#lines + 1] = table.concat(list, ",\n")
    lines[#lines + 1] = '}'
    return table.concat(lines, "\n"), n
end

local box
local function Build()
    if box then return box end
    box = UI.MapWindow("MyMapIsRichPlusQuestExport", 600, 300, L.LEARN_EXPORT_TITLE, nil, 8600)
    local c = box.content
    box.info = UI.DimText(c, "")
    box.info:SetPoint("TOPLEFT", 10, -6)
    box.info:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    box.info:SetJustifyH("LEFT")
    local inset = UI.Inset(c)
    inset:SetPoint("TOPLEFT", 4, -40)
    inset:SetPoint("BOTTOMRIGHT", -4, 6)
    local edit = CreateFrame("EditBox", nil, inset)
    edit:SetMultiLine(true)
    edit:SetMaxLetters(0)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(540)
    edit:SetHeight(200)
    edit:SetScript("OnEscapePressed", function() box:Hide() end)
    edit:SetScript("OnTextChanged", function(self, user)
        -- (un texte à copier reste tel quel)
        if user and box.text then
            self:SetText(box.text)
            self:HighlightText()
        end
    end)
    local scroll = UI.Scroll(inset, edit, 30)
    scroll:SetPoint("TOPLEFT", 10, -8)
    scroll:SetPoint("BOTTOMRIGHT", -22, 8)
    box.edit = edit
    ns.Focus.RegisterWindow(box, { onBack = function() box:Hide() end, first = function() return edit end })
    return box
end

function Learn.ShowExport()
    local text, n = Learn.Export()
    if n == 0 then
        ns.Print(L.LEARN_EXPORT_NONE)
        return
    end
    Build()
    box.text = text
    box.info:SetText(L.LEARN_EXPORT_INFO:format(n))
    box.edit:SetText(text)
    box:ClearAllPoints()
    box:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    box:Show()
    box:Raise()
    box.edit:SetFocus()
    box.edit:HighlightText()
end
