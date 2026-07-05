# New CapMan - Architecture

## Vue d'ensemble

```
Navigateur
 └- new-capman-{play|lvup-play|editor}.ejs   (+ new-capman-classement.ejs : page pure fetch)
     ├- <script> pixi-legacy.min.js        (PixiJS 5.3.12, WebGL + repli Canvas2D)
     ├- window.__NC_LVUP / __NC_EDIT       (posés par la vue -> choisissent le mode)
     ├- <script> game.js                   (Haxe 4 -> JS, compilé depuis src/)
     ├- <script> lvup.js                   (LvUP seulement : cookie + enchaînement)
     └- new CapManBoot(canvas)             (@:expose)
          ├- PIXI.Loader.shared -> capman-0.png (planche keyée) + 18 textures FX (fx/*.png)
          ├- AKApi.setMode/​setEditor       -> League | LvUP (PROGRESSION) | Éditeur
          ├- Cs.initGfx()       -> mt.pix.Store découpe la planche en frames/anims
          ├- new Game()         -> labyrinthe + héros + pièces + monstres + bonus
          │     ├- jeu normal : seq.Init (anim d'entrée) -> gstep 0
          │     └- éditeur    : initLevel direct -> new seq.Editor() (prend la main via stepFx)
          └- ticker 40 fps      -> Game.update(true) (physique + anims + rendu)
     events window : nc-ready / nc-score / nc-finished / nc-progress / nc-editor
                     -> POST /api/results (game:"newCapman", mode:"league" ; LvUP ne poste pas)
```

## Arborescence

```
Arkadeo-Public/
  build.ps1                      # compile Haxe -> web/game.js (toolchain embarquée)
  server.js                      # serveur Express + SQLite
  games.config.js                # registre du portail (tuiles)
  src/
    capman.hxml                  # config de build Haxe 4
    Boot.hx                      # @:expose("CapManBoot"), boucle 40 fps, modes, ponts events/éditeur
    Game.hx                      # cœur : grille, génération labyrinthe, loadLevel (LvUP), update, score
    Cs.hx                        # constantes + initGfx (slices/anims) + levels (= CsLevels.DATA)
    CsLevels.hx                  # 20 niveaux LvUP (chaîne haxe.Serializer)
    Square.hx                    # case de la grille (murs, pièces, distances, FX burstWall/fxTwinkle)
    Ent.hx                       # entité sur grille (mouvement moveCoef/EStep, garde anti-null)
    ent/{Hero,Bad,Bonus}.hx      # héros (clavier/bonus/pièces), base monstre (seekDir), bonus ramassable
    bad/{Classic,Skull,Block,Jumper,Hunter}.hx   # 5 types de monstres
    Door.hx                      # porte pivotante (extends EL, flip -> fx.FlipDoor)
    Level.hx                     # conteneur de scène (bg/shade/walls + plans DP_* + DepthManager)
    Inter.hx                     # HUD minimal + icône de bonus à l'écran
    Plasma.hx                    # traînée multicolore additive du Skull (disques + BlurFilter)
    Protocol.hx                  # enums BonusKind/EStep + typedefs DataProgression/DataLevel
    api/{AKApi,AKConst,AKProtocol}.hx   # API Arkadeo (score/seed/level/input + mode League/LvUP/Éditeur)
    common_haxe_avm1/KeyboardManager.hx # gestion clavier (utilitaire d'origine réutilisé)
    seq/                         # séquences (mt.fx.Sequence) :
      Init.hx                    #   anim d'entrée (scroll via mt.fx.Tween)
      Countdown.hx               #   SpeedRun : décompte 3-2-1-Go
      BadFlow.hx, BonusPop.hx    #   League : spawn progressif monstres / apparition bonus
      TimeUp.hx                  #   LvUP : pression (spawn Hunters croissant) = « timer »
      Hit.hx, Win.hx             #   mort du héros / victoire de niveau (LvUP)
      SpitCoins.hx               #   League : replace les pièces (sans reset)
      Editor.hx                  #   ÉDITEUR de niveaux (overlay stepFx)
    fx/{Spawn,FlipDoor,Focus,RunningCoin}.hx       # FX de gameplay
    gfx/{Rad,PartBadExplosion,LightTriangle,FxTex}.hx   # sprites FX (frames PNG)
    mt/
      pix/{Store,Element,Frame,Anim}.hx # couche atlas/anims PixiJS
      bumdum9/Lib.hx             # shim : SP/EL/PT/MX + Col/Arr/Num/En/Tween
      fx/{Part,Shake,ShockWave,Tween}.hx # FX PixiJS ; Manager/Fx/Sequence : utilitaires réutilisés
      Rand.hx                    # générateur pseudo-aléatoire (réutilisé)
      DepthManager.hx            # shim : add/over/empty via zIndex PixiJS
      flash/Volatile.hx          # typedef Volatile<T> = T
      MLib.hx + kiroukou/math/MLib.hx   # helpers max/min/abs/isEven
  web/
    game.js (+ .map)             # sortie Haxe
    lvup.js                      # client LvUP (cookie newcapman_lvup_level + enchaînement)
    vendor/pixi-legacy.min.js    # PixiJS vendoré
    img/content/capman/capman-0.png   # planche découpée au runtime
    img/content/capman/fx/*.png        # 18 sprites FX (disco/partbad/rad/lighttriangle)
  views/
    portal.ejs                   # portail d'accueil
    new-capman-play.ejs          # vue League
    new-capman-lvup-play.ejs     # vue LvUP (pose __NC_LVUP, barre de niveau/progression)
    new-capman-speedrun-play.ejs # vue SpeedRun (pose __NC_SPEEDRUN, chrono)
    new-capman-editor.ejs        # éditeur (pose __NC_EDIT, panneau raccourcis + import/export)
    new-capman-classement.ejs    # classement 2 onglets League + SpeedRun (fetch /api/results)
    partials/legal.ejs           # mention légale
  assets/                        # site.css, dev-counter.js, arkadeo-renderer.js, arkadeo-endgame.js, favicon, icônes
  tools/haxe4/                   # toolchain Haxe 4.3.7 embarquée (haxe + neko + haxelib pixijs)
```

## La couche de shims (`src/mt`)

CapMan est de l'AS3 Flash ; les classes `flash.*` / `mt.*` attendues sont
fournies en PixiJS par des shims sous `src/mt`. Les quelques utilitaires `mt.*`
purs (indépendants de Flash) sont réutilisés tels quels, vendorés dans `src/mt`.
Les shims fournissent en PixiJS ce que CapMan attend :

| Type CapMan (AS3) | Shim PixiJS | Notes |
|---|---|---|
| `SP` (`flash.display.Sprite`) | `mt.bumdum9.Lib.Sp` = `Container` + `.graphics`/`.scaleX`/`.scaleY` | conteneur ; `blendMode` no-op |
| `EL` (`mt.pix.Element`) | `mt.pix.Element` (couche atlas PixiJS) | sprite animé via `Store` |
| `Col`/`Arr`/`Num`/`En`/`Tween` | classes du module `mt.bumdum9.Lib` | `Col.setColor` -> `tint` |
| `mt.DepthManager` (`dm.add`) | shim `zIndex` + `sortableChildren` | la lib n'a pas `add` |
| `mt.flash.Volatile<T>` | `typedef = T` | wrapper anti-triche neutralisé |
| `mt.MLib` / `mt.kiroukou.math.MLib` | helpers locaux | `max/min/abs/isEven` |
| `api.AKApi`/`AKConst`/`AKProtocol` | client JS | score/seed/level + input via `KeyboardManager` |
| `mt.Rand`, `mt.fx.{Manager,Fx,Sequence}`, `common_haxe_avm1.KeyboardManager` | **réutilisés tels quels** (vendorés dans `src`) | utilitaires purs |

## Modèle de boucle et de rendu

CapMan tournait à **~40-42 fps** (frame rate d'auteur des SWF d'origine : la lib
graphique `gfx.swf` et le moteur `bumdum.swf` sont à 42, `gameResources.swf` à 40).
CapMan n'ayant **pas** de `game.swf` d'origine (compilé depuis les sources), la
cadence n'est lisible que dans ces libs d'assets. On retient **40 fps** (valeur
ronde, = `gameResources.swf`). Son `Game.update(true)` fait physique + avance
d'animations + rendu en un seul appel, **sans interpolation séparée** :

- `Boot` accumule `ticker.elapsedMS` et appelle `update()` par pas fixes de
  `1000/40` ms (anti-spirale : max 4 pas par frame rendu). À 30 fps le jeu tournait
  ~25 % trop lentement (héros et monstres) - corrigé à 40.
- Les entités sont des `mt.pix.Element` (pixi `Sprite`) positionnées en `.x`/`.y`
  à chaque pas ; `EL.updateAnims()` avance les timelines quand `render==true`.
- La profondeur est gérée par `mt.DepthManager` (plans `DP_*` -> `zIndex`,
  `sortableChildren=true`). Les entités sont re-triées par `y` chaque frame
  (`ents.sort(zSort)` + `dm.over`).

`devTick(n)` sur `Boot` permet d'avancer la logique à la main (tests headless où
`requestAnimationFrame` est en pause dans un onglet masqué).

## Modes de jeu (un seul moteur, dispatch dans `Boot`/`Game`)

Le même `game.js` sert les 3 modes ; la **vue** choisit le mode via des globals,
`Boot` les lit, et `AKApi` porte l'état (`progression`, `editor`, `level`) :

| Mode | Déclencheur | Effet |
|---|---|---|
| **League** | défaut | `generate()` (labyrinthe aléatoire), `MONSTERS_INIT` + `seq.BadFlow`, score, fin de pièces -> `seq.SpitCoins` (replace sans reset). |
| **LvUP** | `window.__NC_LVUP` ou `?mode=lvup` | `GM_PROGRESSION` : campagne **20 niveaux** (`Cs.MAXLEVEL` ; `Cs.campaignData()`/`loadLevel`), `seq.TimeUp`, fin de pièces -> `seq.Win` -> niveau suivant. Cf. [LVUP](LVUP.md). |
| **SpeedRun** | `window.__NC_SPEEDRUN` ou `?mode=speedrun` | `GM_PROGRESSION` + flag `speedrun` : 20 niveaux dessinés enchaînés **en mémoire** (slide `seq.Init`), 3-2-1-Go (`seq.Countdown`), chrono (`Boot.sr*`), mort → respawn niveau courant. Classement par **temps**. Cf. [SPEEDRUN](SPEEDRUN.md). |
| **Éditeur** | `window.__NC_EDIT` ou `?mode=edit` | `Game` construit le niveau **sans `seq.Init`** puis lance `new seq.Editor()` (`stepFx`, jeu en pause). Couvre 1-30 + bouton « Tester » (`playtest`/`endPlaytest`). Cf. [EDITOR](EDITOR.md). |

`Game.stepFx` est la clé de la **pause** : quand il est non-null (flip de porte,
`seq.Win`, éditeur), `Game.update()` ne fait qu'appeler `stepFx.update()` et sort
avant la logique de jeu et le `fxm`.

### Taille de grille variable

La grille est **petite (19×15, canvas 600×460)** pour League et la campagne LvUP
jouée (`Cs.MAXLEVEL=20`), et **agrandie (26×20, canvas 832×640)** pour les niveaux
≥ `Cs.BIG_FROM` (21) - utilisés dans l'**éditeur** qui va jusqu'à `Cs.EDITOR_MAX=30`.
`Cs.setSize(big)` pose
`WIDTH/HEIGHT/XMAX/YMAX` et **recalcule `CX/CY`** ; la logique (génération, IA,
indexation `x*YMAX+y`) est déjà dimension-agnostique. `Boot` choisit la taille
**au boot** selon le niveau (modèle « 1 niveau = 1 reload ») ou la change en cours
via `Boot.setSizeAndRebuild(big)` (renderer.resize + nouveau `Game` ;
`Element.clearAnimated()` purge la liste d'anims statique avant reconstruction). Le
canvas est affiché **borné au viewport** (CSS `max-width/height` + `pixelated`).

> **Reconstruction & re-entrance** : reconstruire le `Game` est sûr depuis l'éditeur
> en pause (`update()` sort tôt quand `stepFx != null`) et depuis le boundary-scroll,
> mais **pas** depuis une fin de partie en playtest (émise au cœur de `update()`).
> `Boot.endPlaytest()` diffère donc le rebuild via `setTimeout(0)`.

## Events window (host ↔ moteur)

| Event | Émis quand | Détail |
|---|---|---|
| `nc-ready` | jeu construit (en pause) | `{}` |
| `nc-score` | score modifié (League) | `{score}` |
| `nc-progress` | pièce ramassée (LvUP) | `{c, level}` (c = avancement 0->1) |
| `nc-finished` | fin de partie | `{win, score, mode, level}` -> `POST /api/results` |
| `nc-editor` | édition (éditeur) | `{level, count, modified}` |

Côté `Boot`, les méthodes `@:expose`ées appelées par le host : `startPlay()`,
`devTick(n)`, `devCap/devSpawn/devKillBads/devClear` (DEV), et
`editorExport/editorImport/editorGoto/editorClear/editorReset` + `playtest/endPlaytest`
(éditeur).

## Intégration serveur

Dans `server.js` :

- Portail `/` + 5 routes de jeu : `/new-capman` (League), `/new-capman/speedrun`,
  `/new-capman/lvup`, `/new-capman/classement`, `/new-capman/editor` -> rendent les vues `.ejs`.
- `app.use("/new-capman/assets", express.static(web/, …))` (no-store).
- `POST /api/results` / `GET /api/results` / `GET /api/stats` -> base SQLite `scores.db`.
- Tuile CapMan dans `games.config.js` (`GROUPS`) avec
  `btns: [League, LvUP, SpeedRun, Éditeur, Classement]` -> rendu automatique par `portal.ejs`.
