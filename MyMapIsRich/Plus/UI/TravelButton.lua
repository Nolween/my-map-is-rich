-- Le bouton de voyage (réglage travelButton, onglet Trajets) : pendant un
-- itinéraire, l'étape qui demande d'agir, à portée d'un clic ou d'une touche.
--   - Une téléportation de classe (Travel/Planner.lua) : le bouton lance son
--     sort ; sa recharge s'y voit.
--   - Chez le maître de vol, sa carte ouverte : le bouton prend le vol de
--     l'itinéraire (TakeTaxiNode), tous ses sauts d'un coup.
-- Clic droit : passer cette étape (ns.Travel.SkipLeg : l'itinéraire est refait
-- sans elle).
-- L'aide au maître de vol : sa carte ouverte, un panneau à nous, à côté
-- d'elle, dit la prochaine étape de l'itinéraire et le temps du vol, avec
-- « Prendre ce vol » ; un anneau doré marque sa destination sur la carte (posé
-- sur le bouton de ce maître de vol, rien n'est écrit dans la carte du jeu).
-- C'est un bouton protégé (SecureActionButtonTemplate, comme UI/QuestButtons.lua) :
-- créé, changé, montré ou caché hors combat seulement ; un changement pendant
-- un combat attend PLAYER_REGEN_ENABLED. Maj+glisser le déplace (hors combat).
-- Son raccourci : Raccourcis > My Map Is Rich (Bindings.xml : CLICK), à la
-- manette aussi par la liste des raccourcis du jeu ; le même raccourci prend
-- le vol chez le maître de vol.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local TB = {}
ns.TravelButton = TB

local SIZE = 40
local TAXI_REACH = 90        -- yd : à son maître de vol, l'étape d'un vol est la tienne
local TAXI_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local BINDING = "CLICK MyMapIsRichTravelButton:LeftButton"
local RING_TEXTURE = "Interface\\AddOns\\MyMapIsRich\\Media\\Textures\\GroupRing.tga"   -- (l'anneau du calque Groupe)

local frame, button, help, ring
local pending = false
local taxiOpen = false
local shown                  -- { kind = "teleport" | "taxi", spell, name, slot, secs, leg }

_G["BINDING_NAME_" .. BINDING] = L.BINDING_TRAVEL

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function On()
    return ns.db and ns.db.options.travelButton ~= false and ns.db.options.travel ~= false
        and not (ns.Conflict and ns.Conflict())
end

-- Le texte du raccourci du bouton (« F », « RB »), ou nil
local function KeyText()
    local key = GetBindingKey and GetBindingKey(BINDING)
    if not key then return end
    return GetBindingText and GetBindingText(key, "KEY_") or key
end

---------------------------------------------------------------------------
-- La carte des vols : le bouton d'un maître de vol (son numéro sur cette carte)
---------------------------------------------------------------------------
local function TaxiSlot(node)
    if not (node and node.node) then return end
    -- (C_TaxiMap : chaque maître de vol avec son numéro de jeu)
    local mapID = GetTaxiMapID and Plain(GetTaxiMapID())
    if mapID and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
        local ok, list = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
        if ok and type(list) == "table" then
            for _, info in ipairs(list) do
                if type(info) == "table" and info.nodeID == node.node and info.slotIndex then return info.slotIndex end
            end
        end
    end
    -- (sinon par son nom, celui du jeu dans ta langue)
    local G = ns.TravelGraph
    for i = 1, (NumTaxiNodes and NumTaxiNodes() or 0) do
        local name = TaxiNodeName and Plain(TaxiNodeName(i))
        if name and node.name and G.Short(name) == node.name then return i end
    end
end

local function Reachable(slot)
    if not (slot and TaxiNodeGetType) then return false end
    local ok, kind = pcall(TaxiNodeGetType, slot)
    return ok and Plain(kind) == "REACHABLE"
end

---------------------------------------------------------------------------
-- L'étape qui demande d'agir
---------------------------------------------------------------------------
local function Wanted()
    local T = ns.Travel
    if not (T and T.Live) then return end
    local plan, index = T.Live()
    if not plan then return end
    local leg = plan.legs[index]
    if leg and leg.kind == "teleport" and leg.spell then
        return { kind = "teleport", spell = leg.spell, name = leg.to.name, leg = leg }
    end
    -- (chez le maître de vol, sa carte ouverte : le vol de l'itinéraire qui part d'ici)
    if not taxiOpen then return end
    local Pl, G = ns.TravelPlanner, ns.TravelGraph
    local here = Pl.PlayerPoint()
    for i = index, math.min(#plan.legs, index + 1) do
        local l = plan.legs[i]
        if l and l.kind == "flight" and here and l.from.cont == here.cont and G.Dist(here, l.from) <= TAXI_REACH then
            local slot = TaxiSlot(l.to)
            if Reachable(slot) then return { kind = "taxi", slot = slot, name = l.to.name, secs = l.secs, leg = l } end
        end
    end
end

local function TakeFlight()
    if shown and shown.kind == "taxi" and taxiOpen and TakeTaxiNode then
        pcall(TakeTaxiNode, shown.slot)
    end
end

---------------------------------------------------------------------------
-- Le bouton
---------------------------------------------------------------------------
local function SavePosition()
    local point, _, rel, x, y = frame:GetPoint(1)
    ns.db.options.travelButtonPos = { point, rel, x, y }
end

local function Tooltip(self)
    if not shown then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if shown.kind == "teleport" then
        GameTooltip:SetText(L.TRAVEL_LEG_TELEPORT:format(shown.name or "?"), 1, 0.82, 0)
    else
        GameTooltip:SetText(L.TRAVELBTN_TAXI:format(shown.name or "?"), 1, 0.82, 0)
    end
    GameTooltip:AddLine(L.TRAVELBTN_SKIP, 0.8, 0.8, 0.8, true)
    local key = KeyText()
    if key then GameTooltip:AddLine(L.TRAVELBTN_KEY:format(key), 0.6, 0.6, 0.6) end
    GameTooltip:AddLine(L.QUESTBTN_MOVE, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function Build()
    if frame or InCombatLockdown() then return frame end
    frame = CreateFrame("Frame", "MyMapIsRichTravelButtonFrame", UIParent)
    frame:SetSize(SIZE, SIZE)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    local pos = ns.db.options.travelButtonPos
    if type(pos) == "table" and pos[1] then
        frame:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -240)
    end
    button = UI.ActionSlot(frame, SIZE, "MyMapIsRichTravelButton", true, true)
    button:SetPoint("CENTER", frame, "CENTER", 0, 0)
    -- (clic droit : rien de protégé, une macro vide ; l'étape est passée après le clic)
    button:SetAttribute("type2", "macro")
    button:SetAttribute("macrotext2", "")
    button:SetScript("PreClick", function(_, which)
        if which ~= "RightButton" then TakeFlight() end
    end)
    button:SetScript("PostClick", function(_, which)
        if which == "RightButton" and ns.Travel then ns.Travel.SkipLeg() end
    end)
    button:SetScript("OnEnter", Tooltip)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        if IsShiftKeyDown() and not InCombatLockdown() then frame:StartMoving() end
    end)
    button:SetScript("OnDragStop", function()
        if InCombatLockdown() then return end
        frame:StopMovingOrSizing()
        SavePosition()
    end)
    -- (à côté : ce qu'il fait, et son raccourci)
    frame.text = UI.Text(frame, "GameFontNormal")
    frame.text:SetPoint("LEFT", button, "RIGHT", 8, 7)
    frame.text:SetJustifyH("LEFT")
    frame.key = UI.DimText(frame, nil, "GameFontHighlightSmall")
    frame.key:SetPoint("TOPLEFT", frame.text, "BOTTOMLEFT", 0, -3)
    frame:Hide()
    return frame
end

local function Cooldown()
    if not (button and shown and shown.kind == "teleport") then return end
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, shown.spell)
        if ok and type(info) == "table" then start, duration = Plain(info.startTime), Plain(info.duration) end
    elseif GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, shown.spell)
        if ok then start, duration = Plain(s), Plain(d) end
    end
    if type(start) == "number" and type(duration) == "number" and duration > 1.5 then
        button.cooldown:SetCooldown(start, duration)
    elseif button.cooldown.Clear then
        button.cooldown:Clear()
    else
        button.cooldown:SetCooldown(0, 0)
    end
end

---------------------------------------------------------------------------
-- L'aide au maître de vol
---------------------------------------------------------------------------
local function Duration(secs)
    if ns.RouteHud and ns.RouteHud.Duration then return ns.RouteHud.Duration(secs) end
    return tostring(math.floor((secs or 0) + 0.5))
end

local function BuildHelp()
    if help then return help end
    help = UI.Panel(UIParent, "MyMapIsRichTaxiHelp", "DIALOG")
    help:SetSize(240, 118)
    help:EnableMouse(true)
    help.title = UI.Text(help, "GameFontNormal", L.TRAVEL_TOOLTIP_TITLE)
    help.title:SetPoint("TOPLEFT", 12, -10)
    help.text = UI.Text(help, "GameFontHighlightSmall")
    help.text:SetPoint("TOPLEFT", help.title, "BOTTOMLEFT", 0, -6)
    help.text:SetPoint("RIGHT", help, "RIGHT", -12, 0)
    help.text:SetJustifyH("LEFT")
    help.take = UI.Button(help, L.TAXI_TAKE, 216, 26)
    help.take:SetPoint("BOTTOMLEFT", 12, 30)
    help.take:SetScript("OnClick", function() TakeFlight() end)
    help.key = UI.DimText(help, nil, "GameFontDisableSmall")
    help.key:SetPoint("BOTTOMLEFT", 12, 12)
    help.key:SetPoint("RIGHT", help, "RIGHT", -12, 0)
    help.key:SetJustifyH("LEFT")
    help:Hide()
    -- (l'anneau sur la destination : un cadre à nous, posé sur son bouton)
    ring = CreateFrame("Frame", nil, UIParent)
    ring:SetFrameStrata("DIALOG")
    ring:SetSize(34, 34)
    ring.tex = ring:CreateTexture(nil, "OVERLAY")
    ring.tex:SetAllPoints()
    ring.tex:SetTexture(RING_TEXTURE)
    ring.tex:SetVertexColor(1, 0.82, 0, 1)
    ring:Hide()
    return help
end

local function ShowHelp()
    local taxi = shown and shown.kind == "taxi" and shown
    if not taxi then
        if help then help:Hide() end
        if ring then ring:Hide() end
        return
    end
    BuildHelp()
    help:ClearAllPoints()
    local anchor = _G.TaxiFrame
    if anchor and anchor:IsShown() then
        help:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, -20)
    else
        help:SetPoint("RIGHT", UIParent, "RIGHT", -40, 0)
    end
    help.text:SetText(L.TAXI_NEXT:format(taxi.name or "?", Duration(taxi.secs)))
    local key = KeyText()
    help.key:SetText(key and L.TRAVELBTN_KEY:format(key) or L.TAXI_NO_KEY)
    help:Show()
    local slotButton = _G["TaxiButton" .. taxi.slot]
    ring:ClearAllPoints()
    if slotButton and slotButton:IsShown() then
        ring:SetPoint("CENTER", slotButton, "CENTER", 0, 0)
        ring:Show()
    else
        ring:Hide()
    end
end

---------------------------------------------------------------------------
-- Tout remis à jour (hors combat ; pendant un combat : à sa fin)
---------------------------------------------------------------------------
function TB.Refresh()
    local want = On() and Wanted() or nil
    -- (l'aide au maître de vol n'est pas protégée : elle suit tout de suite)
    shown = want
    ShowHelp()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    if not want then
        if frame then
            button:SetAttribute("type", nil)
            button:SetAttribute("spell", nil)
            frame:Hide()
        end
        return
    end
    if not Build() then return end
    if want.kind == "teleport" then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", want.name)
        local icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(want.spell))
            or (GetSpellTexture and GetSpellTexture(want.spell))
        button.icon:SetTexture(icon)
        frame.text:SetText(L.TRAVEL_LEG_TELEPORT:format(want.name or "?"))
    else
        -- (un vol : rien de protégé, le clic le prend avant, PreClick)
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
        button.icon:SetTexture(TAXI_ICON)
        frame.text:SetText(L.TRAVELBTN_TAXI:format(want.name or "?"))
    end
    local key = KeyText()
    frame.key:SetText(key and L.TRAVELBTN_KEY:format(key) or L.TRAVELBTN_SKIP)
    frame:Show()
    Cooldown()
end

local wait = false
local function Soon()
    if wait then return end
    wait = true
    C_Timer.After(0.2, function()
        wait = false
        local ok, err = pcall(TB.Refresh)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end)
end
ns.On("TRAVEL", Soon)
ns.On("OPTIONS", Soon)

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "TAXIMAP_OPENED" then
        taxiOpen = true
    elseif event == "TAXIMAP_CLOSED" then
        taxiOpen = false
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        pcall(Cooldown)
        return
    elseif event == "PLAYER_REGEN_ENABLED" and not pending then
        return
    end
    Soon()
end)
for _, e in ipairs({ "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_REGEN_ENABLED", "SPELL_UPDATE_COOLDOWN",
    "UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD" }) do
    pcall(events.RegisterEvent, events, e)
end
