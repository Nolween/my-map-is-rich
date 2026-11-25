-- La fenêtre de l'addon (/mmir, le bouton de la minimap), comme celle de My
-- Gamepad Is Rich, d'après la charte (CHARTE.md) : portrait rond, onglets
-- dans la barre de titre, barre d'état en bas ; chaque écran a sa phrase
-- d'accueil à côté du portrait, puis ses panneaux.
--   Réglages : la manette sur la carte, l'apparence
--   Carte     : les réglages de la carte elle-même (UI/MapPage.lua)
--   Quêtes    : le suivi des quêtes à droite de l'écran (UI/Tracker.lua)
--   Trajets  : le calcul des itinéraires, le guidage, le groupe
--   Aide     : les boutons, carte par carte, et les commandes
--   Découvrir : UI/DonateTab.lua (mes projets ; don PayPal)
-- Et la page dans Options > AddOns, qui l'ouvre (UI/Options.lua).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local WIDTH, HEIGHT = 980, 640
local TITLE_H = 40              -- (la barre de titre, liseré compris)
local TITLE_MID = -21           -- (le milieu de la barre de titre)
local STATUS_H = 24             -- (la barre d'état, en bas)
local TAB_H, TAB_GAP = 26, 4
local GAP = UI.PAGE_GAP
local TAB_ORDER = { "settings", "map", "quests", "travel", "help", "donate" }
local ICONS = {
    settings = "Interface\\Icons\\Trade_Engineering",
    map = "Interface\\Icons\\INV_Misc_Spyglass_02",
    quests = "Interface\\Icons\\INV_Scroll_03",
    travel = "Interface\\Icons\\INV_Misc_Map_01",
    help = "Interface\\Icons\\INV_Misc_Book_08",
    -- (un coffre au trésor : UI/DonateTab.lua, chargé avant)
    donate = UI.DONATE_ICON,
}

local frame, titleText, status, statusRight
local pages, tabs = {}, {}
local currentTab = "settings"
local refreshers = {}

---------------------------------------------------------------------------
-- Les onglets (ceux de My Gamepad Is Rich)
---------------------------------------------------------------------------
local function SetTabSelected(tab, on)
    tab.glow:SetShown(on)
    if on then
        UI.Fill(tab.bg, "tabOnBottom")
        tab.edge:SetColor(1, 0.82, 0, 1)
        tab.text:SetFontObject("GameFontHighlight")
    else
        UI.Fade(tab.bg, "VERTICAL", "tabBottom", 1, "tabTop", 1)
        tab.edge:SetColor("panelEdge", 1)
        tab.text:SetFontObject("GameFontNormal")
    end
end

local SelectTab

local function CategoryTab(parent, key, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(TAB_H)
    b:SetFrameLevel(parent:GetFrameLevel() + 2)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetPoint("TOPLEFT", 1, -1)
    b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    b.glow = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.glow:SetPoint("TOPLEFT", 1, -1)
    b.glow:SetPoint("BOTTOMRIGHT", -1, 1)
    UI.Gradient(b.glow, "HORIZONTAL", 1, 0.82, 0, 0.22, 1, 0.82, 0, 0.05)
    b.edge = UI.Border(b, "panelEdge", 1, 0, "BORDER")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    hl:SetColorTexture(1, 0.82, 0, 0.07)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetTexture(ICONS[key])
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.text = UI.Text(b, "GameFontNormal", label)
    SetTabSelected(b, false)
    b:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
        SelectTab(key)
    end)
    return b
end

local function LayoutTabs()
    if not (frame and titleText) then return end
    local x = 84 + titleText:GetStringWidth() + 29
    for _, key in ipairs(TAB_ORDER) do
        local tab = tabs[key]
        local w = tab.text:GetStringWidth() + 22
        tab:SetWidth(w + 24)
        tab.icon:ClearAllPoints()
        tab.icon:SetPoint("LEFT", 12, 0)
        tab.text:ClearAllPoints()
        tab.text:SetPoint("LEFT", tab.icon, "RIGHT", 6, 0)
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", frame, "TOPLEFT", x, TITLE_MID)
        x = x + w + 24 + TAB_GAP
    end
end

local function RefreshStatus()
    if not status then return end
    local ok = ns.Ready()
    local view = ok and ns.ViewReady()
    if not ok then
        status:SetText("|cffff7060" .. L.STATUS_BAR_NO_OPENMAP .. "|r")
    elseif not ns.PadUI() then
        status:SetText(L.STATUS_BAR_NO_PADUI)
    elseif view then
        status:SetText("|cff40ff40" .. L.STATUS_BAR_READY .. "|r")
    else
        status:SetText(L.STATUS_BAR_WAIT)
    end
    statusRight:SetText(L.TITLE .. " " .. ns.VERSION)
end

local function RefreshAll()
    for _, fn in ipairs(refreshers) do pcall(fn) end
    RefreshStatus()
end
UI.RefreshAll = RefreshAll

SelectTab = function(name)
    if not pages[name] then name = "settings" end
    currentTab = name
    if ns.db then ns.db.options.tab = name end
    for key, page in pairs(pages) do page:SetShown(key == name) end
    for key, tab in pairs(tabs) do SetTabSelected(tab, key == name) end
    RefreshAll()
end

---------------------------------------------------------------------------
-- Réglages
---------------------------------------------------------------------------
local function Panel(page, x, y, width)
    local p = UI.Inset(page)
    p:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
    if width then p:SetWidth(width) else p:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y) end
    p:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    return p
end

local function Changed()
    ns.Fire("OPTIONS")
    RefreshAll()
end

-- Une case à cocher de la charte, avec son aide en dessous
local function Option(parent, key, label, tip, y, onChange)
    local cb = UI.Check(parent, label)
    cb:SetPoint("TOPLEFT", 16, y)
    cb:SetScript("OnClick", function(self)
        ns.db.options[key] = self:GetChecked() and true or false
        if onChange then onChange(ns.db.options[key]) end
        Changed()
    end)
    local help = UI.DimText(parent, tip)
    help:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 30, 0)
    help:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    help:SetJustifyH("LEFT")
    refreshers[#refreshers + 1] = function() cb:SetChecked(ns.db.options[key] and true or false) end
    return cb
end

-- Un choix parmi plusieurs : son nom, puis un bouton gris qui passe au suivant
local function Cycle(parent, key, label, choices, y, onChange)
    local fs = UI.Text(parent, "GameFontNormal", label)
    fs:SetPoint("TOPLEFT", 20, y - 5)
    local b = UI.Button(parent, "", 180, 24, "grey")
    b:SetPoint("TOPRIGHT", -16, y)
    local function Show()
        for _, c in ipairs(choices) do
            if c[1] == ns.db.options[key] then b:SetText(c[2]) return end
        end
        b:SetText(choices[1][2])
    end
    b:SetScript("OnClick", function()
        local at = 1
        for i, c in ipairs(choices) do if c[1] == ns.db.options[key] then at = i end end
        ns.db.options[key] = choices[at % #choices + 1][1]
        if onChange then onChange(ns.db.options[key]) end
        Show()
        Changed()
    end)
    refreshers[#refreshers + 1] = Show
    return b
end

local function BuildSettings(page)
    UI.PageIntro(page, L.SETTINGS_DESC)
    -- (les réglages de la carte elle-même : l'onglet Carte, UI/MapPage.lua)
    local half = math.floor((WIDTH - 16 - 8 - GAP) / 2)
    local left = Panel(page, 0, UI.PAGE_TOP, half)
    local right = Panel(page, half + GAP, UI.PAGE_TOP)

    UI.Section(left, L.SET_MAP, 16, -14)
    local y = -46
    Option(left, "enabled", L.OPT_ENABLED, L.OPT_ENABLED_TIP, y)
    y = y - 70
    Option(left, "magnet", L.OPT_MAGNET, L.OPT_MAGNET_TIP, y)
    y = y - 62
    Cycle(left, "magnetRadius", L.OPT_MAGNET_RADIUS, {
        { 16, L.OPT_MAGNET_SMALL }, { 24, L.OPT_MAGNET_MEDIUM }, { 36, L.OPT_MAGNET_LARGE },
    }, y)
    y = y - 40
    Option(left, "hints", L.OPT_HINTS, L.OPT_HINTS_TIP, y)
    y = y - 62
    Option(left, "centerOnOpen", L.OPT_CENTER_OPEN, L.OPT_CENTER_OPEN_TIP, y)
    y = y - 62
    Option(left, "whatsNew", L.OPT_WHATSNEW, L.OPT_WHATSNEW_TIP, y)

    UI.Section(right, L.SET_LOOK, 16, -14)
    y = -50
    Cycle(right, "keyboard", L.OPT_KEYBOARD, {
        { "auto", L.OPT_AUTO }, { "azerty", "AZERTY" }, { "qwerty", "QWERTY" },
    }, y)
    y = y - 38
    Cycle(right, "glyphs", L.OPT_GLYPHS, {
        { "auto", L.OPT_AUTO }, { "xbox", "Xbox" }, { "ps", "PlayStation" },
    }, y)
    y = y - 38
    local themes = {}
    for _, t in ipairs(UI.THEMES) do themes[#themes + 1] = { t.id, L[t.label] } end
    Cycle(right, "theme", L.OPT_THEME, themes, y, function(id) UI.SetTheme(id, true) end)
    y = y - 50
    -- (le bouton autour de la minimap : réglé par MinimapButton.lua)
    local mm = UI.Check(right, L.OPT_MINIMAP)
    mm:SetPoint("TOPLEFT", 16, y)
    mm:SetScript("OnClick", function(self)
        if ns.MinimapButton then ns.MinimapButton.SetShown(self:GetChecked()) end
    end)
    local mmHelp = UI.DimText(right, L.OPT_MINIMAP_TIP)
    mmHelp:SetPoint("TOPLEFT", mm, "BOTTOMLEFT", 30, 0)
    mmHelp:SetPoint("RIGHT", right, "RIGHT", -16, 0)
    mmHelp:SetJustifyH("LEFT")
    refreshers[#refreshers + 1] = function()
        mm:SetChecked(not ns.MinimapButton or ns.MinimapButton.IsShown())
    end

    -- (en bas de la colonne de gauche)
    local reset = UI.Button(left, L.OPT_RESET, 220, 24, "grey")
    reset:SetPoint("BOTTOMLEFT", 16, 16)
    reset:SetScript("OnClick", function()
        ns.ResetOptions()
        UI.SetTheme(ns.db.options.theme, true)
        Changed()
    end)
end

---------------------------------------------------------------------------
-- Quêtes : le suivi des quêtes à droite de l'écran (UI/Tracker.lua), et les
-- autres suivis qui lui prennent la place
---------------------------------------------------------------------------
local function BuildQuests(page)
    UI.PageIntro(page, L.TRACKER_PAGE_DESC)
    local half = math.floor((WIDTH - 16 - 8 - GAP) / 2)
    local left = Panel(page, 0, UI.PAGE_TOP, half)
    local right = Panel(page, half + GAP, UI.PAGE_TOP)
    local function TR() return ns.Tracker end

    UI.Section(left, L.SET_TRACKER, 16, -14)
    local y = -46
    Option(left, "tracker", L.OPT_TRACKER, L.OPT_TRACKER_TIP, y)
    -- (sur la même ligne, à droite : le remettre à sa place)
    local place = UI.Button(left, L.OPT_TRACKER_RESET, 200, 22, "grey")
    place:SetPoint("TOPRIGHT", -16, y)
    place:SetScript("OnClick", function() if TR() then TR().ResetPosition() end end)
    y = y - 76
    Cycle(left, "trackerSort", L.OPT_TRACKER_SORT, {
        { "dist", L.TRACKER_SORT_DIST }, { "zone", L.TRACKER_SORT_ZONE },
    }, y)
    y = y - 38
    Cycle(left, "trackerFilter", L.OPT_TRACKER_FILTER, {
        { "all", L.TRACKER_FILTER_ALL }, { "watched", L.TRACKER_FILTER_WATCHED },
        { "zone", L.TRACKER_FILTER_ZONE }, { "near", L.TRACKER_FILTER_NEAR },
    }, y)
    y = y - 40
    -- (l'opacité du fond : en direct, sans repasser par tous les réglages)
    local alphaLabel = UI.Text(left, "GameFontNormal", L.OPT_TRACKER_ALPHA)
    alphaLabel:SetPoint("TOPLEFT", 20, y - 3)
    local alpha = UI.Slider(left, 150, 0, 100, 5, function(v)
        ns.db.options.trackerAlpha = v / 100
        if TR() then TR().Repaint() end
    end, function(v) return ("%d %%"):format(v) end)
    alpha:SetPoint("TOPRIGHT", -76, y)
    refreshers[#refreshers + 1] = function()
        alpha:SetValueQuiet(math.floor((tonumber(ns.db.options.trackerAlpha) or 0.7) * 100 + 0.5))
    end
    y = y - 40
    Option(left, "trackerParty", L.OPT_TRACKER_PARTY, L.OPT_TRACKER_PARTY_TIP, y)
    y = y - 62
    Option(left, "trackerCombat", L.OPT_TRACKER_COMBAT, L.OPT_TRACKER_COMBAT_TIP, y)
    y = y - 58
    Option(left, "trackerLock", L.OPT_TRACKER_LOCK, L.OPT_TRACKER_LOCK_TIP, y)
    -- (en bas : les quêtes masquées du suivi, remises)
    local unhide = UI.Button(left, "", 280, 24, "grey")
    unhide:SetPoint("BOTTOMLEFT", 16, 16)
    unhide:SetScript("OnClick", function() if TR() then TR().UnhideAll() end end)
    refreshers[#refreshers + 1] = function()
        local n = TR() and TR().NumHidden() or 0
        unhide:SetText(L.OPT_TRACKER_UNHIDE:format(n))
        unhide:SetEnabled(n > 0)
    end

    -- (les autres suivis : celui d'EllesmereUI, celui de Questie)
    UI.Section(right, L.SET_TRACKER_OTHER, 16, -14)
    local rival = UI.Text(right, "GameFontHighlight")
    rival:SetPoint("TOPLEFT", 20, -48)
    rival:SetPoint("RIGHT", right, "RIGHT", -16, 0)
    rival:SetJustifyH("LEFT")
    local use = UI.Button(right, L.TRACKER_RIVAL_USE, 280, 24)
    use:SetPoint("TOPLEFT", rival, "BOTTOMLEFT", 0, -12)
    use:SetScript("OnClick", function()
        if not TR() then return end
        if TR().reload then
            ReloadUI()
            return
        end
        TR().UseOurs()
        RefreshAll()
    end)
    refreshers[#refreshers + 1] = function()
        local who = TR() and TR().Rival()
        if who == "ellesmere" then
            rival:SetText(L.TRACKER_RIVAL_ELLESMERE)
        elseif who == "questie" then
            rival:SetText(L.TRACKER_RIVAL_QUESTIE)
        else
            rival:SetText(L.TRACKER_RIVAL_NONE)
        end
        use:SetShown(who ~= nil)
        use:SetText(TR() and TR().reload and L.TRACKER_RIVAL_RELOAD or L.TRACKER_RIVAL_USE)
    end

    UI.Section(right, L.TRACKER_HELP_TITLE, 16, -150)
    local help = UI.Text(right, "GameFontHighlight", L.TRACKER_HELP)
    help:SetPoint("TOPLEFT", 20, -184)
    help:SetPoint("RIGHT", right, "RIGHT", -16, 0)
    help:SetJustifyH("LEFT")
    help:SetJustifyV("TOP")
    help:SetSpacing(3)
end

---------------------------------------------------------------------------
-- Trajets : le calcul (R3 sur la carte, Travel/), le guidage pendant le
-- trajet, le groupe
---------------------------------------------------------------------------
local function BuildTravel(page)
    UI.PageIntro(page, L.TRAVEL_PAGE_DESC)
    local half = math.floor((WIDTH - 16 - 8 - GAP) / 2)
    local left = Panel(page, 0, UI.PAGE_TOP, half)
    local right = Panel(page, half + GAP, UI.PAGE_TOP)
    local function Next()
        if ns.Travel and ns.Travel.Active() then ns.Print(L.TRAVEL_ROADS_NEXT) end
    end

    UI.Section(left, L.SET_TRAVEL, 16, -14)
    local y = -46
    Option(left, "travel", L.OPT_TRAVEL, L.OPT_TRAVEL_TIP, y)
    y = y - 62
    Option(left, "travelTerrain", L.OPT_TRAVEL_TERRAIN, L.OPT_TRAVEL_TERRAIN_TIP, y, Next)
    y = y - 62
    -- (le chemin à pied : routes au maximum, routes si possible, à travers champs)
    Cycle(left, "travelPath", L.OPT_TRAVEL_PATH, {
        { "roads", L.OPT_PATH_ROADS }, { "mixed", L.OPT_PATH_MIXED }, { "fields", L.OPT_PATH_FIELDS },
    }, y, Next)
    local pathHelp = UI.DimText(left, L.OPT_TRAVEL_PATH_TIP)
    pathHelp:SetPoint("TOPLEFT", 20, y - 30)
    pathHelp:SetPoint("RIGHT", left, "RIGHT", -16, 0)
    pathHelp:SetJustifyH("LEFT")
    y = y - 62
    Option(left, "travelCorpse", L.OPT_TRAVEL_CORPSE, L.OPT_TRAVEL_CORPSE_TIP, y, function(on)
        if on and ns.Travel then ns.Travel.CheckGhost() end
    end)
    y = y - 66
    Cycle(left, "travelSpeed", L.OPT_TRAVEL_SPEED, {
        { "auto", L.OPT_AUTO }, { "walk", L.OPT_SPEED_WALK }, { "slow", L.OPT_SPEED_SLOW }, { "fast", L.OPT_SPEED_FAST },
    }, y)
    y = y - 62
    Option(left, "travelHearth", L.OPT_TRAVEL_HEARTH, L.OPT_TRAVEL_HEARTH_TIP, y, Next)

    UI.Section(right, L.SET_GUIDE, 16, -14)
    y = -46
    Option(right, "travelHud", L.OPT_TRAVEL_HUD, L.OPT_TRAVEL_HUD_TIP, y)
    -- (sur la même ligne, à droite : le remettre à sa place)
    local place = UI.Button(right, L.OPT_TRAVEL_HUD_RESET, 210, 22, "grey")
    place:SetPoint("TOPRIGHT", -16, y)
    place:SetScript("OnClick", function()
        if ns.RouteHud then ns.RouteHud.ResetPosition() end
    end)
    y = y - 58
    Option(right, "travelArrow", L.OPT_TRAVEL_ARROW, L.OPT_TRAVEL_ARROW_TIP, y)
    -- (sur la même ligne, à droite : replier ou déplier le panneau, à la
    -- manette aussi ; à la souris, la flèche de son coin le fait)
    local fold = UI.Button(right, L.OPT_TRAVEL_HUD_FOLD, 210, 22, "grey")
    fold:SetPoint("TOPRIGHT", -16, y)
    fold:SetScript("OnClick", function()
        if ns.RouteHud then ns.RouteHud.ToggleFold() end
    end)
    y = y - 52
    Option(right, "travelMinimap", L.OPT_TRAVEL_MINIMAP, L.OPT_TRAVEL_MINIMAP_TIP, y)
    y = y - 52
    Option(right, "travelRumble", L.OPT_TRAVEL_RUMBLE, L.OPT_TRAVEL_RUMBLE_TIP, y)
    y = y - 58
    Option(right, "travelSound", L.OPT_TRAVEL_SOUND, L.OPT_TRAVEL_SOUND_TIP, y)
    y = y - 60
    UI.Section(right, L.SET_GROUP, 16, y)
    y = y - 32
    Option(right, "travelShare", L.OPT_TRAVEL_SHARE, L.OPT_TRAVEL_SHARE_TIP, y)
    y = y - 58
    Option(right, "travelShareChat", L.OPT_TRAVEL_SHARE_CHAT, L.OPT_TRAVEL_SHARE_CHAT_TIP, y)
end

---------------------------------------------------------------------------
-- La fenêtre
---------------------------------------------------------------------------
local function Build()
    local f = CreateFrame("Frame", "MyMapIsRichPlusFrame", UIParent)
    frame = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    -- (au-dessus de la carte plein écran, qui est en HIGH : l'onglet Carte
    -- s'ouvre aussi depuis la carte)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    -- (Échap la ferme, comme les autres addons ; c'est une fenêtre à part,
    -- pas une fenêtre par-dessus la carte)
    tinsert(UISpecialFrames, "MyMapIsRichPlusFrame")

    titleText = UI.WindowChrome(f, TITLE_H, L.TITLE, 84)
    local sep = f:CreateTexture(nil, "BORDER")
    sep:SetSize(1, 18)
    sep:SetPoint("LEFT", titleText, "RIGHT", 14, 0)
    UI.Fill(sep, "panelEdge")
    UI.Portrait(f, "Interface\\AddOns\\MyMapIsRich\\Media\\Icon")

    local c = CreateFrame("Frame", nil, f)
    c:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -TITLE_H)
    c:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)

    local labels = { settings = L.TAB_SETTINGS, map = L.TAB_MAP, quests = L.TAB_QUESTS, travel = L.TAB_TRAVEL, help = L.TAB_HELP, donate = L.TAB_DONATE }
    for _, key in ipairs(TAB_ORDER) do tabs[key] = CategoryTab(f, key, labels[key]) end
    LayoutTabs()
    for _, key in ipairs(TAB_ORDER) do
        local page = CreateFrame("Frame", nil, c)
        page:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -4)
        page:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -4, STATUS_H + 2)
        page:Hide()
        pages[key] = page
    end

    -- (barre d'état)
    local line = c:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.18)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 8, STATUS_H)
    line:SetPoint("BOTTOMRIGHT", -8, STATUS_H)
    status = UI.Text(c, "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", 12, 7)
    status:SetJustifyH("LEFT")
    statusRight = UI.Text(c, "GameFontNormalSmall")
    statusRight:SetPoint("BOTTOMRIGHT", -12, 7)

    BuildSettings(pages.settings)
    UI.BuildMapPage(pages.map, WIDTH - 24, function(fn) refreshers[#refreshers + 1] = fn end)
    BuildQuests(pages.quests)
    BuildTravel(pages.travel)
    -- (l'aide, un guide en étapes : UI/HelpTab.lua ; la page fait la hauteur
    -- de la fenêtre, moins la barre de titre, la barre d'état et les marges)
    UI.BuildHelpPage(pages.help, HEIGHT - TITLE_H - 4 - 4 - (STATUS_H + 2))
    UI.BuildDonatePage(pages.donate)
    -- (les cases et les champs du jeu aux couleurs de la charte)
    UI.SkinControls(c)

    f:SetScript("OnShow", function()
        LayoutTabs()
        RefreshAll()
    end)
    f:Hide()
    -- (carte ouverte, la manette la mène comme les autres fenêtres : la croix,
    -- A, B la ferme, LB / RB changent d'onglet ; Pad/Focus.lua)
    if ns.Focus and ns.Focus.RegisterWindow then
        ns.Focus.RegisterWindow(f, {
            onBack = function() f:Hide() end,
            onTab = function(dir)
                local at = 1
                for i, key in ipairs(TAB_ORDER) do if key == currentTab then at = i end end
                SelectTab(TAB_ORDER[(at - 1 + dir) % #TAB_ORDER + 1])
            end,
        })
    end
end

function UI.Show(tab)
    if not ns.db then return end
    if not frame then
        currentTab = ns.db.options.tab or "settings"
        Build()
    end
    frame:Show()
    SelectTab(tab or currentTab)
end

function UI.Hide()
    if frame then frame:Hide() end
end

-- La fenêtre est-elle ouverte (sur cet onglet) ?
function UI.Shown(tab)
    if not (frame and frame:IsShown()) then return false end
    return tab == nil or tab == currentTab
end

function UI.Toggle(tab)
    if frame and frame:IsShown() and not tab then
        frame:Hide()
    else
        UI.Show(tab)
    end
end

ns.On("OPTIONS", function() if frame and frame:IsShown() then RefreshAll() end end)
-- (une quête masquée ou remise, le tri changé depuis le suivi : UI/Tracker.lua)
ns.On("TRACKER", function() if frame and frame:IsShown() then RefreshAll() end end)
