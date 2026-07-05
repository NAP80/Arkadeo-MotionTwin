// Découpe la texture de base (gfx.png keyé) en Frames (sous-textures) ; index =
// nom->base, timelines = nom->liste d'indices. makeTransp est un no-op (keyage fait
// hors ligne par gen_atlas.py).
package mt.pix;

import pixi.core.textures.Texture;
import pixi.core.textures.BaseTexture;

class Store {
	var lastIndex:Int;
	var ddx:Int;
	var ddy:Int;

	public var timelines:Map<String, Array<Int>>;
	public var index:Map<String, Int>;
	public var frames:Array<Frame>;
	public var base:BaseTexture;

	public function new(tex:Texture) {
		base = tex.baseTexture;
		frames = [];
		ddx = 0;
		ddy = 0;
		lastIndex = 0;
		index = new Map();
		timelines = new Map();
	}

	public function addFrame(x, y, w, h, flipX = false, flipY = false, ?rot:Float) {
		var fr = new Frame(base, x, y, w, h, flipX, flipY, rot);
		fr.ddx = ddx;
		fr.ddy = ddy;
		frames.push(fr);
		return fr;
	}

	public function slice(sx, sy, w, h, xmax = 1, ymax = 1, flipX = false, flipY = false, ?rot:Float) {
		for (y in 0...ymax)
			for (x in 0...xmax)
				addFrame(sx + x * w, sy + y * h, w, h, flipX, flipY, rot);
	}

	public function slice90(sx, sy, w, h, xmax = 1, ymax = 1) {
		for (n in 0...4)
			slice(sx, sy, w, h, xmax, ymax, false, false, n * 1.57);
	}

	public function addIndex(str:String) {
		index.set(str, frames.length);
		lastIndex = frames.length;
	}

	public function addAnim(str:String, frames:Array<Int>, ?rythm:Array<Int>, multi = 1) {
		var a = [];
		var id = 0;
		for (n in frames) {
			var max = 1;
			if (rythm != null) {
				if (id < rythm.length)
					max = rythm[id];
				else
					max = rythm[rythm.length - 1];
			}
			for (i in 0...max)
				a.push(n + lastIndex);
			id++;
		}
		if (multi > 1) {
			for (k in 0...multi)
				timelines.set(str + "_" + k, a);
		} else {
			timelines.set(str, a);
		}
	}

	public function setOffset(dx = 0, dy = 0) {
		ddx = dx;
		ddy = dy;
	}

	public function makeTransp(color) {
		// keyage blanc->alpha fait offline (gen_atlas.py) -> rien à faire au runtime.
	}

	public function get(?id:Int = 0, ?str:String):Frame {
		if (str != null) {
			var b = index.get(str);
			if (b != null)
				id += b;
		}
		return frames[id];
	}

	public function getLength() {
		return frames.length;
	}

	public function getTimeline(str:String) {
		return timelines.get(str);
	}

	public function hasTimeline(str:String) {
		return timelines.exists(str);
	}
}
