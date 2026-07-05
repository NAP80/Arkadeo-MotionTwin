package flash.filters;

// Base des filtres Flash. Étend PIXI.Filter (pass-through) pour que
// `obj.filters = [new GlowFilter(...)]` type-check contre le champ hérité
// filters:Array<pixi.Filter>.
class BitmapFilter extends pixi.core.renderers.webgl.filters.Filter {
	public function new() {
		super();
	}
}
