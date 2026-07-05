package seq;

import mt.bumdum9.Lib;

// SpeedRun : compte à rebours 3-2-1-Go (départ du run et après chaque mort). Met le jeu en
// pause via Game.me.stepFx (le héros ne bouge pas), mais le clavier reste suivi : on peut
// MAINTENIR une direction pendant le décompte. À « Go » : on reprend le jeu (gstep 0) et on
// démarre/reprend le chrono pile à cet instant ; au premier update le héros lit la touche
// tenue et part aussitôt dans cette direction.
class Countdown extends mt.fx.Sequence {
	static inline var PER = 40; // frames par palier (~1 s à 40 fps)

	var shown:Int;

	public function new() {
		super();
		Game.me.stepFx = this;
		shown = -1;
		majDisplay(); // affiche « 3 » tout de suite
	}

	function majDisplay() {
		var n = 3 - Std.int(timer / PER); // 3, 2, 1
		if (n != shown) {
			shown = n;
			if (n > 0) Boot.me.srCountdown(n);
		}
	}

	override function update() {
		super.update();
		if (timer >= PER * 3) {
			go();
			return;
		}
		majDisplay();
	}

	function go() {
		Game.me.stepFx = null;
		Game.me.gstep = 0;
		Boot.me.srGo();
		Boot.me.srSetRunning(true); // chrono démarre/reprend exactement à « Go »
		kill();
	}
}
