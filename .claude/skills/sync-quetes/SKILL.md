---
name: sync-quetes
description: Synchronise la base des quêtes de My Map Is Rich (Plus/Data/Quests.lua) avec la dernière version Forever de QuestieDB, la vérifie et résume ce qui a changé. À lancer quand QuestieDB publie une nouvelle version, ou avant de publier une version de l'addon.
---

# Synchroniser la base des quêtes

La base des quêtes de My Map Is Rich (`MyMapIsRich/Plus/Data/Quests.lua`) est une copie de la base Forever de QuestieDB (https://github.com/Questie/QuestieDB, données sous GPLv3). Elle est générée par `tools/quests/build_quests.py`, et on ne la modifie jamais à la main. Réponds en français.

## Étapes

1. **L'état d'avant.** Note la version actuelle : la ligne `build = "QuestieDB x.y.z"` de `MyMapIsRich/Plus/Data/Quests.lua`. Note aussi sa taille.
2. **La nouvelle version.** Lance, depuis la racine du dépôt :
   ```
   py tools/quests/build_quests.py --fetch
   ```
   L'outil télécharge la dernière archive Forever des versions GitHub de QuestieDB et l'extrait dans `tools/quests/source/QuestieDB-<version>/`, un dossier ignoré par git. Il prend aussi la liste noire et les fêtes de la dernière version de Questie, dans `tools/quests/source/Questie-<version>/`. Ces fichiers sont **lus comme des données par `tools/quests/questie_hidden.py`, jamais exécutés**. Il régénère ensuite le fichier et affiche :
   - le nombre de quêtes, de PNJ, d'objets du monde, d'objets de quête et de points ;
   - les points hors des cartes connues ;
   - la taille du fichier ;
   - le nombre de cartes et la vérification de la quête 7.

   Si la version est déjà là, l'outil le dit et régénère quand même : `forever_fixes.json` a pu changer.
3. **Vérifier.**
   - La syntaxe Lua 5.1 du fichier généré. Il n'y a pas de Lua sur ce poste : installe `lupa` dans un environnement virtuel du dossier temporaire et compile le fichier avec `loadstring`, sans l'exécuter.
   - Les points « hors des cartes connues » doivent rester à 0 ou presque. Sinon, QuestieDB a ajouté des zones absentes de `support/Forever/Zones/areaIdToUiMapId.lua`, et il faut le signaler.
   - La ligne « liste noire de Questie : N quêtes, M valeurs illisibles ». M doit rester à 0. Sinon, une expression nouvelle est apparue dans `QuestieQuestBlacklist.lua` : montre-la et propose de l'ajouter à la grammaire de `questie_hidden.py`, sans jamais exécuter le fichier.
   - La taille doit rester raisonnable, environ 2,5 Mo pour la 1.1.6. Signale tout saut de plus de 20 %.
   - Si le format de QuestieDB a changé (une erreur du décodeur `tools/quests/questiedb.py`, une clé `X-…` absente, des champs déplacés dans `src/meta/*Meta.lua` de l'archive), arrête-toi, explique ce qui a changé et propose la correction du décodeur, sans rien publier.
4. **La licence.** Compare le `LICENSE.md` de l'archive avec la fin de `MyMapIsRich/LICENSES/QuestieDB.txt`. S'il a changé, montre ce qui diffère et demande avant de continuer : la copie de leurs données repose sur leur accord sous GPLv3.
5. **Le résumé**, pour le joueur :
   - l'ancienne et la nouvelle version de QuestieDB ;
   - ce qui a changé dans les comptes ;
   - les nouvelles cartes s'il y en a (compare la liste des cartes avec `git diff --stat` et le fichier d'avant) ;
   - le rappel qu'il faut **`/reload`** en jeu pour voir les changements (aucun fichier n'est ajouté au `.toc`).

## Ce qu'on ne fait pas

- Ne pas committer : seulement si le joueur le demande, avec le message `Base des quêtes : QuestieDB x.y.z` et la mention de co-auteur habituelle.
- Ne pas changer la version de l'addon ni le CHANGELOG, sauf si le joueur prépare une version : la procédure « Publier une version » de CLAUDE.md s'applique alors.
- Ne pas reprendre les chances de butin de QuestieDB (`support/*/DropTables`) : elles viennent de Wowhead.
- Ne jamais utiliser le nom ni le logo de Questie pour My Map Is Rich.
