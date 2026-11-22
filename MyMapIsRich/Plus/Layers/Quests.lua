-- Les quêtes de ton journal sur la carte, de toutes les zones et à tous les
-- zooms : en code de My Map Is Rich depuis la 0.9.0 (elles venaient de
-- Map/Quests.lua, d'OpenMap). La carte du jeu ne montre les quêtes d'une zone
-- que sur la carte de cette zone ; ici, chaque zone a les siennes
-- (C_QuestLog.GetQuestsOnMap), dans l'allure des icônes du jeu.
--   - la quête suivie (celle du jeu) a son icône dorée et sa zone en ombre,
--     comme sur la carte du jeu ;
--   - le survol d'une icône montre sa zone et ses objectifs ;
--   - un clic la suit et la carte zoome dessus (la fiche d'un point, UI/
--     PointCard.lua, le fait aussi) ; le journal du jeu n'est jamais touché ;
--   - les « ! » : les quêtes qu'on peut commencer dans la zone où est la
--     carte du jeu (C_QuestLine.GetAvailableQuestLines).
-- Le calque Quêtes du rail (« questIcons ») et son détail « toutes les zones »
-- (« allQuests » ; sinon, seulement la zone où est la carte du jeu).
-- Lire les quêtes de toutes les zones est un appel au jeu par zone (des
-- dizaines) : elles se lisent quelques-unes par image, et les icônes se
-- posent ensemble une fois tout lu ; rien n'est lu carte fermée.
local _, root = ...
local ns = root.Plus
local L = ns.L

local K = ns.Map.Coords
local Pins = ns.Map.Pins
local V = ns.Map.View
local Settings = ns.Map.Settings

Settings.Own("questIcons", true)
Settings.Own("allQuests", true)

local function G(name) return _G[name] end

local BADGE = { atlas = "UI-QuestPoi-QuestNumber", texture = "Interface\\GossipFrame\\ActiveQuestIcon", size = 22 }
local IN_PROGRESS = { atlas = "Quest-In-Progress-Icon-yellow", texture = "Interface\\GossipFrame\\IncompleteQuestIcon" }
local TURN_IN = { atlas = "UI-QuestPoi-QuestBangTurnIn", texture = "Interface\\GossipFrame\\ActiveQuestIcon" }
local FOCUSED = { atlas = "UI-QuestPoi-QuestNumber-SuperTracked", texture = "Interface\\GossipFrame\\ActiveQuestIcon", size = 22 }
local OFFER = { atlas = "QuestNormal", texture = "Interface\\GossipFrame\\AvailableQuestIcon", size = 22 }
local SAME = 0.002              -- (unités du monde) les icônes d'une même quête si proches n'en font qu'une
local EVERY = 0.5               -- s : le journal change par rafales
local READ_MS = 3               -- ms par image pour lire les zones
local ZOOM_TO = 6
local NONE = {}

local set, offerSet, maps
local dirty, waiting = false, false
local reading                   -- la lecture en cours : { list, at, found, seen, ids, ... }
local drawn = {}                -- les icônes posées
local focusedPin
local focusTint                 -- (un client sans l'atlas doré : l'icône teintée d'or)

local function HasAtlas(name)
    return not (C_Texture and C_Texture.GetAtlasInfo) or C_Texture.GetAtlasInfo(name) ~= nil
end

-- Les cartes d'où les quêtes se lisent : les zones et les villes du monde
local function Maps()
    if maps then return maps end
    maps = {}
    local ok, list = pcall(C_Map.GetMapChildrenInfo, K.World(), Enum.UIMapType.Zone, true)
    for _, info in ipairs(ok and list or NONE) do
        if K.Rect(info.mapID) then maps[#maps + 1] = info.mapID end
    end
    return maps
end

local function Style(pin, on)
    local look = on and FOCUSED or BADGE
    pin.look = look
    ns.UI.SetIcon(pin.Icon, look.texture, look.atlas)
    if pin.Highlight then ns.UI.SetIcon(pin.Highlight, look.texture, look.atlas) end
    if on and focusTint then pin.Icon:SetVertexColor(1, 0.82, 0) else pin.Icon:SetVertexColor(1, 1, 1) end
end

-- La quête suivie : son icône dorée, sa zone en ombre
local function Focus()
    if not set then return end
    if focusTint == nil then focusTint = not HasAtlas(FOCUSED.atlas) end
    local tracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
    local found
    if tracked then
        for _, pin in ipairs(drawn) do
            if pin.data and pin.data.id == tracked then
                found = pin
                break
            end
        end
    end
    if found ~= focusedPin then
        if focusedPin then Style(focusedPin, false) end
        if found then Style(found, true) end
        focusedPin = found
    end
    V.QuestFocus(found and tracked or nil, found and found.data.map or nil)
end

local function Enter(pin)
    local q = pin.data
    if not q then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q.id)
    -- (son niveau et sa couleur, « [39+] », comme les icônes de quête du jeu)
    local decorate = G("SetQuestTitleLevelAndDifficultyColor")
    if title and decorate then title = decorate(q.id, title) end
    GameTooltip:SetText(title or "?", 1, 0.82, 0)
    local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(q.id)
    if q.complete then
        GameTooltip:AddLine(_G.QUEST_WATCH_QUEST_READY or L.QUESTS_DONE, 0.5, 0.95, 0.4)
    elseif index and G("GetNumQuestLeaderBoards") and G("GetQuestLogLeaderBoard") then
        for i = 1, G("GetNumQuestLeaderBoards")(index) or 0 do
            local text, _, finished = G("GetQuestLogLeaderBoard")(i, index)
            if text and not finished then GameTooltip:AddLine((_G.QUEST_DASH or "- ") .. text, 1, 1, 1, true) end
        end
    end
    GameTooltip:AddLine(L.QUESTS_CLICK, 0.6, 0.6, 0.6)
    GameTooltip:Show()
    V.QuestArea(q.id, q.map)
end

local function Leave()
    GameTooltip:Hide()
    V.QuestArea(nil)
end

local function EnterOffer(pin)
    local q = pin.data
    if not q then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(q.name or "?", 1, 0.82, 0)
    if q.line and q.line ~= "" and q.line ~= q.name then GameTooltip:AddLine(q.line, 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

-- Un clic : la quête suivie (comme les icônes du jeu), et la vue dessus
local function Click(pin)
    local q = pin.data
    if not q then return end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        if C_QuestLog.AddQuestWatch and not (C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(q.id)) then
            pcall(C_QuestLog.AddQuestWatch, q.id)
        end
        pcall(C_SuperTrack.SetSuperTrackedQuestID, q.id)
    end
    Focus()
    local _, _, zoom = V.Now()
    V.Glide(pin.u, pin.v, math.max(zoom or 1, ZOOM_TO))
end

-- L'état par-dessus l'icône : en cours, ou à rendre
local function Mark(pin, complete)
    if not pin.questMark then
        pin.questMark = pin:CreateTexture(nil, "OVERLAY")
        pin.questMark:SetPoint("CENTER")
    end
    local look, size = complete and TURN_IN or IN_PROGRESS, BADGE.size * 0.6
    pin.questMark:SetSize(size, size)
    ns.UI.SetIcon(pin.questMark, look.texture, look.atlas)
    pin.questMark:Show()
end

-- Les « ! » : les quêtes qu'on peut commencer dans la zone où est la carte
-- du jeu ; pas celles de ton journal, ni d'un autre étage, ni une cachée
local function Offers(ids)
    local zone = V.GameMapID()
    if not (offerSet and zone and K.Rect(zone) and C_QuestLine and C_QuestLine.GetAvailableQuestLines) then return end
    Pins.SetOn(offerSet, true)
    local same = Enum.QuestLineFloorLocation and Enum.QuestLineFloorLocation.Same or 2
    local seen = {}
    local ok, lines = pcall(C_QuestLine.GetAvailableQuestLines, zone)
    for _, q in ipairs(ok and lines or NONE) do
        local id = q.questID
        if id and q.x and q.y and not q.isHidden and not q.inProgress and not ids[id] and not seen[id]
            and (q.floorLocation == nil or q.floorLocation == same) then
            seen[id] = true
            local u, v = K.ToWorld(zone, q.x, q.y)
            local pin = u and Pins.Add(offerSet, u, v, OFFER, { id = id, name = q.questName, line = q.questLineName })
            if pin then
                pin:SetScript("OnEnter", EnterOffer)
                pin:SetScript("OnLeave", GameTooltip_Hide)
            end
        end
    end
end

-- Les quêtes d'une zone, dans la lecture r
local function ReadMap(r, mapID)
    local have = G("HaveQuestData")
    for _, q in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or NONE) do
        local id = q.questID
        if id and q.x and q.y and not q.isMapIndicatorQuest and (not have or have(id)) then
            local u, v = K.ToWorld(mapID, q.x, q.y)
            local key = u and (id .. ":" .. math.floor(u / SAME) .. ":" .. math.floor(v / SAME))
            if key and not r.seen[key] then
                r.seen[key] = true
                r.ids[id] = true
                r.found[#r.found + 1] = { u, v, id, C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) or false, mapID }
            end
        end
    end
end

-- Tout lu : les icônes, d'un coup
local function Draw(r)
    if offerSet then
        Pins.Clear(offerSet)
        Pins.SetOn(offerSet, false)
    end
    if focusedPin then
        Style(focusedPin, false)
        focusedPin = nil
    end
    Pins.Clear(set)
    wipe(drawn)
    for _, f in ipairs(r.found) do
        local pin = Pins.Add(set, f[1], f[2], BADGE, { id = f[3], complete = f[4], map = f[5] })
        if pin then
            Mark(pin, f[4])
            pin:SetScript("OnEnter", Enter)
            pin:SetScript("OnLeave", Leave)
            pin.OnClick = Click
            drawn[#drawn + 1] = pin
        end
    end
    Focus()
    Offers(r.ids)
end

local Soon
local reader = CreateFrame("Frame")
reader:Hide()
reader:SetScript("OnUpdate", function(self)
    local r = reading
    if not r then
        self:Hide()
        return
    end
    local list = r.list
    local t0 = debugprofilestop and debugprofilestop()
    local n = 0
    while r.at <= #list do
        local mapID = list[r.at]
        r.at, n = r.at + 1, n + 1
        local ok, err = pcall(ReadMap, r, mapID)
        if not ok then
            reading = nil
            self:Hide()
            if geterrorhandler then geterrorhandler()(err) end
            return
        end
        if (t0 and debugprofilestop() - t0 >= READ_MS) or (not t0 and n >= 3) then break end
    end
    if r.at <= #list then return end
    reading = nil
    self:Hide()
    Draw(r)
    if dirty then Soon() end              -- (le journal a changé pendant la lecture : encore une fois)
end)

local function Clear()
    if offerSet then
        Pins.Clear(offerSet)
        Pins.SetOn(offerSet, false)
    end
    if focusedPin then
        Style(focusedPin, false)
        focusedPin = nil
    end
    if set then Pins.Clear(set) end
    wipe(drawn)
    V.QuestFocus(nil)
end

function ns.Map.RefreshQuests()
    dirty = false
    reading = nil
    reader:Hide()
    if not set and Pins.Ready() then set = Pins.Set("quests", 1, 5) end
    if not set then return end
    if not offerSet then offerSet = Pins.Set("questoffers", 1, 4) end   -- (sous les icônes des quêtes)
    -- (et comme les quêtes du jeu : pas avec ses objectifs de quête cachés, questPOI)
    local on = C_QuestLog.GetQuestsOnMap ~= nil and Settings.Get("questIcons") ~= false
        and not (GetCVarBool and not GetCVarBool("questPOI"))
    Pins.SetOn(set, on)
    if not on then
        Clear()
        return
    end
    -- (« toutes les zones » éteint : seulement la zone où est la carte du jeu)
    local list = Maps()
    if Settings.Get("allQuests") == false then
        local zone = V.GameMapID()
        list = zone and K.Rect(zone) and { zone } or NONE
    end
    reading = { list = list, at = 1, found = {}, seen = {}, ids = {} }
    reader:Show()
end

-- (une rafale de mises à jour du journal : un seul rafraîchissement)
Soon = function()
    dirty = true
    if waiting then return end
    waiting = true
    C_Timer.After(EVERY, function()
        waiting = false
        if dirty and not reading and ns.MapShown() then ns.Map.RefreshQuests() end
    end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, cvar)
    if event == "CVAR_UPDATE" and cvar ~= "questPOI" then return end
    if ns.MapShown() then Soon() end
end)

local hooked = false
local function Hook()
    if hooked then return end
    hooked = true
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED", "CVAR_UPDATE", "QUESTLINE_UPDATE" }) do
        pcall(events.RegisterEvent, events, e)
    end
    local map = _G.WorldMapFrame
    if map and type(map.OnMapChanged) == "function" then hooksecurefunc(map, "OnMapChanged", function() Soon() end) end
end

ns.On("MAP_BUILT", function()
    Hook()
    ns.Map.RefreshQuests()
end)
ns.On("MAP_SHOW", function() if ns.Map.IsBuilt() then Soon() end end)
-- (fermée pendant la lecture : elle reprend à la prochaine ouverture)
ns.On("MAP_HIDE", function()
    if reading then
        reading = nil
        reader:Hide()
        dirty = true
    end
end)
ns.On("MAP_REFRESH", function() if ns.Map.IsBuilt() and ns.MapShown() then Soon() end end)

-- (les ponts : la vue d'OpenMap, Map/PadView.lua, et mod:Refresh)
ns.On("MAP_ATTACHED", function()
    ns.Map.Migrate("quests", function(old, new)
        if old.questIcons ~= nil then new.settings.questIcons = old.questIcons end
        if old.allQuests ~= nil then new.settings.allQuests = old.allQuests end
    end)
    local mod = ns.Map.Legacy()
    if not mod then return end
    mod.SetupQuests = function() Hook() end
    mod.RefreshQuests = function() ns.Map.RefreshQuests() end
end)
