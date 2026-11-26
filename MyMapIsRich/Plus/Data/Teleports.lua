-- Généré par tools/teleports/build_teleports.ps1 : ne pas modifier à la main.
-- Les téléportations de classe que les itinéraires peuvent prendre (Travel/Planner.lua).
-- Source : Shortest Path Forever v1.45.13 de cjber (https://github.com/cjber/shortest-path-forever),
-- Data/Teleports.lua. Données dérivées, sous licence GPL-3.0-or-later (voir LICENSE).
--   { spell, cont, x, y (où le sort pose, en yards du monde), cast (s), reagent (l'objet qu'il demande) }
-- x vers le nord, y vers l'ouest (UnitPosition).
local _, root = ...
local ns = root.Plus

ns.TeleportData = {
	{ spell = 3561, cont = 0, x = -9003.46, y = 870.031, cast = 10, reagent = 17031 }, -- Teleport: Stormwind
	{ spell = 3562, cont = 0, x = -4613.62, y = -915.38, cast = 10, reagent = 17031 }, -- Teleport: Ironforge
	{ spell = 3563, cont = 0, x = 1773.47, y = 61.121, cast = 10, reagent = 17031 }, -- Teleport: Undercity
	{ spell = 3565, cont = 1, x = 9664.14, y = 2526.36, cast = 10, reagent = 17031 }, -- Teleport: Darnassus
	{ spell = 3566, cont = 1, x = -964.98, y = 283.433, cast = 10, reagent = 17031 }, -- Teleport: Thunder Bluff
	{ spell = 3567, cont = 1, x = 1469.85, y = -4221.52, cast = 10, reagent = 17031 }, -- Teleport: Orgrimmar
	{ spell = 18960, cont = 1, x = 7991.88, y = -2679.84, cast = 10 }, -- Teleport: Moonglade
}
