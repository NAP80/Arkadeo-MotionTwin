package mt.fx;

import pixi.core.graphics.Graphics;

// Anneau additif qui grossit et s'estompe. Réécrit en Graphics : la version lib
// Repose sur des dégradés Flash absents en PixiJS.
class ShockWave extends mt.fx.Fx {
	public var root:Graphics;

	var min:Float;
	var max:Float;
	var spc:Float;
	var fadeStart:Float;
	var scy:Float;

	public function new(min:Float, max:Float, spc = 0.1, fadeStart = 0.0, scy = 1.0) {
		super();
		this.min = min;
		this.max = max;
		this.spc = spc;
		this.fadeStart = fadeStart;
		this.scy = scy;

		root = new Graphics();
		root.beginFill(0xFFFFFF);
		root.drawCircle(0, 0, 50);
		root.endFill();
		untyped root.blendMode = pixi.core.Pixi.BlendModes.ADD;

		curveIn(0.5);
		maj(0);
	}

	override function update() {
		super.update();
		coef = Math.min(coef + spc, 1);
		maj(coef);
		if (coef == 1) kill();
	}

	function maj(c:Float) {
		var co = curve(c);
		var sc = (min + (max - min) * co) * 0.01;
		root.scale.set(sc, sc * scy);
		if (co > fadeStart) {
			var cc = (co - fadeStart) / (1 - fadeStart);
			root.alpha = 1 - cc;
		}
	}

	public function setPos(nx:Float, ny:Float) {
		root.x = nx;
		root.y = ny;
	}

	override function kill() {
		super.kill();
		// destroy (pas seulement removeChild) : libère le buffer GPU du Graphics.
		var r = root;
		root = null;
		if (r != null) untyped r.destroy();
	}
}
