// New Rock Faller - Game (rejeu PixiJS de Rock Faller, mode League).
//
// Boucle interactive : sélection 2×2 à la souris, rotation horaire (1 coup),
// combos (groupes ≥4 même couleur), tubes qui aspirent les rochers, chute +
// refill, fin de partie League à 0 coup. Les animations utilisent un petit
// système de tweens inline (tweenTo / vanishFx).
import common_haxe_avm1.display.ASprite;
import common_haxe_avm1.MouseManager;
import pixi.core.sprites.Sprite;
import pixi.core.text.Text;
import pixi.core.Pixi.BlendModes;

// Groupe de pierres connectées de même couleur (getGroups / flood-fill).
typedef CGroup = {
	var id:Int;
	var l:Array<Slot>;
}

// Étapes de la boucle (enum Step du jeu d'origine).
enum Step {
	S_Play;
	S_Rot;
	S_Grab;
	S_Fall(grabAgain:Bool);
	S_Game_Over;
}

class Game {
	// Taille NATIVE du stage Rock Faller (gfx.swf : 600×480).
	public static inline var WIDTH = 600;
	public static inline var HEIGHT = 480;

	// Géométrie (valeurs du jeu d'origine).
	public static inline var STAGE_SIZE = 6; // grille 6×6
	public static inline var STAGE_X = 120;
	public static inline var STAGE_Y = 50; // descendu (35→50) : tuyaux plus bas (moins d'espace vide)
	public static inline var COMBO_COUNT = 4;
	public static inline var COMBO_MULT = 0.8;
	public static inline var EXIT_DIST = 60;
	public static inline var SHINE_WAIT = 10.0; // délai moyen entre brillances (par couleur)
	// Placement du fond (réglé visu) : scale uniforme « cover » + décalage pour
	// centrer la zone de jeu (teal) sur la grille (centre x=300).
	public static inline var BG_SCALE = 1.023;
	public static inline var BG_OFFX = -64;
	public static inline var BG_OFFY = 0;

	public static var DIRS = [[1, 0], [0, 1], [-1, 0], [0, -1]];
	public static var SEL_DIRS = [[0, 0], [1, 0], [1, 1], [0, 1]];
	public static var EXIT_STARTS = [[0, 1, 4, 5], [0, 2, 3, 5]];
	// League : 10 coups au départ (PLAY_COUNT[0][0]).
	public static inline var PLAY_COUNT_LEAGUE = 10;
	// LvUP (PROGRESSION) : coups de départ + objectif de score par niveau 1..30
	// (jeu d'origine : PLAY_COUNT[1] / PROGRESSION_SCORES).
	public static var PLAY_COUNT_LVUP = [0, 13, 13, 13, 13, 13, 12, 12, 12, 12, 12, 11, 11, 11, 11, 11, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10];
	public static var PROGRESSION_SCORES = [0, 5000, 8000, 9500, 11000, 12500, 14000, 15500, 17000, 18500, 20000, 21500, 23000, 24500, 26000, 27500, 29000, 30500, 32000, 33500, 35000, 36500, 38000, 39500, 40500, 42000, 43500, 45000, 46500, 48000, 50000];
	public static inline var LVUP_MAX_LEVEL = 30;

	public static var me:Game;

	var root:ASprite;
	var seed:mt.Rand;

	// Calques (z-order), du fond vers l'avant.
	public var layerBg:ASprite;
	public var layerGlow:ASprite; // halos de sélection (sous TOUTES les pierres)
	public var layerStones:ASprite;
	public var layerExits:ASprite;
	public var layerInter:ASprite;
	public var layerScore:ASprite;
	public var layerFx:ASprite;
	public var layerFgGems:ASprite; // gemmes déco du fond, DERRIÈRE fg.png (lèvres rocheuses)
	public var layerFg:ASprite;

	public var grid:Array<Array<Slot>>;
	public var allSlots:Array<Slot>;
	public var exits:Array<Exit>;

	public var leftPlay:Int;
	var mcPlays:Array<ASprite>;
	var playWithoutGrab:Int = 0;
	public var objective:Int = 0; // LvUP : score à atteindre (0 = League, pas d'objectif)

	// État de la boucle.
	public var step:Step;
	public var selected:Array<Slot>;
	public var falls:Array<Slot>;
	public var waitingFx:Int = 0;
	var comboCount:Int = 0;
	var toRefill:Array<Int>;
	var curSelX:Int = -1;
	var curSelY:Int = -1;
	var nextMudPart:Int = 0;
	var fallSndCd:Int = 0; // throttle du son de chute (évite 30 sons simultanés)
	var shines:Array<{id:Int, wait:Float}>; // planning des brillances (une entrée/couleur)

	// Tweens/anim inline (closures renvoyant true quand terminées).
	var fxList:Array<Void->Bool>;

	public function new(root:ASprite) {
		me = this;
		this.root = root;
		seed = new mt.Rand(1 + Std.random(0x7FFFFE));
		allSlots = [];
		exits = [];
		selected = [];
		falls = [];
		toRefill = [];
		fxList = [];

		// --- Calques ---
		layerBg = new ASprite();
		layerGlow = new ASprite();
		layerStones = new ASprite();
		layerExits = new ASprite();
		layerInter = new ASprite();
		layerScore = new ASprite();
		layerFx = new ASprite();
		layerFgGems = new ASprite();
		layerFg = new ASprite();
		// layerGlow est SOUS layerStones → les halos restent derrière toutes les pierres
		// (sinon le halo d'une pierre voisine recouvre la gemme adjacente du carré 2×2).
		// layerFgGems est SOUS layerFg : les gemmes déco passent DERRIÈRE le foreground,
		// dont les « lèvres » rocheuses (shape gfx 44) recouvrent le bas de chaque gemme
		// → gemmes PARTIELLES (incrustées dans la roche), comme l'original.
		for (l in [layerBg, layerGlow, layerStones, layerExits, layerInter, layerScore, layerFx, layerFgGems, layerFg])
			root.addChild(l);

		// --- Fond (gfx.Background) : largeur NATIVE décalée pour aligner la zone de
		// jeu (teal) sur la grille (mesure : teal centre x≈356 → on vise 300), hauteur
		// étirée pour remplir le stage. (BG_OFFX réglé visuellement.)
		var bgTex = untyped js.Syntax.code("PIXI.Loader.shared.resources['rf-bg'].texture");
		if (bgTex != null) {
			var bg = new Sprite(bgTex);
			bg.scale.set(BG_SCALE, BG_SCALE); // cover uniforme : remplit sans déformer
			bg.x = BG_OFFX;
			bg.y = BG_OFFY;
			layerBg.addChild(bg);
		}

		initStage();
		initInter();

		// --- Avant-plan (gfx.Foreground) PAR-DESSUS le plateau ---
		var fgTex = untyped js.Syntax.code("PIXI.Loader.shared.resources['rf-fg'].texture");
		if (fgTex != null) {
			var fg = new Sprite(fgTex);
			fg.x = 0;
			fg.y = 0;
			fg.width = WIDTH;   // recadré sur son contenu → remplit le stage, plus de décalage
			fg.height = HEIGHT;
			layerFg.addChild(fg);
		}

		// Gemmes déco du fond (_g0.._g4) : COULEUR ALÉATOIRE par partie. Le foreground
		// est fourni SANS ces gemmes ; on repose ici une gemme
		// avec l'asset d'origine = anim "Deco" (= symbole gfx.Stone biseauté/incrusté,
		// sans le coffret _pk), PAS le cristal net du plateau. Transform SWF exact
		// (meta.fgGems : x/y/scale/rot des matrices de gfx.Foreground) + gotoAndStop
		// (rand(4)+1) pour la couleur, comme l'original (`_gN.gotoAndStop(rand(4)+1)`).
		var fgGems:Array<Dynamic> = untyped js.Syntax.code("(PIXI.Loader.shared.resources['rockfaller'].spritesheet.data.meta.fgGems || [])");
		if (fgGems != null) {
			for (gm in fgGems) {
				var gem = new ASprite("Deco");
				gem.gotoAndStop(rand(Stone.getMaxId()) + 1); // couleur aléatoire (frames 1-4)
				var sc:Float = gm.scale;
				gem._xscale = gem._yscale = sc * 100;
				gem._rotation = gm.rot;
				gem._x = gm.x;
				gem._y = gm.y;
				layerFgGems.addChild(gem); // DERRIÈRE fg.png → lèvres rocheuses par-dessus
			}
			// Masque (gfx shape 20) : clippe le calque des gemmes aux « fenêtres » de la
			// roche → gemmes PARTIELLES (seul le dessus dépasse), comme l'original. Le
			// fg_mask.png est aligné par pack (même transfo que les positions des gemmes).
			var maskTex = untyped js.Syntax.code("(PIXI.Loader.shared.resources['rf-fgmask'] ? PIXI.Loader.shared.resources['rf-fgmask'].texture : null)");
			if (maskTex != null) {
				var maskSp = new Sprite(maskTex);
				maskSp.x = 0;
				maskSp.y = 0;
				layerFgGems.addChild(maskSp);
				untyped layerFgGems.mask = maskSp;
			}
		}

		step = S_Play;
		nextMudPart = 80 + rand(80);
	}

	public function rand(n:Int):Int {
		return seed.random(n);
	}

	// ------------------------------------------------------------------
	// Construction du plateau
	// ------------------------------------------------------------------
	function initStage():Void {
		allSlots = [];
		exits = [];
		grid = [];
		var toCheck:Array<Slot> = [];
		for (x in 0...STAGE_SIZE) {
			grid[x] = [];
			for (y in 0...STAGE_SIZE) {
				grid[x][y] = new Slot(x, y);
				toCheck.push(grid[x][y]);
			}
		}

		// Tubes (exits) sur la rangée du bas, aux colonnes tirées.
		for (i in EXIT_STARTS[rand(EXIT_STARTS.length)]) {
			var e = new Exit();
			grid[i][STAGE_SIZE - 1].setExit(e);
			exits.push(e);
		}

		// Insère des rochers noirs puis supprime les combos automatiques.
		insertStones(toCheck, 3);
		killAutoCombo(toCheck);

		// Planning des brillances : une entrée par couleur, délai initial aléatoire.
		shines = [];
		for (i in 0...Stone.getMaxId())
			shines.push({id: i, wait: SHINE_WAIT + (Std.random(2) * 2 - 1) * SHINE_WAIT / 2});
	}

	function initInter():Void {
		if (Boot.me.mode == "lvup") {
			var lv = Boot.me.level;
			if (lv < 1) lv = 1;
			if (lv > LVUP_MAX_LEVEL) lv = LVUP_MAX_LEVEL;
			leftPlay = PLAY_COUNT_LVUP[lv];
			objective = PROGRESSION_SCORES[lv];
		} else {
			leftPlay = PLAY_COUNT_LEAGUE;
			objective = 0;
		}
		mcPlays = [];
		for (i in 0...leftPlay) {
			var p = new ASprite("Play");
			layerInter.addChild(p);
			p.gotoAndStop(1);
			p._x = 25;
			p._y = 20 + i * 30;
			mcPlays.push(p);
		}
	}

	// ------------------------------------------------------------------
	// Boucle de jeu (machine à états)
	// ------------------------------------------------------------------
	public function update(dt:Float):Void {
		updateFx();

		// Clic / TAP (front montant suivi par Boot) → rotation. Sur mobile il n'y a pas
		// de survol préalable : on cale d'abord la sélection sous le pointeur (le doigt)
		// pour faire tourner LE carré 2×2 touché. Sur desktop, le survol a déjà fixé la
		// sélection → updateSelection est un no-op (position inchangée).
		if (Boot.me.clickPending) {
			if (Type.enumEq(step, S_Play))
				updateSelection(false);
			emitRotation();
		}

		// Lissage sélection (échelle) + chute en cours (copie : fall() retire de `falls`).
		for (s in allSlots)
			s.update();
		for (s in falls.copy())
			s.fall();

		// Particules de boue ambiantes (gfx.MudPart) - cf. addMudParts d'origine.
		nextMudPart--;
		if (nextMudPart < 0)
			addMudParts();

		if (fallSndCd > 0)
			fallSndCd--;

		switch (step) {
			case S_Play:
				updateShine();
				updateSelection(false);

			case S_Rot:
				updateShine();
				if (waitingFx > 0)
					return;
				waitingFx = 0;
				rotationDone();
				var combos = getCombos();
				if (combos.toGrab.length > 0)
					playWithoutGrab = 0;
				else
					playWithoutGrab++;
				if (!combos.has)
					setStep(S_Play);
				else {
					startGrab(combos.toDestroy, combos.toGrab);
					setStep(S_Grab);
				}

			case S_Grab:
				if (waitingFx > 0)
					return;
				waitingFx = 0;
				startFall();
				var combos = getCombos();
				if (!combos.has) {
					startRefill();
					setStep(S_Fall(false));
				} else
					setStep(S_Fall(true));

			case S_Fall(grabAgain):
				if (falls.length > 0)
					return;
				if (grabAgain) {
					var combos = getCombos();
					comboCount++;
					startGrab(combos.toDestroy, combos.toGrab);
					setStep(S_Grab);
				} else
					setStep(S_Play);

			case S_Game_Over:
		}
	}

	public function setStep(s:Step):Void {
		switch (s) {
			case S_Play:
				if (leftPlay <= 0) {
					// League : fin = victoire (score pur). LvUP : gagné si objectif atteint.
					var win = (Boot.me.mode == "lvup") ? (Boot.me.score >= objective) : true;
					Boot.me.gameOver(win);
					s = S_Game_Over;
				}
			default:
		}
		step = s;
	}

	// --- Sélection 2×2 sous la souris ---
	function updateSelection(force:Bool):Void {
		var mx = MouseManager.getMouseX();
		var my = MouseManager.getMouseY();
		var px = Std.int((mx - (STAGE_X + Slot.SIZE / 2)) / Slot.SIZE);
		var py = Std.int((my - (STAGE_Y + Slot.SIZE / 2)) / Slot.SIZE);
		if (px < 0 || px > STAGE_SIZE - 2 || py < 0 || py > STAGE_SIZE - 2) {
			px = -1;
			py = -1;
		}
		if (px == curSelX && py == curSelY && !force)
			return;

		unselect();
		curSelX = px;
		curSelY = py;
		if (px < 0)
			return;
		for (i in 0...4) {
			var sl = grid[px + SEL_DIRS[i][0]][py + SEL_DIRS[i][1]];
			sl.select(DIRS[i]);
			selected.push(sl);
		}
		// Étincelles autour du carro 2×2 sélectionné (cf. updateSelection d'origine).
		var p = Slot.getStonePos(px, py);
		var cx = p.x + Slot.SIZE / 2;
		var cy = p.y + Slot.SIZE / 2;
		var pnb = 3 + rand(3);
		for (i in 0...pnb)
			spawnSparkle(cx + (rand(2) * 2 - 1) * (12 + rand(20)), cy + (rand(2) * 2 - 1) * (12 + rand(20)));
		// Survol (rollover) sur 4 blocs : un des 6 sons mouseover.
		snd.Sfx.play("Rocks_mouseover" + (1 + rand(6)));
	}

	function unselect():Void {
		for (s in selected.copy())
			s.unselect();
		selected = [];
		curSelX = -1;
		curSelY = -1;
	}

	// Brillance périodique : UNE SEULE couleur scintille à la fois, en alternance. On
	// décrémente la couleur en tête de file jusqu'à expiration de son délai, puis on
	// déclenche toutes ses pierres (vague diagonale via Slot.setShine) et on la renvoie
	// en queue. ⚠ Décrémenter les 4 couleurs en parallèle les ferait scintiller ensemble.
	function updateShine():Void {
		if (shines == null || shines.length == 0)
			return;
		var sh = shines[0]; // tête : redécrémentée tant qu'elle n'a pas expiré
		sh.wait -= 0.1;
		if (sh.wait > 0.0)
			return;
		for (sl in allSlots)
			if (sl.stone != null && !sl.stone.isStone() && sl.stone.id == sh.id)
				sl.setShine();
		sh.wait = SHINE_WAIT + (Std.random(2) * 2 - 1) * SHINE_WAIT / 2;
		shines.shift();
		shines.push(sh); // -> queue : la couleur suivante prend la tête
	}

	function emitRotation():Void {
		if (!Type.enumEq(step, S_Play) || selected.length < 4)
			return;
		startRotation();
	}

	function startRotation():Void {
		spendPlay();
		for (i in 0...selected.length)
			selected[i].rotate(i);
		snd.Sfx.play("Rocks_rotate");
		setStep(S_Rot);
	}

	function rotationDone():Void {
		var newOrder = [for (s in selected) s.stone];
		newOrder.unshift(newOrder.pop());
		for (i in 0...selected.length)
			selected[i].setStone(newOrder[i]);
		comboCount = 0;
		updateSelection(true);
	}

	// --- Combos ---
	function getCombos():{has:Bool, toDestroy:Array<CGroup>, toGrab:Array<Exit>} {
		var toDestroy = [];
		for (g in getGroups())
			if (g.l.length >= COMBO_COUNT)
				toDestroy.push(g);
		var toGrab = [];
		for (e in exits)
			if (e.slot != null && e.slot.stone != null && e.slot.stone.isStone())
				toGrab.push(e);
		return {toDestroy: toDestroy, toGrab: toGrab, has: toDestroy.length > 0 || toGrab.length > 0};
	}

	function startGrab(toDestroy:Array<CGroup>, toGrab:Array<Exit>):Void {
		unselect();
		resetRefill();

		// Son de destruction de blocs (cf. startGrab d'origine) : niveau de combo
		// (0/1/2+) × (un seul groupe X4 / plusieurs XX).
		if (toDestroy.length > 0) {
			var lvl = comboCount > 2 ? 3 : comboCount + 1;
			var kind = toDestroy.length == 1 ? "X4L" : "XXL";
			snd.Sfx.play("Blocks_" + kind + lvl);
		}

		for (g in toDestroy) {
			var scorePerStone = Std.int(g.l[0].stone.getPoints() * (1.0 + COMBO_MULT * comboCount) * toDestroy.length);
			addScore(g.l.length * scorePerStone);
			for (s in g.l) {
				prepareScore(s.x, s.y, scorePerStone);
				var pos = Slot.getStonePos(s.x, s.y);
				spawnOnce("Vanish", pos.x, pos.y, false); // éclat de destruction (gfx.Vanish)
				var mc = s.stone.mc;
				waitingFx++;
				vanishFx(mc, 12, function() {
					s.vanishStone();
					waitDone();
				});
				toRefill[s.x]++;
			}
		}

		for (e in toGrab) {
			var s = e.slot;
			var mc = s.stone.mc;
			var nx = mc._x + e.dir[0] * EXIT_DIST;
			var ny = mc._y + e.dir[1] * EXIT_DIST;
			waitingFx++;
			toRefill[s.x]++;
			// waitDone() est appelé par proc() APRÈS switchSlot (et non ici) : la chaîne
			// d'états attend que le tube se soit déplacé, puis re-teste getCombos → un
			// rocher déjà au sol sous la nouvelle case du tube est bien aspiré.
			tweenTo(mc, nx, ny, 8, function() {
				s.removeStone();
				e.proc();
			});
		}
	}

	// --- Chute / refill ---
	function resetRefill():Void {
		toRefill = [];
		for (x in 0...STAGE_SIZE) {
			toRefill[x] = 0;
			for (y in 0...STAGE_SIZE)
				if (grid[x][y].stone == null)
					toRefill[x]++;
		}
	}

	function startFall():Void {
		for (x in 0...toRefill.length) {
			if (toRefill[x] == 0)
				continue;
			var y = STAGE_SIZE - 1;
			var count = 0;
			while (y > 0) {
				if (grid[x][y].stone == null) {
					var sy = y;
					var dy = y - 1;
					while (dy >= 0) {
						if (grid[x][dy].stone != null) {
							grid[x][sy].setStone(grid[x][dy].stone, false);
							grid[x][dy].stone = null;
							grid[x][sy].setFall(count * 2);
							count++;
							sy--;
						}
						dy--;
					}
				}
				y--;
			}
		}
	}

	function startRefill():Void {
		var toCheck:Array<Slot> = [];
		for (x in 0...toRefill.length) {
			if (toRefill[x] == 0)
				continue;
			var delta = rand(20);
			for (i in 0...toRefill[x]) {
				var st = new Stone(true);
				grid[x][i].setStone(st, false);
				toCheck.push(grid[x][i]);
				st.mc._x = Slot.getStonePos(x, i).x;
				st.mc._y = -5 - delta - (toRefill[x] - i) * (Slot.SIZE + 50);
				grid[x][i].setFall();
				grid[x][i].stone.isNew = true;
			}
		}
		insertStones(toCheck);
		killAutoCombo(toCheck);
		// PK (cadeaux) absents en League → rien à poser.
	}

	// --- Score / coups ---
	public function addScore(s:Int):Void {
		Boot.me.addScore(s);
		// LvUP : alimente la barre de progression (score / objectif).
		if (Boot.me.mode == "lvup" && objective > 0)
			Boot.me.setProgress(Boot.me.score / objective);
	}

	function spendPlay():Void {
		if (leftPlay <= 0)
			return;
		leftPlay--;
		if (mcPlays[leftPlay] != null)
			mcPlays[leftPlay].gotoAndStop(2);
	}

	// Bonus : +1 coup (bouton du host). Relance la partie si elle était finie.
	public function bonusPlay():Void {
		addPlay(1);
		if (Type.enumEq(step, S_Game_Over))
			step = S_Play;
	}

	public function addPlay(n:Int):Void {
		for (i in leftPlay...(leftPlay + n)) {
			if (mcPlays[i] == null) {
				var p = new ASprite("Play");
				layerInter.addChild(p);
				p._x = 25;
				p._y = 20 + i * 30;
				mcPlays[i] = p;
			}
			mcPlays[i].gotoAndStop(1);
			mcPlays[i]._visible = true;
		}
		leftPlay += n;
	}

	// Popup "+score" qui monte et s'estompe (non bloquant).
	function prepareScore(gx:Int, gy:Int, score:Int):Void {
		var t = new Text("+" + score, cast {
			fontFamily: "Arial, sans-serif", fontSize: 16, fontWeight: "bold",
			fill: 0xffe066, stroke: 0x000000, strokeThickness: 3
		});
		t.anchor.set(0.5, 0.5);
		var p = Slot.getStonePos(gx, gy);
		t.x = p.x;
		t.y = p.y;
		layerScore.addChild(t);
		var pnb = 2 + rand(3);
		for (i in 0...pnb)
			spawnSparkle(p.x + (rand(2) * 2 - 1) * (5 + rand(8)), p.y + (rand(2) * 2 - 1) * (5 + rand(8)));
		var tt = 0;
		fxList.push(function() {
			tt++;
			t.y -= 1.2;
			t.alpha = 1 - tt / 30.0;
			if (tt >= 30) {
				if (t.parent != null)
					t.parent.removeChild(t);
				return true;
			}
			return false;
		});
	}

	// Son d'atterrissage d'une pierre (Rock_fall1..9 aléatoire), throttlé.
	public function onStoneLanded():Void {
		if (fallSndCd > 0)
			return;
		fallSndCd = 3;
		snd.Sfx.play("Rock_fall" + (1 + rand(9)));
	}

	// ------------------------------------------------------------------
	// Particules / FX (gfx.Sparkle*, gfx.Vanish, gfx.MudPart)
	// ------------------------------------------------------------------
	// Sprite d'atlas joué UNE fois puis auto-retiré (gfx.Vanish : éclat).
	function spawnOnce(name:String, x:Float, y:Float, blendAdd:Bool):Void {
		var sp = new ASprite(name);
		sp._x = x;
		sp._y = y;
		if (blendAdd)
			sp.blendMode = BlendModes.ADD;
		sp.loop = false;
		sp.removeOnFrame = sp._totalframes;
		sp.play();
		layerFx.addChild(sp);
	}

	// Étincelle (gfx.Sparkle/2/3) qui dérive vers le haut et s'estompe.
	function spawnSparkle(x:Float, y:Float):Void {
		var names = ["Sparkle", "Sparkle2", "Sparkle3"];
		spawnParticle(names[rand(3)], x, y, (Math.random() - 0.5) * 1.2, -0.3 - Math.random(), -0.04, 10 + rand(10), true);
	}

	// Particule générique : sprite d'atlas (anim bouclée) avec vélocité + poids,
	// fondu sur `timer` frames, retiré à la fin.
	function spawnParticle(name:String, x:Float, y:Float, vx:Float, vy:Float, weight:Float, timer:Int, blendAdd:Bool):Void {
		var sp = new ASprite(name);
		sp._x = x;
		sp._y = y;
		if (blendAdd)
			sp.blendMode = BlendModes.ADD;
		if (sp._totalframes > 1) {
			sp.loop = true;
			sp.play();
		}
		layerFx.addChild(sp);
		var t = 0;
		var dvx = vx;
		var dvy = vy;
		fxList.push(function() {
			t++;
			dvy += weight;
			dvx *= 0.96;
			sp._x = sp._x + dvx;
			sp._y = sp._y + dvy;
			sp._alpha = 100 * Math.max(0, 1 - t / timer);
			if (t >= timer) {
				sp.removeMovieClip();
				return true;
			}
			return false;
		});
	}

	// Boue qui tombe en fond (gfx.MudPart) - cf. addMudParts d'origine.
	function addMudParts():Void {
		nextMudPart = 70 + rand(70);
		var n = 1;
		var nb = rand(10);
		if (nb < 2)
			n += 2;
		else if (nb < 5)
			n += 1;
		for (i in 0...n) {
			var sp = new ASprite("MudPart");
			sp.gotoAndStop(rand(5) + 1);
			sp._x = 40 + rand(WIDTH - 80);
			sp._y = -50 - rand(250);
			sp._rotation = rand(360);
			if (rand(2) == 0)
				sp._xscale = -100;
			layerFx.addChild(sp);
			var vy = 1.0 + Math.random() * 2;
			var t = 0;
			fxList.push(function() {
				t++;
				vy += 0.3;
				sp._y = sp._y + vy;
				sp._rotation = sp._rotation + 3;
				if (sp._y > HEIGHT + 60 || t > 400) {
					sp.removeMovieClip();
					return true;
				}
				return false;
			});
		}
	}

	// ------------------------------------------------------------------
	// Système de tweens inline
	// ------------------------------------------------------------------
	function updateFx():Void {
		var i = fxList.length - 1;
		while (i >= 0) {
			if (fxList[i]())
				fxList.splice(i, 1);
			i--;
		}
	}

	public function tweenTo(mc:ASprite, tx:Float, ty:Float, dur:Int, ?onFinish:Void->Void):Void {
		var t = 0;
		var sx = mc._x;
		var sy = mc._y;
		fxList.push(function() {
			t++;
			var k = t / dur;
			if (k > 1)
				k = 1;
			var e = k * k * (3 - 2 * k); // smoothstep
			mc._x = sx + (tx - sx) * e;
			mc._y = sy + (ty - sy) * e;
			if (t >= dur) {
				if (onFinish != null)
					onFinish();
				return true;
			}
			return false;
		});
	}

	public function vanishFx(mc:ASprite, dur:Int, ?onFinish:Void->Void):Void {
		var t = 0;
		var a0 = mc._alpha;
		var s0 = mc._xscale;
		fxList.push(function() {
			t++;
			var k = t / dur;
			if (k > 1)
				k = 1;
			mc._alpha = a0 * (1 - k);
			mc._xscale = mc._yscale = s0 * (1 - k);
			if (t >= dur) {
				if (onFinish != null)
					onFinish();
				return true;
			}
			return false;
		});
	}

	public function waitDone():Void {
		waitingFx--;
	}

	public function getFreeExitSlots():Array<Slot> {
		var res = [];
		for (i in 0...STAGE_SIZE) {
			var s = grid[i][STAGE_SIZE - 1];
			if (s.exit == null)
				res.push(s);
		}
		return res;
	}

	// ------------------------------------------------------------------
	// Pierres : insertion / combos (flood-fill)
	// ------------------------------------------------------------------
	function countStones():Int {
		var c = 0;
		for (s in allSlots)
			if (s.stone != null && s.stone.isStone())
				c++;
		return c;
	}

	function insertStones(changeable:Array<Slot>, force:Int = 0):Void {
		var weights = [20, 48, 30, 2];
		var nStones = force;
		if (nStones == 0) {
			var canHave = randomProbs(weights);
			nStones = canHave - countStones();
		}
		nStones += Std.int(Math.round(playWithoutGrab / 10.0));
		nStones = Std.int(Math.min(nStones, changeable.length));

		var guard = 0;
		while (nStones > 0 && guard++ < 2000) {
			var slot = changeable[rand(changeable.length)];
			if (slot.stone.isStone() || slot.y == STAGE_SIZE - 1)
				continue;
			slot.stone.setId(10);
			nStones--;
		}
	}

	function killAutoCombo(changeable:Array<Slot>):Void {
		var guard = 0;
		while (guard++ < 1000) {
			var groups = getGroups();
			var autoCombo = false;
			for (g in groups) {
				if (g.l.length < COMBO_COUNT)
					continue;
				autoCombo = true;
				break;
			}
			if (autoCombo) {
				for (s in changeable)
					if (!s.stone.isStone())
						s.stone.draw();
			} else
				break;
		}
	}

	function parse(from:Slot, into:Array<Slot>):Void {
		from.group.l.push(from);
		for (d in DIRS) {
			var nx = from.x + d[0];
			var ny = from.y + d[1];
			if (nx < 0 || nx >= STAGE_SIZE || ny < 0 || ny >= STAGE_SIZE)
				continue;
			var s = grid[nx][ny];
			if (s.group != null || s.stone == null || s.stone.isStone() || from.stone.id != s.stone.id)
				continue;
			into.remove(s);
			s.group = from.group;
			parse(s, into);
		}
	}

	public function getGroups():Array<CGroup> {
		resetGroups();
		var s:Array<Slot> = [];
		for (sl in allSlots)
			if (sl.stone != null && !sl.stone.isStone())
				s.push(sl);
		var groups:Array<CGroup> = [];
		while (s.length > 0) {
			var a = s.pop();
			a.group = {id: groups.length, l: []};
			groups.push(a.group);
			parse(a, s);
		}
		return groups;
	}

	function resetGroups():Void {
		for (g in grid)
			for (s in g)
				s.killGroup();
	}

	public static function randomProbs(t:Array<Int>):Int {
		var n = 0;
		for (e in t)
			n += e;
		n = Game.me.rand(n);
		var i = 0;
		while (n >= t[i]) {
			n -= t[i];
			i++;
		}
		return i;
	}
}
