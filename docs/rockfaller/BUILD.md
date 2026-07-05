# New Rock Faller - Build & toolchain

## Prérequis

La toolchain Haxe est **embarquée** dans le dépôt (`tools/haxe4`) : aucune
installation n'est nécessaire pour compiler.

- Haxe **4.3.7** (`tools/haxe4/haxe-4.3.7-win/haxe.exe`)
- Neko 2.4.0 (`tools/haxe4/neko-2.4.0-win64`)
- Repo haxelib local `tools/haxe4/haxelib_repo` : **pixijs** (+ sa dépendance `perf.js`)

Pour lancer le serveur : Node.js (18+) et `npm install` (à la racine).

## Compiler le jeu

```powershell
pwsh build-rockfaller.ps1
```

`build-rockfaller.ps1` pose les variables d'environnement de la toolchain, puis
appelle `haxe rockfaller/src/rockfaller.hxml`. Sortie : `rockfaller/web/game.js`.

### `rockfaller/src/rockfaller.hxml`

```
-js rockfaller/web/game.js
-lib pixijs
-cp rockfaller/src
-debug
-dce no
Boot
```

Tout le code vit sous `rockfaller/src` : les sources du jeu **et** les utilitaires
d'origine réutilisés (`common_haxe_avm1.display.ASprite`, `MouseManager`, `kado.*`,
`mt.*`), vendorés là. Un seul classpath.

## Assets (pré-générés, committés)

Aucune régénération nécessaire pour développer :

- `rockfaller/web/img/content/rockfaller/` : atlas `rockfaller-0.png` + `-0.json`,
  fond `bg.png`, avant-plan `fg.png`. `ASprite` lit la spritesheet via le loader partagé.
- `rockfaller/web/sounds/*.mp3` : musique en boucle + 29 SFX (cf. [SOUND](SOUND.md)).

## Servir / tester

```powershell
npm install
npm start
```

Le serveur écoute sur `http://localhost:3000`. Routes Rock Faller :

- `/new-rock-faller` - League
- `/new-rock-faller?mode=lvup` - campagne LvUP (30 niveaux, cookie `rockFaller_lvup_level`)
- `/new-rock-faller/classement` - classement (League)

Les assets sont servis en `no-store` sous `/new-rock-faller/assets`.

### Vérification headless

`Boot` expose `devTick(n)` pour avancer `n` pas de logique sans
`requestAnimationFrame`. Comme le rendu est interpolé dans le ticker (en pause hors
onglet actif), appeler `RockFallerBoot.me.gameRoot.updateGraphics(1)` avant une
capture pour forcer la mise à jour des positions pixi.
