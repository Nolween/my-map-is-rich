# My Map Is Rich — consignes pour Claude

Add-on World of Warcraft pour **WoW Forever** (client 1.16.x, `## Interface: 16001…16200`, Lua 5.1).
Une carte du monde d'un seul tenant, jouable à la souris et **à la manette**, avec itinéraires, lieux et partage en groupe.
Né d'un fork d'**OpenMap** 0.8.11 (MIT) auquel on a ajouté tout **OpenMap On Gamepad** 0.6.0. Depuis la 1.0.0, tout son code est le nôtre : c'est un addon de la famille « … Is Rich » (My Guild Is Rich, My Gamepad Is Rich, My Auction House Is Rich), dans `G:\Addons Wow Dev\`.

Le [README.md](README.md) décrit les fonctions et la structure, la [CHARTE.md](CHARTE.md) l'apparence. Ce fichier dit **comment travailler**.

## Langue et ton

- Répondre en **français**. Les commentaires du code neuf, le CHANGELOG, la CHARTE et les messages de commit sont en français.
- Le style de la maison : des phrases courtes et concrètes, sans jargon, qui disent **ce que voit ou fait le joueur** (« Le panneau de trajet dit l'étape… »). Pas d'anglicismes quand un mot français existe (« addon » et les noms de boutons de manette restent).
- Le code est indenté de **4 espaces**, ses commentaires en français (ceux de `Plus/Map/Art.lua` et `Close.lua`, portés d'OpenMap, ont été traduits). Les fichiers générés de `Data/Map/` gardent leurs commentaires anglais.

## Comment l'addon est rangé

| | |
|---|---|
| Code | `Plus/` : `Map/` (le moteur de la carte), `Layers/` (ses calques), `Pad/`, `Travel/`, `UI/`, `Data/`, `Locales/` |
| Espace de noms | `local _, root = ... ; local ns = root.Plus` en tête de **chaque** fichier ; `root` ne porte que les données de `Data/Map/` (et `root.Media`, posé par `Plus/Init.lua`) |
| Textes | `ns.L.CLE` (`Plus/Locales/`) |
| Sauvegardes | `MyMapIsRichPlusDB` (`ns.db`, défauts dans `DEFAULTS` de `Plus/Core.lua` ; la carte dans `ns.db.map`), `MyMapIsRichPlusCharDB` (`ns.char`, par personnage) |
| Données | `Data/Map/` (les tables de la carte) et `Media/Map/` (ses textures), tirées du jeu par les outils d'OpenMap |

- Le reste de Plus atteint la carte **par `ns.Map`** ([Plus/Map/Api.lua](MyMapIsRich/Plus/Map/Api.lua)) et ses données **par `ns.Map.Data`** ([Plus/Map/Data.lua](MyMapIsRich/Plus/Map/Data.lua)), jamais par `root` ou un global.
- **L'ordre de chargement est celui du `.toc`** ([MyMapIsRich/MyMapIsRich.toc](MyMapIsRich/MyMapIsRich.toc)) : `Plus/Init.lua`, puis les données, puis le reste de Plus. Tout fichier ajouté s'y inscrit à sa place (une nouvelle langue avant `Plus\Locales\Init.lua`, un écran après `UI\Widgets.lua`…). Un fichier ajouté demande de **relancer le jeu** : `/reload` ne le charge pas.
- Ne pas modifier : `Data/Map/` et `Media/Map/` (générés par les outils d'OpenMap), `Plus/Data/` (généré par `tools/roads`, `tools/nav`, `tools/hazards`, `tools/teleports`, `tools/transit` et `tools/quests`, voir le README). On régénère, on n'édite pas à la main. La base des quêtes (`Plus/Data/Quests.lua`) se synchronise avec QuestieDB par la commande `/sync-quetes` ; nos corrections vont dans `tools/quests/forever_fixes.json`.

## D'où vient le code (OpenMap, de la 0.5.0 à la 1.0.0)

Le code d'OpenMap a été remplacé par le nôtre, une version par étape (le détail : [FEUILLE_DE_ROUTE.md](FEUILLE_DE_ROUTE.md)). Ce qu'il en reste à savoir :
- **Les anciennes sauvegardes** (`MyMapIsRichDB`, `MyMapIsRichCharDB`, celles de la carte d'OpenMap) restent déclarées dans le `.toc` et **ne s'effacent jamais** : chaque module en copie une fois ce que le joueur avait par `ns.Map.Migrate` ([Plus/Map/Settings.lua](MyMapIsRich/Plus/Map/Settings.lua) ; épingles, dessins, vols appris…). Un personnage secondaire migre à sa connexion : ces migrations restent.
- Un réglage de la carte se déclare avec sa valeur d'origine par `ns.Map.Settings.Own(clé, défaut)` dans le module qui s'en sert.
- `Plus/Map/Art.lua` (le dessin) et `Close.lua` (le zoom rapproché) sont le code d'OpenMap porté (MIT). Après la 1.2.0, ce qui ne servait qu'aux autres clients d'OpenMap en est parti : ils ne lisent que les tables de `Data/Map/`. On peut les simplifier encore, en vérifiant en jeu.
- Les dessins de Santiago Reyes, faits pour OpenMap, ont été retirés : on ne les remet pas.

## Traduction : les 10 langues, toujours

Tout texte vu par le joueur passe par `L` et existe dans les **10 langues du client** : `enUS` (référence), `frFR`, `deDE`, `esES` (sert aussi à `esMX`), `itIT`, `ptBR`, `ruRU`, `koKR`, `zhCN`, `zhTW`.
Aucune chaîne en dur dans le code, même pour un message de discussion ou une info-bulle.

**Dans `Plus/Locales/`** (le seul système de traduction depuis la 1.0.0 ; celui de My Guild Is Rich : `ns.AddLocale(code, { CLE = "texte" })`) :
- Une clé ajoutée l'est **dans les 10 fichiers dans le même changement**, à la même place (même section, même ordre que `enUS.lua`), traduite pour de vrai. Pas de « TODO », pas de copie de l'anglais.
- Les `%s` / `%d` gardent **le même ordre** que l'anglais (`string.format` n'a pas d'arguments numérotés).
- Ne se traduisent pas : les commandes (`/mmir lieux`), les noms de boutons et de touches (A, B, LB, RT, R3, View, F9…), « My Map Is Rich » et les noms des autres addons.
- Les clés gardent leur préfixe de rubrique : `HINT_`, `OPT_`, `TRAVEL_`, `HUD_`, `PLACES_`, `SHARE_`, `STATUS_`, `WHATSNEW_`…
- Les noms du jeu (zones, PNJ, objets) viennent de l'API du jeu, déjà traduits ; on ne les met pas dans les Locales.
- La longueur compte : l'allemand et le russe sont plus longs, le coréen et le chinois plus courts. Un bouton ou une colonne doit tenir en allemand.
- **Les 10 langues ont toutes leurs clés** (1084, avec le guide de l'aide et le tutoriel). Pour compter, lire toutes les clés d'une ligne : les 8 langues en rangent souvent plusieurs par ligne. `enUS` et `frFR` ont plusieurs blocs `ns.AddLocale` : une clé redéfinie dans un bloc plus bas remplace la première, alors une clé ne s'écrit qu'une fois. Une clé que le code ne lit plus se retire des 10 fichiers.

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

- **Rien n'est écrit dans les cadres de Blizzard** : seulement `hooksecurefunc` et `HookScript`. Pas de remplacement de fonction globale du jeu. Seules exceptions, dites en tête de leur fichier :
  - venue d'OpenMap, dans `Plus/Map/View.lua` : l'alpha du dessin de la carte du jeu (`ScrollContainer.Child`) et de son nom de zone, cachés sous notre vue et rendus à sa fermeture ;
  - depuis la 1.2.0, dans `Plus/UI/Tracker.lua` : le suivi des quêtes du jeu (`ObjectiveTrackerFrame`), mis à l'alpha 0 tant que le nôtre est actif, rendu (alpha 1) quand on le coupe. **Jamais de `Hide()` ni de `Show()`** : ses `OnHide` / `OnShow` tourneraient au nom de l'addon, contamineraient l'interface manette, et le jeu bloquerait `SetPreferredGamepadInteractTarget` (1.3.0). Rien n'est touché si le suivi d'EllesmereUI ou de Questie est actif (`TR.Rival()`).
- **Aucune fenêtre de l'addon dans `UISpecialFrames`** : l'interface manette de Forever la parcourt et bloquerait B au nom de l'addon. B ferme les fenêtres de l'addon par [Plus/Pad/Focus.lua](MyMapIsRich/Plus/Pad/Focus.lua).
- **La manette se prend par des raccourcis prioritaires** (`SetOverrideBindingClick` vers des boutons invisibles à nous, comme `Pad/Bindings.lua`), seulement les boutons utiles, hors combat, rendus à la fermeture. **Jamais par `EnableGamePadButton`** (ni `SetPropagateGamePadInput`) : le jeu exécute alors les autres boutons depuis le code de l'addon et bloque ensuite `SetPreferredGamepadInteractTarget` jusqu'au `/reload` (le tutoriel l'a refait en 1.2.x). Ouvrir la carte du jeu depuis l'addon (`ToggleWorldMap`) passe par `ns.Risky("OpenMap")`.
- **En combat** (`InCombatLockdown()`) : pas de création ni de déplacement de cadres protégés, pas de changement de raccourcis ; on attend `PLAYER_REGEN_ENABLED`. La manette rend la main au jeu au début d'un combat.
- **Tout écran se joue à la manette** : ses éléments sont atteignables à la croix (focus de `Pad/Focus.lua`, `ns.Map.Cursor.AddRoot` pour les fenêtres sur la carte), A / B / X ont un sens, et la barre d'aide (`UI/HintBar.lua`) annonce les boutons avec leurs pastilles (`UI/Glyphs.lua`). Le suivi des quêtes (`UI/Tracker.lua`) est l'exception voulue : hors de la carte, il ne fait qu'afficher (la manette est au jeu) ; ses gestes passent à la manette par la liste des quêtes de la carte et l'onglet Quêtes.
- **La veille** : si OpenMap ou OpenMap On Gamepad est activé, My Map Is Rich n'accroche rien (`ns.Conflict()` dans `Plus/Core.lua`). Tout nouveau point d'accroche passe par ce test.
- **Les préfixes de messages entre joueurs ne changent pas** (`OpenMap`, `OMGPRoute`) : ils font passer épingles et destinations entre les trois addons (`OpenMapLoc`, les positions d'amis, est parti avec les amis en 0.5.0). Un format de message qui change reste lisible par les versions d'avant. L'avancée des quêtes du groupe (1.2.0, `Plus/Quests/Party.lua`) a son propre préfixe, `MMIRQuest`, entre joueurs de My Map Is Rich seulement.
- Les dépendances facultatives (Questie, My Gamepad Is Rich, Leatrix_Maps, Spoken…) se testent avant usage ; l'addon marche sans aucune. Spoken se prend seulement par sa porte publique (`Spoken/API.lua` : `IsCompatible(1)`, `HasStory` / `PlayStory` / `StopStory`, ses avis `AUDIO_CHANGED`), dans `Plus/UI/QuestPanel.lua`. `HasStory` et `PlayStory` choisissent un instant la quête dans le journal du jeu : sous `ns.Risky("SelectQuest")`, et la réponse de `HasStory` gardée par quête.
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
- [.luacheckrc](.luacheckrc) et [.github/workflows/luacheck.yml](.github/workflows/luacheck.yml) (repris de My Guild Is Rich) : GitHub vérifie la syntaxe à chaque envoi, données générées exclues. Les avertissements (globales, variables inutilisées) sont encore ignorés.
- Test en jeu par la jonction décrite dans le README (`K:\World of Warcraft\_forever_\Interface\AddOns\MyMapIsRich`). Diagnostics : `/mmir etat`, `/mmir sonde`, `/mmir sonde carte`, `/mmir sonde terrain`, `/mmir test`, `/mmir focus`, `/mmir carte status`.
- Après un changement, dire au joueur s'il faut `/reload` ou relancer le jeu (fichier ajouté au `.toc`).

## Fichiers partagés avec les autres addons

Ces fichiers existent, presque identiques, dans My Guild Is Rich, My Gamepad Is Rich et OpenMap On Gamepad. Un changement de fond se signale pour être reporté ailleurs :
- `Plus/UI/Widgets.lua` (repris de My Auction House Is Rich) et la CHARTE ;
- `Plus/UI/Projects.lua`, `Plus/UI/DonateTab.lua` (onglet Découvrir) ;
- `Plus/UI/WhatsNew.lua` (fenêtre Nouveautés) ;
- `Plus/Locales/Locales.lua` (le système de traduction).

## Licences

My Map Is Rich est sous **GPL-3.0-or-later** (à cause des données de marche de Shortest Path Forever, de cjber). Le dessin de la carte, son zoom rapproché et ses données restent sous MIT (`LICENSES/OpenMap.txt`, détail dans `LICENSES/README.txt`), crédits d'OpenMap dans la fenêtre Crédits ([Plus/UI/Credits.lua](MyMapIsRich/Plus/UI/Credits.lua), un texte par langue : `CREDITS_TEXT`). Ace3 n'est plus livré depuis la 0.6.0, et sa licence est retirée. Ces fichiers ne se suppriment pas, et un code repris d'ailleurs ajoute sa licence et son crédit.
