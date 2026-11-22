--------------------------------------------------------------------------------
-- Init: loaded last. Settings at ADDON_LOADED; the map and its slash commands
-- at PLAYER_LOGIN. (0.6.0 : plus d'AceConfig ; les réglages de la carte sont
-- l'onglet Carte de /mmir, Plus/UI/MapPage.lua.)
--
--   /mmir carte                the map's settings (Plus/Core.lua)
--   /mmir carte status         what the map is doing
--   /mmir carte pins           the map pins (Pins.lua)
--   /mmir carte draw           the quill: draw on the map (Sketch.lua)
--------------------------------------------------------------------------------

local ADDON, ns = ...
if ns.loadMs.start then ns.loadMs.files = debugprofilestop() - ns.loadMs.start end

-- (true : la commande était l'une des siennes ; false : Plus ouvre les réglages de la carte)
local function Slash(msg)
	local raw = (msg or ""):match("^%s*(.-)%s*$")
	msg = raw:lower()
	local mod = ns:GetModule("worldmap")
	local word, rest = msg:match("^(%S+)%s+(.+)$")
	local takes = {}
	if takes[word] then msg, rest = word, raw:match("^%S+%s+(.+)$") end
	-- (My Map Is Rich 0.5.0 : paint, notes, debug, bench, news, welcome, highlights et reset sont partis
	-- avec la carte classique et les outils d'OpenMap ; 0.10.0 : entrance, dungeons et bosses, avec
	-- Map/Dungeons.lua)
	local run = {
		status = "Diag", pins = "TogglePins", draw = "ToggleSketch", forgetflights = "ForgetFlights",
		warm = "ToggleWarm",
	}
	-- (the controller view's diagnostics: it runs while OpenMap's usual map is off, PadView.lua)
	if msg == "padview" and mod.PadViewDiag then mod.PadViewDiag() return true end
	-- the controller view's map (PadView.lua): what works on it, its status its own
	if run[msg] and mod.padWaits and mod.PadViewOn and mod.PadViewOn() then
		local onView = { pins = true, draw = true }
		if msg == "status" and mod.PadViewDiag then mod.PadViewDiag()
		elseif onView[msg] and mod[run[msg]] then mod[run[msg]](mod)
		elseif not mod.db.classicMap then ns:Print(ns.L["That isn't available on the full-screen map yet."])
		else ns:Print(ns.L["That isn't available with the Gamepad UI yet."]) end
		return true
	end
	if run[msg] then
		if mod.enabled and mod[run[msg]] then mod[run[msg]](mod, takes[msg] and rest or nil)
		elseif mod.padWaits and not mod.db.classicMap then ns:Print(ns.L["That isn't available on the full-screen map yet."])
		elseif mod.padWaits then ns:Print(mod.PadOffText())
		else ns:Print(ns.L["The map is off."]) end
		return true
	end
	return false
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
		-- (la page d'Options > AddOns est celle de Plus/UI/Options.lua, qui ouvre /mmir ; les
		-- commandes de la carte passent par /mmir carte : Plus/Core.lua appelle ns.MapSlash)
	end
end)

-- /mmir carte <…> : les anciennes commandes d'OpenMap (status, pins, draw, dungeons...)
ns.MapSlash = Slash
