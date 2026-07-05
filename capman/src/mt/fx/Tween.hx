package mt.fx;

import pixi.core.display.Container;

// Anime la position d'un Container de (sx,sy) vers (ex,ey) ; utilisé par seq.Init.
class Tween extends mt.fx.Fx {
	var root:Container;

	public var speed:Float;
	public var fitPix:Bool;
	public var tw:mt.bumdum9.Lib.Tween;

	public function new(mc:Container, ex:Float, ey:Float, sp = 0.1, ?sx:Float, ?sy:Float, ?pManager) {
		super(pManager);
		root = mc;
		speed = sp;
		if (sx == null) sx = root.x;
		if (sy == null) sy = root.y;
		tw = new mt.bumdum9.Lib.Tween(sx, sy, ex, ey);
	}

	override function update() {
		coef = Math.min(coef + speed, 1);
		var c = curve(coef);
		var p = tw.getPos(c);
		root.x = p.x;
		root.y = p.y;
		if (fitPix) {
			root.x = Std.int(root.x);
			root.y = Std.int(root.y);
		}
		if (coef == 1) kill();
	}
}
