# Journal des versions — My Map Is Rich

## 1.1.0

**Des quêtes partout, et des trajets plus courts.** Vingt idées reprises des autres addons Forever (cartes et quêtes), à la façon de My Map Is Rich : à la souris comme à la manette, sans Questie.

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : des fichiers s'ajoutent).

- **Les marqueurs de quêtes**, dans les détails du calque Quêtes (clic droit ou Y sur le rail) :
  - **les camps** : les apparitions proches d'un monstre font une seule icône, qui dit combien il y en a, et **les zones de chasse** sont tracées autour ;
  - **seulement les quêtes suivies**, et **les autres estompées** quand tu choisis une quête (sa fiche ouverte, ou la manette sur elle dans la liste) ;
  - **les quêtes bientôt prêtes** (dans un ou deux niveaux, ou une étape avant) : un « ! » violet et pâle, son info-bulle dit ce qui manque (éteint d'office) ;
  - un « ! » dit ce que sa quête a de particulier : ta classe, un donjon, répétable (un « ! » bleu), « Chaîne 2/5 ».
- **Cacher un marqueur** : sa fiche (A ou un clic dessus) a « Cacher ce marqueur ». L'onglet Carte de `/mmir`, rubrique Les quêtes, les rend.
- **Les quêtes hors de la carte**, chacune avec sa case dans les détails du calque :
  - sur **la minimap** ;
  - dans **les info-bulles** : un monstre, un PNJ, un objet du monde ou de tes sacs dit à quelle quête il sert et où tu en es (« 3/10 ») ;
  - en **icônes sur les plaques de nom** : une épée, un sac, un « ! », un « ? » (pour les PNJ amicaux, leurs plaques de nom doivent être affichées dans les options du jeu) ;
  - **deux boutons à l'écran** : l'objet de quête à utiliser et le monstre à cibler, pour la quête de ton itinéraire, sinon celle que tu suis. Maj+glisser les déplace ; leurs raccourcis sont dans Raccourcis > My Map Is Rich (la manette aussi).
- **Les lieux (LB)** ont deux onglets de plus :
  - **Près de moi** : l'aubergiste, le réparateur, le maître de vol, le maître de ta classe, le banquier, le maître des écuries et le commissaire-priseur les plus proches, avec le temps pour y aller ; Y ou A l'itinéraire ;
  - **Où aller** : les zones où tu as le plus de quêtes à prendre, avec leurs niveaux ; l'itinéraire mène au donneur qui en a le plus.
  - Dans l'onglet File, en bas : **Tout mon journal dans la file** (chaque objectif, ou à qui rendre une quête finie, dans l'ordre le plus court).
- **La pierre de foyer** compte dans les itinéraires quand elle est prête et fait gagner du temps : « Utilise ta pierre de foyer » est alors la première étape. L'auberge s'apprend là où tu la lies, ou la première fois que la pierre t'y emmène (onglet Trajets : « Utiliser la pierre de foyer »).
- **La fiche d'une quête** montre sa chaîne : les étapes faites cochées, celle-ci, la suivante et qui la donne. **Son menu** (Y ou clic droit) peut abandonner toutes les quêtes grises, après confirmation.
- **L'onglet Quêtes de la carte d'un donjon** vient maintenant de la base des quêtes de l'addon : à prendre, dans ton journal, faites ; un clic, l'itinéraire jusqu'au donneur. L'entrée du donjon dit combien sont à prendre. Questie, Dungeon Journal et NeedRoll restent au choix (onglet Carte, « Quêtes des donjons »).
- **Ce que la base ne sait pas** : une quête de Forever absente de la base est apprise quand tu la prends (ses autres personnages de ta faction voient son « ! »), et un « ! » qu'un PNJ dément s'efface jusqu'à ton prochain niveau.
- **Deux commandes** : `/mmir pourquoi <quête>` (son numéro ou son nom) dit pourquoi une quête n'a pas de « ! » ; `/mmir quetes export` donne les quêtes apprises, à copier.
- Les traductions de l'itinéraire, de la file et des lieux sont complétées dans les 8 autres langues.
- **Corrigé** : la touche qui ouvre la carte la referme aussi, carte ouverte, même quand un autre addon la pose (un bouton en plus de la manette lié à « Ouvrir la carte » dans My Gamepad Is Rich).

## 1.0.0

**My Map Is Rich se passe d'OpenMap.** De la 0.5.0 à aujourd'hui, le code d'OpenMap a été remplacé par le nôtre, une version par étape. Avec la 1.0.0, il ne reste plus rien de lui qui tourne à part.

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : des fichiers ont changé de place).

- **Rien ne devrait changer à l'écran** : la carte, ses icônes, la manette, les itinéraires et les réglages marchent comme avant.
- **Tes épingles, tes dessins, tes maîtres de vol appris et tes réglages de la carte** sont repris une fois, comme à chaque étape. Les anciennes sauvegardes ne sont pas effacées : un personnage que tu n'as pas joué depuis retrouve les siennes à sa connexion.
- **La veille** : si OpenMap ou OpenMap On Gamepad est activé aussi, My Map Is Rich n'accroche toujours rien et le dit dans la discussion.
- **`/mmir carte status`, `pins`, `draw` et `forgetflights`** marchent comme avant.
- **Tes réglages sont mieux protégés** : un nombre que le jeu ne saurait pas relire est retiré de tes sauvegardes à la déconnexion, au lieu de faire perdre tout le fichier.
- Le dessin de la carte et son zoom rapproché restent ceux d'OpenMap, portés dans l'addon, et ses données restent celles de ses outils (licence MIT, crédits dans l'onglet Aide).
- **X à la manette ne sert plus qu'à une chose : plein écran ou carte réduite**, où que tu sois sur la carte (la carte, la liste et la fiche des quêtes, la fiche d'un point, les lieux, le rail des calques, la plume, un donjon). Ce qu'il faisait d'autre passe sur **View** :
  - ajouter à la file (liste des quêtes, fiche d'un point, lieux) ; dans l'onglet File, retirer ;
  - les détails d'un calque (rail des calques) ; le clic droit dans une fenêtre posée sur la carte.
  La plume se range par View puis « Terminé », la carte d'un donjon se quitte par son bouton « < … » en haut à gauche (le curseur dessus, A). Le clavier à l'écran (effacer) et l'invitation du groupe (plus tard) gardent leur X. Sur la carte réduite, la croix bas (celle du jeu) met aussi la carte en vrai plein écran, comme X, et la croix haut la ramène en carte réduite ; un plein écran choisi par X n'est pas défait par la croix haut.
- **LT / RT sur la carte** : l'icône précédente / suivante autour du curseur. RT n'ouvre plus la liste des quêtes, toujours affichée : la croix du jeu y amène (dans la liste, RT revient toujours à la carte).
- **L'onglet Découvrir** donne maintenant la page CurseForge de My Map Is Rich (https://www.curseforge.com/wow/addons/my-map-is-rich-forever), à copier.
- **Revenus dans l'onglet Carte** (`/mmir carte`), des réglages d'OpenMap qui n'avaient plus de case :
  - « Ctrl+clic pose une épingle » (rubrique Épingles) : éteins-le si un autre addon pose la sienne au Ctrl+clic (Map Pin Enhanced) ;
  - « Minimap dans les trous (essai) » (rubrique Au plus près) ;
  - « Niveaux des zones » et « Couleur de l'assombrissement » (nouvelle rubrique Les détails) : la couleur par défaut, sépia, bleu nuit, gris, ou celle que tu avais choisie sous OpenMap.
- **Corrigé** :
  - une zone que tu viens d'explorer, ou une ville où tu entres, s'éclaircit sur la carte sans attendre un `/reload`, et les lieux « seulement trouvés » de cette zone apparaissent ;
  - un code d'épingles (`OMPINS1:`) dont une note a des espaces s'importe en entier, ceux d'OpenMap compris ;
  - la gomme de la plume met à jour le nombre de traits d'une épingle ; retirer une épingle sur laquelle on dessine range la plume ;
  - l'onglet Quêtes de la carte d'un donjon suit le journal quand une quête est acceptée ou rendue ;
  - à la manette, sur la carte réduite, la liste des quêtes défile jusqu'au bout : la manette du jeu qui y entre passe dans notre liste au lieu de s'arrêter à sa dernière ligne visible ;
  - à la manette, remonter dans la liste des quêtes la fait défiler jusqu'à la première quête, au lieu de sauter à la recherche ou aux boutons du dessus (plein écran comme carte réduite) ;
  - à la manette, un seul appui sur la croix gauche passe de la liste des quêtes au curseur de la carte (il en fallait deux) ;
  - `/mmir on` après un `/reload` fait avec l'addon coupé remet la carte de l'addon sans un autre `/reload` ;
  - en veille, l'addon ne fait plus rien : plus de trajet vers ton corps, de destinations du groupe, de page dans les Options ni de menu dans la liste des addons de la minimap.

## 0.15.0

**Le zoom rapproché passe dans le code de My Map Is Rich.**

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : l'addon a un fichier nouveau).

- **Le zoom rapproché** (la minimap du jeu qui se mêle à la carte quand tu zoomes, les capitales, les grottes et les entrées de donjon, les trous de la carte comblés) est maintenant dans l'addon lui-même. Il marche comme avant : rien ne devrait changer à l'écran.
- **Tes réglages** de l'onglet Carte, rubrique « Au plus près » (détail de la minimap, son mélange, le zoom d'où elle vient, sa profondeur, la minimap dans les capitales, « Adoucir, grain de papier », les grottes), sont repris une fois. Les anciens restent en place.
- **Tout le moteur de la carte** est désormais le code de My Map Is Rich. Il reste d'OpenMap ses sauvegardes, la veille et `/mmir carte`, qui partiront avec la 1.0.0.

## 0.14.0

**Le dessin de la carte passe dans le code de My Map Is Rich.**

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : l'addon a un fichier nouveau).

- **Le dessin de la carte** (les zones assemblées, la mer, les noms des continents et des mers, les villes, les zones inexplorées montrées, assombries ou cachées, les couleurs harmonisées) est maintenant dans l'addon lui-même. C'est le même dessin qu'avant, repris tel quel : rien ne devrait changer à l'écran.
- **Corrigé** : depuis la 0.13.0, l'addon pouvait rester en veille au chargement (« My Map Is Rich est désactivé »), parce qu'il cherchait encore une fonction des icônes partie avec elles.

## 0.13.0

**Les icônes de la carte, en code de My Map Is Rich.**

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : l'addon a un fichier nouveau).

- **Toutes les icônes de la carte** passent par notre propre moteur : les entrées de donjon, les quais, les maîtres de vol, les quêtes, les citadins, ton groupe, tes épingles, tes dessins, le point de destination et ta flèche. À l'écran, rien ne devrait changer : elles gardent leur taille quand on zoome, seules celles près de la vue sont dessinées, et chaque calque se montre à son zoom.
- **Les quais** (bateaux, tours des zeppelins, dirigeables) : leur info-bulle dit où va la traversée, dans la langue du jeu ; un clic glisse jusqu'à l'autre bout.
- « Seulement les lieux trouvés », la taille des icônes, le zoom d'où viennent celles des lieux et « Cacher les épingles du monde en instance » marchent comme avant.

## 0.12.0

**La vue de la carte, en code de My Map Is Rich.**

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : l'addon a des fichiers nouveaux).

- **La carte plein écran et la carte réduite** sont désormais notre propre vue. À l'écran, rien ne devrait changer :
  - à la souris : la molette, tirer, le clic gauche pour entrer dans une zone, le clic droit pour en sortir, le bouton du milieu pour te localiser ;
  - à la manette : le curseur jusqu'aux bords, le stick droit pour zoomer, A et X, le stick gauche enfoncé pour le point de destination ;
  - ta flèche, la zone d'une quête, les icônes de Questie et des autres addons (TomTom…) avec leurs info-bulles, les chemins des monstres de Questie.
- **Les réglages de l'aspect de la carte** (onglet Carte, rail des calques) sont repris : zones inexplorées (pour le compte ou ce personnage), assombrissement, couleurs, taille et zoom des icônes, zoom le plus profond, ta flèche, « seulement les lieux trouvés », « Cacher les épingles du monde en instance ».
- « Cacher les épingles du monde en instance » suit maintenant chaque entrée et sortie d'instance, carte fermée aussi.
- `/mmir carte status` dit où en est la vue (`/mmir carte padview` fait de même). `/mmir carte warm` est parti avec l'ancien code.

## 0.11.0

**La plume, en code de My Map Is Rich, et son plateau aux couleurs de l'addon.**

Après la mise à jour, **relance le jeu** (un `/reload` ne suffit pas : l'addon a un fichier nouveau).

- **Le plateau de la plume** (la roue, la fiche d'un point, le raccourci du jeu, `/mmir carte draw`), refait aux couleurs de l'addon :
  - les outils : stylo, ligne, flèche, cercle, marques de raid, gomme ;
  - six encres et trois épaisseurs ;
  - Défaire, Effacer (deux clics) et Terminé ;
  - en bas, le nombre de tes dessins.
- **À la souris, sur la carte plein écran** : on dessine en tirant (avant, il fallait cliquer, bouger, cliquer), tirer au clic droit déplace la carte, et la molette zoome. Ctrl+Z défait, Échap range la plume.
- **À la manette**, comme avant : A pose la plume puis la lève, X la range, View passe dans le plateau. Nouveau : A sur la marque de raid déjà choisie passe à la marque suivante (avant, il fallait un clic droit).
- **Sur une épingle** (« Dessiner » sur sa fiche), le plateau s'ouvre sous la fiche. Le dessin part avec l'épingle et se cache avec tes épingles.
- **Sur la carte d'un donjon**, la plume dessine sur l'étage, comme avant.
- Tous tes dessins sont repris, ceux des donjons aussi, avec le réglage « Tes dessins » du rail des calques.

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
