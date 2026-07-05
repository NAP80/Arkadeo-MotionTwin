import mt.bumdum9.Lib;
import Protocol;

// HUD minimal : le score passe par le host (nc-score)
// On gère le bonus en attente (bonusKind) et son icône (chaussure/étoile, haut-droite).
class Inter {
	public var bonusKind:BonusKind;

	var icon:EL;

	public function new() {
		bonusKind = null;
	}

	public function update() {}

	public function setBonus(k:BonusKind) {
		bonusKind = k;
		if (icon == null) {
			icon = new EL();
			// Plan DP_INTER -> au-dessus du labyrinthe
			Game.me.dm.add(icon, Game.DP_INTER);
			icon.x = Cs.WIDTH - 18;
			icon.y = 18;
		}
		icon.goto(k == BonusKind.BK_Jump ? "shoe" : "cap");
		icon.visible = true;
	}

	public function removeBonus() {
		bonusKind = null;
		if (icon != null) icon.visible = false;
	}
}
