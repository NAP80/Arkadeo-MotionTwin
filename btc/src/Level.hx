import Const;
import flash.display.Sprite;
import flash.display.BitmapData;
import mt.deepnight.Lib;
import mt.deepnight.slb.BSprite;
import mt.RandList;
import com.gen.LevelGenerator;

// Deux points remplacent le Flash d'origine : readFromFile lit une BitmapData fournie
// par Boot (Level.source) au lieu de l'embed compile-time, et render dessine des
// sprites PixiJS au lieu de compositer une BitmapData.
typedef MapCell = {
	var collide:Bool;
	var ladder:Bool;
}

class Level {
	// Carte de collision fournie par Boot avant new Game().
	public static var source:BitmapData;

	var mode:Mode;
	var map:Array<Array<MapCell>>;
	var walls:Sprite;
	var rseed:mt.Rand;
	var spots:Map<String, Array<{cx:Int, cy:Int}>>;
	public var lgen:LevelGenerator;

	public function new() {
		mode = Mode.ME;
		map = new Array();
		rseed = new mt.Rand(0);
		spots = new Map();
		lgen = new LevelGenerator();

		for (cx in 0...Const.LWID) {
			map[cx] = new Array();
			for (cy in 0...Const.LHEI)
				map[cx][cy] = {collide: false, ladder: false};
		}
	}

	inline function initRandom() {
		rseed.initSeed(getSeed());
	}

	inline function getSeed() {
		// Progression = graine par niveau (lid) ; les autres modes = graine de partie.
		// On teste isProgression (pas isLeague) pour ne pas appeler asProgression() en Défi.
		return mode.isProgression() ? mode.asProgression().lid : mode.seed;
	}

	// Génère le niveau via le LevelGenerator, puis remplit collision + spots.
	public function generateProgression(lvl:Int) {
		initRandom();
		lgen.generateProgressionLevel(lvl);

		// Plateformes -> collision + spots de sol.
		for (p in lgen.platforms) {
			var cy = p.cy;
			for (cx in p.cx...p.cx + p.wid) {
				map[cx][cy].collide = true;
				addSpot("ground", cx, cy - 1);
				addSpot("floor_" + getFloor(cy - 1), cx, cy - 1);
			}
		}

		// Échelles (trace de la plateforme vers le haut jusqu'à la collision).
		for (p in lgen.platforms)
			for (lcx in p.ladders) {
				var lcy = p.cy - 1;
				while (lcy > 0 && !hasCollision(lcx, lcy)) {
					map[lcx][lcy].ladder = true;
					lcy--;
				}
				map[lcx][lcy].ladder = true;
			}

		initRandom();
	}

	// Défi Coffres : map fixe mais générée par le LevelGenerator pinné sur un niveau
	// constant. Le générateur seede de façon déterministe (18660 + lid*1000), donc
	// generateProgressionLevel(ENDLESS_LVL) rend toujours la même map. On force en plus
	// un plancher continu (pas de chute mortelle). Changer ENDLESS_LVL = autre map.
	static inline var ENDLESS_LVL = 42; // choisi : 1 seule échelle multi-étages hors sol -> 1 seul skip

	public function generateEndless() {
		lgen.generateProgressionLevel(ENDLESS_LVL);

		// Plateformes du générateur -> collision.
		for (p in lgen.platforms) {
			var cy = p.cy;
			for (cx in p.cx...p.cx + p.wid)
				if (cx >= 0 && cx < Const.LWID && cy >= 0 && cy < Const.LHEI)
					map[cx][cy].collide = true;
		}

		// Plancher plein en bas (toute la rangée du bas).
		for (cx in 0...Const.LWID)
			map[cx][Const.LHEI - 1].collide = true;

		// Chaque échelle est reliée à la plateforme du dessus (ou au sommet) pour ne jamais
		// laisser de bout flottant. Une échelle monte d'1 étage max, sauf celles partant du
		// sol (floor 0) qui peuvent en faire 2 : on saute donc les échelles hors-sol qui
		// franchiraient >=2 étages, sauf si elles atteignent le sommet (route d'évasion).
		for (p in lgen.platforms) {
			var pcy = p.cy;
			for (lcx in p.ladders) {
				var dest = pcy - 1;
				while (dest > 0 && !hasCollision(lcx, dest)) dest--; // 1re plateforme au-dessus / sommet
				if (getFloor(pcy) > 0 && dest > 0 && Std.int(Math.ceil((pcy - dest) / 3)) >= 2)
					continue;
				var lcy = pcy - 1;
				while (lcy > dest) { map[lcx][lcy].ladder = true; lcy--; }
				if (dest >= 0) map[lcx][dest].ladder = true; // coiffe (plateforme ou sommet)
			}
		}

		ensureEscapeRoute();
		rebuildSpots();
	}

	// Garantit qu'une échelle atteint le sommet (cy=0), sinon les ennemis ne peuvent jamais
	// s'échapper et on ne perd jamais. On prolonge l'échelle existante la plus haute plutôt
	// que de creuser un puits pleine hauteur : seule chaîne autorisée à dépasser 1 étage.
	public var escapeForced:Bool = false; // true si on a dû prolonger une échelle vers le sommet

	function ensureEscapeRoute() {
		for (cx in 0...Const.LWID)
			if (map[cx][0].ladder)
				return; // route vers le haut déjà présente

		// Prolonge jusqu'à cy=0 l'échelle qui monte le plus haut.
		var bestCx = 1, bestCy = Const.LHEI;
		for (cx in 0...Const.LWID)
			for (cy in 0...Const.LHEI)
				if (map[cx][cy].ladder && cy < bestCy) { bestCy = cy; bestCx = cx; }

		escapeForced = true;
		for (cy in 0...bestCy) {
			map[bestCx][cy].collide = false;
			map[bestCx][cy].ladder = true;
		}
	}

	// Spots de sol : toute cellule vide avec une collision juste en dessous est un point
	// où héros/ennemis/coffres peuvent se tenir.
	function rebuildSpots() {
		spots = new Map();
		for (cx in 0...Const.LWID)
			for (cy in 0...Const.LHEI)
				if (!map[cx][cy].collide && cy + 1 < Const.LHEI && map[cx][cy + 1].collide) {
					addSpot("ground", cx, cy);
					addSpot("floor_" + getFloor(cy), cx, cy);
				}
	}

	public function readFromFile(n:Int) {
		for (x in 0...Const.LWID) {
			map[x] = new Array();
			for (y in 0...Const.LHEI) {
				var pixel = source != null ? source.getPixel(x, y + n * Const.LHEI) : 0;
				var under = source != null ? source.getPixel(x, y + n * Const.LHEI + 1) : 0;
				var coll = pixel == 0xFFFFFF;
				map[x][y] = {
					collide: coll,
					ladder: pixel == 0xFF0000 || under == 0xff0000,
				}
				if (!coll && under == 0xFFFFFF) {
					addSpot("ground", x, y);
					addSpot("floor_" + getFloor(y), x, y);
				}
			}
		}
	}

	public static inline function getFloor(cy):Int {
		return 4 - Std.int(Math.min(4, Math.max(0, (cy - 2) / 3)));
	}

	public inline function addSpot(k:String, cx, cy) {
		if (!spots.exists(k))
			spots.set(k, new Array());
		spots.get(k).push({cx: cx, cy: cy});
	}

	public function destroy() {
		detach();
	}

	public function detach() {
		if (walls != null) {
			if (walls.parent != null)
				walls.parent.removeChild(walls);
			walls = null;
		}
	}

	public inline function isValid(cx, cy) {
		return cx >= 0 && cy >= 0 && cx < Const.LWID && cy < Const.LHEI;
	}

	public inline function hasCollision(cx, cy) {
		if (cy < 0 || cy >= Const.LHEI)
			return false;
		else if (cx < 0 || cx >= Const.LWID)
			return true;
		else
			return map[cx][cy].collide;
	}

	public function hasLadder(cx, cy) {
		if (cy < 0)
			return true;
		else if (isValid(cx, cy))
			return map[cx][cy].ladder;
		else
			return false;
	}

	// Rendu : fond + plateformes (tuiles de bord Side + miroir aléatoire) + décorations +
	// échelles. L'ordre des tirages rseed doit rester aligné sur l'original, sinon la map
	// visuelle diverge de la map de collision.
	public function render() {
		initRandom();
		detach();
		walls = new Sprite();
		mode.dm.add(walls, Const.DP_BG);

		// z : fond < deco arrière < ombres < plateformes/deco avant < échelles.
		var bgLayer = new Sprite();
		var backLayer = new Sprite();
		var shadowLayer = new Sprite();
		var platLayer = new Sprite();
		var ladderLayer = new Sprite();
		walls.addChild(bgLayer);
		walls.addChild(backLayer);
		walls.addChild(shadowLayer);
		walls.addChild(platLayer);
		walls.addChild(ladderLayer);

		// Ombre portée sous le bord inférieur exposé de chaque plateforme (relief).
		var shadowG = new flash.display.Graphics();
		shadowLayer.addChild(shadowG);

		// Fond (Progression : frame = (lid/10)%4 selon le thème ; League : frame 0).
		if (mode.bgs != null && mode.bgs.exists("bg")) {
			var bgFrame = mode.isProgression() ? Std.int(mode.asProgression().lid / 10) % 4 : 0;
			var bg = mode.bgs.get("bg", mode.bgs.exists("bg", bgFrame) ? bgFrame : 0);
			bg.setCenter(0, 0);
			bg.scaleX = bg.scaleY = 2;
			bgLayer.addChild(bg);
		}

		// Peau du décor : "Rock" par défaut, variable selon le niveau en Progression. On tire
		// un set puis une peau par cellule (rseed : skinSet d'abord, fromMap ensuite).
		var skinSet:Array<Map<String, Int>> = [["Rock" => 10]];
		if (mode.isProgression()) {
			var lid = mode.asProgression().lid;
			skinSet = if (lid < 10) [["Wood" => 10]]; else if (lid < 20) [["Grass" => 10]]; else if (lid < 30) [["Roof" => 10]]; else if (lid <
				40) [["Rock" => 10]]; else if (lid < 50) [["Ice" => 10], ["Ice" => 10, "Metal" => 3], ["Ice" => 10, "Brick" => 4]]; else if (lid <
				60) [["Blue" => 10]]; else if (lid < 70) [["Ruby" => 10]]; else if (lid < 80) [["Metal" => 10], ["Metal" => 10, "Ice" => 4]]; else if (lid <
				90) [["Metal" => 10], ["Metal" => 10, "Ice" => 4]]; else if (lid < 100) [["Obsidian" => 10], ["Obsidian" => 10, "Brick" => 4]]; else
				[["Obsidian" => 10, "Roof" => 4]];
		}
		var skin = skinSet[rseed.random(skinSet.length)];

		var hasBack = mode.tiles.exists("deco_back");
		var hasFront = mode.tiles.exists("deco_front");

		for (cx in 0...Const.LWID)
			for (cy in 0...Const.LHEI) {
				var x = cx * Const.GRID;
				var y = cy * Const.GRID;

				if (hasCollision(cx, cy)) {
					var id = RandList.fromMap(skin).draw(rseed.random); // peau tirée par cellule
					if (mode.tiles.exists("plateform" + id)) {
						var hasSide = mode.tiles.exists("plateform" + id + "Side");
						var s:BSprite;
						if (hasSide && !hasCollision(cx + 1, cy)) {
							s = mode.tiles.get("plateform" + id + "Side");
							s.x = x;
						} else if (hasSide && !hasCollision(cx - 1, cy)) {
							s = mode.tiles.get("plateform" + id + "Side");
							s.scaleX = -1;
							s.x = x + Const.GRID;
						} else {
							s = mode.tiles.get("plateform" + id);
							s.scaleX = rseed.sign();
							s.x = s.scaleX < 0 ? x + Const.GRID : x;
						}
						s.setCenter(0, 0);
						s.y = y;
						platLayer.addChild(s);
					}

					// Ombre portée si l'espace en dessous est ouvert (2 bandes = fondu).
					if (!hasCollision(cx, cy + 1)) {
						shadowG.beginFill(0x120726, 0.38);
						shadowG.drawRect(x, y + Const.GRID, Const.GRID, 7);
						shadowG.endFill();
						shadowG.beginFill(0x120726, 0.18);
						shadowG.drawRect(x, y + Const.GRID + 7, Const.GRID, 7);
						shadowG.endFill();
					}
				}

				var interior = hasCollision(cx, cy) && hasCollision(cx - 1, cy) && hasCollision(cx + 1, cy);

				// Décoration arrière (25 %)
				if (rseed.random(100) < 25 && interior && hasBack) {
					var s = mode.tiles.getRandom("deco_back", rseed.random);
					s.setCenter(0.5, 0);
					s.x = x;
					s.y = y - Const.GRID;
					backLayer.addChild(s);
				}

				// Décoration avant (10 %)
				if (rseed.random(100) < 10 && interior && hasFront) {
					var s = mode.tiles.getRandom("deco_front", rseed.random);
					s.scaleX = rseed.sign();
					s.scaleY = rseed.range(0.5, 1);
					s.x = x;
					s.y = y;
					s.setPivotCoord(s.width * 0.5, 34);
					platLayer.addChild(s);
				}
			}

		// Échelles (frame : 1 = haut, 2 = bas, 0 = milieu)
		if (mode.tiles.exists("ladder"))
			for (cx in 0...Const.LWID)
				for (cy in 0...Const.LHEI)
					if (hasLadder(cx, cy)) {
						var f = !hasLadder(cx, cy - 1) ? 1 : (!hasLadder(cx, cy + 1) ? 2 : 0);
						var s = mode.tiles.get("ladder", f);
						s.setCenter(0, 0);
						s.x = cx * Const.GRID;
						s.y = cy * Const.GRID;
						ladderLayer.addChild(s);
					}
	}

	public function getGroundSpotsCopy() {
		return spots.get("ground").copy();
	}

	public function getGroundSpotsAround(cx, cy, ?min = 0, ?max = 5) {
		var all = [];
		for (pt in spots.get("ground")) {
			var d = Lib.distanceSqr(cx, cy, pt.cx, pt.cy);
			if (d >= min * min && d <= max * max)
				all.push(pt);
		}
		return all;
	}

	public function getRandomSpotFar(?floor:Int) {
		var pt = null;
		var tries = 200;
		do {
			pt = getRandomSpot(floor);
		} while (tries-- > 0 && Lib.distance(mode.hero.cx, mode.hero.cy, pt.cx, pt.cy) <= 5);
		return pt;
	}

	public function getRandomSpot(?floor:Int) {
		if (floor == null) {
			var all = spots.get("ground");
			return all[rseed.random(all.length)];
		} else {
			var all = spots.get("floor_" + floor);
			// Repli : si l'étage demandé n'a aucun spot (map procédurale clairsemée),
			// on retombe sur le sol → évite un crash (all[random(0)] = null).
			if (all == null || all.length == 0)
				all = spots.get("ground");
			return all[rseed.random(all.length)];
		}
	}
}
