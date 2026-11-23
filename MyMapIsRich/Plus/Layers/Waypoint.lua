-- Le point de destination : ns.Map.Waypoint, en code de My Map Is Rich depuis
-- la 0.9.0 (il venait de Map/Nav.lua, d'OpenMap).
-- Celui du jeu quand le client le prend (son épingle, sa flèche) ; sinon le
-- nôtre, gardé par personnage (MyMapIsRichPlusCharDB.map.waypoint). Et celui
-- de TomTom, s'il est là. Il se montre sur toute la carte, avec son icône à
-- lui, sauf s'il est sur une de tes épingles (Layers/MyPins.lua), qui se
-- montre alors suivie. Un clic sur son icône l'efface ; Maj+clic met le lien
-- du jeu vers lui dans la discussion.
local _, root = ...
local ns = root.Plus
local L = ns.L

local W = ns.Map.Waypoint
local K = ns.Map.Coords
local Pins = ns.Map.Pins

local LOOK = { atlas = "Waypoint-MapPin-Tracked", texture = "Interface\\Minimap\\Ping\\ping5", size = 30 }
local set
local tomtomPoint               -- (le point de TomTom posé pour nous : retiré avec le nôtre)

local function XY(vec)
    if type(vec) ~= "table" then return end
    if vec.GetXY then return vec:GetXY() end
    return vec.x, vec.y
end

local function Char()
    local c = ns.Map.CharDB()
    return c or {}
end

-- Celui du jeu : carte, x, y
local function GamePoint()
    if not (C_Map.HasUserWaypoint and C_Map.GetUserWaypoint) then return end
    local ok, has = pcall(C_Map.HasUserWaypoint)
    if not ok or not has then return end
    local okP, point = pcall(C_Map.GetUserWaypoint)
    if okP and point and point.position then
        local x, y = XY(point.position)
        return point.uiMapID, x, y
    end
end

-- Le point de destination : carte, x, y, et s'il est le nôtre (pas celui du jeu)
function W.Point()
    local mapID, x, y = GamePoint()
    if mapID then return mapID, x, y, false end
    local own = Char().waypoint
    if own then return own[1], own[2], own[3], true end
end

local function ClearTomTom()
    local tomtom = _G.TomTom
    if tomtomPoint and tomtom and tomtom.RemoveWaypoint then pcall(tomtom.RemoveWaypoint, tomtom, tomtomPoint) end
    tomtomPoint = nil
end

local function Enter(self)
    local mapID, x, y, own = W.Point()
    if not mapID then return end
    local info = C_Map.GetMapInfo(mapID)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.WAYPOINT, 1, 0.82, 0)
    GameTooltip:AddLine(("%s  %.1f, %.1f"):format(info and info.name or "", x * 100, y * 100), 1, 1, 1)
    GameTooltip:AddLine(L.WAYPOINT_CLICK, 0.6, 0.6, 0.6)
    if not own then GameTooltip:AddLine(L.PINS_SHIFT_CHAT, 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

-- Son icône : un clic l'efface, Maj+clic met le lien du jeu dans la discussion
local function Click()
    if IsModifiedClick and IsModifiedClick("CHATLINK") then
        local ok, link = pcall(C_Map.GetUserWaypointHyperlink or nop)
        if ok and link then
            local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
            if insert then insert(link) end
        end
        return
    end
    W.Clear()
end

-- Son icône redessinée (et les épingles : celle qui le porte se montre suivie)
function W.Refresh()
    if not set and Pins.Ready() then set = Pins.Set("waypoint", 0, 5) end
    ns.Map.MyPins.Refresh()
    if not set then return end
    Pins.Clear(set)
    local mapID, x, y = W.Point()
    if not mapID then return end
    if ns.Map.MyPins.At(mapID, x, y) then return end   -- (l'épingle le montre)
    local u, v = K.ToWorld(mapID, x, y)
    local pin = u and Pins.Add(set, u, v, LOOK)
    if not pin then return end
    pin:SetScript("OnEnter", Enter)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    pin.OnClick = Click
end

-- Suivre un point d'une carte : celui du jeu s'il le prend, sinon le nôtre ;
-- et celui de TomTom. title : son nom chez TomTom (sinon le nom de la carte)
function W.Track(mapID, x, y, title)
    if not (mapID and x and y) then return false end
    local info = C_Map.GetMapInfo(mapID)
    local game = false
    if C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates
        and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(mapID)) then
        game = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x, y)) and GamePoint() ~= nil
        if game and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
        end
    end
    local char = ns.Map.CharDB()
    if char then char.waypoint = not game and { mapID, x, y } or nil end
    local tomtom = _G.TomTom
    ClearTomTom()
    if tomtom and tomtom.AddWaypoint then
        local name = (title and title ~= "") and title or (info and info.name) or "My Map Is Rich"
        local ok, point = pcall(tomtom.AddWaypoint, tomtom, mapID, x, y, { title = name, from = "My Map Is Rich" })
        if ok then tomtomPoint = point end
    end
    W.Refresh()
    return true
end

-- Plus suivi
function W.Clear()
    if C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
    local char = ns.Map.CharDB()
    if char then char.waypoint = nil end
    ClearTomTom()
    W.Refresh()
end

function W.CanTrack() return true end

---------------------------------------------------------------------------
-- La migration du point d'OpenMap (MyMapIsRichCharDB.worldmap.pin)
---------------------------------------------------------------------------
ns.On("MAP_ATTACHED", function()
    ns.Map.Migrate("waypoint", function(old, new, copy)
        if type(old.pin) == "table" and old.pin[1] then new.waypoint = copy(old.pin) end
    end, true)
end)

ns.On("MAP_BUILT", function() W.Refresh() end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if ns.Conflict() then return end
        pcall(self.RegisterEvent, self, "USER_WAYPOINT_UPDATED")
        pcall(self.RegisterEvent, self, "SUPER_TRACKING_CHANGED")
    elseif ns.Map.IsBuilt() then
        W.Refresh()
    end
end)
