-- « Mes projets » : le récapitulatif des addons de l'auteur, chacun avec le
-- lien de sa page CurseForge, à copier (WoW n'ouvre pas de navigateur).
-- Affiché en haut de l'onglet Découvrir (UI/DonateTab.lua).
-- Ce fichier est le même dans chaque addon (My Gamepad Is Rich, My Guild Is
-- Rich, OpenMap On Gamepad) : un projet de plus, ou un lien qui change, se
-- reporte dans les trois. N'utilise que des éléments présents partout
-- (UI.Text, UI.Border).
local addonName, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

-- (https://www.curseforge.com/members/cashandrick/projects)
UI.PROJECTS_URL = "https://www.curseforge.com/members/cashandrick/projects"
UI.PROJECTS = {
    { addon = "MyGamepadIsRich", name = "My Gamepad Is Rich", desc = "PROJECT_MGIR",
        icon = "Interface\\Icons\\INV_Misc_EngGizmos_20",
        url = "https://www.curseforge.com/wow/addons/wow-forever-my-gamepad-is-rich" },
    { addon = "MyGuildIsRich", name = "My Guild Is Rich", desc = "PROJECT_MGUIR",
        icon = "Interface\\Icons\\INV_Misc_Coin_02",
        url = "https://www.curseforge.com/wow/addons/my-guild-is-rich" },
    { addon = "MyMapIsRich", name = "My Map Is Rich", desc = "PROJECT_MMIR",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        url = "https://www.curseforge.com/wow/addons/my-map-is-rich-forever" },
    { addon = "OpenMapOnGamepad", name = "OpenMap On Gamepad", desc = "PROJECT_OMGP",
        icon = "Interface\\Icons\\INV_Misc_Map02",
        url = "https://www.curseforge.com/wow/addons/openmap-on-gamepad-forever" },
}

local ROW_H = 46
local LINK_W = 330

local function Loaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
    return IsAddOnLoaded and IsAddOnLoaded(name)
end

-- (le gris des textes secondaires de la charte : la palette s'il y en a une)
local function Dim(fs)
    if UI.OnTheme and UI.RGB then
        UI.OnTheme(fs, function() fs:SetTextColor(UI.RGB("textDim")) end)
    else
        fs:SetTextColor(0.647, 0.604, 0.525)
    end
end

-- Un champ qui montre un lien, qu'on ne peut que sélectionner et copier
function UI.CopyBox(parent, width, url)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(width, 24)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetText(url)
    edit:SetCursorPosition(0)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(url)
            self:HighlightText()
        end
    end)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    edit:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetCursorPosition(0)
    end)
    edit:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    if UI.SkinInput then UI.SkinInput(edit) end
    return edit
end

-- Le récapitulatif, `width` de large ; rend le cadre (sa hauteur est mise)
-- et la liste des champs de lien (pour leur ôter le focus)
function UI.BuildProjects(parent, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(width)
    local links = {}

    -- (en haut de l'onglet : pas de trait au-dessus, celui d'en dessous le
    -- sépare du don, UI/DonateTab.lua)
    local title = UI.Text(f, "GameFontNormalLarge", L.PROJECTS_TITLE)
    title:SetPoint("TOPLEFT", 0, 0)
    local intro = UI.Text(f, "GameFontHighlightSmall", L.PROJECTS_INTRO)
    intro:SetPoint("LEFT", title, "RIGHT", 12, -1)
    intro:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    intro:SetJustifyH("LEFT")
    intro:SetWordWrap(false)
    Dim(intro)

    local y = -28
    for _, p in ipairs(UI.PROJECTS) do
        local row = CreateFrame("Frame", nil, f)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", 0, y)
        row:SetHeight(ROW_H - 6)
        -- (l'icône : celle de l'addon s'il est installé, sinon une icône du jeu)
        local iconFrame = CreateFrame("Frame", nil, row)
        iconFrame:SetSize(34, 34)
        iconFrame:SetPoint("LEFT", 0, 0)
        UI.Border(iconFrame, 0.69, 0.54, 0.24, 1)
        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        local here = p.addon == addonName
        if here or Loaded(p.addon) then
            icon:SetTexture("Interface\\AddOns\\" .. p.addon .. "\\Media\\Icon")
        else
            icon:SetTexture(p.icon)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end
        local name = UI.Text(row, "GameFontNormal", p.name)
        name:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 10, -2)
        -- (une petite mention : cet addon-ci, ou déjà installé)
        local mark = here and L.PROJECTS_THIS or (Loaded(p.addon) and L.PROJECTS_INSTALLED) or nil
        if mark then
            local tag = UI.Text(row, "GameFontNormalSmall", "· " .. mark)
            tag:SetPoint("LEFT", name, "RIGHT", 6, 0)
            Dim(tag)
        end
        local desc = UI.Text(row, "GameFontHighlightSmall", L[p.desc])
        desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("RIGHT", row, "RIGHT", -(LINK_W + 16), 0)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(false)
        local link = UI.CopyBox(row, LINK_W, p.url)
        link:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        links[#links + 1] = link
        y = y - ROW_H
    end

    -- (et la page de tous les projets)
    local allLabel = UI.Text(f, "GameFontHighlightSmall", L.PROJECTS_ALL)
    allLabel:SetPoint("TOPLEFT", 0, y - 6)
    Dim(allLabel)
    local all = UI.CopyBox(f, LINK_W, UI.PROJECTS_URL)
    all:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, y)
    links[#links + 1] = all

    f:SetHeight(-y + 26)
    return f, links
end
