# New Brutal Teenage Crisis - Architecture

## Principe

La logique Haxe d'origine de BTC est **recompilée Haxe 4 → JS**, sa couche de rendu Flash
étant remplacée par **PixiJS** via une couche de shims. Deux familles de code, toutes deux
vendorées sous `btc/src` :

- **Logique réutilisée** (reprise quasi verbatim du jeu d'origine) : `Game`, `Mode`,
  `mode/League`, `Entity`, `Hero`, `Mob` + `en/mob/*`, `en/it/*`, `Level` (collision),
  `Const`, `com/gen/LevelGenerator` (campagne), et les utilitaires `mt.deepnight.slb.AnimManager`,
  `mt.deepnight.Color`, `mt.Rand`, `mt.Cooldown`, `mt.RandList`, `mt.deepnight.Lib`, `mt.deepnight.Tweenie`.
- **Shims / adaptations PixiJS** : tout ce qui touche Flash/rendu - le package `flash.*`,
  le pont SpriteLib (`mt.deepnight.slb.*`), `mt.flash.DepthManager`, `Fx`, `Hud`, l'API `api.*`,
  et les modes ajoutés `mode/Endless` (Défi) et `mode/Progression` (campagne).

Tout est dans un seul classpath (`-cp btc/src`) : seules les versions « gagnantes » (shim si
présent, sinon original) ont été vendorées, donc pas de conflit de résolution. Comme les shims
vivent dans le package `flash.*` (interdit par défaut sur la cible JS), le build passe
`--macro allowPackage('flash')`.

## Surface de shims (`flash.*` et `mt.*`)

| Package | Rôle |
|---|---|
| `flash.display.*` | `Sprite`→`PIXI.Container`, `Bitmap`, `BitmapData` (canvas offscreen), `Graphics`, `BlendMode`, `MovieClip`, `PixelSnapping` |
| `flash.geom.*` | `Point`, `Rectangle`, `ColorTransform`, `Matrix` (arithmétique réelle) |
| `flash.filters.*` | `GlowFilter`, `BlurFilter`, `DropShadowFilter`, `BitmapFilter` (mappés sur PixiJS, WebGL) |
| `flash.text.*` | `TextField`→`PIXI.Text`, `TextFormat`, `TextFieldAutoSize` |
| `flash.ui.Keyboard` | codes touches (LEFT/RIGHT/UP/DOWN/SPACE/ESCAPE) |
| `api.{AKApi,AKConst,AKProtocol}` | pont standalone : clavier, mode, relais score/fin vers `Boot` |
| `game.IGame` | interface `update(render)` (le loader d'origine, ici piloté par `Boot`) |
| `mt.flash.DepthManager` | z-order sur des conteneurs PIXI indexés par `Const.DP_*` |
| `mt.deepnight.{Process,Particle,Cinematic}` | boucle de process, particules, cinématiques (PixiJS) |
| `mt.deepnight.slb.{BLib,BSprite,AnimManager,SpriteInterface,SpritePivot}` | **pont SpriteLib PixiJS** - voir [SPRITELIB_BRIDGE.md](SPRITELIB_BRIDGE.md) |
| `mt.deepnight.slb.assets.{ShoeBox,TexturePacker}` | parseurs d'atlas XML au **runtime** |

Détail des pièges de collision de champs (pivot/scale/transform, BlendMode…) : [SHIM_COLLISIONS.md](SHIM_COLLISIONS.md).

## Boot & boucle

`Boot` (`@:expose("BTCBoot")`) étend `PIXI.Application` (600×460, pas fixe 30 fps). La page fait
`new BTCBoot(canvas)`. Au démarrage : `AKApi.init()` (lit `?mode=…`, écoute le clavier, lit le
cookie LvUP), chargement des textures (PIXI.Loader) + des XML d'atlas (fetch), `BLib.register(...)`,
`Level.source` = bitmap de collision (`testLevel.png`), création du `Game`, puis émission de
`btc-ready`. Le clic « Jouer » appelle `BTCBoot.me.startPlay()`.

## Modes de jeu

Le même `game.js` sert les trois modes ; `AKApi` lit `location.search` et `Game` s'aiguille :

| Mode | Déclencheur | Effet |
|---|---|---|
| **League** | défaut | survie, score pur ; fin → `POST /api/results` `game:"newBtc"`, `mode:"league"` |
| **LvUP** | `?mode=lvup` | `mode/Progression` : campagne **100 niveaux** (`com.gen.LevelGenerator`), niveau en cookie `newbtc_lvup_level`, barre de progression (coffres détruits / total) ; **aucun POST** (progression personnelle) |
| **Défi Coffres** | `?mode=defi` | `mode/Endless` : survie infinie, score = coffres détruits ; fin → `POST /api/results` `game:"newBtcDefi"`, `mode:"defi"` |

Détail du Défi : [DEFI_COFFRES.md](DEFI_COFFRES.md). Règles générales : [GAMEPLAY.md](GAMEPLAY.md).

## Events window (host ↔ moteur)

| Event | Émis quand | Détail |
|---|---|---|
| `btc-ready` | jeu construit (en pause) | `{}` |
| `btc-score` | score modifié | `{score}` |
| `btc-progress` | LvUP, coffre détruit | `{destroyed, total}` |
| `btc-finished` | fin de partie | `{win, score, mode, lvupLevel}` → `POST /api/results` (sauf LvUP) |

## Assets

Servis sous `/new-btc/assets` (dossier `btc/web`), chargés par `Boot` :
`sheet.png` + `sheet.xml` + `sheet.anims.xml` (atlas + anims), `backgrounds.png` + `backgrounds.xml`,
`testLevel.png` (carte de collision), `logo.png`. Les 3 fichiers `texts.{fr,en,es}.xml` sont
embarqués dans `game.js` à la compilation (`-resource`, dans `btc/res/`). Pas de son.

## Serveur

Dans `server.js` : `app.get("/new-btc")` (League + `?mode=lvup` + `?mode=defi`),
`app.get("/new-btc/classement")`, et `app.use("/new-btc/assets", express.static("btc/web", …))`
(no-store). Tuile dans `games.config.js` (`GROUPS`, boutons League/LvUP/Défi Coffres/Classement).
Le classement est une page à deux onglets (League `game:"newBtc"`, Défi `game:"newBtcDefi"`).

## Layout

```
btc/
  src/                 # sources Haxe (+ btc.hxml) : originaux réutilisés + shims + slb, vendorés
  res/                 # texts.{fr,en,es}.xml (embarqués via -resource)
  web/                 # game.js, vendor/pixi-legacy.min.js, sheet.*, backgrounds.*, testLevel.png, logo.png
build-btc.ps1          # compile btc/src -> btc/web/game.js
```
