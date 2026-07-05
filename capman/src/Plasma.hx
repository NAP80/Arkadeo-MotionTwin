import mt.bumdum9.Lib;
import pixi.core.graphics.Graphics;

// Grille de chaleur XMAX×YMAX : Skull.stamp() y dépose une couleur, chaque cellule s'estompe.
// Rendu en petits disques additifs à alpha faible + BlurFilter -> glow doux.*
// C'est globalement pas comme l'original, faudrait faire mieux, mais c'est compliqué
class Plasma {
	public var gfx:Graphics;

	var col:Array<Int>;
	var a:Array<Float>;

	inline static var FADE = 0.012; // ~ -2/255 par frame, comme l'original
	inline static var MAX_A = 0.45; // alpha de dépôt (faible -> traînée discrète)

	public function new() {
		gfx = new Graphics();
		gfx.x = Cs.CX;
		gfx.y = Cs.CY;
		untyped gfx.blendMode = pixi.core.Pixi.BlendModes.ADD;
		// Flou : adoucit les disques pour éviter des cercles nets.
		try {
			untyped gfx.filters = js.Syntax.code("[new PIXI.filters.BlurFilter(6)]");
		} catch (e:Dynamic) {}

		var n = Cs.XMAX * Cs.YMAX;
		col = [for (i in 0...n) 0];
		a = [for (i in 0...n) 0.0];
	}

	public function stamp(x:Int, y:Int, color:Int) {
		if (x < 0 || y < 0 || x >= Cs.XMAX || y >= Cs.YMAX) return;
		var i = x * Cs.YMAX + y;
		col[i] = color;
		a[i] = MAX_A;
	}

	public function fade() {
		gfx.clear();
		var r = Cs.SQ * 0.5;
		var any = false;
		for (x in 0...Cs.XMAX) {
			for (y in 0...Cs.YMAX) {
				var i = x * Cs.YMAX + y;
				if (a[i] <= 0) continue;
				a[i] -= FADE;
				if (a[i] <= 0) {
					a[i] = 0;
					continue;
				}
				gfx.beginFill(col[i], a[i]);
				gfx.drawCircle(x * Cs.SQ + Cs.SQ * 0.5, y * Cs.SQ + Cs.SQ * 0.5, r);
				gfx.endFill();
				any = true;
			}
		}
		// Plasma vide -> on saute le rendu ET la passe de BlurFilter (coûteuse) sans
		// changement visuel (un plasma vide est de toute façon invisible).
		gfx.renderable = any;
	}
}
