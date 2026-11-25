-- Ton corps sur la carte : mort ou en fantôme, la pierre tombale du jeu là où
-- il est tombé, pour aller le retrouver. Le jeu la dessine sur sa propre
-- carte, qui est sous la nôtre et cachée : on la redessine. Le jeu ne sait
-- où est le corps qu'un instant après la libération, sans événement pour le
-- dire : carte ouverte, la place est relue chaque seconde. Rien quand tu es
-- vivant. Le trajet jusqu'au corps, lui, est dans Travel/Guide.lua.
local _, root = ...
local ns = root.Plus
local L = ns.L

local K = ns.Map.Coords
local Pins = ns.Map.Pins

-- (la pierre tombale des cimetières du jeu ; sinon la tête de mort des cibles)
local LOOK = { atlas = "poi-graveyard-neutral", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    size = 24 }
local EVERY = 1                 -- s entre deux lectures, carte ouverte

local set, pin
local last                      -- { u, v, map } : la dernière place connue du corps

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Dead()
    return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") and true or false
end

-- Où est le corps : sur la carte où est le joueur, sinon sur celles qui la
-- contiennent (la zone, le continent). u, v (unités du monde), et sa carte
local function Find()
    if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition and C_Map and C_Map.GetBestMapForUnit) then return end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    mapID = ok and Plain(mapID) or nil
    local guard = 0
    while mapID and guard < 6 do
        guard = guard + 1
        local okP, pos = pcall(C_DeathInfo.GetCorpseMapPosition, mapID)
        if okP and pos then
            local okXY, x, y = pcall(pos.GetXY, pos)
            x, y = okXY and Plain(x), okXY and Plain(y)
            if x and y and (x ~= 0 or y ~= 0) then
                local u, v = K.ToWorld(mapID, x, y)
                if u then return u, v, mapID end
            end
        end
        local okI, info = pcall(C_Map.GetMapInfo, mapID)
        mapID = okI and type(info) == "table" and info.parentMapID or nil
        if mapID == 0 then mapID = nil end
    end
end

local function Tooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.CORPSE_TITLE, 1, 0.82, 0)
    local info = last and last.map and C_Map.GetMapInfo(last.map)
    if info and info.name then GameTooltip:AddLine(info.name, 1, 1, 1) end
    GameTooltip:Show()
end

local function Leave(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function Clear()
    if set and pin then Pins.Remove(set, pin) end
    pin = nil
end

function ns.Map.RefreshCorpse()
    if not set and Pins.Ready() then set = Pins.Set("corpse", 0, 6) end
    if not set then return end
    if not Dead() then
        last = nil
        Clear()
        return
    end
    -- (le corps lu ailleurs, sur un autre continent : sa dernière place reste)
    local u, v, map = Find()
    if u then last = { u = u, v = v, map = map } end
    if not last then
        Clear()
        return
    end
    if pin then
        Pins.Move(set, pin, last.u, last.v)
        return
    end
    pin = Pins.Add(set, last.u, last.v, LOOK)
    if not pin then return end
    pin:SetScript("OnEnter", Tooltip)
    pin:SetScript("OnLeave", Leave)
    pin:SetScript("OnHide", Leave)
    -- (rien à presser : le A de la manette zoome dessous)
    pin.openmapNoPress = true
end

local ticker = CreateFrame("Frame")
ticker:Hide()
local wait = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = EVERY
    ns.Map.RefreshCorpse()
end)

ns.On("MAP_SHOW", function()
    wait = 0
    ticker:Show()
end)
ns.On("MAP_HIDE", function() ticker:Hide() end)
ns.On("MAP_BUILT", function() ns.Map.RefreshCorpse() end)
ns.On("MAP_REFRESH", function() ns.Map.RefreshCorpse() end)

-- (mort, libéré, ressuscité : la place change ou s'efface, même carte fermée)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_UNGHOST")
events:SetScript("OnEvent", function()
    if ns.Conflict() or not (ns.Map.IsBuilt and ns.Map.IsBuilt()) then return end
    ns.Map.RefreshCorpse()
    C_Timer.After(1, ns.Map.RefreshCorpse)
end)
