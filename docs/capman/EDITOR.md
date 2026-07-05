# New CapMan - Éditeur de niveaux

L'éditeur permet de **dessiner les niveaux** du mode [LvUP](LVUP.md) (murs,
blocs, portes, héros, monstres) directement dans le navigateur, de **tester** le
niveau construit en un clic, et de les **exporter/importer** - soit tout le
**groupe** de niveaux, soit **un seul niveau** (taille max) - via une chaîne
`haxe.Serializer`. Il couvre **30 niveaux** (`Cs.EDITOR_MAX`) : les **1-20** en
grille 19×15, les **21-30** en grande grille 26×20 (canvas 832×640) - la taille
suit le niveau édité.

> **Découplage** : l'éditeur va jusqu'à 30 (`Cs.EDITOR_MAX`), mais la **campagne
> LvUP jouée** plafonne à 20 (`Cs.MAXLEVEL`, cf. [LVUP.md](LVUP.md)). Les niveaux
> 21-30 se dessinent/se testent dans l'éditeur sans (encore) faire partie de la
> campagne jouée.

- **Route** : `/new-capman/editor` (lien « Éditeur » dans la tuile, sous « Classement »).
- **Vue** : `views/new-capman-editor.ejs`.
- **Code moteur** : `src/seq/Editor.hx`.

## Comment ça marche

L'éditeur est un **portage de `seq/Editor.hx`** d'origine. Il ne s'agit PAS d'une
réécriture en JS : c'est le vrai code de l'éditeur du jeu, recompilé en PixiJS,
qui réutilise toute la grille (`Square`, `Door`, `ent.Bad`, `ent.Hero`) et le
rendu du jeu.

1. La vue pose `window.__NC_EDIT = true` **avant** de charger `game.js`.
2. `Boot` détecte le mode (`window.__NC_EDIT` **ou** `?mode=edit`) et appelle
   `AKApi.setEditor(true)`.
3. Le constructeur de `Game` voit `AKApi.isEditor()` -> il construit le niveau
   **sans animation d'entrée** (`initLevel()` direct, `gstep = 0`) puis lance
   `new seq.Editor()`.
4. `seq.Editor` s'enregistre comme `Game.me.stepFx`. Tant que `stepFx` est posé,
   `Game.update()` **met le jeu en pause** (il ne fait qu'appeler
   `stepFx.update()` et sort avant la logique de jeu et le `fxm`). L'éditeur reçoit
   donc son `update()` à chaque frame et a la main exclusive.

## Saisie

- **Souris** : la case survolée (cadre vert) est le curseur. Position lue dans
  `Boot.me.renderer.plugins.interaction.mouse.global` (coordonnées scène = celles
  de `Square.getPos`, le stage n'étant ni scalé ni décalé). Conversion :
  `x = int((mouseX - Cs.CX) / Cs.SQ)`, idem en y.
- **Clavier** : via `common_haxe_avm1.KeyboardManager` (codes bruts, l'original
  utilisait `flash.ui.Keyboard`).

| Touche | Code | Action |
|---|---|---|
| `D` `S` `Q` `Z` | 68/83/81/90 | bascule un mur (droite / bas / gauche / haut) |
| `Espace` | 32 | bloc plein (ferme/ouvre les 4 murs) ; **maintenir = peindre** en balayant à la souris (poser/retirer figé au 1er appui) |
| `R` | 82 | rectangle : 1er appui = coin 1, 2e = coin 2 (remplit si la 1re case est libre, sinon vide) |
| `T` | 84 | porte pivotante (pose/retire) |
| `H` | 72 | place le héros (ou supprime l'entité présente) |
| `1`..`5` | 49-53 | monstre Classic / Skull / Block / Jumper / Hunter |
| `Suppr` | 46 | supprime l'entité sous le curseur |
| `←` `->` | 37/39 | niveau précédent / suivant |
| `Maj` + flèche | 16 | **décale tout le niveau** (`moveAll` : roule lignes/colonnes, ré-applique aux monstres + départ) |
| `Retour arrière` | 8 | recharge la campagne d'origine (`Cs.levels`) |
| `Échap` | 27 | quitte l'éditeur (reprend le jeu : `fillCoins` + `seekDir`) |

> `toggleMonster`/`toggleHero` sur une case **bloquée ou occupée** suppriment
> l'entité au lieu d'en poser une (comportement fidèle à l'original).

## Tester le niveau (éditeur jouable)

Le bouton **« ▶ Tester ce niveau »** lance une partie sur la configuration en
cours, sans recharger la page :

- `seq.Editor.playtest()` passe en sémantique campagne (PROGRESSION, pour que
  « toutes les pièces » = victoire) puis appelle `leave()` (retire l'overlay
  éditeur, `fillCoins`, amorce les monstres) et `hero.majHeroDist()`.
- À la **mort** (`seq.Hit`) ou à la **victoire** (`seq.Win`), `AKApi.gameOver`
  émet `nc-finished` ; la page appelle `Boot.endPlaytest()` qui **reconstruit
  l'éditeur** à la bonne taille (`setSizeAndRebuild`) - on revient à l'édition,
  niveau intact (autosauvegardé). Bouton « ⏹ Revenir à l'édition » pour sortir
  sans mourir.
- La reconstruction est **différée (`setTimeout 0`)** : `nc-finished` est émis
  pendant `game.update()`, donc rebâtir tout de suite détruirait le jeu en cours
  d'itération (crash). On attend la fin de la pile courante.

## Taille de grille & navigation (1-30)

- Navigation `←`/`→` sur **1-30** (`lim = Cs.MAXLEVEL`). Franchir la frontière
  **20↔21** change la taille de grille : l'éditeur sauve puis demande à
  `Boot.setSizeAndRebuild(big)` de reconstruire le jeu à la bonne dimension
  (le niveau cible se rouvre depuis le store).
- Au **boot** de l'éditeur, `Boot` lit le curseur dans le store pour choisir la
  taille initiale. `Cs.setSize(big)` pose `WIDTH/HEIGHT/XMAX/YMAX` et recalcule
  `CX/CY` ; `Element.clearAnimated()` purge la liste d'anims statique avant chaque
  reconstruction (sinon des sprites détruits planteraient `updateAnims`).
- `loadLevel` **synchronise `AKApi.setLevel(cursor+1)`** à chaque navigation : la
  taille choisie par `endPlaytest` (`isBigLevel(AKApi.getLevel())`) doit refléter le
  niveau réellement édité, sinon un niveau petit serait rechargé dans une grande
  grille (ou l'inverse) au retour d'essai -> map cassée.

## Persistance & échange

- **Stockage local** : clé `localStorage["newcapman_editor_levels"]` (remplace le
  `flash.net.SharedObject "pacman"` de l'original). Chaque édition appelle
  `saveLevel()` -> `saveData()` qui sérialise `data` (`haxe.Serializer.run`) dans
  localStorage. **Tout est sauvegardé automatiquement.**
- **Au chargement** : si la clé existe -> on la désérialise ; sinon on part de la
  **campagne d'origine** (`Cs.levels`), ce qui permet d'éditer les niveaux fournis.
- **Export / import du GROUPE** : exposés à la page (panneau « Import / Export ») :
  - `editorExport()` -> chaîne sérialisée de **tous** les niveaux (bouton **Copier**).
  - `editorImport(s)` -> charge une chaîne collée (rejette proprement si invalide).
  - La chaîne produite est **directement réutilisable** comme `CsLevels.DATA` pour
    figer de nouveaux niveaux dans le jeu.
- **Export / import d'UN SEUL niveau** (panneau « Niveau seul (taille max) ») :
  - `editorExportLevel()` -> chaîne sérialisée du **niveau courant seul** (un `DataLevel`,
    bouton **Exporter ce niveau**). Réservé aux niveaux **21-30** : la page bloque
    l'export sur un petit niveau, car un niveau unitaire est par convention à la
    **taille maximale** (grande grille 26×20, 520 cases).
  - `editorImportLevel(s)` -> importe un seul niveau. **Exige** une chaîne à la taille
    maximale (520 cases) - sinon rejet (et une chaîne de *groupe* est aussi rejetée),
    ce qui évite de blanchir le niveau via le garde de taille de `loadLevel`. Le niveau
    remplace le **grand niveau courant** si on en édite un ; sinon l'éditeur **bascule
    au niveau 21** (`setSizeAndRebuild(true)`, grande grille) et l'y charge.

## Format de données (`DataProgression` / `DataLevel`)

`Protocol.hx` :

```haxe
typedef DataProgression = { _cursor:Int, _list:Array<DataLevel> }
typedef DataLevel = {
  _squares:Array<Int>,  // 1 entier par case (x*YMAX + y), bitmask des murs OUVERTS
  _bads:Array<Int>,     // paires [bid, squareId] : type de monstre + case
  _doors:Array<Int>,    // squareId des portes (case d'ancrage, doorDir == 0)
  _start:Int,           // squareId du héros
}
```

- `_squares[i]` encode l'**ouverture** des murs : bit `di` à 1 = mur `di` **ouvert**.
  `saveLevel` lit `sq.getWallId()` (somme `2^di` des murs non pleins) ; `loadLevel`
  refait l'inverse : `sq.setWall(di, (n % (2^(di+1)) >= 2^di) ? 0 : 1)`.
- `bid` : 0=Classic, 1=Skull, 2=Block, 3=Jumper, 4=Hunter.

## Ponts exposés (`Boot` -> page)

| Méthode `CapManBoot.me.*` | Rôle |
|---|---|
| `editorExport()` | renvoie la chaîne sérialisée du **groupe** |
| `editorImport(s)` | importe une chaîne de **groupe** (true/false) |
| `editorExportLevel()` | renvoie la chaîne d'**un seul** niveau (courant, taille max) |
| `editorImportLevel(s)` | importe **un seul** niveau (taille max requise ; bascule au niveau 21 si besoin) |
| `editorGoto(di)` | navigue (`0`=suivant, `2`=précédent) |
| `editorClear()` | vide le niveau courant (tout en murs) |
| `editorReset()` | recharge la campagne (`Cs.levels`) |
| `playtest()` | lance l'essai sur la config construite |
| `endPlaytest()` | fin d'essai -> reconstruit l'éditeur (niveau intact) |
| `editorInfo(level,count,modified)` | **émis** par l'éditeur -> event window `nc-editor` (la page met à jour le n° de niveau, le total, et l'indicateur « ● modifié ») |

## Vérification (headless)

Simulation souris (`interaction.mouse.global`) + `dispatchEvent(KeyboardEvent)` +
`devTick(1)`. Validé : bascule de mur, bloc, pose de monstre/héros/porte,
navigation entre niveaux, persistance localStorage, export round-trip, rejet d'une
chaîne invalide, reset campagne - **0 erreur console**. La prise en main fine
(souris) se confirme dans un vrai navigateur.
