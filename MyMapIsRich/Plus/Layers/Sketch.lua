-- La plume : dessiner sur la carte, pour soi. En code et aux couleurs de My
-- Map Is Rich depuis la 0.11.0 (elle venait de Map/Sketch.lua d'OpenMap).
--   le plateau   la plume, la ligne droite, la flèche, le cercle, les marques
--                de raid et la gomme ; six encres, trois épaisseurs ; Défaire,
--                Effacer, Terminé. Il s'ouvre par la roue, la fiche d'un
--                point, le raccourci du jeu ou /mmir carte draw ;
--   la souris    tirer à gauche trace, tirer à droite déplace la carte, la
--                molette zoome ; Ctrl+Z défait, Échap range la plume ;
--   la manette   A pose la plume puis la lève (un trait : A, bouger, A),
--                X la range, View passe dans le plateau (Pad/MapNav.lua) ;
--   une épingle  « Dessiner » sur sa fiche attache ce qu'on dessine à elle :
--                le dessin part avec elle, et se cache avec les épingles.
-- Sur la carte d'un donjon, la plume dessine sur son étage
-- (Layers/DungeonView.lua) ; ses traits sont gardés ici aussi (sketch.dungeons).
-- Un trait : { id, tool, ink, size, pts = { u, v, u, v, ... } (le monde, 0..1),
-- mark (le numéro d'une marque de raid), pin (l'id de l'épingle) }.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local SKM = {}
ns.Sketch = SKM
local SK = ns.Map.Sketch
local DG = ns.Map.Dungeons
local Settings = ns.Map.Settings

Settings.Own("sketchShown", true)       -- « Tes dessins » montrés (le rail des calques)

-- les encres : nettes sur le parchemin et sur le sol plus sombre de la minicarte
local INKS = {
    { "SKETCH_INK_BLACK", 0.1, 0.08, 0.06 },
    { "SKETCH_INK_RED", 0.92, 0.18, 0.14 },
    { "SKETCH_INK_BLUE", 0.22, 0.5, 1 },
    { "SKETCH_INK_GREEN", 0.24, 0.82, 0.32 },
    { "SKETCH_INK_GOLD", 1, 0.8, 0.16 },
    { "SKETCH_INK_WHITE", 1, 1, 1 },
}
local NIBS = { 2, 3.5, 6 }       -- px à l'écran
local NIB_NAMES = { "SKETCH_FINE", "SKETCH_MEDIUM", "SKETCH_BROAD" }

-- les outils, chaque bouton montrant ce qu'il trace (glyph : des traits dans
-- une boîte de 32 x 20, depuis son coin en haut à gauche)
local function Circle(cx, cy, r, n)
    local out = {}
    for k = 0, n do
        local a = k / n * 2 * math.pi
        out[#out + 1] = { cx + math.cos(a) * r, cy + math.sin(a) * r }
    end
    return out
end
local TOOLS = {
    { key = "quill", name = "SKETCH_PEN", tip = "SKETCH_PEN_TIP",
        glyph = { { { 3, 15 }, { 8, 7 }, { 13, 13 }, { 19, 5 }, { 24, 12 }, { 29, 6 } } } },
    { key = "line", name = "SKETCH_LINE", tip = "SKETCH_LINE_TIP", glyph = { { { 4, 17 }, { 28, 3 } } } },
    { key = "arrow", name = "SKETCH_ARROW", tip = "SKETCH_ARROW_TIP",
        glyph = { { { 4, 17 }, { 28, 3 } }, { { 19, 3 }, { 28, 3 }, { 24, 11 } } } },
    { key = "ring", name = "SKETCH_RING", tip = "SKETCH_RING_TIP", glyph = { Circle(16, 10, 8, 16) } },
    { key = "mark", name = "SKETCH_MARK", tip = "SKETCH_MARK_TIP" },
    { key = "erase", name = "SKETCH_ERASE", tip = "SKETCH_ERASE_TIP",
        glyph = { { { 6, 13 }, { 16, 3 }, { 27, 11 }, { 17, 21 }, { 6, 13 } }, { { 11, 8 }, { 22, 16 } } } },
}
local STEP = 3                   -- px que parcourt le curseur avant que la plume ajoute un point
local NEAR = 8                   -- px : un clic de gomme si près d'un dessin l'enlève
local MAX_POINTS = 600           -- dans un trait
local MAX_STROKES = 2000
local MARK = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
-- (le capteur de la souris : au-dessus de l'art de la carte, 9900 au plus, sous
-- son habillage, UI/MapChrome.lua : 9940, dont les boutons restent à portée)
local CATCHER_LEVEL = 9935

local set, liveSet               -- les dessins, et le trait en cours (redessiné seul pendant qu'il grandit)
local catcher, tray
local drawing = false
local forPin                     -- l'épingle à qui s'attache ce qu'on dessine (sa fiche : Layers/PinsWindow.lua)
local stroke                     -- le trait en cours : { record, x, y, lx, ly, pu }
local pan                        -- la carte tirée au clic droit : { x, y, u, v, zoom, pu, pv }
local waiting                    -- la plume demandée avant que la carte soit dessinée : { pin, dock }
local Redraw, RefreshTray

local function Round(x) return math.floor(x * 1e5 + 0.5) / 1e5 end

---------------------------------------------------------------------------
-- Les sauvegardes : MyMapIsRichPlusDB.map.sketch (le compte entier)
---------------------------------------------------------------------------
local function DB()
    local db = ns.Map.DB()
    if not db then return { strokes = {}, nextId = 1, tool = "quill", ink = 1, size = 2, mark = 8 } end
    local sk = db.sketch
    if type(sk) ~= "table" then
        sk = {}
        db.sketch = sk
    end
    sk.strokes = sk.strokes or {}
    sk.nextId = sk.nextId or 1
    sk.tool = sk.tool or "quill"
    sk.ink = sk.ink or 1
    sk.size = sk.size or 2
    sk.mark = sk.mark or 8
    return sk
end

local function Shown() return Settings.Get("sketchShown") ~= false end

-- Ce qui suit un changement : la fiche de l'épingle ouverte, le contexte de la manette
local function Changed()
    if ns.PinsWindow then ns.PinsWindow.DrawingChanged() end
    if ns.Pad and ns.Pad.Dirty then ns.Pad.Dirty() end
end

---------------------------------------------------------------------------
-- Les traits : chacun avec un halo pâle dessous, pour que l'encre se lise
-- sur une terre sombre comme claire
---------------------------------------------------------------------------
-- Les points d'un trait : ceux de la plume tels que tracés ; une ligne, une
-- flèche (sa pointe, une part de sa longueur) et un cercle (rond à l'écran :
-- les côtés du monde ne sont pas égaux) calculés depuis ses deux bouts
local function Points(st)
    local p = st.pts
    if st.tool == "quill" or #p < 4 then return p end
    local u0, v0, u1, v1 = p[1], p[2], p[#p - 1], p[#p]
    local W, H = ns.Map.Coords.Size()
    if not W then return p end
    if st.tool == "ring" then
        local r = math.sqrt(((u1 - u0) * W) ^ 2 + ((v1 - v0) * H) ^ 2)
        local out = {}
        for k = 0, 40 do
            local a = k / 40 * 2 * math.pi
            out[#out + 1], out[#out + 2] = u0 + math.cos(a) * r / W, v0 + math.sin(a) * r / H
        end
        return out
    end
    if st.tool == "arrow" then
        local dx, dy = (u1 - u0) * W, (v1 - v0) * H
        local len = math.sqrt(dx * dx + dy * dy)
        if len == 0 then return { u0, v0, u1, v1 } end
        local head = math.min(len * 0.3, len * 0.12 + 0.002 * W)
        local ux, uy = dx / len, dy / len
        local function At(angle)
            local c, s = math.cos(angle), math.sin(angle)
            return u1 - (ux * c - uy * s) * head / W, v1 - (ux * s + uy * c) * head / H
        end
        local lu, lv = At(0.45)
        local ru, rv = At(-0.45)
        return { u0, v0, u1, v1, lu, lv, u1, v1, ru, rv }
    end
    return { u0, v0, u1, v1 }
end

local function Halo(ink)
    if ink[2] + ink[3] + ink[4] < 1.5 then return 0.93, 0.86, 0.7, 0.45 end
    return 0.1, 0.07, 0.04, 0.5
end

local function Ink(st, into, pts)
    local ink = INKS[st.ink] or INKS[1]
    local nib = NIBS[st.size] or NIBS[2]
    local hr, hg, hb, ha = Halo(ink)
    local P = ns.Map.Pins
    P.Path(into, pts, nib + 2, hr, hg, hb, ha, 0)
    P.Path(into, pts, nib, ink[2], ink[3], ink[4], 1, 1)
end

local function Draw(st, into)
    if type(st.pts) ~= "table" or #st.pts < 2 then return end
    if st.tool == "mark" then
        local pin = ns.Map.Pins.Add(into, st.pts[1], st.pts[2], { texture = MARK .. (st.mark or 8), size = 22 })
        if pin then
            pin:EnableMouse(false)
            pin.openmapNoPress = true     -- (A à la manette passe au travers : rien à presser)
        end
        return
    end
    Ink(st, into, Points(st))
end

Redraw = function()
    if not set then return end
    local P = ns.Map.Pins
    P.Clear(set)
    -- (le dessin d'une épingle se cache avec tes épingles, sauf celle sur laquelle tu dessines)
    local pinsHidden = ns.Map.MyPins.Hidden and ns.Map.MyPins.Hidden()
    for _, st in ipairs(DB().strokes) do
        if not (st.pin and pinsHidden and st.pin ~= (forPin and forPin.id)) then Draw(st, set) end
    end
    P.SetOn(set, Shown() or drawing)
end

local function RedrawLive()
    if not liveSet then return end
    ns.Map.Pins.Clear(liveSet)
    if stroke then Draw(stroke.record, liveSet) end
end

---------------------------------------------------------------------------
-- La plume en main
---------------------------------------------------------------------------
-- (moins de points là où un trait va droit : Douglas-Peucker, à tol près, en unités du monde)
local function Thin(p, tol)
    local n = #p / 2
    if n < 3 then return p end
    local keep = { [1] = true, [n] = true }
    local function Run(i, j)
        local ax, ay, bx, by = p[2 * i - 1], p[2 * i], p[2 * j - 1], p[2 * j]
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local best, at = -1, nil
        for k = i + 1, j - 1 do
            local x, y = p[2 * k - 1], p[2 * k]
            local dist
            if len > 0 then
                dist = math.abs((by - ay) * x - (bx - ax) * y + bx * ay - by * ax) / len
            else
                dist = math.sqrt((x - ax) ^ 2 + (y - ay) ^ 2)
            end
            if dist > best then best, at = dist, k end
        end
        if at and best > tol then
            keep[at] = true
            Run(i, at)
            Run(at, j)
        end
    end
    Run(1, n)
    local out = {}
    for k = 1, n do
        if keep[k] then out[#out + 1], out[#out + 2] = p[2 * k - 1], p[2 * k] end
    end
    return out
end

-- (ceux qu'on touche : tous, ou ceux de l'épingle sur laquelle on dessine)
local function Mine(st) return not forPin or st.pin == forPin.id end

local function Erase(u, v, pu, pv)
    local list = DB().strokes
    for i = #list, 1, -1 do
        local pts = Mine(list[i]) and Points(list[i]) or {}
        for k = 1, #pts - 1, 2 do
            -- (près d'un point, ou du trait qui va au suivant)
            local x0, y0 = (pts[k] - u) / pu, (pts[k + 1] - v) / pv
            local x1 = pts[k + 2] and (pts[k + 2] - u) / pu
            local y1 = pts[k + 3] and (pts[k + 3] - v) / pv
            local dist = math.sqrt(x0 * x0 + y0 * y0)
            if x1 and y1 then
                local dx, dy = x1 - x0, y1 - y0
                local d2 = dx * dx + dy * dy
                local t = d2 > 0 and math.max(0, math.min(1, -(x0 * dx + y0 * dy) / d2)) or 0
                local cx, cy = x0 + dx * t, y0 + dy * t
                dist = math.min(dist, math.sqrt(cx * cx + cy * cy))
            end
            if dist < NEAR + (NIBS[list[i].size] or 3) then
                table.remove(list, i)
                Redraw()
                return
            end
        end
    end
end

-- Où est la main qui dessine (px de l'écran) : le curseur de la manette, sinon la souris
local function Hand()
    local x, y = ns.Map.Cursor.XY()
    if x then return x, y end
    return GetCursorPosition()
end

local function Start()
    local u, v, pu, pv = ns.Map.Cursor.World()
    if not u then return end
    local db = DB()
    if db.tool == "erase" then
        Erase(u, v, pu, pv)
        RefreshTray()
        return
    end
    if #db.strokes >= MAX_STROKES then
        ns.Print(L.SKETCH_TOO_MANY)
        return
    end
    local st = { tool = db.tool, ink = db.ink, size = db.size, pts = { Round(u), Round(v) }, pin = forPin and forPin.id or nil }
    if db.tool == "mark" then
        st.mark = db.mark
        st.id = db.nextId
        db.nextId = db.nextId + 1
        table.insert(db.strokes, st)
        Redraw()
        RefreshTray()
        Changed()
        return
    end
    local x, y = Hand()
    stroke = { record = st, x = x, y = y, lx = x, ly = y, pu = pu }
end

local function Move()
    if not stroke then return end
    local x, y = Hand()
    if math.abs(x - stroke.lx) + math.abs(y - stroke.ly) < STEP then return end
    local u, v = ns.Map.Cursor.World()
    if not u then return end
    stroke.lx, stroke.ly = x, y
    local p = stroke.record.pts
    if stroke.record.tool == "quill" then
        -- (le dernier bout seulement : le trait jusque-là reste tel quel)
        if #p >= MAX_POINTS * 2 or not liveSet then return end
        p[#p + 1], p[#p + 2] = Round(u), Round(v)
        local n = #p
        Ink(stroke.record, liveSet, { p[n - 3], p[n - 2], p[n - 1], p[n] })
    else
        p[3], p[4] = Round(u), Round(v)        -- (l'autre bout, là où est le curseur)
        RedrawLive()
    end
end

local function Finish()
    if not stroke then return end
    local st = stroke.record
    local tol = stroke.pu * 0.75
    stroke = nil
    RedrawLive()
    if #st.pts < 4 then return end            -- (un clic : rien de tracé)
    if st.tool == "quill" then st.pts = Thin(st.pts, tol) end
    local db = DB()
    st.id = db.nextId
    db.nextId = db.nextId + 1
    table.insert(db.strokes, st)
    Redraw()
    RefreshTray()
    if forPin then ns.Map.MyPins.Refresh() end
    Changed()
end

local function Undo()
    local list = DB().strokes
    local last, at
    for i, st in ipairs(list) do
        if Mine(st) and (not last or (st.id or 0) > (last.id or 0)) then last, at = st, i end
    end
    if at then
        table.remove(list, at)
        Redraw()
        RefreshTray()
        Changed()
    end
end

local function Clear()
    local list = DB().strokes
    for i = #list, 1, -1 do
        if Mine(list[i]) then table.remove(list, i) end
    end
    Redraw()
    RefreshTray()
    if forPin then ns.Map.MyPins.Refresh() end
    Changed()
end

---------------------------------------------------------------------------
-- La carte tirée au clic droit (la vue garde son zoom)
---------------------------------------------------------------------------
local function PanStart()
    local u, v, zoom = ns.Map.View.Now()
    local _, _, pu, pv = ns.Map.Cursor.World()
    if not (u and pu) then return end
    local x, y = GetCursorPosition()
    pan = { x = x, y = y, u = u, v = v, zoom = zoom, pu = pu, pv = pv }
end

local function PanMove()
    if not pan then return end
    if not IsMouseButtonDown("RightButton") then pan = nil return end
    local x, y = GetCursorPosition()
    local es = catcher:GetEffectiveScale()
    local dx, dy = (x - pan.x) / es, (y - pan.y) / es
    ns.Map.View.Show(pan.u - dx * pan.pu, pan.v + dy * pan.pv, pan.zoom)
end

---------------------------------------------------------------------------
-- Le plateau : les outils, les encres, les épaisseurs, aux couleurs de la charte
---------------------------------------------------------------------------
local function Select(b, on)
    b.sel:SetShown(on)
    b.selEdge:SetShown(on)
end

-- Un bouton carré du plateau : un fond en retrait, survol et choix en or
local function Slot(parent, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    UI.PaintWell(b)
    b.sel = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.sel:SetAllPoints()
    UI.Gradient(b.sel, "VERTICAL", 1, 0.82, 0, 0.06, 1, 0.82, 0, 0.22)
    b.selEdge = UI.Border(b, 1, 0.82, 0, 0.9, 0, "OVERLAY")
    Select(b, false)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.08)
    return b
end

local function Tip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(title, 1, 0.82, 0)
    if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
    GameTooltip:Show()
end

RefreshTray = function()
    if not tray then return end
    local db = DB()
    local ink = INKS[db.ink] or INKS[1]
    for _, b in ipairs(tray.tools) do
        local on = b.key == db.tool
        Select(b, on)
        b.label:SetFontObject(on and "GameFontHighlightSmall" or "GameFontNormalSmall")
        for _, line in ipairs(b.lines) do
            if on then line:SetVertexColor(1, 0.82, 0) else line:SetVertexColor(UI.RGB("textDim")) end
        end
    end
    tray.markButton.mark:SetTexture(MARK .. db.mark)
    for i, b in ipairs(tray.inks) do b.ring:SetShown(i == db.ink) end
    for i, b in ipairs(tray.nibs) do
        Select(b, i == db.size)
        b.dot:SetColorTexture(ink[2], ink[3], ink[4], 1)
    end
    local count = 0
    for _, st in ipairs(db.strokes) do
        if Mine(st) then count = count + 1 end
    end
    if forPin then
        local note = forPin.note ~= "" and forPin.note or L.SKETCH_PIN
        if #note > 28 then note = note:sub(1, 26):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
        tray.status:SetText(L.SKETCH_ON_PIN:format(note))
    else
        tray.status:SetText(L.SKETCH_COUNT:format(count))
    end
end

-- Un outil : ce qu'il trace, au-dessus de son nom
local function ToolButton(t)
    local b = Slot(tray.content, 46, 44)
    b.key = t.key
    b.lines = {}
    for _, path in ipairs(t.glyph or {}) do
        for k = 1, #path - 1 do
            local line = b:CreateLine(nil, "ARTWORK")
            line:SetThickness(2)
            line:SetColorTexture(1, 1, 1, 1)
            line:SetStartPoint("TOPLEFT", b, 7 + path[k][1], -5 - path[k][2])
            line:SetEndPoint("TOPLEFT", b, 7 + path[k + 1][1], -5 - path[k + 1][2])
            b.lines[#b.lines + 1] = line
        end
    end
    if t.key == "mark" then
        b.mark = b:CreateTexture(nil, "ARTWORK")
        b.mark:SetSize(20, 20)
        b.mark:SetPoint("TOP", 0, -5)
        tray.markButton = b
    end
    b.label = UI.Text(b, "GameFontNormalSmall", L[t.name])
    b.label:SetPoint("BOTTOM", 0, 4)
    b.label:SetPoint("LEFT", 2, 0)
    b.label:SetPoint("RIGHT", -2, 0)
    b.label:SetWordWrap(false)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, button)
        local db = DB()
        -- (la marque : un clic droit, ou un clic sur elle déjà choisie, en change)
        if t.key == "mark" and (button == "RightButton" or db.tool == "mark") then db.mark = db.mark % 8 + 1 end
        db.tool = t.key
        RefreshTray()
    end)
    b:SetScript("OnEnter", function(self) Tip(self, L[t.name], L[t.tip]) end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function Caption(text, x)
    local f = UI.Text(tray.content, "GameFontNormalSmall", text)
    f:SetPoint("TOPLEFT", x, -6)
end

local function CreateTray()
    tray = UI.MapWindow("MyMapIsRichQuill", 100, 146, L.SKETCH_TITLE, nil, 8300)
    -- (un plateau, pas une fenêtre à mener à la croix : A dessine sur la carte,
    -- le curseur y presse les boutons, View y passe : Pad/MapNav.lua)
    tray.padPassive = true
    tray:SetScript("OnHide", function() if drawing then SKM.Toggle(false) end end)
    local c = tray.content
    local y = -22
    local x = 8
    -- les outils
    Caption(L.SKETCH_TOOL, x)
    tray.tools = {}
    for _, t in ipairs(TOOLS) do
        local b = ToolButton(t)
        b:SetPoint("TOPLEFT", x, y)
        tray.tools[#tray.tools + 1] = b
        x = x + 50
    end
    -- les encres : une goutte ronde chacune, cerclée d'or quand elle est choisie
    x = x + 14
    Caption(L.SKETCH_INK, x)
    tray.inks = {}
    for i, ink in ipairs(INKS) do
        local b = CreateFrame("Button", nil, c)
        b:SetSize(26, 26)
        b:SetPoint("TOPLEFT", x, y - 9)
        b.ring = UI.Disc(b, 30, "BACKGROUND")
        b.ring:SetColorTexture(1, 0.82, 0, 1)
        local rim = UI.Disc(b, 24, "BORDER")
        UI.Fill(rim, "edgeLight", 1)
        local drop = UI.Disc(b, 20, "ARTWORK")
        drop:SetColorTexture(ink[2], ink[3], ink[4], 1)
        b:SetScript("OnClick", function()
            local db = DB()
            db.ink = i
            if db.tool == "erase" or db.tool == "mark" then db.tool = "quill" end
            RefreshTray()
        end)
        b:SetScript("OnEnter", function(self) Tip(self, L[ink[1]]) end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        tray.inks[i] = b
        x = x + 30
    end
    -- les épaisseurs : un point chacune, large comme son trait, dans l'encre choisie
    x = x + 12
    Caption(L.SKETCH_WIDTH, x)
    tray.nibs = {}
    for i, nib in ipairs(NIBS) do
        local b = Slot(c, 28, 28)
        b:SetPoint("TOPLEFT", x, y - 8)
        local paper = b:CreateTexture(nil, "BORDER")
        paper:SetPoint("TOPLEFT", 3, -3)
        paper:SetPoint("BOTTOMRIGHT", -3, 3)
        paper:SetColorTexture(0.85, 0.78, 0.62, 1)     -- (un bout de parchemin : toute encre s'y voit)
        b.dot = b:CreateTexture(nil, "ARTWORK")
        b.dot:SetSize(nib * 1.6 + 2, nib * 1.6 + 2)
        b.dot:SetPoint("CENTER")
        b:SetScript("OnClick", function()
            DB().size = i
            RefreshTray()
        end)
        b:SetScript("OnEnter", function(self) Tip(self, L[NIB_NAMES[i]]) end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        tray.nibs[i] = b
        x = x + 32
    end
    -- Défaire, Effacer (deux fois), Terminé
    x = x + 14
    local undo = UI.Button(c, L.SKETCH_UNDO, 92, 22, "grey")
    undo:SetPoint("TOPLEFT", x, y)
    undo:SetScript("OnClick", Undo)
    UI.Tip(undo, L.SKETCH_UNDO, L.SKETCH_UNDO_TIP)
    local clear = UI.Button(c, L.SKETCH_CLEAR, 92, 22, "grey")
    clear:SetPoint("TOPLEFT", undo, "BOTTOMLEFT", 0, -2)
    clear:SetScript("OnClick", function(self)
        if self.armed then
            self.armed = nil
            self:SetText(L.SKETCH_CLEAR)
            Clear()
            return
        end
        self.armed = true
        self:SetText(L.SKETCH_CLEAR_SURE)
        C_Timer.After(3, function()
            self.armed = nil
            self:SetText(L.SKETCH_CLEAR)
        end)
    end)
    UI.Tip(clear, L.SKETCH_CLEAR, L.SKETCH_CLEAR_TIP)
    x = x + 92 + 8
    local done = UI.Button(c, L.SKETCH_DONE, 100, 30)
    done:SetPoint("TOPLEFT", x, y - 7)
    done:SetScript("OnClick", function()
        -- (sur une épingle : sa fiche finie aussi, sa note et sa couleur gardées)
        if forPin and ns.PinsWindow then ns.PinsWindow.FinishDrawing() else SKM.Toggle(false) end
    end)
    UI.Tip(done, L.SKETCH_DONE, L.SKETCH_DONE_TIP)
    x = x + 100 + 8
    -- en bas : ce qui est dessiné, et comment
    local rule = UI.Rule(c)
    rule:SetPoint("TOPLEFT", 4, y - 52)
    rule:SetPoint("TOPRIGHT", -4, y - 52)
    tray.status = UI.Text(c, "GameFontNormalSmall")
    tray.status:SetPoint("TOPLEFT", 8, y - 60)
    local help = UI.DimText(c, L.SKETCH_HELP)
    help:SetPoint("TOPRIGHT", -8, y - 60)
    tray:SetSize(x + 18, 146)
end

-- Le capteur de la souris, sur toute la carte, pendant qu'on dessine
local function CreateCatcher()
    local view = ns.Map.View.Frame()
    if not view then return end
    catcher = CreateFrame("Frame", nil, view)
    catcher:SetAllPoints(view)
    catcher:SetFrameLevel(CATCHER_LEVEL)
    catcher:EnableMouse(true)
    catcher:EnableMouseWheel(true)
    catcher:Hide()
    catcher:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then Start()
        elseif button == "RightButton" then PanStart() end
    end)
    catcher:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then Finish()
        elseif button == "RightButton" then pan = nil end
    end)
    catcher:SetScript("OnMouseWheel", function(_, delta) ns.Map.View.Wheel(delta) end)
    catcher:SetScript("OnUpdate", function()
        Move()
        PanMove()
    end)
    -- Ctrl+Z défait, Échap range la plume ; les autres touches passent au jeu
    -- (le passage des touches ne se règle pas en combat)
    catcher:EnableKeyboard(true)
    pcall(catcher.SetPropagateKeyboardInput, catcher, true)
    catcher:SetScript("OnKeyDown", function(self, key)
        local undo = key == "Z" and IsControlKeyDown()
        if not (undo or key == "ESCAPE") or InCombatLockdown() then return end
        self:SetPropagateKeyboardInput(false)
        if undo then Undo() else SKM.Toggle(false) end
        C_Timer.After(0, function()
            if not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, true) end
        end)
    end)
end

---------------------------------------------------------------------------
-- Sortir la plume, la ranger
---------------------------------------------------------------------------
-- on : la plume sortie (nil : l'inverse) ; pin : ce qu'on dessine s'attache à
-- cette épingle, et dock (sa fiche) a le plateau juste dessous
function SKM.Toggle(on, pin, dock)
    -- (la carte d'un donjon ouverte : la plume dessine sur son étage)
    if not pin and not drawing and DG.Shown() then
        if on == nil then on = not DG.Drawing() end
        DG.Draw(on)
        Changed()
        return
    end
    if on == nil then on = not drawing end
    if on and not ns.MapShown() then
        -- (la carte ouverte d'abord, puis la plume quand elle est dessinée)
        waiting = { pin = pin, dock = dock }
        if not InCombatLockdown() and ToggleWorldMap then pcall(ToggleWorldMap) end
        return
    end
    if on and not (set and ns.Map.View.Frame()) then
        waiting = { pin = pin, dock = dock }
        return
    end
    waiting = nil
    if on and drawing then SKM.Toggle(false) end   -- (un dessin à la fois : celui d'avant rangé)
    if not on and stroke then Finish() end
    drawing = on and true or false
    forPin = drawing and pin or nil
    pan = nil
    if drawing then
        if not catcher then CreateCatcher() end
        if not tray then CreateTray() end
        tray:ClearAllPoints()
        if dock then
            tray:SetPoint("TOP", dock, "BOTTOM", 0, -4)
            tray.title:SetText(L.SKETCH_TITLE_PIN)
        else
            tray:SetPoint("TOP", ns.Map.View.Frame(), "TOP", 0, -72)
            tray.title:SetText(L.SKETCH_TITLE)
        end
    end
    if catcher then catcher:SetShown(drawing) end
    if tray then tray:SetShown(drawing) end
    Redraw()
    RefreshTray()
    Changed()
end

-- A à la manette, la plume sortie : la plume posée là où est le curseur (une
-- marque ou la gomme aussitôt), ou levée, le trait fini (la manette n'a pas de
-- glisser : A, bouger, A)
function SKM.PadPress()
    if not drawing then return false end
    if stroke then Finish() else Start() end
    return true
end

---------------------------------------------------------------------------
-- Pour le reste de Plus (ns.Map.Sketch) : la roue, la fiche d'un point, les
-- épingles, la carte d'un donjon, la manette
---------------------------------------------------------------------------
function SK.Toggle(on) SKM.Toggle(on) end
function SK.Drawing() return drawing or DG.Drawing() or false end
function SK.Available() return true end
-- Les dessins attachés à une épingle : combien, dessiner sur elle (le
-- plateau sous dock), l'épingle en cours, les effacer avec elle
function SK.Count(pinId)
    local n = 0
    for _, st in ipairs(DB().strokes) do
        if st.pin == pinId then n = n + 1 end
    end
    return n
end
function SK.ForPin(pin, dock) SKM.Toggle(true, pin, dock) end
function SK.Pin() return drawing and forPin or nil end
function SK.Drop(pinId)
    local list = DB().strokes
    for i = #list, 1, -1 do
        if list[i].pin == pinId then table.remove(list, i) end
    end
    Redraw()
end
function SK.Redraw() Redraw() end
-- Le plateau, s'il est sorti (View à la manette y passe)
function SK.Tray() return tray and tray:IsVisible() and tray or nil end
-- Les traits sur la carte d'un donjon, par mapID de l'instance (make : la
-- table créée s'il n'y en a pas)
function SK.DungeonStrokes(key, make)
    if not key then return end
    local db = DB()
    if make then
        db.dungeons = db.dungeons or {}
        db.dungeons[key] = db.dungeons[key] or {}
    end
    return db.dungeons and db.dungeons[key]
end
-- L'encre choisie : { r, g, b }
function SK.Ink()
    local ink = INKS[DB().ink] or INKS[1]
    return { ink[2], ink[3], ink[4] }
end
function SK.Shown() return Shown() end
function SK.Changed() Changed() end

local function Migrate()
    -- (les dessins de tout le compte, et « Tes dessins » montrés ou non)
    ns.Map.Migrate("sketch", function(old, new, copy)
        if type(old.sketch) == "table" then new.sketch = copy(old.sketch) end
        if old.sketchShown ~= nil then new.settings.sketchShown = old.sketchShown and true or false end
    end)
end

ns.On("MAP_ATTACHED", function()
    Migrate()
end)
ns.On("MAP_BUILT", function()
    local P = ns.Map.Pins
    set = P.Set("sketch", 0, 4)
    liveSet = P.Set("sketchLive", 0, 4)
    Redraw()
    -- (la plume demandée avant que la carte soit dessinée)
    if waiting and ns.MapShown() then
        local w = waiting
        C_Timer.After(0, function() SKM.Toggle(true, w.pin, w.dock) end)
    end
end)
ns.On("MAP_SHOW", function()
    if waiting and set then
        local w = waiting
        C_Timer.After(0, function() if ns.MapShown() then SKM.Toggle(true, w.pin, w.dock) end end)
    end
end)
ns.On("MAP_HIDE", function()
    waiting = nil
    if drawing then SKM.Toggle(false) end
end)
ns.On("MAP_REFRESH", function() Redraw() end)
