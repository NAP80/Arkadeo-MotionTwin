package seq;

import mt.bumdum9.Lib;
import Protocol;

// Pression du mode LvUP : passé coinMax*25 frames un Hunter apparaît, puis un toutes les 600 frames, jusqu'à dépasser 16 monstres.
// Utile si on veut changer le jeu plus tard
class TimeUp extends mt.fx.Sequence {
	var limit:Int;

	public function new() {
		super();
		limit = Game.me.coinMax * 25;
	}

	override function update() {
		super.update();
		if (timer > limit) {
			timer = 0;
			limit = 600;
			new fx.Spawn(4);
			if (Game.me.bads.length > 16) kill(); // 16 monstres max, après c'est kill. C'est un peu nul, faudrait changer ça.
		}
	}
}
