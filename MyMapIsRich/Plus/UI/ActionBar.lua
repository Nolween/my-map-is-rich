-- La roue des actions (View sur la carte) : six actions en cercle autour du
-- curseur de la manette, choisies au stick droit (sa direction), validées
-- par A ; View la ferme (B ferme la carte, comme toujours).
-- La roue ne pose aucun raccourci : poser les nôtres fait perdre le focus de
-- la carte à l'interface manette, et le jeu rend alors les sticks au
-- personnage et à la caméra (la caméra tournait en choisissant). Ses boutons
-- sont lus sur la manette, comme sur la carte seule (Pad/Bindings.lua, mode
-- « read ») ; la roue suit le curseur, qui reste sur son moyeu : là, la vue
-- d'OpenMap ne zoome pas au stick droit et A n'y presse rien.
--   en haut              Ajouter à la file (le point sous le curseur)
--   en haut à droite     Envoyer au groupe (le point sous le curseur)
--   en bas à droite      Poser une épingle (la roue se ferme, A la pose)
--   en bas               Mes épingles
--   en bas à gauche      Plume
--   en haut à gauche     Réglages de la carte (l'onglet Carte de /mmir)
-- Au milieu, le nom de l'action choisie et ce qu'elle fait. Le point sous le
-- curseur est retenu à l'ouverture de la roue. LB (lieux) et RB (me suivre)
-- restent sur la carte.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI
local P = ns.Pad
local F = ns.Focus

local AB = {}
ns.ActionBar = AB

local SIZE = 420             -- le disque de la roue
local RADIUS = 132           -- les actions, sur ce cercle
local HUB = 132              -- le moyeu, au milieu
local TILE_W, TILE_H = 124, 96
local BADGE = 62             -- la pastille ronde d'une action
local STICK_MIN = 0.5        -- l'inclinaison du stick qui choisit une action

local frame, tiles = nil, {}
local selected               -- la case choisie
local point                  -- le point sous le curseur

local function NeedPoint(fn)
    return function()
        if not point then
            ns.Print(L.TRAVEL_NO_THERE)
            return
        end
        fn(point)
    end
end

-- (dans le sens des aiguilles d'une montre, depuis le haut)
local ACTIONS = {
    { "ACT_QUEUE", "ACT_QUEUE_TIP", "Interface\\Icons\\INV_Misc_Note_01", NeedPoint(function(p)
        if ns.Travel then ns.Travel.Enqueue(p) end
    end) },
    { "ACT_SHARE", "ACT_SHARE_TIP", "Interface\\Icons\\INV_Misc_GroupNeedMore", NeedPoint(function(p)
        if ns.TravelShare then ns.TravelShare.Propose(p) end
    end) },
    { "ACT_PIN", "ACT_PIN_TIP", "Interface\\Icons\\INV_Misc_Map_01", function() ns.Map.MyPins.SetMode(true) end },
    { "ACT_PINS", "ACT_PINS_TIP", "Interface\\Icons\\INV_Misc_Book_09", function() ns.Map.MyPins.Toggle(true) end },
    { "ACT_QUILL", "ACT_QUILL_TIP", "Interface\\Icons\\INV_Inscription_Tradeskill01", function() ns.Map.Sketch.Toggle(true) end },
    { "ACT_MENU", "ACT_MENU_TIP", "Interface\\Icons\\INV_Misc_Gear_01", function() F.ToggleMenu() end },
}

local function ShowChoice(tile)
    if not frame then return end
    if tile then
        frame.label:SetText(L[tile.action[1]])
        frame.sub:SetText(L[tile.action[2]])
    else
        frame.label:SetText(L.WHEEL_TITLE)
        frame.sub:SetText(L.WHEEL_PICK)
    end
end

-- Une action : une pastille ronde (un halo doré, un cercle, l'icône rognée
-- en rond) et son nom dessous
local function Paint(b, on)
    b.halo:SetShown(on)
    if on then
        b.ring:SetColorTexture(1, 0.82, 0, 1)
        b.icon:SetAlpha(1)
        b.icon:SetDesaturated(false)
        b.text:SetFontObject("GameFontNormal")
    else
        UI.Fill(b.ring, "edgeLight", 0.9)
        b.icon:SetAlpha(0.8)
        b.icon:SetDesaturated(true)
        b.text:SetFontObject("GameFontHighlightSmall")
    end
end

local function Tile(i, a)
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(TILE_W, TILE_H)
    b.action = a
    b.noFocusFrame = true   -- (la pastille s'allume elle-même : pas de cadre carré)
    local badge = CreateFrame("Frame", nil, b)
    badge:SetSize(BADGE + 16, BADGE + 16)
    badge:SetPoint("TOP", 0, 0)
    b.halo = UI.Disc(badge, BADGE + 14, "BACKGROUND", 0)
    b.halo:SetColorTexture(1, 0.82, 0, 0.22)
    b.ring = UI.Disc(badge, BADGE, "BACKGROUND", 1)
    local inner = UI.Disc(badge, BADGE - 4, "BORDER", 0)
    UI.Fill(inner, "well", 1)
    b.icon = UI.Disc(badge, BADGE - 10, "ARTWORK", 0)
    b.icon:SetTexture(a[3])
    b.text = UI.Text(b, "GameFontHighlightSmall", L[a[1]])
    b.text:SetPoint("TOP", badge, "BOTTOM", 0, 0)
    b.text:SetPoint("LEFT", 0, 0)
    b.text:SetPoint("RIGHT", 0, 0)
    b.text:SetWordWrap(false)
    Paint(b, false)
    -- (la souris dessus : choisie aussi)
    b:SetScript("OnEnter", function(self) AB.Select(self) end)
    b:SetScript("OnClick", function(self)
        AB.Hide()
        local ok, err = pcall(self.action[4])
        if not ok and geterrorhandler then geterrorhandler()(err) end
        P.Dirty()
    end)
    -- (sa place sur le cercle : l'angle depuis le haut, dans le sens des
    -- aiguilles d'une montre ; c'est le centre de la pastille qui y est)
    local angle = math.rad((i - 1) * 60)
    local dy = TILE_H / 2 - (BADGE + 16) / 2
    b:SetPoint("CENTER", frame, "CENTER", math.sin(angle) * RADIUS, math.cos(angle) * RADIUS - dy)
    return b
end

local function Build()
    if frame then return end
    local f = CreateFrame("Frame", "MyMapIsRichPlusWheel", UIParent)
    frame = f
    f:SetSize(SIZE, SIZE)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(8000)
    -- (pas tenue dans l'écran : le moyeu doit rester sous le curseur)
    f:EnableMouse(true)
    -- (le disque : un cercle doré, le fond sombre, un second cercle discret
    -- entre les actions et le moyeu)
    UI.Fill(UI.Disc(f, SIZE, "BACKGROUND", -8), "goldDim", 0.95)
    UI.Fill(UI.Disc(f, SIZE - 4, "BACKGROUND", -7), "windowBottom", 0.96)
    UI.Fill(UI.Disc(f, SIZE - 12, "BACKGROUND", -6), "windowTop", 0.9)
    -- (le moyeu : l'action choisie)
    local hub = CreateFrame("Frame", nil, f)
    hub:SetSize(HUB, HUB)
    hub:SetPoint("CENTER")
    UI.Fill(UI.Disc(hub, HUB, "BACKGROUND", 0), "goldSoft", 0.9)
    UI.Fill(UI.Disc(hub, HUB - 4, "BACKGROUND", 1), "well", 1)
    f.label = UI.Text(hub, "GameFontNormal")
    f.label:SetPoint("BOTTOM", hub, "CENTER", 0, 2)
    f.label:SetWidth(HUB - 22)
    if f.label.SetMaxLines then f.label:SetMaxLines(2) end
    f.sub = UI.DimText(hub, "")
    f.sub:SetPoint("TOP", hub, "CENTER", 0, -4)
    f.sub:SetWidth(HUB - 26)
    if f.sub.SetMaxLines then f.sub:SetMaxLines(2) end
    for i, a in ipairs(ACTIONS) do tiles[i] = Tile(i, a) end
    -- (les sticks reçus par la roue quand elle les garde : rien à en faire,
    -- ils ne vont simplement pas au jeu)
    pcall(f.SetScript, f, "OnGamePadStick", function() end)
    f:SetScript("OnUpdate", function()
        -- (la roue suit le curseur de la manette : il reste sur son moyeu, où
        -- OpenMap ne zoome pas au stick droit et où A ne presse rien)
        local cx, cy = ns.Map.Cursor.XY()
        if cx then
            local es = f:GetEffectiveScale()
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / es, cy / es)
        end
        -- (au stick droit : la case dans sa direction)
        local stick = ns.MapCamera and ns.MapCamera.Stick
        if not stick then return end
        local x, y = stick()
        if not x or x * x + y * y < STICK_MIN * STICK_MIN then return end
        local deg = math.deg(math.atan2(x, y)) % 360
        AB.Select(tiles[math.floor(((deg + 30) % 360) / 60) + 1])
    end)
    f:Hide()
    -- (dans les cadres que le curseur de la manette d'OpenMap survole : sur la
    -- roue, sa vue ne zoome pas et ne glisse pas)
    ns.Map.Cursor.AddRoot(f)
end

-- L'action choisie (au stick, ou la souris dessus) : sa pastille s'allume
function AB.Select(tile)
    if tile == selected then return end
    if selected then Paint(selected, false) end
    selected = tile
    if tile then Paint(tile, true) end
    ShowChoice(tile)
end

-- A : l'action choisie (le point sous le curseur pris maintenant)
local function Validate()
    if not selected then return end
    point = ns.TravelPlanner and ns.TravelPlanner.CursorPoint() or point
    selected:Click()
end

-- Les sticks gardés par la roue : sans cela, le stick droit, que rien sous le
-- curseur ne prend (la roue n'est pas la carte), va au jeu, qui tourne la
-- caméra. Seulement les sticks (EnableGamePadStick), jamais les boutons :
-- ils restent lus sur la manette (Pad/Bindings.lua), et leurs actions au
-- jeu. La direction du stick droit est toujours lue sur la manette (C.Stick).
local function KeepSticks(on)
    if not (frame and frame.EnableGamePadStick) then return end
    if on and InCombatLockdown() then return end
    pcall(frame.EnableGamePadStick, frame, on and true or false)
end

function AB.Show()
    if not ns.Ready() then return end
    Build()
    point = ns.TravelPlanner and ns.TravelPlanner.CursorPoint() or nil
    AB.Select(nil)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:Show()
    KeepSticks(true)
    P.Dirty()
end

function AB.Hide()
    KeepSticks(false)
    if frame then frame:Hide() end
    AB.Select(nil)
    P.Dirty()
end

function AB.Shown() return frame and frame:IsShown() or false end

-- La roue garde-t-elle les sticks ? (/mmir camera trace)
function AB.KeepsSticks()
    if not (frame and frame.IsGamePadStickEnabled) then return nil end
    local ok, on = pcall(frame.IsGamePadStickEnabled, frame)
    return ok and on or false
end

function AB.Toggle()
    if AB.Shown() then AB.Hide() else AB.Show() end
end

-- Le contexte de la roue : comme la carte seule, aucun raccourci posé (la
-- carte garde la manette : les sticks ne reviennent pas au personnage ni à
-- la caméra) ; ses boutons sont lus. A valide, View ferme ; B reste celui du
-- jeu (il ferme la carte, et la roue avec)
P.DefineContext("wheel", 55, function() return AB.Shown() end, nil, "read")
P.SetAction("wheel", "PAD1", Validate, function() return selected and "HINT_SELECT" or nil end)
P.SetAction("wheel", "PADBACK", AB.Hide, "HINT_CLOSE")
P.SetPassive("wheel", "RSTICK", "HINT_WHEEL_STICK")

ns.On("MAP_HIDE", AB.Hide)
