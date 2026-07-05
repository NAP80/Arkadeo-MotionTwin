// New Rock Faller - Slot (case de la grille 6×6).
// Détient sa pierre + (option) un
// exit (tube) sur la rangée du bas. Sélection (surbrillance 2×2), rotation
// (tween via Game.tweenTo) et chute (gravité, fall()) portées fidèlement.
import common_haxe_avm1.display.ASprite;
import pixi.core.sprites.Sprite;
import pixi.core.Pixi.BlendModes;
import Game.CGroup;

class Slot {
	public static inline var SIZE = 60;
	public static inline var SEL_SCALE = 1.10;

	// Lueur de sélection : silhouette BLANCHE de la gemme, FLOUTÉE et en mode ADD,
	// posée JUSTE DERRIÈRE la pierre → un halo qui épouse le CONTOUR EXACT de la gemme
	// (et non un cadre). Reproduit Filt.glow(stone.mc, 1.7, 10, 0xFFFFFF) de l'original
	// (GlowFilter blanc). Deux filtres PARTAGÉS du build PixiJS de base :
	//   • ColorMatrixFilter forçant RGB→blanc (alpha conservé) - sinon un `tint` blanc
	//     laisse les couleurs de la gemme (halo rouge/bleu au lieu de blanc) ;
	//   • BlurFilter pour étaler le halo.
	static var fWhite:Dynamic = null;
	static var fBlur:Dynamic = null;
	static function ensureFilters():Bool {
		if (fWhite != null)
			return true;
		var has:Bool = js.Syntax.code("(typeof PIXI !== 'undefined' && PIXI.filters && PIXI.filters.BlurFilter && PIXI.filters.ColorMatrixFilter) ? true : false");
		if (!has)
			return false;
		// Matrice 5×4 : out.rgb = 1 (offset), out.a = in.a → silhouette blanche pleine.
		fWhite = js.Syntax.code("(function(){var cm=new PIXI.filters.ColorMatrixFilter();cm.matrix=[0,0,0,0,1, 0,0,0,0,1, 0,0,0,0,1, 0,0,0,1,0];return cm;})()");
		fBlur = js.Syntax.code("new PIXI.filters.BlurFilter(4, 2)");
		return true;
	}

	public var x:Int;
	public var y:Int;
	public var stone:Stone;
	public var exit:Exit;
	public var group:CGroup;
	public var selected:Bool = false;
	var glow:Sprite; // halo blanc (silhouette floutée) derrière la pierre sélectionnée

	// État chute.
	public var waitFall:Int = 0;
	public var g:Float = 0;
	// Brillance : délai avant le balayage (stagger diagonal), null = pas de shine prévu.
	public var waitShine:Null<Float> = null;

	public function new(px:Int, py:Int) {
		x = px;
		y = py;
		stone = new Stone();
		setDefaultStonePos();
		Game.me.allSlots.push(this);
	}

	public function setExit(e:Exit):Void {
		if (exit != null)
			throw "can't set an exit on " + x + "," + y;
		exit = e;
		e.slot = this;
		e.setPos(x, y);
	}

	public function setDefaultStonePos():Void {
		var p = getStonePos(x, y);
		stone.mc._x = p.x;
		stone.mc._y = p.y;
	}

	public static function getStonePos(sx:Int, sy:Int):{x:Float, y:Float} {
		return {x: Game.STAGE_X + (sx + 0.5) * SIZE, y: Game.STAGE_Y + (sy + 0.5) * SIZE};
	}

	public function setStone(st:Stone, ?recal:Bool = true):Void {
		stone = st;
		if (recal)
			setDefaultStonePos();
	}

	// --- Sélection (surbrillance du carré 2×2 sous la souris) ---
	public function select(dir:Array<Int>):Void {
		selected = true;
		var mc = stone.mc;
		Game.me.layerStones.addChild(mc); // remonte la pierre au-dessus des autres
		// Lueur blanche épousant la silhouette (texture forcée blanche + flou), pour
		// TOUTES les pierres (gemmes ET rocher) → même contour qui épouse la forme.
		if (glow == null) {
			glow = new Sprite();
			glow.blendMode = BlendModes.ADD;
			if (ensureFilters())
				untyped glow.filters = js.Syntax.code("[{0},{1}]", fWhite, fBlur);
		}
		glow.texture = mc.texture;
		glow.anchor.set(mc.anchor.x, mc.anchor.y);
		Game.me.layerGlow.addChild(glow); // SOUS toutes les pierres
		syncGlow();
	}

	// Recolle le halo sur la pierre (texture/position/échelle/rotation courantes).
	inline function syncGlow():Void {
		if (glow == null || glow.parent == null)
			return;
		var mc = stone.mc;
		glow.texture = mc.texture;
		glow.x = mc._x;
		glow.y = mc._y;
		var s = mc._xscale / 100 * 1.06; // léger débord → le halo dépasse la gemme
		glow.scale.set(s, s);
		glow.rotation = mc._rotation / 180 * Math.PI;
	}

	public function unselect():Void {
		if (!selected)
			return;
		selected = false;
		stone.mc._rotation = 0;
		if (glow != null && glow.parent != null)
			glow.parent.removeChild(glow);
	}

	// Programme un balayage de brillance après un délai (stagger diagonal (x+y)·0.1).
	public function setShine():Void {
		waitShine = (x + y) * 0.1;
	}

	// Lissage de l'échelle de sélection (1→1.10) + déclenchement différé de la brillance.
	public function update():Void {
		if (stone == null)
			return;
		// Brillance : décompte puis joue le balayage du cristal.
		if (waitShine != null) {
			waitShine -= 0.1;
			if (waitShine <= 0) {
				waitShine = null;
				stone.shine();
			}
		}
		var target = selected ? SEL_SCALE : 1.0;
		var cur = stone.mc._xscale / 100;
		if (Math.abs(cur - target) > 0.004)
			cur += (target - cur) * 0.4;
		else
			cur = target;
		stone.mc._xscale = stone.mc._yscale = cur * 100;
		// Le halo suit la pierre (échelle de sélection 1→1.10, position, texture).
		if (selected)
			syncGlow();
	}

	// --- Rotation : tween de la pierre vers la case voisine (sens horaire) ---
	public function rotate(dIdx:Int):Void {
		stone.mc._rotation = 0;
		var nSlot = Game.me.grid[x + Game.DIRS[dIdx][0]][y + Game.DIRS[dIdx][1]];
		var dest = getStonePos(nSlot.x, nSlot.y);
		Game.me.waitingFx++;
		Game.me.tweenTo(stone.mc, dest.x, dest.y, 5, function() Game.me.waitDone());
	}

	// --- Chute (gravité) : porté de Slot.fall() ---
	public function setFall(?wait:Int = 0):Void {
		waitFall = wait;
		g = 1.4;
		Game.me.falls.push(this);
	}

	public function fall():Void {
		if (waitFall > 0) {
			waitFall--;
			return;
		}
		var nPos = getStonePos(x, y);
		var t = Math.min(10.0 + g, nPos.y - stone.mc._y);
		g = Math.min(g * g, 25.0);
		stone.mc._y = stone.mc._y + t;
		if (nPos.y - stone.mc._y < 4) {
			stone.mc._y = nPos.y;
			Game.me.falls.remove(this);
			stone.breakIt();
			Game.me.onStoneLanded(); // hook son
		}
	}

	// --- Destruction / aspiration ---
	public function vanishStone():Void {
		if (stone == null)
			return;
		stone.kill();
		stone = null;
	}

	public function removeStone():Void {
		if (stone == null)
			return;
		stone.kill();
		stone = null;
	}

	public function killGroup():Void {
		group = null;
	}

	public function kill():Void {
		if (stone != null)
			stone.kill();
		if (exit != null && exit.mc != null && exit.mc.parent != null)
			exit.mc.parent.removeChild(exit.mc);
	}
}
