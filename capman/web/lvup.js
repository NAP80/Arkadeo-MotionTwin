// New CapMan - client LvUP (campagne).
// Gère le cookie de niveau, la barre de progression, le passage/réessai de niveau et l'enregistrement du résultat.
// Servi sous /new-capman/assets/lvup.js, chargé par new-capman-lvup-play.ejs
// APRÈS game.js. Le moteur (CapManBoot) lit le niveau dans le même cookie.
(function () {
  var CK = "newcapman_lvup_level";
  var MAX = window.__NC_MAXLEVEL || 20;

  var msg = document.getElementById("nc-msg");
  var lvEl = document.getElementById("nc-lv");
  var playLvEl = document.getElementById("nc-play-lv");
  var fill = document.getElementById("nc-prog-fill");
  var playOverlay = document.getElementById("nc-play");
  var playBtn = document.getElementById("nc-play-btn");

  function getCookie(n) { var m = document.cookie.match("(?:^|;)\\s*" + n + "=([^;]*)"); return m ? decodeURIComponent(m[1]) : null; }
  function setCookie(n, v, d) { var e = new Date(Date.now() + (d || 365) * 864e5).toUTCString(); document.cookie = n + "=" + encodeURIComponent(v) + "; expires=" + e + "; path=/"; }
  function curLevel() { var x = parseInt(getCookie(CK) || "1", 10); if (isNaN(x) || x < 1) x = 1; return Math.min(x, MAX); }

  var lv = curLevel();
  if (lvEl) lvEl.textContent = lv;
  if (playLvEl) playLvEl.textContent = lv;

  if (typeof PIXI === "undefined") { msg.textContent = "Erreur : PixiJS non chargé."; return; }
  if (typeof CapManBoot === "undefined") { msg.textContent = "Erreur : game.js (CapManBoot) non chargé."; return; }

  // Barre de progression (0->1)
  window.addEventListener("nc-progress", function (e) {
    if (fill && e.detail) fill.style.width = Math.round(Math.min(1, Math.max(0, e.detail.c)) * 100) + "%";
  });

  // Écran « Jouer »
  var playStarted = false;
  window.addEventListener("nc-ready", function () { playOverlay.hidden = false; msg.textContent = "Prêt - clique sur Jouer."; });
  function doPlay() {
    if (playStarted) return;
    playStarted = true;
    try { if (CapManBoot.me) CapManBoot.me.startPlay(); } catch (e) { console.error(e); }
    playOverlay.hidden = true;
    msg.textContent = "Niveau " + lv + "…";
  }
  playBtn.addEventListener("click", doPlay);

  // Fin de partie : passage de niveau (win) ou réessai (lose). Le LvUP est une
  // progression personnelle -> on N'enregistre PAS dans le classement (réservé à League).
  var done = false;
  window.addEventListener("nc-finished", function (e) {
    if (done) return;
    done = true;
    var d = e.detail || {};
    var win = !!d.win;

    if (win) {
      if (lv >= MAX) { setCookie(CK, "1"); msg.textContent = "🎉 Campagne terminée (niveau " + MAX + ") ! Retour au niveau 1…"; }
      else { setCookie(CK, String(lv + 1)); msg.textContent = "Niveau " + lv + " réussi ✓ -> niveau " + (lv + 1) + "…"; }
    } else {
      msg.textContent = "Échec au niveau " + lv + ". Nouvelle tentative…";
    }
    setTimeout(function () { location.href = "/new-capman/lvup"; }, 2500);
  });

  try {
    new CapManBoot(document.getElementById("nc-canvas"));
    msg.textContent = "PixiJS v" + PIXI.VERSION + " - niveau " + lv + ".";
  } catch (err) {
    msg.textContent = "Erreur au démarrage : " + err;
    console.error(err);
  }
})();
