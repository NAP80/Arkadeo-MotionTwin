# New Brutal Teenage Crisis - Build & toolchain

## Prérequis

La toolchain Haxe est **embarquée** dans le dépôt (`tools/haxe4`) : rien à installer pour compiler.

- Haxe **4.3.7** (`tools/haxe4/haxe-4.3.7-win/haxe.exe`)
- Neko 2.4.0 (`tools/haxe4/neko-2.4.0-win64`)
- Repo haxelib local `tools/haxe4/haxelib_repo` : **pixijs** (+ sa dépendance `perf.js`)

Pour lancer le serveur : Node.js (18+) et `npm install` (à la racine).

## Compiler le jeu

```powershell
pwsh build-btc.ps1
```

`build-btc.ps1` pose les variables d'environnement de la toolchain, puis appelle
`haxe btc/src/btc.hxml`. Sortie : `btc/web/game.js`.

### `btc/src/btc.hxml`

```
-js btc/web/game.js
-lib pixijs
--macro allowPackage('flash')
-cp btc/src
-resource btc/res/texts.fr.xml@fr
-resource btc/res/texts.en.xml@en
-resource btc/res/texts.es.xml@es
-dce no
Boot
```

- `--macro allowPackage('flash')` : les shims Flash→PixiJS vivent dans le package `flash.*`,
  interdit par défaut sur la cible JS.
- **Un seul classpath** `btc/src` : il contient à la fois les sources d'origine réutilisées
  (logique du jeu), les shims Flash→PixiJS et le pont SpriteLib. Seules les versions effectivement
  utilisées y ont été vendorées.
- `-resource` embarque les 3 fichiers de textes (`btc/res/texts.*.xml`) dans `game.js`.

## Assets (pré-générés, committés)

Aucune régénération nécessaire pour développer. Dans `btc/web/` :

- `sheet.png` + `sheet.xml` + `sheet.anims.xml` : atlas principal + animations.
- `backgrounds.png` + `backgrounds.xml` : décors.
- `testLevel.png` : carte de collision (lue par `Boot` → `Level.source`).
- `logo.png` : écran-titre.

`Boot` charge les PNG via `PIXI.Loader` et les XML via `fetch`, puis les enregistre dans
le pont SpriteLib (`BLib.register`). Pas de son.

## Servir / tester

```powershell
npm install
npm start
```

Le serveur écoute sur `http://localhost:3000`. Routes BTC :

- `/new-btc` - League
- `/new-btc?mode=lvup` - campagne LvUP (100 niveaux, cookie `newbtc_lvup_level`)
- `/new-btc?mode=defi` - Défi Coffres (survie, score = coffres détruits)
- `/new-btc/classement` - classement (onglets League + Défi Coffres)

Les assets sont servis en `no-store` sous `/new-btc/assets` : un rebuild + un rechargement
de page suffisent.
