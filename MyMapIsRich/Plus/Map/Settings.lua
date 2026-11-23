-- Les réglages de la carte : ns.Map.Settings, et leur passage d'OpenMap à Plus.
--
-- Un réglage de la carte (un calque allumé, la plume, les épingles...) vit
-- dans MyMapIsRichPlusDB.map, et MyMapIsRichPlusCharDB.map pour ce qui est
-- propre au personnage. Chaque module déclare ses clés et leur valeur
-- d'origine (Settings.Own) ; le rail des calques les lit et les écrit par
-- Settings.Get et Settings.Set.
--
-- Avant la 1.0.0, ils vivaient dans les sauvegardes de la carte d'OpenMap
-- (MyMapIsRichDB, MyMapIsRichCharDB, toujours déclarées dans le .toc). Une
-- migration (M.Migrate) copie, une fois, ce que le joueur y avait (ses
-- épingles, ses dessins, ses vols appris) ; elle n'efface rien de l'ancien :
-- revenir à une version d'avant le retrouve. Un personnage secondaire migre
-- à sa propre connexion.
local _, root = ...
local ns = root.Plus

local M = ns.Map
local Settings = {}
M.Settings = Settings

local DEFAULT = {}        -- clé -> sa valeur tant que le joueur n'y a pas touché

-- Une clé d'un module de la carte, et sa valeur d'origine (si le joueur n'en a pas)
function Settings.Own(key, default)
    DEFAULT[key] = default
end

-- Nos sauvegardes de la carte (créées au chargement : M.InitDB)
function M.DB() return ns.db and ns.db.map end
function M.CharDB() return ns.char and ns.char.map end

-- Un réglage du compte
function Settings.Get(key)
    local db = M.DB()
    local v = db and db.settings[key]
    if v == nil then v = DEFAULT[key] end
    return v
end

function Settings.Set(key, value)
    local db = M.DB()
    if db then db.settings[key] = value end
end

-- Un réglage du personnage
function Settings.Char(key)
    local db = M.CharDB()
    return db and db.settings[key]
end

function Settings.SetChar(key, value)
    local db = M.CharDB()
    if db then db.settings[key] = value end
end

-- La valeur d'origine d'un réglage (nil : il n'en a pas)
function Settings.Default(key) return DEFAULT[key] end

-- Les réglages du compte, comme une table (lire, écrire une clé) : pour le
-- rail des calques, qui les parcourt clé par clé
local proxy = setmetatable({}, {
    __index = function(_, key) return Settings.Get(key) end,
    __newindex = function(_, key, value) Settings.Set(key, value) end,
})
function Settings.Table()
    if M.Ready() then return proxy end
end

-- La carte se redessine d'après ses réglages (Map/Look.lua ; « MAP_REFRESH »)
function Settings.Refresh()
    if M.Look and M.Look.Refresh then M.Look.Refresh() end
end

-- La page des réglages de la carte : l'onglet Carte de /mmir (UI/MapPage.lua)
function Settings.OpenPage() M.Menu.Open() end

---------------------------------------------------------------------------
-- Les sauvegardes et les migrations
---------------------------------------------------------------------------
local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end
M.Copy = Copy

-- (au chargement, Plus/Core.lua : nos tables de la carte, prêtes)
function M.InitDB()
    local db = ns.db
    db.map = db.map or {}
    db.map.settings = db.map.settings or {}
    db.map.migrated = db.map.migrated or {}
    local char = ns.char
    char.map = char.map or {}
    char.map.settings = char.map.settings or {}
    char.map.migrated = char.map.migrated or {}
end

-- Les anciennes sauvegardes de la carte (celles d'OpenMap), telles qu'elles
-- sont sur le disque : lues directement, sans attendre la carte
function M.OldDB()
    local t = _G.MyMapIsRichDB
    return type(t) == "table" and type(t.worldmap) == "table" and t.worldmap or nil
end
function M.OldCharDB()
    local t = _G.MyMapIsRichCharDB
    return type(t) == "table" and type(t.worldmap) == "table" and t.worldmap or nil
end

-- Une migration, faite une seule fois (par compte, ou par personnage) :
-- fn(old, new, copy) copie ce qu'il faut de old (les anciennes sauvegardes)
-- vers new (les nôtres). Une erreur la laisse à refaire à la connexion suivante.
function M.Migrate(name, fn, perChar)
    local new = perChar and M.CharDB() or M.DB()
    if not new or new.migrated[name] then return end
    local old = perChar and M.OldCharDB() or M.OldDB()
    if old then
        local ok, err = pcall(fn, old, new, Copy)
        if not ok then
            if geterrorhandler then geterrorhandler()(err) end
            return
        end
    end
    new.migrated[name] = true
end

---------------------------------------------------------------------------
-- À la déconnexion : un nombre NaN ou infini dans les sauvegardes s'écrit en
-- un texte que le jeu ne sait pas relire, et tout le fichier est perdu (tous
-- les réglages revenus à leur valeur d'origine à la connexion suivante). On
-- les retire avant (le même soin qu'OpenMap prenait de ses sauvegardes).
---------------------------------------------------------------------------
local function Scrub(t, seen)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
        if type(v) == "number" and (v ~= v or v == math.huge or v == -math.huge) then t[k] = nil
        elseif type(v) == "table" then Scrub(v, seen) end
    end
end

local logout = CreateFrame("Frame")
logout:RegisterEvent("PLAYER_LOGOUT")
logout:SetScript("OnEvent", function()
    Scrub(ns.db, {})
    Scrub(ns.char, {})
end)
