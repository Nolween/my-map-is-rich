-- Les vibrations de la manette pendant un itinéraire (repris de My Gamepad Is
-- Rich, Rumble.lua) : une impulsion à chaque nouvelle étape, deux à
-- l'arrivée, une longue quand on quitte le chemin, trois courtes avant
-- l'atterrissage d'un vol. Seulement si le jeu donne C_GamePad.SetVibration ;
-- réglage « Vibrations » (onglet Trajets), coché par défaut. Rien n'est
-- protégé : cela marche aussi en combat.
local _, root = ...
local ns = root.Plus

local RB = {}
ns.Rumble = RB

function RB.Available()
    return type(C_GamePad) == "table" and type(C_GamePad.SetVibration) == "function"
end

function RB.Enabled()
    return RB.Available() and ns.db ~= nil and ns.db.options.travelRumble ~= false
end

-- Chaque motif : des impulsions { durée, intensité }, séparées par GAP
local GAP = 0.08
local PATTERNS = {
    step = { { 0.10, 0.5 } },
    arrive = { { 0.12, 0.6 }, { 0.12, 0.6 } },
    off = { { 0.35, 0.4 } },
    land = { { 0.07, 0.5 }, { 0.07, 0.5 }, { 0.07, 0.5 } },
}

local function Start(intensity)
    pcall(C_GamePad.SetVibration, "Low", intensity)
end

local function Stop()
    if C_GamePad.StopVibration then pcall(C_GamePad.StopVibration) else Start(0) end
end

function RB.Play(kind)
    if not RB.Enabled() then return end
    local pattern = PATTERNS[kind]
    if not pattern then return end
    local t = 0
    for _, pulse in ipairs(pattern) do
        local duration, intensity = pulse[1], pulse[2]
        if t == 0 then Start(intensity) else C_Timer.After(t, function() Start(intensity) end) end
        t = t + duration
        C_Timer.After(t, Stop)
        t = t + GAP
    end
end
