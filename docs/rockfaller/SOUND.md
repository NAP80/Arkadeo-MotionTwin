# New Rock Faller - Son

**Actif par défaut**. Musique en boucle + 29 SFX (mêmes sons que la version d'origine).

## Backend - `rockfaller/src/snd/Sfx.hx`

`HTML5 Audio` (`js.html.Audio`), pas de dépendance externe :
- `Sfx.play(name, ?volume)` : réutilise un **pool** d'éléments `Audio` par son
  (anneau de 4) → chevauchement limité SANS créer un `new Audio()` à chaque lecture
  (évite le churn décodeur/mémoire sur sons rapprochés).
  Source : `/new-rock-faller/assets/sounds/<name>.mp3`.
- `Sfx.startMusic("Music", 0.6)` : instance unique, `loop = true`.
- `Sfx.setMuted(b)` / `toggleMuted()` / `isMuted()` : coupe/relance la musique et
  bloque les SFX.

## Autoplay (politique navigateur)
Les navigateurs interdisent l'audio sans **geste utilisateur**. La musique est donc
démarrée dans `Boot.startPlay()` - appelé au **clic sur « Jouer »** (geste valide).
Les SFX suivent (déclenchés par les clics/le jeu).

## Mute
Le bouton **🔊 Son / 🔇 Muet** de la vue appelle `RockFallerBoot.me.toggleMute()`
(→ `Sfx.toggleMuted`) et bascule le libellé. Démarrage en mode **actif**.

## Mapping des sons

| Événement | Son(s) | Déclencheur (code) |
|---|---|---|
| Musique de fond | `Music` (boucle) | `Boot.startPlay` |
| Survol d'une sélection | `Rocks_mouseover1..6` (aléatoire) | `Game.updateSelection` |
| Rotation | `Rocks_rotate` | `Game.startRotation` |
| Destruction de blocs | `Blocks_X4L{1..3}` (1 groupe) / `Blocks_XXL{1..3}` (≥2) selon combo | `Game.startGrab` |
| Pierre qui atterrit | `Rock_fall1..9` (aléatoire, **throttlé** ~3 frames) | `Game.onStoneLanded` (via `Slot.fall`) |
| Rocher aspiré (coups) | `Blackrock_life2` / `life3` / `life4` | `Exit.proc` (`Ex_Play_*`) |
| Rocher aspiré (score) | `Blackrock_points1` / `points2` | `Exit.proc` (`Ex_Points_*`) |
| Déplacement du tube | `Pipe` | `Exit.proc` (après `switchSlot`) |

Le **throttle** du son de chute évite ~30 lectures simultanées quand une colonne
entière retombe.

## Fichiers
29 MP3 dans `rockfaller/web/sounds/` :
`Music`, `Rocks_rotate`, `Rock_fall1..9`, `Blocks_X4L1..3`, `Blocks_XXL1..3`,
`Blackrock_life2..4`, `Blackrock_points1..2`, `Pipe`, `Rocks_mouseover1..6`.

> ⚠️ Le chemin compte : le statique sert `web/` sous `/new-rock-faller/assets`, donc
> les sons doivent être dans `web/sounds/` (et non `web/assets/sounds/`).

## Vérification
Le **playback audible** se vérifie en vrai navigateur (le clic « Jouer » lève la
restriction d'autoplay).
