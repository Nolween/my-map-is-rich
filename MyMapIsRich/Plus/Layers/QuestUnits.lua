-- Les quêtes dans le monde, hors de la carte, d'après les mêmes marqueurs
-- (Layers/QuestMarks.lua : QM.Entries) :
--   - les info-bulles (réglage questTooltips) : un monstre, un PNJ, un objet
--     du monde ou un objet de tes sacs dit à quelle quête il sert et où tu en
--     es (« Kobolds tués : 3/10 »), qu'il prend une quête finie, ou qu'il en
--     donne que tu peux prendre ;
--   - les barres de nom (réglage questPlates) : une icône au-dessus d'un
--     monstre à tuer (une épée), de celui qui lâche ou vend l'objet à trouver
--     (un sac), d'un PNJ où rendre une quête (« ? ») ou qui en donne (« ! »).
--     Seulement les barres de nom que le jeu montre (Interface > Noms : celles
--     des PNJ amicaux pour les « ! » et « ? »).
-- Rien n'est écrit dans les cadres du jeu : les info-bulles passent par
-- TooltipDataProcessor (sinon HookScript), et nos icônes sont des cadres à
-- nous, posés au-dessus de la barre de nom (jamais dedans). Les valeurs que
-- le client garde secrètes (issecretvalue) sont laissées de côté.
local _, root = ...
local ns = root.Plus
local L = ns.L

local Settings = ns.Map.Settings
local Log = ns.Quests.Log

local QU = {}
ns.QuestUnits = QU

Settings.Own("questTooltips", true)
Settings.Own("questPlates", true)

local MAX_LINES = 6             -- lignes de quêtes au plus dans une info-bulle
local PLATE_SIZE = 20           -- px
local PLATE_LOOKS = {
    kill = { texture = "Interface\\Cursor\\Attack", fallback = "Interface\\Minimap\\ObjectIcons" },
    loot = { texture = "Interface\\Cursor\\Pickup", fallback = "Interface\\Minimap\\ObjectIcons" },
    buy = { texture = "Interface\\Cursor\\Buy", fallback = "Interface\\GossipFrame\\VendorGossipIcon" },
    finish = { atlas = "QuestTurnin", texture = "Interface\\GossipFrame\\ActiveQuestIcon" },
    offer = { atlas = "QuestNormal", texture = "Interface\\GossipFrame\\AvailableQuestIcon" },
}
local RANK = { finish = 1, kill = 2, loot = 3, buy = 4, offer = 5 }   -- (une seule icône par barre : la plus utile)

local function QM() return ns.Quests and ns.Quests.Marks end

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Ready()
    return QM() ~= nil and ns.Quests.Db.Has() and not (ns.Conflict and ns.Conflict())
end

---------------------------------------------------------------------------
-- Ce que sait chaque PNJ ou objet du monde (ref > 0 un PNJ, < 0 un objet),
-- et chaque objet à trouver : gardé jusqu'au prochain changement des marqueurs
---------------------------------------------------------------------------
local byRef, byItem

local function Index()
    if byRef then return byRef, byItem end
    byRef, byItem = {}, {}
    if not Ready() then return byRef, byItem end
    -- (comme la carte : seulement les sortes que le calque Quêtes montre, les grises si elle les montre)
    local all = QM().Entries()
    for _, what in ipairs({ "end", "goal", "offer" }) do
        for _, e in ipairs(QM().Want(what) and all[what] or {}) do
            if type(e.ref) == "number" then

                byRef[e.ref] = byRef[e.ref] or {}
                table.insert(byRef[e.ref], e)
            end
        end
    end
    -- (les objets à trouver de tes quêtes, et où tu en es)
    for id, q in pairs(Log.Quests()) do
        if not q.complete then
            for _, o in ipairs(Log.Goals(id)) do
                if o.item and not o.finished then
                    byItem[o.item] = byItem[o.item] or {}
                    table.insert(byItem[o.item], { quest = id, text = o.text })
                end
            end
        end
    end
    return byRef, byItem
end

ns.On("QUEST_MARKS", function(alphaOnly)
    if alphaOnly then return end
    byRef, byItem = nil, nil
    QU.RefreshPlates()
end)

-- (le numéro d'un PNJ ou d'un objet du monde dans un GUID : « Creature-0-…-id-… »)
local function FromGUID(guid)
    guid = Plain(guid)
    if type(guid) ~= "string" then return end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    id = tonumber(id)
    if not id then return end
    if kind == "Creature" or kind == "Vehicle" then return id end
    if kind == "GameObject" then return -id end
end

local function UnitRef(unit)
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    return FromGUID(UnitGUID(unit))
end

---------------------------------------------------------------------------
-- Les info-bulles
---------------------------------------------------------------------------
local function Head(tip, id, last)
    if id == last then return id end
    local title = QM().Title(id)
    tip:AddLine(title, 1, 0.82, 0)
    return id
end

local function AddRef(tip, ref)
    local list = Index()[ref]
    if not list then return end
    local n, last = 0, nil
    for _, e in ipairs(list) do
        for _, line in ipairs(e.lines) do
            if n >= MAX_LINES then return end
            n = n + 1
            if e.what == "end" then
                tip:AddLine(L.QUESTUNIT_TURN_IN:format(QM().Title(line.quest)), 0.5, 0.95, 0.4)
                last = nil
            elseif e.what == "offer" then
                tip:AddLine(L.QUESTUNIT_OFFER:format(QM().Title(line.quest)), 1, 0.82, 0)
                last = nil
            else
                last = Head(tip, line.quest, last)
                if line.text then tip:AddLine("  " .. line.text, 1, 1, 1, true) end
            end
        end
    end
end

local function AddItem(tip, itemID)
    local _, items = Index()
    local list = itemID and items[itemID]
    if not list then return end
    local last
    for i, line in ipairs(list) do
        if i > MAX_LINES then return end
        last = Head(tip, line.quest, last)
        if line.text then tip:AddLine("  " .. line.text, 1, 1, 1, true) end
    end
end

local function TipsOn() return Ready() and Settings.Get("questTooltips") ~= false end

local function OnUnit(tip)
    if not TipsOn() or tip ~= GameTooltip then return end
    local ok, _, unit = pcall(tip.GetUnit, tip)
    unit = ok and Plain(unit) or nil
    local ref = UnitRef(unit or "mouseover")
    if ref then AddRef(tip, ref) end
end

local function OnItem(tip, data)
    if not TipsOn() then return end
    local id = data and Plain(data.id)
    if not id and tip.GetItem then
        local ok, _, link = pcall(tip.GetItem, tip)
        link = ok and Plain(link) or nil
        id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
    end
    if type(id) == "number" then AddItem(tip, id) end
end

local function OnObject(tip, data)
    if not TipsOn() or tip ~= GameTooltip then return end
    local ref = data and FromGUID(data.guid)
    if ref and ref < 0 then AddRef(tip, ref) end
end

local TDP = _G.TooltipDataProcessor
local kinds = Enum and Enum.TooltipDataType
if TDP and TDP.AddTooltipPostCall and kinds then
    if kinds.Unit then TDP.AddTooltipPostCall(kinds.Unit, function(tip) pcall(OnUnit, tip) end) end
    if kinds.Item then TDP.AddTooltipPostCall(kinds.Item, function(tip, data) pcall(OnItem, tip, data) end) end
    if kinds.Object then TDP.AddTooltipPostCall(kinds.Object, function(tip, data) pcall(OnObject, tip, data) end) end
else
    GameTooltip:HookScript("OnTooltipSetUnit", function(tip) pcall(OnUnit, tip) end)
    GameTooltip:HookScript("OnTooltipSetItem", function(tip) pcall(OnItem, tip) end)
end

---------------------------------------------------------------------------
-- Les barres de nom
---------------------------------------------------------------------------
local marks = {}                -- unité de la barre -> notre icône
local pool = {}

local function PlatesOn() return Ready() and Settings.Get("questPlates") ~= false end

-- L'icône la plus utile pour ce PNJ : une quête à rendre, un monstre à tuer,
-- ce qui lâche ou vend l'objet, une quête à prendre
local function PlateKind(ref)
    local best
    for _, e in ipairs(Index()[ref] or {}) do
        local kind = e.what == "end" and "finish" or e.what == "offer" and "offer" or e.kind
        if RANK[kind] and (not best or RANK[kind] < RANK[best]) then best = kind end
    end
    return best
end

local function Drop(unit)
    local m = marks[unit]
    if not m then return end
    m:Hide()
    m:ClearAllPoints()
    marks[unit] = nil
    pool[#pool + 1] = m
end

local function Mark(unit)
    Drop(unit)
    if not PlatesOn() then return end
    local ref = UnitRef(unit)
    local kind = ref and PlateKind(ref)
    if not kind then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate then return end
    local m = table.remove(pool)
    if not m then
        m = CreateFrame("Frame", nil, UIParent)
        m:SetFrameStrata("BACKGROUND")
        m:SetSize(PLATE_SIZE, PLATE_SIZE)
        m.Icon = m:CreateTexture(nil, "ARTWORK")
        m.Icon:SetAllPoints()
        m:EnableMouse(false)
    end
    ns.Map.Pins.Look(m.Icon, PLATE_LOOKS[kind])
    if not pcall(m.SetPoint, m, "BOTTOM", plate, "TOP", 0, -6) then
        pool[#pool + 1] = m
        return
    end
    m:Show()
    marks[unit] = m
end

function QU.RefreshPlates()
    local units = {}
    for unit in pairs(marks) do units[#units + 1] = unit end
    for _, unit in ipairs(units) do Drop(unit) end
    if not (PlatesOn() and C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    for _, plate in ipairs(ok and plates or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then Mark(unit) end
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local ok, err = pcall(Mark, unit)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Drop(unit)
    end
end)
if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
    for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do
        pcall(events.RegisterEvent, events, e)
    end
end
