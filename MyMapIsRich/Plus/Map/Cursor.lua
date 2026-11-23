-- Le curseur de la manette sur la carte : ce qu'il survole et presse, et les
-- sticks lus sur la manette. En code de My Map Is Rich depuis la 0.12.0 (il
-- venait de Map/Gamepad.lua et Map/WorldMap.lua).
-- Le curseur est celui du jeu (SoftCursor, le stick gauche) ; sa place sur la
-- vue est donnée par Map/View.lua (C.XY, C.World). Ici :
--   les racines   les fenêtres de l'addon sur la carte (C.AddRoot) : ce qui
--                 est sous le curseur y est survolé comme à la souris, A le
--                 presse ;
--   les sticks    lus sur la manette, sans raccourci posé : le droit zoome
--                 (C.ZoomTilt), le gauche dit vers où pousse le curseur
--                 (C.Stick) quand il bute sur un bord.
local _, root = ...
local ns = root.Plus

local C = ns.Map.Cursor

local roots = {}                 -- les fenêtres de l'addon sur la carte
local PAD_DEAD = 0.05            -- le stick du zoom au repos, en dessous

function C.AddRoot(f) if f then roots[#roots + 1] = f end end
function C.Roots() return roots end

local function Inside(f, x, y)
    local l, b, w, h = f:GetRect()
    if not l then return false end
    local es = f:GetEffectiveScale()
    local il, ir, it, ib = f:GetHitRectInsets()
    x, y = x / es, y / es
    return x >= l + il and x <= l + w - ir and y >= b + ib and y <= b + h - it
end

local function Pressable(f)
    return f:IsObjectType("Button") or f:IsObjectType("Slider") or f:IsObjectType("EditBox")
end

-- (la place d'un cadre dans l'empilement : sa strate, puis son niveau)
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local function Height(f) return (STRATA[f:GetFrameStrata()] or 3) * 100000 + f:GetFrameLevel() end

-- Le cadre pressable le plus haut sous (x, y) dans f et ses enfants (found) ;
-- blocked : un cadre qui prend la souris est là (le fond d'une fenêtre), la
-- carte dessous ne l'est donc pas
local found, foundLevel, blocked
local Find
local function FindIn(x, y, ...)
    for i = 1, select("#", ...) do Find((select(i, ...)), x, y) end
end
function Find(f, x, y)
    if not f:IsVisible() then return end
    if f:IsMouseEnabled() and Inside(f, x, y) then
        blocked = true
        -- (noPadPress : un bouton protégé du jeu que A ne doit pas cliquer d'ici)
        if Pressable(f) and not f.noPadPress and (not found or Height(f) >= foundLevel) then
            found, foundLevel = f, Height(f)
        end
    end
    FindIn(x, y, f:GetChildren())
end

-- Le cadre de l'addon sous (x, y) (px de l'écran), et si un cadre est là
function C.ControlAt(x, y)
    found, foundLevel, blocked = nil, nil, false
    for _, f in ipairs(roots) do Find(f, x, y) end
    return found, blocked
end

-- Le cadre de l'addon le plus haut sous (x, y) qui prend la molette (une
-- liste...), pour que le stick droit la fasse défiler
local wheel, wheelLevel
local function FindWheel(f, x, y)
    if not f:IsVisible() then return end
    if f:IsMouseWheelEnabled() and f:GetScript("OnMouseWheel") and Inside(f, x, y)
        and (not wheel or Height(f) >= wheelLevel) then
        wheel, wheelLevel = f, Height(f)
    end
    for _, child in ipairs({ f:GetChildren() }) do FindWheel(child, x, y) end
end
function C.WheelAt(x, y)
    wheel, wheelLevel = nil, nil
    for _, f in ipairs(roots) do FindWheel(f, x, y) end
    return wheel
end

-- A, le curseur en (x, y) : vrai si c'était à l'addon de le prendre
function C.Press(x, y)
    local f, taken = C.ControlAt(x, y)
    if not f then return taken end
    if f:IsObjectType("Slider") then
        -- (à la valeur sous le curseur)
        local lo, hi = f:GetMinMaxValues()
        local l, _, w = f:GetRect()
        if l and w > 0 and hi > lo then
            local v = lo + (hi - lo) * math.max(0, math.min(1, (x / f:GetEffectiveScale() - l) / w))
            local step = f:GetValueStep()
            if step and step > 0 then v = lo + math.floor((v - lo) / step + 0.5) * step end
            f:SetValue(v)
        end
    elseif f:IsObjectType("EditBox") then
        f:SetFocus()
    elseif f.OnClick and not f:GetScript("OnClick") then
        f:OnClick()             -- (une icône de la carte : son clic)
    else
        f:Click()
    end
    return true
end

---------------------------------------------------------------------------
-- Les sticks, lus sur la manette (aucun raccourci posé)
---------------------------------------------------------------------------
local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Le stick qui porte ce nom dans la configuration de la manette : x, y (-1..1)
local function StickXY(name)
    if not (ns.Map.PadUI() and C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.StickIndexToConfigName) then
        return nil
    end
    local ok, state = pcall(C_GamePad.GetDeviceMappedState)
    if not ok or type(state) ~= "table" then return nil end
    local count, sticks = Plain(state.stickCount), Plain(state.sticks)
    if type(count) ~= "number" or type(sticks) ~= "table" then return nil end
    for i = 1, count do
        local okN, n = pcall(C_GamePad.StickIndexToConfigName, i - 1)   -- (comptés depuis 0)
        if okN and n == name then
            local stick = sticks[i]
            local x = type(stick) == "table" and Plain(stick.x)
            local y = type(stick) == "table" and Plain(stick.y)
            if type(x) ~= "number" or type(y) ~= "number" then return nil end
            return x, y
        end
    end
    return nil
end

-- Le stick du zoom (le droit, « Camera ») : -1 (dézoomer) à 1 (zoomer), 0 au
-- repos ; nil : il ne se lit pas (pas d'interface manette)
function C.ZoomTilt()
    local _, y = StickXY("Camera")
    if type(y) ~= "number" then return nil end
    if math.abs(y) < PAD_DEAD then return 0 end
    local tilt = math.min(math.abs(y), 1) ^ 1.8                       -- (la courbe du jeu)
    return y >= 0 and tilt or -tilt
end

-- Le stick du curseur (le gauche, « Movement ») : x, y (vers la droite et vers le haut)
function C.Stick() return StickXY("Movement") end
