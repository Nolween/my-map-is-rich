--------------------------------------------------------------------------------
-- Le dessin de la carte du monde, assemblé : toutes les cartes de zone sur un seul canevas, pour
-- que la carte passe d'une zone à la suivante en zoomant au lieu de changer de carte.
--
-- Les coordonnées sont des « unités du monde » : les pixels de l'art de la carte d'Azeroth (947).
-- Chaque carte est placée par C_Map.GetMapRectOnMap(carte, 947). L'art se bâtit une fois ;
-- Layout(hôte) le replace dans les unités du canevas d'une carte hôte, pour qu'il tienne dans
-- n'importe quel canevas (celui de notre vue, Map/View.lua).
--
-- Les couches, du bas vers le haut, et le zoom où chacune apparaît (zoom 1 : le monde entier
-- tient dans la vue) :
--   art du monde       toujours
--   art des continents CONT_FADE     (de larges bords adoucis cachent son cadre)
--   art de base des zones DETAIL_FADE (surtout du parchemin vide dans ce client ; il
--                                     se montre sur son territoire, MapTerritory : sa
--                                     terre et un peu au-delà, et toute terre de son
--                                     rectangle, jamais la mer ; il comble les trous)
--   morceaux des zones DETAIL_FADE   (les morceaux d'exploration coupés à la forme de la
--                                     zone : ceux explorés venus du client, les autres
--                                     de ns.MapReveal ; un bord fin adouci)
--   intérieurs         DETAIL_FADE   (les morceaux encore, par MapCore, depuis juste
--                                     à l'intérieur de chaque contour : la terre de chaque
--                                     zone passe sur le halo de parchemin des voisines)
--   villes             CITY_FADE x le zoom où la ville remplit la vue (pas de
--                                     morceaux à elles : l'art de base, un bord rond
--                                     adouci, pour que leurs abords ternes s'effacent)
--   icônes             chacune le sien (Map/PinSets.lua)
-- L'art du monde et des continents s'estompe une fois les zones dessus, jusqu'à un soupçon sur une
-- mer de la couleur de l'eau de l'art lui-même : les trous se lisent comme la mer, pas comme des lettres floues.
-- La mer garde la texture de Blizzard (S.SetSea) : le papier marbré de la haute mer
-- (MapSea) et les traits de vagues des côtes (MapHatch, sur la bande côtière de chaque
-- continent, MapCoast), tous deux tirés de l'art du continent et répétés à son échelle,
-- puis en octaves plus fines en approchant : plus de traits viennent avec le zoom.
-- Sa terre reste de la terre (PlaceLand : masque MapLand, teinte et grain du parchemin) : les
-- régions sans carte de zone (Quel'Thalas, Gilnéas...) rejoignent les zones comme de la terre.
-- L'art de chaque zone va aussi loin que Blizzard l'a peint (MapTerritory) : sa propre terre, la
-- mer au large de ses côtes (les hachures et îlots de Blizzard, pas les nôtres), et la terre autour
-- qu'aucune zone ne possède, partagée avec les voisines qui la peignent aussi. La terre qu'aucune
-- zone ne peint (ns.MapGaps) est le papier vide des cartes de zone (MapPaper par MapGapLand), où
-- leur art s'efface à son cadre ; il apparaît avec les zones.
-- L'harmonie des couleurs : l'art de chaque zone est dessiné une deuxième fois, teinté vers une
-- palette commune (ns.MapGrade), par un masque de sa bande de bord
-- (Media/Textures/MapBand/<uiMapID>) : à pleine force sur le contour de la zone,
-- s'effaçant vers l'intérieur, pour que bords et montagnes se passent la main en douceur et que
-- les couleurs propres de la zone restent en elle.
--
-- En code de My Map Is Rich depuis la 0.14.0 : c'est le dessin d'OpenMap (Map/Stitch.lua, licence MIT,
-- LICENSES/OpenMap.txt), porté dans Plus tel quel, ses commentaires traduits. Il se fait connaître par
-- ns.Map.SetArt ; le zoom rapproché (Map/Close.lua) s'y ajoute.
-- Le reste de Plus l'atteint par ns.Map.Art ; les icônes sont dans Map/PinSets.lua.
--------------------------------------------------------------------------------

local _, root = ...
local ns = root.Plus
-- (les tables de données et les outils du dessin d'OpenMap : par l'adaptateur, jusqu'en 1.0.0)
local D = ns.Map.Data.All()

local S = {}
ns.Map.SetArt(S)

local WORLD = 947
S.WORLD = WORLD

local CONT_FADE = { 1.3, 2.2 }  -- le zoom où chaque couche commence / finit d'apparaître
local CONT_IN, WORLD_OUT = { 1.3, 1.7 }, { 1.7, 2.2 }   -- (les continents arrivent en entier, puis la terre de l'art du monde sous eux s'en va)
local LABELS_OUT = { 3, 4 }     -- les noms des continents partent quand les zones (et leurs noms) arrivent
local SEA_LABELS_OUT = { 3.5, 5 } -- ... et ceux des mers un peu après (rien ne vient par-dessus)
local WORLD_SEA_OUT = { 4, 7 }  -- la mer de l'art du monde (le tourbillon, le navire...) reste l'océan jusqu'assez près (ses
                                --  lettres sont nettoyées à la main : tools/map-art) ; la texture de la mer prend le relais ensuite
local WORLD_COAST_OUT = { 3, 5 } -- ... mais au large des côtes, où ses hachures deviendraient énormes, bien plus tôt
local DETAIL_FADE = D.ClientMaps and D.ClientMaps.detailFade or { 3, 4.5 } -- (tard : l'art du continent, d'un
                                --  seul tenant, porte les zooms moyens ; celui d'un client : Data\<client>\Client.lua)
local DETAIL_HINT = { 1.8, 3, D.ClientMaps and D.ClientMaps.detailHint == false and 0 or 0.3 }   -- ... après un soupçon
                                --  de plus loin : où, et de quelle force
local CITY_FADE = { 0.2, 0.4 }  -- (les villes : la part du zoom où elles remplissent la vue : leur propre carte prend le relais
                                --  de la peinture qu'en fait la zone dès qu'elles en remplissent un cinquième à deux cinquièmes,
                                --  assez grand pour que leurs noms se lisent)
local CITY_FADE_OF = D.ClientMaps and D.ClientMaps.cityFadeOf or {   -- ... plus tôt là où la zone ne la peint
    [1454] = { 0.08, 0.25 },    --  que floue (Orgrimmar, sur celle de Durotar : un long fondu, sur la peinture de sa zone)
    [1456] = { 0.08, 0.25 },    --  (Les Pitons-du-Tonnerre, sur celle de Mulgore : avant que la bannière de sa zone parte)
}                               -- (les cartes de WoW Forever ; celles d'un autre client : Data\<client>\Client.lua)
local BANNER_OUT = { 0.25, 0.4 } -- ... et où la bannière de la zone pour une ville qui garde la sienne (ns.MapCityTitles)
                                --  lui cède la place : dès que celle-ci se lit (tools/map-preview/render.py fait pareil)
local UNDERGROUND_CITIES = D.ClientMaps and D.ClientMaps.underground or { [1458] = true, [1455] = true }   -- Fossoyeuse, Forgefer : la minicarte y
                                -- montre la surface, alors leur propre carte est dessinée par-dessus (et elle est tenue hors d'elles ;
                                -- la minicarte du jeu de l'intérieur de la ville passe sur leur carte : Close.lua ; de même dans
                                -- tools/map-preview/render.py et tools/map-caves/minimap.py)
local MUTE_FADE = { 4, 7 }      -- ... et où l'art du monde et des continents s'estompe
local SEA_FADE = { 1.2, 1.9 }   -- ... et où il quitte la mer (ses grandes lettres de mer), la texture de la mer prenant le relais
local UNDISCOVERED = { 0.05, 0.06, 0.08, 0.62 }   -- la terre inexplorée, ombrée (« dim ») : plus sombre et plus grise, sur
                                --  l'art des zones et la minicarte de près (un simple mélange : la carte reste opaque)
local SEA = { 0.50, 0.49, 0.41 } -- la couleur de la mer là où aucune carte n'en peint (MapSeaField couvre le reste)
local LAND_TINT, LAND_DESAT = { 0.96, 0.92, 0.84 }, 0.25   -- la terre sans carte, vers le parchemin de l'art des zones
local GRAIN_TILE = 14           -- unités du monde par case du grain du parchemin
local GRAIN_OCTAVES = { { 1, 0, 0.55 }, { 2.618, 0.37, 0.5 } }   -- { taille x, décalage (cases), force }
local BACK_MUTE = 0.92          -- de combien l'art du monde et des continents s'efface en s'estompant
local SEA_REACH = 1.5            -- jusqu'où la mer va au-delà de l'art du monde (en largeurs du monde, de chaque côté)
local SEA_TILE = 128            -- la case du papier de la mer, en pixels de l'art des continents (tools/map-preview/sea.py)
local HATCH_W, HATCH_H = 34, 84 -- ... la case des traits de vagues
local SEA_OCTAVE, HATCH_OCTAVE = 4, 7     -- le zoom où chacune commence à se diviser par deux, pour garder sa taille à l'écran
local HATCH_ALPHA = 0.6

local TEX = D.Media.tex
local FEATHER, FEATHER_THIN, FEATHER_WIDE = TEX .. "MapFeather", TEX .. "MapFeatherThin", TEX .. "MapFeatherWide"
local FEATHER_ROUND = TEX .. "MapFeatherRound"
local LAND, GRAIN = TEX .. "MapLand\\", TEX .. "MapGrain"
local BAND, TERRITORY, CORE = TEX .. "MapBand\\", TEX .. "MapTerritory\\", TEX .. "MapCore\\"
local ZONELAND = TEX .. "MapZoneLand\\"   -- (la terre de chaque zone sans sa mer peinte : render.py --bake-zone-land)
local EDGE = TEX .. "MapEdge\\"     -- le cadre propre de chaque zone, mesuré (tools/map-preview/render.py --bake-edges)
local SEA_DARK, SEA_LIGHT, SEA_FIELD = TEX .. "MapSeaDark", TEX .. "MapSeaLight", TEX .. "MapSeaField\\"
local SEA_FIELD_OUT = TEX .. "MapSeaFieldOut"   -- (la couleur de la mer du monde portée au-delà : sea_world.py)
local HATCH, COAST = TEX .. "MapHatch", TEX .. "MapCoast\\"
local PAPER_LAYERS = { { 1, 0, 1 }, { 2.618, 0.41, 0.5 } }   -- le papier des trous : { taille x, décalage (cases), alpha }
local SEA_MASK = TEX .. "MapSeaMask\\"
local SEA_OUT = TEX .. "MapSeaOut\\"   -- (la haute mer de chaque continent au-delà des bords de l'art du monde : tools/map-preview/sea_world.py)
local SEA_OPEN, SEA_COAST = TEX .. "MapSeaOpen\\947", TEX .. "MapSeaCoast\\947"   -- (la mer de l'art du monde, hors des côtes / au large : de même)
local GAP_LAND, PAPER = TEX .. "MapGapLand\\", TEX .. "MapPaper"
local W, H                      -- la taille de l'art de la carte du monde (unités du monde)
local namesFrame                -- (les lettres des noms : Letter, plus bas)
local labelsRoot, names = nil, {}   -- les noms lettrés (ns.MapLabels) : { frame, label }, bâtis à leur première apparition
local root, contRoot, tilesRoot, overlayRoot, coreRoot, blurRoot, citiesRoot, shadeRoot
local placed = {}               -- chaque région : { region, x, y, w, h } en unités du monde
local graded = {}               -- l'art des zones : { tex, mapID, piece } (piece : son morceau, ou false pour l'art de base)
local twins = {}                -- ses copies aux couleurs harmonisées, de même forme
local zoneTex = {}              -- mapID -> ses entrées harmonisées et jumelles (montrées / cachées avec la zone)
local inView = {}               -- mapID -> si la zone est près de la vue (S.Cull)
local detailLive = false        -- si le détail des zones est dessiné du tout (assez de zoom)
local ShowZone, GradeEntry      -- (plus bas)
local gradeNow = { 1, 0, "show" }   -- les réglages d'ApplyGrade
local culled = {}               -- d'autres régions montrées seulement près de la vue : { region, l, t, r, b } (0..1)
local backdrop = {}             -- les textures de l'art du monde et des continents (sur la terre)
local backdropSea = {}          -- ... le même art sur la mer (MapSeaMask), parti plus tôt
local worldArt = {}             -- lesquelles sont celles de la carte du monde (elle passe la main aux continents)
local worldCoast = {}           -- la mer de l'art du monde au large des côtes (ses hachures) : partie avant sa haute mer
local landFill = {}             -- la terre des continents gardée comme terre (copie de l'art + grain), montrée quand le fond s'estompe
local gapFill = {}              -- les cases qui comblent les trous (elles apparaissent avec le détail des zones)
local seaPaper = {}             -- le marbré du papier de la mer : deux octaves, une sombre et une claire chacune
local hatches = {}              -- par continent : { l, r, t, b, k (unités du monde par px d'art), tex = { deux octaves } }
local cities = {}               -- { frame, le zoom où elle remplit la vue (à peu près) }
local rects = {}                -- mapID -> { l, r, t, b } sur le monde, ou false
local host = { l = 0, t = 0, k = 1 }   -- la carte hôte : son coin (unités du monde) et ses unités par unité du monde
local zoomNow, scaleNow, muted, seaNow, worldOut, worldSea, worldCoastOut = 1, 1, -1, -1, -1, -1, -1
local detailNow, softNow = 1, 0   -- le fondu de zoom du détail des zones ; la force du flou
local underNow = 0              -- jusqu'où une grotte a fait surface (Close.lua)

-- une région amenée à l'alpha `a`, et cachée une fois partie (dessinée à alpha 0, une couche coûte
-- encore toute sa surface ; la plupart ont la taille du monde, beaucoup masquées)
-- (seulement quand ça change : ces couches tiennent des milliers de textures, et S.SetZoom tourne
-- plusieurs fois à l'ouverture de la carte)
local function Fade(region, a)
    if S.chartHide and S.chartHide[region] then a = 0 end   -- (rangée sous la carte marine : S.SetChart)
    if region.omFade == a then return end
    region.omFade = a
    region:SetAlpha(a)
    region:SetShown(a > 0.003)
end

-- L'art des zones cuit en cases du monde (ns.MapZoneArt, render.py --bake-zones) : aux réglages où il
-- a été cuit, dessiné à la place des couches vivantes des zones (tilesRoot, overlayRoot, coreRoot : des
-- centaines de textures masquées en vue) tant que la vue n'a pas dépassé les propres pixels des cases,
-- puis leur passant la main (FADE : px d'écran par px de case). `live` : la part des couches vivantes (0 : les cases seules, 1 : le vivant seul).
-- (Une seule table : le fichier est près de la limite de 200 variables locales de Lua)
-- Le passage de main est le même art sur le même art : les couches vivantes s'allument (à fond) sous les cases
-- un peu avant (WARM, du début de FADE : leurs fichiers se chargent pendant ce temps) et les cases s'effacent ;
-- et tant que leurs fichiers arrivent encore (busy) les cases restent (holding), sinon le parchemin nu des zones,
-- le premier de leurs fichiers à arriver, se montrait un instant entre les deux
-- desat : la désaturation propre aux cases, le reste du chemin de celle où elles sont cuites au réglage
-- (désaturer deux fois, c'est désaturer une fois de 1 - (1 - a)(1 - b)) : elles servent tout réglage de couleur
-- english : les cases sont cuites des fichiers du client anglais, noms lettrés sur l'art compris
-- lettered : des cases dans la langue du client : l'anglais, ou le jeu propre d'une autre langue s'il est
-- cuit (MapZones\<locale>\, de l'art de ce client : ns.MapZoneArt.locales) ; toute autre langue dessine
-- les zones en vivant, de l'art du client dans sa langue
-- (FADE s'arrête à 1,2, pas 1,6 : les cases font 16 px par unité du monde, moins de la moitié de l'art de la
-- plupart des zones ; au-delà d'un px d'écran par px de case, elles étaient grossies, molles, sur un art vivant
-- plus net, et les zooms moyens devenaient flous. Plus tôt dépassait le budget de perf.py pour un dézoom)
local Baked = { FADE = { 0.95, 1.2 }, WARM = 0.85, tiles = {}, use = false, live = 1, warm = false, busy = false, holding = false,
    path = TEX .. "MapZones\\", desat = 0, english = not GetLocale or GetLocale():sub(1, 2) == "en" }
Baked.lettered = Baked.english
if not Baked.english and D.MapZoneArt and D.MapZoneArt.locales and D.MapZoneArt.locales[GetLocale()] then
    Baked.path, Baked.lettered = TEX .. "MapZones\\" .. GetLocale() .. "\\", true
end

-- Les régions des couches vivantes des zones (tilesRoot, overlayRoot, coreRoot : des milliers de textures et
-- leurs masques) ne sont ancrées que tant qu'elles peuvent se montrer. Chaque région est posée sur root, et à
-- chaque image d'un déplacement ou d'un zoom le jeu remet en page tout ce qui y est ancré, caché ou non : des
-- milliers de textures cachées coûtent autant que l'art à l'écran. masks : mapID -> les fiches de ses masques ;
-- placed : mapID -> si elles sont ancrées ; seen : si le détail des zones se montre du tout
local Live = { masks = {}, placed = {}, seen = false }
function Live.Under(f)
    while f do
        if f == tilesRoot or f == overlayRoot or f == coreRoot then return true end
        f = f:GetParent()
    end
    return false
end

-- l'alpha des couches du détail des zones : le fondu du zoom, moins l'adoucissement et le souterrain
local appliedDetail, appliedSoft
local function ApplyDetail()
    local d = detailNow * (1 - 0.75 * underNow)
    -- (un client dont les zones arrivent continent par continent, ns.ClientMaps.detailDensity : le cadre de chaque
    -- zone au fondu de son continent, Live.contFade ; une pas encore arrivée est cachée, ses fichiers pas demandés : ShowZone)
    if Live.zones then
        for mapID, z in pairs(Live.zones) do
            local a = (Live.contFade[z.cont] or detailNow) * (1 - 0.75 * underNow)
            Fade(z.frame, a)
            if z.pieces then Fade(z.pieces, a) end
            local on = a > 0.003
            if z.on ~= on then
                z.on = on
                if inView[mapID] == true then ShowZone(mapID) end
            end
        end
    end
    if blurRoot and softNow ~= appliedSoft then
        appliedSoft = softNow
        Fade(blurRoot, d * softNow)
    end
    local live = Baked.use and Baked.live or 1
    local warm = Baked.use and Baked.warm or false
    -- (les cases tenues tant que les fichiers des zones arrivent, quelle que soit la raison : un zoom rapide
    -- amène plus de zones en vue après que les couches vivantes se sont allumées, et elles se montreraient en parchemin)
    Baked.holding = d > 0.001 and (live > 0 or warm) and Baked.use and Baked.busy or false
    local key = live + (warm and 2 or 0) + (Baked.holding and 4 or 0)
    if d == appliedDetail and key == Baked.applied then return end
    appliedDetail, Baked.applied = d, key
    -- (les couches vivantes à fond sous les cases, dès juste avant le passage de main : Baked, plus haut)
    local on, seen = d > 0.001 and (live > 0 or warm), d > 0.001
    local dl = on and d or 0
    if on ~= detailLive or seen ~= Live.seen then   -- (les fichiers des zones se chargent la première fois que leur détail se montre ; les
        detailLive, Live.seen = on, seen             --  régions des couches vivantes sont ancrées tant qu'elles se montrent, ShowZone)
        for mapID in pairs(zoneTex) do
            if inView[mapID] == true then ShowZone(mapID) end
        end
    end
    tilesRoot:SetShown(on)
    overlayRoot:SetShown(on)
    tilesRoot:SetAlpha(Live.zones and (on and 1 or 0) or dl)   -- (celui de chaque zone, plus haut, là où elles arrivent par continent)
    for _, tex in ipairs(gapFill) do tex:SetAlpha(d) end
    overlayRoot:SetAlpha(Live.zones and (on and 1 or 0) or dl)
    -- les intérieurs (une deuxième copie des morceaux de chaque zone) seulement avec les zones elles-mêmes :
    -- sous le léger soupçon de plus loin, ils se verraient à peine, sur les deux continents à la fois
    Fade(coreRoot, on and math.max(0, (d - DETAIL_HINT[3]) / (1 - DETAIL_HINT[3])) or 0)
    if blurRoot then Fade(blurRoot, d * softNow) end
    if Baked.frame then
        -- (les couches vivantes s'empilent : l'art de base d'une zone et ses morceaux, chacun à d, couvrent 1 - (1 - d)^2
        -- de ce qui est dessous ; les cases sont tout cela en un, alors elles sont dessinées aussi fort)
        -- (la tenue adoucie, pas d'un coup : elle va et vient bien des fois pendant un déplacement ou un zoom, et les cases,
        -- une zone pas trouvée non grisée dedans, sautaient par-dessus l'art vivant grisé : la terre inexplorée clignotait.
        -- Baked.easer, plus bas)
        Baked.want = Baked.holding and 1 or 0
        if Baked.hold == nil then Baked.hold = Baked.want end
        if Baked.hold ~= Baked.want and Baked.easer then Baked.easer:Show() end
        local gone = live * (1 - Baked.hold)
        Fade(Baked.frame, math.floor((1 - (1 - d) ^ 2) * (1 - gone) * 100 + 0.5) / 100)
        Baked.Cull()
    end
end
-- la tenue des cases cuites vers Baked.want : vite à l'arrivée (le parchemin se verrait), lentement au départ (taux par seconde)
Baked.easer = CreateFrame("Frame")
Baked.easer:Hide()
Baked.easer:SetScript("OnUpdate", function(self, elapsed)
    local want, h = Baked.want or 0, Baked.hold or 0
    h = h + (want - h) * math.min(1, elapsed * (want > h and 12 or 3))
    if math.abs(want - h) < 0.02 then h = want self:Hide() end
    Baked.hold = h
    appliedDetail = nil                     -- (ApplyDetail de nouveau, pour l'alpha des cases)
    ApplyDetail()
end)
S.stats = { zones = 0, tiles = 0, overlays = 0, pins = 0, cities = {} }
S.viewHooks = {}                -- fn(u, v, hu, hv, zoom) à chaque déplacement ou zoom (le S.SetView de Close.lua les appelle)

--------------------------------------------------------------------------------
-- La géométrie
--------------------------------------------------------------------------------

-- le rectangle d'une carte sur le monde (0..1), gardé ; nil quand elle n'y est pas
function S.Rect(mapID)
    local r = rects[mapID]
    if r == nil then
        if mapID == WORLD then
            r = { 0, 1, 0, 1 }
        else
            -- (une ville, dans un client qui a un monde à lui : d'après la place de ses coins dans le monde,
            -- comme le joueur, son maître de vol et la minicarte sont placés. Le rectangle de retail sur la carte
            -- d'Azeroth, atteint par sa zone et son continent, se trompe de dizaines de mètres pour Hurlevent : ta
            -- flèche et les icônes de Blizzard dessus étaient à côté de leur place, le rapport d'un joueur)
            local w = D.MapWorld
            if w and w.zones and w.zones[mapID] == 2 and S.FromYards then
                local ok0, c0, p0 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
                local ok1, c1, p1 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
                if ok0 and ok1 and p0 and p1 and c0 == c1 then
                    local u0, v0 = S.FromYards(c0, D.Safe.XY(p0))
                    local u1, v1 = S.FromYards(c1, D.Safe.XY(p1))
                    if u0 and u1 and math.abs(u1 - u0) > 1e-6 and math.abs(v1 - v0) > 1e-6 then
                        r = { math.min(u0, u1), math.max(u0, u1), math.min(v0, v1), math.max(v0, v1) }
                    end
                end
            end
            if not r then
                local ok, l, rr, t, b = pcall(C_Map.GetMapRectOnMap, mapID, WORLD)
                r = (ok and l and rr > l and b > t) and { l, rr, t, b } or false
            end
        end
        rects[mapID] = r
    end
    if r then return r[1], r[2], r[3], r[4] end
end

function S.Size() return W, H end

-- si une carte est assemblée dans le monde, et comme quoi (1 : une zone, 2 : une ville, 3 : un continent) :
-- un client qui a un monde à lui en donne la liste (ns.MapWorld, tools/map-data/world.py) ; sinon chaque
-- continent et zone de la carte d'Azeroth l'est (nil : comme son art le fait). `host` : comme la carte
-- du jeu la montre, qui peut être une autre version d'une carte assemblée (ns.MapWorld.alias : Uldum assiégé)
function S.Stitched(mapID, host)
    local world = D.MapWorld
    if not world then return true end
    if not world.kind then
        world.kind = {}
        for _, id in ipairs(world.continents or {}) do world.kind[id] = 3 end
        for id, k in pairs(world.zones or {}) do world.kind[id] = k end
    end
    if host and world.alias and world.alias[mapID] then mapID = world.alias[mapID] end
    return world.kind[mapID] ~= nil or mapID == WORLD, world.kind[mapID]
end

-- la taille de l'art d'une carte (unités de son canevas)
local function ArtSize(mapID)
    local layers = C_Map.GetMapArtLayers(mapID)
    local layer = layers and layers[1]
    if layer then return layer.layerWidth, layer.layerHeight, layer end
end
S.ArtSize = ArtSize

-- la zone / le continent le plus fin sous un point du monde (0..1), avec la chaîne
-- depuis le monde : { 947, continent, zone }, et la zone d'une ville avant elle : { 947, continent, zone, ville }.
-- La carte d'une ville est l'enfant de son continent dans les tables du jeu, et le continent la donne pour tout
-- point de son rectangle, qui déborde loin sur sa zone : près de Forgefer (Kharanos), la carte dessous passait
-- à la ville et un clic y zoomait, et Dun Morogh n'était jamais dans la chaîne (rapports de joueurs).
-- Une ville ne compte donc qu'au milieu de son rectangle (CITY_EDGE : la part de chaque côté laissée à sa zone)
function S.ChainAt(u, v)
    local CITY_EDGE = 0.25          -- (pas une variable locale du fichier : il est à la limite de 200 de Lua)
    local chain = { WORLD }
    if not D.Safe.Finite(u, v) then return chain end   -- (le jeu lève une erreur sur un point NaN : #261)
    local mapID, x, y = WORLD, u, v
    for _ = 1, 4 do
        local info = C_Map.GetMapInfoAtPosition(mapID, x, y)
        if not info or info.mapID == mapID then break end
        if info.mapType ~= Enum.UIMapType.Continent and info.mapType ~= Enum.UIMapType.Zone then break end
        local l, r, t, b = C_Map.GetMapRectOnMap(info.mapID, mapID)
        if not l or r <= l or b <= t then break end
        local cx, cy = (x - l) / (r - l), (y - t) / (b - t)
        local zone = D.MapCityZones and D.MapCityZones[info.mapID]
        local zl, zr, zt, zb
        if zone then zl, zr, zt, zb = C_Map.GetMapRectOnMap(zone, mapID) end
        if zl and zr > zl and zb > zt then
            tinsert(chain, zone)
            if math.min(cx, 1 - cx) < CITY_EDGE or math.min(cy, 1 - cy) < CITY_EDGE then break end
        end
        mapID, x, y = info.mapID, cx, cy
        tinsert(chain, mapID)
    end
    return chain
end

--------------------------------------------------------------------------------
-- Poser l'art (en unités du monde ; Layout l'ancre)
--------------------------------------------------------------------------------

local function Pow2(n)
    local p = 16
    while p < n do p = p * 2 end
    return p
end

-- les cases de l'art d'une carte (identifiants de fichier, ligne par ligne) : celles du client, avec les
-- cases nettoyées à la main (ns.MapArtEdits, tools/map-art) à leur place
local function ArtFiles(mapID)
    local files = C_Map.GetMapArtLayerTextures(mapID, 1)
    local edits = D.MapArtEdits and D.MapArtEdits[mapID]
    if not files or not edits then return files end
    local out = {}
    for i, f in ipairs(files) do out[i] = f end
    for _, i in ipairs(edits) do out[i] = TEX .. "MapArt\\" .. mapID .. "_" .. i end
    return out
end

local PlaceRecord, ForEachPiece
local function Record(region, x, y, w, h)
    -- une région dans un cadre décalé (les copies du flou) pend à ce cadre
    local parent = region:GetParent()
    local rec = { region, x, y, w, h, rel = parent and parent.omShift and parent or nil }
    placed[#placed + 1] = rec
    region.omRec = rec
    PlaceRecord(rec)
    -- les fiches des ombres de l'inexploré, rassemblées par couche (Shade.Anchor)
    local c = S.recCollect
    if c then c[#c + 1] = rec end
end

-- Le rectangle de l'art d'une carte en unités du monde : gauche, haut, échelle x, échelle y
local function Place(mapID)
    local aw, ah, layer = ArtSize(mapID)
    local l, r, t, b = S.Rect(mapID)
    if not aw or not l then return end
    return { left = l * W, top = t * H, sx = (r - l) * W / aw, sy = (b - t) * H / ah, layer = layer, mapID = mapID }
end

-- un masque sur tout l'art d'une carte (bords adoucis, ou la bande de bord d'une zone)
local function Feather(parent, p, file)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    Record(mask, p.left, p.top, p.layer.layerWidth * p.sx, p.layer.layerHeight * p.sy)
    if p.mapID and Live.Under(parent) then         -- (celui d'une couche vivante : ancré tant que l'art de la zone peut se montrer)
        local list = Live.masks[p.mapID] or {}
        Live.masks[p.mapID] = list
        list[#list + 1] = mask.omRec
    end
    return mask
end

-- Une image w x h en (x, y) dans l'art d'une carte, coupée en cases (identifiants ligne par ligne).
-- Les cases de base sont des fichiers tw x th entiers, rognés au bord de l'art ; celles du bord des
-- morceaux vont à la puissance de deux suivante. `mask2` : un second masque sur les cases ;
-- `band` : dessine aussi une copie harmonisée par ce masque.
-- l'art des morceaux d'une zone est dessiné sans sa bannière d'une ville (ns.MapBannerHoles) : la copie
-- de la bannière se montre à la place, et part de près (S.SetZoom). Les copies sont coupées de l'art du
-- client anglais, lettrées en anglais : une autre langue garde la bannière de la zone, dans sa
-- langue (celle des Pitons-du-Tonnerre en esMX, de Darnassus en zhCN : #47)
local holeMasks = {}
local function BannerHole(parent, p)
    if not Baked.english then return end
    if not (p.mapID and D.MapBannerHoles and D.MapBannerHoles[p.mapID]) then return end
    local key = tostring(parent) .. p.mapID
    holeMasks[key] = holeMasks[key] or Feather(parent, p, TEX .. "MapBannerHole\\" .. p.mapID)
    return holeMasks[key]
end

local function PlaceTiles(parent, p, files, x, y, w, h, drawLayer, sub, overlay, mask, list, piece, band, mask2)
    local tw, th = p.layer.tileWidth, p.layer.tileHeight
    local cols, rows = math.ceil(w / tw), math.ceil(h / th)
    local n = 0
    local layer = Live.Under(parent)               -- (celle d'une couche vivante des zones : montrée seulement avec les couches)
    for j = 1, rows do
        local ph = (j < rows) and th or (h - (rows - 1) * th)
        local fh = (j < rows or not overlay) and th or Pow2(ph)
        for k = 1, cols do
            local f = files[(j - 1) * cols + k]
            local file = tonumber(f) or f              -- (un identifiant de fichier, ou le chemin d'une case retouchée)
            local pw = (k < cols) and tw or (w - (cols - 1) * tw)
            local fw = (k < cols or not overlay) and tw or Pow2(pw)
            -- (une case dont son masque ne laisse rien, ou vide : aucune, ns.MapBlank et ns.MapOff)
            if file and pw > 0 and ph > 0 and not (overlay and D.MapBlank and D.MapBlank[file])
                and not (p.off and not overlay and p.off[(j - 1) * cols + k]) then
                local tx, ty = p.left + (x + (k - 1) * tw) * p.sx, p.top + (y + (j - 1) * th) * p.sy
                -- les textures d'une zone reçoivent leur fichier une fois la zone en vue (ShowZone) : ouvrir la
                -- carte charge ce qui y est, pas le monde entier
                local lazy = band or list == graded              -- (ShowZone les met en file ; celles d'un fond trié, S.Cull)
                    or list == backdrop and D.ClientMaps and D.ClientMaps.cullBackdrop
                for copy = 1, band and 2 or 1 do
                    local tex = parent:CreateTexture(nil, drawLayer, nil, sub + (copy - 1) * 2)
                    if lazy then tex.omFile = file else tex:SetTexture(file, nil, nil, "TRILINEAR") end
                    tex:SetTexCoord(0, pw / fw, 0, ph / fh)
                    Record(tex, tx, ty, pw * p.sx, ph * p.sy)
                    if mask then tex:AddMaskTexture(mask) end
                    local hole = overlay and BannerHole(parent, p)
                    if hole then tex:AddMaskTexture(hole) end
                    -- (une texture de zone garde son rectangle sur le monde, 0..1 : ShowZone ne montre que
                    -- celles près de la vue)
                    local u0, v0, u1, v1 = tx / W, ty / H, (tx + pw * p.sx) / W, (ty + ph * p.sy) / H
                    if copy == 2 then
                        tex:AddMaskTexture(band)
                        local e = { tex, p.mapID, piece, twin = true, layer = layer, u0 = u0, v0 = v0, u1 = u1, v1 = v1 }
                        twins[#twins + 1] = e
                        local list = zoneTex[p.mapID] or {}
                        zoneTex[p.mapID] = list
                        list[#list + 1] = e
                    else
                        if mask2 then tex:AddMaskTexture(mask2) end
                        if list == graded then
                            local e = { tex, p.mapID, piece, layer = layer, u0 = u0, v0 = v0, u1 = u1, v1 = v1,
                                under = not overlay and p.under and p.under[(j - 1) * cols + k],
                                blur = parent.omShift or nil }   -- (celle d'une copie du flou : ShowZone)
                            graded[#graded + 1] = e
                            local list = zoneTex[p.mapID] or {}
                            zoneTex[p.mapID] = list
                            list[#list + 1] = e
                        elseif list then
                            list[#list + 1] = tex
                        end
                    end
                end
                n = n + 1
            end
        end
    end
    return n
end

-- les masques générés de la zone (MapBand, MapTerritory, MapCore) sur `parent` ; seules les zones
-- harmonisées en ont (et les territoires d'un client sans le reste : ns.MapTerritories)
local function ZoneMask(parent, p, folder)
    if D.MapGrade and D.MapGrade[p.mapID] then return Feather(parent, p, folder .. p.mapID) end
    if folder == TERRITORY and D.MapTerritories and D.MapTerritories[p.mapID] then return Feather(parent, p, folder .. p.mapID) end
end

-- L'art de base d'une carte (toute sa couche), bords adoucis par `feather` s'il est donné ;
-- celui d'une zone ne se montre que sur son territoire, qui finit à son propre cadre, et sa copie
-- harmonisée avec lui (`feather` par-dessus effaçait sa peinture bien à l'intérieur du cadre, et là où rien
-- d'autre ne prenait le relais, le papier se montrait : une bande orange le long de la côte est d'Arathi)
local function PlaceBase(parent, mapID, drawLayer, list, feather)
    local p = Place(mapID)
    if not p then return 0 end
    local files = ArtFiles(mapID)
    if not files or #files == 0 then return 0 end
    local territory = list == graded and ZoneMask(parent, p, TERRITORY)
    local mask = territory or (feather and Feather(parent, p, feather))
    local band = list == graded and ZoneMask(parent, p, BAND)
    p.under = D.MapUnder and D.MapUnder[mapID]   -- (ses cases entièrement sous la peinture de ses morceaux : ShowZone)
    p.off = territory and D.MapOff and D.MapOff[mapID]   -- (... et entièrement hors de son territoire : aucune)
    return PlaceTiles(parent, p, files, 0, 0, p.layer.layerWidth, p.layer.layerHeight, drawLayer, 0, false, mask, list, false, band)
end

-- L'art du monde et des continents comme fond, deux fois : sur sa terre et sa bande côtière (backdrop,
-- MapBackLand : le halo des hauts-fonds et les hachures de Blizzard restent avec la terre) et sur sa
-- haute mer (backdropSea, MapSeaMask), pour que les lettres de la mer partent avant la terre
local function PlaceBackdrop(parent, mapID, drawLayer, feather)
    local p = Place(mapID)
    if not p then return end
    local files = ArtFiles(mapID)
    if not files or #files == 0 then return end
    local mask = feather and Feather(parent, p, feather)
    if D.ClientMaps and D.ClientMaps.sea == false then
        -- (un client dont l'art peint sa propre mer : l'art tel quel, une fois ; celui d'un continent sur sa terre et
        -- les hauts-fonds autour, ns.MapBackLands (territory.py), l'art du monde se montrant au-delà ; près de la vue
        -- seulement, ses fichiers chargés à son approche : S.Cull)
        local n = #backdrop
        local land = D.MapBackLands and D.MapBackLands[mapID] and Feather(parent, p, TEX .. "MapBackLand\\" .. mapID)
        PlaceTiles(parent, p, files, 0, 0, p.layer.layerWidth, p.layer.layerHeight, drawLayer, 0, false, mask, backdrop, false, nil, land)
        for i = n + 1, #backdrop do
            local tex, rec = backdrop[i], backdrop[i].omRec
            if D.ClientMaps.cullBackdrop then
                culled[#culled + 1] = { tex, rec[2] / W, rec[3] / H, (rec[2] + rec[4]) / W, (rec[3] + rec[5]) / H, layer = parent }
            end
        end
        return
    end
    local sea = Feather(parent, p, mapID == WORLD and SEA_OPEN or SEA_MASK .. mapID)
    local land = Feather(parent, p, TEX .. "MapBackLand\\" .. mapID)   -- (sa terre et sa bande côtière : elles restent)
    PlaceTiles(parent, p, files, 0, 0, p.layer.layerWidth, p.layer.layerHeight, drawLayer, 0, false, mask, backdrop, false, nil, land)
    PlaceTiles(parent, p, files, 0, 0, p.layer.layerWidth, p.layer.layerHeight, drawLayer, 0, false, mask, backdropSea, false, nil, sea)   -- (même sous-niveau : les masques ne se chevauchent pas)
    if mapID == WORLD then
        PlaceTiles(parent, p, files, 0, 0, p.layer.layerWidth, p.layer.layerHeight, drawLayer, 0, false, mask, worldCoast, false, nil,
            Feather(parent, p, SEA_COAST))
    end
    return mask
end

-- La terre d'un continent gardée comme terre une fois le fond estompé en mer (les régions sans
-- carte de zone, comme Quel'Thalas au nord des Maleterres) : MapLand, un champ de couleur doux
-- de la terre de l'art du continent (sans ses traits d'encre ni ses noms), réchauffé
-- vers le parchemin de l'art des zones, avec le grain du parchemin à l'échelle de l'art des zones
local function PlaceLand(mapID)
    local p = Place(mapID)
    if not p then return end
    local w, h = p.layer.layerWidth * p.sx, p.layer.layerHeight * p.sy
    local mask, land = Feather(contRoot, p, FEATHER_WIDE), Feather(contRoot, p, LAND .. mapID)
    local field = contRoot:CreateTexture(nil, "ARTWORK", nil, 2)
    field:SetTexture(LAND .. mapID, nil, nil, "LINEAR")
    field:SetVertexColor(LAND_TINT[1], LAND_TINT[2], LAND_TINT[3])
    field:SetDesaturation(LAND_DESAT)
    Record(field, p.left, p.top, w, h)
    field:AddMaskTexture(mask)
    landFill[#landFill + 1] = field
    -- le grain deux fois, à des tailles et des décalages qui ne s'alignent pas : sur une grande étendue
    -- de terre nue, il ne se répète jamais
    for _, o in ipairs(GRAIN_OCTAVES) do
        local grain = contRoot:CreateTexture(nil, "ARTWORK", nil, 6)
        local size = GRAIN_TILE * o[1]
        grain:SetTexture(GRAIN, "REPEAT", "REPEAT")
        grain:SetTexCoord(o[2], o[2] + w / size, o[2] * 1.7, o[2] * 1.7 + h / size)
        grain:SetVertexColor(1, 1, 1, o[3])
        Record(grain, p.left, p.top, w, h)
        grain:AddMaskTexture(mask)
        grain:AddMaskTexture(land)
        landFill[#landFill + 1] = grain
    end

    -- les trous entre et autour de ses zones (ns.MapGaps, tools/map-preview/gapfill.py) : du papier de
    -- carte vide par un masque de là où est la terre (l'art des zones s'y efface)
    local gaps = D.MapGaps and D.MapGaps[mapID]
    if gaps then
        local size, paper = D.MapGaps.tile, D.MapGaps.paper
        for k = 1, #gaps - 2, 3 do
            local i, j = gaps[k], gaps[k + 1]
            local name = mapID .. "_" .. i .. "_" .. j
            local x, y = p.left + i * size, p.top + j * size
            if paper then
                local land = contRoot:CreateMaskTexture()
                land:SetTexture(GAP_LAND .. name, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                Record(land, x, y, size, size)
                -- deux fois, à des tailles et des décalages qui ne s'alignent jamais : il ne se lit pas comme carrelé
                for n, o in ipairs(PAPER_LAYERS) do
                    local tex = contRoot:CreateTexture(nil, "ARTWORK", nil, 2 + n)
                    local s_ = paper * o[1]
                    tex:SetTexture(PAPER, "REPEAT", "REPEAT")
                    tex:SetTexCoord(x / s_ + o[2], (x + size) / s_ + o[2], y / s_ + o[2] * 1.7, (y + size) / s_ + o[2] * 1.7)
                    tex:SetVertexColor(1, 1, 1, o[3])
                    Record(tex, x, y, size, size)
                    tex:AddMaskTexture(land)
                    tex:AddMaskTexture(mask)
                    gapFill[#gapFill + 1] = tex
                    culled[#culled + 1] = { tex, x / W, y / H, (x + size) / W, (y + size) / H }
                end
            end
        end
    end

    -- ses traits de vagues côtiers : deux octaves par la bande côtière, entre
    -- l'art du continent et la terre (posés par S.SetSea)
    local coast = Feather(contRoot, p, COAST .. mapID)
    local l, r, t, b = S.Rect(mapID)
    local h = { l, r, t, b, k = (r - l) * W / p.layer.layerWidth, mapID = mapID, tex = {} }
    for i = 1, 2 do
        local tex = contRoot:CreateTexture(nil, "ARTWORK", nil, 1)
        tex:SetTexture(HATCH, "REPEAT", "REPEAT")
        tex:AddMaskTexture(coast)
        tex:Hide()
        h.tex[i] = tex
    end
    hatches[#hatches + 1] = h
end

-- chaque morceau d'une zone : fn(files, x, y, w, h, sublevel, piece). Un morceau est
-- { key, unexplored }, une table par morceau partagée par toutes ses copies (morceau, intérieur,
-- flou), pour que S.RefreshExplored puisse la retourner quand le joueur l'explore.
local overlayZones = {}         -- les zones qui ont des morceaux
local pieces = {}               -- mapID -> clé -> morceau
local function Piece(mapID, key, unexplored)
    local list = pieces[mapID] or {}
    pieces[mapID] = list
    local piece = list[key] or { key = key }
    list[key] = piece
    piece.unexplored = unexplored
    return piece
end
ForEachPiece = function(mapID, fn)
    local explored = C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}
    local reveal = D.MapReveal and D.MapReveal[C_Map.GetMapArtID(mapID) or 0]
    local seen = {}
    for _, info in ipairs(explored) do
        local key = info.textureWidth .. ":" .. info.textureHeight .. ":" .. info.offsetX .. ":" .. info.offsetY
        seen[key] = true
        if not info.isShownByMouseOver then
            fn(info.fileDataIDs, info.offsetX, info.offsetY, info.textureWidth, info.textureHeight, 1, Piece(mapID, key, false))
        end
    end
    for key, ids in pairs(reveal or {}) do
        if not seen[key] then
            local w, h, x, y = strsplit(":", key)
            fn({ strsplit(",", ids) }, tonumber(x), tonumber(y), tonumber(w), tonumber(h), 0, Piece(mapID, key, true))
        end
    end
end

-- Les morceaux d'une zone : ceux explorés venus du client, les autres des données de révélation.
-- Dessinés deux fois : entiers (avec leurs halos de parchemin) sur overlayRoot, et leur
-- intérieur (MapCore) sur coreRoot, au-dessus du halo de chaque zone.
local function PlaceOverlays(mapID)
    local p = Place(mapID)
    if not p then return 0 end
    local explored = C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}
    local reveal = D.MapReveal and D.MapReveal[C_Map.GetMapArtID(mapID) or 0]
    if #explored == 0 and not reveal then return 0 end
    -- (un client dont les zones arrivent continent par continent : celle de chaque zone sur un cadre à elle,
    -- en fondu avec son art de base, S.ZoneByContinent)
    local parent = overlayRoot
    if D.ClientMaps and D.ClientMaps.detailDensity then
        parent = CreateFrame("Frame", nil, overlayRoot)
        parent:SetAllPoints(root)
        parent:SetFrameLevel(overlayRoot:GetFrameLevel())
        Live.overlayOf = Live.overlayOf or {}
        Live.overlayOf[mapID] = parent
    end
    -- à l'intérieur du cadre propre de la zone (mesuré par zone : la terre qu'elle peint jusqu'au bord se montre ;
    -- la mer s'y estompe)
    local mask = ZoneMask(parent, p, EDGE) or Feather(parent, p, FEATHER_THIN)
    local band = ZoneMask(parent, p, BAND)
    local core = ZoneMask(coreRoot, p, CORE)
    local coreThin = core and (ZoneMask(coreRoot, p, EDGE) or Feather(coreRoot, p, FEATHER_THIN))
    -- (sans les intérieurs, sur son territoire là où elle en a un : ses halos jamais sur la terre d'une voisine)
    local territory = not core and ZoneMask(parent, p, TERRITORY) or nil
    local n = 0
    ForEachPiece(mapID, function(files, x, y, w, h, sub, piece)
        n = n + PlaceTiles(parent, p, files, x, y, w, h, "ARTWORK", sub, true, mask, graded, piece, band, territory)
        if core then
            PlaceTiles(coreRoot, p, files, x, y, w, h, "ARTWORK", sub, true, coreThin, graded, piece, nil, core)
        end
    end)
    overlayZones[#overlayZones + 1] = mapID
    return n
end

--------------------------------------------------------------------------------
-- Les icônes : à My Map Is Rich depuis sa 0.13.0 (Map/PinSets.lua : jeux d'icônes, icônes, traits,
-- ta flèche). Gardé ici : les régions posées en unités du monde depuis la construction (les couches
-- de Close.lua, les ancres des icônes : S.PlaceWorld) et la façon de poser une fiche
--------------------------------------------------------------------------------

local dynamic = {}              -- région -> fiche : les ancres et les couches de près (ajoutées et retirées souvent)

-- pose la région d'une fiche, une fois, en unités du monde : celles de root (Layout met root
-- à l'échelle de la carte hôte : rien n'est reposé quand l'hôte change)
PlaceRecord = function(rec)
    local region = rec[1]
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", rec.rel or root, "TOPLEFT", rec[2], -rec[3])
    region:SetSize(rec[4], rec[5])
end

local cullBox                   -- la dernière vue que S.Cull a vue, avec sa marge : { u0, v0, u1, v1 }
local NONE = {}                 -- (une liste vide à parcourir, gardée : pas une neuve à chaque image)

-- les trous peints à la main, allumés ou éteints (éteints : le papier des trous, comme avant). Les
-- cases cuites les ont, alors éteints, les couches vivantes dessinent (S.ApplyGrade : à appeler après)
function S.SetGapFillsShown(shown)
    Baked.noFills = not shown
    if S.fillRoot then S.fillRoot:SetShown(shown and true or false) end
end

--------------------------------------------------------------------------------
-- Les yards du monde -> la carte du monde (0..1), par les coins de chaque continent
--------------------------------------------------------------------------------

local CONTINENT_MAP = { [0] = 1415, [1] = 1414 }
local corners = {}              -- continent -> { x0, y0, x1, y1, mapID } ou false

local function Corners(cont)
    local c = corners[cont]
    if c ~= nil then return c end
    c = false
    local mapID = CONTINENT_MAP[cont]
    local ok0, _, p0 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
    local ok1, _, p1 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
    if mapID and ok0 and ok1 and p0 and p1 then
        local x0, y0 = D.Safe.XY(p0)
        local x1, y1 = D.Safe.XY(p1)
        c = { x0, y0, x1, y1, mapID }
    end
    corners[cont] = c
    return c
end

-- les deux façons dont le vecteur des coins et les X / Y du monde peuvent s'aligner sur les x / y de
-- la carte ; `swap` en choisit une. (D'habitude le vecteur est (X, Y du monde) et le x de la carte
-- suit le Y du monde : HereBeDragons le lit comme haut, gauche.)
local function Project(c, wx, wy, swap)
    local mx, my
    if swap then
        mx, my = (wx - c[1]) / (c[3] - c[1]), (wy - c[2]) / (c[4] - c[2])
    else
        mx, my = (wy - c[2]) / (c[4] - c[2]), (wx - c[1]) / (c[3] - c[1])
    end
    local l, r, t, b = S.Rect(c[5])
    if not l then return end
    return l + mx * (r - l), t + my * (b - t)
end

local swap
-- une position du monde (yards sur le continent 0 / 1) sur la carte d'Azeroth (0..1). Un client qui a un monde
-- à lui y a les régions de chaque carte du jeu (ns.MapWorld.yards, tools/map-data/world.py : dans la boîte
-- d'une région, u = au + bu * y, v = av + bv * x) ; une position dans aucune (celles de l'Outreterre, sur la
-- carte du jeu des îles draeneï) n'est pas sur le monde assemblé. (Un peu au-delà de la boîte d'une région,
-- elle l'est encore : la terre de sa carte peut dépasser la boîte que la carte d'Azeroth lui donne, comme Quel'Thalas)
function S.FromYards(cont, wx, wy)
    local yards = D.MapWorld and D.MapWorld.yards
    if yards then
        for _, r in ipairs(yards[cont] or NONE) do
            local mx, my = (r[2] - r[1]) * 0.2, (r[4] - r[3]) * 0.2
            if wx >= r[1] - mx and wx <= r[2] + mx and wy >= r[3] - my and wy <= r[4] + my then
                return r[5] + r[6] * wy, r[7] + r[8] * wx
            end
        end
        return
    end
    local c = Corners(cont)
    if not c then return end
    if swap == nil then
        -- l'ordre des axes réglé une fois : le maître de vol de Hurlevent (-8840.6, 489.7) est dans Elwynn / Hurlevent
        local wc = Corners(0)
        swap = false
        if wc then
            for _, try in ipairs({ false, true }) do
                local u, v = Project(wc, -8840.6, 489.7, try)
                for _, zone in ipairs({ 1429, 1453 }) do
                    local l, r, t, b = S.Rect(zone)
                    if u and l and u >= l and u <= r and v >= t and v <= b then swap = try end
                end
            end
        end
    end
    return Project(c, wx, wy, swap)
end

--------------------------------------------------------------------------------
-- Construire, mettre en page, zoomer
--------------------------------------------------------------------------------

-- (ns.ClientMaps.detailDensity) le cadre d'une zone, en fondu avec les zones de son continent (ApplyDetail) :
-- Live.zones, et les px d'art par unité du monde de chaque continent sur cette densité (Live.contK : S.SetZoom en règle DETAIL_FADE)
function S.ZoneByContinent(mapID, frame)
    local cont = mapID
    for _ = 1, 8 do
        local info = C_Map.GetMapInfo(cont)
        if not info or info.mapType == Enum.UIMapType.Continent or not info.parentMapID then break end
        cont = info.parentMapID
    end
    Live.zones, Live.contK, Live.contFade = Live.zones or {}, Live.contK or {}, Live.contFade or {}
    Live.zones[mapID] = { frame = frame, cont = cont, pieces = Live.overlayOf and Live.overlayOf[mapID] }
    if Live.contK[cont] == nil then
        local aw = ArtSize(cont)
        local l, r = S.Rect(cont)
        Live.contK[cont] = aw and l and r > l and aw / ((r - l) * W) / D.ClientMaps.detailDensity or 1
    end
end

-- Bâtit tout sur `parent` (le canevas de la vue) : les cadres de l'art depuis `artLevel`
-- (il lui faut `range` niveaux), les icônes à `iconLevel`.
-- La construction, toute (S.Build), ou quelques ms par image (S.BuildSoon : après l'écran de chargement, pour
-- que ni elle ni la première ouverture de la carte ne la portent toute). S.Pace, entre ses étapes, rend
-- l'image une fois sa tranche usée ; une construction en cours quand la carte s'ouvre est finie aussitôt.
-- (Sur S, pas en variables locales : le fichier est à la limite de 200 de Lua)
S.PACE_MS = 4
function S.Pace()
    local p = S.pace
    if p and not p.rush and coroutine.running() == p.co and debugprofilestop() - p.t0 > S.PACE_MS then
        coroutine.yield()
    end
end

-- une tranche d'une construction sur plusieurs images ; false une fois finie (ou ratée : l'erreur est montrée)
function S.PaceStep()
    local p = S.pace
    if not p then return false end
    p.t0 = debugprofilestop()
    local ok, err = coroutine.resume(p.co)
    p.ms = p.ms + debugprofilestop() - p.t0
    if ok and coroutine.status(p.co) ~= "dead" then return true end
    S.pace, S.paceMs = nil, p.ms
    if not ok then geterrorhandler()(err) elseif p.done then p.done() end
    return false
end

function S.BuildSoon(parent, artLevel, range, iconLevel, done)
    if root or S.pace then return end
    S.pace = { ms = 0, done = done, co = coroutine.create(function() S.BuildNow(parent, artLevel, range, iconLevel) end) }
    if not S.paceFrame then
        S.paceFrame = CreateFrame("Frame")
        S.paceFrame:SetScript("OnUpdate", function(self)
            if InCombatLockdown() then return end    -- (rien pendant un combat : une image y vaut plus)
            if not S.PaceStep() then self:Hide() end
        end)
    end
    S.paceFrame:Show()
end

function S.Build(parent, artLevel, range, iconLevel)
    if S.pace then                          -- (en cours sur plusieurs images : le reste maintenant)
        S.pace.rush = true
        while S.PaceStep() do end
        return S.built
    end
    return S.BuildNow(parent, artLevel, range, iconLevel)
end

function S.BuildNow(parent, artLevel, range, iconLevel)
    if root then return end
    S.artTop = artLevel + range             -- (le haut de l'art)
    S.iconLevel = iconLevel                 -- (les icônes de la carte)
    W, H = ArtSize(WORLD)
    if not W then return end
    local function Layer(level)
        local fr = CreateFrame("Frame", nil, root)
        fr:SetAllPoints(root)
        fr:SetFrameLevel(level)
        return fr
    end
    root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", parent, "TOPLEFT")
    root:SetSize(1, 1)
    root:SetFrameLevel(artLevel)
    S.chartHost = { parent, artLevel - 1 }   -- (le cadre de la carte marine : sous tout l'art)
    contRoot = Layer(artLevel + 1)
    tilesRoot = Layer(artLevel + 2)
    overlayRoot = Layer(artLevel + range - 16)
    coreRoot = Layer(artLevel + range - 15)
    blurRoot = Layer(artLevel + range - 14)   -- (ses copies prennent les 4 niveaux suivants)
    citiesRoot = Layer(artLevel + range - 9)
    shadeRoot = Layer(artLevel + range - 7)   -- (la terre inexplorée assombrie : sur l'art et la minicarte)
    S.closeLayers = {                       -- pour Close.lua : les couches du zoom le plus proche
        minimap = Layer(artLevel + range - 8),
        grain = Layer(artLevel + range - 1),   -- (sur tout ; range - 5 est celui des villes souterraines)
        under = Layer(artLevel + range - 4),
    }
    labelsRoot = Layer(artLevel + range - 3)
    -- (les icônes et ta flèche : Map/PinSets.lua, sur la vue)

    -- la mer va bien au-delà de l'art du monde : une vue large (ou haute) montre plus d'océan,
    -- pas le bord du papier : sa couleur (celles de la mer du monde portées vers l'extérieur, gardant
    -- les teintes de la mer près de ses bords), et son marbré à l'échelle des continents (l'art du
    -- monde et la couleur de sa mer s'y fondent à leurs bords)
    -- (un client dont l'art peint sa propre mer, ns.ClientMaps.sea false : rien de la nôtre, seulement la
    -- couleur de la mer de son art du monde au-delà de ses bords)
    local seaOn = not (D.ClientMaps and D.ClientMaps.sea == false)
    local sea = root:CreateTexture(nil, "BACKGROUND", nil, -8)
    if seaOn then
        sea:SetTexture(SEA_FIELD_OUT, nil, nil, "LINEAR")
    else
        local c = D.ClientMaps.seaColor or SEA
        sea:SetColorTexture(c[1], c[2], c[3], 1)
    end
    Record(sea, -SEA_REACH * W, -SEA_REACH * H, (1 + 2 * SEA_REACH) * W, (1 + 2 * SEA_REACH) * H)
    -- (et le parchemin de l'art du monde qui continue au-delà de son bord déchiré, MapPaper teinté à sa marge :
    -- ns.MapPaperOut, territory.py)
    local paperOut = not seaOn and D.MapPaperOut
    if paperOut then
        local tex, k = root:CreateTexture(nil, "BACKGROUND", nil, -7), paperOut[1]
        tex:SetTexture(PAPER, "REPEAT", "REPEAT")
        tex:SetVertexColor(paperOut[2], paperOut[3], paperOut[4], 1)
        Record(tex, -SEA_REACH * W, -SEA_REACH * H, (1 + 2 * SEA_REACH) * W, (1 + 2 * SEA_REACH) * H)
        tex:SetTexCoord(-SEA_REACH * W / k, (1 + SEA_REACH) * W / k, -SEA_REACH * H / k, (1 + SEA_REACH) * H / k)
    end
    local outer = {}
    for i, file in ipairs(seaOn and { SEA_DARK, SEA_LIGHT } or NONE) do
        local tex = root:CreateTexture(nil, "BACKGROUND", nil, -7)
        tex:SetTexture(file, "REPEAT", "REPEAT")
        Record(tex, -SEA_REACH * W, -SEA_REACH * H, (1 + 2 * SEA_REACH) * W, (1 + 2 * SEA_REACH) * H)
        outer[i] = tex
    end
    S.chartOff = { sea, outer[1], outer[2] }   -- (la mer de la carte marine prend leur place : S.SetChart)
    -- la couleur de la mer telle que les cartes du monde et des continents la peignent (MapSeaField) : en
    -- zoomant, la carte garde la couleur qu'elle avait de loin ; celle des continents se fond dans celle du monde
    for _, mapID in ipairs(seaOn and (D.ClientMaps and D.ClientMaps.seaFields or { WORLD, 1414, 1415 }) or NONE) do
        local p = Place(mapID)
        if p then
            local w, h = p.layer.layerWidth * p.sx, p.layer.layerHeight * p.sy
            local field = root:CreateTexture(nil, "BACKGROUND", nil, mapID == WORLD and -6 or -5)
            field:SetTexture(SEA_FIELD .. mapID, nil, nil, "LINEAR")
            Record(field, p.left, p.top, w, h)
            local fade = Feather(root, p, FEATHER_WIDE)
            field:AddMaskTexture(fade)
            if mapID == WORLD then S.chartMasks = { fade } else tinsert(S.chartOff, field) end
        end
    end
    -- et son marbré par-dessus, sombre et clair, en deux octaves
    for i = 1, seaOn and 4 or 0 do
        local tex = root:CreateTexture(nil, "BACKGROUND", nil, -5 + i)
        tex:SetTexture(i % 2 == 1 and SEA_DARK or SEA_LIGHT, "REPEAT", "REPEAT")
        tex:Hide()
        seaPaper[i] = tex
    end
    local nb, ns_ = #backdrop, #backdropSea
    S.Pace()
    -- (jusqu'à son propre bord déchiré là où un client a son contour, MapBackLand : territory.py)
    local worldMask = PlaceBackdrop(root, WORLD, "BACKGROUND", not (D.MapBackLands and D.MapBackLands[WORLD]) and FEATHER_WIDE or nil)
    if S.chartMasks and worldMask then S.chartMasks[#S.chartMasks + 1] = worldMask end
    -- au-delà de ses bords, la mer propre des continents (leurs roses des vents, navire et serpent de mer)
    -- la prolonge, comme une part de la mer du monde (pas sous la carte marine : sa mer le fait)
    local outFrom = #backdropSea
    for _, info in ipairs(C_Map.GetMapChildrenInfo(WORLD, Enum.UIMapType.Continent, true) or {}) do
        S.Pace()
        local p, files = Place(info.mapID), ArtFiles(info.mapID)
        if p and files and #files > 0 and S.Stitched(info.mapID) and seaOn then
            PlaceTiles(root, p, files, 0, 0, p.layer.layerWidth, p.layer.layerHeight, "BACKGROUND", 0, false,
                Feather(root, p, SEA_OUT .. info.mapID), backdropSea, false)
        end
    end
    S.chartSeaOut = {}
    for i = outFrom + 1, #backdropSea do S.chartSeaOut[backdropSea[i]] = true end
    for i = nb + 1, #backdrop do worldArt[backdrop[i]] = true end
    for i = ns_ + 1, #backdropSea do worldArt[backdropSea[i]] = true end
    for _, info in ipairs(C_Map.GetMapChildrenInfo(WORLD, Enum.UIMapType.Continent, true) or {}) do
        S.Pace()
        if S.Stitched(info.mapID) then
            PlaceBackdrop(contRoot, info.mapID, "ARTWORK", FEATHER_WIDE)
            if seaOn then PlaceLand(info.mapID) end   -- (sa terre gardée comme terre sur notre mer)
        end
    end
    -- le marbré de la mer extérieure, à l'échelle de la première octave du papier de la mer (celle des Royaumes de l'Est)
    local size = SEA_TILE * 0.4
    for _, h in ipairs(hatches) do
        if h.mapID == (D.ClientMaps and D.ClientMaps.seaScale or 1415) then size = SEA_TILE * h.k end
    end
    for _, tex in ipairs(outer) do
        local x0, y0 = -SEA_REACH * W, -SEA_REACH * H
        local x1, y1 = (1 + SEA_REACH) * W, (1 + SEA_REACH) * H
        tex:SetTexCoord(x0 / size, x1 / size, y0 / size, y1 / size)
    end

    -- les noms des continents et des mers (S.SetZoom lettre chacun à sa première apparition)
    namesFrame = CreateFrame("Frame", nil, labelsRoot)
    namesFrame:SetSize(1, 1)
    -- tant que la carte bouge, les halos des noms des mers se reposent : chaque chaîne de police est redessinée à sa
    -- nouvelle taille à chaque image d'un zoom, et remise en page à chaque image d'un déplacement, et le halo fait huit
    -- des neuf d'une lettre. De retour une fois la carte arrêtée. Les continents gardent les leurs (peu de lettres, et
    -- leur lueur qui s'éteignait et se rallumait au zoom se voyait). (Sur `names`, pas en variables locales : le fichier est
    -- près de la limite de 200 de Lua)
    -- les noms des continents reposent aussi leur anneau extérieur, léger (la moitié des chaînes de police de
    -- leur halo, redessinées à chaque image d'un zoom) ; l'anneau intérieur reste, leur lueur ne clignote pas
    names.Hush = function(on)
        names.hushed = on
        for _, n in ipairs(names) do
            local land = n[2].fade == "land"
            for _, copy in ipairs(n[1].halos or NONE) do
                if not land or copy.omOuter then copy:SetShown(not on) end
            end
        end
        names.watch:SetShown(on)
    end
    names.watch = CreateFrame("Frame")
    names.watch:Hide()
    names.watch:SetScript("OnUpdate", function()
        if GetTime() - (names.movedAt or 0) > 0.15 then names.Hush(false) end
    end)
    for _, label in ipairs(D.MapLabels or {}) do
        local f = CreateFrame("Frame", nil, namesFrame)
        f:SetPoint("TOPLEFT")
        f:SetSize(1, 1)
        f:Hide()
        -- sa boîte sur le monde (0..1), pour S.Cull : ses lignes, avec de la place pour un nom plus large
        -- que la ligne de l'art (celui d'une autre langue) et pour son halo
        local n, p = { f, label }, Place(label.map)
        for _, line in ipairs(p and label.lines or NONE) do
            local x0, x1 = p.left + line[1] * p.sx, p.left + line[2] * p.sx
            local y1 = p.top + line[3] * p.sy
            local y0 = y1 - line[4] * p.sy
            n.l, n.r = math.min(n.l or x0, x0), math.max(n.r or x1, x1)
            n.t, n.b = math.min(n.t or y0, y0), math.max(n.b or y1, y1)
        end
        if n.l then
            local mx, my = (n.r - n.l) * 0.5, (n.b - n.t)
            n.l, n.r, n.t, n.b = (n.l - mx) / W, (n.r + mx) / W, (n.t - my) / H, (n.b + my) / H
        end
        names[#names + 1] = n
    end

    -- les zones, les plus grandes d'abord pour que les petites passent dessus ; les villes au-dessus de tout
    S.Pace()
    local zones = C_Map.GetMapChildrenInfo(WORLD, Enum.UIMapType.Zone, true) or {}
    local area = {}
    for _, info in ipairs(zones) do
        local l, r, t, b = S.Rect(info.mapID)
        area[info.mapID] = l and (r - l) * (b - t) or 0
    end
    table.sort(zones, function(a, b) return area[a.mapID] > area[b.mapID] end)
    local level = artLevel + 2
    for _, info in ipairs(zones) do
        S.Pace()
        -- (une zone, ou une ville : comme la liste de son client le dit, sinon une zone sans morceaux explorables est une ville)
        local stitched, kind = S.Stitched(info.mapID)
        if area[info.mapID] > 0 and stitched then
            local n = kind ~= 2 and PlaceOverlays(info.mapID) or 0
            if kind == 1 or (not kind and n > 0) then
                level = math.min(level + 1, artLevel + range - 17)
                local zf = CreateFrame("Frame", nil, tilesRoot)
                zf:SetAllPoints(root)
                zf:SetFrameLevel(level)
                if D.ClientMaps and D.ClientMaps.detailDensity then S.ZoneByContinent(info.mapID, zf) end
                -- (une zone sans morceaux ni territoire à elle, une île : un bord rond adouci, hors de son cadre)
                local plain = n == 0 and not (D.MapTerritories and D.MapTerritories[info.mapID])
                S.stats.tiles = S.stats.tiles + PlaceBase(zf, info.mapID, "ARTWORK", graded, plain and FEATHER_ROUND or FEATHER)
                S.stats.overlays = S.stats.overlays + n
            else
                tinsert(S.stats.cities, info.mapID)
                local cf = CreateFrame("Frame", nil, citiesRoot)
                cf:SetAllPoints(root)
                -- (une ville souterraine au-dessus de la couche de la minicarte, qui montre la surface par-dessus)
                cf:SetFrameLevel(UNDERGROUND_CITIES[info.mapID] and artLevel + range - 5 or citiesRoot:GetFrameLevel())
                local l, r, t, b = S.Rect(info.mapID)
                local cull = { cf, l, t, r, b, city = true }
                -- (le zoom où elle remplit la vue, dans le zoom dont les couches s'estompent : sur un monde de zones plus
                -- petites, ns.ClientMaps.zoom, c'en est moins)
                cities[#cities + 1] = { cf, 1 / (r - l) / (D.ClientMaps and D.ClientMaps.zoom or 1), mapID = info.mapID, cull = cull }
                culled[#culled + 1] = cull
                -- (une ville réduite à la ville, son plan : ns.MapCityCuts, banners.py)
                local cut = D.MapCityCuts and D.MapCityCuts[info.mapID] and TEX .. "MapCityMask\\" .. info.mapID
                PlaceBase(cf, info.mapID, "ARTWORK", graded, cut or FEATHER_ROUND)
            end
            S.stats.zones = S.stats.zones + 1
        end
    end

    -- des cartes plus fines que le client a de terres qu'aucune zone ne couvre (ns.MapGaps.art, gapfill.py : la
    -- carte inexplorée de Gilnéas de Blizzard) : ses propres cases, à leur résolution, par MapCoastArt
    -- (sa terre et ses hauts-fonds, là où aucune zone ne peint), sous chaque zone, sur le papier des trous
    for _, x in ipairs(D.MapGaps and D.MapGaps.art or {}) do
        S.Pace()
        local name, _, r, list = unpack(x)
        local files = {}                -- (0 : une case dont son masque ne laisse rien ; pas dessinée)
        for i, f in ipairs(list) do files[i] = f ~= 0 and f or nil end
        local p = { left = r[1] * W, top = r[3] * H, sx = (r[2] - r[1]) * W / 1002, sy = (r[4] - r[3]) * H / 668,
            layer = { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } }
        local f = CreateFrame("Frame", nil, tilesRoot)
        f:SetAllPoints(root)
        f:SetFrameLevel(tilesRoot:GetFrameLevel())
        PlaceTiles(f, p, files, 0, 0, 1002, 668, "ARTWORK", 0, false, Feather(f, p, TEX .. "MapCoastArt\\" .. name))
        culled[#culled + 1] = { f, r[1], r[3], r[2], r[4] }
    end

    -- les trous peints à la main (ns.MapGapFills : la terre qu'aucune carte de zone ne couvre, peinte dans le
    -- style des cartes de zone d'après l'art de Blizzard), sur le papier des trous et les cartes plus fines de
    -- Blizzard, sous chaque zone. Chacun ne se montre que près de la vue (S.Cull), ses fichiers chargés la première
    -- fois ; S.SetGapFillsShown les éteint tous (les cases cuites les ont : Baked.noFills)
    S.fillRoot = CreateFrame("Frame", nil, tilesRoot)
    S.fillRoot:SetAllPoints(root)
    S.fillRoot:SetFrameLevel(tilesRoot:GetFrameLevel())
    for _, x in ipairs(D.MapGapFills or {}) do
        S.Pace()
        local num, r, fw, fh, cols, list = unpack(x)
        local sx, sy = (r[3] - r[1]) * W / fw, (r[4] - r[2]) * H / fh
        local f = CreateFrame("Frame", nil, S.fillRoot)
        f:SetAllPoints(root)
        f:SetFrameLevel(tilesRoot:GetFrameLevel())
        f:Hide()
        local texs = {}
        for _, i in ipairs(list) do
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            local pw, ph = math.min(256, fw - col * 256), math.min(256, fh - row * 256)
            local tex = f:CreateTexture(nil, "ARTWORK", nil, 1)
            tex.omFile = TEX .. "MapGapFill\\" .. num .. "_" .. i
            tex:SetTexCoord(0, pw / 256, 0, ph / 256)
            Record(tex, r[1] * W + col * 256 * sx, r[2] * H + row * 256 * sy, pw * sx, ph * sy)
            texs[#texs + 1] = tex
        end
        f:SetScript("OnShow", function(self)
            if self.omLoaded then return end
            self.omLoaded = true
            for _, tex in ipairs(texs) do S.QueueLoad(tex) end   -- (le chargeur : en fondu, les cases cuites tenues jusque-là)
        end)
        culled[#culled + 1] = { f, r[1], r[2], r[3], r[4] }
    end

    -- la bannière du nom d'une zone pour une ville (ns.MapBanners, tools/map-preview/banners.py), coupée de
    -- l'art de la zone : le titre de la ville à tous les zooms (sa propre carte est réduite à son plan, sans
    -- sa bannière), sur la ville et les couches de près (la minicarte, les grottes), avec les noms
    for _, c in ipairs(cities) do
        local b = Baked.english and D.MapBanners and D.MapBanners[c.mapID]
        local p = b and Place(b[1])
        if p then
            local f = CreateFrame("Frame", nil, citiesRoot)
            f:SetAllPoints(root)
            f:SetFrameLevel(artLevel + range - 3)
            local tex = f:CreateTexture(nil, "ARTWORK")
            tex:SetTexture(TEX .. "MapBanner\\" .. c.mapID, nil, nil, "LINEAR")
            Record(tex, p.left + b[2] * p.sx, p.top + b[3] * p.sy, b[4] * p.sx, b[5] * p.sy)
            f:Hide()
            c.banner, c.bannerTex = f, tex
        end
    end

    S.Pace()
    cities.Build()
    Baked.Build()
    S.Pace()
    S.built = true
    return true
end

-- (bâti entièrement : une construction sur plusieurs images a son root bien avant d'être finie)
function S.IsBuilt() return S.built == true end
function S.Root() return S.built and root or nil end   -- (le root, une fois bâti)

-- combien la propre carte d'une ville souterraine couvre le point (u, v) (0..1) : Close.lua tient
-- la minicarte hors d'elle, car la minicarte y montre la surface (les ruines au-dessus de Fossoyeuse,
-- la montagne de Forgefer), et pose à la place sur sa carte la minicarte du jeu de l'intérieur de la ville
-- (S.UndergroundCity). Sur les villes à l'air libre, la minicarte est la ville, et s'y mêle.

-- si (u, v) est dans la propre carte d'une ville (la vue y laisse zoomer plus loin)
function S.InCity(u, v)
    for _, c in ipairs(cities) do
        local l, r, t, b = S.Rect(c.mapID)
        if l and u > l and u < r and v > t and v < b then return true end
    end
    return false
end
-- combien les propres cartes des villes couvrent (u, v) : à plein au milieu, en s'effaçant vers le bord
-- du rectangle de chacune. `underground` : les villes sous la surface (leur minicarte est celle de la
-- surface), sinon les autres
local function Cover(u, v, underground)
    local cover, most = 0, nil
    for _, c in ipairs(cities) do
        local l, r, t, b
        if (UNDERGROUND_CITIES[c.mapID] and true or false) == underground then l, r, t, b = S.Rect(c.mapID) end
        if l and u > l and u < r and v > t and v < b then
            local e = math.min(u - l, r - u) / (r - l) * 2
            e = math.min(e, math.min(v - t, b - v) / (b - t) * 2)
            local here = c[1]:GetAlpha() * math.min(1, e * 2.5)
            if here > cover then cover, most = here, c.mapID end
        end
    end
    return cover, most                             -- (et la ville qui le couvre le plus)
end
function S.CityCover(u, v) return Cover(u, v, true) end
function S.SurfaceCityCover(u, v) return Cover(u, v, false) end

-- pour la minicarte de Close.lua dans les trous : la couche des continents (sous chaque zone : ce qui y est
-- dessiné ne se montre que là où aucune zone ne couvre), et les trous de chaque continent en masque doux
local landMasks = {}
function S.GapLayer() return contRoot end
function S.GapMask(mapID)
    if landMasks[mapID] == nil then
        local p = Place(mapID)
        landMasks[mapID] = p and Feather(contRoot, p, TEX .. "MapGapMask\\" .. mapID) or false
    end
    return landMasks[mapID] or nil
end

-- pour la minicarte de près de Close.lua : la terre de chaque continent (un peu au-delà de sa côte) en
-- masque doux sur `layer`, pour que la minicarte ne dessine jamais la haute mer (sombre, en cases carrées).
-- MapMiniLand, pas MapLand : plus fin, et avec la terre propre des zones : les villes sur la côte et
-- les îles que l'art du continent dessine comme de la mer (Port-Menethil, Teldrassil) gardent leur minicarte
local MINI_LAND = TEX .. "MapMiniLand\\"
local minimapMasks = {}
function S.LandMask(layer, mapID)
    if minimapMasks[mapID] == nil then
        local p = Place(mapID)
        minimapMasks[mapID] = p and Feather(layer, p, MINI_LAND .. mapID) or false
    end
    return minimapMasks[mapID] or nil
end

-- pour /mmir carte status : les régions posées (art, masques) et posées depuis (icônes, couches de près)
function S.RegionCount()
    local n = 0
    for _ in pairs(dynamic) do n = n + 1 end
    return #placed, n
end

-- pour /mmir carte status : combien des régions de l'art sont dessinées maintenant
function S.DrawnCount()
    local n = 0
    for _, rec in ipairs(placed) do
        if rec[1]:IsVisible() and rec[1]:GetObjectType() == "Texture" then n = n + 1 end
    end
    return n
end

-- la vue a bougé (un déplacement ou un zoom : le S.SetView de Close.lua) : une troisième image de suite, c'est
-- la carte qui bouge, et les halos des noms se reposent jusqu'à l'arrêt (l'ouverture, un réglage changé : une ou deux)
function S.Moved()
    if not names.Hush then return end
    local now = GetTime()
    if now == names.movedAt then return end      -- (une par image)
    names.moves = names.movedAt and now - names.movedAt < 0.1 and (names.moves or 0) + 1 or 1
    names.movedAt = now
    if not names.hushed and names.moves >= 3 then names.Hush(true) end
end

function S.SetShown(shown)
    if root and root:IsShown() ~= (shown and true or false) then root:SetShown(shown) end
    local chart = S.Chart and S.Chart.Frame()
    if chart and chart:IsShown() ~= (shown and S.Chart.on or false) then chart:SetShown(shown and S.Chart.on or false) end
end

function S.IsShownNow() return root and root:IsShown() or false end

-- la carte marine allumée ou éteinte : notre propre mer au-delà de la carte du monde rangée (sa couleur portée
-- au-delà, MapSeaFieldOut ; son marbré ; la couleur de la mer des continents et leur mer au-delà des bords de la
-- carte du monde), et la carte du monde se fondant dans la carte marine par MapChart\Middle (ses continents, îles et
-- côtes entiers) au lieu de son large fondu de bord, sa haute mer amenée vers celle de la carte marine
-- (ns.MapChart.seaTint) ; la texture propre de la mer, en approchant, tenue de même à la mer de la carte du monde
function S.SetChart(on)
    if not root or not S.chartOff or not S.chartMasks then return end   -- (un client sans mer à lui n'a pas de carte marine)
    on = on and true or false
    if S.chartNow == on then return end
    S.chartNow = on
    for _, r in ipairs(S.chartOff) do r:SetShown(not on) end
    local file = on and TEX .. "MapChart\\Middle" or FEATHER_WIDE
    for _, m in ipairs(S.chartMasks) do m:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") end
    for _, tex in ipairs(seaPaper) do
        if on then tex:AddMaskTexture(S.chartMasks[1]) else tex:RemoveMaskTexture(S.chartMasks[1]) end
    end
    S.chartHide = on and S.chartSeaOut or nil
    S.chartTint = on and D.MapChart and D.MapChart.seaTint or nil
    muted = -1                                     -- (S.SetZoom repose les fondus de l'art du monde et des continents)
    if scaleNow and scaleNow > 0 then S.SetZoom(zoomNow, scaleNow) end
end

-- les parties de l'art, chacune { nom, régions }, à cacher un instant pour voir
-- ce qu'elle coûte. (Les textures posées directement sur root : la mer et l'art de la carte du monde)
function S.Parts()
    if not root then return {} end
    local own, copies = {}, {}
    for _, r in ipairs({ root:GetRegions() }) do
        if r:GetObjectType() == "Texture" then own[#own + 1] = r end
    end
    for _, e in ipairs(twins) do copies[#copies + 1] = e[1] end
    local L = S.closeLayers or {}
    return {
        { "all My Map Is Rich art and icons", { root } },
        { "sea and world art", own },
        { "continents, land, gap paper", { contRoot } },
        { "zone base art", { tilesRoot } },
        { "zone overlays", { overlayRoot } },
        { "zone interiors", { coreRoot } },
        { "baked zone art", { Baked.frame } },
        { "colour-match copies", copies },
        { "blur", { blurRoot } },
        { "cities", { citiesRoot } },
        { "unexplored shade", { shadeRoot } },
        { "minimap detail", { L.minimap } },
        { "grain", { L.grain } },
        { "caves", { L.under } },
        { "names", { labelsRoot } },
    }
end

-- la prochaine S.Cull montre ou cache chaque texture des zones et chaque région triée
-- à nouveau, comme elles doivent l'être
function S.ResetShown()
    if not root then return end
    wipe(inView)
    wipe(Live.placed)
    cullBox = nil
    for _, list in pairs(zoneTex) do
        for _, e in ipairs(list) do e.shown = nil end
    end
    for _, c in ipairs(culled) do c.here = nil end
    for _, n in ipairs(names) do n.near = nil end
end

-- les copies du flou (voir S.SetBlur) : décalées en diagonale de chaque côté d'une fraction de pixel d'art
local BLUR_TAPS = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
local BLUR_PX = 0.6             -- pixels d'art par prise
local blurZones = {}            -- mapID -> ses quatre cadres de copies
local lastGrade                 -- les réglages d'ApplyGrade, pour les copies bâties plus tard

local function PlaceShift(f)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", root, "TOPLEFT", f.dx, -f.dy)
    f:SetSize(1, 1)
end

--------------------------------------------------------------------------------
-- Les noms : ceux des continents et des mers, lettrés en direct dans la police du client
-- comme l'art de la carte de Blizzard les lettre (ns.MapLabels ; l'art est nettoyé à la main des
-- siens) : encre sombre, petites capitales après une capitale, espacées, dans un doux
-- halo clair. En unités du monde x NAME_UNITS sur namesFrame, que Layout met à l'échelle de
-- l'hôte : la taille des polices reste la même quelle que soit la carte hôte du canevas.
--------------------------------------------------------------------------------

local NAME_UNITS = 4            -- unités de police par unité du monde
local NAME_CAP = 0.69           -- la hauteur des capitales de Friz Quadrata, en tailles de police
local NAME_MIDDLE = 0.36        -- ... et le milieu de la boîte de ses lettres, au-dessus de la ligne de base
local NAME_SMALL = 0.78         -- les petites capitales, par rapport aux capitales (mesuré sur l'art)
local NAME_TRACK = 0.1          -- l'espacement le plus petit, en hauteurs de capitale (un nom plus long dans une autre langue)
local NAME_SPACE = 0.4          -- une espace entre mots, en hauteurs de capitale (un nom qui ne tient pas sur les lignes de l'art)
local HALO = { { 0.07, 1 }, { 0.15, 0.45 } }   -- les copies derrière l'encre : { rayon de l'anneau (hauteurs de capitale), force }
local HALO_TAPS = 8
local INK_ALPHA = 0.9           -- (l'encre de l'art laisse passer un peu du papier)

-- le nom d'un libellé dans la langue du client, sinon le sien
local function NameOf(label)
    local n, text = label.name, nil
    if n.map then
        local info = C_Map.GetMapInfo(n.map)
        text = info and info.name
    elseif n.area then
        text = C_Map.GetAreaInfo(n.area)
    end
    return (text and text ~= "") and text or n.text
end

-- les mots du nom sur les lignes de l'art : un par ligne, comme l'art les pose, ou (le nom d'une autre
-- langue, avec plus ou moins de mots) tous sur la plus large
local function SetLines(label, text)
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end
    local lines = label.lines
    if #words == #lines then
        local out = {}
        for i, line in ipairs(lines) do out[i] = { line, words[i] } end
        return out
    end
    local widest = lines[1]
    for _, line in ipairs(lines) do
        if line[2] - line[1] > widest[2] - widest[1] then widest = line end
    end
    return { { widest, text } }
end

local function Letter(f, label)
    local p = Place(label.map)
    if not p then return end
    local ink, glow = label.ink, label.glow
    local font = STANDARD_TEXT_FONT                -- (Friz Quadrata ; celle du client dans les autres alphabets)
    for _, set in ipairs(SetLines(label, NameOf(label))) do
        local line, text = set[1], set[2]
        local u = NAME_UNITS
        local left, right = (p.left + line[1] * p.sx) * u, (p.left + line[2] * p.sx) * u
        local base, cap = (p.top + line[3] * p.sy) * u, line[4] * p.sy * u
        -- les lettres : une capitale au début de chaque mot, des petites capitales ensuite (une ligne toute en
        -- petites capitales est déjà mesurée à leur taille)
        local glyphs, width, wordStart = {}, 0, true
        for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            if ch == " " then
                glyphs[#glyphs + 1] = { w = NAME_SPACE * cap }
                width = width + NAME_SPACE * cap
                wordStart = true
            else
                local size = cap / NAME_CAP * ((wordStart or line[5]) and 1 or NAME_SMALL)
                local fs = f:CreateFontString(nil, "OVERLAY")
                fs:SetFont(font, size, "")
                fs:SetText(#ch == 1 and ch:upper() or ch)
                fs:SetTextColor(ink[1] / 255, ink[2] / 255, ink[3] / 255, INK_ALPHA)
                fs:SetShadowOffset(0, 0)
                local w = fs:GetStringWidth()
                glyphs[#glyphs + 1] = { fs = fs, size = size, w = w }
                width = width + w
                wordStart = false
            end
        end
        -- espacé sur la ligne de l'art, centré dessus
        local gaps = #glyphs - 1
        local track = gaps > 0 and math.max(NAME_TRACK * cap, (right - left - width) / gaps) or 0
        local x = (left + right) / 2 - (width + track * gaps) / 2
        for _, g in ipairs(glyphs) do
            if g.fs then
                local y = -base + NAME_MIDDLE * g.size
                g.fs:SetPoint("LEFT", f, "TOPLEFT", x, y)
                -- le halo : des copies en anneau autour, dans la couleur de la lueur. L'ombre de chaque copie est la
                -- prise opposée de l'anneau : un anneau fait moitié moins de chaînes de police (chacune est
                -- déplacée à chaque image d'un déplacement, et redessinée à chaque image d'un zoom)
                for _, ring in ipairs(HALO) do
                    local r, a = ring[1] * cap, math.min(1, ring[2] * label.glowA / HALO_TAPS * 2)
                    for i = 1, HALO_TAPS / 2 do
                        local angle = (i - 1) / HALO_TAPS * 2 * math.pi
                        local dx, dy = r * math.cos(angle), r * math.sin(angle)
                        local copy = f:CreateFontString(nil, "ARTWORK")
                        copy:SetFont(font, g.size, "")
                        copy:SetText(g.fs:GetText())
                        copy:SetTextColor(glow[1] / 255, glow[2] / 255, glow[3] / 255, a)
                        copy:SetShadowColor(glow[1] / 255, glow[2] / 255, glow[3] / 255, a)
                        copy:SetShadowOffset(-2 * dx, -2 * dy)
                        copy:SetPoint("LEFT", f, "TOPLEFT", x + dx, y + dy)
                        f.halos = f.halos or {}
                        f.halos[#f.halos + 1] = copy
                        copy.omOuter = ring ~= HALO[1] or nil   -- (names.Hush)
                        if names.hushed and (label.fade ~= "land" or copy.omOuter) then copy:Hide() end
                    end
                end
            end
            x = x + g.w + track
        end
    end
end

-- met l'art en page dans les unités du canevas de `mapID` (elle doit être sur le monde). Tout est
-- posé en unités du monde sur root : c'est l'échelle et le coin de root, un seul changement, quelle
-- que soit la quantité bâtie (les décalages sont dans les unités propres de root, mises à l'échelle)
function S.Layout(mapID)
    local aw = ArtSize(mapID)
    local l, r, t = S.Rect(mapID)
    if not root or not aw or not l then return false end
    local k = aw / ((r - l) * W)
    scaleNow = -1
    -- la même carte de nouveau (à chaque ouverture) : rien à déplacer, et déplacer root
    -- ferait remettre en page par le jeu chaque texture dessous
    if host.mapID == mapID and host.k == k then return true end
    host.l, host.t, host.k, host.mapID = l * W, t * H, k, mapID
    root:SetScale(k)
    S.chartScale = k                                -- (le cadre de la carte marine garde l'échelle de root : ses régions sont posées sur root)
    if S.Chart and S.Chart.Frame() then S.Chart.Frame():SetScale(k) end
    root:ClearAllPoints()
    root:SetPoint("TOPLEFT", root:GetParent(), "TOPLEFT", -host.l, host.t)
    namesFrame:SetScale(1 / NAME_UNITS)
    namesFrame:ClearAllPoints()
    namesFrame:SetPoint("TOPLEFT", labelsRoot, "TOPLEFT")
    return true
end

-- les lettres d'un nom, bâties la première fois qu'il se montre. Un nom, ce sont des centaines de chaînes de
-- police (son halo), et toutes faites en une image donnaient un à-coup au premier dézoom d'une session (350 en
-- un pas, dans tools/offline-test/perf.py) : un nom par appel, le reste un instant après
-- (un champ, pas une variable locale : le fichier est à la limite de 200 de Lua)
names.perCall = 1
function S.BuildNames()
    local left = names.perCall
    local more = false
    for _, n in ipairs(names) do
        if not n.built and (n[1].omFade or 0) > 0.01 then
            if left > 0 then
                left = left - 1
                n.built = true
                Letter(n[1], n[2])
            else
                more = true
            end
        end
    end
    if more and not names.soon then
        names.soon = true
        C_Timer.After(0.05, function()
            names.soon = nil
            S.BuildNames()
        end)
    end
end

-- zoom : 1 = le monde tient dans la vue ; scale : l'échelle du canevas hôte (unités de l'hôte -> px de la vue)
-- pour /mmir carte status : chaque part du temps de S.SetZoom (ms, lissé) et la pire
local zoomSteps = {}
S.zoomSteps = zoomSteps
local stepAt
local function Step(name)
    if not debugprofilestop then return end
    local now = debugprofilestop()
    if name and stepAt then
        local ms = now - stepAt
        local st = zoomSteps[name] or { ms = ms, worst = 0 }
        st.ms, st.worst = st.ms * 0.9 + ms * 0.1, math.max(st.worst, ms)
        zoomSteps[name] = st
    end
    stepAt = now
end

-- les fondus de SetZoom : 0..1 sur `range` ({ from, to }, ou from, to) du zoom actuel. (Ici,
-- et les fondus des noms dans une table gardée : un pas de zoom ne fait pas de déchets, il tourne à chaque image)
local function Smooth(range, to)
    local from = range
    if to == nil then from, to = range[1], range[2] end
    local t = math.max(0, math.min(1, (zoomNow - from) / (to - from)))
    return t * t * (3 - 2 * t)
end
local fades = {}

function S.SetZoom(zoom, scale)
    if not root then return end
    Step()
    zoomNow = zoom
    Fade(contRoot, Smooth(CONT_IN))
    if Live.contShown ~= contRoot:IsShown() then      -- (l'art des continents en vue reçoit ses fichiers à son arrivée : S.Cull)
        Live.contShown = contRoot:IsShown()
        if Live.contShown then S.LoadCulled() end
    end
    fades.land = 1 - Smooth(LABELS_OUT)          -- les noms (un de chaque, fixés sur le monde)
    fades.sea = 1 - Smooth(SEA_LABELS_OUT)
    for _, n in ipairs(names) do
        local a = math.floor((fades[n[2].fade] or 0) * 100 + 0.5) / 100
        Fade(n[1], a)
        if n.near == false and n[1]:IsShown() then n[1]:Hide() end   -- (hors de la vue : S.Cull)
    end
    S.BuildNames()
    Step("names")
    detailNow = DETAIL_HINT[3] * Smooth(DETAIL_HINT) + (1 - DETAIL_HINT[3]) * Smooth(DETAIL_FADE)
    if Live.contK then                          -- (les zones de chaque continent selon la résolution de son propre art : ApplyDetail)
        local most = 0
        for c, k in pairs(Live.contK) do
            local f = Smooth(DETAIL_FADE[1] * k, DETAIL_FADE[2] * k)
            Live.contFade[c] = f
            if f > most then most = f end
        end
        detailNow = most
    end
    -- (les copies grisées du continent sous les zones pas trouvées : seulement jusqu'à ce que le détail des zones soit dessus)
    if S.greyRoot and S.greyRoot:IsShown() ~= (detailNow < 0.98) then S.greyRoot:SetShown(detailNow < 0.98) end
    if Baked.frame then                         -- (px d'écran par px cuit : les couches vivantes prennent le relais au-delà)
        local _, ph = GetPhysicalScreenSize()
        local r = root:GetEffectiveScale() * (ph or 768) / 768 / D.MapZoneArt.px
        local t = math.max(0, math.min(1, (r - Baked.FADE[1]) / (Baked.FADE[2] - Baked.FADE[1])))
        Baked.live = math.floor(t * t * (3 - 2 * t) * 50 + 0.5) / 50
        Baked.warm = r >= Baked.FADE[1] * Baked.WARM
    end
    ApplyDetail()
    Step("zone detail")
    for _, c in ipairs(cities) do
        local fade = CITY_FADE_OF[c.mapID] or CITY_FADE
        local a = Smooth(fade[1] * c[2], fade[2] * c[2])
        -- (montrée près de la vue, S.Cull, tant qu'elle est un peu en fondu : à alpha 0 ses textures coûtent encore
        -- leur surface, et une ville de retail en a 150)
        if c.alpha ~= a then
            c.alpha = a
            c[1]:SetAlpha(a)
            local shown = a > 0.003 and c.cull.here ~= false
            if c[1]:IsShown() ~= shown then c[1]:SetShown(shown) end
        end
    end
    -- (la bannière de la zone pour chaque ville : l'art de la zone est dessiné sans elle, c'est donc la bannière,
    -- avec le détail de la zone ; le titre de la ville une fois dedans, sauf si sa propre carte garde le sien)
    cities.Banners()
    Step("cities")
    local m = math.floor(Smooth(MUTE_FADE) * 20) / 20
    local sm = math.floor(Smooth(SEA_FADE) * 20) / 20
    -- la carte du monde cède la place à celles des continents à leur arrivée (sinon chaque nom et chaque
    -- libellé de mer se montrent deux fois, un peu écartés) ; la texture propre de la mer prend le relais autour
    local wo = math.floor(Smooth(WORLD_OUT) * 20) / 20
    local ws = math.floor(Smooth(WORLD_SEA_OUT) * 20) / 20
    local wc = math.floor(Smooth(WORLD_COAST_OUT) * 20) / 20
    -- (un client dont l'art peint sa propre mer : elle reste comme Blizzard l'a peinte, jamais estompée vers notre mer,
    -- et l'art du monde reste sous celui des continents : il n'y a pas de mer à nous dessous)
    if D.ClientMaps and D.ClientMaps.sea == false then m, sm, wo, ws, wc = muted, seaNow, worldOut, worldSea, worldCoastOut end
    if m ~= muted or sm ~= seaNow or wo ~= worldOut or ws ~= worldSea or wc ~= worldCoastOut then
        muted, seaNow, worldOut, worldSea, worldCoastOut = m, sm, wo, ws, wc
        for _, tex in ipairs(worldCoast) do Fade(tex, 1 - wc) end
        local c = 1 - 0.45 * m
        for _, tex in ipairs(backdrop) do
            tex:SetDesaturation(0.8 * m)
            tex:SetVertexColor(c, c * 0.97, c * 0.92)
            Fade(tex, (1 - BACK_MUTE * m) * (worldArt[tex] and (1 - wo) or 1))
        end
        S.GreyMute()                                   -- (les copies grisées par Shade.Grey : estompées de même)
        local tint = S.chartTint                       -- (la carte marine : la haute mer du monde amenée vers sa mer)
        for _, tex in ipairs(backdropSea) do
            if worldArt[tex] then                      -- la mer du monde : l'océan, comme Blizzard l'a peint
                tex:SetDesaturation(tint and tint[4] or 0)
                tex:SetVertexColor(tint and tint[1] or 1, tint and tint[2] or 1, tint and tint[3] or 1)
                Fade(tex, 1 - ws)
            else                                       -- la haute mer d'un continent : celle du monde est dessous
                tex:SetDesaturation(0.8 * m)
                tex:SetVertexColor(c, c * 0.97, c * 0.92)
                Fade(tex, (1 - BACK_MUTE * m) * (1 - sm))
            end
        end
        if S.SetSea then S.SetSea() end
    end
    Step("world / continent art")
    for _, tex in ipairs(landFill) do Fade(tex, math.max(m, underNow)) end
    Step("land")

    scaleNow = scale
    -- (les icônes, et lesquels de leurs jeux se montrent à ce zoom : Map/PinSets.lua)
    if S.OnZoomIcons then S.OnZoomIcons(zoomNow) end
    Step("icon sets")
end

--------------------------------------------------------------------------------
-- Pour Close.lua : des régions posées en unités du monde (0..1), et yards <-> monde
--------------------------------------------------------------------------------

-- le flou au zoom le plus proche (Close.lua), où l'art est étiré au-delà de ses pixels.
-- Chaque zone en vue reçoit quatre copies de son intérieur (BLUR_TAPS, déclaré avec Layout,
-- qui les repose), dessinées à 1/2, 1/3, 1/4, 1/5 dessus : une moyenne régulière de cinq
-- prises, c'est-à-dire un vrai petit flou. Bâties la première fois qu'une zone en a besoin.
local function BuildBlur(mapID)
    local p = Place(mapID)
    if not p or not (D.MapGrade and D.MapGrade[mapID]) then blurZones[mapID] = false return end
    local frames, from = {}, #graded + 1
    for i, tap in ipairs(BLUR_TAPS) do
        local f = CreateFrame("Frame", nil, blurRoot)
        f.omShift = true
        f.dx, f.dy = tap[1] * BLUR_PX * p.sx, tap[2] * BLUR_PX * p.sy
        f:SetFrameLevel(blurRoot:GetFrameLevel() + i)
        f:SetAlpha(1 / (i + 1))
        PlaceShift(f)
        local thin, core = ZoneMask(f, p, EDGE) or Feather(f, p, FEATHER_THIN), ZoneMask(f, p, CORE)
        ForEachPiece(mapID, function(files, x, y, w, h, sub, piece)
            PlaceTiles(f, p, files, x, y, w, h, "ARTWORK", sub, true, thin, graded, piece, nil, core)
        end)
        frames[i] = f
    end
    blurZones[mapID] = frames
    -- (ses propres nouvelles copies harmonisées et mises en file de chargement, pas celles de chaque zone)
    if lastGrade then
        for i = from, #graded do GradeEntry(graded[i], lastGrade[2]) end
    end
    ShowZone(mapID)
end

-- amount 0..1 ; le rectangle du monde de la vue (0..1) : les zones dedans reçoivent leurs copies.
-- most : allume (ou bâtit) au plus les copies de tant de zones à cet appel, le reste au suivant
-- (Close.lua ramène le flou quelques zones par image, pas toutes en une) ; true une fois toutes faites
function S.SetBlur(amount, u0, v0, u1, v1, most)
    if not root then return true end
    softNow = amount
    local left = most or math.huge
    local done = true
    for _, mapID in ipairs(overlayZones) do
        local l, r, t, b = S.Rect(mapID)
        local inView = amount > 0.01 and l and r > u0 and l < u1 and b > v0 and t < v1
        local frames = blurZones[mapID]
        if inView and (frames == nil or (frames and not frames.shown)) and left <= 0 then
            done = false
        else
            if inView and frames == nil then BuildBlur(mapID) frames = blurZones[mapID] end
            local shown = inView and true or false
            if frames and frames.shown ~= shown then
                frames.shown = shown
                for _, f in ipairs(frames) do f:SetShown(shown) end
                if shown then left = left - 1 end
            end
        end
    end
    ApplyDetail()
    return done
end

-- le souterrain (Close.lua) : quand une grotte fait surface, le monde au-dessus devient flou. Le
-- détail des zones revient aux douces couleurs de terre du continent (MapLand), qui se lit
-- comme un flou ; Close.lua ajoute un grain plus fort et un assombrissement par-dessus.
function S.SetUnderground(t)
    if not root or t == underNow then return end
    underNow = t
    ApplyDetail()
    for _, tex in ipairs(landFill) do Fade(tex, math.max(muted, t)) end
end

-- la texture de la mer sur la vue (le S.SetView de Close.lua la passe ; l'estompage la rappelle
-- avec la dernière vue). Les deux se répètent à l'échelle de l'art du continent, puis se divisent par deux
-- chaque fois que le zoom double au-delà de SEA_OCTAVE / HATCH_OCTAVE, en fondu d'une octave à l'autre : le
-- papier et les traits gardent leur taille à l'écran et de plus fins arrivent en approchant.
local seaView = {}
-- (posé sur une boîte bien plus grande que la vue : le motif est fixé sur le monde, un déplacement ne le
-- repose donc qu'à l'approche du bord de la boîte ; un zoom ou un estompage qui change, à chaque fois)
local seaBox = { k = 1.8 }      -- { u0, v0, u1, v1, zoom =, m = } tel que posé en dernier ; k : sa demi-taille, en vues
local function shift(k) return (k * 0.37) % 1 end   -- (le décalage propre à une octave : plus bas)
local function Octaves(from)
    local o = math.max(0, math.log(zoomNow / from) / math.log(2))
    local n = math.floor(o)
    return 2 ^ n, o - n
end

local function Tile(tex, u0, v0, u1, v1, sx, sy, alpha, shift)
    if alpha <= 0.01 or u1 <= u0 or v1 <= v0 then tex:Hide() return end
    local o = shift or 0
    tex:SetTexCoord(u0 * W / sx + o, u1 * W / sx + o, v0 * H / sy + o * 1.6, v1 * H / sy + o * 1.6)
    S.PlaceWorld(tex, u0, v0, u1, v1)
    tex:SetAlpha(alpha)
    tex:Show()
end

function S.SetSea(u, v, hu, hv)
    if not root or not seaPaper[1] then return end   -- (aucune : un client dont l'art peint sa propre mer)
    if u then seaView[1], seaView[2], seaView[3], seaView[4] = u, v, hu, hv end
    u, v, hu, hv = seaView[1], seaView[2], seaView[3], seaView[4]
    if not u then return end
    local m = math.max(0, worldSea, worldCoastOut)   -- (sous la mer de l'art du monde : elle se montre quand celle-ci part, d'abord au large des côtes)
    local sb = seaBox
    if sb.zoom == zoomNow and sb.m == m and u - hu * 1.2 > sb[1] and u + hu * 1.2 < sb[3]
        and v - hv * 1.2 > sb[2] and v + hv * 1.2 < sb[4] then return end
    local u0, u1, v0, v1 = u - hu * sb.k, u + hu * sb.k, v - hv * sb.k, v + hv * sb.k
    sb[1], sb[2], sb[3], sb[4], sb.zoom, sb.m = u0, v0, u1, v1, zoomNow, m
    local ek = hatches[1] and hatches[1].k or 0.4
    for _, h in ipairs(hatches) do
        if h.mapID == (D.ClientMaps and D.ClientMaps.seaScale or 1415) then ek = h.k end
    end
    local div, f = Octaves(SEA_OCTAVE)
    local size = SEA_TILE * ek
    -- chaque taille garde son propre décalage (le numéro de l'octave) : quand la copie plus fine prend
    -- le relais au doublement du zoom, c'est le même motif à la même place, sans saut
    local n = math.floor(math.log(div) / math.log(2) + 0.5)
    for i = 1, 2 do
        Tile(seaPaper[i], u0, v0, u1, v1, size / div, size / div, m * (1 - f), shift(n))
        Tile(seaPaper[i + 2], u0, v0, u1, v1, size / div / 2, size / div / 2, m * f, shift(n + 1))
    end
    div, f = Octaves(HATCH_OCTAVE)
    for _, h in ipairs(hatches) do
        local a0, a1 = math.max(u0, h[1]), math.min(u1, h[2])
        local b0, b1 = math.max(v0, h[3]), math.min(v1, h[4])
        local a = m * HATCH_ALPHA
        local sx, sy = HATCH_W * h.k / div, HATCH_H * h.k / div
        Tile(h.tex[1], a0, b0, a1, b1, sx, sy, a * math.sqrt(1 - f))
        Tile(h.tex[2], a0, b0, a1, b1, sx / 2, sy / 2, a * math.sqrt(f))
    end
end

-- pose `region` sur le rectangle du monde u0..u1, v0..v1 (0..1), en suivant Layout
function S.PlaceWorld(region, u0, v0, u1, v1)
    local rec = dynamic[region] or { region }
    rec[2], rec[3], rec[4], rec[5] = u0 * W, v0 * H, (u1 - u0) * W, (v1 - v0) * H
    dynamic[region] = rec
    PlaceRecord(rec)
end

function S.UnplaceWorld(region)
    dynamic[region] = nil
end

-- un point du monde (0..1) en yards sur le continent 0 / 1 (l'inverse de FromYards)
function S.ToYards(cont, u, v)
    -- (les yards propres d'un client : la carte linéaire de sa région, inversée ; l'échantillonner à l'origine,
    -- plus bas, ne trouve rien là où une région d'une carte du jeu n'arrive pas : les îles draeneï, l'île du Tonnerre)
    local yards = D.MapWorld and D.MapWorld.yards
    if yards then
        local r = (yards[cont] or NONE)[1]
        if not r or r[6] == 0 or r[8] == 0 then return end
        return (v - r[7]) / r[8], (u - r[5]) / r[6]
    end
    local x0, y0 = S.FromYards(cont, 0, 0)
    local x1, y1 = S.FromYards(cont, 1000, 0)
    local x2, y2 = S.FromYards(cont, 0, 1000)
    if not x0 or not x1 or not x2 then return end
    -- la projection est linéaire : résoudre u, v = origine + wx * a + wy * b
    local ax, ay, bx, by = (x1 - x0) / 1000, (y1 - y0) / 1000, (x2 - x0) / 1000, (y2 - y0) / 1000
    local det = ax * by - bx * ay
    if det == 0 then return end
    local du, dv = u - x0, v - y0
    return (du * by - bx * dv) / det, (ax * dv - du * ay) / det
end

S.CaveMasks = D.Media.tex .. "MapCave\\"

-- l'harmonie des couleurs : les copies des bords vont de `strength` vers la palette
-- commune (ns.MapGrade) ; `desat` retire un peu de couleur de chaque zone. `unexplored` :
-- "show" montre les lieux pas encore explorés tels quels, "dim" les assombrit (plus sombres et plus froids ;
-- une zone pas trouvée du tout est aussi ombrée sur l'art du continent, elle se voit de tout zoom), ou
-- "hide" les cache (le parchemin vide de la zone s'y montre, comme sur la carte de Blizzard)
-- les textures d'une zone montrées ou cachées : près de la vue, et pas un morceau inexploré qu'on cache
-- les fichiers des zones en attente, quelques-uns par image (LOAD_PER_FRAME), pour qu'une zone qui
-- arrive en vue (ou la carte ouverte sur une) ne bloque pas une image à les poser tous d'un coup
-- Chacune apparaît en fondu en recevant son fichier (LOAD_FADE), sans surgir (le fichier lui-même arrive
-- en quelques images). Une longue file (la carte ouverte sur une zone de près : un millier et plus) est
-- posée en 60 images au plus, pas 300 (une image qui posait 300 fichiers était un à-coup de 35 ms sur
-- une machine à 240 Hz, chaque fichier étant un chargement et un envoi, en test : deux secondes pour que
-- le détail arrive, et un déplacement vers du neuf arrivant en quelques images de plus)
local LOAD_PER_FRAME = { 40, frames = 6, most = 60, steps = 8 }   -- (une seule variable locale : le fichier est à la limite de 200 de Lua)
local LOAD_FADE = 0.3           -- secondes
local loadQueue, loadAt = {}, 1
local fading, fadingN = {}, 0   -- texture -> quand elle a reçu son fichier
local loader = CreateFrame("Frame")
loader:Hide()
loader:SetScript("OnUpdate", function(self)
    -- (les fichiers demandés depuis le dernier changement de zoom, par un déplacement ou un tri : les cases cuites tenues dessus aussi)
    if Baked.busy and Baked.use and not Baked.holding then ApplyDetail() end
    local n, now = 0, GetTime()
    local L_ = LOAD_PER_FRAME
    local most = math.min(L_.most, math.max(L_[1], math.ceil((#loadQueue - loadAt + 1) / L_.frames)))
    while loadAt <= #loadQueue and n < most do
        local tex = loadQueue[loadAt]
        loadAt = loadAt + 1
        if tex.omFile then
            tex:SetTexture(tex.omFile, nil, nil, "TRILINEAR")
            tex.omFile = nil
            tex:SetAlpha(0)
            tex.omStep = 0
            fading[tex] = now
            fadingN = fadingN + 1
            n = n + 1
        end
    end
    if loadAt > #loadQueue then wipe(loadQueue) loadAt = 1 end
    for tex, t0 in pairs(fading) do
        local t = (now - t0) / LOAD_FADE
        if t >= 1 then
            tex:SetAlpha(1)
            fading[tex] = nil
            fadingN = fadingN - 1
        else
            -- (par pas : un fondu, c'est un appel au client à chaque image pour chaque texture en fondu, 700 et plus quand un
            -- dézoom amène les cases des continents ; un pas de plus que l'œil n'en voit est un pas qu'il ne voit pas)
            local a = math.floor(t * t * (3 - 2 * t) * L_.steps + 0.5) / L_.steps
            if a ~= tex.omStep then
                tex.omStep = a
                tex:SetAlpha(a)
            end
        end
    end
    if loadAt == 1 and #loadQueue == 0 and fadingN == 0 then
        self:Hide()
        Baked.busy = false
        if Baked.holding then                   -- (tout est arrivé : les cases cuites peuvent partir)
            Baked.holding = false
            ApplyDetail()
        end
    end
end)

-- une texture d'une couche qui n'est pas celle d'une zone (les trous peints à la main) par le même chargeur : les
-- cases cuites restent dessus jusqu'à l'arrivée de son fichier (Baked.holding)
function S.QueueLoad(tex)
    if not tex.omFile or tex.omQueued then return end
    tex.omQueued = true
    loadQueue[#loadQueue + 1] = tex
    loader:Show()
    Baked.busy = true
end

--------------------------------------------------------------------------------
-- La terre inexplorée, assombrie (« dim »). Une zone dont tu n'as rien trouvé : une ombre sur son art et la
-- minicarte de près, par sa terre sans la mer que peint son art (MapZoneLand : la mer reste
-- telle quelle), de tout zoom. Une zone où tu es allé : l'art de chaque morceau de nouveau sur celui de la zone
-- (des cases cuites ou des couches vivantes), les morceaux inexplorés assombris et ceux explorés par-dessus, tels quels.
-- (Les morceaux de Blizzard sont des rectangles opaques, plus de la moitié de l'art d'une zone sous deux ou plus :
-- une ombre par morceau s'empilait plus sombre où ils se chevauchent et montrait les cases de chaque morceau en
-- lignes ; des copies de l'art sur le même art ne s'empilent pas, et leurs bords sont ceux des morceaux.) Bâtie la
-- première fois qu'on la veut, les morceaux d'une zone à sa première arrivée en vue ; cachée avec la zone hors de la vue.
--------------------------------------------------------------------------------

-- (une seule table : le fichier est près de la limite de 200 variables locales de Lua)
-- zones : mapID -> { frame, land, p, all = texture, rim = texture, dim = frame, pieces = { morceau -> { copies } } },
-- ou false. REACH : unités du monde autour d'une zone que couvre sa part de bord (BORDER_REACH de render.py).
-- DIM : la couleur d'un morceau inexploré, { r, g, b (multiplicateurs), désaturation } : près de celle de l'ombre
-- (UNDISCOVERED à son alpha sur l'art), car une texture ne peut que multiplier (DIM de render.py)
local Shade = { zones = {}, on = false, REACH = 64, DIM = { 0.38, 0.39, 0.43, 0.8 } }
-- de quelle force (l'assombrissement, 0..1 de l'ombre pleine) : l'alpha de l'ombre et DIM vers rien, de même, et
-- chaque texture d'ombre faite (teintée), recolorée quand elle change. DIMK : DIM à cette force
Shade.k, Shade.tinted, Shade.DIMK = 1, {}, { 0.38, 0.39, 0.43, 0.8 }
-- les couches d'ombre ancrées seulement tant qu'elles se montrent, comme les couches vivantes (Live) :
-- chaque image d'un déplacement ou d'un zoom remet en page tout ce qui est ancré à root, caché ou non
function Shade.Collect()
    local recs, prev = { on = true }, S.recCollect
    S.recCollect = recs
    return recs, prev
end
function Shade.Anchor(recs, on)
    if not recs or recs.on == on then return end
    recs.on = on
    for _, rec in ipairs(recs) do
        if on then PlaceRecord(rec) else rec[1]:ClearAllPoints() end
    end
end
function Shade.Tint(tex)
    Shade.tinted[#Shade.tinted + 1] = tex
    tex:SetColorTexture(UNDISCOVERED[1], UNDISCOVERED[2], UNDISCOVERED[3], UNDISCOVERED[4] * Shade.k)
end
-- color : la couleur de l'ombre ({ r, g, b } : la teinte de l'assombrissement, #9), ou nil pour l'ombre
-- sombre du jeu ; la couleur d'un morceau inexploré (DIM) la suit, comme l'ombre à son alpha sur du blanc
Shade.UNDISC0, Shade.DIM0 = { UNDISCOVERED[1], UNDISCOVERED[2], UNDISCOVERED[3] }, { Shade.DIM[1], Shade.DIM[2], Shade.DIM[3] }
function S.SetDarkening(k, color)
    k = math.max(0, math.min(1, tonumber(k) or 1))
    local c = type(color) == "table" and tonumber(color[1]) and tonumber(color[2]) and tonumber(color[3]) and color or nil
    local key = c and ("%.3f %.3f %.3f"):format(c[1], c[2], c[3]) or ""
    if k == Shade.k and key == (Shade.colorKey or "") then return end
    Shade.k, Shade.colorKey = k, key
    for i = 1, 3 do
        UNDISCOVERED[i] = c and math.max(0, math.min(1, c[i])) or Shade.UNDISC0[i]
        Shade.DIM[i] = c and (1 - UNDISCOVERED[4]) + UNDISCOVERED[4] * UNDISCOVERED[i] or Shade.DIM0[i]
    end
    for i = 1, 3 do Shade.DIMK[i] = 1 - (1 - Shade.DIM[i]) * k end
    Shade.DIMK[4] = Shade.DIM[4] * k
    S.greyD = Shade.DIMK[4]
    S.GreyMute()
    for _, tex in ipairs(Shade.tinted) do tex:SetColorTexture(UNDISCOVERED[1], UNDISCOVERED[2], UNDISCOVERED[3], UNDISCOVERED[4] * k) end
    for _, z in pairs(Shade.zones) do
        if z then
            z.coloured = nil
        end
    end
    if lastGrade then S.ApplyGrade(unpack(lastGrade)) end
end

function Shade.Texture(z, x, y, w, h)
    local tex = z.frame:CreateTexture(nil, "ARTWORK")
    Shade.Tint(tex)
    Record(tex, x, y, w, h)
    tex:AddMaskTexture(z.land)
    return tex
end

function Shade.Zone(mapID)
    local z = Shade.zones[mapID]
    if z ~= nil then return z end
    z = false
    local p = Place(mapID)
    if p and shadeRoot then
        local frame = CreateFrame("Frame", nil, shadeRoot)
        frame:SetAllPoints(root)
        local recs, prev = Shade.Collect()
        local land = ZoneMask(frame, p, ZONELAND)
        if land then
            z = { frame = frame, land = land, p = p }
            z.all = Shade.Texture(z, p.left, p.top, p.layer.layerWidth * p.sx, p.layer.layerHeight * p.sy)
            -- ... et sa part de la terre autour qui n'est à aucune zone (montagnes des bords, terre vide
            -- entre les zones : MapZoneBorder, sur le rectangle de son art et REACH autour) : une étendue
            -- de zones pas trouvées est sombre de l'une à l'autre
            local R = Shade.REACH
            local x, y = p.left - R, p.top - R
            local w, h = p.layer.layerWidth * p.sx + 2 * R, p.layer.layerHeight * p.sy + 2 * R
            local share = frame:CreateMaskTexture()
            share:SetTexture(TEX .. "MapZoneBorder\\" .. mapID, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            Record(share, x, y, w, h)
            z.rim = frame:CreateTexture(nil, "ARTWORK")
            Shade.Tint(z.rim)
            Record(z.rim, x, y, w, h)
            z.rim:AddMaskTexture(share)
            z.grey = Shade.Grey(mapID, p, share, x, y, w, h)
            z.recs = recs
        else
            frame:Hide()
        end
        S.recCollect = prev
    end
    Shade.zones[mapID] = z
    return z
end

-- Vu du continent, l'art est la peinture du continent lui-même, les bandes et les traits de ses zones peints
-- plus clairs, et ils se voyaient clairs à travers l'ombre (une capture d'écran) : sous une zone pas trouvée
-- du tout et sa part de la terre autour, une copie grisée de l'art du continent (la désaturation de Shade.DIMK),
-- dans la couche du continent (en fondu avec elle), ses cases près de la zone seulement
-- les copies de Shade.Grey estompées comme l'art qu'elles copient (S.SetZoom) : celui du monde cédant la place aux continents ;
-- seulement les copies montrées (les zones près de la vue) ; les autres sont estompées à leur apparition (list)
function S.GreyMute(list)
    local m, wo = math.max(muted, 0), math.max(worldOut, 0)
    local c = 1 - 0.45 * m
    local d = math.max(S.greyD or Shade.DIMK[4], 0.8 * m)
    local function Mute(tex)
        tex:SetDesaturation(d)
        tex:SetVertexColor(c, c * 0.97, c * 0.92)
        tex:SetAlpha((1 - BACK_MUTE * m) * (tex.omWorld and (1 - wo) or 1))
    end
    if list then for _, tex in ipairs(list) do Mute(tex) end return end
    for tex in pairs(S.greyTex or NONE) do
        if tex:IsShown() then Mute(tex) end
    end
end

function Shade.Grey(mapID, p, share, x, y, w, h)
    local info = C_Map.GetMapInfo(mapID)
    if not (info and info.parentMapID and contRoot) then return end
    if not S.greyRoot then
        S.greyRoot = CreateFrame("Frame", nil, contRoot)
        S.greyRoot:SetAllPoints(root)
        S.greyRoot:SetFrameLevel(contRoot:GetFrameLevel())
        S.greyRoot:SetShown(detailNow < 0.98)
    end
    local g = S.greyRoot
    local recs, prev = Shade.Collect()
    local land = ZoneMask(g, p, ZONELAND)
    local rim = g:CreateMaskTexture()
    rim:SetTexture(TEX .. "MapZoneBorder\\" .. mapID, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    Record(rim, x, y, w, h)
    local out = {}
    -- (la peinture du continent, et celle du monde de plus loin : chacune grisée à son apparition)
    for _, artID in ipairs({ info.parentMapID, WORLD }) do
        local c, files = Place(artID), ArtFiles(artID)
        if c and files and #files > 0 then
            local tw, th = c.layer.tileWidth, c.layer.tileHeight
            local cols = math.ceil(c.layer.layerWidth / tw)
            for j = 1, math.ceil(c.layer.layerHeight / th) do
                for k = 1, cols do
                    local file = files[(j - 1) * cols + k]
                    file = tonumber(file) or file
                    local tx, ty = c.left + (k - 1) * tw * c.sx, c.top + (j - 1) * th * c.sy
                    local pw = math.min(tw, c.layer.layerWidth - (k - 1) * tw)
                    local ph = math.min(th, c.layer.layerHeight - (j - 1) * th)
                    -- (chaque copie coupée à la propre boîte de son masque : le rectangle de l'art de la zone, ou celui-ci et
                    -- sa part autour ; une case entière sous chaque zone était dessinée encore et encore, et coûtait des
                    -- images par seconde au zoom)
                    local boxes = { { land or false, p.left, p.top, p.layer.layerWidth * p.sx, p.layer.layerHeight * p.sy }, { rim, x, y, w, h } }
                    for _, bx in ipairs(boxes) do
                        local mask = bx[1]
                        local x0, y0 = math.max(tx, bx[2]), math.max(ty, bx[3])
                        local x1, y1 = math.min(tx + pw * c.sx, bx[2] + bx[4]), math.min(ty + ph * c.sy, bx[3] + bx[5])
                        if file and mask and x1 > x0 and y1 > y0 then
                            local tex = g:CreateTexture(nil, "ARTWORK", nil, 1)
                            tex:SetTexture(file, nil, nil, "TRILINEAR")
                            local ku, kv = 1 / (tw * c.sx), 1 / (th * c.sy)
                            tex:SetTexCoord((x0 - tx) * ku, (x1 - tx) * ku, (y0 - ty) * kv, (y1 - ty) * kv)
                            Record(tex, x0, y0, x1 - x0, y1 - y0)
                            tex:AddMaskTexture(mask)
                            tex.omWorld = artID == WORLD or nil
                            tex:Hide()
                            S.greyTex = S.greyTex or {}
                            S.greyTex[tex] = true
                            out[#out + 1] = tex
                        end
                    end
                end
            end
        end
    end
    S.recCollect = prev
    out.recs = recs
    Shade.Anchor(recs, false)          -- (faites cachées : ancrées à leur apparition, Shade.Show)
    return out
end

-- une zone où tu es allé : l'art de chaque morceau de nouveau, comme les morceaux sont dessinés (le cadre de
-- la zone, le trou de sa bannière, sa copie harmonisée par la bande de bord), sur une couche au-dessus de l'art
-- des zones et des cases cuites et sous les copies du flou, les villes et la minicarte. Shade.Colour les assombrit
function Shade.Pieces(mapID, z)
    z.pieces = {}
    local p = z.p
    if not Shade.root then
        Shade.root = CreateFrame("Frame", nil, root)
        Shade.root:SetAllPoints(root)
        Shade.root:SetFrameLevel(blurRoot:GetFrameLevel())   -- (blurRoot n'a pas d'art à lui : ses copies sont un niveau plus haut)
    end
    local f = CreateFrame("Frame", nil, Shade.root)
    f:SetAllPoints(root)
    z.dim = f
    local recs, prev = Shade.Collect()
    z.dimRecs = recs
    local edge = ZoneMask(f, p, EDGE) or Feather(f, p, FEATHER_THIN)
    local band, hole = ZoneMask(f, p, BAND), BannerHole(f, p)
    z.dimLand = ZoneMask(f, p, ZONELAND)          -- (un morceau assombri : sa terre seulement, la mer qu'il peint laissée telle quelle)
    local tw, th = p.layer.tileWidth, p.layer.tileHeight
    ForEachPiece(mapID, function(files, x, y, w, h, _, piece)
        local list = {}
        local cols, rows = math.ceil(w / tw), math.ceil(h / th)
        for j = 1, rows do
            local ph = (j < rows) and th or (h - (rows - 1) * th)
            for k = 1, cols do
                local file = files[(j - 1) * cols + k]
                file = tonumber(file) or file
                local pw = (k < cols) and tw or (w - (cols - 1) * tw)
                if file and pw > 0 and ph > 0 then
                    local fw, fh = (k < cols) and tw or Pow2(pw), (j < rows) and th or Pow2(ph)
                    local tx, ty = p.left + (x + (k - 1) * tw) * p.sx, p.top + (y + (j - 1) * th) * p.sy
                    for copy = 1, band and 2 or 1 do
                        local tex = f:CreateTexture(nil, "ARTWORK")
                        tex:SetTexture(file, nil, nil, "TRILINEAR")
                        tex:SetTexCoord(0, pw / fw, 0, ph / fh)
                        Record(tex, tx, ty, pw * p.sx, ph * p.sy)
                        tex:AddMaskTexture(edge)
                        if hole then tex:AddMaskTexture(hole) end
                        if copy == 2 then tex:AddMaskTexture(band) end
                        list[#list + 1] = { tex, twin = copy == 2 }
                    end
                end
            end
        end
        z.pieces[piece] = list
    end)
    S.recCollect = prev
end

-- les copies colorées selon que leur morceau est exploré, aux réglages de couleur actuels : les explorés
-- comme les morceaux le sont, par-dessus les inexplorés, assombris (DIM) sur la seule terre de la zone (la mer
-- qu'elle peint laissée telle quelle) et sans leur copie harmonisée (une texture prend trois masques)
function Shade.Colour(mapID, z)
    local strength, desat = gradeNow[1], gradeNow[2]
    -- (seulement quand les réglages ou les morceaux explorés ont changé : ceci tourne à chaque tri)
    local un = 0
    for piece in pairs(z.pieces) do if piece.unexplored then un = un + 1 end end
    if z.coloured and z.cS == strength and z.cD == desat and z.cU == un and z.cK == Shade.k then return end
    z.coloured, z.cS, z.cD, z.cU, z.cK = true, strength, desat, un, Shade.k
    local m = D.MapGrade and D.MapGrade[mapID]
    local DK = Shade.DIMK
    for piece, list in pairs(z.pieces) do
        local dark = piece.unexplored and true or false
        for _, e in ipairs(list) do
            local r, g, b = 1, 1, 1
            if e.twin and m then r, g, b = 1 + (m[1] - 1) * strength, 1 + (m[2] - 1) * strength, 1 + (m[3] - 1) * strength end
            if dark then r, g, b = DK[1], DK[2], DK[3] end
            local tex = e[1]
            if z.dimLand and not e.twin and e.landed ~= dark then
                e.landed = dark
                if dark then tex:AddMaskTexture(z.dimLand) else tex:RemoveMaskTexture(z.dimLand) end
            end
            tex:SetVertexColor(r, g, b, 1)
            tex:SetDesaturation(dark and math.max(desat, DK[4]) or desat)
            tex:SetDrawLayer("ARTWORK", (dark and 0 or 2) + (e.twin and 1 or 0))
            tex:SetShown(not (e.twin and (dark or strength <= 0)))
        end
    end
end

-- combien d'une zone est inexploré : "all", "some", ou nil (rien, ou pas de morceaux)
function Shade.Unexplored(mapID)
    local list = pieces[mapID]
    if not list or next(list) == nil then return nil end
    local any, all = false, true
    for _, piece in pairs(list) do
        if piece.unexplored then any = true else all = false end
    end
    return all and "all" or (any and "some" or nil)
end

-- près de la vue : le rectangle de son art et REACH autour (sa part de bord), contre la boîte de S.Cull
function Shade.Near(mapID)
    local box = cullBox
    if not box then return true end
    local l, r, t, b = S.Rect(mapID)
    if not l then return false end
    local du, dv = Shade.REACH / W, Shade.REACH / H
    return r + du > box[1] and l - du < box[3] and b + dv > box[2] and t - dv < box[4]
end

-- une zone pas trouvée du tout : son ombre (et sa part de la terre des bords) ; une où tu es allé : les
-- copies de ses morceaux ; près de la vue seulement
function Shade.Show(mapID)
    local z = Shade.zones[mapID]
    local state = Shade.on and Shade.Unexplored(mapID)
    if not state then
        if z then
            z.frame:Hide()
            Shade.Anchor(z.recs, false)
            if z.dim then z.dim:Hide() Shade.Anchor(z.dimRecs, false) end
            if z.grey and z.greyShown then
                z.greyShown = false
                for _, tex in ipairs(z.grey) do tex:Hide() end
                Shade.Anchor(z.grey.recs, false)
            end
        end
        return
    end
    if z == nil then z = Shade.Zone(mapID) end
    if not z then return end
    local here = Shade.Near(mapID)
    z.near = here
    local whole = here and state == "all"
    Shade.Anchor(z.recs, whole)
    z.frame:SetShown(whole)
    local grey = whole
    if z.grey and z.greyShown ~= grey then
        z.greyShown = grey
        if grey then Shade.Anchor(z.grey.recs, true) S.GreyMute(z.grey) end
        for _, tex in ipairs(z.grey) do tex:SetShown(grey) end
        if not grey then Shade.Anchor(z.grey.recs, false) end
    end
    local some = here and state == "some"
    if some and not z.pieces then Shade.Pieces(mapID, z) end
    if z.dim then
        local copies = some and not Shade.Hide.minimap      -- (la minicarte dessinée : Shade.Hide assombrit par-dessus)
        Shade.Anchor(z.dimRecs, copies)
        z.dim:SetShown(copies)
        if copies then Shade.Colour(mapID, z) end
    end
end

--------------------------------------------------------------------------------
-- La terre inexplorée de près, cachée ou assombrie. Le détail de la minicarte (Close.lua) est dessiné sur l'art
-- des zones, et montrait la terre que les morceaux cachés laissent vide, ou telle quelle là où ils sont assombris.
-- Par-dessus, tant qu'il se montre : cachée, là où sont les morceaux inexplorés d'une zone et aucun exploré (la
-- différence de leurs rectangles, coupée en bandes le long des bords de chaque morceau), l'art vide de la zone de nouveau ;
-- assombrie, l'ombre qu'a une zone pas trouvée du tout (UNDISCOVERED), sur l'art et la minicarte de même,
-- dans la forme propre de chaque morceau inexploré (l'alpha de son art, adoucie comme les copies assombries
-- des morceaux : en rectangles elle avait des bords durs de près, #101, #129), les copies sous la minicarte rangées
-- pendant ce temps (les deux assombrissent de même : Shade.DIM est accordé à l'ombre). La terre inexplorée a le même
-- aspect de tout zoom, le détail de la minicarte la suivant.
--------------------------------------------------------------------------------

-- (dans la table de Shade : le fichier est à la limite de 200 variables locales de Lua)
-- zones : mapID -> { frame, un, grade } (un : combien de morceaux étaient inexplorés à sa création ; grade : le
-- mode et les couleurs de sa création) ; root : sa couche, sur la minicarte (S.artTop - 6), faite quand on la veut
-- rects : mapID -> { un, list } : les rectangles d'une zone, recalculés seulement quand elle a moins de morceaux inexplorés
-- mode : "hide", "dim" ou false (les lieux inexplorés tels quels)
Shade.Hide = { zones = {}, rects = {}, mode = false, minimap = false }

-- les rectangles qu'une zone cache (px de son art : x0, y0, x1, y1), et combien de ses morceaux sont inexplorés
function Shade.Hide.Rects(mapID)
    local list = pieces[mapID]
    if not list then return nil, 0 end
    local count = 0
    for _, piece in pairs(list) do if piece.unexplored then count = count + 1 end end
    local known = Shade.Hide.rects[mapID]
    if known and known[1] == count then return known[2], count end
    local un, ex, xs, ys = {}, {}, {}, {}
    for key, piece in pairs(list) do
        local w, h, x, y = strsplit(":", key)
        w, h, x, y = tonumber(w), tonumber(h), tonumber(x), tonumber(y)
        local r = { x, y, x + w, y + h }
        if piece.unexplored then un[#un + 1] = r else ex[#ex + 1] = r end
        xs[#xs + 1], xs[#xs + 2], ys[#ys + 1], ys[#ys + 2] = x, x + w, y, y + h
    end
    if #un == 0 then
        Shade.Hide.rects[mapID] = { 0, nil }
        return nil, 0
    end
    table.sort(xs)
    table.sort(ys)
    local function Inside(rs, cx, cy)
        for _, r in ipairs(rs) do
            if cx > r[1] and cx < r[3] and cy > r[2] and cy < r[4] then return true end
        end
    end
    local out = {}
    for j = 1, #ys - 1 do
        local y0, y1 = ys[j], ys[j + 1]
        if y1 > y0 then
            local run                       -- (des cellules côte à côte sur une rangée : une bande)
            for i = 1, #xs - 1 do
                local x0, x1 = xs[i], xs[i + 1]
                if x1 > x0 then
                    local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                    if Inside(un, cx, cy) and not Inside(ex, cx, cy) then
                        if run and run[3] == x0 then run[3] = x1 else run = { x0, y0, x1, y1 } out[#out + 1] = run end
                    else
                        run = nil
                    end
                end
            end
        end
    end
    Shade.Hide.rects[mapID] = { count, out }
    return out, count
end

-- les cases des morceaux inexplorés, là où elles sont dessinées (unités du monde, comme Shade.Pieces pose leurs copies) :
-- { fichier, x, y, w, h (l'art que la case montre), fw, fh (son fichier entier, la puissance de deux suivante au bord) }
function Shade.Hide.Tiles(mapID, p)
    local out = {}
    local tw, th = p.layer.tileWidth, p.layer.tileHeight
    ForEachPiece(mapID, function(files, x, y, w, h, _, piece)
        if not piece.unexplored then return end
        local cols, rows = math.ceil(w / tw), math.ceil(h / th)
        for j = 1, rows do
            local ph = (j < rows) and th or (h - (rows - 1) * th)
            for k = 1, cols do
                local file = files[(j - 1) * cols + k]
                file = tonumber(file) or file
                local pw = (k < cols) and tw or (w - (cols - 1) * tw)
                if file and pw > 0 and ph > 0 then
                    local fw, fh = (k < cols) and tw or Pow2(pw), (j < rows) and th or Pow2(ph)
                    out[#out + 1] = { file = file, x = p.left + (x + (k - 1) * tw) * p.sx, y = p.top + (y + (j - 1) * th) * p.sy,
                        w = pw * p.sx, h = ph * p.sy, fw = fw * p.sx, fh = fh * p.sy }
                end
            end
        end
    end)
    return out
end

-- l'art vide d'une zone sur ses rectangles cachés, dessiné comme son art de base (PlaceBase : sur son territoire,
-- sa copie harmonisée par sa bande de bord aussi)
function Shade.Hide.Build(mapID, rects, un, grade)
    local p = Place(mapID)
    local files = p and ArtFiles(mapID)
    if not files or #files == 0 then return false end
    local f = CreateFrame("Frame", nil, Shade.Hide.root)
    f:SetAllPoints(root)
    local recs, prev = Shade.Collect()
    local made = Shade.Hide.BuildIn(f, p, files, mapID, rects, un, grade)
    S.recCollect = prev
    made.recs = recs
    return made
end
function Shade.Hide.BuildIn(f, p, files, mapID, rects, un, grade)
    if Shade.Hide.mode == "dim" then
        -- (l'ombre sur la seule terre de la zone, comme une zone pas trouvée du tout est ombrée : la mer qu'elle peint
        -- laissée ; par l'art de chaque morceau inexploré, son alpha donnant la forme de l'ombre : Shade.Hide.Tiles)
        local land = ZoneMask(f, p, ZONELAND)
        for _, t in ipairs(Shade.Hide.Tiles(mapID, p)) do
            local tex = f:CreateTexture(nil, "ARTWORK")
            Shade.Tint(tex)
            Record(tex, t.x, t.y, t.w, t.h)
            local shape = f:CreateMaskTexture()
            shape:SetTexture(t.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            Record(shape, t.x, t.y, t.fw, t.fh)      -- (le fichier entier : un masque ne se coupe pas, il se pose)
            tex:AddMaskTexture(shape)
            if land then tex:AddMaskTexture(land) end
        end
        return { frame = f, un = un, grade = grade }
    end
    local band, territory = ZoneMask(f, p, BAND), ZoneMask(f, p, TERRITORY)
    local mask = territory or Feather(f, p, FEATHER)
    local m = D.MapGrade and D.MapGrade[mapID]
    local strength, desat = gradeNow[1], gradeNow[2]
    local tw, th = p.layer.tileWidth, p.layer.tileHeight
    local cols = math.ceil(p.layer.layerWidth / tw)
    for _, r in ipairs(rects) do
        for j = math.floor(r[2] / th), math.ceil(r[4] / th) - 1 do
            for k = math.floor(r[1] / tw), math.ceil(r[3] / tw) - 1 do
                local file = files[j * cols + k + 1]
                file = tonumber(file) or file
                local x0, y0 = math.max(r[1], k * tw), math.max(r[2], j * th)
                local x1, y1 = math.min(r[3], (k + 1) * tw), math.min(r[4], (j + 1) * th)
                if file and x1 > x0 and y1 > y0 then
                    for copy = 1, band and 2 or 1 do
                        local tex = f:CreateTexture(nil, "ARTWORK", nil, copy - 1)
                        tex:SetTexture(file, nil, nil, "TRILINEAR")
                        tex:SetTexCoord((x0 - k * tw) / tw, (x1 - k * tw) / tw, (y0 - j * th) / th, (y1 - j * th) / th)
                        Record(tex, p.left + x0 * p.sx, p.top + y0 * p.sy, (x1 - x0) * p.sx, (y1 - y0) * p.sy)
                        tex:AddMaskTexture(mask)
                        tex:SetDesaturation(desat)
                        if copy == 2 then
                            tex:AddMaskTexture(band)
                            if m then tex:SetVertexColor(1 + (m[1] - 1) * strength, 1 + (m[2] - 1) * strength, 1 + (m[3] - 1) * strength, 1) end
                        end
                    end
                end
            end
        end
    end
    return { frame = f, un = un, grade = grade }
end

-- montré tant que la terre inexplorée est cachée ou assombrie (assombrie : une zone où tu es allé, une jamais
-- trouvée étant déjà ombrée en entier sur la minicarte), que le détail de la minicarte est dessiné, et que la
-- zone est près de la vue ; refait quand le joueur en a exploré davantage, ou que le mode ou les couleurs
-- ont changé
function Shade.Hide.Show(mapID)
    local z = Shade.Hide.zones[mapID]
    local mode = Shade.Hide.mode
    local want = (mode == "hide" or (mode == "dim" and Shade.Unexplored(mapID) == "some"))
        and Shade.Hide.minimap and root and Shade.Near(mapID)
    if want then
        if not Shade.Hide.root then
            Shade.Hide.root = CreateFrame("Frame", nil, root)
            Shade.Hide.root:SetAllPoints(root)
            Shade.Hide.root:SetFrameLevel(S.artTop - 6)
        end
        local rects, un = Shade.Hide.Rects(mapID)
        local g1, g2 = gradeNow[1], gradeNow[2]
        if z and (z.un ~= un or z.gm ~= mode or z.g1 ~= g1 or z.g2 ~= g2) then
            -- l'ancien lâché : désancré et ses fichiers rendus (il restait ancré)
            if z.frame then z.frame:Hide() end
            Shade.Anchor(z.recs, false)
            for _, rec in ipairs(z.recs or NONE) do
                local r = rec[1]
                if r.SetTexture then pcall(r.SetTexture, r, nil) end
            end
            z = nil
        end
        if not z then
            z = (mode == "dim" and un > 0 or rects and #rects > 0) and Shade.Hide.Build(mapID, rects, un, mode)
                or {}
            z.un, z.gm, z.g1, z.g2 = un, mode, g1, g2
            Shade.Hide.zones[mapID] = z
        end
        Shade.Anchor(z.recs, true)
        if z.frame then z.frame:Show() end
    elseif z and z.frame then
        z.frame:Hide()
        Shade.Anchor(z.recs, false)
    end
end

-- Close.lua : si le détail de la minicarte est dessiné
function S.MinimapShown(on)
    on = on and true or false
    if Shade.Hide.minimap == on then return end
    Shade.Hide.minimap = on
    for mapID in pairs(zoneTex) do
        Shade.Show(mapID)                -- (les copies assombries d'une zone rangées sous la minicarte, ou remises)
        Shade.Hide.Show(mapID)
    end
end

-- un point du monde (0..1) caché comme terre inexplorée (Close.lua : une grotte là ne fait pas surface)
function S.HiddenAt(u, v)
    if Shade.Hide.mode ~= "hide" then return false end
    if Shade.Places.At(u, v) then return true end   -- (un lieu qu'un trou peint montre, pas encore trouvé)
    local chain = S.ChainAt(u, v)
    local mapID = chain[#chain]
    local p = mapID and Place(mapID)
    local rects = p and Shade.Hide.Rects(mapID)
    if not rects then return false end
    local x, y = (u * W - p.left) / p.sx, (v * H - p.top) / p.sy
    for _, r in ipairs(rects) do
        if x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4] then return true end
    end
    return false
end

-- les textures d'une zone : celles près de la vue (la boîte de S.Cull), case par case : de près, seule la part
-- d'une zone à l'écran est dessinée (et a ses fichiers chargés), pas tout de chaque zone qui touche la vue.
-- Une cachée lâche son ancre (et les masques des couches vivantes d'une zone aussi tant qu'aucun de son art vivant
-- ne peut se montrer) : un déplacement ou un zoom ne remet pas en page des milliers de textures que personne ne voit (Live, plus haut)
ShowZone = function(mapID)
    local here = inView[mapID] ~= false
    local inside = inView[mapID] == true          -- (en vue et dessinée : ses fichiers sont voulus)
    local hide, strength = gradeNow[3] == "hide", gradeNow[1]
    local box = cullBox
    local z = Live.zones and Live.zones[mapID]       -- (une zone arrivée par son continent, ApplyDetail : pas encore, pas dessinée)
    local zoneOn = not z or z.on
    for _, e in ipairs(zoneTex[mapID] or NONE) do
        local tex = e[1]
        local near = here and (not box or not e.u0 or (e.u1 > box[1] and e.u0 < box[3] and e.v1 > box[2] and e.v0 < box[4]))
        local drawn = (not e.layer or detailLive) and zoneOn   -- (les couches vivantes : seulement tant qu'elles se montrent ; les villes : toujours)
        local un = e[3] and e[3].unexplored
        -- (une case de base sous les morceaux de sa zone seulement quand les inexplorés sont cachés : ns.MapUnder)
        drawn = drawn and not (e.under and not hide)
            -- (et pas la copie de flou d'un morceau inexploré tant que la terre inexplorée est assombrie : les quatre copies
            -- du flou sont sur les assombries (Shade.Pieces) et en couvrent les quatre cinquièmes : du zoom de l'adoucissement
            -- à celui de la minicarte, l'assombrissement disparaissait presque, et revenait chaque fois que la carte bougeait)
            and not (e.blur and un and Shade.on)
        if near and drawn and inside and (detailLive or Live.seen) and tex.omFile and not tex.omQueued then
            tex.omQueued = true
            loadQueue[#loadQueue + 1] = tex
            loader:Show()
            Baked.busy = true
        end
        local show = near and drawn and not (un and hide) and (not e.twin or strength > 0)
        if e.shown ~= show then
            e.shown = show
            if show then
                if not tex:GetPoint() then PlaceRecord(tex.omRec) end
                tex:Show()
            else
                tex:Hide()
                tex:ClearAllPoints()
            end
        end
    end
    local want = (here and detailLive and zoneOn) and true or false
    if Live.placed[mapID] ~= want then
        Live.placed[mapID] = want
        for _, rec in ipairs(Live.masks[mapID] or NONE) do
            if want then PlaceRecord(rec) else rec[1]:ClearAllPoints() end
        end
    end
    Shade.Show(mapID)
    Shade.Hide.Show(mapID)
end

-- combien de l'art des zones a ses fichiers chargés, sur tout ;
-- les régions posées depuis la construction (ancres des icônes, couches de près) ; la file de chargement
function S.ArtStats()
    local loaded, total = 0, 0
    for _, list in pairs(zoneTex) do
        for _, e in ipairs(list) do
            total = total + 1
            if not e[1].omFile then loaded = loaded + 1 end
        end
    end
    local live = 0
    for _ in pairs(dynamic) do live = live + 1 end
    return loaded, total, live, #loadQueue - loadAt + 1
end

-- la couleur d'une texture de zone : un peu de couleur retirée. (L'alpha propre de la texture est son fondu
-- d'arrivée ; les lieux inexplorés sont assombris par les ombres dessus, Shade.Show)
GradeEntry = function(g, desat)
    g[1]:SetVertexColor(1, 1, 1, 1)
    g[1]:SetDesaturation(desat)
end

function S.ApplyGrade(strength, desat, unexplored)
    lastGrade = { strength, desat, unexplored }
    gradeNow = { strength, desat, unexplored }
    local grade = D.MapGrade or {}
    local dim = unexplored == "dim" and D.MapGrade ~= nil   -- (les ombres ont besoin des masques de terre de ses zones)
    Shade.on = dim
    Shade.Hide.mode = (unexplored == "hide" or dim) and unexplored or false
    for _, g in ipairs(graded) do GradeEntry(g, desat) end
    for _, g in ipairs(twins) do
        local tex, m = g[1], grade[g[2]]
        tex:SetVertexColor(1 + (m[1] - 1) * strength, 1 + (m[2] - 1) * strength, 1 + (m[3] - 1) * strength, 1)
        tex:SetDesaturation(desat)
    end
    -- une zone pas trouvée du tout : son art vivant grisé (la désaturation de DIMK) sous son ombre, pour que les
    -- bandes et traits plus clairs que peint son art ne se voient pas clairs à travers de près. (Les cases cuites,
    -- dessinées de plus loin, restent telles quelles : les couches vivantes à tous les zooms coûtent trop d'images par
    -- seconde, et de là-bas c'est surtout la peinture du continent, grisée par Shade.Grey, qui se voit)
    for mapID, list in pairs(zoneTex) do
        local grey = Shade.on and Shade.Unexplored(mapID) == "all"
        if grey or list.greyed then
            list.greyed = grey or nil
            local d = grey and math.max(desat, Shade.DIMK[4]) or desat
            for _, e in ipairs(list) do e[1]:SetDesaturation(d) end
        end
    end
    for mapID in pairs(zoneTex) do ShowZone(mapID) end
    Shade.Places.Show()
    if root then
        for _, c in ipairs(cities) do c.dark = nil end   -- (le réglage plus haut a reposé leurs couleurs)
        cities.Dim()
        cities.Banners()
    end
    -- l'art cuit seulement aux réglages où il a été cuit (lieux inexplorés cachés : en vivant, morceau par morceau),
    -- et avec des cases dans la langue du client (Baked.lettered)
    local art = D.MapZoneArt
    Baked.use = (art and Baked.frame and strength == art.colorMatch and desat >= art.desaturate - 0.001
        and unexplored ~= "hide" and not Baked.noFills and Baked.lettered and (Baked.missing or 0) < 3) and true or false
    local bd = art and math.max(0, (desat - art.desaturate) / (1 - art.desaturate)) or 0
    if Baked.use and math.abs(bd - Baked.desat) > 0.001 then
        Baked.desat = bd
        for _, t in ipairs(Baked.tiles) do if t.tex then t.tex:SetDesaturation(bd) end end
    end
    if root then
        appliedDetail = nil
        ApplyDetail()
    end
end

-- seul ce qui est près de la vue est dessiné : l'art de chaque zone (case par case), les villes, les trous comblés.
-- (Les régions cachées ne coûtent rien ; au zoom le plus proche, la plupart du monde est hors de l'écran.) La boîte
-- est gardée tant que la vue reste bien dedans : un déplacement la refait de temps en temps, pas à chaque image.
-- margin : de la taille de la vue, de chaque côté ; refaite quand la vue arrive à `keep` de son bord (de
-- la taille de la vue), ou a zoomé `zoom` fois depuis (la boîte serait bien trop grande).
-- (Une seule table : le fichier est près de la limite de 200 variables locales de Lua)
local CULL = { margin = D.ClientMaps and D.ClientMaps.cullMargin or 0.35, keep = 0.1, zoom = 1.6 }
function S.Cull(u0, v0, u1, v1)
    if not root then return end
    local w, h = u1 - u0, v1 - v0
    local box = cullBox
    local keep = CULL.keep
    if box and box.done and w * CULL.zoom > box.w and u0 - w * keep > box[1] and u1 + w * keep < box[3]
        and v0 - h * keep > box[2] and v1 + h * keep < box[4] then return end
    local mu, mv = w * CULL.margin, h * CULL.margin
    u0, v0, u1, v1 = u0 - mu, v0 - mv, u1 + mu, v1 + mv
    cullBox = box or {}
    cullBox[1], cullBox[2], cullBox[3], cullBox[4], cullBox.w = u0, v0, u1, v1, w
    -- (faite à la fin : une qui s'est arrêtée sur une erreur est refaite la fois suivante, pas gardée telle quelle)
    cullBox.done = false
    for mapID in pairs(zoneTex) do
        local l, r, t, b = S.Rect(mapID)
        local here = (l and r > u0 and l < u1 and b > v0 and t < v1) and true or false
        if here or inView[mapID] ~= here then        -- (une en vue : ses cases près de la nouvelle boîte)
            inView[mapID] = here
            ShowZone(mapID)
        end
    end
    for _, c in ipairs(culled) do
        local here = c[4] > u0 and c[2] < u1 and c[5] > v0 and c[3] < v1
        if c.here ~= here then
            c.here = here
            local r = c[1]
            if r.omRec then                          -- (une texture à elle, le papier des trous : son ancre aussi, Live)
                if here then
                    if not r:GetPoint() then PlaceRecord(r.omRec) end
                else
                    r:ClearAllPoints()
                end
            end
            r:SetShown(here and (not c.city or (r:GetAlpha() or 1) > 0.003))   -- (une ville : tant qu'elle est en fondu, SetZoom)
            -- (une case de fond triée : son fichier une fois près de la vue et sa couche montrée)
            if here and r.omFile and (not c.layer or c.layer:IsShown()) then S.QueueLoad(r) end
        end
    end
    Baked.Cull()
    -- les noms : chaque lettre fait de nombreuses chaînes de police (son halo), toutes déplacées à chaque image d'un déplacement
    for _, n in ipairs(names) do
        local near = not n.l or (n.r > u0 and n.l < u1 and n.b > v0 and n.t < v1)
        if n.near ~= near then
            n.near = near
            n[1]:SetShown(near and (n[1].omFade or 0) > 0.003)
        end
    end
    if Shade.on then
        for mapID, z in pairs(Shade.zones) do
            if z and z.near ~= Shade.Near(mapID) then Shade.Show(mapID) end
        end
    end
    if Shade.Hide.mode then Shade.Places.Show() end   -- (les lieux qu'un trou peint montre, près de la boîte)
    -- les cases des icônes (Map/PinSets.lua)
    if S.OnCullIcons then S.OnCullIcons(u0, v0, u1, v1) end
    cullBox.done = true
end

-- les cases de fond triées près de la vue, une fois leur couche montrée (l'art des continents à son arrivée)
function S.LoadCulled()
    for _, c in ipairs(culled) do
        if c.here and c.layer and c[1].omFile and c.layer:IsShown() then S.QueueLoad(c[1]) end
    end
end

-- la carte montrée de nouveau : la prochaine S.Cull tourne en entier, et les villes sont remontrées, leurs cadres,
-- textures et fondus (une ville restée cachée montrait la peinture de sa zone jusqu'à un /reload : #30)
function S.Recull()
    if not root then return end
    if cullBox then cullBox.done = false end
    for _, c in ipairs(cities) do
        c.alpha = nil
        for _, e in ipairs(zoneTex[c.mapID] or NONE) do e.shown = nil end
    end
    for _, c in ipairs(culled) do
        if c.city then c.here = nil end
    end
end

-- les cases cuites (Baked, plus haut) : chacune posée la première fois qu'elle est près de la vue (son fichier posé alors),
-- et montrée près de la vue (la boîte de S.Cull) tant que l'art cuit se montre
function Baked.Build()
    local art = D.MapZoneArt
    if not art or not root then return end
    local f = CreateFrame("Frame", nil, root)
    f:SetAllPoints(root)
    f:SetFrameLevel(coreRoot:GetFrameLevel())   -- (à la place des couches vivantes, sous le flou et les villes)
    f:Hide()
    Baked.frame = f
    local size = art.step / art.px            -- unités du monde qu'une case couvre
    Baked.inset = (art.size - art.step) / 2 / art.size
    for _, key in ipairs(art.tiles) do
        local i, j = math.floor(key / 256), key % 256
        local x, y = i * size, j * size
        Baked.tiles[#Baked.tiles + 1] = { name = i .. "_" .. j, x = x, y = y, size = size,
            u0 = x / W, v0 = y / H, u1 = (x + size) / W, v1 = (y + size) / H }
    end
end

-- /mmir carte status : les cases cuites que le jeu n'a pas trouvées (#349, #353), et où il a cherché
function S.BakedMissing() return Baked.missing or 0, Baked.path end

function Baked.Cull()
    local f, box = Baked.frame, cullBox
    if not f or not f:IsShown() then return end
    for _, t in ipairs(Baked.tiles) do
        local near = not box or (t.u1 > box[1] and t.u0 < box[3] and t.v1 > box[2] and t.v0 < box[4])
        if near and not t.tex then
            t.tex = f:CreateTexture(nil, "ARTWORK")
            local ok = t.tex:SetTexture(Baked.path .. t.name, nil, nil, "TRILINEAR")
            t.tex:SetTexCoord(Baked.inset, 1 - Baked.inset, Baked.inset, 1 - Baked.inset)
            t.tex:SetDesaturation(Baked.desat)
            Record(t.tex, t.x, t.y, t.size, t.size)
            t.shown = true
            -- (une case que le jeu ne trouve pas se dessine comme un carré vert plein, de la taille d'une zone ou plus : #349,
            -- #353, une installation qui ne les a pas, ou un jeu pas relancé depuis. Celle-là est laissée de côté ; s'il en
            -- manque quelques-unes, les zones sont dessinées en vivant, comme dans un client sans cases dans sa langue)
            if ok == false then
                t.missing, t.shown = true, false
                t.tex:Hide()
                Baked.missing = (Baked.missing or 0) + 1
                if Baked.missing == 3 and lastGrade then C_Timer.After(0, function() S.ApplyGrade(unpack(lastGrade)) end) end
            end
        end
        if t.tex and not t.missing and t.shown ~= near then
            t.shown = near
            t.tex:SetShown(near)
        end
    end
end

-- les morceaux des cartes de zone dont le rectangle contient le point du monde (x, y) (unités du monde), et leurs zones
-- (un ensemble) : ce qui dit si un lieu sans morceaux à lui a été trouvé (une ville, Shade.Places)
function Shade.Under(x, y)
    local covers, zones = {}, {}
    for zoneID, list in pairs(pieces) do
        local p = Place(zoneID)
        if p then
            local px_, py_ = (x - p.left) / p.sx, (y - p.top) / p.sy
            for key, piece in pairs(list) do
                local w, h, kx, ky = strsplit(":", key)
                w, h, kx, ky = tonumber(w), tonumber(h), tonumber(kx), tonumber(ky)
                if w and px_ >= kx and px_ <= kx + w and py_ >= ky and py_ <= ky + h then
                    covers[#covers + 1] = piece
                    zones[zoneID] = true
                end
            end
        end
    end
    return covers, zones
end

-- trouvé : un de ces morceaux exploré (la carte de Blizzard dessine le rectangle entier de chacun), ou aucun là
function Shade.Found(covers)
    if #covers == 0 then return true end
    for _, piece in ipairs(covers) do
        if not piece.unexplored then return true end
    end
    return false
end

-- Si chaque ville a été trouvée : sa propre carte n'a pas de morceaux à explorer, alors les morceaux des cartes de
-- zone sous son centre (ceux de Durotar pour Orgrimmar) le disent ; s'il n'y en a aucun, elle est trouvée. La ville
-- elle-même aussi, une fois que tu y es entré : par le tram, Forgefer est trouvée sans que le morceau de Dun Morogh
-- dessus le soit (les lieux explorés du jeu sur la carte de la ville, et où tu es). Les textures d'une ville
-- partagent un même morceau de remplacement : les lieux inexplorés cachés cachent une ville pas trouvée comme un
-- morceau, et la bannière de sa zone avec. (Sur `cities` : le fichier est près de la limite de 200 variables locales)
cities.Build = function()
    for _, c in ipairs(cities) do
        local l, r, t, b = S.Rect(c.mapID)
        c.covers, c.piece = Shade.Under((l + r) / 2 * W, (t + b) / 2 * H), { key = "city" }
        for _, e in ipairs(zoneTex[c.mapID] or NONE) do e[3] = c.piece end
    end
    cities.Refresh()
end

cities.Visited = function(mapID)
    if C_Map.GetBestMapForUnit("player") == mapID then return true end
    local at = C_MapExplorationInfo.GetExploredAreaIDsAtPosition
    local ok, areas = pcall(at, mapID, CreateVector2D(0.5, 0.5))
    return ok and type(areas) == "table" and #areas > 0
end

-- (vrai quand une ville a été trouvée ou perdue depuis)
cities.Refresh = function()
    local changed = false
    for _, c in ipairs(cities) do
        local un = not (Shade.Found(c.covers) or cities.Visited(c.mapID))
        if c.piece.unexplored ~= un then c.piece.unexplored, changed = un, true end
    end
    return changed
end

-- les bannières des zones pour leurs villes : avec le détail des zones, cédant la place à celle de la ville (BANNER_OUT),
-- et parties avec une ville pas trouvée tant que les lieux inexplorés sont cachés
cities.Banners = function()
    for _, c in ipairs(cities) do
        if c.banner then
            local out = D.MapCityTitles and D.MapCityTitles[c.mapID] and Smooth(BANNER_OUT[1] * c[2], BANNER_OUT[2] * c[2]) or 0
            local lost = gradeNow[3] == "hide" and c.piece and c.piece.unexplored
            Fade(c.banner, lost and 0 or math.floor(detailNow * (1 - out) * 50 + 0.5) / 50)
        end
    end
end

-- une ville pas trouvée tant que les lieux inexplorés sont assombris : sa propre carte et la bannière de sa zone
-- assombries comme l'art inexploré de la zone (Shade.DIM). Les deux sont dessinées sur l'assombrissement (la bannière
-- sur tout, la ville sur les morceaux assombris d'une zone visitée) : il ne les atteint pas
cities.Dim = function()
    local DK = Shade.DIMK
    local strength, desat = gradeNow[1], gradeNow[2]
    for _, c in ipairs(cities) do
        local dark = Shade.on and c.piece and c.piece.unexplored and true or false
        if c.dark ~= dark then
            c.dark = dark
            local m = D.MapGrade and D.MapGrade[c.mapID]
            for _, e in ipairs(zoneTex[c.mapID] or NONE) do
                local r, g, b = 1, 1, 1
                if e.twin and m then r, g, b = 1 + (m[1] - 1) * strength, 1 + (m[2] - 1) * strength, 1 + (m[3] - 1) * strength end
                if dark then r, g, b = r * DK[1], g * DK[2], b * DK[3] end
                e[1]:SetVertexColor(r, g, b, 1)
                e[1]:SetDesaturation(dark and math.max(desat, DK[4]) or desat)
            end
            if c.bannerTex then
                c.bannerTex:SetVertexColor(dark and DK[1] or 1, dark and DK[2] or 1, dark and DK[3] or 1, 1)
                c.bannerTex:SetDesaturation(dark and DK[4] or 0)
            end
        end
    end
end

-- pour Close.lua : le cadre propre d'une ville souterraine (la minicarte du jeu de la ville s'y pose, sur sa
-- carte), si c'est une ville pas trouvée tant que les lieux inexplorés sont cachés (sa carte l'est), et l'ombre
-- tant qu'ils sont assombris (Shade.DIM : sa carte est assombrie ainsi)
function S.UndergroundCity(mapID)
    if not UNDERGROUND_CITIES[mapID] then return end
    for _, c in ipairs(cities) do
        if c.mapID == mapID then
            local lost = c.piece and c.piece.unexplored
            return c[1], (lost and gradeNow[3] == "hide") and true or false, lost and Shade.on and Shade.DIMK or nil
        end
    end
end

--------------------------------------------------------------------------------
-- Des lieux qu'un trou peint montre et qu'aucune carte de zone ne dessine (ns.MapGapPlaces, tools/map-preview/gapplaces.py) :
-- ceux de WoW Forever, peints d'après la minicarte du jeu (le site de fouilles des Paluns, une vallée verte
-- au sud de Whelgar). Le jeu ne marque personne comme les ayant explorés et les cartes de Blizzard ne les dessinent
-- jamais, alors chacun se trouve comme une ville, par les morceaux des cartes de zone sous son milieu. Tant que les lieux
-- inexplorés sont cachés, un pas trouvé est le papier vide des trous (MapPaper, posé comme PlaceLand le pose, pour qu'il
-- rejoigne le leur) sur la peinture et la minicarte de près ; sur la couche des zones, il apparaît avec leur
-- détail. Assombri : l'ombre de la terre inexplorée, sur les deux, de tout zoom, sauf si sa zone n'est pas
-- trouvée du tout (l'ombre de cette zone a sa part de la terre autour, celui-ci avec).
--------------------------------------------------------------------------------

-- (dans la table de Shade : le fichier est à la limite de 200 variables locales de Lua)
-- list : { area, box (l, t, r, b, 0..1), cells, covers, zones, found, hide = cadre, dim = cadre },
-- faite la première fois qu'on la veut (les morceaux des zones sont connus alors)
Shade.Places = { list = false }

function Shade.Places.Build()
    local list = {}
    for _, x in ipairs(D.MapGapPlaces or NONE) do
        local e = { area = x[1], box = x[3], cells = x[5] }
        e.covers, e.zones = Shade.Under(x[4][1] * W, x[4][2] * H)
        list[#list + 1] = e
    end
    Shade.Places.list = list
    Shade.Places.Refresh()
end

function Shade.Places.Refresh()
    for _, e in ipairs(Shade.Places.list or NONE) do e.found = Shade.Found(e.covers) end
end

-- la couverture d'un lieu : "hide", le papier (sur la minicarte : le niveau de Shade.Hide) ; "dim", l'ombre (celui de shadeRoot)
function Shade.Places.Frame(e, how)
    local b = e.box
    local x, y, w, h = b[1] * W, b[2] * H, (b[3] - b[1]) * W, (b[4] - b[2]) * H
    local f = CreateFrame("Frame", nil, how == "hide" and tilesRoot or shadeRoot)
    f:SetAllPoints(root)
    f:SetFrameLevel(how == "hide" and S.artTop - 6 or shadeRoot:GetFrameLevel())
    local mask = f:CreateMaskTexture()
    mask:SetTexture(TEX .. "MapGapPlace\\" .. e.area, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    Record(mask, x, y, w, h)
    local paper = D.MapGaps and D.MapGaps.paper
    if how == "hide" and paper then
        for n, o in ipairs(PAPER_LAYERS) do
            local tex = f:CreateTexture(nil, "ARTWORK", nil, n)
            local s_ = paper * o[1]
            tex:SetTexture(PAPER, "REPEAT", "REPEAT")
            tex:SetTexCoord(x / s_ + o[2], (x + w) / s_ + o[2], y / s_ + o[2] * 1.7, (y + h) / s_ + o[2] * 1.7)
            tex:SetVertexColor(1, 1, 1, o[3])
            Record(tex, x, y, w, h)
            tex:AddMaskTexture(mask)
        end
    elseif how == "dim" then
        local tex = f:CreateTexture(nil, "ARTWORK")
        Shade.Tint(tex)
        Record(tex, x, y, w, h)
        tex:AddMaskTexture(mask)
    end
    f:Hide()
    return f
end

-- la couverture de chaque lieu pour le mode actuel des lieux inexplorés, près de la vue (la boîte de S.Cull) seulement
function Shade.Places.Show()
    if not root then return end
    local P = Shade.Places
    if not P.list then P.Build() end
    local mode, box = Shade.Hide.mode, cullBox
    for _, e in ipairs(P.list) do
        local b = e.box
        local lost = not e.found and (not box or (b[3] > box[1] and b[1] < box[3] and b[4] > box[2] and b[2] < box[4]))
        local whole = false
        for zoneID in pairs(e.zones) do
            if Shade.Unexplored(zoneID) == "all" then whole = true end
        end
        local hide, dim = lost and mode == "hide", lost and mode == "dim" and not whole
        if hide and not e.hide then e.hide = P.Frame(e, "hide") end
        if dim and not e.dim then e.dim = P.Frame(e, "dim") end
        if e.hide and e.hide:IsShown() ~= hide then e.hide:SetShown(hide) end
        if e.dim and e.dim:IsShown() ~= dim then e.dim:SetShown(dim) end
    end
end

-- si un lieu pas trouvé couvre le point du monde (u, v) (0..1), par ses cellules (16 de côté :
-- CELLS de gapplaces.py) couvertes à moitié ou plus (S.HiddenAt)
function Shade.Places.At(u, v)
    for _, e in ipairs(Shade.Places.list or NONE) do
        local b = e.box
        if not e.found and u >= b[1] and u < b[3] and v >= b[2] and v < b[4] then
            local k = math.floor((v - b[2]) / (b[4] - b[2]) * 16) * 16 + math.floor((u - b[1]) / (b[3] - b[1]) * 16) + 1
            if (tonumber(e.cells:sub(k, k), 16) or 0) >= 8 then return true end
        end
    end
    return false
end

-- le joueur est allé quelque part de nouveau : une ville trouvée en y entrant (ZONE_CHANGED_NEW_AREA)
function S.RefreshCities()
    if cities.Refresh() then
        Shade.Places.Refresh()
        if lastGrade then S.ApplyGrade(unpack(lastGrade)) end
    end
end

-- le joueur a exploré quelque part : ses morceaux cessent d'être inexplorés (MAP_EXPLORATION_UPDATED)
function S.RefreshExplored()
    local changed = false
    for mapID, list in pairs(pieces) do
        local now = {}
        for _, info in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}) do
            now[info.textureWidth .. ":" .. info.textureHeight .. ":" .. info.offsetX .. ":" .. info.offsetY] = true
        end
        for key, piece in pairs(list) do
            local un = not now[key]
            if piece.unexplored ~= un then piece.unexplored, changed = un, true end
        end
    end
    -- (une ville trouvée en y entrant, les morceaux de la zone dessus inchangés : Forgefer par le tram)
    if cities.Refresh() then changed = true end
    if changed then Shade.Places.Refresh() end
    if changed and lastGrade then S.ApplyGrade(unpack(lastGrade)) end
    if changed and S.RefreshFound then S.RefreshFound() end   -- (les icônes : Map/PinSets.lua)
end

-- /mmir carte status : les morceaux explorables d'une zone, explorés et tous, et ce que le jeu lui-même compte
-- comme exploré là (un écart : des morceaux assombris que le jeu dit trouvés, #357 #360)
function S.ExploredCount(mapID)
    local list = pieces[mapID]
    if not list then return end
    local all, found = 0, 0
    for _, piece in pairs(list) do all = all + 1 if not piece.unexplored then found = found + 1 end end
    local ok, game = pcall(C_MapExplorationInfo.GetExploredMapTextures, mapID)
    return found, all, ok and type(game) == "table" and #game or 0
end

-- Seulement les lieux trouvés (le réglage de la carte, Map/PinSets.lua) : une entrée de donjon, un quai ou une
-- tour de zeppelin montrés une fois exploré le sol de la zone où ils sont (ou un peu autour : un quai est dans l'eau),
-- comme la carte de Blizzard le révèle ; un hors de toute zone, toujours (la demande d'un joueur)
function S.Found(u, v)
    -- dans une ville (le Gouffre de Ragefeu, dans la Faille de l'ombre d'Orgrimmar) : trouvé avec la ville, dont la
    -- propre carte n'a pas de morceaux à explorer (#113)
    for _, c in ipairs(cities) do
        local l, r, t, b = S.Rect(c.mapID)
        if l and u >= l and u <= r and v >= t and v <= b then return not (c.piece and c.piece.unexplored) end
    end
    local chain = S.ChainAt(u, v)
    local zone = chain[#chain]
    if #chain < 3 then return true end
    local l, r, t, b = S.Rect(zone)
    if not l then return true end
    local x, y = (u - l) / (r - l), (v - t) / (b - t)
    local at = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredAreaIDsAtPosition
    if not at then return true end
    for _, o in ipairs({ { 0, 0 }, { 0.015, 0 }, { -0.015, 0 }, { 0, 0.015 }, { 0, -0.015 } }) do
        local ok, areas = pcall(at, zone, CreateVector2D(x + o[1], y + o[2]))
        if ok and type(areas) == "table" and #areas > 0 then return true end
    end
    return false
end

