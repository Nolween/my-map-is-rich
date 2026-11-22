-- Les coordonnées de la carte : ns.Map.Coords, en code de My Map Is Rich
-- depuis la 0.7.0 (elles venaient de Map/Stitch.lua et Map/WorldMap.lua).
--
-- Le monde de la carte : la carte d'Azeroth du jeu (947), u et v de 0 à 1
-- (v croît vers le bas). Une carte du jeu (zone, ville, continent) y a son
-- rectangle, celui que le jeu donne (C_Map.GetMapRectOnMap). Un point du
-- jeu en mètres (yards, sur le continent 0 ou 1) s'y place par les coins de
-- la carte de son continent.
-- Le dessin de la carte (Map/Stitch.lua) garde encore ses propres calculs ;
-- /mmir sonde carte compare les deux (Diag.lua).
local _, root = ...
local ns = root.Plus

local K = ns.Map.Coords
local WORLD = 947
local CONTINENT_MAP = { [0] = 1415, [1] = 1414 }   -- continent du jeu -> sa carte
local CITY_EDGE = 0.25    -- la part de chaque bord d'une ville laissée à sa zone (ChainAt)

local function Finite(...)
    for i = 1, select("#", ...) do
        local n = select(i, ...)
        if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then return false end
        if issecretvalue and issecretvalue(n) then return false end
    end
    return true
end
K.Finite = Finite

local function XY(vec)
    if type(vec) ~= "table" then return end
    if vec.GetXY then return vec:GetXY() end
    return vec.x, vec.y
end

-- La carte du monde entier
function K.World() return WORLD end

-- Le rectangle d'une carte sur le monde : gauche, droite, haut, bas (0..1) ;
-- rien si elle n'y est pas (gardé une fois trouvé)
local rects = {}
function K.Rect(mapID)
    if not mapID then return end
    local r = rects[mapID]
    if r == nil then
        if mapID == WORLD then
            r = { 0, 1, 0, 1 }
        else
            local ok, l, rr, t, b = pcall(C_Map.GetMapRectOnMap, mapID, WORLD)
            r = (ok and Finite(l, rr, t, b) and rr > l and b > t) and { l, rr, t, b } or false
        end
        rects[mapID] = r
    end
    if r then return r[1], r[2], r[3], r[4] end
end

-- Un point d'une carte du jeu (0..1) vers le monde, et l'inverse
function K.ToWorld(mapID, x, y)
    local l, r, t, b = K.Rect(mapID)
    if not (l and x and y) then return end
    return l + x * (r - l), t + y * (b - t)
end

function K.FromWorld(mapID, u, v)
    local l, r, t, b = K.Rect(mapID)
    if not (l and u and v) then return end
    return (u - l) / (r - l), (v - t) / (b - t)
end

-- Les cartes sous un point du monde, du monde à la plus petite : { 947,
-- continent, zone[, ville] }. Une ville ne compte qu'au milieu de son
-- rectangle : le jeu la donne pour tout son rectangle, qui déborde loin sur
-- sa zone (près de Forgefer, Kharanos tombait dans la ville)
function K.ChainAt(u, v)
    local chain = { WORLD }
    if not Finite(u, v) then return chain end   -- (le jeu lève une erreur sur un point NaN)
    local cityZones = ns.Map.Data.CityZones()
    local mapID, x, y = WORLD, u, v
    for _ = 1, 4 do
        local ok, info = pcall(C_Map.GetMapInfoAtPosition, mapID, x, y)
        if not ok or not info or info.mapID == mapID then break end
        if info.mapType ~= Enum.UIMapType.Continent and info.mapType ~= Enum.UIMapType.Zone then break end
        local okR, l, r, t, b = pcall(C_Map.GetMapRectOnMap, info.mapID, mapID)
        if not (okR and l and r > l and b > t) then break end
        local cx, cy = (x - l) / (r - l), (y - t) / (b - t)
        local zone = cityZones and cityZones[info.mapID]
        if zone then
            local okZ, zl, zr, zt, zb = pcall(C_Map.GetMapRectOnMap, zone, mapID)
            if okZ and zl and zr > zl and zb > zt then
                chain[#chain + 1] = zone
                if math.min(cx, 1 - cx) < CITY_EDGE or math.min(cy, 1 - cy) < CITY_EDGE then break end
            end
        end
        mapID, x, y = info.mapID, cx, cy
        chain[#chain + 1] = mapID
    end
    return chain
end

-- La zone la plus fine sous un point du monde : sa carte, et la place du point dessus
function K.ZoneAt(u, v)
    if not (u and v) then return end
    local chain = K.ChainAt(u, v)
    for i = #chain, 1, -1 do
        local id = chain[i]
        if id ~= WORLD then
            local x, y = K.FromWorld(id, u, v)
            if x then return id, x, y end
        end
    end
end

---------------------------------------------------------------------------
-- Les mètres du jeu (yards) vers le monde, par les coins de chaque continent
---------------------------------------------------------------------------
local corners = {}        -- continent -> { x0, y0, x1, y1, mapID } ou false
local function Corners(cont)
    local c = corners[cont]
    if c ~= nil then return c end
    c = false
    local mapID = CONTINENT_MAP[cont]
    if mapID and C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local ok0, _, p0 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
        local ok1, _, p1 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
        if ok0 and ok1 and p0 and p1 then
            local x0, y0 = XY(p0)
            local x1, y1 = XY(p1)
            if Finite(x0, y0, x1, y1) and x1 ~= x0 and y1 ~= y0 then c = { x0, y0, x1, y1, mapID } end
        end
    end
    corners[cont] = c
    return c
end

-- (le vecteur des coins et les X / Y du jeu peuvent s'aligner de deux façons
-- avec les x / y de la carte : swap choisit ; d'habitude, le x de la carte
-- suit le Y du jeu)
local function Project(c, wx, wy, swap)
    local mx, my
    if swap then
        mx, my = (wx - c[1]) / (c[3] - c[1]), (wy - c[2]) / (c[4] - c[2])
    else
        mx, my = (wy - c[2]) / (c[4] - c[2]), (wx - c[1]) / (c[3] - c[1])
    end
    return K.ToWorld(c[5], mx, my)
end

local swap
-- Un point en yards (continent 0 ou 1) vers le monde : u, v
function K.FromYards(cont, wx, wy)
    if not Finite(wx, wy) then return end
    local c = Corners(cont)
    if not c then return end
    if swap == nil then
        -- (l'ordre des axes, une fois : le maître de vol de Hurlevent, -8840.6,
        -- 489.7, est dans la forêt d'Elwynn ou à Hurlevent)
        local wc = Corners(0)
        swap = false
        if wc then
            for _, try in ipairs({ false, true }) do
                local u, v = Project(wc, -8840.6, 489.7, try)
                for _, zone in ipairs({ 1429, 1453 }) do
                    local l, r, t, b = K.Rect(zone)
                    if u and l and u >= l and u <= r and v >= t and v <= b then swap = try end
                end
            end
        end
    end
    return Project(c, wx, wy, swap)
end

-- Un point du monde vers les yards d'un continent (l'inverse de FromYards)
function K.ToYards(cont, u, v)
    if not Finite(u, v) then return end
    local x0, y0 = K.FromYards(cont, 0, 0)
    local x1, y1 = K.FromYards(cont, 1000, 0)
    local x2, y2 = K.FromYards(cont, 0, 1000)
    if not (x0 and x1 and x2) then return end
    -- (la projection est linéaire : u, v = origine + wx * a + wy * b)
    local ax, ay, bx, by = (x1 - x0) / 1000, (y1 - y0) / 1000, (x2 - x0) / 1000, (y2 - y0) / 1000
    local det = ax * by - bx * ay
    if det == 0 then return end
    local du, dv = u - x0, v - y0
    return (du * by - bx * dv) / det, (ax * dv - du * ay) / det
end
