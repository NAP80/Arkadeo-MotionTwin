package mt.deepnight.slb;

import mt.MLib;
import mt.deepnight.slb.BLib; // amène les typedefs LibGroup / FrameData / SLBError

// Portage PixiJS de slb.BSprite : un flash.display.Sprite (= PIXI.Container) qui
// affiche un PIXI.Sprite enfant (`bmp`) texturé par une sous-texture de l'atlas.
// L'anim est pilotée par AnimManager.
class BSprite extends flash.display.Sprite implements SpriteInterface {
	public static var ALL:Array<BSprite> = [];
	static var EMPTY_BD:flash.display.BitmapData;

	public var a:AnimManager;
	public var lib:BLib;
	public var groupName:String;
	public var group:LibGroup;
	public var frame:Int;
	public var frameData:FrameData;
	var slbPivot:SpritePivot; // renommé : `pivot` collisionne avec DisplayObject.pivot (PixiJS)
	public var destroyed:Bool;

	public var beforeRender:Null<Void->Void>;
	public var onFrameChange:Null<Void->Void>;

	var bmp:Dynamic; // le PIXI.Sprite enfant

	public function new(?l:BLib, ?g:String, ?frame = 0) {
		super();
		destroyed = false;
		this.frame = 0;
		slbPivot = new SpritePivot();
		a = new AnimManager(this);
		bmp = js.Syntax.code("new PIXI.Sprite()");
		addChild(bmp);
		ALL.push(this);
		if (l != null)
			set(l, g, frame);
	}

	public function set(?l:BLib, ?g:String, ?frame = 0, ?stopAllAnims = false):Void {
		if (l != null) {
			if (lib != null) lib.removeChild(this);
			lib = l;
			lib.addChild(this);
			if (g == null) {
				groupName = null;
				group = null;
				frameData = null;
			}
			if (slbPivot.isUndefined)
				setCenterRatio(lib.defaultCenterX, lib.defaultCenterY);
		}
		if (g != null && g != groupName)
			groupName = g;

		if (isReady()) {
			if (stopAllAnims) a.stopWithoutStateAnims();
			group = lib.getGroup(groupName);
			frameData = lib.getFrameData(groupName, frame);
			if (frameData == null) throw 'Unknown frame: $groupName($frame)';
			setFrame(frame);
		}
	}

	public function setFrame(f:Int):Void {
		frame = f;
		if (isReady()) {
			frameData = lib.getFrameData(groupName, frame);
			if (frameData == null) throw 'Unknown frame: $groupName($frame)';
			bmp.texture = lib.getFrameTexture(groupName, frame);
			applyPivot();
			if (onFrameChange != null) onFrameChange();
		}
	}

	function applyPivot():Void {
		if (!isReady()) return;
		var px:Float;
		var py:Float;
		if (slbPivot.isUsingCoord()) {
			px = MLib.round(-slbPivot.coordX - frameData.realFrame.x);
			py = MLib.round(-slbPivot.coordY - frameData.realFrame.y);
		} else if (slbPivot.isUsingFactor()) {
			px = Std.int(-frameData.realFrame.realWid * slbPivot.centerFactorX - frameData.realFrame.x);
			py = Std.int(-frameData.realFrame.realHei * slbPivot.centerFactorY - frameData.realFrame.y);
		} else
			return;
		// Retournement horizontal via le BITMAP, pas le container : l'échelle X du
		// container reste positive → PIXI.width positif → points d'attache de Hero
		// corrects. bmp.x = -px quand retourné = miroir autour de l'origine.
		bmp.scale.x = flipX;
		bmp.x = flipX > 0 ? px : -px;
		bmp.y = py;
	}

	// Signe du retournement, mémorisé à part pour garder le scale container positif.
	// get_scaleX renvoie la valeur signée (Hero teste scaleX<0), set_scaleX met un
	// scale container >=0 et retourne le bmp.
	var flipX:Float = 1;

	override function get_scaleX():Float return flipX * scale.x;

	override function set_scaleX(v:Float):Float {
		flipX = v < 0 ? -1 : 1;
		scale.x = v < 0 ? -v : v;
		applyPivot();
		return v;
	}

	// Alias attendu par le jeu (setCenter).
	public inline function setCenter(xr:Float, yr:Float):Void setCenterRatio(xr, yr);

	public inline function setCenterRatio(xr:Float, yr:Float):Void {
		slbPivot.setCenterRatio(xr, yr);
		applyPivot();
	}

	public inline function setPivotCoord(x:Float, y:Float):Void {
		slbPivot.setCoord(x, y);
		applyPivot();
	}

	public inline function setScale(v:Float):Void {
		scaleX = v;
		scaleY = v;
	}

	public inline function setPos(x:Float, y:Float):Void {
		this.x = x;
		this.y = y;
	}

	public inline function setSize(w:Float, h:Float):Void {
		this.width = w;
		this.height = h;
	}

	// Teinte multiplicative de la frame.
	public function setTint(c:Int):Void
		untyped if (bmp != null) bmp.tint = c;

	public function constraintSize(w:Float, ?h:Null<Float>, ?useFrameDataRealSize = false):Void {
		if (useFrameDataRealSize)
			setScale(MLib.fmin(w / frameData.realFrame.realWid, (h == null ? w : h) / frameData.realFrame.realHei));
		else
			setScale(MLib.fmin(w / this.width, (h == null ? w : h) / this.height));
	}

	public inline function setRandom(?l:BLib, g:String, rndFunc:Int->Int):Void {
		set(l, g, lib.getRandomFrame(g, rndFunc));
	}

	public inline function setRandomFrame(?rndFunc:Int->Int):Void {
		if (isReady())
			set(groupName, lib.getRandomFrame(groupName, rndFunc == null ? Std.random : rndFunc));
	}

	public function getAnimDuration():Int {
		var g = isReady() ? group : null;
		return g != null ? g.anim.length : 0;
	}

	public inline function isGroup(k:String):Bool return groupName == k;
	public inline function is(k:String, f:Int):Bool return groupName == k && frame == f;
	public inline function isReady():Bool return !destroyed && groupName != null;
	public function totalFrames():Int return group.frames.length;

	// Lecture pixel : crop caché de la frame courante, où getColorBoundsRect va
	// chercher les marqueurs d'attache (0x00bdff / 0x18fff7).
	public function getBitmapDataReadOnly():flash.display.BitmapData {
		if (isReady() && frameData != null && lib != null)
			return lib.getFrameBitmapData(groupName, frame);
		if (EMPTY_BD == null) EMPTY_BD = new flash.display.BitmapData(1, 1, true, 0x0);
		return EMPTY_BD;
	}
	public function getBitmapData():flash.display.BitmapData return getBitmapDataReadOnly();

	public function clone<T>(?s:T):T {
		var c = new BSprite(lib, groupName, frame);
		return cast c;
	}

	public function toString():String return "BSprite_" + groupName + "[" + frame + "]";

	public function dispose():Void {
		if (destroyed) return;
		destroyed = true;
		if (lib != null) lib.removeChild(this);
		if (parent != null) parent.removeChild(this);
		ALL.remove(this);
		if (a != null) a.destroy();
		a = null;
		lib = null;
		frameData = null;
		group = null;
		groupName = null;
		slbPivot = null;
		beforeRender = null;
		onFrameChange = null;
	}

	// Pilote toutes les anims vivantes.
	public static function updateAll():Void {
		for (s in ALL.copy())
			if (!s.destroyed) {
				s.a.update();
				if (s.beforeRender != null) s.beforeRender();
			}
	}
}
