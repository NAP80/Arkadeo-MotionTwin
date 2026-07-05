package mt.bumdum9;

import pixi.core.display.Container;
import pixi.core.display.DisplayObject;
import pixi.core.graphics.Graphics;
import pixi.core.math.Point;
import pixi.core.math.Matrix;

// Shim PixiJS de mt.bumdum9.Lib (la version lib est #if flash only).
// Fournit les types display (SP/EL/PT/MX) et les utilitaires (Col/Arr/Num/En/Tween) en PixiJS.

// --- typedefs display ---
typedef EL = mt.pix.Element;
typedef PT = Point;
typedef MX = Matrix;

// Container + .graphics (lazy) + .scaleX/.scaleY, pour que le code AS3 d'origine (mc.graphics.beginFill, mc.scaleX = ...) compile sur PixiJS.
class Sp extends Container {
	var _g:Graphics;

	public var graphics(get, never):Graphics;

	inline function get_graphics():Graphics {
		if (_g == null) {
			_g = new Graphics();
			addChildAt(_g, 0);
		}
		return _g;
	}

	public var scaleX(get, set):Float;

	inline function get_scaleX():Float
		return scale.x;

	inline function set_scaleX(v:Float):Float {
		scale.x = v;
		return v;
	}

	public var scaleY(get, set):Float;

	inline function get_scaleY():Float
		return scale.y;

	inline function set_scaleY(v:Float):Float {
		scale.y = v;
		return v;
	}

	// Container n'a pas de blendMode : holder no-op (conteneurs décoratifs).
	public var blendMode:Int = 0;

	public function new() {
		super();
	}
}

typedef SP = Sp;
typedef MC = Sp;

// --- couleur (PixiJS) ---
class Col {
	public static function colToObj(col) {
		return {r: col >> 16, g: (col >> 8) & 0xFF, b: col & 0xFF};
	}

	public static function objToCol(o:{r:Int, g:Int, b:Int}) {
		return (o.r << 16) | (o.g << 8) | o.b;
	}

	// Flash colorisait via colorTransform ; PixiJS : teinte multiplicative.
	public static function setColor(mc:DisplayObject, col:Int, dec = -255):Void {
		untyped mc.tint = col;
	}

	public static function rgb2Hex(r:Int, g:Int, b:Int) {
		return (r << 16) + (g << 8) + b;
	}

	public static function hsl2Rgb(hue = 0.0, sat = 1.0, lum = 0.5) {
		var r:Float;
		var g:Float;
		var b:Float;
		if (lum == 0) {
			r = g = b = 0;
		} else if (sat == 0) {
			r = g = b = lum;
		} else {
			var t2 = (lum <= 0.5) ? lum * (1 + sat) : lum + sat - (lum * sat);
			var t1 = 2 * lum - t2;
			var t3 = [hue + 1 / 3, hue, hue - 1 / 3];
			var clr = [0.0, 0.0, 0.0];
			for (i in 0...3) {
				if (t3[i] < 0) t3[i] += 1;
				if (t3[i] > 1) t3[i] -= 1;
				if (6 * t3[i] < 1) clr[i] = t1 + (t2 - t1) * t3[i] * 6;
				else if (2 * t3[i] < 1) clr[i] = t2;
				else if (3 * t3[i] < 2) clr[i] = (t1 + (t2 - t1) * ((2 / 3) - t3[i]) * 6);
				else clr[i] = t1;
			}
			r = clr[0];
			g = clr[1];
			b = clr[2];
		}
		return rgb2Hex(Std.int(r * 255), Std.int(g * 255), Std.int(b * 255));
	}
}

// --- Utilitaires ---
class Arr {
	public static function shuffle<A>(a:Array<A>, ?rnd:mt.Rand) {
		var f = Std.random;
		if (rnd != null)
			f = rnd.random;
		var b = [];
		while (a.length > 0)
			b.push(a.pop());
		while (b.length > 0) {
			a.insert(f(a.length + 1), b.pop());
		}
	}
}

class Num {
	public static function mm(a, b, c) {
		return Math.min(Math.max(a, b), c);
	}

	public static function clamp(a, b, c) {
		if (b < a) return a;
		if (b > c) return c;
		return b;
	}

	public static function sMod(n:Float, mod:Float) {
		if (mod == 0) return n;
		while (n >= mod) n -= mod;
		while (n < 0) n += mod;
		return n;
	}

	public static function hMod(n:Float, mod:Float) {
		while (n > mod) n -= mod * 2;
		while (n < -mod) n += mod * 2;
		return n;
	}
}

class En {
	public static function get(e, id:Int) {
		var a = Type.getEnumConstructs(e);
		return Type.createEnum(e, a[id]);
	}

	public static function next<T>(e:T):T
		return dec(e, 1);

	public static function prev<T>(e:T):T
		return dec(e, -1);

	public static function dec<T>(e:T, inc):T {
		var index = Type.enumIndex(cast e) + inc;
		var en = Type.getEnum(cast e);
		var a = Type.getEnumConstructs(en);
		var n = a.length;
		while (index >= n) index -= n;
		while (index < 0) index += n;
		return Type.createEnum(en, a[index]);
	}
}

class Tween {
	public var sx:Float;
	public var sy:Float;
	public var ex:Float;
	public var ey:Float;
	public var coef:Float;

	public function new(?sx:Float, ?sy:Float, ?ex:Float, ?ey:Float) {
		this.sx = sx;
		this.sy = sy;
		this.ex = ex;
		this.ey = ey;
		coef = 0;
	}

	public function getPos(?c:Float) {
		if (c == null) c = coef;
		return {x: sx + (ex - sx) * c, y: sy + (ey - sy) * c};
	}

	public function getDist() {
		var dx = ex - sx;
		var dy = ey - sy;
		return Math.sqrt(dx * dx + dy * dy);
	}

	public function getAngle() {
		var dx = ex - sx;
		var dy = ey - sy;
		return Math.atan2(dy, dx);
	}
}
