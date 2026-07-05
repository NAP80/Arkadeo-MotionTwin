package mt.fx;

import pixi.core.display.Container;

// Secoue un Container puis le remet à sa place (bad.Block qui défonce un mur).
class Shake extends mt.fx.Fx {
	var mc:Container;
	var friction:Float;
	var bx:Float;
	var by:Float;
	var ddx:Float;
	var ddy:Float;
	var timer:Int;
	var mod:Int;

	public var timeLimit:Int;
	public var fitPix:Bool;

	public function new(mc:Container, dx:Float, dy:Float, frict = 0.75, mod = 2) {
		super();
		this.mod = mod;
		this.mc = mc;
		friction = frict;
		bx = mc.x;
		by = mc.y;
		ddx = dx;
		ddy = dy;
		timeLimit = -1;
		timer = 0;
		fitPix = false;
		update();
	}

	override function update() {
		timer++;
		if (timer % mod != 0) return;

		ddx *= -friction;
		ddy *= -friction;
		mc.x = bx + ddx;
		mc.y = by + ddy;
		if (fitPix) {
			mc.x = Std.int(mc.x);
			mc.y = Std.int(mc.y);
		}
		if (Math.abs(ddx) + Math.abs(ddy) < 1 || timer == timeLimit) {
			kill();
		}
	}

	override function kill() {
		mc.x = bx;
		mc.y = by;
		super.kill();
	}
}
