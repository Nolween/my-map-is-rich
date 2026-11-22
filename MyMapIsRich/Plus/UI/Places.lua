-- Le navigateur de lieux (LB sur la carte) : une seule liste, quatre
-- onglets qu'on change à LB / RB.
--   Lieux       le monde, puis un continent, puis une zone (la zone entière,
--               ses donjons et raids, ses maîtres de vol) ; « Ma position »
--               en tête. A ouvre (une zone : la carte y va), B remonte.
--   Rechercher  le clavier virtuel s'ouvre à côté, les résultats se mettent
--               à jour à chaque lettre (accents et majuscules ignorés) : les
--               lieux ci-dessus, et les PNJ et objets de Questie s'il est là.
--   Récents     les derniers lieux choisis.
--   File        les destinations du trajet en plusieurs étapes
--               (Travel/Guide.lua) : la destination en cours, puis la file.
-- Sur un lieu : Y l'itinéraire jusqu'à lui, X l'ajouter à la file. Dans la
-- recherche, A lance l'itinéraire, Y montre le lieu sur la carte. Dans la
-- file : A y aller maintenant, X retirer, LT / RT monter / descendre, Y la
-- remettre dans l'ordre le plus court.
-- Les lieux sont ceux de la recherche d'OpenMap (Nav.lua, Places), lus dans
-- ses tables : les cartes du jeu (C_Map) qu'il sait dessiner (S.Rect), ses
-- entrées de donjon (MapPlaces.instances) et ses maîtres de vol
-- (MapFlights.nodes).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI
local P = ns.Pad
local F = ns.Focus

local PL = {}
ns.Places = PL

local W = 560
local ROWS, ROW_H = 13, 26
local RECENT_MAX = 10
local RESULTS_MAX = 60
local TAB_ORDER = { "places", "search", "recent", "queue" }

local frame, list, tabs, crumb, box, foot
local tab = "places"
local path = {}              -- Lieux : { continent, zone } choisis
local Refill                 -- (remplit la liste de l'onglet en cours)

local function Pl() return ns.TravelPlanner end
local function T() return ns.Travel end

---------------------------------------------------------------------------
-- Les lieux
---------------------------------------------------------------------------
local function ByName(a, b) return (a.text or "") < (b.text or "") end

-- Les cartes du jeu sous `parent`, d'un type, qu'OpenMap sait dessiner
local function Children(parent, kind)
    local S = ns.S
    local out = {}
    local ok, found = pcall(C_Map.GetMapChildrenInfo, parent, kind, true)
    if not ok or type(found) ~= "table" then return out end
    local seen = {}
    for _, info in ipairs(found) do
        if info.mapID and not seen[info.mapID] and S.Rect(info.mapID) then
            seen[info.mapID] = true
            out[#out + 1] = { text = info.name, mapID = info.mapID }
        end
    end
    table.sort(out, ByName)
    return out
end

-- Les donjons et maîtres de vol, rangés par zone (une fois)
local byZone
local function Index()
    if byZone then return byZone end
    byZone = {}
    local S, OM = ns.S, ns.OM
    local function Put(u, v, item)
        if not u then return end
        local ok, chain = pcall(S.ChainAt, u, v)
        if not ok or type(chain) ~= "table" then return end
        for _, id in ipairs(chain) do
            byZone[id] = byZone[id] or {}
            table.insert(byZone[id], item)
        end
    end
    for _, g in ipairs((OM.MapPlaces or {}).instances or {}) do
        local ok, u, v
        if S.EntranceAt then ok, u, v = pcall(S.EntranceAt, g) else ok, u, v = pcall(S.FromYards, g[1], g[2], g[3]) end
        if ok and u and type(g[4]) == "table" then
            for _, inst in ipairs(g[4]) do
                local okN, name = pcall(S.InstanceName, inst)
                if okN and name then
                    Put(u, v, { text = name, kind = inst[3] and L.PLACE_RAID or L.PLACE_DUNGEON, u = u, v = v, order = inst[3] and 2 or 1 })
                end
            end
        end
    end
    for _, node in pairs((OM.MapFlights or {}).nodes or {}) do
        if type(node) == "table" and node[1] then
            local ok, u, v = pcall(S.FromYards, node[2], node[3], node[4])
            if ok and u then Put(u, v, { text = node[1], kind = L.PLACE_FLIGHT, u = u, v = v, order = 3 }) end
        end
    end
    return byZone
end

local function ZoneItems(zone)
    local out = { { text = L.PLACE_WHOLE_ZONE, mapID = zone.mapID, kind = zone.text, name = zone.text } }
    local found = {}
    for _, it in ipairs(Index()[zone.mapID] or {}) do found[#found + 1] = it end
    table.sort(found, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.text < b.text
    end)
    for _, it in ipairs(found) do out[#out + 1] = it end
    return out
end

---------------------------------------------------------------------------
-- Un lieu : où il est, y aller sur la carte, l'itinéraire
---------------------------------------------------------------------------
local function Remember(item)
    local recent = ns.db.recent
    for i = #recent, 1, -1 do
        if recent[i].text == item.text and recent[i].kind == item.kind then table.remove(recent, i) end
    end
    local p = item.point
    table.insert(recent, 1, { text = item.text, kind = item.kind, mapID = item.mapID, u = item.u, v = item.v, name = item.name,
        cont = p and p.cont, x = p and p.x, y = p and p.y })
    while #recent > RECENT_MAX do table.remove(recent) end
end

-- Le point du monde d'un lieu (yards), pour un itinéraire
local function PointOf(item)
    if item.point then return item.point end
    local p
    if item.resolve then
        p = item.resolve()
    elseif item.cont and item.x then
        p = { cont = item.cont, x = item.x, y = item.y }
    elseif item.u then
        p = Pl().PointAtUV(item.u, item.v)
    elseif item.mapID then
        p = Pl().WorldOf(item.mapID, 0.5, 0.5)
    end
    if p then
        p.name = item.name or item.text
        item.point = p
    end
    return p
end

-- La carte glisse jusqu'au lieu
local function ShowOnMap(item)
    local S, mod = ns.S, ns.mod
    -- (la vue part vers ce lieu : elle ne suit plus le personnage, Pad/MapNav.lua)
    if ns.MapNav and ns.MapNav.SetFollow then ns.MapNav.SetFollow(false) end
    local u, v = item.u, item.v
    if not u and item.mapID then
        local l, r, t, b = S.Rect(item.mapID)
        if l and S.GlideToRect then ns.Call(S.GlideToRect, l, t, r, b, 0.95) end
        return
    end
    if not u then
        local p = PointOf(item)
        if p then u, v = Pl().UV(p) end
    end
    if u then
        local ok, _, _, zoom = pcall(mod.ViewNow)
        ns.Call(mod.Glide, u, v, math.max(14, ok and zoom or 1))
    end
end

local function Route(item)
    local p = PointOf(item)
    if not p then
        ns.Print(L.TRAVEL_NO_THERE)
        return
    end
    Remember(item)
    PL.Hide()
    T().Go(T().Copy(p))
end

local function Queue(item)
    local p = PointOf(item)
    if not p then
        ns.Print(L.TRAVEL_NO_THERE)
        return
    end
    Remember(item)
    local goal = T().Copy(p)
    T().Enqueue(goal)
    Refill()
end

---------------------------------------------------------------------------
-- La recherche : les lieux d'OpenMap, et les PNJ et objets de Questie
-- (leur nom traduit par Questie), indexés une fois, par morceaux
---------------------------------------------------------------------------
-- (les lettres accentuées de l'alphabet latin, U+00C0 à U+00FF, sans leur accent)
local PLAIN = { "a", "a", "a", "a", "a", "a", "ae", "c", "e", "e", "e", "e", "i", "i", "i", "i",
    "d", "n", "o", "o", "o", "o", "o", "x", "o", "u", "u", "u", "u", "y", "th", "ss",
    "a", "a", "a", "a", "a", "a", "ae", "c", "e", "e", "e", "e", "i", "i", "i", "i",
    "d", "n", "o", "o", "o", "o", "o", "", "o", "u", "u", "u", "u", "y", "th", "y" }
local ACCENTS = {}
for i, s in ipairs(PLAIN) do ACCENTS["\195" .. string.char(127 + i)] = s end

-- (les accents d'abord, puis les minuscules des seules lettres A à Z :
-- string.lower dépend de la langue de la machine, et pourrait abîmer les
-- octets d'un caractère UTF-8, russe, coréen, chinois)
local function Norm(s)
    s = (s or ""):gsub("\195[\128-\191]", ACCENTS)
    return (s:gsub("[A-Z]", string.lower))
end
PL.Norm = Norm

local entries                -- { { text, norm, kind, order, u, v, mapID, ids, db }, ... }
local building = false
local questieDone = false

local function Questie()
    local loader = _G.QuestieLoader
    if not loader then return end
    local ok, db = pcall(loader.ImportModule, loader, "QuestieDB")
    local ok2, zones = pcall(loader.ImportModule, loader, "ZoneDB")
    if ok and ok2 and db and db.NPCPointers and db.QueryNPCSingle and zones then return db, zones end
end

local function PlacesEntries()
    local out = {}
    local function Add(item, order)
        out[#out + 1] = { text = item.text, norm = Norm(item.text), kind = item.kind, order = order,
            u = item.u, v = item.v, mapID = item.mapID, name = item.text }
    end
    for _, cont in ipairs(Children(ns.S.WORLD, Enum.UIMapType.Continent)) do
        for _, zone in ipairs(Children(cont.mapID, Enum.UIMapType.Zone)) do
            Add({ text = zone.text, kind = L.PLACE_ZONE, mapID = zone.mapID }, 1)
        end
    end
    local seen = {}
    for _, items in pairs(Index()) do
        for _, it in ipairs(items) do
            if not seen[it] then
                seen[it] = true
                Add(it, 1)
            end
        end
    end
    return out
end

-- Les PNJ et objets de Questie : un nom, ses numéros (plusieurs PNJ portent
-- souvent le même nom) ; par morceaux, pour ne rien figer
local CHUNK = 700
local function BuildQuestie(done)
    local QDB = Questie()
    if not QDB then return done() end
    local byName = {}
    local jobs = {}
    for id in pairs(QDB.NPCPointers) do jobs[#jobs + 1] = { id, "npc" } end
    if QDB.ObjectPointers and QDB.QueryObjectSingle then
        for id in pairs(QDB.ObjectPointers) do jobs[#jobs + 1] = { id, "object" } end
    end
    local i = 0
    local function Step()
        for _ = 1, CHUNK do
            i = i + 1
            local job = jobs[i]
            if not job then
                questieDone = true
                return done()
            end
            local id, kind = job[1], job[2]
            local query = kind == "npc" and QDB.QueryNPCSingle or QDB.QueryObjectSingle
            local ok, name = pcall(query, id, "name")
            if ok and type(name) == "string" and name ~= "" then
                local key = kind .. "\1" .. name
                local e = byName[key]
                if not e then
                    e = { text = name, norm = Norm(name), kind = kind == "npc" and L.SEARCH_NPC or L.SEARCH_OBJECT,
                        order = kind == "npc" and 2 or 3, ids = {}, db = kind, name = name }
                    byName[key] = e
                    entries[#entries + 1] = e
                end
                e.ids[#e.ids + 1] = id
            end
        end
        C_Timer.After(0, Step)
    end
    Step()
end

local function EnsureIndex(onReady)
    if entries and (questieDone or not Questie()) then return true end
    if building then return false end
    building = true
    entries = entries or PlacesEntries()
    BuildQuestie(function()
        building = false
        if onReady then onReady() end
    end)
    return questieDone or not Questie()
end

-- Le point d'un PNJ ou d'un objet : son apparition la plus proche du joueur
local function Resolve(e)
    local QDB, ZoneDB = Questie()
    if not QDB then return end
    local G = ns.TravelGraph
    local here = Pl().PlayerPoint()
    local best, bestD
    local query = e.db == "npc" and QDB.QueryNPCSingle or QDB.QueryObjectSingle
    for n, id in ipairs(e.ids) do
        if n > 12 then break end
        local ok, spawns = pcall(query, id, "spawns")
        if ok and type(spawns) == "table" then
            for areaID, coords in pairs(spawns) do
                local okM, uiMapID = pcall(ZoneDB.GetUiMapIdByAreaId, ZoneDB, areaID)
                if okM and uiMapID and type(coords) == "table" then
                    local step = math.max(1, math.floor(#coords / 30))
                    for k = 1, #coords, step do
                        local c = coords[k]
                        if type(c) == "table" and c[1] and c[1] >= 0 then
                            local p = Pl().WorldOf(uiMapID, c[1] / 100, c[2] / 100)
                            if p then
                                local d = 1e9
                                if here and here.cont == p.cont then d = G.Dist(here, p) elseif not here then d = 0 end
                                if not bestD or d < bestD then best, bestD = p, d end
                                if not here then return best end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function Search(text)
    local q = Norm(strtrim(text or ""))
    if q == "" then return {} end
    local found = {}
    local plainQ = q:gsub("%p", "%%%0")
    for _, e in ipairs(entries or {}) do
        local at = e.norm:find(q, 1, true)
        if at then
            local score = at == 1 and 0 or (e.norm:find("[%s%-']" .. plainQ) and 1 or 2)
            found[#found + 1] = { e = e, score = score }
        end
    end
    table.sort(found, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.e.order ~= b.e.order then return a.e.order < b.e.order end
        if #a.e.text ~= #b.e.text then return #a.e.text < #b.e.text end
        return a.e.text < b.e.text
    end)
    local out = {}
    for i = 1, math.min(#found, RESULTS_MAX) do
        local e = found[i].e
        local item = { text = e.text, name = e.name, kind = e.kind, u = e.u, v = e.v, mapID = e.mapID, search = true }
        if e.ids then item.resolve = function() return Resolve(e) end end
        out[i] = item
    end
    return out
end

---------------------------------------------------------------------------
-- La liste (le contrat de Focus : rows, offset, numRows, items, SetOffset)
---------------------------------------------------------------------------
-- Ce qui s'écrit à droite d'une ligne : son genre, et pour un résultat de
-- recherche sa zone et sa distance (calculées quand la ligne s'affiche)
local function RightText(item)
    if item.right then return item.right end
    if not item.search then return item.kind or "" end
    local parts = { item.kind }
    -- (une zone entière : son nom suffit)
    local p = not item.mapID and PointOf(item) or nil
    if p then
        local zone = Pl().ZoneName(p)
        if zone and zone ~= item.text then parts[#parts + 1] = zone end
        local here = Pl().PlayerPoint()
        if here and here.cont == p.cont then
            parts[#parts + 1] = ns.RouteHud.Yards(ns.TravelGraph.Dist(here, p))
        end
    end
    item.right = table.concat(parts, " · ")
    return item.right
end

local function BuildList(parent)
    local inset = UI.Inset(parent)
    local l = CreateFrame("Frame", nil, inset)
    l:SetPoint("TOPLEFT", 4, -4)
    l:SetPoint("BOTTOMRIGHT", -4, 4)
    l.rows, l.items, l.offset, l.numRows = {}, {}, 0, ROWS
    for i = 1, ROWS do
        local row = UI.NavButton(l, ROW_H - 2)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("RIGHT", l, "RIGHT", 0, 0)
        row:SetLevel(2)
        row.count:SetWidth(230)
        row.count:SetWordWrap(false)
        row:SetScript("OnClick", function(self) if self.item and l.onClick then l.onClick(self.item) end end)
        row:SetScript("OnEnter", function(self)
            if self.item and self.item.tip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.item.text, 1, 0.82, 0)
                GameTooltip:AddLine(self.item.tip, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        row:Hide()
        l.rows[i] = row
    end
    l:EnableMouseWheel(true)
    l:SetScript("OnMouseWheel", function(self, delta) self:SetOffset(self.offset - delta * 3) end)
    function l:Refresh()
        for i, row in ipairs(self.rows) do
            local item = self.items[self.offset + i]
            row.item = item
            if item then
                row.text:SetText(item.label or item.text or "")
                row.count:SetText(RightText(item))
                row:SetSelected(item.selected)
                row:Show()
            else
                row:Hide()
            end
        end
    end
    function l:SetOffset(o)
        local maxOff = math.max(0, #self.items - self.numRows)
        self.offset = math.max(0, math.min(math.floor(o), maxOff))
        self:Refresh()
    end
    function l:SetItems(items)
        self.items = items or {}
        self:SetOffset(0)
    end
    l.inset = inset
    return l
end

-- La croix passe sur la ligne `i` (la première par défaut)
local function FocusRow(i)
    C_Timer.After(0.05, function()
        if not (frame and frame:IsShown()) then return end
        i = i or 1
        if i <= list.offset or i > list.offset + list.numRows then list:SetOffset(i - 1) end
        local row = list.rows[i - list.offset]
        if row and row:IsVisible() then F.SetCurrent(row) end
    end)
end

-- L'élément de la ligne choisie à la croix
local function Selected()
    local f = F.Current()
    return f and f.item
end

---------------------------------------------------------------------------
-- Les onglets
---------------------------------------------------------------------------
local function Crumb()
    local parts = { L.PLACES_WORLD }
    for _, it in ipairs(path) do parts[#parts + 1] = it.text end
    return table.concat(parts, "  |cff8a7a55›|r  ")
end

local function FillPlaces()
    crumb:SetText(Crumb())
    local items
    if #path == 0 then
        items = { { text = L.PLACES_FIND_ME, findMe = true, tip = L.PLACES_FIND_ME_TIP, kind = "" } }
        for _, c in ipairs(Children(ns.S.WORLD, Enum.UIMapType.Continent)) do
            c.kind, c.level = L.PLACE_CONTINENT, "continent"
            items[#items + 1] = c
        end
    elseif #path == 1 then
        items = Children(path[1].mapID, Enum.UIMapType.Zone)
        for _, z in ipairs(items) do z.kind, z.level, z.name = L.PLACE_ZONE, "zone", z.text end
    else
        items = ZoneItems(path[2])
    end
    list:SetItems(items)
end

local function FillRecent()
    crumb:SetText(L.PLACES_RECENT_INTRO)
    local items = {}
    for _, r in ipairs(ns.db.recent) do
        items[#items + 1] = { text = r.text, kind = r.kind, mapID = r.mapID, u = r.u, v = r.v, name = r.name,
            cont = r.cont, x = r.x, y = r.y }
    end
    list:SetItems(items)
end

local function FillQueue()
    local items = {}
    local goal = T().Goal()
    if goal then
        items[1] = { label = "|cffffd1001.|r  " .. T().GoalName(goal), text = T().GoalName(goal), right = L.QUEUE_CURRENT,
            current = true, selected = true }
    end
    for i, g in ipairs(T().Queue()) do
        local n = #items + 1
        local zone = T().ZoneOf(g)
        items[n] = { label = ("%d.  %s"):format(n, T().GoalName(g)), text = T().GoalName(g), right = zone or "",
            queued = i }
    end
    local count = #T().Queue()
    crumb:SetText(count == 0 and L.QUEUE_EMPTY or L.QUEUE_INTRO)
    list:SetItems(items)
end

local function FillSearch()
    crumb:SetText("")
    local ready = EnsureIndex(function()
        if frame and frame:IsShown() and tab == "search" then Refill() end
    end)
    local items = Search(box:GetText())
    if #items == 0 then
        local text = strtrim(box:GetText() or "")
        local note = text == "" and L.SEARCH_HINT or (ready and L.SEARCH_NONE or L.SEARCH_BUILDING)
        items = { { text = note, note = true, right = "" } }
    elseif not ready then
        items[#items + 1] = { text = L.SEARCH_BUILDING, note = true, right = "" }
    end
    list:SetItems(items)
end

-- Ce que font A, X, Y, LT / RT dans chaque onglet, et leur aide
local HANDLERS = {
    places = {
        a = function(item)
            if item.findMe then
                local mod = ns.mod
                PL.Hide()
                ns.Call(mod.FindMe, mod)
            elseif item.level == "continent" then
                path = { item }
                FillPlaces()
                FocusRow(1)
            elseif item.level == "zone" then
                path[2] = item
                FillPlaces()
                ShowOnMap({ mapID = item.mapID })
                FocusRow(1)
            else
                Remember(item)
                ShowOnMap(item)
                PL.Hide()
            end
        end,
        y = Route, x = Queue,
        hints = { { "PAD1", "PLACES_OPEN" }, { "PAD4", "PLACES_ROUTE" }, { "PAD3", "PLACES_QUEUE" }, { "PAD2", "HINT_BACK" } },
    },
    search = {
        a = Route, x = Queue,
        y = function(item) ShowOnMap(item) PL.Hide() end,
        hints = { { "PAD1", "PLACES_ROUTE" }, { "PAD3", "PLACES_QUEUE" }, { "PAD4", "PLACES_SHOW" }, { "PAD2", "HINT_CLOSE" } },
    },
    recent = {
        a = function(item) ShowOnMap(item) PL.Hide() end,
        y = Route, x = Queue,
        hints = { { "PAD1", "PLACES_SHOW" }, { "PAD4", "PLACES_ROUTE" }, { "PAD3", "PLACES_QUEUE" }, { "PAD2", "HINT_CLOSE" } },
    },
    queue = {
        a = function(item)
            if item.queued then
                T().GoQueued(item.queued)
                FillQueue()
                FocusRow(1)
            end
        end,
        x = function(item)
            if item.current then T().Skip() elseif item.queued then T().Unqueue(item.queued) end
            FillQueue()
            FocusRow(1)
        end,
        y = function()
            T().Optimize()
            FillQueue()
        end,
        move = function(item, dir)
            if not item.queued then return end
            local j = T().MoveQueued(item.queued, dir)
            FillQueue()
            FocusRow(j + (T().Goal() and 1 or 0))
        end,
        hints = { { "PAD1", "QUEUE_GO" }, { "PAD3", "QUEUE_REMOVE" }, { "PADLTRIGGER", "QUEUE_MOVE" }, { "PAD4", "QUEUE_SORT" }, { "PAD2", "HINT_CLOSE" } },
    },
}

local function Handle(key, ...)
    local item = Selected()
    local h = HANDLERS[tab]
    if not (item and h and h[key]) or item.note then return end
    local ok, err = pcall(h[key], item, ...)
    if not ok and geterrorhandler then geterrorhandler()(err) end
end

local function DrawFoot()
    local h = HANDLERS[tab]
    for i, g in ipairs(foot.items) do
        local hint = h.hints[i]
        if hint then
            g.glyph:SetKey(hint[1])
            g.text:SetText(L[hint[2]])
            g:SetWidth(22 + g.text:GetStringWidth())
            g:Show()
        else
            g:Hide()
        end
    end
end

local function Place()
    frame:ClearAllPoints()
    if tab == "search" then
        -- (le clavier à gauche, les résultats à droite)
        frame:SetPoint("TOPLEFT", UIParent, "TOP", 4, -60)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
end

Refill = function()
    if not frame then return end
    for key, t in pairs(tabs) do
        t.text:SetFontObject(key == tab and "GameFontNormalLarge" or "GameFontDisable")
        t.line:SetShown(key == tab)
        t:SetWidth(t.text:GetStringWidth() + 8)
    end
    local count = #T().Queue() + (T().Goal() and 1 or 0)
    tabs.queue.text:SetText(count > 0 and L.PLACES_TAB_QUEUE_N:format(count) or L.PLACES_TAB_QUEUE)
    tabs.queue:SetWidth(tabs.queue.text:GetStringWidth() + 8)
    box:SetShown(tab == "search")
    crumb:SetShown(tab ~= "search")
    if tab == "places" then FillPlaces()
    elseif tab == "search" then FillSearch()
    elseif tab == "recent" then FillRecent()
    else FillQueue() end
    DrawFoot()
end

local function OpenKeyboard()
    -- (à la souris, sur la carte plein écran : le vrai clavier, le champ prend la main)
    if not ns.PadUI() then
        box:SetFocus()
        return
    end
    if ns.Keyboard then ns.Keyboard.Open(box) end
end

local function SetTab(key)
    if ns.Keyboard and ns.Keyboard.Shown() then ns.Keyboard.Close() end
    tab = key
    Place()
    Refill()
    if key == "search" then
        C_Timer.After(0.05, OpenKeyboard)
    else
        FocusRow(1)
    end
end

local function CycleTab(dir)
    local at = 1
    for i, k in ipairs(TAB_ORDER) do if k == tab then at = i end end
    SetTab(TAB_ORDER[(at - 1 + dir) % #TAB_ORDER + 1])
end

-- B : dans Lieux, remonter d'un niveau ; sinon fermer
local function Back()
    if tab == "places" and #path > 0 then
        table.remove(path)
        FillPlaces()
        FocusRow(1)
        return
    end
    PL.Hide()
end

---------------------------------------------------------------------------
-- La fenêtre
---------------------------------------------------------------------------
local function Tab(parent, key, label, prev)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(24)
    b.noGamepad = true   -- (LB / RB : la croix ne s'y arrête pas)
    b.text = UI.Text(b, "GameFontDisable", label)
    b.text:SetPoint("CENTER", 0, 1)
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", 0, 0)
    b.line:SetPoint("BOTTOMRIGHT", 0, 0)
    b.line:SetColorTexture(1, 0.82, 0, 1)
    b:SetScript("OnClick", function() SetTab(key) end)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 14, 0) end
    return b
end

local function Build()
    if frame then return end
    local h = 32 + 4 + 34 + ROWS * ROW_H + 8 + 40
    frame = UI.MapWindow("MyMapIsRichPlusPlaces", W, h, L.PLACES_TITLE)
    local c = frame.content
    -- (les onglets, dans la barre de titre, entre les pastilles LB et RB)
    local lb = UI.CreateGlyph(frame, 18)
    lb:SetKey("PADLSHOULDER")
    lb:SetPoint("LEFT", frame.title, "RIGHT", 16, 0)
    tabs = {}
    local labels = { places = L.PLACES_TAB_PLACES, search = L.PLACES_TAB_SEARCH, recent = L.PLACES_TAB_RECENT, queue = L.PLACES_TAB_QUEUE }
    local prev
    for _, key in ipairs(TAB_ORDER) do
        local t = Tab(frame, key, labels[key], prev)
        if not prev then t:SetPoint("LEFT", lb, "RIGHT", 10, 0) end
        tabs[key] = t
        prev = t
    end
    local rb = UI.CreateGlyph(frame, 18)
    rb:SetKey("PADRSHOULDER")
    rb:SetPoint("LEFT", prev, "RIGHT", 10, 0)

    -- (le fil d'Ariane, ou le champ de recherche)
    crumb = UI.DimText(c, "", "GameFontHighlight")
    crumb:SetPoint("TOPLEFT", 6, -8)
    crumb:SetPoint("RIGHT", c, "RIGHT", -6, 0)
    crumb:SetJustifyH("LEFT")
    crumb:SetWordWrap(false)
    box = CreateFrame("EditBox", nil, c)
    box:SetPoint("TOPLEFT", 8, -4)
    box:SetPoint("RIGHT", c, "RIGHT", -4, 0)
    box:SetHeight(24)
    box:SetFontObject("GameFontHighlight")
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    box:SetTextInsets(4, 4, 0, 0)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    UI.SkinInput(box)
    -- (le clavier à gauche de la fenêtre)
    box.keyboardPlace = function(kb) kb:SetPoint("TOPRIGHT", UIParent, "TOP", -4, -60) end
    local pending = false
    box:SetScript("OnTextChanged", function()
        if pending then return end
        pending = true
        C_Timer.After(0.12, function()
            pending = false
            if frame:IsShown() and tab == "search" then FillSearch() end
        end)
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        FocusRow(1)
    end)
    box:Hide()

    list = BuildList(c)
    list.inset:SetPoint("TOPLEFT", 0, -34)
    list.inset:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    list.inset:SetHeight(ROWS * ROW_H + 8)
    list.onClick = function(item)
        local hd = HANDLERS[tab]
        if hd and hd.a and not item.note then hd.a(item) end
    end

    -- (en bas : les boutons de l'onglet)
    foot = CreateFrame("Frame", nil, c)
    foot:SetPoint("BOTTOMLEFT", 4, 4)
    foot:SetPoint("BOTTOMRIGHT", -4, 4)
    foot:SetHeight(26)
    foot.items = {}
    local last
    for i = 1, 5 do
        local g = CreateFrame("Frame", nil, foot)
        g:SetHeight(20)
        g.glyph = UI.CreateGlyph(g, 18)
        g.glyph:SetPoint("LEFT", 0, 0)
        g.text = UI.Text(g, "GameFontHighlightSmall")
        g.text:SetPoint("LEFT", g.glyph, "RIGHT", 4, 0)
        if last then g:SetPoint("LEFT", last, "RIGHT", 16, 0) else g:SetPoint("LEFT", foot, "LEFT", 4, 0) end
        foot.items[i] = g
        last = g
    end

    F.RegisterWindow(frame, { onBack = Back, onTab = CycleTab, first = function() return list.rows[1] end })
end

function PL.Show(which)
    if not (ns.Ready() and ns.S and ns.S.Rect) then return end
    Build()
    -- (le navigateur s'ouvre sur Lieux, là où on en était)
    tab = which or "places"
    Place()
    frame:Show()
    Refill()
    if tab == "search" then C_Timer.After(0.05, OpenKeyboard) end
    P.Dirty()
end

function PL.Hide()
    if ns.Keyboard and ns.Keyboard.Shown() then ns.Keyboard.Close() end
    if frame then frame:Hide() end
    P.Dirty()
end

function PL.Shown() return frame and frame:IsShown() or false end

function PL.Toggle()
    if PL.Shown() then PL.Hide() else PL.Show() end
end

-- Le contexte du navigateur : celui des fenêtres (la croix, A sur une
-- ligne, LB / RB les onglets), plus Y, X, LT / RT selon l'onglet
local function Label(key)
    return function()
        for _, hint in ipairs(HANDLERS[tab].hints) do
            if hint[1] == key then return hint[2] end
        end
    end
end

P.DefineContext("places", 52, function() return PL.Shown() and F.Top() == frame end, "window")
P.SetAction("places", "PAD4", function() Handle("y") end, Label("PAD4"))
P.SetAction("places", "PAD3", function() Handle("x") end, Label("PAD3"))
P.SetAction("places", "PAD2", Back, function() return tab == "places" and #path > 0 and "HINT_BACK" or "HINT_CLOSE" end)
P.SetAction("places", "PADLTRIGGER", function() Handle("move", -1) end)
P.SetAction("places", "PADRTRIGGER", function() Handle("move", 1) end, function() return tab == "queue" and "QUEUE_MOVE" or nil end)
F.WINDOW_CONTEXTS.places = true

-- (la file change pendant que l'onglet File est ouvert : la liste suit)
ns.On("TRAVEL", function()
    if frame and frame:IsShown() and tab == "queue" then FillQueue() end
end)
ns.On("MAP_HIDE", PL.Hide)
