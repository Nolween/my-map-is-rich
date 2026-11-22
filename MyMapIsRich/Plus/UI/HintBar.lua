-- La barre d'aide : en bas de la carte, les boutons de la manette qui
-- servent maintenant, chacun avec son icône et ce qu'il fait (ceux de
-- l'addon en blanc, ceux du jeu et d'OpenMap en gris). Elle suit le contexte
-- (la carte seule, une fenêtre, le clavier, un donjon, la plume).
-- Sur la carte plein écran, en bas de l'écran ; à la souris, elle dit les
-- clics et les touches (la carte, le panneau des calques).
-- Elle ne prend pas la souris, et n'est posée qu'au-dessus de la carte (son
-- cadre est à nous ; il est seulement accroché à la vue de la carte).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI
local P = ns.Pad

local H = {}
ns.HintBar = H

local GLYPH = 20
local GAP = 14

local bar, items = nil, {}

local function Build()
    if bar then return end
    bar = CreateFrame("Frame", "MyMapIsRichPlusHints", UIParent)
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    bar:SetFrameLevel(7000)
    bar:SetHeight(30)
    bar:EnableMouse(false)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.Fade(bg, "VERTICAL", "windowBottom", 0.92, "windowTop", 0.92)
    UI.Border(bar, "windowEdge", 1)
    local line = bar:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", 1, -1)
    line:SetPoint("TOPRIGHT", -1, -1)
    line:SetHeight(1)
    line:SetColorTexture(1, 0.82, 0, 0.35)
    bar:Hide()
end

local function Item(i)
    local it = items[i]
    if it then return it end
    it = CreateFrame("Frame", nil, bar)
    it:SetHeight(GLYPH)
    it.glyph = UI.CreateGlyph(it, GLYPH)
    it.glyph:SetPoint("LEFT", 0, 0)
    it.text = UI.Text(it, "GameFontHighlightSmall")
    it.text:SetPoint("LEFT", it.glyph, "RIGHT", 4, 0)
    items[i] = it
    return it
end

-- (le pied de la carte de l'interface manette, sa propre barre d'aide, est
-- en bas de la vue quand la carte a le focus : la nôtre se met au-dessus)
local FOOTER_H = 56

local function Place()
    local map = _G.WorldMapFrame
    local sc = map and map.ScrollContainer
    local footer = map and map.worldMapFooter
    local above = type(footer) == "table" and footer.isShown and FOOTER_H or 0
    bar:ClearAllPoints()
    -- (la carte plein écran : en bas de l'écran, le pied de la carte du jeu caché dessous)
    if ns.FullMap() then
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 6)
    elseif sc then
        bar:SetPoint("BOTTOM", sc, "BOTTOM", 0, 6 + above)
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 40)
    end
end

-- (la croix : une icône pour les quatre directions)
local SHOWN_AS = { PADDRIGHT = "DPAD" }

---------------------------------------------------------------------------
-- À la souris, sur la carte plein écran : les clics et les touches (la
-- maquette « La barre d'aide »). Une suite de touches (Maj + clic) puis ce
-- qu'elle fait ; celles du jeu en gris.
---------------------------------------------------------------------------
local MOUSE_ATLAS = {
    clickL = { "newplayertutorial-icon-mouse-leftbutton", "NPE_LeftClick" },
    clickR = { "newplayertutorial-icon-mouse-rightbutton", "NPE_RightClick" },
    wheel = { "newplayertutorial-icon-mouse-middlebutton", "NPE_MiddleClick" },
}
local MOUSE_SHORT = { clickL = "L", clickR = "R", wheel = "M" }
local KEYS = {
    SHIFT = { "SHIFT_KEY_TEXT", "Shift" }, CTRL = { "CTRL_KEY_TEXT", "Ctrl" },
    ALT = { "ALT_KEY_TEXT", "Alt" }, ESC = { "KEY_ESCAPE", "Esc" },
}
local MOUSE_HINTS = {
    map = {
        { { "clickL" }, "HINT_M_PICK" },
        { { "SHIFT", "+", "clickL" }, "HINT_TRAVEL" },
        { { "CTRL", "+", "clickL" }, "HINT_M_PIN" },
        { { "ALT", "+", "clickL" }, "HINT_ACTIONS" },
        { { "CTRL", "+", "F" }, "HINT_GOTO" },
        { { "L" }, "HINT_QUESTS", true },
        { { "clickR" }, "HINT_ZOOM_OUT", true },
        { { "wheel" }, "HINT_ZOOM", true },
        { { "ESC" }, "HINT_CLOSE", true },
    },
    rail = {
        { { "clickL" }, "HINT_TOGGLE" },
        { { "clickR" }, "HINT_LAYER_DETAILS" },
        { { "ESC" }, "HINT_CLOSE_MAP", true },
    },
    quests = {
        { { "clickL" }, "HINT_SELECT" },
        { { "SHIFT", "+", "clickL" }, "HINT_ROUTE_NOW" },
        { { "clickR" }, "ACT_QUEUE" },
        { { "L" }, "HINT_QUESTS_CLOSE", true },
        { { "ESC" }, "HINT_CLOSE_MAP", true },
    },
}

local function KeyText(key)
    local k = KEYS[key]
    if not k then return key end
    local name = _G[k[1]]
    return type(name) == "string" and name ~= "" and name or k[2]
end

-- Une touche : un petit carré sombre bordé, son nom en blanc
local function Chip(parent, text)
    local chip = CreateFrame("Frame", nil, parent)
    chip:SetHeight(18)
    local bg = chip:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.Fill(bg, "inputBg", 1)
    UI.Border(chip, "edgeLight", 1)
    local fs = UI.Text(chip, "GameFontHighlightSmall", text)
    fs:SetPoint("CENTER", 0, 0)
    chip:SetWidth(math.max(18, math.ceil(fs:GetStringWidth()) + 10))
    return chip
end

-- Un élément de la suite : un clic (l'atlas de la souris du jeu), « + », ou une touche
local function Piece(parent, what)
    if what == "+" then
        local fs = UI.DimText(parent, "+", "GameFontHighlightSmall")
        return fs, math.ceil(fs:GetStringWidth())
    end
    local atlases = MOUSE_ATLAS[what]
    if atlases then
        for _, name in ipairs(atlases) do
            if UI.HasAtlas(name) then
                local t = parent:CreateTexture(nil, "ARTWORK")
                t:SetAtlas(name)
                t:SetSize(16, 20)
                return t, 16
            end
        end
        local chip = Chip(parent, MOUSE_SHORT[what])
        return chip, chip:GetWidth()
    end
    local chip = Chip(parent, KeyText(what))
    return chip, chip:GetWidth()
end

local mouseSets = {}

local function MouseSet(ctx)
    local set = mouseSets[ctx]
    if set then return set end
    set = CreateFrame("Frame", nil, bar)
    set:SetAllPoints(bar)
    local x = 10
    for _, hint in ipairs(MOUSE_HINTS[ctx]) do
        for _, what in ipairs(hint[1]) do
            local piece, w = Piece(set, what)
            piece:SetPoint("LEFT", set, "LEFT", x, 0)
            x = x + w + 3
        end
        local text = UI.Text(set, "GameFontHighlightSmall", L[hint[2]] or hint[2])
        text:SetPoint("LEFT", set, "LEFT", x + 2, 0)
        if hint[3] then UI.OnTheme(text, function() text:SetTextColor(UI.RGB("textDim")) end) end
        x = x + 2 + math.ceil(text:GetStringWidth()) + GAP
    end
    set.width = x - GAP + 10
    set:Hide()
    mouseSets[ctx] = set
    return set
end

-- La souris a la carte plein écran (l'interface manette éteinte : les
-- contextes des fenêtres peuvent se poser quand même, leurs boutons ne
-- servent pas)
local function MouseMode()
    return ns.MapShown() and ns.FullMap() and not ns.PadUI()
end

function H.Refresh()
    if not ns.db then return end
    local mouse = MouseMode()
    if not (ns.db.options.hints and (P.current or mouse)) then
        if bar then bar:Hide() end
        return
    end
    Build()
    for _, set in pairs(mouseSets) do set:Hide() end
    if mouse then
        for i = 1, #items do items[i]:Hide() end
        local ctx = "map"
        if ns.Layers and ns.Layers.PanelShown() then ctx = "rail"
        elseif ns.QuestPanel and ns.QuestPanel.Shown() then ctx = "quests" end
        local set = MouseSet(ctx)
        set:Show()
        bar:SetWidth(set.width)
        Place()
        bar:Show()
        return
    end
    local hints = P.Hints()
    local x = 10
    for i, h in ipairs(hints) do
        local it = Item(i)
        it.glyph:SetKey(SHOWN_AS[h.key] or h.key)
        it.text:SetText(tostring(h.text or ""))
        if h.passive then it.text:SetTextColor(UI.RGB("textDim")) else it.text:SetTextColor(1, 1, 1) end
        it:SetWidth(GLYPH + 4 + it.text:GetStringWidth())
        it:ClearAllPoints()
        it:SetPoint("LEFT", bar, "LEFT", x, 0)
        it:Show()
        x = x + it:GetWidth() + GAP
    end
    for i = #hints + 1, #items do items[i]:Hide() end
    bar:SetWidth(x - GAP + 10)
    Place()
    bar:SetShown(#hints > 0)
end

-- (les libellés dépendent de l'état : mode épingle, étages... revus souvent)
local ticker = CreateFrame("Frame")
local wait = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = 0.4
    if P.current or (bar and bar:IsShown()) or MouseMode() then H.Refresh() end
end)

ns.On("CONTEXT", H.Refresh)
ns.On("OPTIONS", H.Refresh)
ns.On("MAP_SHOW", function() C_Timer.After(0.1, H.Refresh) end)
ns.On("MAP_HIDE", function() if bar then bar:Hide() end end)
