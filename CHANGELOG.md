# Journal des versions — My Map Is Rich

## 0.10.0

**Les donjons, en code de My Map Is Rich, et leur carte aux couleurs de l'addon.**

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : l'addon a des fichiers nouveaux).

- **Les entrées de donjon et de raid** sur la carte : leur icône, leurs niveaux dessous, colorés pour ton niveau ; au survol, le nom de chaque donjon, ses niveaux, son nombre de boss, et ce que fera le clic. Plusieurs donjons à une même entrée (Hache-Tripes, le Monastère écarlate) : le clic ouvre le menu de la carte pour choisir.
- **La carte d'un donjon**, refaite :
  - en haut, **Retour** vers la zone de l'entrée, l'étage entre deux flèches (un clic sur son nom : la liste des étages), la croix ;
  - à gauche, la carte de l'étage, ses boss numérotés et tes dessins de la plume ; la molette zoome, tirer déplace, un clic droit revient au monde ;
  - à droite, le panneau du donjon : ses niveaux et les onglets **Étages** (chaque étage en vignette), **Boss**, **Quêtes** (avec Questie, celles que tu peux prendre, faites ou dans ton journal ; avec Dungeon Journal ou NeedRoll, un bouton pour les ouvrir) et **Butin** (NeedRoll) ;
  - sans carte de ce donjon dans le jeu, la page le dit, et le panneau reste.
- **À la manette**, comme avant : LB / RB pour les étages, LT / RT pour les onglets, View pour passer dans le panneau, le stick droit pour zoomer, X pour revenir au monde.
- **Dans un donjon**, la carte ouverte montre de nouveau la sienne (réglage « Carte du donjon à l'intérieur », onglet Carte de `/mmir`), sauf là où Dungeon Journal ou NeedRoll montrent la leur. Revenir au monde le montre autour de l'entrée.
- **Un donjon où tu es entré compte comme trouvé** (« Seulement les lieux trouvés ») : son entrée reste visible même si le sol autour n'est pas exploré. Ce personnage s'en souvient.
- Tes réglages des donjons, l'onglet choisi et les boss que tu avais placés à la main sont repris.
- Partis avec `Map/Dungeons.lua` : `/mmir carte entrance`, `/mmir carte dungeons` et `/mmir carte bosses`, des outils d'OpenMap qui ne marchaient plus sur la carte plein écran.

## 0.9.0

**Les quêtes, les citadins, le groupe et le point de destination, en code de My Map Is Rich.**

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : l'addon a des fichiers nouveaux).

- **Les quêtes sur la carte** (le calque Quêtes) : celles de ton journal, dans toutes les zones et à tous les zooms (le détail « toutes les zones » éteint : seulement la zone où est la carte du jeu). La quête suivie a son icône dorée et sa zone en ombre ; le survol d'une quête montre sa zone et ses objectifs ; un clic la suit et zoome dessus. Les « ! » des quêtes à commencer dans la zone sont là aussi. Les zones se lisent quelques-unes par image : la carte ne fige pas à l'ouverture.
- **Les citadins et les monstres rares** (le calque Citadins, avec Questie) : vendeurs, réparation, aubergistes, écuries, banquiers, boîtes aux lettres, maîtres de classe et de métier, esprits soigneurs, monstres rares ; chaque sorte se construit la première fois qu'on l'allume.
- **Ton groupe et ton raid** : un point à la couleur de la classe de chacun, cerclé d'or ; pâle, sous le milieu de sa zone, quand le jeu tait sa place. Les points se déplacent au lieu d'être redessinés : leur info-bulle ne clignote plus.
- **Le point de destination** (celui du jeu, sinon le nôtre, et celui de TomTom) : son icône sur toute la carte, sauf s'il est sur une de tes épingles ; un clic l'efface, Maj+clic met son lien dans la discussion. Celui de chaque personnage est repris.
- **Me localiser** (le bouton de l'habillage, la croix, les lieux, le raccourci du jeu) et **le mode « poser une épingle »** (la roue, puis A sur la carte).
- **Le nom du lieu**, en haut à gauche de la carte : avec les niveaux de la zone, colorés pour ton niveau, et la pêche pour qui la connaît.
- **La réouverture de la carte** se simplifie : avec « Centrer sur moi à l'ouverture de la carte » (onglet Réglages), elle rouvre sur toi, à la taille de ta zone ; sans, là où tu l'avais laissée. Les autres choix d'OpenMap (garder le zoom, toute ta zone, garder la vue si tu y es encore) ne sont plus là.
- Tes réglages de ces calques sont repris.
- Partis avec `Map/Nav.lua` : sa recherche (celle des lieux, LB ou Aller à…, la remplace depuis la 0.6.0) et le repère qui marquait un lieu trouvé.

## 0.8.0

**Les maîtres de vol, les bateaux et les zeppelins, en code de My Map Is Rich.**

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : l'addon a des fichiers nouveaux).

- **Les maîtres de vol** de ta faction (et ceux de ta classe, comme Havre-du-Nord pour les druides) : en couleur ceux que tu as appris, en gris les autres, que le bouton « découverts seulement » du rail cache. Un maître de vol est appris quand tu l'as vu connu chez un maître de vol : la liste est gardée par personnage.
- **Le trajet en vol** : sur la fiche d'un maître de vol, son action (« Les vols depuis ce maître de vol ») le choisit, cerclé d'or ; la même action sur un autre dessine le trajet le long des vrais chemins des vols, avec ses escales et son temps. Le temps est celui de tes propres vols directs quand tu les as faits, sinon une estimation (« environ »). Un trajet qui passe par des maîtres de vol que tu n'as pas appris est pâle et le dit.
- **Les routes des bateaux et des zeppelins** (le détail « Routes » du calque Bateaux et zeppelins) : des points réguliers le long du vrai trajet, plus serrés quand on zoome ; bleu pour l'Alliance, rouge pour la Horde et les ports gobelins. Une route s'éclaire et dit d'où à où elle va quand le curseur en approche : désormais **aussi à la souris** sur la carte plein écran (avant, seulement au curseur de la manette).
- **Tout est repris** : les maîtres de vol appris de chaque personnage (à sa prochaine connexion) et les temps de vol mesurés. Les itinéraires (R3) s'en servent comme avant.
- `/mmir carte forgetflights` (oublier les vols appris de ce personnage, si l'un est compté à tort) remarche sur la carte plein écran.
- Corrigé : sur la fiche d'un quai de bateau ou de zeppelin, l'action du quai (l'autre bout de la traversée) avait disparu depuis la 0.5.0.

## 0.7.0

**Tes épingles, refaites aux couleurs de l'addon, et des coordonnées qui sont les nôtres.**

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : l'addon a des fichiers nouveaux).

- **La fiche d'une épingle** s'ouvre quand tu en poses une (Ctrl+clic sur la carte, Poser une épingle dans la roue ou sur la fiche d'un point) ou quand tu cliques dessus :
  - sa note (à la manette, A sur le champ ouvre le clavier virtuel) et sa couleur (or, rouge, vert, bleu, violet), vues tout de suite sur la carte ;
  - Suivre ou Ne plus suivre : le point de destination du jeu et sa flèche (et celui de TomTom) ;
  - Dessiner sur la carte : la plume, attachée à l'épingle (retirer l'épingle retire son dessin) ; la fiche dit combien de traits elle porte ;
  - la partager à ton groupe, ta guilde ou ta cible, ou en code ; la retirer ; Fini (aussi Entrée, la croix ou B) garde la note.
- **La liste des épingles** (les épingles de la roue, `/mmir carte pins`) : chaque épingle avec sa couleur, sa zone, sa note, et si elle est suivie ou porte un dessin. Un clic fait glisser la carte jusqu'à elle, un clic droit (X à la manette) ouvre sa fiche, Maj+clic la met dans la discussion, Alt+clic la retire. En bas : Importer un code, Tout partager (en code, au groupe, à la guilde), Tout retirer (après confirmation). Plus de 12 épingles : la molette, ou LB / RB à la manette, tournent les pages.
- **Les épingles qu'on te partage** arrivent dans une petite fenêtre : Les ajouter ou Ignorer (celles du groupe sans demander, si tu l'as réglé dans l'onglet Carte).
- **Tout ce que tu avais est repris** : tes épingles, leurs notes, couleurs et dessins, et leurs réglages. Le partage reste lisible par OpenMap, dans les deux sens, comme les codes d'épingles.
- Les fenêtres des épingles ont l'allure de l'addon (fini les boutons et le cadre d'OpenMap) et se jouent à la manette comme les autres : la croix, A, X, B.
- **Sous le capot** : les coordonnées de la carte (où est une zone, quelle carte est sous un point, les mètres du jeu) sont celles de My Map Is Rich. `/mmir sonde carte` les compare à celles d'OpenMap, encore là pour dessiner la carte : elles doivent être identiques.

## 0.6.0

**Les réglages de la carte dans la fenêtre de l'addon, et la fin du menu d'OpenMap.**

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : l'addon a des fichiers nouveaux).

- **Un nouvel onglet Carte** dans la fenêtre `/mmir`, entre Réglages et Trajets. On y arrive aussi par l'engrenage de la carte (sur le rail des calques et en haut à droite), la roue (View), le menu d'Alt+clic, Y dans une fenêtre et `/mmir carte`. Trois panneaux, aux couleurs de l'addon :
  - **L'aspect** : les zones inexplorées (montrées, assombries ou cachées, aussi pour ce personnage seulement), l'assombrissement, l'harmonie des couleurs, moins de couleur ; le zoom le plus profond, la taille des icônes, le zoom dès lequel elles s'affichent, ta flèche ; un bouton remet les curseurs à leur valeur d'origine ;
  - **Au plus près** : le détail de la minimap du jeu (sa force, dès quel zoom, au plus fort, dans les capitales), l'adoucissement et le grain de papier, les grottes et les entrées de donjon ;
  - **Les épingles et les donjons** : les épingles des autres (et celles du groupe sans demander), envoyer les tiennes au groupe, suivre les nouvelles ; la carte du donjon à l'intérieur, les donjons d'après la minimap, les entrées vers Dungeon Journal, d'où viennent les quêtes des donjons.

  Chaque réglage a son info-bulle et agit tout de suite. Ouverte depuis la carte, la fenêtre passe par-dessus, et la manette la mène comme les autres fenêtres de l'addon : la croix va d'un réglage à l'autre, A coche ou change un choix, gauche et droite font glisser un curseur, LB et RB changent d'onglet, B ferme. Ce que la carte montre reste sur le rail des calques.
- **Le menu de la carte d'OpenMap et sa fenêtre de réglages ne sont plus là**, ni les bibliothèques Ace3 qui la dessinaient. Ses réglages qui ne servaient qu'à la carte classique sont partis avec elle (le passage d'une zone à l'autre au repos, la surbrillance, la cadence d'images, le fondu en marchant…). Le calque Groupe s'appelle désormais « Groupe et raid ».
- **Les raccourcis du jeu** (Raccourcis > My Map Is Rich) marchent sur la carte plein écran : me localiser, poser une épingle, les épingles, la plume et (nouveau) les réglages de la carte. La carte s'ouvre d'abord si elle est fermée (pas en combat). Le raccourci du journal de quêtes est retiré : la liste des quêtes est toujours à droite de la carte.
- **Les crédits** : un bouton Crédits dans l'onglet Aide (qui a fait la carte, ses données, ses images).
- **Le menu des addons de la minimap** et **Titan Panel** (ou un autre afficheur LibDataBroker) ouvrent la fenêtre de l'addon ; clic droit, la manette sur la carte en marche ou à l'arrêt, comme le bouton de la minimap. L'ancien bouton de minimap d'OpenMap est retiré : celui de l'addon reste.
- L'aide (onglet Aide, `/mmir aide`) et les info-bulles de la roue sont maintenant traduites dans toutes les langues.

## 0.5.0

**Le début de la fin d'OpenMap : une carte plus légère, et notre propre accès à la carte.**

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : l'addon a des fichiers nouveaux).

- **Plus de 300 Mo de moins.** Ce qui venait d'OpenMap sans servir à la carte plein écran est parti :
  - **la carte classique** (la carte d'OpenMap dessinée dans la fenêtre de carte du jeu) et son réglage « Carte classique » dans `/mmir`, avec ce qui n'existait que pour elle : la carte marine, la luminosité, le redimensionnement de la fenêtre du jeu, les réglages de compatibilité avec les autres cartes ;
  - **les amis et la guilde sur la carte**, et le partage de sa position (le calque Groupe garde ton groupe et ton raid) ;
  - les fenêtres **Nouveautés** et **Signaler un problème** d'OpenMap (les nouveautés sont celles de `/mmir news`), son écran d'accueil, ses outils de mesure ;
  - **les dessins de Santiago Reyes**, faits pour OpenMap : les terres peintes entre les zones (du papier de carte vierge à la place), la carte marine et les cartes dessinées des donjons propres à Forever (une page vide quand le jeu n'a pas de carte du donjon) ;
  - le cache d'images des zones : elles sont dessinées en direct, comme le faisaient déjà les clients français, allemand, espagnol, italien, coréen et chinois ;
  - l'icône d'OpenMap : celle de My Map Is Rich la remplace dans le menu de la carte et le bouton de la minimap.
- `/mmir carte` perd les commandes parties avec ces fonctions (`news`, `notes`, `debug`, `bench`, `welcome`, `reset`…).
- **Le menu d'une quête** : Y, ou un clic droit, sur une quête de la liste ouvre son menu, sans passer par la fiche : voir la quête, itinéraire, file, suivre, partager, lien dans la discussion, abandonner (après confirmation).
- **La marche** :
  - le réglage « Suivre les routes » devient **« Chemin à pied »**, dans l'onglet Trajets : routes au maximum, routes si possible, à travers champs ;
  - moins de détours et de zigzags : un chemin ne fait plus de crochet vers un petit bout de route ;
  - l'eau et les villes de l'autre faction sont évitées (sauf au départ et à l'arrivée) ;
  - le temps d'un trajet suit ta vitesse du moment (à pied, en monture, en forme de voyage).
- Sous le capot : tout ce que l'addon demande à la carte passe désormais par un seul fichier (`Plus/Map/Api.lua`). Les prochaines versions y remplaceront, morceau par morceau, le code d'OpenMap par le nôtre (épingles, vols, quêtes, donjons, plume, puis le dessin de la carte), avec des fenêtres à la charte de l'addon.

## 0.4.0

**Tes quêtes sur la carte, plein écran ou réduite.**

- **Toujours affichées** avec la carte, à droite : rien ne les cache, la carte qui se ferme seulement. Il n'y a plus de bouton Quêtes, et L ne fait qu'ouvrir la carte.
  - À la manette, **RT** entre dans la liste (Start reste au menu en cercle). Dans la liste, le curseur de la carte s'efface : **la croix** va de quête en quête, et la carte glisse vers chacune. LT y change le tri ; **B**, RT ou la croix gauche reviennent à la carte, et la croix gauche du jeu (« Carte ») lui redonne le curseur, comme dans le jeu. Sur la carte plein écran, à l'ouverture, la manette est déjà dans la liste si la carte n'a pas son curseur ; **A** sur une quête, au curseur, entre aussi dans la liste.
  - Sur la carte plein écran, **LT** saute d'icône en icône autour du curseur (c'était RT).
- **Le panneau, à droite**, sur toute la hauteur :
  - tes quêtes par zone ou les plus proches (LT à la manette), avec une recherche ;
  - chacune avec son niveau en couleur, sa progression et sa distance ;
  - **A, ou un clic, ouvre la fiche d'une quête** à la place de la liste, comme dans le journal du jeu : ses objectifs, son histoire, ses récompenses (les objets au choix ou donnés, avec leur info-bulle, l'argent, l'expérience) et le temps pour y aller depuis toi. **B** (ou Retour) revient à la liste ;
  - à la manette, dans la fiche : la croix haut / bas fait défiler, gauche / droite va de récompense en récompense, A suit la quête, Y l'itinéraire, X la file, LT la partage.
- **Choisir une quête** fait glisser la carte jusqu'à elle et montre sa zone. Itinéraire (Y) part tout de suite, depuis où tu es, sans aperçu à confirmer ; Ajouter à la file (X), Suivre, Partager au groupe. À la souris : Maj+clic sur une quête part aussi tout de suite, clic droit l'ajoute à la file.
- **Plein écran ou carte réduite.** Le nouveau bouton en haut à droite (à côté de la croix), ou **X** à la manette, réduit la carte : le jeu reste visible autour et ton personnage peut bouger, comme avec la carte en fenêtre du jeu. La carte réduite se joue comme le plein écran : le même rail des calques (s'il manque de hauteur, il garde les boutons qui tiennent ; le clic droit sur un calque, ou Y, ouvre le panneau de tous les calques), la même aide (raccourcie pour tenir dans la carte), « Aller à… » ouvert sur la carte ; seules tes quêtes passent dehors, collées à son bord droit. Le même geste la remet en plein écran (la croix bas du jeu, qui agrandit sa propre carte, y met aussi celle de l'addon). Le choix est retenu pour la fois suivante. Pas en combat. (X ferme toujours d'abord une fenêtre de la carte ouverte, comme la carte d'un donjon ou la plume ; le stick droit zoome.)
- **Le panneau de trajet** ne s'affiche plus sur la carte plein écran (le tracé et la fiche y disent déjà le trajet). Avec la carte réduite, où l'on marche carte ouverte, il reste à sa place, avec sa flèche GPS, et se déplace toujours à la souris. En jeu, **il se replie** : la flèche de son coin ne laisse que l'en-tête et le temps qu'il reste. À la manette : le bouton « Replier / déplier le panneau » de l'onglet Trajets (`/mmir`), ou `/mmir panneau replier`. **La flèche GPS** sous le panneau est redessinée : une flèche nette, dorée (verte dans la bonne direction), dans un disque sombre marqué d'un cran doré pour « devant toi ».
- **Le rail des calques passe à gauche**, sous la zone. Son bouton « ··· » laisse la place à deux boutons : **les maîtres de vol découverts seulement** (gryphon ou wyverne), et **les réglages de la carte** (engrenage). La fiche d'un point et l'aperçu d'un itinéraire se posent à sa droite.
- **Sur la carte plein écran, ton personnage ne bouge plus.** Les touches de déplacement font glisser la carte ; le saut, la course automatique et s'asseoir ne font rien. En combat, tout redevient normal. À la manette, le stick droit n'y tourne plus la caméra, et **le stick gauche ne fait plus marcher ton personnage** : tant que la carte n'a pas son curseur, la manette est dans tes quêtes et le stick y va de quête en quête, comme la croix (dans la fiche d'une quête, il la fait défiler). Sorti de la liste, le stick ou RT y ramène, et la croix gauche du jeu donne le curseur à la carte.

## 0.3.0

Deuxième étape de la nouvelle interface : **la fiche d'un point, l'aperçu d'un itinéraire et le menu des actions**, sur la carte plein écran.

- **La fiche d'un point** : A, ou un clic, sur une icône de la carte (donjon, maître de vol, quai, épingle, quête, PNJ de ville…) ouvre sa fiche sous le nom de la zone, et le point est cerclé d'or. La fiche dit :
  - ce qu'est le point (le titre et les lignes de son info-bulle) ;
  - sa zone et ses coordonnées ;
  - le temps pour y aller depuis toi, et par où (à pied, vol, bateau…).

  Elle propose : Itinéraire (Y), Ajouter à la file (X), l'action de l'icône (la carte du donjon, les vols du maître de vol, modifier l'épingle), Poser une épingle ici, Envoyer au groupe. B ou la croix la ferment.
- **L'aperçu de l'itinéraire** : Itinéraire (Y) sur la fiche montre tout le trajet avant de partir : le temps, l'heure d'arrivée, une barre par étape, la liste des étapes. Partir (A), Ajouter à la file (X), Annuler (B, retour à la fiche). R3 et Maj+clic partent toujours tout de suite, sans aperçu.
- **À la souris**, Alt+clic sur la carte ouvre le menu des actions là où tu as cliqué : itinéraire, file, envoyer au groupe, épingle, liste des épingles, plume, réglages de la carte. Sur une icône, Maj+clic part tout de suite et Ctrl+clic pose une épingle. À la manette, la roue (View) reste la même.
- Avant, une icône faisait son action dès le premier clic ; elle la fait maintenant depuis sa fiche.

## 0.2.0

**La carte s'ouvre en plein écran**, à la souris comme à la manette. C'est la première étape de la nouvelle interface des maquettes.

- **L'habillage de la carte** :
  - en haut à gauche, la zone sous le curseur et son continent ;
  - en haut au milieu, **Aller à…** (LB à la manette, Ctrl+F au clavier), qui ouvre pour l'instant la recherche du navigateur de lieux ;
  - en haut à droite, Me localiser, Me suivre, le menu de la carte et Fermer ;
  - en bas à droite, tes coordonnées et celles du curseur ;
  - au bord, « Toi » quand ta flèche sort de la vue (un clic recentre).
- **Le rail des calques**, à droite : donjons, maîtres de vol, bateaux et zeppelins, quêtes, citadins, groupe, épingles, dessins. Un clic affiche ou cache un calque, un clic droit montre ses détails. Le dernier bouton, ou Y à la manette, ouvre le panneau des calques avec tous les détails.
- **À la souris** : Maj+clic trace un itinéraire, Ctrl+clic pose une épingle, Alt+clic ouvre les actions, le clic du milieu te retrouve. La barre d'aide, en bas, montre les clics et les touches ; à la manette, elle montre les boutons.
- **À la manette**, le curseur parcourt tout l'écran. A presse les boutons de l'habillage et du rail.
- **L'ancienne carte reste là** : onglet Réglages de `/mmir`, « Carte classique », puis `/reload`. Il lui reste ce que la carte plein écran n'a pas encore : la carte marine, le zoom dans les grottes, la luminosité, le redimensionnement de la fenêtre, et les icônes des addons qui ne passent pas par HereBeDragons.
- Les trajets à pied **ne font plus de détour** pour rejoindre une route : ils vont au plus court en contournant les obstacles. Le réglage « Suivre les routes » ne fait plus que départager deux chemins presque aussi longs.
- Toutes les langues ont maintenant les infos-bulles des réglages et la fenêtre Nouveautés.

## 0.1.0

Première version : **la carte d'OpenMap et tout OpenMap On Gamepad dans un seul addon**.

- **La carte** : celle d'OpenMap 0.8.11, toutes les zones assemblées en une carte du monde d'un seul tenant, avec ses icônes (donjons, maîtres de vol, bateaux et zeppelins, PNJ de ville), les épingles, la plume, les cartes de donjon, les amis et la guilde, les coordonnées et les niveaux des zones. Son code est sous licence MIT (OpenMap contributors) ; il est renommé pour vivre à côté d'OpenMap sans conflit (globaux, sauvegardes, fenêtres, raccourcis clavier).
- **À la manette** (repris d'OpenMap On Gamepad 0.6.0) : R3 l'itinéraire le plus rapide, RB me suivre, LB les lieux (parcourir, rechercher au clavier, récents, la file), View la roue autour du curseur, LT / RT d'icône en icône, la croix dans les fenêtres, le clavier virtuel, les cartes de donjon.
- **Les itinéraires** : à pied par les routes en contournant les obstacles, par les vols appris, les bateaux, les zeppelins, le portail de Darnassus et le tram ; le panneau de trajet, la barre de vol, la flèche GPS, les vibrations ; les trajets en plusieurs étapes ; le retour au corps ; les destinations partagées avec le groupe et le ralliement.
- **Une fenêtre** : `/mmir` (Réglages, Trajets, Aide, Découvrir), avec un bouton « Réglages de la carte » ; `/mmir carte <…>` reprend les commandes de la carte. Un seul bouton à la minimap.
- **Avec OpenMap ou OpenMap On Gamepad activé aussi**, My Map Is Rich reste en veille et le dit : il les remplace tous les deux. Les messages entre joueurs gardent leurs préfixes, si bien que les positions d'amis, les épingles et les destinations passent entre les trois addons.
- Licence **GPL-3.0-or-later** (les données de marche viennent de Shortest Path Forever, de cjber).
