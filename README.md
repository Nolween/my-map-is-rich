# My Map Is Rich

Une carte du monde d'un seul tenant pour **WoW Forever**, toutes les zones assemblées, aussi pratique à la souris qu'**à la manette**. On passe d'une zone à la suivante en dézoomant, et on y trace le trajet le plus rapide jusqu'à n'importe quel point.

My Map Is Rich réunit dans un seul addon :
- **la carte d'[OpenMap](https://github.com/openmap-world/openmap)** 0.8.11 : la carte assemblée, ses icônes (donjons, maîtres de vol, bateaux, PNJ de ville), les épingles, la plume, les cartes de donjon, les amis et la guilde sur la carte… Son code est sous licence MIT, merci à ses auteurs ;
- **tout [OpenMap On Gamepad](https://github.com/Nolween/openmap-on-gamepad)** 0.6.0 : la manette sur la carte, les itinéraires, le panneau de trajet et la flèche GPS, la file, la roue, les lieux et la recherche, le partage avec le groupe.

## La carte plein écran

Depuis la 0.2.0, M (ou le bouton carte de la manette) ouvre la carte **en plein écran**, à la souris comme à la manette (ou **réduite** : le bouton en haut à droite, ou X à la manette, passe de l'un à l'autre ; réduite, le jeu reste visible, le personnage peut bouger, et la carte se joue de la même façon, seule la liste des quêtes passe dehors, collée à son bord droit) :
- en haut à gauche, la zone sous le curseur (le panneau de trajet, lui, reste en jeu : la carte plein écran le cache, la carte réduite le laisse) ;
- en haut au milieu, **Aller à…** (LB, Ctrl+F), qui s'ouvre sur la carte ;
- en haut à droite, Me localiser, Me suivre, le menu de la carte, Plein écran / Carte réduite et Fermer ;
- à gauche, sous la zone, **le rail des calques** (donjons, maîtres de vol, bateaux et zeppelins, quêtes, citadins, groupe, épingles, dessins) : un clic affiche ou cache un calque, un clic droit (ou Y) ouvre le panneau des calques et leurs détails ; dessous, un bouton pour les maîtres de vol découverts seulement, et un pour les réglages de la carte ; une carte réduite trop basse garde les boutons qui tiennent, les réglages toujours en dernier ;
- à droite, **tes quêtes**, toujours affichées (à la manette, RT entre dans la liste, où la croix va de quête en quête ; B, RT ou la croix gauche reviennent à la carte) : par zone ou les plus proches, la fiche d'une quête (A ou un clic : ses objectifs, son histoire, ses récompenses, comme dans le journal du jeu), l'itinéraire, la file, suivre, partager ;
- en bas à droite, tes coordonnées et celles du curseur ; au bord, « Toi » quand ta flèche sort de la vue ;
- en bas, la barre d'aide : les boutons de la manette, ou les clics et les touches à la souris.

Carte ouverte en plein écran (hors combat), le personnage ne bouge pas : les touches de déplacement font glisser la carte. À la manette, le stick gauche non plus : tant que la carte n'a pas son curseur (la croix gauche du jeu le lui donne), la manette est dans tes quêtes, dès l'ouverture, et le stick y va de quête en quête. Carte réduite, il bouge comme d'habitude.

À la souris : clic gauche choisir ou zoomer, clic droit dézoomer, molette zoom, glisser pour déplacer, Maj+clic itinéraire, Ctrl+clic épingle, Alt+clic le menu des actions, clic du milieu me localiser, Échap ou M fermer.

Une icône choisie (A, ou un clic) ouvre **sa fiche**, sous la zone : ce qu'est le point, le temps pour y aller et par où, et quoi faire (itinéraire, file, l'action de l'icône, poser une épingle, envoyer au groupe). Itinéraire (Y) en montre d'abord **l'aperçu** : le temps, l'arrivée, chaque étape ; Partir (A), la file (X), Annuler (B). R3 et Maj+clic partent tout de suite.

La carte du jeu reste ouverte dessous, invisible : c'est elle que M, Échap et B ferment. **La carte classique** (celle d'OpenMap, dessinée dans la fenêtre de carte du jeu) revient par l'onglet Réglages de `/mmir`, « Carte classique », puis `/reload`. Elle garde ce que la carte plein écran n'a pas encore : la carte marine, le zoom dans les grottes, la luminosité, le redimensionnement de la fenêtre et les icônes des addons qui ne passent pas par HereBeDragons.

## À la manette

| Où | Bouton | Action |
|---|---|---|
| Carte | R3 | Itinéraire le plus rapide jusqu'au point sous le curseur (à pied, vols appris, bateaux, zeppelins, portail de Darnassus, tram des profondeurs) ; R3 sur sa destination l'annule |
| Carte | RB | Me suivre : la carte me garde au centre quand je bouge (RB de nouveau : arrêter) |
| Carte | LB | Aller à… (carte plein écran) ou Lieux : parcourir, rechercher au clavier (lieux, PNJ et objets de Questie), récents, la file |
| Carte | Y | Le panneau des calques (carte plein écran) |
| Carte | View | La roue, autour du curseur : ajouter à la file, envoyer au groupe, poser une épingle, épingles, plume, menu de la carte (stick droit pour choisir, A pour valider, View pour fermer) |
| Carte | LT / RT | Carte plein écran : LT l'icône suivante autour du curseur, RT entre dans la liste des quêtes (la croix y va de quête en quête). Carte classique : icône précédente / suivante |
| Carte | Stick gauche, A, X, B, croix, L3, stick droit | Ceux du jeu et de la carte : curseur (sur tout l'écran, carte plein écran), appuyer / zoomer, plein écran ou carte réduite (X, carte de l'addon ; ailleurs dézoomer), fermer, Carte standard, marqueur, zoom |
| Liste des quêtes | R3 | Itinéraire tout de suite jusqu'à la quête choisie (Y : l'aperçu d'abord) ; R3 sur la quête du trajet en cours l'annule ; carte réduite : stick droit pour tourner la caméra |
| Fenêtre | Croix, A / X / B, LB / RB | D'un élément à l'autre, valider / clic droit / retour, onglets |
| Lieux | Y / X | Itinéraire jusqu'au lieu / l'ajouter à la file ; dans la file : LT / RT monter / descendre |
| Champ de texte | A | Clavier virtuel |

Pendant un itinéraire, en jeu (la carte plein écran le cache, la carte réduite le laisse), le **panneau de trajet** dit l'étape, le temps restant et l'heure d'arrivée (en vol : la barre de vol et l'alerte d'atterrissage), une **flèche GPS** dessous montre où aller, et la manette **vibre** à chaque étape. En fantôme, l'itinéraire mène au corps.

## Commandes

- `/mmir` : la fenêtre de l'addon (Réglages, Trajets, Aide, Découvrir), aussi par le bouton de la minimap
- `/mmir carte <…>` : les commandes de la carte venues d'OpenMap (`status`, `pins`, `news`, `draw`, `reset`, `debug`…) ; `/mmir carte` seul ouvre le menu de la carte
- `/mmir etat` : où en est l'addon ; `/mmir trajet` (`trajet stop`) : l'itinéraire en cours
- `/mmir lieux`, `/mmir file` (`file vider`), `/mmir panneau`, `/mmir news`, `/mmir minimap`, `/mmir on` / `off`, `/mmir reset`
- Diagnostic : `/mmir sonde`, `/mmir test`, `/mmir focus`, `/mmir camera sonde`, `/mmir camera trace`

## Avec OpenMap ou OpenMap On Gamepad

My Map Is Rich les remplace tous les deux. Si l'un d'eux est activé aussi, My Map Is Rich **reste en veille** (rien n'est accroché à la carte) et le dit dans la discussion : désactive-les dans la liste des addons, puis `/reload`.
Les messages entre joueurs gardent leurs préfixes (`OpenMapLoc`, `OpenMap` pour les épingles, `OMGPRoute` pour les destinations du groupe) : les positions d'amis, les épingles partagées et les destinations passent entre My Map Is Rich, OpenMap et OpenMap On Gamepad.
Avec **My Gamepad Is Rich** (après la 1.6.2), ses boutons s'effacent quand la carte a la manette.

## Comment c'est fait

```
MyMapIsRich/                le dossier de l'addon
  MyMapIsRich.toc
  Core.lua Init.lua API.lua Credits.lua Libs/ Locales/ Data/Forever/ Map/ Media/   la carte (OpenMap 0.8.11, renommé)
  Plus/                     la couche reprise d'OpenMap On Gamepad
    Init.lua Core.lua Diag.lua Locales/ Pad/ Travel/ UI/ Data/
  LICENSE  LICENSES/ (OpenMap.txt, Ace3.txt)
tools/                      roads/ et nav/ : les données de marche (voir plus bas) ;
                            media/Arrow.ps1 : la flèche GPS (Media/Arrow.tga)
```

- **La carte** est le code d'OpenMap 0.8.11, copié tel qu'il est installé puis renommé : ses globaux (`MyMapIsRich`, `MyMapIsRichAPI`, les cadres `MyMapIsRich…`), ses sauvegardes (`MyMapIsRichDB`, `MyMapIsRichCharDB`), ses textes (« My Map Is Rich »). Les commentaires gardent le nom d'OpenMap : ils disent d'où vient le code.
- **Plus** a son propre espace de noms : chaque fichier commence par `local _, root = ... ; local ns = root.Plus`. Ses `ns.L`, `ns.db` (`MyMapIsRichPlusDB`), `ns.UI`... ne touchent jamais ceux de la carte. Il atteint la carte par `ns.OM` (la racine : `root:GetModule("worldmap")`, `root.MapStitch`).
- La veille : `ns.Conflict()` (Core.lua), demandée à la connexion par Init.lua, Map/Launcher.lua et Plus/Core.lua.
- Règle : rien n'est écrit dans les cadres de Blizzard (seulement `hooksecurefunc` / `HookScript`), et aucune fenêtre de la manette n'entre dans `UISpecialFrames` : sinon l'interface manette du jeu bloque des actions au nom de l'addon.
- **La carte plein écran** est la vue manette d'OpenMap (`Map/PadView.lua`) étendue à tout l'écran et à la souris : elle se bâtit une fois, sur son propre cadre, enfant de la carte du jeu (qui reste ouverte dessous). Plus pose dessus son habillage (`Plus/UI/MapChrome.lua`) et le rail des calques (`Plus/UI/Layers.lua`). Le réglage `classicMap` (« Carte classique ») rend la carte d'OpenMap dessinée dans celle du jeu, après un `/reload`.
- Le détail des modules de Plus (la couche des boutons, les itinéraires, le panneau, la roue, les lieux, le groupe) est dans les en-têtes de leurs fichiers, comme dans OpenMap On Gamepad.

## Les données de marche

`MyMapIsRich/Plus/Data/Roads.lua`, `Nav0.lua`, `Nav1.lua` et `Passages.lua` sont générés par `tools/roads/build_roads.py` et `tools/nav/build_nav.py`, à partir de [Shortest Path Forever](https://github.com/cjber/shortest-path-forever) (de cjber, GPL-3.0-or-later) :

```
python -m venv .venv
.venv\Scripts\pip install -r tools\roads\requirements.txt
.venv\Scripts\python tools\roads\build_roads.py ["K:\World of Warcraft\_forever_\Interface\AddOns\ShortestPathForever"]
.venv\Scripts\python tools\nav\build_nav.py ["K:\World of Warcraft\_forever_\Interface\AddOns\ShortestPathForever"]
```

Les données de la carte (`MyMapIsRich/Data/Forever/`) viennent des outils d'OpenMap, dans son dépôt.

## Licence et crédits

My Map Is Rich est sous licence **GPL-3.0-or-later** (`MyMapIsRich/LICENSE`), parce qu'il livre les données de marche tirées de Shortest Path Forever (merci à cjber).
Le code de la carte vient d'**OpenMap** (© OpenMap contributors, licence MIT : `MyMapIsRich/LICENSES/OpenMap.txt`) ; ses crédits sont dans `MyMapIsRich/Credits.lua`. Ace3 : `MyMapIsRich/LICENSES/Ace3.txt`. Les images de la carte sont celles de Blizzard.

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
