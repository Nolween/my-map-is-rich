-- La barre d'aide : en bas de la carte, les boutons de la manette qui
-- servent maintenant, chacun avec son icône et ce qu'il fait (ceux de
-- l'addon en blanc, ceux du jeu et d'OpenMap en gris). Elle suit le contexte
-- (la carte seule, une fenêtre, le clavier, un donjon, la plume).
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
    if sc then
        bar:SetPoint("BOTTOM", sc, "BOTTOM", 0, 6 + above)
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 40)
    end
end

-- (la croix : une icône pour les quatre directions)
local SHOWN_AS = { PADDRIGHT = "DPAD" }

function H.Refresh()
    if not ns.db then return end
    if not (ns.db.options.hints and P.current) then
        if bar then bar:Hide() end
        return
    end
    Build()
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
    if P.current or (bar and bar:IsShown()) then H.Refresh() end
end)

ns.On("CONTEXT", H.Refresh)
ns.On("OPTIONS", H.Refresh)
ns.On("MAP_HIDE", function() if bar then bar:Hide() end end)
