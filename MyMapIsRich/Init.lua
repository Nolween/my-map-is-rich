--------------------------------------------------------------------------------
-- Init: loaded last. Settings at ADDON_LOADED; the map, options and slash
-- commands at PLAYER_LOGIN.
--
--   /mmir carte         options
--   /mmir carte status         what the map is doing
--   /mmir carte notes          map notes (paint areas, say what's there, export them)
--   /mmir carte debug          the debug overlay (frame rate, frame times, what OpenMap costs)
--   /mmir carte bench [zoom]   times the map at several zooms, each part off in turn (Bench.lua)
--   /mmir carte pins           the map pins (Pins.lua)
--   /mmir carte news           what's new in this version (News.lua)
--   /mmir carte draw           the quill: draw on the map (Sketch.lua)
--   /mmir carte dungeons       which map each dungeon entrance opens (Dungeons.lua)
--   /mmir carte entrance <name>  where you stand, as a dungeon entrance for tools/map-data (Dungeons.lua)
--   /mmir carte highlights     where the game draws each zone's highlight, for tools/map-preview (Debug.lua)
--------------------------------------------------------------------------------

local ADDON, ns = ...
if ns.loadMs.start then ns.loadMs.files = debugprofilestop() - ns.loadMs.start end

local function Options()
	local mod = ns:GetModule("worldmap")
	local args = mod.Options and mod:Options() or {}
	args.enabled = { type = "toggle", name = ns.L["Enable My Map Is Rich"], order = 0, width = "full",
		desc = ns.L["Turning My Map Is Rich off takes a reload."],
		get = function() return mod.db.enabled end,
		set = function(_, v) mod.db.enabled = v; ns:Print(ns.L["Takes effect after a /reload."]) end }
	args.padWaits = { type = "description", order = 0.5, fontSize = "medium",
		name = function() return "|cffff8040" .. mod.PadOffText() .. "|r" end,
		hidden = function() return not mod.padWaits or not mod.db.classicMap or (mod.PadViewOn and mod.PadViewOn()) or false end }
	return { type = "group", name = "|cff" .. ns.ACCENT .. "My Map Is Rich|r " .. ns.version, args = args }
end

-- OpenMap's settings are the map's own menu (Panel.lua); with the map off (no menu), the options window,
-- which can turn it back on
local function OpenOptions()
	local mod = ns:GetModule("worldmap")
	if mod.enabled and mod.OpenMenu and mod:OpenMenu() then return end
	local ACD = LibStub("AceConfigDialog-3.0", true)
	if ACD then ACD:Open("My Map Is Rich") end
end
ns.OpenOptions = OpenOptions

local function Slash(msg)
	local raw = (msg or ""):match("^%s*(.-)%s*$")
	msg = raw:lower()
	local mod = ns:GetModule("worldmap")
	local word, rest = msg:match("^(%S+)%s+(.+)$")
	local takes = { bench = true, entrance = true }  -- (/mmir carte bench 16: at that zoom; /mmir carte entrance Dire Maul - East)
	if takes[word] then msg, rest = word, raw:match("^%S+%s+(.+)$") end
	local run = {
		status = "Diag", paint = "TogglePaint", notes = "TogglePaint", debug = "ToggleDebugOverlay",
		bench = "Bench", pins = "TogglePins", news = "ToggleNews", entrance = "Entrance", draw = "ToggleSketch", dungeons = "DungeonDiag", bosses = "ToggleBossPlacer", forgetflights = "ForgetFlights",
		welcome = "ShowWelcome", highlights = "Highlights", warm = "ToggleWarm",
		reset = "ResetWindow",   -- (reset: the windowed map's size and place, for one off the screen)
	}
	-- (the controller view's diagnostics: it runs while OpenMap's usual map is off, PadView.lua)
	if msg == "padview" and mod.PadViewDiag then return mod.PadViewDiag() end
	-- the controller view's map (PadView.lua): what works on it, its status its own
	if run[msg] and mod.padWaits and mod.PadViewOn and mod.PadViewOn() then
		local onView = { pins = true, draw = true, news = true }
		if msg == "status" and mod.PadViewDiag then mod.PadViewDiag()
		elseif onView[msg] and mod[run[msg]] then mod[run[msg]](mod)
		elseif not mod.db.classicMap then ns:Print(ns.L["That isn't available on the full-screen map yet."])
		else ns:Print(ns.L["That isn't available with the Gamepad UI yet."]) end
		return
	end
	if run[msg] then
		if mod.enabled and mod[run[msg]] then mod[run[msg]](mod, takes[msg] and rest or nil)
		elseif mod.padWaits and not mod.db.classicMap then ns:Print(ns.L["That isn't available on the full-screen map yet."])
		elseif mod.padWaits then ns:Print(mod.PadOffText())
		else ns:Print(ns.L["The map is off."]) end
	else
		OpenOptions()
	end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == ADDON then
		ns:InitDB()
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		-- (OpenMap ou OpenMap On Gamepad chargé aussi : en veille, la carte leur reste)
		local rival = ns.Conflict()
		if rival then
			ns.dormant = rival
			ns:Print(ns.L["%s is also enabled: My Map Is Rich stays off. Turn it off in the AddOns list, then /reload."], rival)
			return
		end
		local t0 = debugprofilestop and debugprofilestop()
		ns:EnableModules()
		if t0 then ns.loadMs.login = debugprofilestop() - t0 end
		local AC = LibStub("AceConfig-3.0", true)
		if AC then AC:RegisterOptionsTable("My Map Is Rich", Options) end
		-- (la page d'Options > AddOns est celle de Plus/UI/Options.lua, qui ouvre /mmir ; les
		-- commandes de la carte passent par /mmir carte : Plus/Core.lua appelle ns.MapSlash)
	end
end)

-- /mmir carte <…> : les anciennes commandes d'OpenMap (status, pins, news, draw, reset...)
ns.MapSlash = Slash

-- La fenêtre des réglages de la carte (AceConfig), même la carte fermée (le bouton « Réglages de la
-- carte » de /mmir : Plus/UI/MainFrame.lua)
function ns.OpenSettingsWindow()
	local ACD = LibStub("AceConfigDialog-3.0", true)
	if ACD then ACD:Open("My Map Is Rich") end
end

function ns.NotifyOptions()
	local ACR = LibStub("AceConfigRegistry-3.0", true)
	if ACR then ACR:NotifyChange("My Map Is Rich") end
end
