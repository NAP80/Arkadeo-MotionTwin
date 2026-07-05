package en.mob;

// L'explosion est lancée immédiatement mais APRÈS super.onDie() (donc killed=true) : ainsi
// une explosion en chaîne ne re-touche pas le bombeur source (garde !e.killed), ce qui
// évite double butin et ré-entrance infinie.
class Bomber extends Walker {
	var exploded:Bool;

	public function new(x, y) {
		super(x, y);

		type = MT_Bomber;
		animBaseKey = "mob_d";
		initLife(1);
		speed *= 0.6 + 0.2 * Math.min(1, mode.diff / 200);
		radius = 14;
		exploded = false;
		barY -= 5;
	}

	function explode() {
		if (exploded)
			return;
		exploded = true;

		var r = 200;
		fx.bombExplosion(xx, yy, r);
		for (e in en.Mob.ALL)
			if (e != this && !e.killed && atDistance(e, r)) {
				e.hit(xx, yy, 5);
				e.ignoreFloors(1);
			}
	}

	override function onDie() {
		super.onDie(); // killed=true avant d'exploser
		explode(); // quelle que soit la cause de la mort
	}

	override function loot() {
		dropGold(4);
	}

	override function update() {
		super.update();

		if (!cd.hasSet("spark", rnd(4, 8)))
			fx.sparks(xx + dir * 5, yy - 50, dir);
	}
}
