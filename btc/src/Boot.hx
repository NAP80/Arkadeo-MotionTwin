// Boot PixiJS de New Brutal Teenage Crisis (@:expose("BTCBoot")).
// Charge l'atlas + testLevel, alimente le registre slb, fournit Level.source
// (collision), instancie le jeu et pilote game.update(true) à cadence fixe 30 fps.
import js.html.CanvasElement;
import js.html.CustomEvent;
import js.Browser;
import mt.deepnight.slb.BLib;
import flash.display.BitmapData;

@:expose("BTCBoot")
class Boot extends pixi.core.Application {
	public static var me:Boot;

	inline static var W = 600;
	inline static var H = 460;
	inline static var STEP = 1000.0 / 30.0;
	inline static var MAX_STEPS = 4;

	// Bonus de saut de la fraise (SuperPower), réintroduit ici (le SWF d'origine n'en
	// avait aucun). Surplus d'élan par frame tant qu'on maintient Haut pendant jumpExtend
	// (~3 frames) → bonus total ≈ 3× cette valeur. Seul réglage pour doser la hauteur.
	// Repères : 0.20 ≈ +55 % (trop), 0.08 ≈ +18 %.
	inline static var SUPER_JUMP_BOOST = 0.07;

	// Vitesse de chute max du héros (cases/frame). La charge du Fly le projette vers le bas
	// à ~2.0 et la physique d'origine n'a aucune vitesse terminale → plongeon ~5× trop
	// rapide. On plafonne la descente : la charge garde sa poussée horizontale + le stun.
	inline static var HERO_MAX_FALL = 0.45;

	// Plafond du héros (cy mini). Borne cosmétique (le Fly est blindé contre la boucle via
	// le shadow Fly.initTarget) : relevée pour ne pas couper les sauts au bord haut. Entre
	// 0 et là, l'amorti d'origine (Entity.update dy*=0.6 quand cy<0) freine la montée.
	inline static var CEILING_CY = -6;

	public var score:Int = 0;
	public var started:Bool = false;

	var acc:Float = 0;
	var game:Game;

	public function new(canvas:CanvasElement) {
		super({view: canvas, width: W, height: H, backgroundColor: 0x1a0a12, antialias: false});
		me = this;

		// Const.hx déclare PHASE_CD/PHASE_DURATION avant FPS ; Haxe exécute les init
		// statiques dans l'ordre → seconds() lit FPS=undefined → valeurs à NaN, donc
		// isPhasing() toujours faux (la phase Espace ne coupe rien, jauge HUD NaN).
		// On recalcule ici, FPS valant désormais 30.
		Const.PHASE_CD = Const.seconds(15);
		Const.PHASE_DURATION = Const.seconds(2.5);

		js.Syntax.code("PIXI.settings.SCALE_MODE = PIXI.SCALE_MODES.NEAREST");
		canvas.width = W;
		canvas.height = H;

		api.AKApi.init();

		var loader:Dynamic = js.Syntax.code("PIXI.Loader.shared");
		loader.add("sheet", "/new-btc/assets/sheet.png");
		loader.add("backgrounds", "/new-btc/assets/backgrounds.png");
		loader.add("testlevel", "/new-btc/assets/testLevel.png");

		fetchText("/new-btc/assets/sheet.xml", function(sheetXml) {
			fetchText("/new-btc/assets/sheet.anims.xml", function(animsXml) {
				fetchText("/new-btc/assets/backgrounds.xml", function(bgXml) {
					loader.load(function(_, _) onLoaded(sheetXml, animsXml, bgXml));
				});
			});
		});

		this.ticker.add(function(_) tick());
	}

	static function fetchText(url:String, cb:String->Void):Void {
		js.Syntax.code("fetch({0}).then(function(r){return r.text();}).then({1}).catch(function(e){console.error('fetch',{0},e);})", url, cb);
	}

	function onLoaded(sheetXml:String, animsXml:String, bgXml:String):Void {
		try {
			var res:Dynamic = js.Syntax.code("PIXI.Loader.shared.resources");
			// Registre slb pour les importXml runtime appelés dans Mode.
			BLib.register("assets/sheet.xml", sheetXml, animsXml, res.sheet.texture.baseTexture, res.sheet.data);
			BLib.register("assets/backgrounds.xml", bgXml, null, res.backgrounds.texture.baseTexture, res.backgrounds.data);
			// Carte de collision League.
			Level.source = BitmapData.fromImage(res.testlevel.data);

			game = new Game();
			this.stage.addChild(game);

			var modeName = api.AKApi.lvup ? "Progression/LvUP niv." + api.AKApi.getLevel() : (api.AKApi.defi ? "Défi Coffres" : "League");
			trace("BTCBoot: Game créé (mode " + modeName + ")");
			emit("btc-ready", {});
		} catch (e:Dynamic) {
			Browser.console.error("BTCBoot onLoaded ERROR:", e, (untyped e).stack);
		}
	}

	// Lancé par le host au clic « Jouer ».
	public function startPlay():Void {
		started = true;
	}

	function tick():Void {
		if (game == null) return;
		acc += this.ticker.elapsedMS;
		var n = 0;
		while (acc >= STEP && n < MAX_STEPS) {
			acc -= STEP;
			n++;
			if (started) {
				game.update(true);
				// Appelé DANS la boucle à pas fixe (30 fps) : hors de la boucle il tournerait
				// une fois par frame d'affichage (60/144 Hz) et le bonus s'appliquerait 2 à 5×
				// trop souvent → hauteur de saut fonction du taux de rafraîchissement.
				superPowerJumpBoost();
			}
		}
		if (acc > STEP * MAX_STEPS) acc = 0;
		clampHero();
		syncHeroAttachAlpha();
		emitProgress();
	}

	// Bonus de saut de la fraise : surplus d'élan tant qu'on maintient Haut pendant
	// jumpExtend, mais PAS sur la frame de décollage. Ainsi un saut « tapé » (touche
	// relâchée tôt) garde la hauteur de base, seul le saut maintenu gagne le bonus.
	var prevJumpExtend:Bool = false;

	function superPowerJumpBoost():Void {
		var m = Mode.ME;
		if (m == null || m.hero == null) { prevJumpExtend = false; return; }
		var hero = m.hero;
		if (hero.killed || hero.hasLeft) { prevJumpExtend = false; return; }
		var je = hero.cd.has("jumpExtend");
		// prevJumpExtend && je : on saute la 1re frame de jumpExtend (= le décollage) → le
		// bonus ne s'applique qu'aux frames d'extension suivantes.
		if (hero.hasSuperPower() && je && prevJumpExtend && api.AKApi.isDown(38)) {
			untyped { if (hero.dy < 0) hero.dy -= SUPER_JUMP_BOOST; }
		}
		prevJumpExtend = je;
	}

	// Garde-fous de position du héros, contre les sorties de map dues aux lasers du Fly
	// (poussée + stopFall empilés l'éjectaient et faisaient planter le jeu).
	function clampHero():Void {
		var m = Mode.ME;
		if (m == null || m.hero == null || m.level == null) return;
		var hero = m.hero;
		if (hero.hasLeft || hero.killed) return;

		// Vitesse terminale : on plafonne uniquement la descente (dy>0) → le saut intact.
		untyped { if (hero.dy > HERO_MAX_FALL) hero.dy = HERO_MAX_FALL; }

		// Plafond (borne cosmétique) : voir CEILING_CY.
		if (hero.cy < CEILING_CY) {
			untyped {
				hero.cy = CEILING_CY;
				hero.yr = 0.5;
				if (hero.dy < 0) hero.dy = 0;
			}
		}

		// Sol (League seulement) : projeté sous le niveau → reposé au sol. En LvUP, c'est
		// Progression qui gère la chute (perte de vie + respawn).
		if (!api.AKApi.lvup && hero.cy >= Const.LHEI) {
			var pt:Dynamic = null;
			try {
				pt = m.level.getRandomSpot(0); // sol du niveau 0 (bas)
			} catch (e:Dynamic) {}
			if (pt == null) pt = m.level.getRandomSpot(); // repli : n'importe quel sol
			if (pt == null) return;
			hero.setPos(pt.cx, pt.cy);
			untyped {
				hero.dx = 0;
				hero.dy = 0;
				hero.stable = false;
			}
		}
	}

	// LvUP : le score est nul (le Gold ne tombe qu'en League) → le host affiche plutôt
	// la progression « coffres détruits / total ». On émet un event quand ça change.
	var lastDestroyed:Int = -1;
	var lockTotal:Int = 0; // total initial de coffres (on garde le max, Lock.ALL diminue)

	function emitProgress():Void {
		if (!api.AKApi.lvup || game == null || !started) return;
		// Lock.ALL rétrécit (coffres détruits retirés via unregister) : il faut figer le
		// total initial, sinon destroyed = ALL.length - remaining reste à 0.
		var cur = en.mob.Lock.ALL.length;
		if (cur > lockTotal) lockTotal = cur;
		if (lockTotal <= 0) return;
		var remaining = en.mob.Lock.getRemainings().length;
		var destroyed = lockTotal - remaining;
		if (destroyed == lastDestroyed) return;
		lastDestroyed = destroyed;
		emit("btc-progress", {destroyed: destroyed, total: lockTotal, remaining: remaining});
	}

	// La couette, le boulet et la chaîne sont des objets d'affichage séparés (DP_HERO),
	// pas des enfants du corps → la phase (Hero.phaseOut → sprite.alpha=0.4) ne les
	// assombrissait pas. On aligne leur alpha sur celui du corps à chaque frame.
	function syncHeroAttachAlpha():Void {
		var m = Mode.ME;
		if (m == null) return;
		var hero = m.hero;
		if (hero == null || hero.sprite == null) return;
		var a:Float = hero.sprite.alpha;
		untyped {
			if (hero.hair != null) hero.hair.alpha = a;
			var ball = hero.ball;
			if (ball != null) {
				if (ball.sprite != null) ball.sprite.alpha = a;
				var chain = ball.chain;
				if (chain != null) {
					var i = 0;
					while (i < chain.length) {
						chain[i].alpha = a;
						i++;
					}
				}
			}
		}
	}

	// Dev/headless : avance N frames de jeu (rAF en pause onglet caché).
	public function devTick(n:Int):Void {
		started = true;
		for (i in 0...n)
			if (game != null) game.update(true);
		emitProgress();
	}

	// Bouton DEV « bonus » : fait apparaître un bonus loin du héros.
	// 0 = Bombe, 1 = Super Power, 2 = Méga Bombe.
	public function spawnBonus(type:Int):Void {
		if (game == null) return;
		var m = Mode.ME;
		if (m == null || m.level == null || m.hero == null) return;
		var pt = m.level.getRandomSpotFar();
		switch (type) {
			case 1: new en.it.SuperPower(pt.cx, pt.cy);
			case 2: new en.it.MegaBomb(pt.cx, pt.cy);
			default: new en.it.Bomb(pt.cx, pt.cy);
		}
	}

	// Bouton DEV : fait apparaître le monstre volant (Fly).
	public function devSpawnFly():Void {
		if (game == null) return;
		var m = Mode.ME;
		if (m == null || m.level == null) return;
		new en.mob.Fly();
	}

	// Bouton DEV : tue tous les vrais monstres (countAsMob), pas les serrures (coffres).
	public function devKillAllMobs():Void {
		if (game == null) return;
		for (e in en.Mob.ALL.copy())
			if (e.countAsMob && !e.killed)
				e.hit(e.xx, e.yy, 9999);
	}

	// --- Ponts score / fin (relayés par le host vers /api/results) ---

	public function addScore(n:Int):Int {
		score = n;
		emit("btc-score", {score: score});
		return score;
	}

	public function getScore():Int return score;

	public function gameOver(win:Bool):Void {
		emit("btc-finished", {
			win: win,
			score: score, // en Défi : score = nb de coffres détruits (Endless.onChestDestroyed)
			mode: api.AKApi.lvup ? "lvup" : (api.AKApi.defi ? "defi" : "league"),
			lvupLevel: api.AKApi.playedLevel
		});
	}

	function emit(name:String, detail:Dynamic):Void {
		untyped Browser.window.dispatchEvent(new CustomEvent(name, {detail: detail}));
	}
}
