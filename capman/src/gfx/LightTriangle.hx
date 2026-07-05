package gfx;

import pixi.core.sprites.Sprite;

// Éclat du sillage (starDust) / spawn. Teinté + passé en ADD par Square.fxTwinkle.
class LightTriangle extends Sprite {
	public function new() {
		super();
		this.texture = FxTex.tex("lt0");
		anchor.set(0.5, 0.5);
	}
}
