-- « Nouveautés » : après une mise à jour, une fenêtre montre ce qui a
-- changé dans les 5 dernières versions au plus (les plus récentes en haut, à
-- faire défiler ; celles d'après la dernière connexion marquées « Nouveau »).
-- Une fois par mise à jour, à la connexion, hors combat ; pas à la première
-- installation. On la revoit avec /mmir news, ou le bouton Nouveautés de
-- l'onglet Aide (MainFrame.lua). La même que dans My Guild Is Rich et My
-- Gamepad Is Rich.
-- Une fenêtre à elle, par-dessus le jeu (pas par-dessus la carte), aux
-- couleurs de la charte (CHARTE.md), fermée par Échap.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local W = {}
ns.WhatsNew = W

-- Les 5 dernières versions publiées au plus, de la plus récente à la plus
-- ancienne (clé du texte dans les Locales). À chaque version : on l'ajoute en
-- tête, et au-delà de 5, on retire la dernière.
local NOTES = {
    { version = "1.3.2", text = "WHATSNEW_MMIR_1_3_2" },
    { version = "1.3.1", text = "WHATSNEW_MMIR_1_3_1" },
    { version = "1.3.0", text = "WHATSNEW_MMIR_1_3_0" },
    { version = "1.2.0", text = "WHATSNEW_MMIR_1_2_0" },
    { version = "1.1.0", text = "WHATSNEW_MMIR_1_1_0" },
}


-- (la version d'avant celle qui a introduit cette fenêtre : ce qu'on
-- suppose chez qui avait déjà l'addon, faute de version retenue)
local BEFORE = "0.3.0"

local FEEDBACK_URL = "https://github.com/Nolween/my-map-is-rich/issues"
local BOX_W, BOX_H = 640, 560

-- « 0.10.0 » > « 0.9.3 » : comparaison nombre par nombre
local function Newer(a, b)
    local x, y = {}, {}
    for n in tostring(a):gmatch("%d+") do x[#x + 1] = tonumber(n) end
    for n in tostring(b):gmatch("%d+") do y[#y + 1] = tonumber(n) end
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p > q end
    end
    return false
end
W.Newer = Newer

-- Le texte des versions ; since : la dernière version vue (les plus
-- récentes sont marquées « Nouveau »)
local function Text(since)
    local parts = {}
    for _, note in ipairs(NOTES) do
        local head = "|cffffd100" .. note.version .. "|r"
        if since and Newer(note.version, since) then
            head = head .. "   |cff40ff40" .. L.WHATSNEW_NEW .. "|r"
        end
        parts[#parts + 1] = head .. "\n" .. L[note.text]
    end
    return table.concat(parts, "\n\n")
end

---------------------------------------------------------------------------
-- La fenêtre
---------------------------------------------------------------------------
local frame

local function Build()
    local f = CreateFrame("Frame", "MyMapIsRichPlusWhatsNew", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(BOX_W, BOX_H)
    f:SetPoint("CENTER", 0, 30)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.DialogBackdrop(f)
    -- (Échap la ferme : une fenêtre à part, jamais par-dessus la carte,
    -- comme la fenêtre de l'addon)
    tinsert(UISpecialFrames, "MyMapIsRichPlusWhatsNew")

    -- En-tête : le nom de l'addon, le titre, ce qu'on voit
    local label = UI.Text(f, "GameFontDisableSmall", L.TITLE)
    label:SetPoint("TOPLEFT", 20, -16)
    local title = UI.Text(f, "GameFontNormalHuge", L.WHATSNEW_TITLE)
    title:SetPoint("TOPLEFT", 20, -30)
    f.sub = UI.Text(f, "GameFontHighlightSmall")
    f.sub:SetPoint("TOPLEFT", 20, -58)
    f.sub:SetPoint("RIGHT", -20, 0)
    f.sub:SetJustifyH("LEFT")
    local rule = UI.Rule(f)
    rule:SetPoint("TOPLEFT", 16, -76)
    rule:SetPoint("TOPRIGHT", -16, -76)

    -- (la croix : un petit carré rouge cerclé d'or, comme la fenêtre)
    local x = CreateFrame("Button", nil, f)
    x:SetSize(20, 20)
    x:SetPoint("TOPRIGHT", -12, -12)
    local xbg = x:CreateTexture(nil, "BACKGROUND")
    xbg:SetAllPoints()
    UI.Gradient(xbg, "VERTICAL", 0.29, 0.02, 0.012, 1, 0.66, 0.094, 0.059, 1)
    UI.Border(x, 0.79, 0.65, 0.29, 1)
    local xt = UI.Text(x, "GameFontNormal", "×")
    xt:SetPoint("CENTER", 0, 1)
    local xhl = x:CreateTexture(nil, "HIGHLIGHT")
    xhl:SetAllPoints()
    xhl:SetColorTexture(1, 0.6, 0.4, 0.18)
    x:SetScript("OnClick", function() f:Hide() end)

    -- Les nouveautés, dans un panneau qui défile (molette, ou la barre
    -- dorée à droite)
    local box = UI.Inset(f)
    box:SetPoint("TOPLEFT", 16, -86)
    box:SetPoint("BOTTOMRIGHT", -16, 112)
    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 14, -12)
    scroll:SetPoint("BOTTOMRIGHT", -24, 12)
    local body = CreateFrame("Frame", nil, scroll)
    local textW = BOX_W - 32 - 14 - 24
    body:SetSize(textW, 10)
    scroll:SetScrollChild(body)
    f.text = UI.Text(body, "GameFontHighlight")
    f.text:SetPoint("TOPLEFT", 0, 0)
    f.text:SetWidth(textW)
    f.text:SetJustifyH("LEFT")
    f.text:SetSpacing(3)

    local bar = CreateFrame("Slider", nil, box)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(8)
    bar:SetPoint("TOPRIGHT", -8, -12)
    bar:SetPoint("BOTTOMRIGHT", -8, 12)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.45)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.85, 0.68, 0.2, 0.9)
    thumb:SetSize(8, 40)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function(_, v)
        if f.quiet then return end
        scroll:SetVerticalScroll(v)
    end)
    local function Max()
        return math.max(0, body:GetHeight() - scroll:GetHeight())
    end
    function f:ScrollTo(v)
        v = math.max(0, math.min(Max(), v))
        scroll:SetVerticalScroll(v)
        self.quiet = true
        bar:SetMinMaxValues(0, Max())
        bar:SetValue(v)
        self.quiet = false
        bar:SetShown(Max() > 0)
    end
    for _, frameWithWheel in ipairs({ scroll, box }) do
        frameWithWheel:EnableMouseWheel(true)
        frameWithWheel:SetScript("OnMouseWheel", function(_, delta)
            f:ScrollTo(scroll:GetVerticalScroll() - delta * 50)
        end)
    end
    f.body = body

    -- Sous les nouveautés : un avis, une idée, un bug ? Le lien à copier,
    -- remis tel quel si on le modifie
    local feedback = UI.Text(f, "GameFontNormal", L.WHATSNEW_FEEDBACK)
    feedback:SetPoint("BOTTOMLEFT", 20, 80)
    feedback:SetPoint("RIGHT", -20, 0)
    feedback:SetJustifyH("LEFT")
    local link = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    link:SetSize(BOX_W - 60, 20)
    link:SetPoint("BOTTOMLEFT", 26, 52)
    link:SetAutoFocus(false)
    link:SetText(FEEDBACK_URL)
    link:SetCursorPosition(0)
    link:SetScript("OnTextChanged", function(self, user)
        if user then
            self:SetText(FEEDBACK_URL)
            self:HighlightText()
        end
    end)
    link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    link:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- (ne plus l'afficher après une mise à jour ; /mmir news et le bouton
    -- de l'onglet Aide l'ouvrent toujours)
    local never = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    never:SetSize(24, 24)
    never:SetPoint("BOTTOMLEFT", 16, 14)
    local neverText = UI.Text(f, "GameFontHighlightSmall", L.WHATSNEW_NEVER)
    neverText:SetPoint("LEFT", never, "LEFT", 26, 0)
    neverText:SetWidth(BOX_W - 32 - 120 - 200 - 16 - 30)
    neverText:SetJustifyH("LEFT")
    never:SetHitRectInsets(0, -math.min(neverText:GetWidth(), (neverText:GetStringWidth() or 0) + 8), 0, 0)
    never:SetScript("OnClick", function(self) W.SetEnabled(not self:GetChecked()) end)
    UI.Tip(never, L.WHATSNEW_NEVER, L.WHATSNEW_NEVER_TIP)
    f.never = never

    local close = UI.Button(f, CLOSE or "OK", 120, 24, "grey")
    close:SetPoint("BOTTOMRIGHT", -16, 14)
    close:SetScript("OnClick", function() f:Hide() end)
    f.close = close
    local open = UI.Button(f, L.OPEN_CONFIG, 200, 24)
    open:SetPoint("RIGHT", close, "LEFT", -8, 0)
    open:SetScript("OnClick", function()
        f:Hide()
        UI.Show()
    end)

    -- (le champ du lien et la case aux couleurs de la charte)
    UI.SkinControls(f)
    f:Hide()
    frame = f
end

-- Ouvre la fenêtre ; since : la dernière version vue (pour « Nouveau »)
function W.Open(since)
    if not ns.db then return end
    if not frame then Build() end
    frame.sub:SetText(L.WHATSNEW_SUB:format(ns.VERSION))
    frame.never:SetChecked(not W.Enabled())
    frame.text:SetText(Text(since))
    frame.body:SetHeight(frame.text:GetStringHeight() + 8)
    frame:Show()
    -- (la hauteur du texte n'est sûre qu'une fois la fenêtre affichée)
    frame:ScrollTo(0)
    C_Timer.After(0, function()
        frame.body:SetHeight(frame.text:GetStringHeight() + 8)
        frame:ScrollTo(0)
    end)
end

-- Montrée après une mise à jour ? (onglet Réglages, ou la case de la
-- fenêtre ; db.options.whatsNew, coché par défaut)
function W.Enabled()
    return ns.db and ns.db.options.whatsNew ~= false
end

function W.SetEnabled(on)
    ns.db.options.whatsNew = on and true or false
    ns.Fire("OPTIONS")
end

-- À la connexion : la fenêtre si l'addon a été mis à jour depuis la
-- dernière fois (et qu'on ne l'a pas coupée). Première installation :
-- rien, la version est retenue. En combat : à la fin du combat.
local waiting
function W.MaybeShow()
    if not ns.db then return end
    if InCombatLockdown() then
        if not waiting then
            waiting = CreateFrame("Frame")
            waiting:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                W.MaybeShow()
            end)
        end
        waiting:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local current, last = ns.VERSION, ns.db.lastVersion
    ns.db.lastVersion = current
    if last == nil then
        -- (rien de retenu : installé à l'instant, ou avant que l'addon ne
        -- retienne sa version)
        if ns.freshInstall then return end
        last = BEFORE
    end
    if Newer(current, last) and W.Enabled() then W.Open(last) end
end
