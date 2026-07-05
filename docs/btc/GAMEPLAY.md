# New Brutal Teenage Crisis - Règles de jeu (spécification du portage)

Référence du comportement, fidèle au jeu d'origine.

## Vue d'ensemble

Brawler « brute em all » en **vue de dessus** sur une **grille**, à **30 FPS**. On incarne un
ado armé d'une **boule-chaîne** (`ChainBall`) : on **fonce sur les monstres pour les éliminer**
et on **empêche les monstres d'atteindre le haut de l'écran**. En **League** : **survie pure**,
la difficulté monte automatiquement, la partie finit à la mort du héros (3 crédits). **Pas de
victoire** (`hasWin:false`) → score pur, enregistré au classement.

## Constantes (`src/Const.hx`)

| Const | Valeur | Sens |
|---|---|---|
| `WID × HEI` | 600 × 460 | dimensions écran (rendu natif 1:1) |
| `LWID × LHEI` | 23 × 17 | dimensions grille (cases) |
| `GRID` | 26 | taille d'une case en pixels |
| `FPS` | 30 | images/seconde |
| `GRAVITY` | 0.07 | gravité (feeling « flottant ») |
| `FRICTION` | 0.85 | friction |
| `AUTODIFF` | 30 | difficulté +1 toutes les ~30 frames (modulé par le skill) |
| `PHASE_CD` | `seconds(15)` = 450 f | cooldown de la phase |
| `PHASE_DURATION` | `seconds(2.5)` = 75 f | durée de la phase |
| Couches `DP_*` | BG, BG_FX, ENTITY, MOB, PHASE, FX, ITEM, HERO, INTERF | z-order (DepthManager) |

## Contrôles

| Entrée | Action |
|---|---|
| **Flèches ← →** | se déplacer / foncer (attaque au contact) |
| **double-tap ← ou →** | **dash** (course rapide) |
| **Espace** | **phase** : invincibilité + traversée temporaire (esquive) |
| Échap/Espace | ferme un pop-up de tuto (Progression niv.1 seulement) |

## Héros (`src/en/Hero.hx`)

- 3 crédits (`setCredits(3)`), rayon ~20 px, vitesse 0.04, gravité 0.07.
- **Boule-chaîne** (`ChainBall`) accrochée au héros (point d'attache `0x18fff7`), couette
  (`0x00bdff`) - positions lues via une **table d'attache pré-calculée**.
- **Phase** : cooldown 15 s, durée 2.5 s ; rend invincible + overlay teinté violet (`DP_PHASE`).
- **Attaque** : animation de slash au contact ; 1 dégât (5 avec SuperPower). **Slam** : si chute
  ≥ 0.30 de vélocité → +2 dégâts.
- **Skill** : score de performance passif (monte au ramassage d'or) qui module la difficulté.
- **Mort** : −1 crédit, flash écran rouge, knockback des Walkers ; game over à 0 crédit.

## Monstres (`src/en/mob/`), apparition selon `diff`

| Monstre | Apparaît | Vitesse | Vie | Spécial | Loot |
|---|---|---|---|---|---|
| **Simple** | début | 0.25× | 2 | lent, petit | 2 or |
| **Classic** | début | 1.0× | 1 | standard | - |
| **Bomber** | début | 1.0× | 3 | explose à la mort (souffle large) | - |
| **Big** | `diff ≥ 50` | 0.8× | 4 | gros, cap 2 unités | - |
| **Smart** | `diff ≥ 90` | 0.37× | 3 | pathfinding (choisit l'échelle) | 10 or |
| **Fly** | `diff ≥ 250` | 0.25× | 2 | volant (sans gravité), charge le héros (invuln pendant la charge) | 5 or |

Comportements : les **Walkers** (Simple/Classic/Big/Smart) patrouillent, montent aux échelles,
sautent les trous, évitent les collisions. **Bomber** marche comme Classic puis splash à la mort.
**Fly** erre, attend 4–7 s puis charge le héros (interruptible par une attaque).

## Items (`src/en/it/`)

| Item | Effet |
|---|---|
| **Gold** (5 paliers) | 500 / 250 / 100 / 50 / 10 points (selon l'étage). `Gold.VALUES = aconst([...])` → **AKConst**. |
| **Bomb** | nettoie les mobs proches |
| **MegaBomb** | AoE plus large |
| **SuperPower** | ×5 dégâts, ~5–6 s ; réapparaît régulièrement en League |
| **KPoint** | jetons-cadeaux d'origine - **vides en standalone** (`getInGamePrizeTokens()` = `[]`) |

## Boucle / vagues (`src/mode/League.hx`)

- **Niveau statique** lu depuis `testLevel.png` (carte de collision 23×17, `getPixel`).
- **Difficulté** : `diff` part de 0, +1 toutes les ~`AUTODIFF` frames (intervalle réduit par le skill).
- **Spawn** : max mobs = `3 + diff*0.05` ; cadence = `30 × (0.25 + 1.25 × max(0, 1 − diff/60))` frames.
- **Power-ups** : posés toutes les ~5–7 s en League.
- **Fin** : mort du héros (0 crédit) → `gameOver(false)` → overlay + `btcOnGameOver`/`btc-finished`.
- **Score** : somme des pièces ramassées (poussé via `addScore` → `btcUpdateScore`/`btc-score`,
  **sans throttle** : `addScore` n'est appelé qu'au ramassage).

## FX (`Fx.hx`)

Explosions, étincelles de coup, traînées de dash, marqueurs de danger, pops de score, flash
de perte de vie (plein écran, blend NORMAL). Particules via `mt.deepnight.Particle` ; les
`flash.filters.{Glow,Blur,DropShadow}` sont mappés sur des filtres PixiJS (WebGL).

## HUD (`src/Hud.hx`)

- **Cœurs** (crédits) en haut-gauche, **icône de phase** (se remplit selon le cooldown),
  **score** poussé à la page, champ debug (perf/fps) en `#if debug` (cosmétique).

## Mode Progression / LvUP (`mode/Progression.hx`)

Campagne **100 niveaux** générés (`com/gen/LevelGenerator`, `MAX_LEVEL=100`) : **serrures**
(`Lock` Silver/Gold/Movable) à détruire dans l'ordre → **sortie** (`Exit`) s'ouvre → l'atteindre
= `gameOver(true)`. Tuto au niveau 1. Barre de progression = coffres détruits / total. Niveau
courant en cookie `newbtc_lvup_level` ; la campagne n'est pas enregistrée au classement.
