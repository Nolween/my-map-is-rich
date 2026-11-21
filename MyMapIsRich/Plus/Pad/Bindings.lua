-- La couche des boutons de la manette, carte ouverte.
--
-- Chaque module déclare un contexte (P.DefineContext) : un nom, une
-- priorité, une fonction qui dit s'il s'applique maintenant, et ses actions
-- (P.SetAction : un bouton -> une fonction et son libellé pour la barre
-- d'aide). Toutes les 0,1 s, carte ouverte, le contexte le plus prioritaire
-- qui s'applique est choisi ; s'il change, ses boutons sont posés.
--   keyboard (100) : le clavier virtuel ouvert (UI/Keyboard.lua)
--   window    (50) : une fenêtre d'OpenMap ou de l'addon (Pad/Focus.lua)
--   sketch    (45) : la plume d'OpenMap sortie (Pad/MapNav.lua)
--   dungeon   (40) : la carte d'un donjon (Pad/Dungeon.lua)
--   questlog  (20) : une quête de la liste de droite a le focus (Travel/Quests.lua)
--   map       (10) : la carte seule (Pad/MapNav.lua)
--
-- Comment les boutons sont pris : par des raccourcis prioritaires
-- (SetOverrideBindingClick) vers des boutons invisibles à nous, posés
-- seulement carte ouverte et hors combat, comme My Guild Is Rich. Jamais en
-- prenant toute la manette (EnableGamePadButton, SetPropagateGamePadInput) :
-- le jeu exécute alors les actions des autres boutons depuis le code de
-- l'addon et les bloque. Seuls les boutons du contexte sont pris : les autres
-- restent à la carte du jeu et à la vue manette d'OpenMap (sur la carte
-- seule : A, X, B, le stick gauche et son clic, le stick droit).
-- L'interface manette refait les raccourcis de la carte à chaque changement
-- de carte (son pied de page, worldMapFooter) : les nôtres sont reposés
-- après, comme OpenMap le fait pour les siens (Map/Gamepad.lua).
local _, root = ...
local ns = root.Plus
local L = ns.L

local P = {}
ns.Pad = P

-- Les boutons que l'addon peut prendre
local KEYS = {
    "PAD1", "PAD2", "PAD3", "PAD4",
    "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
    "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER",
    "PADFORWARD", "PADBACK",
    -- (R3 : pris seulement sur la liste des quêtes, où le jeu en fait un
    -- ping ; sur la carte, il est lu : Travel/Quests.lua, Pad/MapNav.lua)
    "PADRSTICK",
}
P.KEYS = KEYS
-- (ceux qui se répètent tant qu'on les tient)
local REPEAT = { PADDUP = true, PADDDOWN = true, PADDLEFT = true, PADDRIGHT = true }
local REPEAT_DELAY, REPEAT_EVERY = 0.35, 0.085
local REPEAT_MAX = 6          -- s : sécurité si le relâchement n'arrive jamais
local EVERY = 0.1             -- s entre deux choix du contexte

---------------------------------------------------------------------------
-- Les contextes
---------------------------------------------------------------------------
local contexts = {}   -- nom -> { name, priority, detect, base, actions, order, passive }
local sorted = {}

-- mode : "bind" (des raccourcis, par défaut) ou "read" (aucun raccourci : les
-- boutons sont lus sur la manette, Read plus bas). Sur la carte seule,
-- l'interface manette lie tous les boutons ; y poser nos raccourcis lui fait
-- perdre le focus de la carte (plus de curseur, le stick fait marcher le
-- personnage) : là, seuls des boutons dont elle ne se sert pas sont lus.
function P.DefineContext(name, priority, detect, base, mode)
    local c = contexts[name] or { name = name, actions = {}, order = {}, passive = {} }
    c.priority, c.detect, c.base, c.mode = priority, detect, base, mode or "bind"
    contexts[name] = c
    wipe(sorted)
    for _, ctx in pairs(contexts) do sorted[#sorted + 1] = ctx end
    table.sort(sorted, function(a, b) return a.priority > b.priority end)
    return c
end

-- Une action d'un contexte : fn(), label (clé de traduction ou fonction qui
-- rend un texte ; nil : pas dans la barre d'aide)
function P.SetAction(name, key, fn, label)
    local c = contexts[name] or P.DefineContext(name, 0, function() return false end)
    if not c.actions[key] then c.order[#c.order + 1] = key end
    c.actions[key] = { fn = fn, label = label }
end

-- Une aide pour un bouton que l'addon ne prend pas (celui du jeu ou
-- d'OpenMap, dans la barre d'aide)
function P.SetPassive(name, key, label)
    local c = contexts[name] or P.DefineContext(name, 0, function() return false end)
    c.passive[#c.passive + 1] = { key = key, label = label }
end

-- Les actions d'un contexte, avec celles de son contexte de base
local function ActionOf(name, key)
    local c = contexts[name]
    while c do
        local a = c.actions[key]
        if a then return a end
        c = c.base and contexts[c.base]
    end
end

local function KeysOf(name)
    local out, seen = {}, {}
    local c = contexts[name]
    while c do
        for _, key in ipairs(c.order) do
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = key
            end
        end
        c = c.base and contexts[c.base]
    end
    return out
end

-- Pour la barre d'aide : { { key, text }, ... } du contexte en cours
function P.Hints()
    local out = {}
    local name = P.current
    if not name then return out end
    for _, key in ipairs(KeysOf(name)) do
        local a = ActionOf(name, key)
        local label = a and a.label
        if type(label) == "function" then label = label() end
        if type(label) == "string" then out[#out + 1] = { key = key, text = L[label] or label } end
    end
    local c = contexts[name]
    -- (un bouton déjà dit par un contexte ne l'est pas encore par sa base :
    -- la roue dit ce que fait le stick droit, la fenêtre ne le redit pas)
    local said = {}
    while c do
        for _, p in ipairs(c.passive) do
            -- (un libellé qui dépend de l'état : la fonction peut ne rien rendre,
            -- l'aide n'est alors pas montrée)
            local label = p.label
            if type(label) == "function" then label = label() end
            if type(label) == "string" and not said[p.key] then
                said[p.key] = true
                out[#out + 1] = { key = p.key, text = L[label] or label, passive = true }
            end
        end
        c = c.base and contexts[c.base]
    end
    return out
end

---------------------------------------------------------------------------
-- L'état physique de la manette (pour la répétition de la croix)
---------------------------------------------------------------------------
local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Les boutons de la manette maintenant (la table du jeu), sinon nil
local function PadButtons()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return nil end
    local ok, state = pcall(C_GamePad.GetDeviceMappedState)
    if not ok or type(state) ~= "table" then return nil end
    local buttons = Plain(state.buttons)
    return type(buttons) == "table" and buttons or nil
end

local indexOf = {}
local function IndexOf(key)
    local index = indexOf[key]
    if index == nil then
        index = false
        if C_GamePad and C_GamePad.ButtonBindingToIndex then
            local ok, i = pcall(C_GamePad.ButtonBindingToIndex, key)
            if ok and type(i) == "number" then index = i end
        end
        indexOf[key] = index
    end
    return index or nil
end

-- Un bouton enfoncé dans `buttons` (true / false ; nil : on ne sait pas)
local function DownIn(buttons, key)
    local index = buttons and IndexOf(key)
    if not index then return nil end
    local v = Plain(buttons[index + 1])
    if v == nil then return nil end
    return v and true or false
end

function P.IsPadDown(key)
    return DownIn(PadButtons(), key)
end

---------------------------------------------------------------------------
-- L'imitation Maj / Ctrl / Alt des boutons (Forever : LT imite Maj, LB
-- Ctrl). Un tel bouton n'envoie son propre appui que s'il est tapé très
-- brièvement : tant que l'addon le prend, l'imitation est coupée, et remise
-- dès qu'il le rend (à la fermeture de la carte, avant un combat, à la
-- déconnexion ; et à la connexion si le jeu s'est arrêté carte ouverte).
-- Les réglages d'origine sont gardés dans OpenMapOnGamepadDB.padEmulation.
---------------------------------------------------------------------------
local EMULATE_CVARS = { "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }

local function GetCVarValue(name)
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    if not get then return nil end
    local ok, value = pcall(get, name)
    return ok and value or nil
end

local function SetCVarValue(name, value)
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if set then pcall(set, name, value) end
end

local function CutEmulation(keys)
    if not ns.db then return end
    ns.db.padEmulation = ns.db.padEmulation or {}
    local saved = ns.db.padEmulation
    local taken = {}
    for _, key in ipairs(keys) do taken[key] = true end
    for _, cvar in ipairs(EMULATE_CVARS) do
        local value = GetCVarValue(cvar)
        if value and taken[value] and not saved[cvar] then
            saved[cvar] = value
            SetCVarValue(cvar, "none")
        end
    end
end

local function RestoreEmulation()
    local saved = ns.db and ns.db.padEmulation
    if not saved then return end
    for cvar, value in pairs(saved) do
        -- (remis seulement s'il est toujours coupé : un autre addon a pu le
        -- changer entre-temps)
        if GetCVarValue(cvar) == "none" then SetCVarValue(cvar, value) end
        saved[cvar] = nil
    end
end

---------------------------------------------------------------------------
-- Les raccourcis
---------------------------------------------------------------------------
local owner = CreateFrame("Frame")
local buttons = {}
P.current = nil              -- le contexte dont les boutons sont posés
local pending = false        -- à refaire dès la fin du combat
local force = false          -- à reposer même sans changement (l'interface manette a refait les siens)
local repeatKey, repeatWait, repeatFor = nil, 0, 0

local function StopRepeat()
    repeatKey = nil
end

-- (un contexte « read » : l'état de ses boutons au passage précédent ; nil
-- tant qu'il n'a pas été lu une première fois, pour qu'un bouton déjà tenu
-- en entrant ne compte pas comme un appui)
local readPrev

local function IsRead(name)
    local c = name and contexts[name]
    return c and c.mode == "read" or false
end
P.IsRead = IsRead

local function Bind(name)
    if InCombatLockdown() then
        pending = true
        return
    end
    pending, force = false, false
    StopRepeat()
    readPrev = nil
    ClearOverrideBindings(owner)
    RestoreEmulation()
    local was = P.current
    P.current = name
    if name then
        local keys = KeysOf(name)
        -- (l'imitation Maj / Ctrl est un réglage du jeu, pas un raccourci :
        -- coupée aussi pour les boutons lus)
        CutEmulation(keys)
        if not IsRead(name) then
            for _, key in ipairs(keys) do
                local b = buttons[key]
                if b then SetOverrideBindingClick(owner, true, key, b:GetName(), "LeftButton") end
            end
        end
    end
    if was ~= name then ns.Fire("CONTEXT", name, was) end
end

-- Pourquoi l'addon ne prend rien (pour /mmir etat) : la première condition
-- qui manque, sinon nil
function P.WhyNone()
    if not ns.db then return "WHY_NONE_DB" end
    if not ns.db.options.enabled then return "WHY_NONE_OFF" end
    if not ns.Ready() then return "WHY_NONE_OPENMAP" end
    if not ns.ViewReady() then return "WHY_NONE_VIEW" end
    if not ns.MapShown() then return "WHY_NONE_MAP" end
    if not ns.ViewOn() then return "WHY_NONE_VIEW_OFF" end
    if InCombatLockdown() then return "WHY_NONE_COMBAT" end
    for _, c in ipairs(sorted) do
        local ok, on = pcall(c.detect)
        if ok and on then return nil end
    end
    return "WHY_NONE_FOCUS"
end

-- Le contexte qui s'applique maintenant (nil : l'addon ne prend rien)
local function Resolve()
    if P.suspended then return nil end   -- (/mmir test en cours)
    if not (ns.db and ns.db.options.enabled and ns.Ready() and ns.ViewReady()) then return nil end
    if not (ns.MapShown() and ns.ViewOn()) then return nil end
    if InCombatLockdown() then return nil end
    for _, c in ipairs(sorted) do
        local ok, on = pcall(c.detect)
        if ok and on then return c.name end
    end
    return nil
end

-- À revoir au prochain passage (une fenêtre vient de s'ouvrir...)
local dirty = true
function P.Dirty() dirty = true end

-- Nos raccourcis sont-ils toujours ceux qui comptent ? L'interface manette
-- de Forever lie elle aussi tous les boutons sur la carte (vers ses
-- InputFunctionBindingButton_<bouton>, /mmir sonde) et les refait quand son
-- focus change : un de nos boutons passé chez elle, tous sont reposés.
-- (Garde-fou : si elle les reprend sans cesse, on arrête de se battre pour
-- cette ouverture de la carte, et /mmir etat le dit.)
local function Expected(key)
    local b = buttons[key]
    return b and ("CLICK " .. b:GetName() .. ":LeftButton")
end

-- Les boutons du contexte en cours qui ne sont plus à nous
function P.Lost()
    local out = {}
    if not P.current or IsRead(P.current) then return out end
    for _, key in ipairs(KeysOf(P.current)) do
        local ok, action = pcall(GetBindingAction, key, true)
        if ok and action ~= Expected(key) then out[#out + 1] = key end
    end
    return out
end

local retakes, retakeSince = 0, 0
local RETAKE_MAX, RETAKE_WINDOW = 10, 3
P.gaveUp = false

local function Watch()
    if not P.current or P.gaveUp or InCombatLockdown() then return end
    if #P.Lost() == 0 then return end
    local now = GetTime()
    if now - retakeSince > RETAKE_WINDOW then retakes, retakeSince = 0, now end
    retakes = retakes + 1
    if retakes > RETAKE_MAX then
        P.gaveUp = true
        return
    end
    force = true
end

-- Les boutons de l'addon enfoncés : key -> GetTime() de l'appui. Les
-- raccourcis ne changent pas tant qu'un d'eux est tenu, sinon son
-- relâchement irait à la carte du jeu (A qui ferme une fenêtre puis zoome)
local held = {}

local function Holding()
    local now = GetTime()
    for key, t in pairs(held) do
        if now - t > 1.5 or P.IsPadDown(key) == false then
            held[key] = nil
        else
            return true
        end
    end
    return false
end

function P.Refresh(now)
    local want = Resolve()
    if want ~= P.current or force or pending then
        if want and P.current and Holding() then
            dirty = true
            return
        end
        Bind(want)
    end
    if now then dirty = false end
end

-- L'addon a la manette (lu par My Gamepad Is Rich, qui s'efface alors)
function P.Active() return P.current ~= nil end
function ns.Active() return P.current ~= nil end

-- Rendre les boutons tout de suite (la sonde : lire ceux du jeu) ; ils sont
-- reposés au passage suivant
function P.Release()
    Bind(nil)
    dirty = true
end

local function Dispatch(key, down)
    if not down then
        held[key] = nil
        if key == repeatKey then StopRepeat() end
        return
    end
    held[key] = GetTime()
    local name = P.current
    local a = name and ActionOf(name, key)
    if not a then return end
    local ok, err = pcall(a.fn)
    if not ok and geterrorhandler then geterrorhandler()(err) end
    dirty = true
    if REPEAT[key] then
        repeatKey, repeatWait, repeatFor = key, REPEAT_DELAY, 0
    end
end

for _, key in ipairs(KEYS) do
    local b = CreateFrame("Button", "MyMapIsRichPlusPad" .. key, UIParent)
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetScript("OnClick", function(_, _, down) Dispatch(key, down) end)
    buttons[key] = b
end

---------------------------------------------------------------------------
-- Le moteur : actif carte ouverte
---------------------------------------------------------------------------
-- Un contexte « read » : ses boutons lus sur la manette à chaque image ; un
-- bouton qui vient d'être enfoncé fait son action. Le jeu reçoit aussi
-- l'appui (rien n'est pris) : seuls des boutons dont l'interface manette ne
-- se sert pas sur la carte sont donnés à ces contextes.
local function Read()
    local name = P.current
    local buttonsNow = PadButtons()
    if not buttonsNow then return end
    local first = readPrev == nil
    readPrev = readPrev or {}
    for _, key in ipairs(KeysOf(name)) do
        local down = DownIn(buttonsNow, key)
        if down ~= nil then
            if down and not readPrev[key] and not first then
                local a = ActionOf(name, key)
                if a then
                    local ok, err = pcall(a.fn)
                    if not ok and geterrorhandler then geterrorhandler()(err) end
                    dirty = true
                end
            end
            readPrev[key] = down
        end
    end
end

local driver = CreateFrame("Frame")
driver:Hide()
local wait = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    if P.current and IsRead(P.current) then Read() end
    -- (la croix tenue : l'action se répète tant que le bouton est enfoncé)
    if repeatKey then
        repeatFor = repeatFor + elapsed
        local down = P.IsPadDown(repeatKey)
        if down == false or repeatFor > REPEAT_MAX then
            StopRepeat()
        else
            repeatWait = repeatWait - elapsed
            if repeatWait <= 0 then
                repeatWait = REPEAT_EVERY
                local a = P.current and ActionOf(P.current, repeatKey)
                if a then pcall(a.fn) else StopRepeat() end
            end
        end
    end
    wait = wait - elapsed
    if wait > 0 and not dirty then return end
    wait, dirty = EVERY, false
    Watch()
    P.Refresh()
end)

local function OnMapShow()
    dirty = true
    P.gaveUp, retakes = false, 0
    driver:Show()
    ns.Fire("MAP_SHOW")
end

local function OnMapHide()
    driver:Hide()
    Bind(nil)
    ns.Fire("MAP_HIDE")
end

local function Setup()
    local map = _G.WorldMapFrame
    if not map or P.hooked then return end
    P.hooked = true
    map:HookScript("OnShow", OnMapShow)
    map:HookScript("OnHide", OnMapHide)
    -- (après l'interface manette, chaque fois qu'elle refait les raccourcis
    -- de la carte : les nôtres reposés au passage suivant)
    local footer = map.worldMapFooter
    if type(footer) == "table" then
        for _, fname in ipairs({ "ShowAndActivateBindings", "HideAndDeactivateBindings", "Refresh" }) do
            if type(footer[fname]) == "function" then
                hooksecurefunc(footer, fname, function()
                    if P.current then force = true end
                    dirty = true
                end)
            end
        end
    end
    if map:IsShown() then OnMapShow() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_LOGOUT" then
        RestoreEmulation()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- (le combat commence : les boutons rendus au jeu tant qu'on le peut
        -- encore, juste avant le verrouillage)
        Bind(nil)
    else
        dirty = true
    end
end)

ns.On("READY", function()
    if _G.WorldMapFrame then
        Setup()
    elseif EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Setup)
    end
end)

ns.On("OPTIONS", function() dirty = true end)
