package mt.deepnight.slb;

import flash.geom.Rectangle;
import mt.MLib;

typedef FrameData = {
	x			: Int,
	y			: Int,
	wid			: Int,
	hei			: Int,
	realFrame	: {x:Int, y:Int, realWid:Int, realHei:Int},
	rect		: Rectangle,
	?pX			: Float,
	?pY			: Float,
}

typedef LibGroup = {
	id		: String,
	maxWid	: Int,
	maxHei	: Int,
	frames	: Array<FrameData>,
	anim	: Array<Int>,
};

enum SLBError {
	NoGroupSelected;
	GroupAlreadyExists(g:String);
	InvalidFrameDuration(s:String);
	EndFrameLower(s:String);
	InvalidFrames(s:String);
	NoCurrentGroup;
	AnimFrameExceeds(id:String, anim:String, frame:Int);
	AssetImportFailed(e:Dynamic);
	NotSameSLBFromBatch;
}

// Portage PixiJS de slb.BLib : au lieu de blitter des BitmapData, chaque frame est
// une sous-texture de l'atlas (base + Rectangle). API publique conservée.
class BLib {
	// Registre alimenté par Boot avant new Game, consommé par l'importXml runtime.
	public static var REG:Map<String, {xml:String, anims:String, base:Dynamic, canvas:Dynamic}> = new Map();
	public static function register(url:String, xml:String, anims:String, base:Dynamic, canvas:Dynamic):Void {
		REG.set(url, {xml: xml, anims: anims, base: base, canvas: canvas});
	}

	public var base:Dynamic; // PIXI.BaseTexture de l'atlas
	public var srcCanvas:Dynamic; // <canvas>/<img> source de l'atlas (lecture pixel)
	var groups:Map<String, LibGroup>;
	var currentGroup:Null<LibGroup>;
	var frameRandDraw:Map<String, Array<Int>>;
	public var defaultCenterX(default, null):Float;
	public var defaultCenterY(default, null):Float;
	var gridX:Int;
	var gridY:Int;
	var children:Array<SpriteInterface>;
	var texCache:Map<String, Array<Dynamic>>;
	var frameBdCache:Map<String, flash.display.BitmapData>; // crops de frame cachés (lecture pixel)

	public function new(base:Dynamic, ?canvas:Dynamic) {
		this.base = base;
		this.srcCanvas = canvas;
		groups = new Map();
		frameRandDraw = new Map();
		texCache = new Map();
		frameBdCache = new Map();
		defaultCenterX = 0;
		defaultCenterY = 0;
		gridX = gridY = 16;
		children = [];
	}

	// Sous-texture PIXI cachée pour (group, frame).
	public function getFrameTexture(k:String, frame:Int):Dynamic {
		if (!texCache.exists(k))
			texCache.set(k, []);
		var arr = texCache.get(k);
		if (arr[frame] == null) {
			var fd = getFrameData(k, frame);
			arr[frame] = js.Syntax.code("new PIXI.Texture({0}, new PIXI.Rectangle({1},{2},{3},{4}))", base, fd.x, fd.y, fd.wid, fd.hei);
		}
		return arr[frame];
	}

	// No-op : les textures sont paresseuses, plus de pré-blit. Conservé car appelé.
	public function initBdGroups():Void {}

	// Crop caché de la frame depuis l'atlas. Sert à la lecture pixel (Hero cherche
	// ses pixels-marqueurs couette/chaîne via getColorBoundsRect).
	public function getFrameBitmapData(k:String, frame:Int):flash.display.BitmapData {
		var key = k + "#" + frame;
		if (frameBdCache.exists(key))
			return frameBdCache.get(key);
		var fd = getFrameData(k, frame);
		var w = fd != null ? fd.wid : 1;
		var h = fd != null ? fd.hei : 1;
		var bd = new flash.display.BitmapData(w, h, true, 0x0);
		if (fd != null && srcCanvas != null)
			bd.copyFromCanvas(srcCanvas, fd.x, fd.y, fd.wid, fd.hei);
		frameBdCache.set(key, bd);
		return bd;
	}

	public inline function get(k:String, ?frame = 0, ?xr = 0.0, ?yr = 0.0, ?p:flash.display.DisplayObjectContainer):BSprite {
		var s = new BSprite(this, k, frame);
		s.setCenterRatio(xr, yr);
		if (p != null)
			p.addChild(s);
		return s;
	}

	public function getAndPlay(k:String, ?plays = 99999, ?killAfterPlay = false):BSprite {
		var s = new BSprite(this);
		s.a.play(k, plays);
		if (killAfterPlay)
			s.a.killAfterPlay();
		return s;
	}

	public inline function getRandom(k:String, ?rndFunc:Int->Int):BSprite {
		return get(k, getRandomFrame(k, rndFunc));
	}

	public inline function setDefaultCenter(cx, cy):Void {
		defaultCenterX = cx;
		defaultCenterY = cy;
	}

	public function setSliceGrid(w, h):Void {
		gridX = w;
		gridY = h;
	}

	public inline function getGroup(?k:String):Null<LibGroup> {
		return k == null ? currentGroup : groups.get(k);
	}

	public inline function getGroups() return groups;

	public inline function getAnim(k):Array<Int> return getGroup(k).anim;
	public inline function getAnimDuration(k):Int return getAnim(k).length;

	public function createGroup(k:String):Null<LibGroup> {
		if (groups.exists(k))
			throw SLBError.GroupAlreadyExists(k);
		groups.set(k, {id: k, maxWid: 0, maxHei: 0, frames: new Array(), anim: new Array()});
		return setCurrentGroup(k);
	}

	inline function setCurrentGroup(k:String):Null<LibGroup> {
		currentGroup = getGroup(k);
		return getGroup();
	}

	public function getRectangle(k:String, ?frame = 0):Null<Rectangle> {
		var g = getGroup(k);
		if (g == null) return null;
		var fr = g.frames[frame];
		if (fr == null) return null;
		return new Rectangle(fr.x, fr.y, fr.wid, fr.hei);
	}

	public inline function getFrameData(k:String, ?frame = 0):Null<FrameData> {
		var g = getGroup(k);
		return g == null ? null : g.frames[frame];
	}

	public inline function exists(k:String, ?frame = 0):Bool {
		return k != null && frame >= 0 && groups.exists(k) && groups.get(k).frames.length > frame;
	}

	public function getRandomFrame(k:String, ?rndFunc:Int->Int):Int {
		if (rndFunc == null) rndFunc = Std.random;
		return if (frameRandDraw.exists(k)) {
			var a = frameRandDraw.get(k);
			a[rndFunc(a.length)];
		} else rndFunc(countFrames(k));
	}

	public inline function countFrames(k:String):Int return getGroup(k).frames.length;

	public function sliceCustom(groupName:String, frame:Int, x:Int, y:Int, wid:Int, hei:Int, ?realFrame:{x:Int, y:Int, realWid:Int, realHei:Int}, ?pX:Float, ?pY:Float):Void {
		var g = if (exists(groupName)) getGroup(groupName) else createGroup(groupName);
		g.maxWid = MLib.max(g.maxWid, wid);
		g.maxHei = MLib.max(g.maxHei, hei);
		if (realFrame == null)
			realFrame = {x: 0, y: 0, realWid: wid, realHei: hei};
		g.frames[frame] = {x: x, y: y, wid: wid, hei: hei, realFrame: realFrame, rect: new Rectangle(x, y, wid, hei), pX: pX, pY: pY};
	}

	public function slice(groupName:String, x:Int, y:Int, wid:Int, hei:Int, ?repeatX = 1, ?repeatY = 1):Void {
		var g = createGroup(groupName);
		setCurrentGroup(groupName);
		g.maxWid = MLib.max(g.maxWid, wid);
		g.maxHei = MLib.max(g.maxHei, hei);
		for (iy in 0...repeatY)
			for (ix in 0...repeatX)
				g.frames.push({x: x + ix * wid, y: y + iy * hei, wid: wid, hei: hei, realFrame: {x: 0, y: 0, realWid: wid, realHei: hei}, rect: new Rectangle(x + ix * wid, y + iy * hei, wid, hei)});
	}

	public function __defineAnim(?group:String, anim:Array<Int>):Void {
		if (currentGroup == null && group == null)
			throw SLBError.NoCurrentGroup;
		if (group != null)
			setCurrentGroup(group);
		var a = [];
		for (f in anim) {
			if (f >= currentGroup.frames.length)
				throw SLBError.AnimFrameExceeds(currentGroup.id, "[" + anim.join(",") + "] " + currentGroup.frames.length, f);
			a.push(f);
		}
		currentGroup.anim = a;
	}

	// Parsing de définition d'anim "0-5, 6(2), 7(1)".
	public static function parseAnimDefinition(animDef:String, ?timin = 1):Array<Int> {
		animDef = StringTools.replace(animDef, ")", "(");
		var frames:Array<Int> = new Array();
		var parts = animDef.split(",");
		for (p in parts) {
			p = StringTools.trim(p);
			if (p == "") continue;
			var curTiming = timin;
			if (p.indexOf("(") > 0) {
				var t = Std.parseInt(p.split("(")[1]);
				if (t == null || Math.isNaN(t)) throw SLBError.InvalidFrameDuration(p);
				curTiming = t;
				p = p.substr(0, p.indexOf("("));
			}
			if (p.indexOf("-") < 0) {
				var f = Std.parseInt(p);
				for (i in 0...curTiming) frames.push(f);
				continue;
			}
			if (p.indexOf("-") > 0) {
				var from = Std.parseInt(p.split("-")[0]);
				var to = Std.parseInt(p.split("-")[1]) + 1;
				if (to < from) throw SLBError.EndFrameLower(p);
				while (from < to) {
					for (i in 0...curTiming) frames.push(from);
					from++;
				}
				continue;
			}
			throw SLBError.InvalidFrames(p);
		}
		return frames;
	}

	// drawInto* : no-op (le Level qui les appelait est lui-même shadowé).
	public function drawIntoBitmap(bd:Dynamic, x:Float, y:Float, k:String, ?frame = 0, ?centerX:Float, ?centerY:Float):Void {}
	public function drawIntoBitmapRandom(bd:Dynamic, x:Float, y:Float, k:String, ?rndFunc:Int->Int, ?centerX:Float, ?centerY:Float):Void {}
	public function getMovieClip(k:String, ?frame = 0, ?centerX:Float, ?centerY:Float):flash.display.MovieClip return new flash.display.MovieClip();

	// Points d'attache : non implémentés (no-op).
	public function parseAttachPoints(colors:Array<Int>, dotSpriteSuffix:String):Void {}
	public function getAttachPoint(s:SpriteInterface, col:Int):{dx:Float, dy:Float} return {dx: 0., dy: 0.};

	// Enfants pilotés en anim
	public function addChild(s:SpriteInterface):Void children.push(s);
	public function removeChild(s:SpriteInterface):Void children.remove(s);
	public inline function countChildren():Int return children.length;
	public function updateChildren():Void {
		for (bs in children)
			if (!bs.destroyed) {
				bs.a.update();
				if (bs.beforeRender != null) bs.beforeRender();
			}
	}

	public function destroy():Void {
		while (children.length > 0)
			children[0].dispose();
		texCache = new Map();
	}

	public function toString():String {
		var l = [];
		for (k in groups.keys()) {
			var g = getGroup(k);
			l.push(k + " (" + g.maxWid + "x" + g.maxHei + ") : " + g.frames.length + "f");
		}
		return l.join("\n");
	}
}
