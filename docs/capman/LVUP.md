# New CapMan - Mode LvUP (campagne) & Classement

À côté du mode **League** (labyrinthe généré aléatoirement, score pur), New CapMan
propose un mode **LvUP** : une **campagne de 20 niveaux** (tous en grille 19×15) à
réussir l'un après l'autre. C'est le pendant du mode « PROGRESSION » de l'original.

> **Campagne jouée vs éditeur** : la campagne **jouée** plafonne à 20
> (`Cs.MAXLEVEL`). L'**éditeur**, lui, va jusqu'à 30 (`Cs.EDITOR_MAX`) et dessine
> les niveaux 21-30 en **grande grille 26×20** (≥ `Cs.BIG_FROM`=21) - cf.
> [EDITOR.md](EDITOR.md). Pour intégrer ces niveaux à la campagne jouée, remonter
> `Cs.MAXLEVEL` à 30.

- **Route jeu** : `/new-capman/lvup` (bouton « LvUP » de la tuile).
- **Route classement** : `/new-capman/classement` (bouton « Classement »).
- **Vues** : `new-capman-lvup-play.ejs`, `new-capman-classement.ejs`.
- **Client** : `web/lvup.js`.

## Activation du mode

`Boot` passe en PROGRESSION si `window.__NC_LVUP == true` (posé par la vue LvUP)
**ou** si l'URL contient `?mode=lvup` :

```haxe
var lvup = (untyped window.__NC_LVUP == true) || location.search.indexOf("mode=lvup") >= 0;
AKApi.setMode(lvup, lvup ? readLevelCookie() : 1);
```

`AKApi.getGameMode()` renvoie alors `GM_PROGRESSION`. La **seed** est fixée au
numéro de niveau (`seed = level`) -> les éventuels niveaux générés (au-delà des 20
dessinés) sont reproductibles d'une tentative à l'autre.

## Source des niveaux (`Cs.campaignData()`)

- La campagne est lue via **`Cs.campaignData()`** : le blob `localStorage`
  `newcapman_editor_levels` (édité, s'il existe), **sinon** les 20 niveaux bakés
  `Cs.levels` = `CsLevels.DATA` (chaîne `haxe.Serializer`, cf.
  [EDITOR.md](EDITOR.md) § Format de données). Ainsi éditer reflète immédiatement
  la campagne ; un navigateur vierge joue les 20 bakés.
- `CsLevels.hx` contient les 20 niveaux dessinés (chaîne `haxe.Serializer`), extraits du jeu d'origine.
- `Game.initLevel()` (branche `GM_PROGRESSION`) désérialise `Cs.campaignData()`,
  prend le niveau `AKApi.getLevel() - 1` et le charge via `loadLevel(DataLevel)`. Si
  ce niveau n'est pas dessiné (absent / au-delà des fournis), il **génère** un
  labyrinthe à la **taille courante** (grand pour 21-30).
- **Taille par niveau** : `Boot` décide au démarrage (`Cs.setSize(big)` avec
  `big = niveau >= 21`) avant de créer le jeu - possible car chaque niveau LvUP
  recharge la page. `initGrid()` choisit un skin de tuiles (`skinId = level % 4`).
- *Pour livrer 30 niveaux dessinés à d'autres joueurs, baker l'export de l'éditeur
  dans `CsLevels.hx` (suivi ultérieur) ; aujourd'hui 21-30 vivent dans le
  localStorage de l'auteur.*

## Déroulé d'un niveau

1. **Pression croissante** (`seq.TimeUp`, le « timer » du mode) : après
   `coinMax * 25` frames, fait apparaître un Hunter (`fx.Spawn(4)`), puis un toutes
   les **600 frames**, jusqu'à dépasser 16 monstres. C'est ce qui pousse le joueur à
   finir vite plutôt qu'un compte à rebours visible.
2. **Toutes les pièces ramassées** -> `Game.onLastCoin()` lance `seq.Win` (en LvUP) :
   fige le jeu, secoue puis **explose tous les monstres** (`gfx.PartBadExplosion`),
   puis appelle `AKApi.gameOver(true)`.
3. **Progression** : `Square.removeCoin` pousse `AKApi.setProgression(1 - coins/coinMax)`
   -> event `nc-progress {c, level}` -> barre de progression de la page.

## Cookie & enchaînement (`lvup.js`)

- Cookie **`newcapman_lvup_level`** (1..`MAX`=20). `Boot.readLevelCookie()` le lit
  au démarrage (et en déduit la taille de grille) ; `lvup.js` l'écrit.
- À `nc-finished {win, score, mode, level}` :
  - **Pas d'enregistrement** : le LvUP est une progression personnelle → il
    **n'écrit PAS** dans `/api/results` (le classement est réservé au mode League).
  - **Victoire** : niveau + 1 (ou retour à 1 si le niveau `MAX` est franchi).
  - **Échec** : on rejoue le même niveau.
  - Rechargement de `/new-capman/lvup` après ~2,5 s (modèle « 1 niveau = 1 reload »).
- La page démarre le moteur avec `new CapManBoot(canvas)` et un écran « ▶ Jouer »
  (`startPlay()`), comme la vue League.

## Classement (`/new-capman/classement`)

La page `/new-capman/classement` a **deux onglets** : *League* (score) et *SpeedRun*
(temps). **Le LvUP n'écrit PAS dans le classement** (progression personnelle). Onglet
League : `/api/results` en **`strict=1&game=newCapman&mode=league`**, tri par score
décroissant, bandeau *Parties · Score max · Score moyen*.
L'onglet SpeedRun (temps) est détaillé dans [SPEEDRUN.md](SPEEDRUN.md). ⚠ La page de jeu
League poste `game:"newCapman"` (cf. `new-capman-play.ejs`).

## Différence avec League

| | League (`/new-capman`) | LvUP (`/new-capman/lvup`) |
|---|---|---|
| Labyrinthe | généré (seed aléatoire) | 20 niveaux dessinés (19×15 ; générés au-delà) |
| Fin (toutes pièces) | `seq.SpitCoins` (replace les pièces, **pas de reset**) | `seq.Win` -> niveau suivant |
| Monstres | `MONSTERS_INIT` + `seq.BadFlow` | départ dessiné + `seq.TimeUp` (pression) |
| Score | compte (`nc-score`) | non pertinent (progression par niveau) |
| Animation d'entrée | `seq.Init` (scroll) | `seq.Init` (scroll) |
