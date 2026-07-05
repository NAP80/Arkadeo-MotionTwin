package flash.filters;

// PIXI.filters.BlurFilter est fourni par pixi-legacy (≠ Glow/DropShadow qui exigent
// pixi-filters, non vendoré) → on adosse flash.filters.BlurFilter à un vrai flou PixiJS.
@:native("PIXI.filters.BlurFilter")
private extern class PixiBlur extends pixi.core.renderers.webgl.filters.Filter {
	function new(?strength:Float, ?quality:Float, ?resolution:Float, ?kernelSize:Int);
	var blur:Float;
	var blurX:Float;
	var blurY:Float;
	var quality:Int;
}

class BlurFilter extends PixiBlur {
	public function new(?blurX:Float = 4.0, ?blurY:Float = 4.0, ?quality:Int = 1) {
		super(Math.max(blurX, blurY), quality > 0 ? quality : 1);
		this.blurX = blurX;
		this.blurY = blurY;
	}
}
