--------------------------------------------------------------------------------
-- Les zooms les plus proches : là où l'art de Blizzard n'a plus de pixels.
--   minicarte  les cases de la minicarte du jeu sur la carte peinte (ns.MapMinimap) : leurs propres
--              couleurs, adoucies et réchauffées vers le parchemin avec un soupçon de la couleur
--              propre de la zone (ns.MapTones), elles ajoutent les bois, les rochers et les bâtiments.
--              Un simple mélange : il ne peut pas éclaircir au-delà du blanc (un mélange additif brûlait
--              les zones pâles comme Tanaris), et il laisse la carte opaque (une multiplication, en jeu,
--              multiplie aussi l'opacité de la carte et le monde se voit au travers).
--              Sur les villes souterraines (Forgefer, Fossoyeuse), dont la minicarte est la surface
--              au-dessus, la minicarte du jeu de l'intérieur de la ville (ns.MapCityMinimap) à la place.
--   adouci     l'art des zones un peu flou (S.SetBlur : un flou à cinq prises des zones
--              en vue) et un grain de parchemin + le grain du papier par-dessus : l'art étiré
--              se lit comme du papier vu de près, pas comme des pixels
--   souterrain les grottes et les abords d'instance : les micro-cartes de Blizzard (ns.MapCaves,
--              sans cadre : masques MapCave), et toutes les autres telles que la minicarte du jeu les
--              dessine de l'intérieur (ns.MapCaveMinimap). Zoome tout près sur une : la surface s'assombrit
--              pendant que sa carte remonte à sa vraie place ; dézoome et elle redescend.
-- Tout suit la vue : le S.SetView du dessin (Map/Art.lua), appelé à chaque déplacement ou zoom.
--
-- En code de My Map Is Rich depuis la 0.15.0 : c'est le zoom rapproché d'OpenMap (Map/Close.lua, licence
-- MIT, LICENSES/OpenMap.txt), porté dans Plus tel quel, ses commentaires traduits ; ses réglages
-- (minimap, minimapMix...) sont à My Map Is Rich, copiés une fois de ceux d'OpenMap (plus bas).
--------------------------------------------------------------------------------

local _, root = ...
local ns = root.Plus
-- (les tables de données et les outils d'OpenMap : par l'adaptateur, jusqu'en 1.0.0)
local D = ns.Map.Data.All()
local S = ns.Map.ArtTable()           -- (le dessin : Map/Art.lua)
local Settings = ns.Map.Settings
-- (les réglages, lus comme une table : ceux du zoom rapproché sont à My Map Is Rich, plus bas)
local DB = setmetatable({}, { __index = function(_, key) return Settings.Get(key) end })

Settings.Own("minimap", true)                -- le détail de la minicarte de près, du tout (éteint : la carte peinte seule, partout)
Settings.Own("minimapMix", 0.45)             -- la force du détail de la minicarte de près (0 : aucun)
Settings.Own("minimapDeep", 0.85)            -- le plus qu'elle montre à tout zoom (atteint au plus profond, où la carte peinte n'a plus rien)
Settings.Own("minimapFrom", 20)              -- le zoom où elle commence à se mêler (MINI_FROM : ce à quoi il peut être réglé)
Settings.Own("cityMinimap", true)            -- ... sur les propres cartes des six grandes villes aussi (éteint : leurs propres cartes seules)
Settings.Own("soften", false)                -- adouci + grain du papier de près (son flou se repose pendant que la carte bouge)
Settings.Own("underground", true)            -- les grottes et les abords d'instance
Settings.Own("gapMinimap", false)            -- la minicarte sur la terre qu'aucune carte de zone ne couvre (à l'essai : éteinte, cette terre reste
                                --  le parchemin vide des cartes de zone, une carte inachevée)

local MINI_FADE = { 20, 34 }    -- le zoom où la minicarte se mêle (avec minimapFrom à 20 : les deux bougent avec lui)
local DEEP_FADE = { 30, 48 }    -- ... et où elle prend le relais, vers minimapDeep
local MINI_FROM = { 1, 60, 1 }  -- le plus petit de minimapFrom (le monde entier), le plus grand, le pas
ns.Map.Look.MINI_FROM = MINI_FROM
local miniFade, deepFade = { 20, 34 }, { 30, 48 }   -- (les fondus tels que réglés : gardés, pas refaits à chaque vue)
local CITY_MINI = 0.5           -- le plus que la minicarte montre sur la propre carte d'une ville
-- ... rien sur les propres cartes des six grandes villes avec cityMinimap éteint
local function CityMost() return DB.cityMinimap == false and 0 or CITY_MINI end
local GAP_FADE, GAP_MIX = { 4, 8 }, 0.6   -- ... et dans les trous entre les zones : où, et de quelle force
local GAP_MAX = 220             -- des cases au plus (elle commence de plus loin, donc plus sont en vue)
local SOFT_FADE = { 8, 18 }    -- ... l'adoucissement et le grain
local UNDER_START, UNDER_FULL = 4, 1.8      -- largeur de la vue / largeur de la grotte où une grotte commence / finit de remonter
local UNDER_ZOOM = { 28, 40 }   -- ... et le zoom qu'elle attend (une grande remonterait sur toute sa zone)
-- (sans attendre : un repère qu'on regarde de plus loin, l'intérieur du Mont Rochenoire)
local UNDER_ZOOM_OF = { [33] = false }
-- (et les étages plus profonds d'une montagne ne remontent jamais d'eux-mêmes : ils sont sous le principal,
-- les Cavernes de Rochenoire et la descente vers les Profondeurs sous le Mont Rochenoire)
local UNDER_SKIP = { [34] = true, [35] = true }
local TILE = 1600 / 3           -- yards par case de la minicarte
-- la surcouche : peinte * (1 - mix) + mix * teinte * minicarte. La minicarte garde ses propres couleurs,
-- adoucies (MINI_DESAT) et réchauffées vers le parchemin de la carte (PAPER), avec seulement un soupçon
-- de la couleur propre de la zone (TONE_SHARE) : elle s'inscrit dans la palette de la carte peinte sans
-- être recolorée
local MINI_DESAT = 0.35
local PAPER = { 1, 0.93, 0.80 }
local TONE_SHARE = 0.25
local DEFAULT_TONE = { 0.56, 0.45, 0.17 }    -- (la moyenne de l'art des zones, là où une zone n'a pas de teinte)

-- la teinte d'une case d'après une couleur de zone : la chaleur du parchemin, au quart du chemin vers la
-- couleur de la zone portée à pleine clarté
local function Tint(tone)
    local top = math.max(tone[1], tone[2], tone[3], 1e-3)
    local r, g, b = tone[1] / top, tone[2] / top, tone[3] / top
    return PAPER[1] + (r - PAPER[1]) * TONE_SHARE, PAPER[2] + (g - PAPER[2]) * TONE_SHARE, PAPER[3] + (b - PAPER[3]) * TONE_SHARE
end

local function TileTone(u, v)
    local chain = S.ChainAt(u, v)
    return Tint(D.MapTones and D.MapTones[chain[#chain]] or DEFAULT_TONE)
end
local GRAIN = D.Media.tex .. "MapGrain"
local TOOTH = D.Media.tex .. "MapTooth"
-- les cartes du jeu de chaque continent (ses cases de minicarte et ses grottes) et le continent de chaque carte
-- du jeu (par la terre duquel sa minicarte est dessinée) : les deux de WoW Forever, ou ceux d'un client (ns.MapWorld.minimap, world.py)
local CONT_OF, CONT_MAP = { [1415] = { 0 }, [1414] = { 1 } }, { [0] = 1415, [1] = 1414 }
if D.MapWorld and D.MapWorld.minimap then
    CONT_OF, CONT_MAP = D.MapWorld.minimap, {}
    local ids = {}
    for c in pairs(CONT_OF) do ids[#ids + 1] = c end
    table.sort(ids)                 -- (une carte du jeu que deux continents partagent : la terre du premier, les Royaumes de l'Est)
    for _, c in ipairs(ids) do
        for _, g in ipairs(CONT_OF[c]) do CONT_MAP[g] = CONT_MAP[g] or c end
    end
end

local function Smooth(x, r)
    local t = math.max(0, math.min(1, (x - r[1]) / (r[2] - r[1])))
    return t * t * (3 - 2 * t)
end

-- les cartes du jeu (continent 0 / 1...) du continent où est le centre de la vue : recherchées de nouveau seulement
-- une fois le centre un peu déplacé (la recherche du jeu fait des tables, et ceci tourne à chaque image d'un déplacement ou d'un zoom)
local lastCU, lastCV, lastCont
local function ContinentAt(u, v)
    if lastCU and math.abs(u - lastCU) < 0.002 and math.abs(v - lastCV) < 0.002 then return lastCont end
    lastCU, lastCV, lastCont = u, v, nil
    for _, id in ipairs(S.ChainAt(u, v)) do
        if CONT_OF[id] then lastCont = CONT_OF[id] break end
    end
    return lastCont
end

-- chaque carte du jeu (continent 0 / 1...) dont la vue chevauche la carte du continent (une liste, réutilisée)
local contsInView = {}
local function ContinentsInView(u, v, hu, hv)
    local out = contsInView
    wipe(out)
    for mapID, conts in pairs(CONT_OF) do
        local l, r, t, b = S.Rect(mapID)
        if l and r > u - hu and l < u + hu and b > v - hv and t < v + hv then
            for _, cont in ipairs(conts) do
                if not tContains(out, cont) then out[#out + 1] = cont end
            end
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- Les cases de la minicarte
--------------------------------------------------------------------------------

local tiles, pool = {}, {}      -- cont * 4096 + index -> { texture }
local TileKey = function(cont, tx, ty) return cont * 4096 + tx * 64 + ty end   -- (un nombre : pas une chaîne par case et par image)
local wantedTiles, wantedGap = {}, {}   -- (réutilisée à chaque mise à jour)

-- une case, par la terre de son continent (S.LandMask) : la mer de la minicarte est laissée de côté
local function Tile(layer, fid, cont)
    local t = tremove(pool)
    if not t then
        t = { layer:CreateTexture(nil, "ARTWORK") }
        t[1]:SetDesaturation(MINI_DESAT)
    end
    local mask = CONT_MAP[cont] and S.LandMask and S.LandMask(layer, CONT_MAP[cont])
    if t.mask ~= mask then
        if t.mask then t[1]:RemoveMaskTexture(t.mask) end
        if mask then t[1]:AddMaskTexture(mask) end
        t.mask = mask
    end
    t[1]:SetTexture(fid, nil, nil, "LINEAR")
    t.omA = nil                 -- (son alpha reposé : UpdateMinimap saute une case inchangée)
    return t
end

local function DropTile(key)
    local t = tiles[key]
    for _, tex in ipairs(t) do tex:Hide(); S.UnplaceWorld(tex) end
    tiles[key] = nil
    pool[#pool + 1] = t
end

-- Les copies plus petites de la minicarte (ns.MapMinimapLOD, tools/map-preview/minimaplod.py) : son détail
-- de plus loin que ses propres cases ne peuvent être dessinées (64 au plus ; un continent en a plus de
-- mille). Chaque copie est coupée en morceaux de `per` cases de côté, teintés comme les cases. Dessinées
-- la grossière sous la fine sous les cases du jeu, leurs forces réglées pour que les trois fassent `mix` :
-- la plus fine prend le relais quand moins de cases sont en vue
local LOD = D.Media.tex .. "MapMiniLOD\\"
local NATIVE_FROM = { 64, 36 }  -- cases en vue où les cases du jeu commencent / finissent de prendre le relais
local FINE_FROM = { 40, 24 }    -- cases en travers de la vue où la copie plus fine commence / finit de prendre le relais
local lodPieces, lodPool, wantedLOD = {}, {}, {}   -- clé -> texture ; textures libres ; (réutilisées à chaque mise à jour)
local lodSets = {}              -- (continent * 2 + niveau) -> { [col * 64 + row] = true }

local function LODSet(cont, level, keys)
    local k = cont * 2 + level
    if not lodSets[k] then
        local set = {}
        for _, key in ipairs(keys) do set[key] = true end
        lodSets[k] = set
    end
    return lodSets[k]
end

local function LODPiece(layer, cont, sub)
    local t = tremove(lodPool) or layer:CreateTexture(nil, "ARTWORK")
    t:SetDrawLayer("ARTWORK", sub)
    t:SetDesaturation(MINI_DESAT)
    t.omA = nil                 -- (voir Tile)
    local mask = CONT_MAP[cont] and S.LandMask and S.LandMask(layer, CONT_MAP[cont])
    if t.omMask ~= mask then
        if t.omMask then t:RemoveMaskTexture(t.omMask) end
        if mask then t:AddMaskTexture(mask) end
        t.omMask = mask
    end
    return t
end

-- les morceaux d'une copie sur les cases tx0 .. tx1, ty0 .. ty1, à `alpha`
local function ShowLOD(layer, cont, level, per, keys, tx0, tx1, ty0, ty1, alpha)
    local set = LODSet(cont, level, keys)
    for col = math.floor(tx0 / per), math.floor(tx1 / per) do
        for row = math.floor(ty0 / per), math.floor(ty1 / per) do
            if set[col * 64 + row] then
                local key = ((cont * 2 + level) * 64 + col) * 64 + row
                wantedLOD[key] = true
                local t = lodPieces[key]
                if not t then
                    local u0, v0 = S.FromYards(cont, (32 - row * per) * TILE, (32 - col * per) * TILE)
                    local u1, v1 = S.FromYards(cont, (32 - (row + 1) * per) * TILE, (32 - (col + 1) * per) * TILE)
                    if u0 and u1 then           -- (aucun pour un morceau hors du monde assemblé : ceux de l'Outreterre, sur 530)
                        t = LODPiece(layer, cont, -level)
                        t:SetTexture(LOD .. cont .. "_" .. per .. "_" .. col .. "_" .. row, nil, nil, "LINEAR")
                        lodPieces[key] = t
                        S.PlaceWorld(t, math.min(u0, u1), math.min(v0, v1), math.max(u0, u1), math.max(v0, v1))
                        t:Show()
                    end
                end
                if t and t.omA ~= alpha then t.omA = alpha t:SetAlpha(alpha) end
            end
        end
    end
end

local function UpdateMinimap(layer, conts, u, v, hu, hv, mix)
    local wanted = wantedTiles
    wipe(wanted)
    wipe(wantedLOD)
    for _, cont in ipairs(conts) do
        local list = D.MapMinimap and D.MapMinimap[cont]
        local xa, ya, xb, yb
        if list and mix > 0.01 then
            xa, ya = S.ToYards(cont, u - hu, v - hv)
            xb, yb = S.ToYards(cont, u + hu, v + hv)
        end
        if xa and xb then
            local tx0, tx1 = math.floor(32 - math.max(ya, yb) / TILE), math.floor(32 - math.min(ya, yb) / TILE)
            local ty0, ty1 = math.floor(32 - math.max(xa, xb) / TILE), math.floor(32 - math.min(xa, xb) / TILE)
            local count, across = (tx1 - tx0 + 1) * (ty1 - ty0 + 1), math.max(tx1 - tx0 + 1, ty1 - ty0 + 1)
            -- combien chacune se montre : les cases du jeu, la copie plus fine, la plus grossière
            local lods = D.MapMinimapLOD and D.MapMinimapLOD[cont]
            local wn = count <= 64 and (lods and Smooth(count, NATIVE_FROM) or 1) or 0
            local fine = Smooth(across, FINE_FROM)
            local a3 = mix * wn
            local a2 = a3 < 1 and mix * (1 - wn) * fine / (1 - a3) or 0
            local a1 = mix * (1 - wn) * (1 - fine) / math.max(1e-3, (1 - a2) * (1 - a3))
            if lods then
                for level, lv in ipairs(lods) do               -- (la plus fine d'abord)
                    local a = level == 1 and a2 or a1
                    if a > 0.005 then ShowLOD(layer, cont, level, lv[1], lv[2], tx0, tx1, ty0, ty1, math.min(1, a)) end
                end
            end
            if count <= 64 and a3 > 0.005 then
                for tx = tx0, tx1 do
                    for ty = ty0, ty1 do
                        local fid = list[tx * 64 + ty]
                        local u0, v0, u1, v1
                        if fid and not tiles[TileKey(cont, tx, ty)] then
                            u0, v0 = S.FromYards(cont, (32 - ty) * TILE, (32 - tx) * TILE)
                            u1, v1 = S.FromYards(cont, (31 - ty) * TILE, (31 - tx) * TILE)
                            if not (u0 and u1) then fid = nil end     -- (une case hors du monde assemblé)
                        end
                        if fid then
                            local key = TileKey(cont, tx, ty)
                            wanted[key] = true
                            local t = tiles[key]
                            if not t then
                                t = Tile(layer, fid, cont)
                                tiles[key] = t
                                t[1]:SetVertexColor(TileTone((u0 + u1) / 2, (v0 + v1) / 2))
                                for _, tex in ipairs(t) do
                                    S.PlaceWorld(tex, math.min(u0, u1), math.min(v0, v1), math.max(u0, u1), math.max(v0, v1))
                                    tex:Show()
                                end
                            end
                            if t.omA ~= a3 then t.omA = a3 t[1]:SetAlpha(a3) end
                        end
                    end
                end
            end
        end
    end
    for key in pairs(tiles) do
        if not wanted[key] then DropTile(key) end
    end
    for key, t in pairs(lodPieces) do
        if not wantedLOD[key] then
            t:Hide(); S.UnplaceWorld(t)
            lodPieces[key] = nil
            lodPool[#lodPool + 1] = t
        end
    end
end

--------------------------------------------------------------------------------
-- La minicarte dans les trous (à l'essai) : la terre qu'aucune carte de zone ne couvre (à l'ouest de la Gorge
-- des Vents brûlants, le mont Hyjal...) reçoit la minicarte du jeu, de plus loin que la surcouche
-- de près. Dessinée sous chaque zone, par un masque doux des trous (MapGapMask) : elle s'efface
-- à leurs bords ; les cases vides au-delà du bord du monde sont laissées de côté (gapfill.py) ;
-- teintée de la couleur de la zone la plus proche.
--------------------------------------------------------------------------------

local gapTiles, gapPools = {}, {}   -- clé -> texture ; continent -> ses textures libres (chacune masquée par sa terre)
local gapSets                   -- mapID du continent -> { [x * 64 + y] = true } : les cases qui touchent un trou

local function GapSet(mapID)
    gapSets = gapSets or {}
    if gapSets[mapID] == nil then
        local set = {}
        for _, key in ipairs(D.MapGaps and D.MapGaps.minimap and D.MapGaps.minimap[mapID] or {}) do set[key] = true end
        gapSets[mapID] = set
    end
    return gapSets[mapID]
end

-- la couleur de la zone la plus proche, en regardant un peu autour d'un point dans un trou
local GAP_REACH = { 0, 0.004, 0.009, 0.016 }
local function GapTone(u, v)
    for _, reach in ipairs(GAP_REACH) do
        for k = 0, reach > 0 and 7 or 0 do
            local a = k * math.pi / 4
            local chain = S.ChainAt(u + math.cos(a) * reach, v + math.sin(a) * reach * 1.5)
            local tone = D.MapTones and D.MapTones[chain[#chain]]
            if tone then return tone end
        end
    end
    return DEFAULT_TONE
end

local function UpdateGapMinimap(conts, u, v, hu, hv, alpha)
    local wanted, n = wantedGap, 0
    wipe(wanted)
    local layer = S.GapLayer and S.GapLayer()
    for _, cont in ipairs(conts) do
        local list = D.MapMinimap and D.MapMinimap[cont]
        local mapID = CONT_MAP[cont]
        local landMask = mapID and D.MapGaps and S.GapMask and S.GapMask(mapID)   -- (un client avec seulement des trous)
        local xa, ya, xb, yb
        if list and alpha > 0.01 and layer and landMask and D.MapGaps then
            xa, ya = S.ToYards(cont, u - hu, v - hv)
            xb, yb = S.ToYards(cont, u + hu, v + hv)
        end
        if xa and xb then
            local set = GapSet(mapID)
            local pool = gapPools[cont] or {}
            gapPools[cont] = pool
            local tx0, tx1 = math.floor(32 - math.max(ya, yb) / TILE), math.floor(32 - math.min(ya, yb) / TILE)
            local ty0, ty1 = math.floor(32 - math.max(xa, xb) / TILE), math.floor(32 - math.min(xa, xb) / TILE)
            for tx = tx0, tx1 do
                for ty = ty0, ty1 do
                    local fid = list[tx * 64 + ty]
                    if fid and n < GAP_MAX and set[tx * 64 + ty] then
                        local u0, v0 = S.FromYards(cont, (32 - ty) * TILE, (32 - tx) * TILE)
                        local u1, v1 = S.FromYards(cont, (31 - ty) * TILE, (31 - tx) * TILE)
                        local cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
                        do
                            n = n + 1
                            local key = TileKey(cont, tx, ty)
                            wanted[key] = true
                            local tex = gapTiles[key]
                            if not tex then
                                tex = tremove(pool)
                                if not tex then
                                    tex = layer:CreateTexture(nil, "ARTWORK", nil, 5)
                                    tex:SetDesaturation(MINI_DESAT)
                                    tex:AddMaskTexture(landMask)
                                    tex.cont = cont
                                end
                                tex:SetTexture(fid, nil, nil, "LINEAR")
                                tex:SetVertexColor(Tint(GapTone(cu, cv)))
                                S.PlaceWorld(tex, math.min(u0, u1), math.min(v0, v1), math.max(u0, u1), math.max(v0, v1))
                                tex:Show()
                                gapTiles[key] = tex
                            end
                            tex:SetAlpha(alpha)
                        end
                    end
                end
            end
        end
    end
    for key, tex in pairs(gapTiles) do
        if not wanted[key] then
            tex:Hide()
            S.UnplaceWorld(tex)
            gapTiles[key] = nil
            local pool = gapPools[tex.cont] or {}
            gapPools[tex.cont] = pool
            pool[#pool + 1] = tex
        end
    end
    return n
end

--------------------------------------------------------------------------------
-- Le grain du papier : deux octaves chacun de marbré et de grain, posés sur la carte (ils bougent
-- avec elle) et en fondu l'un dans l'autre, pour que le grain ait toujours la même taille à l'écran
--------------------------------------------------------------------------------

local grain
-- (posé sur une boîte bien plus grande que la vue, comme la mer : le grain est fixé sur le monde, un déplacement
-- ne le repose qu'au bord de la boîte ; un zoom ou un changement de force, à chaque fois)
local GRAIN_BOX = 1.8           -- la demi-taille de la boîte, en vues
local grainBox = {}             -- { u0, v0, u1, v1, hu =, amount = } tel que posé en dernier

local function UpdateGrain(layer, u, v, hu, hv, amount)
    if not grain then
        grain = {}
        for i, spec in ipairs({ { GRAIN, 1 }, { GRAIN, 2 }, { TOOTH, 1 }, { TOOTH, 2 } }) do
            local tex = layer:CreateTexture(nil, "OVERLAY", nil, i)
            tex:SetTexture(spec[1], "REPEAT", "REPEAT")
            grain[i] = { tex = tex, octave = spec[2], tooth = spec[1] == TOOTH }
        end
    end
    local gb = grainBox
    if amount <= 0.01 then
        if gb.amount ~= 0 then
            for _, g in ipairs(grain) do g.tex:Hide() end
            gb.amount = 0
        end
        return
    end
    if gb.hu == hu and gb.amount == amount and u - hu * 1.2 > gb[1] and u + hu * 1.2 < gb[3]
        and v - hv * 1.2 > gb[2] and v + hv * 1.2 < gb[4] then return end
    local W, H = S.Size()
    local u0, u1, v0, v1 = u - hu * GRAIN_BOX, u + hu * GRAIN_BOX, v - hv * GRAIN_BOX, v + hv * GRAIN_BOX
    gb[1], gb[2], gb[3], gb[4], gb.hu, gb.amount = u0, v0, u1, v1, hu, amount
    local want = math.log(hu * 2 * W * 0.35) / math.log(2)      -- une case de marbré ~ un tiers de la vue
    local n = math.floor(want)
    local f = want - n
    for _, g in ipairs(grain) do
        local size = 2 ^ (n + g.octave - 1) / (g.tooth and 6 or 1)          -- unités du monde
        local a = (g.octave == 1 and (1 - f) or f) * amount * (g.tooth and 0.9 or 0.7)
        g.tex:SetTexCoord(u0 * W / size, u1 * W / size, v0 * H / size, v1 * H / size)
        S.PlaceWorld(g.tex, u0, v0, u1, v1)
        g.tex:SetAlpha(a)
        g.tex:SetShown(a > 0.004)   -- (une octave éteinte en fondu coûte encore toute la vue : cachée)
    end
end

--------------------------------------------------------------------------------
-- Le souterrain : les grottes et les abords d'instance. Les cartes des grottes de Blizzard (ns.MapCaves : ses
-- micro-cartes, sans cadre par les masques MapCave), et toute autre grotte ou zone souterraine telle que la
-- minicarte du jeu la dessine de l'intérieur (ns.MapCaveMinimap, tools/map-caves/minimap.py : les images de
-- minicarte de ses bâtiments, chacune un carré tourné comme la grotte est posée). Celles de Blizzard ont pour clé
-- leur ID de carte, celles de la minicarte moins leur place dans sa liste.
--------------------------------------------------------------------------------

local caves = {}                -- clé -> { frame }, ou false
local rects = {}                -- clé -> { u0, v0, u1, v1 } (0..1)
local EMPTY = {}
local dim

local function CaveRect(c)
    -- l'art couvre sa boîte du monde (UiMin / UiMax sont presque toujours 0..1)
    local u0, v0 = S.FromYards(c[2], c[5], c[6])       -- nord-ouest : X maxi, Y maxi
    local u1, v1 = S.FromYards(c[2], c[3], c[4])
    if not u0 or not u1 then return end
    return math.min(u0, u1), math.min(v0, v1), math.max(u0, u1), math.max(v0, v1)
end

-- la boîte d'une grotte de la minicarte : { continent, minX, minY, maxX, maxY (yards), images }
local function MiniRect(c)
    local u0, v0 = S.FromYards(c[1], c[4], c[5])
    local u1, v1 = S.FromYards(c[1], c[2], c[3])
    if not u0 or not u1 then return end
    return math.min(u0, u1), math.min(v0, v1), math.max(u0, u1), math.max(v0, v1)
end

-- la boîte de n'importe quelle grotte sur le monde, calculée une fois
local function RectOf(key)
    local r = rects[key]
    if r then return r end
    local u0, v0, u1, v1
    if key > 0 then
        u0, v0, u1, v1 = CaveRect(D.MapCaves[key])
    else
        u0, v0, u1, v1 = MiniRect(D.MapCaveMinimap[-key])
    end
    if not u0 then return end
    r = { u0, v0, u1, v1 }
    rects[key] = r
    return r
end

local function Cave(layer, id, c)
    local u0, v0, u1, v1 = CaveRect(c)
    if not u0 then return false end
    local frame = CreateFrame("Frame", nil, layer)
    frame:SetAllPoints(layer)
    frame:SetFrameLevel(layer:GetFrameLevel() + 1)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(S.CaveMasks .. id, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    S.PlaceWorld(mask, u0, v0, u1, v1)
    local tw, th = (u1 - u0) / (1002 / 256), (v1 - v0) / (668 / 256)   -- une case de 256 px en unités du monde
    for n, fid in ipairs(c[11]) do
        local col, row = (n - 1) % 4, math.floor((n - 1) / 4)
        local pw, ph = math.min(256, 1002 - col * 256), math.min(256, 668 - row * 256)
        local tex = frame:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(fid, nil, nil, "TRILINEAR")
        tex:SetTexCoord(0, pw / 256, 0, ph / 256)
        local x0, y0 = u0 + col * tw, v0 + row * th
        S.PlaceWorld(tex, x0, y0, x0 + tw * pw / 256, y0 + th * ph / 256)
        tex:AddMaskTexture(mask)
    end
    return { frame = frame }
end

-- les unités du monde (0..1) par yard sur un continent : est-ouest (u), nord-sud (v)
local perYard = {}
local function PerYard(cont)
    local k = perYard[cont]
    if not k then
        local u0, v0 = S.FromYards(cont, 0, 0)
        local u1 = S.FromYards(cont, 0, 1000)
        local _, v1 = S.FromYards(cont, 1000, 0)
        if not (u0 and u1 and v1) then return end
        k = { math.abs(u1 - u0) / 1000, math.abs(v1 - v0) / 1000 }
        perYard[cont] = k
    end
    return k[1], k[2]
end

-- la minicarte du jeu d'un lieu de l'intérieur (une grotte, une ville souterraine) : ses images (fichier, centre X, Y,
-- côté en yards, rotation, u1, v0), chacune un carré autour de l'image du bloc (ses coordonnées de texture au-delà
-- de l'image : ramenées à rien) tourné autour de son centre ; l'étage le plus bas d'abord, sous ceux du dessus.
-- Sur `frame`, dans sa couche de dessin `layer`, teintées r, g, b ; rend les textures
local function Pictures(frame, c, layer, r, g, b)
    local ku, kv = PerYard(c[1])
    local out = {}
    if not ku then return out end
    local p = c[6]
    local n = #p / 7
    for i = 1, n do
        local j = (i - 1) * 7
        local u, v = S.FromYards(c[1], p[j + 2], p[j + 3])
        if u then
            local hu, hv = p[j + 4] / 2 * ku, p[j + 4] / 2 * kv
            local tex = frame:CreateTexture(nil, layer, nil, math.min(7, math.floor((i - 1) * 16 / n) - 8))
            tex:SetTexture(p[j + 1], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
            tex:SetTexCoord(0, p[j + 6], p[j + 7], 1)
            tex:SetRotation(p[j + 5])
            tex:SetDesaturation(MINI_DESAT)
            tex:SetVertexColor(r, g, b)
            tex.omWorld = { u - hu, v - hv, u + hu, v + hv }
            S.PlaceWorld(tex, u - hu, v - hv, u + hu, v + hv)
            out[#out + 1] = tex
        end
    end
    return out
end

-- une grotte d'après la minicarte du jeu, teintée comme la minicarte de près
local function MiniCave(layer, c)
    if not PerYard(c[1]) then return false end
    local frame = CreateFrame("Frame", nil, layer)
    frame:SetAllPoints(layer)
    frame:SetFrameLevel(layer:GetFrameLevel() + 1)
    Pictures(frame, c, "ARTWORK", PAPER[1], PAPER[2], PAPER[3])
    return { frame = frame }
end

local function CaveFrame(layer, key)
    local cave = caves[key]
    if cave == nil then
        if key > 0 then cave = Cave(layer, key, D.MapCaves[key]) else cave = MiniCave(layer, D.MapCaveMinimap[-key]) end
        caves[key] = cave
    end
    return cave
end

-- un étage par lieu : une grotte ou une entrée de donjon à plusieurs étages au même endroit (le donjon de
-- Tiragarde...) montre le premier
local primary
local function Primary(id, c)
    if not primary then
        primary = {}
        for k, cc in pairs(D.MapCaves or EMPTY) do
            if not UNDER_SKIP[k] and (not primary[cc[1]] or k < primary[cc[1]]) then primary[cc[1]] = k end
        end
    end
    return primary[c[1]] == id
end

-- Chaque grotte en vue remonte selon la part de la vue qu'elle remplit (UNDER_START .. UNDER_FULL de son
-- plus grand côté) une fois le zoom assez profond (UNDER_ZOOM), et reste tant qu'elle est à l'écran. La surface
-- au-dessus s'assombrit et s'adoucit seulement pour celle sur laquelle tu es centré : se promener ne
-- noircit pas toute la carte.
local underShown = {}           -- (réutilisée à chaque mise à jour)
local UNDER_RANGE = { UNDER_FULL, UNDER_START }
local FOCUS_RANGE = { 0.35, 0.8 }
local function Surface(shown, key, r, u, v, hu, hv, steps, focus)
    if not (r[3] > u - hu and r[1] < u + hu and r[4] > v - hv and r[2] < v + hv) then return focus end
    local fill = math.min((2 * hu) / (r[3] - r[1]), (2 * hv) / (r[4] - r[2]))   -- vue / grotte, dans son plus grand sens
    local tz = 1 - Smooth(fill, UNDER_RANGE)
    local wait = UNDER_ZOOM_OF[key]
    if wait == nil then wait = UNDER_ZOOM end
    if wait then tz = tz * Smooth(steps, wait) end
    if tz <= 0.01 then return focus end
    -- (pas une sous une terre encore inexplorée, tant que celle-ci est cachée)
    if S.HiddenAt and S.HiddenAt((r[1] + r[3]) / 2, (r[2] + r[4]) / 2) then return focus end
    shown[key] = tz
    local off = math.max(math.abs((r[1] + r[3]) / 2 - u) / hu, math.abs((r[2] + r[4]) / 2 - v) / hv)
    return math.max(focus, tz * (1 - Smooth(off, FOCUS_RANGE)))
end

local function UpdateUnderground(layer, conts, u, v, hu, hv, steps)
    local shown, focus = underShown, 0
    wipe(shown)
    if DB.underground and conts then
        for id, c in pairs(D.MapCaves or EMPTY) do
            if tContains(conts, c[2]) and not UNDER_SKIP[id] and Primary(id, c) then
                local r = RectOf(id)
                if r then focus = Surface(shown, id, r, u, v, hu, hv, steps, focus) end
            end
        end
        for i, c in ipairs(D.MapCaveMinimap or EMPTY) do
            if tContains(conts, c[1]) then
                local r = RectOf(-i)
                if r then focus = Surface(shown, -i, r, u, v, hu, hv, steps, focus) end
            end
        end
    end
    for key, cave in pairs(caves) do
        if cave and not shown[key] then cave.frame:Hide() end
    end
    for key, t in pairs(shown) do
        local cave = CaveFrame(layer, key)
        if cave then
            cave.frame:Show()
            cave.frame:SetAlpha(t)
        end
    end
    if not dim then
        dim = layer:CreateTexture(nil, "BACKGROUND")
        dim:SetColorTexture(0.05, 0.035, 0.02, 1)
    end
    if focus > 0.01 then
        S.PlaceWorld(dim, u - hu * 1.5, v - hv * 1.5, u + hu * 1.5, v + hv * 1.5)
        dim:SetAlpha(0.45 * focus)
        dim:Show()
    else
        dim:Hide()
    end
    S.SetUnderground(focus)
    return focus
end

-- la grotte qui contient une position du monde (yards), pour les icônes des entrées : la carte de Blizzard, sinon
-- celle de la minicarte
function S.CaveAt(cont, x, y)
    for id, c in pairs(D.MapCaves or EMPTY) do
        if c[2] == cont and x >= c[3] and x <= c[5] and y >= c[4] and y <= c[6] then
            local r = RectOf(id)
            if r then return id, r[1], r[2], r[3], r[4] end
        end
    end
    for i, c in ipairs(D.MapCaveMinimap or EMPTY) do
        if c[1] == cont and x >= c[2] and x <= c[4] and y >= c[3] and y <= c[5] then
            local r = RectOf(-i)
            if r then return -i, r[1], r[2], r[3], r[4] end
        end
    end
end

-- la plus petite grotte autour d'un point du monde (0..1), avec une marge : la vue laisse le zoom aller plus
-- loin sur une, jusqu'à ce que sa carte remplisse la vue
local CAVE_MARGIN = 0.25         -- (de sa taille, de chaque côté)
local function Nearest(r, u, v, best, area)
    local mu, mv = (r[3] - r[1]) * CAVE_MARGIN, (r[4] - r[2]) * CAVE_MARGIN
    if u < r[1] - mu or u > r[3] + mu or v < r[2] - mv or v > r[4] + mv then return best, area end
    local a = (r[3] - r[1]) * (r[4] - r[2])
    if not area or a < area then return r, a end
    return best, area
end
function S.CaveRectAt(u, v)
    if not DB.underground then return end
    local best, area
    for id in pairs(D.MapCaves or EMPTY) do
        local r = not UNDER_SKIP[id] and RectOf(id)
        if r then best, area = Nearest(r, u, v, best, area) end
    end
    for i in ipairs(D.MapCaveMinimap or EMPTY) do
        local r = RectOf(-i)
        if r then best, area = Nearest(r, u, v, best, area) end
    end
    if best then return best[1], best[2], best[3], best[4] end
end

--------------------------------------------------------------------------------
-- Les villes souterraines (Forgefer, Fossoyeuse) : la minicarte sur elles est celle de la surface (la montagne
-- de Forgefer, les ruines au-dessus de Fossoyeuse), tenue hors d'elles (S.CityCover). À l'intérieur, la minicarte
-- du jeu dessine le bâtiment de la ville (ns.MapCityMinimap, tools/map-caves/minimap.py) : ses images vont sur la
-- propre carte de la ville, sur son cadre (S.UndergroundCity : montrée, triée et en fondu avec elle), comme la minicarte
-- va sur une ville à l'air libre : au mélange de la minicarte, pas plus que CITY_MINI (rien avec cityMinimap éteint).
-- Pas une grotte : rien ne s'assombrit autour
--------------------------------------------------------------------------------

local cityPics = {}             -- mapID de la ville -> { ses textures, tone =, alpha =, dark = }, ou false

local function CityPictures(mapID, c)
    local frame = S.UndergroundCity and S.UndergroundCity(mapID)
    local l, r, t, b = S.Rect(mapID)
    if not frame or not l then return false end
    local tone = { TileTone((l + r) / 2, (t + b) / 2) }    -- (la teinte propre de la minicarte là)
    local pics = Pictures(frame, c, "OVERLAY", tone[1], tone[2], tone[3])
    pics.tone = tone
    for _, tex in ipairs(pics) do                -- (montrée, et ancrée, une fois qu'il y en a un peu)
        tex:Hide()
        tex:ClearAllPoints()
        S.UnplaceWorld(tex)
    end
    pics.shown = false
    return pics
end

local function UpdateCityMinimap(u, v, hu, hv, mix)
    for mapID, c in pairs(D.MapCityMinimap or EMPTY) do
        local pics = cityPics[mapID]
        local frame, hidden, dark = S.UndergroundCity(mapID)
        local l, r, t, b = S.Rect(mapID)
        -- (en vue, et sa carte arrivée : à alpha 0 elles coûteraient encore leur surface)
        local near = frame and l and r > u - hu and l < u + hu and b > v - hv and t < v + hv and (frame:GetAlpha() or 0) > 0.01
        if pics == nil and near and mix > 0.004 then
            pics = CityPictures(mapID, c)
            cityPics[mapID] = pics
        end
        if pics then
            local a = (near and not hidden) and math.floor(math.min(mix, CityMost()) * 50 + 0.5) / 50 or 0
            if pics.alpha ~= a then
                pics.alpha = a
                -- (cachées, elles lâchent leurs ancres : le jeu remet en page à chaque image d'un déplacement
                -- tout ce qui pend à la carte, montré ou non)
                local show = a > 0
                for _, tex in ipairs(pics) do
                    tex:SetAlpha(a)
                    if show ~= pics.shown then
                        if show then
                            S.PlaceWorld(tex, tex.omWorld[1], tex.omWorld[2], tex.omWorld[3], tex.omWorld[4])
                        else
                            tex:ClearAllPoints()
                            S.UnplaceWorld(tex)
                        end
                        tex:SetShown(show)
                    end
                end
                pics.shown = show
            end
            if pics.dark ~= dark then      -- (une ville pas trouvée assombrie comme sa carte l'est)
                pics.dark = dark
                local tone = pics.tone
                for _, tex in ipairs(pics) do
                    tex:SetVertexColor(tone[1] * (dark and dark[1] or 1), tone[2] * (dark and dark[2] or 1), tone[3] * (dark and dark[3] or 1))
                    tex:SetDesaturation(dark and math.max(MINI_DESAT, dark[4]) or MINI_DESAT)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------

-- chaque part tourne seule : une qui échoue (une différence de client) ne doit pas emporter les autres.
-- Son erreur est signalée une fois, et /mmir carte status la liste.
local failed = {}
S.closeFailed = failed
local stepMs = {}               -- le temps de chaque étape (ms, lissé) et le pire, pour /mmir carte status
S.closeSteps = stepMs
local function Try(name, fn, ...)
    local start = debugprofilestop and debugprofilestop()
    local ok, a, b = pcall(fn, ...)
    if start then
        local ms = debugprofilestop() - start
        local s = stepMs[name] or { ms = ms, worst = 0 }
        s.ms, s.worst = s.ms * 0.9 + ms * 0.1, math.max(s.worst, ms)
        stepMs[name] = s
    end
    if ok then return a, b end
    if not failed[name] then
        failed[name] = tostring(a)
        geterrorhandler()(("My Map Is Rich %s: %s"):format(name, tostring(a)))
    end
end

-- la vue : centre (0..1), demi-taille (0..1), zoom (selon la surface en vue : le DetailK de la vue,
-- Map/View.lua), et `steps` : le zoom tout court, depuis le monde entier, aussi loin que la molette est allée.
-- Les fondus de la minicarte vont selon lui : la même molette tourne en petite fenêtre ou en plein écran (selon
-- la surface, la vue large du plein écran la faisait arriver plus tard)
-- le flou se repose pendant que la carte bouge : ses quatre copies de chaque zone en vue sont remises en page
-- à chaque image d'un zoom ou d'un déplacement (environ 60 ms par image de zoom et 8 ms par image de déplacement
-- à 16x) ; de retour `after` secondes après l'arrêt. Une mise à jour seule de la vue (la carte ouverte, un
-- réglage changé) l'applique aussitôt : il se repose dès la deuxième mise à jour de suite (à `gap` au plus).
-- Il revient `step` zones par image : tout d'un coup, c'était une longue image à chaque arrêt de la carte,
-- sur laquelle tombait le cran de molette suivant, un instant après. `after` dépasse la pause entre deux
-- crans : zoomer cran par cran le garde au repos ; un zoom qui reprend arrête le retour
local BlurRest = { frame = CreateFrame("Frame"), args = {}, at = -10, after = 0.35, gap = 0.1, step = 2 }
BlurRest.frame:Hide()
BlurRest.frame:SetScript("OnUpdate", function(self)
    if ns.Map.View.Zooming and ns.Map.View.Zooming() then BlurRest.at = GetTime() return end
    if GetTime() - BlurRest.at < BlurRest.after then return end
    local a = BlurRest.args
    local done = Try("blur", S.SetBlur, a[1], a[2], a[3], a[4], a[5], BlurRest.step)
    if done ~= false then self:Hide() end
end)

S.closeView = {}
function S.SetView(u, v, hu, hv, zoom, steps)
    steps = steps or zoom
    local L = S.closeLayers
    if not L then return end
    if not D.Safe.Finite(u, v, hu, hv, zoom) then return end   -- (pas une vue : le NaN de #261)
    local cv = S.closeView
    local start = debugprofilestop and debugprofilestop()
    cv.zoom, cv.time, cv.updates = zoom, GetTime(), (cv.updates or 0) + 1
    if S.Moved then S.Moved() end
    local cont = Try("continent", ContinentAt, u, v)
    Try("sea", S.SetSea, u, v, hu, hv)
    Try("culling", S.Cull, u - hu, v - hv, u + hu, v + hv)
    local soft = DB.soften and Smooth(zoom, SOFT_FADE) or 0
    cv.soft = soft
    local now = GetTime()
    local moving = (ns.Map.View.Zooming and ns.Map.View.Zooming()) or now - BlurRest.at < BlurRest.gap
    BlurRest.at = now
    local blur = soft               -- (le grain va encore selon soft : seul le flou se repose)
    if soft > 0 and moving then
        local a = BlurRest.args
        a[1], a[2], a[3], a[4], a[5] = soft, u - hu, v - hv, u + hu, v + hv
        BlurRest.frame:Show()
        blur = 0
    else
        BlurRest.frame:Hide()       -- (appliqué maintenant : un plus ancien en attente le déferait)
    end
    Try("blur", S.SetBlur, blur, u - hu, v - hv, u + hu, v + hv)
    local base = DB.minimap and DB.minimapMix or 0
    local k = (DB.minimapFrom or MINI_FADE[1]) / MINI_FADE[1]          -- (plus tôt ou plus tard : les fondus suivent)
    -- (la prise de relais vers minimapDeep recule avec lui, jamais plus tôt : c'est là que la carte peinte
    -- n'a plus de détail)
    miniFade[1], miniFade[2] = MINI_FADE[1] * k, MINI_FADE[2] * k
    deepFade[1], deepFade[2] = DEEP_FADE[1] * math.max(1, k), DEEP_FADE[2] * math.max(1, k)
    local most = DB.minimapDeep or 1                     -- (le plus qu'elle montre jamais)
    local from = DB.minimapFrom or MINI_FADE[1]
    local mix = math.min(base, most) * (from <= MINI_FROM[1] and 1 or Smooth(steps, miniFade))   -- (au moins : depuis le monde entier)
    if base > 0 then mix = mix + (most - mix) * Smooth(steps, deepFade) end
    -- pas sur la propre carte d'une ville souterraine (la minicarte y est la surface, pas la ville : la
    -- minicarte du jeu de l'intérieur de la ville passe dessus à la place, UpdateCityMinimap)
    local inside = mix
    mix = mix * (1 - (Try("cities", S.CityCover, u, v) or 0))
    -- et sur les villes à la surface pas plus que CITY_MINI (rien avec cityMinimap éteint) : leur propre plan mène
    local city = Try("surface cities", S.SurfaceCityCover, u, v)
    local most = CityMost()
    if mix > most then mix = mix + (most - mix) * (city or 0) end
    cv.mix = mix
    if S.MinimapShown then S.MinimapShown(mix > 0.004) end   -- (la terre inexplorée cachée par-dessus : Map/Art.lua)
    local conts = Try("continents", ContinentsInView, u, v, hu, hv) or {}
    Try("minimap", UpdateMinimap, L.minimap, conts, u, v, hu, hv, mix)
    Try("underground cities' minimap", UpdateCityMinimap, u, v, hu, hv, inside)
    cv.gapTiles = Try("minimap in the gaps", UpdateGapMinimap, conts, u, v, hu, hv,
        DB.minimap and DB.gapMinimap and GAP_MIX * Smooth(steps, GAP_FADE) or 0)
    local under = Try("underground", UpdateUnderground, L.under, cont, u, v, hu, hv, steps) or 0
    -- le monde flou au-dessus d'une grotte reçoit un grain plus fort
    Try("grain", UpdateGrain, L.grain, u, v, hu, hv, math.max(soft, math.min(1.4, under * 1.4)))
    -- les noms des accroches faits une fois, pas une chaîne neuve à chaque image
    S.viewHookNames = S.viewHookNames or {}
    local names = S.viewHookNames
    for i, fn in ipairs(S.viewHooks) do
        local step = names[i]
        if not step then step = "view hook " .. i names[i] = step end
        Try(step, fn, u, v, hu, hv, zoom)
    end
    local n = 0
    for _ in pairs(tiles) do n = n + 1 end
    cv.tiles = n
    if start then
        local ms = debugprofilestop() - start
        cv.ms = (cv.ms or ms) * 0.9 + ms * 0.1
        cv.worst = math.max(cv.worst or 0, ms)
    end
end

---------------------------------------------------------------------------
-- La migration : les réglages du zoom rapproché d'OpenMap (MyMapIsRichDB.worldmap),
-- copiés une fois ; l'ancien n'est pas effacé
---------------------------------------------------------------------------
ns.On("MAP_ATTACHED", function()
    ns.Map.Migrate("close", function(old, new)
        for _, key in ipairs({ "minimap", "minimapMix", "minimapDeep", "minimapFrom", "cityMinimap", "soften", "underground", "gapMinimap" }) do
            if old[key] ~= nil then new.settings[key] = old[key] end
        end
    end)
end)
