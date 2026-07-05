package mt.deepnight;

import flash.display.DisplayObject;
import flash.display.Bitmap;
import flash.display.BitmapData;

// Helpers maths + flatten (rendu d'un DisplayObject en Bitmap, version PixiJS).
class Lib {
	public static inline function distanceSqr(ax:Float, ay:Float, bx:Float, by:Float):Float {
		var dx = ax - bx;
		var dy = ay - by;
		return dx * dx + dy * dy;
	}

	public static inline function distance(ax:Float, ay:Float, bx:Float, by:Float):Float {
		return Math.sqrt(distanceSqr(ax, ay, bx, by));
	}

	public static inline function iabs(v:Int):Int return v < 0 ? -v : v;
	public static inline function fabs(v:Float):Float return v < 0 ? -v : v;
	public static inline function ceil(v:Float):Int return Math.ceil(v);
	public static inline function floor(v:Float):Int return Math.floor(v);
	public static inline function round(v:Float):Int return Math.round(v);
	public static inline function toDeg(rad:Float):Float return rad * 180 / Math.PI;
	public static inline function toRad(deg:Float):Float return deg * Math.PI / 180;
	public static inline function sign(v:Float):Int return v < 0 ? -1 : (v > 0 ? 1 : 0);

	public static function rnd(min:Float, max:Float, ?sign:Bool):Float {
		var v = min + (max - min) * Math.random();
		return (sign == true && Math.random() < 0.5) ? -v : v;
	}

	public static function irnd(min:Int, max:Int, ?sign:Bool):Int {
		var v = min + Std.random(max - min + 1);
		return (sign == true && Math.random() < 0.5) ? -v : v;
	}

	public static function prettyFloat(v:Float, ?precision = 2):String {
		var m = Math.pow(10, precision);
		return Std.string(Math.round(v * m) / m);
	}

	public static function shuffleArray<T>(arr:Array<T>, rndFunc:Int->Int):Void {
		var i = arr.length;
		while (i > 1) {
			i--;
			var j = rndFunc(i + 1);
			var t = arr[i];
			arr[i] = arr[j];
			arr[j] = t;
		}
	}

	// ⚠ RENVOIE le tableau (LevelGenerator fait `x = Lib.shuffle(x, rnd)`).
	public static function shuffle<T>(arr:Array<T>, rndFunc:Int->Int):Array<T> {
		shuffleArray(arr, rndFunc);
		return arr;
	}

	// Rend un DisplayObject dans un <canvas> via le plugin extract de PIXI (renderer
	// du Boot). Repli sur bitmap vide si extract indisponible.
	public static function flatten(o:DisplayObject, ?padding:Int = 0):Bitmap {
		var w = Std.int(Math.max(1, untyped o.width)) + padding * 2;
		var h = Std.int(Math.max(1, untyped o.height)) + padding * 2;
		var bd = new BitmapData(w, h, true, 0x0);
		try {
			var ex:Dynamic = untyped Boot.me.renderer.plugins.extract;
			if (ex != null) {
				var cnv:Dynamic = ex.canvas(o);
				bd.copyFromCanvas(cnv, 0, 0, untyped cnv.width, untyped cnv.height);
			}
		} catch (e:Dynamic) {
			js.Browser.console.warn("Lib.flatten: extract indisponible (" + e + ")");
		}
		return new Bitmap(bd);
	}
}
