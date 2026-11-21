# Charte graphique — My Map Is Rich

*Reprise le 21 novembre 2026 de la charte d'OpenMap On Gamepad (elle-même reprise de My Gamepad Is Rich et My Guild Is Rich), pour que les addons se ressemblent.*
Tout nouvel écran, et chaque écran refait, suit cette charte.
Les fonctions citées sont dans [MyMapIsRich/Plus/UI/Widgets.lua](MyMapIsRich/Plus/UI/Widgets.lua) (reprises de My Auction House Is Rich), la palette dans `UI.COLORS`.

## Le périmètre

La charte vaut pour **les fenêtres de l'addon** : le navigateur de lieux, le clavier virtuel, la roue des actions, la fenêtre d'une destination reçue, le panneau de trajet et la barre d'aide en bas de la carte. Le cadre doré de l'élément choisi à la croix est celui de My Guild Is Rich.

Elle ne touche **pas** :
- les **fenêtres de la carte** venues d'OpenMap (son menu, les épingles, les donjons, la fenêtre de réglages AceConfig...) : en 0.1.0 elles gardent l'apparence d'OpenMap ; les passer à la charte est prévu ;
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

- **La fenêtre de l'addon** (`UI/MainFrame.lua`, `/mmir`, bouton de la minimap), comme celle de My Gamepad Is Rich : 980 × 640, déplaçable, fermée par Échap ou la croix ; barre de titre de 40 px (titre doré à côté du portrait, un petit trait, les onglets Réglages, Aide, Soutenir avec leur icône) ; portrait rond cerclé d'or ; barre d'état de 24 px (l'état d'OpenMap à gauche, la version à droite). Chaque écran a sa phrase d'accueil (`UI.PageIntro`) puis ses panneaux (`UI.Inset`), séparés de 6 px.
- **Onglet Découvrir** (anciennement Soutenir ; `UI/DonateTab.lua` et `UI/Projects.lua`, les mêmes fichiers dans tous les addons ; icône : un coffre au trésor, `UI.DONATE_ICON`) : en haut, Mes projets (icône cadrée d'or, nom doré, une phrase, le lien à copier) ; un trait doré ; dessous, le QR code sur fond blanc cadré d'or à gauche, le titre, le texte et le lien à droite.
- La page d'Options > AddOns garde les boutons du jeu et ouvre la fenêtre.
- `UI.MapWindow(nom, l, h, titre)` : le cadre de la charte (`UI.WindowChrome`), une barre de titre de 32 px, la croix « × » dans un carré rouge cerclé d'or à droite ; ni portrait ni onglets. Strate `FULLSCREEN_DIALOG`, au-dessus de la carte du jeu ; ajoutée aux cadres du curseur de la manette d'OpenMap (`mod.padRoots`).
- **Navigateur de lieux** : trois colonnes de 236 px (des `UI.Inset`), séparées de 6 px, avec des lignes `UI.NavButton` de niveau 2 ; la ligne choisie est dorée.
- **Clavier virtuel** : touches de 40 × 32 px, rouges pour les lettres, grises pour les accents et les touches spéciales (chacune avec l'icône de son bouton de manette) ; le texte en cours dans une zone en retrait (`UI.Well`), le curseur du texte en or.
- **Barre d'actions** (View sur la carte) : une rangée de boutons de 118 × 44 px, le premier rouge (le menu d'OpenMap), les autres gris.
- **Barre d'aide** : bande de 30 px en bas de la vue de la carte, fond de fenêtre, trait doré en haut ; l'icône de chaque bouton puis ce qu'il fait (blanc : l'addon ; gris : le jeu et OpenMap).

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
| Ligne de liste | `UI.RowBackground(row)` | Rayure une ligne sur deux (`row.stripe`), sélection `row.selected`. |
| Séparation | `UI.Rule(parent)` | Un trait doré à 22 %. |
| Titre de section | `UI.Section(parent, texte, x, y, droite)` | Titre doré, trait doré jusqu'au bord. |
| Défilement | `UI.Scroll(parent, enfant, pas)` | Un pouce doré sur fond noir, 12 px à droite du cadre ; molette. |
| Curseur | `UI.Slider(...)` | Rail sombre bordé, partie remplie en doré, curseur doré. |
| Fenêtre par-dessus l'écran | `UI.Dialog(nom, l, h, titre, strate)` | Fond `dialog`, barre de titre de 32 px, titre doré à gauche, croix ; le contenu commence à 40 px du haut. |
| Petite boîte (confirmation, nom) | `UI.Confirm`, `UI.AskText` | Fond `dialog`, un trait doré en haut. |
| Menu contextuel | `UI.ShowMenu` | Fond `dialog`, survol en voile doré. |

## Cases à cocher et champs de saisie

- On les crée avec **`UI.Check(parent, texte)`**, **`UI.Input(parent, l, h)`** et **`UI.SearchBox(...)`** : le modèle du jeu, habillé tout de suite (fond sombre, liseré brun, la coche dorée du jeu reste).
- Un contrôle créé directement avec un modèle du jeu s'habille avec `UI.SkinCheck` / `UI.SkinInput`, ou `UI.SkinControls(cadre)` pour tout un cadre. La fenêtre de configuration passe `UI.SkinControls` après sa construction ; chaque `UI.Dialog` le fait à son ouverture.
- Un texte de plusieurs lignes (export, import, rapport) : **`UI.TextArea`**, fond `inputBg`, liseré `dialogEdge`, barre de défilement de la charte.
