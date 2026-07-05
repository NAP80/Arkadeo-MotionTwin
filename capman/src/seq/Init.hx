package seq;

import mt.bumdum9.Lib;
import Protocol;

// Animation d'entrée : le niveau créé glisse depuis la droite (mt.fx.Tween),
// L'ancien sort par la gauche ; à la fin gstep = 0 (jouable).
class Init extends mt.fx.Sequence {
	static var SPEED = 0.05;

	public function new() {
		super();
		var mcw = Cs.WIDTH + 4;

		if (Game.me.level != null) {
			var e = new mt.fx.Tween(Game.me.level, -mcw, 0, SPEED);
			e.curveInOut();
			e.onFinish = Game.me.level.kill;
			Game.me.level = null;
		}

		Game.me.initLevel();
		Game.me.level.x = mcw;
		var e = new mt.fx.Tween(Game.me.level, 0, 0, SPEED);
		e.curveInOut();
		e.onFinish = end;
	}

	public function end() {
		if (Game.me.srWantCountdown) {
			// SpeedRun : 3-2-1-Go avant de (re)jouer (départ, changement de niveau, respawn).
			// seq.Countdown règle gstep = 0 et démarre le chrono à « Go ».
			Game.me.srWantCountdown = false;
			new seq.Countdown();
		} else {
			Game.me.gstep = 0;
		}
		kill();
	}
}
