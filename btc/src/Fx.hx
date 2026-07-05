import flash.display.BlendMode;
import flash.filters.GlowFilter;
import flash.filters.BlurFilter;
import mt.deepnight.Particle;
import mt.deepnight.Lib;
import mt.deepnight.Color;
import mt.deepnight.slb.BSprite;
import mt.MLib;
import Const;

// Effets du jeu (particules PixiJS). Points d'attention par rapport au Flash d'origine :
//  - blend ADD via register() (propagé aux feuilles → additif),
//  - rotation en RADIANS là où l'original mettait des degrés,
//  - shake manuel (oscillation amortie de root.y, sans dérive),
//  - cas Flash-only adaptés (colorTransform→alpha, flatten→enfant direct).
class Fx {
	public static var ME:Fx;
	var mode:Mode;
	var lowq:Bool;
	var perf:Float;
	var powerColor:Float;

	// shake (oscillation amortie de mode.root.y, remise à 0 à la fin)
	var shakeMs:Float = 0;
	var shakeDur:Float = 0;
	var shakeAmp:Float = 0;

	public function new() {
		ME = this;
		mode = Mode.ME;
		lowq = api.AKApi.isLowQuality();
		perf = api.AKApi.getPerf();
		powerColor = 0;
		Particle.LIMIT = lowq ? 30 : 350;
	}

	public function destroy():Void {
		mode = null;
	}

	public function register(p:Particle, ?b:BlendMode, ?bg = false):Void {
		mode.dm.add(p, bg ? Const.DP_BG_FX : Const.DP_FX);
		p.blendMode = b != null ? b : BlendMode.ADD;
	}

	inline function rnd(min:Float, max:Float, ?sign:Bool):Float return Lib.rnd(min, max, sign);
	inline function irnd(min:Int, max:Int, ?sign:Bool):Int return Lib.irnd(min, max, sign);

	public function clear():Void {
		Particle.clearAll();
	}

	public function marker(cx:Float, cy:Float, ?col = 0xFFFF00, ?alpha = 1.0):Void {
		var p = new Particle((cx + 0.5) * Const.GRID, (cy + 0.5) * Const.GRID);
		p.alpha = alpha;
		p.drawCircle(5, col);
		p.life = 50;
		p.filters = [new GlowFilter(col, 1, 16, 16, 1)];
		register(p, BlendMode.NORMAL);
	}

	public function radius(x:Float, y:Float, r:Float, col:Int):Void {
		var p = new Particle(x, y);
		p.drawCircle(r, col);
		p.life = 0;
		p.ds = -0.02;
		p.filters = [new BlurFilter(16, 16)];
		register(p);
	}

	public function bombExplosion(x:Float, y:Float, r:Float):Void {
		if (!mode.tiles.exists("explo_big")) return;
		var s = mode.tiles.getAndPlay("explo_big", 1, true);
		mode.dm.add(s, Const.DP_FX);
		s.blendMode = BlendMode.ADD;
		s.setCenter(0.5, 0.5);
		s.x = x;
		s.y = y;
		s.width = r * 2;
		s.height = r * 2;
		s.rotation = rnd(0, 6.28);
	}

	public function heroDash(e:Entity):Void {
		var p = new Particle(e.xx, e.yy - 10);
		p.drawCircle(16, 0xDCA2DD, 1, false, 4);
		p.ds = 0.4;
		p.onUpdate = function() p.ds *= 0.8;
		p.life = 0;
		register(p);

		var d = e.dx < 0 ? -1 : 1;
		for (i in 0...12) {
			var p = new Particle(e.xx - d * 10 + rnd(0, 10, true), e.yy - rnd(3, 30));
			p.drawBox(rnd(4, 16), 1, 0xDCA2DD);
			p.dx = d * rnd(4, 8);
			p.frict = 0.85;
			p.life = rnd(0, 3);
			register(p);
		}
	}

	public function explosion(x:Float, y:Float, ?intensity = 1.0):Void {
		if (lowq) return;

		var p = new Particle(x, y);
		p.drawCircle(25, 0xFFFF80, 1, false, 2);
		p.ds = 0.2;
		p.life = 0;
		register(p);

		for (i in 0...(lowq ? 1 : MLib.ceil(5 * intensity))) {
			var p = new Particle(x, y - 10);
			if (i == 0) {
				p.drawCircle(16, 0xFFF8BF, 1);
				p.ds = 0.05;
			} else {
				p.setPos(p.x + rnd(2, 15, true), p.y + rnd(2, 15, true));
				p.drawCircle(12, 0xFFF8BF, 1);
				p.delay = i + irnd(0, 1);
				p.ds = -rnd(0.05, 0.10);
				p.moveAng(rnd(0, 6.28), rnd(1, 2));
				p.frict = rnd(0.9, 0.97);
			}
			p.filters = [new GlowFilter(0xFFCC00, 1, 16, 16, 2)];
			p.life = rnd(1, 3);
			register(p);
		}
	}

	public function lockActivation(e:Entity):Void {
		var p = new Particle(e.xx, e.yy - 20);
		p.drawCircle(25, 0x97ADD2, 1);
		p.ds = 0.1;
		p.life = 4;
		register(p);

		var p = new Particle(e.xx, e.yy - 20);
		p.drawCircle(25, 0x97ADD2, 0.5);
		p.delay = 10;
		p.ds = 0.1;
		p.life = 4;
		register(p);
	}

	public function heroDeath(e:en.Hero):Void {
		flashBang(0xFF0000, 1, 40);
		explosion(e.xx, e.yy - 10, 1);
		shake(2, 800);
	}

	public function bottomDeathHero(x:Float):Void {
		if (!mode.tiles.exists("damage")) return;
		var s = mode.tiles.getAndPlay("damage", 1, true);
		mode.dm.add(s, Const.DP_FX);
		s.blendMode = BlendMode.ADD;
		s.setCenter(0.5, 0);
		s.scaleX = 2;
		s.scaleY = -s.scaleX;
		s.x = x;
		s.y = Const.HEI;
	}

	public function bottomDeathMob(x:Float):Void {
		if (!mode.tiles.exists("damage")) return;
		var s = mode.tiles.getAndPlay("damage", 1, true);
		mode.dm.add(s, Const.DP_FX);
		s.blendMode = BlendMode.ADD;
		s.setCenter(0.5, 0);
		s.scaleX = 1;
		s.scaleY = -s.scaleX;
		s.x = x;
		s.y = Const.HEI;
	}

	// Progression uniquement (jamais appelé en League).
	public function exit():Void {
		shake(2, 200);
		flashBang(0x0080FF, 1);
	}

	public function slam(x:Float, y:Float):Void {
		var p = new Particle(x, y);
		p.drawCircle(30, 0x00FFFF);
		p.scaleY = 0.3;
		p.life = 0;
		p.ds = 0.1;
		p.filters = [new BlurFilter(8, 8)];
		register(p);
	}

	public function spawn(x:Float, y:Float):Void {
		var p = new Particle(x, y - 10);
		p.drawCircle(25, 0xFF0000);
		p.life = 2;
		p.ds = -0.07;
		p.filters = [new BlurFilter(16, 16)];
		register(p);
	}

	public function spawnKP(e:en.it.KPoint):Void {
		var p = new Particle(e.xx, e.yy - 10);
		p.drawCircle(30, 0x00A6FF);
		p.life = 4;
		p.ds = 0.07;
		p.filters = [new BlurFilter(16, 16)];
		register(p);
	}

	public function phaseOut(e:Entity):Void {
		for (i in 0...40) {
			var p = new Particle(e.xx + rnd(0, 5, true), e.yy - rnd(5, 25));
			p.drawBox(rnd(2, 7), 2, 0xDED0FB, 1);
			p.filters = [new GlowFilter(0x824DF0, 1, 8, 8, 2)];
			var a = rnd(0, 6.28);
			p.moveAng(a, rnd(2, 16));
			p.frict = 0.91;
			p.life = rnd(5, 30);
			p.rotation = a;
			register(p);
		}

		var p = new Particle(e.xx, e.yy - 10);
		p.drawCircle(50, 0xA078F3, 1, false);
		p.life = 3;
		p.ds = -0.1;
		p.onUpdate = function() p.ds *= 0.5;
		register(p);
	}

	public function pickKP(e:en.it.KPoint):Void {
		var col = switch (e.kp.frame) {
			case 1: 0x80FF00;
			case 2: 0xFF9300;
			case 3: 0x009FFF;
			case 4: 0xFF80FF;
			default: 0xFF0000;
		}
		var p = new Particle(e.xx, e.yy - 10);
		p.drawCircle(30, col, 0.3);
		p.life = 3;
		p.ds = 0.8;
		p.onUpdate = function() p.ds *= 0.5;
		p.filters = [new BlurFilter(16, 16)];
		register(p);

		pop(e.xx, e.yy, e.kp.amount.get(), col);

		for (i in 0...30) {
			var p = new Particle(e.xx, e.yy - 10);
			p.moveAng(rnd(0, 6.28), rnd(12, 14));
			p.life = rnd(10, 30);
			p.drawBox(3, 3, col, 1);
			p.gx = rnd(0, 0.5, true);
			p.gy = rnd(0, 0.5, true);
			p.frict = 0.9;
			p.filters = [new GlowFilter(col, 0.5, 8, 8, 3)];
			register(p);
		}
	}

	// Cœur perdu : clignotement + fondu (rendait le colorTransform Flash).
	public function creditLoss(x:Float, y:Float):Void {
		if (!mode.tiles.exists("heart")) return;
		var p = new Particle(x, y);
		var s = mode.tiles.get("heart", mode.tiles.exists("heart", 1) ? 1 : 0); // frame 1 = cœur perdu
		p.addChild(s);
		s.setCenter(0.5, 0.5);
		s.filters = [new GlowFilter(0xFF0000, 0.8, 16, 16, 1)];
		p.dx = 2;
		p.frict = 0.95;
		p.onUpdate = function() {
			s.visible = !s.visible;
			s.alpha = 1 - p.time() * 0.3;
		}
		p.onKill = function() s.destroy();
		register(p);
	}

	public function flashBang(col:Int, ?alpha = 1.0, ?duration = 0.):Void {
		var p = new Particle(0, 0);
		p.life = duration;
		p.da = -1 / (duration + 1);
		p.graphics.beginFill(col, alpha);
		p.graphics.drawRect(0, 0, Const.WID, Const.HEI);
		p.graphics.endFill();
		register(p); // ADD : flash additif coloré qui éclaircit la scène
	}

	// Oscillation amortie de root.y autour de 0 (pas de Tweenie, pour éviter une
	// dérive permanente). Avancé dans update().
	public function shake(power:Float, ms:Float):Void {
		if (lowq) ms *= 0.5;
		var amp = 8 * power;
		if (ms > shakeMs - shakeDur || amp > shakeAmp) {
			shakeDur = ms;
			shakeMs = ms;
			shakeAmp = amp;
		}
	}

	public function pop(x:Float, y:Float, str:Dynamic, ?col = 0xFFBF00):Void {
		var p = new Particle(x, y);
		var tf = mode.createField(str, col, true);
		p.addChild(tf);
		tf.scaleX = tf.scaleY = 2;
		tf.x = Std.int(-tf.width * 0.5);
		tf.y = Std.int(-tf.height);
		tf.filters = [new GlowFilter(0x0, 1, 2, 2, 8)];
		p.dy = -12;
		p.frictY = 0.8;
		register(p, BlendMode.NORMAL);
	}

	public function rocks():Void {
		shake(1, 2000);
		if (!mode.tiles.exists("rocher")) return;
		var n = 20;
		for (i in 0...n) {
			var p = new Particle(Const.WID * i / n + rnd(0, 20, true), 0);
			var s = mode.tiles.getRandom("rocher");
			p.addChild(s);
			s.setCenter(0.5, 0.5);
			p.onKill = function() p.destroy();
			p.scaleX = p.scaleY = rnd(0.5, 1.5);
			p.dy = rnd(1, 8);
			p.delay = rnd(0, 20);
			p.gy = rnd(1.5, 3);
			p.frict = rnd(0.96, 0.99);
			p.rotation = rnd(0, 6.28);
			p.groundY = Const.HEI + rnd(0, 20);
			p.life = rnd(40, 60);
			p.onBounce = function() {
				p.gy = p.dy = 0;
				p.groundY = 99999;
				p.rotation += rnd(0.3, 0.7, true);
				shake(1, 500);
			};
			register(p, BlendMode.NORMAL);
		}
	}

	// Avertissement (mob grimpant une échelle de sortie) : halo rouge flou + « Danger »
	// jaune en haut de la colonne menacée. Ré-émis toutes les 10 ticks par Walker.
	public function danger(cx:Float):Void {
		var x = (cx + 0.5) * Const.GRID;

		// Demi-disque rouge bombé vers le bas : arc(0..π) = moitié BASSE du disque
		// (y descend en PIXI).
		var halo = new Particle(x, 0);
		halo.graphics.beginFill(0xFF0000, 0.5);
		halo.graphics.arc(0, 0, 50, 0, Math.PI, false);
		halo.graphics.endFill();
		halo.scaleX = 1.8;
		halo.life = 0;
		halo.filters = [new BlurFilter(40, 20)];
		register(halo);

		var p = new Particle(x, 6);
		var tf = mode.createField("Danger", 0xFFFF00, true);
		tf.scaleX = tf.scaleY = 2;
		tf.x = Std.int(-tf.width * 0.5);
		tf.y = 0;
		p.addChild(tf);
		p.life = 0;
		register(p, BlendMode.NORMAL); // texte lisible, pas additif
	}

	public function superPower(e:Entity):Void {
		powerColor += 0.1;
		if (powerColor >= 1) powerColor--;
		var c = Color.randomColor(powerColor);

		// Pelure : copie teintée de la frame courante du héros qui dérive et s'estompe
		// (élément le plus visible de l'effet). L'original faisait flatten + colorTransform.
		if (!lowq && e.sprite != null && e.sprite.groupName != null) {
			var ghost = mode.tiles.get(e.sprite.groupName, e.sprite.frame);
			ghost.setCenter(0.5, 1); // même ancrage que le héros
			ghost.setTint(c);
			var pg = new Particle(e.xx, e.yy);
			pg.addChild(ghost);
			pg.scaleX = e.dir; // épouse le sens du héros
			pg.alpha = 0.5;
			pg.da = -0.02;
			pg.dx = rnd(0.2, 0.5, true);
			pg.dy = rnd(0.2, 0.5, true);
			pg.frictX = pg.frictY = 0.92;
			pg.life = 20 + irnd(0, 2);
			pg.onKill = function() ghost.dispose();
			register(pg, BlendMode.ADD, true); // derrière le héros + additif → traînée arc-en-ciel
		}

		var p = new Particle(e.xx + rnd(0, 4, true), e.yy - e.radius + rnd(0, 4, true));
		p.graphics.lineStyle(1, c, rnd(0.2, 0.5));
		p.graphics.drawCircle(0, 0, 20);
		p.ds = rnd(0.02, 0.05);
		p.life = rnd(3, 8);
		p.filters = [new GlowFilter(c, 1, 8, 8, 2)];
		register(p);
	}

	public function phaseSpark():Void {
		if (lowq) return;
		for (i in 0...2) {
			var p = new Particle(rnd(30, Const.WID - 30), rnd(30, Const.HEI - 30));
			p.drawBox(3, 3, 0xD9C9FA, rnd(0.4, 1));
			p.moveAng(rnd(0, 6.28), rnd(1, 2));
			p.da = rnd(0.03, 0.1);
			p.alpha = 0;
			p.gx = rnd(0, 0.1, true);
			p.gy = rnd(0, 0.1, true);
			p.life = rnd(7, 20);
			p.filters = [new GlowFilter(0x9A70F1, 0.7, 8, 8, 2)];
			register(p);
		}
	}

	// Halo lumineux à l'impact. L'original le voulait en OVERLAY, mais le shim remappe
	// OVERLAY→SCREEN (WebGL v5) qui blanchit et s'EMPILE → flash excessif quand les coups
	// fusent. Rendu en NORMAL, petit et à faible alpha : lueur contenue, sans cumul.
	public function light(x:Float, y:Float):Void {
		if (lowq) return;
		var p = new Particle(x, y);
		p.drawCircle(70, 0xFFFFCC, 0.22);
		p.life = 0;
		p.filters = [new BlurFilter(32, 32)];
		register(p, BlendMode.NORMAL);
	}

	public function spriteFx(k:String, x:Float, y:Float, ?blend:BlendMode):BSprite {
		if (!mode.tiles.exists(k)) return null;
		var s = mode.tiles.getAndPlay(k, 1, true);
		mode.dm.add(s, Const.DP_FX);
		s.setCenter(0.5, 1);
		s.alpha = 0.6;
		s.x = x;
		s.y = y;
		s.blendMode = blend == null ? BlendMode.ADD : blend;
		return s;
	}

	public function popScore(x:Float, y:Float, v:Int):Void {
		// Score doré, plus petit et discret que createField : taille 13, teinte dorée,
		// halo resserré. Flotte vers le haut puis s'efface via la Particle.
		var fmt = new flash.text.TextFormat();
		fmt.font = "def";
		fmt.size = 13;
		fmt.color = 0xFFD24A;
		var tf = new flash.text.TextField();
		tf.defaultTextFormat = fmt;
		tf.embedFonts = true;
		tf.text = Std.string(v);
		var p = new Particle(x, y);
		p.addChild(tf);
		tf.x = Std.int(-tf.textWidth * 0.5);
		tf.y = Std.int(-tf.textHeight);
		tf.filters = [new GlowFilter(0xFFA600, 0.9, 6, 6, 2)];
		p.dy = -0.3;
		register(p);
	}

	public function hit(x:Float, y:Float, n:Int):Void {
		for (i in 0...n) {
			var p = new Particle(x + rnd(0, 10, true), y + rnd(0, 10, true));
			p.drawCircle(rnd(9, 13), 0xFFFFCC, 0.5);
			p.life = 0;
			p.filters = [new GlowFilter(0xFFAC00, 1, 16, 16, 3)];
			register(p);
		}
	}

	public function backHit(from:Entity, to:Entity, ?col = 0xFFCC00):Void {
		if (lowq) return;
		var fc = from.getCenter();
		var tc = to.getCenter();
		var baseAng = Math.atan2(tc.y - fc.y, tc.x - fc.x);
		for (i in 0...5) {
			var a = baseAng + rnd(0, 0.35, true);
			var p = new Particle(fc.x, fc.y);
			p.drawBox(rnd(5, 15), 2, col, rnd(0.4, 0.8));
			p.moveAng(a, rnd(20, 40));
			p.rotation = a;
			p.frictX = p.frictY = rnd(0.80, 0.90);
			p.life = rnd(3, 10);
			p.filters = [new GlowFilter(col, 0.8, 4, 4, 2)];
			register(p);
		}
	}

	public function loseLife(x:Float):Void {
		flashBang(0xFFAC00, 0.5);
		shake(1, 1000);
		if (!mode.tiles.exists("damage")) return;
		var s = mode.tiles.getAndPlay("damage", 1, true);
		mode.dm.add(s, Const.DP_FX);
		s.blendMode = BlendMode.ADD;
		s.setCenter(0.5, 0);
		s.scaleX = s.scaleY = 2;
		s.x = x;
	}

	public function dashTrail(e:Entity, tx:Float, ty:Float):Void {
		var d = Lib.distance(e.xx, e.yy, tx, ty);
		var a = Math.atan2(ty - e.yy, tx - e.xx);
		var n = MLib.ceil(d / 20);
		var dx = Math.cos(a) * d / n;
		var dy = Math.sin(a) * d / n;
		if (mode.tiles.exists("fxDash"))
			for (i in 0...n) {
				var p = new Particle(e.xx + dx * i, e.yy + dy * i);
				var s = mode.tiles.get("fxDash");
				s.setCenter(0.5, 0.5);
				p.addChild(s);
				p.rotation = a;
				p.onKill = function() s.destroy();
				p.ds = -rnd(0.02, 0.05);
				p.scaleX = p.scaleY = rnd(1, 2);
				p.life = rnd(5, 10);
				p.alpha = 0.1 + 0.9 * (i / n);
				register(p);
			}

		var p = new Particle(tx, ty);
		p.drawCircle(25, 0x0ACCF5, 1);
		p.ds = 0.05;
		p.life = 2;
		register(p);
	}

	public function tutorialPointer(cx:Float, cy:Float):Void {
		var n = 300;
		var x = (cx + 0.5) * Const.GRID;
		var y = (cy + 0.5) * Const.GRID;

		var p = new Particle(x, y);
		p.drawCircle(100, 0xFFFF80, 1, false);
		p.filters = [new GlowFilter(0xFF9900, 1, 8, 8, 4)];
		p.ds = -0.08;
		p.onUpdate = function() p.ds *= 0.85;
		p.life = 60;
		register(p);

		for (i in 0...n) {
			var a = rnd(0, 6.28);
			var px = x + Math.cos(a) * 40;
			var py = y + Math.sin(a) * 40;
			var p = new Particle(px, py);
			p.drawCircle(rnd(3, 5), 0xFFFF80);
			p.delay = i * 0.35 + rnd(0, 50);
			p.alpha = 0;
			p.da = 0.15;
			p.moveAng(a + 1.48, 2);
			p.frict = 0.95;
			p.life = rnd(15, 25);
			p.filters = [new BlurFilter(4, 4)];
			register(p);
		}
	}

	public function sparks(x:Float, y:Float, dir:Float):Void {
		for (i in 0...(lowq ? 2 : 5)) {
			var p = new Particle(x, y);
			var w = Std.random(100) < 20 ? 2 : 1;
			p.drawBox(w, w, 0xFFFF00, rnd(0.5, 1));
			p.alpha = 0;
			p.da = 0.2;
			p.dx = -dir * rnd(0, 2);
			p.dy = -rnd(0.2, 2);
			p.rotation = Math.atan2(p.dy, p.dx);
			if (Std.random(100) < 30) p.dx *= 3;
			if (Std.random(100) < 30) p.dy *= 5;
			p.gy = rnd(0.1, 0.3);
			p.life = rnd(5, 15);
			p.frictX = p.frictY = 0.95;
			p.filters = [new GlowFilter(0xFF8600, 1, 8, 8, 6)];
			register(p);
		}
	}

	public function update():Void {
		perf = api.AKApi.getPerf();
		Particle.update();

		// Shake amorti (root.y autour de 0).
		if (shakeMs > 0 && mode != null && mode.root != null) {
			shakeMs -= 1000.0 / 30.0;
			if (shakeMs <= 0) {
				shakeMs = 0;
				mode.root.y = 0;
			} else {
				var r = shakeMs / shakeDur;
				mode.root.y = Math.sin(shakeMs * 0.06) * shakeAmp * r;
			}
		}
	}
}
