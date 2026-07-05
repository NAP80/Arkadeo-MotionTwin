package fx;

import mt.bumdum9.Lib;
import Protocol;

// Pivote une porte de 90° en mettant le jeu en pause (Game.stepFx) le temps de l'anim.
class FlipDoor extends mt.fx.Fx {
	var sens:Int;
	var door:Door;

	public function new(door, clockwise) {
		super();
		this.door = door;
		this.sens = clockwise ? 1 : -1;
		Game.me.stepFx = this;

		curveInOut();
	}

	override function update() {
		super.update();
		coef = Math.min(coef + 0.15, 1);

		// Flash : degrés -> PixiJS : radians.
		door.rotation = (-door.dir * 90 + curve(coef) * 90 * sens) * Math.PI / 180;
		if (coef == 1) {
			door.setDir(1 - door.dir);
			Game.me.hero.majHeroDist();
			Game.me.stepFx = null;
			kill();
		}
	}
}
