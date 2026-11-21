-- Le clavier virtuel : écrire à la manette dans un champ d'OpenMap (la
-- recherche d'un lieu, la note d'une épingle, un code d'épingles...) ou de
-- l'addon. Il s'ouvre quand on appuie sur A sur un champ de texte.
--   croix         : choisir une touche          A : la taper
--   X             : effacer                      Y : espace
--   LB / RB       : déplacer le curseur du texte LT : majuscules
--   RT / Menu     : valider (comme Entrée)       B : annuler (le texte d'avant)
-- Le champ ne prend jamais le focus du clavier (il le garderait pour tous les
-- boutons) : le texte y est écrit directement (SetText), et le champ reçoit
-- son OnTextChanged comme si on tapait (la recherche d'OpenMap montre ses
-- résultats). Valider appelle son OnEnterPressed (aller au premier lieu
-- trouvé, enregistrer la note).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI
local P = ns.Pad
local F = ns.Focus

local K = {}
ns.Keyboard = K

local LAYOUTS = {
    azerty = {
        { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
        { "a", "z", "e", "r", "t", "y", "u", "i", "o", "p" },
        { "q", "s", "d", "f", "g", "h", "j", "k", "l", "m" },
        { "w", "x", "c", "v", "b", "n", "'", "-", ".", "," },
        { "é", "è", "ê", "à", "ç", "ù", "ô", "î", "û", "ë" },
    },
    qwerty = {
        { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
        { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
        { "a", "s", "d", "f", "g", "h", "j", "k", "l", "'" },
        { "z", "x", "c", "v", "b", "n", "m", "-", ".", "," },
        { "é", "è", "à", "ç", "ñ", "ü", "ö", "ä", "ß", "ê" },
    },
}

-- (les majuscules : string.upper ne connaît pas les accents)
local UPPER = {
    ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["à"] = "À", ["ç"] = "Ç", ["ù"] = "Ù",
    ["ô"] = "Ô", ["î"] = "Î", ["û"] = "Û", ["ë"] = "Ë", ["ñ"] = "Ñ", ["ü"] = "Ü",
    ["ö"] = "Ö", ["ä"] = "Ä",
}

local KEY_W, KEY_H, GAP = 40, 32, 4
local COLS = 10

local frame, preview, keys, specials
local target, original, caret, upper = nil, nil, 0, false
local layoutBuilt

local function LayoutName()
    local choice = ns.db and ns.db.options.keyboard or "auto"
    if choice == "azerty" or choice == "qwerty" then return choice end
    return (GetLocale and GetLocale() == "frFR") and "azerty" or "qwerty"
end

local function Upper(ch)
    return UPPER[ch] or ch:upper()
end

local function Text()
    return target and target:GetText() or ""
end

-- (le texte du champ, le curseur gardé par nous : sans le focus, le champ ne
-- garde pas le sien)
local function SetText(text, at)
    if not target then return end
    target:SetText(text)
    caret = math.max(0, math.min(#text, at))
    if target.SetCursorPosition then pcall(target.SetCursorPosition, target, caret) end
    K.Refresh()
end

-- Le début du caractère UTF-8 avant la position `at` (octets)
local function PrevChar(text, at)
    local i = at
    while i > 0 do
        local b = text:byte(i)
        if not b or b < 0x80 or b >= 0xC0 then return i - 1 end
        i = i - 1
    end
    return 0
end

local function NextChar(text, at)
    local i = at + 1
    local b = text:byte(i)
    if not b then return at end
    local len = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
    return math.min(#text, at + len)
end

local function Letters(text)
    local n = 0
    for _ in text:gmatch("[^\128-\191]") do n = n + 1 end
    return n
end

function K.Type(ch)
    if not target then return end
    local text = Text()
    local max = target.GetMaxLetters and target:GetMaxLetters() or 0
    if max and max > 0 and Letters(text) >= max then return end
    if upper then ch = Upper(ch) end
    SetText(text:sub(1, caret) .. ch .. text:sub(caret + 1), caret + #ch)
end

function K.Backspace()
    local text = Text()
    if caret <= 0 then return end
    local from = PrevChar(text, caret)
    SetText(text:sub(1, from) .. text:sub(caret + 1), from)
end

function K.MoveCaret(dir)
    local text = Text()
    if dir < 0 then caret = PrevChar(text, caret) else caret = NextChar(text, caret) end
    if target and target.SetCursorPosition then pcall(target.SetCursorPosition, target, caret) end
    K.Refresh()
end

function K.ToggleUpper()
    upper = not upper
    K.Refresh()
end

function K.Close()
    target, original = nil, nil
    if frame then frame:Hide() end
    P.Dirty()
end

function K.Validate()
    local box = target
    K.Close()
    if not box then return end
    local fn = box:GetScript("OnEnterPressed")
    if fn then
        local ok, err = pcall(fn, box)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end

function K.Cancel()
    if target and original then
        target:SetText(original)
    end
    K.Close()
end

---------------------------------------------------------------------------
-- La fenêtre
---------------------------------------------------------------------------
function K.Refresh()
    if not frame then return end
    local text = Text()
    local before, after = text:sub(1, caret), text:sub(caret + 1)
    local function Esc(s) return (s:gsub("|", "||")) end
    preview:SetText(Esc(before) .. "|cffffd100|||r" .. Esc(after))
    for _, b in ipairs(keys) do
        local ch = b.char
        b:SetText(upper and Upper(ch) or ch)
    end
    if specials.shift then specials.shift:SetText(upper and L.KB_SHIFT_ON or L.KB_SHIFT) end
end

local function Special(parent, label, glyphKey, w, onClick)
    local b = UI.Button(parent, label, w, KEY_H, "grey")
    b:SetScript("OnClick", onClick)
    if glyphKey and UI.CreateGlyph then
        local g = UI.CreateGlyph(b, 16)
        g:SetPoint("LEFT", 4, 0)
        g:SetKey(glyphKey)
        b:GetFontString():SetPoint("LEFT", 22, 0)
    end
    return b
end

local function BuildKeys()
    local name = LayoutName()
    if layoutBuilt == name then return end
    layoutBuilt = name
    for _, b in ipairs(keys) do b:Hide() end
    wipe(keys)
    local rows = LAYOUTS[name]
    local top = -46
    for r, row in ipairs(rows) do
        for c, ch in ipairs(row) do
            local b = UI.Button(frame.content, ch, KEY_W, KEY_H, r == 5 and "grey" or "red")
            b:SetPoint("TOPLEFT", (c - 1) * (KEY_W + GAP), top - (r - 1) * (KEY_H + GAP))
            b.char = ch
            b:SetScript("OnClick", function(self) K.Type(self.char) end)
            keys[#keys + 1] = b
        end
    end
end

local function Build()
    if frame then return end
    local w = COLS * KEY_W + (COLS - 1) * GAP + 12
    local h = 32 + 4 + 40 + 6 * (KEY_H + GAP) + 10
    frame = UI.MapWindow("MyMapIsRichPlusKeyboard", w, h, L.KB_TITLE, nil, 9000)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", 0, -60)
    frame.close:SetScript("OnClick", K.Cancel)
    -- (le texte en cours, et le curseur du texte en doré)
    local well = UI.Well(frame.content)
    well:SetPoint("TOPLEFT", 0, 0)
    well:SetPoint("TOPRIGHT", 0, 0)
    well:SetHeight(36)
    preview = UI.Text(well, "GameFontHighlightLarge")
    preview:SetPoint("LEFT", 10, 0)
    preview:SetPoint("RIGHT", -10, 0)
    preview:SetJustifyH("LEFT")
    preview:SetWordWrap(false)
    keys, specials = {}, {}
    BuildKeys()
    -- (la dernière rangée : les touches qui ont aussi leur bouton)
    local y = -46 - 5 * (KEY_H + GAP)
    local x = 0
    local function Add(key, label, glyphKey, width, fn)
        local b = Special(frame.content, label, glyphKey, width, fn)
        b:SetPoint("TOPLEFT", x, y)
        x = x + width + GAP
        specials[key] = b
    end
    Add("shift", L.KB_SHIFT, "PADLTRIGGER", 84, K.ToggleUpper)
    Add("left", "", "PADLSHOULDER", 40, function() K.MoveCaret(-1) end)
    Add("right", "", "PADRSHOULDER", 40, function() K.MoveCaret(1) end)
    Add("space", L.KB_SPACE, "PAD4", 92, function() K.Type(" ") end)
    Add("back", L.KB_BACKSPACE, "PAD3", 84, K.Backspace)
    Add("ok", L.KB_OK, "PADRTRIGGER", COLS * (KEY_W + GAP) - GAP - x, K.Validate)
    -- (la croix commence sur la première lettre)
    F.RegisterWindow(frame, { onBack = K.Cancel, first = function() return keys[COLS + 1] end })
end

-- Ouvrir le clavier sur un champ de texte ; `place(frame)` le pose ailleurs
-- qu'en haut de l'écran (un champ peut aussi le dire : box.keyboardPlace),
-- la recherche du navigateur de lieux par exemple, pour que ses résultats
-- restent visibles à côté
function K.Open(box, place)
    if not (box and box.GetText) then return end
    Build()
    BuildKeys()
    place = place or box.keyboardPlace
    frame:ClearAllPoints()
    if place then place(frame) else frame:SetPoint("TOP", UIParent, "TOP", 0, -60) end
    target, original = box, box:GetText() or ""
    caret = #original
    upper = false
    frame:Show()
    K.Refresh()
    P.Dirty()
end

function K.Shown() return frame and frame:IsShown() or false end

-- (la carte se ferme, le combat commence : le clavier aussi)
ns.On("MAP_HIDE", function() if K.Shown() then K.Cancel() end end)

---------------------------------------------------------------------------
-- Le contexte « keyboard » : celui des fenêtres (la croix, A), plus ses
-- boutons à lui
---------------------------------------------------------------------------
P.DefineContext("keyboard", 100, K.Shown, "window")
P.SetAction("keyboard", "PAD2", K.Cancel, "HINT_CANCEL")
P.SetAction("keyboard", "PAD3", K.Backspace, "KB_BACKSPACE")
P.SetAction("keyboard", "PAD4", function() K.Type(" ") end, "KB_SPACE")
P.SetAction("keyboard", "PADLSHOULDER", function() K.MoveCaret(-1) end)
P.SetAction("keyboard", "PADRSHOULDER", function() K.MoveCaret(1) end, "HINT_CARET")
P.SetAction("keyboard", "PADLTRIGGER", K.ToggleUpper, "KB_SHIFT")
P.SetAction("keyboard", "PADRTRIGGER", K.Validate, "KB_OK")
P.SetAction("keyboard", "PADFORWARD", K.Validate)
P.SetAction("keyboard", "PAD1", function() F.Activate("LeftButton") end, "HINT_TYPE")
