-- Les marqueurs de quêtes, tirés de la base des quêtes de My Map Is Rich
-- (Quests/Db.lua) : là où le jeu ne montre que la zone d'un objectif, ils
-- disent qui tuer, quoi ramasser et sur qui, quoi utiliser, où rendre une
-- quête finie et où en prendre de nouvelles. Trois jeux d'icônes :
--   - « qm_goal » (réglage questGoals) : les objectifs en cours de ton
--     journal, une icône par endroit où se trouve le monstre, l'objet du
--     monde, celui qui lâche ou vend l'objet à trouver, ou le lieu à
--     explorer ; un objectif rempli n'en a plus ;
--   - « qm_end » (questEnds) : un « ? » doré là où se rend une quête finie ;
--   - « qm_offer » (questOffers) : un « ! » sur les donneurs des quêtes que tu
--     peux prendre (Quests/Offers.lua) ; les grises avec questOffersGrey.
-- Une icône par PNJ ou objet et par endroit : son info-bulle dit toutes les
-- quêtes qui y mènent. Un PNJ dans un donjon a son icône à l'entrée.
-- Un clic (A à la manette) : la quête est suivie et la vue zoome dessus.
-- Les trois jeux suivent le calque Quêtes du rail (« questIcons ») ; ils se
-- posent quelques centaines par image, la carte ouverte seulement.
local _, root = ...
local ns = root.Plus
local L = ns.L

local K = ns.Map.Coords
local Pins = ns.Map.Pins
local V = ns.Map.View
local Settings = ns.Map.Settings
local Db = ns.Quests.Db
local Log = ns.Quests.Log
local Offers = ns.Quests.Offers

local QM = {}
ns.Quests.Marks = QM

Settings.Own("questGoals", true)
Settings.Own("questEnds", true)
Settings.Own("questOffers", true)
Settings.Own("questOffersGrey", false)

-- les allures, par sorte d'objectif (des curseurs du jeu : sur tous les clients)
local LOOKS = {
    kill = { texture = "Interface\\Cursor\\Attack", fallback = "Interface\\Minimap\\ObjectIcons", size = 16 },
    loot = { texture = "Interface\\Cursor\\Pickup", fallback = "Interface\\Minimap\\ObjectIcons", size = 16 },
    use = { texture = "Interface\\Cursor\\Interact", fallback = "Interface\\Minimap\\ObjectIcons", size = 16 },
    buy = { texture = "Interface\\Cursor\\Buy", fallback = "Interface\\GossipFrame\\VendorGossipIcon", size = 16 },
    explore = { texture = "Interface\\Cursor\\Inspect", fallback = "Interface\\Minimap\\ObjectIcons", size = 18 },
    finish = { atlas = "QuestTurnin", texture = "Interface\\GossipFrame\\ActiveQuestIcon", size = 18 },
    offer = { atlas = "QuestNormal", texture = "Interface\\GossipFrame\\AvailableQuestIcon", size = 18 },
}
local ORDER = { kill = 1, use = 2, loot = 3, buy = 4, explore = 5 }      -- (l'icône d'un PNJ qui sert à plusieurs objectifs)
local MANY = 20                 -- au-delà de ce nombre d'endroits, des icônes plus petites
local SMALL = 0.75
local PER_FRAME = 250           -- icônes posées par image
local ZOOM_TO = 6

local sets = {}                 -- "goal" | "end" | "offer" -> jeu d'icônes
local building = 0              -- (la construction en cours : une nouvelle annule l'ancienne)
local dirty = true

local function On() return Db.Has() and Settings.Get("questIcons") ~= false end
function QM.OffersOn() return On() and Settings.Get("questOffers") ~= false end

---------------------------------------------------------------------------
-- Les titres et les info-bulles
---------------------------------------------------------------------------
local function Title(id)
    local q = Log.Quests()[id]
    local title = q and q.title
    if not title and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, t = pcall(C_QuestLog.GetTitleForQuestID, id)
        if ok and type(t) == "string" and t ~= "" then title = t end
    end
    local base = Db.Quest(id)
    title = title or (base and base.title) or ("#" .. id)
    local level = (q and q.level) or (base and base.level)
    if level and level > 0 then title = "[" .. level .. "] " .. title end
    return title, level
end

local function Colour(level)
    local get = _G.GetQuestDifficultyColor
    if level and level > 0 and get then
        local ok, c = pcall(get, level)
        if ok and type(c) == "table" and c.r then return c.r, c.g, c.b end
    end
    return 1, 1, 1
end

-- (le rang d'un PNJ : élite et chef, les mots du jeu ; rare, ceux des citadins)
local function Rank(r)
    if r == 2 then return L.TOWNSFOLK_RARE_ELITE end
    if r == 4 then return L.TOWNSFOLK_RARE end
    if r == 1 then return _G.ELITE end
    if r == 3 then return _G.BOSS end
end

local function Enter(pin)
    local e = pin.data
    if not e then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    -- (un lieu à explorer n'a pas de PNJ : e.ref est « x<quête> »)
    local ref = type(e.ref) == "number" and e.ref or nil
    GameTooltip:SetText(ref and Db.Name(ref) or L.QUESTMARK_EXPLORE, 1, 0.82, 0)
    local npc = ref and ref > 0 and Db.Npc(ref)
    if npc and npc.minLevel and npc.minLevel > 0 then
        local lv = npc.minLevel == npc.maxLevel and tostring(npc.minLevel) or (npc.minLevel .. "-" .. (npc.maxLevel or npc.minLevel))
        local rank = Rank(npc.rank)
        GameTooltip:AddLine((LEVEL or "") .. " " .. lv .. (rank and ("  " .. rank) or ""), 0.8, 0.8, 0.8)
    end
    if pin.inside then GameTooltip:AddLine(L.QUESTMARK_DUNGEON, 0.6, 0.6, 0.6) end
    if e.what == "end" then GameTooltip:AddLine(L.QUESTMARK_TURN_IN, 0.5, 0.95, 0.4)
    elseif e.what == "offer" then GameTooltip:AddLine(L.QUESTMARK_OFFERS, 1, 1, 1) end
    for _, line in ipairs(e.lines) do
        local title, level = Title(line.quest)
        GameTooltip:AddLine(title, Colour(level))
        if line.text then
            local text = (_G.QUEST_DASH or "- ") .. line.text
            if line.vendor then text = text .. "  |cff999999" .. L.QUESTMARK_VENDOR .. "|r" end
            GameTooltip:AddLine(text, 1, 1, 1, true)
        end
    end
    GameTooltip:AddLine(e.what == "offer" and L.QUESTMARK_ZOOM or L.QUESTS_CLICK, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

-- Un clic : la quête suivie (celle de l'objectif ou à rendre), et la vue dessus
local function Click(pin)
    local e = pin.data
    if not e then return end
    local first = e.lines[1] and e.lines[1].quest
    if first and e.what ~= "offer" and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        if C_QuestLog.AddQuestWatch and not (C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(first)) then
            pcall(C_QuestLog.AddQuestWatch, first)
        end
        pcall(C_SuperTrack.SetSuperTrackedQuestID, first)
    end
    local _, _, zoom = V.Now()
    V.Glide(pin.u, pin.v, math.max(zoom or 1, ZOOM_TO))
end

---------------------------------------------------------------------------
-- Ce qu'il faut marquer : un par PNJ ou objet du monde, avec ses quêtes
---------------------------------------------------------------------------
-- (into : { byRef = { ref -> e }, list = { e, ... } })
local function Entry(into, what, ref, kind)
    local e = into.byRef[ref]
    if not e then
        e = { ref = ref, what = what, kind = kind, lines = {} }
        into.byRef[ref] = e
        into.list[#into.list + 1] = e
    elseif kind and ORDER[kind] and (not e.kind or ORDER[kind] < ORDER[e.kind]) then
        e.kind = kind
    end
    return e
end

local function Goals(out)
    for id, q in pairs(Log.Quests()) do
        if not q.complete then
            for _, o in ipairs(Log.Goals(id)) do
                if not o.finished then
                    for _, ref in ipairs(o.refs or {}) do
                        local kind = ref < 0 and "use" or "kill"
                        local e = Entry(out, "goal", ref, kind)
                        e.lines[#e.lines + 1] = { quest = id, text = o.text }
                    end
                    if o.item then
                        for _, s in ipairs(Db.Sources(o.item)) do
                            local e = Entry(out, "goal", s[1], s.vendor and "buy" or "loot")
                            e.lines[#e.lines + 1] = { quest = id, text = o.text, vendor = s.vendor }
                        end
                    end
                    if o.explore then
                        local e = Entry(out, "goal", "x" .. id, "explore")
                        e.spots = Db.Explore(id)
                        e.lines[#e.lines + 1] = { quest = id, text = o.text }
                    end
                end
            end
        end
    end
end

local function Ends(out)
    for id, q in pairs(Log.Quests()) do
        local base = q.complete and Db.Quest(id)
        for _, ref in ipairs(base and base.ends or {}) do
            local e = Entry(out, "end", ref, "finish")
            e.lines[#e.lines + 1] = { quest = id }
        end
    end
end

local function OffersOf(out)
    local grey = Settings.Get("questOffersGrey") == true
    local side = UnitFactionGroup("player") == "Horde" and 2 or 1
    for _, o in ipairs(Offers.List()) do
        if grey or not o.trivial then
            local base = Db.Quest(o.id)
            for _, ref in ipairs(base and base.starts or {}) do
                if bit.band(Db.React(ref), side) ~= 0 then
                    local e = Entry(out, "offer", ref, "offer")
                    e.lines[#e.lines + 1] = { quest = o.id }
                    e.trivial = (e.trivial ~= false) and o.trivial
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- La pose des icônes, quelques centaines par image
---------------------------------------------------------------------------
local function Place(set, e, look, todo)
    local spots = e.spots or Db.Places(e.ref)
    if #spots > MANY then look = { texture = look.texture, atlas = look.atlas, fallback = look.fallback, size = look.size * SMALL } end
    local mine = UnitLevel("player") or 1
    for _, p in ipairs(spots) do
        -- (un donneur dans un donjon : son « ! » à l'entrée, seulement au niveau du donjon)
        if not (e.what == "offer" and p.inside and p.minLevel and mine < p.minLevel) then
            todo[#todo + 1] = { set, p, look, e }
        end
    end
end

local function Build(token, todo, at)
    if token ~= building then return end
    local stop = math.min(at + PER_FRAME - 1, #todo)
    for i = at, stop do
        local t = todo[i]
        local pin = Pins.Add(t[1], t[2][1], t[2][2], t[3], t[4])
        if pin then
            pin.inside = t[2].inside
            if t[4].trivial then pin.Icon:SetDesaturated(true) end
            pin:SetScript("OnEnter", Enter)
            pin:SetScript("OnLeave", GameTooltip_Hide)
            pin.OnClick = Click
        end
    end
    if stop < #todo then C_Timer.After(0, function() Build(token, todo, stop + 1) end) end
end

local function Sets()
    if sets.goal or not Pins.Ready() then return sets.goal ~= nil end
    sets.goal = Pins.Set("qm_goal", 2, 4)
    sets.offer = Pins.Set("qm_offer", 3, 4)     -- (sous les icônes des quêtes du jeu)
    sets["end"] = Pins.Set("qm_end", 1, 6)      -- (au-dessus)
    return sets.goal ~= nil
end

function QM.Refresh()
    if not Sets() then return end
    building = building + 1
    dirty = false
    for _, set in pairs(sets) do Pins.Clear(set) end
    local on = On()
    local want = {
        goal = on and Settings.Get("questGoals") ~= false,
        ["end"] = on and Settings.Get("questEnds") ~= false,
        offer = on and Settings.Get("questOffers") ~= false,
    }
    for what, set in pairs(sets) do Pins.SetOn(set, want[what]) end
    if not on then return end
    local todo = {}
    local function Each(what, fill)
        if not want[what] then return end
        local out = { byRef = {}, list = {} }
        fill(out)
        for _, e in ipairs(out.list) do Place(sets[what], e, LOOKS[e.kind] or LOOKS.kill, todo) end
    end
    Each("goal", Goals)
    Each("end", Ends)
    Each("offer", OffersOf)
    Build(building, todo, 1)
end

ns.On("MAP_BUILT", function() QM.Refresh() end)
ns.On("MAP_SHOW", function() if dirty and ns.Map.IsBuilt() then QM.Refresh() end end)
ns.On("MAP_REFRESH", function() if ns.Map.IsBuilt() then QM.Refresh() end end)
ns.On("QUESTS_CHANGED", function()
    if ns.Map.IsBuilt() and ns.MapShown() then QM.Refresh() else dirty = true end
end)

---------------------------------------------------------------------------
-- /mmir sonde quetes : tes quêtes du journal dans la base, et où tu es (en
-- yards, pour tools/quests/forever_fixes.json)
---------------------------------------------------------------------------
function QM.Probe()
    if not Db.Has() then
        ns.Print(L.PROBE_QUESTS_NO_BASE)
        return
    end
    ns.Print(L.PROBE_QUESTS_HEAD:format(Db.Build() or "?"))
    local n = 0
    for id, q in pairs(Log.Quests()) do
        n = n + 1
        local base = Db.Quest(id)
        if not base then
            ns.Print(L.PROBE_QUESTS_MISSING:format(id, q.title or "?"))
        else
            local found, total, spots = 0, 0, 0
            for _, o in ipairs(Log.Goals(id)) do
                total = total + 1
                local refs = {}
                for _, ref in ipairs(o.refs or {}) do refs[#refs + 1] = ref end
                for _, s in ipairs(o.item and Db.Sources(o.item) or {}) do refs[#refs + 1] = s[1] end
                if #refs > 0 or o.explore then found = found + 1 end
                for _, ref in ipairs(refs) do spots = spots + #Db.Places(ref) end
                if o.explore then spots = spots + #Db.Explore(id) end
            end
            ns.Print(L.PROBE_QUESTS_LINE:format(id, q.title or base.title, found, total, spots))
        end
    end
    if n == 0 then ns.Print(L.PROBE_QUESTS_NONE) end
    -- (où tu es, comme forever_fixes.json l'attend : la carte du jeu et x, y en %)
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y
    if pos then x, y = pos:GetXY() end
    if x then ns.Print(L.PROBE_QUESTS_HERE:format(mapID, x * 100, y * 100)) end
end
