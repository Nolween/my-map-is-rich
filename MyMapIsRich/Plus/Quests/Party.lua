-- Le progrès du groupe : chacun de ceux qui ont My Map Is Rich envoie au
-- groupe l'avancée de ses quêtes ; le suivi des quêtes (UI/Tracker.lua) la
-- montre sous les quêtes que vous avez en commun (« Pam : 3/8 · 0/1 »).
-- Les messages (préfixe MMIRQuest, à lui seul : ceux d'OpenMap et d'OpenMap
-- On Gamepad ne changent pas ; champs séparés par des tabulations) :
--   P1 questID fini parts   l'avancée d'une quête : fini 1 ou 0, parts
--                           « a/b,a/b » (un objectif sans compte : 1/1 ou 0/1)
--   X1 questID              la quête a quitté son journal
--   R1                      « envoyez-moi tout » (à l'arrivée dans un groupe)
-- Une quête n'est envoyée que quand elle change, un message toutes les
-- 0,2 s au plus. Aussi dans un donjon (c'est là que le groupe en a besoin).
-- Rien n'est envoyé en veille (ns.Conflict), ni le réglage « Progrès du
-- groupe » coupé.
--   Party.Of(questID)   { { name, colored, done, parts = { { have, need } } } }
local _, root = ...
local ns = root.Plus

ns.Quests = ns.Quests or {}
local Party = {}
ns.Quests.Party = Party

local Log = ns.Quests.Log

local PREFIX = "MMIRQuest"
local SEND_EVERY = 0.2          -- s entre deux messages
local RESEND_GAP = 5            -- s : plusieurs « envoyez-moi tout » rapprochés, un seul envoi

local sent = {}                 -- questID -> ce qui a été envoyé (P1 sans son questID)
local outbox = {}               -- les messages à envoyer, dans l'ordre
local others = {}               -- nom court -> { [questID] = { done, parts } }
local resentAt = -100
local wasGrouped = false

local function On()
    return ns.db and ns.db.options.trackerParty ~= false and not ns.Conflict()
end

---------------------------------------------------------------------------
-- Le groupe
---------------------------------------------------------------------------
local function Channel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end

-- Le prénom seul : sur Forever, un personnage a un prénom et un nom
-- (« Pam Aleybzez »), et le jeu ne les donne pas toujours ensemble (UnitName :
-- le prénom ; l'expéditeur d'un message : peut-être les deux, et le royaume).
-- Comparés par le prénom, les deux se retrouvent
local function Short(name)
    name = name or ""
    if Ambiguate then name = Ambiguate(name, "short") or name end
    return name:match("^[^%s%-]+") or name
end

-- Les membres du groupe (sans toi) : nom court -> sa classe
local function Members()
    local out = {}
    local raid = IsInRaid and IsInRaid()
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    for i = 1, n do
        local unit = raid and ("raid" .. i) or ("party" .. i)
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local name = UnitName(unit)
            if name then out[Short(name)] = select(2, UnitClass(unit)) or false end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Envoyer
---------------------------------------------------------------------------
local function Push(...)
    outbox[#outbox + 1] = table.concat({ ... }, "\t")
end

-- L'avancée d'une quête : fini, et « a/b,a/b »
local function State(q)
    local parts = {}
    for _, o in ipairs(Log.Objectives(q.id, q.index)) do
        local have, need = tonumber(o.have), tonumber(o.need)
        if not (have and need and need > 0) then
            have, need = o.finished and 1 or 0, 1
        end
        parts[#parts + 1] = math.floor(have) .. "/" .. math.floor(need)
    end
    return (q.complete and "1" or "0") .. "\t" .. table.concat(parts, ",")
end

-- Ce qui a changé depuis le dernier envoi
local function Diff()
    if not (On() and Channel()) then return end
    local log = Log.Quests()
    for id, q in pairs(log) do
        local state = State(q)
        if sent[id] ~= state then
            sent[id] = state
            Push("P1", id, state)
        end
    end
    for id in pairs(sent) do
        if not log[id] then
            sent[id] = nil
            Push("X1", id)
        end
    end
end

-- Tout, de nouveau (quelqu'un arrive dans le groupe)
local function ResendAll()
    local now = GetTime()
    if now - resentAt < RESEND_GAP then return end
    resentAt = now
    wipe(sent)
    Diff()
end

local ticker = CreateFrame("Frame")
local wait = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = SEND_EVERY
    local msg = table.remove(outbox, 1)
    if not msg then
        self:Hide()
        return
    end
    local channel = Channel()
    if not (channel and C_ChatInfo and C_ChatInfo.SendAddonMessage) then
        wipe(outbox)
        return
    end
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel)
end)
ticker:Hide()

local function Flush()
    if #outbox > 0 then ticker:Show() end
end

---------------------------------------------------------------------------
-- Recevoir
---------------------------------------------------------------------------
local function OnMessage(text, sender)
    local who = Short(sender)
    if who == Short(UnitName("player")) then return end
    local f = { strsplit("\t", text) }
    local kind = f[1]
    if kind == "R1" then
        ResendAll()
        Flush()
        return
    end
    local id = tonumber(f[2])
    if not id then return end
    others[who] = others[who] or {}
    if kind == "P1" then
        local parts = {}
        for have, need in (f[4] or ""):gmatch("(%d+)/(%d+)") do parts[#parts + 1] = { tonumber(have), tonumber(need) } end
        others[who][id] = { done = f[3] == "1", parts = parts }
    elseif kind == "X1" then
        others[who][id] = nil
    else
        return
    end
    ns.Fire("QUESTS_PARTY")
end

-- Ceux du groupe qui ont cette quête : { { name, colored, done, parts } },
-- par nom
function Party.Of(questID)
    local out = {}
    if not (On() and Channel()) then return out end
    local members = Members()
    for name, quests in pairs(others) do
        local q = quests[questID]
        if q and members[name] ~= nil then
            out[#out + 1] = { name = name, colored = ns.UI.ClassColored(name, members[name] or nil),
                done = q.done, parts = q.parts }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

---------------------------------------------------------------------------
-- Les événements
---------------------------------------------------------------------------
local function Roster()
    local grouped = Channel() ~= nil
    if grouped and not wasGrouped then
        -- (arrivé dans un groupe : on demande tout, et on envoie tout)
        wasGrouped = true
        if On() then
            Push("R1")
            ResendAll()
            Flush()
        end
    elseif not grouped and wasGrouped then
        wasGrouped = false
        wipe(sent)
        wipe(outbox)
        wipe(others)
        ns.Fire("QUESTS_PARTY")
        return
    end
    -- (ceux qui sont partis : oubliés)
    local members, gone = Members(), false
    for name in pairs(others) do
        if members[name] == nil then
            others[name] = nil
            gone = true
        end
    end
    if gone then ns.Fire("QUESTS_PARTY") end
end

ns.On("QUESTS_CHANGED", function()
    Diff()
    Flush()
end)
-- (le réglage remis : tout est renvoyé)
ns.On("OPTIONS", function()
    if On() and Channel() and next(sent) == nil then
        ResendAll()
        Flush()
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:SetScript("OnEvent", function(_, event, prefix, text, _, sender)
    if ns.Conflict() then return end
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        end
        -- (un /reload dans un groupe : comme une arrivée)
        C_Timer.After(3, Roster)
        return
    elseif event == "GROUP_ROSTER_UPDATE" then
        Roster()
        return
    end
    if prefix ~= PREFIX or type(text) ~= "string" or not On() then return end
    local ok, err = pcall(OnMessage, text, sender)
    if not ok and geterrorhandler then geterrorhandler()(err) end
end)
