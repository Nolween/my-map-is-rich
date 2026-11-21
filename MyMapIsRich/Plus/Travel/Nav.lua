-- Les chemins à pied précis : une recherche A* sur la grille de marche
-- (Data/Nav0.lua, Nav1.lua, faits par tools/nav/build_nav.py d'après le
-- maillage de Shortest Path Forever). Chaque case (environ 8 yards) a une
-- surface de base et parfois des étages : un pont, la rue d'une ville bâtie
-- sur ses caves, les étages d'un bâtiment, les anneaux de Fossoyeuse. Chaque
-- surface dit les pas permis vers ses voisines : les falaises, les murs, les
-- montées trop raides et les pentes qui ne se prennent qu'en descendant sont
-- contournés, et un pas d'un étage nomme la surface où il arrive. Les
-- ascenseurs relient le haut et le bas d'un même endroit.
-- Le chemin préfère les routes et évite l'eau (on y nage, plus lentement).
--   Nav.Available()                    la grille peut-elle servir ?
--   Nav.Find(cont, from, to, speed, done)
--       cherche en tâche de fond (quelques milliers de nœuds par image), puis
--       appelle done({ points = { {x, y}, ... }, secs, length, cells, floors,
--       lifts, alt }) ou done(nil, raison) ; rend une fonction qui l'annule.
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
local ROAD = 0.7             -- un yard de route compte pour 0,7 (la préférence pour les routes)
local WEIGHT = 1.35          -- A* pondéré : un peu moins court, bien plus rapide
local BUDGET = 2500          -- nœuds examinés par image (moins en combat)
local MAX_CELLS = 250000     -- au-delà, on abandonne (l'estimation reste)
local NEAR_GOAL = 200        -- yd : l'arrivée hors d'atteinte (un plateau, une corniche) ; un chemin
                             -- jusqu'à la case atteinte la plus proche, s'il en est à moins de ça
local SNAP = 8               -- cases : un départ ou une arrivée sur une case bloquée glisse jusque-là
local LOOK = 48              -- cases : la portée du lissage
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

-- Une ligne droite d'un nœud à l'autre est-elle praticable ? Case après case,
-- les surfaces où l'on peut être (sans eau, sauf si l'un des bouts en est) ;
-- le nœud d'arrivée doit en être
local CUR, NEXT = {}, {}
local function Clear(m, a, b)
    if a == b then return true end
    local GY = m.GY
    local ca, cb = floor(a / 64), floor(b / 64)
    local ax, ay, bx, by = floor(ca / GY), ca % GY, floor(cb / GY), cb % GY
    local n = math.max(abs(bx - ax), abs(by - ay))
    if n == 0 then return false end
    local wet = Info(m, a) == 2 or Info(m, b) == 2
    local cur, nxt = CUR, NEXT
    cur[1] = a
    local nc = 1
    local px, py = ax, ay
    for i = 1, n do
        local x = floor(ax + (bx - ax) * i / n + 0.5)
        local y = floor(ay + (by - ay) * i / n + 0.5)
        local d = DIR[(x - px + 1) * 3 + y - py + 2]
        local nn = 0
        for j = 1, nc do
            local id = cur[j]
            local layer = id % 64
            local cell = (id - layer) / 64
            local before = nn
            nn = StepTo(m, floor(cell / GY), cell % GY, layer, d, nxt, nn)
            -- (sans doublon, et sans eau)
            local k = before + 1
            while k <= nn do
                local v, dup = nxt[k], false
                for q = 1, k - 1 do
                    if nxt[q] == v then dup = true break end
                end
                if dup or (not wet and Info(m, v) == 2) then
                    nxt[k] = nxt[nn]
                    nn = nn - 1
                else
                    k = k + 1
                end
            end
        end
        if nn == 0 then return false end
        cur, nxt, nc = nxt, cur, nn
        px, py = x, y
    end
    for j = 1, nc do
        if cur[j] == b then return true end
    end
    return false
end

-- La recherche (une coroutine, reprise à chaque image)
local function Search(job)
    local m, speed = job.m, job.speed
    local GY, cs = m.GY, m.cs
    local fx, fy = CellOf(m, job.from.x, job.from.y)
    local gx0, gy0 = CellOf(m, job.to.x, job.to.y)
    local sx, sy, sLayer, sList = Snap(m, fx, fy, Want(job.from))
    local wantGoal = Want(job.to)
    local tx, ty, tLayer = Snap(m, gx0, gy0, wantGoal)
    if not (sx and tx) then return nil, "nocell" end
    -- (une arrivée au sol : la première surface atteinte de sa case convient ;
    -- une couche donnée ou la plus basse est cherchée)
    local anyGoal = wantGoal == "ground"
    local water = math.max(1, speed / SWIM)
    local goal = (tx * GY + ty) * 64 + tLayer
    local goalCell = tx * GY + ty
    local gcost, came, lifted, closed = {}, {}, {}, {}
    local heap = G.Heap()
    local function H(gx, gy)
        local dx, dy = abs(gx - tx), abs(gy - ty)
        local lo, hi = math.min(dx, dy), math.max(dx, dy)
        return (hi - lo + lo * SQRT2) * cs * ROAD * WEIGHT
    end
    -- (le départ : la surface supposée, et les autres de la case un peu plus cher)
    local h0 = H(sx, sy)
    local other = Want(job.from) == "ground" and OTHER_START or OTHER_FAR
    for _, layer in ipairs(sList) do
        local id = (sx * GY + sy) * 64 + layer
        local g = layer == sLayer and 0 or other
        gcost[id] = g
        heap.Push(g + h0, id)
    end
    local count, budget = 0, 0
    -- (la case atteinte la plus proche de l'arrivée, en cas d'arrivée hors d'atteinte ;
    -- l'arrivée atteinte sur une autre surface)
    local nearest, nearestD = nil, math.huge
    local alt, altAt
    local function Give(why)
        if alt then
            goal = alt
            return true, why
        end
        if not nearest or nearestD * cs > NEAR_GOAL then return false end
        goal = nearest
        return true, why
    end
    while true do
        local _, id = heap.Pop()
        if not id then
            if Give("noway") then break end
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
                if Give("toofar") then break end
                return nil, "toofar"
            end
            local layer = id % 64
            local cell = (id - layer) / 64
            local gx, gy = floor(cell / GY), cell % GY
            do
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
            local n = Expand(m, id)
            for j = 1, n do
                local nid = NB[j]
                if not closed[nid] then
                    local secs = NL[j]
                    local d
                    if secs then
                        d = secs * speed
                    else
                        local kind, road = Info(m, nid)
                        d = ND[j]
                        if kind == 2 then d = d * water elseif road then d = d * ROAD end
                    end
                    local g = g0 + d
                    local old = gcost[nid]
                    if not old or g < old then
                        gcost[nid], came[nid], lifted[nid] = g, id, secs
                        local c = floor(nid / 64)
                        heap.Push(g + H(floor(c / GY), c % GY), nid)
                    end
                end
            end
        end
    end
    -- (les nœuds du chemin, du départ à l'arrivée ; le temps réel)
    local nodes = {}
    local id = goal
    while id do
        table.insert(nodes, 1, id)
        id = came[id]
    end
    local secs, length, lifts, floors = 0, 0, 0, 0
    for i = 1, #nodes do
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
                secs = secs + d / (Info(m, nodes[i]) == 2 and SWIM or speed)
            end
        end
    end
    -- (lissé : d'un nœud, aussi loin que la ligne droite reste praticable ; un
    -- ascenseur est un point du tracé)
    local points = { { x = job.from.x, y = job.from.y } }
    local i, steps = 1, 0
    while i < #nodes do
        local j = math.min(#nodes, i + LOOK)
        -- (pas au-delà d'un ascenseur)
        for q = i + 1, j do
            if lifted[nodes[q]] then
                j = q == i + 1 and q or q - 1
                break
            end
        end
        while j > i + 1 do
            if Clear(m, nodes[i], nodes[j]) then break end
            j = j - 1
            steps = steps + 1
            if steps % 64 == 0 then coroutine.yield() end
        end
        local c = floor(nodes[j] / 64)
        local x, y = Center(m, floor(c / GY), c % GY)
        points[#points + 1] = { x = x, y = y }
        i = j
    end
    if #points < 2 then points[2] = { x = job.to.x, y = job.to.y } end
    points[#points] = { x = job.to.x, y = job.to.y }
    return { points = points, secs = secs, length = length, cells = count, floors = floors, lifts = lifts,
        alt = floor(goal / 64) ~= goalCell or (not anyGoal and goal % 64 ~= tLayer),
        startLayer = sLayer, goalLayer = goal % 64 }
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
    local job = { m = m, from = from, to = to, speed = speed or 7, done = done }
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
