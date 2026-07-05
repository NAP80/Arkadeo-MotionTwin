// New Rock Faller - boot autonome. Réutilise la lib kado (ASprite, DepthManager,
// Timer, MouseManager, FixedFramerate, Seed) ; canvas 600×480 (rendu 1:1) ; atlas sous
// /new-rock-faller/assets. Score et fin de partie émis en CustomEvents window que la vue
// relaie vers POST /api/results. Le host instancie `new RockFallerBoot(canvas)` (@:expose).
import pixi.core.Application;
import pixi.core.ticker.Ticker;
import js.html.CanvasElement;
import js.html.CustomEvent;
import js.Browser;
import common_haxe_avm1.display.ASprite;
import common_haxe_avm1.KeyboardManager;
import common_haxe_avm1.MouseManager;
import mt.DepthManager;
import mt.Timer;
import kado.FixedFramerate;
import kado.Seed;

@:expose("RockFallerBoot")
class Boot extends Application {
	public static var me:Boot;

	public var score:Int = 0;
	// Écran d'accueil : le jeu est CRÉÉ (1ʳᵉ frame figée) mais ne tourne pas tant
	// que le joueur n'a pas cliqué « Jouer » (startPlay, déclenché par le host).
	public var started:Bool = false;
	// Clic gauche : maintenu (leftDown) + front montant consommé par Game pour
	// déclencher la rotation du carré 2×2 survolé (cf. fg.onClick(emitRotation)).
	public var leftDown:Bool = false;
	public var clickPending:Bool = false;
	// Mode de jeu : "league" (défaut) ou "lvup" (campagne 30 niveaux) + niveau courant.
	public var mode:String = "league";
	public var level:Int = 1;

	var root:ASprite;
	var dm:DepthManager;
	var gameRoot:ASprite;
	var game:Game;
	var ff:FixedFramerate;
	var simulationTimeMs:Float = 0;

	// Délai (ms) entre la fin de partie et l'écran de fin : laisse les dernières
	// animations (chutes/refill/combos/FX) se terminer et le plateau se poser pour que
	// la « Victoire » ne coupe pas net. Le moteur continue de tourner pendant ce délai.
	static inline var END_DELAY_MS = 2000;
	var endTimeoutId:Int = -1; // setTimeout en attente (annulable par +1 coup)

	public function new(canvas:CanvasElement, ?mode:String, ?level:Int) {
		super({
			view: canvas,
			width: Game.WIDTH,
			height: Game.HEIGHT,
			backgroundColor: 0x000000,
			antialias: true,
		});
		me = this;
		this.mode = (mode == null) ? "league" : mode;
		this.level = (level == null || level < 1) ? 1 : level;
		canvas.width = Game.WIDTH;
		canvas.height = Game.HEIGHT;

		root = new ASprite();
		dm = new DepthManager(root);
		this.stage.addChild(root);

		KeyboardManager.init();
		MouseManager.init(this);
		Seed.init(1 + Std.random(0x7FFFFE));

		// Clic / TAP : POINTER events (souris + tactile + stylet), pas `mousedown` (peu
		// fiable sur mobile). La rotation est déclenchée au **RELÂCHEMENT** (pointerup),
		// pas à l'appui : `pointerdown` ARME le geste (leftDown), `pointerup` SUR le canvas
		// le valide (clickPending). Un appui relâché hors du canvas (souris) est annulé.
		// (CSS `touch-action:none` sur le canvas → le geste n'est pas volé par scroll/zoom.)
		var isLeft = function(e) return untyped e.button == 0 || untyped e.pointerType == "touch";
		canvas.addEventListener("pointerdown", function(e) {
			if (isLeft(e)) leftDown = true;
		});
		canvas.addEventListener("pointerup", function(e) {
			if (isLeft(e)) {
				if (leftDown) clickPending = true; // rotation au relâchement
				leftDown = false;
			}
		});
		// Relâché/annulé hors du canvas → on annule le geste (pas de rotation).
		js.Browser.document.addEventListener("pointerup", function(e) {
			if (isLeft(e)) leftDown = false;
		});
		canvas.addEventListener("pointercancel", function(e) {
			leftDown = false;
		});

		// Boucle fixe (physique) + rendu interpolé.
		ff = new FixedFramerate(updatePhysics);
		untyped Ticker.system.add((delta:Float) -> {
			ff.onTick(untyped Ticker.system.elapsedMS);
		});
		this.ticker.add(() -> {
			if (gameRoot != null)
				gameRoot.updateGraphics(ff.alpha);
		});

		// Atlas des symboles gfx de Rock Faller (extraits du SWF d'origine). Chargé dans le loader
		// PARTAGÉ (PIXI.Loader.shared) car c'est celui que lit ASprite.
		// "rockfaller" EN PREMIER → c'est la spritesheet que prend ASprite (1ʳᵉ ressource).
		var shared:pixi.loaders.Loader = untyped PIXI.Loader.shared;
		shared.add("rockfaller", "/new-rock-faller/assets/img/content/rockfaller/rockfaller-0.json");
		shared.add("rf-bg", "/new-rock-faller/assets/img/content/rockfaller/bg.png");
		shared.add("rf-fg", "/new-rock-faller/assets/img/content/rockfaller/fg.png");
		shared.add("rf-fgmask", "/new-rock-faller/assets/img/content/rockfaller/fg_mask.png");
		shared.load(() -> startGame());
	}

	function startGame():Void {
		KeyboardManager.clearState();
		MouseManager.clearState();
		simulationTimeMs = Timer.oldTime;
		gameRoot = dm.empty(1);
		try {
			game = new Game(gameRoot);
			emit("rf-ready", {});
		} catch (e:Dynamic) {
			js.Browser.console.error("RockFallerBoot startGame ERROR:", e, (untyped e).stack);
		}
	}

	// Lance réellement la partie (appelé par le host au clic sur « Jouer »).
	// Le clic est un geste utilisateur → on peut démarrer la musique (autoplay OK).
	public function startPlay():Void {
		started = true;
		snd.Sfx.startMusic("Music");
	}

	// Bouton mute du host (renvoie le nouvel état muet).
	public function toggleMute():Bool {
		return snd.Sfx.toggleMuted();
	}

	// Bouton bonus du host : +1 coup (relance la partie si elle était finie).
	public function addBonusPlay():Void {
		// Si on relance pendant le délai de fin, on annule l'écran de fin programmé.
		if (endTimeoutId != -1) {
			js.Browser.window.clearTimeout(endTimeoutId);
			endTimeoutId = -1;
		}
		if (game != null)
			game.bonusPlay();
	}

	function updatePhysics(dt:Float):Void {
		KeyboardManager.beginFrame();
		MouseManager.beginFrame();
		simulationTimeMs += dt;
		Timer.update(simulationTimeMs);
		Timer.deltaT = dt / 1000;
		Timer.tmod = 1;
		Timer.calc_tmod = 1;
		if (game != null && started) {
			gameRoot.update();
			game.update(dt);
		}
		// Front montant du clic consommé APRÈS l'update du jeu.
		clickPending = false;
	}

	// Dev/headless : avance N pas de physique à la main (l'aperçu headless met
	// requestAnimationFrame en pause → permet de vérifier la logique sans rAF).
	public function devTick(n:Int):Void {
		started = true;
		for (i in 0...n)
			updatePhysics(FixedFramerate.STEP);
	}

	// --- Ponts score / fin de partie (relayés par le host vers /api/results) ---
	public function addScore(n:Int):Int {
		score += n;
		emit("rf-score", {score: score});
		return score;
	}

	public function getScore():Int {
		return score;
	}

	public function gameOver(win:Bool):Void {
		if (endTimeoutId != -1)
			return; // déjà programmé
		// On DIFFÈRE l'écran de fin de quelques secondes : le moteur continue de tourner
		// (les dernières chutes/FX se terminent, le plateau se pose), puis on émet
		// rf-finished → ArkadeoEndgame fige + affiche « Victoire / Rejouer ».
		endTimeoutId = js.Browser.window.setTimeout(function() {
			endTimeoutId = -1;
			emit("rf-finished", {win: win, score: score, mode: mode, level: level});
		}, END_DELAY_MS);
	}

	// LvUP : barre de progression (ratio = score / objectif).
	public function setProgress(ratio:Float):Void {
		emit("rf-progress", {ratio: ratio, score: score});
	}

	function emit(name:String, detail:Dynamic):Void {
		untyped Browser.window.dispatchEvent(new CustomEvent(name, {detail: detail}));
	}
}
