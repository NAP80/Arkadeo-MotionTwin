// ============================================================================
// Arkadeo - Arrêt complet du moteur à la fin de partie (jeux « New X » PixiJS)
// ----------------------------------------------------------------------------
// Chargé sur les pages de jeu New (PixiJS). À la fin de partie (CustomEvent
// <prefix>-finished émis par le Boot, ex. "nc-finished", "rf-finished"), on
// STOPPE le ticker de l'Application PixiJS. Comme la boucle de jeu ET le rendu
// sont tous deux branchés sur `app.ticker` (this.ticker.add(tick) + le render
// injecté par pixi.Application), l'arrêter fige tout : plus une seule frame
// n'est rendue, le CPU/GPU retombe à zéro. Sans ça, après la partie le rAF
// continue de tourner indéfiniment derrière l'écran de fin.
//
// ⚠ Pulsar et Rock Faller pilotent leur LOGIQUE (kado.FixedFramerate) sur
// PIXI.Ticker.system, PAS sur app.ticker (qui n'y fait que le rendu interpolé).
// On stoppe donc AUSSI Ticker.system, sinon la physique continuerait de tourner
// après la fin de partie. Inoffensif pour les 14 autres jeux (logique+rendu sur
// app.ticker ; Ticker.system n'y sert qu'à l'InteractionManager, inutile une fois
// l'overlay de fin affiché).
//
// L'ÉCRAN de fin (overlay DOM + bouton « Rejouer ») reste géré par chaque page :
// ici on ne touche QUE le moteur. Les deux sont indépendants (l'overlay est du
// DOM par-dessus le canvas figé).
//
// Usage (dans le script inline de la page, après game.js) :
//     ArkadeoEndgame.arm({ event: "az-finished", boot: "AnimozBoot" });
//
// Tous les Boot Arkadeo PixiJS étendent pixi.core.Application et exposent
// XxxBoot.me → on coupe XxxBoot.me.ticker. halt/resume sont idempotents ;
// resume() sert aux jeux qui peuvent reprendre après la fin (Rock Faller +1 coup).
// ============================================================================
(function () {
  "use strict";

  function appOf(bootName) {
    try {
      var B = bootName ? window[bootName] : null;
      return B && B.me ? B.me : null;
    } catch (e) {
      return null;
    }
  }

  function systemTicker() {
    try {
      if (window.PIXI && PIXI.Ticker && PIXI.Ticker.system) return PIXI.Ticker.system;
    } catch (e) {}
    return null;
  }

  function halt(bootName) {
    var app = appOf(bootName);
    try {
      if (app && app.ticker && app.ticker.stop) app.ticker.stop();
    } catch (e) {
      /* moteur absent / déjà arrêté : on ignore */
    }
    // Logique sur Ticker.system (Pulsar / Rock Faller) → la figer aussi.
    var sys = systemTicker();
    try { if (sys && sys.stop) sys.stop(); } catch (e) {}
    window.__ARK_HALTED = true;
  }

  function resume(bootName) {
    var app = appOf(bootName);
    try {
      if (app && app.ticker && app.ticker.start) app.ticker.start();
    } catch (e) {}
    var sys = systemTicker();
    try { if (sys && sys.start) sys.start(); } catch (e) {}
    window.__ARK_HALTED = false;
  }

  var ArkadeoEndgame = {
    halt: halt,
    resume: resume,
    // arm({ event, boot }) : à chaque occurrence de l'événement de fin, fige le
    // moteur. Le setTimeout(0) laisse les autres handlers de la page (POST score,
    // affichage de l'overlay) s'exécuter sur la même frame AVANT la coupure.
    arm: function (opts) {
      opts = opts || {};
      var event = opts.event;
      var bootName = opts.boot;
      if (!event) return;
      window.addEventListener(event, function () {
        setTimeout(function () { halt(bootName); }, 0);
      });
    }
  };

  window.ArkadeoEndgame = ArkadeoEndgame;
})();
