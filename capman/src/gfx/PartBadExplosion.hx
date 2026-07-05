package gfx;

import pixi.core.display.Container;

// Explosion de monstre : 12 frames jouées une fois.
class PartBadExplosion extends Container {
	public function new() {
		super();
		var a:Dynamic = FxTex.anim("partbad", 12, 0.5);
		untyped a.loop = false;
		untyped this.addChild(a);
		// stop() au retrait : sinon l'AnimatedSprite reste branchée au ticker partagé.
		untyped this.on("removed", function(_) a.stop());
	}
}
