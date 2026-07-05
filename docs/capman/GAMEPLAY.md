# New CapMan - Gameplay (CapMan = Pac-Man)

CapMan est un **Pac-Man** : on déplace le héros dans un labyrinthe pour ramasser
**toutes les pièces** en évitant les monstres. **Aucun tube, aucune pierre qui
tombe, aucun son** - ces mécaniques ne font pas partie de CapMan.

## Plateau

- Grille **19×15** cases (`Cs.XMAX`/`Cs.YMAX`), case = **32 px** (`Cs.SQ`).
- Surface **600×460** (`Cs.WIDTH`/`Cs.HEIGHT`) ; offsets de grille
  `CX = (600-19·32)/2 = -4`, `CY = (460-15·32)/2 = -10` (les bords débordent
  légèrement, comme l'original).
- Chaque `Square` stocke 4 murs (`walls`), d'éventuelles pièces, portes,
  distances de pathfinding (`hdist`).

## Génération du labyrinthe (mode League)

`Game.generate()` (repris verbatim) :

1. Marque les cases de bordure comme `out` (zone jouable centrale).
2. `snakeIt()` - serpents aléatoires seedés qui creusent des couloirs jusqu'à
   remplir la zone.
3. Ouvre les culs-de-sac à 3 murs, puis ouvre des passages vers les cases les
   plus lointaines (BFS `buildDistFrom`) pour réduire les impasses.
4. Place **2 portes** (`new Door()`) sur les meilleures positions (`getDoorScore`).

Déterminisme via `mt.Rand(seed)` (`seed = AKApi.getSeed() + AKApi.getLevel()`).

## Modes de jeu

- **League** (`/new-capman`) : labyrinthe **généré** (ci-dessus), score, monstres
  via `seq.BadFlow`. Toutes les pièces -> `seq.SpitCoins` (replace, pas de reset).
- **LvUP** (`/new-capman/lvup`) : campagne de **20 niveaux dessinés** (chargés
  depuis `Cs.levels`), pression croissante (`seq.TimeUp`), toutes les pièces ->
  `seq.Win` -> niveau suivant. Détails dans [LVUP.md](LVUP.md).
- **Éditeur** (`/new-capman/editor`) : conçoit ces niveaux. Détails dans [EDITOR.md](EDITOR.md).

## Animation d'entrée

Au démarrage d'un niveau (League et LvUP), `seq.Init` crée le niveau puis le fait
**glisser depuis la droite** (`mt.fx.Tween`, courbe in/out, `x: 604 -> 0`) ; un
éventuel niveau précédent sort par la gauche. À la fin, `gstep = 0` (jeu jouable).
Le mode Éditeur saute cette animation (construction directe).

## Héros

- **Déplacement** : flèches directionnelles, sur grille avec interpolation fluide
  (`moveCoef` 0->1 entre deux cases). `EStep` = `VOID`/`MOVE`/`JUMPING`.
- **Demi-tour instantané** : presser la direction opposée pendant un déplacement
  inverse la progression (réactif, fidèle à l'original).
- **Pièces** : franchir une case contenant une pièce la ramasse. Score = base
  (20) + incrément (5) × combo consécutif, plafonné à 60 (`Cs.SCORE_BALL*`). Le
  combo se réinitialise si on passe sur une case sans pièce.
- **Animations** : `hero_walk_<dir>` (marche), `hero_die` (mort), variantes
  `_shoe` (bonus saut) et `_cap` (bonus étoile).
- **Pièces toutes ramassées (League)** : déclenche `seq.SpitCoins` - des pièces
  « courent » (`fx.RunningCoin`) depuis la case du héros et se **replacent** sur
  toutes les cases libres. Le niveau **n'est PAS réinitialisé** : labyrinthe,
  monstres et bonus restent tels quels ; seules les pièces reviennent.

## Bonus

- 🥾 **Chaussures** (`BK_Jump`) : permet de **sauter par-dessus un mur** (touche
  Espace pour activer le bonus ramassé). Le saut suit une trajectoire en `z`
  (`-sin(moveCoef·π)·20`).
- ⭐ **Casquette** (`BK_Star`) : **invincibilité** - les monstres explosent au
  contact au lieu de tuer, et rapportent un **bonus de score en combo** (style
  Pac-Man : 100 -> 200 -> 400 -> 800, plafonné ; remis à 0 à chaque nouvelle casquette).
  *(Ajout du portage : `Game.addStarKill` ; l'original ne donnait pas de score sur
  ce kill.)*
- Durée : `Cs.BONUS_LIFE = 210` frames, avec clignotement de fin.

## Monstres - 5 types

Spawn progressif (League : `seq.BadFlow` ; LvUP : `seq.TimeUp`), pathfinding par
distance BFS au héros (`hdist`, recalculée à chaque case via `majHeroDist`).
Collision à moins de ~6 px -> mort du héros (`seq.Hit` -> `nc-finished`), sauf
invincibilité (le monstre explose et rapporte un combo de score).

| Type | Comportement |
|---|---|
| `Classic` | chasseur simple (`smiley_turn`) |
| `Skull` | chasse + charge focalisée (`skull_base`/`skull_fire`) |
| `Block` | fonce et **casse les murs** (`burstWall`) (`blocker_*`) |
| `Jumper` | **saute par-dessus** les murs (`jumper_*`) |
| `Hunter` | pathfinding agressif, vitesse oscillante (`seeker_fly`) |

## Portes

Cases spéciales reliant deux couloirs ; pivotent (`flip`) quand le héros les
traverse, réorientant le passage. État de mur dédié (`2`) traversable par les
calculs de distance « passDoor ».

## API / fin de partie

- `api.AKApi` (mock) : `getSeed`/`getLevel`/`getGameMode` (League ou PROGRESSION),
  `setMode`/`setEditor`, `isDown`/`isToggled` (via `KeyboardManager`), `addScore`,
  `setProgression` (LvUP), `gameOver`.
- Le score est émis en `nc-score` (League, affiché par le host) ; l'avancement LvUP
  en `nc-progress`. La fin de partie en `nc-finished {win, score, mode, level}`. Seul
  **League** enregistre : `POST /api/results` (`game:"newCapman", mode:"league"`) ; le
  LvUP est une progression personnelle, hors classement.
- Boutons **DEV** (page League) : `devCap()` (donne la casquette étoile),
  `devSpawn(id)` (1 par monstre), `devKillBads()`, `devClear()` (console, teste
  `SpitCoins`).
