-- Les maîtres de vol sur la carte : ns.Map.Flights, en code de My Map Is Rich
-- depuis la 0.8.0 (ils venaient de Map/Flights.lua, d'OpenMap).
--   - chaque maître de vol de ta faction (et ceux de ta classe) : en couleur
--     ceux que tu as appris, en gris les autres (le réglage « seulement les
--     lieux découverts » cache ceux-là) ;
--   - appris : vus comme connus chez un maître de vol, retenus par personnage
--     (MyMapIsRichPlusCharDB.map.flightsKnown) ;
--   - l'action d'un maître de vol (sa fiche, UI/PointCard.lua) : le choisir,
--     puis en choisir un autre, et le trajet en vol se dessine le long des
--     vrais chemins, avec ses escales et son temps ;
--   - les temps : mesurés sur tes propres vols directs (pour tout le compte,
--     MyMapIsRichPlusDB.map.flightTimes), sinon estimés d'après la longueur.
-- Les réglages « flight » (le calque) et « foundOnly » sont ceux de la carte
-- (Map/Look.lua), que ses autres icônes suivent aussi.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local FL = ns.Map.Flights
local K = ns.Map.Coords
local Pins = ns.Map.Pins
local Settings = ns.Map.Settings

local SPEED = 30                -- yards par seconde (les vols de Classic, à peu près)
local ROUTE_COLOR = { 0.95, 0.78, 0.35 }
-- (vert comme sur la carte des vols du jeu ; gris : pas appris. L'icône de la
-- faction, rouge pour la Horde, se lisait « pas appris »)
local NODE_LOOK = { atlas = "Taxi_Frame_Green", texture = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green" }
local RING_LOOK = { atlas = "Waypoint-MapPin-Untracked", texture = "Interface\\Minimap\\Ping\\ping5" }
local SIZE_KNOWN, SIZE_NOT = 22, 18
-- (les sortes de nœuds qu'un maître de vol liste comme appris ; DISTANT, un
-- nœud qu'un vol traverse sans que tu l'aies appris, n'en est pas)
local LEARNED = { CURRENT = true, REACHABLE = true, UNREACHABLE = true }

local nodeAt = {}               -- id -> { u, v }
local edges = {}                -- id -> { { vers, chemin }, ... }
local pins = {}                 -- id -> icône
local set, routeSet
local selected                  -- le premier maître de vol choisi
local factionBit

local function Data() return ns.Map.Data.Flights() end

---------------------------------------------------------------------------
-- Les sauvegardes : les temps mesurés (le compte), les appris (le personnage)
---------------------------------------------------------------------------
function FL.Times()
    local db = ns.Map.DB()
    if not db then return {} end
    db.flightTimes = db.flightTimes or {}
    return db.flightTimes
end

function FL.Known()
    local char = ns.Map.CharDB()
    return char and char.flightsKnown
end

local function Learned()
    local char = ns.Map.CharDB()
    if not char then return {} end
    char.flightsKnown = char.flightsKnown or {}
    return char.flightsKnown
end

-- (le suivi des vols est le nôtre depuis la 0.8.0 : toujours en place)
function FL.Setup() return true end
function FL.Tracked() return true end

---------------------------------------------------------------------------
-- Les appris
---------------------------------------------------------------------------
-- Ceux que le jeu dit trouvés (C_TaxiMap.GetTaxiNodesForMap), relus à chaque
-- ouverture de la carte ; la même liste les nomme dans la langue du client :
-- les noms anglais des données sont remplacés par les siens. WoW Forever les
-- dit tous trouvés : alors seuls ceux vus chez un maître de vol comptent.
local found = {}
local function ReadFound()
    wipe(found)
    local F = Data()
    if not (F and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return end
    local seen, hidden = {}, 0
    for _, mapID in ipairs({ 1414, 1415 }) do
        local ok, list = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
        if ok and type(list) == "table" then
            for _, info in ipairs(list) do
                if type(info) == "table" and info.nodeID then
                    if info.isUndiscovered == false then
                        seen[info.nodeID] = true
                    elseif info.isUndiscovered == true then
                        hidden = hidden + 1
                    end
                    local n = F.nodes[info.nodeID]
                    if n and type(info.name) == "string" and info.name ~= "" then n[1] = info.name end
                end
            end
        end
    end
    if hidden == 0 then return end
    for id in pairs(seen) do found[id] = true end
end

-- Appris : la liste vue chez un maître de vol par ce personnage ; avant
-- qu'il en ait vu un, ce que le jeu dit
local function Known(id)
    local F = Data()
    local n = F and F.nodes[id]
    local learned = FL.Known()
    if learned and next(learned) then return n and learned[n[1]] and true or false end
    return found[id] and true or false
end
FL.IsKnown = Known

local function RefreshLook()
    ReadFound()
    local foundOnly = Settings.Get("foundOnly")
    for id, pin in pairs(pins) do
        local known = Known(id)
        pin:SetShown(known or not foundOnly)
        pin.Icon:SetDesaturated(not known)
        pin.Icon:SetAlpha(known and 1 or 0.9)
        if pin.shadow then pin.shadow:SetAlpha(known and 0.8 or 0.65) end
        local size = known and SIZE_KNOWN or SIZE_NOT
        pin:SetSize(size, size)
    end
end
FL.Refresh = RefreshLook

-- /mmir carte forgetflights : les appris oubliés pour ce personnage ; le
-- prochain maître de vol les réapprend
function FL.Forget()
    local char = ns.Map.CharDB()
    if char then char.flightsKnown = {} end
    if set then RefreshLook() end
    ns.Print(L.FLIGHT_FORGOTTEN)
end

---------------------------------------------------------------------------
-- Chez un maître de vol : les appris ; en vol : le temps mesuré
---------------------------------------------------------------------------
local taxi = {}                 -- le vol en cours : de, vers, départ
local watch = 0

local function OnTaxiMap()
    if not (NumTaxiNodes and TaxiNodeName and TaxiNodeGetType) then return end
    local learned, current = Learned(), nil
    for i = 1, NumTaxiNodes() do
        local name, kind = TaxiNodeName(i), TaxiNodeGetType(i)
        if LEARNED[kind] and name then learned[name] = true end
        if kind == "CURRENT" then current = name end
    end
    taxi.here = current
    if set then RefreshLook() end
end

local function WatchFlight(token)
    if token ~= watch then return end
    if UnitOnTaxi("player") then
        taxi.flying = taxi.flying or GetTime()
    elseif taxi.flying then
        local secs = GetTime() - taxi.flying
        -- (les vols directs seulement : le temps d'un saut se relit pour ce saut)
        if taxi.from and taxi.to and taxi.direct and secs > 5 then
            FL.Times()[taxi.from .. "|" .. taxi.to] = math.floor(secs + 0.5)
        end
        wipe(taxi)
        return
    elseif GetTime() - (taxi.asked or 0) > 10 then
        wipe(taxi)                 -- (jamais parti)
        return
    end
    C_Timer.After(0.5, function() WatchFlight(token) end)
end

local function OnTakeTaxi(index)
    watch = watch + 1
    local hops = GetNumRoutes and GetNumRoutes(index)
    taxi.from, taxi.to, taxi.flying, taxi.asked = taxi.here, TaxiNodeName(index), nil, GetTime()
    taxi.direct = hops == 1
    local token = watch
    C_Timer.After(0.5, function() WatchFlight(token) end)
end

---------------------------------------------------------------------------
-- Le trajet en vol d'un maître de vol à un autre
---------------------------------------------------------------------------
-- (de ta faction, et ceux d'une classe pour elle seule : Havre-du-Nord, les druides)
local function Usable(id)
    local F = Data()
    local n = F and F.nodes[id]
    if not (n and bit and bit.band and type(n[5]) == "number" and bit.band(n[5], factionBit or 0) ~= 0) then return false end
    return not n[6] or n[6] == select(2, UnitClass("player"))
end

-- Le trajet le plus court en longueur de vol ; knownOnly : par des appris seulement
local function Route(from, to, knownOnly)
    local dist, prev, via, done = { [from] = 0 }, {}, {}, {}
    while true do
        local best, bd
        for id, d in pairs(dist) do
            if not done[id] and (not bd or d < bd) then best, bd = id, d end
        end
        if not best then return end
        if best == to then break end
        done[best] = true
        for _, e in ipairs(edges[best] or {}) do
            local nxt, path = e[1], e[2]
            if Usable(nxt) and (not knownOnly or Known(nxt) or nxt == to) then
                local nd = bd + path[3]
                if not dist[nxt] or nd < dist[nxt] then dist[nxt], prev[nxt], via[nxt] = nd, best, path end
            end
        end
    end
    local legs, id = {}, to
    while id ~= from do
        table.insert(legs, 1, via[id])
        id = prev[id]
    end
    return legs
end

local function Clock(secs)
    return ("%d:%02d"):format(math.floor(secs / 60), math.floor(secs % 60))
end

-- Le nom court : « Hurlevent, Elwynn » -> « Hurlevent » (la virgule pleine
-- chasse cherchée en texte simple : les motifs de Lua vont octet par octet)
local function Short(name)
    local s = tostring(name or "?"):match("^[^,]+") or tostring(name or "?")
    local i = s:find("，", 1, true)
    return i and s:sub(1, i - 1) or s
end

-- Le temps d'un saut : mesuré, sinon estimé
local function LegTime(path)
    local F = Data()
    local a, b = F.nodes[path[1]], F.nodes[path[2]]
    local t = a and b and FL.Times()[a[1] .. "|" .. b[1]]
    return t or path[3] / SPEED, t ~= nil
end

local function ClearRoute()
    if routeSet then Pins.Clear(routeSet) end
    if selected and pins[selected] then pins[selected].ring:Hide() end
    selected = nil
end
FL.ClearRoute = ClearRoute

local function ShowRoute(from, to)
    local F = Data()
    Pins.Clear(routeSet)
    local legs, knownOnly = Route(from, to, true), true
    if not legs then legs, knownOnly = Route(from, to, false), false end
    if not legs then
        ns.Print(L.FLIGHT_NO_ROUTE, F.nodes[from][1], F.nodes[to][1])
        return
    end
    -- (le trajet par les appris laisse passer ses deux bouts même pas appris :
    -- un trajet qui part ou arrive à l'un d'eux en a quand même besoin)
    knownOnly = knownOnly and Known(from) and Known(to) and true or false
    local total, measured, cont = 0, true, F.nodes[from][2]
    local r, g, b = ROUTE_COLOR[1], ROUTE_COLOR[2], ROUTE_COLOR[3]
    local alpha = knownOnly and 0.95 or 0.5
    for _, path in ipairs(legs) do
        local t, m = LegTime(path)
        total = total + t
        measured = measured and m
        local p = path[5]
        if type(p) == "table" and #p >= 4 then
            local pu, pv = K.FromYards(cont, p[1], p[2])
            for k = 3, #p - 1, 2 do
                local u, v = K.FromYards(cont, p[k], p[k + 1])
                if pu and u then
                    local edge = Pins.Line(routeSet, pu, pv, u, v, 3, 0.25, 0.16, 0.05, alpha * 0.8)
                    local core = Pins.Line(routeSet, pu, pv, u, v, 1.6, r, g, b, alpha)
                    if edge then edge:SetDrawLayer("ARTWORK", 0) end
                    if core then core:SetDrawLayer("ARTWORK", 1) end
                end
                pu, pv = u, v
            end
        end
    end
    -- (la légende, à côté de l'arrivée : une icône sans image)
    local at = nodeAt[to]
    local label = at and Pins.Add(routeSet, at[1], at[2], { texture = "", size = 1 })
    if not label then return end
    label:EnableMouse(false)
    if not label.caption then        -- (les icônes sont réutilisées : la légende est faite une fois)
        label.caption = label:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label.caption:SetPoint("LEFT", label, "CENTER", 14, 0)
        label.caption:SetShadowOffset(1, -1)
    end
    local stops = #legs - 1
    label.caption:SetText(("%s > %s  |cffffffff%s|r%s"):format(
        Short(F.nodes[from][1]), Short(F.nodes[to][1]),
        measured and Clock(total) or L.FLIGHT_ABOUT:format(Clock(total)),
        stops > 0 and ("  |cffaaaaaa(" .. (stops == 1 and L.FLIGHT_ONE_STOP or L.FLIGHT_STOPS:format(stops)) .. ")|r") or "")
        .. (knownOnly and "" or ("\n|cffff8060" .. L.FLIGHT_NEEDS_UNLEARNED .. "|r")))
    label.caption:Show()
end

-- L'action d'un maître de vol : le choisir ; un autre ensuite : le trajet
local function NodeClick(pin)
    local id = pin.node
    if not selected or selected == id then
        ClearRoute()
        selected = id
        pin.ring:Show()
    else
        local from = selected
        if pins[from] then pins[from].ring:Hide() end
        selected = nil
        ShowRoute(from, id)
    end
end

local function NodeEnter(pin)
    local F = Data()
    local n = F.nodes[pin.node]
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(n[1], 1, 0.82, 0)
    GameTooltip:AddLine(Known(pin.node) and L.FLIGHT_LEARNED or L.FLIGHT_NOT_LEARNED, 0.8, 0.8, 0.8)
    if selected and selected ~= pin.node then
        local legs = Route(selected, pin.node, true) or Route(selected, pin.node, false)
        if legs then
            local total = 0
            for _, path in ipairs(legs) do total = total + LegTime(path) end
            GameTooltip:AddLine(L.FLIGHT_FROM:format(Short(F.nodes[selected][1]), Clock(total)), 1, 1, 1)
        end
        GameTooltip:AddLine(L.FLIGHT_CLICK_ROUTE, 0.6, 0.6, 0.6)
    else
        GameTooltip:AddLine(L.FLIGHT_CLICK_FIRST, 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- La construction, une fois la carte dessinée
---------------------------------------------------------------------------
local function Build()
    local F = Data()
    if set or not (F and Pins.Ready()) then return end
    factionBit = UnitFactionGroup("player") == "Horde" and 2 or 1
    -- (les clés « flight » et « route » : le calque et ses icônes dès un zoom,
    -- cachés dans les donjons, comme les autres icônes de la carte)
    set = Pins.Set("flight", 2.5, 2)
    routeSet = Pins.Set("route", 1, 1)
    if not (set and routeSet) then return end
    for _, path in ipairs(F.paths or {}) do
        edges[path[1]] = edges[path[1]] or {}
        table.insert(edges[path[1]], { path[2], path })
    end
    for id, n in pairs(F.nodes or {}) do
        if Usable(id) then
            local u, v = K.FromYards(n[2], n[3], n[4])
            local look = { atlas = NODE_LOOK.atlas, texture = NODE_LOOK.texture, size = SIZE_KNOWN }
            local pin = u and Pins.Add(set, u, v, look)
            if pin then
                nodeAt[id] = { u, v }
                pin.node = id
                -- (un contour sombre : la même botte en noir, un peu plus grande, dessous)
                pin.shadow = pin.shadow or pin:CreateTexture(nil, "BACKGROUND")
                pin.shadow:ClearAllPoints()
                pin.shadow:SetPoint("TOPLEFT", -3, 3)
                pin.shadow:SetPoint("BOTTOMRIGHT", 3, -3)
                UI.SetIcon(pin.shadow, NODE_LOOK.texture, NODE_LOOK.atlas)
                pin.shadow:SetVertexColor(0, 0, 0)
                pin.shadow:Show()
                pin.ring = pin.ring or pin:CreateTexture(nil, "OVERLAY")
                pin.ring:SetPoint("CENTER")
                pin.ring:SetSize(30, 30)
                UI.SetIcon(pin.ring, RING_LOOK.texture, RING_LOOK.atlas)
                pin.ring:SetVertexColor(1, 0.85, 0.3)
                pin.ring:Hide()
                pin:SetScript("OnEnter", NodeEnter)
                pin:SetScript("OnLeave", GameTooltip_Hide)
                pin.OnClick = NodeClick
                pins[id] = pin
            end
        end
    end
    Pins.SetOn(set, Settings.Get("flight") ~= false)
    RefreshLook()
end

---------------------------------------------------------------------------
-- Le pont vers le code d'OpenMap qui reste (/mmir carte forgetflights :
-- Init.lua), et la migration
---------------------------------------------------------------------------
local function Bridge()
    local mod = ns.Map.Legacy()
    if mod then mod.ForgetFlights = function() FL.Forget() end end
end
-- (un réglage changé, « seulement les lieux trouvés » : l'aspect des maîtres de vol)
ns.On("MAP_REFRESH", function() if set then RefreshLook() end end)

local function Migrate()
    ns.Map.Migrate("flightTimes", function(old, new, copy)
        if type(old.flightTimes) == "table" then new.flightTimes = copy(old.flightTimes) end
    end)
    -- (les appris retenus par OpenMap 0.7.5 et avant comptaient des nœuds pas
    -- appris : seuls ceux de sa version 2 sont repris)
    ns.Map.Migrate("flightsKnown", function(old, new, copy)
        if old.flightsKnownV == 2 and type(old.flightsKnown) == "table" then new.flightsKnown = copy(old.flightsKnown) end
    end, true)
end

ns.On("MAP_ATTACHED", function()
    Migrate()
    Bridge()
end)
ns.On("MAP_BUILT", Build)
ns.On("MAP_SHOW", function() if set then RefreshLook() end end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if root.dormant then return end
        self:RegisterEvent("TAXIMAP_OPENED")
        self:RegisterEvent("TAXI_NODE_STATUS_CHANGED")
        if TakeTaxiNode then hooksecurefunc("TakeTaxiNode", OnTakeTaxi) end
    elseif event == "TAXIMAP_OPENED" then
        OnTaxiMap()
    elseif event == "TAXI_NODE_STATUS_CHANGED" then
        if set then RefreshLook() end
    end
end)
