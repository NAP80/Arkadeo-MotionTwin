import mt.bumdum9.Lib;
import Protocol;
import api.AKApi;
import api.AKProtocol;

// Coeur du jeu : grille, génération du labyrinthe, boucle update, score.
// Les constantes DP_* remplacent la macro @:build(IntInliner) de l'original.
class Game extends SP {
	public static inline var DP_BG = 0;
	public static inline var DP_LEVEL = 1;
	public static inline var DP_INTER = 2;
	public static inline var DP_FILTER = 3;

	public var gstep:Int;
	public var gtimer:Int;
	public var bg:SP;
	public var dif:Int;
	public var coins:Int;
	public var coinMax:Int;
	public var seed:mt.Rand;
	public var squares:Array<Square>;
	public var ents:Array<Ent>;
	public var bads:Array<ent.Bad>;
	public var hero:ent.Hero;
	public var inter:Inter;
	public var level:Level;
	public var dm:mt.DepthManager;
	public var fxm:mt.fx.Manager;
	public var stepFx:mt.fx.Fx; // Transition qui met le jeu en pause (flip de porte)
	public var plasma:Plasma; // Trace multicolore additive (traînées du Skull)
	public var bonus:Null<BonusKind>;
	public var bonusLife:Int;

	public static var me:Game;

	public function new() {
		super();
		me = this;
		dm = new mt.DepthManager(this);
		fxm = new mt.fx.Manager();
		mt.fx.Fx.DEFAULT_MANAGER = fxm;
		gtimer = 0;
		seed = new mt.Rand(AKApi.getSeed() + AKApi.getLevel());
		gstep = -1;
		dif = 0;

		Cs.initGfx();

		bg = new SP();
		dm.add(bg, DP_BG);
		bg.graphics.beginFill(0);
		bg.graphics.drawRect(0, 0, Cs.WIDTH, Cs.HEIGHT);
		bg.graphics.endFill();

		// HUD (contrat minimal ; le score est affiché par le host).
		inter = new Inter();

		// GAME MODE
		switch (AKApi.getGameMode()) {
			case GM_PROGRESSION:
			case GM_LEAGUE:
			default:
		}

		if (AKApi.isEditor()) {
			// Mode ÉDITEUR : on construit le niveau directement (sans animation d'entrée) puis on lance l'éditeur,
			// qui prend la main (stepFx) et met le jeu en pause. Cf. seq.Editor.
			initLevel();
			gstep = 0;
			new seq.Editor();
		} else {
			// SpeedRun : 3-2-1-Go au lancement du run (seq.Init crée le niveau, puis compte à rebours).
			if (AKApi.isSpeedrun()) srWantCountdown = true;
			// seq.Init crée le niveau (initLevel) PUIS l'anime en entrée (scroll depuis la droite) ; il met gstep = 0 à la fin.
			// gstep reste -1 d'ici là (le jeu ne tourne pas tant que l'animation d'entrée n'est pas finie).
			new seq.Init();
		}
	}

	// SpeedRun : seq.Init.end lancera un compte à rebours (départ du run / respawn après mort)
	// au lieu de passer directement en jeu (gstep 0).
	public var srWantCountdown:Bool = false;

	public function initLevel() {
		ents = [];
		bads = [];
		coins = 0;
		// LEVEL
		level = new Level();
		dm.add(level, DP_LEVEL);
		// GRID
		initGrid();
		// HERO
		hero = new ent.Hero();
		// DATA : niveau DESSINÉ (LvUP), GÉNÉRÉ au-delà (LvUP), ou GÉNÉRÉ (League).
		var generatedLevel = false;
		switch (AKApi.getGameMode()) {
			case GM_PROGRESSION:
				// Campagne = niveaux édités (localStorage) si présents, sinon bakés.
				var data:DataProgression = haxe.Unserializer.run(Cs.campaignData());
				var idx = AKApi.getLevel() - 1;
				var dl = (idx >= 0 && idx < data._list.length) ? data._list[idx] : null;
				// Niveau dessiné valide POUR LA TAILLE COURANTE (longueur = grille) sinon généré.
				if (dl != null && dl._squares != null && dl._squares.length == Cs.XMAX * Cs.YMAX) {
					loadLevel(dl); // niveau dessiné à la main
				} else {
					generatedLevel = true; // niveau non dessiné -> généré (à la taille courante)
					generate();
					var sq = getFreeRandomSquare();
					if (sq == null) throw("argh");
					hero.setSquare(sq.x, sq.y);
				}
			case GM_LEAGUE:
				generate();
				var sq = getFreeRandomSquare();
				if (sq == null) throw("argh");
				hero.setSquare(sq.x, sq.y);
			default:
		}
		hero.majHeroDist();
		// COINS (fillCoins dessine aussi toutes les tuiles via sq.initGfx)
		fillCoins();
		// PLASMA (trace "multicolore" des traînées du Skull, par-dessus le sol).
		plasma = new Plasma();
		Level.me.dm.add(plasma.gfx, Level.DP_PLASMA);
		// MONSTRES selon le mode
		switch (AKApi.getGameMode()) {
			case GM_PROGRESSION:
				// Niveaux générés : on amorce quelques monstres (croissant avec le niveau)
				if (generatedLevel) {
					var n = 1 + Std.int(AKApi.getLevel() / 3);
					for (i in 0...n) {
						var b = spawnBad(i % 5);
						b.autoPos();
					}
				}
				// SpeedRun : niveaux dessinés purs (pas de pression seq.TimeUp) -> déterministe.
				if (!AKApi.isSpeedrun()) new seq.TimeUp(); // Pression : spawn progressif de Hunters
			case GM_LEAGUE:
				for (id in Cs.MONSTERS_INIT) {
					var b = spawnBad(id);
					b.autoPos();
				}
				new seq.BadFlow();
			default:
		}
		for (b in bads)
			b.seekDir();
		// BONUS : apparition périodique (chaussures / étoile). Pas en SpeedRun (déterministe
		// + évite une séquence persistante qui s'accumulerait entre niveaux enchaînés).
		if (!AKApi.isSpeedrun()) new seq.BonusPop();
	}

	// Charge un niveau dessiné (LvUP) : murs (bitmask par case), portes, monstres (paires [type, squareId]), départ du héros.
	public function loadLevel(data:DataLevel) {
		var id = 0;
		for (n in data._squares) {
			var sq = squares[id];
			if (sq == null) break;
			for (di in 0...4) {
				var base = Std.int(Math.pow(2, di));
				if (sq.dnei[di] == null) continue;
				sq.setWall(di, (n % (base * 2) >= base) ? 0 : 1);
			}
			id++;
		}
		for (id in data._doors)
			if (squares[id] != null) new Door(squares[id]);
		for (i in 0...(data._bads.length >> 1)) {
			if (squares[data._bads[i * 2 + 1]] == null) continue;
			var b = spawnBad(data._bads[i * 2]);
			b.gotoSquareId(data._bads[i * 2 + 1]);
		}
		hero.gotoSquareId(data._start);
	}

	public function spawnBad(id:Int):ent.Bad {
		switch (id) {
			case 0: return new bad.Classic();
			case 1: return new bad.Skull();
			case 2: return new bad.Block();
			case 3: return new bad.Jumper();
			default: return new bad.Hunter();
		}
	}

	public function fillCoins() {
		coins = 0;
		var addCoin = true;
		for (sq in Game.me.squares) {
			if (addCoin && !sq.isBlock() && hero.square != sq) {
				sq.addCoin();
				addCoin = !Cs.FORCE_ONE_COIN;
			}
			sq.initGfx();
		}
		coinMax = coins;
	}

	// UPDATE
	public function update(render:Bool) {
		gtimer++;
		if (inter != null) inter.update();

		// Transition (flip de porte) : le jeu est en pause, seul le FX tourne.
		if (stepFx != null) {
			stepFx.update();
			return;
		}

		switch (gstep) {
			case 0:
				// Chrono SpeedRun : on ne compte que le JEU ACTIF (gstep 0). En pause
				// pendant le slide/3-2-1/mort (gstep != 0). srTick gère le drapeau srRunning.
				if (AKApi.isSpeedrun()) Boot.me.srTick();

				for (e in ents.copy())
					e.update();
				if (render)
					EL.updateAnims();

				if (plasma != null) plasma.fade();

				if (gtimer % 10 == 0)
					for (sq in squares)
						if (sq.htrack > 0)
							sq.htrack--;
			default:
		}

		fxm.update();

		// Z-SORT des entités par y (profondeur) au sein du plan DP_ENTS.
		ents.sort(zSort);
		for (e in ents)
			Level.me.dm.over(e.root);
	}

	public function zSort(a:Ent, b:Ent) {
		if (a.y < b.y) return -1;
		if (a.y > b.y) return 1;
		return 0;
	}

	// GRID
	var free:Array<Square>;

	function initGrid() {
		var skinId = 1;
		if (AKApi.getGameMode() == GM_PROGRESSION)
			skinId = AKApi.getLevel() % 4;
		// INIT
		squares = [];
		for (x in 0...Cs.XMAX) {
			for (y in 0...Cs.YMAX) {
				var sq = new Square(x, y);
				sq.skinId = skinId;
				squares.push(sq);
			}
		}
		// NEI
		for (sq in squares) {
			for (d in Cs.DIR) {
				var nx = sq.x + d[0];
				var ny = sq.y + d[1];
				var nsq = getSquare(nx, ny);
				sq.dnei.push(nsq);
				if (nsq != null) sq.nei.push(nsq);
			}
		}
	}

	function generate() {
		free = squares.copy();
		var mx = 4;
		var my = 2;
		for (sq in squares) {
			sq.out = sq.x < mx || sq.x >= Cs.XMAX - mx || sq.y < my || sq.y >= Cs.YMAX - my;
			if (sq.out)
				free.remove(sq);
		}
		// LABY
		while (free.length > 0)
			snakeIt();
		// OPEN 3-WALL SQUARES
		for (sq in squares) {
			if (sq.out) continue;
			var op = [];
			for (di in 0...4)
				if (sq.getWall(di) == 0)
					op.push(di);

			if (op.length == 1) {
				var di = (op[0] + 2) % 4;
				var nsq = sq.dnei[di];
				if (nsq != null && !nsq.out) {
					sq.open(di);
				} else {
					buildDistFrom(sq);
					var best = 0;
					var wdi = -1;
					for (i in 0...2) {
						di = (di + [1, 2][i]) % 4;
						var nsq = sq.dnei[di];
						if (nsq != null && !nsq.out && nsq.hdist > best) {
							wdi = di;
							best = nsq.hdist;
						}
					}
					if (best > 0) {
						sq.open(wdi);
					} else {
						sq.mark(0xFF0000);
					}
				}
			}
		}

		// OPEN FAR SQUARES
		for (sq in squares) {
			if (sq.out) continue;
			buildDistFrom(sq);
			var best = 0;
			var wdi = -1;
			for (di in 0...4) {
				var nsq = sq.dnei[di];
				if (nsq != null && !nsq.out && nsq.hdist > best) {
					wdi = di;
					best = nsq.hdist;
				}
			}
			if (best > 10) sq.open(wdi);
		}

		// DOORS
		for (i in 0...2) new Door();
	}

	function snakeIt() {
		var color = Std.random(0xFFFFFF);
		Arr.shuffle(free, seed);
		var start = free[rnd(free.length)];
		for (sq in free) {
			var ok = false;
			for (di in 0...4) {
				var nei = sq.dnei[di];
				if (nei != null && nei.tag == 1 && !nei.out) {
					start = sq;
					start.open(di);
					ok = true;
					break;
				}
			}
			if (ok) break;
		}
		var cur = start;
		var max = 48;
		var n = 0;
		while (n++ < max) {
			cur.color = color;
			cur.tag = 1;
			free.remove(cur);
			var a = [];
			for (di in 0...4) {
				var nsq = cur.dnei[di];
				if (nsq == null || nsq.tag == 1 || nsq.out) continue;
				a.push(di);
			}
			if (a.length == 0) break;
			var di = a[rnd(a.length)];
			cur.open(di);
			cur = cur.dnei[di];
		}
	}

	// GRID - DIST
	public function buildDistFrom(square:Square, passDoor = false) {
		for (sq in Game.me.squares)
			sq.hdist = 999;
		square.hdist = 0;
		var work = [square];
		while (work.length > 0)
			work = expand(work, passDoor);
	}

	function expand(work:Array<Square>, passDoor = false) {
		var a = [];
		for (sq in work) {
			var hdist = sq.hdist + 1;
			for (di in 0...4) {
				var nsq = sq.dnei[di];
				var wall = sq.getWall(di) > 0;
				if (passDoor && sq.getWall(di) == 2) wall = false;
				if (nsq == null || nsq.hdist <= hdist || wall) continue;
				nsq.hdist = hdist;
				a.push(nsq);
			}
		}
		return a;
	}

	// RANDOM
	public function rnd(n) {
		return seed.random(n);
	}

	// Combo de kills à l'étoile (réinitialisé à chaque casquette ramassée).
	public var starCombo:Int = 0;

	// Score + petit score flottant.
	public function addScore(n, ?x, ?y) {
		if (AKApi.getGameMode() != GM_LEAGUE) return;
		AKApi.addScore(api.AKApi.const(n));

		if (x != null && Level.me != null) {
			// Teinte vert->rouge selon la valeur, appliquée sur les chiffres (EL), pas sur le conteneur.
			var sb = Cs.SCORE_BALL.get();
			var sm = Cs.SCORE_BALL_MAX.get();
			var c = (n - sb) / (sm - sb);
			if (c < 0) c = 0;
			if (c > 1) c = 1;
			var tint = mt.bumdum9.Lib.Col.hsl2Rgb(c * 0.8 + 0.1, 1.0, 0.6);

			var mc = new mt.bumdum9.Lib.Sp();
			// Contour noir 1px : garde le score max (magenta) lisible sur fond clair.
			for (off in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
				var o = Cs.getTinyScore(n);
				for (d in o.children) untyped d.tint = 0x000000;
				o.x = off[0];
				o.y = off[1];
				mc.addChild(o);
			}
			var fg = Cs.getTinyScore(n);
			for (d in fg.children) untyped d.tint = tint;
			mc.addChild(fg);

			Level.me.dm.add(mc, Level.DP_SCORE);
			var p = new mt.fx.Part(mc);
			p.vy = -5;
			p.frict = 0.75;
			p.timer = 50;
			p.fadeLimit = 5;
			p.fadeType = 2;
			p.fitPix = true;
			p.setPos(x, y);
			p.setScale(0.5);
		}
	}

	// Bonus de score quand un monstre est tué grâce à la casquette (BK_Star).
	// Combo façon Pac-Man : 100 -> 200 -> 400 -> 800 (plafonné), remis à 0 à chaque nouvelle casquette ramassée (cf. ent.Hero.applyBonus).
	public function addStarKill(x:Float, y:Float) {
		var step = (starCombo < 3) ? starCombo : 3;
		var n = 100 * (1 << step);
		addScore(n, x, y);
		starCombo++;
	}

	public function onLastCoin() {
		if (AKApi.isSpeedrun()) {
			// SpeedRun : niveau réussi -> on fige et on planifie l'avance (slide vers le
			// niveau suivant, ou fin du run au niveau 20). DIFFÉRÉ (Boot.srScheduleAdvance,
			// setTimeout 0) : on est dans la boucle d'ents de update(), reconstruire le
			// niveau ici détruirait des objets en cours d'itération.
			gstep = 1;
			Boot.me.srScheduleAdvance();
			return;
		}
		switch (AKApi.getGameMode()) {
			case GM_PROGRESSION:
				// LvUP : niveau réussi -> seq.Win (explose les monstres puis AKApi.gameOver(true) -> passage au niveau suivant côté host).
				new seq.Win();
			case GM_LEAGUE:
				// League : on replace les pièces (seq.SpitCoins) sans réinitialiser le niveau.
				new seq.SpitCoins();
			default:
		}
	}

	// SpeedRun : (re)construit le niveau courant via le slide d'entrée (seq.Init), suivi
	// d'un 3-2-1-Go. Appelé en DIFFÉRÉ par Boot (hors de la boucle update()). `fxm.clean()`
	// tue d'abord les FX en vol (root encore valide) : sinon un Part survivrait à la
	// destruction de l'ancien Level (que seq.Init détruit en fin de slide) -> crash.
	public function srRebuildLevel() {
		gstep = -1;
		fxm.clean();
		srWantCountdown = true;
		new seq.Init();
	}

	// DEV : donne la casquette d'invincibilité.
	public function devCap() {
		if (inter != null) inter.setBonus(BonusKind.BK_Star);
	}

	// DEV : fait apparaître un monstre du type donné.
	public function devSpawn(id:Int) {
		var b = spawnBad(id);
		b.autoPos();
		b.seekDir();
	}

	// DEV : supprime tous les monstres de la partie en cours.
	public function devKillBads() {
		for (b in bads.copy())
			b.kill();
	}

	// TOOLS
	public function getSquare(x, y) {
		if (!isIn(x, y)) return null;
		return squares[x * Cs.YMAX + y];
	}

	public function isIn(x, y) {
		return x >= 0 && x < Cs.XMAX && y >= 0 && y < Cs.YMAX;
	}

	public function getFreeSquares() {
		var a = [];
		for (sq in squares)
			if (!sq.isBlock() && !sq.out)
				a.push(sq);
		return a;
	}

	public function getFreeRandomSquare(distMin = -1) {
		var a = getFreeSquares();
		if (distMin > 0)
			for (sq in a.copy())
				if (sq.hdist < distMin)
					a.remove(sq);
		return a[rnd(a.length)];
	}
}
