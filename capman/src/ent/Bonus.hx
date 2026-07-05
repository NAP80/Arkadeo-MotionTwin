package ent;

import Protocol;
import mt.bumdum9.Lib;

// Bonus posé sur une case ; ramassé au contact -> Inter.setBonus(kind).
class Bonus extends Ent {
	public var kind(default, null):BonusKind;

	var gfx:EL;

	public function new(kind:BonusKind) {
		super();
		this.kind = kind;

		gfx = new EL();
		switch (kind) {
			case BK_Jump: gfx.goto("shoe");
			case BK_Star: gfx.goto("cap");
		}
		root.addChild(gfx);
		var sq = Game.me.getFreeRandomSquare();
		this.setSquare(sq.x, sq.y);
	}

	override function update() {
		super.update();
		var h = Game.me.hero;
		if (!h.dead && h.step != JUMPING) {
			var dist = getDistTo(h);
			if (dist < ray + 6) {
				Game.me.inter.setBonus(kind);
				kill();
			}
		}
	}

	override public function kill() {
		this.square.fxTwinkle();
		this.square.fxTwinkle();
		super.kill();
	}
}
