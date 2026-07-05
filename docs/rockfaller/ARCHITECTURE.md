# New Rock Faller - Architecture

## 1. Arborescence du module

```
rockfaller/
├-- src/                            # sources Haxe (+ rockfaller.hxml)
│   ├-- Boot.hx                     # @:expose("RockFallerBoot") : PIXI.Application 600×480
│   ├-- Game.hx                     # cœur : machine à états + FX + sons
│   ├-- Slot.hx / Stone.hx / Exit.hx  # case / pierre / tube (ASprite)
│   ├-- snd/Sfx.hx                  # backend audio HTML5 (musique + SFX, mute)
│   └-- common_haxe_avm1/ kado/ mt/ # utilitaires d'origine réutilisés (ASprite, MouseManager, kado.*, mt.*)
└-- web/                            # servi sous /new-rock-faller/assets
    ├-- game.js (+ .map)            # sortie de compilation
    ├-- vendor/pixi-legacy.min.js   # PixiJS 5.3.12 (WebGL + Canvas2D)
    ├-- img/content/rockfaller/     # atlas (rockfaller-0.png/json) + bg.png + fg.png
    └-- sounds/*.mp3                # 29 sons
```

Les assets (atlas, fond, avant-plan, sons) sont pré-générés à partir du jeu d'origine
et livrés dans `web/` (cf. [BUILD](BUILD.md)).

## 2. Compilation (`rockfaller.hxml`)

```hxml
-js rockfaller/web/game.js
-lib pixijs
-cp rockfaller/src
-debug
-dce no
Boot
```

`pwsh build-rockfaller.ps1` pose la toolchain embarquée (`tools/haxe4` : Haxe 4.3.7
+ Neko + haxelib pixijs) puis compile. Les utilitaires réutilisés (`ASprite`,
`MouseManager`, `kado.*`, `mt.*`) sont vendorés sous `rockfaller/src` : un seul classpath.

## 3. Boot (`Boot.hx`)

`class Boot extends pixi.core.Application`, exposé `@:expose("RockFallerBoot")`.
Le host fait `new RockFallerBoot(canvas)`.

- **PIXI.Application** 600×480, fond noir, `antialias`.
- Réutilise la lib kado : `ASprite` (racine d'affichage), `mt.DepthManager`
  (`gameRoot = dm.empty(1)`), `mt.Timer`, `KeyboardManager` + `MouseManager`,
  `kado.FixedFramerate`, `kado.Seed`.
- **Double boucle** (calquée sur `KadoKadeoManager`) :
  - `FixedFramerate` → `updatePhysics(dt)` à cadence fixe : `MouseManager.beginFrame`,
    `Timer.update`, puis `gameRoot.update()` (avance l'état + les anims `ASprite`)
    et `game.update(dt)` (logique). `clickPending` consommé puis remis à zéro.
  - `ticker` (rAF) → `gameRoot.updateGraphics(ff.alpha)` : interpole
    `_prevState → _curState` vers la position pixi réelle (rendu fluide).
- **Chargement atlas** : `PIXI.Loader.shared.add("rockfaller", …json)` +
  `"rf-bg"` + `"rf-fg"`, puis `startGame()` crée le `Game`. `"rockfaller"` ajouté
  **en premier** → c'est la spritesheet que lit `ASprite`.
- **Entrées** : `pointerdown` (souris **ou** tactile) sur le canvas → `clickPending=true`
  (front montant consommé par `Game.emitRotation`) ; `pointerup` (document) → `leftDown=false`.
  Mobile : pas de survol avant le tap → `Game.update` cale la sélection sous le doigt
  avant la rotation ; canvas mis à l'échelle en CSS (cadre responsive 5:4, `touch-action:
  none`), `MouseManager` remappe le tap.
- **Ponts host** : `startPlay()` (lance la boucle + la musique), `toggleMute()`,
  `addScore/getScore`, `gameOver(win)`, `devTick(n)` (avance N pas sans rAF, pour
  tests headless), et `emit(name, detail)` → `CustomEvent` window.

## 4. `ASprite` (lib kado) - l'outil clé

`common_haxe_avm1.display.ASprite extends PIXI.Sprite` émule un MovieClip :

- `new ASprite("Nom")` lit `sheet.data.animations["Nom"]` (liste de frames de
  l'atlas) → multi-frames ; sinon une texture unique `Nom.png`.
- API AVM1 : `_x/_y/_xscale/_yscale/_rotation` (degrés) / `_alpha` (0-100),
  `gotoAndStop/gotoAndPlay`, `play/stop`, `loop`, `stopOnFrame`, `removeOnFrame`,
  `removeMovieClip`, `_currentframe/_totalframes`, `attachMovie`, `initTextField`.
- **Important** : positionner via `_x/_y` (état `_curState`), pas via `.x/.y` brut -
  `updateGraphics(alpha)` réécrit la position pixi à partir de `_curState`. Les
  enfants `ASprite` sont mis à jour récursivement ; les `Sprite`/`Text` simples
  gardent la position qu'on leur fixe directement (utilisé pour bg/fg et les Text).
- **Getters Haxe** : en JS, `_x` n'est pas un champ mais `get__x()` (utile à savoir
  pour le débogage console : lire `mc._curState.x` / `mc.get__x()`).

## 5. `Game` - calques et boucle

**Calques** (conteneurs `ASprite`, z du fond vers l'avant) : `layerBg`, **`layerGlow`**,
`layerStones`, `layerExits`, `layerInter`, `layerScore`, `layerFx`, **`layerFgGems`**,
`layerFg`. (Z-order explicite, plus simple que `DepthManager` pour ce jeu.) `layerGlow`
(entre le fond et les pierres) porte les **halos de sélection** ; le placer **sous toutes
les pierres** évite que le halo d'une pierre masque la gemme voisine du carré 2×2.
`layerFgGems` porte les **5 gemmes déco du fond** (asset `Deco`), **sous `layerFg`**
et **masqué par `fg_mask`** → gemmes **partielles**. `layerFg` reçoit l'avant-plan
(`fg.png` : cadre + lèvres rocheuses).

**Machine à états** (`enum Step`) fidèle à l'original :
`S_Play → S_Rot → S_Grab → S_Fall(grabAgain) → (combo encore ?)`, `S_Game_Over`.
Chaque frame : `updateFx()` (tweens), consommation du clic, `Slot.update()` (échelle
sélection), `Slot.fall()` (chute), spawner de boue, puis le `switch (step)`.

**Tweens inline** (`fxList:Array<Void->Bool>`) : closures renvoyant `true` quand
finies. `tweenTo(mc, x, y, dur, onFinish)` (smoothstep) pour la rotation et
l'aspiration ; `vanishFx(mc, dur, onFinish)` (fondu + rétrécissement) pour la
destruction ; `waitingFx` compte les anims bloquantes (les transitions d'état
attendent `waitingFx==0` / `falls.length==0`).

Détail des règles : [GAMEPLAY](GAMEPLAY.md).

## 6. Ponts score / fin → site

| Émis (Boot) | Quand | Reçu (vue EJS) → action |
|---|---|---|
| `rf-ready` | partie créée (figée) | affiche le bouton « Jouer » |
| `rf-score` | `addScore` | met à jour l'affichage du score |
| `rf-finished` | `gameOver(win)` (0 coup) | **League seulement** → `POST /api/results` `{game:"newRockFaller", mode:"league", win, score, durationMs}`. **LvUP : aucun POST** (la campagne n'entre pas au classement ; sa progression vit dans le cookie) |

> **Enregistrement** : le portage enregistre sous **`game:"newRockFaller"`**. Classement
> dédié : route `/new-rock-faller/classement` (vue `new-rock-faller-classement.ejs`) qui lit
> `/api/results?strict=1&game=newRockFaller&mode=league` (**`strict`** force un match EXACT
> du jeu ; **`mode=league`** → la campagne LvUP n'apparaît jamais au classement).

Pas d'API `AKApi` : la logique du shim League d'origine est repliée directement dans
`Game`/`Boot` (file d'events = `clickPending`, score = `Boot.addScore`,
gameOver = `Boot.gameOver`).

## 7. Serveur

Dans `server.js` : `app.get("/new-rock-faller")` (League + `?mode=lvup`),
`app.get("/new-rock-faller/classement")`, et
`app.use("/new-rock-faller/assets", express.static("rockfaller/web", …))` (no-store).
Tuile dans `games.config.js` (`GROUPS`) → rendu automatique par `portal.ejs`. Le
classement lit `/api/results?strict=1&game=newRockFaller&mode=league`.
