package seq;

import mt.bumdum9.Lib;
import Protocol;

// Éditeur de niveaux. S'enregistre comme Game.me.stepFx (met le jeu en pause) et reçoit son update() chaque frame,
// Édite directement la grille du Game (souris via interaction.mouse.global, clavier via KeyboardManager).
// Persistance en localStorage + export texte exposé à la page (cf. Boot.editor*).
class Editor extends mt.fx.Sequence {
	static inline var K_BACKSPACE = 8;
	static inline var K_ESCAPE = 27;
	static inline var K_SPACE = 32;
	static inline var K_DELETE = 46;
	static inline var K_LEFT = 37;
	static inline var K_UP = 38;
	static inline var K_RIGHT = 39;
	static inline var K_DOWN = 40;
	static inline var K_SHIFT = 16;

	public static var me:Editor;

	var cursor:SP;
	var root:SP;
	var square:Square;

	var data:DataProgression;

	var rectangleStart:Null<Int>;
	var rectangleCursor:SP;

	// Peinture de blocs en maintenant Espace : paintFill = mode (poser/retirer) figé
	// au 1er appui ; paintSq = dernière case peinte (anti-répétition sur place).
	var paintSq:Square;
	var paintFill:Bool;

	public function new() {
		super();
		me = this;
		Game.me.stepFx = this;

		root = new SP();
		Game.me.dm.add(root, Game.DP_INTER);

		// R-CURSOR (rectangle, orange)
		rectangleCursor = new SP();
		rectangleCursor.graphics.lineStyle(1, 0xFF8800);
		rectangleCursor.graphics.drawRect(0, 0, Cs.SQ, Cs.SQ);
		root.addChild(rectangleCursor);
		rectangleCursor.visible = false;

		// CURSOR (case survolée, vert)
		cursor = new SP();
		cursor.graphics.lineStyle(1, 0x88FF00);
		cursor.graphics.drawRect(0, 0, Cs.SQ, Cs.SQ);
		root.addChild(cursor);

		// DATA : on repart des niveaux stockés, sinon de la campagne d'origine.
		var stored = loadStore();
		if (stored == null) {
			data = haxe.Unserializer.run(Cs.levels);
		} else {
			data = stored;
		}
		if (data._cursor == null) data._cursor = 0;

		loadLevel();
	}

	function clean() {
		for (sq in Game.me.squares) {
			sq.removeCoin(false);
			if (sq.door != null) sq.door.kill();
		}
		for (e in Game.me.ents.copy())
			if (e != Game.me.hero)
				e.kill();
	}

	// Position souris en coordonnées scène (stage non scalé = coords Square.getPos).
	function getMouse():{x:Float, y:Float} {
		var g:Dynamic = untyped Boot.me.renderer.plugins.interaction.mouse.global;
		return {x: g.x, y: g.y};
	}

	override function update() {
		super.update();

		var m = getMouse();
		var x = Std.int((m.x - Cs.CX) / Cs.SQ);
		var y = Std.int((m.y - Cs.CY) / Cs.SQ);

		square = Game.me.getSquare(x, y);
		if (square == null) {
			cursor.visible = false;
			return;
		}
		cursor.visible = true;
		var pos = Square.getPos(x, y);
		cursor.x = pos.x;
		cursor.y = pos.y;

		if (api.AKApi.isToggled(68)) toggleWall(0); // D
		if (api.AKApi.isToggled(83)) toggleWall(1); // S
		if (api.AKApi.isToggled(81)) toggleWall(2); // Q
		if (api.AKApi.isToggled(90)) toggleWall(3); // Z

		// BLOC : Espace maintenu = peinture continue (le mode poser/retirer est figé au
		// 1er appui d'après la case visée), en balayant à la souris case par case.
		if (api.AKApi.isToggled(K_SPACE)) {
			paintFill = !square.isBlock();
			setBlockState(square, paintFill);
			paintSq = square;
			saveLevel();
		} else if (api.AKApi.isDown(K_SPACE)) {
			if (square != paintSq) {
				setBlockState(square, paintFill);
				paintSq = square;
				saveLevel();
			}
		} else {
			paintSq = null;
		}

		if (api.AKApi.isToggled(K_DELETE)) delete();
		if (api.AKApi.isToggled(K_ESCAPE)) leave();
		if (api.AKApi.isToggled(K_BACKSPACE)) reset();

		if (api.AKApi.isToggled(K_RIGHT)) scroll(0);
		if (api.AKApi.isToggled(K_DOWN)) scroll(1);
		if (api.AKApi.isToggled(K_LEFT)) scroll(2);
		if (api.AKApi.isToggled(K_UP)) scroll(3);

		if (api.AKApi.isToggled(72)) toggleHero();   // (H)éros
		if (api.AKApi.isToggled(82)) doRectangle();  // (R)ectangle
		if (api.AKApi.isToggled(84)) toggleTurner();  // (T)urner / porte

		if (api.AKApi.isToggled(49)) toggleMonster(0); // 1
		if (api.AKApi.isToggled(50)) toggleMonster(1); // 2
		if (api.AKApi.isToggled(51)) toggleMonster(2); // 3
		if (api.AKApi.isToggled(52)) toggleMonster(3); // 4
		if (api.AKApi.isToggled(53)) toggleMonster(4); // 5
	}

	// STRUCTURE
	function toggleWall(di) {
		var n = square.getWall(di);
		if (n == 2) return; // mur de porte : non éditable
		setWall(square, di, 1 - n);
		saveLevel();
	}

	// Pose (fill) ou retire (ouvre vers les voisins non-bloc) un bloc plein sur une case.
	function setBlockState(sq:Square, fill:Bool) {
		if (fill) {
			for (di in 0...4) setWall(sq, di, 1);
		} else {
			for (di in 0...4) {
				var nsq = sq.dnei[di];
				if (nsq == null || nsq.isBlock()) continue;
				setWall(sq, di, 0);
			}
		}
	}

	function toggleTurner() {
		var a = [];
		var sq = square;
		for (di in 0...4) {
			a.push(sq);
			sq = sq.dnei[di];
			if (sq == null) return; // bord de grille : pas de porte ici
		}

		var door = null;
		for (sq in a) if (sq.door != null) door = sq.door;

		if (door == null) {
			door = new Door(square);
			for (sq in a) sq.majGfx();
		} else {
			door.kill();
		}
		saveLevel();
	}

	function setWall(sq:Square, di, n) {
		// Au bord de la grille, dnei[di] est null : ce mur est la bordure, toujours
		// plein et non éditable. Sans ce garde, setWall/majGfx déréférence null.
		if (sq.dnei[di] == null) return;
		sq.setWall(di, n);
		sq.dnei[di].majGfx();
		sq.majGfx();
	}

	function doRectangle() {
		if (rectangleStart == null) {
			rectangleStart = square.getId();
			var pos = Square.getPos(square.x, square.y);
			rectangleCursor.x = pos.x;
			rectangleCursor.y = pos.y;
		} else {
			var a = Game.me.squares[rectangleStart];
			var fill = !a.isBlock();

			var sx = Std.int(Math.min(a.x, square.x));
			var sy = Std.int(Math.min(a.y, square.y));
			var xmax = Math.abs(a.x - square.x);
			var ymax = Math.abs(a.y - square.y);
			for (x in sx...sx + Std.int(xmax) + 1) {
				for (y in sy...sy + Std.int(ymax) + 1) {
					var sq = Game.me.getSquare(x, y);
					if (sq == null) continue;
					if (fill) {
						for (di in 0...4) setWall(sq, di, 1);
					} else {
						var dirs = [0, 1, 2, 3];
						if (x == sx + xmax) dirs.remove(0);
						if (y == sy + ymax) dirs.remove(1);
						if (x == sx) dirs.remove(2);
						if (y == sy) dirs.remove(3);
						for (di in dirs) setWall(sq, di, 0);
					}
				}
			}
			majAll();
			rectangleStart = null;
			saveLevel();
		}
		rectangleCursor.visible = rectangleStart != null;
	}

	// ENTS
	function toggleHero() {
		if (!isFree()) {
			delete();
			return;
		}
		Game.me.hero.setSquare(square.x, square.y);
		saveLevel();
	}

	function toggleMonster(id) {
		if (!isFree()) {
			delete();
			return;
		}
		var b = Game.me.spawnBad(id);
		b.setSquare(square.x, square.y);
		saveLevel();
	}

	function delete() {
		for (e in Game.me.ents.copy())
			if (e.square == square && e != Game.me.hero)
				e.kill();
		saveLevel();
	}

	function isFree() {
		if (square.isBlock()) return false;
		for (e in Game.me.ents) if (e.square == square) return false;
		return true;
	}

	// SCROLL (navigation entre niveaux ; Shift = décale tout le contenu)
	function scroll(di) {
		if (api.AKApi.isDown(K_SHIFT)) {
			moveAll(di);
			return;
		}
		var lim = Cs.EDITOR_MAX;
		var cur = data._cursor + [1, 1, -1, -1][di];
		if (cur < 0) cur += lim;
		if (cur >= lim) cur -= lim;

		// Franchir la frontière petit/grand (niveau 20<->21) change la taille de
		// grille : on sauve puis on reconstruit le jeu à la bonne taille (l'éditeur
		// rouvre le niveau cible depuis le store). Sinon navigation en mémoire.
		var sameBand = Cs.isBigLevel(cur + 1) == Cs.isBigLevel(data._cursor + 1);
		data._cursor = cur;
		if (!sameBand) {
			saveData();
			Boot.me.setSizeAndRebuild(Cs.isBigLevel(cur + 1));
			return;
		}
		loadLevel();
		saveData(); // persiste le curseur (pour rouvrir au bon niveau après un essai)
	}

	function moveAll(di) {
		var dat = data._list[data._cursor];
		var all = dat._squares;
		var max = Cs.XMAX * Cs.YMAX;

		var moveEnts = function(inc) {
			for (id in 0...dat._bads.length >> 1) {
				var sid = dat._bads[id * 2 + 1];
				sid = Std.int(Num.sMod(sid + inc, max));
				dat._bads[id * 2 + 1] = sid;
			}
			dat._start = Std.int(Num.sMod(dat._start + inc, max));
		}
		var prev = function() {
			all.unshift(all.pop());
			moveEnts(1);
		}
		var next = function() {
			all.push(all.shift());
			moveEnts(-1);
		}

		switch (di) {
			case 0: for (i in 0...Cs.YMAX) prev();
			case 1: prev();
			case 2: for (i in 0...Cs.YMAX) next();
			case 3: next();
		}
		loadLevel();
	}

	function majAll() {
		for (sq in Game.me.squares) sq.majGfx();
	}

	// DATA (localStorage)
	function loadStore():DataProgression {
		try {
			var s = js.Browser.window.localStorage.getItem(Cs.EDITOR_STORE);
			if (s == null || s == "") return null;
			return haxe.Unserializer.run(s);
		} catch (e:Dynamic) {
			return null;
		}
	}

	function saveData() {
		try {
			js.Browser.window.localStorage.setItem(Cs.EDITOR_STORE, haxe.Serializer.run(data));
		} catch (e:Dynamic) {}
		pushInfo();
	}

	function reset() {
		data = haxe.Unserializer.run(Cs.levels);
		if (data._cursor == null) data._cursor = 0;
		loadLevel();
		saveData();
	}

	// LEVEL
	function resetLevel() {
		var dat:DataLevel = {_squares: [], _bads: [], _doors: [], _start: (Cs.XMAX * Cs.YMAX) >> 1};
		for (i in 0...Cs.XMAX * Cs.YMAX) dat._squares.push(0);
		data._list[data._cursor] = dat;
	}

	function loadLevel() {
		// Garde AKApi.level synchronisé sur le niveau édité : la taille de grille
		// utilisée à l'essai (playtest) et au retour (endPlaytest) en dépend.
		api.AKApi.setLevel(data._cursor + 1);

		// Annule un rectangle en cours : son ancre vaut pour le niveau qu'on quitte.
		rectangleStart = null;
		rectangleCursor.visible = false;

		if (data._list[data._cursor] == null) resetLevel();
		// Niveau enregistré à une AUTRE taille de grille (données héritées d'une
		// dimension précédente) -> on le réinitialise à la taille courante plutôt
		// que de déborder du tableau squares (écran noir).
		if (data._list[data._cursor]._squares.length != Cs.XMAX * Cs.YMAX) resetLevel();
		var o = data._list[data._cursor];

		clean();

		// SQUARES
		var id = 0;
		for (n in o._squares) {
			var sq = Game.me.squares[id];
			if (sq == null) break;
			for (di in 0...4) {
				var base = Std.int(Math.pow(2, di));
				if (sq.dnei[di] == null) continue;
				sq.setWall(di, (n % (base * 2) >= base) ? 0 : 1);
			}
			id++;
		}
		majAll();

		// DOORS
		if (o._doors != null) {
			for (id in o._doors)
				if (Game.me.squares[id] != null) new Door(Game.me.squares[id]);
		} else {
			o._doors = [];
		}

		// BADS
		for (i in 0...(o._bads.length >> 1)) {
			if (Game.me.squares[o._bads[i * 2 + 1]] == null) continue;
			var b = Game.me.spawnBad(o._bads[i * 2]);
			b.gotoSquareId(o._bads[i * 2 + 1]);
		}

		// HERO
		Game.me.hero.gotoSquareId(o._start);

		pushInfo();
	}

	function saveLevel() {
		var o = data._list[data._cursor];

		// SQUARES
		var id = 0;
		o._doors = [];
		for (sq in Game.me.squares) {
			o._squares[id] = sq.getWallId();
			if (sq.door != null && sq.doorDir == 0) o._doors.push(sq.getId());
			id++;
		}

		// BADS
		o._bads = [];
		for (b in Game.me.bads) {
			o._bads.push(b.bid);
			o._bads.push(b.square.getId());
		}

		// HERO
		o._start = Game.me.hero.square.getId();

		saveData();
	}

	// --- Ponts vers la page HTML (exposés via Boot) ---

	// Donnée sérialisée (pour export / copie presse-papiers côté page).
	public function exportString():String {
		return haxe.Serializer.run(data);
	}

	// Importe une chaîne sérialisée (collée par l'utilisateur).
	public function importString(s:String):Bool {
		try {
			var d:DataProgression = haxe.Unserializer.run(s);
			if (d._cursor == null) d._cursor = 0;
			data = d;
			loadLevel();
			saveData();
			return true;
		} catch (e:Dynamic) {
			return false;
		}
	}

	// Donnée sérialisée du SEUL niveau courant (export unitaire).
	public function exportLevelString():String {
		saveLevel(); // capture l'état affiché à l'écran
		return haxe.Serializer.run(data._list[data._cursor]);
	}

	// Importe UN seul niveau. Convention : un niveau unitaire est à la taille MAX
	// (grande grille 26×20) -> on refuse toute autre taille (sinon le garde de
	// loadLevel le réinitialiserait). Cible : le niveau courant s'il est déjà grand,
	// sinon le 1er grand (21), avec reconstruction à la grande grille.
	public function importLevelString(s:String):Bool {
		var dl:DataLevel;
		try {
			dl = haxe.Unserializer.run(s);
		} catch (e:Dynamic) {
			return false;
		}
		if (dl == null || dl._squares == null) return false;
		if (dl._squares.length != Cs.BIG_XMAX * Cs.BIG_YMAX) return false;
		if (dl._bads == null) dl._bads = [];
		if (dl._doors == null) dl._doors = [];
		if (dl._start == null) dl._start = (Cs.BIG_XMAX * Cs.BIG_YMAX) >> 1;

		var onBig = Cs.isBigLevel(data._cursor + 1);
		var target = onBig ? data._cursor : (Cs.BIG_FROM - 1);
		data._list[target] = dl;
		data._cursor = target;

		if (onBig) {
			loadLevel();
			saveData();
		} else {
			// Bascule en grande grille : on persiste puis on reconstruit ; le nouvel
			// éditeur rouvre au curseur (niveau 21) avec le niveau importé.
			saveData();
			Boot.me.setSizeAndRebuild(true);
		}
		return true;
	}

	// Vide le niveau courant (tout en murs) puis sauvegarde.
	public function clearLevel():Void {
		resetLevel();
		loadLevel();
		saveLevel();
	}

	// Navigation niveau (appelée par les boutons de la page).
	public function gotoLevel(di:Int):Void {
		scroll(di);
	}

	public function resetToCampaign():Void {
		reset();
	}

	function pushInfo():Void {
		var modified = (Cs.levels != haxe.Serializer.run(data));
		if (Boot.me != null) Boot.me.editorInfo(data._cursor + 1, data._list.length, modified);
	}

	// Quitte l'éditeur (reprend le jeu normal).
	public function leave() {
		kill();
		if (root.parent != null) root.parent.removeChild(root);
		Game.me.stepFx = null;
		Game.me.fillCoins();
		for (b in Game.me.bads) b.seekDir();
	}

	// Bouton « Tester » : joue la configuration en cours sur la grille éditée.
	// On passe en sémantique campagne (PROGRESSION) pour que « toutes les pièces »
	// = victoire (gameOver) et non un simple replacement ; la page écoute nc-finished
	// et appelle Boot.endPlaytest() pour revenir à l'édition.
	public function playtest() {
		api.AKApi.setMode(true, api.AKApi.getLevel());
		leave();
		Game.me.gstep = 0;
		Game.me.hero.majHeroDist();
	}
}
