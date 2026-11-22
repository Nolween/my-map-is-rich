-- Les crédits : qui a fait la carte, ses données, ses images. Ouverts par le
-- bouton Crédits de l'onglet Aide (UI/MainFrame.lua). Depuis la 0.6.0, ils
-- remplacent la page Crédits des nouveautés d'OpenMap (Credits.lua) : le
-- crédit d'OpenMap y reste, tant que son code et ses données sont dans
-- l'addon (licence MIT : LICENSES/OpenMap.txt).
-- Une petite fenêtre de la charte (CHARTE.md), enfant de la page qui l'ouvre
-- (elle se ferme avec la fenêtre de l'addon) ; à la manette, B la ferme et le
-- stick droit fait défiler (Pad/Focus.lua).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local CR = {}
ns.Credits = CR

local BOX_W, BOX_H = 560, 440
local frame

local function Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(BOX_W, BOX_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.DialogBackdrop(f)

    local label = UI.Text(f, "GameFontDisableSmall", L.TITLE)
    label:SetPoint("TOPLEFT", 20, -16)
    local title = UI.Text(f, "GameFontNormalHuge", L.CREDITS_TITLE)
    title:SetPoint("TOPLEFT", 20, -30)
    local close = UI.CloseButton(f, 20, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -12, -12)
    local rule = UI.Rule(f)
    rule:SetPoint("TOPLEFT", 16, -62)
    rule:SetPoint("TOPRIGHT", -16, -62)

    -- (le texte, dans un panneau qui défile)
    local box = UI.Inset(f)
    box:SetPoint("TOPLEFT", 16, -72)
    box:SetPoint("BOTTOMRIGHT", -16, 16)
    local textW = BOX_W - 32 - 28 - 24
    local body = CreateFrame("Frame", nil, box)
    body:SetSize(textW, 10)
    local scroll = UI.Scroll(box, body, 40)
    scroll:SetPoint("TOPLEFT", 14, -12)
    scroll:SetPoint("BOTTOMRIGHT", -26, 12)
    local text = UI.Text(body, "GameFontHighlight", L.CREDITS_TEXT)
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetWidth(textW)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)
    body:SetHeight(math.max(10, text:GetStringHeight() + 4))
    f.scroll = scroll

    f:Hide()
    if ns.Focus and ns.Focus.RegisterWindow then
        ns.Focus.RegisterWindow(f, { onBack = function() f:Hide() end, first = function() return close end })
    end
    return f
end

-- parent : la page qui l'ouvre (l'onglet Aide)
function CR.Open(parent)
    if not frame then frame = Build(parent or UIParent) end
    frame:Show()
    frame:Raise()
    if frame.scroll and frame.scroll.ToTop then frame.scroll:ToTop() end
end
