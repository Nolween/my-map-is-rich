-- Généré par tools/nav/build_nav.py : ne pas modifier à la main.
-- Les passages des itinéraires (Travel/Graph.lua) : un portail ou un tram entre deux points d'un
-- continent. Source : Shortest Path Forever v1.43.2 de cjber (Data/Portals.lua, Data/Transports.lua),
-- sous licence GPL-3.0-or-later (voir LICENSE).
-- { kind, name, faction, secs, a = { cont, x, y, couche }, b = { ... } } : on va dans les deux sens.
local _, root = ...
local ns = root.Plus

ns.Passages = {
	{ kind = "portal", name = "Darnassus", faction = "Alliance", secs = 10, a = { 1, 8799.4, 969.8, 0 }, b = { 1, 9947.5, 2630.0, 0 } },
	{ kind = "tram", name = "Deeprun Tram", faction = "Alliance", secs = 130, a = { 0, -8346.5, 514.0, 2 }, b = { 0, -4840.3, -1330.5, 1 } },
}
