# My Map Is Rich

Une carte du monde d'un seul tenant pour **WoW Forever**, toutes les zones assemblées, aussi pratique à la souris qu'**à la manette**. On passe d'une zone à la suivante en dézoomant, et on y trace le trajet le plus rapide jusqu'à n'importe quel point.

My Map Is Rich réunit dans un seul addon :
- **la carte d'[OpenMap](https://github.com/openmap-world/openmap)** 0.8.11 : la carte assemblée, ses icônes (donjons, maîtres de vol, bateaux, PNJ de ville), les épingles, la plume, les cartes de donjon, les amis et la guilde sur la carte… Son code est sous licence MIT, merci à ses auteurs ;
- **tout [OpenMap On Gamepad](https://github.com/Nolween/openmap-on-gamepad)** 0.6.0 : la manette sur la carte, les itinéraires, le panneau de trajet et la flèche GPS, la file, la roue, les lieux et la recherche, le partage avec le groupe.

## À la manette

| Où | Bouton | Action |
|---|---|---|
| Carte | R3 | Itinéraire le plus rapide jusqu'au point sous le curseur (à pied, vols appris, bateaux, zeppelins, portail de Darnassus, tram des profondeurs) ; R3 sur sa destination l'annule |
| Carte | RB | Me suivre : la carte me garde au centre quand je bouge (RB de nouveau : arrêter) |
| Carte | LB | Lieux : parcourir, rechercher au clavier (lieux, PNJ et objets de Questie), récents, la file |
| Carte | View | La roue, autour du curseur : ajouter à la file, envoyer au groupe, poser une épingle, épingles, plume, menu de la carte (stick droit pour choisir, A pour valider, View pour fermer) |
| Carte | LT / RT | Icône précédente / suivante autour du curseur |
| Carte | Stick gauche, A, X, B, Y, croix, L3, stick droit | Ceux du jeu et de la carte : curseur, appuyer / zoomer, dézoomer, fermer, Plus, Carte standard, marqueur, zoom |
| Liste des quêtes (carte réduite) | R3 | Itinéraire jusqu'à la quête qui a le focus ; stick droit : tourner la caméra |
| Fenêtre | Croix, A / X / B, LB / RB | D'un élément à l'autre, valider / clic droit / retour, onglets |
| Lieux | Y / X | Itinéraire jusqu'au lieu / l'ajouter à la file ; dans la file : LT / RT monter / descendre |
| Champ de texte | A | Clavier virtuel |

Pendant un itinéraire, le **panneau de trajet** dit l'étape, le temps restant et l'heure d'arrivée (en vol : la barre de vol et l'alerte d'atterrissage), une **flèche GPS** dessous montre où aller, et la manette **vibre** à chaque étape. En fantôme, l'itinéraire mène au corps.

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
tools/                      roads/ et nav/ : les données de marche (voir plus bas)
```

- **La carte** est le code d'OpenMap 0.8.11, copié tel qu'il est installé puis renommé : ses globaux (`MyMapIsRich`, `MyMapIsRichAPI`, les cadres `MyMapIsRich…`), ses sauvegardes (`MyMapIsRichDB`, `MyMapIsRichCharDB`), ses textes (« My Map Is Rich »). Les commentaires gardent le nom d'OpenMap : ils disent d'où vient le code.
- **Plus** a son propre espace de noms : chaque fichier commence par `local _, root = ... ; local ns = root.Plus`. Ses `ns.L`, `ns.db` (`MyMapIsRichPlusDB`), `ns.UI`... ne touchent jamais ceux de la carte. Il atteint la carte par `ns.OM` (la racine : `root:GetModule("worldmap")`, `root.MapStitch`).
- La veille : `ns.Conflict()` (Core.lua), demandée à la connexion par Init.lua, Map/Launcher.lua et Plus/Core.lua.
- Règle : rien n'est écrit dans les cadres de Blizzard (seulement `hooksecurefunc` / `HookScript`), et aucune fenêtre de la manette n'entre dans `UISpecialFrames` : sinon l'interface manette du jeu bloque des actions au nom de l'addon.
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
