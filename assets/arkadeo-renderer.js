// ============================================================================
// Arkadeo - Renderer PixiJS uniforme (jeux « New X »)
// ----------------------------------------------------------------------------
// Chargé APRÈS pixi-legacy.min.js et AVANT game.js (donc avant toute création
// d'Application / de contexte WebGL). But : que TOUS les jeux rendent en WebGL
// de façon identique d'un navigateur à l'autre, au lieu que certains basculent
// sur le renderer Canvas2D.
//
// pixi-legacy teste isWebGLSupported() avec failIfMajorPerformanceCaveat=true :
// ce test ÉCHOUE sur un WebGL « logiciel »/bridé (Chrome accélération matérielle
// OFF, GPU blacklisté…) → PixiJS bascule sur Canvas2D, qui rend filtres/blends
// différemment (halos « chelou » sur Chrome alors que Firefox en WebGL est
// nickel). On désactive ce caveat pour garder le MÊME rendu WebGL partout.
// (WebGL2 est déjà l'environnement préféré de PixiJS v5 quand il est dispo ;
// sinon repli WebGL1 - jamais Canvas, sauf navigateur sans WebGL du tout.)
//
// Placé dans un fichier partagé (servi sur /assets/arkadeo-renderer.js, comme
// site.css / dev-counter.js) → un seul endroit pour tous les jeux. cf. la note
// mémoire pixijs_canvas_fallback.
// ============================================================================
(function () {
  if (typeof PIXI === "undefined" || !PIXI.settings) return;
  try { PIXI.settings.FAIL_IF_MAJOR_PERFORMANCE_CAVEAT = false; } catch (e) {}
})();
