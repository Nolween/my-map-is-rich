-- Les marqueurs de quêtes, tirés de la base des quêtes de My Map Is Rich
-- (Quests/Db.lua) : là où le jeu ne montre que la zone d'un objectif, ils
-- disent qui tuer, quoi ramasser et sur qui, quoi utiliser, où rendre une
-- quête finie et où en prendre de nouvelles. Trois jeux d'icônes :
--   - « qm_goal » (réglage questGoals) : les objectifs en cours de ton
--     journal, une icône par endroit où se trouve le monstre, l'objet du
--     monde, celui qui lâche ou vend l'objet à trouver, ou le lieu à
--     explorer ; un objectif rempli n'en a plus ;
--   - « qm_end » (questEnds) : un « ? » doré là où se rend une quête finie ;
--   - « qm_offer » (questOffers) : un « ! » sur les donneurs des quêtes que tu
--     peux prendre (Quests/Offers.lua) ; les grises avec questOffersGrey.
-- Une icône par PNJ ou objet et par endroit : son info-bulle dit toutes les
-- quêtes qui y mènent. Un PNJ dans un donjon a son icône à l'entrée.
-- Un clic (A à la manette) : la quête est suivie et la vue zoome dessus.
-- Les trois jeux suivent le calque Quêtes du rail (« questIcons ») ; ils se
-- posent quelques centaines par image, la carte ouverte seulement.
-- Les détails du calque :
--   - les camps (questCamps) : les apparitions proches d'un même PNJ ou objet
--     (à CAMP yards l'une de l'autre) font une seule icône, à leur milieu, et
--     son info-bulle dit combien il y en a ;
--   - les quêtes suivies seulement (questTracked) : les objectifs et les « ? »
--     des quêtes suivies (et de celle choisie dans la liste) ;
--   - les autres estompées (questSpotlight) : une quête choisie dans la liste
--     des quêtes (sa fiche ouverte, ou la manette dans la liste : UI/QuestPanel.lua,
--     « QUEST_SPOTLIGHT »), les icônes qui ne la concernent pas pâlissent.
--   - les zones de chasse (questAreas) : l'enveloppe des camps d'un objectif ;
--   - les quêtes bientôt prêtes (questOffersSoon) : un « ! » violet et pâle,
--     son info-bulle dit ce qui manque (Quests/Offers.lua : Offers.Soon).
-- Les « ! » disent aussi ce qu'une quête a de particulier (QM.Tags : de
-- classe, de donjon, répétable, sa place dans une chaîne ; les répétables
-- seules : un « ! » bleu), et s'ajoutent ceux des quêtes apprises en jouant,
-- sans ceux qu'un PNJ a démentis (Quests/Learn.lua).
-- Une icône peut être cachée depuis sa fiche (UI/PointCard.lua) : ses quêtes
-- n'ont plus d'icône pour ce personnage (Quests/Offers.lua : Offers.Hide), et
-- l'onglet Carte de /mmir les rend.
-- La minimap (Layers/QuestMinimap.lua), les info-bulles et les barres de nom
-- (Layers/QuestUnits.lua) lisent les mêmes marqueurs : QM.Entries, QM.Spots.

local _, root = ...
local ns = root.Plus
local L = ns.L

local K = ns.Map.Coords
local Pins = ns.Map.Pins
local V = ns.Map.View
local Settings = ns.Map.Settings
local Db = ns.Quests.Db
local Log = ns.Quests.Log
local Offers = ns.Quests.Offers

local QM = {}
ns.Quests.Marks = QM

Settings.Own("questGoals", true)
Settings.Own("questEnds", true)
Settings.Own("questOffers", true)
Settings.Own("questOffersGrey", false)
Settings.Own("questCamps", true)
Settings.Own("questTracked", false)
Settings.Own("questSpotlight", true)
Settings.Own("questOffersSoon", false)
Settings.Own("questAreas", true)

-- les allures, par sorte d'objectif (des curseurs du jeu : sur tous les clients)
local LOOKS = {
    kill = { texture = "Interface\\Cursor\\Attack", fallback = "Interface\\Minimap\\ObjectIcons", size = 16 },
    loot = { texture = "Interface\\Cursor\\Pickup", fallback = "Interface\\Minimap\\ObjectIcons", size = 16 },
    use = { texture = "Interface\\Cursor\\Interact", fallback = "Interface\\Minimap\\ObjectIcons", size = 16 },
    buy = { texture = "Interface\\Cursor\\Buy", fallback = "Interface\\GossipFrame\\VendorGossipIcon", size = 16 },
    explore = { texture = "Interface\\Cursor\\Inspect", fallback = "Interface\\Minimap\\ObjectIcons", size = 18 },
    finish = { atlas = "QuestTurnin", texture = "Interface\\GossipFrame\\ActiveQuestIcon", size = 18 },
    offer = { atlas = "QuestNormal", texture = "Interface\\GossipFrame\\AvailableQuestIcon", size = 18 },
    daily = { atlas = "QuestDaily", texture = "Interface\\GossipFrame\\DailyQuestIcon", fallback = "Interface\\GossipFrame\\AvailableQuestIcon", size = 18 },
    soon = { atlas = "QuestNormal", texture = "Interface\\GossipFrame\\AvailableQuestIcon", size = 15, color = { 0.78, 0.55, 1, 0.8 } },
}
local ORDER = { kill = 1, use = 2, loot = 3, buy = 4, explore = 5 }      -- (l'icône d'un PNJ qui sert à plusieurs objectifs)
local MANY = 20                 -- au-delà de ce nombre d'endroits, des icônes plus petites
local SMALL = 0.75
local PER_FRAME = 250           -- icônes posées par image
local ZOOM_TO = 6
local CAMP = 50                 -- yards : deux apparitions plus proches sont du même camp
local FADED = 0.3               -- l'alpha des icônes qui ne concernent pas la quête choisie

local sets = {}                 -- "goal" | "end" | "offer" -> jeu d'icônes
local building = 0              -- (la construction en cours : une nouvelle annule l'ancienne)
local dirty = true
local spot                      -- la quête choisie dans la liste des quêtes (QUEST_SPOTLIGHT), ou nil

local function On() return Db.Has() and Settings.Get("questIcons") ~= false end
function QM.OffersOn() return On() and Settings.Get("questOffers") ~= false end

---------------------------------------------------------------------------
-- Les titres et les info-bulles
---------------------------------------------------------------------------
local function Title(id)
    local q = Log.Quests()[id]
    local title = q and q.title
    if not title and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, t = pcall(C_QuestLog.GetTitleForQuestID, id)
        if ok and type(t) == "string" and t ~= "" then title = t end
    end
    local base = Db.Quest(id)
    title = title or (base and base.title) or (ns.Quests.Learn and ns.Quests.Learn.Title(id)) or ("#" .. id)
    local level = (q and q.level) or (base and base.level)
    if level and level > 0 then title = "[" .. level .. "] " .. title end
    return title, level
end

local function Colour(level)
    local get = _G.GetQuestDifficultyColor
    if level and level > 0 and get then
        local ok, c = pcall(get, level)
        if ok and type(c) == "table" and c.r then return c.r, c.g, c.b end
    end
    return 1, 1, 1
end

-- (le rang d'un PNJ : élite et chef, les mots du jeu ; rare, ceux des citadins)
local function Rank(r)
    if r == 2 then return L.TOWNSFOLK_RARE_ELITE end
    if r == 4 then return L.TOWNSFOLK_RARE end
    if r == 1 then return _G.ELITE end
    if r == 3 then return _G.BOSS end
end

local function Enter(pin)
    local e = pin.data
    if not e then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    -- (un lieu à explorer n'a pas de PNJ : e.ref est « x<quête> »)
    local ref = type(e.ref) == "number" and e.ref or e.name
    GameTooltip:SetText(e.label or (ref and Db.Name(ref)) or L.QUESTMARK_EXPLORE, 1, 0.82, 0)
    local npc = ref and ref > 0 and Db.Npc(ref)
    if npc and npc.minLevel and npc.minLevel > 0 then
        local lv = npc.minLevel == npc.maxLevel and tostring(npc.minLevel) or (npc.minLevel .. "-" .. (npc.maxLevel or npc.minLevel))
        local rank = Rank(npc.rank)
        GameTooltip:AddLine((LEVEL or "") .. " " .. lv .. (rank and ("  " .. rank) or ""), 0.8, 0.8, 0.8)
    end
    if pin.inside then GameTooltip:AddLine(L.QUESTMARK_DUNGEON, 0.6, 0.6, 0.6) end
    if pin.camp then GameTooltip:AddLine(L.QUESTMARK_CAMP:format(pin.camp), 0.6, 0.6, 0.6) end
    if e.what == "end" then GameTooltip:AddLine(L.QUESTMARK_TURN_IN, 0.5, 0.95, 0.4)
    elseif e.soon then GameTooltip:AddLine(L.QUESTMARK_SOON, 0.78, 0.55, 1)
    elseif e.what == "offer" then GameTooltip:AddLine(L.QUESTMARK_OFFERS, 1, 1, 1) end
    for _, line in ipairs(e.lines) do
        local title, level = Title(line.quest)
        GameTooltip:AddLine(title, Colour(level))
        -- (de classe, de donjon, répétable, sa place dans une chaîne ; apprise en jouant)
        if line.tags then GameTooltip:AddLine("   " .. line.tags, 0.7, 0.7, 0.7) end
        if line.learned then GameTooltip:AddLine("   " .. L.QUESTMARK_LEARNED, 0.6, 0.6, 0.6, true) end
        if line.text then
            local text = (_G.QUEST_DASH or "- ") .. line.text
            if line.vendor then text = text .. "  |cff999999" .. L.QUESTMARK_VENDOR .. "|r" end
            GameTooltip:AddLine(text, 1, 1, 1, true)
        end
    end
    if not pin.noClick then
        GameTooltip:AddLine(e.what == "offer" and L.QUESTMARK_ZOOM or L.QUESTS_CLICK, 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end
-- (la même info-bulle pour une icône de la minimap : Layers/QuestMinimap.lua ;
-- son cadre porte data, inside, camp et noClick)
QM.Enter = Enter
QM.Title = function(id) return (Title(id)) end
QM.Colour = Colour

-- Un clic : la quête suivie (celle de l'objectif ou à rendre), et la vue dessus
local function Click(pin)
    local e = pin.data
    if not e then return end
    local first = e.lines[1] and e.lines[1].quest
    if first and e.what ~= "offer" and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        if C_QuestLog.AddQuestWatch and not (C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(first)) then
            pcall(C_QuestLog.AddQuestWatch, first)
        end
        pcall(C_SuperTrack.SetSuperTrackedQuestID, first)
    end
    local _, _, zoom = V.Now()
    V.Glide(pin.u, pin.v, math.max(zoom or 1, ZOOM_TO))
end

---------------------------------------------------------------------------
-- Ce qu'il faut marquer : un par PNJ ou objet du monde, avec ses quêtes
---------------------------------------------------------------------------
-- (into : { byRef = { ref -> e }, list = { e, ... } })
local function Entry(into, what, ref, kind)
    local e = into.byRef[ref]
    if not e then
        e = { ref = ref, what = what, kind = kind, lines = {} }
        into.byRef[ref] = e
        into.list[#into.list + 1] = e
    elseif kind and ORDER[kind] and (not e.kind or ORDER[kind] < ORDER[e.kind]) then
        e.kind = kind
    end
    return e
end

-- Ce qu'une quête à prendre a de particulier, pour son info-bulle : de ta
-- classe (sa couleur), de donjon, répétable, sa place dans une chaîne
function QM.Tags(id)
    local q = Db.Quest(id)
    if not q then return end
    local tags = {}
    if q.classes and q.classes ~= 0 then
        local _, class = UnitClass("player")
        local name = _G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[class]
        local c = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
        if name then tags[#tags + 1] = c and c.colorStr and ("|c%s%s|r"):format(c.colorStr, name) or name end
    end
    if Db.IsDungeonQuest(id) then tags[#tags + 1] = L.QUESTMARK_TAG_DUNGEON end
    if q.repeatable then tags[#tags + 1] = L.QUESTMARK_TAG_REPEAT end
    local step, total = Db.ChainPlace(id)
    if total > 1 then tags[#tags + 1] = L.QUESTMARK_TAG_CHAIN:format(step, total) end
    return #tags > 0 and table.concat(tags, " · ") or nil
end

-- (une quête suivie : la liste de suivi du jeu)
local function Watched(id, q)
    if C_QuestLog and C_QuestLog.IsQuestWatched then
        local ok, yes = pcall(C_QuestLog.IsQuestWatched, id)
        if ok then return yes and true or false end
    end
    local watched = _G.IsQuestWatched
    if watched and q.index then
        local ok, yes = pcall(watched, q.index)
        return ok and yes and true or false
    end
    return true
end

-- Une quête du journal qui a ses icônes : pas cachée par le joueur, et suivie
-- si seules les suivies en ont (celle choisie dans la liste en a toujours)
local function Marked(id, q)
    if Offers.Hidden(id) then return false end
    if Settings.Get("questTracked") ~= true or id == spot then return true end
    return Watched(id, q)
end

local function Goals(out)
    for id, q in pairs(Log.Quests()) do
        if not q.complete and Marked(id, q) then
            for _, o in ipairs(Log.Goals(id)) do
                if not o.finished then
                    for _, ref in ipairs(o.refs or {}) do
                        local kind = ref < 0 and "use" or "kill"
                        local e = Entry(out, "goal", ref, kind)
                        e.lines[#e.lines + 1] = { quest = id, text = o.text }
                    end
                    if o.item then
                        for _, s in ipairs(Db.Sources(o.item)) do
                            local e = Entry(out, "goal", s[1], s.vendor and "buy" or "loot")
                            e.lines[#e.lines + 1] = { quest = id, text = o.text, vendor = s.vendor }
                        end
                    end
                    if o.explore then
                        local e = Entry(out, "goal", "x" .. id, "explore")
                        e.spots = Db.Explore(id)
                        e.lines[#e.lines + 1] = { quest = id, text = o.text }
                    end
                end
            end
        end
    end
end

local function Ends(out)
    for id, q in pairs(Log.Quests()) do
        local base = q.complete and Marked(id, q) and Db.Quest(id)
        for _, ref in ipairs(base and base.ends or {}) do
            local e = Entry(out, "end", ref, "finish")
            e.lines[#e.lines + 1] = { quest = id }
        end
    end
end

local function OffersOf(out)
    local grey = Settings.Get("questOffersGrey") == true
    local side = UnitFactionGroup("player") == "Horde" and 2 or 1
    local Learn = ns.Quests.Learn
    for _, o in ipairs(Offers.List()) do
        if (grey or not o.trivial) and not Offers.Hidden(o.id) then
            local base = Db.Quest(o.id)
            for _, ref in ipairs(base and base.starts or {}) do
                -- (pas chez un PNJ qui a démenti cette quête : Quests/Learn.lua)
                if bit.band(Db.React(ref), side) ~= 0 and not (Learn and Learn.NotOffered(o.id, ref)) then
                    local e = Entry(out, "offer", ref, "offer")
                    e.lines[#e.lines + 1] = { quest = o.id, tags = QM.Tags(o.id) }
                    e.trivial = (e.trivial ~= false) and o.trivial
                    -- (seulement des quêtes répétables : le « ! » bleu)
                    e.daily = (e.daily ~= false) and base.repeatable or false
                end
            end
        end
    end
    -- (les quêtes apprises en jouant, absentes de la base : leur donneur, là où on l'a vu)
    for _, o in ipairs(Learn and Learn.Offers() or {}) do
        if not Offers.Hidden(o.id) then
            local e = Entry(out, "offer", o.ref, "offer")
            e.spots = e.spots or o.spots
            e.label = e.label or (not Db.Name(o.ref) and o.name) or nil

            e.lines[#e.lines + 1] = { quest = o.id, learned = true }
            e.daily = false
        end
    end
    -- (les quêtes bientôt prêtes, à part : un « ! » violet, pâle ; Quests/Offers.lua)
    if Settings.Get("questOffersSoon") == true then
        for _, o in ipairs(Offers.Soon()) do
            local base = not Offers.Hidden(o.id) and Db.Quest(o.id)
            for _, ref in ipairs(base and base.starts or {}) do
                if bit.band(Db.React(ref), side) ~= 0 then
                    local e = Entry(out, "offer", "s" .. ref, "soon")
                    e.spots = e.spots or Db.Places(ref)
                    e.soon, e.name = true, ref
                    e.lines[#e.lines + 1] = { quest = o.id, text = Offers.Why(o.id) }
                end
            end
        end
    end
    for _, e in ipairs(out.list) do
        if e.daily then e.kind = "daily" end
    end
end

---------------------------------------------------------------------------
-- La pose des icônes, quelques centaines par image
---------------------------------------------------------------------------
-- Un yard en unités du monde, sur chaque axe (le continent 0 : les deux sont
-- à la même échelle sur la carte du monde, assez pour faire des camps)
local yardU, yardV
local function Yard()
    if yardU then return yardU, yardV end
    local u0, v0 = K.FromYards(0, 0, 0)
    local u1, v1 = K.FromYards(0, 100, 0)
    local u2, v2 = K.FromYards(0, 0, 100)
    if not (u0 and u1 and u2) then return end
    -- (les axes du jeu peuvent être croisés avec ceux de la carte : le plus grand des deux)
    local du = math.max(math.abs(u1 - u0), math.abs(u2 - u0)) / 100
    local dv = math.max(math.abs(v1 - v0), math.abs(v2 - v0)) / 100
    if du > 0 and dv > 0 then yardU, yardV = du, dv end
    return yardU, yardV
end

-- Les camps : les points à moins de CAMP yards du premier d'un camp le
-- rejoignent ; un camp est posé à leur milieu, avec leur nombre (camp). Les
-- entrées de donjon restent seules. Une grille de cases d'un camp de large :
-- un point ne regarde que les camps des cases voisines.
local function Camps(spots)
    local du, dv = Yard()
    if not du or #spots < 2 then return spots end
    local w, h = CAMP * du, CAMP * dv
    local grid, camps, out = {}, {}, {}
    for _, p in ipairs(spots) do
        if p.inside then
            out[#out + 1] = p
        else
            local i, j = math.floor(p[1] / w), math.floor(p[2] / h)
            local into
            for di = -1, 1 do
                for dj = -1, 1 do
                    for _, c in ipairs(grid[(i + di) * 65536 + (j + dj)] or {}) do
                        local x, y = (p[1] - c.u) / du, (p[2] - c.v) / dv
                        if not into and x * x + y * y <= CAMP * CAMP then into = c end
                    end
                end
            end
            if into then
                into.n, into.su, into.sv = into.n + 1, into.su + p[1], into.sv + p[2]
                into.pts[#into.pts + 1] = p
            else
                into = { u = p[1], v = p[2], n = 1, su = p[1], sv = p[2], pts = { p } }
                camps[#camps + 1] = into
                local key = i * 65536 + j
                grid[key] = grid[key] or {}
                table.insert(grid[key], into)
            end
        end
    end
    for _, c in ipairs(camps) do
        out[#out + 1] = { c.su / c.n, c.sv / c.n, camp = c.n > 1 and c.n or nil, pts = c.pts }
    end
    return out
end

-- L'enveloppe convexe de points du monde (la chaîne monotone d'Andrew) : ses
-- sommets dans l'ordre (une enveloppe ne change pas avec l'échelle des axes)
local function Hull(pts)
    local p = {}
    for i, q in ipairs(pts) do p[i] = q end
    table.sort(p, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
    if #p < 3 then return p end
    local function Cross(o, a, b) return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1]) end
    local lower, upper = {}, {}
    for _, q in ipairs(p) do
        while #lower >= 2 and Cross(lower[#lower - 1], lower[#lower], q) <= 0 do table.remove(lower) end
        lower[#lower + 1] = q
    end
    for i = #p, 1, -1 do
        local q = p[i]
        while #upper >= 2 and Cross(upper[#upper - 1], upper[#upper], q) <= 0 do table.remove(upper) end
        upper[#upper + 1] = q
    end
    table.remove(lower)
    table.remove(upper)
    for _, q in ipairs(upper) do lower[#lower + 1] = q end
    return lower
end


-- Les points d'une icône (en camps si c'est le réglage), sans les entrées de
-- donjon d'un donneur que ton niveau n'atteint pas encore ; et son allure
-- (plus petite quand elle a beaucoup de points)
function QM.Spots(e)
    local spots = e.spots or Db.Places(e.ref)
    if Settings.Get("questCamps") ~= false then spots = Camps(spots) end
    local look = LOOKS[e.kind] or LOOKS.kill
    if #spots > MANY then
        look = { texture = look.texture, atlas = look.atlas, fallback = look.fallback, size = look.size * SMALL, color = look.color }
    end
    local mine = UnitLevel("player") or 1
    local out = {}
    for _, p in ipairs(spots) do
        -- (un donneur dans un donjon : son « ! » à l'entrée, seulement au niveau du donjon)
        if not (e.what == "offer" and p.inside and p.minLevel and mine < p.minLevel) then out[#out + 1] = p end
    end
    return out, look
end

local function Place(set, e, todo)
    local spots, look = QM.Spots(e)
    for _, p in ipairs(spots) do todo[#todo + 1] = { set, p, look, e } end
end

-- (l'icône concerne-t-elle la quête choisie ?)
local function About(e, id)
    for _, line in ipairs(e and e.lines or {}) do
        if line.quest == id then return true end
    end
    return false
end

-- L'alpha d'une icône : pâle si une quête est choisie et que l'icône ne la concerne pas
function QM.Alpha(e)
    local faded = spot and Settings.Get("questSpotlight") ~= false and not About(e, spot)
    return faded and FADED or 1
end

local function Fade(pin) pin.Icon:SetAlpha(QM.Alpha(pin.data)) end

-- Ce qu'il faut marquer, par jeu : { goal = { e, ... }, ["end"] = ..., offer = ... },
-- gardé jusqu'au prochain changement (le journal, un réglage, une quête cachée
-- ou choisie) ; la minimap, les info-bulles et les barres de nom s'en servent
-- aussi (« QUEST_MARKS » quand il change)
local entries
function QM.Entries()
    if entries then return entries end
    entries = { goal = {}, ["end"] = {}, offer = {} }
    if not Db.Has() then return entries end
    for what, fill in pairs({ goal = Goals, ["end"] = Ends, offer = OffersOf }) do
        local out = { byRef = {}, list = {} }
        fill(out)
        entries[what] = out.list
    end
    return entries
end

-- Un jeu montré : le calque Quêtes allumé, et le détail de ce jeu
function QM.Want(what)
    if not On() then return false end
    if what == "goal" then return Settings.Get("questGoals") ~= false end
    if what == "end" then return Settings.Get("questEnds") ~= false end
    return Settings.Get("questOffers") ~= false
end

local function Build(token, todo, at)
    if token ~= building then return end
    local stop = math.min(at + PER_FRAME - 1, #todo)
    for i = at, stop do
        local t = todo[i]
        local pin = Pins.Add(t[1], t[2][1], t[2][2], t[3], t[4])
        if pin then
            pin.inside = t[2].inside
            pin.camp = t[2].camp
            if t[4].trivial or t[4].soon then pin.Icon:SetDesaturated(true) end

            Fade(pin)
            pin:SetScript("OnEnter", Enter)
            pin:SetScript("OnLeave", GameTooltip_Hide)
            pin.OnClick = Click
        end
    end
    if stop < #todo then C_Timer.After(0, function() Build(token, todo, stop + 1) end) end
end

-- Les zones de chasse (réglage questAreas) : autour de chaque camp d'au moins
-- trois apparitions d'un objectif en cours, son enveloppe, à la couleur de sa
-- sorte ; la quête choisie seulement, s'il y en a une
local areaSet
local AREA_COLORS = { kill = { 1, 0.35, 0.3 }, loot = { 1, 0.82, 0.2 }, use = { 0.45, 0.8, 1 }, buy = { 0.6, 1, 0.5 } }
local AREA_MIN = 3

local function DrawAreas()
    if not areaSet then
        if not Pins.Ready() then return end
        areaSet = Pins.Set("qm_area", 3, 2)
        if not areaSet then return end
    end
    Pins.Clear(areaSet)
    local on = On() and QM.Want("goal") and Settings.Get("questAreas") ~= false
    Pins.SetOn(areaSet, on)
    if not on then return end
    for _, e in ipairs(QM.Entries().goal or {}) do
        local color = AREA_COLORS[e.kind]
        if color and (not spot or About(e, spot)) then
            for _, c in ipairs(Camps(e.spots or Db.Places(e.ref))) do
                if c.pts and #c.pts >= AREA_MIN then
                    local h = Hull(c.pts)
                    if #h >= 3 then
                        local path = {}
                        for _, q in ipairs(h) do
                            path[#path + 1] = q[1]
                            path[#path + 1] = q[2]
                        end
                        path[#path + 1], path[#path + 1] = h[1][1], h[1][2]
                        Pins.Path(areaSet, path, 2, color[1], color[2], color[3], 0.55)
                    end
                end
            end
        end
    end
end

local function Sets()
    if sets.goal or not Pins.Ready() then return sets.goal ~= nil end
    sets.goal = Pins.Set("qm_goal", 2, 4)
    sets.offer = Pins.Set("qm_offer", 3, 4)     -- (sous les icônes des quêtes du jeu)
    sets["end"] = Pins.Set("qm_end", 1, 6)      -- (au-dessus)
    return sets.goal ~= nil
end

function QM.Refresh()
    if not Sets() then return end
    building = building + 1
    dirty = false
    for _, set in pairs(sets) do Pins.Clear(set) end
    for what, set in pairs(sets) do Pins.SetOn(set, QM.Want(what)) end
    if not On() then
        DrawAreas()
        return
    end
    local todo = {}
    local all = QM.Entries()
    for _, what in ipairs({ "goal", "end", "offer" }) do
        if QM.Want(what) then
            for _, e in ipairs(all[what]) do Place(sets[what], e, todo) end
        end
    end
    Build(building, todo, 1)
    DrawAreas()
end

-- Ce qu'il faut marquer a changé : à refaire, la carte (ouverte) aussi
local function Changed()
    entries = nil
    if ns.Map.IsBuilt() and ns.MapShown() then QM.Refresh() else dirty = true end
    ns.Fire("QUEST_MARKS")
end

ns.On("MAP_BUILT", function() QM.Refresh() end)
ns.On("MAP_SHOW", function() if dirty and ns.Map.IsBuilt() then QM.Refresh() end end)
-- (un réglage changé : les quêtes suivies, les grises, les camps...)
ns.On("MAP_REFRESH", function()
    entries = nil
    if ns.Map.IsBuilt() then QM.Refresh() end
    ns.Fire("QUEST_MARKS")
end)
ns.On("QUESTS_CHANGED", Changed)
ns.On("QUESTS_HIDDEN", Changed)
ns.On("QUESTS_LEARNED", Changed)

-- La quête choisie dans la liste des quêtes (nil : aucune) : les autres
-- icônes pâlissent ; seules les suivies : celle-ci a aussi les siennes
ns.On("QUEST_SPOTLIGHT", function(id)
    if id == spot then return end
    spot = id
    if Settings.Get("questTracked") == true then
        Changed()
        return
    end
    for _, set in pairs(sets) do
        for _, pin in ipairs(set.pins) do Fade(pin) end
    end
    if ns.Map.IsBuilt() then DrawAreas() end
    ns.Fire("QUEST_MARKS", true)
end)

-- (la liste de suivi du jeu change : les icônes des quêtes suivies suivent)
local watch = CreateFrame("Frame")
local watchWaiting = false
watch:SetScript("OnEvent", function()
    if Settings.Get("questTracked") ~= true or watchWaiting then return end
    watchWaiting = true
    C_Timer.After(0.3, function()
        watchWaiting = false
        Changed()
    end)
end)
pcall(watch.RegisterEvent, watch, "QUEST_WATCH_LIST_CHANGED")

---------------------------------------------------------------------------
-- Cacher une icône (la fiche d'un point : UI/PointCard.lua) : ses quêtes,
-- pour ce personnage
---------------------------------------------------------------------------
local function QuestsOf(pin)
    local e = pin and pin.data
    if type(e) ~= "table" or not e.lines then return end
    for _, set in pairs(sets) do
        if pin:GetParent() and pin:GetParent():GetParent() == set.frame then
            local ids, seen = {}, {}
            for _, line in ipairs(e.lines) do
                if line.quest and not seen[line.quest] then
                    seen[line.quest] = true
                    ids[#ids + 1] = line.quest
                end
            end
            return ids
        end
    end
end

function QM.CanHide(pin) return QuestsOf(pin) ~= nil end

function QM.Hide(pin)
    local ids = QuestsOf(pin)
    if not ids or #ids == 0 then return end
    local titles = {}
    for i, id in ipairs(ids) do
        if i > 3 then
            titles[#titles + 1] = "..."
            break
        end
        titles[#titles + 1] = (Title(id))
    end
    Offers.Hide(ids)
    ns.Print(L.QUESTMARK_HIDDEN:format(table.concat(titles, ", ")))
end

---------------------------------------------------------------------------
-- /mmir sonde quetes : tes quêtes du journal dans la base, et où tu es (en
-- yards, pour tools/quests/forever_fixes.json)
---------------------------------------------------------------------------
function QM.Probe()
    if not Db.Has() then
        ns.Print(L.PROBE_QUESTS_NO_BASE)
        return
    end
    ns.Print(L.PROBE_QUESTS_HEAD:format(Db.Build() or "?"))
    local n = 0
    for id, q in pairs(Log.Quests()) do
        n = n + 1
        local base = Db.Quest(id)
        if not base then
            ns.Print(L.PROBE_QUESTS_MISSING:format(id, q.title or "?"))
        else
            local found, total, spots = 0, 0, 0
            for _, o in ipairs(Log.Goals(id)) do
                total = total + 1
                local refs = {}
                for _, ref in ipairs(o.refs or {}) do refs[#refs + 1] = ref end
                for _, s in ipairs(o.item and Db.Sources(o.item) or {}) do refs[#refs + 1] = s[1] end
                if #refs > 0 or o.explore then found = found + 1 end
                for _, ref in ipairs(refs) do spots = spots + #Db.Places(ref) end
                if o.explore then spots = spots + #Db.Explore(id) end
            end
            ns.Print(L.PROBE_QUESTS_LINE:format(id, q.title or base.title, found, total, spots))
        end
    end
    if n == 0 then ns.Print(L.PROBE_QUESTS_NONE) end
    -- (où tu es, comme forever_fixes.json l'attend : la carte du jeu et x, y en %)
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y
    if pos then x, y = pos:GetXY() end
    if x then ns.Print(L.PROBE_QUESTS_HERE:format(mapID, x * 100, y * 100)) end
end
