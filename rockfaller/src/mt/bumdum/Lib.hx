package mt.bumdum;

import pixi.filters.colormatrix.ColorMatrixFilter;
import pixi.core.display.DisplayObject;
import pixi.filters.blur.BlurFilter;
import pixi.filters.extras.GlowFilter;
import pixi.filters.extras.ColorReplaceFilter;
import common_haxe_avm1.display.ASprite;

typedef Point = {x:Float, y:Float}

typedef PointWithGetter_ = {
	var x(get, set):Float;
	var y(get, set):Float;
}

class PointWrapper {
	var p:Point;

	public var x(get, set):Float;
	public var y(get, set):Float;

	inline function get_x():Float
		return p.x;

	inline function get_y():Float
		return p.y;

	inline function set_x(v:Float):Float
		return p.x = v;

	inline function set_y(v:Float):Float
		return p.y = v;

	public inline function new(p:Point) {
		this.p = p;
	}
}

@:forward
abstract PointWithGetter(PointWithGetter_) from PointWithGetter_ {
	@:to inline function toPoint():Point
		return {x: this.x, y: this.y};

	@:from static inline function fromObject(p:Point):PointWithGetter {
		return new PointWrapper(p);
	}
}

class En {
	inline static public function index(e:Dynamic) {
		return Type.enumIndex(e);
	}
	/*
		static public function get(e:Enum,idx:Int,?params:Array<Dynamic>) : Dynamic {
			return TypecreateEnum(e,Type.getEnumConstructs(e)[idx],params);
	}*/
}

class Num {
	public static var COLLISION_QUANT = 100;

	public static inline function q(v:Float):Float {
		return Math.round(v * COLLISION_QUANT) / COLLISION_QUANT;
	}

	static public function mm(a, b, c) {
		return Math.min(Math.max(a, b), c);
	}

	static public function sMod(n:Float, mod:Float) {
		if (mod == 0 || mod == null || n == null)
			return null;
		while (n >= mod)
			n -= mod;
		while (n < 0)
			n += mod;
		return n;
	}

	static public function hMod(n:Float, mod:Float) {
		if (mod == 0 || mod == null || n == null)
			return null;
		while (n > mod)
			n -= mod * 2;
		while (n < -mod)
			n += mod * 2;
		return n;
	}

	static public function rnd(n:Int, f:Float) {
		return Std.int(Math.pow(Math.random(), f) * n);
	}
}

class Col {
	static public function colToObj(col) {
		return {
			r: col >> 16,
			g: (col >> 8) & 0xFF,
			b: col & 0xFF
		};
	}

	static public function objToCol(o) {
		return (o.r << 16) | (o.g << 8) | o.b;
	}

	static public function colToObj32(col) {
		return {
			a: col >>> 24,
			r: (col >> 16) & 0xFF,
			g: (col >> 8) & 0xFF,
			b: col & 0xFF
		};
	}

	static public function objToCol32(o) {
		return (o.r << 24) | (o.g << 16) | (o.b << 8) | o.a;
	}

	static public function setPercentColor(mc:ASprite, prc:Float, col:Int, ?inc:Float, ?alpha = 100) {
		var pct = Math.min(Math.max(prc, 0), 100);
		var c = pct / 100;
		var m = 1 - c;
		var i = (inc == null ? 0 : inc) / 255;
		var a = Math.min(Math.max(alpha, 0), 100) / 100;

		var r = ((col >> 16) & 0xFF) / 255;
		var g = ((col >> 8) & 0xFF) / 255;
		var b = (col & 0xFF) / 255;

		var cm:ColorMatrixFilter = cast Reflect.field(mc, "__percentColorFilter");
		if (cm == null) {
			cm = new ColorMatrixFilter();
			Reflect.setField(mc, "__percentColorFilter", cm);
		}

		cm.matrix = [
			m, 0, 0,         0, c * (r + i),
			0, m, 0,         0, c * (g + i),
			0, 0, m,         0, c * (b + i),
			0, 0, 0, m + c * a,           0
		];

		var currentFilters:Array<Dynamic> = cast mc.filters;
		var nextFilters:Array<Dynamic> = [];
		if (currentFilters != null) {
			for (f in currentFilters) {
				if (f != cm)
					nextFilters.push(f);
			}
		}

		if (pct > 0) {
			nextFilters.push(cm);
		}

		mc.filters = nextFilters.length == 0 ? null : cast nextFilters;
	}

	static public function setColor(mc, col:Int, ?dec) {
		mc.tint = col;
	}

	static public function mergeCol(col:Int, col2:Int, ?c) {
		if (c == null)
			c = 0.5;
		var o = Col.colToObj(col);
		var o2 = Col.colToObj(col2);
		var o3 = {
			r: Std.int(o.r * c + o2.r * (1 - c)),
			g: Std.int(o.g * c + o2.g * (1 - c)),
			b: Std.int(o.b * c + o2.b * (1 - c))
		}
		return Col.objToCol(o3);
	}

	static public function mergeCol32(col:Int, col2:Int, ?c) {
		if (c == null)
			c = 0.5;
		var o = Col.colToObj32(col);
		var o2 = Col.colToObj32(col2);
		var o3 = {
			r: Std.int(o.r * c + o2.r * (1 - c)),
			g: Std.int(o.g * c + o2.g * (1 - c)),
			b: Std.int(o.b * c + o2.b * (1 - c)),
			a: Std.int(o.a * c + o2.a * (1 - c))
		}
		return Col.objToCol32(o3);
	}

	static public function getRainbow(?c) {
		if (c == null)
			c = Math.random();
		var max = 3;
		var a:Array<Float> = [0.0, 0.0, 0.0];
		var part = (1 / max * 2);
		for (i in 0...max) {
			var med = part + i * 2 * part;
			var dif = Num.hMod(med - c, 0.5);
			a[i] = Math.min(1.5 - Math.abs(dif) * 3, 1);
		}
		return {
			r: Std.int(a[0] * 255),
			g: Std.int(a[1] * 255),
			b: Std.int(a[2] * 255)
		}
	}

	static public function shuffle(col:Int, inc:Int) {
		var o = colToObj(col);
		o.r = Std.int(Num.mm(0, o.r + (Math.random() * 2 - 1) * inc, 255));
		o.g = Std.int(Num.mm(0, o.g + (Math.random() * 2 - 1) * inc, 255));
		o.b = Std.int(Num.mm(0, o.b + (Math.random() * 2 - 1) * inc, 255));
		return objToCol(o);
	}

	static public function getWeb(col) {
		return "#" + StringTools.hex(col);
	}

	// WHITE IN YOUR BASE ------------------------------------ :)

	public static function rgb2Hex(r:Int, g:Int, b:Int, a:Bool = false) {
		if (!a)
			return (r << 16) + (g << 8) + b;
		var o = colToObj32((r << 16) + (g << 8) + b);
		o.a = 0xFF;
		return objToCol32(o);
	}

	public static function addAlpha(col:Int):Int {
		var o = colToObj32(col);
		o.a = 0xFF;
		return objToCol32(o);
	}

	public static function brighten(rgb:Int, percent:Int) {
		return mergeCol(rgb, 0xFFFFFF, percent / 100);
	}

	public static function darken(rgb:Int, percent:Int) {
		var col = colToObj(rgb);
		col.r -= Math.floor(col.r * percent / 100);
		col.g -= Math.floor(col.g * percent / 100);
		col.b -= Math.floor(col.b * percent / 100);
		return objToCol(col);
	}

	public static function cmyk2rbg(c:Int, m:Int, y:Int, k:Int):Int {
		// adapted from http://arcscripts.esri.com/details.asp?dbid=11276
		var r = 0;
		var g = 0;
		var b = 0;

		if (c + k > 100 || m + k > 100 || y + k > 100) {
			r = -99;
			g = -99;
			b = -99;

			var max = c > m ? c : m;
			max = max > y ? max : y;

			if (max == c)
				r = 0;
			if (max == m)
				g = 0;
			if (max == k)
				b = 0;

			var kk = 100 - max;
			if (r > 0 || r < 0)
				r = Math.round((1 - ((c + kk) / 100)) * 255);
			if (g > 0 || g < 0)
				g = Math.round((1 - ((m + kk) / 100)) * 255);
			if (b > 0 || b < 0)
				b = Math.round((1 - ((y + kk) / 100)) * 255);

			return objToCol({r: r, g: g, b: b});
		}

		r = Math.round((1 - ((c + k) / 100)) * 255);
		g = Math.round((1 - ((m + k) / 100)) * 255);
		b = Math.round((1 - ((y + k) / 100)) * 255);

		return objToCol({r: r, g: g, b: b});
	}
	/*
		static public function setColorMatrix(mc, m, dec){
			if(dec!=null){
				m = m.duplicate();
				for( i in 0...3 ){
					m[4+5*i] = dec;
				}
			}
			var fl = new flash.filters.ColorMatrixFilter();

			fl.matrix = m;
			mc.filters = [fl];
		}
	 */
}

class Str {
	static public function searchAndReplace(str:String, search:String, replace:String) {
		return str.split(search).join(replace);
	}
}

class Filt {
	static public function glow(mc:DisplayObject, distance = 2, strength:Float = 1, color = 0, inner = false):GlowFilter {
		var f = Type.createInstance(GlowFilter, [
			{
				distance: distance,
				outerStrength: inner ? 0 : strength,
				innerStrength: inner ? strength : 0,
				color: color
			}
		]);
		if (mc.filters == null) {
			mc.filters = [f];
			return f;
		}

		mc.filters.push(f);

		return f;
	}

	static public function blur(mc:DisplayObject, blurX:Float = 0, blurY:Float = 0) {
		var f = new BlurFilter();
		f.blurX = blurX;
		f.blurY = blurY;

		if (mc.filters == null) {
			mc.filters = [f];
			return;
		}

		mc.filters.push(f);
	}

	static public function replaceColor(mc:DisplayObject, orig:Int, target:Int, epsilon:Float) {
		var f = new ColorReplaceFilter(untyped orig, untyped target, epsilon);

		if (mc.filters == null) {
			mc.filters = [untyped f];
			return;
		}

		mc.filters.push(untyped f);
	}

	static public function grey(mc:ASprite, ?c:Float, ?inc:Int, ?o, ?m1) {
		/*if (c == null)
				c = 1;
			if (inc == null)
				inc = 0;
			if (o == null)
				o = {r: 0, g: 0, b: 0};

			var m0 = [
				1, 0, 0, 0, 0,
				0, 1, 0, 0, 0,
				0, 0, 1, 0, 0,
				0, 0, 0, 1, 0
			];

			if (m1 == null) {
				var r = 0.25;
				var g = 0.15;
				var b = 0.6;
				m1 = [
					r, g, b, 0, o.r + inc,
					r, g, b, 0, o.g + inc,
					r, g, b, 0, o.b + inc,
					0, 0, 0, 1,         0,

				];
			}

			var m = [];
			for (i in 0...m0.length) {
				m[i] = m0[i] * (1 - c) + m1[i] * c;
			}

			var fl = new flash.filters.ColorMatrixFilter();
			fl.matrix = m;

			var a = mc.filters;
			a.push(fl);
			mc.filters = a; */

		trace("FIXME");
	}
}

class Tween {
	public var sx:Float;
	public var sy:Float;
	public var ex:Float;
	public var ey:Float;

	public function new(?sx:Float, ?sy:Float, ?ex:Float, ?ey:Float) {
		this.sx = sx;
		this.sy = sy;
		this.ex = ex;
		this.ey = ey;
	}

	public function getPos(c:Float) {
		return {
			x: sx * (1 - c) + ex * c,
			y: sy * (1 - c) + ey * c
		};
	}
}
