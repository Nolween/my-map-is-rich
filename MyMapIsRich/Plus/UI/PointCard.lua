-- La fiche d'un point et l'aperçu d'un itinéraire, sur la carte plein écran
-- (maquettes « La fiche d'un point », « L'aperçu d'un itinéraire » et « Les
-- actions »).
--
-- La fiche : A (ou un clic) sur une icône de la carte ne fait plus son action
-- tout de suite, il ouvre sa fiche, toujours au même endroit, sous le nom de la
-- zone, à droite du rail des calques ; le point est cerclé d'or.
-- Elle dit ce qu'est le point (le titre et les lignes de son info-bulle, sa
-- zone et ses coordonnées), le temps pour y aller depuis toi et par où, et
-- propose : Itinéraire (Y : l'aperçu), Ajouter à la file (X), sur un marqueur
-- de quête Voir la quête (un bouton par quête s'il en porte plusieurs : une
-- quête de ton journal, sa fiche dans le panneau des quêtes, UI/QuestPanel.lua ;
-- celle d'un « ! », la fiche d'une quête à prendre, plus bas), l'action de l'icône (la carte d'un donjon, les trajets d'un maître de vol,
-- la fiche d'une épingle), Poser une épingle ici, Envoyer au groupe ; sur un
-- marqueur de quête, Cacher ce marqueur (Layers/QuestMarks.lua). B la ferme.
-- À la souris, sur une icône : Maj+clic l'itinéraire tout de suite, Ctrl+clic
-- une épingle, Alt+clic le menu des actions.
--
-- L'aperçu : le trajet calculé sans être lancé (Travel/Guide.lua :
-- T.Preview) : le temps, l'heure d'arrivée, une barre par étape, les trois
-- styles de marche avec leur durée (Le plus rapide, Équilibré, Routes ; celui
-- du réglage en tête et choisi ; deux styles qui donnent le même chemin n'en
-- font qu'une ligne), la liste des étapes ; Partir (A), Ajouter à la file
-- (X), Annuler (B : retour à la fiche). Les durées viennent d'abord de
-- l'estimation, puis de la grille de marche quand ses recherches finissent
-- (T.Measure). Un style choisi ici reste celui de l'itinéraire lancé.
-- R3 et Maj+clic, eux, partent tout de suite, au style du réglage.
--
-- La fiche d'une quête à prendre (un « ! ») : ce qu'en sait la base des quêtes
-- (Quests/Db.lua), le jeu ne donnant son texte et ses récompenses qu'une fois
-- la quête prise. Itinéraire (Y), Ajouter à la file (View), Retour (B : la
-- fiche du point).
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
local QUESTS_MAX = 3         -- boutons Voir la quête au plus (un marqueur qui porte plusieurs quêtes)
local CHAIN_AROUND = 3       -- la fiche d'une quête à prendre : les étapes de sa chaîne de chaque côté d'elle
local OFFER_SOON = { 0.78, 0.55, 1 }   -- (le violet des « ! » bientôt prêts : Layers/QuestMarks.lua)

local card, preview, offer, ring
local current                -- { point, pin, pinU, pinV, title, lines, action, isPin, icon }
local plan                   -- le plan de l'aperçu (celui du style choisi)
local plans, chosen          -- les plans de l'aperçu, par style ; le style choisi
local stopMeasure            -- arrête les recherches de l'aperçu (T.Measure)
local measuring = false
local STYLE_ROW_H = 26
local backTo                 -- le panneau d'où vient l'aperçu (Annuler y revient) : la fiche, ou celle d'une quête à prendre
local offerQuest             -- la quête à prendre montrée : { id, title, soon, giver } (Layers/QuestMarks.lua : QM.SeeQuests)
local ShowOffer              -- (plus bas)

local function T() return ns.Travel end
local function Pl() return ns.TravelPlanner end
local function R() return ns.TravelRoute end

local function Duration(secs)
    if ns.RouteHud and ns.RouteHud.Duration then return ns.RouteHud.Duration(secs) end
    return R().Clock(secs)
end

local KINDS = {
    walk = "KIND_WALK", flight = "KIND_FLIGHT", boat = "KIND_BOAT",
    zeppelin = "KIND_ZEPPELIN", portal = "KIND_PORTAL", tram = "KIND_TRAM", teleport = "KIND_TELEPORT",
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
    local data = pin.data
    if type(data) == "table" and data.id and data.map then return "FICHE_PIN_EDIT", true end
    local kind = ns.Map.Pins.Kind(pin)
    if kind == "dungeon" then return "FICHE_DUNGEON_MAP" end
    if kind == "flight" then return "FICHE_FLIGHT" end
    if kind == "action" then return "FICHE_MORE" end
end

---------------------------------------------------------------------------
-- Le cercle doré autour du point choisi
---------------------------------------------------------------------------
local function PlaceRing()
    local chrome = ns.MapChrome and ns.MapChrome.Frame()
    local shown = (card and card:IsShown()) or (preview and preview:IsShown()) or (offer and offer:IsShown())
    if not (ring and chrome and shown and current) then
        if ring then ring:Hide() end
        return
    end
    local sx, sy = ns.Map.View.Offset(current.point.u, current.point.v)
    local w, h = chrome:GetWidth() / 2, chrome:GetHeight() / 2
    if not sx or math.abs(sx) > w or math.abs(sy) > h then
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

-- Le haut d'un panneau : à sa place, sous la zone, à droite du rail (le
-- panneau de trajet n'est jamais sur la carte : UI/RouteHud.lua)
local function Place(f)
    local chrome = ns.MapChrome and ns.MapChrome.Frame()
    f:ClearAllPoints()
    if chrome then f:SetPoint("TOPLEFT", chrome, "TOPLEFT", EDGE, -TOP) end
end

local function Roots(f) ns.Map.Cursor.AddRoot(f) end

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
    card.queue = Button(card, L.ACT_QUEUE, "grey", "PADBACK")
    card.queue:SetScript("OnClick", function() Queue() end)
    -- (un marqueur de quête : une quête du journal, sa fiche dans le panneau des quêtes, la manette avec
    -- elle ; une quête à prendre, sa fiche ici)
    card.quests = {}
    for i = 1, QUESTS_MAX do
        local b = Button(card, L.HINT_QUESTS_OPEN, "grey")
        b:SetScript("OnClick", function(self)
            local q, QP = self.quest, ns.QuestPanel
            if not q then return end
            if not q.log then
                ShowOffer(q)
                return
            end
            if not (QP and QP.OpenID) then return end
            Close()
            QP.OpenID(q.id)
            if ns.PadUI() and QP.Focus then QP.Focus() end
        end)
        card.quests[i] = b
    end
    card.action = Button(card, "", "grey")
    card.action:SetScript("OnClick", function()
        local c = current
        if not c then return end
        -- (les icônes sont réutilisées : la même, toujours à sa place ?)
        if c.pin and c.pin.u == c.pinU and c.pin.v == c.pinV and c.pin:IsShown() then
            Close()
            ns.Map.Pins.Action(c.pin)
        end
    end)
    card.pinHere = Button(card, L.FICHE_PIN_HERE, "grey")
    card.pinHere:SetScript("OnClick", function()
        local point = current and current.point
        if not (point and point.map and ns.Map.MyPins.CanAdd()) then return end
        Close()
        ns.Map.MyPins.Add(point.map, point.mx, point.my)
    end)
    card.share = Button(card, L.ACT_SHARE, "grey")
    card.share:SetScript("OnClick", function()
        if current and ns.TravelShare then ns.TravelShare.Propose(current.point) end
    end)
    -- (un marqueur de quête : ses quêtes cachées de la carte, pour ce personnage)
    card.hide = Button(card, L.QUESTMARK_HIDE, "grey")
    card.hide:SetScript("OnClick", function()
        local c = current
        local QM = ns.Quests and ns.Quests.Marks
        if not (c and c.pin and QM) then return end
        Close()
        QM.Hide(c.pin)
    end)
    card.buttons = { card.route, card.queue }
    for _, b in ipairs(card.quests) do card.buttons[#card.buttons + 1] = b end
    for _, b in ipairs({ card.action, card.pinHere, card.share, card.hide }) do card.buttons[#card.buttons + 1] = b end
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

local measureGen = 0         -- (une série de recherches arrêtée ne reprend pas)
local function StopMeasure()
    measureGen = measureGen + 1
    if stopMeasure then stopMeasure() end
    stopMeasure, measuring = nil, false
end

function PC.Close()
    StopMeasure()
    if card then card:Hide() end
    if preview then preview:Hide() end
    if offer then offer:Hide() end
    if ring then ring:Hide() end
    current, plan, plans, chosen, offerQuest, backTo = nil, nil, nil, nil, nil, nil
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
    if offer then offer:Hide() end
    offerQuest = nil
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
    local QM = ns.Quests and ns.Quests.Marks
    card.hide:SetShown(pin and QM and QM.CanHide(pin) or false)
    -- (ses quêtes : « Voir la quête », ou « Voir : <titre> » pour chacune s'il y en a plusieurs)
    local quests = pin and QM and QM.SeeQuests and QM.SeeQuests(pin, QUESTS_MAX) or {}
    for i, b in ipairs(card.quests) do
        local q = quests[i]
        b.quest = q
        b:SetShown(q ~= nil)
        if q then b:SetText(#quests == 1 and L.HINT_QUESTS_OPEN or L.FICHE_SEE_QUEST:format(q.title or "?")) end
    end
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
    -- (les styles de marche : une ligne par chemin différent, le style choisi en or)
    preview.styleRows = {}
    for i = 1, 3 do
        local b = UI.NavButton(preview, STYLE_ROW_H)
        b.count:SetFontObject("GameFontHighlightSmall")
        b:SetScript("OnClick", function(self) PC.PickStyle(self.group) end)
        preview.styleRows[i] = b
    end
    preview.styleDesc = UI.DimText(preview, nil, "GameFontHighlightSmall")
    preview.styleDesc:SetJustifyH("LEFT")
    preview.styleDesc:SetWordWrap(true)
    preview.go = Button(preview, L.PREVIEW_GO, nil, "PAD1")
    preview.go:SetWidth((PREVIEW_W - 34) / 2)
    preview.go:SetScript("OnClick", function() PC.Go() end)
    preview.queue = Button(preview, L.ACT_QUEUE, "grey", "PADBACK")
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
    -- (l'aperçu fermé, d'où que ce soit : ses recherches s'arrêtent)
    preview:SetScript("OnHide", StopMeasure)
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

-- Les styles de marche, dans l'ordre de l'aperçu : celui du réglage, puis les autres
local STYLE_KEYS = { fastest = "TRAVEL_STYLE_FASTEST", balanced = "TRAVEL_STYLE_BALANCED", roads = "TRAVEL_STYLE_ROADS" }
local function StyleOrder()
    local Nav = ns.TravelNav
    local first = Pl().Style()
    local out = { first }
    for _, s in ipairs(Nav and Nav.STYLE_ORDER or {}) do
        if s ~= first then out[#out + 1] = s end
    end
    return out
end

-- Deux plans qui font le même chemin : les mêmes étapes, à quelques secondes près
local function Same(a, b)
    if not (a and b) or #a.legs ~= #b.legs then return false end
    for i, la in ipairs(a.legs) do
        local lb = b.legs[i]
        if la.kind ~= lb.kind or (la.to and la.to.id) ~= (lb.to and lb.to.id) then return false end
        if math.abs(la.secs - lb.secs) > math.max(5, 0.03 * math.max(la.secs, lb.secs)) then return false end
    end
    return true
end

-- Les lignes des styles : { { style, ... }, ... }, les styles au même chemin ensemble
local function StyleGroups()
    local groups = {}
    for _, s in ipairs(StyleOrder()) do
        local p = plans and plans[s]
        if p then
            local into
            for _, g in ipairs(groups) do
                if Same(plans[g[1]], p) then into = g break end
            end
            if into then into[#into + 1] = s else groups[#groups + 1] = { s } end
        end
    end
    return groups
end

local function GroupHas(g, s)
    for _, x in ipairs(g) do if x == s then return true end end
    return false
end

-- Les lignes des styles et la description du style choisi, à partir de y ; rend le nouveau y
local function FillStyles(y)
    local groups = StyleGroups()
    for i, b in ipairs(preview.styleRows) do
        local g = groups[i]
        b.group = g
        if g then
            local names = {}
            for k, s in ipairs(g) do names[k] = L[STYLE_KEYS[s]] end
            b.text:SetText(table.concat(names, " · "))
            b.count:SetText(Duration(plans[g[1]].secs))
            b:SetSelected(GroupHas(g, chosen))
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", preview, "TOPLEFT", 14, y)
            b:SetPoint("RIGHT", preview, "RIGHT", -14, 0)
            b:Show()
            y = y - STYLE_ROW_H - 4
        else
            b:Hide()
        end
    end
    local desc = L[(STYLE_KEYS[chosen] or "TRAVEL_STYLE_BALANCED") .. "_DESC"]
    if measuring then desc = desc .. "  |cff808080" .. L.TRAVEL_STYLE_COMPUTING .. "|r" end
    -- (« plus rapide si tu avais le vol de… » : Planner.Best, pour le style du réglage)
    local hint = plans and plans[Pl().Style()] and plans[Pl().Style()].hint
    if hint then desc = desc .. "\n|cff808080" .. L.TRAVEL_HINT_FLIGHT:format(Duration(hint.saves), hint.name) .. "|r" end
    preview.styleDesc:SetText(desc)
    preview.styleDesc:ClearAllPoints()
    preview.styleDesc:SetPoint("TOPLEFT", preview, "TOPLEFT", 16, y - 2)
    preview.styleDesc:SetPoint("RIGHT", preview, "RIGHT", -14, 0)
    return y - 2 - preview.styleDesc:GetStringHeight() - 10
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
    -- (les styles de marche, puis les étapes)
    for _, row in ipairs(preview.rows) do row:Hide() end
    local y = FillStyles(-80)
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
    local pad = ns.PadUI()
    preview.note:SetText((pad and L.PREVIEW_STYLE_PAD or L.PREVIEW_STYLE_MOUSE) .. "\n"
        .. (pad and L.PREVIEW_HURRY_PAD or L.PREVIEW_HURRY_MOUSE))
    preview.note:ClearAllPoints()
    preview.note:SetPoint("TOPLEFT", preview, "TOPLEFT", 14, y)
    preview.note:SetPoint("RIGHT", preview, "RIGHT", -14, 0)
    y = y - preview.note:GetStringHeight() - 12
    preview:SetHeight(-y)
end

-- Les marches des plans de l'aperçu précisées par la grille, un style après
-- l'autre (le choisi d'abord) ; l'aperçu refait à chaque marche
local function Measure()
    StopMeasure()
    local order, gen = StyleOrder(), measureGen
    measuring = true
    local function Step(i)
        if gen ~= measureGen then return end
        local s = order[i]
        if not s then
            stopMeasure, measuring = nil, false
            if preview:IsShown() then FillPreview() end
            return
        end
        local p = plans and plans[s]
        if not p then return Step(i + 1) end
        -- (le style suivant à l'image d'après : une fin tout de suite ne double pas la série)
        stopMeasure = T().Measure(p, function()
            if gen == measureGen and preview:IsShown() then FillPreview() end
        end, function()
            C_Timer.After(0, function() Step(i + 1) end)
        end)
    end
    Step(1)
end

-- L'aperçu du trajet jusqu'au point de la fiche : un plan par style de marche
function Route()
    if not current then return end
    StopMeasure()
    local first = Pl().Style()
    local p, why = T().Preview(current.point, first)
    if not p then
        ns.Print(why == "here" and L.TRAVEL_ALREADY or why == "nohere" and L.TRAVEL_NO_HERE or L.TRAVEL_NO_ROUTE)
        return
    end
    plans, chosen = { [first] = p }, first
    for _, s in ipairs(StyleOrder()) do
        if s ~= first then plans[s] = T().Preview(current.point, s, false) end
    end
    plan = p
    backTo = (card:IsShown() and card) or (offer and offer:IsShown() and offer) or nil
    card:Hide()
    if offer then offer:Hide() end
    measuring = true
    FillPreview()
    ShowGlyphs(preview)
    Place(preview)
    preview:Show()
    PlaceRing()
    P.Dirty()
    Measure()
end
PC.Route = Route

-- Une ligne de style pressée : son style choisi ; déjà choisi, on part
function PC.PickStyle(group)
    if not (group and plans and preview and preview:IsShown()) then return end
    if GroupHas(group, chosen) then return PC.Go() end
    chosen = group[1]
    plan = plans[chosen] or plan
    FillPreview()
    P.Dirty()
end

function Queue()
    if not current then return end
    local point = current.point
    PC.Close()
    if T() then T().Enqueue(point) end
end

-- Partir : le trajet est calculé de nouveau, depuis où tu es maintenant, au
-- style choisi dans l'aperçu (gardé par l'itinéraire s'il n'est pas celui du réglage)
function PC.Go()
    if not current then return end
    local point = current.point
    local style = preview and preview:IsShown() and chosen ~= Pl().Style() and chosen or nil
    PC.Close()
    if T() then T().Go(point, nil, style) end
end

-- Annuler : retour à la fiche (celle du point, ou d'une quête à prendre), ou fermé
function PC.Back()
    if not (preview and preview:IsShown()) then
        PC.Close()
        return
    end
    preview:Hide()
    plan, plans, chosen = nil, nil, nil
    if backTo and current then
        Place(backTo)
        backTo:Show()
        PlaceRing()
    else
        PC.Close()
    end
    P.Dirty()
end

---------------------------------------------------------------------------
-- La fiche d'une quête à prendre (un « ! » : Voir la quête dans la fiche du
-- point), à sa place, d'après la base des quêtes
---------------------------------------------------------------------------
local function BuildOffer(chrome)
    offer = UI.Overlay(chrome)
    offer:SetWidth(WIDTH)
    offer:EnableMouse(true)
    offer:SetFrameLevel(chrome:GetFrameLevel() + 20)
    offer.close = UI.CloseButton(offer, 20, function() Close() end)
    offer.close:SetPoint("TOPRIGHT", -8, -8)
    offer.close.noGamepad = true
    offer.title = UI.Text(offer, "GameFontNormalLarge")
    offer.title:SetPoint("TOPLEFT", 14, -12)
    offer.title:SetPoint("RIGHT", offer, "RIGHT", -34, 0)
    offer.title:SetJustifyH("LEFT")
    offer.sub = UI.DimText(offer, nil, "GameFontHighlightSmall")
    offer.why = UI.Text(offer, "GameFontHighlightSmall")
    offer.why:SetTextColor(OFFER_SOON[1], OFFER_SOON[2], OFFER_SOON[3])
    offer.body = UI.Text(offer, "GameFontHighlightSmall")
    for _, fs in ipairs({ offer.sub, offer.why, offer.body }) do
        fs:SetPoint("RIGHT", offer, "RIGHT", -14, 0)
        fs:SetJustifyH("LEFT")
    end
    offer.route = Button(offer, L.FICHE_ROUTE, nil, "PAD4")
    offer.route:SetScript("OnClick", function() Route() end)
    offer.queue = Button(offer, L.ACT_QUEUE, "grey", "PADBACK")
    offer.queue:SetScript("OnClick", function() Queue() end)
    offer.back = Button(offer, L.HINT_BACK, "grey", "PAD2")
    offer.back:SetHeight(26)
    offer.back:SetScript("OnClick", function() PC.OfferBack() end)
    offer.buttons = { offer.route, offer.queue, offer.back }
    -- (le nom d'un objet que le jeu n'avait pas encore : la fiche refaite à son arrivée)
    offer:SetScript("OnEvent", function(self)
        if self:IsShown() and offerQuest then self.Fill() end
    end)
    offer:Hide()
    Roots(offer)
    F.RegisterWindow(offer, { onBack = function() PC.OfferBack() end, first = function() return offer.route end })
end

-- Un PNJ ou un objet de la base : son nom, et la zone de son premier point (« Nom · Zone »)
local function NameAndZone(ref)
    local Db = ns.Quests.Db
    local name = ref and Db.Name(ref)
    if not name then return nil end
    local spot = Db.Places(ref)[1]
    local zone = spot and ns.Map.Coords.ZoneAt(spot[1], spot[2])
    local info = zone and C_Map.GetMapInfo and C_Map.GetMapInfo(zone)
    return info and info.name and (name .. " · " .. info.name) or name
end

-- Le nom d'un objet, si le jeu l'a déjà (sinon demandé : GET_ITEM_INFO_RECEIVED)
local function ItemName(itemID)
    local name = GetItemInfo and GetItemInfo(itemID)
    if not name and C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(itemID) end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
    return name
end

-- Le corps de la fiche : qui la donne et qui la reprend, ses objectifs, sa chaîne, d'où vient tout cela.
-- Et si un nom d'objet manque encore
local function OfferBody(o, q)
    local Db = ns.Quests.Db
    local gold = "|cffffd100"
    local parts, waiting = {}, false
    local who = {}
    local giver = (o.giver and NameAndZone(o.giver)) or (current and current.title)
    if giver then who[#who + 1] = gold .. L.FICHE_GIVER .. "|r " .. giver end
    local ender = q and q.ends[1] and NameAndZone(q.ends[1])
    if ender then who[#who + 1] = gold .. L.FICHE_ENDER .. "|r " .. ender end
    if #who > 0 then parts[#parts + 1] = table.concat(who, "\n") end
    -- (les cibles, les objets à rapporter, les lieux à explorer : leurs noms seulement)
    local goals = {}
    for _, g in ipairs(q and q.goals or {}) do
        local name = Db.Name(type(g) == "table" and g[1] or g)
        if name then goals[#goals + 1] = "• " .. name end
    end
    for _, itemID in ipairs(q and q.items or {}) do
        local name = ItemName(itemID)
        if name then goals[#goals + 1] = "• " .. name else waiting = true end
    end
    if q and q.explore then goals[#goals + 1] = "• " .. L.QUESTMARK_EXPLORE end
    if #goals > 0 then parts[#parts + 1] = gold .. L.QUESTS_OBJECTIVES_HEAD .. "|r\n" .. table.concat(goals, "\n") end
    local QP = ns.QuestPanel
    local chain = QP and QP.ChainText and QP.ChainText(o.id, CHAIN_AROUND)
    if chain then parts[#parts + 1] = gold .. L.QUESTS_CHAIN .. "|r\n" .. chain end
    parts[#parts + 1] = UI.Hex("textDim") .. L.FICHE_OFFER_NOTE .. "|r"
    return table.concat(parts, "\n\n"), waiting
end

local function FillOffer()
    local o = offerQuest
    if not (offer and o) then return end
    local Db, QM = ns.Quests.Db, ns.Quests.Marks
    local q = Db.Quest(o.id)
    offer.title:SetText(Db.Title(o.id))
    if QM and QM.Colour and q and q.level and q.level > 0 then
        offer.title:SetTextColor(QM.Colour(q.level))
    else
        offer.title:SetTextColor(1, 0.82, 0)
    end
    -- (son niveau, celui où elle se prend, ce qu'elle a de particulier : sa classe, un donjon, répétable, sa chaîne)
    local bits = {}
    if q and q.level > 0 then bits[#bits + 1] = L.QUESTS_LEVEL:format(q.level) end
    if q and q.minLevel > 0 and q.minLevel ~= q.level then bits[#bits + 1] = L.FICHE_MIN_LEVEL:format(q.minLevel) end
    local tags = QM and QM.Tags and QM.Tags(o.id)
    if tags then bits[#bits + 1] = tags end
    offer.sub:SetText(table.concat(bits, " · "))
    -- (un « ! » bientôt prêt : ce qui manque encore)
    local Offers = ns.Quests.Offers
    offer.why:SetText(o.soon and Offers and Offers.Why and Offers.Why(o.id) or "")
    local body, waiting = OfferBody(o, q)
    offer.body:SetText(body)
    if waiting then pcall(offer.RegisterEvent, offer, "GET_ITEM_INFO_RECEIVED") else offer:UnregisterAllEvents() end
    local travel = ns.db.options.travel and true or false
    offer.route:SetEnabled(travel)
    offer.queue:SetEnabled(travel)
    -- (la mise en page, de haut en bas)
    local y = -12 - offer.title:GetStringHeight() - 4
    for _, fs in ipairs({ offer.sub, offer.why, offer.body }) do
        local text = fs:GetText()
        fs:SetShown(text ~= nil and text ~= "")
        if fs:IsShown() then
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", offer, "TOPLEFT", 14, y)
            fs:SetPoint("RIGHT", offer, "RIGHT", -14, 0)
            y = y - fs:GetStringHeight() - (fs == offer.body and 12 or 6)
        end
    end
    for _, b in ipairs(offer.buttons) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", offer, "TOPLEFT", 14, y)
        y = y - b:GetHeight() - 6
    end
    offer:SetHeight(-y + 4)
end

-- La fiche d'une quête à prendre, à la place de celle du point
function ShowOffer(o)
    if not (offer and current and o) then return end
    offerQuest = o
    card:Hide()
    if preview then preview:Hide() end
    offer.Fill = FillOffer
    FillOffer()
    ShowGlyphs(offer)
    Place(offer)
    offer:Show()
    PlaceRing()
    P.Dirty()
end

-- Retour : la fiche du point
function PC.OfferBack()
    if offer then
        offer:Hide()
        offer:UnregisterAllEvents()
    end
    offerQuest = nil
    if not current then
        PC.Close()
        return
    end
    Place(card)
    card:Show()
    PlaceRing()
    P.Dirty()
end

---------------------------------------------------------------------------
-- Les actions à la souris : un menu là où l'on a fait Alt+clic
---------------------------------------------------------------------------
function PC.Actions(u, v)
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
            if point.map then ns.Map.MyPins.Add(point.map, point.mx, point.my) end
        end), key = L.MENU_CLICK:format(ctrl) },
        { L.ACT_PINS .. "…", function() ns.Map.MyPins.Toggle(true) end, sep = true },
        { L.ACT_QUILL, function() ns.Map.Sketch.Toggle(true) end },
        { L.MAP_SETTINGS, function() ns.Map.Menu.Open() end },
    }
    UI.ShowMenu(items, x, y, title and L.MENU_HERE:format(title) or nil)
end

---------------------------------------------------------------------------
-- Une icône pressée sur la carte plein écran (Map/PadView.lua : Press)
---------------------------------------------------------------------------
local function OnPinPress(pin)
    if not (card and pin.u and pin.v) then return false end
    -- (à la souris, Maj, Ctrl et Alt comme sur la carte ; à la manette, ils ne
    -- sont pas tenus)
    if IsShiftKeyDown() then
        local title = ReadTooltip(pin)
        local point = PointAt(pin.u, pin.v, title)
        if point and T() then T().Go(point) end
        return true
    elseif IsControlKeyDown() and ns.Map.Settings.Get("ctrlClickPin") ~= false then
        local point = PointAt(pin.u, pin.v)
        if point and point.map then ns.Map.MyPins.Add(point.map, point.mx, point.my) end
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
    BuildOffer(chrome)
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
    local function Follow(_, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.03
        PlaceRing()
    end
    card:SetScript("OnUpdate", Follow)
    preview:SetScript("OnUpdate", Follow)
    offer:SetScript("OnUpdate", Follow)
    ns.Map.View.SetPressHandler(OnPinPress)
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
-- (View : dans la file ; X : la taille de la carte, rien d'autre)
P.SetAction("card", "PADBACK", function() Queue() end, "ACT_QUEUE")
P.SetAction("card", "PAD3", ns.PadMapSize, ns.PadMapSizeHint)
P.SetAction("card", "PAD2", function() PC.Close() end, "HINT_CLOSE_CARD")
F.WINDOW_CONTEXTS.card = true

P.DefineContext("preview", 54, function() return preview and preview:IsShown() and F.Top() == preview end, "window")
P.SetAction("preview", "PAD1", function() PC.Go() end, "PREVIEW_GO")
P.SetAction("preview", "PADBACK", function() Queue() end, "ACT_QUEUE")
P.SetAction("preview", "PAD3", ns.PadMapSize, ns.PadMapSizeHint)
P.SetAction("preview", "PAD2", function() PC.Back() end, "HINT_CANCEL")
P.SetAction("preview", "PAD4", function() end)
F.WINDOW_CONTEXTS.preview = true

-- (la fiche d'une quête à prendre : Y l'itinéraire, View la file, B retour à la fiche du point)
P.DefineContext("offer", 53.5, function() return offer and offer:IsShown() and F.Top() == offer end, "window")
P.SetAction("offer", "PAD4", function() Route() end, "FICHE_ROUTE")
P.SetAction("offer", "PADBACK", function() Queue() end, "ACT_QUEUE")
P.SetAction("offer", "PAD3", ns.PadMapSize, ns.PadMapSizeHint)
P.SetAction("offer", "PAD2", function() PC.OfferBack() end, "HINT_BACK")
F.WINDOW_CONTEXTS.offer = true
