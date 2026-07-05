package ent;

import mt.kiroukou.math.MLib;
import mt.bumdum9.Lib;
import Protocol;

// Base des monstres : poursuite (seekDir), déplacement, collision avec le héros.
class Bad extends Ent {
	public var free:Int;
	public var starDust:Int;
	public var hunter:Int;
	public var uturn:Bool;
	public var jumper:Bool;

	public var skin:EL;
	public var bid:Int;

	public function new() {
		super();
		skin = new EL();
		root.addChild(skin);
		Game.me.bads.push(this);

		dir = 0;
		starDust = 0;
		step = MOVE;
		spc = 0.05;
		hunter = 0;
		free = 3;
		uturn = false;
		jumper = false;
		skin.goto(bid * 2, "bads");
		dropShadow();
	}

	override function update() {
		super.update();

		var h = Game.me.hero;
		if (!h.dead && h.step != JUMPING) {
			var dist = getDistTo(h);
			if (dist < ray + 6) {
				if (h.isInvincible()) {
					Game.me.addStarKill(root.x, root.y); // bonus de score (combo)
					explode();
					new fx.Spawn(MLib.max(0, bid - 1));
				} else {
					new seq.Hit(this);
				}
			}
		}

		if (starDust > 0 && Math.random() < starDust / 40) {
			starDust--;
			var p = square.fxTwinkle();
			p.setPos(root.x + Math.random() * 20 - 10, root.y + Math.random() * 20 - 10);
		}
	}

	override function updatePos() {
		super.updatePos();
		root.x = (Std.int(root.x) >> 1) << 1;
		root.y = (Std.int(root.y) >> 1) << 1;
	}

	override function onEnterSquare() {
		super.onEnterSquare();
		square.heat++;
		checkMove();
	}

	function checkMove() {
		seekDir();
		step = MOVE;

		if (!square.isWallLimit(dir) && !square.dnei[dir].isBlock() && square.getWall(dir) > 0) {
			onStartJump();
			step = JUMPING;
		}
	}

	public function seekDir() {
		// DIR LIST
		var a = [];
		for (di in 0...4) {
			var nsq = square.dnei[di];
			if (nsq == null) continue;
			if (square.getWall(di) > 0 && (!jumper || nsq.hdist < 2)) continue;
			if (jumper && square.isWallLimit(di) || nsq.isBlock()) continue;
			a.push(di);
		}

		// UTURN
		if (a.length > 1 && !uturn) a.remove((dir + 2) % 4);

		// Aucune direction ouverte (monstre boxé) -> demi-tour, sinon il garde une
		// direction périmée et traverse un mur / sort de la grille.
		if (a.length == 0) {
			var back = (dir + 2) % 4;
			if (square.dnei[back] != null) a.push(back);
		}

		// CHOICES
		Arr.shuffle(a, Game.me.seed);
		var best = -1;

		for (di in a) {
			var nsq = square.dnei[di];
			// Garde free == 0 : mt.Rand.random(0) = NaN en JS -> scores tous NaN, dir
			// jamais réassigné, le monstre fonce tout droit à travers les murs.
			var score = (free > 0) ? Game.me.rnd(free) : 0;
			var heat = square.hdist - nsq.hdist;
			if (heat > 0) score += hunter * heat;
			if (square.hdist == 0 && Game.me.hero.dir == di) score += 100;

			if (score > best) {
				best = score;
				dir = di;
			}
		}
	}

	public function autoPos() {
		var sq = Game.me.getFreeRandomSquare(8);
		setSquare(sq.x, sq.y);
		seekDir();
	}

	override function kill() {
		Game.me.bads.remove(this);
		super.kill();
	}

	// FX
	public function explode() {
		var mc = new gfx.PartBadExplosion();
		Level.me.dm.add(mc, Level.DP_FX);
		var p = new mt.fx.Part(mc);
		p.timer = 10;
		p.setPos(root.x, root.y);
		mc.x = root.x;
		mc.y = root.y;
		kill();
	}
}
