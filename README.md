# My Map Is Rich

Une carte du monde d'un seul tenant pour **WoW Forever**, toutes les zones assemblées, aussi pratique à la souris qu'**à la manette**. On passe d'une zone à la suivante en dézoomant, et on y trace le trajet le plus rapide jusqu'à n'importe quel point.

My Map Is Rich réunit dans un seul addon :
- **la carte d'[OpenMap](https://github.com/openmap-world/openmap)** 0.8.11 : la carte assemblée, ses icônes (donjons, maîtres de vol, bateaux, PNJ de ville), les épingles, la plume, les cartes de donjon… Son code est sous licence MIT, merci à ses auteurs. De la 0.5.0 à la 1.0.0, il a été remplacé pas à pas par celui de My Map Is Rich (voir « Comment c'est fait ») ;
- **tout [OpenMap On Gamepad](https://github.com/Nolween/openmap-on-gamepad)** 0.6.0 : la manette sur la carte, les itinéraires, le panneau de trajet et la flèche GPS, la file, la roue, les lieux et la recherche, le partage avec le groupe.

## La carte plein écran

Depuis la 0.2.0, M (ou le bouton carte de la manette) ouvre la carte **en plein écran**, à la souris comme à la manette (ou **réduite** : le bouton en haut à droite, ou X à la manette, passe de l'un à l'autre ; réduite, le jeu reste visible, le personnage peut bouger, et la carte se joue de la même façon, seule la liste des quêtes passe dehors, collée à son bord droit) :
- en haut à gauche, la zone sous le curseur (le panneau de trajet, lui, reste en jeu : la carte plein écran le cache, la carte réduite le laisse) ;
- en haut au milieu, **Aller à…** (LB, Ctrl+F), qui s'ouvre sur la carte ;
- en haut à droite, Me localiser, Me suivre, les réglages de la carte (l'onglet Carte de `/mmir`), Plein écran / Carte réduite et Fermer ;
- à gauche, sous la zone, **le rail des calques** (donjons, maîtres de vol, bateaux et zeppelins, quêtes, citadins, groupe, épingles, dessins) : un clic affiche ou cache un calque, un clic droit (ou Y) ouvre le panneau des calques et leurs détails ; dessous, un bouton pour les maîtres de vol découverts seulement, et un pour les réglages de la carte ; une carte réduite trop basse garde les boutons qui tiennent, les réglages toujours en dernier ;
- à droite, **tes quêtes**, toujours affichées (à la manette, RT entre dans la liste, où la croix va de quête en quête ; B, RT ou la croix gauche reviennent à la carte) : par zone ou les plus proches, la fiche d'une quête (A ou un clic : ses objectifs, son histoire, ses récompenses, comme dans le journal du jeu), l'itinéraire, la file, suivre, partager ; Y ou un clic droit sur une quête ouvre **son menu**, sans passer par la fiche : voir la quête, itinéraire, file, suivre, partager, lien dans la discussion, abandonner (après confirmation) ;
- en bas à droite, tes coordonnées et celles du curseur ; au bord, « Toi » quand ta flèche sort de la vue ;
- en bas, la barre d'aide : les boutons de la manette, ou les clics et les touches à la souris.

Carte ouverte en plein écran (hors combat), le personnage ne bouge pas : les touches de déplacement font glisser la carte. À la manette, le stick gauche non plus : tant que la carte n'a pas son curseur (la croix gauche du jeu le lui donne), la manette est dans tes quêtes, dès l'ouverture, et le stick y va de quête en quête. Carte réduite, il bouge comme d'habitude.

À la souris : clic gauche choisir ou zoomer, clic droit dézoomer, molette zoom, glisser pour déplacer, Maj+clic itinéraire, Ctrl+clic épingle, Alt+clic le menu des actions, clic du milieu me localiser, Échap ou M fermer.

Une icône choisie (A, ou un clic) ouvre **sa fiche**, sous la zone : ce qu'est le point, le temps pour y aller et par où, et quoi faire (itinéraire, file, l'action de l'icône, poser une épingle, envoyer au groupe). Itinéraire (Y) en montre d'abord **l'aperçu** : le temps, l'arrivée, chaque étape ; Partir (A), la file (X), Annuler (B). R3 et Maj+clic partent tout de suite.

La carte du jeu reste ouverte dessous, invisible : c'est elle que M, Échap et B ferment. La carte classique d'OpenMap (dessinée dans la fenêtre de carte du jeu) n'existe plus depuis la 0.5.0.

## À la manette

| Où | Bouton | Action |
|---|---|---|
| Carte | R3 | Itinéraire le plus rapide jusqu'au point sous le curseur (à pied, vols appris, bateaux, zeppelins, portail de Darnassus, tram des profondeurs) ; R3 sur sa destination l'annule |
| Carte | RB | Me suivre : la carte me garde au centre quand je bouge (RB de nouveau : arrêter) |
| Carte | LB | Aller à… (carte plein écran) ou Lieux : parcourir, rechercher au clavier (lieux, PNJ et objets de Questie), récents, la file |
| Carte | Y | Le panneau des calques (carte plein écran) |
| Carte | View | La roue, autour du curseur : ajouter à la file, envoyer au groupe, poser une épingle, épingles, plume, réglages de la carte (stick droit pour choisir, A pour valider, View pour fermer) |
| Carte | LT / RT | Carte plein écran : LT l'icône suivante autour du curseur, RT entre dans la liste des quêtes (la croix y va de quête en quête). |
| Carte | X | Plein écran ou carte réduite, **où que l'on soit sur la carte** (liste des quêtes, fiche d'un point, lieux, rail des calques, plume, donjon). C'est son seul rôle ; seuls le clavier virtuel (effacer) et l'invitation du groupe (plus tard) gardent leur X |
| Carte | Stick gauche, A, B, croix, L3, stick droit | Ceux du jeu et de la carte : curseur (sur tout l'écran, carte plein écran), appuyer / zoomer, fermer, Carte standard, marqueur, zoom. La croix haut / bas ne change jamais la taille de la carte |
| Liste des quêtes | R3 | Itinéraire tout de suite jusqu'à la quête choisie ; R3 sur la quête du trajet en cours l'annule ; carte réduite : stick droit pour tourner la caméra |
| Liste des quêtes | Y | Le menu de la quête choisie (voir, itinéraire, file, suivre, partager, lien, abandonner) : la croix choisit, A valide, B ou Y le ferment |
| Liste des quêtes | View | Ajouter la quête choisie à la file |
| Fenêtre | Croix, A / B, View, LB / RB | D'un élément à l'autre, valider / retour, clic droit (View sur la carte, X ailleurs), onglets |
| Lieux, fiche d'un point | Y / View | Itinéraire jusqu'au lieu / l'ajouter à la file ; dans la file : View le retire, LT / RT monter / descendre |
| Rail des calques | View | Les détails du calque choisi |
| Champ de texte | A | Clavier virtuel |

Pendant un itinéraire, en jeu (la carte plein écran le cache, la carte réduite le laisse), le **panneau de trajet** dit l'étape, le temps restant et l'heure d'arrivée (en vol : la barre de vol et l'alerte d'atterrissage), une **flèche GPS** dessous montre où aller, et la manette **vibre** à chaque étape. En fantôme, l'itinéraire mène au corps.

## Commandes

- `/mmir` : la fenêtre de l'addon (Réglages, Carte, Trajets, Aide, Découvrir), aussi par le bouton de la minimap, le menu des addons de la minimap et Titan Panel
- `/mmir carte` : les réglages de la carte (l'onglet Carte) ; `/mmir carte <…>` : les commandes de la carte (`status` : ce que fait la vue ; `pins` : tes épingles ; `draw` : la plume ; `forgetflights` : oublier les maîtres de vol appris par ce personnage)
- Les raccourcis du jeu (Raccourcis > My Map Is Rich) : me localiser, poser une épingle, les épingles, la plume, les réglages de la carte
- `/mmir etat` : où en est l'addon ; `/mmir trajet` (`trajet stop`) : l'itinéraire en cours
- `/mmir lieux`, `/mmir file` (`file vider`), `/mmir panneau`, `/mmir news`, `/mmir minimap`, `/mmir on` / `off`, `/mmir reset`
- Diagnostic : `/mmir sonde`, `/mmir sonde carte` (les coordonnées comparées à celles du dessin de la carte), `/mmir test`, `/mmir focus`, `/mmir camera sonde`, `/mmir camera trace`

## Avec OpenMap ou OpenMap On Gamepad

My Map Is Rich les remplace tous les deux. Si l'un d'eux est activé aussi, My Map Is Rich **reste en veille** (rien n'est accroché à la carte) et le dit dans la discussion : désactive-les dans la liste des addons, puis `/reload`.
Les messages entre joueurs gardent leurs préfixes (`OpenMap` pour les épingles, `OMGPRoute` pour les destinations du groupe) : les épingles partagées et les destinations passent entre My Map Is Rich, OpenMap et OpenMap On Gamepad. (Les positions d'amis, préfixe `OpenMapLoc`, sont parties avec les amis et la guilde sur la carte, en 0.5.0.)
Avec **My Gamepad Is Rich** (après la 1.6.2), ses boutons s'effacent quand la carte a la manette.

## Comment c'est fait

```
MyMapIsRich/                le dossier de l'addon
  MyMapIsRich.toc
  Bindings.xml              les raccourcis du jeu (Plus/UI/KeyBindings.lua)
  Plus/                     tout le code de l'addon
    Init.lua Core.lua Diag.lua Locales/ Map/ Layers/ Pad/ Travel/ UI/ Data/
  Data/Map/                 les données de la carte (tirées du jeu par les outils d'OpenMap)
  Media/                    l'icône, la flèche ; Media/Map/ : les textures de la carte
  LICENSE  LICENSES/ (OpenMap.txt, Ace3.txt, README.txt)
tools/                      roads/ et nav/ : les données de marche (voir plus bas) ;
                            hazards/ : les villes de l'autre faction (voir plus bas) ;
                            media/Arrow.ps1 : la flèche GPS (Media/Arrow.tga)
```

- **D'où ça vient** : My Map Is Rich est né d'OpenMap 0.8.11 (la carte) et d'OpenMap On Gamepad 0.6.0 (la manette, les itinéraires, les lieux). De la 0.5.0 à la 1.0.0, le code d'OpenMap a été remplacé par le nôtre, une version par étape ([FEUILLE_DE_ROUTE.md](FEUILLE_DE_ROUTE.md)). Le dessin de la carte et son zoom rapproché en sont portés tels quels, et ses données restent celles de ses outils.
- **Plus** porte tout le code : chaque fichier commence par `local _, root = ... ; local ns = root.Plus` (l'espace de noms `root` ne garde que les tables de `Data/Map/`). Ses `ns.L`, `ns.db` (`MyMapIsRichPlusDB`), `ns.char` (`MyMapIsRichPlusCharDB`), `ns.UI`... Il atteint la carte **par `ns.Map`** (`Plus/Map/Api.lua` : la vue, le curseur, les coordonnées, les icônes, les épingles, les vols, la plume, les donjons ; `Plus/Map/Data.lua` : les données ; `Plus/Map/Settings.lua` : les réglages de la carte).
- **Les anciennes sauvegardes** (`MyMapIsRichDB`, `MyMapIsRichCharDB`, celles de la carte d'OpenMap) restent déclarées dans le `.toc` : chaque module en copie une fois ce que le joueur avait (`ns.Map.Migrate`), sans rien effacer. Un personnage secondaire migre à sa propre connexion.
- La veille : `ns.Conflict()` (`Plus/Core.lua`), demandée à la connexion.
- Règle : rien n'est écrit dans les cadres de Blizzard (seulement `hooksecurefunc` / `HookScript`), et aucune fenêtre de la manette n'entre dans `UISpecialFrames` : sinon l'interface manette du jeu bloque des actions au nom de l'addon.
- **La carte plein écran** est notre vue (`Plus/Map/View.lua`, depuis la 0.12.0 ; elle venait de la vue manette d'OpenMap), pour la souris et la manette : elle se bâtit une fois, sur son propre cadre, enfant de la carte du jeu (qui reste ouverte dessous). Le dessin de la carte est `Plus/Map/Art.lua`, ses icônes `Plus/Map/PinSets.lua` et le zoom rapproché (la minicarte, les grottes) `Plus/Map/Close.lua` ; le dessin et le zoom rapproché sont ceux d'OpenMap, portés. La vue les atteint par `ns.Map.Art`. Plus pose dessus son habillage (`Plus/UI/MapChrome.lua`) et le rail des calques (`Plus/UI/Layers.lua`).
- Le détail des modules de Plus (la couche des boutons, les itinéraires, le panneau, la roue, les lieux, le groupe) est dans les en-têtes de leurs fichiers, comme dans OpenMap On Gamepad.

## Les données de marche

`MyMapIsRich/Plus/Data/Roads.lua`, `Nav0.lua`, `Nav1.lua` et `Passages.lua` sont générés par `tools/roads/build_roads.py` et `tools/nav/build_nav.py`, à partir de [Shortest Path Forever](https://github.com/cjber/shortest-path-forever) (de cjber, GPL-3.0-or-later) :

```
python -m venv .venv
.venv\Scripts\pip install -r tools\roads\requirements.txt
.venv\Scripts\python tools\roads\build_roads.py ["K:\World of Warcraft\_forever_\Interface\AddOns\ShortestPathForever"]
.venv\Scripts\python tools\nav\build_nav.py ["K:\World of Warcraft\_forever_\Interface\AddOns\ShortestPathForever"]
```

`Hazards.lua` (les villes et capitales de l'autre faction, que les chemins à pied contournent) est écrit par `tools/hazards/build_hazards.ps1`, à partir des mêmes données de Shortest Path Forever, sans Python :

```
powershell -ExecutionPolicy Bypass -File tools\hazards\build_hazards.ps1 ["K:\World of Warcraft\_forever_\Interface\AddOns\ShortestPathForever"]
```

Les données de la carte (`MyMapIsRich/Data/Map/`) et ses textures (`MyMapIsRich/Media/Map/`) viennent des outils d'OpenMap, dans son dépôt : on les régénère, on ne les édite pas.

## Licence et crédits

My Map Is Rich est sous licence **GPL-3.0-or-later** (`MyMapIsRich/LICENSE`), parce qu'il livre les données de marche tirées de Shortest Path Forever (merci à cjber).
Le dessin de la carte, son zoom rapproché et ses données viennent d'**OpenMap** (© OpenMap contributors, licence MIT : `MyMapIsRich/LICENSES/OpenMap.txt`) ; ses crédits sont dans la fenêtre Crédits de l'onglet Aide (`MyMapIsRich/Plus/UI/Credits.lua`). Ace3 n'est plus livré depuis la 0.6.0. Les images de la carte sont celles de Blizzard.

## Paquet

```
.\build.ps1
```
écrit `..\Releases\MyMapIsRich\MyMapIsRich-<version>.zip`.

## Développement

Une jonction depuis le dossier du jeu :
```
mklink /J "K:\World of Warcraft\_forever_\Interface\AddOns\MyMapIsRich" "G:\Addons Wow Dev\MyMapIsRich\MyMapIsRich"
```
