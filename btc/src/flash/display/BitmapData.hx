package flash.display;

import flash.geom.Rectangle;
import flash.geom.Point;

// flash.display.BitmapData adossé à un <canvas> 2D hors-écran.
// getTexture() expose le canvas comme PIXI.Texture.
class BitmapData {
	public var width:Int;
	public var height:Int;
	public var transparent:Bool;

	var canvas:Dynamic;
	var ctx:Dynamic;
	var tex:Dynamic; // PIXI.Texture (paresseux)
	var texDirty:Bool;
	var _imgData:Dynamic; // cache ImageData (invalidé à chaque mutation)

	public function new(width:Int, height:Int, ?transparent:Bool = true, ?fillColor:Int = 0x0) {
		this.width = width;
		this.height = height;
		this.transparent = transparent;
		canvas = js.Browser.document.createElement("canvas");
		canvas.width = width;
		canvas.height = height;
		ctx = canvas.getContext("2d");
		texDirty = true;
		if (fillColor != 0x0 || !transparent)
			fillRect(new Rectangle(0, 0, width, height), fillColor);
	}

	public var rect(get, never):Rectangle;
	inline function get_rect():Rectangle return new Rectangle(0, 0, width, height);

	inline function dirty():Void {
		texDirty = true;
		_imgData = null;
		// Une PIXI.Texture déjà attachée doit être ré-uploadée, sinon la mutation reste figée.
		if (tex != null) {
			untyped tex.update();
			texDirty = false;
		}
	}

	// ImageData complet caché (recalculé après mutation).
	function pixels():Dynamic {
		if (_imgData == null)
			_imgData = ctx.getImageData(0, 0, width, height);
		return _imgData;
	}

	inline function argb(c:Int):String {
		var a = transparent ? ((c >>> 24) & 0xFF) / 255 : 1.0;
		var r = (c >> 16) & 0xFF;
		var g = (c >> 8) & 0xFF;
		var b = c & 0xFF;
		return "rgba(" + r + "," + g + "," + b + "," + a + ")";
	}

	public function fillRect(r:Rectangle, color:Int):Void {
		ctx.clearRect(r.x, r.y, r.width, r.height);
		ctx.fillStyle = argb(color);
		ctx.fillRect(r.x, r.y, r.width, r.height);
		dirty();
	}

	public function getPixel(x:Int, y:Int):Int {
		var d:Dynamic = pixels().data;
		var i = (y * width + x) * 4;
		return (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
	}

	public function getPixel32(x:Int, y:Int):Int {
		var d:Dynamic = pixels().data;
		var i = (y * width + x) * 4;
		return (d[i + 3] << 24) | (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
	}

	public function setPixel(x:Int, y:Int, color:Int):Void {
		ctx.fillStyle = "rgb(" + ((color >> 16) & 0xFF) + "," + ((color >> 8) & 0xFF) + "," + (color & 0xFF) + ")";
		ctx.fillRect(x, y, 1, 1);
		dirty();
	}

	public function setPixel32(x:Int, y:Int, color:Int):Void {
		ctx.fillStyle = argb(color);
		ctx.fillRect(x, y, 1, 1);
		dirty();
	}

	// Boîte englobante des pixels dont (ARGB & mask) == (color & mask).
	public function getColorBoundsRect(mask:Int, color:Int, ?findColor:Bool = true):Rectangle {
		var d:Dynamic = pixels().data;
		var target = color & mask;
		var minX = width, minY = height, maxX = -1, maxY = -1;
		var i = 0;
		for (y in 0...height) {
			for (x in 0...width) {
				var argb = (d[i + 3] << 24) | (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
				var match = (argb & mask) == target;
				if (findColor ? match : !match) {
					if (x < minX) minX = x;
					if (x > maxX) maxX = x;
					if (y < minY) minY = y;
					if (y > maxY) maxY = y;
				}
				i += 4;
			}
		}
		if (maxX < 0)
			return new Rectangle(0, 0, 0, 0);
		return new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
	}

	// Crop d'une région d'un canvas/Image (atlas) dans cette BitmapData.
	public function copyFromCanvas(img:Dynamic, sx:Int, sy:Int, sw:Int, sh:Int):Void {
		try {
			ctx.drawImage(img, sx, sy, sw, sh, 0, 0, sw, sh);
			dirty();
		} catch (e:Dynamic) {}
	}

	// ⚠ matrix/colorTransform TYPÉS (pas Dynamic) : l'appelant écrit souvent
	// `draw(src, colorTransform, blendMode)` en comptant sur le saut d'argument optionnel
	// de Haxe (un ColorTransform n'est pas un Matrix → matrix sauté). Avec des params
	// Dynamic, Haxe ne saute pas → les args se décalent.
	public function draw(source:Dynamic, ?matrix:flash.geom.Matrix, ?colorTransform:flash.geom.ColorTransform, ?blendMode:Dynamic, ?clipRect:Dynamic, ?smoothing:Dynamic):Void {
		try {
			var img = Std.isOfType(source, BitmapData) ? (cast source : BitmapData).canvas : source;
			ctx.save();
			// alpha global depuis le ColorTransform
			if (colorTransform != null) {
				var am:Dynamic = untyped colorTransform.alphaMultiplier;
				if (am != null) ctx.globalAlpha = am;
			}
			// blendMode Flash → composite canvas
			if (blendMode != null) {
				var op = blendToComposite(blendMode);
				if (op != null) ctx.globalCompositeOperation = op;
			}
			ctx.drawImage(img, 0, 0);
			ctx.restore();
			dirty();
		} catch (e:Dynamic) {}
	}

	static function blendToComposite(b:Dynamic):Null<String> {
		return switch (cast b : flash.display.BlendMode) {
			case OVERLAY: "overlay";
			case MULTIPLY: "multiply";
			case SCREEN: "screen";
			case ADD: "lighter";
			default: null;
		}
	}

	public function copyPixels(source:BitmapData, srcRect:Rectangle, dstPoint:Point, ?alphaBitmapData:Dynamic, ?alphaPoint:Dynamic, ?mergeAlpha:Bool):Void {
		try {
			ctx.drawImage(source.canvas, srcRect.x, srcRect.y, srcRect.width, srcRect.height, dstPoint.x, dstPoint.y, srcRect.width, srcRect.height);
			dirty();
		} catch (e:Dynamic) {}
	}

	// Approximation : bruit gris par petits blocs, centré sur ~128 pour qu'un draw
	// OVERLAY/SCREEN reste quasi-neutre (un perlin noir assombrirait le voile).
	public function perlinNoise(baseX:Float, baseY:Float, numOctaves:Int, randomSeed:Int, stitch:Bool, fractalNoise:Bool, ?channelOptions:Int, ?grayScale:Bool, ?offsets:Dynamic):Void {
		var img = ctx.createImageData(width, height);
		var data = img.data;
		var block = 6;
		var by = 0;
		while (by < height) {
			var bx = 0;
			while (bx < width) {
				var v = 124 + Std.random(12); // gris quasi-neutre (~124..136)
				var yy = by;
				while (yy < by + block && yy < height) {
					var xx = bx;
					while (xx < bx + block && xx < width) {
						var i = (yy * width + xx) * 4;
						data[i] = v;
						data[i + 1] = v;
						data[i + 2] = v;
						data[i + 3] = 255;
						xx++;
					}
					yy++;
				}
				bx += block;
			}
			by += block;
		}
		ctx.putImageData(img, 0, 0);
		dirty();
	}
	public function copyChannel(source:Dynamic, srcRect:Rectangle, dstPoint:Point, srcChannel:Int, dstChannel:Int):Void {}
	public function applyFilter(source:Dynamic, srcRect:Rectangle, dstPoint:Point, filter:Dynamic):Void {}

	public function clone():BitmapData {
		var b = new BitmapData(width, height, transparent, 0x0);
		b.ctx.drawImage(canvas, 0, 0);
		b.dirty();
		return b;
	}

	public function dispose():Void {
		canvas = null;
		ctx = null;
		tex = null;
		_imgData = null;
	}

	public function getTexture():Dynamic {
		if (tex == null)
			tex = js.Syntax.code("PIXI.Texture.from({0})", canvas);
		else if (texDirty)
			tex.update();
		texDirty = false;
		return tex;
	}

	public function getCanvas():Dynamic return canvas;

	public static function fromImage(img:Dynamic):BitmapData {
		var b = new BitmapData(img.width, img.height, true, 0x0);
		b.ctx.drawImage(img, 0, 0);
		b.dirty();
		return b;
	}
}
