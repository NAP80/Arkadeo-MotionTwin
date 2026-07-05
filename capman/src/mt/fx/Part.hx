package mt.fx;

import pixi.core.display.Container;

// Particule physique (vx/vy/friction/fade) sur un Container ; transforms via
// l'API PixiJS native. Réécrite car la version lib est typée Flash.
class Part extends mt.fx.Fx {
	public var fitPix:Bool;
	public var x:Float;
	public var y:Float;
	public var vx:Float;
	public var vy:Float;
	public var vr:Float;
	public var sfr:Null<Float>;
	public var weight:Float;
	public var frict:Float;
	public var rfr:Float;
	public var scale:Float;
	public var alpha:Float;
	public var timer:Int;
	public var fadeLimit:Int;
	public var fadeType:Int;

	var fadeInData:{timer:Int, limit:Int};
	var ground:{y:Float, frx:Float, fry:Float};

	public var onBounceGround:Void->Void;
	public var root:Container;

	public function new(mc:Container, ?pManager) {
		super(pManager);
		root = mc;
		fitPix = false;
		x = root.x;
		y = root.y;
		vx = 0;
		vy = 0;
		weight = 0;
		vr = 0;
		sfr = null;
		rfr = 1;
		frict = 1;
		scale = 1;
		alpha = 1;
		timer = -1;
		fadeLimit = 10;
		fadeType = 0;
	}

	public function setScale(sc:Float) {
		scale = sc;
		root.scale.set(sc, sc);
	}

	public function setAlpha(a:Float) {
		alpha = a;
		root.alpha = a;
	}

	override function update() {
		// POS
		vy += weight;
		vx *= frict;
		vy *= frict;
		x += vx;
		y += vy;
		// ROT
		vr *= rfr;
		root.rotation += vr;
		// SC
		if (sfr != null) {
			scale *= sfr;
			setScale(scale);
		}
		// GROUND
		if (ground != null) {
			if (y > ground.y) {
				y = ground.y;
				vx *= ground.frx;
				vy *= -ground.fry;
				if (onBounceGround != null) onBounceGround();
			}
		}
		// FADE IN
		if (fadeInData != null) {
			fadeInData.timer++;
			var c = fadeInData.timer / fadeInData.limit;
			applyFade(c);
			if (c == 1) fadeInData = null;
		}
		// FADE OUT
		timer--;
		if (timer < fadeLimit && timer >= 0) {
			applyFade(timer / fadeLimit);
		}
		// TIME OUT
		if (timer == 0) {
			kill();
			return; // root détruit dans kill() : ne pas le repositionner ensuite
		}
		updatePos();
	}

	inline function applyFade(c:Float) {
		switch (fadeType) {
			case 1: root.alpha = c * alpha;
			case 2: root.scale.set(c * scale, c * scale);
			case 3: root.scale.x = c * scale;
			case 4: root.scale.y = c * scale;
			default:
		}
	}

	public function setPos(nx:Float, ny:Float) {
		x = nx;
		y = ny;
		updatePos();
	}

	public function updatePos() {
		root.x = x;
		root.y = y;
		if (fitPix) {
			root.x = Std.int(root.x);
			root.y = Std.int(root.y);
		}
	}

	public function fadeIn(n:Int) {
		fadeInData = {timer: 0, limit: n};
		root.scale.set(0, 0);
	}

	public function setGround(y, frx, fry, ?timer:Int) {
		ground = {y: y, frx: frx, fry: fry};
		if (timer != null) {
			var me = this;
			onBounceGround = function() me.timer = timer;
		}
	}

	// SHORTCUT
	public function twist(n:Float, ?fr:Null<Float>) {
		if (fr != null) rfr = fr;
		root.rotation = Math.random() * 6.283;
		vr = (Math.random() * 2 - 1) * n;
	}

	public function shortrun(n:Float) {
		x += vx * n;
		y += vy * n;
		updatePos();
	}

	// KILL
	override function kill() {
		// destroy() (pas seulement removeChild) : les particules sont jetables, et un
		// Graphics retiré sans destroy garde son buffer GPU (le GC JS ne libère pas le
		// WebGL) -> fuite progressive (sillage Skull = 3 Graphics/frame). children:true
		// pour les conteneurs (score) ; les textures partagées (atlas) ne sont PAS touchées.
		var r = root;
		root = null;
		if (r != null) untyped r.destroy({children: true});
		super.kill();
	}
}
