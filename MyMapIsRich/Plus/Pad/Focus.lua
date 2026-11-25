-- La navigation à la croix dans les fenêtres de l'addon (sa fenêtre et ses
-- onglets, les épingles et leur fiche, la fiche d'un point, les lieux, le
-- panneau des quêtes, la carte d'un donjon, le clavier virtuel, les
-- nouveautés...). Reprise de My Guild Is Rich (UI/Gamepad.lua) :
--   croix         : d'un élément à l'autre dans la direction voulue (le plus
--                   proche) ; un réglage à curseur : gauche / droite changent
--                   sa valeur ; une liste défile quand on sort de ses lignes
--   A             : valider (clic) ; un champ de texte : le clavier virtuel
--   X             : clic droit
--   B             : retour (ferme la fenêtre du dessus)
--   LB / RB       : onglet précédent / suivant (la fenêtre de l'addon, les lieux, la carte d'un donjon...)
--   Y             : ouvrir / fermer les réglages de la carte (ns.Map.Menu)
-- L'élément choisi a un cadre doré et son info-bulle. Le curseur de la
-- manette (stick gauche) reste utilisable : l'élément qu'il survole devient
-- l'élément choisi.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI
local P = ns.Pad

local F = {}
ns.Focus = F

-- Les fenêtres de l'addon : cadre -> { onBack = fn, onTab = fn(dir) }
local own = {}
function F.RegisterWindow(frame, opts)
    own[frame] = opts or {}
end

-- (la place d'un cadre dans l'empilement : sa strate, puis son niveau)
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local function Height(f) return (STRATA[f:GetFrameStrata()] or 3) * 100000 + f:GetFrameLevel() end

-- Une des fenêtres données au curseur de la manette (ns.Map.Cursor.Roots) :
-- assez grande pour être une fenêtre (pas un bouton du bord de la carte ni
-- une barre d'outils), ni la carte d'un donjon (Pad/Dungeon.lua), ni le
-- plateau de la plume (Pad/MapNav.lua)
local function IsWindow(f)
    if type(f) ~= "table" or not f.IsVisible or not f:IsVisible() then return false end
    if not f:IsMouseEnabled() then return false end
    -- (un panneau au repos, ouvert sans prendre la manette : le panneau des
    -- quêtes, UI/QuestPanel.lua, le plateau de la plume, Layers/Sketch.lua ;
    -- le curseur peut quand même y presser une ligne, un outil)
    if f.padPassive then return false end
    if f == ns.Map.Dungeons.Frame() then return false end
    local w, h = f:GetSize()
    return w and h and w >= 150 and h >= 90 or false
end

local function Windows()
    local out, seen = {}, {}
    local function Add(f)
        if f and not seen[f] and IsWindow(f) then
            seen[f] = true
            out[#out + 1] = f
        end
    end
    for f in pairs(own) do Add(f) end
    for _, f in ipairs(ns.Map.Windows()) do Add(f) end
    for _, f in ipairs(ns.Map.Cursor.Roots() or {}) do Add(f) end
    return out
end

-- Un panneau qui n'est pas une fenêtre, choisi pour la croix le temps d'y
-- faire quelque chose (les outils de la plume, le panneau d'un donjon) :
-- B en ressort
local forced
function F.SetForced(f)
    forced = f
    P.Dirty()
end
function F.Forced() return forced end

-- La fenêtre du dessus (nil : aucune)
function F.Top()
    if forced then
        if forced:IsVisible() then return forced end
        forced = nil
    end
    local best, bestH
    for _, f in ipairs(Windows()) do
        local h = Height(f)
        if not best or h > bestH then best, bestH = f, h end
    end
    return best
end

---------------------------------------------------------------------------
-- Les éléments qu'on peut choisir dans une fenêtre
---------------------------------------------------------------------------
local function Usable(f)
    if not (f:IsVisible() and f:IsMouseEnabled()) then return false end
    if f.IsEnabled and not f:IsEnabled() then return false end
    if f.noGamepad then return false end
    if f.GetEffectiveAlpha and f:GetEffectiveAlpha() < 0.05 then return false end
    local w, h = f:GetSize()
    return w and h and w > 4 and h > 4 and f:GetLeft() ~= nil
end

local function Pressable(f)
    local kind = f:GetObjectType()
    if kind == "Button" or kind == "CheckButton" or kind == "EditBox" then return true end
    -- (un curseur de réglage, pas une barre de défilement verticale)
    if kind == "Slider" then return f:GetOrientation() ~= "VERTICAL" end
    return false
end

local function Collect(frame, out)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsVisible() then
            if Pressable(child) and Usable(child) then out[#out + 1] = child end
            Collect(child, out)
        end
    end
    return out
end
F.Collect = Collect

-- (en pixels de l'écran : les fenêtres n'ont pas toutes la même échelle)
local function Center(f)
    local x, y = f:GetCenter()
    local es = f:GetEffectiveScale()
    return x * es, y * es
end

-- Le plus proche dans une direction (dx, dy : -1, 0 ou 1)
local function Nearest(fx, fy, list, dx, dy, skip)
    local best, bestScore
    for _, f in ipairs(list) do
        if f ~= skip then
            local x, y = Center(f)
            local ax, ay = x - fx, y - fy
            local primary = dx ~= 0 and ax * dx or ay * dy
            local secondary = dx ~= 0 and math.abs(ay) or math.abs(ax)
            if primary > 2 then
                local score = primary + secondary * 2.5
                if not bestScore or score < bestScore then best, bestScore = f, score end
            end
        end
    end
    return best
end
F.Nearest = Nearest

-- Le premier élément (en haut à gauche)
local function First(list)
    local best, bx, by
    for _, f in ipairs(list) do
        local x, y = Center(f)
        if not best or y > by + 4 or (math.abs(y - by) <= 4 and x < bx) then best, bx, by = f, x, y end
    end
    return best
end

---------------------------------------------------------------------------
-- Le cadre doré
---------------------------------------------------------------------------
local frame                 -- le cadre doré
local current               -- l'élément choisi
local scope                 -- la fenêtre où il est

local function Leave(f)
    if not f then return end
    local onLeave = f:GetScript("OnLeave")
    if onLeave then pcall(onLeave, f) end
    if f.UnlockHighlight then pcall(f.UnlockHighlight, f) end
end

-- (le dernier élément choisi dans chaque fenêtre : on y revient quand elle
-- repasse au-dessus, le clavier refermé par exemple)
local lastFocus = setmetatable({}, { __mode = "k" })

local function SetCurrent(f)
    if current == f then return end
    Leave(current)
    current = f
    if f then
        local top = F.Top()
        if top then lastFocus[top] = f end
    end
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        if frame.SetBackdrop then
            frame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
            frame:SetBackdropBorderColor(1, 0.82, 0, 1)
        end
        frame:EnableMouse(false)
        frame:SetScript("OnUpdate", function(self)
            -- (l'élément disparaît sans passer par la manette : le cadre s'en va avec lui)
            if not (current and current:IsVisible()) then
                current = nil
                self:Hide()
            end
        end)
    end
    if not f then
        frame:Hide()
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
    frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
    frame:SetFrameStrata(f:GetFrameStrata())
    frame:SetFrameLevel(math.min(10000, f:GetFrameLevel() + 20))
    -- (un élément qui montre lui-même qu'il est choisi, une case ronde de
    -- la roue : pas de cadre carré autour)
    frame:SetShown(not f.noFocusFrame)
    if f.LockHighlight then pcall(f.LockHighlight, f) end
    local onEnter = f:GetScript("OnEnter")
    if onEnter then pcall(onEnter, f) end
end
F.SetCurrent = SetCurrent

function F.Current() return current end

-- L'élément est dans une zone qui défile (UI.Scroll) : elle défile
-- jusqu'à lui
local function ScrollParent(f)
    local p = f:GetParent()
    while p do
        if p:GetObjectType() == "ScrollFrame" then return p end
        p = p:GetParent()
    end
end

local function EnsureVisible(f)
    local sf = ScrollParent(f)
    if not sf then return end
    local wheel = sf:GetScript("OnMouseWheel")
    for _ = 1, 40 do
        local top, bottom = f:GetTop(), f:GetBottom()
        local sTop, sBottom = sf:GetTop(), sf:GetBottom()
        if not (top and sTop) then return end
        local es, ses = f:GetEffectiveScale(), sf:GetEffectiveScale()
        top, bottom, sTop, sBottom = top * es, bottom * es, sTop * ses, sBottom * ses
        local delta
        if top > sTop + 1 then delta = 1 elseif bottom < sBottom - 1 then delta = -1 else return end
        local before = sf:GetVerticalScroll()
        if wheel then
            pcall(wheel, sf, delta)
        else
            local max = sf:GetVerticalScrollRange() or 0
            sf:SetVerticalScroll(math.max(0, math.min(max, before - delta * 24)))
        end
        if math.abs(sf:GetVerticalScroll() - before) < 0.5 then return end
    end
end

-- Au bord d'une liste aux lignes réutilisées (la liste des épingles, nos
-- listes) : elle défile d'un cran, le cadre reste sur la même ligne
local function ScrollList(f, dy)
    -- (nos listes, UI.ScrollList / Places.lua : rows, offset, SetOffset)
    local p = f:GetParent()
    if p and p.rows and p.SetOffset and p.offset then
        local before = p.offset
        p:SetOffset(p.offset - dy)
        return p.offset ~= before
    end
    -- (une autre liste : la molette de son cadre)
    p = f:GetParent()
    while p and p ~= scope do
        if p:IsMouseWheelEnabled() and p:GetScript("OnMouseWheel") then
            pcall(p:GetScript("OnMouseWheel"), p, dy)
            return true
        end
        p = p:GetParent()
    end
    if scope and scope:IsMouseWheelEnabled() and scope:GetScript("OnMouseWheel") then
        pcall(scope:GetScript("OnMouseWheel"), scope, dy)
        return true
    end
    return false
end

-- Un curseur de réglage : un pas de plus ou de moins
local function StepSlider(s, dir)
    local lo, hi = s:GetMinMaxValues()
    local step = s:GetValueStep()
    if not step or step <= 0 then step = (hi - lo) / 20 end
    s:SetValue(math.max(lo, math.min(hi, s:GetValue() + dir * step)))
end

function F.Elements()
    scope = F.Top()
    return scope and Collect(scope, {}) or {}
end

function F.Move(dx, dy)
    local list = F.Elements()
    if #list == 0 then return SetCurrent(nil) end
    local valid = false
    if current and current:IsVisible() then
        for _, f in ipairs(list) do
            if f == current then valid = true break end
        end
    end
    if not valid then
        local opts = scope and own[scope]
        local start = opts and opts.first and opts.first()
        if not (start and start:IsVisible()) then start = First(list) end
        SetCurrent(start)
        if current then EnsureVisible(current) end
        return
    end
    if dx ~= 0 and current:GetObjectType() == "Slider" then
        StepSlider(current, dx)
        return
    end
    local cx, cy = Center(current)
    local nextOne = Nearest(cx, cy, list, dx, dy, current)
    if nextOne then
        SetCurrent(nextOne)
        EnsureVisible(nextOne)
        return
    end
    if dy ~= 0 and ScrollList(current, dy) then
        -- (la ligne a changé de contenu : son info-bulle refaite)
        local f = current
        C_Timer.After(0, function()
            if f == current and f:IsVisible() then
                Leave(f)
                if f.LockHighlight then pcall(f.LockHighlight, f) end
                local onEnter = f:GetScript("OnEnter")
                if onEnter then pcall(onEnter, f) end
            end
        end)
    end
end

function F.Activate(mouse)
    if not (current and current:IsVisible()) then
        F.Move(0, 0)
        return
    end
    local kind = current:GetObjectType()
    if kind == "EditBox" then
        if ns.Keyboard then ns.Keyboard.Open(current) end
        return
    end
    if kind == "Slider" then return end
    if current.Click then
        local ok, err = pcall(current.Click, current, mouse or "LeftButton")
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
    -- (l'écran a pu changer : on garde le cadre s'il est toujours là)
    C_Timer.After(0.05, function()
        if current and not current:IsVisible() then SetCurrent(nil) end
    end)
end

-- La croix de fermeture d'une fenêtre : un petit bouton dans son coin en haut
-- à droite (UI.CloseButton ; le CloseButton d'un cadre du jeu)
local function FindClose(f)
    for _, key in ipairs({ "close", "CloseButton", "Close" }) do
        local b = f[key]
        if type(b) == "table" and b.IsObjectType and b:IsObjectType("Button") and b:IsVisible() then return b end
    end
    local right, top = f:GetRight(), f:GetTop()
    if not right then return end
    local es = f:GetEffectiveScale()
    right, top = right * es, top * es
    for _, child in ipairs({ f:GetChildren() }) do
        if child:IsObjectType("Button") and child:IsVisible() and child:IsMouseEnabled() then
            local w, h = child:GetSize()
            local r, t = child:GetRight(), child:GetTop()
            if w and w <= 40 and h <= 40 and r then
                local ces = child:GetEffectiveScale()
                if math.abs(r * ces - right) < 30 and math.abs(t * ces - top) < 30 then return child end
            end
        end
    end
end

function F.Close(f)
    if not f then return end
    local opts = own[f]
    if f == forced then
        forced = nil
        P.Dirty()
    elseif opts and opts.onBack then
        opts.onBack()
    elseif f == ns.Map.MyPins.Frame() then
        ns.Map.MyPins.Toggle(false)
    else
        local close = FindClose(f)
        if close then pcall(close.Click, close) else f:Hide() end
    end
    SetCurrent(nil)
end

function F.Back()
    F.Close(F.Top())
end

-- LB / RB : les onglets du menu de la carte (ou d'une de nos fenêtres)
local function CycleTabs(tabs, currentKey, dir)
    if type(tabs) ~= "table" or #tabs == 0 then return false end
    local at = 1
    for i, b in ipairs(tabs) do
        if b.key == currentKey then at = i end
    end
    local nextTab = tabs[(at - 1 + dir) % #tabs + 1]
    if nextTab and nextTab.Click then
        pcall(nextTab.Click, nextTab)
        SetCurrent(nil)
        return true
    end
    return false
end
F.CycleTabs = CycleTabs

function F.Tab(dir)
    local top = F.Top()
    if not top then return end
    local opts = own[top]
    if opts and opts.onTab then
        opts.onTab(dir)
        SetCurrent(nil)
        return
    end
end

-- Y : les réglages de la carte (l'onglet Carte de /mmir) ouverts ou fermés
function F.ToggleMenu()
    if not ns.Ready() then return end
    ns.Map.Menu.Toggle()
    SetCurrent(nil)
end

---------------------------------------------------------------------------
-- Le curseur de la manette : l'élément qu'il survole devient l'élément choisi
---------------------------------------------------------------------------
local lastX, lastY
local follower = CreateFrame("Frame")
follower:Hide()
local wait = 0
follower:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = 0.08
    local x, y = ns.Map.Cursor.XY()
    if not x then return end
    if lastX and math.abs(x - lastX) + math.abs(y - lastY) < 4 then return end
    lastX, lastY = x, y
    local ctl = ns.Map.Cursor.ControlAt(x, y)
    if not ctl or ctl == current then return end
    for _, f in ipairs(F.Elements()) do
        if f == ctl then
            SetCurrent(ctl)
            return
        end
    end
end)

---------------------------------------------------------------------------
-- Le contexte « window »
---------------------------------------------------------------------------
P.DefineContext("window", 50, function() return F.Top() ~= nil end)
P.SetAction("window", "PADDUP", function() F.Move(0, 1) end)
P.SetAction("window", "PADDDOWN", function() F.Move(0, -1) end)
P.SetAction("window", "PADDLEFT", function() F.Move(-1, 0) end)
P.SetAction("window", "PADDRIGHT", function() F.Move(1, 0) end, "HINT_MOVE")
P.SetAction("window", "PAD1", function() F.Activate("LeftButton") end, "HINT_SELECT")
-- (X : le clic droit ; carte ouverte, la taille de la carte, et le clic droit
-- passe sur View. Le clavier et l'invitation gardent leur propre X)
local function OnMap() return ns.FullMap() and ns.MapShown() end
P.SetAction("window", "PAD3", function()
    if OnMap() then ns.PadMapSize() else F.Activate("RightButton") end
end, function() return ns.PadMapSizeHint() or "HINT_RIGHT_CLICK" end)
P.SetAction("window", "PADBACK", function()
    if OnMap() then F.Activate("RightButton") end
end, function() return OnMap() and "HINT_RIGHT_CLICK" or nil end)
P.SetAction("window", "PAD2", F.Back, "HINT_BACK")
P.SetAction("window", "PADLSHOULDER", function() F.Tab(-1) end)
P.SetAction("window", "PADRSHOULDER", function() F.Tab(1) end, function()
    local top = F.Top()
    if top and own[top] and own[top].onTab then return "HINT_TABS" end
end)
P.SetAction("window", "PAD4", F.ToggleMenu, function()
    return ns.Map.Menu.Shown() and "HINT_MENU_CLOSE" or nil
end)
P.SetPassive("window", "RSTICK", "HINT_SCROLL")

-- Les contextes où la croix va d'un élément à l'autre d'une fenêtre : celui
-- des fenêtres, et ceux qui en reprennent les boutons (le clavier, la roue,
-- le navigateur de lieux, une destination reçue)
F.WINDOW_CONTEXTS = { window = true, keyboard = true }
local function InWindow(name) return name ~= nil and F.WINDOW_CONTEXTS[name] == true end

ns.On("CONTEXT", function(name, was)
    local inWindow = InWindow(name)
    follower:SetShown(inWindow)
    lastX, lastY = nil, nil
    if not inWindow then
        SetCurrent(nil)
    elseif not (current and current:IsVisible()) then
        -- (une fenêtre s'ouvre : son premier élément choisi)
        C_Timer.After(0, function()
            if InWindow(P.current) and not (current and current:IsVisible()) then
                F.Move(0, 0)
            end
        end)
    end
end)

-- (une autre fenêtre passe au-dessus, une s'en va : le cadre la suit)
local watcher = CreateFrame("Frame")
local lastTop
watcher:SetScript("OnUpdate", function()
    if not InWindow(P.current) then
        lastTop = nil
        return
    end
    local top = F.Top()
    if top ~= lastTop then
        lastTop = top
        local remembered = top and lastFocus[top]
        if remembered and remembered:IsVisible() then
            SetCurrent(remembered)
        else
            SetCurrent(nil)
            if top then C_Timer.After(0, function() F.Move(0, 0) end) end
        end
    end
end)

ns.On("MAP_HIDE", function()
    forced = nil
    SetCurrent(nil)
end)
