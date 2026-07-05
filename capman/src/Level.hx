import mt.bumdum9.Lib;
import Protocol;

// Conteneur de scène d'un niveau : fond, ombre, murs, et ses propres plans DP_*.
class Level extends SP {
	public static inline var DP_BG = 0;
	public static inline var DP_WALLS = 1;
	public static inline var DP_GROUND = 2;
	public static inline var DP_ENTS = 3;
	public static inline var DP_FX = 4;
	public static inline var DP_SCORE = 5;
	public static inline var DP_PLASMA = 6;

	public var dm:mt.DepthManager;
	public static var me:Level;

	public var bg:SP;
	public var shade:SP;
	public var walls:SP;

	public function new() {
		super();
		me = this;
		dm = new mt.DepthManager(this);
		// BG
		bg = new SP();
		dm.add(bg, DP_BG);
		bg.graphics.beginFill(0x120618);
		bg.graphics.drawRect(0, 0, Cs.WIDTH, Cs.HEIGHT);
		bg.graphics.endFill();

		shade = new SP();
		dm.add(shade, DP_GROUND);
		shade.alpha = 0.5;

		walls = new SP();
		dm.add(walls, DP_WALLS);
	}

	public function kill() {
		// destroy({children:true}) (pas seulement removeChild) : libère tout le sous-arbre
		// du niveau (murs/pièces/entités/plasma/FX, tous enfants de ce Level via dm) -> pas
		// d'accumulation en mémoire quand on enchaîne les niveaux (SpeedRun). Les textures
		// d'atlas partagées ne sont PAS détruites (option texture par défaut = false).
		// Appelé en fin de slide (seq.Init) : le tween n'accède plus au level ensuite, et
		// fxm.clean() a déjà retiré les FX (Part) qui pointaient sur ce sous-arbre.
		// dropUnder : retire les ELs animés de CE niveau de la liste statique ANIMATED
		// (sinon updateAnims les parcourrait après destroy -> crash). Le nouveau niveau,
		// déjà créé, n'est PAS sous `this` -> ses anims sont préservées.
		mt.pix.Element.dropUnder(this);
		if (parent != null) parent.removeChild(this);
		untyped this.destroy({children: true});
	}
}
