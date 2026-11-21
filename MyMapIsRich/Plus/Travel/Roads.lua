-- Le réseau de routes (Data/Roads.lua, fait par tools/roads/build_roads.py
-- d'après les routes de Shortest Path Forever) : décodé à la première
-- demande, par continent.
--   Roads.Get(cont)          -> le réseau, ou nil (pas de routes connues)
--   Roads.Access(net, x, y, k, reach)
--                            -> les k routes les plus proches d'un point, à
--                               moins de `reach` yd : { edge, pos (yd depuis le
--                               nœud a du tronçon), x, y (le point sur la
--                               route), dist }, une par tronçon
--   Roads.Slice(net, e, p0, p1)
--                            -> le tracé du tronçon e de la position p0 à p1
--                               (dans un sens ou dans l'autre) : { {x, y}, ... }
-- Un réseau : n (nœuds), X, Y, edges (nombre de tronçons), EA, EB (les deux
-- nœuds), EL (longueur), et pour chaque tronçon son tracé PX[e], PY[e] (du
-- nœud a au nœud b) et les longueurs cumulées CUM[e] ; around[n] : les
-- tronçons d'un nœud.
local _, root = ...
local ns = root.Plus

local Roads = {}
ns.TravelRoads = Roads

local CELL = 200             -- yd : les cases de l'index des segments
local cache = {}

local function Numbers(s)
    local out = {}
    for v in (s or ""):gmatch("%-?%d+") do out[#out + 1] = tonumber(v) end
    return out
end

local function Key(cx, cy) return cx * 65536 + cy end

local function Decode(data)
    local nodes, edges, points = Numbers(data.nodes), Numbers(data.edges), Numbers(data.points)
    local net = { X = {}, Y = {}, EA = {}, EB = {}, EL = {}, PX = {}, PY = {}, CUM = {}, around = {}, cells = {} }
    local n = #nodes / 2
    for i = 1, n do
        net.X[i], net.Y[i] = nodes[2 * i - 1], nodes[2 * i]
        net.around[i] = {}
    end
    net.n = n
    local count = #edges / 5
    for e = 1, count do
        local base = (e - 1) * 5
        local a, b, start, inner = edges[base + 1], edges[base + 2], edges[base + 4], edges[base + 5]
        local px, py = { net.X[a] }, { net.Y[a] }
        for j = start, start + inner - 1 do
            px[#px + 1], py[#py + 1] = points[2 * j - 1], points[2 * j]
        end
        px[#px + 1], py[#py + 1] = net.X[b], net.Y[b]
        local cum, total = { 0 }, 0
        for j = 2, #px do
            local dx, dy = px[j] - px[j - 1], py[j] - py[j - 1]
            total = total + math.sqrt(dx * dx + dy * dy)
            cum[j] = total
        end
        net.EA[e], net.EB[e], net.EL[e] = a, b, total
        net.PX[e], net.PY[e], net.CUM[e] = px, py, cum
        local list = net.around[a]
        list[#list + 1] = e
        if b ~= a then
            list = net.around[b]
            list[#list + 1] = e
        end
        -- (l'index : chaque segment dans les cases que couvre sa boîte)
        for j = 1, #px - 1 do
            local x0, x1 = math.min(px[j], px[j + 1]), math.max(px[j], px[j + 1])
            local y0, y1 = math.min(py[j], py[j + 1]), math.max(py[j], py[j + 1])
            for cx = math.floor(x0 / CELL), math.floor(x1 / CELL) do
                for cy = math.floor(y0 / CELL), math.floor(y1 / CELL) do
                    local key = Key(cx, cy)
                    local cell = net.cells[key]
                    if not cell then
                        cell = {}
                        net.cells[key] = cell
                    end
                    cell[#cell + 1] = e * 4096 + j
                end
            end
        end
    end
    net.edges = count
    return net
end

function Roads.Get(cont)
    local net = cache[cont]
    if net == nil then
        local data = ns.Roads and ns.Roads[cont]
        net = false
        if type(data) == "table" then
            local ok, decoded = pcall(Decode, data)
            if ok and decoded.n > 0 then net = decoded end
        end
        cache[cont] = net
    end
    return net or nil
end

-- Le point d'un segment le plus proche de (x, y) : t (0..1), distance²
local function Project(ax, ay, bx, by, x, y)
    local dx, dy = bx - ax, by - ay
    local len2 = dx * dx + dy * dy
    local t = 0
    if len2 > 0 then
        t = ((x - ax) * dx + (y - ay) * dy) / len2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local px, py = ax + t * dx, ay + t * dy
    return t, (x - px) * (x - px) + (y - py) * (y - py), px, py
end

function Roads.Access(net, x, y, k, reach)
    local best = {}           -- tronçon -> { edge, pos, x, y, dist }
    local r = math.ceil(reach / CELL)
    local cx0, cy0 = math.floor(x / CELL), math.floor(y / CELL)
    local seen = {}
    for cx = cx0 - r, cx0 + r do
        for cy = cy0 - r, cy0 + r do
            local cell = net.cells[Key(cx, cy)]
            if cell then
                for _, code in ipairs(cell) do
                    if not seen[code] then
                        seen[code] = true
                        local e, j = math.floor(code / 4096), code % 4096
                        local px, py = net.PX[e], net.PY[e]
                        local t, d2, qx, qy = Project(px[j], py[j], px[j + 1], py[j + 1], x, y)
                        if d2 <= reach * reach then
                            local cur = best[e]
                            if not cur or d2 < cur.d2 then
                                local cum = net.CUM[e]
                                best[e] = { edge = e, pos = cum[j] + t * (cum[j + 1] - cum[j]), x = qx, y = qy, d2 = d2 }
                            end
                        end
                    end
                end
            end
        end
    end
    local list = {}
    for _, a in pairs(best) do
        a.dist = math.sqrt(a.d2)
        list[#list + 1] = a
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    for i = #list, k + 1, -1 do list[i] = nil end
    return list
end

-- Le point du tronçon e à la position p (yd depuis a), et l'indice du
-- segment où il est
local function At(net, e, p)
    local cum, px, py = net.CUM[e], net.PX[e], net.PY[e]
    if p <= 0 then return px[1], py[1], 1 end
    local last = #cum
    if p >= cum[last] then return px[last], py[last], last - 1 end
    local j = 1
    while j < last - 1 and cum[j + 1] < p do j = j + 1 end
    local span = cum[j + 1] - cum[j]
    local t = span > 0 and (p - cum[j]) / span or 0
    return px[j] + t * (px[j + 1] - px[j]), py[j] + t * (py[j + 1] - py[j]), j
end

function Roads.Slice(net, e, p0, p1)
    local px, py, cum = net.PX[e], net.PY[e], net.CUM[e]
    local x0, y0, j0 = At(net, e, p0)
    local x1, y1, j1 = At(net, e, p1)
    local out = { { x = x0, y = y0 } }
    if p0 <= p1 then
        for j = j0 + 1, j1 do
            if cum[j] > p0 and cum[j] < p1 then out[#out + 1] = { x = px[j], y = py[j] } end
        end
    else
        for j = j0, j1 + 1, -1 do
            if cum[j] < p0 and cum[j] > p1 then out[#out + 1] = { x = px[j], y = py[j] } end
        end
    end
    out[#out + 1] = { x = x1, y = y1 }
    return out
end
