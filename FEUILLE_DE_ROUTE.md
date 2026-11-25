# Feuille de route — se passer d'OpenMap

My Map Is Rich est né d'un fork d'OpenMap 0.8.11. Le but : retirer tout le code d'OpenMap et refaire les mêmes fonctions avec le nôtre, aux couleurs de la [CHARTE](CHARTE.md).

On avance **une version par étape**, et l'addon reste jouable entre deux. Les règles du chantier sont dans [CLAUDE.md](CLAUDE.md), à la section « Se passer d'OpenMap », et le détail pour le joueur dans le [CHANGELOG](CHANGELOG.md).

État au 23 novembre 2026 : **1.0.0, le chantier est fini.** Les douze étapes sont faites (la 0.13.0 prévue, le dessin et les icônes, a été coupée en deux : les icônes, puis le dessin). Il ne reste plus une ligne de code d'OpenMap qui tourne à part : tout est dans `Plus/`. Restent ses données (`Data/Map/`, `Media/Map/`) et le code de son dessin, porté (`Plus/Map/Art.lua`, `Close.lua`).

## Comment on avance

- **L'adaptateur** ([Plus/Map/Api.lua](MyMapIsRich/Plus/Map/Api.lua)) : Plus n'atteint la carte que par `ns.Map`. Chaque étape remplace un bloc de l'adaptateur par du code neuf, sans rien changer pour le reste de Plus.
- **Les passerelles** : un module neuf branchait ses fonctions sur l'ancien `mod` d'OpenMap, à l'évènement `MAP_ATTACHED`, pour que le code d'OpenMap qui restait continue de marcher. Elles sont toutes parties en 1.0.0.
- **Les réglages** ([Plus/Map/Settings.lua](MyMapIsRich/Plus/Map/Settings.lua)) : une clé reprise vit désormais dans `MyMapIsRichPlusDB.map` (ou dans `MyMapIsRichPlusCharDB.map` pour un personnage). Ce que le joueur avait est copié une seule fois, par `ns.Map.Migrate`. **On n'efface jamais l'ancien.**
- **Les données** gardées : les tables de `Data/Map/` et les textures de `Media/Map/` (jusqu'à la 0.15.0 : `Data/Forever/` et `Media/Textures/Forever/`).

## Fait

| Version | Étape | Code neuf | Code d'OpenMap retiré |
|---|---|---|---|
| 0.5.0 | Ménage et adaptateur | `Plus/Map/Api.lua`, `Settings.lua` ; `MyMapIsRichPlusCharDB` | La carte classique (`Chart`, `Paint`, `Window`, `Compat`, `Combat`), `Friends`, `News`, `Welcome`, `Report`, `Debug`, `Bench`, `API.lua` ; le cache `MapZones` (225 Mo), les dessins de Santiago Reyes, l'icône d'OpenMap |
| 0.6.0 | Les réglages de la carte dans `/mmir` | L'onglet Carte (`Plus/UI/MapPage.lua`), les Crédits (`UI/Credits.lua`), les raccourcis (`UI/KeyBindings.lua`), le bouton du compartiment | `Map/Panel.lua`, `Launcher.lua`, `Credits.lua`, Ace3 (`Libs/`) |
| 0.7.0 | Coordonnées et épingles | `Plus/Map/Coords.lua`, `Plus/Layers/MyPins.lua`, `PinsWindow.lua` (à la charte) ; `/mmir sonde carte` | `Map/Pins.lua` |
| 0.8.0 | Vols, bateaux, zeppelins | `Plus/Layers/Flights.lua`, `Boats.lua` | `Map/Flights.lua`, `Routes.lua` |
| 0.9.0 | Quêtes, citadins, groupe, point de destination | `Plus/Layers/Quests.lua`, `Townsfolk.lua`, `Group.lua`, `Waypoint.lua`, `Locate.lua`, `ZoneInfo.lua` | `Map/Nav.lua`, `Quests.lua`, `Townsfolk.lua`, une partie d'`Extras.lua` |
| 0.10.0 | Donjons | `Plus/Layers/Dungeons.lua`, `DungeonView.lua` (à la charte) ; `Pad/Dungeon.lua` passe par `ns.Map.Dungeons` | `Map/Dungeons.lua` ; les commandes `entrance`, `dungeons`, `bosses` |
| 0.11.0 | La plume | `Plus/Layers/Sketch.lua`, son plateau à la charte ; tirer à la souris trace, tirer à droite déplace la carte | `Map/Sketch.lua` ; les ponts d'épingles qui ne servaient qu'à elle |
| 0.12.0 | La vue | `Plus/Map/View.lua` (la vue plein écran, la souris, la manette), `Cursor.lua` (le curseur de la manette), `Look.lua` (les réglages de l'aspect), `Hbd.lua` (les icônes de Questie et des autres addons, les chemins de Questie) ; les calques appelés directement, plus par des ponts | `Map/PadView.lua`, `Gamepad.lua`, `Extras.lua`, `WorldMap.lua` ; `/mmir carte warm` |
| 0.13.0 | Les icônes | `Plus/Map/PinSets.lua` (les jeux d'icônes, leurs ancres, le tri de ce qui est en vue, la taille des icônes, « seulement les lieux trouvés », ta flèche) ; les quais dans `Layers/Boats.lua`, les entrées de donjon posées par `Layers/Dungeons.lua` | Le moteur d'icônes et les lieux de `Map/Stitch.lua` (environ 530 lignes) |
| 0.14.0 | Le dessin de la carte | `Plus/Map/Art.lua` : le dessin d'OpenMap porté tel quel (son code inchangé, vérifié ligne à ligne ; ses 646 commentaires traduits), ses données par `ns.Map.Data.All()` | `Map/Stitch.lua` |
| 0.15.0 | Le zoom rapproché | `Plus/Map/Close.lua` : la minicarte sous les zones, les villes, les grottes et les trous du dessin, porté tel quel (code vérifié ligne à ligne, commentaires traduits) ; ses 8 réglages dans `MyMapIsRichPlusDB.map` ; le dessin passe par `ns.Map.ArtTable()`, plus de « MapStitch » | `Map/Close.lua` ; le dossier `Map/` est vide |
| 1.0.0 | Fin d'OpenMap | La veille (`ns.Conflict()`) et `/mmir carte <…>` dans `Plus/Core.lua` ; `Plus/Map/Data.lua` (les lectures sûres, les tuiles des grottes et des donjons, l'accès aux tables) ; le chemin des textures dans `Plus/Init.lua` ; les réglages de la carte tous dans `MyMapIsRichPlusDB.map`, nettoyés à la déconnexion ; les données dans `Data/Map/` et `Media/Map/` | `Core.lua`, `Init.lua`, `Locales/` (10 fichiers), `Data/Forever/Client.lua` et `Tiles.lua` ; le module « worldmap » et toutes les passerelles ; `ns.Map.Legacy` |

Ce que le joueur a perdu, par choix :
- la carte classique ;
- les amis et la guilde sur la carte (`OpenMapLoc`) ;
- News, Welcome et Report ;
- `MyMapIsRichAPI` ;
- la recherche de `Nav.lua`, remplacée par les lieux ;
- les outils de développement d'OpenMap.

## Après la 1.0.0

Plus d'étape prévue : la feuille de route est finie. Pistes pour la suite, sans ordre :
- **Simplifier le dessin** : `Plus/Map/Art.lua` (près de 3 000 lignes) et `Close.lua` sont portés tels quels ; une réécriture plus simple, à faire une fois tout testé en jeu, en comparant à l'écran.
- **Nos propres outils de données** : refaire `Data/Map/` et `Media/Map/` sans les outils d'OpenMap. Aucune table n'est devenue inutile : le dessin les lit toutes (`Grade`, `Tones`, `ArtEdits` compris).
- **Des commentaires** de `Plus/Pad/` (`Focus.lua`, `MapNav.lua`, `Bindings.lua`, `Camera.lua`) parlent encore du menu et des fichiers d'OpenMap, partis depuis : à relire quand on y touche.

## Idées venues des autres addons Forever

En novembre 2026, on a lu sur CurseForge une vingtaine d'addons Forever qui touchent aux cartes et aux quêtes : Queston, QuestForever, QuestSpot, Forever Quest Pins, Forever Simple Quests, Forever Quest Routes, BuddiesQuestForever, Loreward, Quest TLDR, Quester, Forever Wayfinder, Adventure Guide, Legacy Forever, Dungeon Quests Forever, 4Ever Leveling… On en a tiré ce qui manque à My Map Is Rich. ★★★ très utile, ★★ utile, ★ plus tard.

| # | Ce que voit le joueur | Vu dans | Chez nous | |
|---|---|---|---|---|
| 1 | Les « ! », « ? » et objectifs proches sur la **minicarte** (option : suivies seulement) | QuestForever, Simple Quests, Queston, QuestSpot | le placement de `Travel/Minimap.lua`, les jeux de `Layers/QuestMarks.lua` | ★★★ |
| 2 | Une **icône au-dessus des monstres et PNJ** utiles (épée, sac, « ! », « ? ») | QuestSpot, Forever Quest Pins, Queston | `NAME_PLATE_UNIT_ADDED`, le `npcID` du GUID ; une texture à nous à côté de la plaquette, `issecretvalue` | ★★★ |
| 3 | L'**info-bulle** d'un monstre, PNJ ou objet dit la quête et où on en est (« 3/10 ») | QuestForever, Forever Quest Pins, Quest TLDR | `TooltipDataProcessor` ou `HookScript`, `Quests/Db.lua` et `Log.lua` | ★★★ |
| 4 | Les **camps** : des apparitions proches font un seul marqueur, au centre | Simple Quests, QuestForever, Forever Quest Pins | un regroupement dans QuestMarks, à la place de la réduction au-delà de `MANY` | ★★★ |
| 5 | La **zone de chasse** dessinée, qui rétrécit avec l'objectif | Forever Quest Routes, Queston, BuddiesQuest | l'enveloppe d'un camp, dessinée comme la plume (`Layers/Sketch.lua`) | ★★ |
| 6 | Les marqueurs **d'une seule quête** : toutes, suivies ou celle choisie ; les autres s'estompent | Simple Quests (« Spotlight ») | un filtre dans QuestMarks, branché sur `UI/QuestPanel.lua` | ★★★ |
| 7 | Des **« ! » qui en disent plus** : répétable, donjon, classe, élite, chaîne 2/5 ; niveau et XP dans l'info-bulle | Forever Quest Pins, QuestSpot, QuestForever | les champs de `Db`, `ns.ZoneInfo.LevelColor` | ★★ |
| 8 | **Cacher un marqueur** depuis son menu, le rétablir dans l'onglet Carte | Forever Quest Pins, Simple Quests, QuestSpot | `ns.char`, un filtre dans `Offers.List()` | ★★★ |
| 9 | **Apprendre** une quête absente de la base (donneur, endroit), oublier un « ! » démenti ; `/mmir quetes export` pour `forever_fixes.json` | QuestForever, QuestSpot, Forever Quest Routes, Quester | `QUEST_DETAIL`, `GOSSIP_SHOW`, `QUEST_ACCEPTED` | ★★★ |
| 10 | **Pourquoi pas de « ! »** : `/mmir pourquoi <quête>` (et l'info-bulle d'un « ! » bientôt prêt) | Forever Quest Pins (`why`) | la règle qui refuse, rendue par `Quests/Offers.lua` | ★★ |
| 11 | Les quêtes **bientôt prêtes** (un ou deux niveaux, une étape avant) en « ! » violet grisé | Simple Quests, QuestForever | Offers, une règle relâchée d'un cran | ★★ |
| 12 | **Ordonner la file** au plus court ; tout le journal dans la file | Forever Quest Routes, Queston, Adventure Guide | la file, `TravelPlanner.Find`, un ordre glouton | ★★★ |
| 13 | La **pierre de foyer** dans l'itinéraire quand elle est prête et rapproche | Forever Quest Routes, Loreward, BuddiesQuest | `GetBindLocation`, la recharge de l'objet 6948, un départ de plus dans `Travel/Planner.lua` | ★★★ |
| 14 | **Le plus proche** : aubergiste, réparateur, maître de vol, formateur, boîte aux lettres, avec le temps | Queston, Loreward | les citadins (`Layers/Townsfolk.lua`), le Planner, `UI/Places.lua` | ★★★ |
| 15 | **Où aller ensuite ?** Les zones à ton niveau, le nombre de quêtes à prendre, le temps pour y aller | Forever Wayfinder, QuestSpot, Adventure Guide | `Offers.List()` par zone, `Data/Map/Levels.lua`, le Planner | ★★ |
| 16 | La **chaîne d'une quête** dans sa fiche : étapes cochées, qui donne la suivante | Forever Quest Routes, Forever Wayfinder, Adventure Guide | `nextInChain` et les prérequis de `Db` | ★★ |
| 17 | Le **bouton de l'objet de quête**, avec raccourci et bouton de manette | Forever Quest Routes, Dungeon Quests Forever | un `SecureActionButton` créé et changé hors combat, `Bindings.xml` | ★★ |
| 18 | **Cibler le monstre** de l'objectif d'un appui | Quester, BuddiesQuest, Dungeon Quests Forever | le même bouton protégé, `/targetexact` | ★★ |
| 19 | **Abandonner les quêtes grises** en lot, après confirmation | Simple Quests, Forever Quest Routes | l'abandon du menu d'une quête, en lot | ★ |
| 20 | Les **quêtes de donjon sans Questie** : à prendre (et le donneur), en cours, faites | Dungeon Quests Forever, BuddiesQuest, 4Ever Leveling | `DN.QuestSource` de `Layers/Dungeons.lua` lit encore Questie : passer à `Quests/Db.lua` | ★★★ |

Plus tard : le taux d'exploration des zones, les sous-zones non découvertes et les défis Legacy (Legacy Forever, QuestSpot) ; les livres de bibliothèque et secrets de Forever (ForeverSecrets) ; les quêtes du groupe sur la carte (un préfixe de message **neuf**, sans toucher à `OpenMap` ni `OMGPRoute`) ; « 12 / 40 quêtes faites » sous le nom de la zone.
Écarté : accepter et rendre tout seul, vendre les gris, les guides de montée en niveau complets, le meilleur équipement, l'heure des bateaux (pas de donnée sûre), le mode sans spoilers.

Par lots :
1. **La carte et les données** : 4, 6, 8, 10, 20 (rien de protégé).
2. **Hors de la carte** : 1, 3, puis 2.
3. **Le trajet** : 13, 14, 12, 15.
4. **Le reste** : 7, 9, 11, 16, 17, 18, 19, 5.

**Les 20 sont écrites (novembre 2026), rien n'est encore testé en jeu.** Ce qui diffère de l'idée de départ :
- 12 : la file se rangeait déjà au plus court à chaque ajout ; il reste « Tout mon journal dans la file », en bas de l'onglet File.
- 14 : les PNJ de service viennent désormais de la base des quêtes (`services`, tiré des drapeaux de Questie) ; la boîte aux lettres n'y est pas (Questie la tient dans son code). Les citadins du rail lisent encore Questie : ils pourraient passer à cette base.
- 7 : ni l'expérience ni « Élite » (la base ne les a pas).
- 16 : la chaîne est une liste dans la fiche, sans « < > ».
- 10 : pas de ligne dans la fiche d'une quête (une quête du journal est déjà prise) : la raison est dans `/mmir pourquoi` et l'info-bulle des « ! » bientôt prêts.
- Après relecture : le calque Quêtes a ses détails sur deux colonnes (ils ne tenaient plus dans la hauteur de la carte).

- 2 : les « ! » et « ? » ne se voient que si les plaques de nom des PNJ amicaux sont affichées (réglage du jeu).
- 9 : l'export va dans deux entrées neuves de `forever_fixes.json`, `addQuests` et `addNpcs`, que `build_quests.py` lit.
- Les nouveaux fichiers (`Quests/Learn.lua`, `Layers/QuestMinimap.lua`, `Layers/QuestUnits.lua`, `UI/QuestButtons.lua`) demandent de relancer le jeu.

## Dettes et décisions en attente

- **Rien n'est encore testé en jeu, de la 0.5.0 à la 1.0.0.** Chaque version a sa liste « En jeu » dans le plan. Les vérifications de base :
  - `/mmir etat`, `/mmir sonde carte`, `/mmir test`, `/mmir focus` ;
  - tout à la souris **et** à la manette ;
  - un client anglais ;
  - les sauvegardes avant et après migration (`WTF\…\SavedVariables`).
- **Des portages, pas des réécritures** : `Plus/Map/Art.lua` (le dessin) et `Close.lua` (le zoom rapproché) sont le code d'OpenMap porté tel quel, et `View.lua`, `Hbd.lua`, `Cursor.lua`, `PinSets.lua` en reprennent de près la logique. Ils sont désormais à nous (Plus, commentaires en français, sous la licence MIT d'OpenMap qui reste créditée), mais une vraie réécriture du dessin, plus simple, reste possible une fois tout testé en jeu.
- **Les traductions** : il manque **63 clés** dans les 8 langues hors `enUS` et `frFR` (895 clés, 1.1.0). Elles sont dans les rubriques `STATUS_`, `SHARE_`, `TEST_`, `CAMERA_`, `WHATSNEW_`, `HUD_`, `TIME_` et `SEARCH_`. On complète une rubrique quand on la touche.
- **`LICENSES/Ace3.txt`** : Ace3 n'est plus livré depuis la 0.6.0. Garder ou retirer ce fichier reste à décider.
- **luacheck** : `.luacheckrc` existe (il laisse de côté `Data/` et `Plus/Data/`, générés), mais le workflow `.github/workflows/luacheck.yml` est encore dans My Guild Is Rich. Il est à reprendre.
- **Les archives** : `build.ps1` n'a pas été lancé pour les versions 0.5.0 à 1.0.0.
