package fx;

import mt.bumdum9.Lib;
import Protocol;

// Apparition d'un monstre : étincelles, puis spawn à timer 40 + anneau de choc.
class Spawn extends mt.fx.Sequence {
	var bid:Int;
	var square:Square;

	public function new(bid:Int) {
		super();
		this.bid = bid;
		square = Game.me.getFreeRandomSquare();
	}

	override function update() {
		super.update();
		switch (step) {
			case 0:
				square.fxTwinkle();
				if (timer == 40) {
					nextStep();
					var b = Game.me.spawnBad(bid);
					b.setSquare(square.x, square.y);
					b.seekDir();
					b.starDust = 40;

					// Anneau de choc à l'apparition (additif, vert).
					var e = new mt.fx.ShockWave(32, 64, 0.05);
					e.curveIn(0.5);
					var pos = square.getCenter();
					e.setPos(pos.x, pos.y);
					Level.me.dm.add(e.root, Level.DP_FX);
					Col.setColor(e.root, 0x00FF88);

					kill();
				}
			default:
		}
	}
}
