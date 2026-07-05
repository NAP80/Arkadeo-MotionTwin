package mode;

import Const;
import com.gen.LevelGenerator;

// Mode Progression (LvUP) : campagne de niveaux générés par LevelGenerator, avec
// serrures (coffres) à détruire pour ouvrir la sortie. Deux adaptations du port :
//  - le tutoriel cinématique (cine.create, macro DSL deepnight non portée) est retiré ;
//  - une chute dans le vide fait perdre une vie + réapparaître (au lieu du game over
//    direct de onReachBottom), tant qu'il reste des crédits.
class Progression extends Mode {
	public var exit:en.Exit;
	public var heroLeft:Bool;
	public var lid:Int;
	var powerUps:Int;

	public function new(g:Game) {
		lid = api.AKApi.getLevel();

		super(g);

		powerUps = 5 + Std.int(lid * 0.03);
		heroLeft = false;
		hero.setCredits(3);
	}

	override function isProgression():Bool {
		return true;
	}

	public function onExit():Void {
		fx.exit();
		hero.leaveGameArea();

		for (e in en.Mob.ALL)
			if (exit.atDistance(e, 200))
				e.hit(exit.xx, exit.yy, 100);

		for (e in en.mob.Walker.ALL)
			if (e.climbing)
				e.hit(hero.xx, hero.yy, 1);

		delayer.add(function() gameOver(true), 1500);
	}

	override function newLevel():Void {
		super.newLevel();

		diff = mt.MLib.round(100 * lid / com.gen.LevelGenerator.MAX_LEVEL);

		level = new Level();
		level.generateProgression(lid);
		level.render();

		hero = new en.Hero();
		exit = new en.Exit(level.lgen.exit.cx, level.lgen.exit.cy);

		// Serrures (coffres) à détruire pour ouvrir la sortie.
		for (t in level.lgen.targets)
			switch (t.type) {
				case LT_Silver: new en.mob.lock.Silver(t.cx, t.cy);
				case LT_Gold: new en.mob.lock.Golden(t.cx, t.cy);
				case LT_Movable: new en.mob.lock.Movable(t.cx, t.cy);
			}

		en.mob.Lock.prepareActionOrder();
		en.mob.Lock.activateNext();
		en.mob.Lock.activateNext();

		addMob();
		addKPoints();
	}

	override function addPowerUp():Void {
		super.addPowerUp();
		if (powerUps > 0) {
			powerUps--;

			var pt = level.getRandomSpotFar();

			var rlist = new mt.RandList();
			rlist.add(function() new en.it.Bomb(pt.cx, pt.cy), 100);
			rlist.add(function() new en.it.SuperPower(pt.cx, pt.cy), 3);
			rlist.add(function() new en.it.MegaBomb(pt.cx, pt.cy), 10);
			rlist.draw(rseed.random)();

			nextPowerUp = Const.seconds(8);
		}
	}

	public function unlockExit():Void {
		exit.open();
	}

	public function addMob():Void {
		var pt = level.getRandomSpotFar(rseed.irange(0, 1));

		if (rseed.random(100) < 3)
			new en.mob.Bomber(pt.cx, pt.cy);
		else {
			var needed = level.lgen.mobs.copy();
			for (e in en.Mob.ALL)
				needed.remove(e.type);

			if (needed.length == 0)
				return;

			var t = needed[rseed.random(needed.length)];
			switch (t) {
				case MT_Simple: new en.mob.Simple(pt.cx, pt.cy);
				case MT_Classic: new en.mob.Classic(pt.cx, pt.cy);
				case MT_Big: new en.mob.Big(pt.cx, pt.cy);
				case MT_Smart: new en.mob.Smart(pt.cx, pt.cy);
				case MT_Bomber: new en.mob.Bomber(pt.cx, pt.cy);
				case MT_Fly: new en.mob.Fly();
			}
		}

		var d = countRealMobs() < 5 ? Const.seconds(0.25) : Const.seconds(lid > 50 ? 0.75 : 1);
		cd.set("mobSpawn", d);
	}

	public function onMobKill():Void {
		cd.set("mobSpawn", cd.get("mobSpawn") + rseed.range(5, 15));
	}

	inline function needMob():Bool {
		return countRealMobs() < level.lgen.mobs.length;
	}

	override function update():Void {
		super.update();

		if (!hasTutorial()) {
			// Respawn des ennemis
			if (!hero.hasLeft && (countRealMobs() == 0 || !cd.has("mobSpawn") && needMob()))
				addMob();
		}

		// Chute dans le vide : perte d'une vie + respawn sur un sol (loseCredit gère le
		// game over s'il ne reste plus de crédit).
		if (hero != null && !hero.hasLeft && !hero.killed && hero.cy >= Const.LHEI) {
			hero.loseCredit();
			if (!hero.killed) {
				var pt = level.getRandomSpot();
				hero.setPos(pt.cx, pt.cy);
				untyped {
					hero.dx = 0;
					hero.dy = 0;
					hero.stable = false;
				}
			}
		}
	}
}
