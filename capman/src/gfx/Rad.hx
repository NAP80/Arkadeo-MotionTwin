package gfx;

import pixi.core.sprites.Sprite;

// Halo radial derrière une pièce qui court (alpha piloté par fx.RunningCoin).
class Rad extends Sprite {
	public function new() {
		super();
		this.texture = FxTex.tex("rad0");
		anchor.set(0.5, 0.5);
		untyped this.blendMode = pixi.core.Pixi.BlendModes.ADD; // Additif : Éclaircit
	}
}
