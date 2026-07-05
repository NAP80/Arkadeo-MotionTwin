// ============================================================================
// Arkadeo - Compteur d'usage des fonctions Dev/Triche (INTERNE)
// ----------------------------------------------------------------------------
// Chargé sur les pages de jeu New (PixiJS). Incrémente window.__ARK_DEV à chaque
// utilisation d'un contrôle "Dev/Triche" :
//   - clic sur un bouton dans un bloc dev  (.nc-dev / .rf-dev …)
//   - bascule d'une case à cocher dev      (id contenant god/dev/cheat/triche,
//                                            ou case située dans un bloc *-dev)
//
// La page lit window.__ARK_DEV au moment d'envoyer le score (champ `devUses`
// du POST /api/results). But : repérer en base les parties "assistées" SANS
// afficher ce compteur sur le classement (purement interne).
//
// Détection par CONVENTION (aucun marquage à ajouter sur les contrôles) :
//   - un conteneur/bouton dev a une classe contenant "-dev" (ex. nc-dev__btn) ;
//   - une case "triche" a un id contenant god/dev/cheat/triche.
// Écoute en phase de capture → fonctionne quel que soit l'ordre de chargement.
//
// Remarque : pour une case à cocher, on compte chaque BASCULE. Une case laissée
// dans son état par défaut (sans interaction) n'est donc pas comptée.
// ============================================================================
(function () {
  window.__ARK_DEV = window.__ARK_DEV || 0;

  function isDevControl(el) {
    if (!el || !el.closest) return false;
    // Bouton/contrôle situé dans un bloc dev (classe contenant "-dev").
    if (el.closest('[class*="-dev"]')) return true;
    // Identifiant évoquant une fonction de triche.
    var id = el.id || "";
    return /(?:^|[-_])(?:dev|god|cheat|triche)/i.test(id);
  }

  // Clics sur boutons dev.
  document.addEventListener(
    "click",
    function (e) {
      var btn = e.target && e.target.closest ? e.target.closest("button") : null;
      if (btn && isDevControl(btn)) window.__ARK_DEV++;
    },
    true
  );

  // Bascules de cases à cocher dev.
  document.addEventListener(
    "change",
    function (e) {
      var t = e.target;
      if (t && t.type === "checkbox" && isDevControl(t)) window.__ARK_DEV++;
    },
    true
  );
})();
