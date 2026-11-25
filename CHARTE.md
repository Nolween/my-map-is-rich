# Charte graphique — My Map Is Rich

*Reprise le 21 novembre 2026 de la charte d'OpenMap On Gamepad (elle-même reprise de My Gamepad Is Rich et My Guild Is Rich), pour que les addons se ressemblent.*
Tout nouvel écran, et chaque écran refait, suit cette charte.
Les fonctions citées sont dans [MyMapIsRich/Plus/UI/Widgets.lua](MyMapIsRich/Plus/UI/Widgets.lua) (reprises de My Auction House Is Rich), la palette dans `UI.COLORS`.

## Le périmètre

La charte vaut pour **les fenêtres de l'addon** : le navigateur de lieux, le clavier virtuel, la roue des actions, la fenêtre d'une destination reçue, le panneau de trajet, le suivi des quêtes (depuis la 1.2.0), la barre d'aide en bas de la carte, et depuis la 0.2.0 **l'habillage de la carte plein écran** (la zone, « Aller à… », les boutons, le rail des calques, les coordonnées). Le cadre doré de l'élément choisi à la croix est celui de My Guild Is Rich.

Elle ne touche **pas** :
- les fenêtres venues d'OpenMap : il n'en reste plus. Son menu et sa fenêtre de réglages AceConfig ont laissé place à l'onglet Carte de `/mmir` en 0.6.0, les fenêtres des épingles sont passées à la charte en 0.7.0, la carte d'un donjon en 0.10.0, le plateau de la plume en 0.11.0 ;
- la page de l'addon dans **Options > AddOns**, qui garde les boutons du jeu ;
- les fenêtres du jeu et des autres addons.

Différence propre à cet addon : aucune fenêtre n'entre dans `UISpecialFrames` (la liste d'Échap). L'interface manette de Forever la lit en fermant ses fenêtres, et une fenêtre d'addon y ferait bloquer B. B ferme les fenêtres de l'addon par la manette (Pad/Focus.lua).

## Les principes

1. **Aucune texture du jeu en fond.** Ni marbre, ni pierre, ni fond de boîte de dialogue, ni modèle `BasicFrameTemplate`, ni bouton `UIPanelButtonTemplate`, ni barre `UIPanelScrollFrameTemplate`. Seulement des aplats de couleur en léger dégradé vertical, dessinés par l'addon.
2. **Du brun très sombre (ou la couleur du thème choisi), des liserés d'un pixel, de l'or pour ce qui compte.** L'or signale le titre, la sélection, ce qui a été trouvé.
3. **Les polices du jeu** (`GameFont…`) : or pour les libellés, blanc pour les valeurs, gris pour le secondaire.
4. **Les couleurs qui ont un sens restent** : les pastilles des boutons de la manette (Glyphs.lua), la couleur de chaque type de bouton dans le tutoriel, le vert du type par défaut, le rouge de ce qui ne marche pas.
5. **Des panneaux, pas des traits.** Chaque zone d'un écran (liste, détail, réglages) est un panneau bordé, séparé des autres par 6 px de fond.

## La palette

| Rôle | Couleur | Clé `UI.COLORS` |
|---|---|---|
| Fond de la fenêtre | `#0d0a07` → `#15100c` (bas → haut) | `windowBottom`, `windowTop` |
| Liseré de la fenêtre (double) / intérieur | `#3b2f22` / `#6b5233` | `windowEdge`, `windowInner` |
| Panneau | `#110d0a` → `#1c1611`, liseré `#4a3b29`, trait noir à 70 % juste dedans | `panelBottom`, `panelTop`, `panelEdge` |
| Zone en retrait (la croix, une ligne, une carte) | `#0d0a08`, liseré `#2e2419` | `well`, `edgeDim` |
| Barre de titre | `#17110c` → `#2a2018`, liseré `#3b2f22` | `headerBottom`, `headerTop` |
| Or (texte, sélection, trouvé) | `#ffd100` | `gold` |
| Or doux (portrait) | `#b08a3e` | `goldSoft` |
| Texte secondaire / aide | `#a59a86` / `#8a8070` | `textDim`, `textFaint` |
| Positif (rempli, par défaut, utilisé) | `#40ff40` | `good` |
| Il manque quelque chose | `#ff7060` | `bad` |
| Fenêtre par-dessus l'écran | `#0a0806` à 98 %, liseré `#6b5a3d` | `dialog`, `dialogEdge` |
| Bord d'une case d'action | `#8a734f` (doré si trouvée, éteint si réservée au jeu) | `edgeLight`, `offRing` |

La palette complète (onglets, boutons gris, cases, champs, curseurs…) est dans `UI.COLORS`, une clé par rôle, commentée.

## Les thèmes

Le brun ci-dessus est le thème **Brun**, la référence. Les autres en dérivent couleur par couleur : **Gris clair**, **Bleu foncé**, **Vert foncé**, **Rose** (`UI.THEMES`, les mêmes que My Guild Is Rich). Le joueur choisit dans l'onglet **Options**, section Interface ; le changement est immédiat (`UI.SetTheme`), gardé dans `db.options.theme`, appliqué à la connexion (Core.lua).

Ne changent pas avec le thème : l'or, le rouge des boutons principaux, les couleurs qui ont un sens (`good`, `bad`, les pastilles des boutons).

**La règle pour tout nouvel écran** : une couleur de fond ou de liseré se prend dans la palette **par sa clé**, jamais en chiffres, sinon elle reste brune dans les autres thèmes :

| Besoin | Fonction |
|---|---|
| Aplat | `UI.Fill(texture, clé, a)` |
| Dégradé | `UI.Fade(texture, "VERTICAL", cléBas, a1, cléHaut, a2)` |
| Liseré | `UI.Border(cadre, clé, a, retrait, couche)`, puis `:SetColor(clé, a)` |
| Teinte d'une texture | `UI.Tint(texture, clé, a)` |
| Couleur d'un texte | `UI.DimText` (secondaire), ou `UI.OnTheme(fs, function() … UI.RGB(clé) … end)` |

Une couleur fixe (l'or, le noir transparent, une couleur à sens) s'écrit en chiffres avec `UI.Gradient`, `UI.Solid` ou `UI.Border(cadre, r, g, b, a)`.

Les états, sur n'importe quel élément :
- **survol** : un voile doré à 7–8 % ;
- **choisi** : un dégradé doré qui s'estompe vers la droite (20 % → 5 %) et un liseré doré ;
- **utilisé / à moi** (le profil actif) : un trait doré de 3 px sur le bord gauche de la ligne (`UI.MarkBar`) ;
- **grisé** : texte `GameFontDisable`, fond éteint.

## Le texte

| Usage | Police |
|---|---|
| Titre d'une fenêtre, d'un panneau, d'une couche | `GameFontNormalLarge` (or) |
| Libellé, section, nom de bouton | `GameFontNormal` / `GameFontNormalSmall` (or) |
| Valeur, nom dans une liste | `GameFontHighlight` / `GameFontHighlightSmall` (blanc) |
| Phrase d'accueil, explication | `UI.DimText` (gris chaud du thème) |
| Aide, rien à montrer | `GameFontDisable` / `GameFontDisableSmall` (gris) |
| Petite étiquette au-dessus d'une liste (« BARRE MANETTE ») | `UI.Label` : `GameFontDisableSmall`, en capitales |

Tout texte passe par `L` et existe dans les **10 langues**.

## Les fenêtres de l'addon

- **La fenêtre de l'addon** (`UI/MainFrame.lua`, `/mmir`, bouton de la minimap), comme celle de My Gamepad Is Rich : 980 × 640, déplaçable, fermée par Échap ou la croix ; barre de titre de 40 px (titre doré à côté du portrait, un petit trait, les onglets Réglages, Carte, Quêtes, Trajets, Aide, Découvrir avec leur icône) ; portrait rond cerclé d'or ; barre d'état de 24 px (l'état de la carte à gauche, la version à droite). Chaque écran a sa phrase d'accueil (`UI.PageIntro`) puis ses panneaux (`UI.Inset`), séparés de 6 px. Strate `DIALOG`, pour passer par-dessus la carte plein écran quand on l'ouvre depuis elle ; carte ouverte, la manette la mène comme une fenêtre de l'addon (`F.RegisterWindow` : B la ferme, LB / RB changent d'onglet).
  - **L'onglet Carte** (`UI/MapPage.lua`) : trois panneaux de même largeur (L'aspect, Au plus près, Les épingles et les donjons), des sections `UI.Section` ; une case par ligne de 30 px (son libellé sur une ligne, l'explication dans l'info-bulle, pas en dessous, faute de place) ; un curseur `UI.Slider` sur deux lignes (le nom doré au-dessus, la valeur en blanc à droite) ; un choix parmi plusieurs : son nom au-dessus, puis un bouton gris de 180 px qui passe au suivant. Un réglage sans effet pour l'instant (l'assombrissement quand les zones ne sont pas assombries) est grisé, pas caché. Un bouton gris en bas du premier panneau remet les curseurs.
  - **L'onglet Quêtes** (`UI/MainFrame.lua`, 1.2.0) : deux panneaux comme l'onglet Trajets. À gauche, Le suivi des quêtes : les cases avec leur aide dessous (`Option`), le tri et ce qu'il montre en boutons gris qui passent au suivant (`Cycle`), l'opacité du fond en `UI.Slider` (en %), « Remettre le suivi en place » en bouton gris sur la ligne de la première case, et « Remettre les quêtes masquées (n) » en bas, grisé quand il n'y en a pas. À droite, Les autres suivis : une phrase qui dit lequel est actif, et sous elle le seul bouton rouge (« Utiliser celui de My Map Is Rich », puis « Recharger l'interface ») ; dessous, Comment il marche, en puces.
  - **L'onglet Aide** (`UI/HelpTab.lua`, `UI.StepGuide`, le guide en étapes de My Guild Is Rich) : la bande du haut (sa phrase, « Revoir le tutoriel » en rouge, Nouveautés et Crédits en gris), puis deux panneaux `UI.Inset`. À gauche, 260 px : « Étapes » en petit or, puis une étape par `UI.NavButton` (son icône, son titre, son numéro en gris à droite), la choisie en or ; l'écart entre deux étapes, 40 px au plus, se resserre pour que la liste tienne. À droite, l'étape : son icône de 54 px dans un rond, sur le fond `well`, cerclée d'un anneau d'or de 64 px ; le titre en `GameFontNormalHuge`, « Étape n sur N » en gris dessous ; un trait doré ; jusqu'à 7 points en blanc, chacun après une pastille ronde de 24 px (son numéro en or sur un brun très sombre, un anneau d'or éteint), les mots importants en or (`{mot}` dans le texte, `{=CLÉ}` pour un libellé de l'interface, nommé comme à l'écran) ; une commande a au bout de sa ligne un bouton gris « Lancer ». En bas, sous un trait doré : Précédent et Suivant en boutons gris de 150 px aux deux bouts (« C'est parti ! » à la dernière étape), au milieu le seul bouton rouge, « Ouvrir cet écran » ou l'action de l'étape (Ouvrir la carte, les lieux, la file), caché quand l'étape n'en a pas. La molette passe d'une étape à l'autre. L'anneau, la pastille et son fond sont des couleurs à sens : ils s'écrivent en chiffres.
  - **Le tutoriel** (`UI/Tutorial.lua`, au premier lancement, `/mmir tuto`, « Revoir le tutoriel ») : comme celui de My Gamepad Is Rich, une fenêtre de 720 px de large (`UI.WindowChrome`, barre de titre de 36 px, sans portrait ni onglets), dont la hauteur suit le texte de l'étape. Le titre de l'étape en `GameFontNormalLarge`, le texte en blanc (les mots importants en or, comme dans l'aide), puis ce qu'on y choisit : des cases `UI.Check` de 30 px, sur une ou deux colonnes ; un choix parmi plusieurs (la taille de la carte, les couleurs, les icônes) est une rangée de cases dont une seule est cochée. Chaque case change le réglage tout de suite. Les addons semblables : une case par addon (son nom, la raison en gris à côté), cochée d'avance, puis le seul bouton rouge, « Désactiver et recharger » ; aucun addon : une phrase grise. En bas, sous un trait doré : « Passer le tutoriel » gris à gauche ; « n / N » en gris, Précédent gris et Suivant rouge à droite (« Ouvrir la carte » à la dernière étape), avec les pastilles B et A quand la manette est active. À la manette, carte fermée, le cadre doré de `Pad/Focus.lua` (2 px d'or) va d'un élément à l'autre.
  - **Les crédits** (`UI/Credits.lua`) : une petite fenêtre 560 × 440 (`UI.DialogBackdrop`), le nom de l'addon en petit gris, le titre en grand, la croix ; le texte dans un panneau qui défile (`UI.Scroll`), les intitulés en or.
- **Les fenêtres des épingles** (`Layers/PinsWindow.lua`, `UI.MapWindow`, par-dessus la carte) : la fiche (470 × 270 : la note dans un champ de la charte, la zone en gris à droite ; les cinq couleurs en carrés de 28 px, la choisie sur fond d'or ; Suivre, Dessiner, les quatre boutons de partage en boutons gris ; Retirer gris en bas à gauche, Fini rouge en bas à droite) ; la liste (12 lignes de 22 px : un point de la couleur de l'épingle, la zone, la note en blanc, « suivie » en vert et « dessin » en or ; la page en gris ; Importer, Tout partager, qui ouvre le menu de la charte, et Tout retirer en bas) ; le code (un champ de plusieurs lignes dans un panneau qui défile) ; la question (le texte, un bouton rouge pour oui, gris pour non). Chacune est donnée à la manette (`F.RegisterWindow`).
- **Le plateau de la plume** (`Layers/Sketch.lua`, `UI.MapWindow` sans portrait, en haut de la carte, ou juste sous la fiche d'une épingle quand on dessine sur elle) : une rangée de boutons carrés en retrait (`UI.PaintWell`), le choisi sur un dégradé d'or et cerclé d'or. Les six outils (46 × 44 px) montrent ce qu'ils tracent, en gris (`textDim`), en or quand ils sont choisis, leur nom dessous ; les six encres sont des gouttes rondes sur un liseré `edgeLight`, la choisie dans un anneau d'or ; les trois épaisseurs, un point de l'encre sur un bout de parchemin. Défaire et Effacer en boutons gris (Effacer demande un second clic), Terminé en rouge. Sous un trait doré : le nombre de dessins en or à gauche, l'aide de la souris en gris à droite. Les couleurs des encres sont des couleurs à sens : elles s'écrivent en chiffres.
- **La carte d'un donjon** (`Layers/DungeonView.lua`) : elle couvre la vue de la carte, au-dessus de son habillage, sur le fond de la fenêtre. Une barre de 40 px en haut (le dégradé des en-têtes, un trait `panelEdge` dessous) : à gauche un bouton gris « < Retour : la zone », au milieu le nom de l'étage en or et « 2 / 6 » en gris dans un bouton gris (un clic : la liste des étages, dans le menu de la charte) entre deux petits boutons gris « < » et « > », à droite la croix. Dessous, à 6 px des bords : la carte de l'étage dans une zone en retrait (`well`, liseré `panelEdge`), et à droite un panneau `UI.Inset` de 320 px (le nom du donjon en or, ses niveaux et « Raid » en gris, quatre onglets `UI.NavButton` de niveau 2 sur une ligne, le choisi en or, un trait doré, puis la liste qui défile : des lignes de 24 px rayées, des textes, un bouton rouge par action, les étages en vignettes deux par deux, celle de l'étage montré cerclée d'or). Les boss sont des têtes de mort sur un disque noir, leur numéro en or. Sans carte de ce donjon, la page reste vide (le dégradé des panneaux) et dit pourquoi, en gris. L'aide des premières ouvertures et la barre de la plume sont des bandeaux `UI.Panel` posés sur la carte.
- **Onglet Découvrir** (anciennement Soutenir ; `UI/DonateTab.lua` et `UI/Projects.lua`, les mêmes fichiers dans tous les addons ; icône : un coffre au trésor, `UI.DONATE_ICON`) : en haut, Mes projets (icône cadrée d'or, nom doré, une phrase, le lien à copier) ; un trait doré ; dessous, le QR code sur fond blanc cadré d'or à gauche, le titre, le texte et le lien à droite.
- La page d'Options > AddOns garde les boutons du jeu et ouvre la fenêtre.
- `UI.MapWindow(nom, l, h, titre)` : le cadre de la charte (`UI.WindowChrome`), une barre de titre de 32 px, la croix « × » dans un carré rouge cerclé d'or à droite ; ni portrait ni onglets. Strate `FULLSCREEN_DIALOG`, au-dessus de la carte du jeu ; ajoutée aux cadres du curseur de la manette (`ns.Map.Cursor.AddRoot`).
- **Navigateur de lieux** : trois colonnes de 236 px (des `UI.Inset`), séparées de 6 px, avec des lignes `UI.NavButton` de niveau 2 ; la ligne choisie est dorée.
- **Clavier virtuel** : touches de 40 × 32 px, rouges pour les lettres, grises pour les accents et les touches spéciales (chacune avec l'icône de son bouton de manette) ; le texte en cours dans une zone en retrait (`UI.Well`), le curseur du texte en or.
- **Barre d'actions** (View sur la carte) : une rangée de boutons de 118 × 44 px, le premier rouge (les réglages de la carte), les autres gris.
- **Barre d'aide** : bande de 30 px en bas de la vue de la carte (de l'écran, sur la carte plein écran), fond de fenêtre, trait doré en haut ; l'icône de chaque bouton puis ce qu'il fait (blanc : l'addon ; gris : le jeu et OpenMap). À la souris, sur la carte plein écran : les clics (l'icône de souris du jeu) et les touches (un carré de 18 px, fond `inputBg`, liseré `edgeLight`, le nom de la touche donné par le jeu : Maj, Ctrl, Alt, Échap), reliés par un « + » gris.

## Le suivi des quêtes

`UI/Tracker.lua`, depuis la 1.2.0 : un panneau **en jeu**, à la place de celui du jeu, à droite de l'écran.
- **300 px de large**, en strate `MEDIUM` : sous les fenêtres, comme le suivi du jeu qu'il remplace. Le cadre ne prend pas la souris (un clic entre deux quêtes passe au jeu) ; seuls l'en-tête, les quêtes, les en-têtes de zone et la ligne du bas la prennent.
- **Le fond** : le dégradé des panneaux (`panelBottom` → `panelTop`), liseré `panelEdge`, trait noir dedans. C'est **le seul panneau dont l'opacité se règle** (de 0 à 100 %, 70 % d'office) : il reste devant le monde tout le temps. Le liseré ne descend pas sous 35 %, pour que le panneau garde son bord.
- **L'en-tête** (28 px, le dégradé des en-têtes à 95 %) : « Quêtes » en or, « 38 / 40 » en blanc ; à droite, le tri dans un petit bouton gris (Distance ou Zone), puis la flèche qui replie, comme le panneau de trajet. On glisse le panneau par l'en-tête (sauf « Verrouiller »). Replié, il ne reste que l'en-tête.
- **Les filtres** : une rangée de `UI.NavButton` de niveau 2, de 20 px, d'égale largeur, le texte centré ; le choisi en or.
- **La liste** (un `UI.Scroll`, la barre dans les 14 px de droite) :
  - les rubriques (« À RENDRE », « EN COURS ») en petites capitales grises, le nombre à droite, un trait d'or à 22 % dessous ;
  - les zones (tri par zone) : le nom en or, la flèche qui replie et le nombre à droite ;
  - une quête : `[niveau]` dans la couleur de difficulté du jeu, le titre en or, « (Élite) » en gris ; la distance à droite en gris (un autre continent : le nom de la zone) ; dessous, en retrait de 14 px, les objectifs en blanc (« - »), faits en gris avec la coche du jeu ; un objectif qui avance s'écrit en or 1,5 s ; « Rendre à … · … » en vert (`good`) avec la coche ; le temps qui reste en or ; l'avancée du groupe en retrait de 24 px, les noms dans la couleur de leur classe ;
  - une ligne sur deux rayée (`UI.RowBackground`), la quête de l'itinéraire avec la barre d'or (`UI.MarkBar`), celle que le jeu suit en priorité sur le fond « choisi » ; survol : le voile d'or à 7 % ; une quête masquée qu'on montre : à 50 % ;
  - en bas, « 3 quêtes masquées » en gris, cliquable ; une liste vide dit pourquoi, en gris.
- **La hauteur suit la liste**, jusqu'à 60 % de l'écran et jamais sous son bas ; au-delà, elle défile.
- **L'ordre ne bouge pas sous la souris**, ni pour un écart de moins de 30 yd : une liste qui se range toute seule ne doit pas sauter sous le clic.
- Le menu d'une quête est celui de la charte (`UI.ShowMenu`), posé contre le panneau, du côté de l'écran où il y a la place.

## L'habillage de la carte plein écran

Tout est posé sur la vue de la carte (`UI/MapChrome.lua`, `UI/Layers.lua`), au-dessus de l'art, à 12 px des bords de l'écran. Chaque bande est un `UI.Overlay` : le fond de la fenêtre, un liseré `windowEdge`, un trait noir dedans, une ombre portée.

- **La zone** (en haut à gauche, 300 × 48) : le nom en or (`GameFontNormalLarge`), le continent en gris dessous. Le rail des calques se pose juste sous elle (à 66 px du haut).
- **Aller à…** (en haut au milieu, 400 × 36) : une loupe dorée, la phrase en gris, et à droite la pastille LB (manette) ou « Ctrl+F » (clavier).
- **Les boutons** (en haut à droite) : une bande de cinq carrés de 36 px (`UI.IconToggle`), séparés de 4 px : Me localiser, Me suivre (allumé quand la carte te suit), Réglages, Taille (l'icône « réduire » du jeu en plein écran, « agrandir » sur la carte réduite) ; Fermer est la croix rouge cerclée d'or, posée au coin de la carte (plein écran ou réduite). Pas de bouton des quêtes : leur panneau est toujours là. **À la manette**, une bande de 30 px (`UI.Overlay`) se pose juste dessous, avec la pastille du bouton à presser en 22 px, centrée sous son carré : RB sous Me suivre, X sous Taille, B sous Fermer ; le panneau des quêtes descend d'autant.
- **Le rail des calques** (à gauche, sous la zone : à 12 px du bord et 66 px du haut, 56 px de large) : l'étiquette « CALQUES » et la pastille Y, puis un `UI.IconToggle` de 44 px par calque, séparés de 6 px ; allumé : dégradé et liseré dorés, pastille verte ; éteint : l'icône à 40 % ; puis, de même taille, les maîtres de vol découverts seulement (allumé ou éteint) et les réglages de la carte (un simple bouton, le dernier). Pas de bouton « ··· » : le clic droit sur un calque, ou Y, ouvre le panneau. Le même rail en plein écran et sur la carte réduite : si la carte manque de hauteur, il garde les boutons qui tiennent au-dessus des coordonnées (80 px du bas), dans l'ordre, et les réglages restent les derniers.
- **Une seule règle pour les deux tailles** : un élément fait la même chose en plein écran et sur la carte réduite ; seule sa place peut changer (la liste des quêtes passe hors de la carte, la barre d'aide se pose en bas de la carte et laisse tomber ses dernières indications plutôt que d'en déborder, « Aller à… » s'ouvre sur la carte). Ne diffère que ce qui vient du jeu resté visible : les touches de déplacement et le panneau de trajet.
- **La colonne de gauche** : à droite du rail (à 74 px du bord), sous la zone, se posent la fiche d'un point et l'aperçu d'un itinéraire (le panneau de trajet n'est jamais sur la carte : caché en plein écran, à sa place en jeu avec la carte réduite). **La colonne de droite** est au panneau des quêtes. Elles ne se croisent pas.
- **Le panneau des quêtes** (`UI/QuestPanel.lua`, 400 px, une bande `UI.Overlay`, à droite sous les boutons du haut, jusqu'au-dessus des coordonnées ; sur la carte réduite, hors de la carte, collé à son bord droit à 4 px, de toute sa hauteur ; toujours affiché, sans croix) : le titre doré et le nombre de quêtes en gris ; à droite, deux onglets de tri (`UI.NavButton` de niveau 2 ; la pastille LT avant eux, qui bascule le tri, la pastille RT après, qui y fait entrer la manette) ; une recherche ; une liste de lignes de 26 px (le niveau dans la couleur de difficulté du jeu, le titre doré, blanc sur la ligne choisie, la progression, verte quand la quête est terminée, la distance en gris), les zones en en-têtes bien détachés : le nom en or et en grand (`GameFontNormalLarge`), le nombre de quêtes en blanc à droite, sur un bandeau dégradé de `goldDim` vers `headerTop`, un trait d'or de 3 px à gauche, un liseré d'or dessous et 3 px de vide au-dessus ; la liste va jusqu'en bas du panneau. **La fiche d'une quête** prend la place de la liste, comme dans le journal du jeu : en haut, Retour (petit bouton gris, pastille B), puis le titre doré, le niveau dans la couleur de difficulté, la zone en gris et « environ … · par où » ; au milieu, une zone qui défile (`UI.Scroll`), avec trois titres de section dorés soulignés d'un trait (les textes du jeu : objectifs, description, récompenses) ; les objectifs ont une coche dessinée (la texture « prêt » du jeu, la police n'a pas « ✓ ») en vert, ou « • » en blanc ; l'histoire en blanc ; les récompenses en cases de 40 px sur deux colonnes (fond `inputBg`, liseré `edgeLight`, l'icône et son nombre, le nom dans la couleur de qualité de l'objet), sous un libellé doré (« Tu pourras choisir… », « Tu recevras : », « Tu recevras aussi : »), puis l'argent avec ses pièces et l'expérience ; en bas, Itinéraire rouge et Ajouter à la file côte à côte, puis Suivre et Partager, petits boutons gris, chacun avec sa pastille de manette.
- **Le panneau des calques** (284 px, à droite du rail) : une ligne en retrait de 32 px par calque (icône, nom doré, case dessinée), la choisie en dégradé doré et texte blanc ; dessous, une zone en retrait avec les détails du calque choisi ; en bas, un bouton gris vers les réglages de la carte.
- **Les coordonnées** (en bas à droite, au-dessus de la barre d'aide) : des `UI.Pill`, fond noir à 80 %, liseré `windowInner`, libellé doré, valeur blanche.
- **« Toi »** : une pastille au bord de la vue, dans ta direction (fond noir à 70 %, liseré `goldDim`, la flèche du jeu tournée vers toi).
- **La fiche d'un point** (`UI/PointCard.lua`, 330 px, une bande `UI.Overlay`) : toujours au même endroit, sous la zone et à droite du rail ; l'icône du point en 40 px, le nom en or, la zone et les coordonnées en gris, les lignes de l'info-bulle en blanc ; une zone en retrait « Depuis toi : environ 4 min 00 », une pastille ronde par étape à la couleur de son trajet (`R.COLORS`), puis par où en gris ; dessous, les boutons de 30 px l'un sous l'autre : Itinéraire rouge (le seul), les autres gris, chacun avec la pastille de son bouton de manette à gauche. Une croix en haut à droite. Le point choisi est cerclé d'or sur la carte.
- **L'aperçu d'un itinéraire** (340 px, à la place de la fiche) : le titre, « vers … » en gris ; le temps en grand, « au total », l'heure d'arrivée à droite ; une barre de 8 px découpée par étape (3 px entre deux) ; une zone en retrait par étape (sa pastille, « 1 · à pied » en gris, ce qu'il faut faire, son temps) ; Partir (rouge) et Ajouter à la file côte à côte, Annuler dessous ; une phrase grise pour qui est pressé.

## La mise en page d'un écran

```
┌ portrait ┐ phrase d'accueil (UI.PageIntro)              [boutons de l'écran]   ← bande de 40 px
┌ liste 236 ─────────┐ ┌──────────── détail (le reste) ─────────────────────┐
│ recherche           │ │ titre · nombre                   [actions grises] │
│ ÉTIQUETTE           │ │ ──── (Rule)                                        │
│ [bouton de catégorie]│ │ zones en retrait (UI.Well) : cases, réglages      │
│ [bouton de catégorie]│ │                                                   │
│ [action grise]      │ │ avertissement · aide                              │
└─────────────────────┘ └───────────────────────────────────────────────────┘
```

- La **bande du haut** (`UI.PAGE_BAND`) porte la phrase d'accueil, à droite du portrait (`UI.PAGE_INTRO_X`), et les boutons propres à l'écran (`UI.PageButton`).
- Les panneaux commencent à `UI.PAGE_TOP`, sont séparés de **6 px** (`UI.PAGE_GAP`), avec **10 à 16 px** de marge intérieure.
- Les éléments sont placés **à des positions calculées** depuis leur panneau, pas accrochés en chaîne sur de longues listes.
- Une **liste vide** dit pourquoi, en gris.

## Les composants

| Besoin | Fonction | Règle |
|---|---|---|
| Panneau | `UI.Inset(parent)` | Le fond de toute zone d'un écran. |
| Zone en retrait | `UI.Well(parent)`, `UI.PaintWell(cadre)` | La croix et A/B/X/Y, une ligne de réglages, une carte du tutoriel. |
| Bouton principal | `UI.Button(parent, texte, l, h)` | Rouge. Un seul par groupe d'actions : OK, Importer, Suivant, Détecter, Utiliser, Revoir le tutoriel… |
| Bouton secondaire | `UI.Button(parent, texte, l, h, "grey")` | Annuler, Fermer, Effacer, Changer, Tester… |
| Flèche monter / descendre | `UI.ArrowButton(parent, "up" / "down")` | Un petit bouton gris. |
| Croix | `UI.CloseButton(parent, taille)` | Carré rouge cerclé d'or. |
| Catégorie, couche, sujet d'aide | `UI.NavButton(parent, h)` + `:SetSelected`, `:SetTextLeft` | Choisi : dégradé et liseré dorés, texte blanc. |
| Guide en étapes (l'onglet Aide) | `UI.StepGuide(page, opts)` (`UI/HelpTab.lua`) | Les étapes à gauche, l'étape choisie à droite, Précédent / bouton rouge / Suivant en bas. Les textes : `HELP_<clé>_T` et `HELP_<clé>`, un point par ligne. |
| Ligne de liste | `UI.RowBackground(row)` | Rayure une ligne sur deux (`row.stripe`), sélection `row.selected`. |
| Séparation | `UI.Rule(parent)` | Un trait doré à 22 %. |
| Titre de section | `UI.Section(parent, texte, x, y, droite)` | Titre doré, trait doré jusqu'au bord. |
| Défilement | `UI.Scroll(parent, enfant, pas)` | Un pouce doré sur fond noir, 12 px à droite du cadre ; molette. |
| Curseur | `UI.Slider(...)` | Rail sombre bordé, partie remplie en doré, curseur doré. |
| Fenêtre par-dessus l'écran | `UI.Dialog(nom, l, h, titre, strate)` | Fond `dialog`, barre de titre de 32 px, titre doré à gauche, croix ; le contenu commence à 40 px du haut. |
| Petite boîte (confirmation, nom) | `UI.Confirm`, `UI.AskText` | Fond `dialog`, un trait doré en haut. |
| Menu contextuel | `UI.ShowMenu(éléments, x, y, titre)`, `UI.HideMenu()` | 250 px, fond `dialog`, une ligne de titre grise, des lignes de 26 px (libellé doré, raccourci gris à droite), un trait doré avant un groupe ; survol en voile doré ; se ferme au clic ailleurs. |
| Bande sur la carte | `UI.Overlay(parent)`, `UI.PaintOverlay(cadre)` | Fond de la fenêtre, liseré `windowEdge`, trait noir dedans, ombre portée. |
| Bouton-icône à allumer | `UI.IconToggle(parent, taille, texture, atlas)` + `:SetOn(true / false / nil)` | Allumé : dégradé et liseré dorés, pastille verte (sauf `b.noDot`) ; éteint : icône à 40 % ; `nil` : un simple bouton. |
| Case d'action | `UI.ActionSlot(parent, taille, nom, protégé, recharge)` | Un carré sur le fond `dialog`, liseré `edgeLight`, l'icône rognée de son bord, survol en voile doré ; protégé (`SecureActionButtonTemplate`) : créé et changé hors combat seulement. Les boutons de la quête choisie (objet, cible). |
| Icône dans un bouton | `UI.SetIcon(texture, chemin, atlas)` | L'atlas du jeu s'il existe, sinon la texture (une icône d'objet est rognée de son bord). |
| Pastille de coordonnées | `UI.Pill(parent)` + `:Set(libellé, valeur, précision)` | Fond noir à 80 %, liseré `windowInner`, libellé doré, valeur blanche. |

## Cases à cocher et champs de saisie

- On les crée avec **`UI.Check(parent, texte)`**, **`UI.Input(parent, l, h)`** et **`UI.SearchBox(...)`** : le modèle du jeu, habillé tout de suite (fond sombre, liseré brun, la coche dorée du jeu reste).
- Un contrôle créé directement avec un modèle du jeu s'habille avec `UI.SkinCheck` / `UI.SkinInput`, ou `UI.SkinControls(cadre)` pour tout un cadre. La fenêtre de configuration passe `UI.SkinControls` après sa construction ; chaque `UI.Dialog` le fait à son ouverture.
- Un texte de plusieurs lignes (export, import, rapport) : **`UI.TextArea`**, fond `inputBg`, liseré `dialogEdge`, barre de défilement de la charte.
