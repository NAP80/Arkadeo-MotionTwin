package seq;

import mt.bumdum9.Lib;
import Protocol;

// Victoire de niveau (LvUP) : fige le jeu, explose tous les monstres, puis AKApi.gameOver(true) (passage au niveau suivant côté host).
class Win extends mt.fx.Sequence {
	public function new() {
		super();
		Game.me.gstep = 1;
		Game.me.dif++;
		for (b in Game.me.bads) {
			var e = new mt.fx.Shake(b.root, 4, 0, 1.0, 2);
			e.timeLimit = 40;
		}
	}

	override function update() {
		super.update();
		switch (step) {
			case 0:
				for (b in Game.me.bads) {
					var ec = function(ec) return (Math.random() * 2 - 1) * ec;
					if (Game.me.gtimer % 2 == 0) {
						var mc = new gfx.PartBadExplosion();
						Level.me.dm.add(mc, Level.DP_FX);
						var p = new mt.fx.Part(mc);
						p.timer = 10;
						p.setPos(b.x + ec(16), b.y + ec(16));
					}
				}

				if (timer == 20) {
					for (b in Game.me.bads.copy())
						b.explode();
					nextStep();
				}

			case 1:
				if (timer == 40) end();
		}
	}

	public function end() {
		kill();
		switch (api.AKApi.getGameMode()) {
			case GM_PROGRESSION:
				nextStep();
				api.AKApi.gameOver(true);
			case GM_LEAGUE:
				new SpitCoins();
			default:
		}
	}
}
