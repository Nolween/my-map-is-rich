-- Les horaires des bateaux et des zeppelins (Data/Transit.lua, d'après
-- Shortest Path Forever ; ses règles : Transport/Model.lua, Observer.lua et
-- UI/Alert.lua de cjber, GPL-3.0-or-later, écrites de nouveau ici).
-- Chaque ligne tourne en boucle : sa période, ses arrêts (quand le bateau
-- arrive à un quai, quand il en repart) et son trajet daté. Il suffit de
-- savoir où en est la boucle à un instant, son « époque » (l'heure du serveur
-- où elle était à 0), pour connaître tous ses passages.
-- L'époque s'apprend en regardant passer le bateau : à bord, ta position
-- chaque seconde (plus vite que MIN_SPEED, pas en vol) donne, pour chaque
-- ligne dont le trajet passe à moins de NEAR yards, où en est sa boucle ; les
-- relevés d'une même traversée qui s'accordent, sur au moins MIN_SPAN, font
-- l'époque de la ligne, si une seule ligne l'emporte nettement. Un horaire
-- appris se garde pour le compte (ns.db.transit[ligne] = { epoch (ms), seen
-- (s) }), KEEP ; au-delà, la ligne redevient sans horaire.
-- Pour l'itinéraire (Travel/Planner.lua) :
--   Transit.Leg(from, to, delay) -> secs (attente + trajet), wait, ligne, timed
--     entre deux quais du réseau (Travel/Graph.lua) : l'attente selon
--     l'horaire, depuis ton arrivée au quai dans `delay` s (un bateau qui part
--     dans moins de BOARD s est manqué : le suivant), sinon l'attente moyenne ;
--     nil si aucune ligne connue ne les relie.
-- Pour le guidage (UI/RouteHud.lua) :
--   Transit.Wait(leg) -> s avant le départ du bateau de l'étape, et s'il est à quai ; nil sans horaire
-- Les alertes (réglage travelAlerts) : un bandeau à nous, la cloche du
-- bateau ou la corne du zeppelin du jeu (réglage Sons), l'icône du jeu qui
-- clignote : AT_DOCK avant l'arrivée du bateau quand tu l'attends au quai de
-- l'étape, ON_BOARD avant ton arrêt quand tu es à bord. Une fois par
-- passage, rien en combat. Transit.Sample() montre l'alerte pour essayer.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local Transit = {}
ns.Transit = Transit

local KEEP = 6 * 3600        -- s : un horaire appris se garde autant
local BOARD = 10             -- s : un bateau qui part plus tôt après ton arrivée au quai est manqué
local MATCH = 150            -- yd : un quai du réseau et celui d'une ligne, s'ils sont si près
local MIN_SPEED = 12         -- yd/s : un bateau file à 30 ; un joueur court à 7, monté à 14
local NEAR = 40              -- yd : plus loin du trajet d'une ligne, on n'est pas dessus
local AGREE = 8000           -- ms : les relevés d'un même bateau s'accordent à ça près
local MIN_SAMPLES = 10
local MIN_SPAN = 30000       -- ms : ... sur au moins ce temps de traversée
local CLEAR_LEAD = 1.25      -- la ligne retenue a au moins autant de fois plus de relevés que la suivante
local RIDE_GAP = 30          -- s sans relevé : la traversée est finie (à quai, ou descendu)
local MAX_SAMPLES = 300
local FIT_EVERY = 10         -- relevés entre deux essais de calage pendant la traversée
local AT_DOCK = 30           -- s avant l'arrivée du bateau au quai où tu l'attends
local ON_BOARD = 20          -- s avant ton arrêt, à bord
local RADIUS = 120           -- yd : au quai
local REPEAT = 120           -- s : une alerte par passage
local SOUND = { boat = 566652, zeppelin = 566719 }   -- la cloche d'un bateau à quai, la corne d'un zeppelin

local floor, sqrt, abs, huge = math.floor, math.sqrt, math.abs, math.huge

---------------------------------------------------------------------------
-- L'heure du serveur en ms : GetServerTime n'a que des secondes entières, et
-- les arrondit vers le bas ; sa plus grande avance sur GetTime est l'écart
-- entre les deux horloges (refait si l'une saute)
---------------------------------------------------------------------------
local offset
local function NowMs()
    local lead = GetServerTime() - GetTime()
    if not offset or lead > offset or offset - lead > 2 then offset = lead end
    return (GetTime() + offset) * 1000
end

local function Data() return type(ns.TransitData) == "table" and ns.TransitData or nil end

local function Store()
    if not ns.db then return {} end
    ns.db.transit = ns.db.transit or {}
    return ns.db.transit
end

-- L'horaire appris d'une ligne, s'il est encore frais
local function Anchor(rid)
    local a = Store()[rid]
    if type(a) == "table" and type(a.epoch) == "number" and type(a.seen) == "number"
        and GetServerTime() - a.seen <= KEEP then
        return a
    end
end
Transit.Anchor = Anchor

local function Faction()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return f
end

---------------------------------------------------------------------------
-- Les passages d'une ligne à un arrêt
---------------------------------------------------------------------------
-- Le prochain passage à l'arrêt `stop` quand la boucle est à `phase` (ms) :
-- à quai maintenant (departIn), ou arriveIn et le départ de ce passage
local function Visit(route, stop, phase)
    local period = route.period
    local stay = (stop[3] - stop[2]) % period
    local since = (phase - stop[2]) % period
    if since < stay then return true, nil, stay - since end
    local arriveIn = (stop[2] - phase) % period
    return false, arriveIn, arriveIn + stay
end

-- L'attente moyenne à un arrêt pour qui y arrive à n'importe quel moment (ms)
local function MeanWait(route, stop)
    local period = route.period
    local stay = (stop[3] - stop[2]) % period
    local docked = stay / period
    return docked * stay / 2 + (1 - docked) * ((period - stay) / 2 + stay)
end

-- Le quai d'une ligne le plus proche d'un point (au plus MATCH yards), gardé
local dockOf = {}
local function DockOf(node)
    local D = Data()
    if not (D and node and node.cont) then return end
    local key = node.cont .. ":" .. floor(node.x) .. ":" .. floor(node.y)
    local found = dockOf[key]
    if found == nil then
        found = false
        local best = MATCH * MATCH
        for i, d in pairs(D.docks) do
            if d[1] == node.cont then
                local dx, dy = d[2] - node.x, d[3] - node.y
                local d2 = dx * dx + dy * dy
                if d2 <= best then found, best = i, d2 end
            end
        end
        dockOf[key] = found
    end
    return found or nil
end

-- Les lignes qui vont du quai a au quai b : { { rid, route, from (arrêt), ride (ms) }, ... }
local pairsOf = {}
local function Lines(a, b)
    local key = a .. ">" .. b
    local list = pairsOf[key]
    if list then return list end
    list = {}
    local D, faction = Data(), Faction()
    for rid, route in pairs(D and D.routes or {}) do
        if not route.faction or route.faction == faction then
            local stops = route.stops
            for i, s in ipairs(stops) do
                if s[1] == a then
                    for j, t in ipairs(stops) do
                        if j ~= i and t[1] == b then
                            list[#list + 1] = { rid = rid, route = route, from = s, ride = (t[2] - s[3]) % route.period }
                        end
                    end
                end
            end
        end
    end
    pairsOf[key] = list
    return list
end

function Transit.Leg(from, to, delay)
    local a, b = DockOf(from), DockOf(to)
    if not (a and b) or a == b then return end
    local at = NowMs() + (delay or 0) * 1000
    local bestSecs, bestWait, bestRid, bestTimed
    for _, line in ipairs(Lines(a, b)) do
        local route, wait, timed = line.route, nil, false
        local anchor = Anchor(line.rid)
        if anchor then
            local _, _, departIn = Visit(route, line.from, (at - anchor.epoch) % route.period)
            if departIn < BOARD * 1000 then departIn = departIn + route.period end
            wait, timed = departIn, true
        else
            wait = MeanWait(route, line.from)
        end
        local secs = (wait + line.ride) / 1000
        if not bestSecs or secs < bestSecs then
            bestSecs, bestWait, bestRid, bestTimed = secs, wait / 1000, line.rid, timed
        end
    end
    return bestSecs, bestWait, bestRid, bestTimed
end

-- Le départ du bateau d'une étape, maintenant : s avant qu'il parte, à quai ou non ; nil sans horaire
function Transit.Wait(leg)
    if not (leg and leg.from and leg.to) then return end
    local a, b = DockOf(leg.from), DockOf(leg.to)
    if not (a and b) then return end
    local now = NowMs()
    local best, bestDocked
    for _, line in ipairs(Lines(a, b)) do
        if not leg.transit or leg.transit == line.rid then
            local anchor = Anchor(line.rid)
            if anchor then
                local docked, _, departIn = Visit(line.route, line.from, (now - anchor.epoch) % line.route.period)
                if not best or departIn < best then best, bestDocked = departIn, docked end
            end
        end
    end
    if best then return best / 1000, bestDocked end
end

-- Le bateau de l'étape : s avant son arrivée au quai de départ (nil : à quai, ou sans horaire),
-- et s avant son arrivée au quai d'arrivée
local function Timing(leg)
    local a, b = DockOf(leg.from), DockOf(leg.to)
    if not (a and b) then return end
    local now = NowMs()
    for _, line in ipairs(Lines(a, b)) do
        if not leg.transit or leg.transit == line.rid then
            local anchor = Anchor(line.rid)
            if anchor then
                local route = line.route
                local phase = (now - anchor.epoch) % route.period
                local docked, arriveIn = Visit(route, line.from, phase)
                local landIn
                for _, s in ipairs(route.stops) do
                    if s[1] == b then
                        local _, arrive = Visit(route, s, phase)
                        if arrive and (not landIn or arrive < landIn) then landIn = arrive end
                    end
                end
                return not docked and arriveIn and arriveIn / 1000 or nil, landIn and landIn / 1000, line.rid
            end
        end
    end
end

---------------------------------------------------------------------------
-- Les relevés à bord
---------------------------------------------------------------------------
-- Où en est la boucle d'une ligne quand on est en (cont, x, y) : chaque phase (ms)
-- où son trajet y passe, en mouvement (un bateau à quai ne bouge pas : rien)
local function Phases(route, cont, x, y, out)
    local f = route.frames
    for i = 1, #f - 6, 6 do
        local a2, ac, ax, ay, jump = f[i + 1], f[i + 2], f[i + 3], f[i + 4], f[i + 5]
        local b1, bx, by = f[i + 6], f[i + 9], f[i + 10]
        if ac == cont and jump == 0 then
            local dx, dy = bx - ax, by - ay
            local len = dx * dx + dy * dy
            if len > 0 then
                local t = ((x - ax) * dx + (y - ay) * dy) / len
                if t > 0 and t < 1 then
                    local px, py = ax + t * dx - x, ay + t * dy - y
                    if px * px + py * py <= NEAR * NEAR then out[#out + 1] = a2 + t * (b1 - a2) end
                end
            end
        end
    end
    return out
end

-- L'époque sur laquelle s'accordent le plus de relevés d'une traversée, et combien (nil s'ils sont trop peu)
local function FitEpoch(route, samples)
    local period, offsets = route.period, {}
    for _, s in ipairs(samples) do
        for _, phase in ipairs(s.phases) do
            offsets[#offsets + 1] = { (s.now - phase) % period, s.now }
        end
    end
    local best, support = nil, 0
    for _, center in ipairs(offsets) do
        local members, sum, first, last = 0, 0, huge, -huge
        for _, other in ipairs(offsets) do
            local delta = (other[1] - center[1] + period / 2) % period - period / 2
            if abs(delta) <= AGREE / 2 then
                members, sum = members + 1, sum + delta
                if other[2] < first then first = other[2] end
                if other[2] > last then last = other[2] end
            end
        end
        if members > support and last - first >= MIN_SPAN then
            best, support = (center[1] + sum / members) % period, members
        end
    end
    if support < MIN_SAMPLES then return nil, support end
    return best, support
end

local ride                   -- { samples = { [ligne] = { { now, phases }, ... } }, count, last (s) }
local previous

-- La traversée a montré sa ligne : son horaire est gardé
local function Record()
    if not ride or InCombatLockdown() then return end
    local D = Data()
    local fits = {}
    for rid, samples in pairs(ride.samples) do
        local epoch, support = FitEpoch(D.routes[rid], samples)
        if epoch then fits[rid] = { epoch = epoch, support = support } end
    end
    local best, second
    for rid, fit in pairs(fits) do
        if not best or fit.support > fits[best].support then
            second = best and fits[best].support or second
            best = rid
        elseif not second or fit.support > second then
            second = fit.support
        end
    end
    if best and (not second or fits[best].support >= CLEAR_LEAD * second) then
        Store()[best] = { epoch = fits[best].epoch, seen = GetServerTime() }
        ride.route = best
        ns.Fire("TRANSIT")
    end
end

local function Sample(here)
    local D = Data()
    if not D then return end
    local now = GetTime()
    local speed = 0
    if here and previous and previous.cont == here.cont and now > previous.t and not (UnitOnTaxi and UnitOnTaxi("player")) then
        local dx, dy = here.x - previous.x, here.y - previous.y
        speed = sqrt(dx * dx + dy * dy) / (now - previous.t)
    end
    previous = here and { cont = here.cont, x = here.x, y = here.y, t = now } or nil
    if speed >= MIN_SPEED then
        local ms = NowMs()
        local faction, seen = Faction(), false
        for rid, route in pairs(D.routes) do
            if not route.faction or route.faction == faction then
                local phases = Phases(route, here.cont, here.x, here.y, {})
                if #phases > 0 then
                    ride = ride or { samples = {}, count = 0 }
                    local list = ride.samples[rid] or {}
                    ride.samples[rid] = list
                    list[#list + 1] = { now = ms, phases = phases }
                    if #list > MAX_SAMPLES then table.remove(list, 1) end
                    seen = true
                end
            end
        end
        if seen then
            ride.last, ride.count = now, ride.count + 1
            if not ride.route and ride.count % FIT_EVERY == 0 then Record() end
        end
    end
    if ride and now - (ride.last or now) > RIDE_GAP then
        Record()
        ride = nil
    end
end

-- (un /reload à bord : la traversée jusque-là est gardée)
local leaving = CreateFrame("Frame")
leaving:RegisterEvent("PLAYER_LEAVING_WORLD")
leaving:SetScript("OnEvent", function() if ride then Record() end end)

---------------------------------------------------------------------------
-- Les alertes
---------------------------------------------------------------------------
local banner, bannerHide
local alerted = {}

local function Banner(title, text)
    if not banner then
        banner = UI.Panel(UIParent, "MyMapIsRichTransitAlert", "HIGH")
        banner:SetSize(420, 58)
        banner:SetPoint("TOP", UIParent, "TOP", 0, -150)
        banner:EnableMouse(false)
        banner.title = UI.Text(banner, "GameFontNormalLarge")
        banner.title:SetPoint("TOP", 0, -10)
        banner.text = UI.Text(banner, "GameFontHighlight")
        banner.text:SetPoint("TOP", banner.title, "BOTTOM", 0, -5)
        banner.text:SetWidth(400)
        banner:Hide()
    end
    banner.title:SetText(title)
    banner.text:SetText(text)
    banner:Show()
    if bannerHide then bannerHide:Cancel() end
    bannerHide = C_Timer.NewTimer(8, function() banner:Hide() end)
end

local function Alert(key, kind, text)
    if GetTime() - (alerted[key] or -huge) < REPEAT then return end
    alerted[key] = GetTime()
    Banner(kind == "zeppelin" and L.TRANSIT_ZEPPELIN or L.TRANSIT_BOAT, text)
    if ns.db.options.travelSound ~= false and SOUND[kind] and PlaySoundFile then
        pcall(PlaySoundFile, SOUND[kind], "Master")
    end
    if FlashClientIcon then pcall(FlashClientIcon) end
end

local function Duration(secs)
    if ns.RouteHud and ns.RouteHud.Duration then return ns.RouteHud.Duration(secs) end
    return tostring(floor(secs + 0.5))
end

local function Alerts(here)
    if not (ns.db and ns.db.options.travelAlerts ~= false) or InCombatLockdown() then return end
    local T = ns.Travel
    if not (T and T.Live) then return end
    local plan, index = T.Live()
    local leg = plan and plan.legs[index]
    if not (leg and (leg.kind == "boat" or leg.kind == "zeppelin") and here) then return end
    local G = ns.TravelGraph
    local comeIn, landIn, rid = Timing(leg)
    if not rid then return end
    local name = T.ZoneOf(leg.to) or "?"
    if leg.from.cont == here.cont and G.Dist(here, leg.from) <= RADIUS then
        -- (au quai : le bateau arrive bientôt)
        if comeIn and comeIn <= AT_DOCK then
            Alert(rid .. ":dock", leg.kind, L.TRANSIT_ARRIVES:format(name, Duration(comeIn)))
        end
    elseif ride and ride.route == rid and landIn and landIn <= ON_BOARD then
        -- (à bord : ton arrêt bientôt)
        Alert(rid .. ":land", leg.kind, L.TRANSIT_LANDING:format(name, Duration(landIn)))
    end
end

-- Pour essayer (onglet Trajets)
function Transit.Sample()
    alerted.sample = nil
    Alert("sample", "boat", L.TRANSIT_ARRIVES:format(L.TRANSIT_SAMPLE_PLACE, Duration(AT_DOCK)))
end

---------------------------------------------------------------------------
-- Chaque seconde, hors instance : un relevé, les alertes
---------------------------------------------------------------------------
C_Timer.NewTicker(1, function()
    if not (ns.db and Data()) or (ns.Conflict and ns.Conflict()) then return end
    if IsInInstance and IsInInstance() then return end
    local Pl = ns.TravelPlanner
    local here = Pl and Pl.PlayerPoint()
    local ok, err = pcall(Sample, here)
    if not ok and geterrorhandler then geterrorhandler()(err) end
    ok, err = pcall(Alerts, here)
    if not ok and geterrorhandler then geterrorhandler()(err) end
end)
