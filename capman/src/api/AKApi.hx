package api;

import api.AKProtocol;
import common_haxe_avm1.KeyboardManager;

// Mock de l'API Arkadeo : mode (League/LvUP/Éditeur), seed, niveau, inputs
// (KeyboardManager) ; score/progression/fin relayés à Boot (CustomEvents nc-*).
class AKApi {
	static var score:Int = 0;
	static var seed:Int = 0;
	static var gameOverShown:Bool = false;
	static var progression:Bool = false; // true = mode LvUP
	static var editor:Bool = false; // true = mode Éditeur de niveaux
	static var speedrun:Bool = false; // true = mode SpeedRun (niveaux 1->20 enchaînés, chrono)
	static var level:Int = 1;

	public static function init(?pSeed:Int):Void {
		score = 0;
		gameOverShown = false;
		seed = (pSeed != null) ? pSeed : Std.int(Math.random() * 1000000);
	}

	// Appelé par Boot après lecture de l'URL/cookie.
	public static function setMode(lvup:Bool, lvl:Int):Void {
		progression = lvup;
		level = (lvl < 1) ? 1 : lvl;
		// LvUP : seed déterministe par niveau (mêmes labyrinthes générés au réessai).
		if (progression) seed = level;
	}

	// Active le mode Éditeur (posé par Boot quand l'URL contient ?mode=edit).
	public static function setEditor(b:Bool):Void {
		editor = b;
	}

	public static function isEditor():Bool {
		return editor;
	}

	// Active le mode SpeedRun (posé par Boot quand l'URL contient ?mode=speedrun).
	// progression=true en parallèle pour charger les niveaux DESSINÉS (comme LvUP).
	public static function setSpeedrun(b:Bool):Void {
		speedrun = b;
	}

	public static function isSpeedrun():Bool {
		return speedrun;
	}

	public static function getModeStr():String {
		return speedrun ? "speedrun" : (editor ? "editor" : (progression ? "lvup" : "league"));
	}

	// --- Valeurs de partie ---
	public static function getSeed():Int {
		return seed;
	}

	public static function getLevel():Int {
		return level;
	}

	// Met à jour le niveau courant sans toucher au mode (utilisé par l'éditeur quand
	// on navigue : la taille de grille à l'essai/retour en dépend).
	public static function setLevel(n:Int):Void {
		level = (n < 1) ? 1 : n;
	}

	public static function getGameMode():GameMode {
		return progression ? GM_PROGRESSION : GM_LEAGUE;
	}

	// --- Inputs (via KeyboardManager) ---
	public static function isDown(k:Int, ?k2:Int, ?k3:Int):Bool {
		if (KeyboardManager.isDown(k)) return true;
		if (k2 != null && KeyboardManager.isDown(k2)) return true;
		if (k3 != null && KeyboardManager.isDown(k3)) return true;
		return false;
	}

	public static function isToggled(k:Int, ?k2:Int, ?k3:Int):Bool {
		if (KeyboardManager.isJustDown(k)) return true;
		if (k2 != null && KeyboardManager.isJustDown(k2)) return true;
		if (k3 != null && KeyboardManager.isJustDown(k3)) return true;
		return false;
	}

	// --- Constantes sécurisées ---
	public static function const(n:Int):AKConst {
		return new AKConst(n);
	}

	// --- Score ---
	public static function addScore(c:AKConst):Void {
		score += c.get();
		if (Boot.me != null) Boot.me.addScore(score);
	}

	public static function getScore():Int {
		return score;
	}

	// --- Barre de progression (0 = début, 1 = niveau presque fini) - LvUP seulement. ---
	public static function setProgression(c:Float):Void {
		if (progression && Boot.me != null) Boot.me.progress(c);
	}

	// --- Cadeaux PK (désactivés en standalone) ---
	public static function getInGamePrizeTokens():Array<SecureInGamePrizeTokens> {
		return [];
	}

	public static function takePrizeTokens(pk:Dynamic):Void {}

	// --- HUD ---
	public static function setStatusMC(mc:Dynamic, ?align:String):Dynamic {
		return null;
	}

	// --- Fin de partie ---
	public static function gameOver(?win:Dynamic):Void {
		if (gameOverShown) return;
		gameOverShown = true;
		if (Boot.me != null) Boot.me.gameOver(win == true);
	}

	// Réarme gameOver (après un essai éditeur, pour pouvoir re-terminer ensuite).
	public static function resetGameOver():Void {
		gameOverShown = false;
	}
}
