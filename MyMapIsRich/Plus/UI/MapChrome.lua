-- L'habillage de la carte plein écran (maquettes « La carte en plein écran »
-- et « L'habillage de la carte ») :
--   en haut à gauche  : la zone sous le curseur (sinon au centre de la vue),
--                       son continent ; dessous, le panneau de trajet
--   en haut au milieu : « Aller à… » (pour l'instant le navigateur de lieux,
--                       sur sa recherche) ; LB à la manette, Ctrl+F au clavier
--   en haut à droite  : Quêtes (UI/QuestPanel.lua), Me localiser, Me suivre,
--                       le menu de la carte, Fermer
--   en bas à droite   : les coordonnées (toi ; le curseur et sa zone)
--   au bord           : « Toi », quand ta flèche sort de la vue (clic : recentre)
-- Le rail des calques est à part (UI/Layers.lua) ; la barre d'aide aussi
-- (UI/HintBar.lua).
-- Tout est posé sur la vue de la carte (Map/PadView.lua : mod.ViewFrame),
-- au-dessus de l'art et de ta flèche, sous le curseur de la manette. Chaque
-- bande est donnée au curseur de la manette (mod.padRoots) : A la presse.
-- À la souris, un clic sur la carte avec Maj : l'itinéraire jusque-là ; avec
-- Ctrl : une épingle ; avec Alt : le menu des actions (mod.OnViewClick ;
-- UI/PointCard.lua). Un clic sur une icône ouvre sa fiche (UI/PointCard.lua).
-- Fermer est un bouton sécurisé qui clique la croix de la carte du jeu (comme
-- Map/Gamepad.lua) : il ferme aussi en combat. Il est fait hors combat, et A ne
-- le presse pas (B ferme la carte, à la manette).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local C = {}
ns.MapChrome = C

local EDGE = 12              -- px : du bord de l'écran
local LEVEL = 9940           -- au-dessus de l'art et de ta flèche (PadView.lua : 9900 au plus), sous le curseur de la manette (9990)
local EVERY = 0.1            -- s entre deux mises à jour
local COORDS_Y = 46          -- px : les coordonnées, au-dessus de la barre d'aide
local SQUARE = 36            -- px : les boutons en haut à droite
local YOU_X, YOU_Y = 90, 80  -- px : le repère « Toi », loin des bords (les bandes)

local chrome                 -- le cadre de l'habillage, sur la vue
local zone, goTo, buttons, pills, you
local quests, locate, follow, menu, closeButton
local wait = 0

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Un cadre donné au curseur de la manette (Map/Gamepad.lua : A le presse)
local function Roots(f)
    local roots = ns.mod and ns.mod.padRoots
    if type(roots) == "table" then table.insert(roots, f) end
end

-- Le nom d'une touche, celui du jeu (Maj, Ctrl, Alt, Échap)
local function KeyName(global, fallback)
    local name = _G[global]
    return type(name) == "string" and name ~= "" and name or fallback
end
C.KeyName = KeyName

---------------------------------------------------------------------------
-- Où tu es, où est le curseur
---------------------------------------------------------------------------
-- Ta carte du jeu et ta place dessus (0..1)
local function PlayerMap()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local ok, best = pcall(C_Map.GetBestMapForUnit, "player")
    best = ok and Plain(best) or nil
    if not best then return end
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, best, "player")
    if not okP or not pos then return end
    local okXY, x, y = pcall(pos.GetXY, pos)
    if not okXY then return end
    x, y = Plain(x), Plain(y)
    if not (x and y) or (x == 0 and y == 0) then return end
    return best, x, y
end

local function MapName(mapID)
    local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

-- La zone sous un point du monde d'OpenMap : sa carte, et la place du point dessus
local function ZoneAt(u, v)
    local S = ns.S
    if not (S and S.ChainAt and S.Rect) then return end
    local chain = S.ChainAt(u, v)
    for i = #chain, 1, -1 do
        local id = chain[i]
        if id ~= S.WORLD then
            local l, r, t, b = S.Rect(id)
            if l and r > l and b > t then return id, (u - l) / (r - l), (v - t) / (b - t) end
        end
    end
end

-- Le curseur est-il sur la carte (celui de la manette, ou la souris) ?
local function CursorLive()
    local mod = ns.mod
    if mod.PadCursorXY then
        local ok, x = pcall(mod.PadCursorXY)
        if ok and x then return true end
    end
    local view = mod.ViewFrame and mod.ViewFrame()
    return view and view:IsMouseOver() or false
end

-- Le point du monde sous le curseur, et sa zone
local function CursorZone()
    local mod = ns.mod
    if not (mod.CursorWorld and CursorLive()) then return end
    local ok, u, v = pcall(mod.CursorWorld)
    if not (ok and u) then return end
    return ZoneAt(u, v)
end

---------------------------------------------------------------------------
-- La souris : Maj, Ctrl ou Alt + clic sur la carte
---------------------------------------------------------------------------
local function PinHere()
    local mod = ns.mod
    if not mod.AddPin then return false end
    local id, x, y = CursorZone()
    if not id then return false end
    ns.Call(mod.AddPin, id, x, y)
    return true
end

local function OnViewClick(button)
    if button ~= "LeftButton" then return false end
    if IsShiftKeyDown() then
        if ns.Travel then ns.Travel.AtCursor() end
        return true
    elseif IsControlKeyDown() then
        return PinHere()
    elseif IsAltKeyDown() then
        -- (le menu des actions là où l'on a cliqué : UI/PointCard.lua ; sinon la roue)
        if ns.PointCard then
            local ok, u, v = pcall(ns.mod.CursorWorld)
            ns.PointCard.Actions(ok and u or nil, ok and v or nil)
        elseif ns.ActionBar then
            ns.ActionBar.Toggle()
        end
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Les actions des boutons
---------------------------------------------------------------------------
function C.GoTo()
    if ns.Places then ns.Places.Show("search") end
end

function C.Locate()
    local mod = ns.mod
    if ns.MapNav then ns.MapNav.SetFollow(false) end
    ns.Call(mod.FindMe, mod, true)
end

function C.ToggleFollow()
    local M = ns.MapNav
    if M then M.SetFollow(not M.Following()) end
end

function C.OpenMenu()
    local mod = ns.mod
    if mod.MenuShown and mod.MenuShown() then ns.Call(mod.CloseMenu) else ns.Call(mod.OpenMenu, mod) end
end

---------------------------------------------------------------------------
-- La construction
---------------------------------------------------------------------------
local function BuildZone()
    zone = UI.Overlay(chrome)
    zone:SetSize(300, 48)
    zone:SetPoint("TOPLEFT", chrome, "TOPLEFT", EDGE, -EDGE)
    zone:EnableMouse(false)
    zone.name = UI.Text(zone, "GameFontNormalLarge")
    zone.name:SetPoint("TOPLEFT", 12, -7)
    zone.name:SetPoint("RIGHT", zone, "RIGHT", -12, 0)
    zone.name:SetJustifyH("LEFT")
    zone.name:SetWordWrap(false)
    zone.sub = UI.DimText(zone, nil, "GameFontHighlightSmall")
    zone.sub:SetPoint("TOPLEFT", zone.name, "BOTTOMLEFT", 0, -3)
    zone.sub:SetPoint("RIGHT", zone, "RIGHT", -12, 0)
    zone.sub:SetJustifyH("LEFT")
    zone.sub:SetWordWrap(false)
    zone:Hide()
end

local function BuildGoTo()
    goTo = CreateFrame("Button", "MyMapIsRichPlusGoTo", chrome)
    goTo:SetSize(400, 36)
    goTo:SetPoint("TOP", chrome, "TOP", 0, -EDGE)
    UI.PaintOverlay(goTo)
    local hl = goTo:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.07)
    local icon = goTo:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    icon:SetVertexColor(1, 0.82, 0)
    goTo.glyph = UI.CreateGlyph(goTo, 20)
    goTo.glyph:SetPoint("RIGHT", -10, 0)
    goTo.glyph:SetKey("PADLSHOULDER")
    goTo.keys = UI.DimText(goTo, nil, "GameFontHighlightSmall")
    goTo.keys:SetPoint("RIGHT", -10, 0)
    goTo.keys:SetText(KeyName("CTRL_KEY_TEXT", "Ctrl") .. "+F")
    goTo.text = UI.DimText(goTo, L.MAP_GOTO, "GameFontHighlight")
    goTo.text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    goTo.text:SetPoint("RIGHT", goTo, "RIGHT", -64, 0)
    goTo.text:SetJustifyH("LEFT")
    goTo.text:SetWordWrap(false)
    goTo:SetScript("OnClick", C.GoTo)
    Roots(goTo)
end

-- (dot : la pastille verte quand il est allumé, Me suivre)
local function Square(texture, title, tip, onClick, dot)
    local b = UI.IconToggle(buttons, SQUARE, texture)
    b.noDot = not dot
    b:SetScript("OnClick", onClick)
    UI.Tip(b, title, tip)
    return b
end

-- La croix de la carte du jeu, cliquée par un bouton sécurisé (fait hors
-- combat : ses attributs ne changent plus ensuite)
local function MakeClose()
    if closeButton or InCombatLockdown() or not buttons then return end
    local map = _G.WorldMapFrame
    local border = map and map.BorderFrame
    local target = border and border.CloseButton
    if not target then return end
    local b = CreateFrame("Button", "MyMapIsRichPlusMapClose", map, "SecureActionButtonTemplate")
    b:SetAttribute("type", "click")
    b:SetAttribute("clickbutton", target)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetSize(SQUARE, SQUARE)
    b:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -(EDGE + 4), -(EDGE + 4))
    -- (la strate de la vue, au-dessus de la carte du jeu : Map/PadView.lua)
    if ns.mod.viewStrata then b:SetFrameStrata(ns.mod.viewStrata) end
    b:SetFrameLevel(LEVEL + 10)
    b.noPadPress = true     -- (A ne le presse pas : B ferme la carte, à la manette)
    b.noGamepad = true
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.Gradient(bg, "VERTICAL", 0.29, 0.02, 0.012, 1, 0.66, 0.094, 0.059, 1)
    UI.Border(b, 0.79, 0.65, 0.29, 1)
    local x = UI.Text(b, "GameFontNormalHuge", "×")
    x:SetPoint("CENTER", 0, 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.6, 0.4, 0.18)
    UI.Tip(b, L.MAP_CLOSE)
    closeButton = b
end

local function BuildButtons()
    -- (cinq carrés : la croix sécurisée se pose à la place du cinquième)
    buttons = UI.Overlay(chrome)
    buttons:SetSize(4 + 5 * SQUARE + 4 * 4 + 4, SQUARE + 8)
    buttons:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -EDGE, -EDGE)
    -- (les quêtes : le bouton du journal, comme celui de la carte du jeu ; UI/QuestPanel.lua)
    quests = Square("Interface\\QuestFrame\\UI-QuestLog-BookIcon", L.QUESTS_TITLE, L.QUESTS_BUTTON_TIP, function()
        if ns.QuestPanel then ns.QuestPanel.Toggle() end
    end, true)
    quests:SetPoint("LEFT", 4, 0)
    quests.glyph = UI.CreateGlyph(quests, 16)
    quests.glyph:SetPoint("BOTTOMRIGHT", 4, -4)
    quests.glyph:SetKey("PADFORWARD")
    quests.key = UI.Text(quests, "GameFontHighlightSmall", "L")
    quests.key:SetPoint("BOTTOMRIGHT", -3, 3)
    locate = Square("Interface\\Icons\\Ability_Hunter_SniperShot", L.MAP_LOCATE, L.MAP_LOCATE_TIP, C.Locate)
    locate:SetPoint("LEFT", quests, "RIGHT", 4, 0)
    follow = Square("Interface\\Icons\\Ability_Tracking", L.MAP_FOLLOW, L.MAP_FOLLOW_TIP, C.ToggleFollow, true)
    follow:SetPoint("LEFT", locate, "RIGHT", 4, 0)
    follow.glyph = UI.CreateGlyph(follow, 16)
    follow.glyph:SetPoint("BOTTOMRIGHT", 4, -4)
    follow.glyph:SetKey("PADRSHOULDER")
    menu = Square("Interface\\Icons\\INV_Misc_Gear_01", L.MAP_SETTINGS, L.MAP_MENU_TIP, C.OpenMenu)
    menu:SetPoint("LEFT", follow, "RIGHT", 4, 0)
    Roots(buttons)
    MakeClose()
end

local function BuildPills()
    pills = CreateFrame("Frame", nil, chrome)
    pills:SetSize(1, 24)
    pills:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -EDGE, COORDS_Y)
    pills.me = UI.Pill(pills)
    pills.cursor = UI.Pill(pills)
    pills.cursor:SetPoint("BOTTOMRIGHT", pills, "BOTTOMRIGHT", 0, 0)
end

local function BuildYou()
    you = CreateFrame("Button", nil, chrome)
    you:SetHeight(22)
    local bg = you:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.7)
    UI.Border(you, "goldDim", 1)
    local hl = you:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.09)
    you.arrow = you:CreateTexture(nil, "ARTWORK")
    you.arrow:SetSize(14, 14)
    you.arrow:SetPoint("LEFT", 6, 0)
    you.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    you.text = UI.Text(you, "GameFontHighlightSmall")
    you.text:SetPoint("LEFT", you.arrow, "RIGHT", 6, 0)
    you:SetScript("OnClick", C.Locate)
    UI.Tip(you, L.MAP_YOU, L.MAP_YOU_TIP)
    you:Hide()
    Roots(you)
end

---------------------------------------------------------------------------
-- Les mises à jour
---------------------------------------------------------------------------
local function UpdateZone()
    local mod = ns.mod
    local text, fish, _, continent
    if mod.ViewPlace then
        local ok, a, b, c, d = pcall(mod.ViewPlace)
        if ok then text, fish, _, continent = a, b, c, d end
    end
    if not text then
        zone:Hide()
        return
    end
    zone.name:SetText(text)
    local sub = continent or ""
    if fish and fish ~= "" then sub = sub ~= "" and (sub .. " · " .. fish) or fish end
    zone.sub:SetText(sub)
    zone:Show()
end

local function UpdatePills()
    local best, x, y = PlayerMap()
    if best then
        pills.me:Set(L.MAP_ME, ("%.1f, %.1f"):format(x * 100, y * 100))
        pills.me:Show()
    else
        pills.me:Hide()
    end
    local id, cx, cy = CursorZone()
    if id then
        pills.cursor:Set(L.MAP_CURSOR, ("%.1f, %.1f"):format(cx * 100, cy * 100), MapName(id))
        pills.cursor:Show()
    else
        pills.cursor:Hide()
    end
    pills.me:ClearAllPoints()
    if pills.cursor:IsShown() then
        pills.me:SetPoint("RIGHT", pills.cursor, "LEFT", -6, 0)
    else
        pills.me:SetPoint("BOTTOMRIGHT", pills, "BOTTOMRIGHT", 0, 0)
    end
end

-- « Toi » au bord, dans ta direction, quand ta flèche sort de la vue
local function UpdateYou()
    local mod = ns.mod
    local best, x, y = PlayerMap()
    local pu, pv
    if best and mod.ToWorld then
        local ok, a, b = pcall(mod.ToWorld, best, x, y)
        if ok then pu, pv = a, b end
    end
    local okV, u, v, zoom = pcall(mod.ViewNow)
    local hu, hv
    if okV and u and mod.ViewHalfExtents then
        local okH, a, b = pcall(mod.ViewHalfExtents, zoom)
        if okH then hu, hv = a, b end
    end
    if not (pu and u and hu and hu > 0 and hv > 0) then
        you:Hide()
        return
    end
    local dx, dy = (pu - u) / hu, (pv - v) / hv
    if math.abs(dx) <= 1 and math.abs(dy) <= 1 then
        you:Hide()
        return
    end
    -- (sur le bord d'un rectangle un peu en retrait, dans ta direction)
    local k = 1 / math.max(math.abs(dx), math.abs(dy))
    local w, h = chrome:GetWidth() / 2 - YOU_X, chrome:GetHeight() / 2 - YOU_Y
    you:ClearAllPoints()
    you:SetPoint("CENTER", chrome, "CENTER", dx * k * w, -dy * k * h)
    -- (la flèche du jeu pointe vers le haut ; l'écran monte quand v descend)
    you.arrow:SetRotation(math.atan2(-dy, dx) - math.pi / 2)
    local name = MapName(best)
    you.text:SetText(name and L.MAP_YOU_AT:format(name) or L.MAP_YOU)
    you:SetWidth(6 + 14 + 6 + you.text:GetStringWidth() + 8)
    you:Show()
end

local function UpdateButtons()
    local M = ns.MapNav
    follow:SetOn(M and M.Following() and true or nil)
    local pad = ns.PadUI()
    follow.glyph:SetShown(pad)
    goTo.glyph:SetShown(pad)
    goTo.keys:SetShown(not pad)
    quests.glyph:SetShown(pad)
    quests.key:SetShown(not pad)
    quests:SetOn((ns.QuestPanel and ns.QuestPanel.Shown()) and true or nil)
end

-- Le bouton Quêtes allumé quand le panneau des quêtes est ouvert (UI/QuestPanel.lua)
function C.SetQuestsLit(on)
    if quests then quests:SetOn(on and true or nil) end
end

local function Update()
    UpdateZone()
    UpdatePills()
    UpdateYou()
    UpdateButtons()
end

local function OnUpdate(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = EVERY
    local ok, err = pcall(Update)
    if not ok and geterrorhandler then
        chrome:SetScript("OnUpdate", nil)
        geterrorhandler()(err)
    end
end

---------------------------------------------------------------------------
-- Ctrl+F : « Aller à… », carte ouverte et hors combat (un raccourci
-- prioritaire, posé et ôté comme ceux de la manette : Pad/Bindings.lua)
---------------------------------------------------------------------------
local keyOwner = CreateFrame("Frame")

---------------------------------------------------------------------------
-- Les touches de déplacement du personnage, carte plein écran ouverte : le
-- personnage ne bouge plus, elles font glisser la carte (avancer : vers le
-- nord, reculer : vers le sud, à gauche et à droite) ; sauter, la course
-- automatique, s'asseoir ne font rien. Posé hors combat seulement, ôté au
-- début d'un combat : en combat, le personnage se déplace comme toujours.
-- (Ni les boutons de la souris ni ceux de la manette : la carte en a besoin.)
---------------------------------------------------------------------------
local MOVES = {
    MOVEFORWARD = "up", MOVEBACKWARD = "down", STRAFELEFT = "left", STRAFERIGHT = "right",
    TURNLEFT = "left", TURNRIGHT = "right",
    JUMP = "none", TOGGLEAUTORUN = "none", SITORSTAND = "none", MOVEANDSTEER = "none",
}
local PAN = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }
local PAN_SPEED = 1.2        -- demi-vues par seconde
local held = {}
local panButtons = {}

local function PanButton(dir)
    local b = panButtons[dir]
    if b then return b end
    b = CreateFrame("Button", "MyMapIsRichPlusMapPan" .. dir, UIParent)
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetScript("OnClick", function(_, _, down) held[dir] = down and true or nil end)
    panButtons[dir] = b
    return b
end

local panDriver = CreateFrame("Frame")
panDriver:SetScript("OnUpdate", function(_, elapsed)
    if not next(held) then return end
    local mod = ns.mod
    if not (mod and mod.ViewNow and mod.ViewHalfExtents and mod.ShowNow) then return end
    local ok, u, v, zoom = pcall(mod.ViewNow)
    if not (ok and u) then return end
    local okH, hu, hv = pcall(mod.ViewHalfExtents, zoom)
    if not (okH and hu) then return end
    local dx, dy = 0, 0
    for dir in pairs(held) do
        local p = PAN[dir]
        if p then dx, dy = dx + p[1], dy + p[2] end
    end
    if dx == 0 and dy == 0 then return end
    local M = ns.MapNav
    if M and M.Following() then M.SetFollow(false) end
    ns.Call(mod.ShowNow, u + dx * hu * PAN_SPEED * elapsed, v + dy * hv * PAN_SPEED * elapsed, zoom)
end)

-- (une touche du clavier, pas un bouton de la souris ni de la manette)
local function Keyboard(key)
    return type(key) == "string" and not key:find("PAD") and not key:find("BUTTON") and not key:find("MOUSEWHEEL")
end

local function BindKeys()
    if InCombatLockdown() then return end
    ClearOverrideBindings(keyOwner)
    wipe(held)
    if chrome and chrome:IsVisible() and goTo then
        SetOverrideBindingClick(keyOwner, true, "CTRL-F", goTo:GetName(), "LeftButton")
        for action, dir in pairs(MOVES) do
            for _, key in ipairs({ GetBindingKey(action) }) do
                if Keyboard(key) and key ~= "CTRL-F" then
                    SetOverrideBindingClick(keyOwner, true, key, PanButton(dir):GetName(), "LeftButton")
                end
            end
        end
    end
end

local function UnbindKeys()
    wipe(held)
    if not InCombatLockdown() then ClearOverrideBindings(keyOwner) end
end

---------------------------------------------------------------------------
local function Build()
    if chrome then return chrome end
    local mod = ns.mod
    local view = mod and mod.ViewFrame and mod.ViewFrame()
    if not view then return end
    chrome = CreateFrame("Frame", nil, view)
    chrome:SetAllPoints(view)
    chrome:SetFrameLevel(LEVEL)
    chrome:EnableMouse(false)
    BuildZone()
    BuildGoTo()
    BuildButtons()
    BuildPills()
    BuildYou()
    chrome:SetScript("OnUpdate", OnUpdate)
    -- (le nom de la zone est le nôtre, en haut à gauche : PadView.lua n'écrit plus le sien)
    mod.viewChrome = true
    mod.OnViewClick = OnViewClick
    ns.Fire("MAP_CHROME", chrome)
    return chrome
end

-- Le cadre de l'habillage (nil : pas encore fait, ou la carte classique)
function C.Frame() return chrome end
C.EDGE, C.LEVEL = EDGE, LEVEL

local function OnShow()
    if not ns.FullMap() then return end
    if not Build() then return end
    wait = 0
    BindKeys()
    MakeClose()
end

ns.On("MAP_SHOW", function()
    OnShow()
    -- (la vue de la carte se fait à sa première ouverture, peut-être juste après nous)
    C_Timer.After(0, OnShow)
end)
ns.On("MAP_HIDE", UnbindKeys)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- (le combat commence : les raccourcis rendus tant qu'on le peut encore ;
        -- le personnage peut de nouveau se déplacer)
        wipe(held)
        ClearOverrideBindings(keyOwner)
    elseif ns.MapShown() then
        BindKeys()
        MakeClose()
    end
end)
