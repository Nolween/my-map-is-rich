-- Plus : la couche de My Map Is Rich reprise d'OpenMap On Gamepad (la
-- manette sur la carte, les itinéraires, les lieux, le groupe, la fenêtre
-- /mmir). Chargé avant tous les autres fichiers de Plus/.
--
-- L'espace de noms de l'addon (root) est celui de la carte (le code
-- d'OpenMap : Core.lua, Map/...). Plus vit dans root.Plus : chacun de ses
-- fichiers commence par « local _, root = ... ; local ns = root.Plus », si
-- bien que ses ns.L, ns.db, ns.UI, ns.Print... ne touchent jamais ceux de la
-- carte. Plus atteint la carte par ns.OM (= root : root:GetModule("worldmap"),
-- root.MapStitch...), comme OpenMap On Gamepad atteignait _G.OpenMap.
local _, root = ...
root.Plus = root.Plus or {}
