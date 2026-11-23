--------------------------------------------------------------------------------
-- Init: loaded last. Settings at ADDON_LOADED; the map and its slash commands
-- at PLAYER_LOGIN. (0.6.0 : plus d'AceConfig ; les réglages de la carte sont
-- l'onglet Carte de /mmir, Plus/UI/MapPage.lua.)
--
--   /mmir carte                the map's settings (Plus/Core.lua)
--   /mmir carte status         what the map's view is doing (Plus/Map/View.lua)
--   /mmir carte pins           the map pins (Plus/Layers/MyPins.lua)
--   /mmir carte draw           the quill: draw on the map (Plus/Layers/Sketch.lua)
--------------------------------------------------------------------------------

local ADDON, ns = ...
if ns.loadMs.start then ns.loadMs.files = debugprofilestop() - ns.loadMs.start end

-- (true : la commande était l'une des siennes ; false : Plus ouvre les réglages de la carte)
local function Slash(msg)
	local raw = (msg or ""):match("^%s*(.-)%s*$")
	msg = raw:lower()
	local mod = ns:GetModule("worldmap")
	-- (My Map Is Rich 0.5.0 : paint, notes, debug, bench, news, welcome, highlights et reset sont partis
	-- avec la carte classique et les outils d'OpenMap ; 0.10.0 : entrance, dungeons et bosses ; 0.12.0 :
	-- warm, et padview devient status. Ce que font les autres : les ponts de Plus, Plus/Layers/ et Plus/Map/)
	local run = { status = "Diag", padview = "Diag", pins = "TogglePins", draw = "ToggleSketch", forgetflights = "ForgetFlights" }
	local fn = run[msg] and mod and mod[run[msg]]
	if fn then
		fn(mod)
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
