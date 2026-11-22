-- Les chemins à pied précis : une recherche A* sur la grille de marche
-- (Data/Nav0.lua, Nav1.lua, faits par tools/nav/build_nav.py d'après le
-- maillage de Shortest Path Forever). Chaque case (environ 8 yards) a une
-- surface de base et parfois des étages : un pont, la rue d'une ville bâtie
-- sur ses caves, les étages d'un bâtiment, les anneaux de Fossoyeuse. Chaque
-- surface dit les pas permis vers ses voisines : les falaises, les murs, les
-- montées trop raides et les pentes qui ne se prennent qu'en descendant sont
-- contournés, et un pas d'un étage nomme la surface où il arrive. Les
-- ascenseurs relient le haut et le bas d'un même endroit.
-- Le choix du chemin suit le réglage « Chemin à pied » (Planner.PathProfile) :
-- un yard hors route compte plus qu'un yard de route (rien de plus à travers
-- champs), et monter sur une route coûte un peu, pour ne pas faire de crochet
-- vers un petit bout de route. Il évite l'eau (on y nage, plus lentement :
-- c'est compté plusieurs fois) et les villes de l'autre faction
-- (Data/Hazards.lua), sauf celle du départ ou de l'arrivée. Le temps annoncé
-- reste le temps réel.
-- La recherche se fait en deux temps : un A* pondéré, rapide, puis un A*
-- exact dans un couloir autour de son chemin, qui retire ses grands tours.
-- Le tracé est ensuite lissé : un raccourci en ligne droite est pris s'il est
-- praticable et ne coûte pas plus que le chemin qu'il remplace (il ne quitte
-- pas la route pour couper un virage, il ne coupe pas par l'eau), puis les
-- points presque alignés sont retirés.
--   Nav.Available()                    la grille peut-elle servir ?
--   Nav.Find(cont, from, to, speed, done)
--       cherche en tâche de fond (quelques milliers de nœuds par image), puis
--       appelle done({ points = { {x, y}, ... }, secs, length, cells, floors,
--       lifts, alt, unreachable }) ou done(nil, raison) ; rend une fonction
--       qui l'annule. unreachable : l'arrivée n'est pas atteinte, le tracé
--       s'arrête au point atteint le plus proche (sans ligne droite par-dessus
--       le relief).
--       from, to : { cont, x, y, layer?, map? }. La surface d'un bout : sa
--       couche si elle est donnée, sinon la plus basse dans une ville sous terre
--       (sa carte), sinon le sol. On ne connaît pas la hauteur du joueur : le
--       départ part aussi des autres surfaces de sa case, un peu plus cher.
-- Un nœud : (gx * GY + gy) * 64 + couche (0 la base, i le i-ème étage depuis
-- le bas). Les tuiles sont décodées à la demande (C_EncodingUtil : base64 puis
-- zlib) et gardées.
local _, root = ...
local ns = root.Plus
local G = ns.TravelGraph

local Nav = {}
ns.TravelNav = Nav

local TILE = 1600 / 3
local SQRT2 = math.sqrt(2)
local SWIM = 4.72            -- yd/s à la nage
local WATER_PREF = 3         -- un yard nagé compte (en plus de la lenteur) 3 fois : on contourne l'eau
local TOWN = 6               -- un yard dans une ville de l'autre faction compte 6 fois (comme SPF)
local WEIGHT = 1.15          -- A* pondéré (le premier temps) : un peu moins court, bien plus rapide ;
                             -- multiplié par la racine du coût hors route
local BLOCK = 4              -- cases : les blocs du couloir du second temps...
local CORRIDOR = 3           -- ... gardés jusqu'à autant de blocs autour du premier chemin
local BUDGET = 2500          -- nœuds examinés par image (moins en combat)
local MAX_CELLS = 400000     -- au-delà, on abandonne (l'estimation reste)
local NEAR_GOAL = 200        -- yd : l'arrivée hors d'atteinte (un plateau, une corniche) ; un chemin
                             -- jusqu'à la case atteinte la plus proche, s'il en est à moins de ça
local END_GAP = 20           -- yd : ... le tracé ne va jusqu'à l'arrivée que si elle en est aussi près
local SNAP = 8               -- cases : un départ ou une arrivée sur une case bloquée glisse jusque-là
local LOOK = 96              -- cases : la portée du lissage
local SLACK = 1              -- yd : un raccourci peut coûter autant que le chemin, à ça près
local STRAIGHT = 3           -- yd : un point du tracé aussi près de la ligne de ses voisins est retiré
-- Les villes de l'autre faction (Data/Hazards.lua) : un maître de vol de
-- l'autre faction sans aucun des tiens à moins de SHARED ; son terrain, ou un
-- cercle de TOWN_RADIUS autour de lui
local TOWN_RADIUS, SHARED = 150, 400
local TOWN_CELL = 100 / 3    -- yd : les morceaux de terrain d'une ville
local CAP_CELL = 64          -- yd : les carrés d'une capitale
local BUCKET = 256           -- yd : l'index des villes
local OTHER_START = 60       -- yd : partir d'une autre surface que celle supposée coûte autant...
local OTHER_FAR = 2000       -- ... ou bien plus, quand on sait où est le bout (une couche donnée, sous terre)
local ALT_EXTRA = 60000      -- nœuds : l'arrivée atteinte sur une autre surface que la voulue, on
                             -- cherche encore la bonne jusque-là
-- Les villes sous terre (cartes du jeu) : un bout y est sur la surface la plus basse
local UNDERGROUND = { [1458] = true }   -- Fossoyeuse

local floor, byte, sqrt, abs = math.floor, string.byte, math.sqrt, math.abs
local maps, jobs = {}, {}

-- Les huit directions (dans l'ordre des bits des étages), leurs opposées, et
-- la direction d'un pas (dx, dy) : DIR[(dx + 1) * 3 + dy + 2]
local DX = { 1, -1, 0, 0, 1, 1, -1, -1 }
local DY = { 0, 0, 1, -1, 1, -1, 1, -1 }
local OPP = { 2, 1, 4, 3, 8, 7, 6, 5 }
local DIR = {}
for d = 1, 8 do DIR[(DX[d] + 1) * 3 + DY[d] + 2] = d end
-- HAS[masque * 8 + d] : le bit de la direction d est-il dans le masque ?
local HAS = {}
for mask = 0, 255 do
    for d = 1, 8 do
        if floor(mask / 2 ^ (d - 1)) % 2 == 1 then HAS[mask * 8 + d] = true end
    end
end

function Nav.Available()
    return C_EncodingUtil and C_EncodingUtil.DecodeBase64 and C_EncodingUtil.DecompressString
        and Enum and Enum.CompressionMethod and Enum.CompressionMethod.Zlib and true or false
end

local function Map(cont)
    local m = maps[cont]
    if m == nil then
        local d = ns.Nav and ns.Nav[cont]
        m = false
        if type(d) == "table" and Nav.Available() then
            local C = d.cells
            m = { d = d, C = C, nx = d.nx, ny = d.ny, GX = d.nx * C, GY = d.ny * C,
                x0 = d.cx0 * TILE, y0 = d.cy0 * TILE, cs = TILE / C, tiles = {}, floors = {}, lift = {} }
            -- (les ascenseurs : un saut dans les deux sens)
            for _, row in ipairs(d.lifts or {}) do
                local a = (row[1] * m.GY + row[2]) * 64 + row[3]
                local b = (row[4] * m.GY + row[5]) * 64 + row[6]
                m.lift[a] = m.lift[a] or {}
                m.lift[b] = m.lift[b] or {}
                table.insert(m.lift[a], b)
                table.insert(m.lift[a], row[7])
                table.insert(m.lift[b], a)
                table.insert(m.lift[b], row[7])
            end
        end
        maps[cont] = m
    end
    return m or nil
end

local function Unpack(s)
    local ok, raw = pcall(function()
        local packed = C_EncodingUtil.DecodeBase64(s)
        return packed and C_EncodingUtil.DecompressString(packed, Enum.CompressionMethod.Zlib)
    end)
    if ok and type(raw) == "string" then return raw end
end

local function Tile(m, k)
    local t = m.tiles[k]
    if t == nil then
        t = false
        local s = m.d.tiles[k + 1]
        local raw = s and Unpack(s)
        if raw and #raw == m.C * m.C then t = raw end
        m.tiles[k] = t
    end
    return t
end

-- Les étages d'une tuile (le format est décrit dans tools/nav/build_nav.py) :
-- cell[case] = { g (la couche du sol, nil : inconnue), low (la plus basse),
-- first, count } ; pour chaque étage i : lay, wat, road, bm (pas vers la base),
-- sm (pas vers la même couche), im (pas entrants depuis la base), ex (les autres
-- pas : dx, dy, couche, ...) ; idx[case * 64 + couche] = i
local function ParseFloors(raw)
    local n = byte(raw, 1) * 256 + byte(raw, 2)
    local pos = 3
    local f = { cell = {}, idx = {}, lay = {}, wat = {}, road = {}, bm = {}, sm = {}, im = {}, ex = {} }
    local cells, lc = {}, -1
    for i = 1, n do
        local d = byte(raw, pos)
        pos = pos + 1
        if d == 255 then
            d = byte(raw, pos) * 256 + byte(raw, pos + 1)
            pos = pos + 2
        end
        lc = lc + d
        cells[i] = lc
    end
    local total = 0
    for i = 1, n do
        local g = byte(raw, pos + i - 1)
        local count = byte(raw, pos + 2 * n + i - 1)
        f.cell[cells[i]] = { g = g ~= 255 and g or nil, low = byte(raw, pos + n + i - 1), first = total + 1, count = count }
        total = total + count
    end
    pos = pos + 3 * n
    local pLay, pBase, pSame, pIn, pEx = pos, pos + total, pos + 2 * total, pos + 3 * total, pos + 4 * total
    local pExtra = pos + 5 * total
    local i = 0
    for c = 1, n do
        local cell = f.cell[cells[c]]
        for _ = 1, cell.count do
            i = i + 1
            local b = byte(raw, pLay + i - 1)
            local layer = b % 64
            f.lay[i], f.wat[i], f.road[i] = layer, floor(b / 64) % 2 == 1, b >= 128
            f.bm[i], f.sm[i], f.im[i] = byte(raw, pBase + i - 1), byte(raw, pSame + i - 1), byte(raw, pIn + i - 1)
            local ne = byte(raw, pEx + i - 1)
            if ne > 0 then
                local ex = {}
                for _ = 1, ne do
                    local a, bb, t = byte(raw, pExtra, pExtra + 2)
                    ex[#ex + 1], ex[#ex + 2], ex[#ex + 3] = a - 64, bb - 64, t
                    pExtra = pExtra + 3
                end
                f.ex[i] = ex
            end
            f.idx[cells[c] * 64 + layer] = i
        end
    end
    return f
end

local function Floors(m, k)
    local f = m.floors[k]
    if f == nil then
        f = false
        local s = m.d.floors and m.d.floors[k + 1]
        local raw = s and Unpack(s)
        if raw then
            local ok, parsed = pcall(ParseFloors, raw)
            if ok then f = parsed end
        end
        m.floors[k] = f
    end
    return f
end

-- Les étages de la tuile d'une case, et la case dans la tuile (nil hors des données)
local function FloorsAt(m, gx, gy)
    if gx < 0 or gy < 0 or gx >= m.GX or gy >= m.GY then return end
    local C = m.C
    local f = Floors(m, floor(gx / C) * m.ny + floor(gy / C))
    if f then return f, (gx % C) * C + gy % C end
end

-- Le code de la base d'une case : 0 pour une case bloquée ou hors des données ;
-- sinon type (1 sol, 2 eau) + 4 * pas permis (1 +x, 2 -x, 4 +y, 8 -y) + 64 * route
local function Code(m, gx, gy)
    if gx < 0 or gy < 0 or gx >= m.GX or gy >= m.GY then return 0 end
    local C = m.C
    local t = Tile(m, floor(gx / C) * m.ny + floor(gy / C))
    if not t then return 0 end
    return byte(t, (gx % C) * C + gy % C + 1) - 48
end

local function Kind(c) return c % 4 end
local function Can(c, bit) return floor(c / 4) % (bit * 2) >= bit end   -- (bit : 1, 2, 4, 8)

local BITX = { [1] = 1, [-1] = 2 }
local BITY = { [1] = 4, [-1] = 8 }

-- Un pas de base à base ; en diagonale, il passe si l'un des deux chemins en L passe
local function Step(m, gx, gy, c, dx, dy)
    if dx == 0 or dy == 0 then
        return Can(c, dx ~= 0 and BITX[dx] or BITY[dy])
    end
    local bx, by = BITX[dx], BITY[dy]
    if Can(c, bx) and Can(Code(m, gx + dx, gy), by) then return true end
    return Can(c, by) and Can(Code(m, gx, gy + dy), bx)
end

-- Le type d'un nœud (0 aucun, 1 sol, 2 eau) et s'il est sur une route
local function Info(m, id)
    local layer = id % 64
    local cell = (id - layer) / 64
    local gx, gy = floor(cell / m.GY), cell % m.GY
    if layer == 0 then
        local c = Code(m, gx, gy)
        return Kind(c), c >= 64
    end
    local f, lc = FloorsAt(m, gx, gy)
    local i = f and f.idx[lc * 64 + layer]
    if not i then return 0, false end
    return f.wat[i] and 2 or 1, f.road[i]
end

-- Les nœuds de la case voisine (direction d) qu'un pas depuis ce nœud atteint :
-- ajoutés à out à partir de n + 1 ; rend le nouveau n
local function StepTo(m, gx, gy, layer, d, out, n)
    local dx, dy = DX[d], DY[d]
    local nx, ny = gx + dx, gy + dy
    if nx < 0 or ny < 0 or nx >= m.GX or ny >= m.GY then return n end
    local base = (nx * m.GY + ny) * 64
    if layer == 0 then
        if Step(m, gx, gy, Code(m, gx, gy), dx, dy) then
            n = n + 1
            out[n] = base
        end
        -- (les étages de la case voisine qui acceptent un pas depuis cette base)
        local f, lc = FloorsAt(m, nx, ny)
        local cell = f and f.cell[lc]
        if cell then
            local od = OPP[d]
            for i = cell.first, cell.first + cell.count - 1 do
                if HAS[f.im[i] * 8 + od] then
                    n = n + 1
                    out[n] = base + f.lay[i]
                end
            end
        end
        return n
    end
    local f, lc = FloorsAt(m, gx, gy)
    local i = f and f.idx[lc * 64 + layer]
    if not i then return n end
    if HAS[f.bm[i] * 8 + d] then
        n = n + 1
        out[n] = base
    end
    if HAS[f.sm[i] * 8 + d] then
        n = n + 1
        out[n] = base + layer
    end
    local ex = f.ex[i]
    if ex then
        for j = 1, #ex, 3 do
            if ex[j] == dx and ex[j + 1] == dy then
                n = n + 1
                out[n] = base + ex[j + 2]
            end
        end
    end
    return n
end

-- Tous les voisins d'un nœud : NB (les nœuds), ND (la distance, yd), NL (les
-- secondes d'un ascenseur, sinon false) ; rend leur nombre
local NB, ND, NL = {}, {}, {}
local function Expand(m, id)
    local layer = id % 64
    local cell = (id - layer) / 64
    local gx, gy = floor(cell / m.GY), cell % m.GY
    local cs, n = m.cs, 0
    for d = 1, 8 do
        local n0 = n
        n = StepTo(m, gx, gy, layer, d, NB, n)
        local dist = d > 4 and cs * SQRT2 or cs
        for j = n0 + 1, n do ND[j], NL[j] = dist, false end
    end
    if layer > 0 then
        -- (les sauts de plus d'une case, ou sur place : une chute)
        local f, lc = FloorsAt(m, gx, gy)
        local i = f and f.idx[lc * 64 + layer]
        local ex = i and f.ex[i]
        if ex then
            for j = 1, #ex, 3 do
                local dx, dy = ex[j], ex[j + 1]
                if abs(dx) > 1 or abs(dy) > 1 or (dx == 0 and dy == 0) then
                    local nx, ny = gx + dx, gy + dy
                    if nx >= 0 and ny >= 0 and nx < m.GX and ny < m.GY then
                        n = n + 1
                        NB[n], ND[n], NL[n] = (nx * m.GY + ny) * 64 + ex[j + 2], cs * math.max(0.5, sqrt(dx * dx + dy * dy)), false
                    end
                end
            end
        end
    end
    local lift = m.lift[id]
    if lift then
        for j = 1, #lift, 2 do
            n = n + 1
            NB[n], ND[n], NL[n] = lift[j], 0, lift[j + 1]
        end
    end
    return n
end

local function CellOf(m, x, y)
    return floor((x - m.x0) / m.cs), floor((y - m.y0) / m.cs)
end
local function Center(m, gx, gy)
    return m.x0 + (gx + 0.5) * m.cs, m.y0 + (gy + 0.5) * m.cs
end

---------------------------------------------------------------------------
-- Les villes de l'autre faction (Data/Hazards.lua, et les maîtres de vol
-- d'OpenMap pour savoir lesquelles sont hostiles). Danger(job) rend une
-- fonction case -> facteur (1 hors des villes), ou nil s'il n'y a rien à
-- éviter ; la ville du départ ou de l'arrivée ne l'est pas.
---------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- Les morceaux d'une ville : l'ensemble de leurs numéros (x d'abord depuis son coin)
local function TownCells(s)
    local set, cell = {}, 0
    for symbol in s:gmatch(".") do
        local value = (B64:find(symbol, 1, true) or 1) - 1
        for b = 5, 0, -1 do
            local p = 2 ^ b
            if value >= p then
                set[cell] = true
                value = value - p
            end
            cell = cell + 1
        end
    end
    return set
end

local function Key(i, j) return (i + 4096) * 8192 + j + 4096 end

-- Les terrains à éviter d'un continent : { x0, y0, x1, y1 (leur boîte), In(x, y) }
local function HostileAreas(cont, faction)
    local data = ns.HazardData
    local list = {}
    if type(data) ~= "table" then return list end
    local mine = faction == "Horde" and 2 or 1
    local theirs = 3 - mine
    -- (les capitales)
    local capitals = {}
    for _, c in pairs(data.capitals or {}) do
        if c[2] == cont and c[1] ~= faction then
            local set, x0, y0, x1, y1 = {}, math.huge, math.huge, -math.huge, -math.huge
            for i, j, n in c[3]:gmatch("(%-?%d+) (%-?%d+) (%d+)") do
                i, j, n = tonumber(i), tonumber(j), tonumber(n)
                for k = 0, n - 1 do set[Key(i, j + k)] = true end
                x0, x1 = math.min(x0, i * CAP_CELL), math.max(x1, (i + 1) * CAP_CELL)
                y0, y1 = math.min(y0, j * CAP_CELL), math.max(y1, (j + n) * CAP_CELL)
            end
            local area = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
            function area.In(x, y) return set[Key(floor(x / CAP_CELL), floor(y / CAP_CELL))] == true end
            list[#list + 1] = area
            capitals[#capitals + 1] = area
        end
    end
    -- (les villes : un maître de vol de l'autre faction, aucun des tiens à
    -- moins de SHARED, pas dans une capitale déjà comptée)
    local F = ns.OM and ns.OM.MapFlights
    local nodes = type(F) == "table" and type(F.nodes) == "table" and F.nodes
    if not (nodes and bit and bit.band) then return list end
    local function Side(n, b)
        return type(n) == "table" and n[2] == cont and type(n[3]) == "number" and type(n[4]) == "number"
            and type(n[5]) == "number" and bit.band(n[5], b) ~= 0
    end
    for id, n in pairs(nodes) do
        if Side(n, theirs) and not Side(n, mine) and not n[6] then
            local skip = false
            for _, o in pairs(nodes) do
                if Side(o, mine) and (o[3] - n[3]) ^ 2 + (o[4] - n[4]) ^ 2 <= SHARED * SHARED then
                    skip = true
                    break
                end
            end
            for _, c in ipairs(capitals) do
                if skip then break end
                skip = c.In(n[3], n[4])
            end
            if not skip then
                local t = data.towns and data.towns[id]
                local area
                if type(t) == "table" and t[1] == cont and type(t[6]) == "string" then
                    local i0, j0, w, h, cells = t[2], t[3], t[4], t[5], TownCells(t[6])
                    area = { x0 = i0 * TOWN_CELL, y0 = j0 * TOWN_CELL, x1 = (i0 + w) * TOWN_CELL, y1 = (j0 + h) * TOWN_CELL }
                    function area.In(x, y)
                        local i, j = floor(x / TOWN_CELL) - i0, floor(y / TOWN_CELL) - j0
                        return i >= 0 and j >= 0 and i < w and j < h and cells[i * h + j] == true
                    end
                else
                    local cx, cy = n[3], n[4]
                    area = { x0 = cx - TOWN_RADIUS, y0 = cy - TOWN_RADIUS, x1 = cx + TOWN_RADIUS, y1 = cy + TOWN_RADIUS }
                    function area.In(x, y) return (x - cx) ^ 2 + (y - cy) ^ 2 <= TOWN_RADIUS * TOWN_RADIUS end
                end
                list[#list + 1] = area
            end
        end
    end
    return list
end

local function Danger(job)
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if faction ~= "Alliance" and faction ~= "Horde" then return end
    local m, from, to = job.m, job.from, job.to
    local buckets, any = {}, false
    for _, a in ipairs(HostileAreas(job.cont, faction)) do
        if not (a.In(from.x, from.y) or a.In(to.x, to.y)) then
            any = true
            for bx = floor(a.x0 / BUCKET), floor(a.x1 / BUCKET) do
                for by = floor(a.y0 / BUCKET), floor(a.y1 / BUCKET) do
                    local k = Key(bx, by)
                    buckets[k] = buckets[k] or {}
                    table.insert(buckets[k], a)
                end
            end
        end
    end
    if not any then return end
    local GY = m.GY
    return function(cell)
        local x, y = Center(m, floor(cell / GY), cell % GY)
        local list = buckets[Key(floor(x / BUCKET), floor(y / BUCKET))]
        if list then
            for _, a in ipairs(list) do
                if x >= a.x0 and x < a.x1 and y >= a.y0 and y < a.y1 and a.In(x, y) then return TOWN end
            end
        end
        return 1
    end
end

-- Le coût d'un pas de d yards jusqu'au nœud nid, pour choisir le chemin
-- (fromRoad : le nœud d'où l'on part est sur une route) ; et s'il est sur
-- une route
local function Cost(job, nid, d, fromRoad)
    local kind, onRoad = Info(job.m, nid)
    if kind == 2 then
        d = d * job.water
    elseif not onRoad then
        d = d * job.off
    elseif not fromRoad then
        d = d + job.join
    end
    local danger = job.danger
    if danger then d = d * danger(floor(nid / 64)) end
    return d, onRoad
end

-- Les surfaces praticables d'une case (leurs couches), et ses données d'étages
local function Surfaces(m, gx, gy)
    local list = {}
    local c = Code(m, gx, gy)
    if Kind(c) ~= 0 and floor(c / 4) % 16 ~= 0 then list[1] = 0 end
    local f, lc = FloorsAt(m, gx, gy)
    local cell = f and f.cell[lc]
    if cell then
        for i = cell.first, cell.first + cell.count - 1 do list[#list + 1] = f.lay[i] end
    end
    return list, cell
end

local function Has(list, layer)
    for _, l in ipairs(list) do
        if l == layer then return true end
    end
    return false
end

-- La surface voulue d'un bout : sa couche donnée, la plus basse (une ville
-- sous terre), ou le sol
local function Want(point)
    if type(point.layer) == "number" then return point.layer end
    if point.map and UNDERGROUND[point.map] then return "lowest" end
    return "ground"
end

local function Pick(list, cell, want)
    if type(want) == "number" and Has(list, want) then return want end
    if want == "lowest" and cell and Has(list, cell.low) then return cell.low end
    if cell and cell.g and Has(list, cell.g) then return cell.g end
    if Has(list, 0) then return 0 end
    return list[1]
end

-- La case praticable la plus proche (au plus SNAP cases) : gx, gy, la couche
-- voulue, et toutes ses surfaces ; une couche donnée est cherchée d'abord
local function Snap(m, gx, gy, want)
    for pass = 1, 2 do
        for r = 0, SNAP do
            local best, bestD, bestList, bestCell
            for dx = -r, r do
                for dy = -r, r do
                    if math.max(abs(dx), abs(dy)) == r then
                        local list, cell = Surfaces(m, gx + dx, gy + dy)
                        if #list > 0 and (pass == 2 or type(want) ~= "number" or Has(list, want)) then
                            local d = dx * dx + dy * dy
                            if not bestD or d < bestD then
                                best, bestD, bestList, bestCell = { gx + dx, gy + dy }, d, list, cell
                            end
                        end
                    end
                end
            end
            if best then return best[1], best[2], Pick(bestList, bestCell, want), bestList end
        end
        if type(want) ~= "number" then return end
    end
end

-- Une ligne droite d'un nœud à l'autre est-elle praticable, sans coûter plus
-- que `limit` ? Case après case, les surfaces où l'on peut être (sans eau,
-- sauf si l'un des bouts en est), chacune avec le coût pour y arriver (Cost) ;
-- le nœud d'arrivée doit en être. Rend vrai et le coût, ou faux.
local CUR, NEXT, CUR_C, NEXT_C, CUR_R, NEXT_R = {}, {}, {}, {}, {}, {}
local function Clear(job, a, b, limit)
    if a == b then return true, 0 end
    local m = job.m
    local GY, cs = m.GY, m.cs
    local ca, cb = floor(a / 64), floor(b / 64)
    local ax, ay, bx, by = floor(ca / GY), ca % GY, floor(cb / GY), cb % GY
    local n = math.max(abs(bx - ax), abs(by - ay))
    if n == 0 then return false end
    local wet = Info(m, a) == 2 or Info(m, b) == 2
    local cur, nxt, cc, nc_, cr, nr = CUR, NEXT, CUR_C, NEXT_C, CUR_R, NEXT_R
    local _, road0 = Info(m, a)
    cur[1], cc[1], cr[1] = a, 0, road0
    local count = 1
    local px, py = ax, ay
    for i = 1, n do
        local x = floor(ax + (bx - ax) * i / n + 0.5)
        local y = floor(ay + (by - ay) * i / n + 0.5)
        local d = DIR[(x - px + 1) * 3 + y - py + 2]
        local len = (x ~= px and y ~= py) and cs * SQRT2 or cs
        local nn = 0
        for j = 1, count do
            local id = cur[j]
            local c0, r0 = cc[j], cr[j]
            local layer = id % 64
            local cell = (id - layer) / 64
            local before = nn
            nn = StepTo(m, floor(cell / GY), cell % GY, layer, d, nxt, nn)
            -- (sans eau, pas trop cher, et sans doublon : le moins cher gardé)
            local k = before + 1
            while k <= nn do
                local v = nxt[k]
                local drop = not wet and Info(m, v) == 2
                local c, r
                if not drop then
                    c, r = Cost(job, v, len, r0)
                    c = c0 + c
                    drop = c > limit
                end
                if not drop then
                    for q = 1, k - 1 do
                        if nxt[q] == v then
                            if c < nc_[q] then nc_[q], nr[q] = c, r end
                            drop = true
                            break
                        end
                    end
                end
                if drop then
                    nxt[k] = nxt[nn]
                    nn = nn - 1
                else
                    nc_[k], nr[k] = c, r
                    k = k + 1
                end
            end
        end
        if nn == 0 then return false end
        cur, nxt, cc, nc_, cr, nr, count = nxt, cur, nc_, cc, nr, cr, nn
        px, py = x, y
    end
    for j = 1, count do
        if cur[j] == b then return true, cc[j] end
    end
    return false
end

-- Une recherche A* (un des deux temps de Search). S : ce que Search a
-- préparé (le départ, l'arrivée) ; p : { hw (le poids de l'heuristique),
-- inside, per (les blocs du couloir permis), goal (le nœud d'arrivée imposé) }.
-- Rend goal (le nœud atteint), came, lifted, count ; ou nil, la raison.
local function Run(job, S, p)
    local m = job.m
    local GY, cs = m.GY, m.cs
    local tx, ty = S.tx, S.ty
    local hk = cs * p.hw
    local function H(gx, gy)
        local dx, dy = abs(gx - tx), abs(gy - ty)
        local lo, hi = math.min(dx, dy), math.max(dx, dy)
        return (hi - lo + lo * SQRT2) * hk
    end
    local goal = p.goal or S.goal
    local goalCell = floor(goal / 64)
    local anyGoal = not p.goal and S.anyGoal
    local inside, per = p.inside, p.per
    local gcost, came, lifted, closed = {}, {}, {}, {}
    local heap = G.Heap()
    -- (le départ : la surface supposée, et les autres de la case un peu plus cher)
    local h0 = H(S.sx, S.sy)
    for _, layer in ipairs(S.sList) do
        local id = (S.sx * GY + S.sy) * 64 + layer
        local g = layer == S.sLayer and 0 or S.other
        gcost[id] = g
        heap.Push(g + h0, id)
    end
    local count, budget = 0, 0
    -- (la case atteinte la plus proche de l'arrivée, en cas d'arrivée hors
    -- d'atteinte ; l'arrivée atteinte sur une autre surface)
    local nearest, nearestD = nil, math.huge
    local alt, altAt
    local function Give()
        if p.goal then return false end
        if alt then
            goal = alt
            return true
        end
        if not nearest or nearestD * cs > NEAR_GOAL then return false end
        goal = nearest
        return true
    end
    while true do
        local _, id = heap.Pop()
        if not id then
            if Give() then break end
            return nil, "noway"
        end
        if id == goal then break end
        if anyGoal and floor(id / 64) == goalCell then
            goal = id
            break
        end
        if not closed[id] then
            closed[id] = true
            count, budget = count + 1, budget + 1
            if count > MAX_CELLS or (altAt and count > altAt) then
                if Give() then break end
                return nil, "toofar"
            end
            local layer = id % 64
            local cell = (id - layer) / 64
            if not p.goal then
                local gx, gy = floor(cell / GY), cell % GY
                local dx, dy = gx - tx, gy - ty
                local d = sqrt(dx * dx + dy * dy)
                if d < nearestD then nearest, nearestD = id, d end
                if cell == goalCell and not alt then alt, altAt = id, count + ALT_EXTRA end
            end
            if budget >= (InCombatLockdown() and BUDGET / 3 or BUDGET) then
                budget = 0
                coroutine.yield()
                if job.cancelled then return nil, "cancelled" end
            end
            local g0 = gcost[id]
            local _, hereRoad = Info(m, id)
            local n = Expand(m, id)
            for j = 1, n do
                local nid = NB[j]
                if not closed[nid] then
                    local c = floor(nid / 64)
                    local ngx, ngy = floor(c / GY), c % GY
                    if not inside or inside[floor(ngx / BLOCK) * per + floor(ngy / BLOCK)] then
                        local secs = NL[j]
                        local d
                        if secs then
                            d = secs * job.speed
                        else
                            d = Cost(job, nid, ND[j], hereRoad)
                        end
                        local g = g0 + d
                        local old = gcost[nid]
                        if not old or g < old then
                            gcost[nid], came[nid], lifted[nid] = g, id, secs
                            heap.Push(g + H(ngx, ngy), nid)
                        end
                    end
                end
            end
        end
    end
    return goal, came, lifted, count
end

-- Les nœuds d'un chemin, du départ à l'arrivée
local function PathNodes(goal, came)
    local back, id = {}, goal
    while id do
        back[#back + 1] = id
        id = came[id]
    end
    local nodes = {}
    for i = #back, 1, -1 do nodes[#nodes + 1] = back[i] end
    return nodes
end

-- Le couloir d'un chemin : les blocs de BLOCK cases jusqu'à CORRIDOR blocs
-- autour de ses nœuds ; et le nombre de blocs par colonne
local function Corridor(m, nodes)
    local per = floor(m.GY / BLOCK) + 1
    local inside, last = {}, nil
    for _, id in ipairs(nodes) do
        local c = floor(id / 64)
        local bx, by = floor(floor(c / m.GY) / BLOCK), floor(c % m.GY / BLOCK)
        local b = bx * per + by
        if b ~= last then
            last = b
            for dx = -CORRIDOR, CORRIDOR do
                for dy = -CORRIDOR, CORRIDOR do
                    inside[(bx + dx) * per + by + dy] = true
                end
            end
        end
    end
    return inside, per
end

-- La distance d'un point à un segment
local function ToSegment(p, a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    local len2 = dx * dx + dy * dy
    local t = len2 > 0 and ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2 or 0
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local qx, qy = a.x + t * dx - p.x, a.y + t * dy - p.y
    return sqrt(qx * qx + qy * qy)
end

-- La recherche (une coroutine, reprise à chaque image)
local function Search(job)
    local m = job.m
    local GY, cs = m.GY, m.cs
    local fx, fy = CellOf(m, job.from.x, job.from.y)
    local gx0, gy0 = CellOf(m, job.to.x, job.to.y)
    local sx, sy, sLayer, sList = Snap(m, fx, fy, Want(job.from))
    local wantGoal = Want(job.to)
    local tx, ty, tLayer = Snap(m, gx0, gy0, wantGoal)
    if not (sx and tx) then return nil, "nocell" end
    job.danger = Danger(job)
    -- (une arrivée au sol : la première surface atteinte de sa case convient ;
    -- une couche donnée ou la plus basse est cherchée)
    local S = { sx = sx, sy = sy, sLayer = sLayer, sList = sList, tx = tx, ty = ty, tLayer = tLayer,
        goal = (tx * GY + ty) * 64 + tLayer, goalCell = tx * GY + ty, anyGoal = wantGoal == "ground",
        other = Want(job.from) == "ground" and OTHER_START or OTHER_FAR }

    -- (le premier temps : pondéré, d'autant plus que le hors-route coûte)
    local goal, came, lifted, count = Run(job, S, { hw = WEIGHT * sqrt(job.off) })
    if not goal then return nil, came end
    local nodes = PathNodes(goal, came)
    -- (le second temps : exact, dans le couloir du premier chemin ; il en
    -- retire les grands tours. S'il échoue, le premier chemin reste)
    local inside, per = Corridor(m, nodes)
    local goal2, came2, lifted2, count2 = Run(job, S, { hw = 1, inside = inside, per = per, goal = goal })
    if job.cancelled then return nil, "cancelled" end
    if goal2 then
        came, lifted, count = came2, lifted2, count + count2
        nodes = PathNodes(goal2, came2)
    end

    -- (le coût cumulé du chemin, comme la recherche le compte)
    local N = #nodes
    local cum = { 0 }
    local _, road = Info(m, nodes[1])
    for i = 2, N do
        local id = nodes[i]
        if lifted[id] then
            cum[i] = cum[i - 1] + lifted[id] * job.speed
        else
            local a, b = floor(nodes[i - 1] / 64), floor(id / 64)
            local dx, dy = floor(b / GY) - floor(a / GY), b % GY - a % GY
            local c
            c, road = Cost(job, id, cs * math.max(0.5, sqrt(dx * dx + dy * dy)), road)
            cum[i] = cum[i - 1] + c
        end
    end

    -- (le temps réel, la longueur, les étages, les ascenseurs)
    local secs, length, lifts, floors = 0, 0, 0, 0
    for i = 1, N do
        if nodes[i] % 64 > 0 then floors = floors + 1 end
        if i > 1 then
            local a, b = floor(nodes[i - 1] / 64), floor(nodes[i] / 64)
            if lifted[nodes[i]] then
                secs = secs + lifted[nodes[i]]
                lifts = lifts + 1
            else
                local dx, dy = floor(b / GY) - floor(a / GY), b % GY - a % GY
                local d = cs * math.max(0.5, sqrt(dx * dx + dy * dy))
                length = length + d
                secs = secs + d / (Info(m, nodes[i]) == 2 and SWIM or job.speed)
            end
        end
    end

    -- (lissé : d'un nœud, aussi loin que la ligne droite reste praticable sans
    -- coûter plus que le chemin ; un ascenseur est un point du tracé)
    local keep, i, steps = { 1 }, 1, 0
    while i < N do
        local j = math.min(N, i + LOOK)
        -- (pas au-delà d'un ascenseur)
        for q = i + 1, j do
            if lifted[nodes[q]] then
                j = q == i + 1 and q or q - 1
                break
            end
        end
        while j > i + 1 do
            steps = steps + 1
            if steps % 32 == 0 then
                coroutine.yield()
                if job.cancelled then return nil, "cancelled" end
            end
            if Clear(job, nodes[i], nodes[j], cum[j] - cum[i] + SLACK) then break end
            j = j - 1
        end
        keep[#keep + 1] = j
        i = j
    end
    -- (une seconde passe : un point est retiré si ses deux voisins se
    -- rejoignent en ligne droite, sans coûter plus ; jamais un ascenseur)
    local k = 2
    while k < #keep do
        local a, b = keep[k - 1], keep[k + 1]
        steps = steps + 1
        if steps % 32 == 0 then
            coroutine.yield()
            if job.cancelled then return nil, "cancelled" end
        end
        if not lifted[nodes[keep[k]]] and not lifted[nodes[b]]
            and Clear(job, nodes[a], nodes[b], cum[b] - cum[a] + SLACK) then
            table.remove(keep, k)
        else
            k = k + 1
        end
    end

    local points = { { x = job.from.x, y = job.from.y } }
    for q = 2, #keep do
        local c = floor(nodes[keep[q]] / 64)
        local x, y = Center(m, floor(c / GY), c % GY)
        points[#points + 1] = { x = x, y = y }
    end
    -- (l'arrivée : le tracé y va si sa case est atteinte, ou presque ; sinon il
    -- s'arrête à la case atteinte la plus proche, sans ligne droite par-dessus
    -- le relief)
    local last = floor(nodes[N] / 64)
    local gapX, gapY = floor(last / GY) - tx, last % GY - ty
    local unreachable = sqrt(gapX * gapX + gapY * gapY) * cs > END_GAP
    if #points < 2 then
        local x, y = Center(m, floor(last / GY), last % GY)
        points[2] = { x = x, y = y }
    end
    if not unreachable then points[#points] = { x = job.to.x, y = job.to.y } end
    -- (les points presque alignés sont retirés)
    local q = 2
    while q < #points do
        if ToSegment(points[q], points[q - 1], points[q + 1]) < STRAIGHT then
            table.remove(points, q)
        else
            q = q + 1
        end
    end
    return { points = points, secs = secs, length = length, cells = count, floors = floors, lifts = lifts,
        alt = last ~= S.goalCell or (not S.anyGoal and nodes[N] % 64 ~= tLayer), unreachable = unreachable,
        startLayer = sLayer, goalLayer = nodes[N] % 64 }
end

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function()
    -- (une recherche finie en lance souvent une autre : la liste est copiée
    -- avant d'être parcourue)
    local list = {}
    for job in pairs(jobs) do list[#list + 1] = job end
    for _, job in ipairs(list) do
        local ok, result, reason = coroutine.resume(job.co, job)
        if not ok then
            jobs[job] = nil
            if geterrorhandler then geterrorhandler()(result) end
            job.done(nil, "error")
        elseif coroutine.status(job.co) == "dead" then
            jobs[job] = nil
            if not job.cancelled then job.done(result, reason) end
        end
    end
    if not next(jobs) then driver:Hide() end
end)

function Nav.Find(cont, from, to, speed, done)
    local m = Map(cont)
    if not (m and from.cont == cont and to.cont == cont) then
        done(nil, "nodata")
        return function() end
    end
    -- (le réglage « Chemin à pied » : Planner.PathProfile)
    local Pl = ns.TravelPlanner
    local profile = Pl and Pl.PathProfile and Pl.PathProfile() or { off = 1.3, join = 16 }
    speed = speed or 7
    local job = { m = m, cont = cont, from = from, to = to, speed = speed, done = done,
        off = profile.off, join = profile.join, water = math.max(1, speed / SWIM) * WATER_PREF }
    job.co = coroutine.create(Search)
    jobs[job] = true
    driver:Show()
    return function()
        job.cancelled = true
        jobs[job] = nil
    end
end

-- (pour /mmir trajet : y a-t-il une grille pour ce continent ?)
function Nav.Has(cont) return Map(cont) ~= nil end
