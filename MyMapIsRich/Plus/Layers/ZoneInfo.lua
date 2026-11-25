-- Le nom du lieu sous le curseur, avec les niveaux de sa zone et la pêche :
-- en code de My Map Is Rich depuis la 0.9.0 (il venait de Map/Extras.lua).
--   les niveaux  ceux de la zone (Data/Map/Levels.lua), colorés pour ton
--                niveau comme les quêtes du jeu : au-dessus de toi rouge ou
--                orange, le tien jaune, en dessous vert, puis gris ;
--   la pêche     pour qui la connaît : la compétence où chaque lancer prend
--                (Data/Map/Fishing.lua : la base + 95), vert dès là,
--                jaune dès la moitié, rouge en dessous.
-- L'habillage de la carte l'écrit en haut à gauche (UI/MapChrome.lua, par la
-- vue : ns.Map.View.Place). Le réglage « zoneLevels » l'allume.
local _, root = ...
local ns = root.Plus

local ZI = {}
ns.ZoneInfo = ZI

ns.Map.Settings.Own("zoneLevels", true)

local FISHING_SPELL = 7620
local FISHING_SKILL = 356         -- (sa ligne de compétence)

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function MapName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name
end

-- Une tranche de niveaux dans les couleurs des quêtes du jeu pour toi : le
-- code de couleur, et la tranche (« 30-40 »)
function ZI.LevelColor(lo, hi)
    hi = hi or lo
    local level = Plain(UnitLevel("player")) or 1
    local color
    if level < lo then
        color = GetQuestDifficultyColor and GetQuestDifficultyColor(lo)
    elseif level > hi then
        color = GetQuestDifficultyColor and GetQuestDifficultyColor(hi - 2)   -- (tout en dessous de toi : vert ou gris, pas jaune)
    end
    color = color or (QuestDifficultyColors and QuestDifficultyColors.difficult) or { r = 1, g = 0.5, b = 0.25 }
    return ("|cff%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255), lo == hi and tostring(hi) or (lo .. "-" .. hi)
end

local function On() return ns.Map.Settings.Get("zoneLevels") ~= false end

-- Les niveaux d'une zone : lo, hi (nil : inconnus) ; aussi pour « Où aller »
-- (UI/Places.lua)
function ZI.Levels(mapID)
    local levels = ns.Map.Data.Levels()
    local lv = levels and levels[mapID]
    if not levels and C_Map.GetMapLevels then
        local ok, lo, hi = pcall(C_Map.GetMapLevels, mapID)
        lo, hi = ok and Plain(lo), ok and Plain(hi)
        if lo and hi and lo > 0 and hi >= lo then lv = { lo, hi } end
    end
    if lv and lv[1] and lv[2] then return lv[1], lv[2] end
end

local function LevelText(mapID)
    if not On() then return "" end
    local lo, hi = ZI.Levels(mapID)
    if not lo then return "" end
    local code, range = ZI.LevelColor(lo, hi)
    return (" %s(%s)|r"):format(code, range)
end

-- La pêche (son nom dans la langue du jeu) et ton rang, relus toutes les
-- quelques secondes au plus (le nom du lieu se relit sans cesse)
local fishing = { at = -10 }
local function FishingRank()
    local now = GetTime()
    if now - fishing.at < 3 then return fishing.name, fishing.rank end
    fishing.at, fishing.rank = now, nil
    local byID = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID
    if byID then
        local ok, info = pcall(byID, FISHING_SKILL)
        if ok and type(info) == "table" and type(info.rank) == "number" and info.rank > 0 then
            fishing.name, fishing.rank = info.name, info.rank
            return fishing.name, fishing.rank
        end
    end
    local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(FISHING_SPELL))
        or (GetSpellInfo and GetSpellInfo(FISHING_SPELL))
    fishing.name = name
    if name and GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local skill, header, _, rank = GetSkillLineInfo(i)
            if not header and skill == name then
                fishing.rank = rank
                break
            end
        end
    end
    return fishing.name, fishing.rank
end

local function FishingText(mapID)
    local fishingData = ns.Map.Data.Fishing()
    local base = On() and fishingData and fishingData[mapID]
    if not base then return nil end
    local name, rank = FishingRank()
    if not (name and rank) then return nil end
    local color = rank >= base + 95 and "ff40ff40" or rank >= base + 45 and "ffffd100" or "ffff4040"
    return ("|c%s%s %d|r"):format(color, name, math.max(1, base + 95))
end

-- Le nom du lieu au point (x, y) de la carte id (0..1) : la zone entière
-- (whole : la carte est dézoomée au-delà) avec ses niveaux, sinon l'endroit
-- que le jeu nomme là ; et la ligne de la pêche
function ZI.PlaceLabel(id, x, y, whole)
    if not id or id == ns.Map.Coords.World() then return end
    if not whole and x and x >= 0 and x <= 1 and y >= 0 and y <= 1 and MapUtil and MapUtil.FindBestAreaNameAtMouse then
        local ok, area = pcall(MapUtil.FindBestAreaNameAtMouse, id, x, y)
        if ok and area then return area, FishingText(id) end
    end
    local name = MapName(id)
    if name then return name .. LevelText(id), FishingText(id) end
end

-- (la migration ; la vue, Map/View.lua, appelle ZI.PlaceLabel)
ns.On("MAP_ATTACHED", function()
    ns.Map.Migrate("zoneLevels", function(old, new)
        if old.zoneLevels ~= nil then new.settings.zoneLevels = old.zoneLevels end
    end)
end)
