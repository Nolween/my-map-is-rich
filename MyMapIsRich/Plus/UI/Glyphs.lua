-- Icônes des boutons de la manette (barre d'aide, clavier virtuel) : les
-- atlas Xbox du jeu, ceux qu'utilise Forever (repris de My Gamepad Is Rich),
-- ou les symboles PlayStation ; sinon une pastille de couleur avec une lettre.
local _, root = ...
local ns = root.Plus

ns.UI = ns.UI or {}
local UI = ns.UI

local ATLAS = {
    PAD1 = { "gamepad-xbox1-buttona-normal", "Gamepad_Ltr_A_64" },
    PAD2 = { "gamepad-xbox1-buttonb-normal", "Gamepad_Ltr_B_64" },
    PAD3 = { "gamepad-xbox1-buttonx-normal", "Gamepad_Ltr_X_64" },
    PAD4 = { "gamepad-xbox1-buttony-normal", "Gamepad_Ltr_Y_64" },
    PADLSHOULDER = { "gamepad-xbox1-trigger-lb-normal", "Gamepad_Ltr_LShoulder_64", "Gamepad_Gen_LShoulder_64" },
    PADRSHOULDER = { "gamepad-xbox1-trigger-rb-normal", "Gamepad_Ltr_RShoulder_64", "Gamepad_Gen_RShoulder_64" },
    PADLTRIGGER = { "gamepad-xbox1-trigger-lt-normal", "Gamepad_Ltr_LTrigger_64", "Gamepad_Gen_LTrigger_64" },
    PADRTRIGGER = { "gamepad-xbox1-trigger-rt-normal", "Gamepad_Ltr_RTrigger_64", "Gamepad_Gen_RTrigger_64" },
    PADLSTICK = { "gamepad-xbox1-stick-l3-normal", "Gamepad_Gen_LStickIn_64" },
    PADRSTICK = { "gamepad-xbox1-stick-r3-normal", "Gamepad_Gen_RStickIn_64" },
    PADDUP = { "gamepad-xbox1-dpadup-normal", "Gamepad_Ltr_Up_64", "Gamepad_Gen_Up_64" },
    PADDDOWN = { "gamepad-xbox1-dpaddown-normal", "Gamepad_Ltr_Down_64", "Gamepad_Gen_Down_64" },
    PADDLEFT = { "gamepad-xbox1-dpadleft-normal", "Gamepad_Ltr_Left_64", "Gamepad_Gen_Left_64" },
    PADDRIGHT = { "gamepad-xbox1-dpadright-normal", "Gamepad_Ltr_Right_64", "Gamepad_Gen_Right_64" },
    PADBACK = { "gamepad-xbox1-view-normal", "Gamepad_Ltr_View_64", "Gamepad_Gen_Back_64" },
    PADFORWARD = { "gamepad-xbox1-menu-normal", "Gamepad_Ltr_Menu_64", "Gamepad_Gen_Forward_64" },
    -- (pas des boutons : la croix entière, les sticks)
    DPAD = { "gamepad-xbox1-dpad-normal", "Gamepad_Gen_DPad_64" },
    LSTICK = { "gamepad-xbox1-stick-l-normal", "Gamepad_Gen_LStick_64" },
    RSTICK = { "gamepad-xbox1-stick-r-normal", "Gamepad_Gen_RStick_64" },
}

local PS_ATLAS = {
    PAD1 = { "Gamepad_Shp_Cross_64" },
    PAD2 = { "Gamepad_Shp_Circle_64" },
    PAD3 = { "Gamepad_Shp_Square_64" },
    PAD4 = { "Gamepad_Shp_Triangle_64" },
    PADLSHOULDER = { "Gamepad_Shp_LShoulder_64" },
    PADRSHOULDER = { "Gamepad_Shp_RShoulder_64" },
    PADLTRIGGER = { "Gamepad_Shp_LTrigger_64" },
    PADRTRIGGER = { "Gamepad_Shp_RTrigger_64" },
    PADBACK = { "Gamepad_Shp_Back_64" },
    PADFORWARD = { "Gamepad_Shp_Forward_64" },
}

-- Couleurs des boutons de façade (pastilles de repli)
local COLORS = {
    PAD1 = { 0.3, 0.75, 0.2 }, PAD2 = { 0.85, 0.2, 0.2 },
    PAD3 = { 0.2, 0.45, 0.9 }, PAD4 = { 0.95, 0.75, 0.1 },
}

-- Libellés courts (pastilles, textes)
local XBOX_LABEL = {
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT",
    PADLSTICK = "L3", PADRSTICK = "R3", PADBACK = "View", PADFORWARD = "Menu",
    PADDUP = "^", PADDDOWN = "v", PADDLEFT = "<", PADDRIGHT = ">",
    DPAD = "+", LSTICK = "LS", RSTICK = "RS",
}
local PS_LABEL = {
    PAD1 = "×", PAD2 = "○", PAD3 = "□", PAD4 = "△",
    PADLSHOULDER = "L1", PADRSHOULDER = "R1", PADLTRIGGER = "L2", PADRTRIGGER = "R2",
    PADBACK = "Share", PADFORWARD = "Options",
}

-- Le style des icônes : le réglage de l'addon ; « auto » : celui de My
-- Gamepad Is Rich s'il est là (la manette qu'on y a choisie), sinon Xbox
function UI.GlyphStyle()
    local choice = ns.db and ns.db.options.glyphs or "auto"
    if choice == "xbox" or choice == "ps" then return choice end
    local mgir = _G.MyGamepadIsRich
    if type(mgir) == "table" and type(mgir.UI) == "table" and type(mgir.UI.GlyphStyle) == "function" then
        local ok, style = pcall(mgir.UI.GlyphStyle)
        if ok and style == "ps" then return "ps" end
    end
    return "xbox"
end

function UI.KeyLabel(key)
    if UI.GlyphStyle() == "ps" and PS_LABEL[key] then return PS_LABEL[key] end
    return XBOX_LABEL[key] or key
end

local atlasCache = {}
local function FindAtlas(key)
    local style = UI.GlyphStyle()
    local cacheKey = style .. key
    if atlasCache[cacheKey] ~= nil then return atlasCache[cacheKey] or nil end
    local candidates = {}
    if style == "ps" then
        for _, name in ipairs(PS_ATLAS[key] or {}) do candidates[#candidates + 1] = name end
        for _, name in ipairs(ATLAS[key] or {}) do
            if not (name:find("xbox") or name:find("_Ltr_")) then candidates[#candidates + 1] = name end
        end
    else
        candidates = ATLAS[key] or {}
    end
    local found = false
    for _, name in ipairs(candidates) do
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then
            found = name
            break
        end
    end
    atlasCache[cacheKey] = found
    return found or nil
end

local allGlyphs = setmetatable({}, { __mode = "k" })

function UI.RefreshGlyphs()
    for g in pairs(allGlyphs) do
        if g.key then g:SetKey(g.key) end
    end
end

-- Une icône de bouton : g:SetKey("PAD1")
function UI.CreateGlyph(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.badge = f:CreateTexture(nil, "BACKGROUND")
    f.badge:SetAllPoints()
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("CENTER")

    function f:SetKey(key)
        self.key = key
        local atlas = FindAtlas(key)
        if atlas then
            self.tex:SetAtlas(atlas)
            self.tex:Show()
            self.badge:Hide()
            self.text:SetText("")
            return
        end
        self.tex:Hide()
        self.badge:Show()
        local c = COLORS[key] or { 0.35, 0.3, 0.22 }
        self.badge:SetColorTexture(c[1], c[2], c[3], 0.9)
        self.text:SetWidth(size + 16)
        self.text:SetWordWrap(false)
        self.text:SetText(UI.KeyLabel(key))
    end

    allGlyphs[f] = true
    return f
end

-- (le style change dans les réglages : les icônes sont redessinées)
ns.On("OPTIONS", function()
    wipe(atlasCache)
    UI.RefreshGlyphs()
end)
