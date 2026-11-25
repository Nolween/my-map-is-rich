-- Onglet « Aide » : un guide en étapes plutôt qu'un long texte, le même que
-- celui de My Guild Is Rich (UI/HelpTab.lua là-bas). À gauche, les étapes
-- (icône, titre, numéro) ; à droite, l'étape choisie (icône dans un rond
-- cerclé d'or, titre, points numérotés, les mots importants en or) ; en bas,
-- Précédent / Ouvrir cet écran / Suivant. La molette change aussi d'étape.
-- Au-dessus, la bande de la page : une phrase, Nouveautés et Crédits.
--
-- Textes : L.HELP_<clé>_T (titre court) et L.HELP_<clé> (points séparés par des
-- retours à la ligne). Dans un point, {mot} est mis en or et {=CLÉ} est
-- remplacé par le libellé L.CLÉ de l'interface (sans son « (%d) »), pour que
-- le guide nomme les onglets exactement comme ils s'affichent.
--
-- À la manette, rien de plus : la page est dans la fenêtre de l'addon, que
-- Pad/Focus.lua mène déjà (la croix d'une étape à l'autre et vers les
-- boutons, A choisit, B ferme, LB / RB changent d'onglet).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MAX_POINTS = 7
local ICONS = "Interface\\Icons\\"

-- Fermer la fenêtre de l'addon, puis ouvrir la carte (pas en combat : la
-- carte du jeu est protégée ; un geste noté, ns.Risky, comme dans
-- UI/QuestPanel.lua)
local function OpenMap()
    UI.Hide()
    if not InCombatLockdown() and ToggleWorldMap and ns.Risky("OpenMap") then pcall(ToggleWorldMap) end
end

-- Fermer la fenêtre de l'addon, puis ouvrir le navigateur de lieux (sur
-- l'onglet which : nil pour Lieux, "queue" pour la file). Il est sur la carte,
-- sous cette fenêtre : on la ferme d'abord.
local function OpenPlaces(which)
    UI.Hide()
    if ns.Places then ns.Places.Show(which) end
end

-- key (textes L.HELP_<key>_T et L.HELP_<key>), icon ;
-- go = { onglet } : l'onglet de la fenêtre que montre l'étape ;
-- action = { label, tip, run } : le bouton du milieu fait autre chose ;
-- commands = { [n° du point] = { cmd, run? } } : un bouton « Lancer » au bout
-- de ce point (voir UI.StepGuide)
local STEPS = {
    { key = "MAP", icon = ICONS .. "INV_Misc_Map_01",
        action = { label = "HELP_OPEN_MAP", tip = "HELP_OPEN_MAP_TIP", run = OpenMap } },
    { key = "ICONS", icon = ICONS .. "INV_Misc_Spyglass_02",
        action = { label = "HELP_OPEN_MAP", tip = "HELP_OPEN_MAP_TIP", run = OpenMap } },
    { key = "ROUTE", icon = ICONS .. "Ability_Tracking", go = { "travel" } },
    { key = "PLACES", icon = ICONS .. "INV_Misc_Book_09",
        action = { label = "HELP_OPEN_PLACES", tip = "HELP_OPEN_PLACES_TIP", run = function() OpenPlaces() end } },
    { key = "QUEUE", icon = ICONS .. "INV_Misc_Note_01",
        action = { label = "HELP_OPEN_QUEUE", tip = "HELP_OPEN_QUEUE_TIP", run = function() OpenPlaces("queue") end } },
    { key = "QUESTS", icon = ICONS .. "INV_Scroll_03", go = { "map" } },
    { key = "TRACKER", icon = ICONS .. "INV_Misc_Note_02", go = { "quests" } },
    { key = "GROUP", icon = ICONS .. "INV_Misc_GroupNeedMore", go = { "travel" } },
    { key = "PINS", icon = ICONS .. "INV_Inscription_Tradeskill01",
        action = { label = "HELP_OPEN_MAP", tip = "HELP_OPEN_MAP_TIP", run = OpenMap } },
    { key = "DUNGEON", icon = ICONS .. "INV_Misc_Head_Dragon_01" },
    { key = "PAD", icon = ICONS .. "INV_Misc_EngGizmos_20" },
    { key = "WINDOW", icon = ICONS .. "INV_Misc_Bag_10" },
    { key = "COMMANDS", icon = ICONS .. "INV_Misc_Gear_01",
        commands = {
            [1] = { cmd = "carte" },
            [2] = { cmd = "lieux", run = function() OpenPlaces() end },
            [3] = { cmd = "trajet" },
            [4] = { cmd = "suivi" },
            [5] = { cmd = "news" },
            -- (point 6, /mmir pourquoi : il lui faut une quête)
            [7] = { cmd = "etat" },
        } },
}

local function Hex(c)
    return ("ff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
        math.floor(c[3] * 255 + 0.5))
end

-- Un point du guide, mis en forme dans la couleur color ; values(clé)
-- remplace {#clé} (facultatif)
local function Format(text, color, values)
    local hex = Hex(color)
    text = text:gsub("{=([%w_]+)}", function(key)
        local label = (L[key] or key):gsub("%s*%(%%d%)", "")
        return "|c" .. hex .. label .. "|r"
    end)
    if values then
        text = text:gsub("{#([%w_]+)}", function(key) return "|c" .. hex .. tostring(values(key) or "?") .. "|r" end)
    end
    text = text:gsub("{(.-)}", function(word) return "|c" .. hex .. word .. "|r" end)
    return text
end

local function Points(text)
    local list = {}
    for line in (text or ""):gmatch("[^\n]+") do list[#list + 1] = line end
    return list
end

-- Une texture découpée en rond (si le jeu sait masquer les textures)
local function Round(frame, tex)
    if not frame.CreateMaskTexture then return end
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
end

local function RoundColor(frame, layer, sublevel, size)
    local t = frame:CreateTexture(nil, layer, nil, sublevel)
    t:SetSize(size, size)
    t:SetPoint("CENTER")
    t:SetColorTexture(1, 1, 1, 1)
    Round(frame, t)
    return t
end

local GOLD = { 1, 0.82, 0 }
local SIDE_W = 260

-- Un texte dont les {mots} sont mis en or (aussi pour le tutoriel, UI/Tutorial.lua)
function UI.GoldWords(text) return Format(text or "", GOLD) end

-- Une icône dans un rond cerclé d'or, sur le fond « well » (comme celle de
-- l'étape du guide ; aussi le tutoriel, UI/Tutorial.lua). Rend le cadre ;
-- f.icon : la texture, à remplir par f.icon:SetTexture
function UI.RoundIcon(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local ring = RoundColor(f, "BORDER", 0, size)
    ring:SetVertexColor(0.69, 0.54, 0.24, 1)
    local back = RoundColor(f, "BORDER", 1, size - 6)
    UI.Tint(back, "well")
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(size - 10, size - 10)
    f.icon:SetPoint("CENTER")
    Round(f, f.icon)
    return f
end

-- Un guide en étapes dans page :
--   opts.steps    : { { key, icon, go, action, commands } } ; textes
--                   L.HELP_<key>_T et L.HELP_<key> ; action = { label, tip,
--                   run } remplace « Ouvrir cet écran » ; commands = { [n] =
--                   { cmd, run?, can? } } : un bouton « Lancer » au bout du
--                   point n (run, ou la commande /mmir cmd ; grisé si can()
--                   est faux)
--   opts.goTo     : function(onglet) : « Ouvrir cet écran »
--   opts.finish   : function() : le bouton de la dernière étape
--   opts.values   : function(clé) -> texte : remplace {#clé} dans les points
--   opts.sideW    : largeur de la liste des étapes (SIDE_W par défaut)
--   opts.height   : hauteur de la page, si elle n'est pas encore connue
-- Rend show(n) : affiche l'étape n.
function UI.StepGuide(page, opts)
    local steps = opts.steps
    local sideW = opts.sideW or SIDE_W
    local current = 1
    local Show

    -- À gauche : les étapes
    local side = UI.Inset(page)
    side:SetPoint("TOPLEFT", 0, 0)
    side:SetPoint("BOTTOMLEFT", 0, 0)
    side:SetWidth(sideW)
    local sideTitle = UI.Text(side, "GameFontNormalSmall", L.HELP_STEPS)
    sideTitle:SetPoint("TOPLEFT", 12, -12)
    local buttons = {}
    -- (l'écart entre deux étapes : 40 px, moins si la liste ne tiendrait pas)
    local height = opts.height or page:GetHeight()
    local pitch = 36
    if height and height > 0 then pitch = math.max(28, math.min(40, math.floor((height - 36) / #steps))) end
    for i, step in ipairs(steps) do
        local b = UI.NavButton(side, pitch - 4)
        b:SetPoint("TOPLEFT", 6, -30 - (i - 1) * pitch)
        b:SetPoint("RIGHT", side, "RIGHT", -6, 0)
        b:SetIconTexture(step.icon)
        b.text:SetText(L["HELP_" .. step.key .. "_T"])
        b.count:SetText(tostring(i))
        b:SetScript("OnClick", function() Show(i) end)
        buttons[i] = b
    end

    -- À droite : l'étape
    local card = UI.Inset(page)
    card:SetPoint("TOPLEFT", sideW + UI.PAGE_GAP, 0)
    card:SetPoint("BOTTOMRIGHT", 0, 0)

    local iconFrame = CreateFrame("Frame", nil, card)
    iconFrame:SetSize(64, 64)
    iconFrame:SetPoint("TOPLEFT", 24, -22)
    -- (l'anneau d'or et la pastille des points : des couleurs à sens, comme
    -- dans My Guild Is Rich ; le fond du rond suit le thème)
    local iconRing = RoundColor(iconFrame, "BORDER", 0, 64)
    iconRing:SetVertexColor(0.69, 0.54, 0.24, 1)
    local iconBack = RoundColor(iconFrame, "BORDER", 1, 58)
    UI.Tint(iconBack, "well")
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(54, 54)
    icon:SetPoint("CENTER")
    Round(iconFrame, icon)

    local title = UI.Text(card, "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 16, -10)
    title:SetPoint("RIGHT", card, "RIGHT", -24, 0)
    title:SetJustifyH("LEFT")
    local counter = UI.Text(card, "GameFontDisableSmall")
    counter:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

    local rule = UI.Rule(card)
    rule:SetPoint("TOPLEFT", 24, -104)
    rule:SetPoint("TOPRIGHT", -24, -104)

    local points = {}
    for n = 1, MAX_POINTS do
        local num = CreateFrame("Frame", nil, card)
        num:SetSize(24, 24)
        local ring = RoundColor(num, "BORDER", 0, 24)
        ring:SetVertexColor(0.54, 0.43, 0.16, 1)
        local back = RoundColor(num, "BORDER", 1, 22)
        back:SetVertexColor(0.165, 0.13, 0.06, 1)
        num.text = UI.Text(num, "GameFontNormal", tostring(n))
        num.text:SetPoint("CENTER", 0, 0)
        local text = UI.Text(card, "GameFontHighlight")
        text:SetJustifyH("LEFT")
        text:SetSpacing(4)
        if n == 1 then
            text:SetPoint("TOPLEFT", 64, -124)
        else
            text:SetPoint("TOPLEFT", points[n - 1].text, "BOTTOMLEFT", 0, -14)
        end
        text:SetPoint("RIGHT", card, "RIGHT", -30, 0)
        num:SetPoint("TOPRIGHT", text, "TOPLEFT", -12, 5)
        -- (le bouton « Lancer » d'une commande, au bout du point)
        local run = UI.Button(card, L.HELP_RUN, 100, 22, "grey")
        run:SetPoint("TOPLEFT", text, "TOPRIGHT", 12, 4)
        run:Hide()
        UI.Tip(run, L.HELP_RUN, function()
            return run.command and L.HELP_RUN_TIP:format("/mmir " .. run.command.cmd)
        end)
        run:SetScript("OnClick", function(self)
            local c = self.command
            if not c then return end
            if c.run then
                c.run()
            elseif SlashCmdList.MYMAPISRICH then
                SlashCmdList.MYMAPISRICH(c.cmd)
            end
        end)
        points[n] = { num = num, text = text, run = run }
    end

    -- En bas : Précédent, Ouvrir cet écran, Suivant (ou « C'est parti ! »)
    local bottomRule = UI.Rule(card)
    bottomRule:SetPoint("BOTTOMLEFT", 24, 56)
    bottomRule:SetPoint("BOTTOMRIGHT", -24, 56)
    local prev = UI.Button(card, L.HELP_PREV, 150, 28, "grey")
    prev:SetPoint("BOTTOMLEFT", 24, 16)
    local nextB = UI.Button(card, L.HELP_NEXT, 150, 28, "grey")
    nextB:SetPoint("BOTTOMRIGHT", -24, 16)
    local go = UI.Button(card, L.HELP_GO, 220, 30)
    go:SetPoint("BOTTOM", 0, 15)
    -- (ou le bouton propre à l'étape : step.action)
    UI.Tip(go, function()
        local action = steps[current].action
        return action and L[action.label] or L.HELP_GO
    end, function()
        local action = steps[current].action
        if action then return action.tip and L[action.tip] end
        return L.HELP_GO_TIP
    end)

    prev:SetScript("OnClick", function() Show(current - 1) end)
    nextB:SetScript("OnClick", function()
        if current < #steps then
            Show(current + 1)
        elseif opts.finish then
            opts.finish()
        end
    end)
    go:SetScript("OnClick", function()
        local step = steps[current]
        if step.action then
            step.action.run()
            return
        end
        local target = step.go
        if target and opts.goTo then opts.goTo(target[1], target[2]) end
    end)

    function Show(n)
        current = math.max(1, math.min(#steps, n or current))
        local step = steps[current]
        for i, b in ipairs(buttons) do b:SetSelected(i == current) end
        icon:SetTexture(step.icon)
        title:SetText(L["HELP_" .. step.key .. "_T"])
        counter:SetText(L.HELP_STEP_OF:format(current, #steps))
        local list = Points(L["HELP_" .. step.key])
        local commands = step.commands
        for i, point in ipairs(points) do
            local line = list[i]
            -- (une étape de commandes : le texte laisse la place aux boutons)
            point.text:SetPoint("RIGHT", card, "RIGHT", commands and -140 or -30, 0)
            point.text:SetText(line and Format(line, step.textColor or GOLD, opts.values) or "")
            point.text:SetShown(line ~= nil)
            point.num:SetShown(line ~= nil)
            local command = line and commands and commands[i]
            point.run.command = command or nil
            point.run:SetShown(command ~= nil)
            if command then point.run:SetEnabled(not command.can or command.can()) end
        end
        prev:SetEnabled(current > 1)
        nextB:SetText(current < #steps and L.HELP_NEXT or L.HELP_START)
        go:SetText(step.action and L[step.action.label] or L.HELP_GO)
        go:SetShown(step.go ~= nil or step.action ~= nil)
    end

    page:EnableMouseWheel(true)
    page:SetScript("OnMouseWheel", function(_, delta) Show(current - delta) end)
    page:SetScript("OnShow", function() Show(current) end)
    Show(1)
    return Show
end

-- L'onglet Aide de la fenêtre (UI/MainFrame.lua) : la bande du haut (une
-- phrase, Revoir le tutoriel, Nouveautés et Crédits), puis le guide.
-- height : la hauteur de la page (la fenêtre n'est pas encore affichée
-- quand on la construit).
function UI.BuildHelpPage(page, height)
    UI.PageIntro(page, L.HELP_INTRO, 490)
    -- (les nouveautés des dernières versions : UI/WhatsNew.lua ; les crédits :
    -- UI/Credits.lua ; le tutoriel du premier lancement : UI/Tutorial.lua)
    local credits = UI.PageButton(page, L.CREDITS_BUTTON, 130)
    credits:SetScript("OnClick", function() if ns.Credits then ns.Credits.Open(page) end end)
    UI.Tip(credits, L.CREDITS_BUTTON, L.CREDITS_BUTTON_TIP)
    local news = UI.PageButton(page, L.WHATSNEW_BUTTON, 160, credits)
    news:SetScript("OnClick", function() if ns.WhatsNew then ns.WhatsNew.Open() end end)
    UI.Tip(news, L.WHATSNEW_BUTTON, L.WHATSNEW_BUTTON_TIP)
    local tuto = UI.PageButton(page, L.TUTO_REPLAY, 180, news, "red")
    tuto:SetScript("OnClick", function() if ns.Tutorial then ns.Tutorial.Open(1) end end)
    UI.Tip(tuto, L.TUTO_REPLAY, L.TUTO_REPLAY_TIP)

    local guide = CreateFrame("Frame", nil, page)
    guide:SetPoint("TOPLEFT", 0, UI.PAGE_TOP)
    guide:SetPoint("BOTTOMRIGHT", 0, 0)
    UI.StepGuide(guide, {
        steps = STEPS,
        height = height and (height + UI.PAGE_TOP) or nil,
        goTo = function(tab) UI.Show(tab) end,
        finish = OpenMap,
    })
end
