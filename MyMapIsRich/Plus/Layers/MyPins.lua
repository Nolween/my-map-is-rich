-- Les épingles du joueur : ns.Map.MyPins, en code de My Map Is Rich depuis la
-- 0.7.0 (elles venaient de Map/Pins.lua, d'OpenMap).
--
-- Autant d'épingles qu'on veut, chacune avec sa note et sa couleur, gardées
-- pour tous les personnages (MyMapIsRichPlusDB.map.pins). Ctrl+clic sur la
-- carte, la roue (Poser une épingle) ou la fiche d'un point en posent une ; la
-- nouvelle est suivie (le point de destination du jeu et sa flèche, et celui
-- de TomTom) et sa fiche s'ouvre pour sa note (Layers/PinsWindow.lua).
-- Le partage : au groupe, à la guilde ou en chuchotement à sa cible, par des
-- messages d'addon que My Map Is Rich et OpenMap lisent tous les deux (le
-- format ne change pas : « P1 », carte, x, y, couleur, note) ; ou par un code
-- à copier-coller n'importe où (« OMPINS1: », le même qu'OpenMap).
-- Une épingle : { id, map (uiMapID), x, y (sur cette carte, 0..1), note,
-- color (COLORS), from (qui l'a partagée), at (time()) }
--
-- Le reste du code venu d'OpenMap (la plume, le point de destination, la vue)
-- appelle encore mod.RefreshPins, mod.PinAt, mod.AddPin... : les ponts, en
-- bas, le leur rendent (ns.Map.Legacy). Ils partiront avec ces modules.
local _, root = ...
local ns = root.Plus
local L = ns.L

local E = ns.Map.MyPins
local K = ns.Map.Coords
local Settings = ns.Map.Settings

local PREFIX = "OpenMap"        -- (le préfixe des messages d'addon : celui d'OpenMap, qu'il lit aussi)
local CODE = "OMPINS1:"         -- (le début d'un code d'épingles à coller)
local NOTE_MAX = 160            -- caractères d'une note
local SHARE_MAX = 100           -- épingles d'un même partage, au plus
local SEND_GAP = 0.3            -- s entre deux messages envoyés (le jeu retient une rafale)
local ASK_AFTER = 1.5           -- s après la dernière épingle reçue d'un joueur avant de demander
local NEAR = 5e-4               -- (deux points si proches sur une carte n'en font qu'un)

E.NOTE_MAX = NOTE_MAX
E.CODE = CODE

-- Les couleurs : { clé du nom, r, g, b } ; la première laisse l'épingle telle quelle
E.COLORS = {
    { "PINS_COLOR_GOLD" },
    { "PINS_COLOR_RED", 1, 0.38, 0.32 },
    { "PINS_COLOR_GREEN", 0.5, 0.95, 0.4 },
    { "PINS_COLOR_BLUE", 0.45, 0.72, 1 },
    { "PINS_COLOR_PURPLE", 0.82, 0.55, 1 },
}
E.MARK = { atlas = "Waypoint-MapPin-Untracked", texture = "Interface\\Minimap\\Ping\\ping5", size = 24 }
local FOLLOWED = { atlas = "Waypoint-MapPin-Tracked", texture = "Interface\\Minimap\\Ping\\ping5", size = 30 }

-- Les réglages repris de la carte d'OpenMap (l'onglet Carte de /mmir, le rail des calques)
Settings.Own("pinsShared", true)        -- les épingles des autres arrivent (on te demande d'abord)
Settings.Own("pinsHidden", false)       -- tes épingles cachées de la carte (la liste les garde)
Settings.Own("pinsFollowNew", true)     -- une épingle posée est suivie
Settings.Own("pinsShareGroup", false)   -- une épingle posée part au groupe quand sa fiche se ferme
Settings.Own("pinsGroupAdd", false)     -- celles du groupe ajoutées sans demander

local fresh = {}                -- les épingles tout juste posées : partagées au groupe quand leur fiche se ferme
local set                       -- leur jeu d'icônes sur la carte
local looks = {}                -- (l'allure de chaque couleur, suivie ou non : faite une fois)

local function DB()
    local db = ns.Map.DB()
    if not db then return { list = {}, nextId = 1 } end
    db.pins = db.pins or { list = {}, nextId = 1 }
    return db.pins
end

function E.List() return DB().list end

function E.ZoneName(mapID)
    local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or "?"
end

-- « Zone  12.3, 45.6 »
function E.Place(p) return ("%s  %.1f, %.1f"):format(E.ZoneName(p.map), p.x * 100, p.y * 100) end

local function Round(v) return math.floor(v * 1e4 + 0.5) / 1e4 end

-- Une note en texte simple : ni caractère de contrôle, ni code d'échappement
-- (« | » : liens, couleurs), coupée (pas au milieu d'un caractère)
function E.Clean(text)
    text = tostring(text or ""):gsub("%c", " "):gsub("|", "/")
    text = strtrim(text)
    if #text > NOTE_MAX then text = text:sub(1, NOTE_MAX):gsub("[\192-\255][\128-\191]*$", "") end
    return text
end
local Clean = E.Clean

local function Same(p, mapID, x, y)
    return p.map == mapID and math.abs(p.x - x) < NEAR and math.abs(p.y - y) < NEAR
end

-- L'épingle à un point d'une carte
function E.At(mapID, x, y)
    if not (mapID and x and y) then return end
    for _, p in ipairs(DB().list) do
        if Same(p, mapID, x, y) then return p end
    end
end

-- L'épingle est-elle suivie (le point de destination est sur elle) ?
function E.Followed(p)
    local mapID, x, y = ns.Map.Waypoint.Point()
    return mapID and x and Same(p, mapID, x, y) or false
end

function E.Follow(p)
    ns.Map.Waypoint.Track(p.map, p.x, p.y, p.note ~= "" and p.note or nil)
end

function E.Unfollow() ns.Map.Waypoint.Clear() end

local function Insert(mapID, x, y, note, color, from)
    local db = DB()
    local p = { id = db.nextId, map = mapID, x = Round(x), y = Round(y), note = Clean(note),
        color = E.COLORS[color or 1] and color or 1, from = from, at = time() }
    db.nextId = db.nextId + 1
    table.insert(db.list, p)
    return p
end

-- Une épingle retirée : plus suivie, son dessin avec elle
function E.Remove(p)
    if E.Followed(p) then E.Unfollow() end
    fresh[p] = nil
    local list = DB().list
    for i = #list, 1, -1 do
        if list[i] == p then table.remove(list, i) end
    end
    ns.Map.Sketch.Drop(p.id)
end

function E.RemoveAll()
    local list = DB().list
    for i = #list, 1, -1 do E.Remove(list[i]) end
    E.Refresh()
end

---------------------------------------------------------------------------
-- Sur la carte
---------------------------------------------------------------------------
function E.Look(color, followed)
    local key = (color or 1) .. (followed and "f" or "")
    if not looks[key] then
        local base, c = followed and FOLLOWED or E.MARK, E.COLORS[color or 1] or E.COLORS[1]
        looks[key] = { atlas = base.atlas, texture = base.texture, size = base.size, color = c[2] and { c[2], c[3], c[4] } or nil }
    end
    return looks[key]
end

local function PinEnter(self)
    local p = self.data
    if not p then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(p.note ~= "" and p.note or L.PINS_PIN, 1, 0.82, 0, true)
    GameTooltip:AddLine(E.Place(p), 1, 1, 1)
    if p.from then GameTooltip:AddLine(L.PINS_SHARED_BY:format(p.from), 0.6, 0.8, 1) end
    if E.Followed(p) then GameTooltip:AddLine(L.PINS_FOLLOWED, 0.5, 0.95, 0.4) end
    GameTooltip:AddLine(L.PINS_PIN_CLICK, 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine(L.PINS_SHIFT_CHAT, 0.6, 0.6, 0.6)
    GameTooltip:AddLine(L.PINS_ALT_DELETE, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function Chatting() return IsModifiedClick and IsModifiedClick("CHATLINK") end

-- Maj+clic (le clic du jeu pour un lien) : l'épingle dans la discussion. Le
-- lien de point de destination du jeu quand il en prend un sur cette carte
-- (qui le clique reçoit le point ; le point de destination est posé le temps
-- du lien, puis remis), avec la note ; sinon la note et la place, en texte
function E.ChatLink(p)
    local link
    if C_Map.GetUserWaypointHyperlink and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates
        and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(p.map)) then
        local before = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
        if pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(p.map, p.x, p.y)) then
            local ok, l = pcall(C_Map.GetUserWaypointHyperlink)
            if ok and type(l) == "string" and l ~= "" then link = l end
        end
        if before then pcall(C_Map.SetUserWaypoint, before) elseif C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
    end
    local note = (p.note or ""):gsub("|", "||")
    local place = ("%s %.1f, %.1f"):format(E.ZoneName(p.map), p.x * 100, p.y * 100)
    local text = link and (note ~= "" and (link .. " " .. note) or link) or (note ~= "" and (note .. " (" .. place .. ")") or place)
    local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
    local open = _G.ChatFrame_OpenChat
    if not (insert and insert(text)) and open then open(text) end
end

-- Un clic sur une épingle de la carte (ou A sur sa fiche : Pins.Action)
local function PinClick(self)
    local p = self and self.data
    if not p then return end
    if IsAltKeyDown() then                 -- (partie tout de suite : beaucoup d'épingles se retirent vite)
        GameTooltip:Hide()
        E.Remove(p)
        E.Refresh()
    elseif Chatting() then
        E.ChatLink(p)
    elseif ns.PinsWindow then
        ns.PinsWindow.Edit(p)
    end
end

function E.Hidden() return Settings.Get("pinsHidden") and true or false end

-- Les épingles redessinées sur la carte (et la liste, la fiche ouverte)
function E.Refresh()
    if not set and ns.Map.Pins.Ready() then set = ns.Map.Pins.Set("userpins", 0, 5) end
    if set then
        ns.Map.Pins.Clear(set)
        for _, p in ipairs(DB().list) do
            local u, v = K.ToWorld(p.map, p.x, p.y)
            if u then
                local pin = ns.Map.Pins.Add(set, u, v, E.Look(p.color, E.Followed(p)), p)
                if pin then
                    pin:SetScript("OnEnter", PinEnter)
                    pin:SetScript("OnLeave", GameTooltip_Hide)
                    pin.OnClick = PinClick
                end
            end
        end
        ns.Map.Pins.SetOn(set, not E.Hidden())
    end
    if ns.PinsWindow then ns.PinsWindow.Refresh() end
end

-- Tes épingles cachées de la carte, ou remontrées (le rail des calques)
function E.SetHidden(hidden)
    hidden = hidden and true or false
    Settings.Set("pinsHidden", hidden)
    -- (la plume d'OpenMap lit encore sa propre clé : ses dessins sur les épingles suivent)
    local mod = ns.Map.Legacy()
    if mod and mod.db then mod.db.pinsHidden = hidden end
    E.Refresh()
    ns.Map.Sketch.Redraw()
end

-- Une nouvelle épingle là où l'on a cliqué : suivie, et sa fiche ouverte pour
-- sa note (tes épingles remontrées si elles étaient cachées : sinon elle
-- serait posée hors de vue)
function E.Add(mapID, x, y)
    if not (mapID and x and y) then return end
    if E.Hidden() then E.SetHidden(false) end
    local p = Insert(mapID, x, y, "")
    if Settings.Get("pinsFollowNew") ~= false then E.Follow(p) end
    fresh[p] = true
    E.Refresh()
    if ns.PinsWindow then ns.PinsWindow.Edit(p) end
    return p
end
function E.CanAdd() return true end

-- La fiche d'une épingle refermée : sa note et sa couleur gardées (save) ;
-- une épingle tout juste posée part alors au groupe (pinsShareGroup)
function E.Done(p, save, note, color)
    if not p then return end
    if save then
        p.note = Clean(note or p.note)
        p.color = E.COLORS[color or p.color] and (color or p.color) or 1
        if E.Followed(p) then E.Follow(p) end   -- (le titre chez TomTom suit la note)
    end
    if fresh[p] then
        fresh[p] = nil
        if save and Settings.Get("pinsShareGroup") and E.Channel("group") then E.Share({ p }, "group") end
    end
    E.Refresh()
end

-- La carte glisse jusqu'à une épingle
function E.GoTo(p)
    local u, v = K.ToWorld(p.map, p.x, p.y)
    if not u then return end
    if ns.MapNav and ns.MapNav.SetFollow then ns.MapNav.SetFollow(false) end
    local _, _, zoom = ns.Map.View.Now()
    local fit = ns.Map.View.FitZoom(p.map)
    ns.Map.View.Glide(u, v, math.max(zoom or 1, (fit or 1) * 1.5))
end

-- La liste des épingles ouverte ou fermée (la carte ouverte d'abord)
function E.Toggle(show)
    if ns.PinsWindow then ns.PinsWindow.ToggleList(show) end
end
function E.Frame() return ns.PinsWindow and ns.PinsWindow.ListFrame() end

---------------------------------------------------------------------------
-- Le partage : des messages d'addon (« P1 », carte, x, y, couleur, note,
-- séparés par des tabulations, 255 octets au plus), quelques-uns par
-- seconde ; et un code d'épingles (CODE, puis carte,x,y,couleur,note de
-- chacune, « % », « , » et « ; » de la note écrits %XX, séparées par « ; »)
---------------------------------------------------------------------------
local queue = {}                -- { message, canal, cible }
local sender = CreateFrame("Frame")
sender:Hide()
local wait = 0
sender:SetScript("OnUpdate", function(self, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    local m = table.remove(queue, 1)
    if not m then
        self:Hide()
        return
    end
    wait = SEND_GAP
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, m[1], m[2], m[3])
end)

local function Message(p)
    local head = ("P1\t%d\t%.4f\t%.4f\t%d\t"):format(p.map, p.x, p.y, p.color or 1)
    local note = p.note or ""
    if #head + #note > 255 then note = note:sub(1, 255 - #head):gsub("[\192-\255][\128-\191]*$", "") end
    return head .. note
end

-- Où un partage peut aller maintenant : "group", "guild", "target" ; le canal
-- et la cible d'un chuchotement, ou rien
function E.Channel(to)
    if to == "group" then
        if IsInRaid() then return "RAID" end
        if IsInGroup() then return "PARTY" end
    elseif to == "guild" then
        if IsInGuild() then return "GUILD" end
    elseif to == "target" then
        if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
            return "WHISPER", GetUnitName("target", true)
        end
    end
end

function E.Share(pins, to)
    local channel, target = E.Channel(to)
    if not channel or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) or #pins == 0 then return end
    for _, p in ipairs(pins) do queue[#queue + 1] = { Message(p), channel, target } end
    sender:Show()
    local who = target or (to == "group" and L.PINS_YOUR_GROUP) or (to == "guild" and L.PINS_YOUR_GUILD) or "?"
    ns.Print(L.PINS_SHARING, #pins, who)
end

local function Escape(note) return (note:gsub("[%%,;]", function(c) return ("%%%02X"):format(c:byte()) end)) end
local function Unescape(note) return (note:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end

function E.CodeOf(pins)
    local parts = {}
    for _, p in ipairs(pins) do
        parts[#parts + 1] = ("%d,%.4f,%.4f,%d,%s"):format(p.map, p.x, p.y, p.color or 1, Escape(p.note or ""))
    end
    return CODE .. table.concat(parts, ";")
end

-- Les champs d'une épingle reçue (message ou code), vérifiés : une carte du
-- monde de la carte, un point dessus
local function Valid(m, x, y, color, note)
    m, x, y, color = tonumber(m), tonumber(x), tonumber(y), tonumber(color)
    if not (m and x and y) or x < 0 or x > 1 or y < 0 or y > 1 or not K.Rect(m) then return end
    return { map = m, x = Round(x), y = Round(y), color = E.COLORS[color or 1] and color or 1, note = Clean(note) }
end

-- Les épingles pas déjà là (même place, même note) ajoutées : combien
function E.AddAll(pins, from)
    local n = 0
    for _, q in ipairs(pins) do
        local dup = false
        for _, p in ipairs(DB().list) do
            if Same(p, q.map, q.x, q.y) and p.note == q.note then
                dup = true
                break
            end
        end
        if not dup then
            Insert(q.map, q.x, q.y, q.note, q.color, from)
            n = n + 1
        end
    end
    E.Refresh()
    return n
end

function E.FromCode(text)
    local body = tostring(text or ""):match(CODE:gsub("%p", "%%%0") .. "(%S+)")
    if not body then return end
    local pins = {}
    for part in body:gmatch("[^;]+") do
        local m, x, y, color, note = strsplit(",", part, 5)
        local q = Valid(m, x, y, color, Unescape(note or ""))
        if q then pins[#pins + 1] = q end
        if #pins >= SHARE_MAX * 5 then break end
    end
    return pins
end

-- Les épingles qu'un joueur partage : gardées un instant après la dernière,
-- puis on te demande pour toutes (UI : ns.PinsWindow.AskShared)
local incoming = {}             -- joueur -> { from, pins, at, group }
local asking = false
function E.SetAsking(on) asking = on and true or false end

local waiter = CreateFrame("Frame")
waiter:Hide()
waiter:SetScript("OnUpdate", function(self)
    if asking then return end
    local now = GetTime()
    for from, batch in pairs(incoming) do
        if now - batch.at > ASK_AFTER then
            incoming[from] = nil
            if batch.group and Settings.Get("pinsGroupAdd") then
                local n = E.AddAll(batch.pins, batch.from)
                if n > 0 then ns.Print(L.PINS_ADDED, n, batch.from) end
            elseif ns.PinsWindow then
                asking = true
                ns.PinsWindow.AskShared(batch)
                return
            end
        end
    end
    if not next(incoming) then self:Hide() end
end)

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function OnAddonMessage(prefix, text, channel, from)
    if prefix ~= PREFIX then return end
    text, from = Plain(text), Plain(from)
    if type(text) ~= "string" or type(from) ~= "string" then return end
    local name = Ambiguate(from, "none")
    if name == UnitName("player") then return end      -- (les tiennes, envoyées à ton groupe ou ta guilde)
    local kind, m, x, y, color, note = strsplit("\t", text, 6)
    -- (« V1 » : la version d'OpenMap de l'envoyeur, que My Map Is Rich ne lit pas)
    if kind ~= "P1" or not Settings.Get("pinsShared") then return end
    local q = Valid(m, x, y, color, note or "")
    if not q then return end
    -- (envoyée à ton groupe ou ton raid, donc de quelqu'un qui en est : sans demander, avec pinsGroupAdd)
    local group = channel == "PARTY" or channel == "RAID"
    local batch = incoming[name] or { from = name, pins = {}, group = group }
    incoming[name] = batch
    if #batch.pins >= SHARE_MAX then return end
    batch.pins[#batch.pins + 1] = q
    batch.at = GetTime()
    waiter:Show()
end

---------------------------------------------------------------------------
-- Les ponts vers le code d'OpenMap qui reste (la plume, le point de
-- destination, la vue) : ce qu'il appelait dans Map/Pins.lua
---------------------------------------------------------------------------
local function Bridge()
    local mod = ns.Map.Legacy()
    if not mod then return end
    mod.RefreshPins = function() E.Refresh() end                     -- (Map/Nav.lua, Map/Sketch.lua)
    mod.PinAt = function(mapID, x, y) return E.At(mapID, x, y) end   -- (Map/Nav.lua : le point de destination sur une épingle)
    mod.AddPin = function(mapID, x, y) return E.Add(mapID, x, y) end -- (Map/Nav.lua : Ctrl+clic, le mode épingle)
    mod.SetPinsHidden = function(hidden) E.SetHidden(hidden) end
    mod.PinsHidden = function() return E.Hidden() end
    mod.TogglePins = function(_, on) E.Toggle(on) end                -- (/mmir carte pins)
    mod.SetupPins = function() end                                   -- (Map/PadView.lua : un clic sur l'épingle ouvre sa fiche)
    -- (la plume : son bouton Fini, et ses changements, pour la fiche ouverte)
    mod.FinishPin = function() if ns.PinsWindow then ns.PinsWindow.FinishDrawing() end end
    mod.OnSketchChanged = function() if ns.PinsWindow then ns.PinsWindow.DrawingChanged() end end
    if mod.db then mod.db.pinsHidden = E.Hidden() end
end

---------------------------------------------------------------------------
-- La migration : les épingles d'OpenMap (MyMapIsRichDB.worldmap.pins) et
-- leurs réglages, copiés une fois ; l'ancien n'est pas effacé
---------------------------------------------------------------------------
local function Migrate()
    ns.Map.Migrate("pins", function(old, new, copy)
        if type(old.pins) == "table" and type(old.pins.list) == "table" then
            new.pins = { list = copy(old.pins.list), nextId = tonumber(old.pins.nextId) or (#old.pins.list + 1) }
        end
        for _, key in ipairs({ "pinsShared", "pinsHidden", "pinsFollowNew", "pinsShareGroup", "pinsGroupAdd" }) do
            if old[key] ~= nil then new.settings[key] = old[key] end
        end
    end)
end

ns.On("MAP_ATTACHED", function()
    Migrate()
    Bridge()
end)

-- (la carte dessinée à sa première ouverture : les épingles posées dès qu'elle l'est)
ns.On("MAP_BUILT", function() E.Refresh() end)
ns.On("MAP_SHOW", function() if ns.Map.IsBuilt() then E.Refresh() end end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if root.dormant then return end
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    elseif event == "CHAT_MSG_ADDON" then
        if root.dormant or not ns.db then return end
        pcall(OnAddonMessage, ...)
    end
end)
