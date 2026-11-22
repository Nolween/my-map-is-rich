-- Petits éléments d'interface maison, dessinés selon la charte graphique
-- commune aux addons (CHARTE.md, reprise de My Guild Is Rich et My Auction
-- House Is Rich) : la palette et ses thèmes, le cadre des fenêtres, les
-- boutons, les panneaux, les boutons de liste, la barre de défilement, les
-- cases et le curseur de réglage.
-- Aucune texture du jeu en fond. Aucune fenêtre n'est mise dans
-- UISpecialFrames (la liste d'Échap) : l'interface manette de Forever la lit
-- en fermant ses fenêtres, et une fenêtre d'addon y ferait bloquer B.
local _, root = ...
local ns = root.Plus
local L = ns.L

local UI = ns.UI or {}
ns.UI = UI

---------------------------------------------------------------------------
-- La palette de la charte : { r, g, b }, de 0 à 1. Les fenêtres prennent
-- leurs couleurs ici, jamais une texture du jeu en fond. C'est le thème
-- « Brun », la référence : les autres thèmes en dérivent (UI.SetTheme). Les
-- clés de FIXED ne changent pas avec le thème : l'or, les couleurs qui ont
-- un sens, le rouge des boutons principaux.
---------------------------------------------------------------------------
local BASE = {
    windowBottom = { 0.051, 0.039, 0.027 },   -- #0d0a07 fond de la fenêtre (bas)
    windowTop = { 0.082, 0.063, 0.047 },      -- #15100c fond de la fenêtre (haut)
    windowEdge = { 0.231, 0.184, 0.133 },     -- #3b2f22 liseré de la fenêtre, des en-têtes, des catégories
    windowInner = { 0.42, 0.32, 0.2 },        -- #6b5233 liseré intérieur
    panelBottom = { 0.067, 0.051, 0.039 },    -- #110d0a panneau (bas)
    panelTop = { 0.11, 0.086, 0.067 },        -- #1c1611 panneau (haut)
    panelEdge = { 0.29, 0.23, 0.16 },         -- #4a3b29 liseré des panneaux
    headerBottom = { 0.09, 0.067, 0.047 },    -- #17110c en-têtes, barre de titre (bas)
    headerTop = { 0.165, 0.125, 0.094 },      -- #2a2018 en-têtes, barre de titre (haut)
    edgeDim = { 0.18, 0.14, 0.098 },          -- #2e2419 liseré discret (cases, zones, catégorie de niveau 2)
    edgeDark = { 0.14, 0.11, 0.078 },         -- #241c14 liseré d'une case de grille
    well = { 0.05, 0.039, 0.031 },            -- #0d0a08 fond d'une case, d'une zone en retrait
    track = { 0.04, 0.03, 0.024 },            -- #0a0806 fond d'une jauge, d'un curseur
    navTop = { 0.165, 0.13, 0.098 },          -- #2a2119 catégorie de niveau 1 (haut)
    navBottom = { 0.086, 0.067, 0.047 },      -- #16110c catégorie de niveau 1 (bas)
    nav2Top = { 0.133, 0.102, 0.075 },        -- #221a13 catégorie de niveau 2 (haut)
    nav2Bottom = { 0.071, 0.055, 0.039 },     -- #120e0a catégorie de niveau 2 (bas)
    tabTop = { 0.133, 0.102, 0.071 },         -- #221a12 onglet de la barre de titre (haut)
    tabBottom = { 0.071, 0.051, 0.035 },      -- #120d09 onglet de la barre de titre (bas)
    tabOnTop = { 0.227, 0.173, 0.11 },        -- #3a2c1c onglet ouvert (haut)
    tabOnBottom = { 0.114, 0.082, 0.055 },    -- #1d150e onglet ouvert (bas)
    greyTop = { 0.294, 0.271, 0.251 },        -- #4b4540 bouton secondaire (haut)
    greyBottom = { 0.11, 0.098, 0.086 },      -- #1c1916 bouton secondaire (bas)
    greyRing = { 0.353, 0.29, 0.208 },        -- #5a4a35 son liseré
    offTop = { 0.18, 0.16, 0.14 },            -- #2e2924 bouton grisé (haut)
    offBottom = { 0.08, 0.07, 0.06 },         -- #14120f bouton grisé (bas)
    offRing = { 0.25, 0.21, 0.16 },           -- #403629 son liseré
    inputBg = { 0.016, 0.012, 0.008 },        -- #040302 fond d'un champ de saisie
    checkBg = { 0.027, 0.02, 0.016 },         -- #070504 fond d'une case à cocher
    edgeLight = { 0.54, 0.45, 0.31 },         -- #8a734f liseré d'une case à cocher, d'un curseur
    dialog = { 0.04, 0.031, 0.024 },          -- #0a0806 fenêtres par-dessus l'écran
    dialogEdge = { 0.42, 0.35, 0.24 },        -- #6b5a3d leur liseré, celui des champs
    textDim = { 0.647, 0.604, 0.525 },        -- #a59a86 texte secondaire
    textFaint = { 0.541, 0.502, 0.439 },      -- #8a8070 aide, détails
    -- (pareilles dans tous les thèmes)
    gold = { 1, 0.82, 0 },                    -- #ffd100 texte doré, sélection, « à moi »
    goldSoft = { 0.69, 0.54, 0.24 },          -- #b08a3e anneau du portrait, onglet ouvert
    goldDim = { 0.54, 0.43, 0.16 },           -- #8a6e29 liseré doré sombre (épinglé, favori)
    good = { 0.25, 1, 0.25 },                 -- #40ff40 positif (bonne affaire, assez, vendu)
    online = { 0.247, 0.82, 0.247 },          -- #3fd13f point « en ligne », pastille
    bad = { 1, 0.44, 0.38 },                  -- #ff7060 négatif (trop cher, il en manque, expiré)
    redTop = { 0.66, 0.094, 0.059 },          -- #a8180f bouton principal (haut)
    redBottom = { 0.278, 0.02, 0.012 },       -- #470503 bouton principal (bas)
    redRing = { 0.435, 0.33, 0.153 },         -- #6f5427 son liseré doré
}
local FIXED = { gold = true, goldSoft = true, goldDim = true, good = true, online = true, bad = true,
    redTop = true, redBottom = true, redRing = true }

-- La palette en cours : les mêmes tables, dont les valeurs changent avec le
-- thème (qui en garde une sous la main a toujours la bonne couleur)
UI.COLORS = {}
for key, c in pairs(BASE) do UI.COLORS[key] = { c[1], c[2], c[3] } end

-- Les thèmes : le brun de la charte, et des variantes qui en dérivent
-- couleur par couleur (teinte remplacée par hue, en degrés ; saturation
-- multipliée par sat ; clarté l -> l * mul + add). Chaque couleur garde sa
-- place par rapport aux autres : un liseré reste plus clair que son
-- panneau, un en-tête que la liste. (Les mêmes que My Guild Is Rich.)
UI.THEMES = {
    { id = "brown", label = "THEME_BROWN" },
    { id = "grey", label = "THEME_GREY", sat = 0, mul = 1.1, add = 0.015 },
    { id = "blue", label = "THEME_BLUE", hue = 215, sat = 1.25, mul = 1.1, add = 0.01 },
    { id = "green", label = "THEME_GREEN", hue = 135, sat = 1, mul = 1.05, add = 0.008 },
    { id = "purple", label = "THEME_PURPLE", hue = 275, sat = 1.3, mul = 1.1, add = 0.012 },
    { id = "pink", label = "THEME_PINK", hue = 328, sat = 1.35, mul = 1.15, add = 0.02 },
}
local THEME_BY_ID = {}
for _, t in ipairs(UI.THEMES) do THEME_BY_ID[t.id] = t end

local function ToHSL(r, g, b)
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local l = (max + min) / 2
    if max == min then return 0, 0, l end
    local d = max - min
    local s = l > 0.5 and d / (2 - max - min) or d / (max + min)
    local h
    if max == r then
        h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
        h = (b - r) / d + 2
    else
        h = (r - g) / d + 4
    end
    return h / 6, s, l
end

local function FromHSL(h, s, l)
    if s == 0 then return l, l, l end
    local function Hue(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return Hue(p, q, h + 1 / 3), Hue(p, q, h), Hue(p, q, h - 1 / 3)
end

-- Une couleur de la palette brune dans un thème
local function Derive(c, theme)
    if not theme.mul then return c[1], c[2], c[3] end
    local h, s, l = ToHSL(c[1], c[2], c[3])
    if theme.hue then h = theme.hue / 360 end
    s = math.min(1, s * theme.sat)
    l = math.min(1, l * theme.mul + theme.add)
    return FromHSL(h, s, l)
end

-- Une couleur d'un thème, sans le choisir (l'aperçu des réglages)
function UI.ThemeColor(id, key)
    local c = BASE[key]
    if FIXED[key] then return c[1], c[2], c[3] end
    return Derive(c, THEME_BY_ID[id] or THEME_BY_ID.brown)
end

-- Une couleur de la palette en cours : r, g, b (multipliés par k) ; avec
-- son opacité : r, g, b, a (à mettre en dernier dans un appel)
function UI.RGB(key, k)
    local c = UI.COLORS[key]
    k = k or 1
    return c[1] * k, c[2] * k, c[3] * k
end

function UI.RGBA(key, a)
    local c = UI.COLORS[key]
    return c[1], c[2], c[3], a or 1
end

-- « |cffrrggbb » d'une couleur de la palette (dans un texte)
function UI.Hex(key)
    local r, g, b = UI.RGB(key)
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- Ce qui est peint aux couleurs de la palette : [objet] = sa peinture,
-- refaite quand le thème change. Un objet repeint autrement en sort.
local painted = {}

-- Peint obj par paint() maintenant et à chaque changement de thème (un
-- fond de cadre, une couleur de texte, une couleur qui dépend d'autre chose
-- que la palette...)
function UI.OnTheme(obj, paint)
    painted[obj] = paint
    paint()
end

local function SetGradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    tex:SetColorTexture(1, 1, 1, 1)
    if tex.SetGradient and CreateColor then
        local ok = pcall(tex.SetGradient, tex, orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
        if ok then return end
    end
    tex:SetColorTexture((r1 + r2) / 2, (g1 + g2) / 2, (b1 + b2) / 2, (a1 + a2) / 2)
end

-- Un dégradé : "VERTICAL" (du bas c1 vers le haut c2) ou "HORIZONTAL" (de
-- la gauche c1 vers la droite c2) ; sans dégradé possible, la moyenne des
-- deux couleurs. En chiffres : ne suit pas le thème (UI.Fade pour les
-- couleurs de la palette).
function UI.Gradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    painted[tex] = nil
    SetGradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
end

-- Un dégradé entre deux couleurs de la palette (k : plus sombre ou plus
-- clair), qui suit le thème
function UI.Fade(tex, orientation, key1, a1, key2, a2, k)
    UI.OnTheme(tex, function()
        local r1, g1, b1 = UI.RGB(key1, k)
        local r2, g2, b2 = UI.RGB(key2, k)
        SetGradient(tex, orientation, r1, g1, b1, a1 or 1, r2, g2, b2, a2 or 1)
    end)
end

-- Un aplat d'une couleur de la palette, qui suit le thème
function UI.Fill(tex, key, a)
    UI.OnTheme(tex, function() tex:SetColorTexture(UI.RGBA(key, a)) end)
end

-- Un aplat en chiffres (une couleur fixe : l'or, le noir transparent...)
function UI.Solid(tex, r, g, b, a)
    painted[tex] = nil
    tex:SetColorTexture(r, g, b, a)
end

-- La teinte d'une texture (SetVertexColor), qui suit le thème
function UI.Tint(tex, key, a)
    UI.OnTheme(tex, function() tex:SetVertexColor(UI.RGBA(key, a)) end)
end

-- Le thème en cours (son id)
function UI.Theme()
    return UI.theme or "brown"
end

-- Change le thème : la palette, puis tout ce qui a été peint avec elle.
-- (Au chargement, quiet : sans enregistrer ni prévenir.)
function UI.SetTheme(id, quiet)
    local theme = THEME_BY_ID[id] or THEME_BY_ID.brown
    UI.theme = theme.id
    for key, c in pairs(BASE) do
        local cur = UI.COLORS[key]
        if FIXED[key] then
            cur[1], cur[2], cur[3] = c[1], c[2], c[3]
        else
            cur[1], cur[2], cur[3] = Derive(c, theme)
        end
    end
    for _, paint in pairs(painted) do
        local ok, err = pcall(paint)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
    if quiet then return end
    if ns.db then ns.db.options.theme = theme.id end
    if ns.Fire then ns.Fire("THEME") end
end

-- Un liseré d'un pixel autour d'un cadre (inset : en retrait) ; rend ses
-- quatre traits, avec :SetShown(on) et :SetColor(r, g, b, a). Une couleur
-- de la palette, qui suit le thème : UI.Border(cadre, clé, a, inset,
-- layer) et :SetColor(clé, a).
function UI.Border(frame, r, g, b, a, inset, layer)
    local key
    if type(r) == "string" then
        key, a, inset, layer = r, g, b, a
    end
    inset = inset or 0
    local t = {}
    for i = 1, 4 do
        t[i] = frame:CreateTexture(nil, layer or "BORDER")
    end
    t[1]:SetPoint("TOPLEFT", inset, -inset)
    t[1]:SetPoint("TOPRIGHT", -inset, -inset)
    t[1]:SetHeight(1)
    t[2]:SetPoint("BOTTOMLEFT", inset, inset)
    t[2]:SetPoint("BOTTOMRIGHT", -inset, inset)
    t[2]:SetHeight(1)
    t[3]:SetPoint("TOPLEFT", inset, -inset)
    t[3]:SetPoint("BOTTOMLEFT", inset, inset)
    t[3]:SetWidth(1)
    t[4]:SetPoint("TOPRIGHT", -inset, -inset)
    t[4]:SetPoint("BOTTOMRIGHT", -inset, inset)
    t[4]:SetWidth(1)
    function t:SetShown(on)
        for i = 1, 4 do self[i]:SetShown(on and true or false) end
    end
    function t:SetColor(cr, cg, cb, ca)
        if type(cr) == "string" then
            UI.OnTheme(self, function()
                for i = 1, 4 do self[i]:SetColorTexture(UI.RGBA(cr, cg)) end
            end)
            return
        end
        painted[self] = nil
        for i = 1, 4 do self[i]:SetColorTexture(cr, cg, cb, ca) end
    end
    if key then t:SetColor(key, a) else t:SetColor(r, g, b, a) end
    return t
end

local function HasAtlas(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
end
UI.HasAtlas = HasAtlas

---------------------------------------------------------------------------
-- Textes, info-bulles
---------------------------------------------------------------------------
function UI.Text(parent, font, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    if text then fs:SetText(text) end
    return fs
end

-- Un texte secondaire (une phrase d'accueil, une précision) : petit, dans
-- la couleur secondaire du thème
function UI.DimText(parent, text, font)
    local fs = UI.Text(parent, font or "GameFontHighlightSmall", text)
    UI.OnTheme(fs, function() fs:SetTextColor(UI.RGB("textDim")) end)
    return fs
end

-- Une petite étiquette au-dessus d'un nom ou d'une liste (« ENCHÈRE ») :
-- grise, en capitales
function UI.Label(parent, text)
    local fs = UI.Text(parent, "GameFontDisableSmall", text and text:upper())
    fs:SetJustifyH("LEFT")
    return fs
end

-- Un titre de section : texte doré, et un trait doré jusqu'au bord droit
-- (right : décalage depuis le bord droit du parent)
function UI.Section(parent, text, x, y, right)
    local title = UI.Text(parent, "GameFontNormalLarge", text)
    title:SetPoint("TOPLEFT", x, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("LEFT", title, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", parent, "TOPRIGHT", -(right or 16), y - 8)
    return title
end

-- Une info-bulle : son titre (en or), puis le texte. title et text peuvent
-- être des fonctions (texte qui dépend de l'état).
function UI.Tip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        local t = type(title) == "function" and title() or title
        local d = type(text) == "function" and text() or text
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(t or "", 1, 0.82, 0, 1, true)
        if d then GameTooltip:AddLine(d, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Un nom de joueur dans la couleur de sa classe (classFile : « MAGE »...),
-- grisé s'il est hors ligne (dim)
function UI.ClassColored(name, classFile, dim)
    name = name or "?"
    if dim then return "|cff808080" .. name .. "|r" end
    local c = classFile and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
    if not c then return name end
    return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, name)
end

---------------------------------------------------------------------------
-- Boutons
---------------------------------------------------------------------------
-- Un bouton de la charte : rouge en dégradé, liseré sombre puis doré, texte
-- doré (style "grey" : gris, pour les actions secondaires). Survol : plus
-- clair ; appuyé : plus sombre ; grisé : texte gris, fond éteint.
-- LockHighlight garde l'aspect survolé. Un seul bouton rouge par groupe
-- d'actions, si possible. (Des clés de la palette : le gris suit le thème,
-- le rouge non.)
local BUTTON_STYLES = {
    red = { top = "redTop", bottom = "redBottom", ring = "redRing" },
    grey = { top = "greyTop", bottom = "greyBottom", ring = "greyRing" },
}

function UI.Button(parent, text, width, height, style)
    local s = BUTTON_STYLES[style or "red"] or BUTTON_STYLES.red
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, height or 22)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetPoint("TOPLEFT", 1, -1)
    b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    local function Paint(dim)
        UI.Fade(b.bg, "VERTICAL", s.bottom, 1, s.top, 1, dim)
    end
    Paint()
    -- (un reflet clair en haut, le liseré sombre, puis le doré dehors)
    local shine = b:CreateTexture(nil, "BORDER")
    shine:SetPoint("TOPLEFT", 2, -2)
    shine:SetPoint("TOPRIGHT", -2, -2)
    shine:SetHeight(1)
    shine:SetColorTexture(1, 0.75, 0.47, 0.3)
    UI.Border(b, 0.06, 0.012, 0.008, 1, 1, "BORDER")
    local ring = UI.Border(b, s.ring, 1, 0, "BORDER")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    hl:SetColorTexture(1, 0.75, 0.5, 0.12)
    b:SetHighlightTexture(hl)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", 4, 0)
    fs:SetPoint("RIGHT", -4, 0)
    fs:SetWordWrap(false)
    b:SetFontString(fs)
    local small = (height or 22) < 22
    b:SetNormalFontObject(small and "GameFontNormalSmall" or "GameFontNormal")
    b:SetHighlightFontObject(small and "GameFontHighlightSmall" or "GameFontHighlight")
    b:SetDisabledFontObject(small and "GameFontDisableSmall" or "GameFontDisable")
    b:SetPushedTextOffset(1, -1)
    b:HookScript("OnMouseDown", function(self) if self:IsEnabled() then Paint(0.75) end end)
    b:HookScript("OnMouseUp", function(self) if self:IsEnabled() then Paint() end end)
    b:HookScript("OnDisable", function()
        UI.Fade(b.bg, "VERTICAL", "offBottom", 1, "offTop", 1)
        shine:Hide()
        ring:SetColor("offRing", 1)
    end)
    b:HookScript("OnEnable", function()
        Paint()
        shine:Show()
        ring:SetColor(s.ring, 1)
    end)
    b:SetText(text or "")
    return b
end

-- Un petit bouton gris avec une flèche (monter, descendre) : dir "up"/"down"
function UI.ArrowButton(parent, dir, size)
    local b = UI.Button(parent, "", size or 22, size or 22, "grey")
    local arrow = b:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(10, 9)
    arrow:SetPoint("CENTER")
    arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    if dir == "up" then arrow:SetTexCoord(0, 0.5625, 1, 0) else arrow:SetTexCoord(0, 0.5625, 0, 1) end
    b:HookScript("OnDisable", function() arrow:SetDesaturated(true) arrow:SetAlpha(0.4) end)
    b:HookScript("OnEnable", function() arrow:SetDesaturated(false) arrow:SetAlpha(1) end)
    return b
end

-- La croix « × » qui ferme : un petit carré rouge cerclé d'or
function UI.CloseButton(parent, size, onClick)
    local close = CreateFrame("Button", nil, parent)
    close:SetSize(size or 22, size or 22)
    local bg = close:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.Gradient(bg, "VERTICAL", 0.29, 0.02, 0.012, 1, 0.66, 0.094, 0.059, 1)
    UI.Border(close, 0.79, 0.65, 0.29, 1)
    local x = UI.Text(close, "GameFontNormalLarge", "×")
    x:SetPoint("CENTER", 0, 1)
    local hl = close:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.6, 0.4, 0.18)
    close:SetScript("OnClick", onClick or function() parent:Hide() end)
    return close
end

---------------------------------------------------------------------------
-- Panneaux, zones, traits
---------------------------------------------------------------------------
-- Le fond d'une fenêtre par-dessus l'écran (confirmation, menu, saisie d'un
-- prix...) : brun très sombre, liseré brun clair
function UI.DialogBackdrop(f)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    UI.Fill(bg, "dialog", 0.98)
    UI.Border(f, "dialogEdge", 1, 0, "BORDER")
end

-- Un cadre au fond d'une fenêtre par-dessus l'écran
function UI.Panel(parent, name, strata)
    local f = CreateFrame("Frame", name, parent)
    UI.DialogBackdrop(f)
    if strata then f:SetFrameStrata(strata) end
    return f
end

-- Un panneau sombre bordé (le fond de chaque zone d'un écran : catégories,
-- liste, détail) : brun très sombre en léger dégradé, liseré brun, un trait
-- noir juste dedans. Le contenu en est l'enfant.
function UI.Inset(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    UI.Fade(f.bg, "VERTICAL", "panelBottom", 0.97, "panelTop", 0.97)
    UI.Border(f, "panelEdge", 1)
    UI.Border(f, 0, 0, 0, 0.7, 1)
    return f
end

-- Une zone en retrait dans un panneau (une carte, une ligne de réglages, le
-- fond d'une case de grille) : un fond plus sombre, un liseré discret.
-- UI.PaintWell peint un cadre qui existe déjà ; UI.Well en crée un.
function UI.PaintWell(f)
    f.wellBg = f:CreateTexture(nil, "BACKGROUND")
    f.wellBg:SetAllPoints()
    UI.Fill(f.wellBg, "well", 0.85)
    f.edge = UI.Border(f, "edgeDim", 1, 0, "BORDER")
    return f
end

function UI.Well(parent)
    return UI.PaintWell(CreateFrame("Frame", nil, parent))
end

-- Un trait horizontal doré (sépare deux parties d'un détail) ; à placer
-- par deux points (largeur)
function UI.Rule(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetColorTexture(1, 0.82, 0, 0.22)
    return t
end

-- Un trait vertical fin (séparation de colonnes)
function UI.VLine(parent, x, top, bottom)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 0.82, 0, 0.18)
    t:SetWidth(1)
    t:SetPoint("TOPLEFT", x, top)
    t:SetPoint("BOTTOMLEFT", x, bottom)
    return t
end

-- Une étiquette (« Pour toi », « Ma vente ») : texte doré entre de petits
-- liserés dorés ; tag:SetText(texte) la redimensionne
function UI.Tag(parent, text)
    local tag = CreateFrame("Frame", nil, parent)
    tag:SetHeight(16)
    tag.text = UI.Text(tag, "GameFontNormalSmall", text)
    tag.text:SetPoint("CENTER", 0, 0)
    UI.Border(tag, 1, 0.82, 0, 0.6)
    function tag:SetText(t)
        self.text:SetText(t or "")
        self:SetWidth(self.text:GetStringWidth() + 12)
    end
    tag:SetText(text)
    return tag
end

-- Une pastille verte avec un nombre (ce qui attend, ce qui est pour moi) ;
-- badge:SetCount(n) la cache à 0
function UI.Badge(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(16, 14)
    b.bg = b:CreateTexture(nil, "OVERLAY")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0.11, 0.48, 0.11, 1)
    b.text = UI.Text(b, "GameFontHighlightSmall")
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetDrawLayer("OVERLAY", 7)
    function b:SetCount(n)
        n = n or 0
        self.text:SetText(n > 0 and tostring(n) or "")
        if n > 0 then self:SetWidth(math.max(16, self.text:GetStringWidth() + 8)) end
        self:SetShown(n > 0)
    end
    b:SetCount(0)
    return b
end

-- Un point de 8 px : vert en ligne, gris sinon ; dot:SetOnline(on)
function UI.OnlineDot(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(8, 8)
    t:SetTexture("Interface\\Buttons\\WHITE8x8")
    local ok, mask = pcall(parent.CreateMaskTexture, parent)
    if ok and mask then
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(t)
        t:AddMaskTexture(mask)
    end
    function t:SetOnline(on)
        if on then self:SetVertexColor(UI.RGBA("online")) else self:SetVertexColor(0.4, 0.4, 0.4, 1) end
    end
    t:SetOnline(false)
    return t
end

---------------------------------------------------------------------------
-- La fenêtre de l'addon : fond en léger dégradé, double liseré brun, barre
-- de titre en dégradé (titre doré à gauche, à côté du portrait, un petit
-- trait, puis les onglets ; croix rouge cerclée d'or à droite), portrait
-- rond cerclé d'or qui déborde en haut à gauche, barre d'état en bas.
---------------------------------------------------------------------------
UI.TITLE_H = 40          -- (la barre de titre, liseré compris)
UI.TITLE_X = 84          -- (le titre, à droite du portrait)
UI.STATUS_H = 24         -- (la barre d'état)

-- Le cadre d'une fenêtre (titleH : la barre de titre, liseré compris ;
-- left : la place du titre) ; rend le titre et la croix
function UI.WindowChrome(f, titleH, title, left)
    titleH = titleH or UI.TITLE_H
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    UI.Fade(bg, "VERTICAL", "windowBottom", 1, "windowTop", 1)
    UI.Border(f, "windowEdge", 1, 0, "BORDER")
    UI.Border(f, "windowEdge", 1, 1, "BORDER")
    UI.Border(f, "windowInner", 1, 2, "BORDER")
    local bar = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    bar:SetPoint("TOPLEFT", 3, -3)
    bar:SetPoint("TOPRIGHT", -3, -3)
    bar:SetHeight(titleH - 4)
    UI.Fade(bar, "VERTICAL", "headerBottom", 1, "headerTop", 1)
    local line = f:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", 3, -(titleH - 1))
    line:SetPoint("TOPRIGHT", -3, -(titleH - 1))
    line:SetHeight(1)
    UI.Fill(line, "panelEdge")
    local text = UI.Text(f, "GameFontNormalLarge", title)
    text:SetPoint("LEFT", f, "TOPLEFT", left or 16, -(titleH / 2) - 1)
    local close = UI.CloseButton(f, 22)
    close:SetPoint("TOPRIGHT", -8, -(titleH - 22) / 2)
    return text, close
end

-- Le portrait : un rond cerclé d'or, l'icône de l'addon dedans, qui déborde
-- en haut à gauche de la fenêtre
function UI.Portrait(f, icon)
    local portrait = CreateFrame("Frame", nil, f)
    portrait:SetSize(68, 68)
    portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 4, 8)
    portrait:SetFrameLevel(f:GetFrameLevel() + 20)
    local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    local function Disc(size, r, g, b, a, layer, sub)
        local t = portrait:CreateTexture(nil, layer, nil, sub)
        t:SetSize(size, size)
        t:SetPoint("CENTER")
        t:SetColorTexture(r, g, b, a)
        local ok, mask = pcall(portrait.CreateMaskTexture, portrait)
        if ok and mask then
            mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(t)
            t:AddMaskTexture(mask)
        end
        return t
    end
    UI.Fill(Disc(68, 0, 0, 0, 1, "BACKGROUND", 0), "headerTop")
    Disc(64, 0.69, 0.54, 0.24, 1, "BACKGROUND", 1)
    Disc(58, 0.165, 0.114, 0.031, 1, "BORDER", 0)
    local tex = Disc(54, 1, 1, 1, 1, "ARTWORK", 0)
    tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_Coin_01")
    portrait.icon = tex
    return portrait
end

-- Un disque : une texture rognée en rond (le masque du portrait), centrée
-- sur `parent` sauf si on la repose ; à peindre ensuite (UI.Fill, SetTexture)
function UI.Disc(parent, size, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
    t:SetSize(size, size)
    t:SetPoint("CENTER")
    local ok, mask = pcall(parent.CreateMaskTexture, parent)
    if ok and mask then
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(t)
        t:AddMaskTexture(mask)
    end
    return t
end

-- La barre d'état (24 px en bas du contenu) : un trait doré, un texte à
-- gauche, un à droite ; rend left, right
function UI.StatusBar(content)
    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.18)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 8, UI.STATUS_H)
    line:SetPoint("BOTTOMRIGHT", -8, UI.STATUS_H)
    local left = UI.Text(content, "GameFontHighlightSmall")
    left:SetPoint("BOTTOMLEFT", 12, 7)
    left:SetJustifyH("LEFT")
    local right = UI.Text(content, "GameFontNormalSmall")
    right:SetPoint("BOTTOMRIGHT", -12, 7)
    right:SetJustifyH("RIGHT")
    return left, right
end

---------------------------------------------------------------------------
-- Fond d'une ligne de liste : rayure une ligne sur deux (row.stripe),
-- choisie en doré (row.selected : un dégradé qui s'estompe vers la droite,
-- liseré doré)
function UI.RowBackground(row)
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(1, 1, 1, 0.022)
    row.selected = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.selected:SetAllPoints()
    UI.Gradient(row.selected, "HORIZONTAL", 1, 0.82, 0, 0.2, 1, 0.82, 0, 0.05)
    local border = UI.Border(row, 1, 0.82, 0, 0.5, 0, "BORDER")
    border:SetShown(false)
    -- (le liseré suit la ligne choisie)
    hooksecurefunc(row.selected, "SetShown", function(_, on) border:SetShown(on) end)
    hooksecurefunc(row.selected, "Hide", function() border:SetShown(false) end)
    hooksecurefunc(row.selected, "Show", function() border:SetShown(true) end)
    row.selected:Hide()
end

-- Un trait doré de 3 px sur le bord gauche d'une ligne (« à moi » : ma
-- vente, mon enchère...)
function UI.MarkBar(row)
    local t = row:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", 0, 0)
    t:SetPoint("BOTTOMLEFT", 0, 0)
    t:SetWidth(3)
    t:SetColorTexture(1, 0.82, 0, 1)
    t:Hide()
    return t
end

-- Un bouton de catégorie (à gauche des listes, comme à l'hôtel des ventes,
-- aux couleurs de la charte). level : 1 (un bouton brun en dégradé,
-- liseré), 2 (plus sombre, en retrait), 3 (le texte seul, encore en
-- retrait). Choisi : dégradé et liseré dorés, texte blanc.
-- b:SetLevel, b:SetSelected(on), b:SetIconTexture, b:SetTextLeft ; b.text,
-- b.icon (facultative) et b.count.
local NAV_STYLE = {
    { top = "navTop", bottom = "navBottom", edge = "windowEdge" },
    { top = "nav2Top", bottom = "nav2Bottom", edge = "edgeDim" },
}

function UI.NavButton(parent, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(height or 22)
    b.normal = b:CreateTexture(nil, "BACKGROUND")
    b.normal:SetAllPoints()
    b.edge = UI.Border(b, "windowEdge", 1, 0, "BORDER")
    b.sel = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.sel:SetAllPoints()
    UI.Gradient(b.sel, "HORIZONTAL", 1, 0.82, 0, 0.2, 1, 0.82, 0, 0.05)
    b.sel:Hide()
    b.selEdge = UI.Border(b, 1, 0.82, 0, 0.9, 0, "ARTWORK")
    b.selEdge:SetShown(false)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 0.82, 0, 0.07)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize((height or 22) - 8, (height or 22) - 8)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.icon:Hide()
    b.text = UI.Text(b, "GameFontNormalSmall")
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b.count = UI.Text(b, "GameFontDisableSmall")
    b.count:SetPoint("RIGHT", -8, 0)
    b.count:SetJustifyH("RIGHT")
    local function Font(self, on)
        if on then return self.level == 1 and "GameFontHighlight" or "GameFontHighlightSmall" end
        return self.level == 1 and "GameFontNormal" or (self.level == 2 and "GameFontNormalSmall" or "GameFontHighlightSmall")
    end
    function b:SetLevel(level, force)
        level = math.max(1, math.min(3, level or 1))
        if level == self.level and not force then return end
        local s = NAV_STYLE[level]
        if s then
            UI.Fade(self.normal, "VERTICAL", s.bottom, 1, s.top, 1)
            self.normal:Show()
            self.edge:SetColor(s.edge, 1)
            self.edge:SetShown(true)
        else
            self.normal:Hide()
            self.edge:SetShown(false)
        end
        local indent = (level - 1) * 14 + 10
        self.text:ClearAllPoints()
        if self.icon:IsShown() then
            self.icon:ClearAllPoints()
            self.icon:SetPoint("LEFT", indent - 4, 0)
            self.text:SetPoint("LEFT", self.icon, "RIGHT", 7, 0)
        else
            self.text:SetPoint("LEFT", self.textLeft or indent, 0)
        end
        self.text:SetPoint("RIGHT", self.count, "LEFT", -4, 0)
        self.level = level
        self:SetSelected(self.isSelected)
    end
    function b:SetIconTexture(tex)
        self.icon:SetTexture(tex)
        self.icon:SetShown(tex ~= nil)
        self:SetLevel(self.level, true)
    end
    -- (le texte plus à droite : de la place pour autre chose à gauche)
    function b:SetTextLeft(x)
        self.textLeft = x
        self:SetLevel(self.level, true)
    end
    function b:SetSelected(on)
        on = on and true or false
        self.isSelected = on
        self.sel:SetShown(on)
        self.selEdge:SetShown(on)
        self.text:SetFontObject(Font(self, on))
    end
    b:SetLevel(1)
    return b
end

---------------------------------------------------------------------------
-- La barre de défilement de la charte : un pouce doré sur fond noir
local function ScrollBar(parent)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(8)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.45)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.85, 0.68, 0.2, 0.9)
    thumb:SetSize(8, 32)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    return bar
end

-- Un contenu libre qui défile (réglages, aide, détail long) : un
-- ScrollFrame et la barre de la charte, à droite (dans les 12 px qui
-- suivent le cadre) ; molette. child, sinon un cadre neuf ; rend le
-- ScrollFrame (scroll.child, scroll.bar, scroll:ToTop()).
function UI.Scroll(parent, child, step)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    child = child or CreateFrame("Frame", nil, scroll)
    if child:GetWidth() == 0 then child:SetSize(10, 10) end
    scroll:SetScrollChild(child)
    scroll.child = child

    local bar = ScrollBar(parent)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    bar:Hide()
    scroll.bar = bar

    local quiet = false
    bar:SetScript("OnValueChanged", function(_, v)
        if quiet then return end
        scroll:SetVerticalScroll(v)
    end)
    local function Sync(self)
        local max = math.max(0, self:GetVerticalScrollRange() or 0)
        quiet = true
        bar:SetMinMaxValues(0, max)
        if self:GetVerticalScroll() > max then self:SetVerticalScroll(max) end
        bar:SetValue(self:GetVerticalScroll())
        quiet = false
        bar:SetShown(max > 0.5)
    end
    scroll:SetScript("OnScrollRangeChanged", Sync)
    scroll:SetScript("OnVerticalScroll", function(_, offset)
        quiet = true
        bar:SetValue(offset)
        quiet = false
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, self:GetVerticalScrollRange() or 0)
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * (step or 40))))
    end)
    function scroll:ToTop()
        self:SetVerticalScroll(0)
        Sync(self)
    end
    return scroll
end

---------------------------------------------------------------------------
-- Cases à cocher et champs de saisie : les modèles du jeu, habillés comme
-- la charte (fond sombre, liseré brun ; la coche dorée du jeu reste).
-- Chaque contrôle n'est habillé qu'une fois. UI.SkinControls(cadre) passe
-- sur tout ce qu'un cadre contient (la fenêtre après sa construction) ; un
-- contrôle créé plus tard s'habille lui-même (UI.Check, UI.Input,
-- UI.SearchBox, ou UI.SkinCheck / UI.SkinInput).
---------------------------------------------------------------------------
function UI.SkinCheck(cb)
    if cb.omgpSkinned then return end
    cb.omgpSkinned = true
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local t = cb[get] and cb[get](cb)
        if t then t:SetAlpha(0) end
    end
    local inset = math.max(3, math.floor((cb:GetWidth() or 24) * 0.17 + 0.5))
    local box = cb:CreateTexture(nil, "BACKGROUND")
    box:SetPoint("TOPLEFT", inset, -inset)
    box:SetPoint("BOTTOMRIGHT", -inset, inset)
    UI.Fill(box, "checkBg", 1)
    UI.Border(cb, "edgeLight", 1, inset, "BORDER")
    local hl = cb:GetHighlightTexture()
    if hl then
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", inset, -inset)
        hl:SetPoint("BOTTOMRIGHT", -inset, inset)
        hl:SetColorTexture(1, 0.82, 0, 0.15)
        hl:SetBlendMode("ADD")
    end
end

-- Une case à cocher habillée, avec son libellé à droite (cb.text), qui se
-- clique aussi
function UI.Check(parent, text, font, size)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(size or 24, size or 24)
    local fs = UI.Text(cb, font or "GameFontHighlight", text)
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.text, cb.label = fs, fs
    cb:SetHitRectInsets(0, -(fs:GetStringWidth() + 8), 0, 0)
    UI.SkinCheck(cb)
    return cb
end

-- Une barre avec un curseur à glisser (aussi à la molette), et sa valeur à
-- droite. onChange(valeur) pendant qu'on glisse, valeur arrondie au pas.
-- format(valeur) -> le texte affiché. s:SetValueQuiet(v) place le curseur
-- sans appeler onChange.
function UI.Slider(parent, width, minValue, maxValue, step, onChange, format)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(width, 20)
    s:SetMinMaxValues(minValue, maxValue)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouse(true)
    s:SetHitRectInsets(0, 0, -4, -4)

    -- (le trait : un liseré, un fond sombre, la partie remplie en doré)
    local edge = s:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetPoint("LEFT", 0, 0)
    edge:SetPoint("RIGHT", 0, 0)
    edge:SetHeight(8)
    UI.Fill(edge, "edgeLight", 0.9)
    local track = s:CreateTexture(nil, "BACKGROUND", nil, 1)
    track:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
    track:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
    UI.Fill(track, "track", 1)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 18)
    thumb:SetColorTexture(1, 0.82, 0, 1)
    s:SetThumbTexture(thumb)
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", track, "TOPLEFT")
    fill:SetPoint("BOTTOM", track, "BOTTOM")
    fill:SetPoint("RIGHT", thumb, "CENTER")
    fill:SetColorTexture(1, 0.78, 0.2, 0.45)

    s.valueText = UI.Text(s, "GameFontHighlight")
    s.valueText:SetPoint("LEFT", s, "RIGHT", 12, 0)

    local function Round(v)
        return minValue + math.floor((v - minValue) / step + 0.5) * step
    end
    local function Show(v)
        s.valueText:SetText(format and format(v) or tostring(v))
    end
    s:SetScript("OnValueChanged", function(self, value)
        value = Round(value)
        Show(value)
        if self.quiet then return end
        if onChange then onChange(value) end
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        local lo, hi = self:GetMinMaxValues()
        self:SetValue(math.max(lo, math.min(hi, Round(self:GetValue()) + delta * step)))
    end)
    function s:SetValueQuiet(v)
        self.quiet = true
        self:SetValue(v)
        self.quiet = false
        Show(Round(v))
    end
    return s
end

---------------------------------------------------------------------------
-- Ce qui se pose sur la carte plein écran (UI/MapChrome.lua, UI/Layers.lua) :
-- les bandes, les boutons-icônes qu'on allume, les pastilles.
---------------------------------------------------------------------------
-- Une bande posée sur la carte (le nom de la zone, les boutons, le rail des
-- calques) : le dégradé de la fenêtre, un liseré brun, un trait noir dedans
-- et une ombre portée. Le contenu en est l'enfant. UI.PaintOverlay peint un
-- cadre qui existe déjà (un bouton : « Aller à… ») ; UI.Overlay en crée un.
function UI.PaintOverlay(f)
    local shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    shadow:SetPoint("TOPLEFT", -2, 1)
    shadow:SetPoint("BOTTOMRIGHT", 3, -4)
    shadow:SetColorTexture(0, 0, 0, 0.45)
    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    f.bg:SetAllPoints()
    UI.Fade(f.bg, "VERTICAL", "windowBottom", 0.96, "windowTop", 0.96)
    UI.Border(f, "windowEdge", 1)
    UI.Border(f, 0, 0, 0, 0.6, 1)
    return f
end

function UI.Overlay(parent)
    return UI.PaintOverlay(CreateFrame("Frame", nil, parent))
end

-- Une icône dans un bouton : un atlas du jeu s'il existe, sinon la texture
-- (une icône d'objet, Interface\Icons, rognée de son bord)
function UI.SetIcon(tex, texture, atlas)
    if atlas and HasAtlas(atlas) then
        tex:SetAtlas(atlas)
        tex:SetTexCoord(0, 1, 0, 1)
        return
    end
    tex:SetTexture(texture)
    if type(texture) == "string" and texture:find("^Interface\\Icons\\") then
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    else
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

-- Un bouton carré avec une icône, qu'on allume ou éteint (un calque du rail,
-- Me suivre) : allumé, le dégradé et le liseré dorés et une pastille verte
-- (sans pastille : b.noDot) ; éteint, l'icône à 40 % ; nil, un simple bouton
-- (Me localiser). Survol : un voile doré.
-- b:SetOn(true / false / nil), b:SetIcon(texture, atlas) ; b.icon, b.isOn.
function UI.IconToggle(parent, size, texture, atlas)
    size = size or 44
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    UI.Fade(b.bg, "VERTICAL", "navBottom", 1, "navTop", 1)
    b.lit = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.lit:SetAllPoints()
    UI.Gradient(b.lit, "HORIZONTAL", 1, 0.82, 0, 0.2, 1, 0.82, 0, 0.05)
    b.edge = UI.Border(b, "panelEdge", 1, 0, "BORDER")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(math.floor(size * 0.55 + 0.5), math.floor(size * 0.55 + 0.5))
    b.icon:SetPoint("CENTER")
    local ring = UI.Disc(b, 8, "OVERLAY", 0)
    ring:ClearAllPoints()
    ring:SetPoint("TOPRIGHT", -2, -2)
    ring:SetColorTexture(0, 0, 0, 1)
    local dot = UI.Disc(b, 6, "OVERLAY", 1)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", ring, "CENTER")
    dot:SetColorTexture(UI.RGBA("good"))
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.09)
    function b:SetIcon(tex, at)
        UI.SetIcon(self.icon, tex, at)
    end
    function b:SetOn(on)
        self.isOn = on
        local lit = on == true
        self.lit:SetShown(lit)
        if lit then self.edge:SetColor(1, 0.82, 0, 0.85) else self.edge:SetColor("panelEdge", 1) end
        self.icon:SetAlpha(on == false and 0.4 or 1)
        self.icon:SetDesaturated(on == false)
        ring:SetShown(lit and not self.noDot)
        dot:SetShown(lit and not self.noDot)
    end
    if texture or atlas then b:SetIcon(texture, atlas) end
    b:SetOn(nil)
    return b
end

-- Une pastille de coordonnées : fond noir, liseré brun, un libellé doré puis
-- une valeur blanche. p:Set(libellé, valeur, précision grise) la redimensionne.
function UI.Pill(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetHeight(24)
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    UI.Border(p, "windowInner", 1)
    p.label = UI.Text(p, "GameFontNormalSmall")
    p.label:SetPoint("LEFT", 10, 0)
    p.extra = UI.DimText(p, nil, "GameFontHighlightSmall")
    p.extra:SetPoint("LEFT", p.label, "RIGHT", 8, 0)
    p.value = UI.Text(p, "GameFontHighlightSmall")
    function p:Set(label, value, extra)
        self.label:SetText(label or "")
        self.extra:SetText(extra or "")
        self.value:SetText(value or "")
        self.value:ClearAllPoints()
        local anchor = (extra and extra ~= "") and self.extra or self.label
        self.value:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
        local w = 20 + self.label:GetStringWidth() + 8 + self.value:GetStringWidth()
        if extra and extra ~= "" then w = w + self.extra:GetStringWidth() + 8 end
        self:SetWidth(math.ceil(w))
    end
    return p
end

---------------------------------------------------------------------------
-- Un menu contextuel (Alt+clic sur la carte) : fond `dialog`, une ligne de
-- titre grise, des lignes de 26 px (le libellé doré, le raccourci en gris à
-- droite), un trait doré avant un groupe ; survol en voile doré. Il se ferme
-- au clic ailleurs, ou quand on choisit.
-- items : { { texte, fonction, key = "Maj+clic", sep = true }, ... } ;
-- x, y : en px de l'écran (GetCursorPosition) ; title : la ligne grise.
---------------------------------------------------------------------------
local MENU_W, MENU_ROW = 250, 26
local menu

local function MenuRow(i)
    local row = menu.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, menu)
    row:SetSize(MENU_W - 2, MENU_ROW)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.09)
    row.text = UI.Text(row, "GameFontNormalSmall")
    row.text:SetPoint("LEFT", 12, 0)
    row.key = UI.Text(row, "GameFontDisableSmall")
    row.key:SetPoint("RIGHT", -12, 0)
    row:SetScript("OnClick", function(self)
        menu:Hide()
        if self.func then
            local ok, err = pcall(self.func)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        end
    end)
    menu.rows[i] = row
    return row
end

function UI.ShowMenu(items, x, y, title)
    if not menu then
        menu = CreateFrame("Frame", "MyMapIsRichPlusMenu", UIParent)
        menu:SetWidth(MENU_W)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(8500)
        menu:SetClampedToScreen(true)
        menu:EnableMouse(true)
        UI.DialogBackdrop(menu)
        menu.title = UI.Text(menu, "GameFontDisableSmall")
        menu.title:SetPoint("TOPLEFT", 12, -8)
        menu.title:SetPoint("RIGHT", menu, "RIGHT", -12, 0)
        menu.title:SetJustifyH("LEFT")
        menu.title:SetWordWrap(false)
        menu.rows, menu.rules = {}, {}
        menu:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
        menu:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
        menu:SetScript("OnEvent", function(self) if not self:IsMouseOver() then self:Hide() end end)
        menu:Hide()
        if ns.mod and type(ns.mod.padRoots) == "table" then table.insert(ns.mod.padRoots, menu) end
    end
    menu.title:SetText(title or "")
    local top = title and -24 or -4
    for _, r in ipairs(menu.rows) do r:Hide() end
    for _, r in ipairs(menu.rules) do r:Hide() end
    local nRule = 0
    for i, item in ipairs(items) do
        if item.sep and i > 1 then
            nRule = nRule + 1
            local rule = menu.rules[nRule]
            if not rule then
                rule = UI.Rule(menu)
                menu.rules[nRule] = rule
            end
            rule:ClearAllPoints()
            rule:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, top - 4)
            rule:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -10, top - 4)
            rule:Show()
            top = top - 9
        end
        local row = MenuRow(i)
        row.text:SetText(item[1] or "")
        row.key:SetText(item.key or "")
        row.func = item[2]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, top)
        row:Show()
        top = top - MENU_ROW
    end
    menu:SetHeight(-top + 6)
    local es = UIParent:GetEffectiveScale()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x or 0) / es + 14, (y or 0) / es - 10)
    menu:Show()
    return menu
end

function UI.HideMenu()
    if menu then menu:Hide() end
end

function UI.MenuShown() return menu and menu:IsShown() or false end

---------------------------------------------------------------------------
-- Une fenêtre de l'addon par-dessus la carte (navigateur de lieux, clavier
-- virtuel) : le cadre de la charte, barre de titre, croix rouge ; ni
-- portrait, ni liste d'Échap (voir l'en-tête). Elle est posée au-dessus de
-- la carte du jeu (strate FULLSCREEN_DIALOG) et ajoutée aux cadres que le
-- curseur de la manette d'OpenMap sait survoler et presser (mod.padRoots).
-- Rend f : f.title, f.close, f.content (sous la barre de titre).
---------------------------------------------------------------------------
function UI.MapWindow(name, w, h, title, titleH, level)
    titleH = titleH or 32
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(level or 8000)
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.title, f.close = UI.WindowChrome(f, titleH, title, 14)
    f.close.noGamepad = true   -- (B ferme : la croix rouge n'est pas un élément à choisir)
    local c = CreateFrame("Frame", nil, f)
    c:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -(titleH + 4))
    c:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
    f.content = c
    f:Hide()
    if ns.mod and type(ns.mod.padRoots) == "table" then
        table.insert(ns.mod.padRoots, f)
    end
    return f
end

---------------------------------------------------------------------------
-- Les champs de saisie habillés comme la charte (UI.SkinInput), et tout ce
-- qu'une fenêtre contient d'un coup (UI.SkinControls)
---------------------------------------------------------------------------
function UI.SkinInput(box)
    if box.omgpSkinned then return end
    box.omgpSkinned = true
    local keep = { [box.searchIcon or false] = true }
    local found = false
    for _, key in ipairs({ "Left", "Middle", "Right", "Mid" }) do
        local t = box[key]
        if t and t.Hide then
            t:Hide()
            t:SetAlpha(0)
            found = true
        end
    end
    if not found then
        for _, region in ipairs({ box:GetRegions() }) do
            if region:GetObjectType() == "Texture" and not keep[region] and region:GetDrawLayer() ~= "HIGHLIGHT" then
                region:SetAlpha(0)
            end
        end
    end
    local bg = box:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetPoint("TOPLEFT", -6, 1)
    bg:SetPoint("BOTTOMRIGHT", 0, -1)
    UI.Fill(bg, "inputBg", 1)
    local edge = CreateFrame("Frame", nil, box)
    edge:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)
    edge:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 0, 0)
    edge:EnableMouse(false)
    UI.Border(edge, "dialogEdge", 1)
end

function UI.SkinControls(root)
    if not root then return end
    local function Walk(frame)
        for _, child in ipairs({ frame:GetChildren() }) do
            local kind = child:GetObjectType()
            if kind == "CheckButton" and child.GetNormalTexture and child:GetNormalTexture() then
                UI.SkinCheck(child)
            elseif kind == "EditBox" then
                UI.SkinInput(child)
            end
            Walk(child)
        end
    end
    Walk(root)
end

---------------------------------------------------------------------------
-- Les écrans de la fenêtre de configuration (comme My Gamepad Is Rich) : en
-- haut, une bande à côté du portrait (la phrase d'accueil, les boutons de
-- l'écran à droite) ; dessous, les panneaux, séparés de 6 px.
---------------------------------------------------------------------------
UI.PAGE_BAND = 40      -- (la hauteur de la bande du haut)
UI.PAGE_TOP = -46      -- (le haut des panneaux)
UI.PAGE_INTRO_X = 78   -- (la phrase d'accueil, à droite du portrait)
UI.PAGE_GAP = 6        -- (entre deux panneaux)

-- La phrase d'accueil d'un écran, dans la bande du haut (right : la place
-- laissée à droite pour les boutons)
function UI.PageIntro(page, text, right)
    local fs = UI.DimText(page, text)
    fs:SetPoint("LEFT", page, "TOPLEFT", UI.PAGE_INTRO_X, -UI.PAGE_BAND / 2)
    fs:SetPoint("RIGHT", page, "TOPRIGHT", -(right or 8), -UI.PAGE_BAND / 2)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    if fs.SetMaxLines then fs:SetMaxLines(3) end
    return fs
end

-- Un bouton de la bande du haut, à droite (après prev, sinon au bord)
function UI.PageButton(page, text, width, prev, style)
    local b = UI.Button(page, text, width, 24, style or "grey")
    if prev then
        b:SetPoint("RIGHT", prev, "LEFT", -6, 0)
    else
        b:SetPoint("RIGHT", page, "TOPRIGHT", -4, -UI.PAGE_BAND / 2)
    end
    return b
end
