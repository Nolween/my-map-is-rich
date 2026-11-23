-- Le rail des calques de la carte plein écran (maquettes « L'habillage de la
-- carte » et « Le rail des calques ouvert ») : à gauche, sous la zone, un
-- bouton par calque (donjons, maîtres de vol, bateaux, quêtes, citadins,
-- groupe, épingles, dessins), allumé quand la carte le montre ; un clic
-- l'allume ou l'éteint, un clic droit ouvre ses détails. Sous les calques,
-- deux boutons : les maîtres de vol découverts seulement, et la fenêtre de
-- réglages de la carte. Le même rail en plein écran et sur la carte réduite
-- (trop basse, elle garde les boutons qui tiennent, les réglages toujours).
-- Le clic droit sur un calque, et Y à la manette, ouvrent le panneau des
-- calques : chaque calque avec sa case, ses détails dessous, et « Réglages
-- de la carte… ».
-- Les calques sont les réglages de la carte (ns.Map.Settings, ceux de son menu et de sa
-- fenêtre de réglages) : rien n'est gardé à part, sauf, pour un calque qui en
-- couvre plusieurs (bateaux et zeppelins, citadins, groupe), lesquels étaient
-- allumés quand on l'a éteint (ns.db.options.layerMemory) : rallumé, il les
-- remet.
-- Dans le panneau, à la manette : la croix, A allume ou éteint, X montre les
-- détails, B revient à la carte.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI
local P = ns.Pad
local F = ns.Focus

local LY = {}
ns.Layers = LY

local RAIL_TOP = 66          -- px : sous le nom de la zone
local TOGGLE = 44            -- px : un bouton du rail
local GAP = 6
local PANEL_W = 284
local ROW_H = 32

local function Icon(name) return "Interface\\Icons\\" .. name end

-- Les calques. keys : les réglages qu'il allume ou éteint ensemble ;
-- details : { libellé, clé } ou { libellé, get =, set = } ou { libellé, folk = { types } }
local function Faction()
    local ok, f = pcall(UnitFactionGroup, "player")
    return ok and f or nil
end

local LAYERS = {
    { id = "dungeons", label = "LAYER_DUNGEONS", atlas = "dungeon", texture = Icon("INV_Misc_Key_13"),
        keys = { "icons" },
        details = {
            { "LAYER_D_LEVELS", "dungeonLevels" },
            { "LAYER_D_BOSSES", "dungeonBosses" },
            { "LAYER_D_DQUESTS", "dungeonQuests" },
            { "LAYER_D_DMAPS", get = function() return ns.Map.Dungeons.MapsOn() end,
                set = function(v) ns.Map.Dungeons.SetMaps(v) end },
        } },
    { id = "flights", label = "LAYER_FLIGHTS", texture = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green",
        atlasFn = function() return Faction() == "Horde" and "TaxiNode_Horde" or "TaxiNode_Alliance" end,
        keys = { "flight" },
        details = { { "LAYER_D_FOUND", "foundOnly" } } },
    { id = "boats", label = "LAYER_BOATS", atlas = "Ships_CargoShip-Map", texture = Icon("INV_Misc_Spyglass_02"),
        keys = { "boats", "zeppelins" },
        details = { { "LAYER_D_ROUTES", "routes" } } },
    { id = "quests", label = "LAYER_QUESTS", texture = "Interface\\GossipFrame\\AvailableQuestIcon",
        keys = { "questIcons" },
        details = {
            { "LAYER_D_ALLQUESTS", "allQuests" },
            { "LAYER_D_QUESTIE", questie = true },
        } },
    { id = "townsfolk", label = "LAYER_TOWNSFOLK", texture = Icon("INV_Misc_Bag_10"),
        folk = { "vendor", "repair", "innkeeper", "stable", "banker", "mailbox", "classTrainer", "profTrainer" },
        folkStart = { vendor = true, repair = true, innkeeper = true, banker = true, mailbox = true },
        details = {
            { "LAYER_D_VENDORS", folk = { "vendor", "repair" } },
            { "LAYER_D_INNS", folk = { "innkeeper", "stable" } },
            { "LAYER_D_BANKS", folk = { "banker", "mailbox" } },
            { "LAYER_D_TRAINERS", folk = { "classTrainer", "profTrainer" } },
        } },
    { id = "group", label = "LAYER_GROUP", texture = Icon("Spell_Holy_PrayerOfFortitude"),
        keys = { "group" },
        details = {} },
    { id = "pins", label = "LAYER_PINS", texture = Icon("INV_Misc_Map_01"), pins = true,
        details = { { "LAYER_D_INSTANCE_PINS", "hideWorldPinsInInstances" } } },
    { id = "drawings", label = "LAYER_DRAWINGS", texture = Icon("INV_Feather_04"),
        keys = { "sketchShown" },
        details = {} },
}

---------------------------------------------------------------------------
-- L'état des calques (les réglages de la carte)
---------------------------------------------------------------------------
local function DB() return ns.Map.Settings.Table() end

local function HasFolk() return ns.Map.Townsfolk.Has() end

local function QuestieProfile()
    return _G.Questie and Questie.db and Questie.db.profile or nil
end

-- Le calque est-il disponible (les citadins : Questie) ?
local function Available(layer)
    if layer.folk then return HasFolk() end
    return true
end

local function IsOn(layer)
    local db = DB()
    if not db then return false end
    if layer.pins then return not db.pinsHidden end
    if layer.folk then
        if not Available(layer) then return false end
        local folk = db.townsfolk or {}
        for _, k in ipairs(layer.folk) do
            if folk[k] then return true end
        end
        return false
    end
    for _, k in ipairs(layer.keys) do
        if db[k] ~= false and db[k] ~= nil then return true end
    end
    return false
end

-- Après un changement : la carte (son menu, sa fenêtre de réglages) suit
local function Changed()
    ns.Map.Settings.Refresh()
    LY.Refresh()
end

local function Memory()
    local options = ns.db and ns.db.options
    if not options then return {} end
    options.layerMemory = options.layerMemory or {}
    return options.layerMemory
end

function LY.Set(layer, on)
    local db = DB()
    if not db then return end
    if layer.pins then
        ns.Map.MyPins.SetHidden(not on)
        Changed()
        return
    end
    local memory = Memory()
    if layer.folk then
        if not Available(layer) then return end
        db.townsfolk = db.townsfolk or {}
        if on then
            local kept = memory[layer.id]
            for _, k in ipairs(layer.folk) do
                if kept then db.townsfolk[k] = kept[k] and true or false
                else db.townsfolk[k] = layer.folkStart[k] and true or false end
            end
        else
            local kept = {}
            for _, k in ipairs(layer.folk) do
                if db.townsfolk[k] then kept[k] = true end
                db.townsfolk[k] = false
            end
            memory[layer.id] = kept
        end
        ns.Map.Townsfolk.Refresh()
        Changed()
        return
    end
    -- (un calque d'une seule clé : elle ; de plusieurs : celles qui étaient allumées)
    if #layer.keys == 1 then
        db[layer.keys[1]] = on and true or false
    elseif on then
        local kept = memory[layer.id]
        local any = false
        if kept then
            for _, k in ipairs(layer.keys) do
                if kept[k] then any = true end
            end
        end
        for _, k in ipairs(layer.keys) do db[k] = (not any) or (kept[k] and true or false) end
    else
        local kept = {}
        for _, k in ipairs(layer.keys) do
            if db[k] ~= false and db[k] ~= nil then kept[k] = true end
            db[k] = false
        end
        memory[layer.id] = kept
    end
    Changed()
end

function LY.Toggle(layer)
    LY.Set(layer, not IsOn(layer))
end

-- Un détail : allumé ?
local function DetailOn(d)
    local db = DB()
    if not db then return false end
    if d.questie then
        local p = QuestieProfile()
        return p and p.enableMapIcons and true or false
    end
    if d.get then
        local ok, v = pcall(d.get)
        return ok and v and true or false
    end
    if d.folk then
        local folk = db.townsfolk or {}
        for _, k in ipairs(d.folk) do
            if folk[k] then return true end
        end
        return false
    end
    return db[d[2]] and true or false
end

local function DetailAvailable(layer, d)
    if d.questie then return QuestieProfile() ~= nil end
    return Available(layer)
end

local function SetDetail(d, on)
    local db = DB()
    if not db then return end
    if d.questie then
        local p = QuestieProfile()
        local loader = _G.QuestieLoader
        local ok, quests = pcall(function() return loader and loader.ImportModule and loader:ImportModule("QuestieQuest") end)
        if not (p and ok and quests and quests.ToggleNotes) then return end
        p.enableMapIcons = on
        pcall(quests.ToggleNotes, quests, on)
    elseif d.set then
        pcall(d.set, on)
    elseif d.folk then
        db.townsfolk = db.townsfolk or {}
        for _, k in ipairs(d.folk) do db.townsfolk[k] = on and true or false end
        ns.Map.Townsfolk.Refresh()
    else
        db[d[2]] = on and true or false
    end
    Changed()
end

---------------------------------------------------------------------------
-- Le rail
---------------------------------------------------------------------------
local rail, toggles, found, settings
local FOUND = LAYERS[2].details[1]   -- (les maîtres de vol : seulement les lieux découverts)
local panel, rows, detailBox, detailTitle, detailEmpty, detailChecks, allSettings
local chosen = LAYERS[2]     -- (le calque dont le panneau montre les détails)

local function Roots(f) ns.Map.Cursor.AddRoot(f) end

local function LayerTip(self)
    local layer = self.layer
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L[layer.label], 1, 0.82, 0)
    if not Available(layer) then
        GameTooltip:AddLine(L.LAYERS_NEEDS_QUESTIE, 1, 0.44, 0.38, true)
    else
        GameTooltip:AddLine(IsOn(layer) and L.LAYERS_TIP_ON or L.LAYERS_TIP_OFF, 1, 1, 1, true)
    end
    GameTooltip:AddLine(L.LAYERS_TIP_DETAILS, UI.RGB("textDim"))
    GameTooltip:Show()
end

local function FoundTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.LAYER_D_FOUND, 1, 0.82, 0)
    GameTooltip:AddLine(L.LAYERS_DETAILS:format(L.LAYER_FLIGHTS), UI.RGB("textDim"))
    GameTooltip:AddLine(DetailOn(FOUND) and L.LAYERS_TIP_ON or L.LAYERS_TIP_OFF, 1, 1, 1, true)
    GameTooltip:Show()
end

local Show

local function BuildRail(chrome)
    rail = UI.Overlay(chrome)
    rail:SetWidth(TOGGLE + 12)
    -- (à gauche, sous le nom de la zone : la droite est au panneau des quêtes)
    rail:SetPoint("TOPLEFT", chrome, "TOPLEFT", ns.MapChrome.EDGE, -RAIL_TOP)
    rail:EnableMouse(true)
    local title = UI.Label(rail, L.LAYERS_TITLE)
    title:SetPoint("TOP", rail, "TOP", -6, -8)
    rail.glyph = UI.CreateGlyph(rail, 18)
    rail.glyph:SetPoint("LEFT", title, "RIGHT", 3, 0)
    rail.glyph:SetKey("PAD4")
    toggles = {}
    local y = -28
    for i, layer in ipairs(LAYERS) do
        local atlas = layer.atlasFn and layer.atlasFn() or layer.atlas
        local b = UI.IconToggle(rail, TOGGLE, layer.texture, atlas)
        b:SetPoint("TOP", rail, "TOP", 0, y)
        b.layer = layer
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                Show(self.layer)
            else
                LY.Toggle(self.layer)
                if GameTooltip:GetOwner() == self then LayerTip(self) end
            end
        end)
        b:SetScript("OnEnter", LayerTip)
        b:SetScript("OnLeave", GameTooltip_Hide)
        toggles[i] = b
        y = y - TOGGLE - GAP
    end
    -- (sous les calques : les maîtres de vol découverts seulement…)
    found = UI.IconToggle(rail, TOGGLE,
        Faction() == "Horde" and Icon("Ability_Mount_Wyvern_01") or Icon("Ability_Mount_Gryphon_01"))
    found:SetScript("OnClick", function(self)
        SetDetail(FOUND, not DetailOn(FOUND))
        if GameTooltip:GetOwner() == self then FoundTip(self) end
    end)
    found:SetScript("OnEnter", FoundTip)
    found:SetScript("OnLeave", GameTooltip_Hide)
    -- (… et la fenêtre de réglages de la carte)
    settings = UI.IconToggle(rail, TOGGLE, Icon("Trade_Engineering"))
    settings:SetScript("OnClick", function()
        ns.Map.Settings.OpenPage()
    end)
    UI.Tip(settings, L.MAP_SETTINGS, L.MAP_SETTINGS_TIP)
    Roots(rail)
end

-- Le rail selon la hauteur de la carte (plein écran ou réduite) : les
-- boutons des calques puis celui des maîtres de vol découverts, ceux qui
-- tiennent au-dessus des coordonnées, dans l'ordre, puis les réglages,
-- toujours là (le clic droit sur un calque et Y ouvrent le panneau, qui a
-- tous les calques)
local RAIL_BOTTOM = 80       -- px : les coordonnées et la barre d'aide, en bas de la carte
local shownButtons
local function Layout()
    local chrome = rail and rail:GetParent()
    local h = chrome and chrome:GetHeight() or 0
    if h <= 0 then return end
    local buttons = {}
    for i, b in ipairs(toggles) do buttons[i] = b end
    buttons[#buttons + 1] = found
    local room = h - RAIL_TOP - RAIL_BOTTOM - 28 - TOGGLE - 6
    local n = math.max(0, math.min(#buttons, math.floor(room / (TOGGLE + GAP))))
    if n == shownButtons then return end
    shownButtons = n
    local y = -28
    for i, b in ipairs(buttons) do
        b:ClearAllPoints()
        b:SetShown(i <= n)
        if i <= n then
            b:SetPoint("TOP", rail, "TOP", 0, y)
            y = y - TOGGLE - GAP
        end
    end
    settings:ClearAllPoints()
    settings:SetPoint("TOP", rail, "TOP", 0, y)
    rail:SetHeight(-(y - TOGGLE - 6))
end

---------------------------------------------------------------------------
-- Le panneau
---------------------------------------------------------------------------
local function FillDetails()
    if not panel then return end
    local layer = chosen
    detailTitle:SetText(L.LAYERS_DETAILS:format(L[layer.label]))
    for _, cb in ipairs(detailChecks) do cb:Hide() end
    local y = -26
    local n = 0
    for _, d in ipairs(layer.details) do
        if DetailAvailable(layer, d) then
            n = n + 1
            local cb = detailChecks[n]
            if not cb then
                cb = UI.Check(detailBox, "", "GameFontHighlightSmall", 22)
                cb:SetScript("OnClick", function(self) SetDetail(self.detail, self:GetChecked() and true or false) end)
                detailChecks[n] = cb
            end
            cb.detail = d
            cb.text:SetText(L[d[1]])
            cb:SetHitRectInsets(0, -(cb.text:GetStringWidth() + 8), 0, 0)
            cb:SetChecked(DetailOn(d))
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", detailBox, "TOPLEFT", 6, y)
            cb:Show()
            y = y - 24
        end
    end
    local why
    if not Available(layer) then why = L.LAYERS_NEEDS_QUESTIE
    elseif n == 0 then why = L.LAYERS_NO_DETAILS end
    detailEmpty:SetText(why or "")
    detailEmpty:SetShown(why ~= nil)
    if why then y = y - 20 end
    detailBox:SetHeight(-y + 6)
    panel:SetHeight(10 + 26 + #LAYERS * (ROW_H + 3) + 8 + detailBox:GetHeight() + 10 + 24 + 12)
end

local function FillRows()
    if not panel then return end
    for i, row in ipairs(rows) do
        local layer = LAYERS[i]
        local on = IsOn(layer)
        local available = Available(layer)
        row.check:SetShown(on)
        row.box:SetAlpha(available and 1 or 0.4)
        row.selected:SetShown(layer == chosen)
        if layer == chosen then row.text:SetTextColor(1, 1, 1) else row.text:SetTextColor(1, 0.82, 0) end
        row.icon:SetAlpha(available and 1 or 0.4)
        row.note:SetText(layer.folk and "Questie" or "")
    end
    FillDetails()
end

local function BuildPanel(chrome)
    panel = UI.Overlay(chrome)
    panel:SetWidth(PANEL_W)
    panel:SetPoint("TOPLEFT", rail, "TOPRIGHT", GAP, 0)
    panel:EnableMouse(true)
    panel:SetFrameLevel(rail:GetFrameLevel() + 2)
    local title = UI.Text(panel, "GameFontNormalLarge", L.LAYERS_TITLE)
    title:SetPoint("TOPLEFT", 14, -12)
    local sub = UI.DimText(panel, L.LAYERS_SUB)
    sub:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -14, -28)
    rows = {}
    local y = -36
    for i, layer in ipairs(LAYERS) do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(PANEL_W - 20, ROW_H)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        UI.PaintWell(row)
        row.selected = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.selected:SetAllPoints()
        UI.Gradient(row.selected, "HORIZONTAL", 1, 0.82, 0, 0.2, 1, 0.82, 0, 0.05)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.82, 0, 0.07)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 6, 0)
        UI.SetIcon(row.icon, layer.texture, layer.atlasFn and layer.atlasFn() or layer.atlas)
        row.text = UI.Text(row, "GameFontNormalSmall", L[layer.label])
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.note = UI.DimText(row, nil, "GameFontDisableSmall")
        row.note:SetPoint("LEFT", row.text, "RIGHT", 6, 0)
        -- (la case, dessinée : un clic sur la ligne l'allume ou l'éteint)
        row.box = CreateFrame("Frame", nil, row)
        row.box:SetSize(16, 16)
        row.box:SetPoint("RIGHT", -8, 0)
        local boxBg = row.box:CreateTexture(nil, "BACKGROUND")
        boxBg:SetAllPoints()
        UI.Fill(boxBg, "checkBg", 1)
        UI.Border(row.box, "edgeLight", 1)
        row.check = row.box:CreateTexture(nil, "ARTWORK")
        row.check:SetSize(22, 22)
        row.check:SetPoint("CENTER", 1, 1)
        row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        row.layer = layer
        row:SetScript("OnClick", function(self, button)
            chosen = self.layer
            if button ~= "RightButton" then LY.Toggle(self.layer) end
            FillRows()
        end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[self.layer.label], 1, 0.82, 0)
            GameTooltip:AddLine(L.LAYERS_ROW_TIP, 1, 1, 1, true)
            if not Available(self.layer) then GameTooltip:AddLine(L.LAYERS_NEEDS_QUESTIE, 1, 0.44, 0.38, true) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        rows[i] = row
        y = y - ROW_H - 3
    end
    detailBox = UI.Well(panel)
    detailBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y - 5)
    detailBox:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    detailTitle = UI.Label(detailBox, "")
    detailTitle:SetPoint("TOPLEFT", 10, -8)
    detailEmpty = UI.DimText(detailBox, nil, "GameFontHighlightSmall")
    detailEmpty:SetPoint("TOPLEFT", 10, -28)
    detailEmpty:SetPoint("RIGHT", detailBox, "RIGHT", -10, 0)
    detailEmpty:SetJustifyH("LEFT")
    detailChecks = {}
    allSettings = UI.Button(panel, L.MAP_SETTINGS, PANEL_W - 20, 24, "grey")
    allSettings:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 12)
    allSettings:SetScript("OnClick", function()
        ns.Map.Settings.OpenPage()
    end)
    UI.Tip(allSettings, L.MAP_SETTINGS, L.MAP_SETTINGS_TIP)
    panel:Hide()
    Roots(panel)
    F.RegisterWindow(panel, { onBack = function() LY.HidePanel() end, first = function() return rows[1] end })
end

---------------------------------------------------------------------------
function LY.Refresh()
    if toggles then
        Layout()
        for _, b in ipairs(toggles) do
            b:SetOn(Available(b.layer) and IsOn(b.layer) or false)
            b:SetEnabled(Available(b.layer))
        end
        found:SetOn(DetailOn(FOUND))
        rail.glyph:SetShown(ns.PadUI())
    end
    if panel and panel:IsShown() then FillRows() end
end

Show = function(layer)
    if not panel then return end
    if layer then chosen = layer end
    panel:Show()
    FillRows()
    P.Dirty()
end
LY.ShowPanel = Show

function LY.HidePanel()
    if panel then panel:Hide() end
    P.Dirty()
end

function LY.PanelShown() return panel and panel:IsShown() or false end

function LY.TogglePanel()
    if LY.PanelShown() then LY.HidePanel() else Show() end
end

ns.On("MAP_CHROME", function(chrome)
    if rail then return end
    BuildRail(chrome)
    BuildPanel(chrome)
    -- (la carte change de taille : le rail suit)
    chrome:HookScript("OnSizeChanged", function() Layout() end)
    LY.Refresh()
end)
ns.On("MAP_SHOW", function() C_Timer.After(0.05, LY.Refresh) end)
ns.On("MAP_HIDE", function() if panel then LY.HidePanel() end end)
ns.On("MAP_SIZE", LY.Refresh)
ns.On("OPTIONS", LY.Refresh)

-- (un réglage changé ailleurs : le menu de la carte, sa fenêtre de réglages)
ns.On("MAP_REFRESH", function() if rail and rail:IsVisible() then LY.Refresh() end end)

---------------------------------------------------------------------------
-- Le panneau à la manette : la croix, A allume ou éteint, X montre les
-- détails, B revient à la carte (le contexte des fenêtres, d'autres libellés)
---------------------------------------------------------------------------
P.DefineContext("rail", 51, function() return LY.PanelShown() and F.Top() == panel end, "window")
P.SetAction("rail", "PADDRIGHT", function() F.Move(1, 0) end, "HINT_MOVE")
P.SetAction("rail", "PAD1", function() F.Activate("LeftButton") end, "HINT_TOGGLE")
-- (View : les détails d'un calque, son clic droit ; X : la taille de la carte)
P.SetAction("rail", "PADBACK", function() F.Activate("RightButton") end, "HINT_LAYER_DETAILS")
P.SetAction("rail", "PAD3", ns.PadMapSize, ns.PadMapSizeHint)
P.SetAction("rail", "PAD2", F.Back, "HINT_BACK_MAP")
P.SetAction("rail", "PAD4", function() LY.HidePanel() end)
F.WINDOW_CONTEXTS.rail = true
