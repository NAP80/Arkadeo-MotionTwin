package mt.deepnight;

// Couleurs : addAlphaF (ARGB), HSL, et filtres de teinte/luminosité en ColorMatrix.
class Color {
	// Ajoute un canal alpha (0..1) à une couleur RGB -> ARGB.
	public static inline function addAlphaF(col:Int, ?a:Float = 1.0):Int {
		return (Std.int(a * 255) << 24) | (col & 0xFFFFFF);
	}

	public static inline function getAlphaf(col:Int):Float {
		return ((col >>> 24) & 0xFF) / 255;
	}

	// HSL -> RGB.
	public static function makeColorHsl(h:Float, ?s:Float = 1.0, ?l:Float = 0.5):Int {
		var r = l, g = l, b = l;
		if (s > 0) {
			function hue(p:Float, q:Float, t:Float):Float {
				if (t < 0) t += 1;
				if (t > 1) t -= 1;
				if (t < 1 / 6) return p + (q - p) * 6 * t;
				if (t < 1 / 2) return q;
				if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
				return p;
			}
			var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
			var p = 2 * l - q;
			r = hue(p, q, h + 1 / 3);
			g = hue(p, q, h);
			b = hue(p, q, h - 1 / 3);
		}
		return (Std.int(r * 255) << 16) | (Std.int(g * 255) << 8) | Std.int(b * 255);
	}

	public static function randomColor(hue:Float, ?sat:Float = 1.0, ?lum:Float = 0.5):Int {
		return makeColorHsl(hue, sat, lum);
	}

	// Matrices 5×4 reprises telles quelles des libs d'origine : même format que PIXI,
	// et offsets nuls ici (pas de souci d'échelle 0..1 vs 0..255).
	public static function getColorizeFilter(col:Int, ?ratioNewColor:Float = 1.0, ?ratioOldColor:Float = 1.0):Dynamic {
		var r = ratioNewColor * ((col >> 16) & 0xFF) / 255;
		var g = ratioNewColor * ((col >> 8) & 0xFF) / 255;
		var b = ratioNewColor * (col & 0xFF) / 255;
		var m:Array<Float> = [
			ratioOldColor + r, r, r, 0, 0,
			g, ratioOldColor + g, g, 0, 0,
			b, b, ratioOldColor + b, 0, 0,
			0, 0, 0, 1.0, 0
		];
		var f:Dynamic = js.Syntax.code("new PIXI.filters.ColorMatrixFilter()");
		untyped f.matrix = m;
		return f;
	}

	public static function getBrightnessFilter(ratio:Float):Dynamic {
		var r = 1 + ratio; // ratio ∈ [-1..1] : -0.5 = assombri, +0.1 = éclairci
		var m:Array<Float> = [
			r, 0, 0, 0, 0,
			0, r, 0, 0, 0,
			0, 0, r, 0, 0,
			0, 0, 0, 1.0, 0
		];
		var f:Dynamic = js.Syntax.code("new PIXI.filters.ColorMatrixFilter()");
		untyped f.matrix = m;
		return f;
	}
}
