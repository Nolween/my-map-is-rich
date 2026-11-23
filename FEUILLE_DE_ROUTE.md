# Feuille de route — se passer d'OpenMap

My Map Is Rich est né d'un fork d'OpenMap 0.8.11. Le but : retirer tout le code d'OpenMap et refaire les mêmes fonctions avec le nôtre, aux couleurs de la [CHARTE](CHARTE.md).

On avance **une version par étape**, et l'addon reste jouable entre deux. Les règles du chantier sont dans [CLAUDE.md](CLAUDE.md), à la section « Se passer d'OpenMap », et le détail pour le joueur dans le [CHANGELOG](CHANGELOG.md).

État au 23 novembre 2026 : **0.15.0**. Onze étapes sur douze sont faites (la 0.13.0 prévue, le dessin et les icônes, a été coupée en deux : les icônes, puis le dessin). Le dossier `Map/` d'OpenMap est vide : tout le moteur de la carte est dans `Plus/Map/`.

## Comment on avance

- **L'adaptateur** ([Plus/Map/Api.lua](MyMapIsRich/Plus/Map/Api.lua)) : Plus n'atteint la carte que par `ns.Map`. Chaque étape remplace un bloc de l'adaptateur par du code neuf, sans rien changer pour le reste de Plus.
- **Les passerelles** : un module neuf branche ses fonctions sur l'ancien `mod` d'OpenMap, à l'évènement `MAP_ATTACHED`. Le code d'OpenMap qui reste (`Core.lua`, `Init.lua`) continue donc de marcher. Ces passerelles partent avec lui.
- **Les réglages** ([Plus/Map/Settings.lua](MyMapIsRich/Plus/Map/Settings.lua)) : une clé reprise vit désormais dans `MyMapIsRichPlusDB.map` (ou dans `MyMapIsRichPlusCharDB.map` pour un personnage). Ce que le joueur avait est copié une seule fois, par `ns.Map.Migrate`. **On n'efface jamais l'ancien.**
- **Les données** gardées pour l'instant : les tables de `Data/Forever/` et les textures de `Media/Textures/Forever/`.

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

Ce que le joueur a perdu, par choix :
- la carte classique ;
- les amis et la guilde sur la carte (`OpenMapLoc`) ;
- News, Welcome et Report ;
- `MyMapIsRichAPI` ;
- la recherche de `Nav.lua`, remplacée par les lieux ;
- les outils de développement d'OpenMap.

## Reste à faire

| Version | Étape | Ce qui part | Ce qu'il faut écrire |
|---|---|---|---|
| 1.0.0 | Fin d'OpenMap | `Core.lua`, `Init.lua`, `Locales/` (10 fichiers) | `ns.Conflict()` dans `Plus/Core.lua`. `Data.lua` remplace `Client.lua` et `Tiles.lua`. Les données vont dans `Data/Map/` et `Media/Map/`, sans les tables devenues inutiles. Mise à jour du README, de la CHARTE, de CLAUDE.md et de `LICENSES/` |

Il reste **388 lignes** de code d'OpenMap (`Core.lua` : le module, les sauvegardes, la veille ; `Init.lua` : `/mmir carte`), plus les 10 fichiers de `Locales/` (des traductions que Plus n'utilise presque plus).

## Dettes et décisions en attente

- **Rien n'est encore testé en jeu, de la 0.5.0 à la 0.15.0.** Chaque version a sa liste « En jeu » dans le plan. Les vérifications de base :
  - `/mmir etat`, `/mmir sonde carte`, `/mmir test`, `/mmir focus` ;
  - tout à la souris **et** à la manette ;
  - un client anglais ;
  - les sauvegardes avant et après migration (`WTF\…\SavedVariables`).
- **Des portages, pas des réécritures** : `Plus/Map/Art.lua` (le dessin) et `Close.lua` (le zoom rapproché) sont le code d'OpenMap porté tel quel, et `View.lua`, `Hbd.lua`, `Cursor.lua`, `PinSets.lua` en reprennent de près la logique. Ils sont désormais à nous (Plus, commentaires en français, sous la licence MIT d'OpenMap qui reste créditée), mais une vraie réécriture du dessin, plus simple, reste possible une fois tout testé en jeu.
- **Les traductions** : il manque **108 clés** dans les 8 langues hors `enUS` et `frFR` (710 clés). Elles sont surtout dans les rubriques `TRAVEL_`, `WHY_`, `STATUS_`, `SHARE_`, `TEST_`, `CAMERA_` et `PROBE_`. On complète une rubrique quand on la touche.
- **`LICENSES/Ace3.txt`** : Ace3 n'est plus livré depuis la 0.6.0. Garder ou retirer ce fichier reste à décider.
- **luacheck** : `.luacheckrc` existe, mais le workflow `.github/workflows/luacheck.yml` est encore dans My Guild Is Rich. Il est à reprendre.
- **Les archives** : `build.ps1` n'a pas été lancé pour les versions 0.5.0 à 0.15.0.
- **Les données** : les tables et les textures tirées des images de Blizzard par les outils d'OpenMap (MIT) restent. Nos propres outils les remplaceront plus tard, hors de cette feuille de route.
