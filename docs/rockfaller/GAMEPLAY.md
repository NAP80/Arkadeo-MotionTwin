# New Rock Faller - Règles de jeu (League)

Reprises fidèlement du Rock Faller d'origine.

## Plateau

- Stage **600×480**. Grille **6×6** (`STAGE_SIZE = 6`), `Slot.SIZE = 60`,
  origine `(STAGE_X = 120, STAGE_Y = 50)` → centres de case
  `(120 + (x+0.5)·60, 50 + (y+0.5)·60)` ; la grille couvre (150,80)→(450,380).
  (`STAGE_Y` descendu 35→50 en finition pour mieux caler tuyaux/grille sur le fond.)
- **Pierres** : 4 gemmes colorées (`id` 0-3 → anims `G0..G3`, un cristal propre par
  couleur, avec balayage de brillance) et le **rocher noir** (`id ≥ 10` → anim `Rock`,
  `isStone()`), la pierre aspirée par les tubes.
- **Tubes / exits** : 1–4 placés sur la **rangée du bas** aux colonnes tirées dans
  `EXIT_STARTS = [[0,1,4,5],[0,2,3,5]]`. Chaque tube est posé **sous** sa case
  (`EXIT_DELTA = 65`) et porte un **effet** affiché (sa valeur).

### Génération initiale
`insertStones(toCheck, 3)` pose 3 rochers (jamais sur la rangée du bas), puis
`killAutoCombo` re-tire les gemmes tant qu'un groupe ≥ 4 existe → pas de combo gratuit.
Poids des rochers en refill : `[20, 48, 30, 2]` (`randomProbs`).

## Coups (plays)
- League : **10 coups** au départ (`PLAY_COUNT[0][0]`). Affichés en colonne à gauche
  (`gfx.Play`, frame 1 = plein, frame 2 = dépensé).
- **Une rotation = 1 coup** (`spendPlay`). À **0 coup**, fin de partie → victoire
  (score pur) : `Boot.gameOver(true)` → `rf-finished`.

## Boucle (machine à états)

```
S_Play  --(clic sur une sélection valide)--▶ S_Rot
S_Rot   --(rotations finies)--▶ rotationDone → combos ? -non▶ S_Play
                                              └-oui▶ startGrab → S_Grab
S_Grab  --(vanish/aspiration finis)--▶ startFall ; combos ? -non▶ startRefill, S_Fall(false)
                                                              └-oui▶ S_Fall(true)
S_Fall  --(chutes finies)--▶ grabAgain ? -oui▶ comboCount++, startGrab, S_Grab
                                          └-non▶ S_Play
```

### Sélection
La souris désigne le coin haut-gauche d'un carré **2×2**
(`px = ⌊(mx−150)/60⌋`, `py = ⌊(my−80)/60⌋`, valides 0..4). Les 4 cases
(`SEL_DIRS = [[0,0],[1,0],[1,1],[0,1]]`) se mettent en avant (échelle lissée vers
**1,10×**) et reçoivent une **lueur blanche** qui épouse le contour de la gemme (≠ un
cadre) ; des **étincelles** (`gfx.Sparkle/2/3`) apparaissent + un son `Rocks_mouseover#`.

> **Lueur** (reproduit `Filt.glow(stone.mc, 1.7, 10, 0xFFFFFF)` de l'original) : une
> silhouette de la pierre forcée en **blanc** (`ColorMatrixFilter`) + **floutée**
> (`BlurFilter`) en mode **ADD**, posée dans le calque `layerGlow` **sous** les pierres.
> S'applique à **toutes** les pierres (gemmes ET rocher).

### Brillance (shine)
Périodiquement, **une seule couleur** de gemmes scintille à la fois, **en alternance**
(round-robin). `Game.updateShine` décrémente le délai de la couleur en tête de file
(`SHINE_WAIT = 10`) ; à expiration, toutes ses pierres scintillent en **vague diagonale**
(`Slot.setShine` → délai `(x+y)·0.1`, puis `Stone.shine()` joue le balayage du cristal),
et la couleur passe en queue. Fidèle à la sémantique `List` de l'original.

### Rotation
Clic gauche / **tap** → `startRotation` : dépense 1 coup, les 4 pierres tournent **dans
le sens horaire** (`DIRS = [[1,0],[0,1],[-1,0],[0,-1]]`, tween 5 frames). Son
`Rocks_rotate`. À la fin, `rotationDone` réordonne les pierres
(`newOrder.unshift(newOrder.pop())`) et resélectionne sous le pointeur.

> **Mobile / tactile** : entrées `pointerdown`/`pointerup` (pas `mousedown`). La rotation
> part au **relâchement** (`pointerdown` arme + surligne, `pointerup` tourne) - pas à
> l'appui. Comme il n'y a pas de survol avant le tap, `Game.update` cale la sélection
> sous le doigt (`updateSelection`) **avant** `emitRotation` → on fait pivoter le **carré
> touché**. Le canvas (600×480) est mis à l'échelle en CSS (cadre responsive) ;
> `MouseManager` remappe le tap (`clientX × view.width/rect.width`).

### Combos
`getGroups()` (flood-fill 4 directions) regroupe les gemmes connectées de même
couleur. Les groupes de **≥ 4** (`COMBO_COUNT`) sont détruits.
**Score par pierre** = `100 × (1 + 0.8·comboCount) × (nb de groupes)`
(`COMBO_MULT = 0.8`, le multiplicateur monte à chaque chaînon). Le score total du
groupe = `nb de pierres × score par pierre`. Chaque pierre : popup « +score » +
étincelles + éclat `gfx.Vanish` + fondu. Son `Blocks_X4L{1..3}` (un seul groupe) /
`Blocks_XXL{1..3}` (plusieurs), selon le niveau de combo.

### Tubes (aspiration)
Un **rocher** posé sur la case d'un tube est **aspiré** (tween vers le tube), puis
`Exit.proc()` applique l'effet :

| Effet | Poids | Valeur | Action |
|---|---|---|---|
| `Ex_Play_2/3/5/8` | 390 / 122 / 15 / 1 | +2 / +3 / +4 / +6 coups | `addPlay` |
| `Ex_Points_1/2/3` | 390 / 82 / 2 | +1500 / +3000 / +7000 pts | `addScore` |

(`FX_WEIGHTS`/`FX_VALUES`.) Son `Blackrock_life#` (coups) ou `Blackrock_points#`
(score), puis le tube se **déplace** sur une autre case libre du bas
(`switchSlot`), retire un nouvel effet et joue `Pipe`.

### Chute & refill
`startFall` compacte chaque colonne (les pierres tombent combler les trous,
gravité `g` croissante dans `Slot.fall`, son `Rock_fall#` à l'atterrissage).
`startRefill` réinjecte par le haut autant de nouvelles pierres que de cases vidées
(`toRefill[x]`), avec `insertStones` (rochers pondérés) + `killAutoCombo`. Les
combos en chaîne incrémentent `comboCount` (donc le multiplicateur).

## Pas de PK / cadeaux en League
`getInGamePrizeTokens()` est vide en League → toute la logique de badges `_pk` est
inerte (jamais affichée). Simplification assumée du portage.
