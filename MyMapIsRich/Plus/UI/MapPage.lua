-- L'onglet Carte de la fenêtre /mmir : les réglages de la carte elle-même.
-- Depuis la 0.6.0, ils remplacent le menu et la fenêtre de réglages venus
-- d'OpenMap. Trois panneaux, d'après la charte (CHARTE.md) :
--   L'aspect     : les zones inexplorées, les couleurs, le zoom, les icônes
--   De près      : la minimap du jeu mêlée à la carte, les grottes ; les
--                  autres réglages (les niveaux des zones, la teinte de l'ombre)
--   Épingles et donjons : ce que les autres partagent, les cartes des donjons
-- Ce que la carte montre (les calques) reste sur son rail, à gauche de la
-- carte (UI/Layers.lua). Chaque réglage passe par ns.Map (Map/Api.lua,
-- Map/Settings.lua), et la carte se redessine aussitôt.
-- À la manette : la croix va d'un réglage à l'autre, A coche ou change un
-- choix, gauche / droite font glisser un curseur (Pad/Focus.lua).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local ROW = 30            -- px : une case à cocher
local SLIDER_ROW = 46     -- px : un curseur, son nom au-dessus
local CYCLE_ROW = 52      -- px : un choix (son nom au-dessus, un bouton gris)
local CYCLE_W = 180

---------------------------------------------------------------------------
-- Les réglages
---------------------------------------------------------------------------
local function Get(key) return ns.Map.Settings.Get(key) end

-- (la carte se redessine une fois qu'on a fini de glisser un curseur, pas à
-- chaque cran : c'est tout son dessin qui est repris)
local pending = false
local function RefreshSoon()
    if pending then return end
    pending = true
    C_Timer.After(0.15, function()
        pending = false
        ns.Map.Settings.Refresh()
    end)
end

local function Set(key, value)
    ns.Map.Settings.Set(key, value)
    RefreshSoon()
end

local function Percent(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end
local function Times(v) return ("×%g"):format(v) end
local function TimesOrAuto(v)
    if v == 0 then return L.OPT_AUTO end
    return Times(v)
end

-- La teinte de l'ombre sur la terre inexplorée assombrie (« darkenColor ») :
-- celle du jeu (false), quelques teintes, ou celle que le joueur avait choisie
-- sous OpenMap (gardée tant qu'il ne la change pas). Ce sont des couleurs du
-- dessin de la carte, pas de l'interface : elles ne suivent pas les thèmes.
local TINTS = {
    { "sepia", { 0.22, 0.14, 0.06 } },
    { "night", { 0.03, 0.05, 0.16 } },
    { "grey", { 0.16, 0.16, 0.16 } },
}
local function SameColor(a, b)
    for i = 1, 3 do
        if math.abs((tonumber(a[i]) or -1) - b[i]) > 0.002 then return false end
    end
    return true
end
-- (le nom de la teinte du moment, et la couleur elle-même si elle n'est d'aucune liste)
local function TintNow()
    local c = ns.Map.Settings.Get("darkenColor")
    if type(c) ~= "table" then return "game" end
    for _, t in ipairs(TINTS) do
        if SameColor(c, t[2]) then return t[1] end
    end
    return "own", c
end

-- Les curseurs remis à leur valeur d'origine (le bouton du bas)
local SLIDERS = { "darkening", "colorMatch", "desaturate", "iconScale", "iconsFrom", "minimapMix", "minimapFrom", "minimapDeep" }
local function ResetSliders()
    local Look = ns.Map.Look
    for _, key in ipairs(SLIDERS) do
        local default = Look.Default(key)
        if default ~= nil then ns.Map.Settings.Set(key, default) end
    end
    local zoom = Look.Default("maxZoom")
    if zoom then Look.SetMaxZoom(zoom) end
    ns.Map.Settings.Refresh()
end

---------------------------------------------------------------------------
-- La construction
---------------------------------------------------------------------------
-- page : la page de l'onglet ; width : sa largeur ; onRefresh(fn) : fn est
-- appelée chaque fois que la fenêtre se met à jour (MainFrame.lua)
function UI.BuildMapPage(page, width, onRefresh)
    UI.PageIntro(page, L.MAP_PAGE_DESC)
    local gap = UI.PAGE_GAP
    local colW = math.floor((width - 2 * gap) / 3)
    local refreshers = {}
    local function Refresh()
        for _, fn in ipairs(refreshers) do pcall(fn) end
    end
    onRefresh(Refresh)

    local function Column(i)
        local p = UI.Inset(page)
        p:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * (colW + gap), UI.PAGE_TOP)
        if i < 3 then p:SetWidth(colW) else p:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, UI.PAGE_TOP) end
        p:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
        return { p = p, y = -14 }
    end

    local function Section(c, text)
        if c.y < -14 then c.y = c.y - 10 end
        UI.Section(c.p, text, 14, c.y)
        c.y = c.y - 32
    end

    -- (grisé quand il ne sert à rien : enabled() faux)
    local function Enable(f, on, label)
        if f.SetEnabled then f:SetEnabled(on) elseif on then f:Enable() else f:Disable() end
        f:SetAlpha(on and 1 or 0.45)
        if label then label:SetAlpha(on and 1 or 0.45) end
    end

    -- Une case à cocher ; get / set : ceux du réglage, sinon la clé
    local function Check(c, key, label, tip, opts)
        opts = opts or {}
        local cb = UI.Check(c.p, label)
        cb:SetPoint("TOPLEFT", 14, c.y)
        cb.text:SetWidth(colW - 60)
        cb.text:SetJustifyH("LEFT")
        cb.text:SetWordWrap(false)
        cb:SetScript("OnClick", function(self)
            local on = self:GetChecked() and true or false
            if opts.set then
                opts.set(on)
                ns.Map.Settings.Refresh()
            else
                Set(key, on)
            end
            C_Timer.After(0.2, Refresh)
        end)
        UI.Tip(cb, label, tip)
        refreshers[#refreshers + 1] = function()
            local on
            if opts.get then on = opts.get() else on = Get(key) end
            cb:SetChecked(on and true or false)
            if opts.enabled then Enable(cb, opts.enabled()) end
        end
        c.y = c.y - ROW
        return cb
    end

    -- Un curseur : son nom au-dessus, sa valeur à droite
    local function Slider(c, key, label, tip, lo, hi, step, format, opts)
        opts = opts or {}
        if not (lo and hi and step) then return end
        local fs = UI.Text(c.p, "GameFontNormal", label)
        fs:SetPoint("TOPLEFT", 18, c.y)
        fs:SetWidth(colW - 32)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        local s = UI.Slider(c.p, colW - 100, lo, hi, step, function(v)
            if opts.set then
                opts.set(v)
                RefreshSoon()
            else
                Set(key, v)
            end
        end, format)
        s:SetPoint("TOPLEFT", 18, c.y - 20)
        UI.Tip(s, label, tip)
        refreshers[#refreshers + 1] = function()
            local v = Get(key)
            if type(v) ~= "number" then v = lo end
            s:SetValueQuiet(math.max(lo, math.min(hi, v)))
            if opts.enabled then Enable(s, opts.enabled(), fs) end
        end
        c.y = c.y - SLIDER_ROW
        return s
    end

    -- Un choix parmi plusieurs : son nom au-dessus, puis un bouton gris qui passe au suivant
    -- (opts.enabled : grisé quand il ne sert à rien)
    local function Cycle(c, label, tip, choices, get, set, opts)
        opts = opts or {}
        local fs = UI.Text(c.p, "GameFontNormal", label)
        fs:SetPoint("TOPLEFT", 18, c.y)
        fs:SetWidth(colW - 32)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        local b = UI.Button(c.p, "", CYCLE_W, 24, "grey")
        b:SetPoint("TOPLEFT", 18, c.y - 20)
        local function Show()
            local now = get()
            for _, ch in ipairs(choices) do
                if ch[1] == now then b:SetText(ch[2]) return end
            end
            b:SetText(choices[1][2])
        end
        local function Refresh1()
            Show()
            if opts.enabled then Enable(b, opts.enabled(), fs) end
        end
        b:SetScript("OnClick", function()
            local now, at = get(), 1
            for i, ch in ipairs(choices) do if ch[1] == now then at = i end end
            set(choices[at % #choices + 1][1])
            Show()
            C_Timer.After(0.2, Refresh)
        end)
        UI.Tip(b, label, tip)
        refreshers[#refreshers + 1] = Refresh1
        c.y = c.y - CYCLE_ROW
        return b
    end

    local Look = ns.Map.Look

    -- (1) L'aspect
    local look = Column(1)
    Section(look, L.SET_MAP_LOOK)
    local grade = Look.HasGrade()
    local unexplored = { { "show", L.OPT_MAP_UNEXPLORED_SHOW } }
    if grade then unexplored[#unexplored + 1] = { "dim", L.OPT_MAP_UNEXPLORED_DIM } end
    unexplored[#unexplored + 1] = { "hide", L.OPT_MAP_UNEXPLORED_HIDE }
    Cycle(look, L.OPT_MAP_UNEXPLORED, grade and L.OPT_MAP_UNEXPLORED_TIP or L.OPT_MAP_UNEXPLORED_TIP_NODIM, unexplored,
        Look.Unexplored, Look.SetUnexplored)
    Check(look, nil, L.OPT_MAP_UNEXPLORED_OWN, L.OPT_MAP_UNEXPLORED_OWN_TIP, {
        get = Look.UnexploredOwn, set = Look.SetUnexploredOwn,
    })
    if grade then
        Slider(look, "darkening", L.OPT_MAP_DARKENING, L.OPT_MAP_DARKENING_TIP, 0.2, 1, 0.05, Percent, {
            enabled = function() return Look.Unexplored() == "dim" end,
        })
        Slider(look, "colorMatch", L.OPT_MAP_COLOR_MATCH, L.OPT_MAP_COLOR_MATCH_TIP, 0, 1, 0.05, Percent)
    end
    Slider(look, "desaturate", L.OPT_MAP_DESATURATE, L.OPT_MAP_DESATURATE_TIP, 0, 0.6, 0.05, Percent)
    Section(look, L.SET_MAP_ZOOM)
    local zLo, zHi, zStep = Look.Range("maxZoom")
    Slider(look, "maxZoom", L.OPT_MAP_MAX_ZOOM, L.OPT_MAP_MAX_ZOOM_TIP, zLo, zHi, zStep, Times, {
        set = function(v) Look.SetMaxZoom(v) end,
    })
    local sLo, sHi, sStep = Look.Range("iconScale")
    Slider(look, "iconScale", L.OPT_MAP_ICON_SCALE, L.OPT_MAP_ICON_SCALE_TIP, sLo, sHi, sStep, Percent)
    local fLo, fHi, fStep = Look.Range("iconsFrom")
    Slider(look, "iconsFrom", L.OPT_MAP_ICONS_FROM, L.OPT_MAP_ICONS_FROM_TIP, fLo, fHi, fStep, TimesOrAuto)
    Check(look, "playerArrow", L.OPT_MAP_ARROW, L.OPT_MAP_ARROW_TIP, {
        get = function() return Get("playerArrow") ~= false end,
    })
    local reset = UI.Button(look.p, L.OPT_MAP_RESET, colW - 28, 24, "grey")
    reset:SetPoint("BOTTOMLEFT", 14, 14)
    reset:SetScript("OnClick", function()
        ResetSliders()
        C_Timer.After(0.2, Refresh)
    end)
    UI.Tip(reset, L.OPT_MAP_RESET, L.OPT_MAP_RESET_TIP)

    -- (2) Au plus près
    local close = Column(2)
    Section(close, L.SET_MAP_CLOSE)
    local function MinimapOn() return Get("minimap") ~= false end
    Check(close, "minimap", L.OPT_MAP_MINIMAP, L.OPT_MAP_MINIMAP_TIP, { get = MinimapOn })
    Slider(close, "minimapMix", L.OPT_MAP_MINIMAP_MIX, L.OPT_MAP_MINIMAP_MIX_TIP, 0, 0.8, 0.05, Percent,
        { enabled = MinimapOn })
    local mLo, mHi, mStep = Look.Range("minimapFrom")
    Slider(close, "minimapFrom", L.OPT_MAP_MINIMAP_FROM, L.OPT_MAP_MINIMAP_FROM_TIP, mLo, mHi, mStep, Times,
        { enabled = MinimapOn })
    Slider(close, "minimapDeep", L.OPT_MAP_MINIMAP_DEEP, L.OPT_MAP_MINIMAP_DEEP_TIP, 0, 1, 0.05, Percent,
        { enabled = MinimapOn })
    Check(close, "cityMinimap", L.OPT_MAP_CITY_MINIMAP, L.OPT_MAP_CITY_MINIMAP_TIP, { enabled = MinimapOn })
    Check(close, "gapMinimap", L.OPT_MAP_GAP_MINIMAP, L.OPT_MAP_GAP_MINIMAP_TIP, { enabled = MinimapOn })
    Check(close, "soften", L.OPT_MAP_SOFTEN, L.OPT_MAP_SOFTEN_TIP)
    Check(close, "underground", L.OPT_MAP_UNDERGROUND, L.OPT_MAP_UNDERGROUND_TIP, {
        get = function() return Get("underground") ~= false end,
    })
    Section(close, L.SET_MAP_DETAILS)
    Check(close, "zoneLevels", L.OPT_MAP_ZONE_LEVELS, L.OPT_MAP_ZONE_LEVELS_TIP, {
        get = function() return Get("zoneLevels") ~= false end,
    })
    if grade then
        -- (« Ta couleur » seulement si le joueur en avait une à lui en ouvrant la fenêtre)
        local _, own = TintNow()
        local tints = { { "game", L.OPT_MAP_DARKEN_GAME }, { "sepia", L.OPT_MAP_DARKEN_SEPIA },
            { "night", L.OPT_MAP_DARKEN_NIGHT }, { "grey", L.OPT_MAP_DARKEN_GREY } }
        if own then tints[#tints + 1] = { "own", L.OPT_MAP_DARKEN_OWN } end
        Cycle(close, L.OPT_MAP_DARKEN_COLOR, L.OPT_MAP_DARKEN_COLOR_TIP, tints, function() return (TintNow()) end,
            function(v)
                local color = false
                if v == "own" then color = own end
                for _, t in ipairs(TINTS) do
                    if t[1] == v then color = { t[2][1], t[2][2], t[2][3] } end
                end
                Set("darkenColor", color or false)
            end, { enabled = function() return Look.Unexplored() == "dim" end })
    end

    -- (3) Épingles et donjons
    local more = Column(3)
    Section(more, L.SET_MAP_PINS)
    Check(more, "pinsShared", L.OPT_MAP_PINS_SHARED, L.OPT_MAP_PINS_SHARED_TIP)
    -- (sans les épingles des autres, celles du groupe n'arrivent pas non plus : Layers/MyPins.lua)
    Check(more, "pinsGroupAdd", L.OPT_MAP_PINS_ADD, L.OPT_MAP_PINS_ADD_TIP, {
        enabled = function() return Get("pinsShared") ~= false end,
    })
    Check(more, "pinsShareGroup", L.OPT_MAP_PINS_SEND, L.OPT_MAP_PINS_SEND_TIP)
    Check(more, "pinsFollowNew", L.OPT_MAP_PINS_FOLLOW, L.OPT_MAP_PINS_FOLLOW_TIP)
    Check(more, "ctrlClickPin", L.OPT_MAP_CTRL_PIN, L.OPT_MAP_CTRL_PIN_TIP, {
        get = function() return Get("ctrlClickPin") ~= false end,
    })
    Section(more, L.SET_MAP_DUNGEONS)
    Check(more, "dungeonInside", L.OPT_MAP_DUNGEON_INSIDE, L.OPT_MAP_DUNGEON_INSIDE_TIP, {
        get = function() return Get("dungeonInside") ~= false end,
    })
    Check(more, "dungeonMinimap", L.OPT_MAP_DUNGEON_MINIMAP, L.OPT_MAP_DUNGEON_MINIMAP_TIP)
    -- (Dungeon Journal et NeedRoll : des addons, s'ils sont installés)
    Check(more, nil, L.OPT_MAP_ENTRANCE_JOURNAL, L.OPT_MAP_ENTRANCE_JOURNAL_TIP, {
        get = function() return Get("entranceClick") == "journal" end,
        set = function(on) ns.Map.Settings.Set("entranceClick", on and "journal" or "map") end,
    })
    Cycle(more, L.OPT_MAP_QUEST_SOURCE, L.OPT_MAP_QUEST_SOURCE_TIP, {
        { "auto", L.OPT_MAP_QUEST_SOURCE_AUTO }, { "base", "My Map Is Rich" }, { "questie", "Questie" },
        { "journal", "Dungeon Journal" }, { "needroll", "NeedRoll" },
    }, function() return Get("questSource") or "auto" end, function(v) Set("questSource", v) end)

    -- (les quêtes cachées de la carte par ce personnage : Quests/Offers.lua)
    local Offers = ns.Quests.Offers
    Section(more, L.SET_MAP_QUESTS)
    local unhide = UI.Button(more.p, "", colW - 28, 24, "grey")
    unhide:SetPoint("TOPLEFT", 14, more.y)
    unhide:SetScript("OnClick", function()
        Offers.Unhide()
        ns.Print(L.OPT_MAP_UNHIDE_DONE)
        C_Timer.After(0.2, Refresh)
    end)
    UI.Tip(unhide, L.OPT_MAP_UNHIDE, L.OPT_MAP_UNHIDE_TIP)
    refreshers[#refreshers + 1] = function()
        local n = Offers.NumHidden()
        unhide:SetText(L.OPT_MAP_UNHIDE_N:format(n))
        Enable(unhide, n > 0)
    end
    more.y = more.y - ROW
end
