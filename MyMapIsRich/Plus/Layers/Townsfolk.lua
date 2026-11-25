-- Les citadins et les monstres rares sur la carte : en code de My Map Is Rich
-- depuis la 0.9.0 (ils venaient de Map/Townsfolk.lua, d'OpenMap). Ils lisaient
-- la base de Questie en jeu ; ils lisent maintenant celle de l'addon
-- (Data/Quests.lua, par Quests/Db.lua : leurs fonctions, leur sous-titre, leur
-- rang, leurs emplacements), et Questie n'est plus nécessaire.
-- Chaque sorte est un jeu d'icônes (« tf_<sorte> »), construit la première
-- fois qu'on l'allume, quelques centaines de PNJ par image (rien ne fige).
-- Le réglage « townsfolk » : { sorte = allumée } (le rail le remplit).
local _, root = ...
local ns = root.Plus
local L = ns.L

local Pins = ns.Map.Pins
local Settings = ns.Map.Settings

Settings.Own("townsfolk", nil)     -- (sa table est posée à la connexion : ci-dessous)

-- sorte -> son allure, le zoom d'où elle se montre, et ce qui choisit ses PNJ
-- (service : la fonction dans la base, Quests/Db.lua ; hostile : montrés aux deux
-- factions ; many : un même PNJ à beaucoup d'endroits, chacun le sien)
local KINDS = {
    { key = "vendor", service = "VENDOR", zoom = 8,
        look = { texture = "Interface\\GossipFrame\\VendorGossipIcon", size = 14 } },
    { key = "repair", service = "REPAIR", zoom = 6,
        look = { texture = "Interface\\Minimap\\Tracking\\Repair", fallback = "Interface\\GossipFrame\\VendorGossipIcon", size = 16 } },
    { key = "innkeeper", service = "INN", zoom = 4,
        look = { texture = "Interface\\Minimap\\Tracking\\Innkeeper", fallback = "Interface\\GossipFrame\\BinderGossipIcon", size = 16 } },
    { key = "banker", service = "BANKER", zoom = 6,
        look = { texture = "Interface\\Minimap\\Tracking\\Banker", fallback = "Interface\\GossipFrame\\BankerGossipIcon", size = 16 } },
    -- (les boîtes aux lettres : des objets du monde, pas des PNJ)
    { key = "mailbox", mailbox = true, zoom = 6, many = true,
        look = { texture = "Interface\\Minimap\\Tracking\\Mailbox", fallback = "Interface\\Icons\\INV_Letter_15", size = 16 } },
    { key = "auctioneer", service = "AUCTION", zoom = 6,
        look = { texture = "Interface\\Minimap\\Tracking\\Auctioneer", fallback = "Interface\\GossipFrame\\VendorGossipIcon", size = 16 } },
    { key = "stable", service = "STABLE", zoom = 6,
        look = { texture = "Interface\\Minimap\\Tracking\\StableMaster", fallback = "Interface\\GossipFrame\\PetitionGossipIcon", size = 16 } },
    { key = "classTrainer", service = "CLASS_TRAINER", class = true, zoom = 6,
        look = { texture = "Interface\\Minimap\\Tracking\\Class", fallback = "Interface\\GossipFrame\\TrainerGossipIcon", size = 16 } },
    { key = "profTrainer", service = "TRAINER", zoom = 8,
        look = { texture = "Interface\\Minimap\\Tracking\\Profession", fallback = "Interface\\GossipFrame\\TrainerGossipIcon", size = 14 } },
    -- (les esprits soigneurs : le jeu n'a pas de table des cimetières pour ce
    -- client ; un seul PNJ, le même pour les deux factions, à chaque cimetière)
    { key = "spirit", service = "SPIRIT", zoom = 3, hostile = true, many = true,
        look = { atlas = "poi-soulspiritghost", texture = "Interface\\Minimap\\ObjectIcons", size = 16 } },
    { key = "rare", rare = true, zoom = 3, hostile = true, many = true,
        look = { atlas = "VignetteKillElite", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", size = 18 } },
}

local RANK = { [2] = "TOWNSFOLK_RARE_ELITE", [4] = "TOWNSFOLK_RARE" }
local WANDER = 6                -- (au-delà de ce nombre d'emplacements, un PNJ qui marche : un seul point)

local built = {}                -- sorte -> vrai une fois ses icônes posées
local building = false

local function Folk()
    local t = Settings.Get("townsfolk")
    return type(t) == "table" and t or {}
end

local function Db() return ns.Quests and ns.Quests.Db end

-- Y a-t-il une base à lire ? (celle de l'addon : toujours, sauf fichier abîmé)
function ns.Map.Townsfolk.Has()
    local db = Db()
    return db and db.Has() or false
end
function ns.Map.Townsfolk.CanRefresh() return true end

-- Un PNJ qui marche (la fille aux chiots autour d'Orgrimmar) a chaque point de
-- son chemin parmi ses emplacements : un seul, le plus près de leur milieu
local function Middle(points)
    local su, sv = 0, 0
    for _, p in ipairs(points) do su, sv = su + p[1], sv + p[2] end
    su, sv = su / #points, sv / #points
    local best, bestD
    for _, p in ipairs(points) do
        local d = (p[1] - su) ^ 2 + (p[2] - sv) ^ 2
        if not bestD or d < bestD then best, bestD = p, d end
    end
    return { best }
end

local function PinEnter(pin)
    local n = pin.data
    if not n then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(n.name, 1, 0.82, 0)
    if n.sub then GameTooltip:AddLine(n.sub, 1, 1, 1) end
    local lv = n.min and n.min > 0 and (n.min == n.max and tostring(n.min) or (n.min .. "-" .. (n.max or n.min)))
    if lv or n.rank then
        GameTooltip:AddLine(((lv and ((LEVEL or "") .. " " .. lv)) or "") .. (n.rank and ("  " .. L[n.rank]) or ""), 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

-- Les PNJ (ref > 0) ou objets (ref < 0) d'une sorte : { ref, ... }
local function Members(db, k)
    if k.mailbox then
        local out = {}
        for i, id in ipairs(db.Mailboxes()) do out[i] = -id end
        return out
    end
    if k.rare then return db.Rares() end
    return db.Services(db[k.service], k.class and select(2, UnitClass("player")) or nil)
end

-- Les icônes des sortes voulues, quelques centaines de PNJ par image
local function Build(kinds, done)
    local db = Db()
    if not (db and db.Has()) then return done(false) end
    local side = UnitFactionGroup("player") == "Horde" and 2 or 1
    local jobs = {}
    for _, k in ipairs(kinds) do
        local set = Pins.Set("tf_" .. k.key, k.zoom, 3)
        if set then
            for _, ref in ipairs(Members(db, k)) do jobs[#jobs + 1] = { k, set, ref } end
        end
    end

    local function Place(k, set, ref)
        if not (k.hostile or bit.band(db.React(ref), side) ~= 0) then return end
        -- (sans les emplacements dans un donjon : la base les pose à son entrée)
        local points = {}
        for _, p in ipairs(db.Places(ref)) do
            if not p.inside then points[#points + 1] = p end
        end
        if #points == 0 then return end
        if not k.many and #points > WANDER then points = Middle(points) end
        local info
        if ref < 0 then
            info = { name = MINIMAP_TRACKING_MAILBOX or db.Name(ref) or "?" }
        else
            local npc = db.Npc(ref) or {}
            info = { name = db.Name(ref) or "?", sub = db.SubName(ref),
                min = npc.minLevel, max = npc.maxLevel, rank = RANK[npc.rank or 0] }
        end
        for _, p in ipairs(points) do
            local pin = Pins.Add(set, p[1], p[2], k.look, info)
            if pin then
                pin:SetScript("OnEnter", PinEnter)
                pin:SetScript("OnLeave", GameTooltip_Hide)
            end
        end
    end

    local i = 0
    local function Chunk()
        for _ = 1, 200 do
            i = i + 1
            local job = jobs[i]
            if not job then return true end
            Place(job[1], job[2], job[3])
        end
    end
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
    if #todo == 0 or building or not ns.Map.Townsfolk.Has() then return end
    building = true
    for _, k in ipairs(todo) do built[k.key] = true end
    Build(todo, function(ok)
        building = false
        if not ok then
            -- (une erreur, déjà montrée : ces sortes se reconstruiront au prochain rafraîchissement)
            for _, k in ipairs(todo) do
                built[k.key] = nil
                local set = Pins.Get("tf_" .. k.key)
                if set then Pins.Clear(set) end
            end
            return
        end
        ns.Map.Townsfolk.Refresh()
    end)
end

ns.On("MAP_BUILT", function() ns.Map.Townsfolk.Refresh() end)
ns.On("MAP_REFRESH", function() ns.Map.Townsfolk.Refresh() end)

-- (la migration : le réglage d'OpenMap repris, et sa table posée pour le rail)
ns.On("MAP_ATTACHED", function()
    ns.Map.Migrate("townsfolk", function(old, new, copy)
        if type(old.townsfolk) == "table" then new.settings.townsfolk = copy(old.townsfolk) end
    end)
    local db = ns.Map.DB()
    if db and type(db.settings.townsfolk) ~= "table" then db.settings.townsfolk = {} end
end)
