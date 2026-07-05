package seq;

import mt.bumdum9.Lib;
import Protocol;

// Héros touché : meurt (rebond + anim) puis game over à timer 80.
class Hit extends mt.fx.Sequence {
	var vz:Float;

	public function new(b:ent.Bad) {
		super();
		vz = -6;
		Game.me.gstep = 1;

		var h = Game.me.hero;
		h.dead = true;

		if (h.canJump())
			h.skin.play("hero_die_shoe");
		else if (h.isInvincible())
			h.skin.play("hero_die_cap");
		else
			h.skin.play("hero_die");

		h.skin.anim.loop = false;
	}

	override function update() {
		super.update();

		var h = Game.me.hero;
		vz += 0.5;
		h.z += vz;
		h.skin.updateAnim();

		if (h.z > 0) {
			h.z = 0;
			vz *= -0.6;
			if (Math.abs(vz) < 1) {
				h.z = 0;
				vz = 0;
			}
		}

		h.updatePos();
		if (timer == 80) {
			if (api.AKApi.isSpeedrun())
				// SpeedRun : pas de game over -> on rejoue le même niveau (3-2-1-Go), le
				// chrono garde le total. Différé (hors pile update) par Boot.
				Boot.me.srScheduleRespawn();
			else
				api.AKApi.gameOver(false);
		}
	}
}
