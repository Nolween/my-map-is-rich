# My Map Is Rich — consignes pour Claude

Add-on World of Warcraft pour **WoW Forever** (client 1.16.x, `## Interface: 16001…16200`, Lua 5.1).
Une carte du monde d'un seul tenant, jouable à la souris et **à la manette**, avec itinéraires, lieux et partage en groupe.
Né d'un fork d'**OpenMap** 0.8.11 (MIT) auquel on a ajouté tout **OpenMap On Gamepad** 0.6.0. Il s'en éloigne désormais : c'est un addon de la famille « … Is Rich » (My Guild Is Rich, My Gamepad Is Rich, My Auction House Is Rich), dans `G:\Addons Wow Dev\`.

Le [README.md](README.md) décrit les fonctions et la structure, la [CHARTE.md](CHARTE.md) l'apparence. Ce fichier dit **comment travailler**.

## Langue et ton

- Répondre en **français**. Les commentaires du code neuf, le CHANGELOG, la CHARTE et les messages de commit sont en français.
- Le style de la maison : des phrases courtes et concrètes, sans jargon, qui disent **ce que voit ou fait le joueur** (« Le panneau de trajet dit l'étape… »). Pas d'anglicismes quand un mot français existe (« addon » et les noms de boutons de manette restent).
- Le code venu d'OpenMap (`Core.lua`, `Map/`, `Init.lua`) garde ses commentaires en anglais et son indentation **par tabulations**. Le code de `Plus/` est indenté de **4 espaces**. On suit l'usage du fichier qu'on modifie.

## Les deux moitiés de l'addon

| | La carte | Plus |
|---|---|---|
| Origine | OpenMap 0.8.11, renommé | OpenMap On Gamepad 0.6.0 |
| Fichiers | `Core.lua`, `Map/`, `Data/Forever/`, `Locales/`, `Init.lua` | `Plus/` (`Map/`, `Pad/`, `Travel/`, `UI/`, `Data/`, `Locales/`) |
| Espace de noms | `root` (le `...` de l'addon) | `local _, root = ... ; local ns = root.Plus` en tête de **chaque** fichier |
| Textes | `ns.L["English text"]` | `ns.L.CLE` |
| Sauvegardes | `MyMapIsRichDB`, `MyMapIsRichCharDB` | `MyMapIsRichPlusDB` (`ns.db`, défauts dans `DEFAULTS` de `Plus/Core.lua`), `MyMapIsRichPlusCharDB` (`ns.char`, par personnage) |

- Plus atteint la carte **par `ns.Map` seulement** ([Plus/Map/Api.lua](MyMapIsRich/Plus/Map/Api.lua)), jamais par `root`, `GetModule` ou un global. Plus ne touche jamais `ns.L` / `ns.db` de la carte, et inversement.
- **L'ordre de chargement est celui du `.toc`** ([MyMapIsRich/MyMapIsRich.toc](MyMapIsRich/MyMapIsRich.toc)). Tout fichier ajouté s'y inscrit à sa place (une nouvelle langue avant `Plus\Locales\Init.lua`, un écran après `UI\Widgets.lua`…). Un fichier ajouté demande de **relancer le jeu** : `/reload` ne le charge pas.
- Ne pas modifier : `Data/Forever/` (généré par les outils d'OpenMap), `Plus/Data/` (généré par `tools/roads`, `tools/nav` et `tools/hazards`, voir le README). On régénère, on n'édite pas à la main.

## Se passer d'OpenMap (en cours depuis la 0.5.0)

Le code d'OpenMap est remplacé par le nôtre, une version par étape, l'addon jouable entre deux (l'état du chantier : [FEUILLE_DE_ROUTE.md](FEUILLE_DE_ROUTE.md), à tenir à jour à chaque étape) :
0.5.0 ménage et adaptateur `ns.Map` · 0.6.0 les réglages de la carte dans `/mmir` (fait : l'onglet Carte, `Plus/UI/MapPage.lua` ; plus de menu d'OpenMap, d'Ace3 ni de `Launcher.lua`) · 0.7.0 coordonnées et épingles (fait : `Plus/Map/Coords.lua`, `Plus/Layers/MyPins.lua`, `PinsWindow.lua` ; le point de destination attend la 0.9.0, avec `Nav.lua`) · 0.8.0 vols, bateaux, zeppelins (fait : `Plus/Layers/Flights.lua`, `Boats.lua` ; les quais passent dans `Boats.lua` en 0.13.0) · 0.9.0 quêtes, citadins, groupe, point de destination, niveaux de zone (fait : `Plus/Layers/Quests.lua`, `Townsfolk.lua`, `Group.lua`, `Waypoint.lua`, `Locate.lua`, `ZoneInfo.lua` ; le reste d'`Extras.lua`, la barre de coordonnées, le fondu, la limite d'images de la carte classique et les icônes de HereBeDragons, part avec la vue en 0.12.0) · 0.10.0 donjons (fait : `Plus/Layers/Dungeons.lua`, `DungeonView.lua` ; les traits de la plume sur la carte d'un donjon sont gardés avec la plume) · 0.11.0 la plume (fait : `Plus/Layers/Sketch.lua`, dans `MyMapIsRichPlusDB.map.sketch`) · 0.12.0 la vue (fait : `Plus/Map/View.lua`, `Cursor.lua`, `Look.lua`, `Hbd.lua` ; le module « worldmap » n'est plus qu'une table de sauvegardes, créée dans `Core.lua` pour `Close.lua`) · 0.13.0 les icônes (fait : `Plus/Map/PinSets.lua` ; les quais dans `Layers/Boats.lua`) · 0.14.0 le dessin de la carte (le reste de `Stitch`) · 0.15.0 le zoom rapproché (`Close`) · 1.0.0 plus de `Core.lua`, `Init.lua`, `Locales/`, `Libs/`.
- Un module réécrit va dans `Plus/Map/` (le moteur) ou `Plus/Layers/` (les calques), en code de Plus, et ses écrans suivent la CHARTE. Il remplace **le bloc de `Plus/Map/Api.lua`** qui appelait OpenMap, sans changer ce que voit le reste de Plus ; le fichier d'OpenMap qu'il remplace se supprime dans le même changement.
- Une clé de réglage reprise passe à `"new"` dans `OWNER` ([Plus/Map/Settings.lua](MyMapIsRich/Plus/Map/Settings.lua)), et ce que le joueur avait se copie une fois par `ns.Map.Migrate` (épingles, dessins, vols appris…). **On n'efface jamais l'ancien** : `MyMapIsRichDB` et `MyMapIsRichCharDB` restent déclarés dans le `.toc`.
- Les textes d'un module réécrit passent dans `Plus/Locales/` (10 langues), en reprenant les traductions de l'ancien `Locales/xxXX.lua`.
- Restent pour l'instant, comme simples données : les tables de `Data/Forever/` et les textures de `Media/Textures/Forever/` (tirées des images de Blizzard par les outils d'OpenMap, MIT). Les dessins de Santiago Reyes, faits pour OpenMap, ont été retirés : on ne les remet pas.

## Traduction : les 10 langues, toujours

Tout texte vu par le joueur passe par `L` et existe dans les **10 langues du client** : `enUS` (référence), `frFR`, `deDE`, `esES` (sert aussi à `esMX`), `itIT`, `ptBR`, `ruRU`, `koKR`, `zhCN`, `zhTW`.
Aucune chaîne en dur dans le code, même pour un message de discussion ou une info-bulle.

**Dans `Plus/Locales/`** (le système de My Guild Is Rich : `ns.AddLocale(code, { CLE = "texte" })`) :
- Une clé ajoutée l'est **dans les 10 fichiers dans le même changement**, à la même place (même section, même ordre que `enUS.lua`), traduite pour de vrai. Pas de « TODO », pas de copie de l'anglais.
- Les `%s` / `%d` gardent **le même ordre** que l'anglais (`string.format` n'a pas d'arguments numérotés).
- Ne se traduisent pas : les commandes (`/mmir lieux`), les noms de boutons et de touches (A, B, LB, RT, R3, View, F9…), « My Map Is Rich » et les noms des autres addons.
- Les clés gardent leur préfixe de rubrique : `HINT_`, `OPT_`, `TRAVEL_`, `HUD_`, `PLACES_`, `SHARE_`, `STATUS_`, `WHATSNEW_`…
- Les noms du jeu (zones, PNJ, objets) viennent de l'API du jeu, déjà traduits ; on ne les met pas dans les Locales.
- La longueur compte : l'allemand et le russe sont plus longs, le coréen et le chinois plus courts. Un bouton ou une colonne doit tenir en allemand.
- **Dette connue (0.1.0)** : `enUS` et `frFR` ont 378 clés, les 8 autres langues 213 ; il en manque 165 (aide, réglages, trajets, partage, diagnostics). Quand on touche une rubrique, on complète ses clés manquantes dans les 8 langues.

**Dans `Locales/`** (la carte, d'OpenMap) : `L["English text"] = "traduction"`, un fichier par langue, **`esMX` compris** (11 fichiers sans l'anglais, qui est la clé elle-même), rangés à peu près par ordre alphabétique de la clé. Ils étaient générés par `tools/locale/translate.py` d'OpenMap, qui n'est pas dans ce dépôt : on les édite désormais à la main (une phrase nouvelle à sa place alphabétique), et une phrase ajoutée au code de la carte l'est dans les 10 fichiers.

**Dans le `.toc`** : `## Notes` existe en anglais et en `Notes-xxXX` pour les 10 autres codes (`esMX` compris). Une fonction majeure ajoutée ou retirée se reporte dans les 11.

## Charte graphique

Tout écran neuf, et tout écran refait, suit [CHARTE.md](CHARTE.md) (la même que My Guild Is Rich, My Gamepad Is Rich et OpenMap On Gamepad). L'essentiel :
- **Aucune texture du jeu en fond** (`BasicFrameTemplate`, `UIPanelButtonTemplate`, `UIPanelScrollFrameTemplate`, marbre…) : des aplats et dégradés dessinés par l'addon.
- Brun très sombre, liserés d'un pixel, **or `#ffd100`** pour le titre, la sélection, ce qui est trouvé. Polices du jeu `GameFont…` : or pour les libellés, blanc pour les valeurs, gris pour le secondaire.
- **Une couleur se prend par sa clé** dans `UI.COLORS` (`UI.Fill`, `UI.Fade`, `UI.Border`, `UI.Tint`, `UI.OnTheme`), jamais en chiffres, sinon elle ne suit pas les 5 thèmes (Brun, Gris clair, Bleu foncé, Vert foncé, Rose). Seules l'or et les couleurs à sens (`good`, `bad`, pastilles de boutons) s'écrivent en chiffres.
- On construit avec les composants de [Plus/UI/Widgets.lua](MyMapIsRich/Plus/UI/Widgets.lua) (`UI.Inset`, `UI.Button`, `UI.NavButton`, `UI.Dialog`, `UI.Scroll`, `UI.Check`, `UI.Input`…) avant d'en écrire un nouveau. Un composant nouveau va dans `Widgets.lua` et dans le tableau des composants de la CHARTE.
- Panneaux séparés de 6 px (`UI.PAGE_GAP`), marges intérieures de 10 à 16 px, positions calculées depuis le panneau. Une liste vide dit pourquoi, en gris.
- Toutes les fenêtres venues d'OpenMap y sont passées : les épingles (0.7.0), la carte d'un donjon (0.10.0), le plateau de la plume (0.11.0).
- Toute règle nouvelle de la charte s'écrit dans CHARTE.md, en français.

## Règles du jeu (taint, combat, manette)

- **Rien n'est écrit dans les cadres de Blizzard** : seulement `hooksecurefunc` et `HookScript`. Pas de remplacement de fonction globale du jeu.
- **Aucune fenêtre de l'addon dans `UISpecialFrames`** : l'interface manette de Forever la parcourt et bloquerait B au nom de l'addon. B ferme les fenêtres de l'addon par [Plus/Pad/Focus.lua](MyMapIsRich/Plus/Pad/Focus.lua).
- **En combat** (`InCombatLockdown()`) : pas de création ni de déplacement de cadres protégés, pas de changement de raccourcis ; on attend `PLAYER_REGEN_ENABLED`. La manette rend la main au jeu au début d'un combat.
- **Tout écran se joue à la manette** : ses éléments sont atteignables à la croix (focus de `Pad/Focus.lua`, `ns.Map.Cursor.AddRoot` pour les fenêtres sur la carte), A / B / X ont un sens, et la barre d'aide (`UI/HintBar.lua`) annonce les boutons avec leurs pastilles (`UI/Glyphs.lua`).
- **La veille** : si OpenMap ou OpenMap On Gamepad est activé, My Map Is Rich n'accroche rien (`ns.Conflict()` dans `Core.lua`). Tout nouveau point d'accroche passe par ce test.
- **Les préfixes de messages entre joueurs ne changent pas** (`OpenMap`, `OMGPRoute`) : ils font passer épingles et destinations entre les trois addons (`OpenMapLoc`, les positions d'amis, est parti avec les amis en 0.5.0). Un format de message qui change reste lisible par les versions d'avant.
- Les dépendances facultatives (Questie, My Gamepad Is Rich, Leatrix_Maps…) se testent avant usage ; l'addon marche sans aucune.
- Une API qui peut manquer sur Forever se teste (`if C_ChatInfo and C_ChatInfo.X then`) ou passe par `pcall`.
- Les globaux nouveaux sont préfixés `MyMapIsRich` ; tout le reste est `local`.

## Publier une version

Une version suit le schéma `X.Y.Z` (la première est la 0.1.0). Dans le même changement :
1. `## Version` dans [MyMapIsRich/MyMapIsRich.toc](MyMapIsRich/MyMapIsRich.toc) (c'est elle que lit `build.ps1`).
2. Une entrée `## X.Y.Z` **en tête** de [CHANGELOG.md](CHANGELOG.md), en français, pour le joueur : ce qui change et où le trouver.
3. La fenêtre Nouveautés ([Plus/UI/WhatsNew.lua](MyMapIsRich/Plus/UI/WhatsNew.lua)) : la version en tête de `NOTES` (5 au plus, on retire la plus ancienne) et sa clé `WHATSNEW_MMIR_X_Y_Z` **dans les 10 langues**.
4. Si l'onglet Découvrir change (un projet, un lien), [Plus/UI/Projects.lua](MyMapIsRich/Plus/UI/Projects.lua) se reporte dans les autres addons, qui ont le même fichier.
5. `.\build.ps1` écrit `..\Releases\MyMapIsRich\MyMapIsRich-<version>.zip`.

Commits : seulement quand on le demande, sur le modèle `Version X.Y.Z : résumé en français` (ou une phrase en français pour un changement hors version).

## Vérifier

- Pas de Lua ni de luacheck sur ce poste : relire soigneusement les fins de blocs (`end`), les virgules des tables de Locales et les guillemets dans les traductions (une apostrophe typographique ou un `"` non échappé casse tout le fichier, donc toute la langue).
- [.luacheckrc](.luacheckrc) existe et parle de `.github/workflows/luacheck.yml`, mais ce workflow **n'est pas encore dans ce dépôt** (il est dans My Guild Is Rich : à reprendre si on le demande).
- Test en jeu par la jonction décrite dans le README (`K:\World of Warcraft\_forever_\Interface\AddOns\MyMapIsRich`). Diagnostics : `/mmir etat`, `/mmir sonde`, `/mmir sonde carte`, `/mmir test`, `/mmir focus`, `/mmir carte status`.
- Après un changement, dire au joueur s'il faut `/reload` ou relancer le jeu (fichier ajouté au `.toc`).

## Fichiers partagés avec les autres addons

Ces fichiers existent, presque identiques, dans My Guild Is Rich, My Gamepad Is Rich et OpenMap On Gamepad. Un changement de fond se signale pour être reporté ailleurs :
- `Plus/UI/Widgets.lua` (repris de My Auction House Is Rich) et la CHARTE ;
- `Plus/UI/Projects.lua`, `Plus/UI/DonateTab.lua` (onglet Découvrir) ;
- `Plus/UI/WhatsNew.lua` (fenêtre Nouveautés) ;
- `Plus/Locales/Locales.lua` (le système de traduction).

## Licences

My Map Is Rich est sous **GPL-3.0-or-later** (à cause des données de marche de Shortest Path Forever, de cjber). Le code de la carte reste sous MIT (`LICENSES/OpenMap.txt`), crédits d'OpenMap dans la fenêtre Crédits ([Plus/UI/Credits.lua](MyMapIsRich/Plus/UI/Credits.lua), un texte par langue : `CREDITS_TEXT`). Ace3 n'est plus livré depuis la 0.6.0 (`LICENSES/Ace3.txt` reste, à retirer si on le décide). Ces fichiers ne se suppriment pas, et un code repris d'ailleurs ajoute sa licence et son crédit.
