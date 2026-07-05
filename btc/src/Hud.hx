import flash.display.Sprite;
import flash.display.Graphics;
import mt.deepnight.slb.BSprite;

// Shadow de Hud : cœurs (crédits) + icône de phase avec jauge de recharge. L'icône
// allumée (phaseOn) est révélée de bas en haut par un masque rectangulaire posé
// par-dessus la version grisée (phaseOff).
// Piège : le masque est posé une fois et jamais retiré (mask=null restaurerait
// renderable=true → carré blanc) ; on ne fait que redessiner le rectangle chaque frame.
class Hud {
	var mode:Mode;
	public var wrapper:Sprite;
	var credits:Array<BSprite>;
	var phaseOn:BSprite;
	var phaseOff:BSprite;
	var phaseGauge:Graphics;

	public function new() {
		mode = Mode.ME;
		credits = [];
		wrapper = new Sprite();
		mode.dm.add(wrapper, Const.DP_INTERF);

		if (mode.tiles.exists("icon_phantom")) {
			phaseOff = mode.tiles.get("icon_phantom", 0); // fantôme grisé (base)
			wrapper.addChild(phaseOff);
			phaseOff.alpha = 0.6;
			phaseOn = mode.tiles.get("icon_phantom", 2); // fantôme allumé (rempli)
			wrapper.addChild(phaseOn);
			phaseOff.x = phaseOn.x = Const.WID - 40;
			phaseOff.y = phaseOn.y = 6;

			phaseGauge = new Graphics();
			wrapper.addChild(phaseGauge);
			untyped phaseOn.mask = phaseGauge; // masque permanent (révèle phaseOn bas->haut)
			untyped phaseGauge.renderable = false; // jamais dessiné en blanc
		}
	}

	public function refresh():Void {
		if (mode.hero == null) return;
		for (s in credits)
			s.dispose();
		credits = [];
		if (!mode.tiles.exists("heart")) return;
		for (i in 0...mode.hero.credits) {
			var s = mode.tiles.get("heart", 0);
			wrapper.addChild(s);
			s.setCenter(0, 0);
			s.x = 5 + i * (s.width + 1);
			s.y = 5;
			credits.push(s);
		}
	}

	public function loseCreditFx():Void {
		if (credits.length == 0) return;
		var s = credits[credits.length - 1];
		mode.fx.creditLoss(s.x + s.width * 0.5, s.y + s.height * 0.5);
	}

	public function update():Void {
		if (phaseOn == null || mode.hero == null) return;
		var t = mode.hero.cd.get("phaseLock");

		// Pendant la recharge : glyphe « en charge » (frame 1) révélé de bas en haut ; le
		// glyphe rempli (frame 2) n'apparaît qu'à 100 %. La base grisée (phaseOff) n'est
		// visible que pendant la recharge. L'icône fait 40×40 → le masque doit tout couvrir.
		phaseGauge.clear();
		phaseGauge.beginFill(0xFFFFFF, 1);
		if (t > 0) {
			phaseOff.visible = true;
			phaseOn.visible = true;
			phaseOn.setFrame(1); // glyphe « en charge », PAS le rempli
			phaseOn.alpha = 0.7;
			var f = 1 - t / Const.PHASE_CD;
			if (f < 0) f = 0;
			else if (f > 1) f = 1;
			var sweep = 28.0; // hauteur du glyphe
			var inset = 6.0; // retrait dans la boîte 40px
			var h = sweep * f;
			phaseGauge.drawRect(phaseOn.x, phaseOn.y + inset + (sweep - h), phaseOn.width, h);
		} else {
			// 100 % uniquement : fantôme REMPLI (frame 2), icône entière, base masquée.
			phaseOff.visible = false;
			phaseOn.visible = true;
			phaseOn.setFrame(2);
			phaseOn.alpha = 1;
			phaseGauge.drawRect(phaseOn.x, phaseOn.y, phaseOn.width, phaseOn.height);
		}
		phaseGauge.endFill();
	}
}
