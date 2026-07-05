# New Brutal Teenage Crisis - Collisions de champs Flash ↔ PixiJS

## Prérequis : `--macro allowPackage('flash')`

Haxe réserve le package `flash` sur la cible JS (« You cannot access the flash package while
targeting js »). Sans `--macro allowPackage('flash')` dans le `.hxml`, aucun shim `flash.*`
(ni source d'origine qui importe `flash.*`) ne compile.

## Collisions de champs hérités de PixiJS

Faire `flash.display.Sprite extends pixi.core.display.Container` couvre la majorité de l'API
(x/y/alpha/visible/rotation/addChild/parent…), mais quelques noms de champs entrent en collision
avec PixiJS et ne peuvent pas être redéclarés dans une sous-classe :

| Membre Flash | Conflit PixiJS | Résolution |
|---|---|---|
| `scale(v)` (méthode de `slb.SpriteInterface`) | `Container.scale : Point` (champ) | `SpriteInterface` ne déclare pas `scale()`/`setScale()` (BTC n'utilise que `scaleX`/`scaleY`). |
| `pivot` (`BSprite`/`SpriteInterface`) | `DisplayObject.pivot : Point` | champ renommé **`slbPivot`**. |
| `transform.matrix` / `transform.colorTransform` (Level, Fx) | `DisplayObject.transform : Transform` (sans `.matrix`) | `Level`/`Fx` sont des implémentations PixiJS dédiées, sans passer par ce champ. |
| `filters = [GlowFilter…]` | `DisplayObject.filters : Array<Filter>` | OK : les `flash.filters.*` étendent `pixi.Filter` → le littéral type correctement. |
| `blendMode` (String) | `Sprite.blendMode : Int` | `flash.display.Sprite` (= Container) porte `blendMode:String` ; ne pas le poser sur un `Bitmap` (= pixi Sprite). |
| `buttonMode` | déjà sur `pixi.interaction.InteractiveTarget` | ne pas le redéclarer sur `flash.display.Sprite`. |

Autres points : `toString()` n'override rien (Container n'en a pas de virtuel) ; `haxe.xml.Fast`
est déprécié → `haxe.xml.Access` (même API).

## Fichiers de rendu réécrits (vs logique réutilisée)

La logique pure est reprise telle quelle : `Game`, `Mode`, `Entity`, `Hero`, `Mob` + `en/mob/*`,
`en/it/*`, `Level` (collision), `Const`, `com/gen/LevelGenerator`, et `AnimManager`, `Color`, `Rand`,
`RandList`, `Delayer`, `Tweenie`, `mt.deepnight.Lib`. Sont réécrits en PixiJS :

- `flash.*` (display/geom/filters/text/ui), `mt.deepnight.{Process,Particle}`, le pont SpriteLib
  (`slb.{BLib,BSprite,SpriteInterface}` + `slb.assets.{ShoeBox,TexturePacker}` au runtime).
- `Fx` (particules + filtres PixiJS), `Level` (collision via `testLevel.png`, rendu plateformes),
  `Hud` (cœurs + score).
- `Lang` : chaînes intégrées (la macro de textes d'origine ne tourne pas en Haxe 4).

Notes de compat : `mt.Cooldown` accepte un `fps` optionnel ; `BSprite` ajoute `setCenter()`
(= `setCenterRatio`) ; les `@:bitmap(...)` (embed Flash compile-time) sont évités.
