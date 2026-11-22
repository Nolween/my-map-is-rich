-- Généré par tools/hazards/build_hazards.ps1 : ne pas modifier à la main.
-- Les villes de l'autre faction, que les chemins à pied contournent (Travel/Nav.lua).
-- Source : Shortest Path Forever v1.45.2 de cjber (https://github.com/cjber/shortest-path-forever),
-- Data/TownAreas.lua, Data/Zones.lua et Data/ZoneCells.lua (lus dans les données du client). Données
-- dérivées, sous licence GPL-3.0-or-later (voir LICENSE).
--   towns[maître de vol] = { continent, i0, j0, w, h, cases } : le terrain que le client appelle du nom
--     de la ville, en morceaux de 100/3 yards (le morceau (i, j) couvre x dans [i, i + 1), y dans
--     [j, j + 1) fois 100/3) ; cases : w x h bits, x d'abord depuis (i0, j0), six bits par symbole
--     base64 (A-Za-z0-9+/), le plus fort d'abord.
--   capitals[carte] = { faction, continent, "i j n ..." } : les carrés de 64 yards de la capitale,
--     n carrés de la colonne i (x / 64) à partir de la ligne j (y / 64).
-- x vers le nord, y vers l'ouest (UnitPosition), en yards du monde.
local _, root = ...
local ns = root.Plus

ns.HazardData = {
	towns = {
		[4] = { 0, -322, 28, 9, 10, "Px/v/////////Pw" }, -- Sentinel Hill
		[7] = { 0, -118, -30, 13, 12, "DgHwP8f+//////////f/D+B8A4" }, -- Menethil Harbor
		[8] = { 0, -167, -95, 10, 8, "Dx9//39/Pz8/Pg" }, -- Thelsamar
		[10] = { 0, 12, 45, 7, 6, "c////88" }, -- The Sepulcher
		[11] = { 0, 39, -2, 21, 18, "A+AD/wH/4H/4P/8f/8//+///f///////////////////////f//f/+Af4AfgAeA" }, -- Ruins of Lordaeron
		[12] = { 0, -326, -41, 14, 10, "Hw/j/P9/3//7/v+f5/n+f4Hg" }, -- Darkshire
		[13] = { 0, -7, -33, 11, 11, "f9////////////9/5/x/A" }, -- Tarren Mill
		[14] = { 0, -31, -21, 12, 10, "HA+D8P//////////9/z/" }, -- Southshore
		[16] = { 0, -43, -82, 9, 11, "AcP8f4/x/n////5/g" }, -- Refuge Pointe
		[17] = { 0, -36, -111, 15, 8, "f39/f39/f39//////38/" }, -- Hammerfall
		[18] = { 0, -436, 9, 10, 12, "PwP4f8////f/f/f/H+B8" }, -- Booty Bay
		[19] = { 0, -436, 9, 10, 12, "PwP4f8////f/f/f/H+B8" }, -- Booty Bay
		[20] = { 0, -375, 1, 6, 9, "PD8/3/f5+" }, -- Grom'gol Base Camp
		[21] = { 0, -203, -70, 7, 7, "Pn//////A" }, -- Kargath
		[25] = { 1, -17, -83, 8, 8, "OHh8fv7//38" }, -- The Crossroads
		[26] = { 1, 189, 10, 10, 10, "Dx/P+/////fh+D4Hg" }, -- Auberdine
		[27] = { 1, 252, 25, 15, 8, "PH7//////////////n48" }, -- Rut'theran Village
		[28] = { 1, 71, -22, 20, 19, "A8AA+AA/wA/8A//A//4//+f//////////////////v//3//5//8//4P/wD/wAHwA" }, -- Astranaar
		[29] = { 1, 23, 22, 11, 12, "f8f+f/f/f/f/f/f///f/f/" }, -- Sun Rock Retreat
		[30] = { 1, -170, -77, 11, 9, "Ph8fj+///////74PA" }, -- Freewind Post
		[31] = { 1, -138, -24, 5, 2, "/8" }, -- Thalanaar
		[32] = { 1, -125, -146, 19, 19, "A+AA/gA/4A/8A/+Af/Af/wf/+P//H//x//+///f//v//3//7//55/4Af4AHwA" }, -- Theramore Isle
		[33] = { 1, 62, 31, 26, 33, "AH4AAAB/8QAAf///4P////D////4/////H////5/////f//g////8B////AP///4B////AP///8B////wMH///+A////wH///+A////AH///4A////AH///4Af///AD///wAf//8AD///AA" }, -- Stonetalon Peak
		[37] = { 1, -2, 32, 13, 11, "Pgfg/n/P/f////////n/H+P4" }, -- Nijel's Point
		[38] = { 1, -54, 89, 10, 10, "f9/3/////////j4GA" }, -- Shadowprey Village
		[39] = { 1, -219, -121, 13, 13, "H8H/v//////////f/n+B+A+AeAPAA" }, -- Gadgetzan
		[40] = { 1, -219, -121, 13, 13, "H8H/v//////////f/n+B+A+AeAPAA" }, -- Gadgetzan
		[41] = { 1, -140, 90, 15, 14, "/8P/j/8//n/9//f/3/9//f/3/9//f/wP4Dw" }, -- Feathermoon Stronghold
		[42] = { 1, -137, 0, 9, 12, "AGAeA+A/H+P+/+f+H8" }, -- Camp Mojache
		[43] = { 0, 5, -69, 8, 13, "B/n/3//j/1/4+8ff/A" }, -- Aerie Peak
		[44] = { 1, 105, -136, 11, 8, "fv///////v7+/v4" }, -- Valormok
		[45] = { 0, -335, -109, 10, 18, "HwAP+Gf/+f/+f/+//+/////Hf/HP/G" }, -- Nethergarde Keep
		[48] = { 1, 150, -13, 7, 4, "f///8" }, -- Bloodvenom Post
		[52] = { 1, 198, -146, 10, 11, "DAP8////////+/8/4/g" }, -- Everlook
		[53] = { 1, 198, -146, 10, 11, "DAP8////////+/8/4/g" }, -- Everlook
		[55] = { 1, -97, -90, 8, 10, "PB+P8/z//8fw/A" }, -- Brackenwall Village
		[56] = { 0, -319, -102, 10, 7, "//////////Hg" }, -- Stonard
		[58] = { 1, 98, 28, 5, 5, "d//3A" }, -- Zoram'gar Outpost
		[61] = { 1, 59, -79, 14, 9, "A4PH4/Hg4eHw+Hw+Hw+Bw" }, -- Splintertree Post
		[62] = { 1, 232, -83, 13, 13, "B3B/g/wf4H+D/H/n/3///7/4P8AeA" }, -- Nighthaven
		[63] = { 1, 232, -83, 13, 13, "B3B/g/wf4H+D/H/n/3///7/4P8AeA" }, -- Nighthaven
		[64] = { 1, 79, -118, 4, 4, "L+4" }, -- Talrendis Point
		[65] = { 1, 180, -66, 14, 14, "f/3/9//f/3/9//////7/+//P/z/48AOAA" }, -- Talonbranch Glade
		[66] = { 0, 26, -47, 4, 6, "///P" }, -- Chillwind Camp
		[67] = { 0, 62, -165, 12, 9, "Px////////////+/Dw" }, -- Light's Hope Chapel
		[68] = { 0, 62, -165, 12, 9, "Px////////////+/Dw" }, -- Light's Hope Chapel
		[70] = { 0, -229, -68, 5, 6, "cce//" }, -- Flame Crest
		[71] = { 0, -254, -87, 8, 8, "f3////9/Phg" }, -- Morgan's Vigil
		[72] = { 1, -208, 17, 8, 11, "AGP8f//z/D+D4DA" }, -- Cenarion Hold
		[73] = { 1, -208, 17, 8, 11, "AGP8f//z/D+D4DA" }, -- Cenarion Hold
		[74] = { 0, -198, -37, 6, 6, "/////f" }, -- Thorium Point
		[75] = { 0, -198, -37, 6, 6, "/////f" }, -- Thorium Point
		[76] = { 0, -21, -143, 7, 10, "/////f8/z/H8" }, -- Revantusk Village
		[77] = { 1, -75, -63, 8, 9, "/3+///////x8" }, -- Camp Taurajo
		[79] = { 1, -189, -39, 8, 9, "D4/H7///////" }, -- Marshal's Refuge
		[80] = { 1, -34, -116, 12, 13, "AD///////////////3/B8AeAOA" }, -- Ratchet
		[559] = { 1, 151, -119, 25, 24, "AAA4AAH8AAf+AH//Af//Af/+A//+B//4D//wH//gP//gf//g///g///w///4///4///4H//4D//8D//8B//8A5/8AB/8AAf4AAHw" }, -- Summit of Eternity
		[3203] = { 0, -241, -146, 5, 7, "////9+" }, -- Rog'mar
		[3242] = { 1, 130, -105, 15, 23, "AAB+AAP8AA/4AH/hwf/H//+f//5///z///n///H//+H//4H//gH/4AAMAA" }, -- Tainted Foothills
		[3276] = { 0, -282, -156, 13, 14, "GAB4A/+f/3/9//f///7/8//H/h/wP8A" }, -- Farholde Keep
	},
	capitals = {
		[1453] = { "Alliance", 0, "-143 4 13 -142 4 23 -141 4 23 -140 4 23 -139 4 23 -138 4 23 -137 0 27 -136 0 27 -135 0 27 -134 0 27 -133 4 23 -132 4 23 -131 4 23 -130 4 23 -129 17 10 -128 17 10 -127 17 10 -126 17 10" }, -- Stormwind
		[1454] = { "Horde", 1, "21 -75 13 22 -75 13 23 -75 13 24 -75 13 25 -79 17 26 -79 17 27 -79 17 28 -79 17 29 -79 8 30 -79 8 31 -79 8 32 -79 8" }, -- Orgrimmar
		[1455] = { "Alliance", 0, "-79 -21 9 -78 -21 9 -77 -21 9 -76 -21 9 -75 -21 9 -74 -21 9 -73 -21 9 -72 -21 9" }, -- Ironforge
		[1456] = { "Horde", 1, "-24 -4 8 -23 -4 8 -22 -4 8 -21 -8 12 -20 -8 12 -19 -8 12 -18 -8 12" }, -- Thunder Bluff
		[1457] = { "Alliance", 1, "149 33 9 150 29 13 151 29 13 152 29 13 153 29 13 154 29 13 155 29 13 156 29 13 157 29 13 158 33 5 159 33 5" }, -- Darnassus
		[1458] = { "Horde", 0, "19 -1 9 20 -1 9 21 -1 9 22 -1 9 23 -1 9 24 -1 9 25 -1 9 26 -1 9 27 -1 9 28 -1 9" }, -- Undercity
	},
}
