-- Les donjons sur la carte : leurs entrées, en code de My Map Is Rich depuis
-- la 0.10.0 (elles venaient de Map/Dungeons.lua d'OpenMap).
--   l'entrée       une icône de donjon ou de raid (Data/Forever/Places.lua, et
--                  celles que le jeu connaît en plus), ses niveaux dessous,
--                  colorés pour ton niveau ; survolée, ce qu'il y a là ;
--   le clic        la carte du donjon (Layers/DungeonView.lua) ; plusieurs
--                  donjons à la même entrée : un menu pour choisir ; avec
--                  « Les entrées ouvrent Dungeon Journal », sa page là-bas ;
--   à l'intérieur  la carte ouverte dans un donjon montre la sienne (réglage
--                  « Carte du donjon à l'intérieur ») ; un donjon où tu es
--                  entré compte comme trouvé (« Seulement les lieux trouvés »).
-- Les quêtes d'un donjon viennent de Questie (lues une fois, en tâche de
-- fond), ou de Dungeon Journal et NeedRoll (ouverts à sa page) : DN.QuestSource.
local _, root = ...
local ns = root.Plus
local L = ns.L

local DN = {}
ns.Dungeons = DN
local DG = ns.Map.Dungeons
local K = ns.Map.Coords
local Settings = ns.Map.Settings
local Get = Settings.Get

-- (les réglages des donjons, repris de la carte d'OpenMap)
local KEYS = {
    dungeonMaps = true,       -- l'entrée ouvre la carte du donjon (sinon : la carte s'en approche)
    dungeonBosses = true,     -- ses boss : l'onglet, et leurs icônes sur sa carte
    dungeonQuests = true,     -- l'onglet Quêtes
    dungeonMinimap = false,   -- d'abord les cartes tirées des images de la minicarte
    dungeonLevels = true,     -- les niveaux sous chaque entrée
    dungeonInside = true,     -- la carte ouverte dans un donjon montre la sienne
    questSource = "auto",     -- "questie", "journal", "needroll" ; "auto" : le premier installé
    entranceClick = "map",    -- "map", ou "journal" : sa page de Dungeon Journal
    dungeonTab = "floors",    -- l'onglet du panneau : floors, bosses, quests, loot
    dungeonHints = 0,         -- les cartes de donjon ouvertes avec l'aide (les premières)
    dungeonMapNoted = false,  -- le message « tu peux l'éteindre », déjà dit
}
for key, default in pairs(KEYS) do Settings.Own(key, default) end

local LOOK = {
    dungeon = { atlas = "dungeon", texture = "Interface\\Minimap\\ObjectIcons", size = 26 },
    raid = { atlas = "raid", texture = "Interface\\Minimap\\ObjectIcons", size = 26 },
}
-- l'étage où s'ouvre une partie d'un donjon (les noms des étages dans les données)
local WING_FLOORS = {
    ["Dire Maul - East"] = "Warpwood Quarter", ["Dire Maul - West"] = "Capital Gardens", ["Dire Maul - North"] = "Gordok Commons",
    ["Scarlet Monastery - Graveyard"] = "Graveyard", ["Scarlet Monastery - Library"] = "Library",
    ["Scarlet Monastery - Armory"] = "Armory", ["Scarlet Monastery - Cathedral"] = "Cathedral",
}
DN.WING_FLOORS = WING_FLOORS
local NEEDROLL_URL = "https://www.curseforge.com/wow/addons/needroll"
DN.NEEDROLL_URL = NEEDROLL_URL

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Call(fn, ...)
    local ok, v = pcall(fn, ...)
    if ok then return Plain(v) end
end

local function Places() return ns.Map.Data.Places() or {} end
DN.Places = Places

function DN.MapsOn() return Get("dungeonMaps") ~= false end

-- (la carte d'OpenMap lit encore dungeonMaps : Map/WorldMap.lua, jusqu'en 0.12.0)
local function Mirror()
    local mod = ns.Map.Legacy()
    if mod and mod.db then mod.db.dungeonMaps = DN.MapsOn() end
end

---------------------------------------------------------------------------
-- Un donjon des données : { mapID de l'instance (0 : inconnu du jeu), nom
-- anglais, raid, niveau mini, niveau maxi }
---------------------------------------------------------------------------
-- La place d'une entrée sur le monde : en yards sur son continent, ou un
-- point d'une carte de zone (« map = » dans Places.lua)
function K.EntranceAt(g)
    if type(g) ~= "table" then return end
    if g.map then return K.ToWorld(g.map, g[2], g[3]) end
    return K.FromYards(g[1], g[2], g[3])
end

-- Le nom d'un donjon dans la langue du joueur (celui du jeu), sinon celui des
-- données. Une partie d'un donjon (« Dire Maul - East ») garde son nom anglais
-- en anglais, et ailleurs prend le nom du donjon suivi du sien
local wings = {}
function K.InstanceName(inst)
    if type(inst) ~= "table" then return end
    local name = GetRealZoneText and inst[1] and inst[1] > 0 and Call(GetRealZoneText, inst[1])
    if not name or name == "" then return inst[2] end
    local wing = wings[inst]
    if wing == nil then
        wing = false
        local en = GetLocale and GetLocale():sub(1, 2) == "en"
        for _, g in ipairs(Places().instances or {}) do
            for _, other in ipairs(g[4]) do
                if other ~= inst and other[1] == inst[1] and other[2] ~= inst[2] then
                    wing = en and inst[2] or (name .. " (" .. inst[2] .. ")")
                end
            end
        end
        wings[inst] = wing
    end
    return wing or name
end

-- Ses niveaux dans les couleurs des quêtes pour toi (nil : les données n'en ont pas)
function DN.Range(inst)
    if not inst[4] then return end
    local code, range = ns.ZoneInfo.LevelColor(inst[4], inst[5] or inst[4])
    return code .. range .. "|r"
end
local Range = DN.Range

-- Ses étages : la carte de Blizzard tirée des fichiers du jeu, ou celle bâtie
-- avec les images de la minicarte (d'abord, avec le réglage) ; rend aussi
-- laquelle ("blizzard" ou "minimap"). Rien : le jeu n'a aucune carte de lui
DN.BLANK = { { blank = true } }
function DN.Floors(inst)
    local D = ns.Map.Data
    local mini = D.DungeonMinimap()
    local m = mini and inst[1] ~= 0 and mini[inst[1]]
    if m and Get("dungeonMinimap") then return m, "minimap" end
    local maps = D.DungeonMaps()
    local b = maps and maps[inst[1]]
    if b then return b, "blizzard" end
    if m then return m, "minimap" end
end

-- Le premier étage à montrer : celui de la partie du donjon
function DN.FirstFloor(inst, floors)
    for i, f in ipairs(floors) do
        if f.wing == inst[2] or (f.name and f.name == WING_FLOORS[inst[2]]) then return i end
    end
    return 1
end

---------------------------------------------------------------------------
-- Dungeon Journal (d'Exehn, pour WoW Forever : /dj) et NeedRoll (de mikebvs)
---------------------------------------------------------------------------
local function Journal()
    local dj = _G.ForeverDungeonJournal_NS
    if type(dj) == "table" and type(dj.DB) == "table" and type(dj.OpenBossPage) == "function" then return dj end
end
function DN.HasJournal() return Journal() ~= nil end

function DN.NeedRoll() return SlashCmdList and SlashCmdList.NEEDROLL end

-- (ses pages portent ses propres noms : « Scarlet Monastery: Graveyard »,
-- rapprochés des nôtres sans « The », casse ni ponctuation)
local function Loose(name)
    return ((name or ""):lower():gsub("^the ", ""):gsub("%s*[-:]%s*", ": "))
end
function DN.JournalName(inst)
    local dj = Journal()
    if not dj then return end
    local want = Loose(inst[2])
    for key, entry in pairs(dj.DB) do
        if type(entry) == "table" and not entry.previewOnly and Loose(key) == want then return key end
    end
end

-- Sa fenêtre à la page du donjon (ses boss, ou ses quêtes) ; false s'il n'en a pas
function DN.OpenJournal(inst, quests)
    local dj, key = Journal(), DN.JournalName(inst)
    if not key then return false end
    -- (montrée d'abord : elle s'ouvre sur la dernière page vue)
    local frame, toggle = _G.ForeverDungeonJournalFrame, _G.ForeverDungeonJournal_Toggle
    if not (frame and frame:IsShown()) and type(toggle) == "function" then pcall(toggle) end
    local open = quests and type(dj.OpenQuestPage) == "function" and dj.OpenQuestPage or dj.OpenBossPage
    return (pcall(open, key))
end

-- La fenêtre de NeedRoll : au butin du donjon (d'un boss), à sa carte
-- (what = "map") ou à une quête, par ses fonctions (NeedRoll_ShowLoot...) ;
-- sinon simplement ouverte. Le donjon par son nom anglais d'abord, puis par
-- le mapID de son instance, puis le boss seul
function DN.OpenNeedRoll(inst, boss, what, quest)
    if quest then
        local show = _G.NeedRoll_ShowQuest
        if type(show) == "function" then
            local ok, done = pcall(show, quest)
            if ok and done then return end
        end
    end
    local show = what == "map" and _G.NeedRoll_ShowMap or _G.NeedRoll_ShowLoot
    if type(show) == "function" and inst then
        local tries = { { inst[2], boss } }
        if inst[1] > 0 then tries[#tries + 1] = { inst[1], boss } end
        if boss then tries[#tries + 1] = { nil, boss } end
        for _, t in ipairs(tries) do
            local ok, done = pcall(show, t[1], t[2])
            if ok and done then return end
        end
    end
    for _, name in ipairs({ "NeedRollFrame", "NeedRollNativeFrame" }) do
        local f = _G[name]
        if f and f.IsShown and f:IsShown() then
            if f.Raise then f:Raise() end
            return
        end
    end
    local open = DN.NeedRoll()
    if open then pcall(open, "") end
end

---------------------------------------------------------------------------
-- Les quêtes de chaque donjon chez Questie (son zoneOrSort : la zone du
-- donjon), lues une fois, 500 par image
---------------------------------------------------------------------------
local quests                -- zone de Questie -> { questID, ... } (nil : pas lu ; false : raté, à refaire)
local scanning = false
local dungeonOf             -- zone d'une partie d'un donjon chez Questie -> celle du donjon

function DN.Questie()
    local loader = _G.QuestieLoader
    if not loader then return end
    local ok, db = pcall(loader.ImportModule, loader, "QuestieDB")
    local ok2, zones = pcall(loader.ImportModule, loader, "ZoneDB")
    if ok and ok2 and db and db.QuestPointers and db.QueryQuestSingle and zones and zones.GetDungeons then return db, zones end
end

-- D'où viennent les quêtes : celui choisi s'il est là, sinon le premier
-- installé de Questie (listées ici), Dungeon Journal, NeedRoll ; nil : aucun
function DN.QuestSource()
    local have = { questie = _G.QuestieLoader ~= nil, journal = Journal() ~= nil, needroll = DN.NeedRoll() ~= nil }
    local want = Get("questSource")
    if have[want] then return want end
    return have.questie and "questie" or have.journal and "journal" or have.needroll and "needroll" or nil
end

local function DungeonArea(zones, areaId)
    if not dungeonOf then
        local list = zones:GetDungeons()
        if not list then return end           -- (les zones de Questie pas encore lues : plus tard)
        dungeonOf = {}
        for base, e in pairs(list) do
            dungeonOf[base] = base
            for _, alt in ipairs(e[2] or {}) do dungeonOf[alt] = dungeonOf[alt] or base end
        end
    end
    return dungeonOf[areaId]
end

local function Scan(done)
    local QDB, zones = DN.Questie()
    if not QDB or not zones:GetDungeons() then return done(false) end
    local ids = {}
    for id in pairs(QDB.QuestPointers) do ids[#ids + 1] = id end
    local found, i = {}, 0
    local function Step()
        local ok, err = pcall(function()
            for _ = 1, 500 do
                i = i + 1
                local id = ids[i]
                if not id then return end
                local z = QDB.QueryQuestSingle(id, "zoneOrSort")
                local area = z and z > 0 and DungeonArea(zones, z)
                if area then
                    found[area] = found[area] or {}
                    table.insert(found[area], id)
                end
            end
        end)
        if not ok then
            if geterrorhandler then geterrorhandler()(err) end
            return done(false)
        end
        if ids[i] then C_Timer.After(0, Step) else done(found) end
    end
    Step()
end

function DN.Scanning() return scanning end

-- Les quêtes de Questie lues, une fois (puis after()) ; à refaire plus tard
-- si sa base n'était pas prête
function DN.EnsureQuests(after)
    if quests ~= nil or scanning or not DN.Questie() then return end
    scanning = true
    Scan(function(found)
        scanning = false
        quests = found or false
        if not found then
            C_Timer.After(15, function() if quests == false then quests = nil after() end end)
        end
        C_Timer.After(0, after)
    end)
end

-- Si tu peux la prendre : ta race et ta classe (les masques de Questie : 0 pour tous)
local function ForYou(QDB, id)
    local _, _, race = UnitRace("player")
    local _, _, class = UnitClass("player")
    local races = QDB.QueryQuestSingle(id, "requiredRaces") or 0
    local classes = QDB.QueryQuestSingle(id, "requiredClasses") or 0
    if race and races ~= 0 and bit.band(races, 2 ^ (race - 1)) == 0 then return false end
    if class and classes ~= 0 and bit.band(classes, 2 ^ (class - 1)) == 0 then return false end
    return true
end

local areaOf = {}           -- donjon -> sa zone chez Questie (false : aucune ; la chercher est lent)

-- Les quêtes d'un donjon que tu peux prendre, par niveau : { id, name,
-- level, done, inLog } ; nil tant qu'elles ne sont pas lues
function DN.QuestList(inst)
    local QDB, zones = DN.Questie()
    if not QDB or not quests or not inst then return end
    local area = areaOf[inst]
    if area == nil then
        for _, name in ipairs({ K.InstanceName(inst), inst[2] }) do
            local ok, byName = pcall(zones.GetAreaIdByName, zones, name)
            area = area or (ok and byName and DungeonArea(zones, byName)) or nil
        end
        areaOf[inst] = area or false
    end
    local list = {}
    for _, id in ipairs(area and quests[area] or {}) do
        if ForYou(QDB, id) then
            list[#list + 1] = { id = id, name = QDB.QueryQuestSingle(id, "name") or "?", level = QDB.QueryQuestSingle(id, "questLevel") or 0 }
        end
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.name < b.name
    end)
    for _, q in ipairs(list) do
        q.done = C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(q.id) or false
        q.inLog = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(q.id) and true or false
    end
    return list
end

-- La couleur d'une quête : celle du jeu pour sa difficulté, grise si faite
function DN.QuestColour(q)
    local c = q.level > 0 and GetQuestDifficultyColor and GetQuestDifficultyColor(q.level)
    if q.done then return "|cff808080" end
    return c and ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) or "|cffffffff"
end

---------------------------------------------------------------------------
-- Les entrées sur la carte
---------------------------------------------------------------------------
local entrancePins = {}

-- (les fichiers du premier étage demandés quand le curseur arrive sur
-- l'entrée : sa carte s'affiche aussitôt au clic)
local preload
local function Preload(pin)
    if not DN.MapsOn() then return end
    if not preload then
        preload = CreateFrame("Frame", nil, UIParent)
        preload:Hide()
        preload.tex = {}
    end
    local n = 0
    for _, inst in ipairs(pin.instances) do
        local floors = DN.Floors(inst)
        local f = floors and floors[DN.FirstFloor(inst, floors)]
        for _, file in ipairs(f and f.tiles or {}) do
            n = n + 1
            preload.tex[n] = preload.tex[n] or preload:CreateTexture()
            preload.tex[n]:SetTexture(file)
        end
    end
end

local function Enter(pin)
    Preload(pin)
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    for _, inst in ipairs(pin.instances) do
        GameTooltip:AddDoubleLine(K.InstanceName(inst), (Range(inst) or "") .. (inst[3] and ("  " .. L.DUNGEON_RAID) or ""),
            1, 0.82, 0, 1, 1, 1)
    end
    local one = #pin.instances == 1 and pin.instances[1]
    local bosses = one and (Places().bosses or {})[one[1]]
    if bosses and #bosses > 0 then GameTooltip:AddLine(L.DUNGEON_BOSSES_N:format(#bosses), 0.8, 0.8, 0.8) end
    local hint
    if not DN.MapsOn() then hint = L.DUNGEON_CLICK_CLOSER
    elseif not one then hint = L.DUNGEON_CLICK_PICK
    elseif Get("entranceClick") == "journal" and DN.JournalName(one) then hint = L.DUNGEON_CLICK_JOURNAL
    elseif DN.Floors(one) then hint = L.DUNGEON_CLICK_MAP
    else hint = L.DUNGEON_CLICK_NOMAP end
    GameTooltip:AddLine(hint, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- Ouvrir un donjon : sa page de Dungeon Journal (si c'est le réglage et qu'il
-- en a une), sinon sa carte. inside : ouverte parce que tu es dedans
function DN.Open(inst, pin, inside)
    if not inst then return end
    if not inside and Get("entranceClick") == "journal" and DN.OpenJournal(inst) then return end
    if ns.DungeonView then ns.DungeonView.Open(inst, pin, inside) end
end
DG.Open = DN.Open

-- Plusieurs donjons à une entrée : le menu de la carte pour choisir, à côté d'elle
local function Choose(pin)
    local items = {}
    for _, inst in ipairs(pin.instances) do
        local extra = (Range(inst) and ("  " .. Range(inst)) or "")
            .. (inst[3] and ("  " .. ns.UI.Hex("textDim") .. L.DUNGEON_RAID .. "|r") or "")
        items[#items + 1] = { K.InstanceName(inst) .. extra, function() DN.Open(inst, pin) end }
    end
    local x, y = pin:GetCenter()
    local es = pin:GetEffectiveScale()
    ns.UI.ShowMenu(items, x and x * es, y and y * es, L.DUNGEON_PICK)
end

local function Click(pin)
    GameTooltip:Hide()
    if #pin.instances == 1 then return DN.Open(pin.instances[1], pin) end
    Choose(pin)
end

-- Les niveaux sous l'icône : du plus bas au plus haut (plusieurs donjons à une entrée)
local LABEL_FONT = _G.GameFontHighlightSmallOutline and "GameFontHighlightSmallOutline" or "GameFontHighlightSmall"
local function Label(pin)
    local lo, hi
    for _, inst in ipairs(pin.instances) do
        if inst[4] then lo, hi = math.min(lo or 99, inst[4]), math.max(hi or 0, inst[5] or inst[4]) end
    end
    if not pin.levelText then
        pin.levelText = pin:CreateFontString(nil, "OVERLAY", LABEL_FONT)
        pin.levelText:SetPoint("TOP", pin, "BOTTOM", 0, 3)
        pin.levelText:SetShadowColor(0, 0, 0, 1)
        pin.levelText:SetShadowOffset(1, -1)
    end
    local code, range
    if lo then code, range = ns.ZoneInfo.LevelColor(lo, hi) end
    pin.levelText:SetText(range and Get("dungeonLevels") ~= false and (code .. range .. "|r") or "")
end

local function Relabel()
    for _, pin in ipairs(entrancePins) do
        if pin.instances then Label(pin) end
    end
end

-- Les entrées (le dessin de la carte les demande : Map/Stitch.lua, BuildPins) :
-- celles des données, puis celles que le jeu connaît (son journal des
-- rencontres, s'il en a un) pour un donjon dont les données n'ont pas l'entrée
function DN.BuildPins(set)
    wipe(entrancePins)
    local P = ns.Map.Pins
    local places = Places()
    local function Pin(u, v, insts, cont, x, y)
        local raid = true
        for _, inst in ipairs(insts) do raid = raid and inst[3] and true or false end
        local pin = P.Add(set, u, v, raid and LOOK.raid or LOOK.dungeon)
        if not pin then return end
        pin.instances, pin.cont, pin.x, pin.y = insts, cont, x, y
        pin:SetScript("OnEnter", Enter)
        pin:SetScript("OnLeave", GameTooltip_Hide)
        pin.OnClick = Click
        Label(pin)
        entrancePins[#entrancePins + 1] = pin
    end
    for _, g in ipairs(places.instances or {}) do
        local u, v = K.EntranceAt(g)
        if u then
            if g.map then Pin(u, v, g[4]) else Pin(u, v, g[4], g[1], g[2], g[3]) end
        end
    end
    local entrances = C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap
    if entrances and C_Map.GetMapChildrenInfo then
        local known = {}
        for _, g in ipairs(places.instances or {}) do
            for _, inst in ipairs(g[4]) do
                known[inst[2]] = true
                known[K.InstanceName(inst)] = true
            end
        end
        local unplaced = {}
        for _, inst in ipairs(places.unplaced or {}) do unplaced[inst[2]] = inst end
        local okZ, zones = pcall(C_Map.GetMapChildrenInfo, K.World(), Enum.UIMapType.Zone, true)
        for _, zone in ipairs(okZ and zones or {}) do
            -- (les zones dessinées seulement : le monde d'un client en laisse de côté)
            local l, r, t, b
            if K.Stitched(zone.mapID) then l, r, t, b = K.Rect(zone.mapID) end
            local ok, list = pcall(entrances, zone.mapID)
            for _, e in ipairs(ok and l and list or {}) do
                local name = Plain(e.name)
                local pos = e.position
                local x, y
                if type(pos) == "table" then
                    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
                end
                x, y = Plain(x), Plain(y)
                if name and x and y and not known[name] then
                    known[name] = true
                    Pin(l + x * (r - l), t + y * (b - t), { unplaced[name] or { 0, name, false } })
                end
            end
        end
    end
    return entrancePins
end

-- L'entrée (son icône) d'un donjon, si elle est sur la carte
local function EntrancePin(inst)
    for _, pin in ipairs(entrancePins) do
        for _, other in ipairs(pin.instances or {}) do
            if other == inst then return pin end
        end
    end
end

---------------------------------------------------------------------------
-- À l'intérieur d'un donjon
---------------------------------------------------------------------------
local function InstanceID()
    if not (IsInInstance and Plain((IsInInstance()))) then return end
    local id = Plain((select(8, GetInstanceInfo())))
    if id and id ~= 0 then return id end
end

-- Le donjon où tu es, tel que les données l'ont (et son entrée) ; un donjon
-- sans entrée connue aussi (unplaced)
function DN.InstanceHere()
    local id = InstanceID()
    if not id then return end
    local places = Places()
    for _, g in ipairs(places.instances or {}) do
        for _, inst in ipairs(g[4]) do
            if inst[1] == id then return inst, g end
        end
    end
    for _, inst in ipairs(places.unplaced or {}) do
        if inst[1] == id then return inst end
    end
end

-- Si tu es dans ce donjon-là
function DN.Inside(inst)
    return inst and inst[1] and inst[1] ~= 0 and InstanceID() == inst[1] or false
end

-- La vue du monde autour de l'entrée du donjon où tu es (tes coordonnées n'y
-- sont pas sur la carte du monde) : u, v, zoom
function DN.EntranceView()
    local _, g = DN.InstanceHere()
    if not g then return end
    local u, v = K.EntranceAt(g)
    if not u then return end
    local chain = K.ChainAt(u, v)
    local fit = ns.Map.View.FitZoom(chain[#chain])
    return u, v, fit and math.min(fit, Get("maxZoom") or math.huge) or nil
end

-- Les donjons où ce personnage est entré : comptés comme trouvés (une entrée
-- que les morceaux explorés ne couvrent pas, sous l'eau ou atteinte par la
-- recherche de groupe, ne se montrait jamais)
function DN.Entered(pin)
    local char = ns.Map.CharDB()
    local seen = char and char.entered
    if not seen or not pin.instances then return false end
    for _, inst in ipairs(pin.instances) do
        if seen[inst[1]] then return true end
    end
    return false
end

local function NoteEntered()
    local inst = DN.InstanceHere()
    local char = ns.Map.CharDB()
    if not inst or inst[1] == 0 or not char then return end
    char.entered = char.entered or {}
    if char.entered[inst[1]] then return end
    char.entered[inst[1]] = true
    ns.Map.Pins.RefreshFound()
end

-- La carte ouverte dans un donjon : la sienne. Pas là où Dungeon Journal ou
-- NeedRoll montrent la leur (ils posent leurs boss dessus)
local function OpenInside()
    if not ns.MapShown() or DG.Shown() then return end
    local inst = DN.InstanceHere()
    if not inst or not DN.MapsOn() or Get("dungeonInside") == false then return end
    if DN.JournalName(inst) or DN.NeedRoll() then return end
    if not Get("dungeonMapNoted") then
        Settings.Set("dungeonMapNoted", true)
        ns.Print(L.DUNGEON_INSIDE_NOTE)
    end
    local pin = EntrancePin(inst)
    if not pin then
        local u, v = DN.EntranceView()
        pin = u and { u = u, v = v } or nil
    end
    DN.Open(inst, pin, true)
end

---------------------------------------------------------------------------
-- Les réglages : l'entrée ouvre la carte du donjon (le rail des calques)
---------------------------------------------------------------------------
function DG.MapsOn() return DN.MapsOn() end
function DG.CanSetMaps() return true end
function DG.SetMaps(on)
    Settings.Set("dungeonMaps", on and true or false)
    Mirror()
    if not on and DG.Shown() then DG.Close() end
    Settings.Refresh()
end
-- L'onglet choisi du panneau de la carte d'un donjon
function DG.Tab() return Get("dungeonTab") end

-- Les réglages ont changé (MAP_REFRESH) : les niveaux, la carte ouverte
function DN.Refresh()
    Relabel()
    if ns.DungeonView then ns.DungeonView.Refresh() end
end

---------------------------------------------------------------------------
-- Ce que le reste de la carte d'OpenMap appelle encore (Map/PadView.lua,
-- Stitch.lua, Sketch.lua, WorldMap.lua) : branché sur ce module
---------------------------------------------------------------------------
local function Bridge()
    local mod, S = ns.Map.Legacy()
    if not mod then return end
    mod.DungeonMapsOn = DN.MapsOn
    mod.SetDungeonMaps = DG.SetMaps
    mod.DungeonViewShown = function() return DG.Shown() end
    -- (X à la manette ; ou la carte qui se ferme : alors sans bruit, le monde laissé tel quel)
    mod.CloseDungeonView = function() DG.Close(not ns.MapShown()) end
    mod.DungeonDraw = function(on) DG.Draw(on) end
    mod.DungeonDrawing = function() return DG.Drawing() end
    mod.InstanceEntranceView = DN.EntranceView
    if S then
        S.BuildDungeonPins = DN.BuildPins
        S.Entered = DN.Entered
        S.EntranceAt = K.EntranceAt
    end
    Mirror()
end

local function Migrate()
    -- (les réglages et les boss placés à la main, une fois)
    ns.Map.Migrate("dungeons", function(old, new, copy)
        for key in pairs(KEYS) do
            if old[key] ~= nil then new.settings[key] = copy(old[key]) end
        end
        if type(old.bossPlaced) == "table" then new.bossPlaced = copy(old.bossPlaced) end
    end)
    -- (les donjons où ce personnage est entré)
    ns.Map.Migrate("dungeonsEntered", function(old, new, copy)
        if type(old.entered) == "table" then new.entered = copy(old.entered) end
    end, true)
end

ns.On("MAP_ATTACHED", function()
    Migrate()
    Bridge()
end)
ns.On("MAP_REFRESH", DN.Refresh)
ns.On("MAP_SHOW", function() C_Timer.After(0.1, OpenInside) end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LEVEL_UP" then
        -- (UnitLevel suit l'évènement un instant après)
        C_Timer.After(0, DN.Refresh)
        return
    end
    -- (un instant après l'écran de chargement)
    C_Timer.After(2, NoteEntered)
end)
