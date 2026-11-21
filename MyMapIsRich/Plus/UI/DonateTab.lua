-- Onglet « Découvrir » : en haut, « Mes projets », les addons de l'auteur et
-- leur page (UI/Projects.lua) ; dessous, un don PayPal facultatif, par QR
-- code (à scanner avec un téléphone) ou par le lien, à copier (WoW n'ouvre
-- pas de navigateur).
-- D'après la charte : un panneau ; en haut les projets, un trait doré, puis
-- à gauche le QR code sur fond blanc, cadré d'or, à droite le titre, le
-- texte, le lien.
-- Ce fichier est le même dans chaque addon (My Gamepad Is Rich, My Guild Is
-- Rich, OpenMap On Gamepad) : le modifier dans les trois. Les textes (TAB_DONATE,
-- DONATE_*) sont ceux de chaque addon, son nom dedans.
local addonName, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local DONATE_URL = "https://www.paypal.com/qrcodes/managed/07f4d316-e214-42f2-b49a-3b5027aa5b0b?utm_source=consweb_more"
local QR_TEXTURE = "Interface\\AddOns\\" .. addonName .. "\\Media\\PayPalQR"
local QR_SIZE = 170
local CONTENT_W = 820
local GAP = 22                  -- (entre les projets, le trait et le don)

-- L'icône de l'onglet : un coffre au trésor (ce qu'il y a à découvrir) ; une
-- boîte du jeu si ce client ne connaît pas le coffre
local CHEST = "Interface\\Icons\\INV_Misc_TreasureChest02b"
UI.DONATE_ICON = (GetFileIDFromPath and not GetFileIDFromPath(CHEST)) and "Interface\\Icons\\INV_Box_01" or CHEST

function UI.BuildDonatePage(page)
    -- (sous la bande d'accueil des écrans, s'il y en a une : My Gamepad Is
    -- Rich, OpenMap On Gamepad ; toute la page sinon : My Guild Is Rich)
    local box = UI.Inset(page)
    box:SetPoint("TOPLEFT", 0, UI.PAGE_TOP or 0)
    box:SetPoint("BOTTOMRIGHT", 0, 0)

    local content = CreateFrame("Frame", nil, box)
    content:SetWidth(CONTENT_W)

    -- (« Mes projets », en haut)
    local projects, links = UI.BuildProjects(content, CONTENT_W)
    projects:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    local top = -(projects:GetHeight() + GAP)

    -- (un trait doré entre les projets et le don)
    local rule = UI.Rule(content)
    rule:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
    rule:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, top)
    top = top - GAP

    -- Le don, dessous : tout est placé dans ce cadre
    local donate = CreateFrame("Frame", nil, content)
    donate:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
    donate:SetWidth(CONTENT_W)
    donate:SetHeight(QR_SIZE + 20 + 34)

    -- (le QR code sur fond blanc, cadré d'or, pour qu'un téléphone le lise bien)
    local holder = CreateFrame("Frame", nil, donate)
    holder:SetSize(QR_SIZE + 20, QR_SIZE + 20)
    holder:SetPoint("TOPLEFT", 0, -4)
    local white = holder:CreateTexture(nil, "BACKGROUND")
    white:SetAllPoints()
    white:SetColorTexture(0.95, 0.92, 0.85, 1)
    UI.Border(holder, 0.69, 0.54, 0.24, 1, -1)
    UI.Border(holder, 0.69, 0.54, 0.24, 1, -2)
    local qr = holder:CreateTexture(nil, "ARTWORK")
    qr:SetSize(QR_SIZE, QR_SIZE)
    qr:SetPoint("CENTER")
    qr:SetTexture(QR_TEXTURE)
    local scan = UI.Text(donate, "GameFontHighlightSmall", L.DONATE_SCAN)
    scan:SetPoint("TOP", holder, "BOTTOM", 0, -10)

    local x = QR_SIZE + 60
    local title = UI.Text(donate, "GameFontNormalHuge", L.DONATE_TITLE)
    title:SetPoint("TOPLEFT", x, -6)
    title:SetPoint("RIGHT", donate, "RIGHT", 0, 0)
    title:SetJustifyH("LEFT")

    local intro = UI.Text(donate, "GameFontHighlight", L.DONATE_INTRO)
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    intro:SetPoint("RIGHT", donate, "RIGHT", 0, 0)
    intro:SetJustifyH("LEFT")
    intro:SetSpacing(4)

    local linkLabel = UI.Text(donate, "GameFontHighlightSmall", L.DONATE_LINK)
    linkLabel:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -18)
    linkLabel:SetPoint("RIGHT", donate, "RIGHT", 0, 0)
    linkLabel:SetJustifyH("LEFT")
    local link = UI.CopyBox(donate, CONTENT_W - x - 10, DONATE_URL)
    link:SetPoint("TOPLEFT", linkLabel, "BOTTOMLEFT", 6, -6)

    local thanks = UI.Text(donate, "GameFontDisableSmall", L.DONATE_THANKS)
    thanks:SetPoint("TOPLEFT", link, "BOTTOMLEFT", -6, -14)
    thanks:SetPoint("RIGHT", donate, "RIGHT", 0, 0)
    thanks:SetJustifyH("LEFT")
    thanks:SetSpacing(3)

    content:SetHeight(-top + donate:GetHeight())
    content:SetPoint("CENTER", 0, 0)

    page:SetScript("OnHide", function()
        link:ClearFocus()
        for _, l in ipairs(links) do l:ClearFocus() end
    end)
end
