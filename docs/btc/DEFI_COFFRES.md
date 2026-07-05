# New Brutal Teenage Crisis - Mode « Défi Coffres » (survie infinie)

> ## En bref
> 3e mode de jeu **parallèle** (en plus de League et de la campagne LvUP, tous deux
> **inchangés**). Survie infinie : on détruit des coffres à l'enchaînement pendant que
> les ennemis montent à la chaîne ; quand on se fait déborder, **le score = le nombre
> de coffres détruits**, classé dans un **classement séparé**.
>
> - **URL** : `/new-btc?mode=defi`
> - **Tuile portail** : « Défi Coffres » (**jaune**), juste au-dessus de « Classement ».
> - **Classement** : `/new-btc/classement`, onglet « Défi Coffres » (game `newBtcDefi`).

---

## 1. Règles du jeu

| Aspect | Défi Coffres | (rappel League) |
|---|---|---|
| Map | **Fixe** (générée **procéduralement**, déterministe), à **sol plein** (zéro vide → pas de chute) | Fixe (`testLevel.png`) |
| Difficulté | **Identique à League** (montée auto de `diff`, mêmes ennemis) | montée auto de `diff` |
| Défaite | Ennemis qui grimpent jusqu'en haut → perte de crédit → game over (3 crédits) | idem |
| Objectif | **Détruire des coffres à l'infini** | Score (pièces d'or) |
| Coffres | **2 affichés en permanence** ; un nouveau réapparaît à chaque destruction ; **pas de porte de fin** | - (coffres = LvUP only) |
| Difficulté des coffres | **Silver** (simple) au début → **Movable** (≥ 5 détruits) → **Golden** (≥ 12) | - |
| Score | **Nombre de coffres détruits** (pas de score d'or : le drop d'or est inhibé) | Or ramassé |
| Persistance | Aucune (chaque partie indépendante ; pas de cookie de progression) | - |

La menace repose sur le **même principe que League** : un ennemi (`en.mob.Walker`) qui
grimpe une échelle jusqu'au sommet (`onReachTop` → `mode.hero.loseCredit()`) coûte un
crédit. **La map DOIT donc comporter des échelles atteignant le haut** (voir § 3.2).

---

## 2. Accès & navigation

- **Lancement** : `api.AKApi` lit `?mode=defi` → expose le flag statique `api.AKApi.defi`.
- **Tuile portail** : dans `games.config.js`, la tuile BTC a un bouton
  `{ href:"/new-btc?mode=defi", btn:"Défi Coffres", btnClass:"defi" }`. La classe
  `game-btn--defi` (jaune `#ffd21f`) est définie dans `site.css`.
  > ⚠️ `games.config.js` est chargé au démarrage → **redémarrer le serveur** après édition.
- **Classement** : page dédiée `new-btc-classement.ejs` à **2 onglets** (League / Défi Coffres).

---

## 3. Architecture

Le mode réutilise **toute** la mécanique de League par héritage et n'ajoute que le
strict nécessaire. Modèle = réutilisation via `-cp` + shadows (cf. `SHIM_COLLISIONS.md`).

### 3.1 Aiguillage du mode

`mode.Endless` **hérite de `mode.League`** → `getGameMode()` renvoie `GM_LEAGUE`
(inutile d'étendre l'enum `GameMode`). On aiguille sur le **flag** dans un **shadow de
`Game.hx`** :

```haxe
case GameMode.GM_LEAGUE :
    if( api.AKApi.defi ) new mode.Endless(this);
    else                 new mode.League(this);
```

### 3.2 La map fixe - **générée procéduralement** (`Level.generateEndless`)

La map n'est **pas dessinée à la main** : elle est produite par le **vrai générateur
procédural** `com.gen.LevelGenerator` (celui de la campagne LvUP), **pinné sur un niveau
constant** `ENDLESS_LVL`. Le générateur seede sa graine de façon déterministe
(`seed = 18660 + lid*1000`) → `generateProgressionLevel(ENDLESS_LVL)` rend **toujours la
même map** procédurale → « en dur, aléatoirement ». **Changer `ENDLESS_LVL` = une autre
map aléatoire.** On ne réutilise du générateur que **plateformes + échelles** (ses
`targets`/`exit`/`addMobs` sont ignorés - on pose nos propres coffres/ennemis).

Ajouts par-dessus le tirage :

- **Plancher continu** : toute la rangée `cy = LHEI-1` est forcée solide → pas de vide →
  pas de chute mortelle (la logique de chute de `Progression` n'est pas utilisée ici).
- **Échelles d'1 étage (le sol peut en faire 2)** : chaque échelle relie sa plateforme à
  la **plateforme du dessus** (1re collision, ou le sommet) → elle finit **toujours** sur
  une plateforme/au sommet → **jamais de bout flottant** (c'était le bug des « chaînes
  cassées » : tronquer une échelle en plein vide laissait un moignon). Le générateur
  espace ses plateformes d'1 étage (`floorHei = 3`), donc les échelles font naturellement
  1 étage. Quand le tirage place une échelle qui **sauterait ≥ 2 étages** (gap de colonne
  sans plateforme intermédiaire) **hors du sol**, on **ne la dessine PAS** (on la saute,
  pas de troncature → pas de moignon) ; **exception** : si elle atteint le sommet
  (`dest == 0`), c'est la **route d'évasion** → on la garde. Les échelles partant du **sol
  (floor 0)** gardent leurs 2 étages. L'accès aux plateformes sautées reste assuré par les
  autres échelles + le saut du héros.
- **`ensureEscapeRoute()`** : garantit qu'une échelle atteint le sommet (`cy = 0`). Si
  aucune n'y arrive, on **PROLONGE l'échelle qui monte déjà le plus haut** jusqu'à `cy=0`
  (pont minimal - surtout pas un puits pleine hauteur). C'est la **seule** chaîne tolérée
  au-delà d'1 étage, car l'évasion l'exige (et elle reste ≤ 2 étages en pratique).
  > ⚠️ **Indispensable** : sans route vers le haut, les ennemis ne s'échappent jamais →
  > on ne perd jamais → partie infinie pour de vrai.
- `rebuildSpots()` reconstruit les spots de sol (toute cellule vide au-dessus d'une
  collision). `getRandomSpot(floor)` **retombe sur le sol** si l'étage demandé est vide
  (map procédurale clairsemée) → pas de crash sur `League.addMob` (étages 0/1).

### 3.3 Le mode (`mode.Endless extends League`)

| Surcharge | Rôle |
|---|---|
| `isLeague() → false` | **Inhibe le drop d'or** : `en.Mob.dropGold` est gardé `if(!isLeague()) return` → aucune pièce ne tombe → pas de score parasite. |
| `newLevel()` | Reprend le minimum de `Mode.newLevel` (nextPowerUp), puis `level.generateEndless()` + `level.render()` + `new en.Hero()` + **2 coffres** (`spawnChest` ×2). **Pas** de `addKPoints` (pas de jetons). |
| `onChestDestroyed()` | Appelé par le shadow de `Lock` à chaque coffre détruit : `chestsDestroyed++`, `Boot.addScore(chestsDestroyed)`, puis `spawnChest()` (on en remet 1 → toujours 2). |
| `spawnChest()` | Pose un coffre **actif** sur un spot éloigné du héros, type tiré selon `chestsDestroyed` (Silver / Movable ≥ 5 / Golden ≥ 12). |

`addMob` / `getMaxMobs` / la montée de `diff` (`Mode.update`) sont **hérités de League
tels quels** → courbe de difficulté identique.

### 3.4 Les coffres (shadow `en/mob/Lock.hx`)

`Lock.onDie()` d'origine ouvre la porte de Progression quand il ne reste plus de coffre
(`mode.asProgression().unlockExit()`) → crasherait en Défi. Le shadow rend `onDie`
**conscient du mode** :

```haxe
override function onDie() {
    super.onDie();
    fx.explosion(xx,yy, 2);
    if( !mode.isProgression() ) {     // Défi : pas de porte, le mode gère
        untyped mode.onChestDestroyed();
        return;
    }
    // … Progression : comportement d'origine INTACT (ordre d'activation + porte) …
}
```

Sous-types réutilisés : `en.mob.lock.Silver` (12 PV), `Movable` (25 PV, recul +
explosion à l'atterrissage), `Golden` (40 PV).

### 3.5 Score & classement

- Le **canal de score est réutilisé** : `Boot.addScore(chestsDestroyed)` met à jour le
  HUD (`btc-score`) ; comme l'or est inhibé (§ 3.3), **aucun conflit**.
- `Boot.gameOver` émet `btc-finished { mode:"defi", score:<coffres détruits>, … }`.
- `new-btc-play.ejs` est **défi-aware** : HUD « **Coffres détruits : N** », écran de jeu
  « DÉFI COFFRES », game over « Coffres détruits : N », et **POST vers le classement
  séparé** `game:"newBtcDefi", mode:"defi"` (la campagne LvUP, elle, ne poste jamais).
- `new-btc-classement.ejs` : page à 2 onglets. League → `game=newBtc&mode=league`
  (colonne « Score ») ; Défi → `game=newBtcDefi&mode=defi` (colonne « Coffres »).
  `/api/results` & `/api/stats` sont **génériques** (filtre `game`/`mode`) → aucun
  changement serveur. Onglet Défi actif = jaune.

### 3.6 Fichiers touchés

| Fichier | Rôle |
|---|---|
| `btc/src/mode/Endless.hx` | le mode |
| `btc/src/Game.hx` | aiguillage défi |
| `btc/src/en/mob/Lock.hx` | `onDie` selon mode |
| `btc/src/Level.hx` | `generateEndless` + `rebuildSpots` + fix `getSeed` |
| `btc/src/api/AKApi.hx` | flag `defi` |
| `btc/src/Boot.hx` | `gameOver` mode `"defi"` |
| `views/new-btc-play.ejs` | HUD/écrans/POST défi-aware |
| `views/new-btc-classement.ejs` | page 2 onglets |
| `games.config.js` | tuile « Défi Coffres » |
| `assets/site.css` | `.game-btn--defi` (jaune) |

Build : `pwsh build-btc.ps1` → `btc/web/game.js`.

---

## 4. Réglages (tuning)

| Quoi | Où | Défaut |
|---|---|---|
| Nombre de coffres simultanés | `Endless.ACTIVE` | `2` |
| Seuils de difficulté des coffres | `Endless.spawnChest` (`chestsDestroyed >= 5 / 12`) | Silver/Movable/Golden |
| Map (un autre layout procédural) | `Level.ENDLESS_LVL` (niveau-modèle du générateur) | `42` |
| Courbe de difficulté / spawn d'ennemis | hérité de `mode.League` (`getMaxMobs`, `addMob`, `Const.AUTODIFF`) | = League |
| Bonus de saut « fraise » (sur saut MAINTENU only) | `Boot.SUPER_JUMP_BOOST` (commun à tous les modes) | `0.07` |
| Vitesse de chute MAX (anti-plongeon charge Fly) | `Boot.HERO_MAX_FALL` (commun à tous les modes) | `0.45` |
| Plafond du héros (marge de saut au-dessus du sommet) | `Boot.CEILING_CY` (commun à tous les modes ; plus négatif = plus haut) | `-6` |

---

## 5. Pièges & décisions

- **`isLeague()=false` pour couper l'or** : élégant (le garde existe déjà dans
  `Mob.dropGold`), mais **impose** que `Level.getSeed()` teste `isProgression()` (et
  **pas** `isLeague()`) - sinon il appelle `asProgression()` sur un mode Défi → crash.
- **Échelles d'évasion obligatoires** (§ 3.2) : c'est la seule source de défaite.
- **Shadow `Lock` minimal** : le chemin Progression est laissé **identique** à
  l'original (copie verbatim) ; on n'ajoute qu'une branche `!isProgression`.
- **Réutilisation du canal de score** : possible **uniquement** parce que l'or est
  inhibé. Si un jour l'or revenait en Défi, il faudrait un compteur séparé.
- **Classement séparé** = nouvel `id` de jeu `newBtcDefi` (pas un nouveau « mode » au
  sens base) → le tri/affichage réutilisent l'API existante sans modification.
- **Redémarrage serveur** requis après toute modif de `games.config.js`.

---

## 6. État & vérification

**Vérifié (headless, preview)** : boot 0 erreur en `?mode=defi` ; **2 coffres** présents ;
ennemis qui spawnent (courbe de difficulté active) ; **boucle de destruction 1→6 coffres**
(toujours 2 à l'écran, score qui suit) ; game over → POST `newBtcDefi` (503 si Mongo
absent = normal, payload défi correct) ; tuile **jaune** `rgb(255,210,31)` au-dessus de
« Classement » ; page classement à **2 onglets** qui basculent (titre / colonne /
libellés). Build `game.js` ≈ 416 Ko.

**Map procédurale vérifiée** (`ENDLESS_LVL=42`) : **0 bout flottant** (`stubs=0` → plus de
chaînes cassées), **segment d'échelle dessiné max = 6 cellules (2 étages)** → aucune
chaîne ne dépasse 2 étages (les échelles inter-plateformes hors-sol qui sauteraient ≥2
étages sont SAUTÉES), **évasion naturelle** (`escapeForced=false`, pas de pont forcé),
spots de spawn OK (sol + étage 1), 2 coffres + ennemis qui spawnent, 0 erreur. (Le niveau
`17` donne le moins d'échelles sautées si on veut maximiser la connectivité.)

**Réglages ajustables** (constantes) :
- Le **rythme d'évasion** des ennemis.
- Les **seuils de difficulté** des coffres.
- Le **layout** : changer `ENDLESS_LVL` donne une autre map aléatoire (déterministe).

Le classement Défi est enregistré dans la base **SQLite** locale (`scores.db`), comme les
autres classements.
