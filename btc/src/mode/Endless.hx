package mode;

import Const;

// Mode « Défi Coffres » : variante de League (même principe et même courbe de
// difficulté `diff`), mais :
//  - map fixe à sol plein (Level.generateEndless, sans vide) ;
//  - pas de score Gold (isLeague()=false → Mob.dropGold inhibé) ni de KPoints ;
//  - 2 coffres affichés en permanence à l'infini (pas de porte de fin), de plus en
//    plus durs ; le « score » = nombre de coffres détruits (classement Défi).
class Endless extends League {
	public var chestsDestroyed:Int = 0;
	static inline var ACTIVE = 2; // coffres présents simultanément

	public function new(g) {
		super(g);
	}

	// false → pas de drop de Gold (Mob.dropGold est gated `if(!isLeague()) return`) et
	// Level utilise mode.seed. Le spawn d'ennemis / la difficulté de League ne dépendent
	// pas de isLeague() → restent actifs par héritage.
	override function isLeague() {
		return false;
	}

	override function newLevel() {
		// On ne veut pas League.newLevel (testLevel + KPoints) : on reprend juste le
		// minimum de Mode.newLevel (nextPowerUp) puis on monte notre map + nos coffres.
		nextPowerUp = Const.seconds( rseed.irange(2, 5) );

		level = new Level();
		level.generateEndless();
		level.render();

		cd.unset("mobSpawn");

		hero = new en.Hero();

		for( i in 0...ACTIVE )
			spawnChest();
	}

	// Appelé par en.mob.Lock.onDie (shadow) à la destruction d'un coffre (hors Progression).
	public function onChestDestroyed() {
		chestsDestroyed++;
		// « score » = coffres détruits (réutilise le canal de score, le Gold est inhibé).
		if( Boot.me!=null )
			Boot.me.addScore(chestsDestroyed);
		spawnChest(); // on en remet un → toujours 2 coffres à l'écran
	}

	// Place un coffre actif sur un spot de sol éloigné du héros. Difficulté croissante :
	// Silver au début, puis Movable, puis Golden.
	function spawnChest() {
		var pt = level.getRandomSpotFar();
		if( pt==null )
			return;

		var r = rseed.random(100);
		var lk:en.mob.Lock;
		if( chestsDestroyed>=12 && r<25 )
			lk = new en.mob.lock.Golden(pt.cx, pt.cy);
		else if( chestsDestroyed>=5 && r<55 )
			lk = new en.mob.lock.Movable(pt.cx, pt.cy);
		else
			lk = new en.mob.lock.Silver(pt.cx, pt.cy);

		lk.activate(); // actif tout de suite (pas d'ordre d'activation comme en Progression)
	}
}
