-- Les objets de quête dans le suivi des quêtes (UI/Tracker.lua) : en face du
-- titre d'une quête qui a un objet à utiliser (une torche, une fiole...), sa
-- case, sur un bord du suivi (réglage trackerItemsSide : le côté du centre de
-- l'écran, la gauche ou la droite). Un clic l'utilise ; le temps de recharge
-- s'y dessine ; au survol, l'objet et sa quête. Réglage trackerItems, l'onglet
-- Quêtes.
-- Ce sont des boutons protégés (SecureActionButtonTemplate). Ils ne sont pas
-- ancrés au suivi : il deviendrait protégé à son tour, et il se refait en
-- combat. Ils sont posés sur UIParent, aux coordonnées de ses quêtes (TR.Shown),
-- à chaque fois qu'il se redessine (le message TRACKER_LAYOUT) ou que sa liste
-- défile. Créés, placés, montrés ou cachés hors combat seulement : un
-- changement pendant un combat attend PLAYER_REGEN_ENABLED, et le suivi garde
-- l'ordre de sa liste tant qu'il y en a (TI.Any). « Masquer en combat » : un
-- pilote d'état les cache avec lui.
-- À la manette, le suivi ne prend aucun bouton hors de la carte : l'objet de
-- la quête de l'itinéraire garde son raccourci (UI/QuestButtons.lua).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local TI = {}
ns.TrackerItems = TI

local SIZE = 26
local GAP = 4                -- px : entre le bord du suivi et la case

local holder                 -- le support des cases (le pilote « en combat » s'y pose)
local slots = {}             -- les cases, réutilisées
local used = 0               -- combien sont montrées
local pending = false        -- une mise en place attendue (après le combat)
local hooked = false         -- le défilement de la liste suivi
local driven                 -- le pilote « [combat] hide » posé (true / false)

local function Opt() return ns.db and ns.db.options or {} end

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function On()
    return ns.db and Opt().trackerItems ~= false and not (ns.Conflict and ns.Conflict())
end

-- Des cases sont-elles montrées ? (le suivi garde alors son ordre en combat)
function TI.Any() return used > 0 end

---------------------------------------------------------------------------
-- Les cases
---------------------------------------------------------------------------
local function Tip(self)
    local it = self.it
    if not it then return end
    GameTooltip:SetOwner(self, self.side == "left" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    pcall(GameTooltip.SetHyperlink, GameTooltip, it.link)
    if self.title then GameTooltip:AddLine(L.QUESTBTN_ITEM_TIP:format(self.title), 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

local function Holder()
    if holder then return holder end
    holder = CreateFrame("Frame", "MyMapIsRichTrackerItems", UIParent)
    holder:SetSize(1, 1)
    holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    holder:SetFrameStrata("MEDIUM")
    -- (au-dessus du suivi, niveau 20, et de sa liste)
    holder:SetFrameLevel(40)
    return holder
end

local function Slot(i)
    local b = slots[i]
    if b then return b end
    b = UI.ActionSlot(Holder(), SIZE, "MyMapIsRichTrackerItem" .. i, true, true)
    b:SetAttribute("type", "item")
    b:SetScript("OnEnter", Tip)
    b:Hide()
    slots[i] = b
    return b
end

local function Cooldown(b)
    local id = b.it and b.it.itemID
    local get = C_Container and C_Container.GetItemCooldown or _G.GetItemCooldown
    if not (id and get and b.cooldown) then return end
    local ok, start, duration, enable = pcall(get, id)
    start, duration = ok and Plain(start), ok and Plain(duration)
    if start and duration and duration > 0 and enable ~= 0 then
        b.cooldown:SetCooldown(start, duration)
    elseif b.cooldown.Clear then
        b.cooldown:Clear()
    else
        b.cooldown:SetCooldown(0, 0)
    end
end

-- « Masquer en combat » : les cases partent avec le suivi (hors combat seulement)
local function Driver()
    if not holder or InCombatLockdown() then return end
    local want = Opt().trackerCombat and true or false
    if want == driven then return end
    driven = want
    if want and RegisterStateDriver then
        RegisterStateDriver(holder, "visibility", "[combat] hide; show")
    else
        if UnregisterStateDriver then UnregisterStateDriver(holder, "visibility") end
        holder:Show()
    end
end

---------------------------------------------------------------------------
-- La mise en place
---------------------------------------------------------------------------
-- (de quel côté du suivi : celui du centre de l'écran, ou celui choisi)
local function Side()
    local side = Opt().trackerItemsSide
    if side == "left" or side == "right" then return side end
    return ns.Tracker.OnRight() and "left" or "right"
end

function TI.Layout()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local TR = ns.Tracker
    local frame, scroll, shown
    if On() and TR then frame, scroll, shown = TR.Shown() end
    local n = 0
    if frame and scroll and scroll:IsShown() and shown then
        if not hooked then
            hooked = true
            scroll:HookScript("OnVerticalScroll", function()
                local ok, err = pcall(TI.Layout)
                if not ok and geterrorhandler then geterrorhandler()(err) end
            end)
        end
        local side = Side()
        local top, bottom = scroll:GetTop(), scroll:GetBottom()
        local edge = side == "left" and frame:GetLeft() or frame:GetRight()
        if top and bottom and edge then
            for _, s in ipairs(shown) do
                local q, block = s.q, s.block
                local bt = block.q == q and block:IsShown() and block:GetTop()
                -- (la case entière dans la partie visible de la liste)
                if bt and bt <= top + 1 and bt - SIZE >= bottom - 1 then
                    local it = ns.QuestButtons and ns.QuestButtons.ItemOf(q.id)
                    if it and it.itemID then
                        n = n + 1
                        local b = Slot(n)
                        b.it, b.side, b.title = it, side, q.title
                        b:SetAttribute("item", "item:" .. it.itemID)
                        b.icon:SetTexture(it.icon)
                        b:ClearAllPoints()
                        if side == "left" then
                            b:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", edge - GAP, bt - 2)
                        else
                            b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", edge + GAP, bt - 2)
                        end
                        Cooldown(b)
                        b:Show()
                    end
                end
            end
        end
    end
    -- (les autres : vides, cachées ; plus rien à utiliser par elles)
    for i = n + 1, #slots do
        local b = slots[i]
        b.it, b.title = nil, nil
        b:SetAttribute("item", nil)
        b:Hide()
    end
    used = n
    Driver()
end

---------------------------------------------------------------------------
-- Les événements
---------------------------------------------------------------------------
ns.On("TRACKER_LAYOUT", TI.Layout)

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then TI.Layout() end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        -- (le temps de recharge : permis en combat, la case ne bouge pas)
        for i = 1, used do pcall(Cooldown, slots[i]) end
    end
end)
for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "BAG_UPDATE_COOLDOWN" }) do
    pcall(events.RegisterEvent, events, e)
end
