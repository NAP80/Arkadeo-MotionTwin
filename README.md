# Arkadeo - Jeux HTML5 (PixiJS)

Portages HTML5 (PixiJS) de jeux Arkadeo, jouables entièrement dans le navigateur
(aucun Flash). Un petit serveur Node sert le portail et les jeux, et enregistre
les scores dans une base SQLite locale.

Jeux inclus :

- **CapMan** - labyrinthe façon Pac-Man : League, campagne LvUP, SpeedRun, éditeur de niveaux.
- **Rock Faller** - puzzle de rochers/gemmes (grille 6×6, tubes, combos) : League + campagne LvUP, avec son.
- **Brutal Teenage Crisis** - brawler « brute em all » : League, campagne LvUP (100 niveaux), Défi Coffres.

## Démarrage rapide

```bash
npm install
npm start
```

Puis ouvrez **http://localhost:3000** (portail). Aucune base externe à installer :
les scores sont stockés dans un fichier `scores.db` (SQLite) créé au premier lancement.

## Routes

| Route | Description |
|---|---|
| `/` | Portail (accueil) |
| `/new-capman` | CapMan - League |
| `/new-capman/lvup` | CapMan - campagne LvUP (20 niveaux) |
| `/new-capman/speedrun` | CapMan - SpeedRun (chronométré) |
| `/new-capman/editor` | CapMan - éditeur de niveaux |
| `/new-capman/classement` | CapMan - classement (League + SpeedRun) |
| `/new-rock-faller` | Rock Faller - League |
| `/new-rock-faller?mode=lvup` | Rock Faller - campagne LvUP (30 niveaux) |
| `/new-rock-faller/classement` | Rock Faller - classement (League) |
| `/new-btc` | Brutal Teenage Crisis - League |
| `/new-btc?mode=lvup` | Brutal Teenage Crisis - campagne LvUP (100 niveaux) |
| `/new-btc?mode=defi` | Brutal Teenage Crisis - Défi Coffres |
| `/new-btc/classement` | Brutal Teenage Crisis - classement (League + Défi) |

## Recompiler un jeu

Les jeux compilés (`*/web/game.js`) sont déjà livrés. Après modification des
sources Haxe d'un jeu, recompilez-le avec la toolchain **embarquée** (rien à installer) :

```powershell
pwsh build-capman.ps1        # -> capman/web/game.js
pwsh build-rockfaller.ps1    # -> rockfaller/web/game.js
pwsh build-btc.ps1           # -> btc/web/game.js
```

## Structure

```
server.js            serveur Express + SQLite (portail + jeux + API scores)
games.config.js      registre du portail (tuiles)
build-capman.ps1     compilation Haxe de CapMan
build-rockfaller.ps1 compilation Haxe de Rock Faller
build-btc.ps1        compilation Haxe de Brutal Teenage Crisis
capman/
  src/               sources Haxe de CapMan (+ capman.hxml)
  web/               game.js compilé, PixiJS, images
rockfaller/
  src/               sources Haxe de Rock Faller (+ rockfaller.hxml)
  web/               game.js compilé, PixiJS, images, sons
btc/
  src/               sources Haxe de Brutal Teenage Crisis (+ btc.hxml)
  res/               textes embarqués à la compilation (-resource)
  web/               game.js compilé, PixiJS, atlas
views/               templates EJS (portail + pages des jeux)
assets/              styles et scripts partagés, favicon, icônes
tools/haxe4/         toolchain Haxe 4.3.7 embarquée
docs/                documentation (docs/capman, docs/rockfaller, docs/btc)
```

Ajouter un jeu = un dossier `<jeu>/{src,web}`, un `build-<jeu>.ps1`, ses vues dans
`views/`, ses routes dans `server.js` et une tuile dans `games.config.js`.

## Documentation

**CapMan** - [ARCHITECTURE](docs/capman/ARCHITECTURE.md) · [BUILD](docs/capman/BUILD.md) ·
[GAMEPLAY](docs/capman/GAMEPLAY.md) · [LVUP](docs/capman/LVUP.md) ·
[SPEEDRUN](docs/capman/SPEEDRUN.md) · [EDITOR](docs/capman/EDITOR.md)

**Rock Faller** - [ARCHITECTURE](docs/rockfaller/ARCHITECTURE.md) · [BUILD](docs/rockfaller/BUILD.md) ·
[GAMEPLAY](docs/rockfaller/GAMEPLAY.md) · [LVUP](docs/rockfaller/LVUP.md) ·
[SOUND](docs/rockfaller/SOUND.md)

**Brutal Teenage Crisis** - [ARCHITECTURE](docs/btc/ARCHITECTURE.md) · [BUILD](docs/btc/BUILD.md) ·
[GAMEPLAY](docs/btc/GAMEPLAY.md) · [DEFI_COFFRES](docs/btc/DEFI_COFFRES.md) ·
[SPRITELIB_BRIDGE](docs/btc/SPRITELIB_BRIDGE.md) · [SHIM_COLLISIONS](docs/btc/SHIM_COLLISIONS.md)

## Licence

Jeux, graphismes, sons et code d'origine © Motion Twin (*Arkadéo*), mis à
disposition sous licence **CC BY-NC-SA 4.0**. Ce dépôt est un portage non
commercial à des fins de préservation. Voir [LICENSE.txt](LICENSE.txt).
