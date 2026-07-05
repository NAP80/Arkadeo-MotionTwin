package bad;

import mt.bumdum9.Lib;
import Protocol;

// Cycle : charge (SPECIAL, halo fx.Focus qui se resserre) -> burst -> dash rapide.
// Pendant le dash il sème des particules (dashTrail) et marque le plasma (stamp).
class Skull extends ent.Bad {
	var fwait:Int;

	inline static var CHASE_SPEED = 3.5;

	public function new() {
		bid = 1;
		super();
		fwait = 5 + Game.me.rnd(5);
		spc = 0.03;

		stopChase();
		skin.play("skull_base");
	}

	override function update() {
		super.update();
		if (step == MOVE && speedMult > 2.0)
			dashTrail();
	}

	// Particules multicolores additives semées le long du dash.
	function dashTrail() {
		var ec = function() return (Math.random() * 2 - 1) * 9;
		for (i in 0...3) {
			var g = new pixi.core.graphics.Graphics();
			g.beginFill(Col.hsl2Rgb(Math.random(), 1.0, 0.62));
			g.drawCircle(0, 0, 1.1 + Math.random() * 1.2);
			g.endFill();
			untyped g.blendMode = pixi.core.Pixi.BlendModes.ADD;
			Level.me.dm.add(g, Level.DP_FX);

			var p = new mt.fx.Part(g);
			p.setPos(root.x + ec(), root.y + ec());
			p.vx = ec() * 0.25;
			p.vy = ec() * 0.25;
			p.frict = 0.9;
			p.weight = -0.015;
			p.timer = 14 + Std.random(22);
			p.fadeLimit = p.timer;
			p.fadeType = 1;
		}
	}

	override function checkMove() {
		super.checkMove();
		fwait--;
		switch (step) {
			case MOVE:
				if (speedMult > 2.0) stamp();
				if (fwait == 0) {
					if (speedMult < CHASE_SPEED) initChase();
					else stopChase();
				}
			case SPECIAL:
			default:
		}
	}

	function initChase() {
		var e = new fx.Focus(32, 5, 0.04, 0.6);
		Level.me.dm.add(e.root, Level.DP_FX);
		step = SPECIAL;
		e.setPos(root.x, root.y);
		e.curveIn(2);
		e.onFinish = release;
		hunter = 20;
		speedMult = CHASE_SPEED;
		uturn = true;
		if (skin.anim != null) skin.anim.stop();
	}

	function stopChase() {
		speedMult = 1.0;
		fwait = 5 + Game.me.rnd(15);
		hunter = 4;
		speedMult = 1.0;
		uturn = false;
		skin.play("skull_base");
	}

	function release() {
		stamp();
		for (i in 0...3) {
			var e = new fx.Focus(0, 26 - i * 7, 0.1 + i * 0.025, 0.1);
			e.setPos(root.x, root.y);
			Level.me.dm.add(e.root, Level.DP_FX);
			if (i == 0) e.onFinish = dash;
		}
	}

	function dash() {
		step = MOVE;
		fwait = 7;
		skin.play("skull_fire");
	}

	function stamp() {
		var cycle = 80;
		var color = Col.hsl2Rgb((Game.me.gtimer % cycle) / cycle);
		if (Game.me.plasma != null) Game.me.plasma.stamp(square.x, square.y, color);
	}
}
