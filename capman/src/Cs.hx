import mt.bumdum9.Lib;
import Protocol;
import api.AKApi;

// Constantes + atlas. initGfx() découpe la planche gfx.png (keyée hors ligne par gen_atlas.py, chargée par Boot) aux coordonnées d'origine.
class Cs {
	public static var WIDTH = 600;
	public static var HEIGHT = 460;
	public static var DIR = [[1, 0], [0, 1], [-1, 0], [0, -1]];
	public static var SQ = 32;
	public static var XMAX = 19; // 18
	public static var YMAX = 15; // 14
	public static var CX = Std.int(WIDTH - XMAX * SQ) >> 1;
	public static var CY = Std.int(HEIGHT - YMAX * SQ) >> 1;

	public static var FORCE_ONE_COIN = false;

	public static var SCORE_BALL = api.AKApi.const(20);
	public static var SCORE_BALL_INC = api.AKApi.const(5);
	public static var SCORE_BALL_MAX = api.AKApi.const(60);

	public static var MONSTERS_INIT = [0];
	public static var MONSTERS_SPAWN_DELAY = [1200, 3000, 5400, 7000, 8600, 9600, 10800];

	public static var BONUS_LIFE = 210;

	// Campagne LvUP JOUÉE : 20 niveaux (cap de lvup.js / la vue LvUP).
	public static inline var MAXLEVEL = 20;
	// Éditeur : on peut dessiner jusqu'à 30 niveaux ; les niveaux >= BIG_FROM (21-30)
	// utilisent la grande grille. (Découplé de MAXLEVEL : la campagne reste à 20.)
	public static inline var EDITOR_MAX = 30;
	public static inline var BIG_FROM = 21;
	// Grande grille (niveaux >= BIG_FROM) : 26×20 = 520 cases.
	public static inline var BIG_XMAX = 26;
	public static inline var BIG_YMAX = 20;
	public static inline var EDITOR_STORE = "newcapman_editor_levels";

	// Niveaux dessinés du mode LvUP (haxe.Serializer) - Désérialisés dans Game.initLevel.
	public static var levels = CsLevels.DATA;

	public static var store:mt.pix.Store;

	// Applique la taille de grille (petit 19×15 / grand 26×20) et
	// recalcule CX/CY (centrage), qui ne sont sinon évalués qu'à l'init de classe.
	public static function setSize(big:Bool) {
		if (big) {
			XMAX = BIG_XMAX; YMAX = BIG_YMAX; WIDTH = XMAX * SQ; HEIGHT = YMAX * SQ; // 832×640
		} else {
			WIDTH = 600; HEIGHT = 460; XMAX = 19; YMAX = 15;
		}
		CX = Std.int(WIDTH - XMAX * SQ) >> 1;
		CY = Std.int(HEIGHT - YMAX * SQ) >> 1;
	}

	public static inline function isBigLevel(level:Int):Bool {
		return level >= BIG_FROM;
	}

	// Source de la campagne : édition locale (localStorage de l'éditeur) si présente,
	// sinon les 20 niveaux bakés. Partagé par le jeu (Game.initLevel) et l'éditeur.
	public static function campaignData():String {
		try {
			var s = js.Browser.window.localStorage.getItem(EDITOR_STORE);
			if (s != null && s != "") return s;
		} catch (e:Dynamic) {}
		return levels;
	}

	public static function getTinyScore(sco:Int) {
		var mc = new SP();
		var a = Std.string(sco).split("");
		var px = -a.length * 2;
		for (char in a) {
			var el = new EL();
			el.goto(char.charCodeAt(0) - 48, "num", 0, 0);
			el.x = px;
			mc.addChild(el);
			px += char == "1" ? 4 : 8;
		}
		return mc;
	}

	public static function initGfx() {
		// Chargé par Boot dans le loader partagé PixiJS.
		var tex = untyped js.Syntax.code("PIXI.Loader.shared.resources['capman'].texture");
		store = new mt.pix.Store(tex);

		mt.pix.Element.DEFAULT_STORE = store;

		store.addIndex("tiles");
		for (i in 0...4)
			store.slice(0, 128 * i, 32, 32, 4, 4);

		store.addIndex("levels");
		store.slice(0, 64, 18, 14, 5, 4);
		store.addIndex("coin");
		store.slice(128, 0, 8, 8);
		store.addIndex("num");
		store.slice(144, 0, 8, 10);
		store.slice(152, 0, 4, 10);
		store.slice(156, 0, 8, 10, 8);
		store.addIndex("door");
		store.slice(128, 16, 64, 16);
		store.addIndex("bads");
		store.slice(192, 32, 32, 32, 2, 6);

		store.addIndex("wall_parts");
		for (i in 0...4) {
			var x = 256 + 16 * i;
			store.slice(x, 16, 6, 5);
			store.slice(x + 9, 16, 7, 6, 1, 2);
			store.slice(x + 1, 21, 7, 6);
			store.slice(x, 28, 5, 4, 2);
		}

		store.addIndex("hero");
		store.slice(6 * 32, 6 * 32, 32, 32, 8, 3);
		store.addAnim("hero_walk_0", [4, 5, 6, 7], [4]);
		store.addAnim("hero_walk_1", [0, 1, 2, 3], [4]);
		store.addAnim("hero_walk_2", [12, 13, 14, 15], [4]);
		store.addAnim("hero_walk_3", [8, 9, 10, 11], [4]);

		var offset = 16;
		var anim = [2, 3, 4, 4, 3, 2, 3, 4, 3, 2, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1];
		store.addAnim("hero_die", anim.map(function(frame) return frame + offset), [4]);

		store.addIndex("hero_cap");
		store.slice(6 * 32, 9 * 32, 32, 32, 8, 3);
		store.addAnim("hero_walk_cap_0", [4, 5, 6, 7], [4]);
		store.addAnim("hero_walk_cap_1", [0, 1, 2, 3], [4]);
		store.addAnim("hero_walk_cap_2", [12, 13, 14, 15], [4]);
		store.addAnim("hero_walk_cap_3", [8, 9, 10, 11], [4]);

		var offset = 16;
		var anim = [2, 3, 4, 4, 3, 2, 3, 4, 3, 2, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1];
		store.addAnim("hero_die_cap", anim.map(function(frame) return frame + offset), [4]);

		store.addIndex("hero_shoe");
		store.slice(6 * 32, 12 * 32, 32, 32, 8, 3);
		store.addAnim("hero_walk_shoe_0", [4, 5, 6, 7], [4]);
		store.addAnim("hero_walk_shoe_1", [0, 1, 2, 3], [4]);
		store.addAnim("hero_walk_shoe_2", [12, 13, 14, 15], [4]);
		store.addAnim("hero_walk_shoe_3", [8, 9, 10, 11], [4]);
		var offset = 16;
		var anim = [2, 3, 4, 4, 3, 2, 3, 4, 3, 2, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1];
		store.addAnim("hero_die_shoe", anim.map(function(frame) return frame + offset), [4]);

		store.addIndex("cap");
		store.slice(6 * 32, 8, 32, 24);

		store.addIndex("shoe");
		store.slice(7 * 32, 8, 32, 24);

		// MONSTER 0 - SMILEY
		store.addIndex("smiley");
		store.slice(192, 32, 32, 32, 7);
		store.addAnim("smiley_turn", [0, 1, 2, 3, 4, 5, 6], [3]);

		// MONSTER 1 - SKULL
		store.addIndex("skull");
		store.slice(192, 64, 32, 32, 4);
		store.addAnim("skull_base", [0, 1], [8]);
		store.addAnim("skull_fire", [2, 3], [4]);

		// MONSTER 2 - BLOCKER
		store.addIndex("blocker");
		store.slice(192, 96, 32, 32, 5);
		store.addAnim("blocker_base", [3], [4]);
		store.addAnim("blocker_angry", [4], [4]);
		store.addAnim("blocker_bam", [0, 1, 2, 3], [38, 4, 4, 40]);

		// MONSTER 3 - JUMPER
		store.addIndex("jumper");
		store.slice(192, 128, 32, 32, 8);
		store.addAnim("jumper_base", [0, 1, 2, 3], [4]);
		store.addAnim("jumper_jump", [4, 7, 6, 6, 7, 7], [4]);
		store.addAnim("jumper_land", [5, 6, 7, 0], [4]);

		// MONSTER 4 - SEEKER
		store.addIndex("seeker");
		store.slice(192, 160, 32, 32, 4);
		store.addAnim("seeker_fly", [0, 1, 2, 3], [4]);
	}
}
