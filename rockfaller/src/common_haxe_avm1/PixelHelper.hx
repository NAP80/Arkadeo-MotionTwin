package common_haxe_avm1;

import pixi.core.display.DisplayObject;
import pixi.core.graphics.Graphics;
import pixi.core.math.Matrix;
import pixi.core.math.Point;
import pixi.core.math.shapes.Rectangle;
import pixi.core.sprites.Sprite;
import pixi.core.textures.RenderTexture;
import pixi.core.textures.Texture;
import haxe.io.UInt8Array;

using Lambda;
using Std;

class PixelHelper {
	var pixels:UInt8Array;

	public var width:Int;
	public var height:Int;

	static public function clearRect(onto:RenderTexture, rectangle:Rectangle) {
		var gfx = new Graphics();
		gfx.beginFill(0x000000, 1);
		gfx.drawRect(rectangle.x, rectangle.y, rectangle.width, rectangle.height);
		untyped gfx.blendMode = PIXI.BLEND_MODES.ERASE;
		draw(onto, gfx, new Matrix());
	}

	static public function fillRect(onto:RenderTexture, rectangle:Rectangle, col:Int, ?alpha:Int, ?clear:Bool) {
		if (clear) {
			clearRect(onto, rectangle);
		}
		var gfx = new Graphics();
		gfx.beginFill(col, alpha == null ? 1 : alpha / 255);
		gfx.drawRect(rectangle.x, rectangle.y, rectangle.width, rectangle.height);
		draw(onto, gfx, new Matrix());
	}

	static public function fill(onto:RenderTexture, col:Int, ?alpha:Int) {
		var gfx = new Graphics();
		gfx.beginFill(col, alpha == null ? 1 : alpha / 255);
		gfx.drawRect(0, 0, onto.width, onto.height);
		draw(onto, gfx, new Matrix());
	}

	static public function draw(onto:RenderTexture, object:DisplayObject, matrix:Matrix) {
		(untyped common_haxe_avm1.MouseManager.getApp().renderer).render(object, cast {renderTexture: onto, clear: false, transform: matrix});
	}

	static public function extract(texture:RenderTexture) {
		return new PixelHelper(untyped common_haxe_avm1.MouseManager.getApp().renderer.plugins.extract.pixels(texture), texture.width.int(),
			texture.height.int());
	}

	static public function copyPixels(onto:RenderTexture, source:Texture, sourceRect:Rectangle, destPoint:Point) {
		var realRect = new Rectangle(source.frame.x + sourceRect.x, source.frame.y + sourceRect.y, sourceRect.width, sourceRect.height);
		var frame = new Texture(source.baseTexture, realRect);
		var sprite = new Sprite(frame);
		sprite.position.set(destPoint.x, destPoint.y);
		draw(onto, sprite, new Matrix());
		frame.destroy(false);
	}

	public function new(pixels:UInt8Array, width:Int, height:Int) {
		this.pixels = pixels;
		this.width = width;
		this.height = height;
	}

	public function getPixelAlpha(x:Int, y:Int):Int {
		var pIndex = (y * width + x) * 4;
		return pixels[pIndex + 3];
	}

	public function getPixel(x:Int, y:Int):Int {
		var pIndex = (y * width + x) * 4;

		return pixels[pIndex] << 16 | pixels[pIndex + 1] << 8 | pixels[pIndex + 2];
	}
}
