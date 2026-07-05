package api;

import api.AKProtocol;

// Port JS (PixiJS) de api.AKApi pour BTC en standalone (la façade d'origine
// n'est pas compilée ici). Jeu piloté au clavier : listeners keydown/keyup sur window,
// isDown/isToggled renvoient l'état réel. Le score et la fin de partie sont relayés à
// Boot (CustomEvents window btc-*).
class AKApi {
	static var score:Int = 0;
	static var seed:Int = 0;
	static var gameOverShown:Bool = false;

	// Mode "Défi Coffres" (survie infinie, coffres) : actif via ?mode=defi. Pas de
	// progression persistante (chaque partie est indépendante ; le score = nb de coffres).
	public static var defi:Bool = false;

	// Mode LvUP (campagne) : actif via ?mode=lvup ; niveau courant persistant via cookie.
	public static var lvup:Bool = false;
	static var lvupLevel:Int = 1;
	public static var playedLevel:Int = 1; // niveau réellement joué (pour le résultat)
	static inline var LVUP_MAX = 100;
	static inline var LVUP_COOKIE = "newbtc_lvup_level";

	// État clavier réel.
	static var keysDown:Map<Int, Bool> = new Map();
	// Touches "toggled" : front montant relâchée→appuyée, consommé à la lecture
	// (un appui physique = un toggle ; ignore l'auto-repeat clavier).
	static var keysToggled:Map<Int, Bool> = new Map();
	static var listenersInstalled:Bool = false;

	// Codes pour lesquels on bloque le scroll par défaut de la page (flèches+espace).
	static var GAME_KEYS = [32, 37, 38, 39, 40];

	// ZQSD (AZERTY) + WASD (QWERTY) → flèches : on remappe au niveau du listener pour
	// que isDown(LEFT/UP/...) fonctionne sans rien changer côté Hero.
	static var KEYMAP:Map<Int, Int> = [
		90 => 38, // Z -> Haut (AZERTY)
		87 => 38, // W -> Haut (QWERTY)
		81 => 37, // Q -> Gauche (AZERTY)
		65 => 37, // A -> Gauche (QWERTY)
		83 => 40, // S -> Bas
		68 => 39, // D -> Droite
	];

	// Appelé par Boot au démarrage.
	public static function init(?pSeed:Int):Void {
		score = 0;
		gameOverShown = false;
		seed = (pSeed != null) ? pSeed : Std.int(Math.random() * 1000000);
		// Campagne LvUP via ?mode=lvup ; niveau courant lu dans le cookie.
		var search:String = js.Browser.window.location.search;
		defi = search != null && search.indexOf("mode=defi") >= 0;
		lvup = search != null && search.indexOf("mode=lvup") >= 0;
		lvupLevel = readLvupLevel();
		playedLevel = lvupLevel;
		ensureListeners();
	}

	static function readLvupLevel():Int {
		var re = ~/newbtc_lvup_level=([0-9]+)/;
		if (js.Browser.document.cookie != null && re.match(js.Browser.document.cookie)) {
			var v = Std.parseInt(re.matched(1));
			if (v != null && v >= 1 && v <= LVUP_MAX)
				return v;
		}
		return 1;
	}

	static function writeLvupLevel(v:Int):Void {
		if (v < 1) v = 1;
		if (v > LVUP_MAX) v = LVUP_MAX;
		lvupLevel = v;
		js.Browser.document.cookie = LVUP_COOKIE + "=" + v + "; path=/; max-age=31536000";
	}

	// Niveau LvUP réussi → on passe au suivant (au prochain chargement de la page).
	public static function advanceLvup():Void {
		if (lvup)
			writeLvupLevel(lvupLevel + 1);
	}

	static function ensureListeners():Void {
		if (listenersInstalled) return;
		listenersInstalled = true;
		js.Browser.window.addEventListener("keydown", function(e:Dynamic) {
			var k:Int = e.keyCode;
			if (KEYMAP.exists(k)) k = KEYMAP.get(k); // ZQSD/WASD -> flèches
			if (keysDown.get(k) != true) keysToggled.set(k, true);
			keysDown.set(k, true);
			if (GAME_KEYS.indexOf(k) >= 0 && e.preventDefault != null) e.preventDefault();
		});
		js.Browser.window.addEventListener("keyup", function(e:Dynamic) {
			var k:Int = e.keyCode;
			if (KEYMAP.exists(k)) k = KEYMAP.get(k);
			keysDown.remove(k);
		});
	}

	// --- valeurs de partie ---
	public static function getSeed():Int {
		return seed;
	}

	public static function getLevel():Int {
		return lvup ? lvupLevel : 1;
	}

	public static function getGameMode():GameMode {
		return lvup ? GM_PROGRESSION : GM_LEAGUE;
	}

	public static function getLang():String {
		return "fr";
	}

	// --- inputs ---
	public static function isDown(k:Int, ?k2:Int, ?k3:Int):Bool {
		if (keysDown.get(k) == true) return true;
		if (k2 != null && keysDown.get(k2) == true) return true;
		if (k3 != null && keysDown.get(k3) == true) return true;
		return false;
	}

	public static function isToggled(k:Int, ?k2:Int, ?k3:Int):Bool {
		if (consumeToggle(k)) return true;
		if (k2 != null && consumeToggle(k2)) return true;
		if (k3 != null && consumeToggle(k3)) return true;
		return false;
	}

	static inline function consumeToggle(k:Int):Bool {
		if (keysToggled.get(k) == true) {
			keysToggled.remove(k);
			return true;
		}
		return false;
	}

	// --- constantes sécurisées ---
	public static function const(n:Int):AKConst {
		return new AKConst(n);
	}

	public static function aconst(a:Array<Int>):Array<AKConst> {
		return [for (n in a) new AKConst(n)];
	}

	// --- score ---
	public static function addScore(c:AKConst):Void {
		score += c.get();
		// BTC : addScore n'est appelé qu'au ramassage d'une pièce (pas chaque frame)
		// → on pousse le HUD à CHAQUE appel, sans throttle.
		if (Boot.me != null) Boot.me.addScore(score);
	}

	public static function getScore():Int {
		return score;
	}

	public static function setProgression(c:Float):Void {
		// LEAGUE : pas de barre de progression. No-op (utile en mode Progression).
	}

	// --- cadeaux PK (désactivés en standalone) ---
	public static function getInGamePrizeTokens():Array<SecureInGamePrizeTokens> {
		return [];
	}

	public static function takePrizeTokens(pk:SecureInGamePrizeTokens):Void {}

	// --- perf / qualité ---
	// Plein régime WebGL : on ne coupe pas les FX lourds (isLowQuality reste false).
	// Particle.LIMIT reste à 350.
	public static function getPerf():Float {
		return 1.0;
	}

	public static function isLowQuality():Bool {
		return false;
	}

	// --- fin de partie ---
	public static function gameOver(?win:Dynamic):Void {
		if (gameOverShown) return;
		gameOverShown = true;
		var w = win == true;
		playedLevel = lvupLevel;
		if (lvup && w) advanceLvup(); // niveau réussi → niveau suivant au prochain chargement
		if (Boot.me != null) Boot.me.gameOver(w);
	}
}
