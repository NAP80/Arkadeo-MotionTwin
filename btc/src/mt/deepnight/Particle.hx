package mt.deepnight;

// Particule à intégration simple (extends Sprite). Points sensibles du cycle de vie,
// à conserver tels quels :
//  - fondu d'ENTRÉE (da) seulement tant que rlife>0, clamp alpha>1 ;
//  - accélération + friction PUIS déplacement (ordre) ;
//  - fondu de SORTIE : à rlife<=0, alpha -= 0.1/frame, mort seulement quand alpha<=0,
//    pour que les FX one-shot life=0 s'estompent sur ~10 frames au lieu d'un frame.
class Particle extends flash.display.Sprite {
	public static var ALL:Array<Particle> = [];
	public static var LIMIT:Int = 350;

	public var dx:Float = 0;
	public var dy:Float = 0;
	public var gx:Float = 0;
	public var gy:Float = 0;
	public var frictX:Float = 1;
	public var frictY:Float = 1;
	public var ds:Float = 0; // delta d'échelle / frame
	public var da:Float = 0; // delta d'alpha / frame (fade-in tant que rlife>0)
	public var bounce:Float = 0.85;
	public var pixel:Bool = false;
	public var groundY:Float = 999999;
	public var killOnLifeOut:Bool = false;

	public var onUpdate:Null<Void->Void>;
	public var onKill:Null<Void->Void>;
	public var onBounce:Null<Void->Void>;

	// life : à l'affectation, fige rlife (vie restante) et maxLife.
	public var life(default, set):Float;
	var rlife:Float = 0;
	var maxLife:Float = 0;
	inline function set_life(v:Float):Float {
		rlife = v;
		maxLife = v;
		return life = v;
	}

	// delay : invisible tant que >0 (comme l'original set_delay).
	public var delay(default, set):Float = 0;
	function set_delay(d:Float):Float {
		visible = d <= 0;
		return delay = d;
	}

	var dead:Bool = false;

	public function new(x:Float, y:Float) {
		super();
		this.x = x;
		this.y = y;
		life = 32 + Std.random(32); // ~1..2 s à 30 fps
		if (ALL.length >= LIMIT)
			ALL.shift().kill();
		ALL.push(this);
	}

	public var frict(never, set):Float;
	inline function set_frict(v:Float):Float {
		frictX = frictY = v;
		return v;
	}

	public inline function setPos(x:Float, y:Float):Void {
		this.x = x;
		this.y = y;
	}

	public inline function moveAng(a:Float, spd:Float):Void {
		dx = Math.cos(a) * spd;
		dy = Math.sin(a) * spd;
	}

	public function drawCircle(r:Float, col:Int, ?alpha:Float = 1.0, ?fill:Bool = true, ?thickness:Float = 0):Void {
		var g = graphics;
		if (thickness > 0 || !fill) {
			g.lineStyle(thickness > 0 ? thickness : 1, col, alpha);
			g.drawCircle(0, 0, r);
		} else {
			g.beginFill(col, alpha);
			g.drawCircle(0, 0, r);
			g.endFill();
		}
	}

	public function drawBox(w:Float, h:Float, col:Int, ?alpha:Float = 1.0):Void {
		var g = graphics;
		g.beginFill(col, alpha);
		g.drawRect(-w * 0.5, -h * 0.5, w, h);
		g.endFill();
	}

	// ratio écoulé [0..1].
	public inline function time():Float {
		return maxLife <= 0 ? (1 - alpha) : 1 - (rlife + alpha) / (maxLife + 1);
	}

	function kill():Void {
		if (dead) return;
		dead = true;
		if (onKill != null) onKill();
		if (parent != null) parent.removeChild(this);
		ALL.remove(this);
	}

	static function step(p:Particle):Void {
		if (p.dead) return;
		if (p.delay > 0) {
			p.delay--;
			p.visible = p.delay <= 0;
			return;
		}

		// Échelle
		if (p.ds != 0) {
			p.scaleX += p.ds;
			p.scaleY += p.ds;
			if (p.scaleX < 0) p.scaleX = 0;
			if (p.scaleY < 0) p.scaleY = 0;
		}

		// Fondu d'entrée (seulement tant qu'en vie)
		if (p.rlife > 0 && p.da != 0) {
			p.alpha += p.da;
			if (p.alpha > 1) {
				p.da = 0;
				p.alpha = 1;
			}
		}

		// Accélération + friction PUIS déplacement
		p.dx += p.gx;
		p.dy += p.gy;
		p.dx *= p.frictX;
		p.dy *= p.frictY;
		p.x += p.dx;
		p.y += p.dy;

		// Rebond au sol
		if (p.groundY < 999999 && p.dy > 0 && p.y >= p.groundY) {
			p.dy = -p.dy * p.bounce;
			p.y = p.groundY - 1;
			if (p.onBounce != null) p.onBounce();
		}

		if (p.onUpdate != null) p.onUpdate();

		// Vie / fondu de sortie
		p.rlife--;
		if (p.rlife <= 0)
			p.alpha -= 0.1;
		if (p.rlife <= 0 && (p.alpha <= 0 || p.killOnLifeOut))
			p.kill();
	}

	public static function update():Void {
		for (p in ALL.copy())
			step(p);
	}

	public static function clearAll():Void {
		for (p in ALL.copy())
			p.kill();
		ALL = [];
	}
}
