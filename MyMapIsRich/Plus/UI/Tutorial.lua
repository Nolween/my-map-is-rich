-- Le tutoriel : au premier lancement de l'addon (et une fois pour ceux qui
-- l'avaient déjà, quand il est arrivé), une fenêtre en étapes qui présente
-- la carte d'un seul tenant, la base des quêtes et les itinéraires, fait
-- choisir les premiers réglages (chaque case change le réglage tout de suite)
-- et propose de couper les addons qui font la même chose. Repris du
-- tutoriel de My Gamepad Is Rich (UI/Tutorial.lua là-bas).
--
-- Rouvert par /mmir tuto et le bouton « Revoir le tutoriel » de l'onglet
-- Aide. Il s'ouvre aussi en veille (OpenMap chargé) : c'est lui qui propose
-- de le couper ; il n'accroche rien du jeu.
--
-- La manette : carte fermée, la manette est au jeu (Pad/Bindings.lua ne
-- prend rien) ; la fenêtre la prend elle-même tant qu'elle est ouverte
-- (EnableGamePadButton) : la croix va d'un élément à l'autre (cadre doré),
-- A appuie, B revient d'une étape, LB / RB changent d'étape. Carte ouverte,
-- c'est Pad/Focus.lua qui la mène, comme les autres fenêtres. En combat, la
-- manette est rendue au jeu.
--
-- Textes : L.TUTO_<clé>_TITLE et L.TUTO_<clé>_TEXT ; {mot} y est mis en or
-- (UI.GoldWords, UI/HelpTab.lua).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local T = {}
ns.Tutorial = T

-- (à monter quand le tutoriel change assez pour être remontré à tous)
T.VERSION = 1

local WIDTH, MIN_HEIGHT = 720, 300
local TEXT_W = WIDTH - 56
local ROW = 30

local frame, current, finished, reloading
local Show

local function Opt() return ns.db.options end
local function Mark() if ns.db then ns.db.tutorialSeen = T.VERSION end end
local function Gold(text) return UI.GoldWords and UI.GoldWords(text) or text end

-- Les réglages de la carte (Map/Settings.lua) : la carte suit tout de suite
local function MapOn(key) return ns.Map.Settings.Get(key) ~= false end
local function MapSet(key, on)
    ns.Map.Settings.Set(key, on and true or false)
    ns.Map.Settings.Refresh()
end
local function OptSet(key, value)
    Opt()[key] = value
    ns.Fire("OPTIONS")
end

---------------------------------------------------------------------------
-- Les cases d'une étape : get() dit si elle est cochée, set(coché) change
-- le réglage. Une case « radio » (un choix parmi plusieurs) a set(true)
-- seulement : la relecture décoche les autres.
---------------------------------------------------------------------------
local function Check(c, label, x, y, get, set, tip)
    local cb = UI.Check(c, label)
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        T.Refresh()
    end)
    if tip then UI.Tip(cb, label, tip) end
    cb.get = get
    c.checks[#c.checks + 1] = cb
    c.focus[#c.focus + 1] = cb
    return cb
end

local function Radio(c, label, x, y, get, pick)
    return Check(c, label, x, y, get, function() pick() end)
end

local function Label(c, text, y)
    local fs = UI.Text(c, "GameFontNormal", text)
    fs:SetPoint("TOPLEFT", 4, y)
    return fs
end

-- La carte : plein écran ou réduite à l'ouverture
local function BuildMap(c)
    local function Small(on)
        Opt().mapSmall = on
        -- (la carte ouverte change de taille, sinon à sa prochaine ouverture)
        if not InCombatLockdown() and ns.SetMapSmall then ns.SetMapSmall(on) end
        ns.Fire("OPTIONS")
    end
    Radio(c, L.MAP_SIZE_FULL, 0, 0, function() return not Opt().mapSmall end, function() Small(false) end)
    Radio(c, L.MAP_SIZE_SMALL, 0, -ROW, function() return Opt().mapSmall and true or false end,
        function() Small(true) end)
    local tip = UI.DimText(c, L.MAP_SIZE_TIP)
    tip:SetPoint("TOPLEFT", 30, -ROW * 2 - 2)
    tip:SetWidth(TEXT_W - 30)
    tip:SetJustifyH("LEFT")
    return ROW * 2 + 6 + tip:GetStringHeight()
end

-- Les quêtes : leurs marqueurs, ailleurs que sur la carte, le suivi
local function BuildQuests(c)
    local function Map(key) return function() return MapOn(key) end, function(on) MapSet(key, on) end end
    local y = 0
    Check(c, L.LAYER_QUESTS, 0, y, Map("questIcons"))
    for _, d in ipairs({ { "LAYER_D_MINIMAP", "questMinimap" }, { "LAYER_D_TOOLTIPS", "questTooltips" },
        { "LAYER_D_PLATES", "questPlates" } }) do
        y = y - ROW
        Check(c, L[d[1]], 24, y, Map(d[2]))
    end
    y = y - ROW
    Check(c, L.OPT_TRACKER, 0, y, function() return Opt().tracker ~= false end, function(on)
        OptSet("tracker", on)
        if ns.Tracker and ns.Tracker.Refresh then ns.Tracker.Refresh() end
    end, L.OPT_TRACKER_TIP)
    return -y + ROW
end

-- Les itinéraires : ce qui accompagne un trajet
local function BuildRoutes(c)
    local y = 0
    for i, d in ipairs({ { "travelHud", "OPT_TRAVEL_HUD" }, { "travelArrow", "OPT_TRAVEL_ARROW" },
        { "travelRumble", "OPT_TRAVEL_RUMBLE" }, { "travelSound", "OPT_TRAVEL_SOUND" },
        { "travelHearth", "OPT_TRAVEL_HEARTH" } }) do
        local key = d[1]
        -- (deux colonnes : trois cases à gauche, deux à droite)
        local x = i <= 3 and 0 or math.floor(TEXT_W / 2)
        y = i == 4 and 0 or y
        Check(c, L[d[2]], x, y, function() return Opt()[key] ~= false end, function(on) OptSet(key, on) end,
            L[d[2] .. "_TIP"])
        y = y - ROW
    end
    return ROW * 3
end

-- L'apparence : les couleurs, les icônes des boutons, la barre d'aide
local function BuildLook(c)
    Label(c, L.OPT_THEME, -4)
    local col = math.floor(TEXT_W / 3)
    for i, t in ipairs(UI.THEMES) do
        local x, y = ((i - 1) % 3) * col, -24 - math.floor((i - 1) / 3) * ROW
        Radio(c, L[t.label], x, y, function() return (Opt().theme or "brown") == t.id end,
            function() UI.SetTheme(t.id) end)
    end
    local y = -24 - math.ceil(#UI.THEMES / 3) * ROW - 8
    Label(c, L.OPT_GLYPHS, y - 4)
    y = y - 24
    for i, g in ipairs({ { "auto", L.OPT_AUTO }, { "xbox", "Xbox" }, { "ps", "PlayStation" } }) do
        Radio(c, g[2], (i - 1) * col, y, function() return (Opt().glyphs or "auto") == g[1] end,
            function() OptSet("glyphs", g[1]) end)
    end
    y = y - ROW - 8
    Check(c, L.OPT_HINTS, 0, y, function() return Opt().hints ~= false end, function(on) OptSet("hints", on) end,
        L.OPT_HINTS_TIP)
    return -y + ROW
end

---------------------------------------------------------------------------
-- Les addons qui font la même chose : ceux qui sont chargés, cochés d'avance ;
-- « Désactiver et recharger » les coupe pour ce personnage. why : la raison
-- montrée à côté (TUTO_WHY_<why>)
---------------------------------------------------------------------------
local SIMILAR = {
    { "OpenMap", "DORMANT" }, { "OpenMapOnGamepad", "DORMANT" },
    { "Questie", "QUESTS" }, { "pfQuest", "QUESTS" },
    { "Leatrix_Maps", "MAP" }, { "Mapster", "MAP" }, { "Magnify", "MAP" }, { "BetterMaps", "MAP" },
    { "HighFidelityWorldMap", "MAP" }, { "HiddenMaps", "MAP" },
    { "EllesmereUIQuestTracker", "TRACKER" }, { "TomTom", "ARROW" },
}

local function Loaded(name)
    local fn = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
    if not fn then return false end
    local ok, on = pcall(fn, name)
    return ok and on and true or false
end

-- Le nom d'un addon tel que la liste du jeu le montre, sans ses couleurs
local function Title(name)
    local meta = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata
    local ok, title = pcall(meta, name, "Title")
    title = ok and type(title) == "string" and title or name
    title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return title
end

-- Ceux qui sont là : { { name, why, title } }
function T.Similar()
    local out = {}
    for _, s in ipairs(SIMILAR) do
        if Loaded(s[1]) then out[#out + 1] = { name = s[1], why = s[2], title = Title(s[1]) } end
    end
    return out
end

-- Couper un addon pour ce personnage. (Sans nom de personnage : sur Forever,
-- le jeu range les addons sous le nom complet, « Prénom Nom », que UnitName
-- ne donne pas ; voir aussi TR.UseOurs, UI/Tracker.lua.) Rend vrai si le jeu
-- l'a vraiment coupé.
local function Disable(name)
    local disable = C_AddOns and C_AddOns.DisableAddOn or _G.DisableAddOn
    if not (disable and pcall(disable, name)) then return false end
    local state
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, v = pcall(C_AddOns.GetAddOnEnableState, name)
        if ok and not (issecretvalue and issecretvalue(v)) then state = v end
    end
    return type(state) ~= "number" or state == 0
end

local function BuildAddons(c)
    c.found = T.Similar()
    c.off = {}
    if #c.found == 0 then
        local none = UI.Text(c, "GameFontDisable", L.TUTO_ADDONS_NONE)
        none:SetPoint("TOPLEFT", 4, -4)
        none:SetWidth(TEXT_W - 8)
        none:SetJustifyH("LEFT")
        return 24
    end
    local y = 0
    for _, a in ipairs(c.found) do
        c.off[a.name] = true
        local cb = Check(c, a.title, 0, y, function() return c.off[a.name] end, function(on) c.off[a.name] = on end)
        local why = UI.DimText(c, L["TUTO_WHY_" .. a.why])
        why:SetPoint("LEFT", cb.label, "RIGHT", 10, 0)
        why:SetPoint("RIGHT", c, "RIGHT", 0, 0)
        why:SetJustifyH("LEFT")
        why:SetWordWrap(false)
        y = y - ROW
    end
    local go = UI.Button(c, L.TUTO_ADDONS_DISABLE, 260, 26)
    go:SetPoint("TOPLEFT", 0, y - 8)
    UI.Tip(go, L.TUTO_ADDONS_DISABLE, L.TUTO_ADDONS_DISABLE_TIP)
    go:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local done, failed = 0, {}
        for _, a in ipairs(c.found) do
            if c.off[a.name] then
                if Disable(a.name) then done = done + 1 else failed[#failed + 1] = a.title end
            end
        end
        if #failed > 0 then ns.Print(L.TUTO_ADDONS_FAILED, table.concat(failed, ", ")) end
        if done == 0 then return end
        -- (après le rechargement, le tutoriel reprend à sa dernière étape)
        Mark()
        ns.db.tutorialResume = "DONE"
        reloading = true
        ReloadUI()
    end)
    c.go = go
    c.focus[#c.focus + 1] = go
    return -y + 8 + 26
end

local function RefreshAddons(c)
    if not c.go then return end
    local any = false
    for _, a in ipairs(c.found) do if c.off[a.name] then any = true end end
    c.go:SetEnabled(any)
end

---------------------------------------------------------------------------
-- Les étapes
---------------------------------------------------------------------------
local STEPS = {
    { key = "WELCOME" },
    { key = "MAP", build = BuildMap },
    { key = "QUESTS", build = BuildQuests },
    { key = "ROUTES", build = BuildRoutes },
    { key = "LOOK", build = BuildLook },
    { key = "ADDONS", build = BuildAddons, refresh = RefreshAddons },
    { key = "DONE" },
}

-- Les cases cochées d'après les réglages (un réglage changé ailleurs, une
-- case radio qui décoche les autres)
function T.Refresh()
    if not (frame and current) then return end
    local c = STEPS[current].content
    if not c then return end
    for _, cb in ipairs(c.checks) do cb:SetChecked(cb.get() and true or false) end
    if STEPS[current].refresh then STEPS[current].refresh(c) end
end

---------------------------------------------------------------------------
-- La manette, carte fermée : la croix, le cadre doré
---------------------------------------------------------------------------
local focus, ring

local function Elements()
    local out = {}
    local c = current and STEPS[current].content
    if c and c:IsShown() then
        for _, f in ipairs(c.focus) do
            if f:IsVisible() and f:IsEnabled() then out[#out + 1] = f end
        end
    end
    for _, f in ipairs({ frame.skip, frame.back, frame.next }) do
        if f:IsVisible() and f:IsEnabled() then out[#out + 1] = f end
    end
    return out
end

local function Leave(f)
    if f and f:GetScript("OnLeave") then pcall(f:GetScript("OnLeave"), f) end
end

local function SetFocus(f)
    if focus == f then return end
    Leave(focus)
    focus = f
    if not ring then
        ring = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        if ring.SetBackdrop then
            ring:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
            ring:SetBackdropBorderColor(1, 0.82, 0, 1)
        end
        ring:EnableMouse(false)
    end
    if not f then ring:Hide() return end
    ring:ClearAllPoints()
    ring:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
    -- (une case : le cadre prend aussi son libellé)
    if f.label then
        ring:SetPoint("BOTTOMRIGHT", f.label, "BOTTOMRIGHT", 4, -3)
        ring:SetPoint("BOTTOM", f, "BOTTOM", 0, -3)
    else
        ring:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
    end
    ring:SetFrameLevel(f:GetFrameLevel() + 5)
    ring:Show()
    if f:GetScript("OnEnter") then pcall(f:GetScript("OnEnter"), f) end
end

local function Move(dir)
    local list = Elements()
    if #list == 0 then return end
    local at = 0
    for i, f in ipairs(list) do if f == focus then at = i end end
    if at == 0 then SetFocus(list[1]) return end
    SetFocus(list[(at - 1 + dir) % #list + 1])
end

local function PadEnabled()
    local get = C_CVar and C_CVar.GetCVar or _G.GetCVar
    local ok, v = pcall(get, "GamePadEnable")
    return ok and v == "1"
end

-- La fenêtre prend la manette : ouverte, carte fermée, hors combat
local function OwnPad()
    return frame and frame:IsShown() and PadEnabled() and not InCombatLockdown()
        and not (ns.MapShown and ns.MapShown())
end

local function UpdatePad()
    if not frame then return end
    local on = OwnPad() and true or false
    if frame.EnableGamePadButton then pcall(frame.EnableGamePadButton, frame, on) end
    for _, g in ipairs(frame.glyphs) do g:SetShown(PadEnabled()) end
    if on then
        if not (focus and focus:IsVisible()) then SetFocus(frame.next) end
    else
        SetFocus(nil)
    end
end

---------------------------------------------------------------------------
-- La fenêtre
---------------------------------------------------------------------------
local function Next()
    if current < #STEPS then
        Show(current + 1)
        return
    end
    -- (la dernière étape : la carte ouverte, sauf en veille ou en combat)
    finished = true
    Mark()
    frame:Hide()
    if not ns.Conflict() and not InCombatLockdown() and ToggleWorldMap then pcall(ToggleWorldMap) end
end

local function Back()
    if current > 1 then Show(current - 1) end
end

function Show(i)
    current = math.max(1, math.min(#STEPS, i))
    local step = STEPS[current]
    for _, s in ipairs(STEPS) do
        if s.content then s.content:Hide() end
    end
    frame.stepTitle:SetText(L["TUTO_" .. step.key .. "_TITLE"])
    frame.body:SetText(Gold(L["TUTO_" .. step.key .. "_TEXT"]))

    local contentH = 0
    if step.build then
        if not step.content then
            local c = CreateFrame("Frame", nil, frame)
            c:SetSize(TEXT_W, 10)
            c.checks, c.focus = {}, {}
            step.content = c
            step.height = step.build(c)
        end
        step.content:ClearAllPoints()
        step.content:SetPoint("TOPLEFT", frame.body, "BOTTOMLEFT", 0, -16)
        step.content:SetHeight(step.height)
        step.content:Show()
        contentH = step.height + 16
    end
    T.Refresh()

    frame.progress:SetText(("%d / %d"):format(current, #STEPS))
    frame.back:SetEnabled(current > 1)
    frame.next:SetText(current == #STEPS and L.TUTO_FINISH or L.TUTO_NEXT)
    -- (la hauteur suit le texte, qui change avec la langue)
    local h = 52 + frame.stepTitle:GetStringHeight() + 14 + frame.body:GetStringHeight() + contentH + 74
    frame:SetHeight(math.max(MIN_HEIGHT, h))
    if OwnPad() then SetFocus(frame.next) else SetFocus(nil) end
end

-- La pastille d'un bouton de la manette, à gauche d'un bouton
local function PadGlyph(button, key)
    local g = UI.CreateGlyph(button, 20)
    g:SetPoint("RIGHT", button, "LEFT", -4, 0)
    g:SetKey(key)
    frame.glyphs[#frame.glyphs + 1] = g
end

local function Build()
    local f = CreateFrame("Frame", "MyMapIsRichPlusTutorial", UIParent)
    frame = f
    f.glyphs = {}
    local _, close = UI.WindowChrome(f, 36, L.TITLE .. " - " .. L.TUTO_TITLE)
    close:SetScript("OnClick", function() f:Hide() end)
    f:SetSize(WIDTH, MIN_HEIGHT)
    f:SetPoint("CENTER", 0, 40)
    -- (comme la fenêtre de l'addon : au-dessus de la carte plein écran.
    -- Pas dans UISpecialFrames : l'interface manette de Forever la
    -- parcourt ; la croix et « Passer » la ferment, B à la manette recule)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.stepTitle = UI.Text(f, "GameFontNormalLarge")
    f.stepTitle:SetPoint("TOPLEFT", 28, -52)
    f.stepTitle:SetWidth(TEXT_W)
    f.stepTitle:SetJustifyH("LEFT")

    f.body = UI.Text(f, "GameFontHighlight")
    f.body:SetPoint("TOPLEFT", f.stepTitle, "BOTTOMLEFT", 0, -14)
    f.body:SetWidth(TEXT_W)
    f.body:SetJustifyH("LEFT")
    f.body:SetSpacing(3)

    -- (en bas, sous un trait doré : passer à gauche ; précédent, suivant)
    local rule = UI.Rule(f)
    rule:SetPoint("BOTTOMLEFT", 14, 52)
    rule:SetPoint("BOTTOMRIGHT", -14, 52)
    f.skip = UI.Button(f, L.TUTO_SKIP, 170, 24, "grey")
    f.skip:SetPoint("BOTTOMLEFT", 16, 16)
    f.skip:SetScript("OnClick", function() f:Hide() end)
    f.next = UI.Button(f, L.TUTO_NEXT, 180, 26)
    f.next:SetPoint("BOTTOMRIGHT", -16, 15)
    f.next:SetScript("OnClick", Next)
    f.back = UI.Button(f, L.TUTO_BACK, 120, 24, "grey")
    f.back:SetPoint("RIGHT", f.next, "LEFT", -32, 0)
    f.back:SetScript("OnClick", Back)
    f.progress = UI.Text(f, "GameFontDisable")
    f.progress:SetPoint("RIGHT", f.back, "LEFT", -34, 0)
    PadGlyph(f.next, "PAD1")
    PadGlyph(f.back, "PAD2")

    -- La manette, carte fermée (OwnPad) : rien ne passe au jeu
    f:SetScript("OnGamePadButtonDown", function(self, button)
        if not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, false) end
        if button == "PADDUP" or button == "PADDLEFT" then Move(-1)
        elseif button == "PADDDOWN" or button == "PADDRIGHT" then Move(1)
        elseif button == "PAD1" then
            if focus and focus:IsVisible() and focus:IsEnabled() then focus:Click() else Next() end
        elseif button == "PAD2" or button == "PADLSHOULDER" then Back()
        elseif button == "PADRSHOULDER" then Next()
        end
    end)
    if f.EnableGamePadButton then pcall(f.EnableGamePadButton, f, false) end

    f:SetScript("OnShow", function()
        finished = false
        UpdatePad()
    end)
    f:SetScript("OnHide", function()
        SetFocus(nil)
        if f.EnableGamePadButton then pcall(f.EnableGamePadButton, f, false) end
        if reloading then return end
        if not finished then
            Mark()
            ns.Print(L.TUTO_REOPEN)
        end
        -- (les nouveautés, s'il y en a, attendaient la fin du tutoriel)
        if not ns.Conflict() and ns.WhatsNew then C_Timer.After(1, ns.WhatsNew.MaybeShow) end
    end)

    -- (carte ouverte : la manette mène la fenêtre comme les autres, Pad/Focus.lua)
    if ns.Focus and ns.Focus.RegisterWindow then
        ns.Focus.RegisterWindow(f, { onBack = Back, first = function() return f.next end })
    end
    local events = CreateFrame("Frame", nil, f)
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", UpdatePad)
    ns.On("MAP_SHOW", UpdatePad)
    ns.On("MAP_HIDE", UpdatePad)
    ns.On("OPTIONS", T.Refresh)
    f:Hide()
end

-- Ouvre le tutoriel à une étape (son numéro ou sa clé : "ADDONS"...), sinon
-- à la première
function T.Open(step)
    if not ns.db then return end
    if InCombatLockdown() then
        ns.Print(L.TUTO_COMBAT)
        return
    end
    if not frame then Build() end
    if ns.UI and ns.UI.Hide then ns.UI.Hide() end
    local index = 1
    if type(step) == "number" then
        index = step
    elseif type(step) == "string" then
        for i, s in ipairs(STEPS) do if s.key == step then index = i end end
    end
    reloading = false
    frame:Show()
    Show(index)
    UpdatePad()
end

-- À montrer à la connexion ? (jamais vu, ou une étape à reprendre après le
-- rechargement de « Désactiver et recharger »)
function T.Pending()
    if not ns.db then return false end
    return ns.db.tutorialResume ~= nil or (ns.db.tutorialSeen or 0) < T.VERSION
end

-- À la connexion (Core.lua) : en combat, à la fin du combat
local waiter
function T.MaybeShow()
    if not T.Pending() then return end
    if InCombatLockdown() then
        if not waiter then
            waiter = CreateFrame("Frame")
            waiter:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                T.MaybeShow()
            end)
        end
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local resume = ns.db.tutorialResume
    ns.db.tutorialResume = nil
    T.Open(resume or 1)
end
