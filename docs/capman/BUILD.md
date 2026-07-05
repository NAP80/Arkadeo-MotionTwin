# New CapMan - Build & toolchain

## Prérequis

La toolchain Haxe est **embarquée** dans le dépôt (`tools/haxe4`) : aucune
installation n'est nécessaire pour compiler.

- Haxe **4.3.7** (`tools/haxe4/haxe-4.3.7-win/haxe.exe`)
- Neko 2.4.0 (`tools/haxe4/neko-2.4.0-win64`)
- Repo haxelib local `tools/haxe4/haxelib_repo` : **pixijs** (+ sa dépendance `perf.js`)

Pour lancer le serveur : Node.js (18+) et `npm install`.

## Compiler le jeu

```powershell
pwsh build.ps1
```

`build.ps1` pose les variables d'environnement de la toolchain embarquée
(`NEKOPATH`, `HAXELIB_PATH`), puis appelle `haxe src/capman.hxml`.
Sortie : `web/game.js`.

### `src/capman.hxml`

```
-js web/game.js
-lib pixijs
-cp src
-debug
-dce no
Boot
```

Tout le code (sources du jeu + shims PixiJS + quelques utilitaires `mt.*`
réutilisés) vit sous `src/` : un seul classpath suffit.

## Assets (pré-générés, committés)

Les assets graphiques sont déjà générés à partir du jeu d'origine et livrés dans
le dépôt ; **aucune régénération n'est nécessaire** pour développer :

- `web/img/content/capman/capman-0.png` : planche maîtresse unique. `Cs.initGfx()`
  la découpe **au runtime** par coordonnées pixel (`mt.pix.Store.slice`) - tuiles,
  pièces, héros, monstres, portes… - aux mêmes coordonnées que l'original.
- `web/img/content/capman/fx/*.png` : 18 frames de FX (`disco-0..3`, `partbad-0..11`,
  `rad-0`, `lighttriangle-0`), chargées par `Boot` dans `PIXI.Loader.shared`.
- `src/CsLevels.hx` : les 20 niveaux dessinés du mode LvUP (chaîne `haxe.Serializer`),
  relue par `haxe.Unserializer` côté jeu et éditeur.

## Servir / tester

```powershell
npm install
npm start
```

Le serveur écoute sur `http://localhost:3000`. Routes (toutes servent le même
`game.js`, le mode est choisi par la vue) :

- `/` - portail
- `/new-capman` - League
- `/new-capman/speedrun` - SpeedRun (chrono)
- `/new-capman/lvup` - campagne LvUP
- `/new-capman/classement` - classement (League + SpeedRun)
- `/new-capman/editor` - éditeur de niveaux

Les assets sont servis en `no-store` sous `/new-capman/assets` : un rebuild + un
rechargement de page suffisent (pas de cache à vider). Une modification de
`server.js` (routes) impose en revanche de **redémarrer le serveur**.

### Vérification headless

`Boot` expose `devTick(n)` pour avancer `n` pas de logique sans
`requestAnimationFrame` (utile quand l'onglet est masqué et que le rAF de PixiJS
est en pause). Exemple (console navigateur) :

```js
CapManBoot.me.started = true;
// simuler une flèche droite maintenue :
var e = new KeyboardEvent('keydown', {}); Object.defineProperty(e, 'keyCode', { get: () => 39 });
window.dispatchEvent(e);
CapManBoot.me.devTick(50);
CapManBoot.me.score; // doit augmenter si des pièces ont été mangées
```
