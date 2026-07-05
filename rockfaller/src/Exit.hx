// New Rock Faller - Exit (tube/cuve sur la rangée du bas).
// mc = ASprite("Exit") (atlas) :
//   frames 1-7 = les 7 effets (couleur de cuve, numéro gravé au packing). Un rocher
//   (isStone) posé sur la case du tube est aspiré → proc() applique l'effet (+coups
//   ou +score) puis le tube change de case.
import common_haxe_avm1.display.ASprite;

enum ExitEffect {
	Ex_Play_2;
	Ex_Play_3;
	Ex_Play_5;
	Ex_Play_8;
	Ex_Points_1;
	Ex_Points_2;
	Ex_Points_3;
}

class Exit {
	public static inline var EXIT_DELTA = 65;
	public static inline var EXIT_HIDE = 150;
	public static var FX_WEIGHTS = [390, 122, 15, 1, 390, 82, 2];
	public static var FX_VALUES = [2, 3, 4, 6, 1500, 3000, 7000];

	public var dir:Array<Int>;
	public var mc:ASprite;
	public var fx:ExitEffect;
	public var slot:Slot;

	public function new() {
		mc = new ASprite("Exit");
		Game.me.layerExits.addChild(mc);
		setEffect(getRandomEffect());
	}

	public function setPos(x:Int, y:Int):Void {
		var pos = Slot.getStonePos(x, y);
		if (y == Game.STAGE_SIZE - 1) { // bas
			mc._x = pos.x;
			mc._y = pos.y + EXIT_DELTA;
			dir = [0, 1];
		} else {
			mc._x = pos.x + EXIT_DELTA * (x == 0 ? -1 : 1);
			mc._y = pos.y;
			dir = [x == 0 ? -1 : 1, 0];
		}
	}

	public function setEffect(effect:ExitEffect):Void {
		fx = effect;
		var idx = Type.enumIndex(fx);
		// La coupe (atlas) porte DÉJÀ le bon numéro gravé au packing (make_exit_cup) :
		// on sélectionne juste la bonne frame. Aucun texte runtime « en dur ».
		mc.gotoAndStop(idx + 1);
	}

	public function getRandomEffect():ExitEffect {
		return Type.createEnumIndex(ExitEffect, Game.randomProbs(FX_WEIGHTS));
	}

	// Applique l'effet du tube après aspiration d'un rocher : +coups ou +score,
	// puis déplace le tube sur une autre case libre du bas et retire un effet.
	public function proc():Void {
		var idx = Type.enumIndex(fx);
		if (idx < 4)
			Game.me.addPlay(FX_VALUES[idx]);
		else
			Game.me.addScore(FX_VALUES[idx]);

		// Son « pierre dans le gobelet » selon l'effet (cf. startGrab d'origine).
		var sndName = switch (fx) {
			case Ex_Play_2: "Blackrock_life2";
			case Ex_Play_3: "Blackrock_life3";
			case Ex_Play_5 | Ex_Play_8: "Blackrock_life4";
			case Ex_Points_1: "Blackrock_points1";
			default: "Blackrock_points2";
		};
		snd.Sfx.play(sndName);

		// Le tube descend hors-champ, change de case + d'effet, puis remonte
		// (cf. EXIT_HIDE de l'original).
		var nfx = getRandomEffect();
		Game.me.tweenTo(mc, mc._x, mc._y + EXIT_HIDE, 6, function() {
			switchSlot();
			// IMPORTANT : on libère la chaîne d'états (waitingFx) UNIQUEMENT après le
			// déplacement du tube. Ainsi le getCombos suivant voit le tube à sa NOUVELLE
			// case et aspire un rocher qui y serait déjà au sol (sinon il reste coincé).
			Game.me.waitDone();
			setEffect(nfx);
			mc._y = mc._y + EXIT_HIDE; // démarre caché sous la nouvelle case
			snd.Sfx.play("Pipe");
			Game.me.tweenTo(mc, mc._x, mc._y - EXIT_HIDE, 6, null);
		});
	}

	public function switchSlot():Void {
		var slots = Game.me.getFreeExitSlots();
		if (slots.length == 0)
			return;
		var s = slots[Game.me.rand(slots.length)];
		if (slot != null)
			slot.exit = null;
		slot = s;
		s.exit = this;
		setPos(s.x, s.y);
	}
}
