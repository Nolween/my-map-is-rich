-- La page dans Options > AddOns, comme celle de My Gamepad Is Rich : le nom,
-- une phrase, et un bouton qui ouvre la fenêtre de l'addon (UI/MainFrame.lua),
-- où sont les réglages. Ses boutons sont ceux du jeu : la page est dans sa
-- fenêtre, et la charte ne vaut que pour nos fenêtres.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local O = {}
ns.Options = O

local registered = false

local function Register()
    if registered then return end
    registered = true
    local panel = CreateFrame("Frame")
    panel.name = L.TITLE
    local title = UI.Text(panel, "GameFontNormalLarge", L.TITLE)
    title:SetPoint("TOPLEFT", 16, -16)
    local desc = UI.Text(panel, "GameFontHighlight", L.SETTINGS_DESC)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetPoint("RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(220, 26)
    open:SetText(L.OPEN_CONFIG)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
        UI.Show()
    end)
    local help = UI.Text(panel, "GameFontHighlightSmall", L.SETTINGS_HELP)
    help:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -18)
    help:SetPoint("RIGHT", -16, 0)
    help:SetJustifyH("LEFT")
    help:SetSpacing(2)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- /mmir : la fenêtre de l'addon
function O.Open(tab)
    UI.Toggle(tab)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", Register)
