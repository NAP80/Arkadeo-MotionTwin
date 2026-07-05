package fx;

import mt.bumdum9.Lib;
import Protocol;
import pixi.core.graphics.Graphics;

// Halo coloré qui pulse (charge du Skull) ; Graphics pour un vrai blendMode ADD.
class Focus extends mt.fx.Fx {
	public var root:Graphics;

	var startRay:Float;
	var endRay:Float;
	var thc:Float;
	var spc:Float;

	public function new(startRay:Float, endRay:Float, spc = 0.1, thc = 1.0) {
		super();
		this.startRay = startRay;
		this.endRay = endRay;
		this.thc = thc;
		this.spc = spc;

		root = new Graphics();
		untyped root.blendMode = pixi.core.Pixi.BlendModes.ADD;
	}

	override function update() {
		super.update();
		coef = Math.min(coef + spc, 1);
		var co = curve(coef);

		var lim = 16;
		var color = Col.hsl2Rgb((Game.me.gtimer % lim) / lim);

		var ray = startRay + (endRay - startRay) * co;

		root.clear();
		root.beginFill(color);
		root.drawCircle(0, 0, ray);

		var cco = 1 - Math.sin(co * 3.14);
		var ray2 = ray * ((1 - thc) + cco * thc);
		root.drawCircle(0, 0, ray2);
		root.endFill();

		if (coef == 1) kill();
	}

	public function setPos(nx:Float, ny:Float) {
		root.x = nx;
		root.y = ny;
	}

	override function kill() {
		super.kill();
		// destroy (pas seulement removeChild) : libère le buffer GPU du Graphics
		// (halo de charge du Skull, créé à répétition).
		var r = root;
		root = null;
		if (r != null) untyped r.destroy();
	}
}
