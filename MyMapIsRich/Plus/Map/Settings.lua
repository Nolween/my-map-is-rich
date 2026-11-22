-- Les réglages de la carte : ns.Map.Settings, et leur passage d'OpenMap à Plus.
--
-- Un réglage de la carte (un calque allumé, la plume, les épingles...) vit
-- encore dans les sauvegardes de la partie venue d'OpenMap (MyMapIsRichDB,
-- MyMapIsRichCharDB) tant que son module n'est pas réécrit. Quand il l'est,
-- sa clé passe dans les nôtres (MyMapIsRichPlusDB.map, et
-- MyMapIsRichPlusCharDB.map pour ce qui est propre au personnage) : OWNER le
-- dit, clé par clé. Settings.Get et Settings.Set lisent et écrivent au bon
-- endroit : le rail des calques n'a pas à savoir qui détient la clé.
--
-- Une migration (M.Migrate) copie, une fois, ce que le joueur avait (ses
-- épingles, ses dessins, ses vols appris) ; elle n'efface rien de l'ancien :
-- revenir à une version d'avant le retrouve. Chaque module réécrit migre ses
-- propres clés, dans la version qui le remplace.
local _, root = ...
local ns = root.Plus

local M = ns.Map
local Settings = {}
M.Settings = Settings

-- clé -> "new" quand elle vit chez nous ; absente : chez la carte d'OpenMap
-- (0.5.0 : toutes chez elle)
local OWNER = {}
Settings.OWNER = OWNER
local DEFAULT = {}        -- clé reprise -> sa valeur tant que le joueur n'y a pas touché

-- Une clé reprise par un module de Plus (sa valeur d'origine, si le joueur
-- n'en a pas) : elle vit désormais dans nos sauvegardes
function Settings.Own(key, default)
    OWNER[key] = "new"
    DEFAULT[key] = default
end

local function Old()
    local ok, mod = pcall(root.GetModule, root, "worldmap")
    return ok and type(mod) == "table" and mod or nil
end

-- Nos sauvegardes de la carte (créées au chargement : M.InitDB)
function M.DB() return ns.db and ns.db.map end
function M.CharDB() return ns.char and ns.char.map end

-- Un réglage du compte
function Settings.Get(key)
    if OWNER[key] == "new" then
        local db = M.DB()
        local v = db and db.settings[key]
        if v == nil then v = DEFAULT[key] end
        return v
    end
    local mod = Old()
    return mod and mod.db and mod.db[key]
end

function Settings.Set(key, value)
    if OWNER[key] == "new" then
        local db = M.DB()
        if db then db.settings[key] = value end
        return
    end
    local mod = Old()
    if mod and mod.db then mod.db[key] = value end
end

-- Un réglage du personnage
function Settings.Char(key)
    if OWNER[key] == "new" then
        local db = M.CharDB()
        return db and db.settings[key]
    end
    local mod = Old()
    return mod and mod.char and mod.char[key]
end

-- Les réglages du compte, comme une table (lire, écrire une clé) : pour le
-- rail des calques, qui les parcourt clé par clé
local proxy = setmetatable({}, {
    __index = function(_, key) return Settings.Get(key) end,
    __newindex = function(_, key, value) Settings.Set(key, value) end,
})
function Settings.Table()
    if M.Ready() then return proxy end
end

-- La carte se redessine d'après ses réglages
function Settings.Refresh()
    local mod = Old()
    if mod and type(mod.Refresh) == "function" then pcall(mod.Refresh, mod) end
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
