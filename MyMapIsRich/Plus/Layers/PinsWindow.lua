-- Les fenêtres des épingles (Layers/MyPins.lua), à la charte (CHARTE.md),
-- depuis la 0.7.0 (elles étaient celles d'OpenMap, Map/Pins.lua) :
--   la fiche d'une épingle : sa note, sa couleur, la suivre, dessiner dessus
--     avec la plume, la partager (groupe, guilde, cible, code), la retirer ;
--   la liste : toutes les épingles (clic : la carte y glisse ; clic droit : sa
--     fiche ; Maj+clic : dans la discussion ; Alt+clic : la retirer), importer
--     un code, tout partager, tout retirer ;
--   le code : à copier, ou à coller pour ajouter les épingles qu'il porte ;
--   la question : ajouter les épingles qu'un joueur partage, tout retirer.
-- Toutes se posent par-dessus la carte (UI.MapWindow) et se jouent à la
-- manette : la croix, A, X (clic droit), B (fermer), LB / RB (pages de la liste).
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI
local F = ns.Focus

local PW = {}
ns.PinsWindow = PW

local E = ns.Map.MyPins
local ROWS = 12
local ROW_H = 22
local editor, list, codeBox, ask

-- Le cadre sur lequel les fenêtres se posent : la vue de la carte, sinon l'écran
local function Host()
    return ns.MapShown() and ns.Map.View.Frame() or UIParent
end

local function Grey(parent, text, w, onClick, tip)
    local b = UI.Button(parent, text, w, 24, "grey")
    b:SetScript("OnClick", onClick)
    if tip then UI.Tip(b, text, tip) end
    return b
end

-- Un champ de saisie de la charte (A à la manette : le clavier virtuel, Pad/Focus.lua)
local function Input(parent, w, maxLetters)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(w, 24)
    box:SetFontObject("GameFontHighlight")
    box:SetAutoFocus(false)
    box:SetMaxLetters(maxLetters or 0)
    box:SetTextInsets(6, 6, 0, 0)
    UI.SkinInput(box)
    return box
end

---------------------------------------------------------------------------
-- La question (oui / non)
---------------------------------------------------------------------------
local function BuildAsk()
    if ask then return ask end
    ask = UI.MapWindow("MyMapIsRichPinsAsk", 440, 200, L.PINS_ASK_TITLE, nil, 8700)
    local c = ask.content
    ask.text = UI.Text(c, "GameFontHighlight")
    ask.text:SetPoint("TOPLEFT", 10, -8)
    ask.text:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    ask.text:SetJustifyH("LEFT")
    ask.text:SetJustifyV("TOP")
    ask.text:SetSpacing(3)
    local w = 196
    ask.yes = UI.Button(c, "", w, 28, "red")
    ask.yes:SetPoint("BOTTOMLEFT", 6, 6)
    ask.no = UI.Button(c, "", w, 28, "grey")
    ask.no:SetPoint("BOTTOMRIGHT", -6, 6)
    local function Answer(yes)
        local fn = yes and ask.onYes or ask.onNo
        ask.onYes, ask.onNo = nil, nil
        ask:Hide()
        if fn then pcall(fn) end
    end
    ask.yes:SetScript("OnClick", function() Answer(true) end)
    ask.no:SetScript("OnClick", function() Answer(false) end)
    ask.close:SetScript("OnClick", function() Answer(false) end)
    F.RegisterWindow(ask, { onBack = function() Answer(false) end, first = function() return ask.yes end })
    return ask
end

-- text : la question ; yes / no : les libellés ; onYes / onNo : ce qu'ils font
function PW.Ask(text, yes, no, onYes, onNo)
    BuildAsk()
    if ask:IsShown() and ask.onNo then pcall(ask.onNo) end   -- (une à la fois : celle d'avant vaut « non »)
    ask.text:SetText(text)
    ask.yes:SetText(yes)
    ask.no:SetText(no)
    ask.onYes, ask.onNo = onYes, onNo
    ask:ClearAllPoints()
    ask:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    ask:Show()
    ask:Raise()
end

-- Les épingles qu'un joueur partage : les ajouter ?
function PW.AskShared(batch)
    local lines = {}
    for i = 1, math.min(3, #batch.pins) do
        local q = batch.pins[i]
        lines[i] = E.ZoneName(q.map) .. (q.note ~= "" and (" — " .. q.note) or "")
    end
    if #batch.pins > 3 then lines[#lines + 1] = L.PINS_ASK_MORE:format(#batch.pins - 3) end
    PW.Ask(L.PINS_ASK:format(batch.from, #batch.pins) .. "\n|cffffffff" .. table.concat(lines, "\n") .. "|r",
        L.PINS_ADD, L.PINS_IGNORE,
        function()
            E.SetAsking(false)
            ns.Print(L.PINS_ADDED, E.AddAll(batch.pins, batch.from), batch.from)
        end,
        function() E.SetAsking(false) end)
end

---------------------------------------------------------------------------
-- Le code : à copier, ou à coller
---------------------------------------------------------------------------
local function BuildCode()
    if codeBox then return codeBox end
    codeBox = UI.MapWindow("MyMapIsRichPinsCode", 560, 236, L.PINS_CODE, nil, 8600)
    local c = codeBox.content
    codeBox.info = UI.DimText(c, "")
    codeBox.info:SetPoint("TOPLEFT", 10, -6)
    codeBox.info:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    codeBox.info:SetJustifyH("LEFT")
    local inset = UI.Inset(c)
    inset:SetPoint("TOPLEFT", 4, -40)
    inset:SetPoint("BOTTOMRIGHT", -4, 42)
    local box = CreateFrame("EditBox", nil, inset)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetWidth(500)
    box:SetHeight(100)
    box:SetScript("OnEscapePressed", function() codeBox:Hide() end)
    box:SetScript("OnTextChanged", function(self, user)
        -- (un code à copier reste tel quel)
        if user and codeBox.text then
            self:SetText(codeBox.text)
            self:HighlightText()
        end
    end)
    local scroll = UI.Scroll(inset, box, 30)
    scroll:SetPoint("TOPLEFT", 10, -8)
    scroll:SetPoint("BOTTOMRIGHT", -22, 8)
    codeBox.box = box
    codeBox.add = UI.Button(c, L.PINS_CODE_ADD, 200, 28, "red")
    codeBox.add:SetPoint("BOTTOMRIGHT", -6, 6)
    codeBox.add:SetScript("OnClick", function()
        local pins = E.FromCode(box:GetText())
        if not pins or #pins == 0 then
            ns.Print(L.PINS_CODE_BAD, E.CODE)
            return
        end
        ns.Print(L.PINS_CODE_ADDED, E.AddAll(pins))
        codeBox:Hide()
    end)
    F.RegisterWindow(codeBox, { onBack = function() codeBox:Hide() end, first = function() return box end })
    return codeBox
end

-- text : un code à copier ; rien : une place pour en coller un
function PW.Code(text)
    BuildCode()
    codeBox.text = text
    codeBox.info:SetText(text and L.PINS_CODE_COPY or L.PINS_CODE_PASTE)
    codeBox.box:SetText(text or "")
    codeBox.add:SetShown(not text)
    codeBox:ClearAllPoints()
    codeBox:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    codeBox:Show()
    codeBox:Raise()
    codeBox.box:SetFocus()
    if text then codeBox.box:HighlightText() end
end

---------------------------------------------------------------------------
-- La fiche d'une épingle
---------------------------------------------------------------------------
local function ShowColors()
    for i, b in ipairs(editor.colors) do
        local on = i == editor.color
        b.ring:SetShown(on)
        b.icon:SetAlpha(on and 1 or 0.7)
    end
end

-- La ligne du dessin : en train de dessiner ou non, et combien est dessiné
local function ShowDrawing()
    if not (editor and editor.pin) then return end
    local now = ns.Map.Sketch.Pin() == editor.pin
    local n = ns.Map.Sketch.Count(editor.pin.id)
    editor.draw:SetText(now and L.PINS_DRAW_STOP or (n > 0 and L.PINS_DRAW_MORE or L.PINS_DRAW))
    editor.drawn:SetText(now and L.PINS_DRAWN_NOW or (n > 0 and L.PINS_DRAWN:format(n) or L.PINS_DRAWN_NONE))
end
PW.DrawingChanged = ShowDrawing

local function ShowFollow()
    if editor and editor.pin then
        editor.follow:SetText(E.Followed(editor.pin) and L.PINS_UNFOLLOW or L.PINS_FOLLOW)
    end
end

-- La fiche fermée : save, sa note et sa couleur gardées (Entrée, Fini, la croix, B)
local function Close(save)
    local p = editor and editor.pin
    if not p then
        if editor then editor:Hide() end
        return
    end
    editor.pin = nil
    -- (son dessin finit avec elle)
    if ns.Map.Sketch.Pin() == p then ns.Map.Sketch.Toggle(false) end
    editor:Hide()
    E.Done(p, save, editor.box:GetText(), editor.color)
end
PW.CloseEditor = Close

-- Le bouton Fini de la plume, en dessinant sur une épingle : l'épingle aussi
function PW.FinishDrawing()
    if editor and editor.pin then Close(true) else ns.Map.Sketch.Toggle(false) end
end

local function BuildEditor()
    if editor then return editor end
    editor = UI.MapWindow("MyMapIsRichPinEditor", 470, 270, L.PINS_PIN, nil, 8400)
    local c = editor.content
    editor.close:SetScript("OnClick", function() Close(true) end)
    -- (la note)
    local noteLabel = UI.Text(c, "GameFontNormal", L.PINS_NOTE)
    noteLabel:SetPoint("TOPLEFT", 10, -8)
    editor.place = UI.DimText(c, "")
    editor.place:SetPoint("LEFT", noteLabel, "RIGHT", 10, 0)
    editor.place:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    editor.place:SetJustifyH("RIGHT")
    editor.place:SetWordWrap(false)
    editor.box = Input(c, 438, E.NOTE_MAX)
    editor.box:SetPoint("TOPLEFT", 10, -28)
    editor.box:SetScript("OnEnterPressed", function() Close(true) end)
    editor.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- (la couleur : l'épingle elle-même dans chacune)
    local colorLabel = UI.Text(c, "GameFontNormal", L.PINS_COLOR)
    colorLabel:SetPoint("TOPLEFT", 10, -68)
    editor.colors = {}
    for i, col in ipairs(E.COLORS) do
        local b = CreateFrame("Button", nil, c)
        b:SetSize(28, 28)
        b:SetPoint("TOPLEFT", 120 + (i - 1) * 36, -60)
        b.ring = b:CreateTexture(nil, "BACKGROUND")
        b.ring:SetPoint("TOPLEFT", -3, 3)
        b.ring:SetPoint("BOTTOMRIGHT", 3, -3)
        b.ring:SetColorTexture(1, 0.82, 0, 0.55)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        UI.SetIcon(b.icon, E.MARK.texture, E.MARK.atlas)
        if col[2] then b.icon:SetVertexColor(col[2], col[3], col[4]) end
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.82, 0, 0.15)
        b:SetScript("OnClick", function()
            editor.color = i
            ShowColors()
            if editor.pin then
                editor.pin.color = i       -- (vue tout de suite sur la carte)
                E.Refresh()
            end
        end)
        UI.Tip(b, L[col[1]])
        editor.colors[i] = b
    end
    -- (la suivre)
    editor.follow = Grey(c, L.PINS_FOLLOW, 150, function()
        local p = editor.pin
        if not p then return end
        if E.Followed(p) then
            E.Unfollow()
        else
            p.note = E.Clean(editor.box:GetText())
            E.Follow(p)
        end
        E.Refresh()
        ShowFollow()
    end, L.PINS_FOLLOW_TIP)
    editor.follow:SetPoint("TOPRIGHT", -10, -62)
    -- (dessiner dessus avec la plume : sa barre s'ouvre sous cette fiche)
    local drawLabel = UI.Text(c, "GameFontNormal", L.PINS_DRAWING)
    drawLabel:SetPoint("TOPLEFT", 10, -108)
    editor.draw = Grey(c, L.PINS_DRAW, 170, function()
        local p = editor.pin
        if not p then return end
        if ns.Map.Sketch.Pin() == p then
            ns.Map.Sketch.Toggle(false)
        else
            p.note = E.Clean(editor.box:GetText())
            p.color = editor.color
            editor.box:ClearFocus()
            ns.Map.Sketch.ForPin(p, editor)
        end
        ShowDrawing()
    end, L.PINS_DRAW_TIP)
    editor.draw:SetPoint("TOPLEFT", 120, -102)
    editor.drawn = UI.DimText(c, "")
    editor.drawn:SetPoint("LEFT", editor.draw, "RIGHT", 10, 0)
    editor.drawn:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    editor.drawn:SetJustifyH("LEFT")
    editor.drawn:SetWordWrap(false)
    -- (la partager : ton groupe, ta guilde, ta cible, un code)
    local shareLabel = UI.Text(c, "GameFontNormal", L.PINS_SHARE)
    shareLabel:SetPoint("TOPLEFT", 10, -148)
    local x = 120
    editor.share = {}
    for _, s in ipairs({
        { "group", L.PINS_TO_GROUP, L.PINS_TO_GROUP_TIP },
        { "guild", L.PINS_TO_GUILD, L.PINS_TO_GUILD_TIP },
        { "target", L.PINS_TO_TARGET, L.PINS_TO_TARGET_TIP },
    }) do
        local b = Grey(c, s[2], 76, function()
            local p = editor.pin
            if not p then return end
            p.note = E.Clean(editor.box:GetText())
            E.Share({ p }, s[1])
        end, s[3])
        b:SetPoint("TOPLEFT", x, -142)
        editor.share[s[1]] = b
        x = x + 80
    end
    local code = Grey(c, L.PINS_CODE, 76, function()
        local p = editor.pin
        if not p then return end
        p.note = E.Clean(editor.box:GetText())
        PW.Code(E.CodeOf({ p }))
    end, L.PINS_CODE_TIP)
    code:SetPoint("TOPLEFT", x, -142)
    -- (en bas : la retirer ; fini)
    local delete = Grey(c, L.PINS_DELETE, 140, function()
        local p = editor.pin
        editor.pin = nil
        editor:Hide()
        if p then
            E.Remove(p)
            E.Refresh()
        end
    end)
    delete:SetPoint("BOTTOMLEFT", 6, 6)
    local done = UI.Button(c, L.PINS_DONE, 160, 28, "red")
    done:SetPoint("BOTTOMRIGHT", -6, 6)
    done:SetScript("OnClick", function() Close(true) end)
    UI.Tip(done, L.PINS_DONE, L.PINS_DONE_TIP)
    editor:SetScript("OnHide", function() if editor.pin then Close(true) end end)
    F.RegisterWindow(editor, { onBack = function() Close(true) end, first = function() return editor.box end })
    return editor
end

function PW.Edit(p)
    if not p then return end
    BuildEditor()
    if editor.pin and editor.pin ~= p then Close(true) end   -- (une à la fois : l'ouverte est gardée)
    editor.pin = p
    editor.color = p.color or 1
    editor.title:SetText(p.from and (L.PINS_PIN .. "  |cff99ccff" .. L.PINS_SHARED_BY:format(p.from) .. "|r") or L.PINS_PIN)
    editor.place:SetText(E.Place(p))
    editor.box:SetText(p.note or "")
    for to, b in pairs(editor.share) do b:SetEnabled(E.Channel(to) ~= nil) end
    ShowColors()
    ShowFollow()
    ShowDrawing()
    editor:ClearAllPoints()
    editor:SetPoint("TOP", Host(), "TOP", 0, -70)
    editor:Show()
    editor:Raise()
    -- (à la souris, la note prend la main ; à la manette, A sur elle ouvre le clavier)
    if not ns.PadUI() then
        editor.box:SetFocus()
        editor.box:HighlightText()
    end
end

---------------------------------------------------------------------------
-- La liste
---------------------------------------------------------------------------
local function RefreshList()
    if not (list and list:IsShown()) then return end
    local pins = E.List()
    list.title:SetText(L.PINS_LIST_TITLE:format(#pins))
    list.empty:SetShown(#pins == 0)
    list.offset = math.max(0, math.min(list.offset or 0, #pins - ROWS))
    for i, row in ipairs(list.rows) do
        local p = pins[list.offset + i]
        row.pin = p
        if p then
            local c = E.COLORS[p.color] or E.COLORS[1]
            row.dot:SetColorTexture(c[2] or 1, c[3] or 0.82, c[4] or 0)
            local drawn = ns.Map.Sketch.Count(p.id) > 0
            row.text:SetText(E.ZoneName(p.map)
                .. (p.note ~= "" and (" · |cffffffff" .. p.note .. "|r") or "")
                .. (drawn and (" |cffe6c27a(" .. L.PINS_DRAWING_TAG .. ")|r") or "")
                .. (E.Followed(p) and (" |cff80f070(" .. L.PINS_FOLLOWED_TAG .. ")|r") or ""))
        end
        row:SetShown(p ~= nil)
    end
    list.page:SetText(#pins > ROWS and ("%d-%d / %d"):format(list.offset + 1, math.min(#pins, list.offset + ROWS), #pins) or "")
end

function PW.Refresh()
    RefreshList()
    if editor and editor:IsShown() and editor.pin then
        ShowFollow()
        ShowDrawing()
    end
end

local function RowEnter(self)
    local p = self.pin
    if not p then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(p.note ~= "" and p.note or L.PINS_PIN, 1, 0.82, 0, true)
    GameTooltip:AddLine(E.Place(p), 1, 1, 1)
    if p.from then GameTooltip:AddLine(L.PINS_SHARED_BY:format(p.from), 0.6, 0.8, 1) end
    GameTooltip:AddLine(L.PINS_ROW_CLICK, 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine(L.PINS_SHIFT_CHAT, 0.6, 0.6, 0.6)
    GameTooltip:AddLine(L.PINS_ALT_DELETE, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function Page(dir)
    list.offset = (list.offset or 0) + dir * ROWS
    RefreshList()
end

local function BuildList()
    if list then return list end
    list = UI.MapWindow("MyMapIsRichPins", 420, ROWS * ROW_H + 112, L.PINS_LIST_TITLE:format(0), nil, 8300)
    local c = list.content
    list.empty = UI.DimText(c, L.PINS_EMPTY)
    list.empty:SetPoint("TOPLEFT", 10, -10)
    list.empty:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    list.empty:SetJustifyH("LEFT")
    list.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, c)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", c, "RIGHT", -4, 0)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.82, 0, 0.09)
        row.dot = row:CreateTexture(nil, "ARTWORK")
        row.dot:SetSize(8, 8)
        row.dot:SetPoint("LEFT", 8, 0)
        row.text = UI.Text(row, "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 24, 0)
        row.text:SetPoint("RIGHT", -6, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row:SetScript("OnClick", function(self, button)
            local p = self.pin
            if not p then return end
            if IsAltKeyDown() then
                E.Remove(p)
                E.Refresh()
            elseif button == "RightButton" then
                PW.Edit(p)
            elseif IsModifiedClick and IsModifiedClick("CHATLINK") then
                E.ChatLink(p)
            else
                E.GoTo(p)
            end
        end)
        row:SetScript("OnEnter", RowEnter)
        row:SetScript("OnLeave", GameTooltip_Hide)
        list.rows[i] = row
    end
    list.page = UI.DimText(c, "")
    list.page:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -6 - ROWS * ROW_H)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        list.offset = (list.offset or 0) - delta * 3
        RefreshList()
    end)
    -- (en bas : importer un code ; tout partager, par un menu, pour que tout
    -- envoyer à la guilde ne soit jamais un clic de travers ; tout retirer)
    local import = Grey(c, L.PINS_IMPORT, 120, function() PW.Code(nil) end, L.PINS_IMPORT_TIP)
    import:SetPoint("BOTTOMLEFT", 6, 6)
    local shareAll
    shareAll = Grey(c, L.PINS_SHARE_ALL, 130, function()
        local x, y = shareAll:GetCenter()
        local es = shareAll:GetEffectiveScale()
        UI.ShowMenu({
            { L.PINS_ALL_CODE, function() PW.Code(E.CodeOf(E.List())) end },
            { L.PINS_ALL_GROUP, function() E.Share(E.List(), "group") end },
            { L.PINS_ALL_GUILD, function() E.Share(E.List(), "guild") end },
        }, x * es, y * es, L.PINS_SHARE_ALL)
    end, L.PINS_SHARE_ALL_TIP)
    shareAll:SetPoint("LEFT", import, "RIGHT", 6, 0)
    local clear = Grey(c, L.PINS_CLEAR, 130, function()
        local n = #E.List()
        if n == 0 then return end
        PW.Ask(L.PINS_CLEAR_ASK:format(n), L.PINS_DELETE, CANCEL or L.PINS_IGNORE, function() E.RemoveAll() end)
    end, L.PINS_CLEAR_TIP)
    clear:SetPoint("BOTTOMRIGHT", -6, 6)
    list:SetScript("OnShow", RefreshList)
    F.RegisterWindow(list, {
        onBack = function() list:Hide() end,
        onTab = Page,
        first = function() return list.rows[1]:IsShown() and list.rows[1] or import end,
    })
    return list
end

function PW.ListFrame() return list end

function PW.ToggleList(show)
    BuildList()
    if show == nil then show = not list:IsShown() end
    if not show then
        list:Hide()
        return
    end
    -- (la carte ouverte d'abord, hors combat : c'est le jeu qui l'ouvre)
    if not ns.MapShown() then
        if InCombatLockdown() or not ToggleWorldMap or not ns.Risky("OpenMap") then return end
        pcall(ToggleWorldMap)
        C_Timer.After(0.3, function() if ns.MapShown() then PW.ToggleList(true) end end)
        return
    end
    list:ClearAllPoints()
    list:SetPoint("TOP", Host(), "TOP", 0, -70)
    list:Show()
    list:Raise()
    RefreshList()
end

-- (la carte fermée : la fiche se ferme en gardant la note, la liste aussi)
ns.On("MAP_HIDE", function()
    if editor and editor:IsShown() then Close(true) end
    if list then list:Hide() end
end)
