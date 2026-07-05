# New Brutal Teenage Crisis - Le pont SpriteLib (`mt.deepnight.slb.*`)

C'est le **morceau le plus risqué** du portage : dans BTC, **chaque entité, FX, tuile et
élément de HUD** est un `BSprite`. Tout le rendu passe par là. Classes concernées :
`mt.deepnight.slb.{BSprite,BLib,AnimManager,SpriteInterface,SpritePivot}`.

## Comment ça marche en Flash (original)

- **`BLib`** (la « librairie ») détient l'atlas (`source : flash.display.BitmapData`) et une
  table de **groupes** : `Map<String, LibGroup>` où
  ```
  LibGroup = { id, maxWid, maxHei, frames:Array<FrameData>, anim:Array<Int> }
  FrameData = { x,y,wid,hei, realFrame:{x,y,realWid,realHei}, rect:Rectangle, ?pX,?pY }
  ```
  - `slice/sliceCustom/sliceGrid/sliceAnim*` remplissent les groupes ; `__defineAnim` /
    `parseAnimDefinition("0-5,6(2),7(1)")` posent la timeline `anim` (liste d'index de frame).
  - **`initBdGroups()`** pré-rend **chaque frame de chaque groupe** dans sa propre
    `BitmapData` (`copyPixels` depuis `source`) → `bdGroups : Map<String, Array<BitmapData>>`.
  - `getCachedBitmapData(group, frame)` renvoie cette `BitmapData` pré-rendue.
- **`BSprite extends flash.display.Sprite`** détient un `flash.display.Bitmap bmp` (enfant).
  - `set(lib, group, frame)` sélectionne le groupe ; `setFrame(f)` fait
    `bmp.bitmapData = lib.getCachedBitmapData(groupName, f)` puis `applyPivot()`.
  - **`applyPivot()`** positionne le bitmap : `bmp.x = -pivot - frameData.realFrame.x` (gère
    le *trim* TexturePacker : `realFrame` = boîte réelle dans la frame rognée).
  - **`a : AnimManager`** joue la timeline et appelle `setFrame()` quand l'index change.
- **Boucle** : `BLib.updateChildren()` itère les `BSprite` vivants → `bs.a.update()` +
  `bs.beforeRender()`. (Dans BTC c'est `BSprite.updateAll()` / la boucle de `Mode` qui pilote.)
- **Attach points** : `BLib.parseAttachPoints(colors, "Dots")` scanne **une fois** les groupes
  `"<anim>Dots"` pour repérer des pixels-marqueurs colorés et stocke un delta `(dx,dy)` par
  `(anim, frame, couleur)`. `getAttachPoint(spr, col)` le relit en O(1). C'est le mécanisme
  propre du moteur pour accrocher couette/boule-chaîne - **à privilégier** sur un
  `getColorBoundsRect` par frame.

## Stratégie : réutilisation + réécriture PixiJS

- **Réutilisés tels quels** : `AnimManager` (logique d'anim pure : curseurs, pile d'anims,
  state anims ; ne touche que `spr.set/setFrame/frame/lib/dispose` de `SpriteInterface` +
  `mt.MLib`) et `SpritePivot` (données de pivot).
- **Réécrits sur PixiJS** : `BLib` et `BSprite`, en **gardant l'API publique exacte** que le
  jeu appelle, mais en remplaçant le blit `BitmapData` par des **textures PixiJS**.

### `BLib` (shadow PixiJS)
- Détient `baseTex : PIXI.BaseTexture` (l'atlas) au lieu de `source:BitmapData`.
- Garde la **même table `groups`/`FrameData`** (même parsing → mêmes rects, mêmes pivots).
- Remplace `initBdGroups`/`getCachedBitmapData(group, frame)` par un **cache de
  `PIXI.Texture`** : `getFrameTexture(group, frame)` = `new PIXI.Texture(baseTex, rect)`
  (mémoïsé). Plus de pré-rendu coûteux par frame.
- Conserve : `slice/sliceCustom/sliceGrid/sliceAnim*`, `createGroup/getGroup/getGroups`,
  `getFrameData/getRectangle/exists/countFrames/getRandomFrame`, `getAnim/getAnimDuration`,
  `__defineAnim/parseAnimDefinition`, `setDefaultCenter/setSliceGrid`, `get/getAndPlay/getRandom`,
  `addChild/removeChild/countChildren/updateChildren`, `parseAttachPoints/getAttachPoint`,
  `destroy`.
- **Retiré** : tout `#if h3d` (heaps), les méthodes `drawIntoBitmap*`/`getBitmapData*`/
  `getMovieClip`/`applyPermanentFilter` (compositing BitmapData) - réimplémentées **seulement
  là où le jeu en a besoin** via un render-to-texture PixiJS (ex. `Level.render`).

### `BSprite` (shadow PixiJS)
- `extends` notre shim `flash.display.Sprite` (= wrapper `PIXI.Container`), `implements SpriteInterface`.
- En interne : un **`PIXI.Sprite` enfant** (à la place du `flash.display.Bitmap`).
- `setFrame(f)` : `child.texture = lib.getFrameTexture(groupName, f)` puis position via
  `applyPivot()` (même formule : `child.x = -pivot - realFrame.x`, `child.y = -pivot - realFrame.y`).
- Garde : `set/setRandom/setRandomFrame`, `setCenter*/setPivotCoord/applyPivot`,
  `setPos/setSize/setScale/scale/constraintSize`, `getAnimDuration/totalFrames`,
  `isGroup/is/isReady`, `getBitmapDataReadOnly` (cf. ci-dessous), `clone`, `dispose`,
  `a:AnimManager`, `lib/groupName/group/frame/frameData`, `beforeRender/onFrameChange`,
  `static updateAll()`.
- **`getBitmapDataReadOnly()` / attach points** : le jeu lit parfois les pixels de la frame
  courante (Hero : couette `0x00bdff`, chaîne `0x18fff7`). On **ne** rescanne **pas** par
  frame : on pré-calcule au chargement (via `BLib.parseAttachPoints` réécrit pour scanner le
  **canvas de l'atlas**) une table `(group,frame,couleur) → (dx,dy)`, et on fait pointer le
  besoin du Hero dessus.

## `ShoeBox` / `TexturePacker` → `importXml` **runtime**

Les originaux (`mt.deepnight.slb.assets.{ShoeBox,TexturePacker}`) sont des
**macros compile-time** (`sys.io.File` + `@:bitmap`) ; `ShoeBox` lève même `#error` (déprécié).
Inutilisables sur la cible JS.

On les **remplace par des fonctions runtime de même nom/signature** :
`ShoeBox.importXml("assets/sheet.xml") : BLib`, `TexturePacker.importXml("assets/backgrounds.xml") : BLib`.
- `Boot` **pré-charge** au démarrage : les `PIXI.BaseTexture` (`sheet.png`/`backgrounds.png`)
  + le **texte XML** (`sheet.xml`/`sheet.anims.xml`/`backgrounds.xml`), et les range dans un
  **registre statique** clé = la chaîne d'URL passée par le jeu.
- `importXml(url)` retrouve l'atlas+XML dans le registre et **parse synchroniquement** :
  - frames `SubTexture` (avec trim `frameX/frameY/frameWidth/frameHeight` → `realFrame`),
  - pour ShoeBox : appliquer en plus les définitions d'anim de `sheet.anims.xml` via
    `BLib.parseAnimDefinition` (réutilisé verbatim - parsing de chaînes pur).
- Le jeu appelle `importXml` de façon **synchrone** dans `Mode` → d'où le pré-chargement
  dans `Boot` avant `new Game()`.
