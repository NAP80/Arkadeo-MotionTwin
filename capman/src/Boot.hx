// Boot autonome.
// Boucle à pas fixe 40 fps : un accumulateur cadence Game.update() et PixiJS rend l'état courant (pas d'interpolation).
// Le host fait `new CapManBoot(canvas)`, score / progression / fin sortent en CustomEvents window.
import pixi.core.Application;
import js.html.CanvasElement;
import js.html.CustomEvent;
import js.Browser;
import common_haxe_avm1.KeyboardManager;
import api.AKApi;

@:expose("CapManBoot")
class Boot extends Application {
	public static var me:Boot;

	inline static var STEP = 1000.0 / 40.0; // Pas de la logique d'origine = 40 fps (gameResources.swf à 40 ; gfx/bumdum à 42)
	inline static var MAX_STEPS = 4; // Anti-spirale si l'onglet a lagué

	public var score:Int = 0;
	public var started:Bool = false;
	public var editMode:Bool = false;

	// SpeedRun : état EN MÉMOIRE (pas de cookie -> un refresh repart au niveau 1).
	public var srMode:Bool = false;
	public var srLevel:Int = 1; // niveau courant du run (1..20)
	public var srFrames:Int = 0; // frames de JEU ACTIF cumulées (= le chrono)
	public var srRunning:Bool = false; // le chrono tourne-t-il (jeu actif, hors 3-2-1/mort) ?

	var game:Game;
	var acc:Float = 0;

	public function new(canvas:CanvasElement) {
		// Mode + niveau + taille décidés AVANT super() (pas d'accès à this).
		// LvUP : niveau lu dans le cookie ; Éditeur : niveau lu dans le hint d'édition.
		// Les niveaux >= Cs.BIG_FROM passent en grande grille (canvas doublé).
		var lvup = isLvupMode();
		var edit = isEditMode();
		var speedrun = isSpeedrunMode();
		// SpeedRun démarre toujours au niveau 1 (petite grille), enchaîné en mémoire.
		var level = speedrun ? 1 : (lvup ? readLevelCookie() : (edit ? readEditorLevel() : 1));
		var big = !speedrun && (lvup || edit) && Cs.isBigLevel(level);
		Cs.setSize(big);

		super({
			view: canvas,
			width: Cs.WIDTH,
			height: Cs.HEIGHT,
			backgroundColor: 0x000000,
			antialias: false,
		});
		me = this;
		canvas.width = Cs.WIDTH;
		canvas.height = Cs.HEIGHT;

		KeyboardManager.init();
		AKApi.init();
		// SpeedRun charge les niveaux DESSINÉS (comme LvUP) -> progression=true.
		AKApi.setMode(lvup || speedrun, level);
		editMode = edit;
		AKApi.setEditor(editMode);
		srMode = speedrun;
		srLevel = 1;
		AKApi.setSpeedrun(speedrun);

		var shared:pixi.loaders.Loader = untyped PIXI.Loader.shared;
		shared.add("capman", "/new-capman/assets/img/content/capman/capman-0.png");
		var fx = "/new-capman/assets/img/content/capman/fx/";
		for (i in 0...12) shared.add("partbad" + i, fx + "partbad-" + i + ".png");
		shared.add("rad0", fx + "rad-0.png");
		shared.add("lt0", fx + "lighttriangle-0.png");
		shared.load(function(_, _) startGame());

		this.ticker.add(function(_) tick());
	}

	function startGame():Void {
		try {
			game = new Game();
			this.stage.addChild(game);
			// L'éditeur tourne tout de suite (il prend la main via stepFx). League / LvUP /
			// SpeedRun attendent le clic « Jouer / Démarrer » (startPlay) : le SpeedRun
			// enchaîne alors seq.Init -> 3-2-1-Go, pour que le joueur soit prêt.
			if (editMode) started = true;
			trace("CapManBoot: game created (paused, waiting for play)");
			emit("nc-ready", {});
		} catch (e:Dynamic) {
			js.Browser.console.error("CapManBoot startGame ERROR:", e, (untyped e).stack);
		}
	}

	// Lance la partie (appelé par le host au clic "Jouer").
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
			updateLogic();
		}
		if (acc > STEP * MAX_STEPS) acc = 0;
	}

	function updateLogic():Void {
		KeyboardManager.beginFrame();
		if (started)
			game.update(true);
	}

	// Dev/headless : avance N pas de logique à la main (rAF en pause).
	public function devTick(n:Int):Void {
		started = true;
		for (i in 0...n)
			updateLogic();
	}

	// DEV : donne une casquette d'invincibilité.
	public function devCap():Void {
		if (game != null) game.devCap();
	}

	// DEV : fait apparaître un monstre du type donné.
	public function devSpawn(id:Int):Void {
		if (game != null) game.devSpawn(id);
	}

	// DEV : supprime tous les monstres de la partie en cours.
	public function devKillBads():Void {
		if (game != null) game.devKillBads();
	}

	// --- Ponts score / fin de partie (relayés par le host vers /api/results) ---
	public function addScore(n:Int):Int {
		score = n;
		emit("nc-score", {score: score});
		return score;
	}

	public function getScore():Int {
		return score;
	}

	// Barre de progression LvUP (0->1), relayée au host (nc-progress).
	public function progress(c:Float):Void {
		emit("nc-progress", {c: c, level: AKApi.getLevel()});
	}

	public function gameOver(win:Bool):Void {
		emit("nc-finished", {win: win, score: score, mode: AKApi.getModeStr(), level: AKApi.getLevel()});
	}

	// --- Ponts SPEEDRUN (chrono en mémoire + events vers la page) ---

	// Appelé chaque frame de JEU ACTIF (gstep 0) par Game.update : avance le chrono.
	public function srTick():Void {
		if (srRunning) srFrames++;
	}

	// Démarre/reprend (true, à « Go ») ou met en pause (false, slide/3-2-1/mort) le chrono.
	public function srSetRunning(b:Bool):Void {
		srRunning = b;
	}

	public function getSpeedrunMs():Int {
		return Std.int(srFrames * STEP);
	}

	public function getSpeedrunLevel():Int {
		return srLevel;
	}

	// Change le niveau courant du run (slide vers le suivant / respawn) + prévient la page.
	public function srSetLevel(n:Int):Void {
		srLevel = n;
		AKApi.setLevel(n);
		emit("nc-sr-level", {level: n});
	}

	// Compte à rebours 3-2-1-Go (seq.Countdown -> overlay de la page).
	public function srCountdown(n:Int):Void {
		emit("nc-countdown", {n: n});
	}

	public function srGo():Void {
		emit("nc-go", {});
	}

	// Fin du run (niveau 20 réussi) : on envoie le TEMPS (durationMs), pas le score.
	public function srFinish():Void {
		srRunning = false;
		emit("nc-finished", {win: true, mode: "speedrun", durationMs: getSpeedrunMs(), level: srLevel});
	}

	var srScheduled:Bool = false;

	// Niveau réussi -> niveau suivant (ou fin au 20). DIFFÉRÉ (setTimeout 0) : reconstruire
	// le niveau hors de la pile update() en cours (sinon destruction d'objets itérés -> crash).
	public function srScheduleAdvance():Void {
		if (srScheduled) return;
		srScheduled = true;
		js.Browser.window.setTimeout(function() {
			srScheduled = false;
			if (srLevel >= Cs.MAXLEVEL) {
				srFinish();
				return;
			}
			srSetRunning(false);
			srSetLevel(srLevel + 1);
			if (game != null) game.srRebuildLevel(); // slide + 3-2-1-Go avant le niveau suivant (le temps de se replacer)
		}, 0);
	}

	// Mort -> on rejoue le MÊME niveau après 3-2-1-Go (le chrono garde le total).
	public function srScheduleRespawn():Void {
		if (srScheduled) return;
		srScheduled = true;
		js.Browser.window.setTimeout(function() {
			srScheduled = false;
			srSetRunning(false);
			// Mort au tout premier niveau = on repart d'un chrono vierge (un raté d'entrée
			// ne coûte rien) ; aux niveaux suivants le temps reste cumulé.
			if (srLevel == 1) srFrames = 0;
			AKApi.resetGameOver();
			if (game != null) game.srRebuildLevel(); // slide + 3-2-1-Go avant de reprendre le même niveau
		}, 0);
	}

	// --- Ponts ÉDITEUR (appelés par la page /new-capman/editor) ---

	// Émis par seq.Editor à chaque changement (niveau courant, total, modifié ?).
	public function editorInfo(level:Int, count:Int, modified:Bool):Void {
		emit("nc-editor", {level: level, count: count, modified: modified});
	}

	// Donnée sérialisée du jeu de niveaux (pour copier/exporter).
	public function editorExport():String {
		return (seq.Editor.me != null) ? seq.Editor.me.exportString() : "";
	}

	// Importe une chaîne sérialisée collée par l'utilisateur (true = OK).
	public function editorImport(s:String):Bool {
		return (seq.Editor.me != null) ? seq.Editor.me.importString(s) : false;
	}

	// Export / import d'UN SEUL niveau (taille max, cf. seq.Editor).
	public function editorExportLevel():String {
		return (seq.Editor.me != null) ? seq.Editor.me.exportLevelString() : "";
	}

	public function editorImportLevel(s:String):Bool {
		return (seq.Editor.me != null) ? seq.Editor.me.importLevelString(s) : false;
	}

	// Navigue (0=suivant,1=bas,2=précédent,3=haut) ; ici 2=précédent / 0=suivant.
	public function editorGoto(di:Int):Void {
		if (seq.Editor.me != null) seq.Editor.me.gotoLevel(di);
	}

	// Vide le niveau courant (tout en murs).
	public function editorClear():Void {
		if (seq.Editor.me != null) seq.Editor.me.clearLevel();
	}

	// Recharge la campagne d'origine (Cs.levels).
	public function editorReset():Void {
		if (seq.Editor.me != null) seq.Editor.me.resetToCampaign();
	}

	// Reconstruit le jeu à une nouvelle taille de grille. Appelé par l'éditeur quand
	// la navigation franchit la frontière petit/grand (niveau 20 <-> 21), et par
	// endPlaytest pour repartir d'un état propre. En mode éditeur, le nouveau Game
	// relance seq.Editor (qui recharge le niveau depuis le store autosauvegardé).
	public function setSizeAndRebuild(big:Bool):Void {
		if (game != null) {
			this.stage.removeChild(game);
			try {
				untyped game.destroy({children: true}); // stoppe les AnimatedSprite -> pas de fuite ticker
			} catch (e:Dynamic) {}
			game = null;
		}
		mt.pix.Element.clearAnimated(); // purge les els détruits avant de recréer le jeu
		Cs.setSize(big);
		this.renderer.resize(Cs.WIDTH, Cs.HEIGHT);
		game = new Game();
		this.stage.addChild(game);
		if (editMode) started = true;
		emit("nc-ready", {});
	}

	// Lance un essai jouable sur la configuration en cours d'édition (bouton Tester).
	public function playtest():Void {
		if (seq.Editor.me != null) seq.Editor.me.playtest();
	}

	var endScheduled:Bool = false;

	// Fin d'essai (mort/victoire, ou bouton « Revenir à l'édition ») : on rebâtit
	// l'éditeur à la bonne taille, niveau intact (autosauvegardé).
	// DIFFÉRÉ (setTimeout 0) : la fin de partie est émise DANS game.update() ; rebâtir
	// le jeu sur place y détruirait l'objet en cours d'itération -> crash. On attend
	// donc la fin de la pile courante.
	public function endPlaytest():Void {
		if (endScheduled) return;
		endScheduled = true;
		js.Browser.window.setTimeout(function() {
			endScheduled = false;
			AKApi.resetGameOver();
			AKApi.setMode(false, AKApi.getLevel()); // retour mode éditeur (progression off)
			AKApi.setEditor(true);
			setSizeAndRebuild(Cs.isBigLevel(AKApi.getLevel()));
		}, 0);
	}

	// --- Détection du mode / niveau (statique : appelé avant super()) ---

	static function isLvupMode():Bool {
		return (untyped js.Browser.window.__NC_LVUP == true) || js.Browser.location.search.indexOf("mode=lvup") >= 0;
	}

	static function isEditMode():Bool {
		return (untyped js.Browser.window.__NC_EDIT == true) || js.Browser.location.search.indexOf("mode=edit") >= 0;
	}

	static function isSpeedrunMode():Bool {
		return (untyped js.Browser.window.__NC_SPEEDRUN == true) || js.Browser.location.search.indexOf("mode=speedrun") >= 0;
	}

	// Niveau LvUP courant lu dans le cookie newcapman_lvup_level (défaut 1).
	static function readLevelCookie():Int {
		var r = ~/newcapman_lvup_level=([0-9]+)/;
		if (r.match(js.Browser.document.cookie)) {
			var n = Std.parseInt(r.matched(1));
			if (n != null && n > 0) return n;
		}
		return 1;
	}

	// Niveau édité courant (1-based) pour choisir la taille au boot de l'éditeur :
	// lu dans le curseur du store (même source que seq.Editor). Défaut 1.
	static function readEditorLevel():Int {
		try {
			var s = js.Browser.window.localStorage.getItem(Cs.EDITOR_STORE);
			if (s != null && s != "") {
				var d:Dynamic = haxe.Unserializer.run(s);
				if (d != null && d._cursor != null) return (d._cursor : Int) + 1;
			}
		} catch (e:Dynamic) {}
		return 1;
	}

	function emit(name:String, detail:Dynamic):Void {
		untyped Browser.window.dispatchEvent(new CustomEvent(name, {detail: detail}));
	}
}
