-- Les citadins et les monstres rares sur la carte, tirés de la base de PNJ de
-- Questie (leurs fonctions, leur rang, leurs emplacements) : en code de My
-- Map Is Rich depuis la 0.9.0 (ils venaient de Map/Townsfolk.lua, d'OpenMap).
-- Chaque sorte est un jeu d'icônes (« tf_<sorte> »), construit la première
-- fois qu'on l'allume, quelques centaines de PNJ par image (rien ne fige).
-- Sans Questie, le calque Citadins du rail est grisé (UI/Layers.lua).
-- Le réglage « townsfolk » : { sorte = allumée } (le rail le remplit).
local _, root = ...
local ns = root.Plus
local L = ns.L

local K = ns.Map.Coords
local Pins = ns.Map.Pins
local Settings = ns.Map.Settings

Settings.Own("townsfolk", nil)     -- (sa table est posée à la connexion : ci-dessous)

-- sorte -> son allure, le zoom d'où elle se montre, et ce qui choisit ses PNJ
local KINDS = {
    { key = "vendor", flag = "VENDOR", zoom = 8,
        look = { texture = "Interface\\GossipFrame\\VendorGossipIcon", size = 14 } },
    { key = "repair", flag = "REPAIR", zoom = 6,
        look = { texture = "Interface\\Minimap\\Tracking\\Repair", fallback = "Interface\\GossipFrame\\VendorGossipIcon", size = 16 } },
    { key = "innkeeper", flag = "INNKEEPER", zoom = 4,
        look = { texture = "Interface\\Minimap\\Tracking\\Innkeeper", fallback = "Interface\\GossipFrame\\BinderGossipIcon", size = 16 } },
    { key = "banker", flag = "BANKER", zoom = 6,
        look = { texture = "Interface\\Minimap\\Tracking\\Banker", fallback = "Interface\\GossipFrame\\BankerGossipIcon", size = 16 } },
    -- (les boîtes aux lettres : des objets, pas des PNJ ; la liste de Questie)
    { key = "mailbox", mailbox = true, zoom = 6,
        look = { texture = "Interface\\Minimap\\Tracking\\Mailbox", fallback = "Interface\\Icons\\INV_Letter_15", size = 16 } },
    { key = "auctioneer", flag = "AUCTIONEER", zoom = 6,
        look = { texture = "Interface\\Minimap\\Tracking\\Auctioneer", fallback = "Interface\\GossipFrame\\VendorGossipIcon", size = 16 } },
    { key = "stable", flag = "STABLEMASTER", zoom = 6,
        look = { texture = "Interface\\Minimap\\Tracking\\StableMaster", fallback = "Interface\\GossipFrame\\PetitionGossipIcon", size = 16 } },
    { key = "classTrainer", flag = "TRAINER", class = true, zoom = 6,
        look = { texture = "Interface\\Minimap\\Tracking\\Class", fallback = "Interface\\GossipFrame\\TrainerGossipIcon", size = 16 } },
    { key = "profTrainer", flag = "TRAINER", profession = true, zoom = 8,
        look = { texture = "Interface\\Minimap\\Tracking\\Profession", fallback = "Interface\\GossipFrame\\TrainerGossipIcon", size = 14 } },
    -- (les esprits soigneurs : le jeu n'a pas de table des cimetières pour ce
    -- client, ils viennent des PNJ de Questie, le même pour les deux factions)
    { key = "spirit", ids = { [6491] = true }, zoom = 3, hostile = true,
        look = { atlas = "poi-soulspiritghost", texture = "Interface\\Minimap\\ObjectIcons", size = 16 } },
    { key = "rare", rare = true, zoom = 3, hostile = true,
        look = { atlas = "VignetteKillElite", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", size = 18 } },
}

local RANK = { [2] = "TOWNSFOLK_RARE_ELITE", [4] = "TOWNSFOLK_RARE" }
-- (le nom anglais des classes, comme le donnent les sous-titres de Questie sur tous les clients)
local ENGLISH_CLASS_NAMES = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid", DEATHKNIGHT = "Death Knight",
    MONK = "Monk", DEMONHUNTER = "Demon Hunter", EVOKER = "Evoker",
}
local WANDER = 6                -- (au-delà de ce nombre d'emplacements dans une zone, un PNJ qui marche : un seul point)

local built = {}                -- sorte -> vrai une fois ses icônes posées
local building = false
local tries = 0                 -- (les essais pendant que la base de Questie se charge)
local told = false              -- (dit une fois que Questie n'est pas là)

local function Folk()
    local t = Settings.Get("townsfolk")
    return type(t) == "table" and t or {}
end

-- Y a-t-il une base à lire (Questie) ?
function ns.Map.Townsfolk.Has()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return _G.QuestieLoader ~= nil or (loaded and loaded("Questie")) and true or false
end
function ns.Map.Townsfolk.CanRefresh() return true end

local function Questie()
    local loader = _G.QuestieLoader
    if not loader then return end
    local ok, db = pcall(loader.ImportModule, loader, "QuestieDB")
    local ok2, zones = pcall(loader.ImportModule, loader, "ZoneDB")
    if ok and ok2 and db and db.NPCPointers and db.QueryNPCSingle and zones then return db, zones end
end

-- Un PNJ qui marche (la fille aux chiots autour d'Orgrimmar) a chaque point de
-- son chemin parmi ses emplacements : un seul, le plus près de leur milieu
local function Middle(coords)
    local sx, sy, n = 0, 0, 0
    for _, c in ipairs(coords) do
        if c[1] and c[1] >= 0 then sx, sy, n = sx + c[1], sy + c[2], n + 1 end
    end
    if n == 0 then return coords end
    sx, sy = sx / n, sy / n
    local best, bestD
    for _, c in ipairs(coords) do
        if c[1] and c[1] >= 0 then
            local d = (c[1] - sx) ^ 2 + (c[2] - sy) ^ 2
            if not bestD or d < bestD then best, bestD = c, d end
        end
    end
    return { best }
end

local function PinEnter(pin)
    local n = pin.data
    if not n then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(n.name, 1, 0.82, 0)
    if n.sub then GameTooltip:AddLine(n.sub, 1, 1, 1) end
    local lv = n.min and (n.min == n.max and tostring(n.min) or (n.min .. "-" .. (n.max or n.min)))
    if lv or n.rank then
        GameTooltip:AddLine(((lv and ((LEVEL or "") .. " " .. lv)) or "") .. (n.rank and ("  " .. L[n.rank]) or ""), 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

-- Tous les PNJ voulus, rangés par sorte ; puis les icônes des sortes allumées
local function Build(kinds, done)
    local QDB, ZoneDB = Questie()
    if not QDB then return done(false) end
    local flags = QDB.npcFlags or {}
    local faction = UnitFactionGroup("player") == "Horde" and "H" or "A"
    local myClass = select(2, UnitClass("player"))
    -- (la classe d'un maître de classe d'après son sous-titre : en anglais ou
    -- traduit par Questie, les deux cherchés en minuscules, les plus longs d'abord)
    local classNames = {}
    local function AddNames(t)
        for token, n in pairs(t or {}) do
            if type(n) == "string" and n ~= "" then classNames[#classNames + 1] = { n:lower(), token } end
        end
    end
    AddNames(ENGLISH_CLASS_NAMES)
    AddNames(LOCALIZED_CLASS_NAMES_MALE)
    AddNames(LOCALIZED_CLASS_NAMES_FEMALE)
    table.sort(classNames, function(a, b) return #a[1] > #b[1] end)

    -- les icônes d'une sorte à chacun de ses emplacements ({ [areaID] = { { x, y } } })
    local function Place(k, spawns, info, walker)
        local set = Pins.Set("tf_" .. k.key, k.zoom, 3)
        if not set then return end
        for areaID, coords in pairs(spawns) do
            if walker and #coords > WANDER then coords = Middle(coords) end
            local okZ, uiMapID = pcall(ZoneDB.GetUiMapIdByAreaId, ZoneDB, areaID)
            local l, r, t, b
            if okZ and uiMapID then l, r, t, b = K.Rect(uiMapID) end
            if l then
                for _, c in ipairs(coords) do
                    if c[1] and c[1] >= 0 then
                        local pin = Pins.Add(set, l + c[1] / 100 * (r - l), t + c[2] / 100 * (b - t), k.look, info)
                        if pin then
                            pin:SetScript("OnEnter", PinEnter)
                            pin:SetScript("OnLeave", GameTooltip_Hide)
                        end
                    end
                end
            end
        end
    end
    -- les boîtes aux lettres, d'un coup (quelques dizaines d'objets) : celles de ta faction
    local function Mailboxes(k)
        local okF, folk = pcall(_G.QuestieLoader.ImportModule, _G.QuestieLoader, "Townsfolk")
        if not okF or type(folk) ~= "table" or not folk.GetMailboxes or not QDB.QueryObjectSingle then return end
        local list
        if folk.GetFactionSpecificMailboxes then
            local ok, alliance, horde = pcall(folk.GetFactionSpecificMailboxes)
            if ok then list = faction == "H" and horde or alliance end
        end
        list = (type(list) == "table" and #list > 0) and list or folk.GetMailboxes() or {}
        local info = { name = MINIMAP_TRACKING_MAILBOX or "?" }
        for _, id in ipairs(list) do
            local spawns = QDB.QueryObjectSingle(id, "spawns")
            if spawns then Place(k, spawns, info) end
        end
    end

    local ids = {}
    for id in pairs(QDB.NPCPointers) do ids[#ids + 1] = id end
    local i = 0
    local function Chunk()
        for _ = 1, 400 do
            i = i + 1
            local id = ids[i]
            if not id then return true end
            local f = QDB.QueryNPCSingle(id, "npcFlags") or 0
            local rank = QDB.QueryNPCSingle(id, "rank") or 0
            local want = {}
            for _, k in ipairs(kinds) do
                local hit
                if k.ids then
                    hit = k.ids[id] or false
                elseif k.rare then
                    hit = RANK[rank] ~= nil
                elseif flags[k.flag] and bit.band(f, flags[k.flag]) ~= 0 then
                    hit = true
                    if k.class or k.profession then
                        local sub = (QDB.QueryNPCSingle(id, "subName") or ""):lower()
                        local cls
                        for _, c in ipairs(classNames) do
                            if sub:find(c[1], 1, true) then
                                cls = c[2]
                                break
                            end
                        end
                        if k.class then hit = cls ~= nil and cls == myClass else hit = cls == nil end
                    end
                end
                if hit then want[#want + 1] = k end
            end
            if #want > 0 then
                local friendly = QDB.QueryNPCSingle(id, "friendlyToFaction") or ""
                local spawns = QDB.QueryNPCSingle(id, "spawns")
                local info = {
                    name = QDB.QueryNPCSingle(id, "name") or "?", sub = QDB.QueryNPCSingle(id, "subName"),
                    min = QDB.QueryNPCSingle(id, "minLevel"), max = QDB.QueryNPCSingle(id, "maxLevel"), rank = RANK[rank],
                }
                for _, k in ipairs(want) do
                    -- (pas les esprits soigneurs ni les rares : un même PNJ à beaucoup d'endroits, chacun le sien)
                    if (k.hostile or friendly:find(faction, 1, true)) and spawns then Place(k, spawns, info, not (k.ids or k.rare)) end
                end
            end
        end
    end
    local npcs = false
    for _, k in ipairs(kinds) do
        if k.mailbox then
            local ok, err = pcall(Mailboxes, k)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        else
            npcs = true
        end
    end
    if not npcs then return done(true) end
    local function Step()
        local ok, finished = pcall(Chunk)
        if not ok then
            if geterrorhandler then geterrorhandler()(finished) end
            return done(false)
        end
        if finished then return done(true) end
        C_Timer.After(0, Step)
    end
    Step()
end

-- Chaque sorte montrée ou cachée ; les sortes allumées pour la première fois construites
function ns.Map.Townsfolk.Refresh()
    if not Pins.Ready() then return end
    local folk, todo = Folk(), {}
    for _, k in ipairs(KINDS) do
        local on = folk[k.key] and true or false
        if on and not built[k.key] then todo[#todo + 1] = k end
        local set = Pins.Get("tf_" .. k.key)
        if set then Pins.SetOn(set, on) end
    end
    if #todo == 0 or building then return end
    -- (pas de Questie du tout, pas seulement sa base encore en chargement : rien à attendre)
    if not ns.Map.Townsfolk.Has() then
        if not told then
            told = true
            ns.Print(L.TOWNSFOLK_NEED_QUESTIE)
        end
        return
    end
    building = true
    for _, k in ipairs(todo) do built[k.key] = true end
    Build(todo, function(ok)
        building = false
        if not ok then
            -- (la base de Questie pas encore prête, elle se charge après la connexion : un peu plus tard)
            for _, k in ipairs(todo) do
                built[k.key] = nil
                local set = Pins.Get("tf_" .. k.key)
                if set then Pins.Clear(set) end
            end
            tries = tries + 1
            if tries <= 12 then
                C_Timer.After(5, ns.Map.Townsfolk.Refresh)
            else
                ns.Print(L.TOWNSFOLK_NO_DB)
            end
            return
        end
        tries = 0
        ns.Map.Townsfolk.Refresh()
    end)
end

ns.On("MAP_BUILT", function() ns.Map.Townsfolk.Refresh() end)
ns.On("MAP_REFRESH", function() ns.Map.Townsfolk.Refresh() end)

-- (la migration : le réglage d'OpenMap repris, et sa table posée pour le
-- rail ; les ponts : la vue d'OpenMap, Map/PadView.lua, et mod:Refresh)
ns.On("MAP_ATTACHED", function()
    ns.Map.Migrate("townsfolk", function(old, new, copy)
        if type(old.townsfolk) == "table" then new.settings.townsfolk = copy(old.townsfolk) end
    end)
    local db = ns.Map.DB()
    if db and type(db.settings.townsfolk) ~= "table" then db.settings.townsfolk = {} end
    local mod = ns.Map.Legacy()
    if not mod then return end
    mod.RefreshTownsfolk = function() ns.Map.Townsfolk.Refresh() end
    mod.HasTownsfolk = function() return ns.Map.Townsfolk.Has() end
end)
