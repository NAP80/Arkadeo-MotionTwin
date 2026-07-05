# New Rock Faller - LvUP (campagne 30 niveaux) - IMPLÉMENTÉ

> **État : implémenté et vérifié (headless).** Mode PROGRESSION : 30 niveaux à
> objectif de score croissant, **sans améliorations** (modèle « PROGRESSION native »
> des autres LvUP du repo). Reste à confirmer en vrai navigateur (fluidité + audio).

## Accès
- Tuile portail **« New Rock Faller »** : 2ᵉ bouton **« Campagne LvUP (PixiJS) »**
  (empilé sous le bouton League) → `/new-rock-faller?mode=lvup`. (Pattern multi-boutons
  des cartes Arkadeo : `tiles[].btns[]` dans `games.config.js`, rendu empilé par
  `game-card__btns` qui est `flex-direction: column`.)
- Direct : <http://localhost:3000/new-rock-faller?mode=lvup>.
- League reste le 1ᵉʳ bouton → `/new-rock-faller` (sans `?mode`).

## Données (source : jeu d'origine)
- `Game.PROGRESSION_SCORES[1..30]` = `5000, 8000, 9500, … , 50000` (objectif/niveau).
- `Game.PLAY_COUNT_LVUP[1..30]` = `13,13,13,13,13,12,…,10` (coups de départ/niveau).
- `Game.LVUP_MAX_LEVEL = 30`.

## Fonctionnement
1. **Sélection du mode/niveau** (côté vue, `new-rock-faller-play.ejs`) :
   - `MODE` = `lvup` si `?mode=lvup`, sinon `league`.
   - `LEVEL` = cookie **`rockFaller_lvup_level`** (1..30, défaut 1).
   - `new RockFallerBoot(canvas, MODE, LEVEL)`.
2. **Moteur** (`Boot` porte `mode`/`level` ; `Game.initInter`) :
   - `leftPlay = PLAY_COUNT_LVUP[level]`, `objective = PROGRESSION_SCORES[level]`.
   - `Game.addScore` → `Boot.setProgress(score/objective)` → évènement **`rf-progress`**
     (barre du HUD).
3. **Fin de niveau** (`Game.setStep(S_Play)` à 0 coup) :
   - `win = score >= objective`. `Boot.gameOver(win)` → **`rf-finished`**
     `{win, score, mode:"lvup", level}`.
4. **Vue** (sur `rf-finished` en LvUP) :
   - **Gagné** → cookie `rockFaller_lvup_level = level+1` (max 30) ; bouton
     « Niveau N ▶ » (recharge `/new-rock-faller?mode=lvup`) ; au niveau 30 :
     « Campagne terminée ! 🏆 ».
   - **Perdu** → cookie inchangé ; bouton « Réessayer le niveau N ».
   - **N'enregistre RIEN au classement** : la LvUP ne fait **pas** de `POST /api/results`
     (la progression vit dans le cookie ; le classement `/new-rock-faller/classement` est
     réservé au League, lu en `mode=league`). Seul le League poste son score.
5. **HUD LvUP** : « Niveau N · Objectif X pts » + barre de progression + bouton suivant.
   Le bonus **🎁 +1 coup** reste disponible (relance la partie finie).

## Vérifié (headless, `devTick` + cookie + dispatch d'évènements)
- Niveau 3 : `leftPlay=13`, `objective=9500`, HUD affiché. ✅
- Combo → `rf-progress` ratio 0,063, barre à 6,3 %. ✅
- Échec (score 600 < 9500) → `rf-finished {win:false, level:3}`, **cookie reste 3**. ✅
- Victoire (score 10400 ≥ 9500) → `rf-finished {win:true, level:3}`, **cookie → 4**,
  bouton « Niveau 4 ▶ », « Niveau 3 réussi ! ». ✅
- 0 erreur console.

## Réutilisation
Cœur commun au League (grille, rotation, combos, tubes, chute, refill, son, FX) ;
seuls changent **coups initiaux**, **objectif**, **condition de fin** et **persistance
du niveau** (cookie). Pas de PK, pas d'améliorations.

## Pistes d'amélioration (non bloquantes)
- Écran de fin intégré au canvas (actuellement géré par la vue HTML).
- Variation de difficulté plus fine que la simple table de coups/objectifs.
