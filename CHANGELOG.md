# Journal des versions — My Map Is Rich

## 0.4.0

**Tes quêtes sur la carte plein écran.**

- **Affichées de base** quand la carte plein écran s'ouvre. Ensuite, elles restent comme tu les as laissées en fermant la carte : affichées ou cachées.
  - Au clavier et à la souris, **L** ou le nouveau bouton **Quêtes** (le premier en haut à droite) les affiche ou les cache.
  - À la manette, **RT** entre dans la liste (et l'affiche si elle était cachée ; Start reste au menu en cercle). Dans la liste, le curseur de la carte s'efface : **la croix** va de quête en quête, et la carte glisse vers chacune. LT y change le tri, RT ferme les quêtes, **B** revient à la carte, qui retrouve son curseur. À l'ouverture de la carte, la liste affichée reste au repos : la carte garde son curseur, et **A** sur une quête, au curseur, entre aussi dans la liste.
  - Sur la carte plein écran, **LT** saute d'icône en icône autour du curseur (c'était RT).
- **Le panneau, à droite**, sur toute la hauteur :
  - tes quêtes par zone ou les plus proches (LT à la manette), avec une recherche ;
  - chacune avec son niveau en couleur, sa progression et sa distance ;
  - **A, ou un clic, ouvre la fiche d'une quête** à la place de la liste, comme dans le journal du jeu : ses objectifs, son histoire, ses récompenses (les objets au choix ou donnés, avec leur info-bulle, l'argent, l'expérience) et le temps pour y aller depuis toi. **B** (ou Retour) revient à la liste ;
  - à la manette, dans la fiche : la croix haut / bas fait défiler, gauche / droite va de récompense en récompense, A suit la quête, Y l'itinéraire, X la file, LT la partage.
- **Choisir une quête** fait glisser la carte jusqu'à elle et montre sa zone. Itinéraire (Y) ouvre l'aperçu du trajet, Ajouter à la file (X), Suivre, Partager au groupe. À la souris : Maj+clic sur une quête part tout de suite, clic droit l'ajoute à la file.
- **Plein écran ou fenêtre.** Le nouveau bouton en haut à droite (à côté de la croix), ou **X** à la manette, met la carte en fenêtre : le jeu reste visible autour et ton personnage peut bouger, comme avec la carte en fenêtre du jeu. Tes quêtes y sont toujours affichées, hors de la carte, collées à son bord droit (la croix gauche, RT ou B rendent la manette et le curseur à la carte). Le même geste la remet en plein écran (la croix bas du jeu, qui agrandit sa propre carte, y met aussi celle de l'addon). Le choix est retenu pour la fois suivante. Pas en combat. (X ferme toujours d'abord une fenêtre de la carte ouverte, comme la carte d'un donjon ou la plume ; le stick droit zoome.)
- **Le panneau de trajet** ne s'affiche plus sur la carte (le tracé et la fiche y disent déjà le trajet) ; en jeu, **il se replie** : la flèche de son coin ne laisse que l'en-tête et le temps qu'il reste. À la manette : le bouton « Replier / déplier le panneau » de l'onglet Trajets (`/mmir`), ou `/mmir panneau replier`. **La flèche GPS** sous le panneau est redessinée : une flèche nette, dorée (verte dans la bonne direction), dans un disque sombre marqué d'un cran doré pour « devant toi ».
- **Le rail des calques passe à gauche**, sous la zone. La fiche d'un point et l'aperçu d'un itinéraire se posent à sa droite.
- **Sur la carte plein écran, ton personnage ne bouge plus.** Les touches de déplacement font glisser la carte ; le saut, la course automatique et s'asseoir ne font rien. En combat, tout redevient normal. À la manette, le stick droit n'y tourne plus la caméra.

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
