# Feuille de route — se passer d'OpenMap

My Map Is Rich est né d'un fork d'OpenMap 0.8.11. Le but : retirer tout le code d'OpenMap et refaire les mêmes fonctions avec le nôtre, aux couleurs de la [CHARTE](CHARTE.md).

On avance **une version par étape**, et l'addon reste jouable entre deux. Les règles du chantier sont dans [CLAUDE.md](CLAUDE.md), à la section « D'où vient le code », et le détail pour le joueur dans le [CHANGELOG](CHANGELOG.md).

État au 25 novembre 2026 : **1.2.0. Le chantier est fini depuis la 1.0.0.** Les douze étapes sont faites (la 0.13.0 prévue, le dessin et les icônes, a été coupée en deux : les icônes, puis le dessin). Il ne reste plus une ligne de code d'OpenMap qui tourne à part : tout est dans `Plus/`. Restent ses données (`Data/Map/`, `Media/Map/`) et le code de son dessin, porté (`Plus/Map/Art.lua`, `Close.lua`).

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

Plus d'étape prévue : la feuille de route est finie. Depuis, la 1.1.0 a repris les vingt idées ci-dessous, et la 1.2.0 a ajouté un suivi des quêtes à nous (`UI/Tracker.lua`, à la place de celui du jeu), le progrès du groupe (`Quests/Party.lua`, préfixe `MMIRQuest`) et l'onglet Quêtes de `/mmir`.

Pistes pour la suite, sans ordre :
- **Simplifier le dessin** : un premier ménage est fait après la 1.2.0. `Plus/Map/Art.lua` passe de 2 973 à 2 376 lignes, `Close.lua` de 891 à 858. Sont partis : les branches des autres clients d'OpenMap (`ClientMaps`, `MapWorld`, `MapTerritories`, `MapBackLands`, `MapBlank`, `MapOff`, `MapUnder`, `MapPaperOut`), l'art des zones cuit en cases (`MapZoneArt`), la carte marine (`MapChart`), les trous peints à la main (`MapGapFills`) et les lieux peints dans les trous (`MapGapPlaces`), qui n'existent pas dans `Data/Map/` ; et les mesures de l'ancien `/mmir carte status` d'OpenMap, que plus rien ne lit. Rien ne devrait changer à l'écran : **à vérifier en jeu**. Une réécriture plus profonde reste possible, en comparant à l'écran.
- **Des fonctions du dessin perdues avec la vue d'OpenMap en 0.12.0** : `S.Recull` (revoir les villes à chaque ouverture de la carte, contre une ville restée cachée jusqu'à un `/reload`, #30 d'OpenMap) et `S.CaveRectAt` (zoomer plus loin sur une grotte, jusqu'à ce que sa carte remplisse la vue) sont rebranchées dans `View.lua` après la 1.2.0 (`Show`, `MostAt`) : **à vérifier en jeu**. `S.ResetShown` (de l'outil de mesure d'OpenMap, `Bench.lua`) et `S.CaveAt` (descendre dans la grotte d'une entrée de donjon sans carte, ce que fait désormais la fenêtre du donjon) sont retirées.
- **Nos propres outils de données** : refaire `Data/Map/` et `Media/Map/` sans les outils d'OpenMap. Aucune table n'est devenue inutile : le dessin les lit toutes (`Grade`, `Tones`, `ArtEdits` compris).
- **Les commentaires** de `Plus/Pad/` (`Focus.lua`, `MapNav.lua`, `Bindings.lua`, `Camera.lua`) qui parlaient du menu et des fichiers d'OpenMap renvoient au code d'aujourd'hui (après la 1.2.0).

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

Plus tard : le taux d'exploration des zones, les sous-zones non découvertes et les défis Legacy (Legacy Forever, QuestSpot) ; les livres de bibliothèque et secrets de Forever (ForeverSecrets) ; les quêtes du groupe sur la carte (le progrès du groupe est fait en 1.2.0, dans le suivi, par le préfixe neuf `MMIRQuest` ; reste à le montrer sur la carte) ; « 12 / 40 quêtes faites » sous le nom de la zone.
Écarté : accepter et rendre tout seul, vendre les gris, les guides de montée en niveau complets, le meilleur équipement, l'heure des bateaux (pas de donnée sûre), le mode sans spoilers.

Par lots :
1. **La carte et les données** : 4, 6, 8, 10, 20 (rien de protégé).
2. **Hors de la carte** : 1, 3, puis 2.
3. **Le trajet** : 13, 14, 12, 15.
4. **Le reste** : 7, 9, 11, 16, 17, 18, 19, 5.

**Les 20 sont écrites (1.1.0, novembre 2026), rien n'est encore testé en jeu.** Ce qui diffère de l'idée de départ :
- 12 : la file se rangeait déjà au plus court à chaque ajout ; il reste « Tout mon journal dans la file », en bas de l'onglet File.
- 14 : les PNJ de service viennent désormais de la base des quêtes (`services`, tiré des drapeaux de Questie) ; après la 1.2.0, s'y ajoutent les marchands, les autres maîtres, les esprits soigneurs, les monstres rares et les boîtes aux lettres (les objets « Mailbox »), et les citadins du rail lisent cette base : plus besoin de Questie.
- 7 : ni l'expérience ni « Élite » (la base ne les a pas).
- 16 : la chaîne est une liste dans la fiche, sans « < > ».
- 10 : pas de ligne dans la fiche d'une quête (une quête du journal est déjà prise) : la raison est dans `/mmir pourquoi` et l'info-bulle des « ! » bientôt prêts.
- Après relecture : le calque Quêtes a ses détails sur deux colonnes (ils ne tenaient plus dans la hauteur de la carte).

- 2 : les « ! » et « ? » ne se voient que si les plaques de nom des PNJ amicaux sont affichées (réglage du jeu).
- 9 : l'export va dans deux entrées neuves de `forever_fixes.json`, `addQuests` et `addNpcs`, que `build_quests.py` lit.
- Les nouveaux fichiers (`Quests/Learn.lua`, `Layers/QuestMinimap.lua`, `Layers/QuestUnits.lua`, `UI/QuestButtons.lua`) demandent de relancer le jeu.

## Idées venues de Polestar

Fin novembre 2026, on a lu [Polestar](https://github.com/fitzforge/polestar) 0.4.3.1, des guides de montée en niveau pour Forever avec son propre calcul d'itinéraire. On en reprend les chiffres et les règles, pas le code : son routeur (Polestar_Nav) est sous GPL-3.0-or-later, mais le reste de Polestar est sous GPL-3.0-only. Ce que Polestar tient lui-même de Shortest Path Forever (horaires des bateaux, alertes, bouton de voyage) s'étudie à la source, dans Shortest Path Forever. Polestar est crédité dans la fenêtre Crédits et dans `LICENSES/README.txt`.

| Version | Ce que voit le joueur | Où |
|---|---|---|
| 1.4.0 · la marche | (publiée, pas encore testée en jeu) **La pierre de foyer sort des itinéraires** (demandé par le joueur : son réglage et son étape s'en vont, l'auberge apprise est oubliée). **Trois styles de marche** : Le plus rapide, Équilibré (le défaut), Routes, aux prix de Polestar par terrain (route, pente douce, pente raide, intérieur, intérieur de cité), dans le réglage « Chemin à pied » et dans l'aperçu d'un itinéraire, qui montre les trois avec leur durée | `tools/nav/build_nav.py` (le format 4 de Shortest Path Forever, le terrain de chaque surface), `Travel/Nav.lua` (`Nav.STYLES`), `Travel/Planner.lua` (`Pl.Style`), `UI/PointCard.lua` ; `/mmir sonde terrain` |
| 1.4.0 · le voyage | (publiée, pas encore testée en jeu) **Les règles du voyage** de Polestar : vols à `longueur / 30 + 2` s par étape ; les téléportations de mage et de druide ; les zones trop hautes évitées (×3 à 4 niveaux de plus, ×20 au-delà de 10) ; un recalcul ne change de chemin que pour 20 s de gain ; « Plus rapide si tu avais le vol de X ». **Le bouton de voyage** (le sort de téléportation de l'étape, « Passer cette étape »). **Le maître de vol** : la prochaine étape marquée sur la carte des vols, « Prendre ce vol » | `Travel/Graph.lua`, `Planner.lua`, `Guide.lua`, `UI/RouteHud.lua` ; `Data/Teleports.lua` (nouveau, généré) ; `tools/hazards` (la zone de chaque morceau de 33 yd) |
| 1.4.0 · les bateaux | (publiée, pas encore testée en jeu) **Les bateaux** : les horaires appris en regardant passer bateaux, zeppelins et tram ; l'attente de chaque trajet ; une alerte avec la cloche du jeu à quai et avant ton arrêt | `Travel/Transit.lua` (nouveau), `Graph.lua` |

Plus tard :
- **Cadavre ou esprit guérisseur** : aller au plus rapide des deux, le mal de résurrection compté, une marge de 5 s.
- **Le style du tracé** : étapes suivantes plus pâles, vols en tirets, chevrons de sens, tracé qui s'efface derrière toi.
- **`/way`**, un remplaçant de TomTom, une petite API.
- **La cible de Polestar sur notre carte** : il dessine par `OpenMapAPI`, retiré chez nous en 0.5.0, ses épingles ne se voient pas sous notre vue.
- **Une épingle par zone vue de loin**, les rares repérés, Maj+clic sur la minicarte.

## Dettes et décisions en attente

- **Rien n'est encore testé en jeu, de la 0.5.0 à la 1.2.0.** Chaque version a sa liste « En jeu » dans le plan. Les vérifications de base :
  - `/mmir etat`, `/mmir sonde carte`, `/mmir test`, `/mmir focus` ;
  - tout à la souris **et** à la manette ;
  - un client anglais ;
  - les sauvegardes avant et après migration (`WTF\…\SavedVariables`).
- **Des portages, pas des réécritures** : `Plus/Map/Art.lua` (le dessin) et `Close.lua` (le zoom rapproché) sont le code d'OpenMap porté, débarrassé après la 1.2.0 de ce qui ne servait qu'aux autres clients, et `View.lua`, `Hbd.lua`, `Cursor.lua`, `PinSets.lua` en reprennent de près la logique. Ils sont désormais à nous (Plus, commentaires en français, sous la licence MIT d'OpenMap qui reste créditée), mais une vraie réécriture du dessin, plus simple, reste possible une fois tout testé en jeu.
- **Les traductions** : faites après la 1.2.0, les 10 langues ont leurs 970 clés. 47 clés traduites dans les 8 langues ; 8 clés que plus rien ne lisait retirées (`OPTIONS_COMBAT`, `PADVIEW_OFF_NOTE`, les nouveautés 0.2.0 à 0.6.0 d'OpenMap On Gamepad) ; 7 clés écrites deux fois dans `enUS` et `frFR` réunies ; 5 textes restés à l'ancienne version dans les 8 langues (`SETTINGS_DESC`, `OPT_ENABLED`...) remis à jour.
- **`LICENSES/Ace3.txt`** : retiré après la 1.2.0 (Ace3 n'est plus livré depuis la 0.6.0).
- **luacheck** : le workflow `.github/workflows/luacheck.yml` est repris de My Guild Is Rich (après la 1.2.0) : la syntaxe est vérifiée à chaque envoi. Reste à lui donner la liste des globales du jeu, pour ne plus ignorer les avertissements.
- **Les archives** : seules la 0.1.0, la 1.0.0 et la 1.1.0 ont la leur dans `..\Releases\MyMapIsRich\` ; `build.ps1` reste à lancer pour la 1.2.0.
