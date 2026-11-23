-- Partager une destination avec le groupe, et s'y rallier.
--   Envoyer (la roue de la carte, « Envoyer au groupe ») : le point sous le
--   curseur part au groupe en message d'addon, et une ligne dans la
--   discussion du groupe le dit aussi pour ceux qui n'ont pas l'addon (zone
--   et coordonnées ; réglage). Celui qui l'envoie y va aussi : c'est le
--   point de ralliement.
--   Recevoir : une fenêtre à la charte (A : y aller et se rallier, X :
--   l'ajouter à la file, B : non merci). Carte fermée, une ligne dans la
--   discussion : la fenêtre s'ouvre avec la carte (l'addon ne prend la
--   manette que carte ouverte).
--   Se rallier : chacun de ceux qui y vont envoie son temps restant toutes
--   les 10 s ; le panneau de trajet montre le temps de chacun (UI/RouteHud.lua).
-- Jamais depuis une instance (donjon, raid, champ de bataille). Les messages
-- (préfixe OMGPRoute, séparés par des tabulations) :
--   D1 id mapID x y nom   une destination proposée (x, y sur la carte, 0..1)
--   E1 id secs total      le temps restant de celui qui l'envoie
--   A1 id                 il est arrivé
--   X1 id                 il ne vient plus
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI
local P = ns.Pad
local F = ns.Focus
local Pl = ns.TravelPlanner

local SH = {}
ns.TravelShare = SH

local PREFIX = "OMGPRoute"
local ETA_EVERY = 10         -- s entre deux temps envoyés
local STALE = 45             -- s sans nouvelles : son temps n'est plus montré
local RALLY_MAX = 15 * 60    -- s : un ralliement s'arrête au plus tard
local AFTER_ARRIVAL = 180    -- s : arrivé, on attend encore les autres
local INVITE_MAX = 5 * 60    -- s : une destination reçue attend la réponse

local rally                  -- { id, goal, name, started, members = { [nom] = { secs, total, t, arrived, left } }, mine = { total, arrived, at } }
local invite                 -- { from, id, goal, name, t }

---------------------------------------------------------------------------
-- Le groupe
---------------------------------------------------------------------------
local function Channel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end

local function InInstance()
    if not IsInInstance then return false end
    local inside = IsInInstance()
    return inside and true or false
end

local function Me()
    return UnitName and UnitName("player") or "?"
end

local function Short(name)
    if Ambiguate then return Ambiguate(name or "", "short") end
    return (name or ""):match("^[^-]+") or name
end

local function Send(...)
    local channel = Channel()
    if not channel or InInstance() then return false end
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
    local msg = table.concat({ ... }, "\t")
    return pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel)
end

-- Les membres du groupe (sans soi) : { name, classFile }
local function GroupMembers()
    local out = {}
    local raid = IsInRaid and IsInRaid()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    local prefix = raid and "raid" or "party"
    local count = raid and n or math.max(0, n - 1)
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local name = UnitName(unit)
            local _, classFile = UnitClass(unit)
            if name then out[#out + 1] = { name = name, classFile = classFile } end
        end
    end
    return out
end

local function Colored(name, classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then
        return ("|cff%02x%02x%02x%s|r"):format(math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5),
            math.floor(c.b * 255 + 0.5), name), c.r, c.g, c.b
    end
    return name, 1, 0.82, 0
end

---------------------------------------------------------------------------
-- Le ralliement
---------------------------------------------------------------------------
local function EndRally(say)
    if not rally then return end
    if say then ns.Travel.Say(L.SHARE_RALLY_END) end
    rally = nil
    ns.Fire("TRAVEL")
end

local function MyRoute()
    local T = ns.Travel
    local goal = T and T.Goal()
    return rally and goal and goal.rally == rally.id
end

local function StartRally(id, goal, name)
    rally = { id = id, goal = goal, name = name, started = GetTime(), members = {}, mine = {} }
    ns.Fire("TRAVEL")
end

-- Pour le panneau de trajet : { name, members = { { name, colored, r, g, b,
-- secs, done, arrived }, ... } } (soi d'abord), ou nil
function SH.Rally()
    if not rally then return end
    local list = {}
    local T = ns.Travel
    local _, myClass = UnitClass("player")
    local me = { name = Me() }
    me.colored, me.r, me.g, me.b = Colored(Me(), myClass)
    if rally.mine.arrived then
        me.arrived = true
    elseif MyRoute() then
        me.secs = T.Remaining()
        local total = rally.mine.total
        if me.secs and total and total > 0 then me.done = 1 - me.secs / total end
    end
    list[1] = me
    local now = GetTime()
    for _, m in ipairs(GroupMembers()) do
        local e = { name = m.name }
        e.colored, e.r, e.g, e.b = Colored(m.name, m.classFile)
        local data = rally.members[m.name]
        if data and not data.left then
            if data.arrived then
                e.arrived = true
            elseif now - data.t <= STALE then
                -- (son temps a coulé depuis son dernier envoi)
                e.secs = math.max(0, data.secs - (now - data.t))
                if data.total and data.total > 0 then e.done = 1 - e.secs / data.total end
            end
        end
        list[#list + 1] = e
    end
    return { name = rally.name, members = list }
end

---------------------------------------------------------------------------
-- Envoyer une destination
---------------------------------------------------------------------------
local function NameOf(point)
    return point.name or Pl.ZoneName(point) or L.TRAVEL_DEST
end

function SH.Propose(point)
    if not point then
        ns.Print(L.TRAVEL_NO_THERE)
        return
    end
    if not Channel() then
        ns.Print(L.SHARE_NO_GROUP)
        return
    end
    if InInstance() then
        ns.Print(L.SHARE_INSTANCE)
        return
    end
    local mapID, mx, my = Pl.MapPoint(point)
    if not mapID then
        ns.Print(L.TRAVEL_NO_THERE)
        return
    end
    local name = NameOf(point)
    local id = Me() .. "-" .. math.floor(GetTime())
    Send("D1", id, mapID, ("%.4f"):format(mx), ("%.4f"):format(my), name)
    -- (pour ceux qui n'ont pas l'addon : la zone et les coordonnées)
    if ns.db.options.travelShareChat ~= false and SendChatMessage then
        local zone = Pl.ZoneName(point) or name
        local text = name ~= zone and L.SHARE_CHAT_NAMED:format(name, zone, mx * 100, my * 100)
            or L.SHARE_CHAT:format(zone, mx * 100, my * 100)
        pcall(SendChatMessage, text, Channel())
    end
    ns.Travel.Say(L.SHARE_SENT, name)
    local goal = ns.Travel.Copy(point)
    goal.name, goal.rally = name, id
    StartRally(id, goal, name)
    if not ns.Travel.Go(goal, true) then
        -- (déjà sur place : arrivé)
        rally.mine.arrived, rally.mine.at = true, GetTime()
        Send("A1", id)
    end
end

---------------------------------------------------------------------------
-- La fenêtre d'une destination reçue
---------------------------------------------------------------------------
local frame

local function CloseInvite()
    invite = nil
    if frame then frame:Hide() end
    P.Dirty()
end

local function Accept()
    local inv = invite
    CloseInvite()
    if not inv then return end
    StartRally(inv.id, inv.goal, inv.name)
    if not ns.Travel.Go(inv.goal, false) then
        rally.mine.arrived, rally.mine.at = true, GetTime()
        Send("A1", inv.id)
    end
end

local function Later()
    local inv = invite
    CloseInvite()
    if inv then ns.Travel.Enqueue(inv.goal) end
end

local function Decline()
    CloseInvite()
end

local function GlyphButton(parent, text, key, w, style, onClick)
    local b = UI.Button(parent, text, w, 34, style)
    b:SetScript("OnClick", onClick)
    local g = UI.CreateGlyph(b, 20)
    g:SetPoint("LEFT", 8, 0)
    g:SetKey(key)
    b:GetFontString():SetPoint("LEFT", 32, 0)
    return b
end

local function Build()
    if frame then return end
    local w, h = 480, 214
    frame = UI.MapWindow("MyMapIsRichPlusShareInvite", w, h, L.SHARE_TITLE, nil, 8600)
    local c = frame.content
    frame.close:SetScript("OnClick", Decline)
    frame.who = UI.Text(c, "GameFontHighlight")
    frame.who:SetPoint("TOPLEFT", 6, -6)
    frame.who:SetPoint("RIGHT", -6, 0)
    frame.who:SetJustifyH("LEFT")
    local well = UI.Well(c)
    well:SetPoint("TOPLEFT", 0, -28)
    well:SetPoint("TOPRIGHT", 0, -28)
    well:SetHeight(70)
    frame.name = UI.Text(well, "GameFontNormalLarge")
    frame.name:SetPoint("TOPLEFT", 12, -10)
    frame.name:SetPoint("RIGHT", -12, 0)
    frame.name:SetJustifyH("LEFT")
    frame.name:SetWordWrap(false)
    frame.zone = UI.DimText(well, "")
    frame.zone:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -4)
    frame.time = UI.Text(well, "GameFontNormal")
    frame.time:SetPoint("TOPLEFT", frame.zone, "BOTTOMLEFT", 0, -4)
    local bw = math.floor((w - 12 - 2 * 8) / 3)
    frame.go = GlyphButton(c, L.SHARE_GO, "PAD1", bw, "red", Accept)
    frame.go:SetPoint("BOTTOMLEFT", 0, 6)
    frame.later = GlyphButton(c, L.SHARE_LATER, "PAD3", bw, "grey", Later)
    frame.later:SetPoint("LEFT", frame.go, "RIGHT", 8, 0)
    frame.no = GlyphButton(c, L.SHARE_NO, "PAD2", bw, "grey", Decline)
    frame.no:SetPoint("LEFT", frame.later, "RIGHT", 8, 0)
    F.RegisterWindow(frame, { onBack = Decline, first = function() return frame.go end })
end

local function ShowInvite()
    if not (invite and ns.MapShown()) or InCombatLockdown() then return end
    if GetTime() - invite.t > INVITE_MAX then
        invite = nil
        return
    end
    Build()
    frame.who:SetText(L.SHARE_FROM:format(invite.colored or invite.from))
    frame.name:SetText(invite.name)
    frame.zone:SetText(Pl.ZoneName(invite.goal) or "")
    -- (le temps d'ici : un calcul, une fois)
    local here = Pl.PlayerPoint()
    local text = ""
    if here then
        local plan = Pl.Find(here, ns.Travel.Copy(invite.goal))
        if plan and plan.secs then text = L.SHARE_TIME:format(ns.RouteHud.Duration(plan.secs)) end
    end
    frame.time:SetText(text)
    frame:Show()
    P.Dirty()
end

-- Le contexte de la fenêtre : celui des fenêtres, plus X (la file) et B
P.DefineContext("invite", 60, function() return frame and frame:IsShown() and F.Top() == frame end, "window")
F.WINDOW_CONTEXTS.invite = true
P.SetAction("invite", "PAD1", Accept, "SHARE_GO")
P.SetAction("invite", "PAD3", Later, "SHARE_LATER")
P.SetAction("invite", "PAD2", Decline, "SHARE_NO")

---------------------------------------------------------------------------
-- Les messages reçus
---------------------------------------------------------------------------
local function OnMessage(text, sender)
    local who = Short(sender)
    if who == Me() then return end
    local f = { strsplit("\t", text) }
    local kind, id = f[1], f[2]
    if kind == "D1" then
        if ns.db.options.travelShare == false or not ns.db.options.travel then return end
        local mapID, mx, my = tonumber(f[3]), tonumber(f[4]), tonumber(f[5])
        local goal = mapID and Pl.WorldOf(mapID, mx, my)
        if not goal then return end
        local name = f[6] ~= "" and f[6] or Pl.ZoneName(goal) or L.TRAVEL_DEST
        goal.name, goal.rally = name, id
        local classFile
        for _, m in ipairs(GroupMembers()) do
            if m.name == who then classFile = m.classFile end
        end
        invite = { from = who, colored = (Colored(who, classFile)), id = id, goal = goal, name = name, t = GetTime() }
        if ns.MapShown() then
            ShowInvite()
        else
            ns.Print(L.SHARE_RECEIVED, invite.colored, name)
        end
        return
    end
    if not (rally and id == rally.id) then return end
    local m = rally.members[who] or {}
    rally.members[who] = m
    if kind == "E1" then
        m.secs, m.total, m.t, m.left = tonumber(f[3]) or 0, tonumber(f[4]), GetTime(), nil
    elseif kind == "A1" then
        m.arrived, m.t = true, GetTime()
    elseif kind == "X1" then
        m.left = true
    end
    ns.Fire("TRAVEL")
end

---------------------------------------------------------------------------
-- Le suivi : le temps envoyé, la fin du ralliement
---------------------------------------------------------------------------
local ticker = CreateFrame("Frame")
local wait = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = ETA_EVERY
    if not rally then return end
    local now = GetTime()
    if not Channel() or now - rally.started > RALLY_MAX then
        EndRally(true)
        return
    end
    if MyRoute() and not rally.mine.arrived then
        local secs = ns.Travel.Remaining()
        if secs then
            rally.mine.total = rally.mine.total or secs
            Send("E1", rally.id, math.floor(secs), math.floor(rally.mine.total))
        end
    end
    -- (arrivé : on attend les autres un moment ; tous là, c'est fini)
    if rally.mine.arrived then
        local all = true
        for _, m in ipairs(GroupMembers()) do
            local data = rally.members[m.name]
            if data and not data.left and not data.arrived and now - (data.t or 0) <= STALE then all = false end
        end
        if all or now - (rally.mine.at or now) > AFTER_ARRIVAL then EndRally(true) end
    end
end)

-- (le trajet du ralliement : arrivé, on le dit ; annulé, on ne vient plus)
ns.On("TRAVEL_ARRIVED", function(goal)
    if rally and goal and goal.rally == rally.id then
        rally.mine.arrived, rally.mine.at = true, GetTime()
        Send("A1", rally.id)
        ns.Fire("TRAVEL")
    end
end)
ns.On("TRAVEL_END", function(goal)
    if rally and goal and goal.rally == rally.id and not rally.mine.arrived then
        Send("X1", rally.id)
        EndRally(false)
    end
end)
ns.On("TRAVEL", function()
    -- (le temps de départ, pour la part du chemin faite)
    if MyRoute() and not rally.mine.total then rally.mine.total = ns.Travel.Remaining() end
end)
ns.On("MAP_SHOW", function() C_Timer.After(0.2, ShowInvite) end)
ns.On("MAP_HIDE", function() if frame then frame:Hide() end end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:SetScript("OnEvent", function(_, event, prefix, text, _, sender)
    -- (en veille, OpenMap On Gamepad chargé aussi : les destinations sont les siennes)
    if ns.Conflict() then return end
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        end
        return
    elseif event == "GROUP_ROSTER_UPDATE" then
        if rally and not Channel() then EndRally(true) end
        return
    end
    if prefix ~= PREFIX or type(text) ~= "string" then return end
    local ok, err = pcall(OnMessage, text, sender)
    if not ok and geterrorhandler then geterrorhandler()(err) end
end)

-- /mmir trajet : le ralliement en cours
function SH.Report()
    local r = SH.Rally()
    if not r then return end
    ns.Print(L.SHARE_REPORT, r.name or "?")
    for _, m in ipairs(r.members) do
        local what = m.arrived and L.HUD_RALLY_HERE or m.secs and ns.RouteHud.Duration(m.secs) or L.HUD_RALLY_NOADDON
        ns.Print("  %s : %s", m.colored or m.name, what)
    end
end
