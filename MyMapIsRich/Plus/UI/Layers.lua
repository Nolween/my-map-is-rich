-- Le rail des calques de la carte plein écran (maquettes « L'habillage de la
-- carte » et « Le rail des calques ouvert ») : à gauche, sous la zone, un
-- bouton par calque (donjons, maîtres de vol, bateaux, quêtes, citadins,
-- groupe, épingles, dessins), allumé quand la carte le montre ; un clic
-- l'allume ou l'éteint, un clic droit ouvre ses détails. Le dernier bouton,
-- et Y à la manette, ouvrent le panneau des calques : chaque calque avec sa
-- case, ses détails dessous, et « Réglages de la carte… » (la fenêtre de
-- réglages de la carte).
-- Les calques sont les réglages de la carte (mod.db, ceux de son menu et de sa
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
            { "LAYER_D_DMAPS", get = function(mod) return mod.DungeonMapsOn and mod.DungeonMapsOn() end,
                set = function(mod, v) if mod.SetDungeonMaps then mod.SetDungeonMaps(v) end end },
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
        keys = { "group", "friends", "guild" },
        details = {
            { "LAYER_D_PARTY", "group" },
            { "LAYER_D_FRIENDS", "friends" },
            { "LAYER_D_GUILD", "guild" },
        } },
    { id = "pins", label = "LAYER_PINS", texture = Icon("INV_Misc_Map_01"), pins = true,
        details = { { "LAYER_D_INSTANCE_PINS", "hideWorldPinsInInstances" } } },
    { id = "drawings", label = "LAYER_DRAWINGS", texture = Icon("INV_Feather_04"),
        keys = { "sketchShown" },
        details = {} },
}

---------------------------------------------------------------------------
-- L'état des calques (les réglages de la carte)
---------------------------------------------------------------------------
local function DB()
    local mod = ns.mod
    return mod and mod.db
end

local function HasFolk()
    local mod = ns.mod
    if not (mod and mod.HasTownsfolk) then return false end
    local ok, has = pcall(mod.HasTownsfolk)
    return ok and has and true or false
end

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
    local mod = ns.mod
    ns.Call(mod.Refresh, mod)
    if ns.OM and ns.OM.NotifyOptions then pcall(ns.OM.NotifyOptions) end
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
    local mod = ns.mod
    if layer.pins then
        ns.Call(mod.SetPinsHidden, not on)
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
        if mod.RefreshTownsfolk then ns.Call(mod.RefreshTownsfolk, mod) end
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
    local mod = ns.mod
    if not db then return false end
    if d.questie then
        local p = QuestieProfile()
        return p and p.enableMapIcons and true or false
    end
    if d.get then
        local ok, v = pcall(d.get, mod)
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
    local mod = ns.mod
    if not db then return end
    if d.questie then
        local p = QuestieProfile()
        local loader = _G.QuestieLoader
        local ok, quests = pcall(function() return loader and loader.ImportModule and loader:ImportModule("QuestieQuest") end)
        if not (p and ok and quests and quests.ToggleNotes) then return end
        p.enableMapIcons = on
        pcall(quests.ToggleNotes, quests, on)
    elseif d.set then
        pcall(d.set, mod, on)
    elseif d.folk then
        db.townsfolk = db.townsfolk or {}
        for _, k in ipairs(d.folk) do db.townsfolk[k] = on and true or false end
        if mod.RefreshTownsfolk then ns.Call(mod.RefreshTownsfolk, mod) end
    else
        db[d[2]] = on and true or false
    end
    Changed()
end

---------------------------------------------------------------------------
-- Le rail
---------------------------------------------------------------------------
local rail, toggles, more
local panel, rows, detailBox, detailTitle, detailEmpty, detailChecks, allSettings
local chosen = LAYERS[2]     -- (le calque dont le panneau montre les détails)

local function Roots(f)
    local roots = ns.mod and ns.mod.padRoots
    if type(roots) == "table" then table.insert(roots, f) end
end

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

local Show

local function BuildRail(chrome)
    rail = UI.Overlay(chrome)
    rail:SetWidth(TOGGLE + 12)
    -- (à gauche, sous le nom de la zone : la droite est au panneau des quêtes)
    rail:SetPoint("TOPLEFT", chrome, "TOPLEFT", ns.MapChrome.EDGE, -RAIL_TOP)
    rail:EnableMouse(true)
    local title = UI.Label(rail, L.LAYERS_TITLE)
    title:SetPoint("TOP", rail, "TOP", -6, -8)
    rail.glyph = UI.CreateGlyph(rail, 14)
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
    more = UI.IconToggle(rail, TOGGLE)
    more:SetPoint("TOP", rail, "TOP", 0, y)
    more.icon:Hide()
    local dots = UI.Text(more, "GameFontNormalLarge", "···")
    dots:SetPoint("CENTER", 0, 2)
    more:SetScript("OnClick", function() LY.TogglePanel() end)
    UI.Tip(more, L.LAYERS_ALL, L.LAYERS_ALL_TIP)
    y = y - TOGGLE - 6
    rail:SetHeight(-y)
    Roots(rail)
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
        if ns.OM and ns.OM.OpenSettingsWindow then ns.OM.OpenSettingsWindow() end
    end)
    UI.Tip(allSettings, L.MAP_SETTINGS, L.MAP_SETTINGS_TIP)
    panel:Hide()
    Roots(panel)
    F.RegisterWindow(panel, { onBack = function() LY.HidePanel() end, first = function() return rows[1] end })
end

---------------------------------------------------------------------------
function LY.Refresh()
    if toggles then
        for _, b in ipairs(toggles) do
            b:SetOn(Available(b.layer) and IsOn(b.layer) or false)
            b:SetEnabled(Available(b.layer))
        end
        rail.glyph:SetShown(ns.PadUI())
    end
    if panel and panel:IsShown() then FillRows() end
end

Show = function(layer)
    if not panel then return end
    if layer then chosen = layer end
    panel:Show()
    FillRows()
    if more then more:SetOn(true) end
    P.Dirty()
end
LY.ShowPanel = Show

function LY.HidePanel()
    if panel then panel:Hide() end
    if more then more:SetOn(nil) end
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
    LY.Refresh()
end)
ns.On("MAP_SHOW", function() C_Timer.After(0.05, LY.Refresh) end)
ns.On("MAP_HIDE", function() if panel then LY.HidePanel() end end)
ns.On("OPTIONS", LY.Refresh)

-- (un réglage changé ailleurs : le menu de la carte, sa fenêtre de réglages)
ns.On("READY", function()
    local mod = ns.mod
    if mod and type(mod.Refresh) == "function" then
        hooksecurefunc(mod, "Refresh", function() if rail and rail:IsVisible() then LY.Refresh() end end)
    end
end)

---------------------------------------------------------------------------
-- Le panneau à la manette : la croix, A allume ou éteint, X montre les
-- détails, B revient à la carte (le contexte des fenêtres, d'autres libellés)
---------------------------------------------------------------------------
P.DefineContext("rail", 51, function() return LY.PanelShown() and F.Top() == panel end, "window")
P.SetAction("rail", "PADDRIGHT", function() F.Move(1, 0) end, "HINT_MOVE")
P.SetAction("rail", "PAD1", function() F.Activate("LeftButton") end, "HINT_TOGGLE")
P.SetAction("rail", "PAD3", function() F.Activate("RightButton") end, "HINT_LAYER_DETAILS")
P.SetAction("rail", "PAD2", F.Back, "HINT_BACK_MAP")
P.SetAction("rail", "PAD4", function() LY.HidePanel() end)
F.WINDOW_CONTEXTS.rail = true
