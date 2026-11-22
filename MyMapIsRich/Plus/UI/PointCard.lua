-- La fiche d'un point et l'aperçu d'un itinéraire, sur la carte plein écran
-- (maquettes « La fiche d'un point », « L'aperçu d'un itinéraire » et « Les
-- actions »).
--
-- La fiche : A (ou un clic) sur une icône de la carte ne fait plus son action
-- tout de suite, il ouvre sa fiche, toujours au même endroit, sous le nom de la
-- zone (sous le panneau de trajet s'il est là) ; le point est cerclé d'or.
-- Elle dit ce qu'est le point (le titre et les lignes de son info-bulle, sa
-- zone et ses coordonnées), le temps pour y aller depuis toi et par où, et
-- propose : Itinéraire (Y : l'aperçu), Ajouter à la file (X), l'action de
-- l'icône (la carte d'un donjon, les trajets d'un maître de vol, la fiche
-- d'une épingle), Poser une épingle ici, Envoyer au groupe. B la ferme.
-- À la souris, sur une icône : Maj+clic l'itinéraire tout de suite, Ctrl+clic
-- une épingle, Alt+clic le menu des actions.
--
-- L'aperçu : le trajet calculé sans être lancé (Travel/Guide.lua :
-- T.Preview) : le temps, l'heure d'arrivée, une barre par étape, la liste des
-- étapes ; Partir (A), Ajouter à la file (X), Annuler (B : retour à la fiche).
-- R3 et Maj+clic, eux, partent tout de suite.
--
-- Les actions à la souris (Alt+clic sur la carte) : un menu là où l'on a
-- cliqué (UI.ShowMenu), le même contenu que la roue de la manette (View).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI
local P = ns.Pad
local F = ns.Focus

local PC = {}
ns.PointCard = PC

local WIDTH = 330
local PREVIEW_W = 340
local BUTTON_H = 30
local EDGE = 74              -- px : à droite du rail des calques (UI/Layers.lua)
local TOP = 66               -- px : sous le nom de la zone
local RING = 44
local INFO_MAX = 3           -- lignes de l'info-bulle reprises

local card, preview, ring
local current                -- { point, pin, pinU, pinV, title, lines, action, isPin, icon }
local plan                   -- le plan de l'aperçu
local fromCard = false       -- l'aperçu vient de la fiche (Annuler y revient)

local function T() return ns.Travel end
local function Pl() return ns.TravelPlanner end
local function R() return ns.TravelRoute end

local function Duration(secs)
    if ns.RouteHud and ns.RouteHud.Duration then return ns.RouteHud.Duration(secs) end
    return R().Clock(secs)
end

local KINDS = {
    walk = "KIND_WALK", flight = "KIND_FLIGHT", boat = "KIND_BOAT",
    zeppelin = "KIND_ZEPPELIN", portal = "KIND_PORTAL", tram = "KIND_TRAM",
}

local function KindColor(kind)
    local c = R().COLORS[kind] or R().COLORS.walk
    return c[1], c[2], c[3]
end

local function Plain(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    text = strtrim(text)
    return text ~= "" and text or nil
end

-- Le point du monde (yards) d'un point de la carte d'OpenMap, avec son nom
local function PointAt(u, v, name)
    local point = Pl().PointAtUV(u, v)
    if point and name then point.name = name end
    return point
end

local function ZoneAndCoords(point)
    if not point then return nil end
    local zone = Pl().ZoneName(point)
    local _, mx, my = Pl().MapPoint(point)
    if zone and mx then return ("%s · %.1f, %.1f"):format(zone, mx * 100, my * 100) end
    return zone
end

---------------------------------------------------------------------------
-- Ce qu'une icône dit d'elle : son info-bulle (dans la langue du jeu)
---------------------------------------------------------------------------
-- (une ligne grise d'aide, « Clic pour… » : pas reprise)
local function IsHint(r, g, b)
    return r and r < 0.75 and math.abs(r - g) < 0.05 and math.abs(g - b) < 0.05
end

local function ReadTooltip(pin)
    local tip = GameTooltip
    if tip:GetOwner() ~= pin or not tip:IsShown() then
        local enter = pin:GetScript("OnEnter")
        if enter then pcall(enter, pin, false) end
    end
    local title, lines = nil, {}
    if tip:GetOwner() == pin then
        for i = 1, tip:NumLines() do
            local left = _G["GameTooltipTextLeft" .. i]
            local right = _G["GameTooltipTextRight" .. i]
            local text = left and Plain(left:GetText())
            local extra = right and right:IsShown() and Plain(right:GetText())
            if text then
                if not title then
                    title = text
                    if extra then lines[#lines + 1] = extra end
                elseif not IsHint(left:GetTextColor()) and #lines < INFO_MAX then
                    lines[#lines + 1] = extra and (text .. "  " .. extra) or text
                end
            end
        end
        tip:Hide()
    end
    return title, lines
end

-- L'action propre à une icône, et son libellé
local function ActionOf(pin)
    local mod = ns.mod
    local data = pin.data
    if type(data) == "table" and data.id and data.map then return "FICHE_PIN_EDIT", true end
    if pin.instances then return "FICHE_DUNGEON_MAP" end
    if pin.node then return "FICHE_FLIGHT" end
    if pin.OnClick and mod.PinAction then return "FICHE_MORE" end
end

---------------------------------------------------------------------------
-- Le cercle doré autour du point choisi
---------------------------------------------------------------------------
local function PlaceRing()
    local mod = ns.mod
    local chrome = ns.MapChrome and ns.MapChrome.Frame()
    local shown = (card and card:IsShown()) or (preview and preview:IsShown())
    if not (ring and chrome and shown and current and mod.ViewOffset) then
        if ring then ring:Hide() end
        return
    end
    local ok, sx, sy = pcall(mod.ViewOffset, current.point.u, current.point.v)
    local w, h = chrome:GetWidth() / 2, chrome:GetHeight() / 2
    if not (ok and sx) or math.abs(sx) > w or math.abs(sy) > h then
        ring:Hide()
        return
    end
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", chrome, "CENTER", sx, -sy)
    ring:Show()
end

---------------------------------------------------------------------------
-- Les boutons des panneaux (avec la pastille de la manette à gauche)
---------------------------------------------------------------------------
local function Button(parent, text, style, key)
    local b = UI.Button(parent, text, WIDTH - 28, BUTTON_H, style)
    if key then
        b.glyph = UI.CreateGlyph(b, 20)
        b.glyph:SetPoint("LEFT", 6, 0)
        b.glyph:SetKey(key)
    end
    return b
end

local function ShowGlyphs(frame)
    local pad = ns.PadUI()
    for _, b in ipairs(frame.buttons or {}) do
        if b.glyph then b.glyph:SetShown(pad) end
    end
end

-- Le haut d'un panneau : à sa place, sous la zone (et sous le panneau de trajet)
local function Place(f)
    local chrome = ns.MapChrome and ns.MapChrome.Frame()
    f:ClearAllPoints()
    local hud = _G.MyMapIsRichPlusRouteHud
    if hud and hud:IsVisible() then
        f:SetPoint("TOPLEFT", hud, "BOTTOMLEFT", 0, -UI.PAGE_GAP)
    elseif chrome then
        f:SetPoint("TOPLEFT", chrome, "TOPLEFT", EDGE, -TOP)
    end
end

local function Roots(f)
    local roots = ns.mod and ns.mod.padRoots
    if type(roots) == "table" then table.insert(roots, f) end
end

---------------------------------------------------------------------------
-- La fiche
---------------------------------------------------------------------------
local Route, Queue, Close

local function BuildCard(chrome)
    card = UI.Overlay(chrome)
    card:SetWidth(WIDTH)
    card:EnableMouse(true)
    card:SetFrameLevel(chrome:GetFrameLevel() + 20)
    card.close = UI.CloseButton(card, 20, function() Close() end)
    card.close:SetPoint("TOPRIGHT", -8, -8)
    card.close.noGamepad = true
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(40, 40)
    card.icon:SetPoint("TOPLEFT", 14, -12)
    card.title = UI.Text(card, "GameFontNormalLarge")
    card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 12, -2)
    card.title:SetPoint("RIGHT", card, "RIGHT", -34, 0)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)
    card.sub = UI.DimText(card, nil, "GameFontHighlightSmall")
    card.sub:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
    card.sub:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    card.sub:SetJustifyH("LEFT")
    card.sub:SetWordWrap(false)
    card.info = UI.Text(card, "GameFontHighlightSmall")
    card.info:SetPoint("TOPLEFT", card.icon, "BOTTOMLEFT", 0, -8)
    card.info:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    card.info:SetJustifyH("LEFT")
    -- (depuis toi : le temps, la couleur de chaque étape, par où)
    card.well = UI.Well(card)
    card.well:SetHeight(42)
    card.from = UI.Text(card.well, "GameFontNormalSmall", L.FICHE_FROM_YOU)
    card.from:SetPoint("TOPLEFT", 10, -8)
    card.time = UI.Text(card.well, "GameFontHighlightSmall")
    card.time:SetPoint("LEFT", card.from, "RIGHT", 6, 0)
    card.how = UI.DimText(card.well, nil, "GameFontHighlightSmall")
    card.how:SetPoint("TOPLEFT", card.from, "BOTTOMLEFT", 0, -4)
    card.how:SetPoint("RIGHT", card.well, "RIGHT", -10, 0)
    card.how:SetJustifyH("LEFT")
    card.how:SetWordWrap(false)
    card.dots = {}
    -- (les boutons)
    card.route = Button(card, L.FICHE_ROUTE, nil, "PAD4")
    card.route:SetScript("OnClick", function() Route() end)
    card.queue = Button(card, L.ACT_QUEUE, "grey", "PAD3")
    card.queue:SetScript("OnClick", function() Queue() end)
    card.action = Button(card, "", "grey")
    card.action:SetScript("OnClick", function()
        local mod = ns.mod
        local c = current
        if not c then return end
        -- (les icônes sont réutilisées : la même, toujours à sa place ?)
        if c.pin and c.pin.u == c.pinU and c.pin.v == c.pinV and c.pin:IsShown() and mod.PinAction then
            Close()
            mod.PinAction(c.pin)
        end
    end)
    card.pinHere = Button(card, L.FICHE_PIN_HERE, "grey")
    card.pinHere:SetScript("OnClick", function()
        local mod = ns.mod
        local point = current and current.point
        if not (point and point.map and mod.AddPin) then return end
        Close()
        ns.Call(mod.AddPin, point.map, point.mx, point.my)
    end)
    card.share = Button(card, L.ACT_SHARE, "grey")
    card.share:SetScript("OnClick", function()
        if current and ns.TravelShare then ns.TravelShare.Propose(current.point) end
    end)
    card.buttons = { card.route, card.queue, card.action, card.pinHere, card.share }
    card:Hide()
    Roots(card)
    F.RegisterWindow(card, { onBack = function() Close() end, first = function() return card.route end })
end

-- Le temps depuis toi, et par où (le plan calculé, pas lancé)
local function FillFrom()
    local c = current
    for _, d in ipairs(card.dots) do d:Hide() end
    local p, why = T().Preview(c.point)
    if not p then
        card.time:SetText("")
        card.how:SetText(why == "here" and L.TRAVEL_ALREADY or why == "nohere" and L.TRAVEL_NO_HERE or L.TRAVEL_NO_ROUTE)
        return
    end
    card.time:SetText(L.FICHE_ABOUT:format(Duration(p.secs)))
    local kinds, x = {}, -10
    for i = #p.legs, 1, -1 do
        local leg = p.legs[i]
        local d = card.dots[i]
        if not d then
            d = UI.Disc(card.well, 10, "ARTWORK")
            card.dots[i] = d
        end
        d:ClearAllPoints()
        d:SetPoint("RIGHT", card.well, "TOPRIGHT", x, -14)
        d:SetColorTexture(KindColor(leg.kind))
        d:Show()
        x = x - 14
    end
    for i, leg in ipairs(p.legs) do kinds[i] = L[KINDS[leg.kind] or "KIND_WALK"] end
    card.how:SetText(table.concat(kinds, ", "))
end

local function Layout()
    local y = -12 - 40 - 8
    local info = table.concat(current.lines, "\n")
    card.info:SetText(info)
    card.info:SetShown(info ~= "")
    if info ~= "" then y = y - card.info:GetStringHeight() - 8 end
    card.well:ClearAllPoints()
    card.well:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)
    card.well:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    y = y - card.well:GetHeight() - 10
    for _, b in ipairs(card.buttons) do
        if b:IsShown() then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)
            y = y - BUTTON_H - 6
        end
    end
    card:SetHeight(-y + 8)
end

function PC.Close()
    if card then card:Hide() end
    if preview then preview:Hide() end
    if ring then ring:Hide() end
    current, plan = nil, nil
    P.Dirty()
end
Close = PC.Close

-- La fiche d'un point de la carte (u, v), d'après l'icône `pin` s'il y en a une
function PC.Show(u, v, pin)
    local chrome = ns.MapChrome and ns.MapChrome.Frame()
    if not (chrome and card) then return false end
    local title, lines = nil, {}
    if pin then title, lines = ReadTooltip(pin) end
    local point = PointAt(u, v, title)
    if not point then return false end
    point.u, point.v = u, v
    local action, isPin = nil, false
    if pin then action, isPin = ActionOf(pin) end
    current = { point = point, pin = pin, pinU = pin and pin.u, pinV = pin and pin.v, title = title,
        lines = lines, action = action, isPin = isPin }
    if preview then preview:Hide() end
    -- (l'icône de l'icône, sinon l'épingle dorée)
    local icon = pin and pin.Icon
    local atlas = icon and icon.GetAtlas and icon:GetAtlas()
    if atlas then
        card.icon:SetAtlas(atlas)
    elseif icon and icon:GetTexture() then
        card.icon:SetTexture(icon:GetTexture())
        card.icon:SetTexCoord(icon:GetTexCoord())
    else
        UI.SetIcon(card.icon, "Interface\\Minimap\\Ping\\ping5", "Waypoint-MapPin-Untracked")
    end
    if icon then card.icon:SetVertexColor(icon:GetVertexColor()) else card.icon:SetVertexColor(1, 0.85, 0.3) end
    local where = ZoneAndCoords(point)
    card.title:SetText(title or Pl().ZoneName(point) or L.TRAVEL_DEST)
    card.sub:SetText(where or "")
    card.action:SetShown(action ~= nil)
    if action then card.action:SetText(L[action]) end
    card.pinHere:SetShown(not isPin)
    card.route:SetEnabled(ns.db.options.travel and true or false)
    card.queue:SetEnabled(ns.db.options.travel and true or false)
    FillFrom()
    Layout()
    ShowGlyphs(card)
    Place(card)
    card:Show()
    PlaceRing()
    P.Dirty()
    return true
end

function PC.Shown() return card and card:IsShown() or false end

---------------------------------------------------------------------------
-- L'aperçu
---------------------------------------------------------------------------
local function BuildPreview(chrome)
    preview = UI.Overlay(chrome)
    preview:SetWidth(PREVIEW_W)
    preview:EnableMouse(true)
    preview:SetFrameLevel(chrome:GetFrameLevel() + 20)
    preview.title = UI.Text(preview, "GameFontNormalLarge", L.PREVIEW_TITLE)
    preview.title:SetPoint("TOPLEFT", 14, -12)
    preview.to = UI.DimText(preview, nil, "GameFontHighlightSmall")
    preview.to:SetPoint("TOPRIGHT", -14, -16)
    preview.to:SetPoint("LEFT", preview.title, "RIGHT", 8, 0)
    preview.to:SetJustifyH("RIGHT")
    preview.to:SetWordWrap(false)
    preview.total = UI.Text(preview, "GameFontHighlightLarge")
    preview.total:SetPoint("TOPLEFT", preview.title, "BOTTOMLEFT", 0, -10)
    preview.word = UI.DimText(preview, L.PREVIEW_TOTAL)
    preview.word:SetPoint("BOTTOMLEFT", preview.total, "BOTTOMRIGHT", 8, 1)
    preview.arrival = UI.DimText(preview, nil, "GameFontHighlightSmall")
    preview.arrival:SetPoint("BOTTOMRIGHT", preview, "TOPRIGHT", -14, -50)
    preview.bar = CreateFrame("Frame", nil, preview)
    preview.bar:SetHeight(8)
    preview.bar:SetPoint("TOPLEFT", 14, -62)
    preview.bar:SetPoint("RIGHT", preview, "RIGHT", -14, 0)
    preview.segs, preview.rows = {}, {}
    preview.go = Button(preview, L.PREVIEW_GO, nil, "PAD1")
    preview.go:SetWidth((PREVIEW_W - 34) / 2)
    preview.go:SetScript("OnClick", function() PC.Go() end)
    preview.queue = Button(preview, L.ACT_QUEUE, "grey", "PAD3")
    preview.queue:SetWidth((PREVIEW_W - 34) / 2)
    preview.queue:SetScript("OnClick", function() Queue() end)
    preview.cancel = Button(preview, L.HINT_CANCEL, "grey", "PAD2")
    preview.cancel:SetWidth(PREVIEW_W - 28)
    preview.cancel:SetHeight(26)
    preview.cancel:SetScript("OnClick", function() PC.Back() end)
    preview.note = UI.DimText(preview, nil, "GameFontDisableSmall")
    preview.note:SetPoint("RIGHT", preview, "RIGHT", -14, 0)
    preview.note:SetJustifyH("LEFT")
    preview.buttons = { preview.go, preview.queue, preview.cancel }
    preview:Hide()
    Roots(preview)
    F.RegisterWindow(preview, { onBack = function() PC.Back() end, first = function() return preview.go end })
end

local function PreviewRow(i)
    local row = preview.rows[i]
    if row then return row end
    row = UI.Well(preview)
    row:SetHeight(36)
    row.dot = UI.Disc(row, 12, "ARTWORK")
    row.dot:ClearAllPoints()
    row.dot:SetPoint("TOPLEFT", 10, -8)
    row.kind = UI.DimText(row, nil, "GameFontHighlightSmall")
    row.kind:SetPoint("TOPLEFT", 32, -5)
    row.text = UI.Text(row, "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.kind, "BOTTOMLEFT", 0, -2)
    row.text:SetPoint("RIGHT", row, "RIGHT", -64, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.secs = UI.Text(row, "GameFontHighlightSmall")
    row.secs:SetPoint("RIGHT", -10, 0)
    preview.rows[i] = row
    return row
end

local function FillPreview()
    local p = plan
    preview.to:SetText(L.HUD_TO:format(T().GoalName(current.point)))
    preview.total:SetText(Duration(p.secs))
    preview.arrival:SetText((date and time) and L.HUD_ARRIVAL:format(date("%H:%M", time() + math.floor(p.secs))) or "")
    -- (la barre : une part par étape, à la couleur de l'étape)
    for _, s in ipairs(preview.segs) do s:Hide() end
    local width = PREVIEW_W - 28
    local gaps = 3 * (#p.legs - 1)
    local x = 0
    for i, leg in ipairs(p.legs) do
        local s = preview.segs[i]
        if not s then
            s = preview.bar:CreateTexture(nil, "ARTWORK")
            preview.segs[i] = s
        end
        local w = math.max(4, (width - gaps) * (leg.secs / math.max(1, p.secs)))
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", preview.bar, "TOPLEFT", x, 0)
        s:SetSize(w, 8)
        local r, g, b = KindColor(leg.kind)
        s:SetColorTexture(r, g, b, 1)
        s:Show()
        x = x + w + 3
    end
    -- (les étapes)
    for _, row in ipairs(preview.rows) do row:Hide() end
    local y = -80
    for i, leg in ipairs(p.legs) do
        local row = PreviewRow(i)
        row.dot:SetColorTexture(KindColor(leg.kind))
        row.kind:SetText(L.PREVIEW_LEG:format(i, L[KINDS[leg.kind] or "KIND_WALK"]))
        row.text:SetText(T().LegText(leg))
        row.secs:SetText(Duration(leg.secs))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", preview, "TOPLEFT", 14, y)
        row:SetPoint("RIGHT", preview, "RIGHT", -14, 0)
        row:Show()
        y = y - 36 - 4
    end
    y = y - 8
    preview.go:ClearAllPoints()
    preview.go:SetPoint("TOPLEFT", preview, "TOPLEFT", 14, y)
    preview.queue:ClearAllPoints()
    preview.queue:SetPoint("LEFT", preview.go, "RIGHT", 6, 0)
    y = y - BUTTON_H - 6
    preview.cancel:ClearAllPoints()
    preview.cancel:SetPoint("TOPLEFT", preview, "TOPLEFT", 14, y)
    y = y - 26 - 10
    preview.note:SetText(ns.PadUI() and L.PREVIEW_HURRY_PAD or L.PREVIEW_HURRY_MOUSE)
    preview.note:ClearAllPoints()
    preview.note:SetPoint("TOPLEFT", preview, "TOPLEFT", 14, y)
    preview.note:SetPoint("RIGHT", preview, "RIGHT", -14, 0)
    y = y - preview.note:GetStringHeight() - 12
    preview:SetHeight(-y)
end

-- L'aperçu du trajet jusqu'au point de la fiche
function Route()
    if not current then return end
    local p, why = T().Preview(current.point)
    if not p then
        ns.Print(why == "here" and L.TRAVEL_ALREADY or why == "nohere" and L.TRAVEL_NO_HERE or L.TRAVEL_NO_ROUTE)
        return
    end
    plan = p
    fromCard = card:IsShown()
    card:Hide()
    FillPreview()
    ShowGlyphs(preview)
    Place(preview)
    preview:Show()
    PlaceRing()
    P.Dirty()
end
PC.Route = Route

-- L'aperçu du trajet jusqu'à un point donné (une quête du panneau des
-- quêtes : UI/QuestPanel.lua), sans fiche : Annuler le ferme
function PC.PreviewPoint(point)
    if not (point and card) then return end
    if not (point.u and point.v) then point.u, point.v = Pl().UV(point) end
    if not point.u then return end
    current = { point = point, lines = {} }
    card:Hide()
    Route()
end

function Queue()
    if not current then return end
    local point = current.point
    PC.Close()
    if T() then T().Enqueue(point) end
end

-- Partir : le trajet est calculé de nouveau, depuis où tu es maintenant
function PC.Go()
    if not current then return end
    local point = current.point
    PC.Close()
    if T() then T().Go(point) end
end

-- Annuler : retour à la fiche, ou fermé
function PC.Back()
    if not (preview and preview:IsShown()) then
        PC.Close()
        return
    end
    preview:Hide()
    plan = nil
    if fromCard and current then
        Place(card)
        card:Show()
        PlaceRing()
    else
        PC.Close()
    end
    P.Dirty()
end

---------------------------------------------------------------------------
-- Les actions à la souris : un menu là où l'on a fait Alt+clic
---------------------------------------------------------------------------
function PC.Actions(u, v)
    local mod = ns.mod
    local point = u and PointAt(u, v)
    local x, y = GetCursorPosition()
    local title = point and ZoneAndCoords(point)
    local function Need(fn)
        return function()
            if not point then
                ns.Print(L.TRAVEL_NO_THERE)
                return
            end
            fn()
        end
    end
    local shift = ns.MapChrome and ns.MapChrome.KeyName("SHIFT_KEY_TEXT", "Shift") or "Shift"
    local ctrl = ns.MapChrome and ns.MapChrome.KeyName("CTRL_KEY_TEXT", "Ctrl") or "Ctrl"
    local items = {
        { L.HINT_TRAVEL, Need(function() T().Go(point) end), key = L.MENU_CLICK:format(shift) },
        { L.ACT_QUEUE, Need(function() T().Enqueue(point) end) },
        { L.ACT_SHARE, Need(function() if ns.TravelShare then ns.TravelShare.Propose(point) end end) },
        { L.ACT_PIN, Need(function()
            if point.map and mod.AddPin then ns.Call(mod.AddPin, point.map, point.mx, point.my) end
        end), key = L.MENU_CLICK:format(ctrl) },
        { L.ACT_PINS .. "…", function() ns.Call(mod.TogglePins, mod, true) end, sep = true },
        { L.ACT_QUILL, function() if mod.ToggleSketch then ns.Call(mod.ToggleSketch, mod, true) end end },
        { L.MAP_SETTINGS, function() ns.Call(mod.OpenMenu, mod) end },
    }
    UI.ShowMenu(items, x, y, title and L.MENU_HERE:format(title) or nil)
end

---------------------------------------------------------------------------
-- Une icône pressée sur la carte plein écran (Map/PadView.lua : Press)
---------------------------------------------------------------------------
local function OnPinPress(pin)
    local mod = ns.mod
    if not (card and pin.u and pin.v) then return false end
    -- (à la souris, Maj, Ctrl et Alt comme sur la carte ; à la manette, ils ne
    -- sont pas tenus)
    if IsShiftKeyDown() then
        local title = ReadTooltip(pin)
        local point = PointAt(pin.u, pin.v, title)
        if point and T() then T().Go(point) end
        return true
    elseif IsControlKeyDown() then
        local point = PointAt(pin.u, pin.v)
        if point and point.map and mod.AddPin then ns.Call(mod.AddPin, point.map, point.mx, point.my) end
        return true
    elseif IsAltKeyDown() then
        PC.Actions(pin.u, pin.v)
        return true
    end
    return PC.Show(pin.u, pin.v, pin)
end

---------------------------------------------------------------------------
local function Build(chrome)
    if card then return end
    BuildCard(chrome)
    BuildPreview(chrome)
    ring = CreateFrame("Frame", nil, chrome)
    ring:SetSize(RING, RING)
    ring:SetFrameLevel(chrome:GetFrameLevel() + 5)
    ring:EnableMouse(false)
    local shade = ring:CreateTexture(nil, "ARTWORK", nil, 0)
    shade:SetSize(RING + 6, RING + 6)
    shade:SetPoint("CENTER")
    UI.SetIcon(shade, "Interface\\Minimap\\Ping\\ping5", "Waypoint-MapPin-Untracked")
    shade:SetVertexColor(0, 0, 0, 0.6)
    local gold = ring:CreateTexture(nil, "ARTWORK", nil, 1)
    gold:SetAllPoints()
    UI.SetIcon(gold, "Interface\\Minimap\\Ping\\ping5", "Waypoint-MapPin-Untracked")
    gold:SetVertexColor(1, 0.82, 0)
    ring:Hide()
    -- (le cercle suit le point quand la vue bouge)
    local wait = 0
    ring:SetScript("OnUpdate", nil)
    card:SetScript("OnUpdate", function(_, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.03
        PlaceRing()
    end)
    preview:SetScript("OnUpdate", function(_, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.03
        PlaceRing()
    end)
    local mod = ns.mod
    mod.OnPinPress = OnPinPress
end

ns.On("MAP_CHROME", Build)
ns.On("MAP_HIDE", function()
    PC.Close()
    UI.HideMenu()
end)

---------------------------------------------------------------------------
-- La manette : la fiche (Y l'itinéraire, X la file, B la ferme) ; l'aperçu
-- (A partir, X la file, B retour à la fiche). La croix et A, ceux des fenêtres.
---------------------------------------------------------------------------
P.DefineContext("card", 53, function() return PC.Shown() and F.Top() == card end, "window")
P.SetAction("card", "PAD4", function() Route() end, "FICHE_ROUTE")
P.SetAction("card", "PAD3", function() Queue() end, "ACT_QUEUE")
P.SetAction("card", "PAD2", function() PC.Close() end, "HINT_CLOSE_CARD")
F.WINDOW_CONTEXTS.card = true

P.DefineContext("preview", 54, function() return preview and preview:IsShown() and F.Top() == preview end, "window")
P.SetAction("preview", "PAD1", function() PC.Go() end, "PREVIEW_GO")
P.SetAction("preview", "PAD3", function() Queue() end, "ACT_QUEUE")
P.SetAction("preview", "PAD2", function() PC.Back() end, "HINT_CANCEL")
P.SetAction("preview", "PAD4", function() end)
F.WINDOW_CONTEXTS.preview = true
