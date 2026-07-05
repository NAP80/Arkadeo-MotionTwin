// New Rock Faller - Stone (pierre/gemme).
//   mc = ASprite par couleur : "G0".."G3" (4 cristaux, frame 1 = statique, frames
//   suivantes = BALAYAGE de brillance) ; "Rock" pour le rocher noir (id≥10, isStone,
//   aspiré par les tubes). Anim choisie selon l'id (recréée si la couleur change).
//   Pas de badge _pk (Kado absent en League). Brillance = shine() joue le balayage.
import common_haxe_avm1.display.ASprite;

class Stone {
	public static inline var POINTS = 100;

	public var mc:ASprite;
	public var id:Int;
	public var isNew:Bool;
	var curAnim:String;

	public function new(?hide:Bool = false) {
		isNew = false;
		draw(); // crée mc via setId
	}

	public function draw():Void {
		setId(Game.me.rand(getMaxId()));
	}

	public static inline function getMaxId():Int {
		return 4;
	}

	public function setId(i:Int):Void {
		id = i;
		// "G0".."G3" = gemmes (avec balayage de brillance) ; "Rock" = rocher noir.
		var anim = (i >= 10) ? "Rock" : "G" + i;
		if (mc == null || curAnim != anim) {
			// (re)crée le sprite avec la bonne anim couleur, en conservant la position.
			var ox = 0.0, oy = 0.0;
			var hadOld = (mc != null);
			if (hadOld) {
				ox = mc._x;
				oy = mc._y;
				if (mc.parent != null)
					mc.parent.removeChild(mc);
			}
			mc = new ASprite(anim);
			Game.me.layerStones.addChild(mc);
			if (hadOld) {
				mc._x = ox;
				mc._y = oy;
			}
			curAnim = anim;
		}
		mc.gotoAndStop(1); // frame statique (le balayage de brillance est joué par shine())
	}

	// Balayage de brillance (cf. _stone.gotoAndPlay(1) d'origine) : joue l'anim du
	// cristal une fois (les frames repassent au statique en fin de boucle).
	public function shine():Void {
		if (id >= 10 || mc == null)
			return;
		mc.loop = false;
		mc.gotoAndPlay(1);
	}

	public function isStone():Bool {
		return id >= 10;
	}

	// Marque la pierre comme "posée" une fois sa chute terminée (cf. Slot.fall).
	public function breakIt():Void {
		if (!isNew)
			return;
		isNew = false;
	}

	public function getPoints():Int {
		return POINTS;
	}

	public function kill():Void {
		if (mc != null && mc.parent != null)
			mc.parent.removeChild(mc);
	}
}
