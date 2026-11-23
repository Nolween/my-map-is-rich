-- La carte d'un donjon, en code et aux couleurs de My Map Is Rich depuis la
-- 0.10.0 (c'était la vue de donjon de Map/Dungeons.lua d'OpenMap).
-- Elle se pose sur la carte du monde, dans le même cadre :
--   en haut      le retour à la zone d'où l'on vient, l'étage entre deux
--                flèches (un clic sur son nom : la liste des étages), la croix ;
--   à gauche     la carte de l'étage (les 12 images de Blizzard, ou celles de
--                la minicarte), ses boss numérotés, les traits de la plume ;
--   à droite     le panneau du donjon : ses niveaux, et les onglets Étages,
--                Boss, Quêtes, Butin.
-- Sans carte de ce donjon dans le jeu, une page grise le dit ; le panneau reste.
-- Souris : la molette zoome autour du curseur, tirer déplace, un clic droit
-- revient au monde. Manette : Pad/Dungeon.lua, par ns.Map.Dungeons.
local _, root = ...
local ns = root.Plus
local L = ns.L
local UI = ns.UI

local DV = {}
ns.DungeonView = DV
local DN = ns.Dungeons
local DG = ns.Map.Dungeons
local K = ns.Map.Coords
local SK = ns.Map.Sketch
local Settings = ns.Map.Settings
local Get = Settings.Get

local PIC_W, PIC_H = 1002, 668   -- l'image d'un étage dans ses 4 x 3 images de 256 (1024 x 768)
local HEAD_H = 40                -- la barre du haut
local SIDE_W = 320               -- le panneau du donjon
local GAP = UI.PAGE_GAP          -- entre deux panneaux
local ZOOM_MIN, ZOOM_MAX = 0.5, 4
local HINTS = 3                  -- les premières cartes ouvertes disent comment revenir
local TAB_H = 24
local ROW_H = 24
local PIN_SIZE = 22
-- (au-dessus de l'habillage de la carte, UI/MapChrome.lua : 9940, et de la
-- fiche d'un point : 9960 ; sous le curseur de la manette : 9990)
local VIEW_LEVEL = 9962

local MARK_STEP = 3              -- px que parcourt le curseur avant que la plume ajoute un point
local MARK_MAX = 300             -- points dans un trait
local MARK_INK = { 0.92, 0.18, 0.14 }

local TABS = {
    { key = "floors", label = "DUNGEON_TAB_FLOORS" },
    { key = "bosses", label = "DUNGEON_TAB_BOSSES" },
    { key = "quests", label = "DUNGEON_TAB_QUESTS" },
    { key = "loot", label = "DUNGEON_TAB_LOOT" },
}

local view
local Layout, Fill, ShowFloor, PlaceMarks, PlacePins, EndMarkup

local function Sound(name)
    if PlaySound and SOUNDKIT and SOUNDKIT[name] then PlaySound(SOUNDKIT[name]) end
end

local function Shown() return view and view:IsShown() or false end

local function TextWidth(fs)
    local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
    return w or 0
end

local function Atlas(tex, name)
    if UI.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
    return false
end

-- Le nom d'un étage : celui des données, sinon « Étage 2 », sinon le donjon
local function FloorName(i)
    local f = view.floors[i]
    return (f and f.name) or (#view.floors > 1 and L.DUNGEON_FLOOR:format(i)) or K.InstanceName(view.inst)
end

---------------------------------------------------------------------------
-- La carte de l'étage : sa place, son zoom
---------------------------------------------------------------------------
Layout = function()
    -- (aucun étage encore : la vue montrée avant ShowFloor)
    if not Shown() or not view.zoom then return end
    local w, h = view.port:GetWidth(), view.port:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then return end
    local s = math.min(w / PIC_W, h / PIC_H) * view.zoom
    local pw, ph = PIC_W * s, PIC_H * s
    -- (gardée dans la vue quand elle est plus grande, au milieu sinon)
    local mx, my = math.max(0, (pw - w) / 2), math.max(0, (ph - h) / 2)
    view.ox = math.max(-mx, math.min(mx, view.ox))
    view.oy = math.max(-my, math.min(my, view.oy))
    view.page:SetSize(pw, ph)
    view.page:ClearAllPoints()
    view.page:SetPoint("CENTER", view.port, "CENTER", view.ox, view.oy)
    for i, t in ipairs(view.tiles) do
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        local tw, th = math.min(256, PIC_W - col * 256), math.min(256, PIC_H - row * 256)
        t:SetSize(tw * s, th * s)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", view.page, "TOPLEFT", col * 256 * s, -row * 256 * s)
        t:SetTexCoord(0, tw / 256, 0, th / 256)
    end
    PlaceMarks(pw, ph)
    PlacePins(pw, ph)
end

-- Zoomer d'un cran autour d'un point de l'écran (px, comme GetCursorPosition ;
-- rien : le milieu)
local function ZoomAt(delta, x, y)
    if not Shown() or not view.zoom then return end
    local z = math.max(ZOOM_MIN, math.min(ZOOM_MAX, view.zoom * (delta > 0 and 1.25 or 0.8)))
    if math.abs(z - view.zoom) < 1e-3 then return end
    local dx, dy = 0, 0
    local cx, cy = view.port:GetCenter()
    if x and y and cx then
        local es = view:GetEffectiveScale()
        dx, dy = x / es - cx - view.ox, y / es - cy - view.oy
    end
    view.ox, view.oy = view.ox - dx * (z / view.zoom - 1), view.oy - dy * (z / view.zoom - 1)
    view.zoom = z
    Layout()
end

local wheelPoint             -- (Pad/Dungeon.lua : le curseur de la manette, quand elle mène)
local function Wheel(delta)
    if wheelPoint then
        local pad, x, y = wheelPoint()
        if pad then return ZoomAt(delta, x, y) end
    end
    ZoomAt(delta, GetCursorPosition())
end

local function UpdateFloorBar()
    local n = #view.floors
    local text = "|cffffd100" .. FloorName(view.floor) .. "|r"
    if n > 1 then text = text .. "  " .. UI.Hex("textDim") .. ("%d / %d"):format(view.floor, n) .. "|r" end
    view.floorButton:SetText(text)
    view.floorButton:SetWidth(math.max(180, math.min(360, TextWidth(view.floorButton:GetFontString()) + 28)))
    view.floorButton:SetEnabled(n > 1)
    view.prev:SetShown(n > 1)
    view.next:SetShown(n > 1)
end

local function LightThumbs()
    for _, w in ipairs(view.side.pool.thumb) do
        local on = w:IsShown() and w.item and w.item.floor == view.floor
        if on then w.edge:SetColor(1, 0.82, 0, 1) else w.edge:SetColor("edgeDim", 1) end
        w.name:SetFontObject(on and "GameFontNormalSmall" or "GameFontHighlightSmall")
    end
end

ShowFloor = function(i, quiet)
    local floors = view.floors
    i = ((i - 1) % #floors) + 1
    if not quiet and i ~= view.floor then Sound("IG_ABILITY_PAGE_TURN") end
    view.floor = i
    local f = floors[i]
    for k, t in ipairs(view.tiles) do
        if f.tiles then t:SetTexture(f.tiles[k], nil, nil, "TRILINEAR") end
        t:SetShown(f.tiles and true or false)
    end
    view.blank:SetShown(f.blank and true or false)
    view.blankText:SetShown(f.blank and true or false)
    UpdateFloorBar()
    LightThumbs()
    view.zoom, view.ox, view.oy = 1, 0, 0
    Layout()
end

---------------------------------------------------------------------------
-- La plume sur la carte d'un donjon : ses traits sur l'image de l'étage, à
-- sa mesure (0..1 en largeur et en hauteur : ils gardent leur place au zoom),
-- chacun sur l'étage où il a été tracé. Ils sont gardés avec les dessins de
-- la plume (Layers/Sketch.lua, sketch.dungeons), par mapID de l'instance.
-- Tirer à gauche trace, tirer à droite déplace ; sa barre : Défaire, Effacer, Terminé.
---------------------------------------------------------------------------
local function StrokesKey(inst)
    return inst and (inst[1] ~= 0 and inst[1] or inst[2])   -- (0 : un donjon inconnu du jeu, par son nom)
end

local function Kept(make) return SK.DungeonStrokes(StrokesKey(view.inst), make) end

PlaceMarks = function(pw, ph)
    view.markLines = view.markLines or {}
    local lines = view.markLines
    local list = view.markup and view.markup.strokes or (SK.Shown() and Kept()) or {}
    local n = 0
    for _, st in ipairs(list) do
        if st.floor == view.floor and type(st.pts) == "table" then
            local p = st.pts
            local ink = st.ink or MARK_INK
            for k = 1, #p - 3, 2 do
                n = n + 1
                local line = lines[n]
                if not line then
                    line = view.page:CreateLine(nil, "OVERLAY")
                    line:SetThickness(3)
                    lines[n] = line
                end
                line:SetColorTexture(ink[1], ink[2], ink[3], 1)
                line:SetStartPoint("TOPLEFT", view.page, p[k] * pw, -p[k + 1] * ph)
                line:SetEndPoint("TOPLEFT", view.page, p[k + 2] * pw, -p[k + 3] * ph)
                line:Show()
            end
        end
    end
    for i = n + 1, #lines do lines[i]:Hide() end
end

local function RedrawMarks()
    local pw, ph = view.page:GetSize()
    if pw and pw > 0 then PlaceMarks(pw, ph) end
end

-- Le curseur sur l'image : 0..1 en largeur et en hauteur (nil hors d'elle ;
-- clamp : ramené au bord)
local function PageAt(clamp)
    local x, y = GetCursorPosition()
    local es = view.page:GetEffectiveScale()
    local l, t, w, h = view.page:GetLeft(), view.page:GetTop(), view.page:GetWidth(), view.page:GetHeight()
    if not (l and t and w and h and w > 0 and h > 0) then return end
    local px, py = (x / es - l) / w, (t - y / es) / h
    if clamp then return math.max(0, math.min(1, px)), math.max(0, math.min(1, py)) end
    if px < 0 or px > 1 or py < 0 or py > 1 then return end
    return px, py
end

local function Round4(x) return math.floor(x * 1e4 + 0.5) / 1e4 end

local function MarkStart()
    local m = view.markup
    local px, py = PageAt()
    if not m or not px then return end
    local st = { floor = view.floor, pts = { Round4(px), Round4(py) }, ink = m.ink }
    m.strokes[#m.strokes + 1] = st
    local x, y = GetCursorPosition()
    m.live = { st = st, x = x, y = y }
end

local function MarkFinish()
    local m = view.markup
    local live = m and m.live
    if not live then return end
    m.live = nil
    if #live.st.pts < 4 then table.remove(m.strokes) end   -- (un clic : rien de tracé)
    RedrawMarks()
    SK.Changed()
end

local function MarkMove()
    local live = view.markup and view.markup.live
    if not live then return end
    if not IsMouseButtonDown("LeftButton") then MarkFinish() return end
    local x, y = GetCursorPosition()
    if math.abs(x - live.x) + math.abs(y - live.y) < MARK_STEP or #live.st.pts >= MARK_MAX * 2 then return end
    live.x, live.y = x, y
    local px, py = PageAt(true)
    if not px then return end
    local p = live.st.pts
    p[#p + 1], p[#p + 2] = Round4(px), Round4(py)
    RedrawMarks()
end

-- Les traits de l'étage montré : le dernier retiré, ou tous
local function DropStrokes(all)
    local m = view.markup
    if not m then return end
    for i = #m.strokes, 1, -1 do
        if m.strokes[i].floor == view.floor then
            table.remove(m.strokes, i)
            if not all then break end
        end
    end
    RedrawMarks()
    SK.Changed()
end

-- La barre de la plume, en haut de la carte : ce qu'on fait, Défaire, Effacer, Terminé
local function DrawBar()
    if view.drawBar then return view.drawBar end
    local bar = UI.Panel(view)
    bar:SetPoint("TOP", view.port, "TOP", 0, -8)
    bar:SetSize(620, 38)
    bar:SetFrameLevel(view:GetFrameLevel() + 14)
    bar:EnableMouse(true)
    local text = UI.Text(bar, "GameFontHighlightSmall", L.DUNGEON_DRAW)
    text:SetPoint("LEFT", 12, 0)
    text:SetPoint("RIGHT", bar, "RIGHT", -284, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    local done = UI.Button(bar, L.DUNGEON_DRAW_DONE, 86, 24)
    done:SetPoint("RIGHT", -8, 0)
    done:SetScript("OnClick", function() EndMarkup() end)
    local clear = UI.Button(bar, L.DUNGEON_DRAW_CLEAR, 86, 24, "grey")
    clear:SetPoint("RIGHT", done, "LEFT", -6, 0)
    clear:SetScript("OnClick", function() DropStrokes(true) end)
    local undo = UI.Button(bar, L.DUNGEON_DRAW_UNDO, 86, 24, "grey")
    undo:SetPoint("RIGHT", clear, "LEFT", -6, 0)
    undo:SetScript("OnClick", function() DropStrokes(false) end)
    view.drawBar = bar
    return bar
end

EndMarkup = function()
    local m = view and view.markup
    if not m then return end
    view.markup = nil
    if view.drawBar then view.drawBar:Hide() end
    RedrawMarks()
    SK.Changed()
end

-- La plume sur la carte du donjon montrée (Layers/Sketch.lua, SKM.Toggle) : on ou off
function DG.Draw(on)
    if not view then return end
    if not on then
        EndMarkup()
        return
    end
    if not Shown() then return end
    EndMarkup()
    view.markup = { strokes = Kept(true), ink = SK.Ink() }
    view.hint:Hide()
    DrawBar():Show()
    RedrawMarks()
    SK.Changed()
end
function DG.Drawing() return view and view.markup and true or false end

---------------------------------------------------------------------------
-- Les boss sur la carte : là où Data/Map/DungeonBosses.lua les met (et
-- ceux que tu avais placés à la main), numérotés comme l'onglet Boss
---------------------------------------------------------------------------
-- (une carte tirée de la minicarte a ses propres étages, donc ses propres places)
local function BossKey(inst)
    local key = StrokesKey(inst)
    if key and view.source == "minimap" then return "minimap:" .. key end
    return key
end

-- Les boss du donjon dans l'ordre du jeu, puis ceux que les places connaissent en plus
local function BossNames(inst)
    local names, seen = {}, {}
    for _, n in ipairs((DN.Places().bosses or {})[inst[1]] or {}) do
        if not seen[n] then names[#names + 1], seen[n] = n, true end
    end
    local key = BossKey(inst)
    local shipped = ns.Map.Data.DungeonBosses()
    local db = ns.Map.DB()
    for _, src in ipairs({ shipped and shipped[key], db and db.bossPlaced and db.bossPlaced[key] }) do
        local extra = {}
        for n in pairs(src or {}) do
            if not seen[n] then extra[#extra + 1] = n end
        end
        table.sort(extra)
        for _, n in ipairs(extra) do names[#names + 1], seen[n] = n, true end
    end
    return names
end

-- La place d'un boss : { étage, x, y }, la tienne d'abord ; nil s'il n'en a pas
local function BossAt(inst, name)
    local key = BossKey(inst)
    local db = ns.Map.DB()
    local mine = db and db.bossPlaced and db.bossPlaced[key]
    if mine and mine[name] then return mine[name], true end
    local shipped = ns.Map.Data.DungeonBosses()
    return shipped and shipped[key] and shipped[key][name]
end

local function BossTip(pin)
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(("%d. %s"):format(pin.index, pin.name), 1, 0.82, 0)
    if pin.mine then GameTooltip:AddLine(L.DUNGEON_BOSS_MINE, 0.6, 0.6, 0.6) end
    if DN.NeedRoll() then GameTooltip:AddLine(L.DUNGEON_NR_LOOT, 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

local function MakePin(i)
    local pin = CreateFrame("Button", nil, view.page)
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    pin:SetFrameLevel(view.page:GetFrameLevel() + 3)
    local ring = UI.Disc(pin, PIN_SIZE + 6, "BACKGROUND")
    ring:SetColorTexture(0, 0, 0, 0.7)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    if not Atlas(pin.icon, "DungeonSkull") then pin.icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull") end
    pin.num = UI.Text(pin, "GameFontNormalSmall")
    pin.num:SetPoint("CENTER", pin, "BOTTOMRIGHT", -2, 3)
    pin.num:SetShadowColor(0, 0, 0, 1)
    pin.num:SetShadowOffset(1, -1)
    pin:SetScript("OnEnter", BossTip)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    pin:SetScript("OnClick", function(self)
        if DN.NeedRoll() then DN.OpenNeedRoll(view.inst, self.name, IsShiftKeyDown() and "map" or nil) end
    end)
    view.bossPins[i] = pin
    return pin
end

PlacePins = function(pw, ph)
    view.bossPins = view.bossPins or {}
    local n = 0
    local inst = view.inst
    local f = view.floors and view.floors[view.floor]
    if inst and Get("dungeonBosses") ~= false and f and not f.blank then
        for i, name in ipairs(BossNames(inst)) do
            local p, mine = BossAt(inst, name)
            if type(p) == "table" and p[1] == view.floor then
                n = n + 1
                local pin = view.bossPins[n] or MakePin(n)
                pin.index, pin.name, pin.mine = i, name, mine
                pin.num:SetText(i)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", view.page, "TOPLEFT", p[2] * pw, -p[3] * ph)
                pin:Show()
            end
        end
    end
    for i = n + 1, #view.bossPins do view.bossPins[i]:Hide() end
end

local function RedrawPins()
    local pw, ph = view.page:GetSize()
    if pw and pw > 0 then PlacePins(pw, ph) end
end

---------------------------------------------------------------------------
-- Le panneau du donjon : ses onglets, et leurs lignes (faites au besoin, gardées)
---------------------------------------------------------------------------
local function TabsShown()
    return {
        floors = view.floors and #view.floors > 1,
        bosses = Get("dungeonBosses") ~= false,
        quests = Get("dungeonQuests") ~= false,
        loot = true,
    }
end

local function CurrentTab(shown)
    local tab = Get("dungeonTab")
    if not shown[tab] then
        tab = shown.floors and "floors" or shown.bosses and "bosses" or shown.quests and "quests" or "loot"
    end
    return tab
end

local function SelectTab(key)
    if Get("dungeonTab") ~= key then Sound("IG_CHARACTER_INFO_TAB") end
    Settings.Set("dungeonTab", key)
    Fill()
end

local function NewItem(kind)
    local side = view.side
    local w
    if kind == "row" then
        w = CreateFrame("Button", nil, side.child)
        w:SetHeight(ROW_H)
        UI.RowBackground(w)
        local hl = w:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.82, 0, 0.09)
        w.right = UI.Text(w, "GameFontDisableSmall")
        w.right:SetPoint("RIGHT", -6, 0)
        w.left = UI.Text(w, "GameFontHighlight")
        w.left:SetPoint("LEFT", 6, 0)
        w.left:SetPoint("RIGHT", w.right, "LEFT", -6, 0)
        w.left:SetJustifyH("LEFT")
        w.left:SetWordWrap(false)
        w:SetScript("OnEnter", function(self) if self.item.tip then self.item.tip(self) end end)
        w:SetScript("OnLeave", GameTooltip_Hide)
        w:SetScript("OnClick", function(self) if self.item.click then self.item.click() end end)
    elseif kind == "text" then
        w = UI.Text(side.child, "GameFontHighlightSmall")
        w:SetJustifyH("LEFT")
        w:SetSpacing(3)
    elseif kind == "button" then
        w = UI.Button(side.child, "", 190, 24)
        w:SetScript("OnClick", function(self) if self.item.click then self.item.click() end end)
    elseif kind == "thumb" then
        -- (l'image d'un étage, en petit (ses 12 images), son nom dessous ; un clic : cet étage)
        w = CreateFrame("Button", nil, side.child)
        UI.PaintWell(w)
        w.tiles = {}
        for k = 1, 12 do w.tiles[k] = w:CreateTexture(nil, "ARTWORK") end
        local hl = w:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", 1, -1)
        hl:SetPoint("BOTTOMRIGHT", -1, 1)
        hl:SetColorTexture(1, 0.82, 0, 0.12)
        w.name = UI.Text(w, "GameFontHighlightSmall")
        w.name:SetPoint("TOP", w, "BOTTOM", 0, -3)
        w.name:SetWordWrap(false)
        w:SetScript("OnClick", function(self) ShowFloor(self.item.floor) end)
    else
        -- (un lien à copier : un champ qui garde son texte, tout choisi)
        w = CreateFrame("EditBox", nil, side.child, "InputBoxTemplate")
        w:SetHeight(22)
        w:SetAutoFocus(false)
        w:SetFontObject("GameFontHighlightSmall")
        UI.SkinInput(w)
        w:SetScript("OnTextChanged", function(self, user)
            if user then
                self:SetText(self.item[1])
                self:HighlightText()
            end
        end)
        w:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        w:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end
    return w
end

local function Dim(text) return UI.Hex("textDim") .. text .. "|r" end

-- Ce que montre chaque onglet : { kind = "row" | "text" | "button" | "link" | "thumb", ... }
local function Items(tab, inst)
    local items = {}
    local function Text(t) items[#items + 1] = { kind = "text", t } end
    local function Button(label, click) items[#items + 1] = { kind = "button", label, click = click } end
    if tab == "bosses" then
        local bosses = (DN.Places().bosses or {})[inst[1]] or {}
        local nr = DN.NeedRoll()
        for i, name in ipairs(bosses) do
            items[#items + 1] = { kind = "row", Dim(i .. ".") .. "  " .. name,
                click = nr and function() DN.OpenNeedRoll(inst, name, IsShiftKeyDown() and "map" or nil) end,
                tip = function(owner)
                    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
                    GameTooltip:AddLine(name, 1, 0.82, 0)
                    GameTooltip:AddLine(nr and L.DUNGEON_NR_LOOT or L.DUNGEON_SEE_LOOT, 0.6, 0.6, 0.6)
                    if _G.NeedRoll_ShowMap then GameTooltip:AddLine(L.DUNGEON_NR_MAP, 0.6, 0.6, 0.6) end
                    GameTooltip:Show()
                end }
        end
        if #bosses == 0 then Text(Dim(L.DUNGEON_NO_BOSSES)) end
        if DN.JournalName(inst) then Button(L.DUNGEON_OPEN_JOURNAL, function() DN.OpenJournal(inst) end) end
    elseif tab == "quests" then
        local source = DN.QuestSource()
        if source == "journal" then
            if DN.JournalName(inst) then
                Text(L.DUNGEON_JOURNAL_QUESTS)
                Button(L.DUNGEON_OPEN_JOURNAL, function() DN.OpenJournal(inst, true) end)
            else
                Text(Dim(L.DUNGEON_JOURNAL_NONE))
            end
        elseif source == "needroll" then
            Text(L.DUNGEON_NR_QUESTS)
            Button(L.DUNGEON_OPEN_NR, function() DN.OpenNeedRoll(inst) end)
        elseif not DN.Questie() then
            Text(Dim(L.DUNGEON_QUESTS_NEED))
        else
            DN.EnsureQuests(function() if Shown() then Fill() end end)
            local list = DN.QuestList(inst)
            if not list then
                Text(Dim(L.DUNGEON_READING))
            elseif #list == 0 then
                Text(Dim(L.DUNGEON_NO_QUESTS))
            else
                local QDB = DN.Questie()
                for _, q in ipairs(list) do
                    items[#items + 1] = { kind = "row", ("%s[%d] %s|r"):format(DN.QuestColour(q), q.level, q.name),
                        right = q.done and L.DUNGEON_DONE or q.inLog and ("|cff80f070" .. L.DUNGEON_IN_LOG .. "|r") or nil,
                        click = _G.NeedRoll_ShowQuest and function() DN.OpenNeedRoll(inst, nil, nil, q.id) end,
                        tip = function(owner)
                            GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
                            GameTooltip:AddLine(q.name, 1, 0.82, 0, true)
                            local okText, text = pcall(QDB.QueryQuestSingle, q.id, "objectivesText")
                            if okText and type(text) == "table" then
                                for _, line in ipairs(text) do GameTooltip:AddLine(line, 1, 1, 1, true) end
                            end
                            local okReq, req = pcall(QDB.QueryQuestSingle, q.id, "requiredLevel")
                            local level = (LEVEL or "Level") .. " " .. q.level
                            if okReq and req and req > 0 then level = level .. "  (" .. L.DUNGEON_FROM_LEVEL:format(req) .. ")" end
                            GameTooltip:AddLine(level, 0.8, 0.8, 0.8)
                            if q.done then GameTooltip:AddLine(L.DUNGEON_COMPLETED, 0.5, 0.95, 0.4)
                            elseif q.inLog then GameTooltip:AddLine(L.DUNGEON_IN_QUEST_LOG, 0.5, 0.95, 0.4) end
                            if _G.NeedRoll_ShowQuest then GameTooltip:AddLine(L.DUNGEON_NR_QUEST, 0.6, 0.6, 0.6) end
                            GameTooltip:Show()
                        end }
                end
            end
        end
    elseif tab == "floors" then
        for i = 1, #view.floors do items[#items + 1] = { kind = "thumb", floor = i } end
    else
        if DN.NeedRoll() then
            Text(L.DUNGEON_NR_LOOT_TEXT)
            Button(L.DUNGEON_OPEN_NR, function() DN.OpenNeedRoll(inst) end)
        else
            Text(L.DUNGEON_NR_RECOMMEND)
            Text(Dim(L.DUNGEON_NR_GET))
            items[#items + 1] = { kind = "link", DN.NEEDROLL_URL }
        end
    end
    return items
end

Fill = function()
    if not Shown() then return end
    local side, inst = view.side, view.inst
    side.title:SetText(K.InstanceName(inst) or "")
    local sub = {}
    if DN.Range(inst) then sub[#sub + 1] = (LEVEL or "Level") .. " " .. DN.Range(inst) end
    if inst[3] then sub[#sub + 1] = L.DUNGEON_RAID end
    side.sub:SetText(table.concat(sub, "   "))
    -- les onglets là (selon les réglages), celui montré
    local shown = TabsShown()
    local tab = CurrentTab(shown)
    local list = {}
    for _, b in ipairs(side.tabs) do
        b:SetShown(shown[b.key] and true or false)
        if shown[b.key] then list[#list + 1] = b end
        b:SetSelected(b.key == tab)
    end
    local inner = SIDE_W - 24
    local tw = math.floor((inner - (#list - 1) * 4) / #list)
    for i, b in ipairs(list) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", side, "TOPLEFT", 12 + (i - 1) * (tw + 4), -56)
        b:SetWidth(tw)
    end
    side.shownTabs = list
    -- ses lignes
    for _, pool in pairs(side.pool) do
        for _, w in ipairs(pool) do w:Hide() end
    end
    local used = { row = 0, text = 0, button = 0, link = 0, thumb = 0 }
    local width = math.max(100, (side.scroll:GetWidth() or 0) - 2)
    if width <= 100 then width = SIDE_W - 40 end
    side.child:SetWidth(width)
    local y = 0
    for _, it in ipairs(Items(tab, inst)) do
        used[it.kind] = used[it.kind] + 1
        local w = side.pool[it.kind][used[it.kind]]
        if not w then
            w = NewItem(it.kind)
            side.pool[it.kind][used[it.kind]] = w
        end
        w.item = it
        w:ClearAllPoints()
        if it.kind == "row" then
            w:SetPoint("TOPLEFT", 0, -y)
            w:SetWidth(width)
            w.stripe:SetShown(used.row % 2 == 0)
            w.left:SetText(it[1])
            w.right:SetText(it.right or "")
            w:EnableMouse(true)
            y = y + ROW_H
        elseif it.kind == "text" then
            w:SetPoint("TOPLEFT", 4, -y - 4)
            w:SetWidth(width - 8)
            w:SetText(it[1])
            y = y + (w:GetStringHeight() or 14) + 12
        elseif it.kind == "button" then
            w:SetPoint("TOPLEFT", 4, -y - 2)
            w:SetText(it[1])
            w:SetWidth(math.min(width - 8, math.max(170, TextWidth(w:GetFontString()) + 24)))
            y = y + 34
        elseif it.kind == "thumb" then
            -- (deux de front, puis à la ligne)
            local tw2 = math.floor((width - 10) / 2)
            local th = math.floor(tw2 * PIC_H / PIC_W)
            local col = (used.thumb - 1) % 2
            w:SetSize(tw2, th)
            w:SetPoint("TOPLEFT", 2 + col * (tw2 + 6), -y - 2)
            local s = (tw2 - 2) / PIC_W
            local f = view.floors[it.floor]
            for k, t in ipairs(w.tiles) do
                local c, r = (k - 1) % 4, math.floor((k - 1) / 4)
                local cw, ch = math.min(256, PIC_W - c * 256), math.min(256, PIC_H - r * 256)
                t:SetTexture(f.tiles and f.tiles[k], nil, nil, "TRILINEAR")
                t:SetShown(f.tiles and true or false)
                t:SetSize(cw * s, ch * s)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", 1 + c * 256 * s, -1 - r * 256 * s)
                t:SetTexCoord(0, cw / 256, 0, ch / 256)
            end
            w.name:SetWidth(tw2)
            w.name:SetText(FloorName(it.floor))
            if col == 1 or it.floor == #view.floors then y = y + th + 22 end
        else
            w:SetPoint("TOPLEFT", 10, -y - 2)
            w:SetWidth(width - 16)
            w:SetText(it[1])
            w:SetCursorPosition(0)
            y = y + 30
        end
        w:Show()
    end
    side.child:SetHeight(math.max(1, y))
    side.scroll:ToTop()
    LightThumbs()
end

---------------------------------------------------------------------------
-- La fenêtre
---------------------------------------------------------------------------
local function FloorMenu()
    local items = {}
    for i = 1, #view.floors do
        local name = FloorName(i)
        items[#items + 1] = { i == view.floor and ("|cffffffff" .. name .. "|r") or name, function() ShowFloor(i) end,
            key = ("%d / %d"):format(i, #view.floors) }
    end
    local x, y = view.floorButton:GetCenter()
    local es = view.floorButton:GetEffectiveScale()
    local w = view.floorButton:GetWidth() or 0
    UI.ShowMenu(items, x and (x - w / 2 - 14) * es, y and (y - 12) * es, K.InstanceName(view.inst))
end

local function BuildBar()
    local bar = CreateFrame("Frame", nil, view)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(HEAD_H)
    bar:SetFrameLevel(view:GetFrameLevel() + 10)
    bar:EnableMouse(true)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.Fade(bg, "VERTICAL", "headerBottom", 1, "headerTop", 1)
    local line = bar:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    UI.Fill(line, "panelEdge")
    -- (le retour au monde, à gauche ; la croix fait de même, à droite)
    view.back = UI.Button(bar, "", 160, 24, "grey")
    view.back:SetPoint("LEFT", 10, 0)
    view.back:SetScript("OnClick", function() DV.Close() end)
    UI.Tip(view.back, function() return view.back:GetText() end, L.DUNGEON_BACK_TIP)
    local close = UI.CloseButton(bar, 22, function() DV.Close() end)
    close:SetPoint("RIGHT", -10, 0)
    close.noGamepad = true      -- (à la manette, le bouton « < … » à gauche revient au monde : la croix n'est pas un élément à choisir)
    -- l'étage : son nom (la liste de tous au clic) entre deux flèches
    view.floorButton = UI.Button(bar, "", 200, 24, "grey")
    view.floorButton:SetPoint("CENTER")
    view.floorButton:SetScript("OnClick", FloorMenu)
    view.prev = UI.Button(bar, "<", 26, 24, "grey")
    view.prev:SetPoint("RIGHT", view.floorButton, "LEFT", -4, 0)
    view.prev:SetScript("OnClick", function() ShowFloor(view.floor - 1) end)
    view.next = UI.Button(bar, ">", 26, 24, "grey")
    view.next:SetPoint("LEFT", view.floorButton, "RIGHT", 4, 0)
    view.next:SetScript("OnClick", function() ShowFloor(view.floor + 1) end)
    view.bar = bar
end

local function BuildPort()
    -- la carte de l'étage : sa zone, découpée (zoomée, elle y reste)
    local port = CreateFrame("Frame", nil, view)
    port:SetPoint("TOPLEFT", GAP, -(HEAD_H + GAP))
    port:SetPoint("BOTTOMRIGHT", -(SIDE_W + 2 * GAP), GAP)
    port:SetClipsChildren(true)
    port:SetScript("OnSizeChanged", function() Layout() end)
    local well = port:CreateTexture(nil, "BACKGROUND")
    well:SetAllPoints()
    UI.Fill(well, "well", 0.9)
    view.port = port
    view.page = CreateFrame("Frame", nil, port)
    view.page:SetSize(PIC_W, PIC_H)
    view.page:SetPoint("CENTER")
    view.tiles = {}
    for i = 1, 12 do view.tiles[i] = view.page:CreateTexture(nil, "ARTWORK") end
    -- (un donjon dont le jeu n'a pas de carte : une page vide, et pourquoi)
    view.blank = view.page:CreateTexture(nil, "ARTWORK")
    view.blank:SetAllPoints()
    UI.Fade(view.blank, "VERTICAL", "panelBottom", 1, "panelTop", 1)
    view.blank:Hide()
    -- (par-dessus la carte, si loin qu'elle soit zoomée : son liseré, et le texte de la page vide)
    local over = CreateFrame("Frame", nil, view)
    over:SetAllPoints(port)
    over:SetFrameLevel(view:GetFrameLevel() + 8)
    UI.Border(over, "panelEdge", 1)
    view.blankText = UI.DimText(over, L.DUNGEON_NO_MAP, "GameFontNormalLarge")
    view.blankText:SetPoint("CENTER")
    view.blankText:SetWidth(420)
    view.blankText:Hide()
    view.over = over
end

local function BuildSide()
    local side = UI.Inset(view)
    side:SetPoint("TOPRIGHT", -GAP, -(HEAD_H + GAP))
    side:SetPoint("BOTTOMRIGHT", -GAP, GAP)
    side:SetWidth(SIDE_W)
    side:SetFrameLevel(view:GetFrameLevel() + 6)
    side:EnableMouse(true)
    side:EnableMouseWheel(true)
    side.title = UI.Text(side, "GameFontNormalLarge")
    side.title:SetPoint("TOPLEFT", 12, -12)
    side.title:SetPoint("RIGHT", side, "RIGHT", -12, 0)
    side.title:SetJustifyH("LEFT")
    side.title:SetWordWrap(false)
    side.sub = UI.DimText(side)
    side.sub:SetPoint("TOPLEFT", side.title, "BOTTOMLEFT", 0, -5)
    side.sub:SetPoint("RIGHT", side, "RIGHT", -12, 0)
    side.sub:SetJustifyH("LEFT")
    side.tabs = {}
    for _, t in ipairs(TABS) do
        local b = UI.NavButton(side, TAB_H)
        b:SetLevel(2)
        b.key = t.key
        b.text:SetText(L[t.label])
        b:SetScript("OnClick", function(self) SelectTab(self.key) end)
        side.tabs[#side.tabs + 1] = b
    end
    local rule = UI.Rule(side)
    rule:SetPoint("TOPLEFT", 12, -(56 + TAB_H + 8))
    rule:SetPoint("TOPRIGHT", -12, -(56 + TAB_H + 8))
    side.scroll = UI.Scroll(side, nil, 48)
    side.child = side.scroll.child
    side.child:SetSize(SIDE_W - 40, 1)
    side.scroll:SetPoint("TOPLEFT", 12, -(56 + TAB_H + 16))
    side.scroll:SetPoint("BOTTOMRIGHT", -22, 12)
    side.pool = { row = {}, text = {}, button = {}, link = {}, thumb = {} }
    view.side = side
end

local function BuildHint()
    -- (comment revenir au monde, les premières fois)
    local hint = UI.Panel(view)
    hint:SetSize(1, 30)
    hint:SetPoint("BOTTOM", view.port, "BOTTOM", 0, 14)
    hint:SetFrameLevel(view:GetFrameLevel() + 12)
    hint.text = UI.Text(hint, "GameFontHighlightSmall", L.DUNGEON_HINT)
    hint.text:SetPoint("CENTER")
    hint.fade = hint:CreateAnimationGroup()
    local fade = hint.fade:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetStartDelay(5)
    fade:SetDuration(1.2)
    hint.fade:SetScript("OnFinished", function() hint:Hide() end)
    hint:Hide()
    view.hint = hint
end

local function Build()
    if view then return view end
    local host = ns.Map.View.Frame()
    if not host then return end
    view = CreateFrame("Frame", "MyMapIsRichDungeonView", host)
    local strata = ns.Map.View.Strata()
    if strata then view:SetFrameStrata(strata) end
    view:SetAllPoints(host)
    view:SetFrameLevel(VIEW_LEVEL)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    view:SetClipsChildren(true)
    local bg = view:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    UI.Fade(bg, "VERTICAL", "windowBottom", 0.98, "windowTop", 0.98)
    BuildBar()
    BuildPort()
    BuildSide()
    BuildHint()
    -- la souris : la molette zoome, tirer déplace, un clic droit revient au monde
    -- (la plume : tirer à gauche trace, à droite déplace)
    view:SetScript("OnMouseWheel", function(_, delta) Wheel(delta) end)
    view:SetScript("OnMouseDown", function(self, button)
        if self.markup and button == "LeftButton" then MarkStart() return end
        local x, y = GetCursorPosition()
        self.drag = { x, y, self.ox or 0, self.oy or 0, button = button }
    end)
    view:SetScript("OnMouseUp", function(self, button)
        local d = self.drag
        self.drag = nil
        if self.markup then
            if button == "LeftButton" then MarkFinish() end
            return
        end
        if button == "RightButton" then
            local x, y = GetCursorPosition()
            if not d or math.abs(x - d[1]) + math.abs(y - d[2]) <= 6 then DV.Close() end
        end
    end)
    view:SetScript("OnUpdate", function(self)
        if self.markup then MarkMove() end
        local d = self.drag
        if not d then return end
        if not IsMouseButtonDown(d.button) then self.drag = nil return end
        local x, y = GetCursorPosition()
        local es = self:GetEffectiveScale()
        self.ox, self.oy = d[3] + (x - d[1]) / es, d[4] + (y - d[2]) / es
        Layout()
    end)
    view:SetScript("OnHide", function(self)
        self.drag = nil
        EndMarkup()
        self.hint:Hide()
        GameTooltip:Hide()
    end)
    view:Hide()
    -- (le curseur de la manette presse ses onglets, ses boutons, ses boss)
    ns.Map.Cursor.AddRoot(view)
    return view
end

-- Ouvrir la carte d'un donjon ; pin : son entrée (d'où l'on revient) ;
-- inside : ouverte parce que tu es dedans
function DV.Open(inst, pin, inside)
    if not inst or not Build() then return false end
    local floors, source = DN.Floors(inst)
    if not floors or #floors == 0 then floors, source = DN.BLANK, nil end
    EndMarkup()
    if ns.PointCard and ns.PointCard.Shown() then ns.PointCard.Close() end
    UI.HideMenu()
    view.inst, view.floors, view.source = inst, floors, source
    view.inside = inside and true or false
    view.fromU, view.fromV = pin and pin.u, pin and pin.v
    -- le retour : la zone de l'entrée
    local chain = view.fromU and K.ChainAt(view.fromU, view.fromV)
    local info = chain and chain[#chain] and C_Map.GetMapInfo(chain[#chain])
    view.back:SetText("|cffffd100<|r  " .. (info and info.name and L.DUNGEON_BACK_TO:format(info.name) or L.DUNGEON_BACK))
    view.back:SetWidth(math.max(110, math.min(300, TextWidth(view.back:GetFontString()) + 28)))
    view.floor = nil
    view:Show()
    Sound("IG_QUEST_LOG_OPEN")
    ShowFloor(DN.FirstFloor(inst, floors), true)
    Fill()
    -- (les premières fois : comment revenir)
    local hints = Get("dungeonHints") or 0
    if hints < HINTS then
        Settings.Set("dungeonHints", hints + 1)
        view.hint:SetWidth(TextWidth(view.hint.text) + 28)
        view.hint:SetAlpha(1)
        view.hint:Show()
        view.hint.fade:Stop()
        view.hint.fade:Play()
    else
        view.hint:Hide()
    end
    return true
end

-- Revenir au monde. Ouverte dedans : le monde autour de l'entrée du donjon
function DV.Close(quiet)
    if not Shown() then return end
    if not quiet then Sound("IG_QUEST_LOG_CLOSE") end
    local inside = view.inside
    view:Hide()
    if inside and not quiet then
        local u, v, zoom = DN.EntranceView()
        local _, _, now = ns.Map.View.Now()
        if u and (zoom or now) then ns.Map.View.Show(u, v, zoom or now) end
    end
end

-- Les réglages ont changé : le panneau, les boss, les traits
function DV.Refresh()
    if not Shown() then return end
    -- (les cartes tirées de la minicarte allumées ou éteintes : d'autres étages)
    local floors, source = DN.Floors(view.inst)
    if not floors or #floors == 0 then floors, source = DN.BLANK, nil end
    if floors ~= view.floors then
        EndMarkup()
        view.floors, view.source = floors, source
        view.floor = nil
        ShowFloor(DN.FirstFloor(view.inst, floors), true)
    end
    Fill()
    RedrawPins()
    RedrawMarks()
end

---------------------------------------------------------------------------
-- Pour le reste de Plus (ns.Map.Dungeons) : la manette (Pad/Dungeon.lua),
-- le rail des calques, Pad/Focus.lua
---------------------------------------------------------------------------
-- La carte d'un donjon est ouverte, et son cadre
function DG.Shown() return Shown() end
function DG.Frame() return view end
function DG.Close(quiet) DV.Close(quiet) end
-- Le panneau du donjon (la manette y passe), la zone de la carte
function DG.Side() return Shown() and view.side or nil end
function DG.Port() return Shown() and view.port or nil end
-- Déplacer la carte de dx, dy px (vers la droite, vers le haut : on regarde plus loin de ce côté)
function DG.Pan(dx, dy)
    if not Shown() then return end
    view.ox = (view.ox or 0) - dx
    view.oy = (view.oy or 0) - dy
    Layout()
end
-- Zoomer d'un cran autour d'un point de l'écran (px ; rien : le milieu)
function DG.Zoom(delta, x, y) ZoomAt(delta, x, y) end
-- (fn() rend true, x, y quand la manette mène : la molette zoome autour de ce point)
function DG.SetWheelPoint(fn) wheelPoint = fn end
-- L'étage précédent ou suivant ; s'il y en a plusieurs
function DG.HasFloors() return Shown() and #view.floors > 1 or false end
function DG.Floor(dir)
    if not DG.HasFloors() then return false end
    ShowFloor(view.floor + (dir < 0 and -1 or 1))
    return true
end
-- L'onglet précédent ou suivant du panneau
function DG.SideTab(dir)
    if not Shown() then return false end
    local list = view.side.shownTabs or {}
    if #list == 0 then return false end
    local at = 1
    local tab = CurrentTab(TabsShown())
    for i, b in ipairs(list) do
        if b.key == tab then at = i end
    end
    local b = list[(at - 1 + (dir < 0 and -1 or 1)) % #list + 1]
    SelectTab(b.key)
    return true
end

ns.On("MAP_HIDE", function() DV.Close(true) end)

-- (une quête rendue ou acceptée, la carte d'un donjon ouverte : son onglet Quêtes suit le journal)
local questEvents = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_TURNED_IN", "QUEST_ACCEPTED" }) do pcall(questEvents.RegisterEvent, questEvents, e) end
questEvents:SetScript("OnEvent", function()
    if Shown() then C_Timer.After(0.5, function() if Shown() then Fill() end end) end
end)
