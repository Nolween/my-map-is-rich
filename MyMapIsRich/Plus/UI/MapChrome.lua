-- L'habillage de la carte plein écran (maquettes « La carte en plein écran »
-- et « L'habillage de la carte ») :
--   en haut à gauche  : la zone sous le curseur (sinon au centre de la vue),
--                       son continent (le panneau de trajet est caché carte ouverte : UI/RouteHud.lua)
--   en haut au milieu : « Aller à… » (pour l'instant le navigateur de lieux,
--                       sur sa recherche) ; LB à la manette, Ctrl+F au clavier
--   en haut à droite  : Me localiser, Me suivre, le menu de la carte, la
--                       taille (plein écran ou réduite), Fermer
--   à droite          : les quêtes, toujours là (UI/QuestPanel.lua)
--   en bas à droite   : les coordonnées (toi ; le curseur et sa zone)
--   au bord           : « Toi », quand ta flèche sort de la vue (clic : recentre)
-- Le rail des calques est à part (UI/Layers.lua) ; la barre d'aide aussi
-- (UI/HintBar.lua).
-- Tout est posé sur la vue de la carte (ns.Map.View.Frame),
-- au-dessus de l'art et de ta flèche, sous le curseur de la manette. Chaque
-- bande est donnée au curseur de la manette (ns.Map.Cursor.AddRoot) : A la presse.
-- À la souris, un clic sur la carte avec Maj : l'itinéraire jusque-là ; avec
-- Ctrl : une épingle ; avec Alt : le menu des actions (ns.Map.View.SetClickHandler ;
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
local locate, follow, menu, size, closeButton
local SIZE_ICONS = {         -- le bouton Taille : réduire (en plein écran), ou plein écran (réduite)
    small = { "Interface\\Buttons\\UI-Panel-SmallerButton-Up", "RedButton-Condense" },
    full = { "Interface\\Buttons\\UI-Panel-BiggerButton-Up", "RedButton-Expand" },
}
local legend                 -- (à la manette : les boutons à presser, sous les carrés)
local LEGEND_H, LEGEND_GLYPH = 30, 22
local wait = 0

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Un cadre donné au curseur de la manette (Map/Gamepad.lua : A le presse)
local function Roots(f) ns.Map.Cursor.AddRoot(f) end

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

-- La zone sous un point du monde : sa carte, et la place du point dessus
local function ZoneAt(u, v) return ns.Map.Coords.ZoneAt(u, v) end

-- Le curseur est-il sur la carte (celui de la manette, ou la souris) ?
local function CursorLive()
    if ns.Map.Cursor.XY() then return true end
    local view = ns.Map.View.Frame()
    return view and view:IsMouseOver() or false
end

-- Le point du monde sous le curseur, et sa zone
local function CursorZone()
    if not CursorLive() then return end
    local u, v = ns.Map.Cursor.World()
    if not u then return end
    return ZoneAt(u, v)
end

---------------------------------------------------------------------------
-- La souris : Maj, Ctrl ou Alt + clic sur la carte
---------------------------------------------------------------------------
local function PinHere()
    if not ns.Map.MyPins.CanAdd() then return false end
    local id, x, y = CursorZone()
    if not id then return false end
    ns.Map.MyPins.Add(id, x, y)
    return true
end

local function OnViewClick(button)
    if button ~= "LeftButton" then return false end
    if IsShiftKeyDown() then
        if ns.Travel then ns.Travel.AtCursor() end
        return true
    elseif IsControlKeyDown() then
        -- (le réglage éteint : le Ctrl+clic laissé à un autre addon, Map Pin Enhanced)
        if ns.Map.Settings.Get("ctrlClickPin") == false then return false end
        return PinHere()
    elseif IsAltKeyDown() then
        -- (le menu des actions là où l'on a cliqué : UI/PointCard.lua ; sinon la roue)
        if ns.PointCard then
            local u, v = ns.Map.Cursor.World()
            ns.PointCard.Actions(u, v)
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
    if ns.MapNav then ns.MapNav.SetFollow(false) end
    ns.Map.View.FindMe(true)
end

function C.ToggleFollow()
    local M = ns.MapNav
    if M then M.SetFollow(not M.Following()) end
end

function C.OpenMenu() ns.Map.Menu.Toggle() end

-- Plein écran ou réduite (Plus/Core.lua : ns.SetMapSmall ; pas en combat)
function C.ToggleSize() ns.ToggleMapSize() end

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
    b:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -(EDGE + 4), -(EDGE + 4))   -- (puis au coin de la carte : PlaceClose)
    -- (la strate de la vue, au-dessus de la carte du jeu : Map/PadView.lua)
    local strata = ns.Map.View.Strata()
    if strata then b:SetFrameStrata(strata) end
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

-- La croix sécurisée au coin haut droit de la carte, plein écran ou réduite :
-- posée sur l'écran (pas sur la carte, qui n'est pas un cadre protégé), d'après
-- la place de la carte ; hors combat seulement (en combat, la carte ne change
-- ni de taille ni de place : ns.SetMapSmall)
local function PlaceClose()
    if not (closeButton and chrome) or InCombatLockdown() then return end
    local right, top = chrome:GetRight(), chrome:GetTop()
    if not (right and top) then return end
    closeButton:ClearAllPoints()
    closeButton:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right - (EDGE + 4), top - (EDGE + 4))
end
C.PlaceClose = PlaceClose

local function BuildButtons()
    -- (cinq carrés : la croix sécurisée se pose à la place du cinquième. Pas
    -- de bouton des quêtes : leur liste est toujours là, UI/QuestPanel.lua)
    buttons = UI.Overlay(chrome)
    buttons:SetSize(4 + 5 * SQUARE + 4 * 4 + 4, SQUARE + 8)
    buttons:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -EDGE, -EDGE)
    locate = Square("Interface\\Icons\\Ability_Hunter_SniperShot", L.MAP_LOCATE, L.MAP_LOCATE_TIP, C.Locate)
    locate:SetPoint("LEFT", 4, 0)
    follow = Square("Interface\\Icons\\Ability_Tracking", L.MAP_FOLLOW, L.MAP_FOLLOW_TIP, C.ToggleFollow, true)
    follow:SetPoint("LEFT", locate, "RIGHT", 4, 0)
    -- (à la manette : sous les carrés, une bande avec le bouton à presser sous
    -- chacun, en grand : RB me suivre, X la taille, B fermer la carte)
    legend = UI.Overlay(chrome)
    legend:SetSize(buttons:GetWidth(), LEGEND_H)
    legend:SetPoint("TOPRIGHT", buttons, "BOTTOMRIGHT", 0, -2)
    legend:EnableMouse(false)
    for slot, key in pairs({ [2] = "PADRSHOULDER", [4] = "PAD3", [5] = "PAD2" }) do
        local g = UI.CreateGlyph(legend, LEGEND_GLYPH)
        g:SetPoint("CENTER", legend, "LEFT", 4 + (slot - 1) * (SQUARE + 4) + SQUARE / 2, 0)
        g:SetKey(key)
    end
    legend:Hide()
    menu = Square("Interface\\Icons\\INV_Misc_Gear_01", L.MAP_SETTINGS, L.MAP_MENU_TIP, C.OpenMenu)
    menu:SetPoint("LEFT", follow, "RIGHT", 4, 0)
    -- (la taille : réduire la carte en fenêtre, ou la remettre en plein écran ; X à la manette)
    size = Square(SIZE_ICONS.small[1], function()
        return ns.MapSmall() and L.MAP_SIZE_FULL or L.MAP_SIZE_SMALL
    end, L.MAP_SIZE_TIP, C.ToggleSize)
    size:SetPoint("LEFT", menu, "RIGHT", 4, 0)
    Roots(buttons)
    MakeClose()
end

-- La bande du haut selon la largeur de la carte (plein écran ou réduite) : la
-- zone un peu plus étroite sur une petite carte ; « Aller à… » au milieu s'il
-- y tient, sinon entre la zone et les boutons ; trop étroit, il ne garde que
-- la loupe (et la pastille LB à la manette)
local GOTO_W, GOTO_MIN, GOTO_TEXT = 400, 64, 150

local function Layout()
    if not (chrome and zone and goTo and buttons) then return end
    local w = chrome:GetWidth() or 0
    if w <= 0 then return end
    local zoneW = math.min(300, math.max(180, math.floor(w * 0.24)))
    zone:SetWidth(zoneW)
    local leftEdge = EDGE + zoneW + 8
    local rightEdge = w - EDGE - buttons:GetWidth() - 8
    goTo:ClearAllPoints()
    if w / 2 - GOTO_W / 2 >= leftEdge and w / 2 + GOTO_W / 2 <= rightEdge then
        goTo:SetWidth(GOTO_W)
        goTo:SetPoint("TOP", chrome, "TOP", 0, -EDGE)
    else
        goTo:SetWidth(math.max(GOTO_MIN, math.min(GOTO_W, rightEdge - leftEdge)))
        goTo:SetPoint("TOPLEFT", chrome, "TOPLEFT", leftEdge, -EDGE)
    end
    goTo.narrow = goTo:GetWidth() < GOTO_TEXT
    goTo.text:SetShown(not goTo.narrow)
    goTo.keys:SetShown(not ns.PadUI() and not goTo.narrow)
end
C.Layout = Layout

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
    local text, fish, _, continent = ns.Map.View.Place()
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
    local best, x, y = PlayerMap()
    local pu, pv
    if best then pu, pv = ns.Map.Coords.ToWorld(best, x, y) end
    local u, v, zoom = ns.Map.View.Now()
    local hu, hv
    if u then hu, hv = ns.Map.View.HalfExtents(zoom) end
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
    -- (la manette branchée ou débranchée, carte ouverte : la bande, et le panneau des quêtes dessous)
    if pad ~= legend:IsShown() and ns.QuestPanel then
        legend:SetShown(pad)
        ns.QuestPanel.Place()
    end
    legend:SetShown(pad)
    goTo.glyph:SetShown(pad)
    goTo.keys:SetShown(not pad and not goTo.narrow)
    -- (le bouton Taille : ce qu'il fera, réduire ou plein écran)
    local icon = ns.MapSmall() and SIZE_ICONS.full or SIZE_ICONS.small
    if size.shownIcon ~= icon then
        size.shownIcon = icon
        size:SetIcon(icon[1], icon[2])
    end
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
-- La carte réduite les laisse au personnage, comme la carte en fenêtre du jeu.
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
    local u, v, zoom = ns.Map.View.Now()
    if not u then return end
    local hu, hv = ns.Map.View.HalfExtents(zoom)
    if not hu then return end
    local dx, dy = 0, 0
    for dir in pairs(held) do
        local p = PAN[dir]
        if p then dx, dy = dx + p[1], dy + p[2] end
    end
    if dx == 0 and dy == 0 then return end
    local M = ns.MapNav
    if M and M.Following() then M.SetFollow(false) end
    ns.Map.View.Show(u + dx * hu * PAN_SPEED * elapsed, v + dy * hv * PAN_SPEED * elapsed, zoom)
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
        for action, dir in pairs(ns.MapSmall() and {} or MOVES) do
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

-- La croix haut / bas du jeu agrandit ou réduit sa carte en fenêtre, celle
-- qui est sous la nôtre. Elle reste au jeu, et l'addon n'y touche pas :
--   - la neutraliser par un raccourci de l'addon brouillait l'interface
--     manette (le jeu bloquait ensuite SetPreferredGamepadInteractTarget) ;
--   - prendre les boutons par un cadre (EnableGamePadButton) fait exécuter
--     les autres depuis le code de l'addon, qui les bloque (Pad/Bindings.lua) ;
--   - remettre la carte du jeu en fenêtre (son Minimize, appelé par l'addon)
--     contamine son état : le jeu bloquait SetPreferredGamepadInteractTarget
--     jusqu'au /reload (1.0.0, comme FocusMap : UI/QuestPanel.lua).
-- Notre carte suit donc celle du jeu, sans jamais la toucher (seulement
-- ns.SetMapSmall, notre propre carte) : la croix bas agrandit celle du jeu
-- sous la carte réduite, la nôtre passe en vrai plein écran, comme avec X ;
-- la croix haut la réduit, la nôtre revient en carte réduite, mais seulement
-- si c'est la croix bas qui l'avait mise en plein écran (un plein écran
-- choisi par X ou le bouton Taille reste). Dans la même image : rien ne se voit
-- de la carte du jeu agrandie entre deux.
local sizeHooked = false
local followed = false        -- notre plein écran vient de la croix bas du jeu
local function HookGameSize()
    local map = _G.WorldMapFrame
    if sizeHooked or not (map and type(map.Maximize) == "function") then return end
    sizeHooked = true
    hooksecurefunc(map, "Maximize", function()
        if not (ns.FullMap() and ns.MapShown() and ns.MapSmall()) or InCombatLockdown() then return end
        ns.SetMapSmall(false)
        followed = true          -- (après MAP_SIZE, qui l'efface)
    end)
    if type(map.Minimize) == "function" then
        hooksecurefunc(map, "Minimize", function()
            if not followed then return end
            followed = false
            if not (ns.FullMap() and ns.MapShown()) or ns.MapSmall() or InCombatLockdown() then return end
            ns.SetMapSmall(true)
        end)
    end
end
-- (X, le bouton Taille ou la carte fermée : ce plein écran n'est plus celui de la croix)
ns.On("MAP_SIZE", function() followed = false end)
ns.On("MAP_HIDE", function() followed = false end)

---------------------------------------------------------------------------
local function Build()
    if chrome then return chrome end
    local view = ns.Map.View.Frame()
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
    ns.Map.View.SetChrome(true)
    ns.Map.View.SetClickHandler(OnViewClick)
    -- (X à la manette, rien d'OpenMap ouvert : la taille de la carte, au lieu
    -- de dézoomer ; le stick droit zoome. En combat, un message : ns.SetMapSmall.
    -- X est aussi lu sur la manette, Pad/MapNav.lua : un seul des deux compte)
    ns.Map.View.SetOutHandler(function()
        ns.PadToggleMapSize()
        return true
    end)
    -- (la carte change de taille : la croix sécurisée la suit)
    chrome:HookScript("OnSizeChanged", function()
        Layout()
        C_Timer.After(0, PlaceClose)
    end)
    Layout()
    ns.Fire("MAP_CHROME", chrome)
    return chrome
end

-- Le cadre de l'habillage (nil : pas encore fait, ou la carte classique)
function C.Frame() return chrome end

-- Le bas des boutons du haut à droite, depuis le haut de l'écran (px) : la
-- bande des boutons de la manette comprise quand elle est là (le panneau des
-- quêtes se pose dessous : UI/QuestPanel.lua)
function C.ButtonsBottom()
    local bottom = EDGE + SQUARE + 8
    if ns.PadUI() then bottom = bottom + 2 + LEGEND_H end
    return bottom
end
C.EDGE, C.LEVEL = EDGE, LEVEL

local function OnShow()
    if not ns.FullMap() then return end
    if not Build() then return end
    wait = 0
    BindKeys()
    MakeClose()
    PlaceClose()
    HookGameSize()
end

ns.On("MAP_SHOW", function()
    OnShow()
    -- (la vue de la carte se fait à sa première ouverture, peut-être juste après nous)
    C_Timer.After(0, OnShow)
end)
ns.On("MAP_HIDE", UnbindKeys)

-- Plein écran ou réduite : la croix au coin, les touches de déplacement
-- (rendues au personnage sur la carte réduite), le bouton Taille
ns.On("MAP_SIZE", function()
    if not chrome then return end
    if ns.MapShown() then BindKeys() end
    wait = 0
    C_Timer.After(0, function()
        Layout()
        PlaceClose()
    end)
end)

-- La carte du jeu gardée en fenêtre sous la nôtre (son réglage miniWorldMap,
-- seulement lui, carte fermée et hors combat) : la carte réduite se pose
-- dessus et la couvre (Map/PadView.lua) ; en plein écran, elle est couverte
-- de toute façon
local function KeepGameWindowed()
    if not ns.FullMap() or InCombatLockdown() or ns.MapShown() then return end
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if not (get and set) then return end
    local ok, now = pcall(get, "miniWorldMap")
    if ok and now ~= nil and now ~= "1" then pcall(set, "miniWorldMap", "1") end
end

ns.On("READY", function()
    -- (la taille choisie, pour la carte : Map/PadView.lua)
    ns.Map.SetSmall(ns.db.options.mapSmall)
    C_Timer.After(1, KeepGameWindowed)
end)
ns.On("MAP_HIDE", function() C_Timer.After(0, KeepGameWindowed) end)

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
        PlaceClose()
    else
        KeepGameWindowed()
    end
end)
