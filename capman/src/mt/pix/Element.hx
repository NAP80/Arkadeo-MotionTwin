// Sprite (EL) qui affiche un Frame du Store et joue ses timelines.
package mt.pix;

import pixi.core.sprites.Sprite;
import pixi.core.display.DisplayObject;

class Element extends Sprite {
	public static var DEFAULT_ALIGN_X = 0.5;
	public static var DEFAULT_ALIGN_Y = 0.5;
	public static var DEFAULT_STORE:Store;

	public var store:Store;
	public var frameAlignX:Float;
	public var frameAlignY:Float;
	public var currentFrame:Frame;

	public var anim:Anim;
	public var currentAnimString:String;

	public function new(?store:Store) {
		super();
		frameAlignX = DEFAULT_ALIGN_X;
		frameAlignY = DEFAULT_ALIGN_Y;
		this.store = store == null ? DEFAULT_STORE : store;
	}

	public function redraw() {
		if (currentFrame != null) {
			drawFrame(currentFrame, frameAlignX, frameAlignY);
			if (anim != null)
				stop();
		}
	}

	public function goto(?id:Int, ?str:String, ?fx:Float, ?fy:Float) {
		drawFrame(store.get(id, str), fx, fy);
		if (anim != null)
			stop();
	}

	public function shuffleDir() {
		rotation = Std.random(4) * 1.5707963;
		scale.x = Std.random(2) * 2 - 1;
		scale.y = Std.random(2) * 2 - 1;
	}

	public function play(str:String, loop = true, frame = 0) {
		if (!store.timelines.exists(str))
			throw("anim " + str + " not found !");
		if (anim == null)
			ANIMATED.push(this);
		anim = new Anim(this);
		anim.loop = loop;
		anim.timeline = store.getTimeline(str);
		anim.goto(frame);
		drawFrame(anim.getCurrentFrame());
		currentAnimString = str;
	}

	public function stop() {
		if (anim == null)
			return;
		anim = null;
		ANIMATED.remove(this);
	}

	public function hasAnim(str) {
		return store.timelines.exists(str);
	}

	public function updateAnim() {
		anim.update();
		if (anim != null && visible) {
			var fr = anim.getCurrentFrame();
			if (fr != currentFrame)
				drawFrame(fr);
		}
	}

	public function swapAnim(newAnim:Anim) {
		newAnim.cursor = anim.cursor;
		newAnim.loop = anim.loop;
		anim = newAnim;
	}

	public inline function isPlaying() {
		return anim != null;
	}

	public function drawFrame(fr:Frame, ?fax:Float, ?fay:Float) {
		if (fax != null)
			frameAlignX = fax;
		if (fay != null)
			frameAlignY = fay;
		currentFrame = fr;
		this.texture = fr.texture;
		var w = fr.width == 0 ? 1 : fr.width;
		var h = fr.height == 0 ? 1 : fr.height;
		anchor.set((w * frameAlignX - fr.ddx) / w, (h * frameAlignY - fr.ddy) / h);
		if (fr.rot != null && fr.rot != 0)
			rotation = fr.rot;
	}

	public function setAlign(x, y) {
		frameAlignX = x;
		frameAlignY = y;
	}

	public function pxx() {
		x = Math.round(x);
		y = Math.round(y);
	}

	public inline function dispose()
		kill();

	public function kill() {
		stop();
		if (parent != null)
			parent.removeChild(this);
	}

	static public var ANIMATED:Array<Element> = [];

	public static function updateAnims() {
		var a = ANIMATED.copy();
		for (el in a)
			el.updateAnim();
	}

	// À appeler avant de reconstruire le jeu : la liste statique survivrait sinon à
	// la destruction du Game (els détruits -> crash dans updateAnims).
	public static function clearAnimated() {
		ANIMATED = [];
	}

	// Retire de ANIMATED tous les els situés SOUS `root`. Appelé quand on détruit un
	// niveau (SpeedRun) : ses ELs animés (skins de monstres...) seraient sinon parcourus
	// par updateAnims APRÈS destroy -> crash (anchor/texture null). Les els des AUTRES
	// niveaux (le nouveau, déjà créé) restent dans la liste.
	public static function dropUnder(root:DisplayObject) {
		ANIMATED = [for (el in ANIMATED) if (!isUnder(el, root)) el];
	}

	static function isUnder(el:Element, root:DisplayObject):Bool {
		var p:DisplayObject = el;
		while (p != null) {
			if (p == root) return true;
			p = p.parent;
		}
		return false;
	}
}
