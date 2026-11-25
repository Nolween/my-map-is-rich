-- Les icônes de la carte : ses jeux d'icônes (et de traits), en code de My
-- Map Is Rich depuis la 0.13.0 (ils venaient de Map/Stitch.lua d'OpenMap).
-- Un jeu d'icônes est un groupe d'icônes qui gardent leur taille à l'écran :
-- chaque icône pend à une ancre invisible posée dans le dessin (en unités du
-- monde : ns.Map.Art.PlaceWorld), et leur calque est sur la vue, pas sur son
-- canevas : il ne change jamais d'échelle, un zoom ne fait que les déplacer.
-- Un jeu se montre s'il est allumé et que le zoom a atteint le sien.
-- Les icônes sont rangées en cases du monde (CELL de large) : seules celles
-- près de la vue sont montrées, un déplacement n'emporte pas toutes celles du
-- monde. Ici aussi : la taille des icônes, le zoom d'où viennent celles des
-- lieux, « seulement les lieux trouvés », les icônes cachées dans une
-- instance, et ta flèche.
local _, root = ...
local ns = root.Plus

local P = ns.Map.Pins
local A = ns.Map.Art

local CELL = 0.04                -- la largeur d'une case (le monde, 0..1)
local ARROW_SIZE = 28

local layer                      -- le calque des icônes, sur la vue
local arrow                      -- ta flèche, sur un cadre à elle (levé au-dessus de toutes les icônes)
local sets = {}                  -- clé -> { frame, on, minZoom, pins, lines, anchors, pinPool, linePool, cells }
local anchorPool = {}
local zoomNow = 1
local box                        -- la vue que le tri a vue en dernier : { u0, v0, u1, v1 }
local NONE = {}
local iconScale = 1
-- les icônes des lieux (donjons, quais, tours, maîtres de vol, citadins) dès
-- ce zoom au moins (nil : chacune dès le sien, « Auto ») ; celles du joueur
-- (épingles, dessins, groupe, point) ne sont jamais retenues. Cachées dans
-- une instance : celles du monde (world)
local places = { from = nil, hidden = false, foundOnly = false,
    sets = { dungeons = true, boats = true, zeppelins = true, flight = true },
    world = { boats = true, zeppelins = true, routes = true, flight = true, route = true, quests = true,
        qm_goal = true, qm_end = true, qm_offer = true } }
-- (les jeux des lieux qu'on trouve : « seulement les lieux trouvés »)
local FOUND = { "dungeons", "boats", "zeppelins" }
local player = {}
local playerHidden = false

---------------------------------------------------------------------------
-- Les ancres : une texture invisible posée dans le dessin, en unités du monde
---------------------------------------------------------------------------
local function Anchor(u, v)
    local W = A.Size()
    local e = 0.01 / (W or 1000)
    local a = table.remove(anchorPool) or A.Root():CreateTexture(nil, "BACKGROUND")
    a:SetAlpha(0)
    a:Hide()        -- (cachée, pas seulement transparente : une montrée se remet en page à chaque image d'un zoom)
    A.PlaceWorld(a, u, v, u + e, v + e)
    return a
end

local function MoveAnchor(a, u, v)
    local W = A.Size()
    local e = 0.01 / (W or 1000)
    A.PlaceWorld(a, u, v, u + e, v + e)
end

local function DropAnchor(a)
    A.UnplaceWorld(a)
    a:ClearAllPoints()
    anchorPool[#anchorPool + 1] = a
end

---------------------------------------------------------------------------
-- Les jeux d'icônes
---------------------------------------------------------------------------
local function Hidden(key) return places.hidden and places.world[key] or false end

local function ShowSets()
    for key, set in pairs(sets) do
        local from = set.minZoom
        local folk = key:sub(1, 3) == "tf_"
        -- (les citadins ne se montrent jamais de plus loin que leur propre zoom : ils sont des milliers)
        if places.from and (places.sets[key] or folk) then from = folk and math.max(from, places.from) or places.from end
        local shown = set.on and not Hidden(key)
            and math.max(zoomNow, 1) >= from and (not set.maxZoom or zoomNow < set.maxZoom)
        if shown and set.build then
            local build = set.build
            set.build = nil
            build(set)
        end
        if set.shownNow ~= shown then
            set.shownNow = shown
            set.frame:SetShown(shown)
        end
    end
end

-- Un jeu d'icônes à soi (créé une fois), ou celui d'un calque ; level : son niveau sur le calque
function P.Set(key, minZoom, level)
    if not layer then return end
    local set = sets[key]
    if not set then
        set = { frame = CreateFrame("Frame", nil, layer), on = true, minZoom = minZoom or 1,
            pins = {}, lines = {}, anchors = {}, pinPool = {}, linePool = {} }
        set.frame:SetAllPoints(layer)
        sets[key] = set
        if Hidden(key) then
            set.shownNow = false
            set.frame:Hide()
        end
    end
    if level then set.frame:SetFrameLevel(layer:GetFrameLevel() + level) end
    return set
end
function P.Get(key) return sets[key] end

-- Un jeu d'icônes allumé ou éteint
function P.SetOn(set, on)
    if type(set) ~= "table" then return end
    set.on = on and true or false
    ShowSets()
end

-- Ce que le jeu d'icônes construit la première fois qu'il se montre
function P.SetBuild(set, fn) if type(set) == "table" then set.build = fn end end

-- Une texture d'après son aspect : { atlas } ou { texture, coords }, size,
-- color, rotation ; un atlas que ce client n'a pas prend la texture, une
-- texture absente fallback
function P.Look(tex, look)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(1, 1, 1, 1)
    if look.atlas and (not C_Texture or not C_Texture.GetAtlasInfo or C_Texture.GetAtlasInfo(look.atlas)) then
        tex:SetAtlas(look.atlas)
    else
        local ok = tex:SetTexture(look.texture or look.fallback or "Interface\\Minimap\\ObjectIcons")
        if ok == false and look.fallback then tex:SetTexture(look.fallback) end
        if look.coords then tex:SetTexCoord(unpack(look.coords)) end
    end
    if look.color then tex:SetVertexColor(unpack(look.color)) end
    tex:SetRotation(look.rotation or 0)
end

-- (la case du monde d'une icône : montrée seulement près de la vue)
local function Cell(set, u, v)
    local i, j = math.floor(u / CELL), math.floor(v / CELL)
    set.cells = set.cells or {}
    local key = i * 4096 + j
    local cell = set.cells[key]
    if not cell then
        cell = CreateFrame("Frame", nil, set.frame)
        cell:SetAllPoints(set.frame)
        cell:SetFrameLevel(set.frame:GetFrameLevel())
        cell.u0, cell.v0 = i * CELL, j * CELL
        set.cells[key] = cell
        if box then
            cell.here = cell.u0 + CELL > box[1] and cell.u0 < box[3] and cell.v0 + CELL > box[2] and cell.v0 < box[4]
            cell:SetShown(cell.here)
        end
    end
    return cell
end

-- Une icône en un point du monde ; look : son aspect (P.Look). Les icônes
-- d'un jeu sont réutilisées : une icône reprise garde les champs que son
-- calque lui avait donnés
function P.Add(set, u, v, look, data)
    if type(set) ~= "table" or not u then return end
    local pin = table.remove(set.pinPool)
    if not pin then
        pin = CreateFrame("Button", nil, set.frame)
        pin.Icon = pin:CreateTexture(nil, "ARTWORK")
        pin.Icon:SetAllPoints()
        pin.Highlight = pin:CreateTexture(nil, "HIGHLIGHT")
        pin.Highlight:SetAllPoints()
        pin.Highlight:SetBlendMode("ADD")
        pin.Highlight:SetAlpha(0.3)             -- (un éclat léger, pas une flamme)
        -- (un clic : ce que la vue en fait, la fiche de Plus d'abord : Map/View.lua)
        pin:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and ns.Map.View.Press then ns.Map.View.Press(self) end
        end)
    end
    local size = look.size or 16
    pin:SetParent(Cell(set, u, v))
    pin:SetSize(size, size)
    pin:SetScale(iconScale)
    pin:SetFrameLevel(set.frame:GetFrameLevel())
    pin.anchor = Anchor(u, v)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", pin.anchor, "TOPLEFT")
    pin.u, pin.v, pin.data, pin.look = u, v, data, look
    P.Look(pin.Icon, look)
    P.Look(pin.Highlight, look)
    pin.Icon:SetDesaturated(false)
    pin.Icon:SetAlpha(1)
    pin:SetScript("OnEnter", nil)
    pin:SetScript("OnLeave", nil)
    pin.OnClick = nil
    pin.found = nil
    pin:EnableMouse(true)
    pin:Show()
    set.pins[#set.pins + 1] = pin
    return pin
end

-- Une icône déplacée (son ancre, pour qu'elle garde son survol)
function P.Move(set, pin, u, v)
    if pin.u == u and pin.v == v then return end
    MoveAnchor(pin.anchor, u, v)
    pin.u, pin.v = u, v
    local cell = Cell(set, u, v)
    if cell ~= pin:GetParent() then
        pin:SetParent(cell)
        pin:SetFrameLevel(set.frame:GetFrameLevel())
    end
end

local function Recycle(set, pin)
    pin:Hide()
    pin:ClearAllPoints()
    DropAnchor(pin.anchor)
    set.pinPool[#set.pinPool + 1] = pin
end

-- Une icône retirée de son jeu
function P.Remove(set, pin)
    for i, active in ipairs(set.pins) do
        if active == pin then
            Recycle(set, pin)
            table.remove(set.pins, i)
            return
        end
    end
end

-- Toutes les icônes, traits et points d'un jeu retirés
function P.Clear(set)
    if type(set) ~= "table" then return end
    for _, pin in ipairs(set.pins) do Recycle(set, pin) end
    for _, line in ipairs(set.lines) do
        line:Hide()
        set.linePool[#set.linePool + 1] = line
    end
    for _, a in ipairs(set.anchors) do DropAnchor(a) end
    wipe(set.pins)
    wipe(set.lines)
    wipe(set.anchors)
end

-- Un trait entre deux points du monde, épais de thickness px à l'écran
function P.Line(set, u1, v1, u2, v2, thickness, r, g, b, a, texture)
    if type(set) ~= "table" then return end
    local line = table.remove(set.linePool) or set.frame:CreateLine(nil, "ARTWORK")
    local a1, a2 = Anchor(u1, v1), Anchor(u2, v2)
    line:ClearAllPoints()
    line:SetStartPoint("TOPLEFT", a1)
    line:SetEndPoint("TOPLEFT", a2)
    line:SetThickness(thickness or 3)
    if texture then line:SetTexture(texture, "REPEAT", "CLAMP") else line:SetColorTexture(1, 1, 1, 1) end
    line:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    line:Show()
    set.lines[#set.lines + 1] = line
    set.anchors[#set.anchors + 1] = a1
    set.anchors[#set.anchors + 1] = a2
    return line
end

-- Un chemin par des points du monde { u1, v1, u2, v2, ... } (un trait de la
-- plume) : un trait entre chaque deux, qui partagent leurs ancres ; sub : son
-- sous-niveau, pour qu'un chemin passe sur un autre
function P.Path(set, pts, thickness, r, g, b, a, sub)
    if type(set) ~= "table" then return end
    local prev
    for i = 1, #pts - 1, 2 do
        local anchor = Anchor(pts[i], pts[i + 1])
        set.anchors[#set.anchors + 1] = anchor
        if prev then
            local line = table.remove(set.linePool) or set.frame:CreateLine(nil, "ARTWORK")
            line:SetDrawLayer("ARTWORK", sub or 0)
            line:ClearAllPoints()
            line:SetStartPoint("TOPLEFT", prev)
            line:SetEndPoint("TOPLEFT", anchor)
            line:SetThickness(thickness or 3)
            line:SetColorTexture(1, 1, 1, 1)
            line:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
            line:Show()
            set.lines[#set.lines + 1] = line
        end
        prev = anchor
    end
end

-- Un point simple (une texture, pas un bouton : les routes en ont des
-- centaines), sur le jeu ou sur parent (un cadre dedans)
function P.Dot(set, u, v, size, look, r, g, b, a, parent)
    if type(set) ~= "table" then return end
    local dot = (parent or set.frame):CreateTexture(nil, "ARTWORK")
    P.Look(dot, look)
    dot:SetVertexColor(r, g, b, a)
    dot:SetSize(size, size)
    local anchor = Anchor(u, v)
    dot:SetPoint("CENTER", anchor, "TOPLEFT")
    set.anchors[#set.anchors + 1] = anchor
    return dot
end

-- fn(u, v, hu, hv, zoom) à chaque déplacement ou zoom de la vue
function P.OnView(fn)
    if type(A.viewHooks) == "table" then table.insert(A.viewHooks, fn) end
end

-- Les icônes des jeux nommés dont le calque est montré (une liste de cadres ;
-- à chacun de voir lesquelles sont visibles à l'écran)
function P.Shown(keys)
    local out = {}
    for _, key in ipairs(keys or NONE) do
        local set = sets[key]
        if set and set.frame:IsVisible() then
            for _, pin in ipairs(set.pins) do out[#out + 1] = pin end
        end
    end
    return out
end

-- L'icône montrée la plus proche d'un point de l'écran (px), à reach px au
-- plus : pour le curseur de la manette, qui n'a pas de survol à lui
function P.At(x, y, reach)
    local best, bestD = nil, reach * reach
    for _, set in pairs(sets) do
        if set.frame:IsVisible() then
            for _, pin in ipairs(set.pins) do
                if pin:IsVisible() and pin:IsMouseEnabled() then
                    local cx, cy = pin:GetCenter()
                    if cx then
                        local es = pin:GetEffectiveScale()
                        local dx, dy = cx * es - x, cy * es - y
                        local d = dx * dx + dy * dy
                        if d < bestD then best, bestD = pin, d end
                    end
                end
            end
        end
    end
    return best
end

-- Ce que fait une icône quand on la choisit (celle de la carte : Map/View.lua)
function P.Action(pin) if ns.Map.View.PinAction then ns.Map.View.PinAction(pin) end end

-- La sorte d'une icône : "dungeon" (une entrée), "flight" (un maître de
-- vol), "action" (une icône qui fait quelque chose quand on la choisit), ou nil
function P.Kind(pin)
    if type(pin) ~= "table" then return end
    -- (pas pin.kind : les quais y mettent « boat » ou « zeppelin »)
    if pin.instances then return "dungeon" end
    if pin.node then return "flight" end
    if pin.OnClick then return "action" end
end

---------------------------------------------------------------------------
-- Les réglages des icônes (Map/Look.lua)
---------------------------------------------------------------------------
-- Toutes les icônes à k fois leur taille (chacune autour de son milieu : elle y est ancrée)
function P.SetIconScale(k)
    k = tonumber(k) or 1
    if k == iconScale then return end
    iconScale = k
    for _, set in pairs(sets) do
        for _, pin in ipairs(set.pins) do pin:SetScale(k) end
    end
end

-- Les icônes des lieux dès ce zoom (0 : chacune dès le sien)
function P.SetPlacesFrom(zoom)
    local z = tonumber(zoom) or 0
    places.from = z > 0 and math.max(1, z) or nil
    ShowSets()
end

-- Les icônes du monde cachées (dans une instance), sans toucher au choix de chaque calque
function P.SetWorldPinsHidden(hidden)
    places.hidden = hidden and true or false
    ShowSets()
end

-- « Seulement les lieux trouvés » : une entrée, un quai, une tour montrés une
-- fois exploré le sol où ils sont (le dessin le sait : Art.Found), une entrée
-- aussi une fois qu'on y est entré (Layers/Dungeons.lua)
function P.RefreshFound()
    for _, key in ipairs(FOUND) do
        local set = sets[key]
        for _, pin in ipairs(set and set.pins or NONE) do
            if pin.u then
                if places.foundOnly then
                    if not pin.found then
                        pin.found = (A.Found and A.Found(pin.u, pin.v))
                            or (ns.Dungeons and pin.instances and ns.Dungeons.Entered(pin)) or false
                    end
                    pin:SetShown(pin.found)
                else
                    pin:Show()
                end
            end
        end
    end
end

function P.SetFoundOnly(on)
    on = on and true or false
    if places.foundOnly == on then return end
    places.foundOnly = on
    P.RefreshFound()
end

---------------------------------------------------------------------------
-- Ta flèche
---------------------------------------------------------------------------
function P.PlacePlayer()
    if not arrow then return end
    if not player.u or playerHidden then arrow:Hide() return end
    local ox, oy = ns.Map.View.Offset(player.u, player.v)
    if not ox then arrow:Hide() return end
    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER", layer, "CENTER", ox, -oy)
    if player.facing then arrow:SetRotation(player.facing) end
    arrow:Show()
end

function P.SetPlayer(u, v, facing)
    player.u, player.v, player.facing = u, v, facing
    P.PlacePlayer()
end

function P.SetPlayerHidden(hidden)
    playerHidden = hidden and true or false
    P.PlacePlayer()
end

-- Ta flèche au-dessus de toutes les icônes, à ce niveau
function P.RaiseArrow(level)
    local f = arrow and arrow:GetParent()
    if f and f:GetFrameLevel() ~= level then f:SetFrameLevel(level) end
end

---------------------------------------------------------------------------
-- La mise en place, et ce que le dessin de la carte leur dit (Map/Art.lua :
-- le zoom, la vue triée, un lieu exploré)
---------------------------------------------------------------------------
-- La carte est dessinée et ses icônes en place
function P.Ready() return layer ~= nil and A.IsBuilt and A.IsBuilt() or false end

-- Le calque des icônes sur la vue, à ce niveau (Map/View.lua, juste après le dessin)
function P.Setup(view, level)
    if layer then return end
    layer = CreateFrame("Frame", nil, view)
    layer:SetAllPoints(view)
    layer:SetFrameLevel(level)
    if layer.SetClipsChildren then layer:SetClipsChildren(true) end
    arrow = CreateFrame("Frame", nil, layer):CreateTexture(nil, "OVERLAY", nil, 7)
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:Hide()
    -- (le zoom : quels jeux se montrent ; la vue triée : les cases près d'elle ; un lieu exploré)
    A.OnZoomIcons = function(zoom)
        zoomNow = zoom or zoomNow
        ShowSets()
    end
    A.OnCullIcons = function(u0, v0, u1, v1)
        box = box or {}
        box[1], box[2], box[3], box[4] = u0, v0, u1, v1
        for _, set in pairs(sets) do
            for _, cell in pairs(set.cells or NONE) do
                local here = cell.u0 + CELL > u0 and cell.u0 < u1 and cell.v0 + CELL > v0 and cell.v0 < v1
                if cell.here ~= here then
                    cell.here = here
                    cell:SetShown(here)
                end
            end
        end
    end
    A.RefreshFound = P.RefreshFound
end
