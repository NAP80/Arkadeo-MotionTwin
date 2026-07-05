// Un Frame = un sous-rectangle de la texture de base -> une Texture PixiJS.
package mt.pix;

import pixi.core.textures.Texture;
import pixi.core.textures.BaseTexture;
import pixi.core.math.shapes.Rectangle;

class Frame {
	public var swapX:Bool;
	public var swapY:Bool;
	public var rot:Null<Float>;

	public var ddx:Int;
	public var ddy:Int;

	public var x:Int;
	public var y:Int;
	public var width:Int;
	public var height:Int;
	public var texture:Texture;

	public function new(base:BaseTexture, x:Int, y:Int, w:Int, h:Int, fx = false, fy = false, ?rot:Float) {
		this.x = x;
		this.y = y;
		this.width = w;
		this.height = h;
		this.rot = rot;
		swapX = fx;
		swapY = fy;
		ddx = 0;
		ddy = 0;
		// PixiJS refuse une frame qui déborde la base (Flash s'en foutait).
		var bw = Std.int(base.width);
		var bh = Std.int(base.height);
		var fw = x + w > bw ? bw - x : w;
		var fh = y + h > bh ? bh - y : h;
		if (x >= 0 && y >= 0 && x < bw && y < bh && fw > 0 && fh > 0)
			texture = new Texture(base, new Rectangle(x, y, fw, fh));
		else
			texture = Texture.EMPTY;
	}
}
