# New CapMan - Mode SpeedRun (20 niveaux à la suite, contre la montre)

Enchaîner les **20 niveaux dessinés** (les mêmes que [LvUP](LVUP.md)) **en une seule
session**, le plus vite possible. Le **temps** (et non le score) est classé - plus rapide
= meilleur.

- **Route jeu** : `/new-capman/speedrun` (bouton « SpeedRun » de la tuile, vert foncé `#157710`).
- **Classement** : onglet **SpeedRun** de `/new-capman/classement` - page à deux onglets
  *League / SpeedRun*. Pas de page ni de tuile dédiée ; le lien de fin de run
  pointe sur `…/classement?tab=speedrun`.
- **Vues** : `new-capman-speedrun-play.ejs` (jeu) ; `new-capman-classement.ejs` (League + SpeedRun).

## Principe

- **Tout en mémoire** (pas de cookie, contrairement à LvUP) : l'état du run (niveau, chrono)
  vit dans `Boot`. **Un refresh de page repart au niveau 1.**
- **Chrono = temps de JEU ACTIF** : il ne tourne que quand on contrôle le héros. En **pause**
  pendant le 3-2-1-Go, le défilement inter-niveaux et l'animation de mort. Basé sur les
  frames logiques (40 fps fixe) → déterministe ; affiché en `mm:ss.cs`.
- **Transitions par défilement** : à la fin d'un niveau, le niveau sort par la gauche et le
  suivant entre par la droite (`seq.Init`), **sans** perdre l'état du run.
- **Mort = on recommence le niveau courant** : animation de mort → 3-2-1-Go → on rejoue le niveau.
  Le chrono **garde le total**, **sauf au niveau 1** où il **repart à 0** (un raté sur le premier
  niveau ne coûte rien).
- **3-2-1-Go** au départ, **entre chaque niveau** (après le défilement) et après chaque mort :
  on peut **maintenir une direction** pendant
  le décompte pour partir pile à « Go » (le clavier reste suivi ; à « Go » le héros lit la
  touche tenue).
- **Niveaux dessinés purs** : monstres placés seulement, **pas** de pression (`seq.TimeUp`)
  ni de bonus aléatoire (`seq.BonusPop`) → chaque niveau est déterministe pour le speedrun.

## Boucle d'états (moteur)

| Moment | Mécanique |
|---|---|
| Lancement (clic « Démarrer ») | `startPlay()` → `seq.Init` (niveau 1) → `seq.Countdown` 3-2-1-Go → `gstep=0` + chrono démarre |
| Jeu actif | `Game.update` `gstep==0` : `Boot.srTick()` avance le chrono (si `srRunning`) |
| Fin de niveau (`onLastCoin`) | `gstep=1` + `Boot.srScheduleAdvance()` (différé `setTimeout 0`) → niveau+1 : `fxm.clean()` + `seq.Init` (défilement) + **`seq.Countdown` 3-2-1-Go** (comme après une mort, le temps de se replacer) ; chrono reprend à « Go ». `srRebuildLevel(true)`. |
| Niveau 20 réussi | `Boot.srFinish()` → `nc-finished {win:true, mode:"speedrun", durationMs}` → la page POST + écran de fin |
| Mort (`seq.Hit`) | en fin d'anim → `Boot.srScheduleRespawn()` (différé) → `fxm.clean()` + `seq.Init` (même niveau) + `seq.Countdown` ; le chrono garde le total **sauf au niveau 1 où `srFrames` repart à 0** |

## Anti-fuite mémoire (critique : 20 niveaux + animations enchaînés)

Reconstruire 20 niveaux en mémoire impose un nettoyage rigoureux à chaque transition :

1. **`Level.kill()` → `destroy({children:true})`** : libère tout le sous-arbre du niveau
   (murs/pièces/entités/plasma/FX, tous enfants du `Level`). Textures d'atlas partagées
   non détruites.
2. **`mt.pix.Element.dropUnder(level)`** (dans `Level.kill`, avant destroy) : retire de la
   liste statique `ANIMATED` les ELs animés du niveau détruit - sinon `updateAnims` les
   parcourrait après destruction → crash (`anchor`/texture null). Le nouveau niveau (déjà
   créé par `seq.Init`) n'est pas sous l'ancien → ses anims sont préservées.
3. **`fxm.clean()` avant chaque `seq.Init`** : tue les FX `mt.fx.Part` en vol (root encore
   valide) pour qu'aucun ne survive à la destruction du niveau.
4. **Avance/respawn différés** (`Boot.srSchedule*` via `setTimeout 0`) : la reconstruction
   se fait HORS de la pile `Game.update()` en cours (sinon on détruirait des objets itérés).


## Classement (temps)

Onglet **SpeedRun** de la page `/new-capman/classement` (`new-capman-classement.ejs`), une page
**à deux onglets** *League / SpeedRun* qui réutilise les classes `site.css`.
Onglet SpeedRun : query
`strict=1&game=newCapman&mode=speedrun&noDev=1`, tri **`durationMs` croissant** (plus rapide =
meilleur), colonne **Temps** (`mm:ss.cs`), chips *Runs · Meilleur temps · Temps moyen* ; seuls
les **runs terminés** (niveau 20) y figurent. `?tab=speedrun` ouvre directement cet onglet
(lien de fin de run).

## Events (moteur → page)

`nc-ready` · `nc-countdown {n}` (3/2/1) · `nc-go` · `nc-sr-level {level}` ·
`nc-finished {win:true, mode:"speedrun", durationMs, level}`. Getters `@:expose` :
`getSpeedrunMs()`, `getSpeedrunLevel()`. La page lit le chrono via une boucle
`requestAnimationFrame` (HUD `mm:ss.cs`).
