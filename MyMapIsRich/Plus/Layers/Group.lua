-- Ton groupe et ton raid sur la carte : un point à la couleur de la classe de
-- chacun, cerclé d'or, où qu'il soit sur le monde. En code de My Map Is Rich
-- depuis la 0.9.0 (il venait de Map/Nav.lua, d'OpenMap).
-- Quand le jeu tait la place de quelqu'un (il la garde parfois secrète) mais
-- dit sa zone, son point est pâle, rangé avec les autres de sa zone sous le
-- milieu de celle-ci. Rafraîchi deux fois par seconde, carte ouverte. Le
-- calque Groupe du rail l'allume ou l'éteint (le réglage « group »).
local _, root = ...
local ns = root.Plus
local L = ns.L

local K = ns.Map.Coords
local Pins = ns.Map.Pins
local Settings = ns.Map.Settings

Settings.Own("group", true)

local DOT = { atlas = "WhiteCircle-RaidBlips", texture = "Interface\\Minimap\\PartyRaidBlips" }
-- (le liseré doré distingue ces points des autres : fin, tout contre le point)
local RING_TEXTURE = "Interface\\AddOns\\MyMapIsRich\\Media\\Textures\\GroupRing.tga"
local RING_SIZE = 16
local ROUGH_ALPHA = 0.55        -- le point de quelqu'un dont on ne connaît que la zone
local ROUGH_SPREAD = 0.006      -- (unités du monde) entre ceux connus seulement par leur zone
local EVERY = 0.5               -- s entre deux rafraîchissements

local set
local pins, looks = {}, {}

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Look(unit)
    local _, class = UnitClass(unit)
    class = Plain(class) or "PRIEST"
    local look = looks[class]
    if not look then
        local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
            or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
        look = { atlas = DOT.atlas, texture = DOT.texture, size = 12, color = c and { c.r, c.g, c.b, 1 } or { 1, 1, 1, 1 } }
        looks[class] = look
    end
    return look
end

local function Tooltip(pin)
    GameTooltip:ClearLines()
    GameTooltip:AddLine(Plain(UnitName(pin.unit)) or "?", 1, 1, 1)
    GameTooltip:AddLine(L.GROUP_TITLE, 1, 0.82, 0)
    local info = pin.zone and C_Map.GetMapInfo(pin.zone)
    if info and info.name then GameTooltip:AddLine(L.GROUP_IN_ZONE:format(info.name), 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

local function Enter(pin)
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    Tooltip(pin)
end

local function Leave(pin)
    if GameTooltip:IsOwned(pin) then GameTooltip:Hide() end
end

-- Où est quelqu'un du groupe : u, v quand le jeu le dit ; sinon rien, et sa zone
local function Place(unit)
    local u, v = K.UnitWorld(unit)
    if u then return u, v end
    local ok, best = pcall(C_Map.GetBestMapForUnit, unit)
    best = ok and Plain(best) or nil
    if best and K.Rect(best) then return nil, nil, best end
end

-- Le n-ième connu seulement par cette zone : des rangées de cinq, juste sous son milieu
local function ZoneSpot(zone, n)
    local l, r, t, b = K.Rect(zone)
    local col, row = (n - 1) % 5, math.floor((n - 1) / 5)
    return (l + r) / 2 + col * ROUGH_SPREAD, (t + b) / 2 + (row + 1) * ROUGH_SPREAD
end

local function Clear()
    if set then Pins.Clear(set) end
    wipe(pins)
end

function ns.Map.RefreshGroup()
    if not set and Pins.Ready() then set = Pins.Set("group", 0, 4) end
    if not set then return end
    if Settings.Get("group") == false or not IsInGroup() then
        Clear()
        return
    end
    -- (chacun garde son icône, déplacée : son info-bulle ne clignote pas)
    local raid = IsInRaid()
    local inZone, seen = {}, {}
    for i = 1, raid and 40 or 4 do
        local unit = (raid and "raid" or "party") .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local u, v, zone = Place(unit)
            if zone and not u then
                inZone[zone] = (inZone[zone] or 0) + 1
                u, v = ZoneSpot(zone, inZone[zone])
            end
            if u then
                local id = Plain(UnitGUID(unit)) or unit
                local look = Look(unit)
                local pin = pins[id]
                if pin then
                    Pins.Move(set, pin, u, v)
                    if pin.look ~= look then
                        ns.UI.SetIcon(pin.Icon, look.texture, look.atlas)
                        pin.Icon:SetVertexColor(look.color[1], look.color[2], look.color[3], 1)
                    end
                else
                    pin = Pins.Add(set, u, v, look)
                    if pin and not pin.Ring then
                        pin.Ring = pin:CreateTexture(nil, "BACKGROUND")
                        pin.Ring:SetSize(RING_SIZE, RING_SIZE)
                        pin.Ring:SetPoint("CENTER")
                        pin.Ring:SetTexture(RING_TEXTURE)
                    end
                    if pin then
                        pin:SetScript("OnEnter", Enter)
                        pin:SetScript("OnLeave", Leave)
                        pin:SetScript("OnHide", Leave)
                        -- (rien à presser : le A de la manette zoome dessous)
                        pin.openmapNoPress = true
                    end
                end
                if pin then
                    pin.look, pin.unit, pin.zone = look, unit, zone
                    pin.Icon:SetAlpha(zone and ROUGH_ALPHA or 1)
                    if GameTooltip:IsOwned(pin) then Tooltip(pin) end
                    pins[id] = pin
                    seen[id] = true
                end
            end
        end
    end
    for id, pin in pairs(pins) do
        if not seen[id] then
            Pins.Remove(set, pin)
            pins[id] = nil
        end
    end
end

local ticker = CreateFrame("Frame")
ticker:Hide()
local wait = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = EVERY
    ns.Map.RefreshGroup()
end)

ns.On("MAP_SHOW", function()
    wait = 0
    ticker:Show()
end)
ns.On("MAP_HIDE", function() ticker:Hide() end)
ns.On("MAP_REFRESH", function() ns.Map.RefreshGroup() end)

-- (les ponts : la vue d'OpenMap, Map/PadView.lua, demande aussi un rafraîchissement)
ns.On("MAP_ATTACHED", function()
    ns.Map.Migrate("group", function(old, new)
        if old.group ~= nil then new.settings.group = old.group end
    end)
    local mod = ns.Map.Legacy()
    if mod then mod.RefreshGroup = function() ns.Map.RefreshGroup() end end
end)
